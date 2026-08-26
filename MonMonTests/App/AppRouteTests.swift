import AppIntents
import Foundation
import Testing

@testable import MonMon

@MainActor
@Suite("App route coordination")
struct AppRouteTests {
    @Test("Quick capture intent launches MonMon in the foreground")
    func quickCaptureIntentLaunchesInForeground() {
        #expect(OpenQuickCaptureIntent.openAppWhenRun)

        if #available(iOS 26.0, macOS 26.0, *) {
            #expect(OpenQuickCaptureIntent.supportedModes == .foreground)
        }
    }

    @Test("Quick capture intent waits behind the app lock")
    func quickCaptureIntentWaitsForUnlock() async {
        let route = AppRoute()
        let appLock = AppLock(isLocked: true)
        let dependency = QuickCaptureIntentDependency(appRoute: route, appLock: appLock)

        await dependency.request()

        #expect(route.quickCaptureRequestID == nil)

        route.releaseQueuedQuickCapture(isLocked: false)

        #expect(route.quickCaptureRequestID != nil)
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
}
