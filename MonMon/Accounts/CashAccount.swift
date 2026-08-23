import Foundation
import SwiftData

@Model
final class CashAccount {
    var id: UUID
    var name: String
    var kind: CashAccountKind
    var openingBalance: Decimal
    var currencyCode: String
    var createdAt: Date

    init(
        id: UUID,
        name: String,
        kind: CashAccountKind,
        openingBalance: Decimal,
        currencyCode: String,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.openingBalance = openingBalance
        self.currencyCode = currencyCode
        self.createdAt = createdAt
    }
}

#if DEBUG
    extension CashAccount {
        static func preview(
            name: String,
            kind: CashAccountKind,
            openingBalance: Decimal,
            createdOffset: TimeInterval = 0
        ) -> CashAccount {
            CashAccount(
                id: UUID(),
                name: name,
                kind: kind,
                openingBalance: openingBalance,
                currencyCode: VNDCurrency.code,
                createdAt: Date(timeIntervalSince1970: 1_700_000_000 + createdOffset)
            )
        }
    }

    extension SavingsDeposit {
        static func preview(
            name: String,
            principal: Decimal,
            annualInterestRate: Decimal,
            termMonths: Int,
            openedOffset: TimeInterval = 0,
            sourceAccountID: UUID? = nil
        ) -> SavingsDeposit {
            let openedAt = Date(timeIntervalSince1970: 1_700_000_000 + openedOffset)

            return SavingsDeposit(
                id: UUID(),
                name: name,
                principal: principal,
                annualInterestRate: annualInterestRate,
                termMonths: termMonths,
                openedAt: openedAt,
                currencyCode: VNDCurrency.code,
                createdAt: openedAt,
                sourceAccountID: sourceAccountID
            )
        }
    }

    extension FundInstrument {
        static func preview(
            name: String,
            symbol: String,
            kind: FundInstrumentKind,
            currentPricePerUnit: Decimal,
            priceOffset: TimeInterval = 0,
            source: FundQuoteSource = .manual
        ) -> FundInstrument {
            let priceAsOf = Date(timeIntervalSince1970: 1_700_000_000 + priceOffset)

            return FundInstrument(
                id: UUID(),
                symbol: symbol,
                name: name,
                kind: kind,
                currentPricePerUnit: currentPricePerUnit,
                priceAsOf: priceAsOf,
                priceSource: source.rawValue,
                priceFetchedAt: source == .manual ? nil : priceAsOf,
                autoQuoteEnabled: true,
                currencyCode: VNDCurrency.code,
                createdAt: priceAsOf
            )
        }
    }

    extension FundHolding {
        static func preview(
            instrument: FundInstrument,
            units: Decimal,
            averageCostPerUnit: Decimal,
            createdOffset: TimeInterval = 0,
            sourceAccountID: UUID? = nil
        ) -> FundHolding {
            FundHolding(
                id: UUID(),
                instrumentID: instrument.id,
                units: units,
                averageCostPerUnit: averageCostPerUnit,
                createdAt: Date(timeIntervalSince1970: 1_700_000_000 + createdOffset),
                sourceAccountID: sourceAccountID
            )
        }
    }

    extension TransactionCategory {
        static func preview(
            name: String,
            kind: TransactionKind,
            symbolName: String,
            colorName: String,
            createdOffset: TimeInterval = 0
        ) -> TransactionCategory {
            TransactionCategory(
                id: UUID(),
                name: name,
                kind: kind,
                symbolName: symbolName,
                colorName: colorName,
                createdAt: Date(timeIntervalSince1970: 1_700_000_000 + createdOffset)
            )
        }
    }

    extension MoneyTransaction {
        static func preview(
            kind: TransactionKind,
            amount: Decimal,
            note: String = "",
            accountID: UUID,
            categoryID: UUID?,
            occurredOffset: TimeInterval = 0
        ) -> MoneyTransaction {
            let occurredAt = Date(timeIntervalSince1970: 1_700_000_000 + occurredOffset)

            return MoneyTransaction(
                id: UUID(),
                kind: kind,
                amount: amount,
                occurredAt: occurredAt,
                note: note,
                accountID: accountID,
                categoryID: categoryID,
                currencyCode: VNDCurrency.code,
                createdAt: occurredAt
            )
        }
    }

    extension AccountTransfer {
        static func preview(
            amount: Decimal,
            note: String = "",
            sourceAccountID: UUID,
            destinationAccountID: UUID,
            occurredOffset: TimeInterval = 0
        ) -> AccountTransfer {
            let occurredAt = Date(timeIntervalSince1970: 1_700_000_000 + occurredOffset)

            return AccountTransfer(
                id: UUID(),
                amount: amount,
                occurredAt: occurredAt,
                note: note,
                sourceAccountID: sourceAccountID,
                destinationAccountID: destinationAccountID,
                currencyCode: VNDCurrency.code,
                createdAt: occurredAt
            )
        }
    }

    extension Debt {
        static func preview(
            counterparty: String,
            direction: DebtDirection,
            principal: Decimal,
            annualInterestRate: Decimal = 0,
            dueDate: Date? = nil,
            accountID: UUID? = nil,
            note: String = "",
            createdOffset: TimeInterval = 0
        ) -> Debt {
            let createdAt = Date(timeIntervalSince1970: 1_700_000_000 - createdOffset)
            return Debt(
                id: UUID(),
                counterparty: counterparty,
                direction: direction,
                principal: principal,
                annualInterestRate: annualInterestRate,
                openedAt: createdAt,
                dueDate: dueDate,
                accountID: accountID,
                note: note,
                currencyCode: VNDCurrency.code,
                createdAt: createdAt
            )
        }
    }

    extension DebtPayment {
        static func preview(
            debtID: UUID,
            amount: Decimal,
            accountID: UUID,
            note: String = "",
            occurredOffset: TimeInterval = 0
        ) -> DebtPayment {
            let occurredAt = Date(timeIntervalSince1970: 1_700_000_000 - occurredOffset)
            return DebtPayment(
                id: UUID(),
                debtID: debtID,
                amount: amount,
                occurredAt: occurredAt,
                accountID: accountID,
                note: note,
                currencyCode: VNDCurrency.code,
                createdAt: occurredAt
            )
        }
    }

    @MainActor
    enum PreviewData {
        static let empty = makeContainer(
            accounts: [],
            deposits: [],
            instruments: [],
            holdings: [],
            categories: [],
            transactions: [],
            transfers: []
        )

        static let populated: ModelContainer = {
            let wallet = CashAccount.preview(
                name: "Wallet",
                kind: .cash,
                openingBalance: 1_250_000
            )
            let techcombank = CashAccount.preview(
                name: "Techcombank",
                kind: .bank,
                openingBalance: 148_900_000,
                createdOffset: 60
            )
            let emergency = CashAccount.preview(
                name: "Emergency fund",
                kind: .bank,
                openingBalance: 120_000_000,
                createdOffset: 120
            )
            let food = TransactionCategory.preview(
                name: "Food",
                kind: .expense,
                symbolName: "fork.knife",
                colorName: "peach"
            )
            let salary = TransactionCategory.preview(
                name: "Salary",
                kind: .income,
                symbolName: "briefcase.fill",
                colorName: "green",
                createdOffset: 60
            )
            let vesaf = FundInstrument.preview(
                name: "VinaCapital VESAF",
                symbol: "VESAF",
                kind: .fund,
                currentPricePerUnit: Decimal(string: "27431.28") ?? 0,
                source: .fmarket
            )
            let diamond = FundInstrument.preview(
                name: "Diamond ETF",
                symbol: "FUEVFVND",
                kind: .etf,
                currentPricePerUnit: 29_850,
                priceOffset: 86_400 * 20,
                source: .vndirect
            )

            let borrowed = Debt.preview(
                counterparty: "Anh Minh",
                direction: .borrowed,
                principal: 30_000_000,
                accountID: wallet.id,
                note: "Help with the deposit"
            )
            let lent = Debt.preview(
                counterparty: "Chị Lan",
                direction: .lent,
                principal: 5_000_000,
                accountID: techcombank.id,
                createdOffset: 86_400 * 20
            )
            // A debt taken before tracking began: it names no account, because
            // its money is already inside an opening balance.
            let legacy = Debt.preview(
                counterparty: "Techcombank",
                direction: .borrowed,
                principal: 250_000_000,
                annualInterestRate: Decimal(string: "8.5") ?? 0,
                dueDate: Date(timeIntervalSince1970: 1_800_000_000),
                createdOffset: 86_400 * 200
            )

            return makeContainer(
                accounts: [wallet, techcombank, emergency],
                deposits: [
                    .preview(
                        name: "Techcombank 6 tháng",
                        principal: 100_000_000,
                        annualInterestRate: Decimal(string: "5.6") ?? 0,
                        termMonths: 6,
                        sourceAccountID: techcombank.id
                    ),
                    .preview(
                        name: "VietinBank 12 tháng",
                        principal: 250_000_000,
                        annualInterestRate: Decimal(string: "6.1") ?? 0,
                        termMonths: 12,
                        openedOffset: 86_400 * 40
                    ),
                ],
                instruments: [vesaf, diamond],
                holdings: [
                    .preview(
                        instrument: vesaf,
                        units: Decimal(string: "1234.5678") ?? 0,
                        averageCostPerUnit: 24_500,
                        sourceAccountID: techcombank.id
                    ),
                    .preview(
                        instrument: diamond,
                        units: 2_000,
                        averageCostPerUnit: 32_100,
                        createdOffset: 86_400 * 20
                    ),
                ],
                categories: [food, salary],
                transactions: [
                    .preview(
                        kind: .expense,
                        amount: 185_000,
                        note: "Lunch with the team",
                        accountID: wallet.id,
                        categoryID: food.id
                    ),
                    .preview(
                        kind: .income,
                        amount: 32_000_000,
                        note: "August salary",
                        accountID: techcombank.id,
                        categoryID: salary.id,
                        occurredOffset: 86_400 * 2
                    ),
                ],
                transfers: [
                    .preview(
                        amount: 2_000_000,
                        note: "Cash for the week",
                        sourceAccountID: techcombank.id,
                        destinationAccountID: wallet.id,
                        occurredOffset: 86_400
                    )
                ],
                debts: [borrowed, lent, legacy],
                payments: [
                    .preview(
                        debtID: borrowed.id,
                        amount: 12_000_000,
                        accountID: wallet.id,
                        note: "First instalment",
                        occurredOffset: 86_400 * 10
                    ),
                    .preview(
                        debtID: lent.id,
                        amount: 5_000_000,
                        accountID: techcombank.id,
                        occurredOffset: 86_400 * 3
                    ),
                ]
            )
        }()

        private static func makeContainer(
            accounts: [CashAccount],
            deposits: [SavingsDeposit],
            instruments: [FundInstrument],
            holdings: [FundHolding],
            categories: [TransactionCategory],
            transactions: [MoneyTransaction],
            transfers: [AccountTransfer],
            debts: [Debt] = [],
            payments: [DebtPayment] = []
        ) -> ModelContainer {
            let container: ModelContainer
            do {
                container = try ModelContainer(
                    for: Schema(MonMonSchema.models),
                    configurations: ModelConfiguration(isStoredInMemoryOnly: true)
                )
            } catch {
                fatalError("Preview container failed: \(error)")
            }

            for account in accounts {
                container.mainContext.insert(account)
            }

            for deposit in deposits {
                container.mainContext.insert(deposit)
            }

            for instrument in instruments {
                container.mainContext.insert(instrument)
            }

            for holding in holdings {
                container.mainContext.insert(holding)
            }

            for category in categories {
                container.mainContext.insert(category)
            }

            for transaction in transactions {
                container.mainContext.insert(transaction)
            }

            for transfer in transfers {
                container.mainContext.insert(transfer)
            }

            for debt in debts {
                container.mainContext.insert(debt)
            }

            for payment in payments {
                container.mainContext.insert(payment)
            }

            return container
        }
    }
#endif
