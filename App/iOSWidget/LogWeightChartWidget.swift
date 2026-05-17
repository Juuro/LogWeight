import WidgetKit
import SwiftUI
import Charts
import HealthKit
import LogWeightCore

struct LogWeightChartEntry: TimelineEntry {
    let date: Date
    let range: ChartTimeRange
    let filteredWeights: [Weight]
    let lineWeights: [Weight]
    let latestWeight: Weight?
    let displayUnit: WeightUnit
    let loadFailed: Bool

    var hasChartData: Bool {
        !filteredWeights.isEmpty
    }

    var chartXDomain: ClosedRange<Date> {
        range.xDomain(weights: filteredWeights, referenceDate: date)
    }

    var chartYDomain: ClosedRange<Double> {
        WeightChartYDomain.domain(for: lineWeights, displayUnit: displayUnit)
    }
}

struct LogWeightChartProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> LogWeightChartEntry {
        Self.placeholderEntry(range: .oneWeek)
    }

    func snapshot(for configuration: LogWeightChartConfigIntent, in context: Context) async -> LogWeightChartEntry {
        let range = await Self.resolvedChartRange(configuration: configuration)
        return await Self.loadEntry(range: range)
    }

    func timeline(for configuration: LogWeightChartConfigIntent, in context: Context) async -> Timeline<LogWeightChartEntry> {
        let range = await Self.resolvedChartRange(configuration: configuration)
        let entry = await Self.loadEntry(range: range)
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: .now)
            ?? .now.addingTimeInterval(1800)
        return Timeline(entries: [entry], policy: .after(nextRefresh))
    }

    static func placeholderEntry(range: ChartTimeRange) -> LogWeightChartEntry {
        let now = Date()
        let samples = (0..<5).map { index in
            Weight(
                valueInKilograms: 75.0 + Double(index) * 0.2,
                recordedAt: now.addingTimeInterval(Double(index - 4) * 86_400)
            )
        }
        let filtered = range.filterWeights(samples, referenceDate: now)
        let line = WeightChartLineSeries.lineWeights(
            visible: filtered,
            allWeights: samples,
            rangeStart: range.cutoffDate(referenceDate: now)
        )
        return LogWeightChartEntry(
            date: now,
            range: range,
            filteredWeights: filtered,
            lineWeights: line,
            latestWeight: samples.last,
            displayUnit: .kilograms,
            loadFailed: false
        )
    }

    private static func resolvedChartRange(
        configuration: LogWeightChartConfigIntent
    ) async -> ChartTimeRange {
        let range = configuration.range.chartTimeRange
        WidgetChartRangeStore.save(range)
        return range
    }

    private static func loadEntry(range: ChartTimeRange) async -> LogWeightChartEntry {
        let now = Date()
        let displayUnit = WeightDisplayPreferences.preferredUnit()
        let store = HKHealthStoreAdapter()

        guard HKHealthStore.isHealthDataAvailable() else {
            return emptyEntry(range: range, displayUnit: displayUnit, now: now, loadFailed: true)
        }

        do {
            let allWeights = try await store.recentWeights(limit: 500)
            let filtered = range.filterWeights(allWeights, referenceDate: now)
            let line = WeightChartLineSeries.lineWeights(
                visible: filtered,
                allWeights: allWeights,
                rangeStart: range.cutoffDate(referenceDate: now)
            )
            let latest = allWeights.max(by: { $0.recordedAt < $1.recordedAt })
            return LogWeightChartEntry(
                date: now,
                range: range,
                filteredWeights: filtered,
                lineWeights: line,
                latestWeight: latest,
                displayUnit: displayUnit,
                loadFailed: false
            )
        } catch {
            return emptyEntry(range: range, displayUnit: displayUnit, now: now, loadFailed: true)
        }
    }

    private static func emptyEntry(
        range: ChartTimeRange,
        displayUnit: WeightUnit,
        now: Date,
        loadFailed: Bool
    ) -> LogWeightChartEntry {
        LogWeightChartEntry(
            date: now,
            range: range,
            filteredWeights: [],
            lineWeights: [],
            latestWeight: nil,
            displayUnit: displayUnit,
            loadFailed: loadFailed
        )
    }
}

