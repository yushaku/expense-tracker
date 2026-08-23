import SwiftUI

struct DebtCard: View {
    let debt: Debt
    let outstanding: Decimal
    let paid: Decimal
    let progress: Decimal
    let accountName: String?
    let isOverdue: Bool
    let projectedInterest: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if debt.principal > 0 {
                repayment
            }

            Divider()
                .overlay(MonMonTheme.border)

            terms
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(MonMonTheme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
        .opacity(isSettled ? 0.72 : 1)
        .accessibilityElement(children: .combine)
    }

    private var isSettled: Bool { outstanding <= 0 }

    private var tint: Color { debt.direction.tint }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: debt.direction.symbolName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 44)
                .background(tint.opacity(0.16), in: RoundedRectangle(cornerRadius: 13))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(debt.counterparty)
                    .font(.headline)
                    .lineLimit(2)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)

                chip
            }

            Spacer(minLength: 12)

            // What is still owed leads, because the principal is history.
            VStack(alignment: .trailing, spacing: 3) {
                Text(VNDCurrency.format(outstanding))
                    .font(.headline)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Text("OUTSTANDING")
                    .font(.caption2.weight(.semibold))
                    .tracking(0.5)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    /// The bar is decorative and the sentence beneath carries it, the way the
    /// doughnuts hand their meaning to a legend.
    private var repayment: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(MonMonTheme.field)

                    Capsule()
                        .fill(tint)
                        .frame(width: proxy.size.width * progressFraction)
                }
            }
            .frame(height: 6)
            .accessibilityHidden(true)

            Text(repaymentDescription)
                .font(.caption)
                .foregroundStyle(MonMonTheme.textSecondary)
        }
    }

    private var terms: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                termColumns
            }

            VStack(alignment: .leading, spacing: 12) {
                termColumns
            }
        }
    }

    @ViewBuilder
    private var termColumns: some View {
        detail(title: "ORIGINAL", value: VNDCurrency.format(debt.principal))
        detail(title: "DUE", value: dueDescription)

        // An interest-free loan is the common case, so the two columns that
        // would only ever read nought are left out entirely.
        if debt.annualInterestRate > 0 {
            detail(
                title: "RATE",
                value: PercentInput.formatWithSymbol(debt.annualInterestRate)
            )
            detail(title: "EST. INTEREST", value: VNDCurrency.format(projectedInterest))
        }
    }

    private func detail(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(MonMonTheme.textSecondary)

            Text(value)
                .font(.subheadline.weight(.medium))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Neither state is signalled by colour alone: each carries an icon and a
    /// word.
    @ViewBuilder
    private var chip: some View {
        if isSettled {
            chipLabel("Settled", systemImage: "checkmark.circle.fill", tint: MonMonTheme.gain)
        } else if isOverdue {
            chipLabel(
                "Overdue",
                systemImage: "exclamationmark.circle.fill",
                tint: MonMonTheme.danger
            )
        }
    }

    private func chipLabel(_ title: String, systemImage: String, tint: Color) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption2.weight(.bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.16), in: Capsule())
            .padding(.top, 2)
    }

    private var subtitle: String {
        let preposition = debt.direction.counterpartyPreposition

        guard let accountName else {
            return "\(debt.direction.displayName) \(preposition) them, no account"
        }

        return switch debt.direction {
        case .borrowed:
            "Borrowed into \(accountName)"
        case .lent:
            "Lent from \(accountName)"
        }
    }

    private var repaymentDescription: String {
        let verb = debt.direction == .borrowed ? "repaid" : "returned"
        return "\(VNDCurrency.format(paid)) of \(VNDCurrency.format(debt.principal)) \(verb)"
    }

    private var dueDescription: String {
        guard let dueDate = debt.dueDate else {
            return "No due date"
        }

        return dueDate.formatted(date: .abbreviated, time: .omitted)
    }

    private var progressFraction: CGFloat {
        CGFloat(NSDecimalNumber(decimal: progress).doubleValue)
    }
}

extension DebtDirection {
    /// Money borrowed reuses the colour a credit card already wears: a credit
    /// card *is* borrowed money, and painting the two differently would be the
    /// app disagreeing with itself. Red is reserved for overdue, so a healthy
    /// loan never reads as an error.
    var tint: Color {
        switch self {
        case .borrowed:
            MonMonTheme.credit
        case .lent:
            MonMonTheme.lent
        }
    }
}

#if DEBUG
    #Preview("Debt cards") {
        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    DebtCard(
                        debt: .preview(
                            counterparty: "Anh Minh",
                            direction: .borrowed,
                            principal: 30_000_000
                        ),
                        outstanding: 18_000_000,
                        paid: 12_000_000,
                        progress: Decimal(string: "0.4") ?? 0,
                        accountName: "Wallet",
                        isOverdue: false,
                        projectedInterest: 0
                    )

                    DebtCard(
                        debt: .preview(
                            counterparty: "Techcombank",
                            direction: .borrowed,
                            principal: 250_000_000,
                            annualInterestRate: Decimal(string: "8.5") ?? 0,
                            dueDate: Date(timeIntervalSince1970: 1_600_000_000)
                        ),
                        outstanding: 250_000_000,
                        paid: 0,
                        progress: 0,
                        accountName: "Techcombank",
                        isOverdue: true,
                        projectedInterest: 21_250_000
                    )

                    DebtCard(
                        debt: .preview(
                            counterparty: "Chị Lan",
                            direction: .lent,
                            principal: 5_000_000
                        ),
                        outstanding: 0,
                        paid: 5_000_000,
                        progress: 1,
                        accountName: "Techcombank",
                        isOverdue: false,
                        projectedInterest: 0
                    )
                }
                .padding(20)
            }
        }
        .foregroundStyle(MonMonTheme.textPrimary)
        .preferredColorScheme(MonMonTheme.colorScheme)
    }
#endif
