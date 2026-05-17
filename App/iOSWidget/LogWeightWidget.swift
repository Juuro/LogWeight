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
        SharedWeightEntryStore.expireStaleDraftIfNeeded()
        return LogWeightWidgetEntry(
            date: .now,
            currentWeightInKilograms: SharedWeightEntryStore.loadCurrentValue()
        )
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
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct LogWeightWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LogWeightWidgetEntry

    private var formatter: WeightFormatter {
        WeightFormatter(locale: .current, fractionDigits: 1)
    }

    private var formattedWeight: String {
        formatter.format(kilograms: entry.currentWeightInKilograms, in: .kilograms)
    }

    var body: some View {
        switch family {
        case .systemSmall:
            smallLayout
        default:
            mediumLayout
        }
    }

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 16) {
            weightHeader(
                iconFont: .system(size: 26, weight: .semibold),
                valueFont: .system(size: 36, weight: .semibold, design: .rounded),
                minimumScaleFactor: 0.7
            )

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                stepperButtons(buttonSize: 36, expandSteppers: false)

                Spacer(minLength: 0)

                saveButton(height: 36, expandWidth: false)
            }
        }
        .padding()
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            weightHeader(
                iconFont: .system(size: 18, weight: .semibold),
                valueFont: .system(size: 22, weight: .semibold, design: .rounded),
                minimumScaleFactor: 0.65
            )

            stepperButtons(buttonSize: 32, expandSteppers: true)

            saveButton(height: 32, expandWidth: true)
        }
        .padding(10)
    }

    private func weightHeader(
        iconFont: Font,
        valueFont: Font,
        minimumScaleFactor: CGFloat
    ) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: "scalemass")
                .font(iconFont)
                .foregroundStyle(.secondary)

            Text(formattedWeight)
                .font(valueFont)
                .lineLimit(1)
                .minimumScaleFactor(minimumScaleFactor)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(formattedWeight)
    }

    private func stepperButtons(buttonSize: CGFloat, expandSteppers: Bool) -> some View {
        HStack(spacing: expandSteppers ? 8 : 12) {
            Button(intent: DecrementWeightIntent()) {
                Image(systemName: "minus")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: expandSteppers ? .infinity : nil)
                    .frame(width: expandSteppers ? nil : buttonSize, height: buttonSize)
            }
            .buttonStyle(.bordered)

            Button(intent: IncrementWeightIntent()) {
                Image(systemName: "plus")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: expandSteppers ? .infinity : nil)
                    .frame(width: expandSteppers ? nil : buttonSize, height: buttonSize)
            }
            .buttonStyle(.bordered)
        }
    }

    private func saveButton(height: CGFloat, expandWidth: Bool) -> some View {
        Button(intent: SaveWeightIntent()) {
            Text("Save")
                .font(expandWidth ? .subheadline.weight(.semibold) : .body.weight(.semibold))
                .frame(maxWidth: expandWidth ? .infinity : nil)
                .frame(height: height)
        }
        .buttonStyle(.borderedProminent)
    }
}

@main
struct LogWeightWidgetBundle: WidgetBundle {
    var body: some Widget {
        LogWeightWidgetConfig()
        LogWeightChartWidgetConfig()
    }
}

#if DEBUG
#Preview(as: .systemSmall) {
    LogWeightWidgetConfig()
} timeline: {
    LogWeightWidgetEntry(date: .now, currentWeightInKilograms: 72.3)
}

#Preview(as: .systemMedium) {
    LogWeightWidgetConfig()
} timeline: {
    LogWeightWidgetEntry(date: .now, currentWeightInKilograms: 72.3)
}
#endif
