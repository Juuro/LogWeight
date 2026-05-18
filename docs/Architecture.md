# Architecture

This document records the architectural decisions that shape Phase 1. Decisions are pulled from the JMAT planning report at `docs/jmat-reports/2026-04-27-logweight-multiplatform-plan.md`.

## ADR-001 — One Xcode multiplatform project, one shared SPM package

**Status:** accepted (Phase 1).

**Decision.** A single Xcode project (managed by XcodeGen, see ADR-005) hosts every platform target. Business logic lives in a local Swift Package — `Packages/LogWeightCore/` — that is consumed by every app target. Per-platform UI lives in `App/<Platform>/`.

**Rationale.** Phase 1 shipped iOS first; **Phase 2** adds a watchOS companion (`LogWeightWatchApp`) plus an embedded WidgetKit extension, both depending on the same `LogWeightCore` package. **Phase 3** adds `LogWeightMac` (menu-bar SwiftUI app, no dock icon) on macOS 14+. The watch target compiles `App/Shared` but excludes `SettingsView.swift` because watchOS does not support `.pickerStyle(.segmented)`; the Watch uses `WatchSettingsView` instead. Putting business logic in a Package means each app target reuses identical, tested code. SPM is the lowest-friction way to share Swift code across Apple platforms — no third-party module manager required.

## ADR-002 — MV with `@Observable`, no separate ViewModel layer

**Status:** accepted.

**Decision.** State classes live alongside views and use the `Observation` framework (`@Observable`). There is no `ViewModel` folder, no Combine plumbing, no `ObservableObject` boilerplate. Tests inject `HealthKitStore` directly into the state class.

**Rationale.** SwiftUI's MV pattern with `@Observable` IS the lightweight VM. A separate VM layer would add ceremony without adding testability. `EntryState` is a plain `@MainActor @Observable final class`. iOS 17+ minimum makes this approach the canonical choice.

## ADR-003 — `HealthKitStore` protocol abstracts `HKHealthStore`

**Status:** accepted.

**Decision.** All HealthKit interaction goes through the `HealthKitStore` protocol in `LogWeightCore`. Production uses `HKHealthStoreAdapter`; tests and previews use `InMemoryHealthKitStore`. The protocol surface uses only Foundation types — `LogWeightCore` does NOT export `HealthKit` types in its public API.

**Rationale.** HealthKit cannot be exercised in CI without entitlements. The protocol abstraction keeps every code path that doesn't actually call `HKHealthStore` testable in CI. The protocol intentionally returns `Void` from `save` (DA3 fix) — record identity is a HealthKit detail, not a domain concept.

## ADR-004 — Apple Health is the sole source of truth

**Status:** accepted.

**Decision.** LogWeight does not maintain a separate weight database. Every read goes through `HealthKitStore.recentWeights(...)` which queries `HKHealthStore` directly. The app stores no weight values in `UserDefaults`, `Keychain`, files, or memory beyond the lifetime of the entry surface.

**Rationale.** This is a user constraint and a privacy constraint. It also fundamentally simplifies sync: HealthKit syncs across the user's devices natively, so we get cross-device history for free.

## ADR-005 — XcodeGen for the project file

**Status:** accepted.

**Decision.** `project.yml` is the source of truth. Anyone clones the repo, runs `xcodegen generate`, and gets a working `LogWeight.xcodeproj`. The generated `.xcodeproj` is gitignored. CI runs XcodeGen on every build.

**Rationale.** Hand-authored `.pbxproj` files are merge-conflict magnets. XcodeGen's YAML format is reviewable, diffable, and reproducible. CI verifies that `project.yml` produces a buildable project on every commit.

## ADR-006 — Privacy is enforced by API surface, not convention

**Status:** accepted.

**Decision.** `SecurityLog` exposes only `event(_:)` (StaticString) and `error(_:code:)` (Int). There is no overload that accepts a `Double`, `String`, `Date`, or `Weight`. Health values cannot be logged because the API does not allow it.

**Rationale.** GDPR Art. 9 data demands defence-in-depth. Convention ("don't log values") fails under stress; an API that rejects values at compile time succeeds.

## ADR-007 — Stepper-primary entry, keyboard secondary

**Status:** accepted.

**Decision.** The primary entry path is the ± stepper. If Apple Health has no body-mass samples (confirmed after a successful read), EntryView opens with the decimal pad over the big number. Save stays enabled while the keyboard is up and commits the typed value in one tap. After the first saved sample, the big number is stepper-only; double-tap restores the last logged weight.

**Rationale.** The Devil's Advocate (DA1) flagged that a Save button in the safe-area inset is occluded by the decimal-pad keyboard on every iPhone. The user chose stepper-primary at the approval gate. This eliminates the keyboard from the median entry path entirely.

## ADR-008 — `AsyncStream` from `HKObserverQuery` invalidates on consumer cancellation

**Status:** accepted.

**Decision.** `HealthKitStore.observeChanges()` returns an `AsyncStream<Void>` built via `AsyncStream.makeStream()`. The producer side holds the underlying observer (e.g. `HKObserverQuery` or in-memory continuation list) in a class-bound holder so `continuation.onTermination` can stop it. Cancelling the consuming `Task` MUST stop the underlying observer.

**Rationale.** DA4 highlighted memory-leak and silent-termination risks in the bridge from `HKObserverQuery` to `AsyncStream`. The contract is now explicit in the protocol comments and verified by `InMemoryHealthKitStoreTests.testObserveChangesStopsWhenConsumerCancels`.

## ADR-009 — History chart is additive; list remains canonical

**Status:** accepted (Phase 4).

**Decision.** `HistoryView` now renders a compact Swift Charts trend (`LineMark` + `PointMark`) on iOS/iPadOS/macOS, while keeping the timestamped list beneath it. watchOS keeps list-only presentation.

**Rationale.** The chart satisfies AC4 without creating a second data model or hiding precise values. The list remains the authoritative, auditable view of each sample.

## ADR-010 — iOS UI tests cover accessibility-critical paths

**Status:** accepted (Phase 4).

**Decision.** iOS UI tests now include history/chart visibility, settings controls, keyboard-save guard, and an `Accessibility XXXL` save flow in addition to smoke save.

**Rationale.** This captures common regressions (layout clipping, control discovery, broken save path) while keeping CI runtime practical.
