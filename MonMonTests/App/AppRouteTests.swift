import AppIntents
import Foundation
import Testing

@testable import MonMon

@MainActor
@Suite("App route coordination")
struct AppRouteTests {
    @Test("Bank capture install opens the published production shortcut without running it")
    func bankShortcutInstallDestination() throws {
        let url = try #require(BankNotificationShortcut.installURL)
        #expect(url.scheme == "https")
        #expect(url.host == "www.icloud.com")
        #expect(url.path == "/shortcuts/31c50fdb6a794b2a999a97dff6f7a1e8")
        #expect(url.query == nil)
    }

    @Test("Apple Pay capture install opens the published shortcut without running it")
    func applePayShortcutInstallDestination() throws {
        let url = try #require(ApplePayCaptureShortcut.installURL)
        #expect(url.scheme == "https")
        #expect(url.host == "www.icloud.com")
        #expect(url.path == "/shortcuts/2e5d68434e3a4cfba96d94b0a9dac317")
        #expect(url.query == nil)
    }

    @Test("Voice capture install opens the published shortcut without running it")
    func voiceCaptureShortcutInstallDestination() throws {
        let url = try #require(QuickNoteCaptureShortcut.installURL)
        #expect(url.scheme == "https")
        #expect(url.host == "www.icloud.com")
        #expect(url.path == "/shortcuts/4da1dc6737a24e649447aa2e1e029e35")
        #expect(url.query == nil)
    }

    @Test("Quick Capture Shortcut shows note, bank and Apple Pay sections in order")
    func quickCaptureShortcutSections() {
        #expect(QuickCaptureShortcut.allCases == [.quickNote, .bankNotification, .applePay])
        #expect(Set(QuickCaptureShortcut.allCases.map(\.id)).count == 3)
    }

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
}
