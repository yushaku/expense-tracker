import SwiftData
import SwiftUI

struct BudgetConfigurationView: View {
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \BudgetJar.createdAt, order: .forward)
    private var jars: [BudgetJar]

    @Query(sort: \TransactionCategory.createdAt, order: .forward)
    private var categories: [TransactionCategory]

    @State private var editorMode: BudgetJarEditorMode?

    var body: some View {
        #if os(macOS)
            content
                .frame(minWidth: 500, minHeight: 640)
        #else
            content
        #endif
    }

    private var content: some View {
        NavigationStack {
            ZStack {
                MonMonTheme.canvas
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: MonMonTheme.contentSpacing) {
                        allocationCard
                        jarsSection

                        if !expenseCategories.isEmpty {
                            categoryMappingSection
                        }
                    }
                    .frame(maxWidth: 640)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Budget setup")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Add Jar", systemImage: "plus") {
                        editorMode = .add
                    }
                    .accessibilityIdentifier("budget-add-jar")
                }
            }
            .appSheet(item: $editorMode) { mode in
                BudgetJarEditorView(mode: mode)
            }
            .tint(MonMonTheme.accent)
            .foregroundStyle(MonMonTheme.textPrimary)
            .preferredColorScheme(MonMonTheme.colorScheme)
        }
    }

    private var allocationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Monthly allocation", systemImage: "chart.pie.fill")
                .font(.headline)

            HStack(alignment: .firstTextBaseline) {
                Text("\(PercentInput.format(allocationTotal))% assigned")
                    .font(.title3.weight(.semibold))

                Spacer()

                Text("\(PercentInput.format(unallocatedPercent))% free")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MonMonTheme.textSecondary)
            }

            ProgressView(value: allocationProgress)
                .tint(MonMonTheme.accent)

            Text("Your jar percentages can total less than 100%. The rest stays unallocated.")
                .font(.caption)
                .foregroundStyle(MonMonTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(MonMonTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("budget-allocation-summary")
    }

    private var jarsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Jars", systemImage: "shippingbox.fill")

            ForEach(jars) { jar in
                Button {
                    editorMode = .edit(jar)
                } label: {
                    jarRow(jar)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("budget-jar-\(jar.id.uuidString)")
                .accessibilityHint("Opens this jar for editing.")
            }
        }
    }

    private var categoryMappingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Category mapping", systemImage: "arrow.triangle.branch")

            Text("Each expense keeps its category. This mapping decides which jar pays for it.")
                .font(.subheadline)
                .foregroundStyle(MonMonTheme.textSecondary)

            VStack(spacing: 0) {
                ForEach(expenseCategories) { category in
                    BudgetCategoryMappingRow(category: category, jars: jars)

                    if category.id != expenseCategories.last?.id {
                        Divider()
                            .overlay(MonMonTheme.border)
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(MonMonTheme.surface, in: RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(MonMonTheme.border, lineWidth: 1)
            }
        }
    }

    private func jarRow(_ jar: BudgetJar) -> some View {
        HStack(spacing: 14) {
            Image(systemName: CategoryPalette.symbolName(jar.symbolName))
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(CategoryPalette.color(named: jar.colorName))
                .frame(width: 44, height: 44)
                .background(
                    CategoryPalette.color(named: jar.colorName).opacity(0.16),
                    in: RoundedRectangle(cornerRadius: 13)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(jar.name)
                        .font(.headline)

                    if jar.isProtected {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(MonMonTheme.textMuted)
                            .accessibilityLabel("Protected jar")
                    }
                }

                Text(jar.isProtected ? "System routing" : "Custom routing")
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }

            Spacer(minLength: 12)

            Text("\(PercentInput.format(jar.allocationPercent))%")
                .font(.headline.monospacedDigit())

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(MonMonTheme.textMuted)
                .accessibilityHidden(true)
        }
        .padding(16)
        .background(MonMonTheme.surface, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(MonMonTheme.border, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private func sectionHeader(_ title: LocalizedStringKey, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.title3.weight(.semibold))
    }

    private var expenseCategories: [TransactionCategory] {
        categories.filter { $0.kind == .expense }
    }

    private var allocationTotal: Decimal {
        jars.reduce(Decimal.zero) { $0 + $1.allocationPercent }
    }

    private var unallocatedPercent: Decimal {
        max(0, 100 - allocationTotal)
    }

    private var allocationProgress: Double {
        min(1, NSDecimalNumber(decimal: allocationTotal).doubleValue / 100)
    }
}

private struct BudgetCategoryMappingRow: View {
    @Environment(\.modelContext) private var modelContext

    @Bindable var category: TransactionCategory
    let jars: [BudgetJar]

    @State private var saveFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Label {
                    Text(category.name)
                        .lineLimit(2)
                } icon: {
                    Image(systemName: CategoryPalette.symbolName(category.symbolName))
                        .foregroundStyle(CategoryPalette.color(named: category.colorName))
                }

                Spacer(minLength: 8)

                Picker("Jar", selection: $category.budgetJarID) {
                    Text("Default jar")
                        .tag(UUID?.none)

                    ForEach(jars) { jar in
                        Text(jar.name)
                            .tag(Optional(jar.id))
                    }
                }
                .labelsHidden()
                .accessibilityLabel("Jar for \(category.name)")
                .accessibilityIdentifier("budget-category-jar-\(category.id.uuidString)")
                .onChange(of: category.budgetJarID) {
                    saveMapping()
                }
            }

            if saveFailed {
                Text("Couldn’t save this mapping. Try again.")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.danger)
            }
        }
        .padding(.vertical, 12)
    }

    private func saveMapping() {
        saveFailed = false

        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            saveFailed = true
        }
    }
}

#if DEBUG
    #Preview("Budget setup") {
        let container = PreviewData.populated
        BudgetJarSeed.seedIfNeeded(
            in: container.mainContext,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            locale: Locale(identifier: "en")
        )
        return BudgetConfigurationView()
            .modelContainer(container)
    }
#endif
