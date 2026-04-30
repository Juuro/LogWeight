import WidgetKit
import SwiftUI
import HealthKit
import LogWeightCore

/// Lock Screen / Smart Stack complication: latest body mass from Apple Health (read-only).
struct BodyMassComplication: Widget {
    let kind: String = "LogWeightBodyMass"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BodyMassTimelineProvider()) { entry in
            BodyMassComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Body weight")
        .description("Shows your latest weight from Apple Health on this Apple Watch.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryInline,
            .accessoryRectangular
        ])
    }
}

struct BodyMassEntry: TimelineEntry {
    let date: Date
    /// Short string for the complication (e.g. `75.2 kg`); `"—"` when unknown.
    let displayText: String
}

struct BodyMassTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> BodyMassEntry {
        BodyMassEntry(date: Date(), displayText: "—")
    }

    func getSnapshot(in context: Context, completion: @escaping (BodyMassEntry) -> Void) {
        completion(BodyMassEntry(date: Date(), displayText: "—"))
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<BodyMassEntry>) -> Void) {
        Task {
            let entry = await Self.loadEntry()
            // Refresh periodically; saves also call `WidgetCenter.reloadAllTimelines()` from the watch app.
            let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
            completion(Timeline(entries: [entry], policy: .after(next)))
        }
    }

    private static func loadEntry() async -> BodyMassEntry {
        let store = HKHealthStoreAdapter()
        guard HKHealthStore.isHealthDataAvailable() else {
            return BodyMassEntry(date: Date(), displayText: "—")
        }
        guard let weights = try? await store.recentWeights(limit: 1), let w = weights.first else {
            return BodyMassEntry(date: Date(), displayText: "—")
        }
        let unit: WeightUnit = Locale.current.measurementSystem == .metric ? .kilograms : .pounds
        let formatter = WeightFormatter(locale: .current, fractionDigits: 1)
        let text = formatter.format(kilograms: w.valueInKilograms, in: unit)
        return BodyMassEntry(date: w.recordedAt, displayText: text)
    }
}

struct BodyMassComplicationView: View {
    @Environment(\.widgetFamily) private var family
    var entry: BodyMassEntry

    var body: some View {
        switch family {
        case .accessoryCircular, .accessoryCorner:
            ZStack {
                AccessoryWidgetBackground()
                Text(entry.displayText)
                    .font(.system(.headline, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        case .accessoryInline:
            Text("Weight \(entry.displayText)")
        case .accessoryRectangular:
            HStack {
                Image(systemName: "scalemass")
                Text(entry.displayText)
                    .font(.headline)
                Spacer(minLength: 0)
            }
        default:
            Text(entry.displayText)
        }
    }
}

#if DEBUG
#Preview(as: .accessoryCircular) {
    BodyMassComplication()
} timeline: {
    BodyMassEntry(date: .now, displayText: "75.0 kg")
}
#endif
