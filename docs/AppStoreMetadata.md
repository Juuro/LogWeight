# App Store Metadata (Phase 4 Draft)

This file tracks App Store Connect metadata needed for a v1.0 submission.

## Product identity

- App name: `LogWeight`
- Primary category: `Health & Fitness`
- Secondary category: none
- Platforms: iOS, iPadOS, watchOS companion, macOS
- Age rating: 4+ (no user-generated content, no web access, no ads)

## Subtitle options

- `Fast weight logging to Apple Health`
- `Calm body-weight tracking`

## Promotional text

`LogWeight lets you save body weight to Apple Health in seconds. No ads, no account, no social feed — just quick entry and clear history.`

## Description

`LogWeight is the fastest calm way to log your body weight on Apple devices.

• Save directly to Apple Health (Body Mass)
• Stepper-first entry for one-handed use
• Apple Watch support with Digital Crown input
• History list with trend chart on iPhone, iPad, and Mac
• Privacy-first by design: no accounts, no analytics, no third-party SDKs

Your data remains in Apple Health. LogWeight does not run its own weight database.`

## Keywords

`weight,body weight,health,healthkit,apple health,log,tracker,watch`

## Privacy URL

- Canonical policy source: `Docs/Privacy.md`
- App Store Connect requires a public HTTPS URL (host this text before submission).

## Support URL

- TODO before release: choose a public support page/contact URL.

## Screenshots checklist

- iPhone 6.9": entry, history chart, settings.
- iPhone 6.1": entry + saved state.
- iPad 13": entry and history chart.
- Apple Watch: entry screen and complication.
- Mac: menu-bar entry popover + history window.

## Review notes (for App Review)

`LogWeight requests HealthKit read/write access only for Body Mass.
The app writes and reads body weight samples in Apple Health.
No data is transmitted off-device by the app.`
