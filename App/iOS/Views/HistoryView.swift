import SwiftUI
import LogWeightCore

/// Plain text history list. Phase 1 deliberately ships no charts — that is the
/// user's explicit choice (see DA7 / approval gate Q "history_scope = list_only").
/// Charts arrive in Phase 4.
struct HistoryView: View {

    let store: HealthKitStore

    @AppStorage(SettingsKey.unitPreference) private var unitPreferenceRaw: String = WeightUnit.kilograms.rawValue
    @State private var weights: [Weight] = []
    @State private var loadError: String?
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
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
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
            List(weights, id: \.recordedAt) { weight in
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
            .listStyle(.plain)
        }
    }

    private func load() async {
        do {
            let result = try await store.recentWeights(limit: 50)
            weights = result
            loadError = nil
        } catch HealthKitError.queryFailed(let code) {
            loadError = "HealthKit query failed (code \(code))."
        } catch {
            loadError = "Unexpected error reading from Apple Health."
        }
    }
}

#Preview {
    HistoryView(store: InMemoryHealthKitStore(samples: [
        Weight(valueInKilograms: 80.0, recordedAt: .now),
        Weight(valueInKilograms: 79.5, recordedAt: .now.addingTimeInterval(-86_400))
    ]))
}
