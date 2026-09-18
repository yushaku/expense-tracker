import Foundation

enum TransactionCategoryClassificationStrategy: Sendable {
    case balanced
    case englishFirst
}

enum TransactionCategoryClassificationResult: Equatable, Sendable {
    case matched(UUID)
    case ambiguous
    case noMatch

    var categoryID: UUID? {
        guard case .matched(let id) = self else { return nil }
        return id
    }
}

/// Shared category inference for Quick Note, bank notifications, and Apple Pay.
/// Amount, direction, date, and safety validation remain owned by each source.
enum TransactionCategoryClassifier {
    private enum Vocabulary {
        case english
        case vietnamese
    }

    static func classify(
        _ rawText: String,
        kind: TransactionKind,
        categories: [CaptureCategory],
        strategy: TransactionCategoryClassificationStrategy
    ) -> TransactionCategoryClassificationResult {
        let text = normalize(rawText)
        let candidates = categories.filter { $0.kind == kind }

        switch strategy {
        case .balanced:
            return bestMatch(
                in: text, candidates: candidates, includesCategoryName: true,
                vocabularies: [.english, .vietnamese])
        case .englishFirst:
            let english = bestMatch(
                in: text, candidates: candidates, includesCategoryName: false,
                vocabularies: [.english])
            guard english == .noMatch else { return english }
            return bestMatch(
                in: text, candidates: candidates, includesCategoryName: true,
                vocabularies: [.vietnamese])
        }
    }

    private static func bestMatch(
        in text: String,
        candidates: [CaptureCategory],
        includesCategoryName: Bool,
        vocabularies: [Vocabulary]
    ) -> TransactionCategoryClassificationResult {
        let scoredMatches = candidates.compactMap { category -> (id: UUID, score: Int)? in
            var phrases = includesCategoryName ? [normalize(category.name)] : []
            for vocabulary in vocabularies {
                phrases.append(contentsOf: aliases(for: category, vocabulary: vocabulary))
            }
            let scores = phrases.compactMap { phrase in
                containsPhrase(phrase, in: text) ? phrase.count : nil
            }
            guard let score = scores.max() else { return nil }
            return (category.id, score)
        }

        guard let bestScore = scoredMatches.map(\.score).max() else { return .noMatch }
        let ids = uniqueIDs(scoredMatches.filter { $0.score == bestScore }.map(\.id))
        if ids.count > 1 { return .ambiguous }
        return ids.first.map(TransactionCategoryClassificationResult.matched) ?? .noMatch
    }

    private static func aliases(
        for category: CaptureCategory,
        vocabulary: Vocabulary
    ) -> [String] {
        switch vocabulary {
        case .english:
            return englishAliases(for: category.symbolName)
        case .vietnamese:
            return vietnameseAliases(for: category.symbolName)
        }
    }

    private static func englishAliases(for symbolName: String) -> [String] {
        switch symbolName {
        case "fork.knife":
            return [
                "starbucks", "highlands", "phuc long", "grabfood", "shopeefood", "restaurant",
                "coffee", "cafe", "food", "meal", "breakfast", "lunch", "dinner", "bakery",
                "kfc", "mcdonald", "lotteria", "pizza",
            ]
        case "car.fill":
            return [
                "grab trip", "grab", "gojek", "taxi", "parking", "fuel", "petrol",
                "gas station", "transport", "metro", "train", "bus", "airline", "flight",
                "vietjet", "vietnam airlines",
            ]
        case "house.fill":
            return [
                "electricity", "electric bill", "water bill", "internet", "wifi", "utility",
                "utilities", "rent", "evn",
            ]
        case "cart.fill":
            return [
                "shopee", "lazada", "tiktok shop", "supermarket", "shopping", "retail",
                "store", "mall", "clothing", "grocery", "groceries",
            ]
        case "cross.case.fill":
            return [
                "pharmacity", "long chau", "hospital", "clinic", "pharmacy", "doctor",
                "dental", "dentist", "medical", "health",
            ]
        case "gamecontroller.fill":
            return [
                "netflix", "spotify", "cinema", "movie", "steam", "game", "youtube",
                "karaoke", "concert", "entertainment",
            ]
        case "briefcase.fill", "banknote.fill":
            return ["salary", "payroll", "wage", "income"]
        case "gift.fill":
            return ["bonus", "commission", "reward"]
        case "building.columns.fill":
            return ["deposit interest", "bank interest", "interest", "dividend"]
        case "tag.fill":
            return ["other"]
        default:
            return []
        }
    }

    private static func vietnameseAliases(for symbolName: String) -> [String] {
        switch symbolName {
        case "fork.knife":
            return [
                "an", "an sang", "an trua", "an toi", "an uong", "bua sang", "bua trua",
                "bua toi", "com", "pho", "bun", "banh mi", "do an", "nha hang", "quan an",
                "ca phe", "tra sua", "nuoc uong",
            ]
        case "car.fill":
            return [
                "di chuyen", "di lai", "xang", "do xang", "gui xe", "ve xe", "xe buyt",
                "xe om", "tau", "ve tau", "ve may bay",
            ]
        case "house.fill":
            return [
                "nha", "tien nha", "thue nha", "tien dien", "tien nuoc", "sua nha",
                "chung cu",
            ]
        case "cart.fill":
            return ["mua sam", "sieu thi", "quan ao", "giay dep", "do gia dung", "mua hang"]
        case "cross.case.fill":
            return [
                "thuoc", "nha thuoc", "kham", "kham benh", "nha khoa", "bac si",
                "benh vien", "bao hiem y te",
            ]
        case "gamecontroller.fill":
            return ["phim", "xem phim", "ve xem phim", "rap phim", "di choi", "giai tri"]
        case "briefcase.fill", "banknote.fill":
            return ["luong", "tien luong", "tien cong", "thu nhap"]
        case "gift.fill":
            return ["thuong", "tien thuong", "hoa hong"]
        case "building.columns.fill":
            return ["lai", "tien lai", "lai tiet kiem", "co tuc"]
        case "tag.fill":
            return ["khac"]
        default:
            return []
        }
    }

    private static func normalize(_ text: String) -> String {
        text.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "vi_VN")
        ).replacingOccurrences(of: "đ", with: "d").lowercased()
    }

    private static func containsPhrase(_ phrase: String, in text: String) -> Bool {
        guard !phrase.isEmpty else { return false }
        let escaped = NSRegularExpression.escapedPattern(for: phrase)
        let expression = try? NSRegularExpression(
            pattern: "(?<![\\p{L}\\p{N}])\(escaped)(?![\\p{L}\\p{N}])")
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression?.firstMatch(in: text, range: range) != nil
    }

    private static func uniqueIDs(_ ids: [UUID]) -> [UUID] {
        var seen = Set<UUID>()
        return ids.filter { seen.insert($0).inserted }
    }
}
