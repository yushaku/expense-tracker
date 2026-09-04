import SwiftData
import SwiftUI

/// Picks instruments out of a provider's catalogue instead of typing them one at a time.
struct FundCatalogueImportView: View {
    @Environment(\.locale) private var locale

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \FundInstrument.symbol, order: .forward)
    private var instruments: [FundInstrument]

    private let title: LocalizedStringKey
    @State private var importer: FundCatalogueImport
    @State private var chosen: Set<String> = []
    @State private var searchText = ""
    @State private var saveErrorMessage: LocalizedStringKey?
    @State private var failedSymbols: [String] = []
    @State private var isSaving = false

    init(title: LocalizedStringKey, importer: FundCatalogueImport) {
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
                        .disabled(isSaving)
                        .accessibilityIdentifier("cancel-import")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(action: addChosen) {
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Add \(chosen.count)")
                        }
                    }
                    .disabled(chosen.isEmpty || isSaving)
                    .accessibilityLabel(confirmAccessibilityLabel)
                    .accessibilityIdentifier("confirm-import")
                }
            }
        }
        .tint(MonMonTheme.accent)
        .interactiveDismissDisabled(isSaving)
        .task { await importer.load(existing: instruments) }
        // Debounced rather than sent per keystroke: the provider is a free
        // public endpoint, and typing "bitcoin" would otherwise be seven
        // requests for one answer. A newer keystroke replaces this task, so
        // only the text somebody stopped on is ever asked about.
        .task(id: searchText) {
            guard importer.offersRemoteSearch else {
                return
            }

            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else {
                return
            }

            await importer.searchRemotely(searchText)
        }
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

                    if let quoteFailureMessage {
                        message(
                            quoteFailureMessage,
                            systemImage: "exclamationmark.circle.fill",
                            tint: MonMonTheme.danger,
                            id: "quote-import-error"
                        )
                    }

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
                        candidateContent
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

    @ViewBuilder
    private var candidateContent: some View {
        if isETF || isCrypto {
            ForEach(shown) { candidate in
                row(candidate)
            }
        } else {
            ForEach(groups) { group in
                ownerHeader(group)

                ForEach(group.funds) { candidate in
                    row(candidate)
                }
            }
        }
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

            if !isETF {
                Text(
                    """
                    Grouped by \(groupNoun) · \(groupCountText). Tap a \(groupNoun) to \
                    take all of its \(itemNoun).
                    """
                )
                .font(.caption)
                .foregroundStyle(MonMonTheme.textSecondary)
            }

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
                return AppText.string(
                    """
                    \(total) gold products, each with the shop buy price \(providerName) \
                    publishes. Pick the ones you hold — nothing is added until you do.
                    """,
                    in: locale
                )
            }
            if isETF {
                return AppText.string(
                    """
                    \(total) HOSE-listed ETFs. Pick the ones you hold — their closing prices are \
                    fetched before they are added.
                    """,
                    in: locale
                )
            }
            return AppText.string(
                """
                \(total) open-ended funds, each with the NAV Fmarket publishes. Pick the ones you \
                hold — nothing is added until you do.
                """,
                in: locale
            )
        }
        return AppText.string("\(shown.count) of \(total) \(itemNoun) match.", in: locale)
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

            if importer.isSearchingRemotely {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Searching")
            }

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
        VStack(alignment: .leading, spacing: 6) {
            Text("No \(itemNoun) matches “\(searchText)”.")

            if let remoteMessage {
                Text(remoteMessage)
            }
        }
        .font(.subheadline)
        .foregroundStyle(MonMonTheme.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 24)
        .accessibilityElement(children: .combine)
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

                FundLogoView(
                    symbol: candidate.symbol,
                    logoURL: candidate.logoURL,
                    size: 34
                )

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
            return AppText.string(
                key: isETF ? "Close fetched when added" : "Refresh will fetch it",
                in: locale
            )
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
        guard !isSaving else { return }
        isSaving = true
        Task { await importChosen() }
    }

    private func importChosen() async {
        defer { isSaving = false }
        saveErrorMessage = nil
        failedSymbols = []
        // Everything ticked, even if the search has since narrowed the list.
        let picked = importer.importable.filter { chosen.contains($0.symbol) }

        do {
            let result = try await importer.importing(
                picked,
                into: modelContext,
                existing: instruments
            )
            chosen.subtract(result.addedSymbols)
            failedSymbols = result.failures.map(\.symbol)

            if result.failures.isEmpty {
                dismiss()
            }
        } catch {
            modelContext.rollback()
            saveErrorMessage = "Couldn’t save these \(itemNoun). Try again."
        }
    }

    private var confirmAccessibilityLabel: Text {
        if isSaving {
            Text("Fetching closing prices")
        } else {
            Text("Add \(chosen.count)")
        }
    }

    private var quoteFailureMessage: LocalizedStringKey? {
        guard !failedSymbols.isEmpty else { return nil }
        let symbols = failedSymbols.joined(separator: ", ")
        return "Couldn’t fetch a closing price for \(symbols). Try Add again."
    }

    private var isGold: Bool { importer.source == .vangToday }
    private var isETF: Bool { importer.source == .vndirect }
    private var isCrypto: Bool { importer.source == .coinGecko }

    /// What to say under a search the loaded list did not answer.
    ///
    /// Only where a remote lookup is possible at all: telling somebody a
    /// complete catalogue is still being searched would be untrue.
    private var remoteMessage: LocalizedStringKey? {
        guard importer.offersRemoteSearch else {
            return nil
        }

        if importer.isSearchingRemotely {
            return "Asking \(providerName)…"
        }

        switch importer.remoteSearchFailure {
        case .none:
            return searchText.trimmingCharacters(in: .whitespacesAndNewlines).count
                < FundCatalogueImport.remoteSearchMinimumLength
                ? "Type at least \(FundCatalogueImport.remoteSearchMinimumLength) characters."
                : "\(providerName) has nothing under that name either."
        case .rateLimited:
            return "Checked a moment ago. Try again shortly."
        case .transport:
            return "No connection, so only the loaded list was searched."
        default:
            return "\(providerName) could not answer that search."
        }
    }
    private var providerName: String { importer.source.displayName(in: locale) }
    /// The nouns this screen builds its sentences from, in the language on
    /// show. Vietnamese does not change a noun for number, so one word answers
    /// for both counts.
    private var itemNoun: String {
        if isGold {
            return AppText.string(key: "gold products", in: locale)
        }
        if isCrypto {
            return AppText.string(key: "coins", in: locale)
        }
        return AppText.string(key: isETF ? "ETFs" : "funds", in: locale)
    }

    private var groupNoun: String {
        AppText.string(key: isGold ? "brands" : "managers", in: locale)
    }
    private var searchPlaceholder: String {
        if isGold {
            return AppText.string("Code, name or brand", in: locale)
        }
        if isCrypto {
            return AppText.string("Ticker or coin name", in: locale)
        }
        return AppText.string(
            key: isETF ? "Ticker or name" : "Ticker, name or manager",
            in: locale
        )
    }
}
