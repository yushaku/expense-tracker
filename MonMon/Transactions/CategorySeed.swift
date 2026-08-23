import Foundation
import SwiftData

/// The starter categories written into an empty store so the owner can record a
/// transaction without setting anything up first. Every one of them can be
/// renamed, restyled, or deleted afterwards.
enum CategorySeed {
    struct Template {
        let name: String
        let kind: TransactionKind
        let symbolName: String
        let colorName: String
    }

    static let templates: [Template] = [
        Template(name: "Food", kind: .expense, symbolName: "fork.knife", colorName: "peach"),
        Template(name: "Transport", kind: .expense, symbolName: "car.fill", colorName: "blue"),
        Template(name: "Housing", kind: .expense, symbolName: "house.fill", colorName: "mauve"),
        Template(name: "Shopping", kind: .expense, symbolName: "cart.fill", colorName: "pink"),
        Template(name: "Health", kind: .expense, symbolName: "cross.case.fill", colorName: "red"),
        Template(
            name: "Entertainment",
            kind: .expense,
            symbolName: "gamecontroller.fill",
            colorName: "lavender"
        ),
        Template(name: "Salary", kind: .income, symbolName: "briefcase.fill", colorName: "green"),
        Template(name: "Bonus", kind: .income, symbolName: "gift.fill", colorName: "yellow"),
        Template(
            name: "Interest",
            kind: .income,
            symbolName: "building.columns.fill",
            colorName: "teal"
        ),
    ]

    static func makeCategories(createdAt: Date) -> [TransactionCategory] {
        templates.enumerated().map { offset, template in
            TransactionCategory(
                id: UUID(),
                name: template.name,
                kind: template.kind,
                symbolName: template.symbolName,
                colorName: template.colorName,
                // Spaced so the seeded order survives a sort by creation date.
                createdAt: createdAt.addingTimeInterval(Double(offset))
            )
        }
    }

    /// Seeds only a store that holds no category at all. Deleting one seeded
    /// category never brings the whole set back.
    @MainActor
    static func seedIfEmpty(in context: ModelContext, createdAt: Date = .now) {
        let existing = (try? context.fetchCount(FetchDescriptor<TransactionCategory>())) ?? 0
        guard existing == 0 else {
            return
        }

        for category in makeCategories(createdAt: createdAt) {
            context.insert(category)
        }

        try? context.save()
    }
}
