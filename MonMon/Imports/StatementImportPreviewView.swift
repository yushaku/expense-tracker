import SwiftUI

struct StatementImportPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @Bindable var inbox: StatementImportInbox
    let staged: StagedBankStatement

    @State private var isConfirmingRemoval = false
    @State private var isRemoving = false

    var body: some View {
        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            content
        }
        .navigationTitle("Statement Review")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    isConfirmingRemoval = true
                } label: {
                    Label("Remove Statement", systemImage: "trash")
                }
                .disabled(isRemoving)
                .accessibilityIdentifier("remove-import-statement")
            }
        }
        .confirmationDialog(
            "Remove this statement?",
            isPresented: $isConfirmingRemoval,
            titleVisibility: .visible
        ) {
            Button("Remove Statement", role: .destructive) {
                removeStatement()
            }
            .accessibilityIdentifier("confirm-remove-import-statement")

            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The staged PDF will be deleted. No financial records are affected.")
        }
        .task(id: staged.id) { await inbox.loadPreview(staged) }
        .onDisappear { inbox.clearPreview() }
        .accessibilityIdentifier("import-statement-preview")
    }

    @ViewBuilder
    private var content: some View {
        switch inbox.previewPhase {
        case .loaded(let preview) where preview.staged.id == staged.id:
            previewContent(preview.statement)
        case .failed(let failedStaged, let failure) where failedStaged.id == staged.id:
            failureContent(failure)
        default:
            progress
        }
    }

    private var progress: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Reading statement locally…")
                .font(.subheadline)
                .foregroundStyle(MonMonTheme.textSecondary)
        }
        .accessibilityIdentifier("import-preview-loading")
    }

    private func failureContent(_ failure: StatementImportFailure) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(MonMonTheme.danger)
                .frame(width: 64, height: 64)
                .background(MonMonTheme.danger.opacity(0.16), in: Circle())
                .accessibilityHidden(true)

            Text("Couldn’t read this statement")
                .font(.title3.weight(.semibold))

            Text(failure.message)
                .font(.subheadline)
                .foregroundStyle(MonMonTheme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)

            Button("Try Again") {
                Task { await inbox.loadPreview(staged) }
            }
            .buttonStyle(.prominentAction)
            .accessibilityIdentifier("retry-import-preview")
        }
        .padding(24)
        .accessibilityIdentifier("import-preview-error")
    }

    private func previewContent(_ statement: ParsedBankStatement) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                summaryCard(statement)

                if !statement.issues.isEmpty {
                    issuesCard(statement.issues)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Transactions")
                        .font(.title3.weight(.semibold))

                    ForEach(statement.candidates) { candidate in
                        candidateRow(candidate)
                    }
                }
            }
            .frame(maxWidth: MonMonTheme.maxContentWidth)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
        }
    }

    private func summaryCard(_ statement: ParsedBankStatement) -> some View {
        card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "building.columns.fill")
                        .font(.title3)
                        .foregroundStyle(MonMonTheme.bank)
                        .frame(width: 44, height: 44)
                        .background(
                            MonMonTheme.bank.opacity(0.16),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(bankName(statement.bank))
                            .font(.headline)

                        if let suffix = statement.accountLastFour {
                            Text("Account •••• \(suffix)")
                                .font(.subheadline)
                                .foregroundStyle(MonMonTheme.textSecondary)
                        }

                        Text(period(statement.period))
                            .font(.caption)
                            .foregroundStyle(MonMonTheme.textSecondary)
                    }

                    Spacer(minLength: 8)

                    completenessLabel(statement.isComplete)
                }

                Divider().overlay(MonMonTheme.border)

                HStack(spacing: 12) {
                    total(
                        title: "Income",
                        amount: statement.parsedTotals.credit,
                        tint: MonMonTheme.gain
                    )
                    total(
                        title: "Expense",
                        amount: statement.parsedTotals.debit,
                        tint: MonMonTheme.danger
                    )
                }

                Text("\(statement.candidates.count) transactions ready for review")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
        .accessibilityIdentifier("import-preview-summary")
    }

    private func completenessLabel(_ isComplete: Bool) -> some View {
        Label(
            isComplete ? "Complete" : "Needs attention",
            systemImage: isComplete ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
        )
        .font(.caption.weight(.semibold))
        .foregroundStyle(isComplete ? MonMonTheme.gain : MonMonTheme.danger)
        .multilineTextAlignment(.trailing)
    }

    private func total(title: LocalizedStringKey, amount: Decimal, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(MonMonTheme.textSecondary)

            Text(VNDCurrency.format(amount))
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func issuesCard(_ issues: [BankStatementIssue]) -> some View {
        card {
            VStack(alignment: .leading, spacing: 12) {
                Label("Needs attention", systemImage: "exclamationmark.triangle.fill")
                    .font(.headline)
                    .foregroundStyle(MonMonTheme.danger)

                Text("MonMon did not silently discard uncertain statement data.")
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)

                ForEach(Array(issues.enumerated()), id: \.offset) { _, issue in
                    Label(issueMessage(issue), systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)
                }
            }
        }
        .accessibilityIdentifier("import-preview-issues")
    }

    private func candidateRow(_ candidate: BankTransactionCandidate) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: candidate.kind.symbolName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(candidate.kind == .income ? MonMonTheme.gain : MonMonTheme.danger)
                .frame(width: 36, height: 36)
                .background(
                    (candidate.kind == .income ? MonMonTheme.gain : MonMonTheme.danger).opacity(
                        0.16),
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(candidate.note.isEmpty ? "No description" : candidate.note)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MonMonTheme.textPrimary)

                Text(candidate.occurredAt.formatted(candidateDateFormat))
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)

                Text("Reference \(candidate.sourceReference) · Page \(candidate.sourcePage)")
                    .font(.caption2)
                    .foregroundStyle(MonMonTheme.textMuted)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(candidate.kind.signLabel)\(VNDCurrency.format(candidate.amount))")
                    .font(.subheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(
                        candidate.kind == .income ? MonMonTheme.gain : MonMonTheme.danger
                    )

                Text(candidate.kind.displayName)
                    .font(.caption2)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
        .padding(14)
        .background(MonMonTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("import-candidate-\(candidate.id)")
    }

    private var candidateDateFormat: Date.FormatStyle {
        Date.FormatStyle(date: .abbreviated, time: .shortened).locale(locale)
    }

    private func issueMessage(_ issue: BankStatementIssue) -> LocalizedStringKey {
        switch issue {
        case .ambiguousAmount(let page, let row):
            "Page \(page), row \(row): amount direction is ambiguous."
        case .invalidRow(let page, let row):
            "Page \(page), row \(row): transaction data is invalid."
        case .totalsMismatch:
            "Parsed totals do not match the totals printed by the bank."
        }
    }

    private func bankName(_ bank: BankStatementBank) -> String {
        switch bank {
        case .tpBank:
            "TPBank"
        }
    }

    private func period(_ range: ClosedRange<Date>) -> String {
        let format = Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale)
        return "\(range.lowerBound.formatted(format)) – \(range.upperBound.formatted(format))"
    }

    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MonMonTheme.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(MonMonTheme.border, lineWidth: 1)
            }
    }

    private func removeStatement() {
        isRemoving = true
        Task {
            let removed = await inbox.remove(staged)
            isRemoving = false
            if removed {
                dismiss()
            }
        }
    }
}
