# LogWeight

A calmer, faster way to log body weight on Apple devices.

- One-tap entry from your **Apple Watch** *(Phase 2)*.
- One-glance entry from your **iOS Lock Screen** *(Phase 4)*.
- Plain history list — no charts, no nudges, no social.
- All data lives in **Apple Health on your device**. Nothing leaves your device.

LogWeight is a SwiftUI multiplatform app for iOS, iPadOS, watchOS, and macOS. It is not, and will never be, a separate weight database — the Health app is the source of truth.

## Status

**Phase 1 (this branch): iOS-only MVP.**

| Phase | Status | Goal |
|---|---|---|
| **1** | In progress | iOS app: stepper-primary entry, plain history list, settings, redaction, Core test suite, end-to-end CI. |
| 2 | Planned | watchOS app + WidgetKit complication. |
| 3 | Planned | macOS menu-bar app. |
| 4 | Planned | Swift Charts in history, iOS Lock-Screen widget, full a11y audit, App Store ship. |

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
│   ├── iOS/                   # iOS app target
│   │   ├── LogWeightApp.swift
│   │   ├── Views/
│   │   └── Resources/         # Info.plist, entitlements, PrivacyInfo.xcprivacy
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

## Privacy

LogWeight handles GDPR Art. 9 special-category health data. See [`Docs/Privacy.md`](Docs/Privacy.md) for the full data-flow statement, lawful basis, and Privacy Manifest summary.

## Contributing

See [`docs/jmat-reports/2026-04-27-logweight-multiplatform-plan.md`](docs/jmat-reports/2026-04-27-logweight-multiplatform-plan.md) for the synthesised architecture and the constraints baked into Phase 1.
