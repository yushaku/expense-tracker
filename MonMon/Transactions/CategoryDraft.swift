import Foundation

enum CategoryFormError: Error, Equatable {
    case emptyName
    case duplicateName
}

struct CategoryDraft: Equatable {
    var name: String
    var kind: TransactionKind
    var symbolName: String
    var colorName: String

    init(
        name: String = "",
        kind: TransactionKind = .expense,
        symbolName: String = CategoryPalette.defaultSymbolName,
        colorName: String = CategoryPalette.defaultColorName
    ) {
        self.name = name
        self.kind = kind
        self.symbolName = CategoryPalette.symbolName(symbolName)
        self.colorName = CategoryPalette.colorName(colorName)
    }

    init(category: TransactionCategory) {
        self.init(
            name: category.name,
            kind: category.kind,
            symbolName: category.symbolName,
            colorName: category.colorName
        )
    }

    /// Validated values ready to write to a model.
    struct ValidatedValues: Equatable {
        var name: String
        var kind: TransactionKind
        var symbolName: String
        var colorName: String
    }

    /// - Parameters:
    ///   - existing: every category already stored, used for the duplicate-name
    ///     check. Two categories may share a name across kinds — "Gift" is a
    ///     plausible expense and a plausible income — but not within one.
    ///   - editedID: the category being edited, so it does not clash with itself.
    func validate(
        existing: [TransactionCategory],
        editedID: UUID?
    ) throws -> ValidatedValues {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw CategoryFormError.emptyName
        }

        let isDuplicate = existing.contains { category in
            category.id != editedID
                && category.kind == kind
                && category.name.caseInsensitiveCompare(trimmedName) == .orderedSame
        }
        guard !isDuplicate else {
            throw CategoryFormError.duplicateName
        }

        return ValidatedValues(
            name: trimmedName,
            kind: kind,
            symbolName: CategoryPalette.symbolName(symbolName),
            colorName: CategoryPalette.colorName(colorName)
        )
    }

    func makeCategory(
        id: UUID,
        createdAt: Date,
        existing: [TransactionCategory]
    ) throws -> TransactionCategory {
        let values = try validate(existing: existing, editedID: nil)

        return TransactionCategory(
            id: id,
            name: values.name,
            kind: values.kind,
            symbolName: values.symbolName,
            colorName: values.colorName,
            createdAt: createdAt
        )
    }

    func apply(
        to category: TransactionCategory,
        existing: [TransactionCategory]
    ) throws {
        let values = try validate(existing: existing, editedID: category.id)

        category.name = values.name
        category.kind = values.kind
        category.symbolName = values.symbolName
        category.colorName = values.colorName
    }
}
