import SwiftUI

enum TransactionEntryTab: Int, CaseIterable {
    case income
    case expense
    case quickAdd

    init(kind: TransactionKind) {
        self = kind == .income ? .income : .expense
    }

    var kind: TransactionKind? {
        switch self {
        case .income: .income
        case .expense: .expense
        case .quickAdd: nil
        }
    }

    func swiped(
        horizontal: CGFloat, vertical: CGFloat, allowsQuickAdd: Bool = true
    ) -> Self {
        // Require an intentional horizontal swipe, leaving vertical scrolling
        // and short drags within form controls alone.
        guard abs(horizontal) >= 60, abs(horizontal) > abs(vertical) * 1.5 else {
            return self
        }
        let last = allowsQuickAdd ? Self.quickAdd.rawValue : Self.expense.rawValue
        let next = min(max(rawValue + (horizontal < 0 ? 1 : -1), 0), last)
        return Self(rawValue: next) ?? self
    }
}

struct TransactionEditorForm: View {
    @Environment(\.locale) private var locale
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var pageTurnDirection = -1.0

    @Binding var draft: TransactionDraft
    @Binding var isQuickAdding: Bool
    @Binding var rawEntry: String

    let accounts: [CashAccount]
    let categories: [TransactionCategory]
    let tripWorkspaces: [TripWorkspace]
    let budgetJars: [BudgetJar]
    let isEditing: Bool
    let validationError: TransactionFormError?
    let saveErrorMessage: LocalizedStringKey?
    let onDelete: () -> Void
    let onCapture: (String) -> Void

