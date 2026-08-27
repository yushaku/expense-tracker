import SwiftUI
import Testing

@testable import MonMon

@Suite("App sheet presentation")
struct AppSheetPresentationTests {
    @Test("Every app sheet prioritizes dismissal over scrolling its content")
    func everySheetPrioritizesDismissal() {
        #expect(AppSheetPresentation.contentInteraction == .resizes)
    }
}
