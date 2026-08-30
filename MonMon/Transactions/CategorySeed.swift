import Foundation
import SwiftData
import SwiftUI

/// The starter categories written into an empty store so the owner can record a
/// transaction without setting anything up first. Every one of them can be
/// renamed, restyled, or deleted afterwards.
enum CategorySeed {
    static let defaultExpenseName = "Food"
    static let defaultIncomeName = "Salary"

    /// The starter category a direction falls back on when the owner has not
    /// chosen one. Renaming or deleting it simply leaves that direction with no
    /// default, which the pickers show as "Choose".
    static func defaultName(for kind: TransactionKind) -> String {
        switch kind {
        case .expense:
            defaultExpenseName
        case .income:
            defaultIncomeName
        }
    }

    struct Template {
        /// Fixed rather than generated, for the same reason `AccountSeed` fixes
        /// its own: two devices seeding the same starter set must produce the
        /// same rows. It also decouples a category's identity from its name,
        /// which is now written in whichever language the owner picked — two
        /// devices set to different languages would otherwise seed nine
        /// categories each and agree on none of them.
        let id: UUID
        /// The key the catalogue answers. Resolved once, at seeding, and stored
        /// as an ordinary name the owner is free to rename afterwards.
        let nameKey: String
        let kind: TransactionKind
        let symbolName: String
        let colorName: String
    }

    /// The id of the nth starter category. Built from its bytes for the reason
    /// `AccountSeed.unassignedID` explains: the ids have to be plain values, not
    /// something computed while the schema is being built.
    private static func seedID(_ index: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, index))
    }

    static let entertainmentID = seedID(6)

    static let templates: [Template] = [
        Template(
            id: seedID(1),
            nameKey: defaultExpenseName,
            kind: .expense,
            symbolName: "fork.knife",
            colorName: "peach"
        ),
        Template(
            id: seedID(2),
            nameKey: "Transport",
            kind: .expense,
            symbolName: "car.fill",
            colorName: "blue"
        ),
        Template(
            id: seedID(3),
            nameKey: "Housing",
            kind: .expense,
            symbolName: "house.fill",
            colorName: "mauve"
        ),
        Template(
            id: seedID(4),
            nameKey: "Shopping",
            kind: .expense,
            symbolName: "cart.fill",
            colorName: "pink"
        ),
        Template(
            id: seedID(5),
            nameKey: "Health",
            kind: .expense,
            symbolName: "cross.case.fill",
            colorName: "red"
        ),
        Template(
            id: entertainmentID,
            nameKey: "Entertainment",
            kind: .expense,
            symbolName: "gamecontroller.fill",
            colorName: "lavender"
        ),
        Template(
            id: seedID(7),
            nameKey: defaultIncomeName,
            kind: .income,
            symbolName: "briefcase.fill",
            colorName: "green"
        ),
        Template(
            id: seedID(8),
            nameKey: "Bonus",
            kind: .income,
            symbolName: "gift.fill",
            colorName: "yellow"
        ),
        Template(
            id: seedID(9),
            nameKey: "Interest",
            kind: .income,
            symbolName: "building.columns.fill",
            colorName: "teal"
        ),
    ]

    /// The starter category a direction falls back on, named by identity rather
    /// than by its name, which the owner may since have rewritten — or which may
    /// have been seeded in the other language.
    static func defaultID(for kind: TransactionKind) -> UUID {
        switch kind {
        case .expense:
            seedID(1)
        case .income:
            seedID(7)
        }
    }

    static func makeCategories(
        createdAt: Date,
        locale: Locale = AppLanguage.stored.locale
    ) -> [TransactionCategory] {
        templates.enumerated().map { offset, template in
            TransactionCategory(
                id: template.id,
                name: AppText.string(key: template.nameKey, in: locale),
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
    static func seedIfEmpty(
        in context: ModelContext,
        createdAt: Date = .now,
        locale: Locale = AppLanguage.stored.locale
    ) {
        let existing = (try? context.fetchCount(FetchDescriptor<TransactionCategory>())) ?? 0
        guard existing == 0 else {
            return
        }

        for category in makeCategories(createdAt: createdAt, locale: locale) {
            context.insert(category)
        }

        try? context.save()
    }
}
