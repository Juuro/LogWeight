# LogWeight

A calmer, faster way to log body weight on Apple devices.

- One-tap entry from your **Apple Watch** (companion app + complication).
- One-glance latest weight on watchOS via **Smart Stack/complication**.
- History list + trend chart (iOS/iPadOS), plus edit/delete from history.
- All data lives in **Apple Health on your device**. Nothing leaves your device.

LogWeight is a SwiftUI app for iOS, iPadOS, and watchOS. It is not, and will never be, a separate weight database — the Health app is the source of truth.

## Status

**Current state:** iOS + iPadOS + watchOS are active. iOS/iPadOS use stepper-first entry with long-press acceleration and shared history/settings screens. watchOS supports Digital Crown input and refreshes its complication after saves.

| Phase | Status | Goal |
|---|---|---|
| **1** | Done | iOS app: stepper-primary entry, plain history list, settings, redaction, Core test suite, CI. |
| **2** | Done | watchOS app: Digital Crown + steppers + save; `WKInterfaceDevice.play(.success)`; WidgetKit complication reading latest weight from HealthKit; shared `HistoryView`. |
| **3** | Done | iPadOS support in the iOS target with the same stepper-first flow and shared `HistoryView` / `SettingsView`. |
| 4 | In progress | Swift Charts in history, broadened XCUITests, accessibility audit docs, App Store metadata prep. |

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
│   ├── Shared/                # SwiftUI shared across platforms (e.g. `HistoryView`, `SettingsView`; watch excludes `SettingsView`)
│   ├── iOSScreenshots/        # iOS screenshot UI test target sources
│   └── iOSUITests/
├── docs/                      # Architecture, HealthKit availability, Privacy, BuildAndDeploy
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

See [`docs/BuildAndDeploy.md`](docs/BuildAndDeploy.md) for full setup, signing, and TestFlight notes.
Phase 4 release docs:
- [`docs/AccessibilityAudit.md`](docs/AccessibilityAudit.md)
- [`docs/AppStoreMetadata.md`](docs/AppStoreMetadata.md)
- [`docs/AppStoreMetadata.localized.md`](docs/AppStoreMetadata.localized.md)

## Privacy

LogWeight handles GDPR Art. 9 special-category health data. See [`docs/Privacy.md`](docs/Privacy.md) for the full data-flow statement, lawful basis, and Privacy Manifest summary.

## Contributing

See [`docs/jmat-reports/2026-04-27-logweight-multiplatform-plan.md`](docs/jmat-reports/2026-04-27-logweight-multiplatform-plan.md) for the synthesised architecture and the constraints baked into the roadmap.
