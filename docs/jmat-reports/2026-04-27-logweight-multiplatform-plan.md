# JMAT Planning Report — LogWeight Multiplatform SwiftUI App

**Date:** 2026-04-27  
**Branch:** `feat/initial-multiplatform-scaffold`  
**Stack:** Swift / SwiftUI + HealthKit + Xcode multiplatform + SPM  
**Confidence:** 89%  
**Devil's Advocate verdict:** `CHALLENGES_FOUND` — highest severity `CRITICAL`

---

## 1. Task

Create a technical plan for a SwiftUI app called **LogWeight** that runs on iOS, iPadOS, watchOS, tvOS, and macOS and writes body weight to Apple Health via HealthKit. The app must prioritize the fastest possible weight entry flow.

### User constraints (treated as soft defaults — exceptions allowed if well-justified)

- Optimize for one-handed or one-tap entry.
- No social, gamified, or analytics features.
- SwiftUI + HealthKit only unless another framework is clearly justified.
- Shared business logic with lightweight platform-specific views.
- History reads from HealthKit; no separate weight DB.
- Ask before adding any feature that increases time-to-save.

---

## 2. Approach (Tech Lead synthesis)

One Xcode multiplatform project. One shared SPM package (`LogWeightCore`) holding the `HealthKitStore` protocol, the `EntryState` `@Observable` class, formatting, and security logging. Lightweight per-platform SwiftUI views consume the same Core.

**Phase 1 ships iOS only** (entry, simple history list, minimal settings) — fully on-device, zero third-party deps, GDPR-safe. Phases 2–5 add watchOS, macOS, polish (charts, accessibility audit), and a tvOS decision.

### Architecture pattern

- **MV with `@Observable`** (not classical MVVM, not Combine boilerplate).
- `HealthKitStore` protocol abstracts `HKHealthStore`. Production = `HKHealthStoreAdapter`. Tests = `InMemoryHealthKitStore` (no entitlements needed → CI-friendly).
- DI via SwiftUI `Environment(\.healthKitStore, ...)`.
- HealthKit is the **sole** source of truth — the app never persists weight values anywhere.

---

## 3. Phased Roadmap

| Phase | Goal | ACs covered | Exit criteria |
|---|---|---|---|
| **1** *(this session + 1–2 follow-ups)* | iOS-only MVP: deep-launch entry, HealthKit save, simple history list, minimal settings, redaction, full Core test suite. | AC1 (iOS subset), AC2, AC3, AC4 (text only), AC5 (3 toggles), AC6 (basics), AC7 (Core tests + 1 UI smoke), AC8 (iOS), AC9 | `swift test` green; iOS app builds on simulator; manual save reaches Apple Health; smoke XCUITest passes. |
| **2** | watchOS App + complication. Digital Crown adjusts weight. WidgetKit complication shows last weight. | AC1 (+watchOS), AC3 (one-handed perfected), AC6 (watchOS), AC8 (watchOS) | watchOS app saves on real watch; complication renders; battery review. |
| **3** | macOS app (menu-bar style). Type number + Return saves. Reuses Core unchanged. | AC1 (+macOS), AC8 (macOS sandbox + entitlements) | macOS 14+ build saves to HealthKit; menu-bar UX validated. |
| **4** | Polish: Swift Charts on iOS/iPad/macOS history, full XCUITest matrix, full accessibility audit, App Store metadata. | AC4 (charts), AC6 (full), AC7 (full pyramid) | v1.0 RC ready for App Store. |
| **5** | tvOS DECISION: stub or drop. Optional Lock-Screen widget, Siri Shortcut. | AC1 (tvOS resolved) | v1.0 ships. |

---

## 4. Phase 1 Files (30 total — all CREATE except `.gitignore`)

### Shared Core package — `Packages/LogWeightCore/`

