# Implementation Plan: Voice and Shortcut Weight Logging

**Branch**: `002-siri-log-weight` (spec directory only; the git branch is chosen by the maintainer) | **Date**: 2026-10-13 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/002-siri-log-weight/spec.md`

## Summary

Replace the widget-only "Save Weight" spoken shortcut with a real **Log Weight** App Intent that takes a weight
(`Measurement<UnitMass>`), validates it, asks for confirmation when it is unusual, writes it to Apple Health through
`HealthKitStore`, and answers with a localized dialog and a typed result. Decision logic (plausible range, large jump,
duplicate window, first entry) lives in a new Foundation-only type in `LogWeightCore` and is covered by `swift test`
with `InMemoryHealthKitStore`. The intent itself is a thin adapter in `App/iOS`. Spoken phrases move from the widget's
`SaveWeightIntent` to the new intent and are localized for all 11 locales via `AppShortcuts.strings`, which the
localization parity script is extended to cover. The widget Save button keeps working untouched.

## Technical Context

**Language/Version**: Swift 5.9 language mode with strict concurrency `complete` (`project.yml`); built with the current Xcode toolchain

**Primary Dependencies**: `AppIntents` (system), existing `LogWeightCore` (`HealthKitStore`, `Weight`, `WeightUnit`, `WeightFormatter`, `WeightDisplayPreferences`, `SecurityLog`). No new third-party dependencies.

**Storage**: N/A. Apple Health remains the only store (Constitution I). No new `UserDefaults` keys, no draft state.

**Testing**: `swift test` in `Packages/LogWeightCore` (new `WeightLoggerTests` with `InMemoryHealthKitStore`); localization parity script; manual device matrix in [quickstart.md](quickstart.md) for Siri routing, locked device, unattended runs, and widget regression (App Intents cannot be fully exercised in unit tests).

**Target Platform**: iOS 17.0+ (deployment target). The intent and provider are iOS-app-only; watchOS and the widget extension are untouched.

**Project Type**: Multiplatform mobile app (XcodeGen project + local SPM package)

**Performance Goals**: Weight saved and confirmation returned in under 2 s after the value is known; end-to-end voice flow under 10 s (SC-001).

**Constraints**: Must not open the app (`openAppWhenRun = false`); requires device unlock (`authenticationPolicy = .requiresAuthentication`); confirmation may use only the iOS 17 API (`requestConfirmation(result:)`, deprecated but available; the replacement is iOS 18+); no health values in logs; no off-device data flow.

**Scale/Scope**: One new intent, one provider rewrite, one Core type + tests, 11 locales x (about 3 phrases + about 10 dialog strings), one script extension, doc updates.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | How the plan satisfies it |
|---|---|---|
| I. Apple Health is the only source of truth | PASS | Writes only via `HealthKitStore.save`. Duplicate/jump checks read `recentWeights`. The intent imports no HealthKit; the existing `HKHealthStoreAdapter` is the only concrete store. No cache, no draft. |
| I. Public Core APIs avoid HealthKit types | PASS | `WeightLogger` API uses `Double` kilograms, `Weight`, `Date`, and plain enums. |
| II. Privacy / no health values in logs | PASS | Only `SecurityLog.event/error` with literal names and error codes; dialogs go to the user, never to logs. No off-device flow, no analytics. `docs/Privacy.md` gets a short note (Siri/Shortcuts handled by the OS; the app receives the value only as a number) and its "no microphone" line is clarified. |
| III. Shared core, platform-local UI | PASS | Logic in Core; `AppIntent` adapter in `App/iOS`. `App/Shared` and watchOS are not touched. |
| IV. Testable by construction | PASS | `WeightLogger` takes `any HealthKitStore` and a clock; tested with `InMemoryHealthKitStore`; `HKHealthStore` never mocked. |
| V. Considered, accessible, localized UX | PASS with note | See Complexity Tracking (voice entry is a different modality from the stepper). All strings added to all 11 locales; parity script extended to `AppShortcuts.strings`. Dialogs are system-rendered (VoiceOver and Dynamic Type handled by the OS). |
| VI. Reproducible project | PASS | New files are picked up by `xcodegen generate`; `project.yml` change only if the new resource folder needs an explicit entry (see research R7). No hand-edited `.xcodeproj`, no manual version bump. |

**Re-check after Phase 1 design**: unchanged, all gates still pass (design adds no store, no log of values, no off-device flow).

## Project Structure

### Documentation (this feature)

```text
specs/002-siri-log-weight/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   ├── intent-contract.md   # Intent parameters, results, dialogs, errors, phrases
│   └── core-api.md          # WeightLogger API in LogWeightCore
└── tasks.md             # Phase 2 output (/speckit-tasks - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
Packages/LogWeightCore/
├── Sources/LogWeightCore/WeightLogging/
│   ├── WeightLogPolicy.swift     # NEW: range, jump, duplicate-window constants
│   └── WeightLogger.swift        # NEW: evaluate(...) / save(...) decision logic
└── Tests/LogWeightCoreTests/
    └── WeightLoggerTests.swift   # NEW

App/
├── iOS/
│   ├── Intents/
│   │   └── LogWeightIntent.swift         # NEW: AppIntent adapter (no HealthKit import)
│   ├── LogWeightAppShortcuts.swift       # CHANGED: provider now exposes LogWeightIntent only
│   └── Resources/<locale>.lproj/AppShortcuts.strings   # NEW x11: localized spoken phrases
├── Shared/
│   ├── Widget/LogWeightWidgetIntents.swift   # CHANGED (small): SaveWeightIntent hidden from Shortcuts
│   └── Resources/<locale>.lproj/Localizable.strings    # CHANGED x11: intent title, prompts, dialogs
└── iOSUITests/ ...                           # no change expected (no in-app UI changed)

Tools/check-localizations.sh   # CHANGED: also check AppShortcuts.strings parity + ${applicationName}
docs/Privacy.md                # CHANGED: Siri/Shortcuts note
docs/Architecture.md           # CHANGED: ADR-011 (voice/automation entry path)
docs/AIScreenshotWorkflow.md   # untouched: no app UI changes, so no new scenes
```

**Structure Decision**: Core owns the policy and decision logic (Constitution III, IV); the iOS app target owns the
intent adapter and provider. The intent lives in `App/iOS`, not `App/Shared/Widget`, because that folder is compiled
into the widget extension as well, and the new intent must exist only in the app process.

## Complexity Tracking

| Deviation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| Voice/automation entry does not use the stepper-first flow (Constitution V, ADR-007) | The value is spoken or supplied by a Shortcut; no stepper or keyboard exists in these surfaces. | Opening the app to use the stepper defeats the hands-free goal (Clarification: never opens the app). Guardrails compensate: plausibility check, jump confirmation, duplicate window, post-save confirmation. Recorded in ADR-011. |
