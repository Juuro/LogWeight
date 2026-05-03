import AppKit
import HealthKit
import SwiftUI
import LogWeightCore

/// Menu-bar window: type a value and press **Return** to save (fastest path on macOS).
/// ± steppers and **Save** mirror iOS; **History** opens a document window; **Settings…** opens system Preferences.
struct MacMenuBarEntryView: View {

    @Bindable var state: EntryState
    let store: HealthKitStore

    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    @AppStorage(SettingsKey.unitPreference) private var unitPreferenceRaw: String = WeightUnit.kilograms.rawValue
    @AppStorage(SettingsKey.hapticsEnabled) private var hapticsEnabled: Bool = true

    @FocusState private var fieldFocused: Bool
    @State private var text: String = ""
    /// Shown when the text field doesn’t parse as a weight (does not touch `saveStatus`).
    @State private var parseHint: String?

    private var displayUnit: WeightUnit {
        WeightUnit(rawValue: unitPreferenceRaw) ?? .kilograms
    }

    private var formatter: WeightFormatter {
        WeightFormatter(locale: .current, fractionDigits: 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Body weight")
                .font(.headline)
                .foregroundStyle(.secondary)

            TextField("Weight", text: $text)
                .focused($fieldFocused)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .onSubmit {
                    Task { @MainActor in await commitFromField() }
                }
                .accessibilityIdentifier("mac.entry.weight")

            HStack(spacing: 12) {
                LongPressStepButton(action: { state.decrement(); syncTextFromState() }) {
                    Image(systemName: "minus")
                        .frame(minWidth: 44, minHeight: 32)
                }

                LongPressStepButton(action: { state.increment(); syncTextFromState() }) {
                    Image(systemName: "plus")
                        .frame(minWidth: 44, minHeight: 32)
                }

                Spacer(minLength: 8)

                Button("Save") {
                    Task { @MainActor in await commitFromField() }
                }
                .disabled(state.saveStatus == .saving)
            }

            statusLine

            HStack(spacing: 12) {
                Button("History…") {
                    openWindow(id: "history")
                }
                .keyboardShortcut("n", modifiers: .command)
                Button("Settings…") {
                    openSettings()
                }
                Spacer()
            }
            .font(.subheadline)
        }
        .padding(20)
        .frame(minWidth: 300, maxWidth: 360)
        .onAppear {
            syncTextFromState()
            fieldFocused = true
        }
        .onChange(of: state.saveStatus) { _, new in
            if case .savedAt = new {
                parseHint = nil
                playSuccessHapticIfEnabled()
                syncTextFromState()
            }
        }
        .privacySensitive()
    }

    @ViewBuilder
    private var statusLine: some View {
        if let parseHint = parseHint {
            Text(parseHint)
                .font(.callout)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 22, alignment: .leading)
        } else {
            switch state.saveStatus {
            case .idle, .saving:
                Text(" ")
                    .font(.callout)
                    .frame(height: 22, alignment: .leading)
                    .hidden()
            case .savedAt:
                Text("Saved to Apple Health")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(height: 22, alignment: .leading)
            case .failed(let code):
                Text(saveFailureMessage(code: code))
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func syncTextFromState() {
        text = String(
            format: "%.1f",
            Measurement(value: state.displayValueInKilograms, unit: UnitMass.kilograms)
                .converted(to: displayUnit.unitMass)
                .value
        )
    }

    private func commitFromField() async {
        guard let kg = formatter.parseToKilograms(text, unit: displayUnit) else {
            parseHint = "Enter a number using digits and a decimal separator (e.g. 75,5 or 75.5)."
            return
        }
        parseHint = nil
        state.setValue(kg, unit: .kilograms)
        await state.commit(store: store)
    }

    private func playSuccessHapticIfEnabled() {
        guard hapticsEnabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
    }

    private func saveFailureMessage(code: Int) -> String {
        if code == HKError.Code.errorAuthorizationDenied.rawValue {
            return "LogWeight can’t write to Apple Health. Open System Settings → Privacy & Security → Health → LogWeight, then enable Body Mass."
        }
        if code == HKError.Code.errorHealthDataUnavailable.rawValue {
            return "Health data isn’t available on this Mac. LogWeight can’t save here."
        }
        if code == -3 {
            return "Health access was denied. Allow it in System Settings → Privacy & Security → Health → LogWeight."
        }
        return "Save failed. Check Apple Health permissions in System Settings."
    }
}

#if DEBUG
#Preview {
    MacMenuBarEntryView(state: EntryState(initialValueInKilograms: 72.4), store: InMemoryHealthKitStore())
        .frame(width: 340, height: 260)
}
#endif