- `Package.swift` — SPM manifest; min iOS 17 / watchOS 10 / macOS 14; zero deps.
- `Sources/LogWeightCore/Models/WeightUnit.swift` — kg / lb / st enum + `HKUnit` bridging.
- `Sources/LogWeightCore/Models/Weight.swift` — `Weight { valueInKilograms, recordedAt }`.
- `Sources/LogWeightCore/HealthKit/HealthKitStore.swift` — protocol: `requestAuthorization`, `save`, `recentWeights(limit:)`, `observeChanges() -> AsyncStream<Void>`.
- `Sources/LogWeightCore/HealthKit/HKHealthStoreAdapter.swift` — production impl using `HKQuantityTypeIdentifier.bodyMass`.
- `Sources/LogWeightCore/HealthKit/InMemoryHealthKitStore.swift` — test/preview double.
- `Sources/LogWeightCore/State/EntryState.swift` — `@Observable final class EntryState`.
- `Sources/LogWeightCore/Settings/SettingsKeys.swift` — `@AppStorage` keys + `schemaVersion=1`.
- `Sources/LogWeightCore/Settings/SettingsMigrator.swift` — schema migration runner (v1 = noop).
- `Sources/LogWeightCore/Formatting/WeightFormatter.swift` — `Measurement<UnitMass>` based locale-aware format/parse.
- `Sources/LogWeightCore/Logging/SecurityLog.swift` — `os_log` wrapper; rejects value args.
- `Tests/LogWeightCoreTests/WeightTests.swift`
- `Tests/LogWeightCoreTests/WeightFormatterTests.swift`
- `Tests/LogWeightCoreTests/EntryStateTests.swift`
- `Tests/LogWeightCoreTests/InMemoryHealthKitStoreTests.swift`

### iOS app target — `App/iOS/`

- `LogWeightApp.swift` — `@main` App; injects `HKHealthStoreAdapter`; calls `SettingsMigrator.migrateIfNeeded()`.
- `Views/EntryView.swift` — root entry surface (large SF Rounded number, ± steppers, Save button, `.privacySensitive()`, `.sensoryFeedback(.success)`).
- `Views/HistoryView.swift` — sheet, lazy-loaded, `List` of recent weights from HealthKit. **No charts in Phase 1.**
- `Views/SettingsView.swift` — unit picker, haptics toggle, default-entry-mode picker, link to Apple Health.
- `Views/PrivacyRedactionModifier.swift` — observes `scenePhase` + `UIScreen.isCaptured`, overlays opaque redaction.
- `Resources/Info.plist` — `NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription`.
- `Resources/LogWeight.entitlements` — `com.apple.developer.healthkit`, App Group `group.dev.logweight`.
- `Resources/PrivacyInfo.xcprivacy` — Apple Privacy Manifest declaring Health & Fitness > Body Measurements.

### Tests, docs, CI

- `App/iOSUITests/EntryViewSmokeTests.swift` — single XCUITest (launch → type 75.0 → tap Save → assert success state ≤ 500ms).
- `Docs/Architecture.md`, `Docs/HealthKitAvailability.md`, `Docs/Privacy.md`, `Docs/BuildAndDeploy.md`.
- `README.md` — public description, scope, non-goals, Phase 1 status.
- `.github/workflows/ci.yml` — `swift test` on `macos-latest` for `LogWeightCore`. iOS `xcodebuild test` deferred until a `.xcodeproj` exists.
- `.gitignore` — **MODIFY** — Xcode artefacts, `DerivedData`, `*.xcuserstate`, `.swiftpm/`, `*.xcodeproj/xcuserdata`.

---

## 5. Design Per Platform

