# Research: Voice and Shortcut Weight Logging

Items marked **Verified** were checked in this session (existing code read, or a throwaway compile check against the
installed iOS 27.1 SDK with an iOS 17.0 target). Items marked **To verify on device** cannot be checked from the
command line and have a test in [quickstart.md](quickstart.md).

## R1 - Parameter type for the weight

- **Decision (revised after device test, 2026-10-13)**: `@Parameter var weight: Double` plus an optional `@Parameter var unit: WeightUnitOption?` (kilograms, pounds; default `WeightDisplayPreferences.preferredUnit()`), with `requestValueDialog` "What's your weight?".
- **Device finding (German Siri)**: with `Measurement<UnitMass>`, "70 Kilo" and "68 Kilogramm" resolved, but "68,9 Kilo", "68 Komma 9 Kilo" and a bare decimal did not (Siri showed the correct transcript but kept asking). Typing `68,9` in Shortcuts worked, so saving was never the problem. The original design below is kept for the record.
- **Original rationale (superseded)**: compiled at iOS 17 and carried an explicit unit, but Siri's decimal resolution for measurements failed on device.
- **Still to verify on device**: that Siri resolves a spoken decimal for a `Double` parameter ("68,9" / "68 Komma 9") and whether a trailing unit word ("Kilo") breaks it. If decimals still fail, fall back to a text parameter parsed by the app, or to separate whole and tenth parts.
- **Alternatives**: `Measurement<UnitMass>` (rejected, see device finding); `Int` grams (loses decimals, bad UX); text parameter parsed by the app (held in reserve).

## R2 - Spoken phrases cannot embed the value

- **Decision**: Register phrases with `\(.applicationName)` only; the value is requested as a follow-up.
- **Rationale**: App Shortcut phrases may contain only `AppEntity`/`AppEnum` parameters, not numbers or measurements, so
  "Log 82.4 kilograms in LogWeight" is not registrable. (Based on App Intents documentation, not compile-checked.)
  Spec was corrected accordingly.
- **Alternatives**: Make unit an `AppEnum` in the phrase ("Log weight in kilograms in LogWeight"), rejected as awkward in 11 languages.

## R3 - Phrase set and localization format

