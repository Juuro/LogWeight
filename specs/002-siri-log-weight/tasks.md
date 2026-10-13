---

description: "Task list for Voice and Shortcut Weight Logging"
---

# Tasks: Voice and Shortcut Weight Logging

**Input**: Design documents from `/specs/002-siri-log-weight/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/core-api.md, contracts/intent-contract.md, quickstart.md

**Status (2026-10-13)**: PAUSED. 25 of 32 tasks done; remaining tasks are device checks (T011, T013, T018, T022, T027, part of T030) and the commit task. Reason: voice decimals ("68,9") were not resolved by Siri on a German device when the weight was a measurement; the intent now takes a plain number plus optional unit, which has not been re-verified. Siri AI (schema-based) is unavailable to EU developers on iOS 27 and has no health domain.

**Tests**: Included for Core logic (`swift test` with `InMemoryHealthKitStore`, per plan.md and Constitution IV). App Intents behavior (Siri routing, lock state, automations) is validated by the manual device matrix in `quickstart.md`; those tasks are marked **[DEVICE]** and need a physical iPhone and the maintainer.

**Organization**: Grouped by user story, in priority order: US1 (P1), US2 (P2), US3 (P2), US5 (P2), US4 (P3). Every story adds its own localization keys to all 11 locales so `Tools/check-localizations.sh` (runs in the pre-commit hook) passes after each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: User story the task belongs to (US1 to US5)
- All paths are relative to the repository root (`/Users/juuro/Repos/LogWeight`)
- Locales (11): `en de fr es it nl pt-BR ja ko zh-Hans zh-Hant`. `Localizable.strings` lives in `App/Shared/Resources/<locale>.lproj/`.
- Never log weights, dates, or spoken text. Only `SecurityLog.event(_:)` with literal names and `SecurityLog.error(_:code:)`.
- Do not edit `.xcodeproj`; run `xcodegen generate`. Do not bump `MARKETING_VERSION` or build numbers.
- Commit messages: Conventional Commits (`feat(intents): ...`).

## Phase 1: Setup

**Purpose**: Clean baseline and working branch

- [X] T001 Run the baseline gates and note any pre-existing failures so they are not attributed to this feature: `cd Packages/LogWeightCore && swift test` and `Tools/check-localizations.sh`
- [X] T002 Create the feature branch from `main` with the untracked `specs/002-siri-log-weight/` carried over: `git switch -c feat/siri-log-weight` (the git branch is currently `main`)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core policy and decision types that every story builds on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T003 [P] Create `Packages/LogWeightCore/Sources/LogWeightCore/WeightLogging/WeightLogPolicy.swift`: `public struct WeightLogPolicy: Sendable, Equatable` with `plausibleRangeKilograms: ClosedRange<Double>` default `20...500`, `largeJumpKilograms: Double` default `10`, `duplicateWindow: TimeInterval` default `60`, `duplicateToleranceKilograms: Double` default `0.05`, and `public static let default`. Public API must be Foundation-only (no HealthKit types) per `contracts/core-api.md`
- [X] T004 Create `Packages/LogWeightCore/Sources/LogWeightCore/WeightLogging/WeightLogger.swift` per `contracts/core-api.md`: public `WeightLogConfirmationReason` (`.outOfRange`, `.largeJump`), `WeightLogEvaluation` (`.ready(Weight)`, `.needsConfirmation(Weight, WeightLogConfirmationReason)`, `.duplicate(Weight)`, `.accessNotGranted`, `.invalid`), `WeightLogOutcome` (`.saved`, `.alreadyLogged`, `.declined`, `.accessNotGranted`, `.invalid`, `.failed(reasonCode: Int)`), and `public struct WeightLogger: Sendable` with `init(store: any HealthKitStore, policy: WeightLogPolicy = .default, now: @escaping @Sendable () -> Date = { .now })`. In this task `evaluate(kilograms:)` implements only: status not `.sharingAuthorized` -> `.accessNotGranted`; `NaN`, infinite, or `<= 0` -> `.invalid` (not confirmable); otherwise `.ready(Weight(valueInKilograms:recordedAt: now()))`. `save(_:)` calls `store.save` exactly once, never retries, maps `HealthKitError.saveFailed(reasonCode:)` to `.failed(reasonCode:)` (any other error -> `.failed(reasonCode: -1)`), and calls `SecurityLog.error("weight_log_save_failed", code:)` on failure. `evaluate` never writes. Order of checks: authorization -> validity -> (later) duplicate -> range -> jump
- [X] T005 Create `Packages/LogWeightCore/Tests/LogWeightCoreTests/WeightLoggerTests.swift` using `InMemoryHealthKitStore` and an injected fixed clock: `.accessNotGranted` for `.notDetermined` and `.sharingDenied` with the store untouched; `.invalid` for `.nan`, `.infinity`, `0`, and `-5`; `.ready` for 82.4 on an authorized empty store with `recordedAt` equal to the injected clock; `save` writes exactly one sample; `save` with `InMemoryHealthKitStore.FailureMode.saveFails(reasonCode: 7)` returns `.failed(reasonCode: 7)` and stores nothing. Run `cd Packages/LogWeightCore && swift test` and confirm it passes

**Checkpoint**: Core foundation compiles and tests pass; story work can begin

---

## Phase 3: User Story 1 - Log a spoken weight with Siri (Priority: P1) 🎯 MVP

**Goal**: "Hey Siri, log weight in LogWeight" asks for a weight, saves one entry to Apple Health, confirms it, and never opens the app. The widget Save button keeps working.

**Independent Test**: `quickstart.md` device rows 1, 2, 3, 9, 12.

- [X] T006 [US1] Add these keys to `App/Shared/Resources/<locale>.lproj/Localizable.strings` for all 11 locales, English value as the key, translated values in the other ten, matching the existing `"Save Weight" = "..."` style: `Log Weight`, `Weight`, `What's your weight?`, `Logged %@.`, `Open LogWeight once to allow access to Apple Health.`, `Enter a valid weight.`, `Couldn't log your weight. Please try again.`. Then run `Tools/check-localizations.sh`
- [X] T007 [US1] Create `App/iOS/Intents/LogWeightIntent.swift` per `contracts/intent-contract.md`: `struct LogWeightIntent: AppIntent` with `static let title: LocalizedStringResource = "Log Weight"`, `static let openAppWhenRun = false`, `static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication`, `@Parameter(title: "Weight", requestValueDialog: "What's your weight?") var weight: Measurement<UnitMass>`. `perform()` returns `some IntentResult & ReturnsValue<Measurement<UnitMass>> & ProvidesDialog`: build `WeightLogger(store: HKHealthStoreAdapter())` (the intent file must not `import HealthKit`), call `evaluate(kilograms: weight.converted(to: .kilograms).value)`; `.ready` -> `save`, then `WidgetTimelineRefresh.reloadEntryAndChartWidgets()` (same helper `SaveWeightIntent` uses; do not post `.logWeightWidgetDidSave`, do not touch `SharedWeightEntryStore`), then return the saved weight in the unit the user supplied (bare number: `WeightDisplayPreferences.preferredUnit()`) with dialog `Logged %@.` using `WeightFormatter`; `.accessNotGranted` / `.invalid` / `.failed` -> throw an error carrying the matching localized dialog (`.accessNotGranted` must NOT call `requestAuthorization()`); `.needsConfirmation` and `.duplicate` are handled in US3/US4 (for now treat as `throw` with the generic failure text so nothing unsafe is saved). Use only `SecurityLog.event` with literal names (`weight_log_saved`, `weight_log_denied`) and `SecurityLog.error`
- [X] T008 [US1] Rewrite `App/iOS/LogWeightAppShortcuts.swift` so the provider exposes exactly one `AppShortcut(intent: LogWeightIntent(), phrases: ["Log weight in \(.applicationName)", "Log my weight in \(.applicationName)", "Save weight in \(.applicationName)"], shortTitle: "Log Weight", systemImageName: "scalemass")` and no longer references `SaveWeightIntent` (FR-007); update the doc comment accordingly
- [X] T009 [P] [US1] In `App/Shared/Widget/LogWeightWidgetIntents.swift` add `static let isDiscoverable = false` to `SaveWeightIntent` (hides it from Shortcuts; behavior and `openAppWhenRun = true` unchanged, FR-014) and update its doc comment to say it is widget-only
- [X] T010 [US1] Run `xcodegen generate`, then `xcodebuild build -scheme LogWeight -destination 'platform=iOS Simulator,name=iPhone 15'`; confirm `LogWeightIntent.swift` is in the LogWeight target only (not the widget or watch targets) and that the only new warning is the expected deprecation (none until US3). Run `xcodebuild build -scheme LogWeightWatch -destination 'generic/platform=watchOS Simulator' CODE_SIGNING_ALLOWED=NO` to confirm watchOS is unaffected
- [ ] T011 [DEVICE] [US1] Run `quickstart.md` rows 1, 2, 3, 9, 12 on a physical iPhone. Record the outcome of research R1 (what unit Siri assigns to a bare spoken number). If Siri substitutes a unit other than the preferred one, implement the R1 fallback in `App/iOS/Intents/LogWeightIntent.swift` (`Double` value + optional unit `AppEnum` defaulting to `WeightDisplayPreferences.preferredUnit()`) and update `specs/002-siri-log-weight/contracts/intent-contract.md` and `research.md` R1. If the widget Save button regressed (row 12), stop and restore a minimal provider registration, then re-plan

**Checkpoint**: US1 delivers hands-free logging and is a shippable MVP

---

## Phase 4: User Story 2 - Shortcuts, Action Button, Spotlight (Priority: P2)

**Goal**: The same action works with a fixed value in Shortcuts, from the Action Button and Spotlight, and its result feeds later shortcut steps.

**Independent Test**: `quickstart.md` device row 11 plus the Controls check in T013.

- [X] T012 [US2] In `App/iOS/Intents/LogWeightIntent.swift` add `static var parameterSummary: some ParameterSummary { Summary("Log \(\.$weight)") }` and `static let description = IntentDescription("Saves your weight to Apple Health.")`; add the corresponding keys that Xcode extracts (build once and read the new entries from the build log, or inspect the generated `.stringsdata`) to `App/Shared/Resources/<locale>.lproj/Localizable.strings` for all 11 locales; run `Tools/check-localizations.sh`
- [ ] T013 [DEVICE] [US2] Run `quickstart.md` row 11: create a shortcut with a fixed value, run it from the Shortcuts app, the Action Button and Spotlight; confirm one entry per run, a visual confirmation, and that the returned weight can be used by a following step (for example "Show Result"). Also confirm FR-006: add the action to a Lock Screen / Control Center control through Shortcuts and run it

**Checkpoint**: US1 and US2 both work

---

## Phase 5: User Story 3 - First entry and unusual values (Priority: P2)

**Goal**: A first-ever entry works; implausible values and large jumps ask for confirmation; unattended runs refuse them.

**Independent Test**: `quickstart.md` device rows 4, 5, 6, 7.

- [X] T014 [US3] Extend `Packages/LogWeightCore/Tests/LogWeightCoreTests/WeightLoggerTests.swift`: first entry (empty authorized store, 80 kg) -> `.ready`; range boundaries `20` and `500` -> `.ready`, `19.9` and `500.1` -> `.needsConfirmation(_, .outOfRange)`; jump exactly `10.0` from newest -> `.ready`, `10.1` -> `.needsConfirmation(_, .largeJump)`; value that is both out of range and a large jump -> reason `.outOfRange` (precedence); `recentWeights` failing via `InMemoryHealthKitStore.FailureMode.queryFails` -> treated as no previous sample (range check still applies, no crash); `evaluate` never changes the store sample count
- [X] T015 [US3] Implement range and jump checks in `Packages/LogWeightCore/Sources/LogWeightCore/WeightLogging/WeightLogger.swift` `evaluate(kilograms:)`: after authorization and validity, read `store.recentWeights(limit: 1)` (a thrown error counts as no previous sample); value outside `policy.plausibleRangeKilograms` -> `.needsConfirmation(weight, .outOfRange)`; else if `abs(value - newest) > policy.largeJumpKilograms` -> `.needsConfirmation(weight, .largeJump)`; else `.ready`. Run `swift test` until T005 and T014 pass
- [X] T016 [US3] Add the key `%@ looks unusual. Log it anyway?` to `App/Shared/Resources/<locale>.lproj/Localizable.strings` for all 11 locales (English key, translated values) and run `Tools/check-localizations.sh`
- [X] T017 [US3] In `App/iOS/Intents/LogWeightIntent.swift` handle `.needsConfirmation`: call `requestConfirmation(result: .result(dialog: ...))` with the `%@ looks unusual. Log it anyway?` dialog, isolated in one private function (iOS 17 API; the iOS 18 replacement is unavailable at the deployment target, accept the deprecation warning and leave a one-line comment pointing to research R5). If it throws, save nothing, call `SecurityLog.event("weight_log_declined")`, and rethrow a localized error (this single path covers both a user declining and an unattended run, FR-009)
- [ ] T018 [DEVICE] [US3] Run `quickstart.md` rows 4, 5, 6, 7. Row 7 is the high-risk check: a Shortcuts automation set to "Run Immediately" with 5 kg or a 15 kg jump MUST fail without saving. If it auto-confirms and saves, implement the R5 fallback in `App/iOS/Intents/LogWeightIntent.swift` (`@Parameter var allowUnusualValue: Bool = false`; unusual values are refused unless true; drop interactive confirmation), update `contracts/intent-contract.md`, `research.md` R5, and the spec Clarifications note

**Checkpoint**: US1, US2, US3 work independently

---

## Phase 6: User Story 5 - Phrases in the user's language (Priority: P2)

**Goal**: Every supported locale has natural phrases containing the app name, enforced by the parity script.

**Independent Test**: `Tools/check-localizations.sh` passes; `quickstart.md` device row 14.

- [X] T019 [P] [US5] Create `App/iOS/Resources/<locale>.lproj/AppShortcuts.strings` for all 11 locales with exactly these three English keys in every file, each translated value containing `${applicationName}` exactly once and no `%` placeholder: `"Log weight in ${applicationName}"`, `"Log my weight in ${applicationName}"`, `"Save weight in ${applicationName}"`. The `en` file maps each key to itself. Natural phrasing per language (for example de: `Gewicht in ${applicationName} erfassen`)
- [X] T020 [US5] Extend `Tools/check-localizations.sh`: also compare the key sets of `App/iOS/Resources/<locale>.lproj/AppShortcuts.strings` against `en`, fail on missing, extra, or duplicate keys, and fail if any value lacks `${applicationName}` exactly once or contains `%`. Keep the existing `Localizable.strings` check and exit codes unchanged
- [X] T021 [US5] Prove the new check works on a throwaway copy in the scratchpad directory: copy `App/` and `Tools/` there, remove one key from one locale, then break one value's `${applicationName}`; each run must exit non-zero with a clear message. Then run `Tools/check-localizations.sh` in the real repo and confirm it passes
- [ ] T022 [DEVICE] [US5] (build and bundle check DONE: all 11 `AppShortcuts.strings` and `nlu.appintents` are in the built app, no `project.yml` change needed; device row 14 PENDING) Run `xcodegen generate` and build; confirm the built `LogWeight.app` contains `<locale>.lproj/AppShortcuts.strings` for all 11 locales (`find <DerivedData>/.../LogWeight.app -name AppShortcuts.strings`). If missing, add an explicit resources entry for `App/iOS/Resources` in `project.yml` (research R7) and regenerate. Then run `quickstart.md` row 14 for de, ja, and one more locale

**Checkpoint**: Voice entry works natively in all 11 languages

---

## Phase 7: User Story 4 - No accidental duplicates (Priority: P3)

**Goal**: Repeating the same value within 60 seconds does not create a second entry, whichever app wrote the first.

**Independent Test**: `quickstart.md` device rows 8 and 13.

- [X] T023 [US4] Extend `Packages/LogWeightCore/Tests/LogWeightCoreTests/WeightLoggerTests.swift`: newest sample equal within `0.05` kg and age `<= 60` s (fixed clock) -> `.duplicate`; age `61` s -> `.ready`; value differing by more than `0.05` kg inside the window -> normal path; a kg/lb round trip (82.4 kg -> 181.65 lb -> back) is still a duplicate; duplicate takes precedence over the range/jump confirmation
- [X] T024 [US4] Implement the duplicate check in `evaluate(kilograms:)` of `Packages/LogWeightCore/Sources/LogWeightCore/WeightLogging/WeightLogger.swift`, after validity and before range/jump: newest sample from `recentWeights(limit: 1)` with `abs(value - newest) <= policy.duplicateToleranceKilograms` and `now() - newest.recordedAt <= policy.duplicateWindow` (and not in the future) -> `.duplicate(newest)`. Run `swift test`
- [X] T025 [US4] Add the key `Already logged %@.` to `App/Shared/Resources/<locale>.lproj/Localizable.strings` for all 11 locales and run `Tools/check-localizations.sh`
- [X] T026 [US4] In `App/iOS/Intents/LogWeightIntent.swift` handle `.duplicate`: do not save, call `SecurityLog.event("weight_log_duplicate")`, and return the existing weight with the `Already logged %@.` dialog
- [ ] T027 [DEVICE] [US4] Run `quickstart.md` rows 8 and 13 (duplicate run; routing versus Apple Health's own "log my weight" phrase). Record the routing result in `research.md` R11

**Checkpoint**: All five stories work

---

## Phase 8: Polish & Cross-Cutting Concerns

- [X] T028 [P] Update `docs/Privacy.md`: add a short "Siri and Shortcuts" section (voice and Shortcuts are processed by the operating system; the app receives only a numeric weight and writes it to Apple Health; nothing leaves the device; no donations or analytics) and clarify the "does not access the microphone" line to say audio is handled by the OS, not the app
- [X] T029 [P] Add `ADR-011` to `docs/Architecture.md`, matching the existing ADR format: the voice/automation entry path is a bounded exception to stepper-first entry (ADR-007), guarded by plausibility range, large-jump confirmation, duplicate window, authentication requirement and post-save confirmation; link research R5/R6
- [ ] T030 (grep audit DONE: no print/os_log/NSLog, all `SecurityLog` calls are literals, no donations; Console.app device check PENDING) Privacy audit (SC-006): `grep -n "print(\|os_log\|Logger(\|NSLog" App/iOS/Intents/LogWeightIntent.swift Packages/LogWeightCore/Sources/LogWeightCore/WeightLogging/*.swift` must return nothing, and every `SecurityLog` call uses a string literal. [DEVICE] then attach Console.app (subsystem `dev.logweight.LogWeight`) while running `quickstart.md` rows 1, 5, 9 and confirm only event names and numeric codes appear
- [X] T031 Run the full gates (DONE: swift test 130/130, check-localizations ok, iOS tests 17/17 on iPhone 16 simulator, watchOS build ok; `iPhone 15` is not installed here) from the constitution: `cd Packages/LogWeightCore && swift test`; `Tools/check-localizations.sh`; `xcodebuild test -scheme LogWeight -destination 'platform=iOS Simulator,name=iPhone 15'`; `xcodebuild build -scheme LogWeightWatch -destination 'generic/platform=watchOS Simulator' CODE_SIGNING_ALLOWED=NO`. No UI views changed, so `Tools/CaptureScene.sh --all` is not required
- [ ] T032 Commit in logical Conventional Commits (for example `feat(core): add weight logger policy and decisions`, `feat(intents): add log weight app intent and shortcuts`, `feat(intents): localize shortcut phrases`, `docs: add siri privacy note and adr-011`); do not bump versions. Record the device-matrix outcomes (rows 2, 7, 10, 13 especially) in the PR description per `quickstart.md` section 4

---

## Dependencies & Execution Order

- **Setup (Phase 1)** -> **Foundational (Phase 2)** -> user stories -> **Polish (Phase 8)**.
- T004 depends on T003. T005 depends on T004.
- **US1** needs Phase 2. **US2** needs US1's intent file. **US3** needs US1 (intent, strings) and extends the Core logger. **US5** is independent of US2-US4 logic but should follow US1 so the phrases point at a working intent. **US4** needs US3's `evaluate` ordering (duplicate sits before range/jump).
- Same-file chains (not parallel): `LogWeightIntent.swift` (T007, T012, T017, T026, and the T011/T018 fallbacks); `WeightLogger.swift` (T004, T015, T024); `WeightLoggerTests.swift` (T005, T014, T023); each locale's `Localizable.strings` across T006, T012, T016, T025.
- **[DEVICE]** tasks need a physical iPhone and the maintainer; they gate the design assumptions in research R1, R5, R6, R11 and must finish before merging.

## Parallel Execution Examples

- **Phase 2**: T003 can start immediately; T004 follows it.
- **US1**: after T007, T008 and T009 touch different files and run together; T006 (strings) can run alongside T007.
- **US5**: T019 (11 new `.strings` files) can be split across locales and run in parallel with T020 (script edit); T021 follows both.
- **Polish**: T028 and T029 are independent docs.
- **Across stories** (if two people work): US5 (T019, T020) can proceed in parallel with US3's Core work (T014, T015).

## Implementation Strategy

- **MVP = Phase 1 + Phase 2 + US1 (T001 to T011).** This alone delivers hands-free logging with a safe default (everything unusual is rejected as generic failure until US3 lands), and fixes today's misleading behavior where "Log weight in LogWeight" saves a stale widget draft.
- **Ship order**: US1 -> US3 (safety guardrails, so the unusual-value path is correct before wide use) -> US5 (localization) -> US2 -> US4. All stories can land in one PR; if split, do not release US1 without US3 and US5, because English-only phrases and the generic-failure path are only acceptable for internal testing.
- **Risk-first**: do T011 and T018 [DEVICE] as early as possible; both can change the intent's parameter shape or confirmation design.

## Summary

- Total tasks: 32 (T001 to T032)
- Per phase: Setup 2, Foundational 3, US1 6, US2 2, US3 5, US5 4, US4 5, Polish 5
- Parallelizable tasks marked [P]: T003, T009, T019, T028, T029
- Device-only tasks: T011, T013, T018, T022, T027, part of T030
