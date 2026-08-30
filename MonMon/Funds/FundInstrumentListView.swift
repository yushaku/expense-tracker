import SwiftData
import SwiftUI

struct FundInstrumentImportOption: Identifiable {
    let source: FundQuoteSource

    var id: String { source.rawValue }

    var sheetTitle: LocalizedStringKey {
        switch source {
        case .fmarket:
            "Add from Fmarket"
        case .vndirect:
            "Add from VNDIRECT"
        case .vangToday:
            "Add Gold from vang.today"
        case .manual:
            "Add instrument"
        }
    }
}

enum FundInstrumentListScope: String, Identifiable {
    case all
    case funds
    case gold

    var id: String { rawValue }

    var kinds: [FundInstrumentKind] {
        switch self {
        case .all:
            FundInstrumentKind.allCases
        case .funds:
            [.fund, .etf]
        case .gold:
            [.gold]
        }
    }

    var defaultKind: FundInstrumentKind { kinds[0] }

    var importOptions: [FundInstrumentImportOption] {
        switch self {
        case .all:
            [.init(source: .fmarket), .init(source: .vndirect), .init(source: .vangToday)]
        case .funds:
            [.init(source: .fmarket), .init(source: .vndirect)]
        case .gold:
            [.init(source: .vangToday)]
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .all:
            "Instruments"
        case .funds:
            "Fund instruments"
        case .gold:
            "Gold instruments"
        }
    }

    var emptyDescription: LocalizedStringKey {
        switch self {
        case .all, .funds:
            "Import open-ended funds from Fmarket or listed ETFs from VNDIRECT, or add one by hand."
        case .gold:
            "Add from vang.today to import gold products with shop prices, or add one by hand."
        }
    }

    @MainActor
    func makeImporter(source: FundQuoteSource) -> FundCatalogueImport {
        switch source {
        case .fmarket:
            FundCatalogueImport(provider: FmarketQuoteProvider())
        case .vndirect:
            FundCatalogueImport(provider: VNDirectQuoteProvider())
        case .vangToday:
            FundCatalogueImport(provider: VangTodayQuoteProvider())
        case .manual:
            FundCatalogueImport()
        }
    }
}

/// The fund catalogue: one row per tradable thing, with the price every
/// position in it is valued from.
///
/// Reached from the Investments toolbar as a sheet, mirroring how Spending
/// reaches Categories — a list of the records other records point at, kept off
/// the main screen because it is edited rarely.
struct FundInstrumentListView: View {
    @Environment(\.locale) private var locale

    @Environment(\.dismiss) private var dismiss

    @Query(sort: \FundInstrument.symbol, order: .forward)
    private var instruments: [FundInstrument]

    @Query(sort: \FundSale.soldAt, order: .reverse)
    private var sales: [FundSale]

    @Query(sort: \FundHolding.createdAt, order: .forward)
    private var holdings: [FundHolding]

    @Environment(\.modelContext) private var modelContext

    @State private var editorMode: FundInstrumentEditorMode?
    @State private var refresher = FundPriceRefresher()
    @State private var importSource: FundQuoteSource?
    @State private var fmarketPage: WebPage?

    let scope: FundInstrumentListScope

    /// Passed in rather than read from the clock so a preview and a test both
    /// get a stable answer for whether a price is stale.
    var asOf: Date

    init(scope: FundInstrumentListScope = .all, asOf: Date = .now) {
        self.scope = scope
        self.asOf = asOf
    }

    var body: some View {
        #if os(macOS)
            list.frame(minWidth: 460, minHeight: 600)
        #else
            list
        #endif
    }

