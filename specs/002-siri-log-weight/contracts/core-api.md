# Contract: `WeightLogger` (LogWeightCore)

Foundation-friendly, no HealthKit types (Constitution I). Signatures are the contract; bodies are implementation.

```swift
public struct WeightLogPolicy: Sendable, Equatable {
    public var plausibleRangeKilograms: ClosedRange<Double>   // 20...500
    public var largeJumpKilograms: Double                      // 10
    public var duplicateWindow: TimeInterval                   // 60
    public var duplicateToleranceKilograms: Double             // 0.05
    public static let `default`: WeightLogPolicy
}

public enum WeightLogConfirmationReason: Sendable, Equatable { case outOfRange, largeJump }

public enum WeightLogEvaluation: Sendable, Equatable {
    case ready(Weight)
    case needsConfirmation(Weight, WeightLogConfirmationReason)
    case duplicate(Weight)
    case accessNotGranted
    case invalid
}

public enum WeightLogOutcome: Sendable, Equatable {
    case saved(Weight)
    case alreadyLogged(Weight)
    case declined
    case accessNotGranted
    case invalid
    case failed(reasonCode: Int)
}

public struct WeightLogger: Sendable {
    public init(store: any HealthKitStore,
                policy: WeightLogPolicy = .default,
                now: @escaping @Sendable () -> Date = { .now })

    /// Checks a request without writing. Reads at most the newest sample.
    public func evaluate(kilograms: Double) async -> WeightLogEvaluation

    /// Writes the weight. Never logs the value; maps errors to `.failed(reasonCode:)`.
    public func save(_ weight: Weight) async -> WeightLogOutcome
}
```

## Behavioral guarantees (each has a test in `WeightLoggerTests`)

1. `evaluate` never writes. `save` writes exactly once and never retries.
2. Not `.sharingAuthorized` -> `.accessNotGranted`, store untouched.
3. `NaN`, infinite, `<= 0` -> `.invalid` (not confirmable).
4. Empty store (first entry) with a value inside the range -> `.ready`.
5. Value outside `plausibleRangeKilograms` -> `.needsConfirmation(_, .outOfRange)`.
6. |value - newest| > `largeJumpKilograms` -> `.needsConfirmation(_, .largeJump)`.
7. Within `duplicateToleranceKilograms` of the newest sample and newest sample age <= `duplicateWindow` -> `.duplicate`; a different value in the window -> normal path.
8. `recentWeights` throwing during `evaluate` -> treated as "no previous sample" (range check still applies); no crash.
9. `save` failure -> `.failed(reasonCode:)` using the `HealthKitError` code; no value in the outcome's description or any `SecurityLog` call.
10. Only `SecurityLog.event(_:)` with literal names and `SecurityLog.error(_:code:)` are used.
