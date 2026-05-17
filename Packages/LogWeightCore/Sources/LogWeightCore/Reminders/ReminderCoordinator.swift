import Foundation

/// Reads reminder preferences and keeps the platform scheduler in sync.
public struct ReminderCoordinator: Sendable {
    public init() {}

    /// Applies stored settings: cancels when disabled; schedules when enabled and authorized.
    ///
    /// Does not request notification permission — callers enable the toggle after `requestAuthorization()`.
    public func sync(
        defaults: UserDefaults = .standard,
        scheduler: any ReminderScheduling
    ) async {
        let settings = DailyReminderSettings.load(from: defaults)
        guard settings.enabled else {
            await scheduler.cancelDailyReminder()
            return
        }
        let status = await scheduler.authorizationStatus()
        guard status == .authorized else { return }
        do {
            try await scheduler.scheduleDailyReminder(hour: settings.hour, minute: settings.minute)
        } catch {
            // Scheduling failures are surfaced only via system settings; no health data in logs.
        }
    }

    /// Requests permission, persists `enabled`, and schedules when granted.
    ///
    /// - Returns: Final authorization status after the request.
    @discardableResult
    public func enableReminder(
        hour: Int,
        minute: Int,
        defaults: UserDefaults = .standard,
        scheduler: any ReminderScheduling
    ) async -> ReminderAuthorizationStatus {
        let status = await scheduler.requestAuthorization()
        guard status == .authorized else {
            var settings = DailyReminderSettings.load(from: defaults)
            settings.enabled = false
            settings.save(to: defaults)
            await scheduler.cancelDailyReminder()
            return status
        }
        let settings = DailyReminderSettings(enabled: true, hour: hour, minute: minute)
        settings.save(to: defaults)
        do {
            try await scheduler.scheduleDailyReminder(hour: settings.hour, minute: settings.minute)
        } catch {}
        return status
    }

    public func disableReminder(
        defaults: UserDefaults = .standard,
        scheduler: any ReminderScheduling
    ) async {
        var settings = DailyReminderSettings.load(from: defaults)
        settings.enabled = false
        settings.save(to: defaults)
        await scheduler.cancelDailyReminder()
    }

    public func updateReminderTime(
        hour: Int,
        minute: Int,
        defaults: UserDefaults = .standard,
        scheduler: any ReminderScheduling
    ) async {
        var settings = DailyReminderSettings.load(from: defaults)
        settings.hour = DailyReminderSettings.clampHour(hour)
        settings.minute = DailyReminderSettings.clampMinute(minute)
        settings.save(to: defaults)
        await sync(defaults: defaults, scheduler: scheduler)
    }
}
