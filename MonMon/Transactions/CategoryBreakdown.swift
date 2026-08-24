import Foundation

/// One wedge of the spending doughnut: everything recorded under one category
/// in the period being looked at.
struct CategoryBreakdownSlice: Identifiable, Equatable {
    /// `nil` gathers the transactions whose category was deleted out from under
    /// them, so their money is still counted rather than silently dropped.
    let categoryID: UUID?
    let name: String
    let symbolName: String
    let colorName: String
    let amount: Decimal
    let count: Int

    var id: String {
        categoryID?.uuidString ?? CategoryBreakdown.uncategorizedID
    }
}

enum CategoryBreakdown {
    static let uncategorizedID = "uncategorized"
    static let uncategorizedName = "Uncategorized"

    /// Groups one direction's transactions by category, largest first.
    ///
    /// - Parameter transactions: already narrowed to the period on show. Keeping
    ///   the filtering outside means this reads the same whether it is fed a
    ///   month, a year, or everything.
    static func slices(
        of kind: TransactionKind,
        transactions: [MoneyTransaction],
        categories: [TransactionCategory]
    ) -> [CategoryBreakdownSlice] {
        let matching = transactions.filter { $0.kind == kind }
        var totals: [UUID?: (amount: Decimal, count: Int)] = [:]

        for transaction in matching {
            let existing = totals[transaction.categoryID] ?? (.zero, 0)
            totals[transaction.categoryID] = (
                existing.amount + transaction.amount,
                existing.count + 1
            )
        }

        let slices = totals.map { categoryID, total in
            let category = categoryID.flatMap { id in
                categories.first { $0.id == id }
            }

            return CategoryBreakdownSlice(
                categoryID: categoryID,
                name: category?.name ?? uncategorizedName,
                symbolName: CategoryPalette.symbolName(
                    category?.symbolName ?? CategoryPalette.defaultSymbolName
                ),
                colorName: CategoryPalette.colorName(
                    category?.colorName ?? CategoryPalette.defaultColorName
                ),
                amount: total.amount,
                count: total.count
            )
        }

        // Sorted by amount, then by name, so an even split never reorders
        // itself between redraws.
        return slices.sorted {
            $0.amount == $1.amount ? $0.name < $1.name : $0.amount > $1.amount
        }
    }

    /// The wedge a given fraction of the way round the doughnut, measured
    /// clockwise from twelve o'clock, which is where the chart starts drawing.
    ///
    /// The wedges are laid out in the order they are listed, so running their
    /// shares up until the turn is passed lands on the one under the finger.
    /// Nothing outside a single turn belongs to a wedge.
    static func slice(
        atTurn turn: Double,
        in slices: [CategoryBreakdownSlice]
    ) -> CategoryBreakdownSlice? {
        let total = total(of: slices)

        guard total > 0, turn >= 0, turn < 1 else {
            return nil
        }

        var passed = Decimal.zero

        for slice in slices {
            passed += slice.amount

            if Decimal(turn) < passed / total {
                return slice
            }
        }

        return slices.last
    }

    static func total(of slices: [CategoryBreakdownSlice]) -> Decimal {
        slices.reduce(Decimal.zero) { total, slice in
            total + slice.amount
        }
    }

    /// The transactions behind one wedge, newest first.
    static func transactions(
        for categoryID: UUID?,
        of kind: TransactionKind,
        in transactions: [MoneyTransaction]
    ) -> [MoneyTransaction] {
        transactions
            .filter { $0.kind == kind && $0.categoryID == categoryID }
            .sorted { $0.occurredAt > $1.occurredAt }
    }
}
