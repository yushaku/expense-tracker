import SwiftUI
import UniformTypeIdentifiers

struct ResearchNotebookView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var notebook = ResearchNotebook()
    @State private var store: ResearchNotebookStore?
    @State private var defaults: UserDefaults?
    @State private var canRead = false
    @State private var canWrite = false
    @State private var errorMessage: LocalizedStringKey?
    @State private var selection = 0
    @State private var isExporting = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("AI research notebook", systemImage: "text.book.closed.fill")
                        .font(.title2.bold())
                    Text(
                        "Research and proposals are AI drafts. Your decisions do not place orders or move money."
                    )
                    .font(.subheadline).foregroundStyle(MonMonTheme.textSecondary)
                    Text(
                        "Stored on this Mac only. Not included in Device Sync or financial backups. Export a copy to keep your research."
                    )
                    .font(.caption).foregroundStyle(MonMonTheme.textSecondary)
                    Toggle("Allow AI to create research and proposals", isOn: writingPermission)
                        .disabled(!canRead || defaults == nil)
                    if !canRead {
                        Text("Enable Allow AI access in Settings first.")
                            .font(.caption).foregroundStyle(MonMonTheme.textSecondary)
                    }
                }
                .researchCard()
                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.circle")
                        .foregroundStyle(MonMonTheme.danger)
                }
                Picker("Content", selection: $selection) {
                    Text("Proposals").tag(0)
                    Text("Research notes").tag(1)
                }
                .pickerStyle(.segmented)
                if selection == 0 {
                    if notebook.proposals.isEmpty {
                        ContentUnavailableView(
                            "No proposals yet", systemImage: "lightbulb",
                            description: Text(
                                "Ask your agent to research an option and save a proposal, then refresh this screen."
                            ))
                    }
                    ForEach(notebook.proposals.reversed()) { proposal in
                        if let store {
                            NavigationLink {
                                ResearchProposalDetail(proposal: proposal, store: store)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(proposal.title).font(.headline)
                                    HStack {
                                        Text(proposal.action.title)
                                        Spacer()
                                        Text(proposal.amount + " " + proposal.currencyCode)
                                    }.font(.subheadline)
                                    HStack {
                                        Text(
                                            notebook.decision(for: proposal)?.decision.title
                                                ?? "Draft")
                                        if notebook.needsReview(proposal) {
                                            Label(
                                                "Needs review",
                                                systemImage: "clock.badge.exclamationmark")
                                        }
                                    }.font(.caption).foregroundStyle(MonMonTheme.textSecondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .researchCard()
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    if notebook.notes.isEmpty {
                        ContentUnavailableView(
                            "No research notes yet", systemImage: "note.text",
                            description: Text(
                                "Notes saved by your agent will appear here after refresh."))
                    }
                    ForEach(notebook.notes.reversed()) { note in
                        NavigationLink {
                            ResearchNoteDetail(note: note)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(note.title).font(.headline)
                                Text(note.content).lineLimit(2).font(.subheadline)
                                    .foregroundStyle(MonMonTheme.textSecondary)
                                LabeledContent("Review after") {
                                    Text(note.reviewAfter, style: .date)
                                }
                                .font(.caption)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .researchCard()
                        }.buttonStyle(.plain)
                    }
                }
            }.padding(20)
        }
        .background(MonMonTheme.canvas)
        .foregroundStyle(MonMonTheme.textPrimary)
        .navigationTitle("Research & proposals")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Export research", systemImage: "square.and.arrow.up") {
                    reload()
                    if errorMessage == nil { isExporting = true }
                }
                .disabled(store == nil || errorMessage != nil)
                Button("Refresh", systemImage: "arrow.clockwise") { reload() }
            }
        }
        .task { reload() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { reload() } }
        .fileExporter(
            isPresented: $isExporting, document: ResearchExportDocument(notebook: notebook),
            contentType: .json, defaultFilename: "MonMon-Research"
        ) { result in
            if case .failure = result { errorMessage = "Could not export research." }
        }
    }

    private var writingPermission: Binding<Bool> {
        Binding(
            get: { canWrite },
            set: { value in
                guard let defaults else { return }
                guard !value || defaults.bool(forKey: MCPConsentStore.allowedKey) else {
                    reload()
                    return
                }
                defaults.set(value, forKey: MCPResearchService.writingAllowedKey)
                canWrite = value
            })
    }

    private func reload() {
        do {
            let config = try MCPRuntimeConfiguration.current()
            guard let defaults = UserDefaults(suiteName: config.appGroupIdentifier) else {
                throw ResearchStoreError.unavailable
            }
            let store = try ResearchNotebookStore.current(configuration: config)
            notebook = try store.load()
            self.store = store
            self.defaults = defaults
            canRead = defaults.bool(forKey: MCPConsentStore.allowedKey)
            canWrite = canRead && defaults.bool(forKey: MCPResearchService.writingAllowedKey)
            errorMessage = nil
        } catch {
            errorMessage = "Could not load research. Your existing notes have not been changed."
        }
    }
}

