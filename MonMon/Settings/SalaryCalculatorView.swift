import SwiftData
import SwiftUI

struct SalaryCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Query(sort: \RecurringRule.createdAt) private var rules: [RecurringRule]
    @Query(sort: \TransactionCategory.createdAt) private var categories: [TransactionCategory]
    @Query(sort: \CashAccount.createdAt) private var accounts: [CashAccount]
    @AppStorage(TransactionDefaults.accountStorageKey) private var defaultAccount = ""

    @State private var amountText = ""
    @State private var fromNet = false
    @State private var dependants = 0
    @State private var period = SalaryCalculator.Period.secondHalf
    @State private var region = SalaryCalculator.Region.i
    @State private var customInsurance = false
    @State private var insuranceText = ""
    @State private var didPrefill = false
    @State private var editor: SalaryEditorPresentation?

    private var firstSalary: RecurringRule? {
        SalaryRecurring.first(in: rules, categories: categories)
    }

    private var result: SalaryCalculator.Result? {
        guard let amount = VNDCurrency.parse(amountText) else { return nil }
        let insurance = customInsurance ? VNDCurrency.parse(insuranceText) : nil
        guard !customInsurance || insurance != nil else { return nil }
        return SalaryCalculator.calculate(
            amount: amount, fromNet: fromNet, dependants: dependants,
            period: period, region: region, insuranceSalary: insurance
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                inputSection
                insuranceSection
                if let result {
                    resultSection(result)
                    Section {
                        Button {
                            prepareRecurring(result.net)
                        } label: {
                            Label(
                                "Use Net for recurring salary",
                                systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                        }
                        .disabled(result.net <= 0)
                        .accessibilityIdentifier("salary-save-recurring")
                    } footer: {
                        Text(
                            firstSalary == nil
                                ? "Review the account and payment date before saving a new monthly Salary rule."
                                : "Review changes to your first monthly Salary rule. Its account and schedule are kept."
                        )
                    }
                } else if !amountText.isEmpty {
                    Section {
                        Text("Enter a valid salary and insurance amount (up to 1 trillion VND).")
                            .foregroundStyle(MonMonTheme.danger)
                    }
                }
                Section {
                    if let url = URL(string: "https://www.topcv.vn/tinh-luong-gross-net") {
                        Link("Reference: TopCV", destination: url)
                    }
                } footer: {
                    Text(
                        "2026 estimate for resident employees with contracts of at least 3 months. Excludes tax-exempt allowances and other deductions. Amounts are rounded to VND."
                    )
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(MonMonTheme.canvas)
            .navigationTitle("Salary calculator")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                        .tint(MonMonTheme.textSecondary)
                }
            }
            .tint(MonMonTheme.accent)
            .appSheet(item: $editor) { presentation in
                RecurringEditorView(mode: presentation.mode, initialDraft: presentation.draft)
            }
            .onAppear {
                guard !didPrefill else { return }
                didPrefill = true
                if let rule = firstSalary {
                    fromNet = true
                    amountText = VNDCurrency.formatPlain(rule.amount)
                }
            }
        }
        #if os(macOS)
            .frame(minWidth: 500, minHeight: 700)
        #endif
    }

    private var inputSection: some View {
        Section {
            Picker("Conversion", selection: $fromNet) {
                Text("Gross → Net").tag(false)
                Text("Net → Gross").tag(true)
            }
            .pickerStyle(.segmented)
            VStack(alignment: .leading, spacing: 8) {
                Text(fromNet ? "Monthly Net (VND)" : "Monthly Gross (VND)")
                    .font(.subheadline)
                VNDTextField(text: $amountText)
                    .font(.title2.weight(.semibold))
                    .accessibilityLabel(fromNet ? "Monthly Net (VND)" : "Monthly Gross (VND)")
                    .accessibilityIdentifier("salary-amount")
            }
            Picker("Calculation period", selection: $period) {
                ForEach(SalaryCalculator.Period.allCases) { value in
                    Text(LocalizedStringKey(value.rawValue)).tag(value)
                }
            }
            Stepper(value: $dependants, in: 0...20) {
                LabeledContent("Dependants", value: dependants.formatted())
            }
        } footer: {
            if firstSalary != nil {
                Text(
                    "Prefilled from your first monthly Salary rule, treated as take-home pay (Net)."
                )
            }
        }
    }

    private var insuranceSection: some View {
        Section("Insurance") {
            Picker("Region", selection: $region) {
                ForEach(SalaryCalculator.Region.allCases) { value in
                    Text(verbatim: value.label).tag(value)
                }
            }
            Toggle("Custom insurance salary", isOn: $customInsurance)
            if customInsurance {
                VNDTextField("Insurance salary (VND)", text: $insuranceText)
                    .accessibilityLabel("Insurance salary (VND)")
            } else {
                Text("Insurance is calculated on full Gross, subject to statutory caps.")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private func resultSection(_ result: SalaryCalculator.Result) -> some View {
        Section("Salary breakdown") {
            moneyRow("Gross salary", result.gross)
            moneyRow("Social insurance (8%)", result.social)
            moneyRow("Health insurance (1.5%)", result.health)
            moneyRow("Unemployment insurance (1%)", result.unemployment)
            moneyRow("Family deductions", result.deductions)
            moneyRow("Taxable income", result.taxable)
            moneyRow("Personal income tax", result.tax)
            moneyRow("Net salary", result.net)
                .fontWeight(.semibold)
                .foregroundStyle(MonMonTheme.accent)
        }
    }

    private func moneyRow(_ title: LocalizedStringKey, _ amount: Decimal) -> some View {
        LabeledContent(title) {
            Text(VNDCurrency.format(amount))
                .monospacedDigit()
        }
    }

    private func prepareRecurring(_ net: Decimal) {
        let rule = firstSalary
        let accountID = TransactionDefaults.resolveAccountID(
            defaultAccount, accounts: accounts.filter { $0.currencyCode == VNDCurrency.code }
        )
        let draft = SalaryRecurring.draft(
            net: net, rule: rule, accountID: accountID,
            categoryID: SalaryRecurring.categoryID(in: categories),
            name: AppText.string("Salary", in: locale), date: .now
        )
        editor = SalaryEditorPresentation(mode: rule.map { .edit($0) } ?? .add, draft: draft)
    }
}

private struct SalaryEditorPresentation: Identifiable {
    let id = UUID()
    let mode: RecurringEditorMode
    let draft: RecurringRuleDraft
}
