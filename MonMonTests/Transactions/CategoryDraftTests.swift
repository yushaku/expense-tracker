import Foundation
import Testing

@testable import MonMon

@Suite("Category draft validation")
struct CategoryDraftTests {
    private let createdAt = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeCategory(
        name: String,
        kind: TransactionKind
    ) -> TransactionCategory {
        TransactionCategory(
            id: UUID(),
            name: name,
            kind: kind,
            symbolName: CategoryPalette.defaultSymbolName,
            colorName: CategoryPalette.defaultColorName,
            createdAt: createdAt
        )
    }

    @Test("A complete draft validates and trims its name")
    func completeDraftValidates() throws {
        let draft = CategoryDraft(
            name: "  Food  ",
            kind: .expense,
            symbolName: "fork.knife",
            colorName: "peach"
        )

        let category = try draft.makeCategory(id: UUID(), createdAt: createdAt, existing: [])

        #expect(category.name == "Food")
        #expect(category.kind == .expense)
        #expect(category.symbolName == "fork.knife")
        #expect(category.colorName == "peach")
    }

    @Test("A blank name is rejected")
    func blankNameIsRejected() {
        let draft = CategoryDraft(name: "   ")

        #expect(throws: CategoryFormError.emptyName) {
            try draft.makeCategory(id: UUID(), createdAt: createdAt, existing: [])
        }
    }

    @Test("A name already used by the same kind is rejected, ignoring case")
    func duplicateNameIsRejected() {
        let existing = [makeCategory(name: "Food", kind: .expense)]
        let draft = CategoryDraft(name: "food", kind: .expense)

        #expect(throws: CategoryFormError.duplicateName) {
            try draft.makeCategory(id: UUID(), createdAt: createdAt, existing: existing)
        }
    }

    @Test("The same name is allowed on the other direction")
    func nameMayRepeatAcrossKinds() throws {
        let existing = [makeCategory(name: "Gift", kind: .expense)]
        let draft = CategoryDraft(name: "Gift", kind: .income)

        let category = try draft.makeCategory(
            id: UUID(),
            createdAt: createdAt,
            existing: existing
        )

        #expect(category.kind == .income)
    }

    @Test("Editing a category does not clash with its own name")
    func editingKeepsItsOwnName() throws {
        let category = makeCategory(name: "Food", kind: .expense)
        var draft = CategoryDraft(category: category)
        draft.colorName = "teal"

        try draft.apply(to: category, existing: [category])

        #expect(category.name == "Food")
        #expect(category.colorName == "teal")
    }

    @Test("A category round trips through a draft")
    func categoryRoundTripsThroughDraft() {
        let category = makeCategory(name: "Transport", kind: .expense)
        category.symbolName = "car.fill"
        category.colorName = "blue"

        let draft = CategoryDraft(category: category)

        #expect(draft.name == "Transport")
        #expect(draft.kind == .expense)
        #expect(draft.symbolName == "car.fill")
        #expect(draft.colorName == "blue")
    }

    @Test("An unknown symbol or colour falls back to a renderable default")
    func unknownStyleFallsBack() {
        let draft = CategoryDraft(
            name: "Food",
            symbolName: "not.a.symbol",
            colorName: "chartreuse"
        )

        #expect(draft.symbolName == CategoryPalette.defaultSymbolName)
        #expect(draft.colorName == CategoryPalette.defaultColorName)
    }
}
