# Data Model: Voice and Shortcut Weight Logging

No new persistent data. All types below are in-memory values in `LogWeightCore` (Foundation only, no HealthKit types).
The only persisted weight data remains the Apple Health body-mass entry.

## WeightLogPolicy

Tunable constants, defaults from the spec's Assumptions.

| Field | Type | Default | Meaning |
|---|---|---|---|
| `plausibleRangeKilograms` | `ClosedRange<Double>` | `20...500` | Values outside need explicit confirmation (FR-009) |
| `largeJumpKilograms` | `Double` | `10` | Difference from newest entry above which confirmation is needed |
| `duplicateWindow` | `TimeInterval` | `60` | An identical value this recent is a duplicate (FR-012) |
| `duplicateToleranceKilograms` | `Double` | `0.05` | "Identical" means within this tolerance (absorbs kg/lb rounding) |

## WeightLogEvaluation (result of checking a request, before saving)

| Case | Meaning | Intent response |
|---|---|---|
| `.ready(Weight)` | Safe to save | Save, then confirm |
| `.needsConfirmation(Weight, ConfirmationReason)` | Unusual but possible | Ask; save only on yes; refuse if it cannot be asked |
| `.duplicate(Weight)` | Same value logged within the window | Do not save; say "already logged" |
| `.accessNotGranted` | Health write not authorized | Do not save; tell user to open LogWeight |
| `.invalid` | Not finite or <= 0 | Do not save; ask for a valid weight |

`ConfirmationReason`: `.outOfRange`, `.largeJump`.

## WeightLogOutcome (what the intent turns into a dialog and result)

`.saved(Weight)`, `.alreadyLogged(Weight)`, `.declined`, `.accessNotGranted`, `.invalid`, `.failed(reasonCode: Int)`.
`.failed` carries only the numeric code from `HealthKitError` (never a value) for `SecurityLog.error`.

## Weight (existing)

`valueInKilograms`, `recordedAt`. The new action creates it with `recordedAt = now` (injected clock in tests).

## Validation and state rules

- Evaluation order: authorization -> validity -> duplicate -> range -> jump. First failing rule decides.
- Both `.outOfRange` and `.largeJump` can apply; one confirmation covers both (reason = `.outOfRange` takes precedence).
- Saved at most once per run; the intent never retries a failed save.
- Unit handling: the request arrives in kilograms (the intent converts from `Measurement<UnitMass>`); the display unit for dialogs is the unit the user supplied, else `WeightDisplayPreferences.preferredUnit()`.
