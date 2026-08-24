import SwiftUI

struct RecurringEditorForm: View {
    @Binding var draft: RecurringRuleDraft

    let accounts: [CashAccount]
    let categories: [TransactionCategory]
    let isEditing: Bool
    let validationError: RecurringFormError?
    let saveErrorMessage: String?
    let onDelete: () -> Void

    var body: some View {
        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                    introduction
                    amountCard
                    scheduleCard
                    detailsCard

                    if let saveErrorMessage {
                        errorBanner(saveErrorMessage)
                    }

                    if isEditing {
                        deleteButton
                    }
                }
                .frame(maxWidth: 560)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var introduction: some View {
        HStack(spacing: 16) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(MonMonTheme.onAccent)
                .frame(width: 46, height: 46)
                .background(directionTint, in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(isEditing ? "Change what repeats" : "Money that comes back")
                    .font(.title3.weight(.semibold))

                Text("Every time this falls due, it is recorded for you.")
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private var directionTint: Color {
        draft.kind == .income ? MonMonTheme.gain : MonMonTheme.danger
    }

    private var amountCard: some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                Picker("Direction", selection: $draft.kind) {
                    ForEach(TransactionKind.allCases, id: \.rawValue) {
                        Text($0.displayName)
                            .tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityIdentifier("recurring-kind")

                HStack(spacing: 12) {
                    Text(draft.kind.signLabel)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(directionTint)
                        .accessibilityLabel(draft.kind == .income ? "Plus" : "Minus")

                    Text("₫")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(MonMonTheme.accent)
                        .accessibilityHidden(true)

                    amountTextField
                        .textFieldStyle(.plain)
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .accessibilityLabel("Amount")
                }
                .padding(16)
                .background(
                    MonMonTheme.field,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )

                if let amountErrorMessage {
                    validationMessage(amountErrorMessage, id: "recurring-amount-error")
                }

                Text("The same amount every time. Change it here when it changes.")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private var scheduleCard: some View {
        card {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader("Repeat", systemImage: "calendar")

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("How often")

                    Picker("How often", selection: $draft.frequency) {
                        ForEach(RecurrenceFrequency.allCases) { frequency in
                            Text(frequency.displayName)
                                .tag(frequency)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .accessibilityIdentifier("recurring-frequency")
                }

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Every")

                    HStack(spacing: 12) {
                        intervalTextField
                            .textFieldStyle(.plain)
                            .monospacedDigit()
                            .frame(maxWidth: 80)
                            .padding(14)
                            .background(
                                MonMonTheme.field,
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                            .accessibilityLabel("Interval")

                        Text(draft.frequency.phrase(interval: intervalForDisplay))
                            .font(.subheadline)
                            .foregroundStyle(MonMonTheme.textSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Starting")

                    DateField(
                        selection: $draft.anchorDate,
                        accessibilityIdentifier: "recurring-anchor-date"
                    )

                    Text(
                        "A start date in the past records what it already covered, "
                            + "as soon as you save."
                    )
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Ends on a date", isOn: $draft.hasEndDate)
                        .font(.subheadline.weight(.medium))
                        .accessibilityIdentifier("recurring-has-end-date")

                    if draft.hasEndDate {
                        DateField(
                            selection: $draft.endDate,
                            accessibilityIdentifier: "recurring-end-date"
                        )
                    }
                }

                if isEditing {
                    Toggle("Paused", isOn: $draft.isPaused)
                        .font(.subheadline.weight(.medium))
                        .accessibilityIdentifier("recurring-paused")

                    Text("A paused rule records nothing, and resuming skips what it missed.")
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)
                }

                if let scheduleErrorMessage {
                    validationMessage(scheduleErrorMessage, id: "recurring-schedule-error")
                }
            }
        }
    }

    private var detailsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader("Details", systemImage: "list.bullet")

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Category")

                    if matchingCategories.isEmpty {
                        Text(missingCategoryNotice)
                            .font(.caption)
                            .foregroundStyle(MonMonTheme.textSecondary)
                    } else {
                        Picker("Category", selection: $draft.categoryID) {
                            Text("Choose")
                                .tag(UUID?.none)

                            ForEach(matchingCategories) { category in
                                Text(category.name)
                                    .tag(UUID?.some(category.id))
                            }
                        }
                        .labelsHidden()
                        .accessibilityIdentifier("recurring-category")
                    }

                    if let categoryErrorMessage {
                        validationMessage(categoryErrorMessage, id: "recurring-category-error")
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Account")

                    if accounts.isEmpty {
                        Text("No account yet. Add one on the Report tab first.")
                            .font(.caption)
                            .foregroundStyle(MonMonTheme.textSecondary)
                    } else {
                        Picker("Account", selection: $draft.accountID) {
                            Text("Choose")
                                .tag(UUID?.none)

                            ForEach(accounts) { account in
                                Text(account.name)
                                    .tag(UUID?.some(account.id))
                            }
                        }
                        .labelsHidden()
                        .accessibilityIdentifier("recurring-account")
                    }

                    if let accountErrorMessage {
                        validationMessage(accountErrorMessage, id: "recurring-account-error")
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Name")

                    TextField("Rent, Salary, Netflix", text: $draft.note)
                        .textFieldStyle(.plain)
                        .padding(14)
                        .background(
                            MonMonTheme.field,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .accessibilityIdentifier("recurring-note")

                    Text("Written onto every entry this records.")
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)
                }
            }
        }
    }

    /// Only for the sentence beside the interval field, so half-typed input
    /// reads as "Every month" rather than as nothing at all.
    private var intervalForDisplay: Int {
        Int(draft.intervalText.trimmingCharacters(in: .whitespaces)) ?? 1
    }

    private var missingCategoryNotice: String {
        "No \(draft.kind.displayName.lowercased()) category yet. "
            + "Add one from the Categories button."
    }

    /// A category only appears for the direction it was created for, so an
    /// expense can never be filed under Salary.
    private var matchingCategories: [TransactionCategory] {
        categories.filter { $0.kind == draft.kind }
    }

    private var deleteButton: some View {
        Button(role: .destructive, action: onDelete) {
            Label("Delete rule", systemImage: "trash.fill")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(14)
        }
        .buttonStyle(.plain)
        .foregroundStyle(MonMonTheme.danger)
        .background(
            MonMonTheme.danger.opacity(0.14),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MonMonTheme.danger.opacity(0.35), lineWidth: 1)
        }
        .accessibilityIdentifier("delete-recurring")
    }

    @ViewBuilder
    private var amountTextField: some View {
        #if os(iOS)
            TextField("0", text: $draft.amountText)
                .keyboardType(.numberPad)
                .accessibilityIdentifier("recurring-amount")
        #else
            TextField("0", text: $draft.amountText)
                .accessibilityIdentifier("recurring-amount")
        #endif
    }

    @ViewBuilder
    private var intervalTextField: some View {
        #if os(iOS)
            TextField("1", text: $draft.intervalText)
                .keyboardType(.numberPad)
                .accessibilityIdentifier("recurring-interval")
        #else
            TextField("1", text: $draft.intervalText)
                .accessibilityIdentifier("recurring-interval")
        #endif
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
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

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(MonMonTheme.textPrimary)
    }

    private func fieldLabel(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.medium))
    }

    private func errorBanner(_ message: String) -> some View {
        validationMessage(message, id: "save-recurring-error")
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(
                MonMonTheme.danger.opacity(0.14),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(MonMonTheme.danger.opacity(0.35), lineWidth: 1)
            }
    }

    private func validationMessage(_ message: String, id: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.caption)
            .foregroundStyle(MonMonTheme.danger)
            .accessibilityIdentifier(id)
    }

    private var amountErrorMessage: String? {
        switch validationError {
        case .invalidAmount:
            "Enter a valid amount."
        case .nonPositiveAmount:
            "Enter an amount greater than zero."
        default:
            nil
        }
    }

    private var accountErrorMessage: String? {
        validationError == .missingAccount
            ? "Pick the account this money moves through." : nil
    }

    private var categoryErrorMessage: String? {
        validationError == .missingCategory ? "Pick a category." : nil
    }

    private var scheduleErrorMessage: String? {
        switch validationError {
        case .invalidInterval:
            "Repeat every whole number of periods, at least one."
        case .endDateBeforeAnchor:
            "The end date cannot come before the start date."
        case .tooManyOccurrences(let count):
            "Saving this would record \(count) entries at once. "
                + "Move the start date closer to today."
        default:
            nil
        }
    }
}