| Platform | Design |
|---|---|
| **iOS** | Launch directly into `EntryView`. Big SF Rounded numeric (tappable → inline decimal pad). Beneath: ± stepper buttons (44pt). Bottom-trailing **Save**. Toolbar: clock → `HistoryView` sheet, gear → `SettingsView`. `.sensoryFeedback(.success)` on save. `.privacySensitive()` throughout. |
| **iPadOS** | Same view tree, centred max-width 500pt card. `ViewThatFits` handles split-view + slide-over. |
| **watchOS** *(Phase 2)* | Single screen: large weight, Digital Crown adjusts ±0.1 unit/notch, Save tap. `WKHapticType.success`. WidgetKit complication (small/circular) shows last weight; tap deep-launches. |
| **macOS** *(Phase 3)* | Menu-bar item (`scalemass` SF Symbol). Click → `NSPopover` with focused `TextField`; type → Return saves. Optional full window via Cmd+N for history. |
| **tvOS** *(Phase 5 decision)* | If retained: stub VStack. No HealthKit capability. Default = drop. |

---

## 6. Permissions & Capabilities

- **HealthKit types requested:** `HKQuantityTypeIdentifier.bodyMass` (read + write only).
- **Info.plist usage strings:**
  - `NSHealthShareUsageDescription`: *"LogWeight reads your weight history from Apple Health to show your timeline. Nothing leaves your device."*
  - `NSHealthUpdateUsageDescription`: *"LogWeight saves each weight you enter to Apple Health on this device. Nothing leaves your device."*
- **Entitlements:** `com.apple.developer.healthkit`, App Group `group.dev.logweight`.
- **Privacy Manifest:** declares Health & Fitness > Body Measurements with purpose `AppFunctionality`, `linkedToUser=true`, `usedForTracking=false`; `NSPrivacyTracking=false`.

---

## 7. Quality Gates

**Critical items addressed (9):** GDPR Art. 9 treatment, zero off-device transmission, least-privilege HealthKit, no third-party SDKs, never log values, app-switcher + screen-recording redaction, `.privacySensitive()`, Privacy Manifest from Phase 1, crash safety.

**High items addressed (6):** cold-start <300ms, time-to-save <500ms, Phase 1 test pyramid (Core unit + 1 iOS smoke), accessibility basics (VoiceOver, Dynamic Type, 44pt), settings schema versioned from v1.0, App Group locked from v1.0.

**Deferred:** Swift Charts → P4. watchOS complication → P2. macOS → P3. tvOS → P5 decision. Localization beyond `NumberFormatter` → P4.

---

## 8. Key Decisions (Conflict Resolutions)

1. **Phase 1 scope:** Architect compromise wins — iOS app target only; multiplatform Xcode project scaffolded so P2/P3 add targets without restructuring. tvOS not scaffolded.
2. **History in P1:** AC4 is a stated criterion → keep it, but as a plain text list only. Charts → P4.
3. **MV vs MVVM:** Architect's `@Observable` MV wins — `EntryState` is *the* lightweight VM, just named the SwiftUI way.
4. **Entry input:** Hybrid wins — pre-filled big number is tappable to a decimal pad; ± buttons step ±0.1; Digital Crown on watchOS.
5. **Charts in P1:** Pragmatist wins — defer to P4.
6. **Redaction:** Security wins MUST — `.privacySensitive()` + opaque overlay ships in Phase 1 (cheap, GDPR-required).
7. **Draft preservation:** Security wins — never persist weight to UserDefaults; draft lives only in `@State`.
8. **Test pyramid:** Pragmatist wins — Core XCTest + 1 iOS XCUITest smoke in Phase 1; full matrix in Phase 4.
9. **Settings schema versioning:** API Contract wins — `schemaVersion=1` from day one (one line of code).

---

## 9. Risks

