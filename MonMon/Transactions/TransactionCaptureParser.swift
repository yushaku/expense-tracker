import Foundation

struct CaptureAccount: Equatable, Sendable {
    let id: UUID
    let name: String
    let isCash: Bool
}

struct CaptureCategory: Equatable, Sendable {
    let id: UUID
    let name: String
    let kind: TransactionKind
    let symbolName: String
}

struct TransactionCaptureContext: Equatable, Sendable {
    var accounts: [CaptureAccount]
    var categories: [CaptureCategory]
    var defaultAccountID: UUID?
    var defaultExpenseCategoryID: UUID?
    var defaultIncomeCategoryID: UUID?
}

enum TransactionCaptureIssue: String, Codable, Equatable, Hashable, Sendable {
    case missingAmount
    case multipleAmounts
    case invalidAmount
    case missingAccount
    case ambiguousAccount
    case missingCategory
    case ambiguousCategory
    case notificationNeedsReview
    case applePayNeedsReview
    case unsupportedCurrency
}

struct ParsedTransactionCapture: Equatable, Sendable {
    let rawText: String
    let kind: TransactionKind
    let amount: Decimal?
    let occurredAt: Date
    let note: String
    let accountID: UUID?
    let categoryID: UUID?
    let issues: Set<TransactionCaptureIssue>

    var isReady: Bool {
        amount != nil && accountID != nil && categoryID != nil && issues.isEmpty
    }
}

enum TransactionCaptureParser {
    private struct AmountMatch {
        let range: Range<String.Index>
        let amount: Decimal?
    }

    private static let amountExpression = try? NSRegularExpression(
        pattern:
            #"(?<![\p{L}\p{N}])(\d+(?:[.,]\d+)*)(?:\s*)(k|nghin|ngan|tr|trieu)?(?![\p{L}\p{N}])"#
    )
    private static let amountWord =
        #"(?:khong|mot|hai|ba|bon|tu|nam|lam|sau|bay|tam|chin|muoi|tram|linh|le|nghin|ngan|trieu)"#
    private static let wordAmountExpression = try? NSRegularExpression(
        pattern: #"(?<![\p{L}\p{N}])("# + amountWord + #"(?:\s+"# + amountWord
            + #")+)(?![\p{L}\p{N}])"#
    )

    static func parse(
        _ rawText: String,
        context: TransactionCaptureContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> ParsedTransactionCapture {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchable = normalize(trimmed)
        let amountMatches = findAmounts(in: trimmed)
        let kind = inferKind(from: searchable, original: trimmed)
        let occurredAt = inferDate(from: searchable, now: now, calendar: calendar)

        var issues = Set<TransactionCaptureIssue>()
        let amount: Decimal?
        switch amountMatches.count {
        case 0:
            amount = nil
            issues.insert(.missingAmount)
        case 1:
            if let parsedAmount = amountMatches[0].amount, parsedAmount > 0 {
                amount = parsedAmount
            } else {
                amount = nil
                issues.insert(.invalidAmount)
            }
        default:
            amount = nil
            issues.insert(.multipleAmounts)
        }

        let accountID = resolveAccount(
            in: searchable,
            context: context,
            issues: &issues
        )
        let categoryID = resolveCategory(
            for: kind,
            in: searchable,
            context: context,
            issues: &issues
        )

        return ParsedTransactionCapture(
            rawText: trimmed,
            kind: kind,
            amount: amount,
            occurredAt: occurredAt,
            note: makeNote(from: trimmed, amountMatches: amountMatches),
            accountID: accountID,
            categoryID: categoryID,
            issues: issues
        )
    }

    private static func findAmounts(in text: String) -> [AmountMatch] {
        guard let amountExpression else {
            return []
        }

        let normalized = normalize(text)
        let range = NSRange(normalized.startIndex..<normalized.endIndex, in: normalized)

        var matches: [AmountMatch] = amountExpression.matches(in: normalized, range: range)
            .compactMap {
                match in
                guard
                    let wholeRange = Range(match.range(at: 0), in: text),
                    let numberRange = Range(match.range(at: 1), in: normalized)
                else {
                    return nil
                }

                let number = String(normalized[numberRange])
                let suffix: String
                if let suffixRange = Range(match.range(at: 2), in: normalized) {
                    suffix = String(normalized[suffixRange])
                } else {
                    suffix = ""
                }

                return AmountMatch(
                    range: wholeRange,
                    amount: parseAmount(number: number, suffix: suffix)
                )
            }

        if let wordAmountExpression {
            matches.append(
                contentsOf: wordAmountExpression.matches(in: normalized, range: range).compactMap {
                    match in
                    guard
                        let wholeRange = Range(match.range(at: 0), in: text),
                        let wordsRange = Range(match.range(at: 1), in: normalized),
                        let amount = parseVietnameseAmountWords(String(normalized[wordsRange]))
                    else { return nil }
                    return AmountMatch(range: wholeRange, amount: amount)
                })
        }

        return matches
    }

    private static func parseAmount(number: String, suffix: String) -> Decimal? {
        let multiplier: Decimal
        switch suffix {
        case "k", "nghin", "ngan":
            multiplier = 1_000
        case "tr", "trieu":
            multiplier = 1_000_000
        default:
            multiplier = 1
        }

        let separators = number.filter { $0 == "." || $0 == "," }
        let normalizedNumber: String
        if multiplier > 1, separators.count == 1,
            let separator = number.firstIndex(where: { $0 == "." || $0 == "," })
        {
            let fractionCount = number.distance(
                from: number.index(after: separator), to: number.endIndex)
            normalizedNumber =
                fractionCount <= 2
                ? number.replacingOccurrences(of: ",", with: ".")
                : number.replacingOccurrences(of: ".", with: "")
                    .replacingOccurrences(of: ",", with: "")
        } else {
            normalizedNumber = number.replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: "")
        }

        guard
            let value = Decimal(string: normalizedNumber, locale: Locale(identifier: "en_US_POSIX"))
        else {
            return nil
        }

        return value * multiplier
    }

