import SwiftUI
import HealthKit
import LogWeightCore

/// Stepper-primary entry surface.
///
/// Layout (top to bottom):
/// - Big SF Rounded numeric value: after Health load, keyboard edit only when Apple Health has no body-mass samples; otherwise double-tap restores last weight
/// - Prominent − / + stepper buttons (44pt, long-press accelerates via SwiftUI Stepper)
/// - Save button bottom-trailing; on first entry, Save commits typed value and dismisses the keyboard in one tap
struct EntryView: View {

    @Bindable var state: EntryState
    let store: HealthKitStore

    @AppStorage(SettingsKey.unitPreference) private var unitPreferenceRaw: String = WeightUnit.kilograms.rawValue
    @AppStorage(SettingsKey.hapticsEnabled) private var hapticsEnabled: Bool = true

    @State private var showSettings = false
    @State private var isEditingValue = false
    @State private var typedValue: String = ""
    @State private var clearSavedStatusTask: Task<Void, Never>?
    @FocusState private var valueFieldFocused: Bool

    /// Keyboard entry only after initial Health load completes and no body-mass sample exists.
    private var canEditWithKeyboard: Bool {
        state.hasResolvedInitialWeight && state.lastSavedWeight == nil
    }

    private var displayUnit: WeightUnit {
        WeightUnit(rawValue: unitPreferenceRaw) ?? .kilograms
    }

    private var formatter: WeightFormatter {
        WeightFormatter(locale: .current, fractionDigits: 1)
    }

    private var weightInputBinding: Binding<String> {
        Binding(
            get: { typedValue },
            set: { typedValue = formatter.sanitizeWeightInput($0) }
        )
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
                        dismissWeightEditor()
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
                dismissWeightEditor()
            }
        }
    }

    @ViewBuilder
    private var weightDisplay: some View {
        let displayValue = state.displayValueInKilograms
        if isEditingValue {
            TextField("", text: weightInputBinding)
                .keyboardType(.decimalPad)
                .focused($valueFieldFocused)
                .font(.system(size: 88, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .accessibilityLabel("Weight value")
                .accessibilityIdentifier("entry.value.textfield")
                .onAppear {
                    valueFieldFocused = true
                }
                .onChange(of: valueFieldFocused) { _, focused in
                    if !focused {
                        isEditingValue = false
                    }
                }
        } else if !state.hasResolvedInitialWeight {
            formattedWeightText(kilograms: displayValue)
        } else if canEditWithKeyboard {
            Button {
                openWeightEditor(currentKilograms: displayValue)
            } label: {
                Text(formatter.format(kilograms: displayValue, in: displayUnit))
                    .font(.system(size: 72, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("entry.value.display")
            .accessibilityLabel(Text("Weight \(formatter.format(kilograms: displayValue, in: displayUnit)). Tap to type your first weight."))
            .accessibilityHint("Opens the keyboard to type your weight.")
        } else {
            formattedWeightText(kilograms: displayValue)
                .onTapGesture(count: 2) {
                    state.restoreDisplayToLastLoggedWeight()
                }
                .accessibilityIdentifier("entry.value.display")
                .accessibilityLabel(Text("Weight \(formatter.format(kilograms: displayValue, in: displayUnit))."))
                .accessibilityHint("Double tap quickly to restore the last logged weight. Use the Restore action in the VoiceOver rotor for the same.")
                .accessibilityAction(named: Text("Restore last logged weight")) {
                    state.restoreDisplayToLastLoggedWeight()
                }
        }
    }

    private func formattedWeightText(kilograms: Double) -> some View {
        Text(formatter.format(kilograms: kilograms, in: displayUnit))
            .font(.system(size: 72, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
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
                if isEditingValue {
                    commitTypedValueIfNeeded()
                    dismissWeightEditor()
                }
                await state.commit(store: store)
                if case .savedAt = state.saveStatus {
                    syncWidgetAfterSuccessfulSave()
                }
            }
        } label: {
            Text("Save")
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(saveButtonBackground, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(state.saveStatus == .saving)
        .accessibilityIdentifier("entry.save")
    }

    private var saveButtonBackground: Color {
        if state.saveStatus == .saving {
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

    private func openWeightEditor(currentKilograms: Double) {
        guard canEditWithKeyboard else { return }
        typedValue = formatter.formatEditableValue(kilograms: currentKilograms, in: displayUnit)
        isEditingValue = true
    }

    private func dismissWeightEditor() {
        valueFieldFocused = false
        isEditingValue = false
    }

    private func syncWidgetAfterSuccessfulSave() {
        Task {
            await WidgetTimelineRefresh.syncEntryStoreAndReloadWidgets(store: store)
        }
    }
}

#Preview {
    EntryView(
        state: EntryState(initialValueInKilograms: 75.0),
        store: InMemoryHealthKitStore()
    )
}
