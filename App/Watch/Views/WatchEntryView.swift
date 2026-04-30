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
    @State private var clearSavedStatusTask: Task<Void, Never>?

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
            VStack(spacing: 10) {
                Spacer(minLength: 4)
                Text(formatter.format(kilograms: state.displayValueInKilograms, in: displayUnit))
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .frame(height: 40)
                    .padding(.top, 6)
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

                primaryActionButton
                Spacer(minLength: 0)
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
                if case .savedAt = new {
                    clearSavedStatusTask?.cancel()
                    clearSavedStatusTask = Task {
                        try? await Task.sleep(for: .seconds(3))
                        guard !Task.isCancelled else { return }
                        await MainActor.run {
                            state.reset()
                        }
                    }
                }
            }
            .onDisappear {
                clearSavedStatusTask?.cancel()
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

    private var primaryActionButton: some View {
        Button {
            Task {
                await state.commit(store: store)
            }
        } label: {
            Group {
                if state.saveStatus == .saving {
                    Text("Saving…")
                } else if case .savedAt = state.saveStatus {
                    Label("Saved", systemImage: "checkmark")
                } else {
                    Text("Save")
                }
            }
            .font(.headline)
            .frame(maxWidth: .infinity, minHeight: 40)
        }
        .buttonStyle(.borderedProminent)
        .disabled(state.saveStatus != .idle && !isFailedState)
        .padding(.top, 2)
        .overlay(alignment: .bottom) {
            if case .failed(let code) = state.saveStatus {
                Text(saveFailureMessage(code: code))
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 4)
                    .offset(y: 16)
            }
        }
    }

    private var isFailedState: Bool {
        if case .failed = state.saveStatus { return true }
        return false
    }
}

#if DEBUG
#Preview {
    WatchEntryView(state: EntryState(initialValueInKilograms: 75), store: InMemoryHealthKitStore())
}
#endif