| # | Risk | Severity | Mitigation |
|---|---|---|---|
| 1 | User denies HealthKit on first launch. | HIGH | Inline calm hint on `EntryView` with deep-link to Settings. Never spam re-prompt. |
| 2 | Health data leakage via crash report or analytics. | HIGH (GDPR Art. 9) | Zero crash reporters in v1; `SecurityLog` rejects value args; code-review checklist. |
| 3 | macOS HealthKit availability narrower than iOS. | MEDIUM | Document deployment target; Phase 3 only; confirm via Context7. |
| 4 | tvOS scope politically retained but technically impossible. | MEDIUM | Phase 5 decision gate; default = drop. |
| 5 | Dynamic Type at `.accessibility5` breaks `EntryView` on iPhone SE. | MEDIUM | `ViewThatFits` from P1; screenshot test pinned at `.accessibility5` in P4. |
| 6 | `.pbxproj` is auto-generated; hand-authoring is fragile. | MEDIUM | Phase 1 ships sources + plist + entitlements + README; user generates project locally. |
| 7 | HealthKit cannot be exercised end-to-end in CI. | MEDIUM | `InMemoryHealthKitStore` covers logic paths; CI runs `swift test` on Core. |
| 8 | Screen-recording redaction relies on `UIScreen.isCaptured`. | LOW | iOS 17 minimum; `.privacySensitive()` covers system redaction. |
| 9 | User pushes back on tvOS deferral. | LOW | Approval gate surfaces the decision. |
| 10 | Settings schema migration runs on every cold start. | LOW | Migrator returns immediately if `schemaVersion == CURRENT`. |

---

## 10. Devil's Advocate — Challenges to Address Before Build

The synthesis is `CHALLENGES_FOUND` with **1 CRITICAL**, **5 HIGH**, **5 MEDIUM**, **2 LOW**. Each must be answered at the approval gate.

### CRITICAL

- **DA1 — Decimal keyboard occludes Save button.** `EntryView` puts Save bottom-trailing in safe area. The decimal pad keyboard on every iPhone covers the bottom ~280pt. SwiftUI does NOT auto-avoid keyboards for arbitrary `ZStack`/`VStack` layouts — only `ScrollView` + `Form`. This breaks the single most important promise of the app. **Fix:** put Save in `.toolbar(placement: .keyboard)` so it always sits on top of the keyboard.

### HIGH

- **DA2 — No `.xcodeproj` + no CI verification.** Phase 1 ships source files only and asks the user to wire the project manually. CI cannot prove the iOS app builds. **Fix:** adopt **XcodeGen** (one `project.yml`, `brew`-installable) so the project is reproducible and CI-verifiable.
- **DA3 — `HealthKitStore.save() -> UUID` leaks HealthKit identity through the abstraction.** Nothing consumes the UUID. **Fix:** drop the return value; if record identity is ever needed, add a separate `delete(_ weight: Weight)` taking a value.
- **DA4 — `observeChanges() -> AsyncStream<Void>` implementation is unspecified.** Bridging `HKObserverQuery` to `AsyncStream` is leak-prone. **Fix:** specify `AsyncStream.makeStream()`, weak continuation, query invalidation on stream termination, foreground-only in Phase 1.
- **DA5 — Stones unit needs compound display (`11 st 4 lb`), not `11.3 st`.** UK users expect compound. **Fix:** special-case `WeightFormatter` for `.stones`; decompose into `(Int stones, Int pounds)`.
- **DA6 — watchOS may be the highest-value platform, not iOS.** The Watch achieves AC3 ("fastest possible entry") better than any iPhone UI. Deferring it gives the most motivated daily user the worst experience. **Fix:** ask the user directly which device they primarily log from.

### MEDIUM

- **DA7 — A history "text list" may not match user intent.** The team's own gap_analysis said "chart" for AC4. **Fix:** explicitly ask whether a list satisfies AC4 for Phase 1.
- **DA8 — `UIScreen.isCaptured` has documented gaps on iOS 17+** (AirPlay mirroring, QuickTime wired recording). The plan dismissed this as an old-iOS issue. **Fix:** acknowledge limits in `Privacy.md`; do not overstate coverage.
- **DA9 — App Group `group.dev.logweight` has no consumer in Phase 1 and is identifier-locked.** **Fix:** either drop it from Phase 1 (add when watchOS arrives) or resolve the real ID now.
- **DA10 — iOS 17 minimum is not justified.** Driver is `@Observable` + `.sensoryFeedback`. iOS 16 is doable with `@ObservableObject` + `UIImpactFeedbackGenerator`. **Fix:** ask the user.
- **DA11 — Consensus error: nobody asked whether LogWeight should exist.** Apple Health's native Add Data is 4 taps. What's LogWeight's USP? **Fix:** ask the user; their answer drives platform priority and UX.
- **DA12 — Draft preservation:** sold as a privacy win but the kill scenario (workout app pressure) is the user's most common path. **Fix:** consider a 10-minute Keychain TTL for drafts (not UserDefaults) — Keychain isn't in unencrypted backups and is hardware-encrypted. Or accept the loss explicitly.