- **Decision**: Three English phrases: "Log weight in ${applicationName}", "Log my weight in ${applicationName}", "Save weight in ${applicationName}" (the last kept so existing users' muscle memory keeps working). Localized in `App/iOS/Resources/<locale>.lproj/AppShortcuts.strings`, one key per English phrase, each translated value containing `${applicationName}`.
- **Rationale**: `AppShortcuts.strings` is the established mechanism for App Shortcut phrases and matches the repo's `.strings` convention; each English phrase maps to exactly one translation, so three keys give three phrases per locale (spec asks for at least two).
- **Why a script extension**: `Tools/check-localizations.sh` only compares `Localizable.strings`. It will also compare `AppShortcuts.strings` key sets across the 11 locales and fail if any value lacks `${applicationName}`.
- **To verify on device**: that every locale's phrases are recognized (Shortcuts app shows them under the app, Siri runs them).
- **Alternatives**: `.xcstrings` string catalog (repo uses `.strings`; mixing formats adds tooling risk).

## R4 - Intent title, prompts, dialogs

- **Decision**: `LocalizedStringResource` with English-sentence keys in the existing `Localizable.strings` (matches current style, e.g. `"Save Weight" = ...`). New keys: "Log Weight", "Weight", "What's your weight?", "Logged %@.", "Already logged %@.", "Confirm %@?" (unusual value), "Allow access to Health in LogWeight first.", and generic failure text. Weight text comes from `WeightFormatter` (locale-aware, one decimal).
- **Rationale**: Covered by the existing parity check. No new infrastructure.

## R5 - Confirmation, and refusing when unattended

- **Decision**: For an out-of-range value or large jump, call `requestConfirmation(result:)` before saving. If it throws (user declines, or nobody can be asked), save nothing and return an error. One code path covers both Siri and unattended runs (Clarification: refuse when unattended).
- **Verified**: `requestConfirmation(result:confirmationActionName:showPrompt:)` compiles at iOS 17 (deprecated warning only). The replacement `requestConfirmation(conditions:actionName:dialog:)` is iOS 18+; not usable at the iOS 17 deployment target. Plan: use the deprecated API, isolate it in one function so it can move behind `#available` later.
- **To verify on device (high risk)**: that a Shortcuts automation set to "Run Immediately" does fail, not auto-confirm. If it auto-confirms, fall back to a `@Parameter var allowUnusualValue: Bool = false`; unusual values are refused unless it is true, and interactive confirmation is dropped.

## R6 - Locked device and Health data

- **Decision**: `static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication`.
- **Verified**: compiles at iOS 17.
- **Rationale**: Health data is protected while locked, and the confirmation dialog reveals a weight; requiring unlock avoids a failed write after a spoken "Logged" and avoids showing health values on a locked screen.
- **To verify on device**: behavior from the Lock Screen and Action Button.

## R7 - Where the code lives and the target membership

- **Decision**: `LogWeightIntent` in `App/iOS/Intents/` (app target only). Core logic in `Packages/LogWeightCore/Sources/LogWeightCore/WeightLogging/`.
- **Verified from `project.yml`**: the app target compiles `App/iOS` and `App/Shared`; the widget extension compiles `App/iOSWidget` and `App/Shared/Widget`; watch app excludes `Widget/**`. So `App/iOS` is the only place that is app-only. `App/iOS/Resources` is not excluded wholesale (only Info.plist, entitlements, PrivacyInfo), so `*.lproj/AppShortcuts.strings` is picked up by `xcodegen generate` without a `project.yml` edit; confirm after generating.
- **Alternative**: `App/Shared` (rejected: would compile into the watch app and widget).

## R8 - Widget Save must keep working

- **Verified**: `SaveWeightIntent` (in `App/Shared/Widget`) is used by `Button(intent:)` in `LogWeightWidget.swift`, runs in the app process (`openAppWhenRun = true`), and is currently registered in `LogWeightAppShortcuts` with a comment saying the registration helps the host app resolve the type.
- **Decision**: Remove it from the provider (FR-007) and mark it `isDiscoverable = false` so it is not listed in the Shortcuts app. It stays in the app target through `App/Shared`.
- **To verify on device (regression)**: tap the widget Save button after the change. If the widget stops saving, restore a minimal registration approach and re-plan.
- **Note**: the widget path calls `requestAuthorization()` after opening the app; the new intent does not (R9).

## R9 - Authorization from a background intent

- **Decision**: If `HealthKitStore.authorizationStatus()` is not `.sharingAuthorized`, return a localized error telling the user to open LogWeight to allow Health access. Do not call `requestAuthorization()` (the system sheet cannot be shown without foreground UI).
- **Rationale**: Meets FR-011 and avoids a hang in a background context.

## R10 - Duplicate and jump detection data

- **Decision**: Read `recentWeights(limit: 1)` (newest sample, any source, including Apple Health's own Siri entries).
  - Duplicate if the new value equals the newest sample within 0.05 kg and the sample is at most 60 s old.
  - Large jump if the difference from the newest sample exceeds 10 kg.
  - First entry = empty result; no jump check, only the range check.
- **Known limitation**: if Health read access was not granted, `recentWeights` is empty (HealthKit privacy model), so dedupe and jump checks silently do not apply; range check still does. Documented in the contract.
- **Alternatives**: persisting a "last logged" marker (rejected: Constitution I, no second store).

## R11 - Interaction with Apple Health's Siri logging

- **Decision**: No suppression attempt. App-name phrases are the only lever (FR-007); the 60 s duplicate window protects against a user logging the same weight through both paths back to back.
- **To verify on device**: whether the phrase "Log my weight" without the app name routes to Health (expected) and whether ours is reachable only with the app name.

## R12 - Documentation and decisions

- **Decision**: Add `ADR-011` in `docs/Architecture.md` (voice/automation entry path as a bounded exception to stepper-first entry, with the guardrails). Add a short Siri/Shortcuts note to `docs/Privacy.md` and clarify the microphone line (the OS handles audio; the app receives only a number).
- **Rationale**: The decision outlives this feature and touches ADR-007; the privacy doc currently says the app does not access the microphone, which stays true but needs the clarification.
