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

/// Structured display fields for accessory layouts (number large, unit small).
struct ComplicationWeightDisplay: Sendable {
    let valueText: String
    let unitText: String
    let fullText: String
    let hasData: Bool

    /// Compact label for corner complications (value + unit, no extra spacing).
    var cornerLabel: String {
        guard hasData else { return "—" }
        return "\(valueText)\(unitText)"
    }

    static let empty = ComplicationWeightDisplay(
        valueText: "—",
        unitText: "",
        fullText: "No weight",
        hasData: false
    )
}

struct BodyMassEntry: TimelineEntry {
    let date: Date
    let display: ComplicationWeightDisplay
}

struct BodyMassTimelineProvider: TimelineProvider {

    func placeholder(in context: Context) -> BodyMassEntry {
        BodyMassEntry(date: Date(), display: Self.previewDisplay())
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (BodyMassEntry) -> Void) {
        if context.isPreview {
            completion(BodyMassEntry(date: Date(), display: Self.previewDisplay()))
            return
        }
        Task {
            completion(await Self.loadEntry())
        }
    }

    /// Sample display used by the complication picker so the slot is never empty.
    private static func previewDisplay() -> ComplicationWeightDisplay {
        let unit: WeightUnit = Locale.current.measurementSystem == .metric ? .kilograms : .pounds
        let sample = unit == .kilograms ? 75.0 : 165.0
        return makeDisplay(kilograms: unit == .kilograms ? sample : sample / 2.20462,
                           unit: unit,
                           locale: .current)
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
            return BodyMassEntry(date: Date(), display: .empty)
        }
        guard let weights = try? await store.recentWeights(limit: 1), let w = weights.first else {
            return BodyMassEntry(date: Date(), display: .empty)
        }
        let unit = Self.preferredUnit()
        let display = Self.makeDisplay(kilograms: w.valueInKilograms, unit: unit, locale: .current)
        return BodyMassEntry(date: w.recordedAt, display: display)
    }

    fileprivate static func preferredUnit() -> WeightUnit {
        if let raw = UserDefaults.standard.string(forKey: SettingsKey.unitPreference),
           let unit = WeightUnit(rawValue: raw) {
            return unit
        }
        return Locale.current.measurementSystem == .metric ? .kilograms : .pounds
    }

    fileprivate static func makeDisplay(
        kilograms: Double,
        unit: WeightUnit,
        locale: Locale
    ) -> ComplicationWeightDisplay {
        let measurement = Measurement(value: kilograms, unit: UnitMass.kilograms)
            .converted(to: unit.unitMass)

        let numberFormatter = NumberFormatter()
        numberFormatter.locale = locale
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumFractionDigits = 1
        numberFormatter.maximumFractionDigits = 1

        let valueText = numberFormatter.string(from: NSNumber(value: measurement.value)) ?? "—"
        let fullText = WeightFormatter(locale: locale, fractionDigits: 1)
            .format(kilograms: kilograms, in: unit)

        return ComplicationWeightDisplay(
            valueText: valueText,
            unitText: unit.shortDisplayName,
            fullText: fullText,
            hasData: true
        )
    }
}

struct BodyMassComplicationView: View {
    @Environment(\.widgetFamily) private var family
    var entry: BodyMassEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularLayout
        case .accessoryCorner:
            cornerLayout
        case .accessoryInline:
            inlineLayout
        case .accessoryRectangular:
            rectangularLayout
        default:
            Text(entry.display.fullText)
        }
    }

    private var circularLayout: some View {
        ZStack {
            AccessoryWidgetBackground()
            if entry.display.hasData {
                VStack(spacing: 0) {
                    Text(entry.display.valueText)
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                        .widgetAccentable(false)
                    Text(entry.display.unitText)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .widgetAccentable(false)
                }
                .privacySensitive()
            } else {
                accentWeightIcon(font: .title2)
            }
        }
        .accessibilityLabel(entry.display.fullText)
    }

    /// Corner slot (Infograph): accent icon in the inner body, weight curves along the dial via `widgetLabel`.
    /// Mirrors Apple's WWDC22 `CornerView` sample so the watch face renders both layers.
    private var cornerLayout: some View {
        Image(systemName: "scalemass.fill")
            .font(.title.bold())
            .widgetAccentable()
            .widgetLabel {
                cornerCurvedLabel
            }
            .accessibilityLabel(entry.display.fullText)
    }

    @ViewBuilder
    private var cornerCurvedLabel: some View {
        if entry.display.hasData {
            Text(entry.display.cornerLabel)
                .font(.system(.body, design: .rounded))
                .fontWeight(.semibold)
                .monospacedDigit()
                .widgetAccentable(false)
                .privacySensitive()
        } else {
            Text("Body weight")
                .font(.system(.body, design: .rounded))
                .fontWeight(.semibold)
                .widgetAccentable(false)
        }
    }

    private var inlineLayout: some View {
        HStack(spacing: 4) {
            accentWeightIcon(font: .body)
            Text(entry.display.fullText)
                .widgetAccentable(false)
        }
        .privacySensitive()
        .accessibilityLabel("Weight \(entry.display.fullText)")
    }

    private var rectangularLayout: some View {
        HStack(spacing: 8) {
            accentWeightIcon(font: .body.weight(.semibold))

            if entry.display.hasData {
                Text(entry.display.fullText)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .layoutPriority(1)
                    .widgetAccentable(false)
                    .privacySensitive()
            } else {
                Text("No weight yet")
                    .font(.headline)
                    .widgetAccentable(false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel(entry.display.fullText)
    }

    /// Tints with the watch face accent color (e.g. Infograph pink); do not add `foregroundStyle` here.
    private func accentWeightIcon(font: Font) -> some View {
        Image(systemName: "scalemass.fill")
            .font(font)
            .symbolRenderingMode(.monochrome)
            .widgetAccentable()
    }
}

#if DEBUG
#Preview(as: .accessoryCircular) {
    BodyMassComplication()
} timeline: {
    BodyMassEntry(
        date: .now,
        display: ComplicationWeightDisplay(
            valueText: "71,5",
            unitText: "kg",
            fullText: "71,5 kg",
            hasData: true
        )
    )
}

#Preview("Circular — empty", as: .accessoryCircular) {
    BodyMassComplication()
} timeline: {
    BodyMassEntry(date: .now, display: .empty)
}

#Preview(as: .accessoryRectangular) {
    BodyMassComplication()
} timeline: {
    BodyMassEntry(
        date: .now,
        display: ComplicationWeightDisplay(
            valueText: "75,0",
            unitText: "kg",
            fullText: "75,0 kg",
            hasData: true
        )
    )
}

#Preview(as: .accessoryCorner) {
    BodyMassComplication()
} timeline: {
    BodyMassEntry(
        date: .now,
        display: ComplicationWeightDisplay(
            valueText: "75,0",
            unitText: "kg",
            fullText: "75,0 kg",
            hasData: true
        )
    )
}
#endif
