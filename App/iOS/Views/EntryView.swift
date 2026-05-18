import SwiftUI
import UIKit
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
    /// True while the Entry tab is selected in `MainTabView`.
    var isTabActive: Bool = true

    @AppStorage(SettingsKey.unitPreference) private var unitPreferenceRaw: String = WeightUnit.kilograms.rawValue
    @AppStorage(SettingsKey.hapticsEnabled) private var hapticsEnabled: Bool = true

    @State private var showSettings = false
    @State private var isEditingValue = false
    @State private var typedValue: String = ""
    @State private var clearSavedStatusTask: Task<Void, Never>?
    @State private var didPresentFirstWeightEditor = false
    /// Bumped when focus work should be abandoned (tab switch, dismiss, new request). In-flight tasks compare to their captured value.
    @State private var firstWeightFocusRequestID: UInt64 = 0
    @State private var firstWeightKeyboardFocusTask: Task<Void, Never>?
    @FocusState private var valueFieldFocused: Bool

    /// Keyboard entry only when HealthKit read succeeded and confirmed no prior samples.
    private var canEditWithKeyboard: Bool {
        state.hasConfirmedEmptyWeightStore
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
                if canEditWithKeyboard {
                    Text("Enter your first weight")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("entry.first-weight.prompt")
                }
                weightDisplay
                stepperRow
                Spacer()
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemBackground))
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 12) {
                    statusLine
                    saveButton
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(Color(uiColor: .systemBackground))
            }
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
            .onAppear {
                handleEntryVisibilityChange(isVisible: isTabActive)
            }
            .onChange(of: isTabActive) { _, isActive in
                handleEntryVisibilityChange(isVisible: isActive)
            }
            .onChange(of: state.hasConfirmedEmptyWeightStore) { _, isEmpty in
                guard isEmpty else { return }
                typedValue = ""
                didPresentFirstWeightEditor = false
                presentFirstWeightEditorIfNeeded()
            }
            .onChange(of: state.hasResolvedInitialWeight) { _, resolved in
                guard resolved, state.hasConfirmedEmptyWeightStore else { return }
                presentFirstWeightEditorIfNeeded()
            }
            .onChange(of: state.displayValueInKilograms) { _, newValue in
                syncTypedValueFromStepperIfNeeded(kilograms: newValue)
            }
        }
    }

    @ViewBuilder
    private var weightDisplay: some View {
        let displayValue = state.displayValueInKilograms
        if isEditingValue || (canEditWithKeyboard && state.hasResolvedInitialWeight) {
            TextField("", text: weightInputBinding, prompt: Text(" "))
                .keyboardType(.decimalPad)
                .focused($valueFieldFocused)
                .optionalFirstWeightDefaultFocus(
                    $valueFieldFocused,
                    prefers: canEditWithKeyboard && isTabActive && state.hasResolvedInitialWeight
                )
                .font(.system(size: 88, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .accessibilityLabel("Weight value")
                .accessibilityIdentifier("entry.value.textfield")
                .onAppear {
                    if canEditWithKeyboard, state.hasResolvedInitialWeight {
                        scheduleFirstWeightKeyboardFocus()
                    } else {
                        valueFieldFocused = true
                    }
                }
                .onChange(of: valueFieldFocused) { _, focused in
                    if !focused, !canEditWithKeyboard {
                        isEditingValue = false
                    }
                }
        } else if !state.hasResolvedInitialWeight {
            Color.clear
                .frame(maxWidth: .infinity)
                .frame(height: 88)
                .accessibilityHidden(true)
        } else {
            formattedWeightText(kilograms: displayValue)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    state.restoreDisplayToLastLoggedWeight()
                }
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
            .accessibilityIdentifier("entry.value.display")
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
                commitTypedValueIfNeeded()
                dismissKeyboard()
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

    private func handleEntryVisibilityChange(isVisible: Bool) {
        if isVisible {
            presentFirstWeightEditorIfNeeded()
            return
        }
        clearSavedStatusTask?.cancel()
        firstWeightFocusRequestID += 1
        firstWeightKeyboardFocusTask?.cancel()
        firstWeightKeyboardFocusTask = nil
        dismissKeyboard()
        didPresentFirstWeightEditor = false
    }

    /// Returning from History via the tab bar leaves `@FocusState` in a state that SwiftUI does
    /// not always reconcile with UIKit. Programmatic `valueFieldFocused = true` (with or without a
    /// false→true toggle) is silently dropped — the value flips but the underlying UITextField is
    /// never made first responder, so no keyboard appears.
    ///
    /// Fix: wait for the tab transition to settle, then bypass SwiftUI and call
    /// `becomeFirstResponder()` directly on the UITextField that backs the SwiftUI `TextField`.
    /// We find it by accessibility identifier in the key window.
    ///
    /// **Important:** uses the `firstWeightFocusRequestID` generation guard so a fresh schedule
    /// (e.g., from another `onChange`) cancels the in-flight pulse cleanly.
    private func scheduleFirstWeightKeyboardFocus() {
        guard isTabActive, canEditWithKeyboard, state.hasResolvedInitialWeight else { return }
        firstWeightFocusRequestID += 1
        let requestID = firstWeightFocusRequestID
        firstWeightKeyboardFocusTask?.cancel()
        firstWeightKeyboardFocusTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, requestID == firstWeightFocusRequestID else { return }
            guard isTabActive, canEditWithKeyboard, state.hasResolvedInitialWeight else { return }
            isEditingValue = true
            // Sync SwiftUI's @FocusState — important so the SwiftUI-side state matches reality and
            // dependent modifiers (binding reads, etc.) behave correctly.
            valueFieldFocused = true
            // Then bypass SwiftUI and directly make the UITextField first responder. This is the
            // only thing that reliably shows the keyboard after a tab swap on iOS 17/18.
            EntryView.makeWeightFieldFirstResponder()
            // Retry once after the keyboard animation slot to catch the rare case where the first
            // call lost a race with another responder change.
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, requestID == firstWeightFocusRequestID else { return }
            guard isTabActive, canEditWithKeyboard, state.hasResolvedInitialWeight else { return }
            if !EntryView.isWeightFieldFirstResponder() {
                valueFieldFocused = true
                EntryView.makeWeightFieldFirstResponder()
            }
        }
    }

    /// Accessibility identifier of the weight TextField — propagated by SwiftUI to the underlying
    /// UITextField so we can locate it in the UIKit window hierarchy.
    private static let weightFieldAccessibilityIdentifier = "entry.value.textfield"

    @MainActor
    private static func makeWeightFieldFirstResponder() {
        guard let textField = findWeightTextField() else { return }
        if !textField.isFirstResponder {
            textField.becomeFirstResponder()
        }
    }

    @MainActor
    private static func isWeightFieldFirstResponder() -> Bool {
        findWeightTextField()?.isFirstResponder ?? false
    }

    @MainActor
    private static func findWeightTextField() -> UITextField? {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows where window.isKeyWindow {
                if let textField = window.firstDescendant(
                    ofType: UITextField.self,
                    accessibilityIdentifier: weightFieldAccessibilityIdentifier
                ) {
                    return textField
                }
            }
        }
        return nil
    }

    private func presentFirstWeightEditorIfNeeded() {
        guard isTabActive, canEditWithKeyboard, state.hasResolvedInitialWeight else { return }
        if !didPresentFirstWeightEditor {
            didPresentFirstWeightEditor = true
            typedValue = ""
        }
        isEditingValue = true
        scheduleFirstWeightKeyboardFocus()
    }

    private func syncTypedValueFromStepperIfNeeded(kilograms: Double) {
        guard canEditWithKeyboard, isEditingValue, kilograms > 0 else { return }
        typedValue = formatter.formatEditableValue(kilograms: kilograms, in: displayUnit)
    }

    private func dismissKeyboard() {
        firstWeightFocusRequestID += 1
        firstWeightKeyboardFocusTask?.cancel()
        firstWeightKeyboardFocusTask = nil
        valueFieldFocused = false
        if !canEditWithKeyboard {
            isEditingValue = false
        }
    }

    private func syncWidgetAfterSuccessfulSave() {
        Task {
            await WidgetTimelineRefresh.syncEntryStoreAndReloadWidgets(store: store)
        }
    }
}

