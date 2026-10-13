# Feature Specification: Voice and Shortcut Weight Logging

**Feature Branch**: `002-siri-log-weight` (spec directory only; work continues on the current branch unless the maintainer decides otherwise)

**Created**: 2026-10-13

**Status**: Paused (2026-10-13). Implementation is on the branch but not releasable: spoken decimals could not be verified on device, and Siri AI cannot be tested from the EU. See tasks.md for open device checks.

**Input**: User description: "Add Siri / App Intents support to LogWeight: an AppIntent "Log weight" with a weight parameter (unit-aware), exposed via an AppShortcutsProvider with phrases that include the app name (e.g. "Log weight in LogWeight"), so users can log weight via Siri, Shortcuts, Action Button, Spotlight and Lock Screen/Control Center. Writes must go through HealthKitStore in Packages/LogWeightCore (no direct HKHealthStore), no health values in SecurityLog, phrases localized for all 11 locales, handle first-entry case (no existing body-mass samples), unit handling, confirmation dialog, and avoid duplicate entries with Apple Health's own Siri logging."

## Context

LogWeight already ships a "Save Weight" action, registered with two English phrases ("Save weight in LogWeight", "Log weight in LogWeight"). That action exists for the interactive widget: it takes **no weight value**, and saves whatever value the widget last staged, then opens the app. Spoken through Siri or run from Shortcuts, it therefore does not log what the user said and gives no spoken answer back. This feature replaces that gap with a real "log this weight" action that accepts a value and takes over the spoken phrases, and keeps the widget's save button working unchanged.

Apple Health's own Siri support can already log weight into Health. LogWeight does not compete with that; it offers the same outcome through the LogWeight name, with LogWeight's units, validation, and confirmation, and makes the action available on Shortcuts, the Action Button, Spotlight, and the Controls surfaces.

## Clarifications

### Session 2026-10-13

