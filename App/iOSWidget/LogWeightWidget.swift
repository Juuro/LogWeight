import WidgetKit
import SwiftUI
import AppIntents
import LogWeightCore

struct LogWeightWidgetConfigIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "LogWeight Widget"
    static var description = IntentDescription("Adjust and save your latest body weight directly from the Home Screen widget.")
}

struct IncrementWeightIntent: AppIntent {
    static var title: LocalizedStringResource = "Increase Weight"
    static var openAppWhenRun = false

    @Parameter(title: "Step (kg)")
    var stepInKilograms: Double

    init() {
        self.stepInKilograms = SharedWeightEntryStore.defaultStepInKilograms
    }

    init(stepInKilograms: Double) {
        self.stepInKilograms = stepInKilograms
    }

    func perform() async throws -> some IntentResult {
        // Read/write shared widget state in the App Group container.
        _ = SharedWeightEntryStore.increment(stepInKilograms: stepInKilograms)
        // Trigger a timeline reload so the updated value is re-rendered immediately.
        WidgetCenter.shared.reloadTimelines(ofKind: LogWeightWidgetConstants.kind)
        return .result()
    }
}

struct DecrementWeightIntent: AppIntent {
    static var title: LocalizedStringResource = "Decrease Weight"
    static var openAppWhenRun = false

    @Parameter(title: "Step (kg)")
    var stepInKilograms: Double

    init() {
        self.stepInKilograms = SharedWeightEntryStore.defaultStepInKilograms
    }

    init(stepInKilograms: Double) {
        self.stepInKilograms = stepInKilograms
    }

    func perform() async throws -> some IntentResult {
        // Read/write shared widget state in the App Group container.
        _ = SharedWeightEntryStore.decrement(stepInKilograms: stepInKilograms)
        // Trigger a timeline reload so the updated value is re-rendered immediately.
        WidgetCenter.shared.reloadTimelines(ofKind: LogWeightWidgetConstants.kind)
        return .result()
    }
}

struct SaveWeightIntent: AppIntent {
    static var title: LocalizedStringResource = "Save Weight"
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult {
        let value = SharedWeightEntryStore.loadCurrentValue()
        // Persist the new latest weight in App Group shared storage.
        SharedWeightEntryStore.save(WeightEntry(value: value, date: .now))
        SharedWeightEntryStore.clearDraftValue()
        // Trigger a timeline reload so the latest saved value is shown.
        WidgetCenter.shared.reloadTimelines(ofKind: LogWeightWidgetConstants.kind)
        return .result()
    }
}

struct LogWeightWidgetEntry: TimelineEntry {
    let date: Date
    let currentWeightInKilograms: Double
}

struct LogWeightWidgetProvider: AppIntentTimelineProvider {
    typealias Intent = LogWeightWidgetConfigIntent
    typealias Entry = LogWeightWidgetEntry

    func placeholder(in context: Context) -> LogWeightWidgetEntry {
        LogWeightWidgetEntry(date: .now, currentWeightInKilograms: 75.0)
    }

    func snapshot(for configuration: LogWeightWidgetConfigIntent, in context: Context) async -> LogWeightWidgetEntry {
        LogWeightWidgetEntry(date: .now, currentWeightInKilograms: SharedWeightEntryStore.loadCurrentValue())
    }

    func timeline(for configuration: LogWeightWidgetConfigIntent, in context: Context) async -> Timeline<LogWeightWidgetEntry> {
        // Read the latest shared value for the widget timeline entry.
        let entry = LogWeightWidgetEntry(date: .now, currentWeightInKilograms: SharedWeightEntryStore.loadCurrentValue())
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }
}

struct LogWeightWidgetConfig: Widget {
    let kind: String = LogWeightWidgetConstants.kind

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: LogWeightWidgetConfigIntent.self, provider: LogWeightWidgetProvider()) { entry in
            LogWeightWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Log Weight")
        .description("Adjust with +/− and save your latest weight without opening the app.")
        .supportedFamilies([.systemMedium])
    }
}

struct LogWeightWidgetView: View {
    let entry: LogWeightWidgetEntry

    private var formatter: WeightFormatter {
        WeightFormatter(locale: .current, fractionDigits: 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Last: \(formatter.format(kilograms: entry.currentWeightInKilograms, in: .kilograms))")
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Button(intent: DecrementWeightIntent()) {
                    Label("−", systemImage: "minus")
                }
                .buttonStyle(.bordered)
                .labelStyle(.iconOnly)

                Button(intent: IncrementWeightIntent()) {
                    Label("+", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .labelStyle(.iconOnly)

                Spacer(minLength: 0)

                Button(intent: SaveWeightIntent()) {
                    Text("Save")
                        .font(.headline)
                        .frame(minWidth: 84)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

@main
struct LogWeightWidgetBundle: WidgetBundle {
    var body: some Widget {
        LogWeightWidgetConfig()
    }
}

#Preview(as: .systemMedium) {
    LogWeightWidgetConfig()
} timeline: {
    LogWeightWidgetEntry(date: .now, currentWeightInKilograms: 72.3)
}
