import SwiftUI
import HealthKit
import LogWeightCore

/// Stepper-primary entry surface.
///
/// Layout (top to bottom):
/// - Big SF Rounded numeric value (tap → opens decimal pad after a short delay; second tap quickly restores last logged weight)
/// - Prominent − / + stepper buttons (44pt, long-press accelerates via SwiftUI Stepper)
/// - Save button bottom-trailing in safe area, disabled while keyboard is up
///
/// DA1 fix: Save is disabled while the decimal-pad keyboard is up. The keyboard
/// toolbar contains a "Done" button that dismisses the keyboard, after which Save
/// becomes tappable. Stepper is the primary path; typing is the secondary path.
struct EntryView: View {

    @Bindable var state: EntryState
    let store: HealthKitStore

    @AppStorage(SettingsKey.unitPreference) private var unitPreferenceRaw: String = WeightUnit.kilograms.rawValue
    @AppStorage(SettingsKey.hapticsEnabled) private var hapticsEnabled: Bool = true

    @State private var showSettings = false
    @State private var isEditingValue = false
    @State private var typedValue: String = ""
    @State private var clearSavedStatusTask: Task<Void, Never>?
    @State private var pendingOpenEditorWork: DispatchWorkItem?
    @FocusState private var valueFieldFocused: Bool

    /// Delay before one tap opens the decimal pad; second tap within this window restores last logged weight (UIKit-style double-tap vs single-tap tradeoff).
    private static let singleTapEditDelaySeconds: TimeInterval = 0.28

    private var displayUnit: WeightUnit {
        WeightUnit(rawValue: unitPreferenceRaw) ?? .kilograms
    }

    private var formatter: WeightFormatter {
        WeightFormatter(locale: .current, fractionDigits: 1)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                weightDisplay
                stepperRow
                Spacer()
                statusLine
                saveButton
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemBackground))
            .privacySensitive()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityIdentifier("entry.settings")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        commitTypedValueIfNeeded()
                        valueFieldFocused = false
                    }
                    .accessibilityIdentifier("entry.keyboard.done")
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sensoryFeedback(.success, trigger: state.saveStatus) { _, new in
                if hapticsEnabled, case .savedAt = new { return true }
                return false
            }
            .onChange(of: state.saveStatus) { _, new in
                guard case .savedAt = new else { return }
                clearSavedStatusTask?.cancel()
                clearSavedStatusTask = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(3))
                    guard !Task.isCancelled else { return }
                    state.reset()
                }
            }
            .onDisappear {
                clearSavedStatusTask?.cancel()
                pendingOpenEditorWork?.cancel()
                pendingOpenEditorWork = nil
            }
        }
    }

    @ViewBuilder
    private var weightDisplay: some View {
        let displayValue = state.displayValueInKilograms
        if valueFieldFocused {
            TextField("", text: $typedValue)
                .keyboardType(.decimalPad)
                .focused($valueFieldFocused)
                .font(.system(size: 88, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .accessibilityLabel("Weight value")
                .accessibilityIdentifier("entry.value.textfield")
        } else {
            Text(formatter.format(kilograms: displayValue, in: displayUnit))
                .font(.system(size: 72, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    handleWeightDisplayTap(currentKilograms: displayValue)
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("entry.value.display")
                .accessibilityLabel(Text("Weight \(formatter.format(kilograms: displayValue, in: displayUnit)). Tap to edit."))
                .accessibilityHint("Double tap quickly to restore the last logged weight. Use the Restore action in the VoiceOver rotor for the same.")
                .accessibilityAction(named: Text("Restore last logged weight")) {
                    state.restoreDisplayToLastLoggedWeight()
                }
        }
    }

    private var stepperRow: some View {
        HStack(spacing: 24) {
            LongPressStepButton(action: state.decrement) {
                Image(systemName: "minus")
                    .font(.title)
                    .frame(width: 88, height: 88)
                    .background(Color(uiColor: .secondarySystemBackground), in: Circle())
            }
            .accessibilityLabel("Decrease weight")
            .accessibilityIdentifier("entry.stepper.minus")

            LongPressStepButton(action: state.increment) {
                Image(systemName: "plus")
                    .font(.title)
                    .frame(width: 88, height: 88)
                    .background(Color(uiColor: .secondarySystemBackground), in: Circle())
            }
            .accessibilityLabel("Increase weight")
            .accessibilityIdentifier("entry.stepper.plus")
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        Group {
            switch state.saveStatus {
            case .idle, .saving:
                Text(" ")
                    .font(.callout)
                    .hidden()
            case .savedAt:
                Text("Saved to Apple Health")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("entry.status.saved")
            case .failed(let code):
                Text(saveFailureMessage(code: code))
                    .font(.callout)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("entry.status.failed")
            }
        }
        .frame(minHeight: 22, alignment: .center)
    }

    private var saveButton: some View {
        Button {
            Task { @MainActor in
                await state.commit(store: store)
            }
        } label: {
            Text("Save")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(saveButtonBackground, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(valueFieldFocused || state.saveStatus == .saving)
        .accessibilityIdentifier("entry.save")
    }

    private var saveButtonBackground: Color {
        if valueFieldFocused || state.saveStatus == .saving {
            return Color.accentColor.opacity(0.4)
        }
        return Color.accentColor
    }

    /// Maps `EntryState.SaveStatus.failed` reason codes to user-facing copy.
    /// Uses `HKError.Code` for values returned from `HealthKitError.saveFailed`.
    private func saveFailureMessage(code: Int) -> String {
        if code == HKError.Code.errorAuthorizationDenied.rawValue {
            return "LogWeight can’t write to Apple Health. Open Settings → Health → Data Access & Devices → LogWeight, then turn on Body Mass."
        }
        if code == HKError.Code.errorHealthDataUnavailable.rawValue || code == -2 {
            return "Health data isn’t available on this device. LogWeight can’t save here."
        }
        if code == -3 {
            return "Health access was denied. You can allow it in Settings → Health → Data Access & Devices → LogWeight."
        }
        return "Save failed. Check Apple Health permissions in Settings."
    }

    private func commitTypedValueIfNeeded() {
        guard !typedValue.isEmpty else { return }
        if let kg = formatter.parseToKilograms(typedValue, unit: displayUnit) {
            state.setValue(kg, unit: .kilograms)
        }
    }

    private func handleWeightDisplayTap(currentKilograms: Double) {
        if let work = pendingOpenEditorWork {
            guard state.lastSavedWeight != nil else {
                return
            }
            work.cancel()
            pendingOpenEditorWork = nil
            state.restoreDisplayToLastLoggedWeight()
            return
        }
        let work = DispatchWorkItem {
            typedValue = String(format: "%.1f", currentKilograms.value(in: displayUnit, formatter: formatter))
            valueFieldFocused = true
            pendingOpenEditorWork = nil
        }
        pendingOpenEditorWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.singleTapEditDelaySeconds, execute: work)
    }
}

private extension Double {
    func value(in unit: WeightUnit, formatter: WeightFormatter) -> Double {
        Measurement(value: self, unit: UnitMass.kilograms)
            .converted(to: unit.unitMass)
            .value
    }
}

#Preview {
    EntryView(
        state: EntryState(initialValueInKilograms: 75.0),
        store: InMemoryHealthKitStore()
    )
}
