import SwiftUI
import LogWeightCore

struct SettingsView: View {

    @AppStorage(SettingsKey.unitPreference) private var unitPreferenceRaw: String = WeightUnit.kilograms.rawValue
    @AppStorage(SettingsKey.defaultEntryMode) private var defaultEntryModeRaw: String = DefaultEntryMode.lastSaved.rawValue
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
                    .pickerStyle(.segmented)
                }

                Section("Entry") {
                    Picker("Pre-fill with", selection: $defaultEntryModeRaw) {
                        Text("Last saved").tag(DefaultEntryMode.lastSaved.rawValue)
                        Text("Fixed value").tag(DefaultEntryMode.fixedValue.rawValue)
                    }
                    Toggle("Haptic feedback on save", isOn: $hapticsEnabled)
                }

                Section("Apple Health") {
                    Link(destination: URL(string: "x-apple-health://")!) {
                        Label("Open Apple Health", systemImage: "heart.text.square")
                    }
                    Text("Your weight history lives in Apple Health. Edit, delete, or export it from the Health app.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("About") {
                    Text("LogWeight saves only to Apple Health on this device. Nothing leaves your device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
