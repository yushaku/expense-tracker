import AppIntents
import SwiftUI
import WidgetKit

/// Quick capture in Control Center, on the Lock Screen, and on the Action
/// button. A control has no keyboard, so this one only opens Add Transaction
/// rather than recording anything itself; the widget's preset buttons are
/// what record without opening the app.
///
/// `OpenQuickCaptureIntent` is what opens the app and why it has to be an
/// intent rather than a URL handed straight to the button.
struct QuickCaptureControl: ControlWidget {
    static let kind = "QuickCaptureControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: OpenQuickCaptureIntent()) {
                Label("Quick Capture", systemImage: "square.and.pencil")
            }
        }
        .displayName("Quick Capture")
        .description("Open MonMon and start a new transaction.")
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
