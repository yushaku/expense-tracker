import SwiftData
import SwiftUI

struct SalaryCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    @Environment(SyncCoordinator.self) private var syncCoordinator
    @Query private var profiles: [SalaryProfile]
    @Query(sort: \RecurringRule.createdAt) private var rules: [RecurringRule]
    @Query(sort: \TransactionCategory.createdAt) private var categories: [TransactionCategory]
    @Query(sort: \CashAccount.createdAt) private var accounts: [CashAccount]
    @AppStorage(TransactionDefaults.accountStorageKey) private var defaultAccount = ""

    @State private var draft = SalaryProfileDraft()
    @State private var savedDraft: SalaryProfileDraft?
    @State private var didLoad = false
    @State private var saveError: LocalizedStringKey?
    @State private var isConfirmingDiscard = false
    @State private var editor: SalaryEditorPresentation?

    private var profile: SalaryProfile? {
        profiles.first { $0.id == SalaryProfile.personalID }
    }

    private var hasUnsavedChanges: Bool {
        draft != (savedDraft ?? SalaryProfileDraft())
    }

    private var linkedRule: RecurringRule? {
        SalaryProfileStore.linkedRule(id: draft.recurringRuleID, in: rules)
    }

    private var compatibleRules: [RecurringRule] {
        rules.filter(SalaryProfileStore.isCompatible)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    introduction
                    if let result = draft.result { summaryCard(result) }
                    profileCard
                    deductionsCard
                    if let result = draft.result { breakdownCard(result) }
                    recurringCard
                    if let saveError {
                        Label(saveError, systemImage: "exclamationmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(MonMonTheme.danger)
                            .accessibilityIdentifier("salary-save-error")
                    }
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) { profileButtons }
                        VStack(alignment: .leading, spacing: 12) { profileButtons }
                    }
                    referenceNote
                }
                .frame(maxWidth: 680)
                .padding(20)
                .frame(maxWidth: .infinity)
            }
            .background(MonMonTheme.canvas)
            .navigationTitle("Salary calculator")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") {
                        if hasUnsavedChanges { isConfirmingDiscard = true } else { dismiss() }
                    }
                    .labelStyle(.iconOnly)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save profile", action: saveProfile)
                        .disabled(
                            !draft.isValid || !hasUnsavedChanges || syncCoordinator.writesLocked
                        )
                        .accessibilityIdentifier("salary-save-profile")
                }
            }
            .confirmationDialog(
                "Discard salary changes?", isPresented: $isConfirmingDiscard,
                titleVisibility: .visible
            ) {
                Button("Discard changes", role: .destructive) { dismiss() }
                Button("Keep editing", role: .cancel) {}
            }
            .interactiveDismissDisabled(hasUnsavedChanges)
            .appSheet(item: $editor, onDismiss: reloadProfile) { presentation in
                RecurringEditorView(
                    mode: presentation.mode, initialDraft: presentation.draft,
                    linkSalaryProfile: true)
            }
            .onAppear {
                guard !didLoad else { return }
                didLoad = true
                reloadProfile()
            }
            .onChange(of: profile?.updatedAt) { _, _ in
                if !hasUnsavedChanges && editor == nil { reloadProfile() }
            }
            .onChange(of: draft) { _, _ in saveError = nil }
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
        }
        #if os(macOS)
            .frame(minWidth: 560, minHeight: 720)
        #endif
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your salary, clearly").font(.title2.weight(.bold))
            Text("Save your agreed salary and see what reaches your account each month.")
                .font(.subheadline).foregroundStyle(MonMonTheme.textSecondary)
            Label(
                hasUnsavedChanges
                    ? "Unsaved changes"
                    : (savedDraft == nil ? "Set up your salary profile" : "Profile saved"),
                systemImage: hasUnsavedChanges
                    ? "pencil.circle"
                    : (savedDraft == nil ? "person.crop.circle" : "checkmark.circle")
            )
            .font(.caption.weight(.medium)).foregroundStyle(MonMonTheme.textSecondary)
        }
    }

    private func summaryCard(_ result: SalaryCalculator.Result) -> some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Label("Estimated monthly take-home", systemImage: "banknote")
                    .font(.subheadline.weight(.medium)).foregroundStyle(MonMonTheme.textSecondary)
                Text(VNDCurrency.format(result.net))
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(MonMonTheme.accent)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("salary-net-result")
                Divider().overlay(MonMonTheme.border)
                moneyRow("Gross salary", result.gross)
                moneyRow("Total insurance and tax", result.gross - result.net)
            }
        }
    }

    private var profileCard: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader("Salary profile", systemImage: "person.crop.circle")
                VStack(alignment: .leading, spacing: 8) {
                    Text("Your name").font(.subheadline.weight(.medium))
                    TextField("Your name", text: $draft.name)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("salary-profile-name")
                    if draft.name.count > 100 {
                        validationText("Use a name with at most 100 characters.")
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Agreed salary basis").font(.subheadline.weight(.medium))
                    Picker("Agreed salary basis", selection: $draft.basis) {
                        Text("Gross").tag(SalaryBasis.gross)
                        Text("Net").tag(SalaryBasis.net)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("salary-deal-basis")
                    Text(
                        draft.basis == .gross
                            ? "Gross is your agreed pay before employee insurance and income tax."
                            : "Net is your agreed take-home pay after employee insurance and income tax."
                    )
                    .font(.caption).foregroundStyle(MonMonTheme.textSecondary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(draft.basis == .gross ? "Monthly Gross (VND)" : "Monthly Net (VND)")
                        .font(.subheadline.weight(.medium))
                    VNDTextField(text: $draft.amountText)
                        .textFieldStyle(.plain)
                        .font(.title2.weight(.semibold))
                        .monospacedDigit()
                        .padding(14)
                        .background(MonMonTheme.field, in: .rect(cornerRadius: 12))
                        .accessibilityLabel(
                            draft.basis == .gross ? "Monthly Gross (VND)" : "Monthly Net (VND)"
                        )
                        .accessibilityIdentifier("salary-amount")
                }
                if !draft.amountText.isEmpty && draft.result == nil {
                    validationText(
                        "Enter a valid salary and insurance amount (up to 1 trillion VND).")
                }
            }
        }
    }

    private var deductionsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 16) {
                sectionHeader("Tax and insurance settings", systemImage: "person.2")
                Stepper(value: $draft.dependants, in: 0...20) {
                    LabeledContent("Dependants", value: draft.dependants.formatted())
                }
                .accessibilityIdentifier("salary-dependants")
                Picker("Calculation period", selection: $draft.period) {
                    ForEach(SalaryCalculator.Period.allCases) { value in
                        Text(LocalizedStringKey(value.rawValue)).tag(value)
                    }
                }
                Picker("Region", selection: $draft.region) {
                    ForEach(SalaryCalculator.Region.allCases) { value in
                        Text(verbatim: value.label).tag(value)
                    }
                }
                Divider().overlay(MonMonTheme.border)
                Toggle("Custom insurance salary", isOn: $draft.customInsurance)
                    .accessibilityIdentifier("salary-custom-insurance")
                if draft.customInsurance {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Insurance salary (VND)").font(.subheadline.weight(.medium))
                        VNDTextField("Insurance salary (VND)", text: $draft.insuranceText)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Insurance salary (VND)")
                            .accessibilityIdentifier("salary-insurance-amount")
                    }
                } else {
                    Text("Insurance is calculated on full Gross, subject to statutory caps.")
                        .font(.caption).foregroundStyle(MonMonTheme.textSecondary)
                }
            }
        }
    }

    private func breakdownCard(_ result: SalaryCalculator.Result) -> some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Salary breakdown", systemImage: "list.bullet.rectangle")
                moneyRow("Gross salary", result.gross)
                moneyRow("Social insurance (8%)", result.social)
                moneyRow("Health insurance (1.5%)", result.health)
                moneyRow("Unemployment insurance (1%)", result.unemployment)
                Divider().overlay(MonMonTheme.border)
                moneyRow("Family deductions", result.deductions)
                moneyRow("Taxable income", result.taxable)
                moneyRow("Personal income tax", result.tax)
                Divider().overlay(MonMonTheme.border)
                moneyRow("Net salary", result.net)
                    .fontWeight(.semibold).foregroundStyle(MonMonTheme.accent)
            }
        }
    }

    private var recurringCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                sectionHeader("Recurring salary", systemImage: "arrow.triangle.2.circlepath")
                Text(
                    "Link a monthly income rule to this profile. Review the Net amount before applying it."
                )
                .font(.subheadline).foregroundStyle(MonMonTheme.textSecondary)
                Picker("Linked salary rule", selection: $draft.recurringRuleID) {
                    Text("Create a new salary rule").tag(UUID?.none)
                    if let id = draft.recurringRuleID, linkedRule == nil {
                        Text("Linked rule unavailable").tag(UUID?.some(id))
                    }
                    ForEach(compatibleRules) { rule in
                        Text(verbatim: recurringRuleTitle(rule))
                            .tag(UUID?.some(rule.id))
                    }
                }
                .accessibilityIdentifier("salary-linked-rule")
                if let rule = linkedRule {
                    moneyRow("Current recurring amount", rule.amount)
                    LabeledContent(
                        "Account",
                        value: accounts.first { $0.id == rule.accountID }?.name
                            ?? AppText.string("Not available", in: locale))
                    LabeledContent("Repeat", value: rule.schedulePhrase(in: locale))
                    LabeledContent(
                        "Starting",
                        value: rule.anchorDate.formatted(
                            .dateTime.day().month(.abbreviated).year().locale(locale)))
                    if rule.isPaused {
                        Label("Paused", systemImage: "pause.circle").foregroundStyle(
                            MonMonTheme.textSecondary)
                    } else if let next = rule.nextOccurrence(after: .now) {
                        LabeledContent(
                            "Next payment",
                            value: next.formatted(
                                .dateTime.day().month(.abbreviated).year().locale(locale)))
                    } else {
                        Text("This salary rule has ended.")
                            .font(.caption).foregroundStyle(MonMonTheme.textSecondary)
                    }
                    if let result = draft.result, rule.amount != result.net {
                        Label(
                            "The recurring amount differs from this estimate.",
                            systemImage: "info.circle"
                        )
                        .font(.caption).foregroundStyle(MonMonTheme.textSecondary)
                    }
                    Button("Use recurring amount as Net") {
                        draft.basis = .net
                        draft.amountText = VNDCurrency.formatPlain(rule.amount)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("salary-import-recurring")
                } else if draft.recurringRuleID != nil {
                    validationText(
                        "The linked rule was removed or is no longer monthly VND income. Choose another rule or create a new one."
                    )
                }
                Button(action: prepareRecurring) {
                    Label(
                        linkedRule == nil ? "Review new salary rule" : "Review recurring update",
                        systemImage: "arrow.right.circle")
                }
                .buttonStyle(.prominentAction)
                .disabled(
                    savedDraft == nil || hasUnsavedChanges || (draft.result?.net ?? 0) <= 0
                        || syncCoordinator.writesLocked
                        || (draft.recurringRuleID != nil && linkedRule == nil)
                )
                .accessibilityIdentifier("salary-save-recurring")
                Text(
                    hasUnsavedChanges || savedDraft == nil
                        ? "Save your profile before reviewing the recurring salary."
                        : (linkedRule == nil
                            ? "Review the account and payment date before saving a new monthly Salary rule."
                            : "Your account and schedule are kept. Past transactions stay unchanged.")
                )
                .font(.caption).foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var profileButtons: some View {
        Button("Save profile", action: saveProfile)
            .buttonStyle(.prominentAction)
            .disabled(!draft.isValid || !hasUnsavedChanges || syncCoordinator.writesLocked)
        if hasUnsavedChanges {
            Button("Discard changes", action: reloadProfile).buttonStyle(.bordered)
        }
    }

    private var referenceNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(
                "2026 estimate for resident employees with contracts of at least 3 months. Excludes tax-exempt allowances and other deductions. Amounts are rounded to VND."
            )
            .font(.caption).foregroundStyle(MonMonTheme.textSecondary)
            if let url = URL(string: "https://www.topcv.vn/tinh-luong-gross-net") {
                Link("Reference: TopCV", destination: url).font(.caption)
            }
        }
    }

    private func moneyRow(_ title: LocalizedStringKey, _ amount: Decimal) -> some View {
        LabeledContent(title) {
            Text(VNDCurrency.format(amount)).monospacedDigit()
        }
        .font(.subheadline)
    }

    private func sectionHeader(_ title: LocalizedStringKey, systemImage: String) -> some View {
        Label(title, systemImage: systemImage).font(.headline).accessibilityAddTraits(.isHeader)
    }

    private func validationText(_ text: LocalizedStringKey) -> some View {
        Text(text).font(.caption).foregroundStyle(MonMonTheme.danger)
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(MonMonTheme.surface, in: .rect(cornerRadius: MonMonTheme.cardRadius))
            .overlay {
                RoundedRectangle(cornerRadius: MonMonTheme.cardRadius).stroke(
                    MonMonTheme.border, lineWidth: 1)
            }
    }

    private func reloadProfile() {
        savedDraft = profile.map(SalaryProfileDraft.init(profile:))
        draft = savedDraft ?? SalaryProfileDraft()
        saveError = nil
    }

    private func saveProfile() {
        do {
            let saved = try SalaryProfileStore.save(draft, in: modelContext)
            savedDraft = SalaryProfileDraft(profile: saved)
            draft = savedDraft ?? SalaryProfileDraft()
            saveError = nil
        } catch {
            saveError = "Couldn’t save your salary profile. Try again."
        }
    }

    private func recurringRuleTitle(_ rule: RecurringRule) -> String {
        let name = rule.note.isEmpty ? AppText.string("Salary", in: locale) : rule.note
        let account =
            accounts.first { $0.id == rule.accountID }?.name
            ?? AppText.string("Not available", in: locale)
        return "\(name) · \(account) · \(VNDCurrency.format(rule.amount))"
    }

    private func prepareRecurring() {
        guard !hasUnsavedChanges, savedDraft != nil, let result = draft.result, result.net > 0,
            draft.recurringRuleID == nil || linkedRule != nil
        else { return }
        let rule = linkedRule
        let accountID = TransactionDefaults.resolveAccountID(
            defaultAccount, accounts: accounts.filter { $0.currencyCode == VNDCurrency.code })
        let recurringDraft = SalaryRecurring.draft(
            net: result.net, rule: rule, accountID: accountID,
            categoryID: SalaryRecurring.categoryID(in: categories),
            name: AppText.string("Salary", in: locale), date: .now)
        editor = SalaryEditorPresentation(
            mode: rule.map { .edit($0) } ?? .add, draft: recurringDraft)
    }
}

private struct SalaryEditorPresentation: Identifiable {
    let id = UUID()
    let mode: RecurringEditorMode
    let draft: RecurringRuleDraft
}
