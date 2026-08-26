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

    static func parse(
        _ rawText: String,
        context: TransactionCaptureContext,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> ParsedTransactionCapture {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchable = normalize(trimmed)
        let amountMatches = findAmounts(in: trimmed)
        let kind = inferKind(from: searchable)
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

        return amountExpression.matches(in: normalized, range: range).compactMap { match in
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

    private static func inferKind(from text: String) -> TransactionKind {
        let incomePhrases = ["thu", "nhan", "luong", "thuong", "hoan tien", "income"]
        return incomePhrases.contains { containsPhrase($0, in: text) } ? .income : .expense
    }

    private static func inferDate(from text: String, now: Date, calendar: Calendar) -> Date {
        guard containsPhrase("hom qua", in: text) else {
            return now
        }

        return calendar.date(byAdding: .day, value: -1, to: now) ?? now
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
        var matches = candidates.filter { category in
            containsPhrase(normalize(category.name), in: text)
        }

        for category in candidates
        where categoryAliases(for: category).contains(where: {
            containsPhrase($0, in: text)
        }) {
            matches.append(category)
        }

        let uniqueMatches = uniqueIDs(matches.map(\.id))
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
            ["an", "an trua", "an toi", "com", "cafe", "ca phe", "food"]
        case "car.fill":
            ["xang", "taxi", "grab", "xe", "transport"]
        case "house.fill":
            ["nha", "tien nha", "dien", "nuoc", "housing"]
        case "cart.fill":
            ["mua sam", "shopping"]
        case "cross.case.fill":
            ["thuoc", "kham", "benh vien", "health"]
        case "gamecontroller.fill":
            ["game", "phim", "giai tri", "entertainment"]
        case "briefcase.fill":
            ["luong", "salary"]
        case "gift.fill":
            ["thuong", "bonus"]
        case "building.columns.fill":
            ["lai", "interest"]
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
            "hôm qua", "hôm nay", "tiền mặt", "cash", "thu", "nhận", "income",
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
