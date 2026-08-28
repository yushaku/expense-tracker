import SwiftUI

/// The badge an instrument is recognised by: its manager's logo when the
/// catalogue carried one, and the first two letters of the ticker when it did
/// not.
///
/// The image is fetched at render rather than stored, so a logo the provider
/// replaces is simply the next one shown. Nothing depends on it arriving: every
/// failure — no URL, no connection, a reply that is not an image — lands on the
/// monogram, which is what this badge showed before logos existed.
struct FundLogoView: View {
    let symbol: String
    /// As stored on `FundInstrument`, or as the catalogue offered it. `nil`
    /// for anything added by hand.
    let logoURL: String?
    var size: CGFloat = 44

    var body: some View {
        content
            .frame(width: size, height: size)
            .background(
                MonMonTheme.funds.opacity(0.16),
                in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
            )
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        if let url = logoURL.flatMap(URL.init(string:)) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFit()
                        .padding(size * 0.14)
                } else {
                    // Both the wait and the failure show the monogram. A
                    // spinner in a 44pt badge reads as something being wrong,
                    // and the letters are the answer either way.
                    monogram
                }
            }
        } else {
            monogram
        }
    }

    private var monogram: some View {
        Text(displaySymbol.prefix(2))
            .font(.system(size: size * 0.34, weight: .bold, design: .rounded))
            .foregroundStyle(MonMonTheme.funds)
    }

    private var displaySymbol: String {
        let trimmed = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "??" : trimmed
    }
}

#Preview {
    HStack(spacing: 14) {
        FundLogoView(symbol: "VESAF", logoURL: nil)
        FundLogoView(symbol: "", logoURL: nil)
        FundLogoView(symbol: "VEOF", logoURL: nil, size: 32)
    }
    .padding()
    .background(MonMonTheme.canvas)
}