    private static func parseVietnameseAmountWords(_ words: String) -> Decimal? {
        let tokens = words.split(whereSeparator: \Character.isWhitespace).map(String.init)
        guard tokens.contains(where: { ["nghin", "ngan", "trieu"].contains($0) }) else {
            return nil
        }

        let digits = [
            "khong": 0, "mot": 1, "hai": 2, "ba": 3, "bon": 4, "tu": 4,
            "nam": 5, "lam": 5, "sau": 6, "bay": 7, "tam": 8, "chin": 9,
        ]
        var total = 0
        var group = 0
        var currentDigit: Int?

        for token in tokens {
            if let digit = digits[token] {
                currentDigit = digit
                continue
            }
            switch token {
            case "muoi":
                group += (currentDigit ?? 1) * 10
                currentDigit = nil
            case "tram":
                group += (currentDigit ?? 1) * 100
                currentDigit = nil
            case "nghin", "ngan":
                group += currentDigit ?? 0
                total += group * 1_000
                group = 0
                currentDigit = nil
            case "trieu":
                group += currentDigit ?? 0
                total += group * 1_000_000
                group = 0
                currentDigit = nil
            case "linh", "le":
                continue
            default:
                return nil
            }
        }

        total += group + (currentDigit ?? 0)
        return total > 0 ? Decimal(total) : nil
    }

    private static func inferKind(from text: String, original: String) -> TransactionKind {
        let incomePhrases = [
            "nhan", "duoc nhan", "duoc tra", "tien vao", "chuyen den",
            "luong", "thuong", "hoa hong", "tien lai", "lai tiet kiem", "co tuc", "hoan tien",
            "income", "salary", "bonus", "interest", "refund",
        ]
        let accentSensitive = original.lowercased(with: Locale(identifier: "vi_VN"))
        let hasAccentSensitiveIncome = ["thu", "lãi"].contains {
            containsPhrase($0, in: accentSensitive)
        }
        let hasFoldedIncome = incomePhrases.contains { containsPhrase($0, in: text) }
        return hasAccentSensitiveIncome || hasFoldedIncome ? .income : .expense
    }

    private static func inferDate(from text: String, now: Date, calendar: Calendar) -> Date {
        let relativeDates: [(phrases: [String], days: Int)] = [
            (["hom kia", "the day before yesterday"], -2),
            (["hom qua", "toi qua", "sang qua", "chieu qua", "dem qua", "yesterday"], -1),
        ]
        for relativeDate in relativeDates
        where relativeDate.phrases.contains(where: { containsPhrase($0, in: text) }) {
            return calendar.date(byAdding: .day, value: relativeDate.days, to: now) ?? now
        }
        return now
    }

    private static func resolveAccount(
        in text: String,
        context: TransactionCaptureContext,
        issues: inout Set<TransactionCaptureIssue>
    ) -> UUID? {
        var matches = context.accounts.filter { account in
            containsPhrase(normalize(account.name), in: text)
        }

        if containsPhrase("tien mat", in: text) || containsPhrase("cash", in: text) {
            matches.append(contentsOf: context.accounts.filter(\.isCash))
        }

        let uniqueMatches = uniqueIDs(matches.map(\.id))
        if uniqueMatches.count > 1 {
            issues.insert(.ambiguousAccount)
            return nil
        }
        if let match = uniqueMatches.first {
            return match
        }

        guard
            let defaultID = context.defaultAccountID,
            context.accounts.contains(where: { $0.id == defaultID })
        else {
            issues.insert(.missingAccount)
            return nil
        }
        return defaultID
    }

