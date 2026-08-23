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

    extension FundHolding {
        static func preview(
            name: String,
            symbol: String,
            kind: FundHoldingKind,
            units: Decimal,
            averageCostPerUnit: Decimal,
            currentNAVPerUnit: Decimal,
            navOffset: TimeInterval = 0,
            sourceAccountID: UUID? = nil
        ) -> FundHolding {
            let navAsOf = Date(timeIntervalSince1970: 1_700_000_000 + navOffset)

            return FundHolding(
                id: UUID(),
                name: name,
                symbol: symbol,
                kind: kind,
                units: units,
                averageCostPerUnit: averageCostPerUnit,
                currentNAVPerUnit: currentNAVPerUnit,
                navAsOf: navAsOf,
                currencyCode: VNDCurrency.code,
                createdAt: navAsOf,
                sourceAccountID: sourceAccountID
            )
        }
    }

    @MainActor
    enum PreviewData {
        static let empty = makeContainer(accounts: [], deposits: [], holdings: [])

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
                holdings: [
                    .preview(
                        name: "VinaCapital VESAF",
                        symbol: "VESAF",
                        kind: .fund,
                        units: Decimal(string: "1234.5678") ?? 0,
                        averageCostPerUnit: 24_500,
                        currentNAVPerUnit: Decimal(string: "27431.28") ?? 0,
                        sourceAccountID: techcombank.id
                    ),
                    .preview(
                        name: "Diamond ETF",
                        symbol: "FUEVFVND",
                        kind: .etf,
                        units: 2_000,
                        averageCostPerUnit: 32_100,
                        currentNAVPerUnit: 29_850,
                        navOffset: 86_400 * 20
                    ),
                ]
            )
        }()

        private static func makeContainer(
            accounts: [CashAccount],
            deposits: [SavingsDeposit],
            holdings: [FundHolding]
        ) -> ModelContainer {
            let container: ModelContainer
            do {
                container = try ModelContainer(
                    for: CashAccount.self, SavingsDeposit.self, FundHolding.self,
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

            for holding in holdings {
                container.mainContext.insert(holding)
            }

            return container
        }
    }
#endif
