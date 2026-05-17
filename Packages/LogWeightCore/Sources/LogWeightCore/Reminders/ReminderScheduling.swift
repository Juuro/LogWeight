import Foundation

/// Notification permission state for daily reminders (no `UserNotifications` types).
public enum ReminderAuthorizationStatus: Sendable, Equatable {
    case notDetermined
    case denied
    case authorized
}

/// Abstraction over local notification scheduling for daily weight-log reminders.
public protocol ReminderScheduling: Sendable {
    func authorizationStatus() async -> ReminderAuthorizationStatus
    func requestAuthorization() async -> ReminderAuthorizationStatus
    func scheduleDailyReminder(hour: Int, minute: Int) async throws
    func cancelDailyReminder() async
}

/// Fixed identifier for the repeating daily reminder request.
public enum ReminderNotificationIdentifier {
    public static let dailyWeightLog = "daily-weight-log"
}

/// Localization keys for notification copy (English keys match `Localizable.strings`).
public enum ReminderNotificationCopy {
    public static let titleKey = "Log your weight"
    public static let bodyKey = "Open LogWeight to record today's weight."
}
