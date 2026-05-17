import Foundation
import LogWeightCore

/// Shared reminder scheduler and coordinator for the iOS app target.
enum ReminderSync {
    static let scheduler: any ReminderScheduling = UserNotificationsReminderScheduler()
    static let coordinator = ReminderCoordinator()

    @MainActor
    static func syncFromStoredSettings() async {
        await coordinator.sync(scheduler: scheduler)
    }
}