    var body: some View {
        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                    entryTabs

                    ZStack(alignment: .top) {
                        entryPage
                            .id(entrySelection.wrappedValue)
                            .transition(
                                TransactionPageTurn(
                                    direction: pageTurnDirection, reduceMotion: reduceMotion)
                            )
                    }
                }
                .frame(maxWidth: 560)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            }
            // In a sheet, a scroll view that bounces eats the start of a drag
            // downwards before the sheet begins to move, so leaving takes two
            // pulls where it should take one. Content that already fits has
            // nothing to scroll and so has no reason to bounce.
            .scrollBounceBehavior(.basedOnSize)
            .simultaneousGesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        let horizontal =
                            layoutDirection == .rightToLeft
                            ? -value.translation.width : value.translation.width
                        let current = entrySelection.wrappedValue
                        let next = current.swiped(
                            horizontal: horizontal,
                            vertical: value.translation.height,
                            allowsQuickAdd: !isEditing
                        )
                        guard next != current else { return }
                        pageTurnDirection = value.translation.width < 0 ? -1 : 1
                        withAnimation(.easeInOut(duration: reduceMotion ? 0.15 : 0.35)) {
                            entrySelection.wrappedValue = next
                        }
                    }
            )
        }
    }

    private var entryPage: some View {
        VStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
            if isQuickAdding {
                TransactionCaptureEntry(rawEntry: $rawEntry, onApply: onCapture)
            } else {
                introduction
                amountCard
                detailsCard

                if showsTripRouting {
                    tripRoutingCard
                }
            }

            if let saveErrorMessage {
                errorBanner(saveErrorMessage)
            }

            if isEditing {
                deleteButton
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var entryTabs: some View {
        Picker("Entry method", selection: entrySelection) {
            ForEach(TransactionKind.allCases, id: \.rawValue) { kind in
                Text(kind.displayName)
                    .tag(TransactionEntryTab(kind: kind))
            }
            if !isEditing {
                Text("Quick Add")
                    .tag(TransactionEntryTab.quickAdd)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityIdentifier("transaction-kind")
    }

    private var entrySelection: Binding<TransactionEntryTab> {
        Binding(
            get: { isQuickAdding ? .quickAdd : TransactionEntryTab(kind: draft.kind) },
            set: { tab in
                isQuickAdding = tab == .quickAdd
                if let kind = tab.kind {
                    draft.kind = kind
                }
            }
        )
    }

    private var introduction: some View {
        HStack(spacing: 16) {
            Image(systemName: draft.kind.symbolName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(MonMonTheme.onAccent)
                .frame(width: 46, height: 46)
                .background(directionTint, in: RoundedRectangle(cornerRadius: 14))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(isEditing ? "Fix what you recorded" : "Where the money went")
                    .font(.title3.weight(.semibold))

                Text("The account you pick moves by exactly this amount.")
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
                HStack(spacing: 12) {
                    Text(draft.kind.signLabel)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(directionTint)
                        .accessibilityLabel(
                            draft.kind == .income ? "Plus" : "Minus"
                        )

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
                    validationMessage(amountErrorMessage, id: "transaction-amount-error")
                }

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Note")

                    TextField("Optional", text: $draft.note)
                        .textFieldStyle(.plain)
                        .padding(14)
                        .background(
                            MonMonTheme.field,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .accessibilityIdentifier("transaction-note")
                }
            }
        }
    }

    private var detailsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader("Details", systemImage: "list.bullet")

                // The two pickers are one decision each and short enough to
                // share a line, which keeps the date in view while a category
                // is being chosen.
                HStack(alignment: .top, spacing: 12) {
                    categoryField

                    accountField
                }

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Date")

                    DateField(
                        selection: $draft.occurredAt,
                        accessibilityIdentifier: "transaction-date"
                    )
                }
            }
        }
    }

    private var tripRoutingCard: some View {
        card {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader("Trip spending", systemImage: "airplane")

                HStack(alignment: .top, spacing: 12) {
                    tripPickerField

                    if draft.tripWorkspaceID != nil {
                        budgetJarPickerField
                    }
                }

                if draft.tripWorkspaceID != nil {
                    Text(
                        "The expense keeps its category. This choice only changes which jar pays for it."
                    )
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
                }

                if let tripRoutingErrorMessage {
                    validationMessage(
                        tripRoutingErrorMessage,
                        id: "transaction-trip-error"
                    )
                }
            }
        }
    }

    private var tripPickerField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Trip")

            Picker("Trip", selection: $draft.tripWorkspaceID) {
                Text("No trip")
                    .tag(UUID?.none)

                ForEach(availableTripWorkspaces) { workspace in
                    Text(workspace.name)
                        .tag(UUID?.some(workspace.id))
                }
            }
            .labelsHidden()
            .accessibilityIdentifier("transaction-trip")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var budgetJarPickerField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Budget jar")

            Picker("Budget jar", selection: $draft.budgetJarOverrideID) {
                Text("Use category jar")
                    .tag(UUID?.none)

                ForEach(budgetJars) { jar in
                    Text(jar.name)
                        .tag(UUID?.some(jar.id))
                }
            }
            .labelsHidden()
            .accessibilityIdentifier("transaction-trip-jar")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var showsTripRouting: Bool {
        draft.kind == .expense
            && (!availableTripWorkspaces.isEmpty || draft.tripWorkspaceID != nil)
    }

    private var availableTripWorkspaces: [TripWorkspace] {
        TripTransactionSelection.availableWorkspaces(
            tripWorkspaces,
            selectedID: draft.tripWorkspaceID
        )
    }

    private var categoryField: some View {
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
                .lineLimit(1)
                .accessibilityIdentifier("transaction-category")
            }

            if let categoryErrorMessage {
                validationMessage(categoryErrorMessage, id: "transaction-category-error")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var accountField: some View {
        VStack(alignment: .leading, spacing: 8) {
            fieldLabel("Account")

            if accounts.isEmpty {
                Text("No account yet. Add one on the Home tab first.")
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
                .lineLimit(1)
                .accessibilityIdentifier("transaction-account")
            }

            if let accountErrorMessage {
                validationMessage(accountErrorMessage, id: "transaction-account-error")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var missingCategoryNotice: LocalizedStringKey {
        """
        No \(draft.kind.displayName(in: locale).lowercased()) category yet. Add one from the \
        Categories button.
        """
    }

    /// A category only appears for the direction it was created for, so an
    /// expense can never be filed under Salary.
    private var matchingCategories: [TransactionCategory] {
        categories.filter { $0.kind == draft.kind }
    }

    private var deleteButton: some View {
        Button(role: .destructive, action: onDelete) {
            Label("Delete transaction", systemImage: "trash.fill")
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
        .accessibilityIdentifier("delete-transaction")
    }

    @ViewBuilder
    private var amountTextField: some View {
        VNDTextField(text: $draft.amountText)
            .accessibilityIdentifier("transaction-amount")
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

    private func sectionHeader(_ title: LocalizedStringKey, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(MonMonTheme.textPrimary)
    }

    private func fieldLabel(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.subheadline.weight(.medium))
    }

    private func errorBanner(_ message: LocalizedStringKey) -> some View {
        validationMessage(message, id: "save-transaction-error")
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

    private func validationMessage(_ message: LocalizedStringKey, id: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.caption)
            .foregroundStyle(MonMonTheme.danger)
            .accessibilityIdentifier(id)
    }

    private var amountErrorMessage: LocalizedStringKey? {
        switch validationError {
        case .invalidAmount:
            "Enter a valid amount."
        case .nonPositiveAmount:
            "Enter an amount greater than zero."
        default:
            nil
        }
    }

    private var accountErrorMessage: LocalizedStringKey? {
        validationError == .missingAccount ? "Pick the account this money moved through." : nil
    }

    private var categoryErrorMessage: LocalizedStringKey? {
        validationError == .missingCategory ? "Pick a category." : nil
    }

    private var tripRoutingErrorMessage: LocalizedStringKey? {
        switch validationError {
        case .tripRequiresExpense:
            "Only expenses can be added to a trip."
        case .jarOverrideRequiresTrip:
            "Choose a trip before overriding its budget jar."
        default:
            nil
        }
    }
}

/// Rotate incoming and outgoing pages in opposite directions. The tab bar stays
/// stationary; Reduce Motion replaces the depth effect with a brief crossfade.
private struct TransactionPageTurn: Transition {
    let direction: Double
    let reduceMotion: Bool

    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .rotation3DEffect(
                .degrees(reduceMotion ? 0 : phase.value * direction * 85),
                axis: (x: 0, y: 1, z: 0),
                perspective: 0.3
            )
            .opacity(phase.isIdentity ? 1 : 0)
    }
}
