import Foundation

/// User-configured daily weight-log reminder (stored in `UserDefaults`).
public struct DailyReminderSettings: Sendable, Equatable {
    public static let defaultHour = 8
    public static let defaultMinute = 0

    public var enabled: Bool
    public var hour: Int
    public var minute: Int

    public init(enabled: Bool, hour: Int, minute: Int) {
        self.enabled = enabled
        self.hour = Self.clampHour(hour)
        self.minute = Self.clampMinute(minute)
    }

    public static func load(from defaults: UserDefaults = .standard) -> DailyReminderSettings {
        DailyReminderSettings(
            enabled: defaults.bool(forKey: SettingsKey.reminderEnabled),
            hour: defaults.object(forKey: SettingsKey.reminderHour) as? Int ?? defaultHour,
            minute: defaults.object(forKey: SettingsKey.reminderMinute) as? Int ?? defaultMinute
        )
    }

    public func save(to defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: SettingsKey.reminderEnabled)
        defaults.set(hour, forKey: SettingsKey.reminderHour)
        defaults.set(minute, forKey: SettingsKey.reminderMinute)
    }

    public static func clampHour(_ hour: Int) -> Int {
        min(23, max(0, hour))
    }

    public static func clampMinute(_ minute: Int) -> Int {
        min(59, max(0, minute))
    }
}
