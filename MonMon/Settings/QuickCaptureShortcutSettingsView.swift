import SwiftUI

enum QuickCaptureShortcut: String, CaseIterable, Identifiable {
    case bankNotification, applePay, quickNote

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
                    NavigationLink(value: shortcut) {
                        HStack {
                            Label(shortcut.title, systemImage: shortcut.symbol)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .accessibilityHidden(true)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .settingsButtonLabelStyle()
                    .appCard()
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
        .navigationDestination(for: QuickCaptureShortcut.self) { shortcut in
            switch shortcut {
            case .bankNotification: BankNotificationSettingsView()
            case .applePay: ApplePayCaptureSettingsView()
            case .quickNote: QuickNoteCaptureSettingsView()
            }
        }
    }
}
