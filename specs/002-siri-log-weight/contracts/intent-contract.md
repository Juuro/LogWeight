# Contract: Log Weight App Intent

Platform surface exposed to Siri, Shortcuts, Spotlight, the Action Button, and Controls (via a Shortcuts action).

## Intent

| Property | Value |
|---|---|
| Type | `LogWeightIntent: AppIntent` in `App/iOS/Intents/LogWeightIntent.swift` |
| Title | "Log Weight" (localized) |
| `openAppWhenRun` | `false` (Clarification: never opens the app) |
| `authenticationPolicy` | `.requiresAuthentication` (device must be unlocked) |
| `isDiscoverable` | `true` |

### Parameters

| Name | Type | Required | Prompt |
|---|---|---|---|
| `weight` | `Double` | Yes | "What's your weight?" (localized) |
| `unit` | `WeightUnitOption?` (`kilograms`, `pounds`) | No (shown under "Show More" in Shortcuts) | none; never asked by Siri |

Unit rules: `unit` if set (Shortcuts), otherwise `WeightDisplayPreferences.preferredUnit()`. Spoken units are not interpreted (research R1, device finding). The confirmation dialog states the unit used. Non-finite or non-positive numbers are rejected as invalid.

### Flow

1. `WeightLogger.evaluate(kilograms:)`.
2. Branch on result:
   - `.accessNotGranted` -> error dialog (open LogWeight to allow Health access); stop.
   - `.invalid` -> error dialog (enter a valid weight); stop.
   - `.duplicate` -> result dialog "Already logged ..."; return the existing value; stop (no write).
   - `.needsConfirmation` -> `requestConfirmation`; if it throws (declined, cannot be asked) -> nothing saved; throw a localized error.
   - `.ready` -> continue.
3. `WeightLogger.save(_:)`; on `.saved` return result + dialog; on `.failed` throw a localized error and call `SecurityLog.error(_, code:)`.
4. After a successful save, update the widget's last-saved-entry cache (`SharedWeightEntryStore.save`, not the staged draft) and reload widget timelines so widgets show the new value. No notification post, no app launch.

### Result

`ReturnsValue<Measurement<UnitMass>>` (the saved or already-logged weight, in the unit the user used) and `ProvidesDialog`.

### Dialog strings (all 11 locales, `Localizable.strings`)

| Key (English) | Used for |
|---|---|
| `Log Weight` | Intent title, short title |
| `Weight` | Parameter title |
| `What's your weight?` | Parameter prompt |
| `Logged %@.` | Success (value formatted by `WeightFormatter`) |
| `Already logged %@.` | Duplicate |
| `%@ looks unusual. Log it anyway?` | Confirmation (range or jump) |
| `Open LogWeight once to allow access to Apple Health.` | No write access |
| `Enter a valid weight.` | Invalid |
| `Couldn't log your weight. Please try again.` | Save failed |
| `Not logged. That weight looks unusual.` | Confirmation declined or impossible (unattended run) |
| `Log ${weight}` | Shortcuts action summary |
| `Saves your weight to Apple Health.` | Action description |

Final wording is set at implementation; the keys must exist in every locale.

## App Shortcuts provider

`LogWeightAppShortcuts` exposes exactly one `AppShortcut` for `LogWeightIntent`, `systemImageName: "scalemass"`.
`SaveWeightIntent` is removed from the provider and marked `isDiscoverable = false` (FR-007).

### Spoken phrases (`AppShortcuts.strings`, per locale)

English keys (each translation MUST contain `${applicationName}` exactly once and MUST NOT contain a number placeholder):

```text
"Log weight in ${applicationName}"
"Log my weight in ${applicationName}"
"Save weight in ${applicationName}"
```

Locales: en, de, fr, es, it, nl, pt-BR, ja, ko, zh-Hans, zh-Hant. Same three keys in every file; enforced by `Tools/check-localizations.sh`.

## Compatibility

- Widget `SaveWeightIntent` signature and behavior unchanged (FR-014).
- The new intent never reads or modifies the widget's staged draft. It writes only the last-saved-entry cache (the same cache manual saves update) and reloads widget timelines. `SharedWeightEntryStore.syncFromLatestWeight` is deliberately not used because it discards the draft.
- No new entitlements, no new Info.plist keys (Health usage strings already exist).