// MARK: - Focus helpers

private extension View {
    /// Applies `.defaultFocus` only when this branch should own initial keyboard focus (iOS 17+ two-parameter API).
    @ViewBuilder
    func optionalFirstWeightDefaultFocus(
        _ binding: FocusState<Bool>.Binding,
        prefers: Bool
    ) -> some View {
        if prefers {
            self.defaultFocus(binding, true)
        } else {
            self
        }
    }
}

private extension UIView {
    /// Depth-first search for the first descendant matching `type` and (optionally) an
    /// `accessibilityIdentifier`. Used to locate SwiftUI-backed UITextFields in the window
    /// hierarchy when SwiftUI's `@FocusState` doesn't reliably establish first responder.
    func firstDescendant<T: UIView>(
        ofType type: T.Type,
        accessibilityIdentifier: String? = nil
    ) -> T? {
        if let typed = self as? T,
           accessibilityIdentifier == nil || self.accessibilityIdentifier == accessibilityIdentifier {
            return typed
        }
        for subview in subviews {
            if let found = subview.firstDescendant(ofType: type, accessibilityIdentifier: accessibilityIdentifier) {
                return found
            }
        }
        return nil
    }
}

#Preview {
    EntryView(
        state: EntryState(initialValueInKilograms: 75.0),
        store: InMemoryHealthKitStore()
    )
}
