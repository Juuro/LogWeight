import XCTest
import os
@testable import LogWeightCore

/// Deterministic tests for the long-press auto-repeat loop. A virtual clock
/// records every requested sleep duration without actually waiting and cancels
/// the engine task at a configured stop point so the loop terminates from a
/// known engine state instead of racing the test against the engine's yield
/// ordering.
final class LongPressRepeatEngineTests: XCTestCase {

    private static let policy = LongPressRepeatPolicy.stepButtonDefault

    /// Cancelling the task before it can complete a single sleep must still
    /// register exactly one fire. This is the contract that every press-down
    /// (even a tap immediately released) counts at least one step.
    @MainActor
    func testInitialFireHappensBeforeAnyAwait() async {
        let clock = VirtualLongPressClock()
        let recorder = FireRecorder()
        let task = Task { @MainActor in
            await runLongPressRepeatLoop(policy: Self.policy, clock: clock) {
                recorder.fire()
            }
        }
        task.cancel()
        await task.value
        XCTAssertEqual(recorder.count, 1,
                       "Exactly one fire must occur even when the task is cancelled before it can yield")
    }

    /// The very first sleep is always the configured `initialDelay`, never a
    /// repeat interval — there is no auto-repeat in the first 0.4 s.
    @MainActor
    func testFirstSleepIsInitialDelay() async {
        let clock = VirtualLongPressClock()
        let recorder = FireRecorder()
        let task = Task { @MainActor in
            await runLongPressRepeatLoop(policy: Self.policy, clock: clock) {
                recorder.fire()
            }
        }
        clock.setStopCondition(.afterSleepCount(1), cancelling: task)
        await task.value
        let sleeps = clock.recordedSleeps()
        XCTAssertEqual(sleeps.count, 1)
        XCTAssertEqual(sleeps[0], .seconds(Self.policy.initialDelay))
    }

    /// While elapsed repeat time is still inside the slow phase, every repeat
    /// sleep (i.e. every sleep after the initial-delay one) must equal
    /// `slowInterval`.
    @MainActor
    func testSlowPhaseCadenceUntilThreshold() async {
        let clock = VirtualLongPressClock()
        let recorder = FireRecorder()
        let task = Task { @MainActor in
            await runLongPressRepeatLoop(policy: Self.policy, clock: clock) {
                recorder.fire()
            }
        }
        // 6 sleeps = initial-delay + 5 slow steps; elapsed reaches 1.0 s,
        // comfortably inside the 2 s slow phase.
        clock.setStopCondition(.afterSleepCount(6), cancelling: task)
        await task.value
        let sleeps = clock.recordedSleeps()
        XCTAssertEqual(sleeps.count, 6)
        XCTAssertEqual(sleeps[0], .seconds(Self.policy.initialDelay))
        for (index, sleep) in sleeps.enumerated() where index > 0 {
            XCTAssertEqual(sleep, .seconds(Self.policy.slowInterval),
                           "Sleep at index \(index) was \(sleep), expected slow interval")
        }
    }

    /// Once accumulated repeat time exceeds the acceleration threshold the
    /// loop must switch to `fastInterval` and never go back.
    @MainActor
    func testSwitchesToFastAfterThreshold() async {
        let clock = VirtualLongPressClock()
        let recorder = FireRecorder()
        let task = Task { @MainActor in
            await runLongPressRepeatLoop(policy: Self.policy, clock: clock) {
                recorder.fire()
            }
        }
        // 20 sleeps = initial + 11 slow + 8 fast: spans the slow→fast transition.
        clock.setStopCondition(.afterSleepCount(20), cancelling: task)
        await task.value
        let sleeps = clock.recordedSleeps()
        XCTAssertEqual(sleeps.count, 20)
        XCTAssertEqual(sleeps[0], .seconds(Self.policy.initialDelay))
        guard let firstFastIndex = sleeps.firstIndex(of: .seconds(Self.policy.fastInterval)) else {
            XCTFail("Loop never switched to fast interval; sleeps: \(sleeps)")
            return
        }
        XCTAssertEqual(firstFastIndex, 12,
                       "Default policy should switch to fast on sleep #13 (initial + 11 slow + then fast); got switch at index \(firstFastIndex)")
        for sleep in sleeps[1..<firstFastIndex] {
            XCTAssertEqual(sleep, .seconds(Self.policy.slowInterval),
                           "Pre-switch sleep should be slow, got \(sleep)")
        }
        for sleep in sleeps[firstFastIndex...] {
            XCTAssertEqual(sleep, .seconds(Self.policy.fastInterval),
                           "Post-switch sleep should be fast, got \(sleep)")
        }
    }

