import Foundation

enum CashBalanceSummary {
    /// A credit card's limit is borrowing capacity, not owner cash. The ledger
    /// balance is negative while money is owed, so adding it to the limit gives
    /// the amount still available without changing any wealth calculation.
    static func availableCredit(limit: Decimal, currentBalance: Decimal) -> Decimal {
        max(.zero, limit + currentBalance)
    }

    static func total(of accounts: [CashAccount]) -> Decimal {
        accounts.reduce(Decimal.zero) { total, account in
            total + account.openingBalance
        }
    }

    /// Money moved out of this account and still tied up elsewhere: the principal
    /// of every savings deposit it funded plus the cost basis of every fund
    /// holding it bought. `holdings` has no default value on purpose — a
    /// forgotten argument would silently overstate the spendable balance.
    static func fundedAmount(
        for account: CashAccount,
        deposits: [SavingsDeposit],
        holdings: [FundHolding]
    ) -> Decimal {
        let depositedPrincipal = deposits.reduce(Decimal.zero) { total, deposit in
            deposit.sourceAccountID == account.id ? total + deposit.principal : total
        }

        return holdings.reduce(depositedPrincipal) { total, holding in
            holding.sourceAccountID == account.id ? total + holding.costBasis : total
        }
    }

    /// Where tracking started, plus the recorded cash flow, plus what internal
    /// transfers moved in or out, plus what debts and their payments moved, plus
    /// what selling a position paid back in, minus the money moved into savings
    /// deposits and funds. `openingBalance` is never rewritten; every later
    /// change is derived.
    ///
    /// A sale is added rather than netted against `fundedAmount`, and that pair
    /// is what makes closing a position come out right. `fundedAmount` keeps
    /// subtracting the lot's original cost, because that is the money that
    /// genuinely left on the day it was bought and no later event changes it;
    /// the sale adds what came back. Over a full round trip the account moves by
    /// the realized profit alone, which is why selling never has to rewrite the
    /// lot it came out of.
    ///
    /// Like `holdings`, none of the collections has a default value, and the
    /// reason has grown teeth: a forgotten argument would silently misreport the
    /// spendable balance, and every source-balance guard in the app now reads
    /// this figure, so the app would permit an overdraft while claiming it had
    /// checked.
    ///
    /// Debt flow needs its own term rather than riding on `fundedAmount`: a
    /// deposit only ever removes cash, whereas borrowing adds it.
    static func available(
        for account: CashAccount,
        deposits: [SavingsDeposit],
        holdings: [FundHolding],
        withdrawals: [SavingsWithdrawal],
        transactions: [MoneyTransaction],
        transfers: [AccountTransfer],
        debts: [Debt],
        payments: [DebtPayment],
        sales: [FundSale]
    ) -> Decimal {
        account.openingBalance
            + TransactionSummary.netFlow(for: account, transactions: transactions)
            + TransferSummary.netFlow(for: account, transfers: transfers)
            + DebtSummary.netFlow(for: account, debts: debts, payments: payments)
            + FundSaleSummary.netFlow(for: account, sales: sales)
            + SavingsWithdrawalSummary.netFlow(for: account, withdrawals: withdrawals)
            - fundedAmount(for: account, deposits: deposits, holdings: holdings)
    }

