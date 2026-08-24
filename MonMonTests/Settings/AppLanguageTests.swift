import Foundation
import Testing

@testable import MonMon

@Suite("App language")
struct AppLanguageTests {
    @Test("Following the device means following it as it changes")
    func systemAutoupdates() {
        #expect(AppLanguage.system.locale == .autoupdatingCurrent)
        #expect(AppLanguage.system.localeIdentifier == nil)
    }

    @Test("A picked language resolves to that language's locale")
    func pickedLanguageResolves() {
        #expect(AppLanguage.english.locale.identifier == "en")
        #expect(AppLanguage.vietnamese.locale.identifier == "vi")
    }

    @Test("A stored value that names no language leaves the choice with the device")
    func unknownStoredValueFallsBack() {
        #expect(AppLanguage(rawValue: "klingon") == nil)
        #expect(AppLanguage(rawValue: "vietnamese") == .vietnamese)
    }

    /// Text built outside a view has no environment to resolve against, so it
    /// goes through `AppText`, which asks the language's own catalogue. Passing
    /// a locale to `String(localized:)` alone would not switch language: that
    /// argument formats what is interpolated, it does not choose the catalogue.
    @Test("Text built outside a view answers in the language it is asked for")
    func catalogueAnswersPerLocale() {
        #expect(AppText.string("Spending", in: Locale(identifier: "vi")) == "Chi tiêu")
        #expect(AppText.string("Spending", in: Locale(identifier: "en")) == "Spending")
        #expect(AppText.string("Settings", in: Locale(identifier: "vi")) == "Cài đặt")
    }
}
