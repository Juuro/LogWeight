import SwiftUI
import LogWeightCore
#if os(iOS)
import UIKit
#endif

struct SettingsView: View {

    @AppStorage(SettingsKey.unitPreference) private var unitPreferenceRaw: String = WeightUnit.kilograms.rawValue
    @AppStorage(SettingsKey.defaultEntryMode) private var defaultEntryModeRaw: String = DefaultEntryMode.lastSaved.rawValue
    @AppStorage(SettingsKey.hapticsEnabled) private var hapticsEnabled: Bool = true
    @AppStorage(SettingsKey.trendArrowEnabled) private var trendArrowEnabled: Bool = true
    @AppStorage(SettingsKey.reminderEnabled) private var reminderEnabled: Bool = false
    @AppStorage(SettingsKey.reminderHour) private var reminderHour: Int = DailyReminderSettings.defaultHour
    @AppStorage(SettingsKey.reminderMinute) private var reminderMinute: Int = DailyReminderSettings.defaultMinute

    @State private var reminderAuthStatus: ReminderAuthorizationStatus = .notDetermined
    @State private var isUpdatingReminder = false
    @State private var pendingReminderEnabled: Bool?

    @Environment(\.dismiss) private var dismiss

#if os(iOS)
    private let reminderCoordinator = ReminderCoordinator()
    private let reminderScheduler: any ReminderScheduling = UserNotificationsReminderScheduler()
#endif

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
                    .accessibilityIdentifier("settings.unit")
                }

                Section("Entry") {
                    Picker("Pre-fill with", selection: $defaultEntryModeRaw) {
                        Text("Last saved").tag(DefaultEntryMode.lastSaved.rawValue)
                        Text("Fixed value").tag(DefaultEntryMode.fixedValue.rawValue)
                    }
                    .accessibilityIdentifier("settings.prefill")
                    Toggle("Haptic feedback on save", isOn: $hapticsEnabled)
                        .accessibilityIdentifier("settings.haptics")
                }

                Section("Display") {
                    Toggle("Show trend arrow", isOn: $trendArrowEnabled)
                        .accessibilityIdentifier("settings.trendArrow")
                }

#if os(iOS)
                Section("Reminders") {
                    Toggle("Daily reminder", isOn: reminderEnabledBinding)
                        .accessibilityIdentifier("settings.reminder.toggle")
                        .disabled(isUpdatingReminder)

                    if reminderEnabled {
                        DatePicker(
                            "Reminder time",
                            selection: reminderTimeBinding,
                            displayedComponents: .hourAndMinute
                        )
                        .accessibilityIdentifier("settings.reminder.time")
                        .disabled(isUpdatingReminder)
                    }

                    if reminderAuthStatus == .denied {
                        Text("Notifications are turned off. Enable them in Settings to get daily reminders.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                            Link("Open Settings", destination: settingsURL)
                        }
                    }
                }
#endif

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

                Text("Made with 🩷🩵 by Juuronina GbR.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .navigationTitle("Settings")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: unitPreferenceRaw) { _, _ in
                WeightDisplayPreferences.mirrorUnitPreferenceToAppGroup()
                WidgetTimelineRefresh.reloadEntryAndChartWidgets()
            }
            .onChange(of: trendArrowEnabled) { _, _ in
                TrendArrowPreferences.mirrorToAppGroup()
                WidgetTimelineRefresh.reloadEntryAndChartWidgets()
            }
#if os(iOS)
            .task {
                reminderAuthStatus = await reminderScheduler.authorizationStatus()
            }
#endif
        }
    }

#if os(iOS)
    private var reminderEnabledBinding: Binding<Bool> {
        Binding(
            get: { reminderEnabled },
            set: { newValue in
                Task { await setReminderEnabled(newValue) }
            }
        )
    }

    private var reminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                components.hour = reminderHour
                components.minute = reminderMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                let hour = components.hour ?? DailyReminderSettings.defaultHour
                let minute = components.minute ?? DailyReminderSettings.defaultMinute
                guard hour != reminderHour || minute != reminderMinute else { return }
                reminderHour = hour
                reminderMinute = minute
                guard reminderEnabled else { return }
                Task { await rescheduleReminderTime() }
            }
        )
    }

    @MainActor
    private func setReminderEnabled(_ enabled: Bool) async {
        if isUpdatingReminder {
            pendingReminderEnabled = enabled
            return
        }
        isUpdatingReminder = true
        defer {
            isUpdatingReminder = false
            if let pending = pendingReminderEnabled {
                pendingReminderEnabled = nil
                Task { await setReminderEnabled(pending) }
            }
        }

        if enabled {
            let status = await reminderCoordinator.enableReminder(
                hour: reminderHour,
                minute: reminderMinute,
                scheduler: reminderScheduler
            )
            reminderAuthStatus = status
            reminderEnabled = status == .authorized
        } else {
            await reminderCoordinator.disableReminder(scheduler: reminderScheduler)
            reminderEnabled = false
            reminderAuthStatus = await reminderScheduler.authorizationStatus()
        }
    }

    @MainActor
    private func rescheduleReminderTime() async {
        if isUpdatingReminder {
            return
        }
        isUpdatingReminder = true
        defer { isUpdatingReminder = false }
        await reminderCoordinator.updateReminderTime(
            hour: reminderHour,
            minute: reminderMinute,
            scheduler: reminderScheduler
        )
        reminderAuthStatus = await reminderScheduler.authorizationStatus()
    }
#endif
}

#if DEBUG
#Preview {
    SettingsView()
}
#endif
