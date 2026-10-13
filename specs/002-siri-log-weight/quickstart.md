# Quickstart: Validating Voice and Shortcut Weight Logging

Details of types and strings: [data-model.md](data-model.md), [contracts/](contracts/). This is a validation guide, not
an implementation.

## Prerequisites

- Xcode with the repo's toolchain; `xcodegen` installed; hooks installed once (`Tools/install-git-hooks.sh`).
- A physical iPhone (iOS 17+) with Health data available and LogWeight installed with Health write access granted. Siri routing, lock state, and automations cannot be verified in the simulator.

## 1. Automated checks

```bash
xcodegen generate
cd Packages/LogWeightCore && swift test            # includes WeightLoggerTests
cd ../.. && Tools/check-localizations.sh            # Localizable.strings + AppShortcuts.strings parity
xcodebuild test -scheme LogWeight -destination 'platform=iOS Simulator,name=iPhone 15'
xcodebuild build -scheme LogWeightWatch -destination 'generic/platform=watchOS Simulator' CODE_SIGNING_ALLOWED=NO
```

Expected: all pass. No new app screens, so no new screenshot scenes; run `Tools/CaptureScene.sh --all` only if any view was touched.

## 2. Device matrix (manual)

| # | Scenario | Steps | Expected | Spec |
|---|---|---|---|---|
| 1 | Siri happy path | Say "Hey Siri, log weight in LogWeight"; answer "82,4" (number only; German: "82 Komma 4" or "82,4") | One entry in Health with 82.4 kg and current time; spoken and shown "Logged ..."; app does not open | US1, FR-001/004 |
| 2 | Unit follows settings | Set the app unit to pounds, answer "180"; then set kilograms and answer "82,4" | Confirmation states the unit used (lb, then kg); Health shows the converted value. In Shortcuts, picking Unit = Pounds overrides the setting | FR-003 |
| 3 | Cancel | Start, then cancel at the weight question | Nothing saved | US1 AS2 |
| 4 | First entry | On a device or Health profile with no body-mass entries, log 80 kg | Saved; no confirmation | US3 AS1, FR-010 |
| 5 | Implausible | Log 5 kg | Confirmation asked; declining saves nothing | US3 AS2 |
| 6 | Large jump | Newest entry 80 kg, log 95 kg | Confirmation asked | US3 AS3 |
| 7 | Unattended | Shortcuts automation "Run Immediately" with a fixed 5 kg or 95 kg value | Run fails with a clear error; nothing saved. If it saves, apply research R5 fallback | FR-009 |
| 8 | Duplicate | Run twice within 60 s with the same value | One entry; second run says "Already logged" | US4 |
| 9 | No Health access | Revoke LogWeight write access, run | Error tells user to open LogWeight; nothing saved | FR-011 |
| 10 | Locked device | Invoke from Lock Screen / Action Button while locked | Prompts for unlock before running; no value shown while locked | R6 |
| 11 | Action Button / Spotlight / Shortcuts | Assign and run; use a fixed value in a shortcut | One entry per run; result usable in the next shortcut step | US2, FR-013 |
| 12 | Widget regression | Widget Save button after stepping the widget value | Still saves the staged value and opens the app, as before | FR-014 |
| 13 | Routing vs Apple Health | Say "log my weight" (no app name), then with the app name | Without name: Health handles it. With name: LogWeight handles it | FR-007, R11 |
| 14 | Localization | For de, ja, and one more locale: set device language, view the app's shortcuts, run by voice | Localized title, phrases contain the app name, localized dialogs | US5 |

## 3. Privacy check

- Run scenarios 1, 5, and 9 with Console.app attached to the device, filter subsystem `dev.logweight.LogWeight`.
- Expected: only event names and numeric error codes; no weights, dates, or spoken text (SC-006).

## 4. Release gate

Items 2, 7, 10, 13 are the assumptions most likely to change the design (research R1, R5, R6, R11). Resolve them before
merging; record the outcomes in the PR description.
