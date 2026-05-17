import Foundation
import LogWeightCore
import UserNotifications

/// Production `ReminderScheduling` backed by `UNUserNotificationCenter`.
struct UserNotificationsReminderScheduler: ReminderScheduling, Sendable {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func authorizationStatus() async -> ReminderAuthorizationStatus {
        let settings = await center.notificationSettings()
        return map(settings.authorizationStatus)
    }

    func requestAuthorization() async -> ReminderAuthorizationStatus {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            return granted ? .authorized : .denied
        } catch {
            return .denied
        }
    }

    func scheduleDailyReminder(hour: Int, minute: Int) async throws {
        await cancelDailyReminder()

        let content = UNMutableNotificationContent()
        content.title = String(localized: String.LocalizationValue(ReminderNotificationCopy.titleKey))
        content.body = String(localized: String.LocalizationValue(ReminderNotificationCopy.bodyKey))
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = DailyReminderSettings.clampHour(hour)
        dateComponents.minute = DailyReminderSettings.clampMinute(minute)

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: ReminderNotificationIdentifier.dailyWeightLog,
            content: content,
            trigger: trigger
        )
        try await center.add(request)
    }

    func cancelDailyReminder() async {
        center.removePendingNotificationRequests(
            withIdentifiers: [ReminderNotificationIdentifier.dailyWeightLog]
        )
    }

    private func map(_ status: UNAuthorizationStatus) -> ReminderAuthorizationStatus {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized, .provisional, .ephemeral:
            return .authorized
        @unknown default:
            return .denied
        }
    }
}
