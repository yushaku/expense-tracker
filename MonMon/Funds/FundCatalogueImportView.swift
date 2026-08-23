import SwiftData
import SwiftUI

/// Picks funds out of Fmarket's list instead of typing them one at a time.
struct FundCatalogueImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \FundInstrument.symbol, order: .forward)
    private var instruments: [FundInstrument]

    @State private var importer = FundCatalogueImport()
    @State private var chosen: Set<String> = []
    @State private var saveErrorMessage: String?

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

                content
            }
            .navigationTitle("Add from Fmarket")
            .accessibilityIdentifier("fmarket-import")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("cancel-import")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add \(chosen.count)", action: addChosen)
                        .disabled(chosen.isEmpty)
                        .accessibilityIdentifier("confirm-import")
                }
            }
        }
        .tint(MonMonTheme.accent)
        .task { await importer.load(existing: instruments) }
    }

    @ViewBuilder
    private var content: some View {
        switch importer.phase {
        case .idle, .loading:
            VStack(spacing: 12) {
                ProgressView()
                Text("Asking Fmarket which funds it lists…")
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
            .accessibilityIdentifier("import-loading")

        case .failed:
            message(
                importer.phase.message ?? "Fmarket could not be reached.",
                systemImage: "xmark.circle.fill",
                tint: MonMonTheme.danger,
                id: "import-error"
            )

        case .loaded where importer.importable.isEmpty:
            message(
                "Every fund Fmarket lists is already in your catalogue.",
                systemImage: "checkmark.circle.fill",
                tint: MonMonTheme.gain,
                id: "import-empty"
            )

        case .loaded:
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    header

                    if let saveErrorMessage {
                        message(
                            saveErrorMessage,
                            systemImage: "xmark.circle.fill",
                            tint: MonMonTheme.danger,
                            id: "save-import-error"
                        )
                    }

                    ForEach(importer.importable) { candidate in
                        row(candidate)
                    }
                }
                .frame(maxWidth: MonMonTheme.maxContentWidth)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(
                "\(importer.importable.count) open-ended funds, each with the NAV Fmarket "
                    + "publishes. Pick the ones you hold — nothing is added until you do."
            )
            .font(.subheadline)
            .foregroundStyle(MonMonTheme.textSecondary)

            HStack(spacing: 12) {
                Button("Select all") {
                    chosen = Set(importer.importable.map(\.symbol))
                }
                .accessibilityIdentifier("select-all-import")

                Button("Clear") { chosen.removeAll() }
                    .disabled(chosen.isEmpty)
                    .accessibilityIdentifier("clear-import")
            }
            .font(.subheadline.weight(.medium))
            .buttonStyle(.plain)
            .foregroundStyle(MonMonTheme.accent)
        }
        .padding(.bottom, 4)
    }

    private func row(_ candidate: FundInstrumentCandidate) -> some View {
        Button {
            toggle(candidate.symbol)
        } label: {
            HStack(spacing: 12) {
                Image(
                    systemName: chosen.contains(candidate.symbol)
                        ? "checkmark.circle.fill" : "circle"
                )
                .font(.title3)
                .foregroundStyle(
                    chosen.contains(candidate.symbol)
                        ? MonMonTheme.accent : MonMonTheme.textSecondary
                )
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(candidate.symbol)
                        .font(.headline)
                        .monospaced()

                    Text(candidate.name)
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 3) {
                    Text(priceText(candidate))
                        .font(.subheadline.weight(.medium))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text(dayText(candidate))
                        .font(.caption2)
                        .foregroundStyle(MonMonTheme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                    .fill(MonMonTheme.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: MonMonTheme.cardRadius, style: .continuous)
                    .stroke(
                        chosen.contains(candidate.symbol)
                            ? MonMonTheme.accent : MonMonTheme.border,
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("import-\(candidate.symbol)")
    }

    private func message(
        _ text: String,
        systemImage: String,
        tint: Color,
        id: String
    ) -> some View {
        Label(text, systemImage: systemImage)
            .font(.subheadline)
            .foregroundStyle(tint)
            .frame(maxWidth: 420)
            .padding(20)
            .accessibilityIdentifier(id)
    }

    private func priceText(_ candidate: FundInstrumentCandidate) -> String {
        guard let price = candidate.pricePerUnit else {
            return "—"
        }
        return VNDCurrency.formatUnitPrice(price)
    }

    private func dayText(_ candidate: FundInstrumentCandidate) -> String {
        guard let day = candidate.priceAsOf else {
            return "Refresh will fetch it"
        }
        return day.formatted(date: .abbreviated, time: .omitted)
    }

    private func toggle(_ symbol: String) {
        if chosen.contains(symbol) {
            chosen.remove(symbol)
        } else {
            chosen.insert(symbol)
        }
    }

    private func addChosen() {
        saveErrorMessage = nil
        let picked = importer.importable.filter { chosen.contains($0.symbol) }

        do {
            try importer.importing(picked, into: modelContext, existing: instruments)
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = "Couldn’t save these funds. Try again."
        }
    }
}
