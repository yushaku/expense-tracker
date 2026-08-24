import SwiftUI

#if os(iOS)
    import SafariServices
#endif

/// A page to show the owner. Wraps a `URL` so it can drive a sheet, which needs
/// something identifiable.
struct WebPage: Identifiable {
    let url: URL

    var id: String { url.absoluteString }

    init(_ url: URL) {
        self.url = url
    }
}

extension View {
    /// Shows the page in place: a Safari view inside the app on iPhone, and the
    /// default browser on Mac, which has no in-app equivalent worth the weight
    /// of embedding one.
    ///
    /// Reader mode, cookies and passwords all come from Safari itself, and the
    /// app never sees the page, so nothing here handles credentials or content.
    func webPage(_ page: Binding<WebPage?>) -> some View {
        modifier(WebPageModifier(page: page))
    }
}

private struct WebPageModifier: ViewModifier {
    @Binding var page: WebPage?

    #if os(macOS)
        @Environment(\.openURL) private var openURL
    #endif

    func body(content: Content) -> some View {
        #if os(macOS)
            content.onChange(of: page?.url) { _, url in
                guard let url else {
                    return
                }

                openURL(url)
                page = nil
            }
        #else
            content.sheet(item: $page) { page in
                SafariPage(url: page.url)
                    .ignoresSafeArea()
            }
        #endif
    }
}

#if os(iOS)
    /// `SFSafariViewController` rather than a `WKWebView`: it arrives with the
    /// address bar, the reader, and the share sheet already built, and it runs
    /// the page out of process.
    private struct SafariPage: UIViewControllerRepresentable {
        let url: URL

        func makeUIViewController(context: Context) -> SFSafariViewController {
            let configuration = SFSafariViewController.Configuration()
            configuration.entersReaderIfAvailable = false

            let controller = SFSafariViewController(url: url, configuration: configuration)
            controller.preferredControlTintColor = UIColor(MonMonTheme.accent)
            return controller
        }

        func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
    }
#endif
