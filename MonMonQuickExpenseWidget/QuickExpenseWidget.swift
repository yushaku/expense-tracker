import SwiftUI
import WidgetKit

struct QuickExpenseEntry: TimelineEntry {
    let date: Date
    let presets: [QuickExpensePreset]
}

struct QuickExpenseProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickExpenseEntry {
        QuickExpenseEntry(date: .now, presets: QuickExpenseConfiguration.defaults.activePresets)
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
        completion(Timeline(entries: [currentEntry], policy: .never))
    }

    private var currentEntry: QuickExpenseEntry {
        QuickExpenseEntry(date: .now, presets: QuickExpensePresetStore().load().activePresets)
    }
}

struct QuickExpenseWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: QuickExpenseEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if family != .systemSmall {
                Label("Quick Expense", systemImage: "bolt.fill")
                    .font(.headline)
                    .foregroundStyle(.tint)

                LazyVGrid(columns: columns, spacing: 8) {
                    presetButtons
                }
            } else {
                VStack(spacing: 5) {
                    presetButtons
                }
            }
        }
        .containerBackground(for: .widget) {
            Color(uiColor: .systemBackground)
        }
    }

    @ViewBuilder
    private var presetButtons: some View {
        ForEach(visiblePresets) { preset in
            QuickExpenseButton(preset: preset)
        }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
    }

    private var visiblePresets: [QuickExpensePreset] {
        Array(entry.presets.prefix(maximumPresetCount))
    }

    private var maximumPresetCount: Int {
        switch family {
        case .systemSmall:
            3
        case .systemMedium:
            6
        case .systemLarge:
            9
        default:
            3
        }
    }
}

private struct QuickExpenseButton: View {
    let preset: QuickExpensePreset

    var body: some View {
        Button(intent: RecordQuickExpenseIntent(slot: preset.slot)) {
            HStack(spacing: 6) {
                Text(preset.symbol)
                    .font(.title3)
                Text(VNDCurrency.format(preset.amount))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 38)
            .padding(.horizontal, 6)
            .background(.secondary.opacity(0.12), in: .rect(cornerRadius: 10))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "Record \(preset.symbol) expense for \(VNDCurrency.formatPlain(preset.amount)) đồng"
        )
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