    private static func resolveCategory(
        for kind: TransactionKind,
        in text: String,
        context: TransactionCaptureContext,
        issues: inout Set<TransactionCaptureIssue>
    ) -> UUID? {
        let candidates = context.categories.filter { $0.kind == kind }
        let scoredMatches = candidates.compactMap { category -> (id: UUID, score: Int)? in
            let phrases = [normalize(category.name)] + categoryAliases(for: category)
            let scores = phrases.compactMap { phrase in
                containsPhrase(phrase, in: text) ? phrase.count : nil
            }
            guard let score = scores.max() else { return nil }
            return (category.id, score)
        }
        let bestScore = scoredMatches.map(\.score).max()
        let uniqueMatches = uniqueIDs(
            scoredMatches.filter { $0.score == bestScore }.map(\.id)
        )
        if uniqueMatches.count > 1 {
            issues.insert(.ambiguousCategory)
            return nil
        }
        if let match = uniqueMatches.first {
            return match
        }

        let defaultID =
            kind == .expense
            ? context.defaultExpenseCategoryID : context.defaultIncomeCategoryID
        guard
            let defaultID,
            candidates.contains(where: { $0.id == defaultID })
        else {
            issues.insert(.missingCategory)
            return nil
        }
        return defaultID
    }

    private static func categoryAliases(for category: CaptureCategory) -> [String] {
        switch category.symbolName {
        case "fork.knife":
            [
                "an", "an sang", "an trua", "an toi", "an uong", "bua sang", "bua trua",
                "bua toi", "com", "pho", "bun", "banh mi", "do an", "nha hang", "quan an",
                "cafe", "ca phe", "tra sua", "nuoc uong", "food", "breakfast", "lunch",
                "dinner", "coffee",
            ]
        case "car.fill":
            [
                "di chuyen", "xang", "do xang", "gui xe", "ve xe", "xe buyt", "xe om",
                "taxi", "grab", "be", "gojek", "tau", "metro", "ve tau", "ve may bay",
                "transport", "parking",
            ]
        case "house.fill":
            [
                "nha", "tien nha", "thue nha", "tien dien", "tien nuoc", "wifi", "internet",
                "gas", "sua nha", "chung cu", "housing", "rent", "utilities",
            ]
        case "cart.fill":
            [
                "mua sam", "sieu thi", "quan ao", "giay dep", "do gia dung", "shopee",
                "lazada", "shopping", "groceries",
            ]
        case "cross.case.fill":
            [
                "thuoc", "kham", "kham benh", "nha khoa", "bac si", "benh vien",
                "bao hiem y te", "health", "medical", "doctor", "dentist",
            ]
        case "gamecontroller.fill":
            [
                "game", "phim", "xem phim", "ve xem phim", "rap phim", "di choi", "netflix",
                "spotify", "karaoke", "giai tri", "concert", "entertainment", "cinema",
            ]
        case "tag.fill":
            ["khac", "other"]
        case "briefcase.fill":
            ["luong", "tien luong", "tien cong", "payroll", "salary", "wage"]
        case "gift.fill":
            ["thuong", "tien thuong", "hoa hong", "bonus", "commission"]
        case "building.columns.fill":
            ["lai", "tien lai", "lai tiet kiem", "co tuc", "interest", "dividend"]
        default:
            []
        }
    }

    private static func makeNote(
        from text: String,
        amountMatches: [AmountMatch]
    ) -> String {
        var note = text
        for match in amountMatches.sorted(by: { $0.range.lowerBound > $1.range.lowerBound }) {
            note.replaceSubrange(match.range, with: " ")
        }

        let removablePhrases = [
            "hôm kia", "hôm qua", "tối qua", "sáng qua", "chiều qua", "đêm qua", "hôm nay",
            "the day before yesterday", "yesterday", "today", "tiền mặt", "cash", "thu", "nhận",
            "income",
        ]
        for phrase in removablePhrases {
            note = note.replacingOccurrences(
                of: phrase,
                with: " ",
                options: [.caseInsensitive, .diacriticInsensitive]
            )
        }

        return note.split(whereSeparator: \Character.isWhitespace).joined(separator: " ")
    }

    private static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "đ", with: "d")
            .lowercased()
    }

    private static func containsPhrase(_ phrase: String, in text: String) -> Bool {
        guard !phrase.isEmpty else {
            return false
        }

        let escaped = NSRegularExpression.escapedPattern(for: phrase)
        let expression = try? NSRegularExpression(
            pattern: "(?<![\\p{L}\\p{N}])\(escaped)(?![\\p{L}\\p{N}])"
        )
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression?.firstMatch(in: text, range: range) != nil
    }

    private static func uniqueIDs(_ ids: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        return ids.filter { seen.insert($0).inserted }
    }
}
