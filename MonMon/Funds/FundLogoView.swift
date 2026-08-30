import SwiftUI

/// The badge an instrument is recognised by: its bundled manager logo when the
/// local catalogue knows the ticker, its provider logo otherwise, and finally
/// the first two letters of the ticker.
///
/// Bundled artwork lets ETFs and open-ended funds managed by the same company
/// share one stable identity without changing persisted models. Nothing depends
/// on a remote image arriving: every failure lands on the monogram.
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
            // The image fills the badge and is cut to its corners, so a logo
            // sits in the same square the monogram does rather than floating
            // inside it. Clipping is on the badge rather than the image so the
            // tinted plate behind a monogram keeps the same shape.
            .clipShape(RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        if let assetName = FundLogoCatalogue.assetName(for: symbol) {
            ZStack {
                Color.white
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.08)
            }
        } else if let url = logoURL.flatMap(URL.init(string:)) {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    // Filled, not fitted: these are square-ish company marks on
                    // their own white ground, and fitting them left a border of
                    // fund mauve around a white tile.
                    image
                        .resizable()
                        .scaledToFill()
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
        FundLogoView(symbol: "FUEVFVND", logoURL: nil)
        FundLogoView(symbol: "VESAF", logoURL: nil)
        FundLogoView(symbol: "", logoURL: nil)
        FundLogoView(symbol: "UNKNOWN", logoURL: nil, size: 32)
    }
    .padding()
    .background(MonMonTheme.canvas)
}
