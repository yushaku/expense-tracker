import AppIntents
import Foundation
import Testing

@testable import MonMon

@MainActor
@Suite("App route coordination")
struct AppRouteTests {
    @Test("Record Transaction is the only advertised app shortcut")
    func onlyRecordTransactionShortcutRemains() {
        #expect(MonMonAppShortcuts.appShortcuts.count == 1)
    }

    @Test("Quick capture waits behind the app lock")
    func lockedQuickCaptureWaitsForUnlock() throws {
        let route = AppRoute()
        let url = try #require(URL(string: "monmon-dev://quick-capture"))

        #expect(route.receive(url, isLocked: true))
        #expect(route.quickCaptureRequestID == nil)

        route.releaseQueuedQuickCapture(isLocked: false)

        #expect(route.quickCaptureRequestID != nil)
    }

    @Test("An active request can be consumed exactly once")
    func activeRequestIsConsumed() throws {
        let route = AppRoute()
        let url = try #require(URL(string: "monmon://quick-capture"))

        #expect(route.receive(url, isLocked: false))
        #expect(route.quickCaptureRequestID != nil)

        route.consumeQuickCapture()

        #expect(route.quickCaptureRequestID == nil)
    }

    @Test("Unrelated URLs are ignored")
    func unrelatedURLIsIgnored() throws {
        let route = AppRoute()
        let url = try #require(URL(string: "monmon://something-else"))

        #expect(!route.receive(url, isLocked: false))
        #expect(route.quickCaptureRequestID == nil)
    }

    @Test("The control's URL is the flavour's own scheme, and the app routes it back")
    func quickCaptureURLRoundTrips() throws {
        let url = try #require(
            AppRoute.quickCaptureURL(in: ["MonMonQuickCaptureURLScheme": "monmon-dev"])
        )

        #expect(url.absoluteString == "monmon-dev://quick-capture")
        #expect(AppRoute().receive(url, isLocked: false))
    }

    /// The control shipped once with a bare `OpenURLIntent` as its action. It
    /// compiled, the suite passed, and tapping the control did nothing: an
    /// action that does not ask for the foreground runs in the widget process.
    /// These are the two flags that ask, one per OS range.
    @Test("The control's intent asks for the foreground, or tapping it opens nothing")
    func controlIntentOpensTheApp() {
        #expect(OpenQuickCaptureIntent.openAppWhenRun)

        if #available(iOS 26.0, macOS 26.0, *) {
            #expect(OpenQuickCaptureIntent.supportedModes.contains(.foreground))
        }
    }

    @Test("A target that forgot the Info.plist key gets no URL, never the wrong flavour")
    func quickCaptureURLNeedsTheScheme() {
        #expect(AppRoute.quickCaptureURL(in: [:]) == nil)
        #expect(AppRoute.quickCaptureURL(in: ["MonMonQuickCaptureURLScheme": ""]) == nil)
    }
}
