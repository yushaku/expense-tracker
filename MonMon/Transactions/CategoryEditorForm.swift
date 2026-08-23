import SwiftUI

struct CategoryEditorForm: View {
    @Binding var draft: CategoryDraft

    let isEditing: Bool
    let usageCount: Int
    let canDelete: Bool
    let deleteBlockedReason: String?
    let validationError: CategoryFormError?
    let saveErrorMessage: String?
    let onDelete: () -> Void

    private let symbolColumns = [GridItem(.adaptive(minimum: 52), spacing: 10)]
    private let colorColumns = [GridItem(.adaptive(minimum: 44), spacing: 10)]

    var body: some View {
        ZStack {
            MonMonTheme.canvas
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                    introduction
                    detailsCard
                    styleCard

                    if let saveErrorMessage {
                        errorBanner(saveErrorMessage)
                    }

                    if isEditing {
                        deleteSection
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
            Image(systemName: CategoryPalette.symbolName(draft.symbolName))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(MonMonTheme.onAccent)
                .frame(width: 46, height: 46)
                .background(
                    CategoryPalette.color(named: draft.colorName),
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(isEditing ? "Restyle this category" : "Name a kind of money")
                    .font(.title3.weight(.semibold))

                Text("Categories group what you spend and what you earn.")
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private var detailsCard: some View {
        card {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader("Category", systemImage: "tag.fill")

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Name")

                    TextField("Food", text: $draft.name)
                        .textFieldStyle(.plain)
                        .padding(14)
                        .background(
                            MonMonTheme.field,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .accessibilityIdentifier("category-name")

                    if let nameErrorMessage {
                        validationMessage(nameErrorMessage, id: "category-name-error")
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    fieldLabel("Direction")

                    Picker("Direction", selection: $draft.kind) {
                        ForEach(TransactionKind.allCases, id: \.rawValue) {
                            Text($0.displayName)
                                .tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .accessibilityIdentifier("category-kind")

                    Text("An expense category cannot be picked for income, and back.")
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)
                }
            }
        }
    }

    private var styleCard: some View {
        card {
            VStack(alignment: .leading, spacing: 18) {
                sectionHeader("Style", systemImage: "paintpalette.fill")

                VStack(alignment: .leading, spacing: 10) {
                    fieldLabel("Symbol")

                    LazyVGrid(columns: symbolColumns, spacing: 10) {
                        ForEach(CategoryPalette.symbolNames, id: \.self) { symbolName in
                            symbolButton(symbolName)
                        }
                    }
                    .accessibilityIdentifier("category-symbol")
                }

                VStack(alignment: .leading, spacing: 10) {
                    fieldLabel("Colour")

                    LazyVGrid(columns: colorColumns, spacing: 10) {
                        ForEach(CategoryPalette.colorNames, id: \.self) { colorName in
                            colorButton(colorName)
                        }
                    }
                    .accessibilityIdentifier("category-color")
                }
            }
        }
    }

    private func symbolButton(_ symbolName: String) -> some View {
        let isSelected = draft.symbolName == symbolName

        return Button {
            draft.symbolName = symbolName
        } label: {
            Image(systemName: symbolName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(
                    isSelected ? MonMonTheme.onAccent : MonMonTheme.textSecondary
                )
                .frame(width: 52, height: 44)
                .background(
                    isSelected
                        ? CategoryPalette.color(named: draft.colorName) : MonMonTheme.field,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(symbolName)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func colorButton(_ colorName: String) -> some View {
        let isSelected = draft.colorName == colorName

        return Button {
            draft.colorName = colorName
        } label: {
            Circle()
                .fill(CategoryPalette.color(named: colorName))
                .frame(width: 34, height: 34)
                .overlay {
                    // The tick, not the ring alone, says which colour is chosen.
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(MonMonTheme.onAccent)
                    }
                }
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(colorName)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var deleteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            deleteButton

            if let deleteBlockedReason {
                Text(deleteBlockedReason)
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            } else if usageCount > 0 {
                Text(reassignNotice)
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
    }

    private var reassignNotice: String {
        let noun = usageCount == 1 ? "transaction" : "transactions"
        return "\(usageCount) \(noun) use this category. You will pick where they go."
    }

    private var deleteButton: some View {
        Button(role: .destructive, action: onDelete) {
            Label("Delete category", systemImage: "trash.fill")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(14)
        }
        .buttonStyle(.plain)
        .disabled(!canDelete)
        .foregroundStyle(canDelete ? MonMonTheme.danger : MonMonTheme.textMuted)
        .background(
            (canDelete ? MonMonTheme.danger.opacity(0.14) : MonMonTheme.field),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(
                    canDelete ? MonMonTheme.danger.opacity(0.35) : MonMonTheme.border,
                    lineWidth: 1
                )
        }
        .accessibilityIdentifier("delete-category")
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
        validationMessage(message, id: "save-category-error")
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

    private var nameErrorMessage: String? {
        switch validationError {
        case .emptyName:
            "Enter a category name."
        case .duplicateName:
            "Another \(draft.kind.displayName.lowercased()) category already has this name."
        case nil:
            nil
        }
    }
}
