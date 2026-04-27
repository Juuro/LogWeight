# Privacy

LogWeight handles body weight, which is GDPR Art. 9 special-category personal data. The privacy posture is documented here so reviewers, auditors, and future contributors share the same understanding.

## Data flow

1. The user enters a weight in the app.
2. The value is held in memory (`@State`) only for the lifetime of the entry surface.
3. On Save, the value is written to `HKHealthStore` via `HKQuantityTypeIdentifier.bodyMass`.
4. The local copy is discarded; subsequent reads go back through HealthKit.

The app:
- has **no** server, **no** account, **no** cloud sync of its own.
- maintains **no** separate weight database.
- writes **no** weight values to logs, `UserDefaults`, `Keychain`, files, or any other persistent storage.
- contains **no** third-party SDKs (no analytics, no crash reporters, no auth providers).
- does **not** access the contact book, location, microphone, camera, photos, or any sensor other than HealthKit body-mass.

Cross-device synchronisation, when the user has more than one device, is handled by Apple Health itself.

## Lawful basis

The lawful basis for processing under GDPR is **explicit consent**, gathered through the standard HealthKit authorisation sheet. The user can revoke consent at any time in **Settings → Health → Data Access & Devices → LogWeight**. Once revoked, future writes will fail and the app surfaces a calm prompt to re-enable.

## Data subject rights

Because the app holds no copy of the user's data:
- **Right of access:** the user reads their data in the Health app.
- **Right to rectification:** edits happen in the Health app.
- **Right to erasure:** delete in the Health app or revoke HealthKit access.
- **Right to data portability:** export from the Health app.
- **Right to object:** revoke HealthKit access.

## Apple Privacy Manifest

`App/iOS/Resources/PrivacyInfo.xcprivacy` declares:

- `NSPrivacyTracking = false` — LogWeight does not track users.
- `NSPrivacyCollectedDataTypes` — declares Health & Fitness > Body Measurements with purpose `AppFunctionality`, linked to the user, not used for tracking.
- `NSPrivacyAccessedAPITypes` — declares the required-reason `UserDefaults` API (settings storage).

## On-screen redaction

The app implements two layers of on-screen redaction:

1. `.privacySensitive()` — the SwiftUI modifier that asks the OS to redact content in system-generated screenshots (app switcher, Siri suggestions, Lock-Screen previews).
2. `PrivacyRedactionModifier` — a custom modifier that overlays an opaque view when the app is backgrounded OR when `UIScreen.main.isCaptured` reports an active screen recording.

### Known limitations of `UIScreen.isCaptured`

`UIScreen.isCaptured` is documented by Apple to *not* fire reliably in every capture scenario. We acknowledge:

- **AirPlay mirroring** to an Apple TV does not always set `isCaptured = true`.
- **Wired QuickTime recording** via a Mac does not set `isCaptured = true`.
- **ReplayKit-driven capture** has its own lifecycle and may not be reflected in `isCaptured`.

These are Apple-framework limitations, not defects in LogWeight. The `.privacySensitive()` modifier handles every system-generated capture scenario regardless of these gaps.

## Data export and deletion (operational)

If a user requests their data:
- They control it themselves in the Health app — LogWeight cannot return data it does not hold.
- If a request comes through the LogWeight contact channel, the response is: "Open the Health app on your device. Tap your profile photo → Export All Health Data."

If a user requests deletion:
- They delete the values in the Health app.
- They revoke HealthKit access for LogWeight in Settings → Health.

## Logging

`SecurityLog` (in `LogWeightCore`) is the only logging facade. It exposes `event(_: StaticString)` and `error(_: StaticString, code: Int)` — and nothing else. There is no API path through which a weight value, a user identifier, a sample identifier, or a date can be logged.