struct LogWeightChartWidgetConfig: Widget {
    let kind: String = LogWeightWidgetConstants.chartKind

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: LogWeightChartConfigIntent.self,
            provider: LogWeightChartProvider()
        ) { entry in
            LogWeightChartWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Weight Trend")
        .description("Your weight trend from Apple Health.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct LogWeightChartWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: LogWeightChartEntry

    private var formatter: WeightFormatter {
        WeightFormatter(locale: .current, fractionDigits: 1)
    }

    var body: some View {
        Group {
            if entry.loadFailed {
                unavailableView
            } else if !entry.hasChartData {
                emptyView
            } else {
                chartContent
            }
        }
        .widgetURL(URL(string: "logweight://history"))
    }

    private var unavailableView: some View {
        VStack(spacing: 6) {
            Image(systemName: "scalemass")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Open LogWeight")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 6) {
            Image(systemName: "chart.xyaxis.line")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No data")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(entry.range.label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var chartContent: some View {
        switch family {
        case .systemSmall:
            smallLayout
        default:
            mediumLayout
        }
    }

    private var smallLayout: some View {
        VStack(alignment: .leading, spacing: 6) {
            weightHeader(weightFont: .system(size: 22, weight: .semibold, design: .rounded))

            trendChart(axisStyle: .smallCompact)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(10)
    }

    private var mediumLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            weightHeader(weightFont: .headline)

            trendChart(axisStyle: .medium)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(8)
    }

    private func weightHeader(weightFont: Font) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: "scalemass")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if let latest = entry.latestWeight {
                Text(formatter.format(kilograms: latest.valueInKilograms, in: entry.displayUnit))
                    .font(weightFont)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }

            Spacer(minLength: 0)

            Text(entry.range.label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary, in: Capsule())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(latestWeightAccessibilityLabel)
    }

    private var latestWeightAccessibilityLabel: String {
        guard let latest = entry.latestWeight else {
            return "Weight trend, \(entry.range.label)"
        }
        let formatted = formatter.format(kilograms: latest.valueInKilograms, in: entry.displayUnit)
        return "Current weight \(formatted), \(entry.range.label) trend"
    }

    private enum ChartAxisStyle {
        case smallCompact
        case medium
    }

    private func trendChart(axisStyle: ChartAxisStyle) -> some View {
        Chart {
            ForEach(entry.lineWeights, id: \.self) { weight in
                LineMark(
                    x: .value("Date", weight.recordedAt),
                    y: .value("Weight", displayValue(for: weight))
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(.teal)
            }

            if let latest = entry.latestWeight,
               entry.filteredWeights.contains(latest) {
                PointMark(
                    x: .value("Date", latest.recordedAt),
                    y: .value("Weight", displayValue(for: latest))
                )
                .foregroundStyle(.teal)
                .symbolSize(axisStyle == .smallCompact ? 36 : 48)
            }
        }
        .chartXScale(domain: entry.chartXDomain)
        .chartYScale(domain: entry.chartYDomain)
        .chartXAxis {
            switch axisStyle {
            case .smallCompact:
                AxisMarks(values: .automatic(desiredCount: 2)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.secondary.opacity(0.35))
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            case .medium:
                AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(.secondary.opacity(0.35))
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day(), centered: true)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: axisStyle == .smallCompact ? 2 : 3)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(.secondary.opacity(0.35))
                AxisValueLabel {
                    if let displayValue = value.as(Double.self) {
                        Text(axisWeightLabel(displayValue))
                            .font(.system(size: axisStyle == .smallCompact ? 9 : 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func axisWeightLabel(_ displayValue: Double) -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.locale = .current
        numberFormatter.numberStyle = .decimal
        numberFormatter.minimumFractionDigits = 1
        numberFormatter.maximumFractionDigits = 1
        return numberFormatter.string(from: NSNumber(value: displayValue)) ?? ""
    }

    private func displayValue(for weight: Weight) -> Double {
        Measurement(value: weight.valueInKilograms, unit: UnitMass.kilograms)
            .converted(to: entry.displayUnit.unitMass)
            .value
    }
}

#if DEBUG
#Preview(as: .systemSmall) {
    LogWeightChartWidgetConfig()
} timeline: {
    LogWeightChartProvider.placeholderEntry(range: .oneWeek)
}

#Preview(as: .systemMedium) {
    LogWeightChartWidgetConfig()
} timeline: {
    LogWeightChartProvider.placeholderEntry(range: .oneMonth)
}
#endif
