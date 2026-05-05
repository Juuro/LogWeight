import Foundation

/// Timing policy for an auto-repeating long-press control.
///
/// All values are seconds. The default `stepButtonDefault` matches the cadence
/// described in `LongPressStepButton`: an immediate fire on press-down, a
/// 0.4 s pause, then a 0.2 s slow phase that switches to a 0.04 s fast phase
/// after 2 s of repeating.
///
/// Held in `LogWeightCore` so the loop logic can be unit-tested with a virtual
/// clock without depending on SwiftUI or real-time `Task.sleep`.
public struct LongPressRepeatPolicy: Sendable, Equatable {

    /// Delay between the initial press and the first auto-repeat step.
    public let initialDelay: TimeInterval

    /// Auto-repeat interval during the slow phase.
    public let slowInterval: TimeInterval

    /// Auto-repeat interval after acceleration kicks in.
    public let fastInterval: TimeInterval

    /// How long the slow phase lasts (measured from the start of repeating)
    /// before acceleration takes over.
    public let accelerationThreshold: TimeInterval

    public init(
        initialDelay: TimeInterval,
        slowInterval: TimeInterval,
        fastInterval: TimeInterval,
        accelerationThreshold: TimeInterval
    ) {
        self.initialDelay = initialDelay
        self.slowInterval = slowInterval
        self.fastInterval = fastInterval
        self.accelerationThreshold = accelerationThreshold
    }

    /// Default policy used by `LongPressStepButton` for +/- weight stepping.
    public static let stepButtonDefault = LongPressRepeatPolicy(
        initialDelay: 0.4,
        slowInterval: 0.2,
        fastInterval: 0.04,
        accelerationThreshold: 2.0
    )
}

/// Abstraction over the only piece of real-time the auto-repeat loop needs:
/// sleeping. Production uses `SystemLongPressClock`; tests substitute a
/// virtual clock that records and short-circuits sleeps.
///
/// Conformers MUST be safe to call from any concurrency context.
public protocol LongPressClock: Sendable {
    /// Suspends for `duration`. Implementations MUST throw `CancellationError`
    /// (or otherwise return promptly) when the surrounding `Task` is cancelled,
    /// so the repeat loop can exit on release.
    func sleep(for duration: Duration) async throws
}

/// Production clock backed by `Task.sleep`.
public struct SystemLongPressClock: LongPressClock {

    public init() {}

    public func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}

/// Drives the auto-repeat loop for a press-and-hold control.
///
/// Lifecycle:
/// 1. Fires `fire()` immediately so even a press cancelled before
///    `initialDelay` registers exactly one step. (This matches the contract
///    documented on `LongPressStepButton`.)
/// 2. Sleeps for `policy.initialDelay`. If the surrounding task is cancelled
///    during the sleep, the function returns without firing again.
/// 3. Enters the slow phase: fires, sleeps `policy.slowInterval`, repeats.
/// 4. Once accumulated elapsed repeat time exceeds `policy.accelerationThreshold`,
///    the interval switches to `policy.fastInterval` for the rest of the press.
/// 5. The loop terminates when `Task.isCancelled` becomes true (typically when
///    the gesture's `.onEnded` cancels the wrapping task).
///
/// Elapsed time is tracked via exact `Duration` arithmetic on the configured
/// intervals — not by subtracting wall-clock `Date`s — so the slow→fast switch
/// happens at a deterministic iteration regardless of floating-point rounding
/// of `Date.addingTimeInterval(_:)` accumulations.
///
/// The function is `@MainActor`-isolated so `fire` can mutate UI / observable
/// state directly without `await`. Callers should run it inside a
/// `Task { @MainActor in await runLongPressRepeatLoop(...) }`.
@MainActor
public func runLongPressRepeatLoop<Clock: LongPressClock>(
    policy: LongPressRepeatPolicy,
    clock: Clock,
    fire: () -> Void
) async {
    fire()
    try? await clock.sleep(for: .seconds(policy.initialDelay))
    if Task.isCancelled { return }

    var elapsed: Duration = .zero
    var interval = policy.slowInterval
    while !Task.isCancelled {
        fire()
        try? await clock.sleep(for: .seconds(interval))
        elapsed += .seconds(interval)
        if interval == policy.slowInterval,
           elapsed > .seconds(policy.accelerationThreshold) {
            interval = policy.fastInterval
        }
    }
}
