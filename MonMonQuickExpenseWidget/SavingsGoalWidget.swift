import AppIntents
import SwiftUI
import WidgetKit

struct SavingsGoalEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Savings goal"
    static let defaultQuery = SavingsGoalQuery()
    let id: UUID
    let name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct SavingsGoalQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [SavingsGoalEntity] {
        GoalWidgetStore().load().filter { identifiers.contains($0.id) && !$0.isArchived }
            .map { SavingsGoalEntity(id: $0.id, name: $0.name) }
    }

    func suggestedEntities() async throws -> [SavingsGoalEntity] {
        GoalWidgetStore().load().filter { !$0.isArchived }
            .map { SavingsGoalEntity(id: $0.id, name: $0.name) }
    }
}

struct SelectSavingsGoalIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Savings goal"
    static let description = IntentDescription("Choose the goal you want to keep in sight.")
    @Parameter(title: "Goal") var goal: SavingsGoalEntity?
}

struct SavingsGoalEntry: TimelineEntry {
    let date: Date
    let goal: GoalWidgetSnapshot?
    let hasSelection: Bool
}

struct SavingsGoalProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SavingsGoalEntry {
        SavingsGoalEntry(date: .now, goal: .preview, hasSelection: true)
    }

    func snapshot(for configuration: SelectSavingsGoalIntent, in context: Context) async
        -> SavingsGoalEntry
    {
        if context.isPreview { return placeholder(in: context) }
        return entry(for: configuration)
    }

    func timeline(for configuration: SelectSavingsGoalIntent, in context: Context) async
        -> Timeline<SavingsGoalEntry>
    {
        Timeline(entries: [entry(for: configuration)], policy: .never)
    }

    private func entry(for configuration: SelectSavingsGoalIntent) -> SavingsGoalEntry {
        SavingsGoalEntry(
            date: .now, goal: GoalWidgetStore().selected(id: configuration.goal?.id),
            hasSelection: configuration.goal != nil)
    }
}

struct SavingsGoalWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SavingsGoalEntry

    var body: some View {
        Group {
            if let goal = entry.goal {
                if family == .systemSmall {
                    small(goal)
                } else {
                    medium(goal)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "flag.checkered")
                        .font(.title2)
                        .foregroundStyle(MonMonTheme.accent)
                    Text(entry.hasSelection ? "Goal unavailable" : "Choose a savings goal")
                        .font(.headline)
                    Text("Open MonMon to refresh goals, then choose one in Edit Widget.")
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)
                }
            }
        }
        .foregroundStyle(MonMonTheme.textPrimary)
        .containerBackground(MonMonTheme.canvas, for: .widget)
        .widgetURL(goalURL)
        .privacySensitive()
    }

    private var goalURL: URL? {
        guard let goal = entry.goal,
            let scheme = Bundle.main.object(forInfoDictionaryKey: "MonMonQuickCaptureURLScheme")
                as? String
        else { return nil }
        return URL(string: "\(scheme)://goal/\(goal.id.uuidString)")
    }

    private func small(_ goal: GoalWidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            title(goal)
            Spacer(minLength: 0)
            Text(goal.progress, format: .percent.precision(.fractionLength(0)))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(CategoryPalette.color(named: goal.colorName))
                .minimumScaleFactor(0.7)
            progress(goal)
            Group {
                if goal.isComplete {
                    Text("Goal reached")
                } else {
                    Text("\(VNDCurrency.format(goal.remainingAmount)) to go")
                }
            }
            .font(.caption)
            .foregroundStyle(MonMonTheme.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
    }

    private func medium(_ goal: GoalWidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                title(goal)
                Spacer(minLength: 4)
                Text(goal.progress, format: .percent.precision(.fractionLength(0)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(CategoryPalette.color(named: goal.colorName))
            }
            HStack(alignment: .firstTextBaseline) {
                Text(VNDCurrency.format(goal.earmarkedAmount))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(CategoryPalette.color(named: goal.colorName))
                Text("/ \(VNDCurrency.format(goal.targetAmount))")
                    .font(.subheadline)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            progress(goal)
            if goal.isComplete {
                Label("Goal reached", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CategoryPalette.color(named: goal.colorName))
            } else if let milestone = goal.nextMilestonePercent,
                let amount = goal.amountToNextMilestone
            {
                Text("\(VNDCurrency.format(amount)) to reach \(milestone)%")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }

    private func title(_ goal: GoalWidgetSnapshot) -> some View {
        Label(goal.name, systemImage: goal.isComplete ? "checkmark.circle.fill" : goal.symbolName)
            .font(.headline)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private func progress(_ goal: GoalWidgetSnapshot) -> some View {
        ProgressView(value: goal.progress)
            .tint(CategoryPalette.color(named: goal.colorName))
            .accessibilityLabel("Goal progress")
            .accessibilityValue(Text(goal.progress, format: .percent.precision(.fractionLength(0))))
    }
}

struct SavingsGoalWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: GoalWidgetStore.kind, intent: SelectSavingsGoalIntent.self,
            provider: SavingsGoalProvider()
        ) { entry in
            SavingsGoalWidgetView(entry: entry)
        }
        .configurationDisplayName("Savings goal")
        .description("Keep your goal and next milestone in sight.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

extension GoalWidgetSnapshot {
    static let preview = GoalWidgetSnapshot(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID(),
        name: "Japan trip", targetAmount: 50_000_000, earmarkedAmount: 30_000_000,
        symbolName: "airplane", colorName: "mauve", isArchived: false)
}

#Preview(as: .systemSmall) {
    SavingsGoalWidget()
} timeline: {
    SavingsGoalEntry(date: .now, goal: .preview, hasSelection: true)
}

#Preview(as: .systemMedium) {
    SavingsGoalWidget()
} timeline: {
    SavingsGoalEntry(date: .now, goal: .preview, hasSelection: true)
}