    /// `available(for:...)` for every account at once, keyed by account id.
    ///
    /// Each record is read once and credited to the account it names, instead
    /// of each account rescanning the whole ledger. A screen with N account
    /// cards used to cost N full passes over every transaction per update; this
    /// costs one. The terms are added in the same order as `available` adds
    /// them, so each figure is the same `Decimal`, which the tests pin.
    /// Records naming an account not in `accounts` are ignored, as they are
    /// there.
    static func balances(
        of accounts: [CashAccount],
        deposits: [SavingsDeposit],
        holdings: [FundHolding],
        withdrawals: [SavingsWithdrawal],
        transactions: [MoneyTransaction],
        transfers: [AccountTransfer],
        debts: [Debt],
        payments: [DebtPayment],
        sales: [FundSale]
    ) -> [UUID: Decimal] {
        var transactionFlow: [UUID: Decimal] = [:]
        for transaction in transactions {
            transactionFlow[transaction.accountID, default: .zero] += transaction.signedAmount
        }

        var transferFlow: [UUID: Decimal] = [:]
        for transfer in transfers {
            // Matches `AccountTransfer.signedAmount(for:)`: when both ends name
            // the same account the source side wins.
            transferFlow[transfer.sourceAccountID, default: .zero] -= transfer.amount
            if transfer.destinationAccountID != transfer.sourceAccountID {
                transferFlow[transfer.destinationAccountID, default: .zero] += transfer.amount
            }
        }

        var debtFlow: [UUID: Decimal] = [:]
        var directions: [UUID: DebtDirection] = [:]
        for debt in debts {
            directions[debt.id] = debt.direction
            if let accountID = debt.accountID {
                debtFlow[accountID, default: .zero] += debt.signedPrincipal
            }
        }
        for payment in payments {
            guard let debtID = payment.debtID, let direction = directions[debtID] else {
                continue
            }
            debtFlow[payment.accountID, default: .zero] += payment.signedAmount(for: direction)
        }

        var saleFlow: [UUID: Decimal] = [:]
        for sale in sales where !sale.isSwap {
            saleFlow[sale.proceedsAccountID, default: .zero] += sale.proceeds
        }

        var withdrawalFlow: [UUID: Decimal] = [:]
        for withdrawal in withdrawals {
            withdrawalFlow[withdrawal.destinationAccountID, default: .zero] +=
                withdrawal.amountReceived
        }

        var funded: [UUID: Decimal] = [:]
        for deposit in deposits {
            if let accountID = deposit.sourceAccountID {
                funded[accountID, default: .zero] += deposit.principal
            }
        }
        for holding in holdings {
            if let accountID = holding.sourceAccountID {
                funded[accountID, default: .zero] += holding.costBasis
            }
        }

        var result: [UUID: Decimal] = [:]
        result.reserveCapacity(accounts.count)
        for account in accounts {
            let id = account.id
            result[id] =
                account.openingBalance
                + (transactionFlow[id] ?? .zero)
                + (transferFlow[id] ?? .zero)
                + (debtFlow[id] ?? .zero)
                + (saleFlow[id] ?? .zero)
                + (withdrawalFlow[id] ?? .zero)
                - (funded[id] ?? .zero)
        }
        return result
    }

    /// Transfers cancel out here: one account's outflow is another's inflow, so
    /// moving money between two of the owner's accounts leaves this total alone.
    ///
    /// Debt flow does not cancel out, because the counterparty lives outside the
    /// app: borrowing genuinely adds cash the owner did not have. That is why
    /// `AssetSummary.netWorth` subtracts what is still owed rather than stopping
    /// at this figure.
    static func totalAvailable(
        of accounts: [CashAccount],
        deposits: [SavingsDeposit],
        holdings: [FundHolding],
        withdrawals: [SavingsWithdrawal],
        transactions: [MoneyTransaction],
        transfers: [AccountTransfer],
        debts: [Debt],
        payments: [DebtPayment],
        sales: [FundSale]
    ) -> Decimal {
        accounts.reduce(Decimal.zero) { total, account in
            total
                + available(
                    for: account,
                    deposits: deposits,
                    holdings: holdings,
                    withdrawals: withdrawals,
                    transactions: transactions,
                    transfers: transfers,
                    debts: debts,
                    payments: payments,
                    sales: sales
                )
        }
    }

    /// The same ledger total scoped to one account kind. Wealth uses this to
    /// present Normal money separately from Credit balances without changing
    /// how either balance is derived.
    static func totalAvailable(
        of accounts: [CashAccount],
        matching kind: CashAccountKind,
        deposits: [SavingsDeposit],
        holdings: [FundHolding],
        withdrawals: [SavingsWithdrawal],
        transactions: [MoneyTransaction],
        transfers: [AccountTransfer],
        debts: [Debt],
        payments: [DebtPayment],
        sales: [FundSale]
    ) -> Decimal {
        totalAvailable(
            of: accounts.filter { $0.kind == kind },
            deposits: deposits,
            holdings: holdings,
            withdrawals: withdrawals,
            transactions: transactions,
            transfers: transfers,
            debts: debts,
            payments: payments,
            sales: sales
        )
    }
}
