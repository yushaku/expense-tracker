import Foundation
import SwiftUI
import Testing

@testable import MonMon

/// The whole language switch rests on SwiftUI resolving a localized key against
/// the locale in the environment rather than the device's own. Rendering is the
/// only way to ask, since the resolved text is not readable from `Text` itself:
/// a key rendered under one language must draw the same pixels as that
/// language's text, and different ones from the other language's.
@Suite("Language resolution")
@MainActor
struct LanguageResolutionTests {
    private func render(_ view: some View) -> Data? {
        let renderer = ImageRenderer(content: view.frame(width: 300, height: 40))
        renderer.scale = 1

        #if os(macOS)
            guard let image = renderer.nsImage,
                let tiff = image.tiffRepresentation
            else {
                return nil
            }

            return tiff
        #else
            return nil
        #endif
    }

    @Test("An interface written from a key follows the language in the environment")
    func textFollowsEnvironmentLocale() {
        let asked = render(Text("Spending").environment(\.locale, Locale(identifier: "vi")))
        let english = render(Text(verbatim: "Spending"))
        let vietnamese = render(Text(verbatim: "Chi tiêu"))

        #expect(asked != nil)
        #expect(asked == vietnamese)
        #expect(asked != english)
    }
}
