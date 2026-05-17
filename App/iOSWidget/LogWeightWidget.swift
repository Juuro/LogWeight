import WidgetKit
import SwiftUI
import LogWeightCore

struct LogWeightWidgetEntry: TimelineEntry {
    let date: Date
    let currentWeightInKilograms: Double
}

struct LogWeightWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> LogWeightWidgetEntry {
        LogWeightWidgetEntry(date: .now, currentWeightInKilograms: 75.0)
    }

    func getSnapshot(in context: Context, completion: @escaping (LogWeightWidgetEntry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LogWeightWidgetEntry>) -> Void) {
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        completion(Timeline(entries: [makeEntry()], policy: .after(nextRefresh)))
    }

    private func makeEntry() -> LogWeightWidgetEntry {
        LogWeightWidgetEntry(date: .now, currentWeightInKilograms: SharedWeightEntryStore.loadCurrentValue())
    }
}

struct LogWeightWidgetConfig: Widget {
    let kind: String = LogWeightWidgetConstants.kind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LogWeightWidgetProvider()) { entry in
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
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "scalemass")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(formatter.format(kilograms: entry.currentWeightInKilograms, in: .kilograms))
                    .font(.system(size: 36, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(formatter.format(kilograms: entry.currentWeightInKilograms, in: .kilograms))

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Button(intent: DecrementWeightIntent()) {
                    Image(systemName: "minus")
                        .font(.body.weight(.semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.bordered)

                Button(intent: IncrementWeightIntent()) {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.bordered)

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
        LogWeightChartWidgetConfig()
    }
}

#Preview(as: .systemMedium) {
    LogWeightWidgetConfig()
} timeline: {
    LogWeightWidgetEntry(date: .now, currentWeightInKilograms: 72.3)
}
