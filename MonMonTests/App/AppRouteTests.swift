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

    @Test("Voice capture intent launches MonMon in the foreground")
    func voiceCaptureIntentLaunchesInForeground() {
        #expect(OpenVoiceCaptureIntent.openAppWhenRun)

        if #available(iOS 26.0, macOS 26.0, *) {
            #expect(OpenVoiceCaptureIntent.supportedModes == .foreground)
        }
    }

    @Test("Voice capture intent preserves voice mode through the route")
    func voiceCaptureIntentRequestsVoiceMode() async {
        let route = AppRoute()
        let appLock = AppLock(isLocked: false)
        let dependency = QuickCaptureIntentDependency(appRoute: route, appLock: appLock)

        await dependency.request(mode: .voice)

        #expect(route.quickCaptureRequest?.mode == .voice)
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

    @Test("Locked voice capture keeps its mode until the app unlocks")
    func lockedVoiceCaptureKeepsItsMode() async {
        let route = AppRoute()
        let appLock = AppLock(isLocked: true)
        let dependency = QuickCaptureIntentDependency(appRoute: route, appLock: appLock)

        await dependency.request(mode: .voice)

        #expect(route.quickCaptureRequest == nil)

        route.releaseQueuedQuickCapture(isLocked: false)

        #expect(route.quickCaptureRequest?.mode == .voice)
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

@Suite("Voice transcript buffer")
struct VoiceTranscriptBufferTests {
    @Test("A newer volatile result replaces the earlier guess")
    func volatileResultIsReplaced() {
        var buffer = VoiceTranscriptBuffer()

        buffer.receive("cafe", isFinal: false)
        buffer.receive("cafe năm mươi nghìn", isFinal: false)

        #expect(buffer.text == "cafe năm mươi nghìn")
    }

    @Test("Finalized text is preserved while the next phrase is still changing")
    func finalizedTextPrecedesTheNextGuess() {
        var buffer = VoiceTranscriptBuffer()

        buffer.receive("cafe 50k", isFinal: true)
        buffer.receive("tiền", isFinal: false)
        buffer.receive("tiền mặt", isFinal: false)

        #expect(buffer.text == "cafe 50k tiền mặt")
    }

    @Test("Blank speech results never create extra whitespace")
    func blankResultsAreIgnored() {
        var buffer = VoiceTranscriptBuffer()

        buffer.receive("  cafe 50k  ", isFinal: true)
        buffer.receive("   ", isFinal: false)

        #expect(buffer.text == "cafe 50k")
    }
}
