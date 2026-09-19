import SwiftUI
import LogWeightCore
#if os(iOS)
import UIKit
#endif

struct SettingsView: View {

    @AppStorage(SettingsKey.unitPreference) private var unitPreferenceRaw: String = WeightUnit.kilograms.rawValue
    @AppStorage(SettingsKey.defaultEntryMode) private var defaultEntryModeRaw: String = DefaultEntryMode.lastSaved.rawValue
    @AppStorage(SettingsKey.hapticsEnabled) private var hapticsEnabled: Bool = true
    @AppStorage(SettingsKey.reminderEnabled) private var reminderEnabled: Bool = false
    @AppStorage(SettingsKey.reminderHour) private var reminderHour: Int = DailyReminderSettings.defaultHour
    @AppStorage(SettingsKey.reminderMinute) private var reminderMinute: Int = DailyReminderSettings.defaultMinute

    @State private var reminderAuthStatus: ReminderAuthorizationStatus = .notDetermined
    @State private var isUpdatingReminder = false
    @State private var pendingReminderEnabled: Bool?

    @Environment(\.dismiss) private var dismiss
#if os(iOS)
    @Environment(\.openURL) private var openURL
    @State private var showsEmailCopiedAlert = false
#endif

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

#if os(iOS)
                Section("Support") {
                    NavigationLink {
                        TipJarView()
                    } label: {
                        Label("Support LogWeight", systemImage: "heart")
                    }
                    .accessibilityIdentifier("settings.tipjar")
                }

                Section("Feedback") {
                    Button {
                        sendFeedbackEmail()
                    } label: {
                        Label("Send feedback", systemImage: "envelope")
                    }
                    .accessibilityIdentifier("settings.feedback.email")

                    Link(destination: FeedbackLinks.writeReviewURL) {
                        Label("Rate LogWeight on the App Store", systemImage: "star")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityIdentifier("settings.feedback.rate")

                    Text("Feedback emails include only your app version, iOS version, and device model. No health data is attached.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
#endif

                Section("Apple Health") {
                    Link(destination: URL(string: "x-apple-health://")!) {
                        Label("Open Apple Health", systemImage: "heart.text.square")
                            .fixedSize(horizontal: false, vertical: true)
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
#if os(iOS)
            .task {
                reminderAuthStatus = await reminderScheduler.authorizationStatus()
            }
            .alert("Email address copied", isPresented: $showsEmailCopiedAlert) {
            } message: {
                Text(FeedbackLinks.supportAddress)
            }
#endif
        }
    }

#if os(iOS)
    /// Opens a prefilled mail draft. If no mail app can handle it, copies the
    /// support address so the user can write from any client.
    private func sendFeedbackEmail() {
        let subject = String(localized: "LogWeight feedback")
        guard let url = FeedbackLinks.mailtoURL(subject: subject, diagnostics: Self.feedbackDiagnostics()) else {
            copySupportAddress()
            return
        }
        openURL(url) { accepted in
            if !accepted { copySupportAddress() }
        }
    }

    private func copySupportAddress() {
        UIPasteboard.general.string = FeedbackLinks.supportAddress
        showsEmailCopiedAlert = true
    }

    private static func feedbackDiagnostics() -> FeedbackLinks.Diagnostics {
        let info = Bundle.main.infoDictionary
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafeBytes(of: &systemInfo.machine) { buffer in
            String(decoding: buffer.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
        let model = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? machine
        return FeedbackLinks.Diagnostics(
            appVersion: info?["CFBundleShortVersionString"] as? String ?? "?",
            build: info?["CFBundleVersion"] as? String ?? "?",
            osVersion: UIDevice.current.systemVersion,
            deviceModel: model
        )
    }

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