    /// After cancellation the loop must stop firing and stop sleeping. We
    /// drive to a known stop point, let the task drain, and assert that no
    /// further fires or sleeps occur once the task has completed.
    @MainActor
    func testCancellationStopsLoopPromptly() async {
        let clock = VirtualLongPressClock()
        let recorder = FireRecorder()
        let task = Task { @MainActor in
            await runLongPressRepeatLoop(policy: Self.policy, clock: clock) {
                recorder.fire()
            }
        }
        clock.setStopCondition(.afterSleepCount(5), cancelling: task)
        await task.value
        let firesAtStop = recorder.count
        let sleepsAtStop = clock.recordedSleeps().count
        XCTAssertEqual(firesAtStop, 5)
        XCTAssertEqual(sleepsAtStop, 5)
        // Drain anything still queued; nothing more should land.
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(recorder.count, firesAtStop,
                       "Loop continued firing after cancellation")
        XCTAssertEqual(clock.recordedSleeps().count, sleepsAtStop,
                       "Loop continued sleeping after cancellation")
    }

    /// Locks down the doc-comment contract on `LongPressStepButton`: the
    /// default policy fires exactly 23 times in the first 3 s of holding
    /// (1 initial + 11 slow + 11 fast). Off-by-one at the threshold check
    /// would change this count and break the assertion.
    @MainActor
    func testFireCountInFirstThreeSecondsMatchesPolicy() async {
        let clock = VirtualLongPressClock()
        let recorder = FireRecorder()
        let task = Task { @MainActor in
            await runLongPressRepeatLoop(policy: Self.policy, clock: clock) {
                recorder.fire()
            }
        }
        clock.setStopCondition(.afterElapsedExceeds(.seconds(3.0)), cancelling: task)
        await task.value
        XCTAssertEqual(recorder.count, 23,
                       "Default policy should fire exactly 23 times in 3 virtual seconds (1 initial + 11 slow + 11 fast)")
    }
}

// MARK: - Helpers

/// Main-actor-isolated counter so the engine's `fire` closure can mutate
/// shared test state without crossing actor boundaries (the engine loop
/// itself is `@MainActor`).
@MainActor
private final class FireRecorder {
    private(set) var count: Int = 0
    func fire() { count += 1 }
}

/// A `LongPressClock` that advances virtual elapsed time by the requested
/// sleep duration without actually waiting, records every sleep, and (when
/// configured) cancels a target task once the stop condition is met.
///
/// Elapsed time is tracked as a `Duration` so accumulations are exact in
/// attoseconds — no `Date.addingTimeInterval(_:)` floating-point drift.
private final class VirtualLongPressClock: LongPressClock, @unchecked Sendable {

    enum StopCondition: Sendable {
        case afterSleepCount(Int)
        case afterElapsedExceeds(Duration)
    }

    private struct State {
        var elapsed: Duration = .zero
        var sleeps: [Duration] = []
        var stopCondition: StopCondition? = nil
        var taskToCancel: Task<Void, Never>? = nil
    }

    private let state: OSAllocatedUnfairLock<State>

    init() {
        self.state = OSAllocatedUnfairLock(initialState: State())
    }

    func sleep(for duration: Duration) async throws {
        let taskToCancel = state.withLock { current -> Task<Void, Never>? in
            current.sleeps.append(duration)
            current.elapsed += duration
            let triggered: Bool
            switch current.stopCondition {
            case .afterSleepCount(let limit):
                triggered = current.sleeps.count >= limit
            case .afterElapsedExceeds(let target):
                triggered = current.elapsed > target
            case .none:
                triggered = false
            }
            return triggered ? current.taskToCancel : nil
        }
        taskToCancel?.cancel()
        await Task.yield()
        try Task.checkCancellation()
    }

    func setStopCondition(_ condition: StopCondition, cancelling task: Task<Void, Never>) {
        state.withLock { current in
            current.stopCondition = condition
            current.taskToCancel = task
        }
    }

    func recordedSleeps() -> [Duration] {
        state.withLock { $0.sleeps }
    }
}