### LOW

- **DA13 — tvOS Phase-5 "decision gate" is indefinite deferral.** HealthKit unavailable; only honest tvOS build is a stub. **Fix:** close the decision now.

---

## 11. Open Questions for the User (Approval Gate)

> The Devil's Advocate raised a CRITICAL challenge plus 5 HIGH challenges that need decisions before code is written. The original synthesis questions (Q1–Q7) plus the DA's gate questions consolidated:

1. **Keyboard + Save (DA1, CRITICAL):** Where should the Save button live when the decimal keyboard is open?  
   *(a) In the keyboard toolbar — always visible (recommended)*  
   *(b) Above the keyboard via `ScrollView` + `.safeAreaInset`*  
   *(c) ± steppers are the primary path; typing is secondary*
2. **Phase order (DA6):** Do you log weight primarily from your **iPhone** or your **Apple Watch**? If Watch, swap Phase 1 / Phase 2.
3. **History view scope (DA7, original Q6):** Is a plain date+weight **text list** sufficient for Phase 1, or do you expect at least a sparkline trend?
4. **`.xcodeproj` strategy (DA2, original Q7):** Manual Xcode project creation per `BuildAndDeploy.md`, OR **XcodeGen** (`project.yml`, `brew install`) for a reproducible CI-verifiable project?
5. **Stone display (DA5):** Compound `11 st 4 lb` (UK convention) or decimal `11.3 st`?
6. **Draft preservation (DA12):** Lose typing on app kill, OR transient Keychain draft with 10-minute TTL (deleted on save)?
7. **tvOS (DA13, original Q1):** Drop tvOS now (recommended — HealthKit unavailable), or keep alive for Phase 5 stub?
8. **USP (DA11):** Why LogWeight instead of Apple Health's native Add Data flow? *(a) Apple Watch one-tap logging, (b) cleaner UI than Health app, (c) Lock-Screen widget, (d) other.*
9. **iOS minimum (DA10):** **iOS 17+** (recommended for `@Observable`/`.sensoryFeedback`), or iOS 16+ for broader audience (~15–20% more devices)?
10. **Bundle prefix (original Q2):** Keep placeholder `dev.logweight.LogWeight`, or use your real developer account team prefix now?
11. **Distribution (original Q3):** Free / paid / private TestFlight only? *(affects whether a public Privacy Policy URL is required.)*
12. **macOS minimum (original Q4):** macOS 14 (Sonoma+, recommended) or macOS 13 (broader audience)?
13. **Localization (original Q5):** en-US only in Phase 1 (recommended), or include de/fr/es?

---

## 12. Specialist Adoption Tracking

| Agent | Adopted | Rejected | Notes |
|---|---:|---:|---|
| architect | 11 | 1 | Charts in P1 deferred. |
| quality-engineer | 6 | 1 | Full XCUITest matrix in P1 deferred to P4. |
| pragmatist | 9 | 2 | tvOS-drop softened to P5; defer-history rejected (it's an AC); defer-redaction rejected (security). |
| frontend-specialist | 8 | 2 | Charts in P1 rejected; stepper-as-primary softened to hybrid. |
| resilience-performance | 9 | 1 | UserDefaults draft persistence rejected. |
| security-specialist | 11 | 0 | All MUSTs adopted. |
| gdpr-compliance | 9 | 0 | All adopted. |
| api-contract-migration | 7 | 0 | All adopted. |
