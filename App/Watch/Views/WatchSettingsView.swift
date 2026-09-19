import SwiftUI
import LogWeightCore

/// Minimal watch settings (unit + haptics). Full settings remain on iPhone.
struct WatchSettingsView: View {

    @AppStorage(SettingsKey.unitPreference) private var unitPreferenceRaw: String = WeightUnit.kilograms.rawValue
    @AppStorage(SettingsKey.hapticsEnabled) private var hapticsEnabled: Bool = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Units") {
                    Picker("Display unit", selection: $unitPreferenceRaw) {
                        ForEach(WeightUnit.allCases, id: \.rawValue) { unit in
                            Text(unit.shortDisplayName).tag(unit.rawValue)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }
                Section("Feedback") {
                    Toggle("Haptics on save", isOn: $hapticsEnabled)
                }
                Section("About") {
                    Text("Made with 🩷🩵 by Juuronina GbR.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    WatchSettingsView()
}
#endif
