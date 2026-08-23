import SwiftData
import SwiftUI

/// The fund catalogue: one row per tradable thing, with the price every
/// position in it is valued from.
///
/// Reached from the Investments toolbar as a sheet, mirroring how Spending
/// reaches Categories — a list of the records other records point at, kept off
/// the main screen because it is edited rarely.
struct FundInstrumentListView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \FundInstrument.symbol, order: .forward)
    private var instruments: [FundInstrument]

    @Query(sort: \FundHolding.createdAt, order: .forward)
    private var holdings: [FundHolding]

    @Environment(\.modelContext) private var modelContext

    @State private var editorMode: FundInstrumentEditorMode?
    @State private var refresher = FundPriceRefresher()
    @State private var isImporting = false

    /// Passed in rather than read from the clock so a preview and a test both
    /// get a stable answer for whether a price is stale.
    var asOf: Date = .now

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

                        if instruments.isEmpty {
                            emptyState
                        } else {
                            ForEach(instruments) { instrument in
                                Button {
                                    editorMode = .edit(instrument)
                                } label: {
                                    row(instrument)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier(
                                    "instrument-\(instrument.id.uuidString)"
                                )
                                .accessibilityHint("Opens this instrument for editing")
                            }
                        }
                    }
                    .frame(maxWidth: MonMonTheme.maxContentWidth)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Instruments")
            .accessibilityIdentifier("instrument-list")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $editorMode) { mode in
                FundInstrumentEditorView(mode: mode)
            }
            .sheet(isPresented: $isImporting) {
                FundCatalogueImportView()
            }
        }
        .tint(MonMonTheme.accent)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nothing in the catalogue yet")
                .font(.headline)

            Text(
                "Add from Fmarket to pull every open-ended fund it lists, with its NAV, "
                    + "or add one by hand. Then record how many units you hold."
            )
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

    private func row(_ instrument: FundInstrument) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(instrument.symbol)
                        .font(.headline)
                        .monospaced()

                    Text("\(instrument.name) · \(instrument.kind.displayName)")
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

            if let outcome = refresher.outcomes[instrument.id], let message = outcome.message {
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

            HStack(spacing: 7) {
                Image(systemName: isStale(instrument) ? "exclamationmark.circle.fill" : "clock")
                    .font(.caption2.weight(.semibold))
                    .accessibilityHidden(true)

                Text(statusDescription(instrument))
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Spacer(minLength: 8)
            }
            .foregroundStyle(isStale(instrument) ? MonMonTheme.danger : MonMonTheme.textSecondary)
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
        .accessibilityElement(children: .combine)
    }

    /// Refresh and the two ways of adding a fund, in the content rather than the
    /// toolbar. macOS collapses a toolbar's extra primary actions into an
    /// overflow, which is how Refresh managed to ship invisible.
    private var actionBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) { actionButtons }
            VStack(alignment: .leading, spacing: 10) { actionButtons }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button {
            refresh()
        } label: {
            Label(
                refresher.isRunning ? "Refreshing…" : "Refresh prices",
                systemImage: "arrow.clockwise"
            )
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(MonMonTheme.accent.opacity(0.16), in: Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(MonMonTheme.accent)
        .disabled(refresher.isRunning || !canRefresh)
        .accessibilityIdentifier("refresh-quotes")

        Button {
            isImporting = true
        } label: {
            Label("Add from Fmarket", systemImage: "square.and.arrow.down")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(MonMonTheme.surface, in: Capsule())
                .overlay(Capsule().stroke(MonMonTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .foregroundStyle(MonMonTheme.textPrimary)
        .accessibilityIdentifier("import-from-fmarket")

        Button {
            editorMode = .add
        } label: {
            Label("Add by hand", systemImage: "plus")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(MonMonTheme.surface, in: Capsule())
                .overlay(Capsule().stroke(MonMonTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .foregroundStyle(MonMonTheme.textPrimary)
        .accessibilityIdentifier("add-instrument")
    }

    /// Refresh is offered only when a request could actually achieve something:
    /// a held instrument, with automatic quotes left on.
    private var canRefresh: Bool {
        refresher.hasAnythingToRefresh(instruments: instruments, holdings: holdings)
    }

    /// Owner-triggered, and the only thing in the app that opens a connection.
    private func refresh() {
        Task {
            await refresher.refresh(
                instruments: instruments,
                holdings: holdings,
                in: modelContext
            )
        }
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
        let day = instrument.priceAsOf.formatted(date: .abbreviated, time: .omitted)
        let held = FundSummary.holdings(for: instrument, holdings: holdings).count
        let position = held == 1 ? "1 position" : "\(held) positions"
        var text =
            "\(instrument.priceLabel) \(day) · \(instrument.source.displayName) · \(position)"

        if isStale(instrument) {
            text += " · Stale"
        } else if !instrument.autoQuoteEnabled {
            text += " · Manual only"
        }

        return text
    }
}
