import SwiftUI
import LogWeightCore
#if !os(watchOS)
import Charts
#endif

/// HealthKit history (source of truth). Shared by iOS, watchOS, and macOS.
/// Phase 4: iOS/iPadOS/macOS get a trend chart above the list.
struct HistoryView: View {

    let store: HealthKitStore

    @AppStorage(SettingsKey.unitPreference) private var unitPreferenceRaw: String = WeightUnit.kilograms.rawValue
    @State private var weights: [Weight] = []
    @State private var loadError: String?
    @State private var deleteError: String?
    @State private var isDeleting = false
    @Environment(\.dismiss) private var dismiss

    private var displayUnit: WeightUnit {
        WeightUnit(rawValue: unitPreferenceRaw) ?? .kilograms
    }

    private var formatter: WeightFormatter {
        WeightFormatter(locale: .current, fractionDigits: 1)
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        f.locale = .current
        return f
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("History")
#if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
#endif
                .toolbar {
#if os(macOS)
                    ToolbarItem(placement: .automatic) {
                        Button("Close") { dismiss() }
                    }
#else
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
#endif
                }
                .task {
                    await load()
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let loadError = loadError {
            VStack(spacing: 12) {
                Text("Couldn't read your weight history.")
                    .font(.headline)
                Text(loadError)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        } else if weights.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "scalemass")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                Text("No weights yet.")
                    .font(.headline)
                Text("Save your first weight on the entry screen.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } else {
            List {
                if let deleteError = deleteError {
                    Section {
                        Text(deleteError)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
#if !os(watchOS)
                Section {
                    chartSection
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
#endif
                Section {
                    ForEach(weights, id: \.self) { weight in
                        HStack {
                            Text(formatter.format(kilograms: weight.valueInKilograms, in: displayUnit))
                                .font(.body.monospacedDigit())
                            Spacer()
                            Text(dateFormatter.string(from: weight.recordedAt))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        .privacySensitive()
                    }
                    .onDelete { offsets in
                        Task { await delete(at: offsets) }
                    }
                } header: {
                    Text("Recent entries")
                }
            }
            .listStyle(.plain)
            .disabled(isDeleting)
        }
    }

#if !os(watchOS)
    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trend")
                .font(.headline)
            Chart(weights.sorted(by: { $0.recordedAt < $1.recordedAt }), id: \.recordedAt) { weight in
                LineMark(
                    x: .value("Date", weight.recordedAt),
                    y: .value("Weight", displayValue(for: weight))
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(.teal)

                PointMark(
                    x: .value("Date", weight.recordedAt),
                    y: .value("Weight", displayValue(for: weight))
                )
                .foregroundStyle(.teal)
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 180)
            .accessibilityIdentifier("history.chart")
        }
        .padding(.vertical, 4)
    }

    private func displayValue(for weight: Weight) -> Double {
        Measurement(value: weight.valueInKilograms, unit: UnitMass.kilograms)
            .converted(to: displayUnit.unitMass)
            .value
    }
#endif

    private func load() async {
        do {
            let result = try await store.recentWeights(limit: 50)
            weights = result
            loadError = nil
            deleteError = nil
        } catch HealthKitError.queryFailed(let code) {
            loadError = "HealthKit query failed (code \(code))."
        } catch {
            loadError = "Unexpected error reading from Apple Health."
        }
    }

    private func delete(at offsets: IndexSet) async {
        isDeleting = true
        defer { isDeleting = false }

        var toDelete: [Weight] = []
        for index in offsets where weights.indices.contains(index) {
            toDelete.append(weights[index])
        }

        do {
            for weight in toDelete {
                try await store.delete(weight)
            }
            await load()
        } catch HealthKitError.deleteFailed(let code) {
            deleteError = "Couldn't delete entry (code \(code))."
        } catch {
            deleteError = "Unexpected error deleting entry."
        }
    }
}

#if DEBUG
#Preview("History") {
    HistoryView(store: InMemoryHealthKitStore(samples: [
        Weight(valueInKilograms: 80.0, recordedAt: .now),
        Weight(valueInKilograms: 79.5, recordedAt: .now.addingTimeInterval(-86_400))
    ]))
}
#endif
