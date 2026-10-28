import SwiftData
import SwiftUI

/// Shared dated history; callers may include internal transfers.
///
/// Spending defines the visual language: transactions are grouped by day, the
/// day's net sits in its header. Transactions keep their edit/delete gestures;
/// transfers share the same details, edit and delete interactions. The enclosing screen owns the shared transaction
/// actions so sheets and the Undo banner stay anchored to its viewport.
struct TransactionListSection<Accessory: View>: View {
    @Environment(\.appDateFormat) private var dateFormat

    @Environment(\.locale) private var locale

    @Query(sort: \TripWorkspace.startedAt, order: .reverse)
    private var tripWorkspaces: [TripWorkspace]

    let title: LocalizedStringKey

    let transactions: [MoneyTransaction]
    let transfers: [AccountTransfer]
    let categories: [TransactionCategory]
    let accounts: [CashAccount]
    let emptyNotice: LocalizedStringKey
    let accessibilityIdentifierPrefix: String
    let showsCount: Bool
    @ViewBuilder let accessory: Accessory

    init(
        title: LocalizedStringKey,
        transactions: [MoneyTransaction],
        transfers: [AccountTransfer] = [],
        categories: [TransactionCategory],
        accounts: [CashAccount],
        emptyNotice: LocalizedStringKey,
        accessibilityIdentifierPrefix: String = "transaction",
        showsCount: Bool = false,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.title = title
        self.transactions = transactions
        self.transfers = transfers
        self.categories = categories
        self.accounts = accounts
        self.emptyNotice = emptyNotice
        self.accessibilityIdentifierPrefix = accessibilityIdentifierPrefix
        self.showsCount = showsCount
        self.accessory = accessory()
    }

    var body: some View {
        // Grouping and the id lookups run once per update rather than once per
        // row: a month can hold hundreds of rows, and each linear search over
        // categories, accounts and trips used to run again for every one.
        let groups = dayGroups
        let lookup = TransactionRowLookup(
            categories: categories,
            accounts: accounts,
            trips: tripWorkspaces
        )

        // Lazy, so only the days near the viewport are built. The enclosing
        // screens put this inside their own scroll view; a plain stack here
        // made every row of the period exist, and rebuild, at once.
        LazyVStack(alignment: .leading, spacing: 20) {
            header

            if transactions.isEmpty && transfers.isEmpty {
                Text(emptyNotice)
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }

            ForEach(groups) { group in
                VStack(alignment: .leading, spacing: 12) {
                    dayHeader(for: group)

                    ForEach(group.entries) { entry in
                        switch entry {
                        case .transaction(let transaction):
                            TransactionItem(
                                transaction: transaction,
                                category: lookup.category(for: transaction),
                                account: lookup.account(transaction.accountID),
                                tripName: lookup.tripName(for: transaction),
                                showsDate: false,
                                accessibilityIdentifier:
                                    "\(accessibilityIdentifierPrefix)-\(transaction.id.uuidString)"
                            )
                        case .transfer(let transfer):
                            TransferItem(
                                transfer: transfer,
                                sourceAccount: lookup.account(transfer.sourceAccountID),
                                destinationAccount: lookup.account(transfer.destinationAccountID),
                                showsDate: false
                            )
                            .accessibilityIdentifier("history-transfer-\(transfer.id.uuidString)")
                        }
                    }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if showsCount {
                Text((transactions.count + transfers.count).formatted())
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MonMonTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(MonMonTheme.accent.opacity(0.16), in: Capsule())
            }

            Spacer(minLength: 8)

            accessory
        }
    }

    private var dayGroups: [TransactionHistoryDay] {
        TransactionHistory.byDay(transactions: transactions, transfers: transfers)
    }

    private func dayHeader(for group: TransactionHistoryDay) -> some View {
        HStack(spacing: 12) {
            Text(
                dateFormat.calendarDay(group.day)
                    .uppercased()
            )
            .font(.caption.weight(.semibold))
            .tracking(0.8)
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            Spacer(minLength: 8)

            Text(signed(group.net))
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
        }
        .foregroundStyle(MonMonTheme.textSecondary)
        .padding(.horizontal, 4)
        .accessibilityElement(children: .combine)
    }

    private func signed(_ amount: Decimal) -> String {
        let magnitude = amount < 0 ? -amount : amount
        let sign = amount < 0 ? "−" : "+"

        return "\(sign)\(VNDCurrency.format(magnitude))"
    }

}

extension TransactionListSection where Accessory == EmptyView {
    init(
        title: LocalizedStringKey = "Transactions",
        transactions: [MoneyTransaction],
        transfers: [AccountTransfer] = [],
        categories: [TransactionCategory],
        accounts: [CashAccount],
        emptyNotice: LocalizedStringKey,
        accessibilityIdentifierPrefix: String = "transaction",
        showsCount: Bool = false
    ) {
        self.init(
            title: title,
            transactions: transactions,
            transfers: transfers,
            categories: categories,
            accounts: accounts,
            emptyNotice: emptyNotice,
            accessibilityIdentifierPrefix: accessibilityIdentifierPrefix,
            showsCount: showsCount
        ) {
            EmptyView()
        }
    }
}

/// What each history row looks up by id, keyed once for the whole list. The
/// first record with an id wins, which is what the linear `first(where:)`
/// searches it replaces returned when a duplicate slipped in.
struct TransactionRowLookup {
    private let categories: [UUID: TransactionCategory]
    private let accounts: [UUID: CashAccount]
    private let tripNames: [UUID: String]

    init(
        categories: [TransactionCategory],
        accounts: [CashAccount],
        trips: [TripWorkspace]
    ) {
        self.categories = Dictionary(firstWins: categories.map { ($0.id, $0) })
        self.accounts = Dictionary(firstWins: accounts.map { ($0.id, $0) })
        self.tripNames = Dictionary(firstWins: trips.map { ($0.id, $0.name) })
    }

    func category(for transaction: MoneyTransaction) -> TransactionCategory? {
        transaction.categoryID.flatMap { categories[$0] }
    }

    func account(_ id: UUID) -> CashAccount? {
        accounts[id]
    }

    func tripName(for transaction: MoneyTransaction) -> String? {
        transaction.tripWorkspaceID.flatMap { tripNames[$0] }
    }
}