private struct ResearchNoteDetail: View {
    let note: ResearchNote
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(note.title).font(.title2.bold())
                Text("AI-authored research").font(.caption).foregroundStyle(
                    MonMonTheme.textSecondary)
                LabeledContent("Researched at") { Text(note.researchedAt, format: .dateTime) }
                LabeledContent("Review after") { Text(note.reviewAfter, format: .dateTime) }
                if note.reviewAfter <= .now {
                    Label("Needs review", systemImage: "clock.badge.exclamationmark")
                        .foregroundStyle(MonMonTheme.danger)
                }
                Text(note.content).textSelection(.enabled)
                if let instrumentID = note.instrumentID {
                    LabeledContent("Instrument ID", value: instrumentID.uuidString)
                        .font(.caption).textSelection(.enabled)
                }
                Text("Sources").font(.headline)
                Text("Source claims and access times are supplied by the agent.")
                    .font(.caption).foregroundStyle(MonMonTheme.textSecondary)
                ForEach(note.sources) { source in
                    VStack(alignment: .leading, spacing: 4) {
                        Link(source.title, destination: source.url)
                        Text(source.url.absoluteString).font(.caption).textSelection(.enabled)
                        LabeledContent("Accessed at") { Text(source.accessedAt, format: .dateTime) }
                            .font(.caption).foregroundStyle(MonMonTheme.textSecondary)
                    }.researchCard()
                }
            }.padding(20).frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(MonMonTheme.canvas).foregroundStyle(MonMonTheme.textPrimary)
        .navigationTitle("Research note")
    }
}

