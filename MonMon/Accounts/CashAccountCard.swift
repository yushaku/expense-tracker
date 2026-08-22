import SwiftUI

struct CashAccountCard: View {
    let account: CashAccount

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                identity
                Spacer(minLength: 12)
                balance(alignment: .trailing)
            }

            VStack(alignment: .leading, spacing: 16) {
                identity
                balance(alignment: .leading)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(MonMonTheme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var identity: some View {
        HStack(spacing: 14) {
            Image(systemName: account.kind.iconName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(account.kind.tint)
                .frame(width: 44, height: 44)
                .background(account.kind.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 13))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(account.name)
                    .font(.headline)
                    .lineLimit(2)

                Text(account.kind.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func balance(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 3) {
            Text(VNDCurrency.format(account.openingBalance))
                .font(.headline)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text("CURRENT BALANCE")
                .font(.caption2.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
        }
    }
}

private extension CashAccountKind {
    var iconName: String {
        switch self {
        case .cash:
            "banknote.fill"
        case .bank:
            "building.columns.fill"
        }
    }

    var tint: Color {
        switch self {
        case .cash:
            MonMonTheme.accent
        case .bank:
            MonMonTheme.bank
        }
    }
}