- Q: Should the new value-taking action own the existing "Log weight in LogWeight" phrases, or should the widget's Save action keep them? → A: The new action owns them. The widget Save keeps working from the widget button only and has no spoken phrases.
- Q: After saving, should the action stay in the background or open the LogWeight app? → A: Never opens the app. The confirmation is spoken or shown as a Siri/Shortcuts snippet only.
- Q (device finding): Can Siri resolve a spoken decimal with a unit into the weight? → A: No. The weight parameter is a plain number and an optional unit choice (default: the app's preferred unit); typed values in Shortcuts accept decimals.
- Q: When the action runs unattended (no one can be asked to confirm) with an implausible value or a large jump, should it save or refuse? → A: Refuse both and return a clear error. Nothing is saved.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Log a spoken weight with Siri (Priority: P1)

A user says "Log weight in LogWeight". Siri asks "What's your weight?" and the user answers with a number (e.g. "82,4"), which is read in the unit chosen in the app's settings. LogWeight records the weight in Apple Health and Siri confirms aloud and on screen, e.g. "Logged 82.4 kg".

**Why this priority**: This is the core request and delivers value on its own, hands-free and without opening the app.

**Independent Test**: Invoke the phrase with a value on a device with Health access granted; verify a new body-mass entry with that value and the current time appears in Apple Health and in LogWeight's history, and that the spoken/on-screen confirmation shows the same value.

**Acceptance Scenarios**:

1. **Given** Health write access is granted, **When** the user says the phrase and answers Siri's weight question with a valid weight, **Then** one body-mass entry with that value is saved to Apple Health and Siri confirms the saved value and unit.
2. **Given** Health write access is granted, **When** the user cancels or does not answer Siri's weight question, **Then** nothing is saved.
3. **Given** the user's preferred unit is pounds, **When** they answer with a number, **Then** it is interpreted and confirmed in pounds; **when** a Shortcuts user picks an explicit unit (kilograms or pounds) in the action, **then** that unit is honoured and the saved weight is correct regardless of the app's display unit.
4. **Given** Health write access has been denied or not yet requested, **When** the action runs, **Then** the user is told that access is needed and how to grant it, and nothing is saved.

---

### User Story 2 - Log weight from Shortcuts, Action Button, and Spotlight (Priority: P2)

A user finds "Log Weight" in the Shortcuts app, in Spotlight, or assigns it to the Action Button. Running it asks for a weight (or uses a value provided by an automation) and logs it exactly as in Story 1, with an on-screen confirmation.

**Why this priority**: Same capability on non-voice surfaces; users who cannot or do not want to speak benefit most, and automations (e.g. a smart-scale shortcut) become possible.

**Independent Test**: Add the action to a new shortcut, give it a fixed value, run it from the Shortcuts app and from the Action Button; verify one entry saved per run.

**Acceptance Scenarios**:

1. **Given** the action is placed in a shortcut with a fixed value, **When** the shortcut runs, **Then** one entry with that value is saved and a confirmation is shown.
2. **Given** the action has no value supplied, **When** it runs, **Then** the user is prompted for one.
3. **Given** the action is used in a larger shortcut, **When** it finishes, **Then** it hands the saved value onward so later steps can use it.

---

### User Story 3 - First-ever entry and unusual values are handled safely (Priority: P2)

A brand-new user, with no body-mass entries in Apple Health, logs a weight by voice. A user also sometimes mishears or mis-speaks a value ("eight hundred twenty kilograms", "0").

**Why this priority**: Health data is long-lived and charted; a wrong first value or an absurd value silently saved erodes trust. The app's existing entry flow already treats the first entry specially, so voice must not bypass those safeguards.

**Independent Test**: With an empty Health store, log a plausible value; separately, attempt an implausible value; verify the first is saved with confirmation and the second is rejected or confirmed before saving.

**Acceptance Scenarios**:

1. **Given** Apple Health has no body-mass entries, **When** the user logs a plausible weight by voice, **Then** it is saved as the first entry and confirmed, without requiring the app to be opened.
2. **Given** a value outside the plausible human range, **When** the action runs, **Then** nothing is saved until the user explicitly confirms or corrects the value.
3. **Given** the value is very different from the most recent entry (a large jump), **When** the action runs, **Then** the user is asked to confirm it before it is saved (threshold default in Assumptions).

---

### User Story 4 - No accidental duplicates (Priority: P3)

A user who also uses Apple Health's own Siri logging, or who triggers the action twice in quick succession (double press of the Action Button, Siri retry), should not end up with duplicate entries for one weighing.

**Why this priority**: Duplicates clutter the auditable history list. Lower priority because the user can delete entries and the cases are uncommon.

**Independent Test**: Run the action twice within a few seconds with the same value; verify the user is told it was already logged and only one entry exists.

**Acceptance Scenarios**:

1. **Given** an entry with the same value was saved moments ago, **When** the action runs again with that value, **Then** no second entry is created and the user is told the weight was already logged.
2. **Given** a different value is logged shortly after the first, **When** the action runs, **Then** it is saved as a separate entry.

---

### User Story 5 - Phrases work in the user's language (Priority: P2)

A German user says "Gewicht in LogWeight erfassen"; a Japanese user uses a Japanese phrase. Every supported language has natural phrases that include the app name, and the action's title, prompts, and confirmations appear in the user's language.

**Why this priority**: The app ships in 11 languages; an English-only voice feature would be a regression in perceived quality for most of its audience.

**Independent Test**: Set the device language to each supported locale in turn; verify the shortcut appears with a localized title and phrase in the Shortcuts app and that the confirmation text is localized.

**Acceptance Scenarios**:

1. **Given** the device language is any supported locale, **When** the user views the app's shortcuts, **Then** titles and suggested phrases are in that language and contain the app name.
2. **Given** the localization parity check runs, **Then** it passes with the new strings included.

---

### Edge Cases

- Health is unavailable on the device (e.g. unsupported hardware) or the device is locked: the action fails with a clear message and saves nothing; locked-device behaviour follows the system default for protected health data.
- The user cancels the follow-up question ("What's your weight?"): nothing is saved.
- Value spoken with decimal comma vs. point, in their locale ("82,4" / "82.4"): interpreted correctly for the device locale.
- The widget's existing Save button is used after this feature ships: it continues to save the staged widget value exactly as before.
- The widget's staged draft value must not leak into the new action (it must never silently save a stale draft when a value was expected).
- Phrase collision with Apple Health's built-in Siri logging: phrases include the app name so the user can choose which app logs; no attempt is made to suppress Apple's own behaviour.
- The write to Apple Health fails after the user has been told it succeeded: not allowed; confirmation is only given after the write succeeds.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST offer a "Log Weight" action that accepts a weight value from the user and saves it as a new body-mass entry in Apple Health, timestamped at the time of the action.
- **FR-002**: When no value is supplied, the action MUST ask the user for one before doing anything else.
- **FR-003**: The action MUST accept the weight in kilograms or pounds (the units the app supports); a spoken number is read in the user's preferred unit, and a unit chosen in the Shortcuts action MUST take precedence over the app's display unit. The confirmation always states the unit used.
- **FR-004**: The action MUST confirm the saved value and unit back to the user, spoken when invoked by voice and visually otherwise, and only after the save to Apple Health has actually succeeded. The action MUST NOT open the LogWeight app; the confirmation is the only feedback.
- **FR-005**: The action MUST be discoverable and runnable from Siri (voice), the Shortcuts app, Spotlight, and the Action Button.
- **FR-006**: The action MUST be usable from the Controls surfaces (Lock Screen / Control Center) by adding it to a control via Shortcuts; a dedicated built-in control is out of scope for this version.
- **FR-007**: The app MUST register spoken phrases that each contain the app name, so Siri can distinguish them from Apple Health's own weight logging. These phrases, including the existing "Log weight in LogWeight" and "Save weight in LogWeight", MUST belong to the new Log Weight action; the widget's Save action MUST NOT be registered with any spoken phrase.
- **FR-008**: All shortcut titles, spoken phrases, parameter prompts, confirmations, and error messages MUST exist in every supported locale (en, de, fr, es, it, nl, pt-BR, ja, ko, zh-Hans, zh-Hant), and the existing localization parity check MUST pass.
- **FR-009**: The action MUST refuse values outside a plausible human weight range without explicit user confirmation, and MUST ask for confirmation when the value differs from the most recent entry by more than a documented threshold. When no one can be asked to confirm (unattended run, e.g. an automation), the action MUST refuse such values, save nothing, and return a clear error.
- **FR-010**: When Apple Health has no body-mass entries yet, the action MUST still work and MUST save the first entry after the same plausibility check.
- **FR-011**: When Health write access has not been granted, the action MUST NOT save anything and MUST tell the user what to do.
- **FR-012**: A repeat run with the same value within a short window MUST NOT create a second entry, and the user MUST be told that the weight was already logged.
- **FR-013**: The action MUST return the saved value as a result so it can be used by later steps in a shortcut.
- **FR-014**: The existing widget "Save" button behaviour MUST continue to work unchanged (it remains reachable from the widget only, not by voice), and the widget's staged draft MUST NOT be read or modified by the new action.
- **FR-015**: Weight data MUST be written only to Apple Health, through the app's single Health-access layer; no separate weight store, cache-of-record, or sync store may be introduced.
- **FR-016**: No weight value, date, or spoken text MAY appear in logs or analytics; instrumentation records only that an invocation occurred and its outcome category.
- **FR-017**: The feature MUST NOT send any user data off the device and MUST NOT add tracking or third-party components.
- **FR-018**: The action MUST be testable without a real Health store using the in-memory store used by the existing tests.

### Key Entities

- **Weight Log Request**: The user's intent to record one weight: a value and unit (possibly spoken), plus the time of the request. Becomes at most one body-mass entry.
- **Body-Mass Entry**: The record in Apple Health (the only persistent weight data); owned by Apple Health, read and written by the app.
- **Log Confirmation**: What is returned to the user and to downstream shortcut steps: the saved value and unit, or an explanation why nothing was saved (access denied, rejected value, duplicate, cancelled).
- **Spoken Phrase Set**: The localized list of invocation phrases, per supported language, each containing the app name.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user can log a weight by voice in under 10 seconds with one phrase and one spoken answer without opening the app.
- **SC-002**: In testing across all 11 supported languages, 100% of registered phrases contain the app name and each language has at least 2 natural-sounding phrases.
- **SC-003**: 100% of successful runs produce exactly one Health entry whose value matches the confirmed value (verified over a test matrix covering each unit and the first-entry case).
- **SC-004**: 0 entries are saved without Health write access, with an implausible value or large jump that the user did not confirm (including all unattended runs), or twice for a repeated identical request within the duplicate window.
- **SC-005**: The widget's existing Save flow passes its current tests without modification of expected behaviour.
- **SC-006**: A privacy review of logging output finds no weights, dates, or spoken text in any log produced by the action.

## Assumptions

- A spoken unit is not understood: device testing (2026-10-13, German) showed Siri cannot turn a spoken decimal with a unit ("68,9 Kilo") into a weight, so by voice the answer is a plain number in the preferred unit. Whole numbers with a unit did resolve, but the unit was not relied upon.
- Spoken phrases registered with Siri cannot contain a numeric value, so by voice the weight is always requested as a follow-up question; Shortcuts users can supply the value directly in the action.
- Target users already use LogWeight and have granted (or can grant) Health write access; the action does not replace the first-run permission flow.
- "Plausible human range" defaults to 20–500 kg (equivalent in other units); "large jump" defaults to a change of more than 10 kg from the most recent entry. Both are tunable during planning.
- The duplicate window defaults to 60 seconds for an identical value.
- A dedicated Lock Screen / Control Center control is out of scope for v1; users get those surfaces by adding the action through Shortcuts (FR-006). Revisit if demand appears.
- Apple Watch voice logging is out of scope for this version (Watch shortcuts can be a follow-up).
- Siri phrase recognition quality and routing relative to Apple Health's own logging is governed by the system; the app only controls its registered phrases and their localization. Exact routing behaviour needs on-device verification during implementation.
- Existing localization catalog conventions (`Localizable.strings` per locale) are reused; any additional resource format required for spoken phrases is decided during planning.
- The feature depends on the existing Health-access layer, unit handling, and in-memory test store; no new persistent data is introduced.
