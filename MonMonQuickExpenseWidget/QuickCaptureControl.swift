import AppIntents
import SwiftUI
import WidgetKit

/// Quick capture in Control Center, on the Lock Screen, and on the Action
/// button. A control has no keyboard, so this one only opens Add Transaction
/// rather than recording anything itself; the widget's preset buttons are
/// what record without opening the app.
///
/// It opens the same URL `AppRoute` already routes, so the control holds no
/// routing of its own: whatever the app does with a quick-capture URL, the
/// control does.
struct QuickCaptureControl: ControlWidget {
    static let kind = "QuickCaptureControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenURLIntent(Self.url)) {
                Label("Quick Capture", systemImage: "square.and.pencil")
            }
        }
        .displayName("Quick Capture")
        .description("Open MonMon and start a new transaction.")
    }

    /// A missing scheme is a build that forgot the Info.plist key, not a state
    /// the owner can be in: the same xcconfig sets the scheme the app registers.
    private static var url: URL {
        guard let url = AppRoute.quickCaptureURL(in: Bundle.main.infoDictionary ?? [:]) else {
            preconditionFailure("MonMonQuickCaptureURLScheme missing from the widget Info.plist")
        }
        return url
    }
}

@main
struct MonMonWidgets: WidgetBundle {
    var body: some Widget {
        MonMonQuickExpenseWidget()
        QuickCaptureControl()
        SavingsGoalWidget()
    }
}
