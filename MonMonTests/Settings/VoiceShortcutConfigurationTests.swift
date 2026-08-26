import Foundation
import Testing

@testable import MonMon

@Suite("Voice shortcut configuration")
struct VoiceShortcutConfigurationTests {
    @Test("An empty shortcut ID keeps installation disabled")
    func emptyShortcutIDIsUnavailable() {
        #expect(VoiceShortcutConfiguration.installationURL(shortcutID: nil) == nil)
        #expect(VoiceShortcutConfiguration.installationURL(shortcutID: "  ") == nil)
    }

    @Test("A published shortcut ID creates its iCloud installation URL")
    func publishedShortcutIDCreatesURL() {
        let url = VoiceShortcutConfiguration.installationURL(shortcutID: "abc123")

        #expect(url?.absoluteString == "https://www.icloud.com/shortcuts/abc123")
    }
}
