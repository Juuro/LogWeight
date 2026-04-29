import SwiftUI
import HealthKit
import WatchKit
import WidgetKit
import LogWeightCore

/// Phase 2 watch entry: Digital Crown adjusts weight (±0.1), Save commits to HealthKit.
struct WatchEntryView: View {

    @Bindable var state: EntryState
    let store: HealthKitStore

    @AppStorage(SettingsKey.unitPreference) private var unitPreferenceRaw: String = WeightUnit.kilograms.rawValue
    @AppStorage(SettingsKey.hapticsEnabled) private var hapticsEnabled: Bool = true

    @State private var showHistory = false
    @State private var showSettings = false

    private var displayUnit: WeightUnit {
        WeightUnit(rawValue: unitPreferenceRaw) ?? .kilograms
    }

    private var formatter: WeightFormatter {
        WeightFormatter(locale: .current, fractionDigits: 1)
    }

    /// Crown binding routes through `setValue` so `EntryState` clamps to sane bounds.
    private var crownKilograms: Binding<Double> {
        Binding(
            get: { state.displayValueInKilograms },
            set: { state.setValue($0, unit: .kilograms) }
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Spacer(minLength: 2)
                Text(formatter.format(kilograms: state.displayValueInKilograms, in: displayUnit))
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.semibold)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .focusable()
                    .digitalCrownRotation(
                        crownKilograms,
                        from: 20,
                        through: 300,
                        by: 0.1,
                        sensitivity: .medium,
                        isContinuous: false,
                        isHapticFeedbackEnabled: true
                    )
                    .privacySensitive()
                    .accessibilityLabel("Weight")

                HStack(spacing: 16) {
                    Button {
                        state.decrement()
                    } label: {
                        Image(systemName: "minus")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Decrease weight")

                    Button {
                        state.increment()
                    } label: {
                        Image(systemName: "plus")
                            .font(.title3)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Increase weight")
                }

                statusLine

                Button {
                    Task {
                        await state.commit(store: store)
                    }
                } label: {
                    Text("Save")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(state.saveStatus == .saving)
                .padding(.top, 2)
                Spacer(minLength: 2)
            }
            .padding(.horizontal, 8)
            // On 42mm screens an inline nav title can overlap main content.
            // Keep the bar icon-only for clear separation and stable spacing.
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock")
                    }
                    .accessibilityLabel("History")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showHistory) {
                HistoryView(store: store)
            }
            .sheet(isPresented: $showSettings) {
                WatchSettingsView()
            }
            .onChange(of: state.saveStatus) { _, new in
                if hapticsEnabled, case .savedAt = new {
                    WKInterfaceDevice.current().play(.success)
                    WidgetCenter.shared.reloadAllTimelines()
                }
            }
        }
    }

    private func saveFailureMessage(code: Int) -> String {
        if code == HKError.Code.errorAuthorizationDenied.rawValue {
            return "Allow Body Mass in Watch → Settings → Health → Apps."
        }
        if code == HKError.Code.errorHealthDataUnavailable.rawValue {
            return "Health data unavailable on this Watch."
        }
        if code == -3 {
            return "Health access denied. Allow in Watch → Settings → Health."
        }
        return "Save failed. Check Health permissions."
    }

    @ViewBuilder
    private var statusLine: some View {
        // Keep a constant reserved height so save-state transitions don't reflow
        // the watch layout and cause a visible jump.
        Group {
            if case .failed(let code) = state.saveStatus {
                Text(saveFailureMessage(code: code))
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
            } else if case .savedAt = state.saveStatus {
                Text("Saved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(" ")
                    .font(.caption)
                    .hidden()
            }
        }
        .frame(height: 22, alignment: .center)
    }
}

#if DEBUG
#Preview {
    WatchEntryView(state: EntryState(initialValueInKilograms: 75), store: InMemoryHealthKitStore())
}
#endif