    private var list: some View {
        NavigationStack {
            ZStack {
                MonMonTheme.canvas
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                        actionBar

                        if filteredInstruments.isEmpty {
                            emptyState
                        } else {
                            ForEach(filteredInstruments) { instrument in
                                row(instrument)
                            }
                        }
                    }
                    .frame(maxWidth: MonMonTheme.maxContentWidth)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(scope.title)
            .accessibilityIdentifier("instrument-list")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .appSheet(item: $editorMode) { mode in
                FundInstrumentEditorView(mode: mode, kinds: scope.kinds)
            }
            .appSheet(item: $importSource) { source in
                let option = FundInstrumentImportOption(source: source)
                FundCatalogueImportView(
                    title: option.sheetTitle,
                    importer: scope.makeImporter(source: source)
                )
            }
            .webPage($fmarketPage)
        }
        .tint(MonMonTheme.accent)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nothing in the catalogue yet")
                .font(.headline)

            Text(scope.emptyDescription)
                .font(.subheadline)
                .foregroundStyle(MonMonTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .fill(MonMonTheme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
    }

    /// The card is two tap targets rather than one: everything but the last line
    /// opens the editor, and the link on that line opens Fmarket. A button
    /// nested inside another button's label would never see the tap.
    private func row(_ instrument: FundInstrument) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                editorMode = .edit(instrument)
            } label: {
                editableContent(instrument)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("instrument-\(instrument.id.uuidString)")
            .accessibilityHint("Opens this instrument for editing")

            statusLine(instrument)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .fill(MonMonTheme.surface)
        }
        .overlay {
            RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
    }

    private func editableContent(_ instrument: FundInstrument) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                FundLogoView(symbol: instrument.symbol, logoURL: instrument.logoURL, size: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text(instrument.symbol)
                        .font(.headline)
                        .monospaced()

                    Text("\(instrument.name) · \(instrument.kind.displayName(in: locale))")
                        .font(.subheadline)
                        .foregroundStyle(MonMonTheme.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(VNDCurrency.formatUnitPrice(instrument.currentPricePerUnit))
                        .font(.headline)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text("PER UNIT")
                        .font(.caption2.weight(.semibold))
                        .tracking(0.5)
                        .foregroundStyle(MonMonTheme.textSecondary)
                }
            }

            if let outcome = refresher.outcomes[instrument.id],
                let message = outcome.message(in: locale)
            {
                Label(
                    message,
                    systemImage: outcome.isFailure ? "xmark.circle.fill" : "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(outcome.isFailure ? MonMonTheme.danger : MonMonTheme.gain)
                .accessibilityIdentifier("quote-error")
            } else if refresher.isRunning {
                Label("Fetching…", systemImage: "arrow.clockwise")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }

        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    private func statusLine(_ instrument: FundInstrument) -> some View {
        HStack(spacing: 7) {
            Image(systemName: isStale(instrument) ? "exclamationmark.circle.fill" : "clock")
                .font(.caption2.weight(.semibold))
                .accessibilityHidden(true)

            Text(statusDescription(instrument))
                .font(.caption)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(
                    isStale(instrument) ? MonMonTheme.danger : MonMonTheme.textSecondary
                )

            Spacer(minLength: 8)

            if let url = FmarketLink.url(for: instrument) {
                fmarketButton(url: url, symbol: instrument.symbol)
            }
        }
        .foregroundStyle(isStale(instrument) ? MonMonTheme.danger : MonMonTheme.textSecondary)
    }

    /// Opens the fund's own page on Fmarket — its strategy, its holdings, its
    /// chart — which is everything this app deliberately does not store.
    private func fmarketButton(url: URL, symbol: String) -> some View {
        Button {
            fmarketPage = WebPage(url)
        } label: {
            Label("Fmarket", systemImage: "safari")
                .font(.caption.weight(.semibold))
                .foregroundStyle(MonMonTheme.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(MonMonTheme.accent.opacity(0.16), in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open \(symbol) on Fmarket")
        .accessibilityIdentifier("open-fmarket-\(symbol.lowercased())")
    }

    /// Refresh, direct imports, and manual add stay in the content rather than
    /// the toolbar. macOS collapses extra primary toolbar actions into an
    /// overflow, which is how Refresh managed to ship invisible.
    ///
    /// Refresh and manual add use icons so each provider can have its own import
    /// button without wrapping the row. Full wording stays available to
    /// accessibility technologies.
    private var actionBar: some View {
        HStack(spacing: 8) {
            actionButton(
                title: refresher.isRunning ? "Refreshing…" : "Refresh",
                systemImage: "arrow.clockwise",
                accessibilityLabel: "Refresh prices",
                identifier: "refresh-quotes",
                isProminent: true,
                showsTitle: false
            ) {
                refresh()
            }
            .disabled(refresher.isRunning || !canRefresh)

            ForEach(scope.importOptions) { option in
                actionButton(
                    title: option.source.displayName,
                    systemImage: "square.and.arrow.down",
                    accessibilityLabel: option.sheetTitle,
                    identifier: "import-from-\(option.source.rawValue)"
                ) {
                    importSource = option.source
                }
            }

            actionButton(
                title: "Add",
                systemImage: "plus",
                accessibilityLabel: "Add by hand",
                identifier: "add-instrument",
                showsTitle: false
            ) {
                editorMode = .add
            }
        }
    }

    private func actionButton(
        title: LocalizedStringKey,
        systemImage: String,
        accessibilityLabel: LocalizedStringKey,
        identifier: String,
        isProminent: Bool = false,
        showsTitle: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if showsTitle {
                    Label(title, systemImage: systemImage)
                } else {
                    Image(systemName: systemImage)
                }
            }
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .frame(maxWidth: .infinity)
            .background {
                if isProminent {
                    Capsule().fill(MonMonTheme.accent.opacity(0.16))
                } else {
                    Capsule()
                        .fill(MonMonTheme.surface)
                        .overlay(Capsule().stroke(MonMonTheme.border, lineWidth: 1))
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isProminent ? MonMonTheme.accent : MonMonTheme.textPrimary)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityIdentifier(identifier)
    }

    /// Refresh is offered only when a request could actually achieve something:
    /// a held instrument, with automatic quotes left on.
    private var canRefresh: Bool {
        refresher.hasAnythingToRefresh(
            instruments: filteredInstruments,
            holdings: holdings,
            sales: sales
        )
    }

    /// Owner-triggered. The Investments screen fetches on opening too, when
    /// what it shows is out of date; this button asks regardless.
    private func refresh() {
        Task {
            await refresher.refresh(
                instruments: filteredInstruments,
                holdings: holdings,
                sales: sales,
                in: modelContext
            )
        }
    }

    private var filteredInstruments: [FundInstrument] {
        instruments.filter { scope.kinds.contains($0.kind) }
    }

    private func isStale(_ instrument: FundInstrument) -> Bool {
        guard instrument.autoQuoteEnabled else {
            return false
        }
        return TradingCalendar.isStale(
            priceAsOf: instrument.priceAsOf,
            kind: instrument.kind,
            asOf: asOf
        )
    }

    /// States the price's age, its source, and how many positions depend on it,
    /// so the row explains both what it is and why it matters.
    private func statusDescription(_ instrument: FundInstrument) -> String {
        let day = TransactionPeriod.day(instrument.priceAsOf, in: locale)
        let held = FundSummary.holdings(for: instrument, holdings: holdings).count
        let position = AppText.string("\(held) positions", in: locale)
        var text =
            "\(instrument.priceLabel(in: locale)) \(day) · "
            + "\(instrument.source.displayName(in: locale)) · \(position)"

        if isStale(instrument) {
            text += " · Stale"
        } else if !instrument.autoQuoteEnabled {
            text += " · Manual only"
        }

        return text
    }
}
