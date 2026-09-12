import SwiftUI
import WidgetKit

struct QuickExpenseEntry: TimelineEntry {
    let date: Date
    let presets: [QuickExpensePreset]
    let feedback: QuickExpenseFeedback?
    var today: WidgetTodayExpenses? = nil
}

struct QuickExpenseProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickExpenseEntry {
        QuickExpenseEntry(
            date: .now,
            presets: QuickExpenseConfiguration.defaults.activePresets,
            feedback: nil
        )
    }

    func getSnapshot(
        in context: Context,
        completion: @escaping (QuickExpenseEntry) -> Void
    ) {
        completion(currentEntry)
    }

    func getTimeline(
        in context: Context,
        completion: @escaping (Timeline<QuickExpenseEntry>) -> Void
    ) {
        let entry = currentEntry
        var entries = [entry]
        if let feedback = entry.feedback {
            entries.append(
                QuickExpenseEntry(
                    date: feedback.expirationDate,
                    presets: entry.presets,
                    feedback: nil,
                    today: WidgetTodayExpensesStore().load(at: feedback.expirationDate)
                )
            )
        }
        // A dated entry clears yesterday even if the app stays closed overnight.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Ho_Chi_Minh") ?? .gmt
        let tomorrow =
            calendar.date(
                byAdding: .day, value: 1, to: calendar.startOfDay(for: entry.date))
            ?? entry.date.addingTimeInterval(86_400)
        entries.append(
            QuickExpenseEntry(
                date: tomorrow, presets: entry.presets, feedback: nil,
                today: WidgetTodayExpensesStore().load(at: tomorrow)))
        completion(
            Timeline(entries: entries.sorted { $0.date < $1.date }, policy: .after(tomorrow)))
    }

    private var currentEntry: QuickExpenseEntry {
        let now = Date.now
        return QuickExpenseEntry(
            date: now,
            presets: QuickExpensePresetStore().load().activePresets,
            feedback: QuickExpenseFeedbackStore().latestSuccess(at: now),
            today: WidgetTodayExpensesStore().load(at: now)
        )
    }
}

struct QuickExpenseWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: QuickExpenseEntry

    var body: some View {
        Group {
            if family == .systemLarge {
                VStack(spacing: 8) {
                    todayExpenses
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    Rectangle()
                        .fill(MonMonTheme.border)
                        .frame(height: 1)
                    quickExpenseGrid
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                }
            } else if family == .systemMedium {
                quickExpenseGrid
            } else {
                VStack(spacing: 5) {
                    presetButtons
                }
            }
        }
        .containerBackground(for: .widget) {
            MonMonTheme.canvas
        }
    }

    private var quickExpenseGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Quick Expense", systemImage: "bolt.fill")
                .font(.headline)
                .foregroundStyle(MonMonTheme.accent)
            LazyVGrid(columns: columns, spacing: family == .systemLarge ? 5 : 8) {
                presetButtons
            }
        }
    }

    private var expensesURL: URL? {
        let scheme =
            Bundle.main.object(forInfoDictionaryKey: "MonMonQuickCaptureURLScheme") as? String
        return URL(string: "\(scheme ?? "monmon")://expenses")
    }

    private var todayExpenses: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text("Today’s expenses")
                    .font(.headline)
                Spacer(minLength: 4)
                if let today = entry.today {
                    Text(VNDCurrency.format(today.total))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MonMonTheme.accent)
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                }
            }
            .lineLimit(1)
            if let today = entry.today {
                if today.count == 0 {
                    Text("No expenses today")
                        .font(.caption)
                        .foregroundStyle(MonMonTheme.textSecondary)
                } else {
                    ForEach(today.expenses) { expense in
                        HStack {
                            Text(expense.title)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text(VNDCurrency.format(expense.amount))
                                .monospacedDigit()
                                .fixedSize()
                        }
                        .font(.caption)
                        .lineLimit(1)
                        .accessibilityElement(children: .combine)
                    }
                    if today.count > today.expenses.count, let expensesURL {
                        Link(destination: expensesURL) {
                            Text("\(today.count - today.expenses.count) more · Open app")
                                .font(.caption2)
                                .foregroundStyle(MonMonTheme.accent)
                        }
                    }
                }
            } else {
                Text("Open MonMon to load today’s expenses")
                    .font(.caption)
                    .foregroundStyle(MonMonTheme.textSecondary)
            }
        }
        .foregroundStyle(MonMonTheme.textPrimary)
        .privacySensitive()
    }

    @ViewBuilder
    private var presetButtons: some View {
        ForEach(visiblePresets) { preset in
            QuickExpenseButton(
                preset: preset,
                showsSuccess: entry.feedback?.slot == preset.slot
            )
        }
    }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: 8),
            count: QuickExpenseWidgetLayout.columns(visible: visiblePresets.count, size: size)
        )
    }

    /// As many of the owner's presets as this size holds. They choose how many
    /// to keep; the size only says how many fit.
    private var visiblePresets: [QuickExpensePreset] {
        Array(entry.presets.prefix(QuickExpenseWidgetLayout.capacity(size)))
    }

    /// The one place WidgetKit's families meet the layout, so the maths stays
    /// testable without a widget host.
    private var size: QuickExpenseWidgetLayout.Size {
        switch family {
        case .systemMedium:
            .medium
        case .systemLarge:
            .large
        default:
            .small
        }
    }
}

private struct QuickExpenseButton: View {
    let preset: QuickExpensePreset
    let showsSuccess: Bool

    var body: some View {
        Button(intent: RecordQuickExpenseIntent(slot: preset.slot)) {
            HStack(spacing: 6) {
                if showsSuccess {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body.weight(.semibold))
                } else {
                    Text(preset.symbol)
                        .font(.body.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Group {
                    if showsSuccess {
                        Text("Saved")
                    } else {
                        Text(VNDCurrency.format(preset.amount))
                    }
                }
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 38)
            .padding(.horizontal, 6)
            .background(MonMonTheme.surface, in: .rect(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(MonMonTheme.border, lineWidth: 1)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .foregroundStyle(showsSuccess ? MonMonTheme.accent : MonMonTheme.textPrimary)
        .invalidatableContent()
        .accessibilityLabel(Text(accessibilityLabel))
    }

    private var accessibilityLabel: LocalizedStringResource {
        if showsSuccess {
            return "Saved \(preset.symbol) expense to MonMon"
        }
        return "Record \(preset.symbol) expense for \(VNDCurrency.formatPlain(preset.amount)) đồng"
    }
}

@main
struct MonMonQuickExpenseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: QuickExpenseWidgetConfiguration.kind,
            provider: QuickExpenseProvider()
        ) { entry in
            QuickExpenseWidgetView(entry: entry)
        }
        .configurationDisplayName("Quick Expense")
        .description("Record one of your configured preset expenses with one tap.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
