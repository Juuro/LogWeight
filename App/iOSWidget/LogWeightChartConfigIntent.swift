import AppIntents
import LogWeightCore

/// Picker values for the chart widget time range.
/// Lives in the widget extension target only so App Intents metadata and
/// persisted configuration share one module identity (`LogWeightWidget`).
enum ChartWidgetRange: String, AppEnum {
    case oneWeek
    case oneMonth
    case threeMonths
    case sixMonths
    case oneYear
    case all

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Range")

    static var defaultCase: ChartWidgetRange { .oneWeek }

    static var caseDisplayRepresentations: [ChartWidgetRange: DisplayRepresentation] {
        [
            .oneWeek: "1W",
            .oneMonth: "1M",
            .threeMonths: "3M",
            .sixMonths: "6M",
            .oneYear: "1Y",
            .all: "All",
        ]
    }

    var chartTimeRange: ChartTimeRange {
        switch self {
        case .oneWeek: .oneWeek
        case .oneMonth: .oneMonth
        case .threeMonths: .threeMonths
        case .sixMonths: .sixMonths
        case .oneYear: .oneYear
        case .all: .all
        }
    }
}

struct LogWeightChartConfigIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Weight Trend"
    static var description = IntentDescription("Shows your weight trend from Apple Health.")

    @Parameter(title: "Range")
    var range: ChartWidgetRange

    init() {
        range = .oneWeek
    }

    init(range: ChartWidgetRange) {
        self.range = range
    }
}
