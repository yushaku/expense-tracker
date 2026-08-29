import Foundation
import SwiftData

enum BudgetJarSeed {
    static let necessitiesID = seedID(1)
    static let investmentID = seedID(2)
    static let educationID = seedID(3)
    static let savingsID = seedID(4)
    static let playID = seedID(5)
    static let givingID = seedID(6)

    private struct Template {
        let id: UUID
        let nameKey: String
        let allocationPercent: Decimal
        let role: BudgetJarRole
        let symbolName: String
        let colorName: String
    }

    private static let templates: [Template] = [
        Template(
            id: necessitiesID,
            nameKey: "Necessities",
            allocationPercent: 55,
            role: .custom,
            symbolName: "house.fill",
            colorName: "blue"
        ),
        Template(
            id: investmentID,
            nameKey: "Investment",
            allocationPercent: 10,
            role: .investment,
            symbolName: "chart.line.uptrend.xyaxis",
            colorName: "mauve"
        ),
        Template(
            id: educationID,
            nameKey: "Education",
            allocationPercent: 10,
            role: .custom,
            symbolName: "graduationcap.fill",
            colorName: "teal"
        ),
        Template(
            id: savingsID,
            nameKey: "Savings",
            allocationPercent: 10,
            role: .savings,
            symbolName: "building.columns.fill",
            colorName: "yellow"
        ),
        Template(
            id: playID,
            nameKey: "Play",
            allocationPercent: 10,
            role: .custom,
            symbolName: "gamecontroller.fill",
            colorName: "pink"
        ),
        Template(
            id: givingID,
            nameKey: "Giving",
            allocationPercent: 5,
            role: .custom,
            symbolName: "gift.fill",
            colorName: "peach"
        ),
    ]

    private static func seedID(_ index: UInt8) -> UUID {
        UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, index))
    }

    @MainActor
    static func seedIfNeeded(
        in context: ModelContext,
        createdAt: Date = .now,
        locale: Locale = AppLanguage.stored.locale,
        saveChanges: Bool = true
    ) {
        let existing = (try? context.fetchCount(FetchDescriptor<BudgetJar>())) ?? 0
        guard existing == 0 else {
            return
        }

        for (offset, template) in templates.enumerated() {
            context.insert(
                BudgetJar(
                    id: template.id,
                    name: AppText.string(key: template.nameKey, in: locale),
                    allocationPercent: template.allocationPercent,
                    role: template.role,
                    symbolName: template.symbolName,
                    colorName: template.colorName,
                    createdAt: createdAt.addingTimeInterval(Double(offset))
                )
            )
        }

        let categories = (try? context.fetch(FetchDescriptor<TransactionCategory>())) ?? []
        for category in categories where category.kind == .expense && category.budgetJarID == nil {
            category.budgetJarID =
                category.id == CategorySeed.entertainmentID
                ? playID : necessitiesID
        }

        if saveChanges {
            try? context.save()
        }
    }
}
