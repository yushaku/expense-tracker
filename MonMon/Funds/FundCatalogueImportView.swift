import SwiftData
import SwiftUI

/// Picks instruments out of a provider's catalogue instead of typing them one at a time.
struct FundCatalogueImportView: View {
    @Environment(\.locale) private var locale

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \FundInstrument.symbol, order: .forward)
    private var instruments: [FundInstrument]

    private let title: String
    @State private var importer: FundCatalogueImport
    @State private var chosen: Set<String> = []
    @State private var searchText = ""
    @State private var saveErrorMessage: LocalizedStringKey?

    init(title: String, importer: FundCatalogueImport) {
        self.title = title
        _importer = State(initialValue: importer)
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

                content
            }
            .navigationTitle(title)
            .accessibilityIdentifier("\(importer.source.rawValue)-import")
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
                Text("Asking \(providerName) which \(itemNoun) it lists…")
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
            .accessibilityIdentifier("import-loading")

        case .failed:
            message(
                LocalizedStringKey(
                    importer.phase.message(providerName: providerName, in: locale)
                        ?? AppText.string("\(providerName) could not be reached.", in: locale)
                ),
                systemImage: "xmark.circle.fill",
                tint: MonMonTheme.danger,
                id: "import-error"
            )

        case .loaded where importer.importable.isEmpty:
            message(
                "Every \(itemNoun) \(providerName) lists is already in your catalogue.",
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

                    if shown.isEmpty {
                        noMatches
                    } else {
                        ForEach(groups) { group in
                            ownerHeader(group)

                            ForEach(group.funds) { candidate in
                                row(candidate)
                            }
                        }
                    }
                }
                .frame(maxWidth: MonMonTheme.maxContentWidth)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            }
        }
    }

    /// The entries on show: everything importable, narrowed by the search.
    private var shown: [FundInstrumentCandidate] {
        importer.matching(searchText)
    }

    private var groups: [FundCatalogueImport.OwnerGroup] {
        FundCatalogueImport.grouped(shown)
    }

    /// Tapping a manager takes all of its funds, which is the whole point of
    /// grouping them: somebody who holds one usually holds its neighbours.
    private func ownerHeader(_ group: FundCatalogueImport.OwnerGroup) -> some View {
        Button {
            toggleGroup(group)
        } label: {
            HStack(spacing: 10) {
                Text(group.owner)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)

                Text("\(group.funds.count)")
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(MonMonTheme.accent.opacity(0.16), in: Capsule())

                Spacer(minLength: 8)

                Image(systemName: isGroupChosen(group) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(
                        isGroupChosen(group) ? MonMonTheme.accent : MonMonTheme.textSecondary
                    )
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 14)
            .padding(.bottom, 2)
        }
        .buttonStyle(.plain)
        .foregroundStyle(MonMonTheme.textPrimary)
        .accessibilityIdentifier("import-owner-\(group.owner)")
        .accessibilityHint("Selects every \(itemNoun) from this \(groupNoun)")
    }

    private func isGroupChosen(_ group: FundCatalogueImport.OwnerGroup) -> Bool {
        !group.funds.isEmpty && group.funds.allSatisfy { chosen.contains($0.symbol) }
    }

    private func toggleGroup(_ group: FundCatalogueImport.OwnerGroup) {
        let symbols = group.funds.map(\.symbol)
        if isGroupChosen(group) {
            symbols.forEach { chosen.remove($0) }
        } else {
            chosen.formUnion(symbols)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(headerText)
                .font(.subheadline)
                .foregroundStyle(MonMonTheme.textSecondary)

            Text(
                """
                Grouped by \(groupNoun) · \(groupCountText). Tap a \(groupNoun) to \
                take all of its \(itemNoun).
                """
            )
            .font(.caption)
            .foregroundStyle(MonMonTheme.textSecondary)

            searchField

            HStack(spacing: 12) {
                // Selects what is on show, not the whole catalogue: with a search
                // typed, "all" can only sensibly mean the ones being looked at.
                Button(searchText.isEmpty ? "Select all" : "Select these") {
                    chosen.formUnion(shown.map(\.symbol))
                }
                .disabled(shown.isEmpty)
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

    private var headerText: String {
        let total = importer.importable.count
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            if isGold {
                return """
                    \(total) gold products, each with the shop buy price \(providerName) \
                    publishes. Pick the ones you hold — nothing is added until you do.
                    """
            }
            return """
                \(total) open-ended funds, each with the NAV Fmarket publishes. Pick the ones you \
                hold — nothing is added until you do.
                """
        }
        return "\(shown.count) of \(total) \(itemNoun) match."
    }

    private var groupCountText: String {
        AppText.string("\(groups.count) \(groupNoun)", in: locale)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(MonMonTheme.textSecondary)
                .accessibilityHidden(true)

            TextField(searchPlaceholder, text: $searchText)
                .textFieldStyle(.plain)
                .accessibilityIdentifier("import-search")

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(MonMonTheme.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
                .accessibilityIdentifier("clear-search")
            }
        }
        .padding(12)
        .background(
            MonMonTheme.field,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    private var noMatches: some View {
        Text("No \(itemNoun) matches “\(searchText)”.")
            .font(.subheadline)
            .foregroundStyle(MonMonTheme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 24)
            .accessibilityIdentifier("import-no-matches")
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
        _ text: LocalizedStringKey,
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
        return TransactionPeriod.day(day, in: locale)
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
        // Everything ticked, even if the search has since narrowed the list.
        let picked = importer.importable.filter { chosen.contains($0.symbol) }

        do {
            try importer.importing(picked, into: modelContext, existing: instruments)
            dismiss()
        } catch {
            modelContext.rollback()
            saveErrorMessage = "Couldn’t save these \(itemNoun). Try again."
        }
    }

    private var isGold: Bool { importer.source == .vangToday }
    private var providerName: String { importer.source.displayName(in: locale) }
    /// The nouns this screen builds its sentences from, in the language on
    /// show. Vietnamese does not change a noun for number, so one word answers
    /// for both counts.
    private var itemNoun: String {
        AppText.string(key: isGold ? "gold products" : "funds", in: locale)
    }

    private var groupNoun: String {
        AppText.string(key: isGold ? "brands" : "managers", in: locale)
    }
    private var searchPlaceholder: String {
        isGold ? "Code, name or brand" : "Ticker, name or manager"
    }
}
