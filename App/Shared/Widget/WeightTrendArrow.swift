import SwiftUI
import LogWeightCore

private enum TrendArrowPreferenceStore {
    static let userDefaults = UserDefaults(suiteName: SharedWeightEntryStore.appGroupIdentifier) ?? .standard
}

/// Compact trend indicator for widgets and history headers.
struct WeightTrendArrow: View {
    let direction: WeightTrendDirection
    var font: Font = .caption2.weight(.semibold)

    @AppStorage(SettingsKey.trendArrowEnabled, store: TrendArrowPreferenceStore.userDefaults)
    private var trendArrowEnabled = true

    /// Shared style for Home Screen widget headers (gray, subheadline size).
    static func widget(direction: WeightTrendDirection) -> WeightTrendArrow {
        WeightTrendArrow(direction: direction, font: .subheadline.weight(.semibold))
    }

    var body: some View {
        if trendArrowEnabled {
            trendContent
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var trendContent: some View {
        switch direction {
        case .unknown:
            EmptyView()
        case .up:
            trendSymbol("arrow.up", accessibilityLabel: "Trending up")
        case .down:
            trendSymbol("arrow.down", accessibilityLabel: "Trending down")
        case .flat:
            trendSymbol("minus", accessibilityLabel: "Weight stable")
        }
    }

    private func trendSymbol(_ name: String, accessibilityLabel: String) -> some View {
        Image(systemName: name)
            .font(font)
            .foregroundStyle(.secondary)
            .accessibilityLabel(accessibilityLabel)
    }
}

#if DEBUG
#Preview("Trend arrows") {
    HStack(spacing: 12) {
        WeightTrendArrow(direction: .up)
        WeightTrendArrow(direction: .down)
        WeightTrendArrow(direction: .flat)
    }
    .padding()
}
#endif
