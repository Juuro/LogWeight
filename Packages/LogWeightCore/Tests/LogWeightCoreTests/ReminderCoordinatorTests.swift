import XCTest
@testable import LogWeightCore

final class ReminderCoordinatorTests: XCTestCase {
    private var defaults: UserDefaults!
    private var scheduler: RecordingReminderScheduler!
    private var coordinator: ReminderCoordinator!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "ReminderCoordinatorTests")!
        defaults.removePersistentDomain(forName: "ReminderCoordinatorTests")
        scheduler = RecordingReminderScheduler()
        coordinator = ReminderCoordinator()
    }

    func testSyncWhenDisabledCancels() async {
        defaults.set(false, forKey: SettingsKey.reminderEnabled)
        await coordinator.sync(defaults: defaults, scheduler: scheduler)
        XCTAssertEqual(scheduler.cancelCount, 1)
        XCTAssertEqual(scheduler.scheduleCalls.count, 0)
    }

    func testSyncWhenEnabledAndAuthorizedSchedules() async {
        defaults.set(true, forKey: SettingsKey.reminderEnabled)
        defaults.set(9, forKey: SettingsKey.reminderHour)
        defaults.set(30, forKey: SettingsKey.reminderMinute)
        scheduler.status = .authorized
        await coordinator.sync(defaults: defaults, scheduler: scheduler)
        XCTAssertEqual(scheduler.scheduleCalls.count, 1)
        XCTAssertEqual(scheduler.scheduleCalls[0].hour, 9)
        XCTAssertEqual(scheduler.scheduleCalls[0].minute, 30)
        XCTAssertEqual(scheduler.cancelCount, 0)
    }

    func testSyncWhenEnabledButDeniedDoesNotSchedule() async {
        defaults.set(true, forKey: SettingsKey.reminderEnabled)
        scheduler.status = .denied
        await coordinator.sync(defaults: defaults, scheduler: scheduler)
        XCTAssertEqual(scheduler.scheduleCalls.count, 0)
        XCTAssertEqual(scheduler.cancelCount, 0)
    }

    func testEnableReminderWhenDeniedPersistsDisabledAndCancels() async {
        scheduler.requestResult = .denied
        let status = await coordinator.enableReminder(
            hour: 8,
            minute: 0,
            defaults: defaults,
            scheduler: scheduler
        )
        XCTAssertEqual(status, .denied)
        XCTAssertFalse(defaults.bool(forKey: SettingsKey.reminderEnabled))
        XCTAssertEqual(scheduler.cancelCount, 1)
        XCTAssertEqual(scheduler.scheduleCalls.count, 0)
    }

    func testEnableReminderWhenAuthorizedPersistsAndSchedules() async {
        scheduler.requestResult = .authorized
        let status = await coordinator.enableReminder(
            hour: 7,
            minute: 15,
            defaults: defaults,
            scheduler: scheduler
        )
        XCTAssertEqual(status, .authorized)
        XCTAssertTrue(defaults.bool(forKey: SettingsKey.reminderEnabled))
        XCTAssertEqual(defaults.integer(forKey: SettingsKey.reminderHour), 7)
        XCTAssertEqual(defaults.integer(forKey: SettingsKey.reminderMinute), 15)
        XCTAssertEqual(scheduler.scheduleCalls.count, 1)
        XCTAssertEqual(scheduler.scheduleCalls[0].hour, 7)
        XCTAssertEqual(scheduler.scheduleCalls[0].minute, 15)
    }

    func testDisableReminderCancelsAndClearsEnabled() async {
        defaults.set(true, forKey: SettingsKey.reminderEnabled)
        await coordinator.disableReminder(defaults: defaults, scheduler: scheduler)
        XCTAssertFalse(defaults.bool(forKey: SettingsKey.reminderEnabled))
        XCTAssertEqual(scheduler.cancelCount, 1)
    }

    func testDailyReminderSettingsClampsInvalidValues() {
        let settings = DailyReminderSettings(enabled: true, hour: 99, minute: -5)
        XCTAssertEqual(settings.hour, 23)
        XCTAssertEqual(settings.minute, 0)
    }

    func testUpdateReminderTimeClampsAndReschedules() async {
        defaults.set(true, forKey: SettingsKey.reminderEnabled)
        scheduler.status = .authorized
        await coordinator.updateReminderTime(hour: 25, minute: 70, defaults: defaults, scheduler: scheduler)
        XCTAssertEqual(defaults.integer(forKey: SettingsKey.reminderHour), 23)
        XCTAssertEqual(defaults.integer(forKey: SettingsKey.reminderMinute), 59)
        XCTAssertEqual(scheduler.scheduleCalls.count, 1)
        XCTAssertEqual(scheduler.scheduleCalls[0].hour, 23)
        XCTAssertEqual(scheduler.scheduleCalls[0].minute, 59)
    }
}

private struct ScheduleCall: Equatable {
    let hour: Int
    let minute: Int
}

private final class RecordingReminderScheduler: ReminderScheduling, @unchecked Sendable {
    var status: ReminderAuthorizationStatus = .notDetermined
    var requestResult: ReminderAuthorizationStatus = .authorized
    private(set) var scheduleCalls: [ScheduleCall] = []
    private(set) var cancelCount = 0

    func authorizationStatus() async -> ReminderAuthorizationStatus {
        status
    }

    func requestAuthorization() async -> ReminderAuthorizationStatus {
        status = requestResult
        return requestResult
    }

    func scheduleDailyReminder(hour: Int, minute: Int) async throws {
        scheduleCalls.append(ScheduleCall(hour: hour, minute: minute))
    }

    func cancelDailyReminder() async {
        cancelCount += 1
    }
}
