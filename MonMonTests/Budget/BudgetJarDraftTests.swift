import Foundation
import Testing

@testable import MonMon

@Suite("Budget jar draft")
struct BudgetJarDraftTests {
    @Test("A jar cannot push total allocation above one hundred percent")
    func totalCannotExceedOneHundred() {
        let existing = [jar(name: "Needs", percent: 90)]
        let draft = BudgetJarDraft(name: "Play", allocationText: "11")

        #expect(throws: BudgetJarFormError.allocationExceeds100) {
            try draft.makeJar(id: UUID(), createdAt: .now, existing: existing)
        }
    }

    @Test("Editing excludes the jar's previous percentage from the total")
    func editingExcludesTheOldValue() throws {
        let needs = jar(name: "Needs", percent: 55)
        let play = jar(name: "Play", percent: 10)
        let draft = BudgetJarDraft(name: "Fun", allocationText: "20")

        try draft.apply(to: play, existing: [needs, play])

        #expect(play.name == "Fun")
        #expect(play.allocationPercent == 20)
    }

    @Test("Names and percentages are validated")
    func fieldsAreValidated() {
        #expect(throws: BudgetJarFormError.emptyName) {
            try BudgetJarDraft(name: " ", allocationText: "10")
                .makeJar(id: UUID(), createdAt: .now, existing: [])
        }
        #expect(throws: BudgetJarFormError.invalidPercent) {
            try BudgetJarDraft(name: "Play", allocationText: "ten")
                .makeJar(id: UUID(), createdAt: .now, existing: [])
        }
        #expect(throws: BudgetJarFormError.negativePercent) {
            try BudgetJarDraft(name: "Play", allocationText: "-1")
                .makeJar(id: UUID(), createdAt: .now, existing: [])
        }
    }

    private func jar(name: String, percent: Decimal) -> BudgetJar {
        BudgetJar(
            id: UUID(),
            name: name,
            allocationPercent: percent,
            role: .custom,
            symbolName: "tag.fill",
            colorName: "green",
            createdAt: .now
        )
    }
}
