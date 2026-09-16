import SwiftUI

enum QuickCaptureShortcut: String, CaseIterable, Identifiable {
    case quickNote, bankNotification, applePay

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .bankNotification: "Bank notifications"
        case .applePay: "Apple Pay capture"
        case .quickNote: "Quick note capture"
        }
    }

    var symbol: String {
        switch self {
        case .bankNotification: "bell.badge"
        case .applePay: "creditcard"
        case .quickNote: "square.and.pencil"
        }
    }
}

struct QuickCaptureShortcutSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                ForEach(QuickCaptureShortcut.allCases) { shortcut in
                    VStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                        Label(shortcut.title, systemImage: shortcut.symbol)
                            .font(.title2.weight(.bold))
                            .accessibilityAddTraits(.isHeader)

                        switch shortcut {
                        case .quickNote: QuickNoteCaptureSettingsContent()
                        case .bankNotification: BankNotificationSettingsContent()
                        case .applePay: ApplePayCaptureSettingsContent()
                        }
                    }
                    .padding(.vertical, 8)
                    .accessibilityIdentifier("quick-capture-shortcut-\(shortcut.id)")
                }
            }
            .frame(maxWidth: MonMonTheme.maxContentWidth)
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background(MonMonTheme.canvas)
        .navigationTitle("Quick Capture Shortcut")
        .foregroundStyle(MonMonTheme.textPrimary)
        .tint(MonMonTheme.accent)
    }
}