private struct ResearchProposalDetail: View {
    let proposal: InvestmentProposal
    let store: ResearchNotebookStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var notebook = ResearchNotebook()
    @State private var reason = ""
    @State private var errorMessage: LocalizedStringKey?
    @State private var isLoaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(proposal.title).font(.title2.bold())
                    Text("AI draft · requires your review").font(.caption)
                    LabeledContent("Target", value: proposal.target)
                    LabeledContent(
                        proposal.action.title, value: proposal.amount + " " + proposal.currencyCode
                    )
                    .font(.headline)
                    LabeledContent("Financial data read at") {
                        Text(proposal.financialDataReadAt, format: .dateTime)
                    }
                    LabeledContent("Valid until") { Text(proposal.validUntil, format: .dateTime) }
                    Text(
                        "Check your current finances before deciding. The read time is supplied by the agent."
                    )
                    .font(.caption).foregroundStyle(MonMonTheme.textSecondary)
                    if notebook.needsReview(proposal) {
                        Label(
                            "Research expired. Request an updated proposal before accepting.",
                            systemImage: "clock.badge.exclamationmark"
                        )
                        .foregroundStyle(MonMonTheme.danger)
                    }
                }.researchCard()
                textSection("Rationale", proposal.rationale)
                textSection("Risks", proposal.risks)
                textSection("Assumptions", proposal.assumptions)
                textSection("Alternatives", proposal.alternatives)
                VStack(alignment: .leading, spacing: 10) {
                    Text("Supporting research").font(.headline)
                    ForEach(proposal.noteIDs, id: \.self) { id in
                        if let note = notebook.notes.first(where: { $0.id == id }) {
                            NavigationLink(note.title) { ResearchNoteDetail(note: note) }
                        }
                    }
                }.researchCard()
                VStack(alignment: .leading, spacing: 10) {
                    Text("Your decision").font(.headline)
                    Text(
                        "Acceptance records your intent only. It does not create a transaction or place an order."
                    )
                    .font(.caption).foregroundStyle(MonMonTheme.textSecondary)
                    TextField("Decision reason", text: $reason, axis: .vertical)
                        .lineLimit(2...5).textFieldStyle(.roundedBorder)
                    HStack {
                        ForEach(ResearchDecision.allCases, id: \.self) { decision in
                            Button(decision.actionTitle) { decide(decision) }
                                .disabled(
                                    !isLoaded
                                        || reason.trimmingCharacters(in: .whitespacesAndNewlines)
                                            .isEmpty
                                        || reason.count > 2000
                                        || (decision == .accepted && notebook.needsReview(proposal))
                                )
                        }
                    }
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(MonMonTheme.danger)
                    }
                }.researchCard()
                ForEach(notebook.decisions.filter { $0.proposalID == proposal.id }.reversed()) {
                    decision in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(decision.decision.title).font(.headline)
                            Spacer()
                            Text(decision.createdAt, format: .dateTime).font(.caption)
                        }
                        Text(decision.reason).textSelection(.enabled)
                    }.researchCard()
                }
            }.padding(20)
        }
        .background(MonMonTheme.canvas).foregroundStyle(MonMonTheme.textPrimary)
        .navigationTitle("Investment proposal")
        .toolbar { Button("Refresh", systemImage: "arrow.clockwise") { reload() } }
        .task { reload() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { reload() } }
    }

    private func textSection(_ title: LocalizedStringKey, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(text).textSelection(.enabled)
        }.frame(maxWidth: .infinity, alignment: .leading).researchCard()
    }
    private func reload() {
        do {
            notebook = try store.load()
            isLoaded = true
            errorMessage = nil
        } catch {
            isLoaded = false
            errorMessage = "Could not load research. Your existing notes have not been changed."
        }
    }
    private func decide(_ decision: ResearchDecision) {
        do {
            try store.decide(proposalID: proposal.id, decision: decision, reason: reason)
            reason = ""
            reload()
        } catch ResearchStoreError.expired {
            errorMessage = "Research expired. Request an updated proposal before accepting."
        } catch {
            errorMessage = "Could not save your decision. Refresh and try again."
        }
    }
}

private struct ResearchExportDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    let notebook: ResearchNotebook
    init(notebook: ResearchNotebook) { self.notebook = notebook }
    init(configuration: ReadConfiguration) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        notebook = try decoder.decode(
            ResearchNotebook.self, from: configuration.file.regularFileContents ?? Data())
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return FileWrapper(regularFileWithContents: try encoder.encode(notebook))
    }
}

private extension View {
    func researchCard() -> some View {
        padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(MonMonTheme.surface, in: .rect(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).stroke(MonMonTheme.border, lineWidth: 1) }
    }
}

private extension InvestmentAction {
    var title: LocalizedStringKey {
        switch self {
        case .buyFund: "Buy fund"
        case .saveCash: "Save money"
        case .holdCash: "Hold cash"
        }
    }
}
private extension ResearchDecision {
    var title: LocalizedStringKey {
        switch self {
        case .accepted: "Accepted · not executed"
        case .deferred: "Deferred"
        case .rejected: "Rejected"
        }
    }
    var actionTitle: LocalizedStringKey {
        switch self {
        case .accepted: "Accept"
        case .deferred: "Defer"
        case .rejected: "Reject"
        }
    }
}
