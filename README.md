# LogWeight

A calmer, faster way to log body weight on Apple devices.

- One-tap entry from your **Apple Watch** (companion app + complication).
- One-glance entry from your **iOS Lock Screen** *(Phase 4)*.
- History list + trend chart (iOS/iPadOS/macOS) — no nudges, no social.
- All data lives in **Apple Health on your device**. Nothing leaves your device.

LogWeight is a SwiftUI multiplatform app for iOS, iPadOS, watchOS, and macOS. It is not, and will never be, a separate weight database — the Health app is the source of truth.

## Status

**Phase 3: iOS + watchOS + macOS.** The macOS target is a menu-bar app (`LSUIElement`) with a `MenuBarExtra` entry window (type weight, **Return** to save), optional **History** window (**⌘N**), and system **Settings** (⌘,). It reuses `LogWeightCore` unchanged. The Watch app still embeds in the iOS product for distribution.

| Phase | Status | Goal |
|---|---|---|
| **1** | Done | iOS app: stepper-primary entry, plain history list, settings, redaction, Core test suite, CI. |
| **2** | Done | watchOS app: Digital Crown + steppers + save; `WKInterfaceDevice.play(.success)`; WidgetKit complication reading latest weight from HealthKit; shared `HistoryView`. |
| **3** | Done | macOS 14+ menu-bar app: sandbox + HealthKit; shared `HistoryView` / `SettingsView`; scheme **LogWeightMac**. |
| 4 | In progress | Swift Charts in history, broader XCUITests, accessibility audit docs, App Store metadata prep. |

## Non-goals

- No analytics, no telemetry, no crash reporters.
- No social, no streaks, no nudges, no AI commentary.
- No third-party SDKs.
- No separate weight database in the app.
- No tvOS — HealthKit is unavailable on tvOS, so a build there cannot serve this app's purpose.

## Project layout

```
LogWeight/
├── project.yml                # XcodeGen — single source of truth for the .xcodeproj
├── Packages/
│   └── LogWeightCore/         # Shared SPM package: models, HealthKitStore protocol, EntryState, formatting, logging
│       ├── Package.swift
│       ├── Sources/LogWeightCore/
│       └── Tests/LogWeightCoreTests/
├── App/
│   ├── iOS/                   # iOS app target (embeds Watch app); includes Assets.xcassets / AppIcon
│   ├── Watch/                 # watchOS companion app; includes Assets.xcassets / AppIcon
│   ├── WatchWidget/           # watchOS WidgetKit extension (complications)
│   ├── macOS/                 # macOS menu-bar target (`LogWeightMac` scheme)
│   ├── Shared/                # SwiftUI shared across platforms (e.g. `HistoryView`, `SettingsView`; watch excludes `SettingsView`)
│   └── iOSUITests/
├── Docs/                      # Architecture, HealthKit availability, Privacy, BuildAndDeploy
├── docs/jmat-reports/         # Multi-agent planning report (this commit)
└── .github/workflows/ci.yml
```

## Building

You need **macOS 14+, Xcode 15+, and Swift 5.9+**. The Xcode project file (`LogWeight.xcodeproj`) is generated from `project.yml` and is **not** committed.

```bash
brew install xcodegen
xcodegen generate
open LogWeight.xcodeproj
```

Run `swift test` from `Packages/LogWeightCore/` to execute the Core unit tests without Xcode.

See [`Docs/BuildAndDeploy.md`](Docs/BuildAndDeploy.md) for full setup, signing, and TestFlight notes.
Phase 4 release docs:
- [`Docs/AccessibilityAudit.md`](Docs/AccessibilityAudit.md)
- [`Docs/AppStoreMetadata.md`](Docs/AppStoreMetadata.md)
- [`Docs/AppStoreMetadata.localized.md`](Docs/AppStoreMetadata.localized.md)

## Privacy

LogWeight handles GDPR Art. 9 special-category health data. See [`Docs/Privacy.md`](Docs/Privacy.md) for the full data-flow statement, lawful basis, and Privacy Manifest summary.

## Monetization

See [`docs/Monetization.md`](docs/Monetization.md) for the recommended pricing approach: keep the core logging flow free, avoid ads and subscriptions, and use a low-cost optional one-time supporter purchase in Settings.

## Contributing

See [`docs/jmat-reports/2026-04-27-logweight-multiplatform-plan.md`](docs/jmat-reports/2026-04-27-logweight-multiplatform-plan.md) for the synthesised architecture and the constraints baked into the roadmap.
