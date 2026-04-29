# Accessibility Audit (Phase 4)

This checklist captures the current accessibility baseline for LogWeight v1.0 RC.

## Scope

- iOS/iPadOS entry, history (including chart), and settings.
- watchOS entry and settings surfaces.
- macOS menu-bar entry, history window, and settings window.

## Manual test matrix

### iOS / iPadOS

- VoiceOver:
  - Entry: value text, +/- controls, Save, History, Settings are announced with clear labels.
  - History: chart and list rows are reachable; rows announce value + timestamp.
  - Settings: all controls are reachable with predictable rotor order.
- Dynamic Type:
  - Validate at `AXXXL` and `Accessibility XXXL` in portrait and landscape iPad.
  - Save flow remains reachable with stepper-primary path.
- Contrast:
  - Check Light/Dark mode for save status, error text, chart stroke/points.
- Hit targets:
  - +/- and Save remain >= 44pt tap size.

### watchOS

- VoiceOver:
  - Crown-adjusted value is announced as weight.
  - Save, History, Settings controls are discoverable and non-overlapping.
- Digital Crown:
  - Focus stays on value and adjustments remain stable.
- Dynamic Type:
  - Verify no overlap on smaller watch sizes (e.g., 42 mm).

### macOS

- Keyboard:
  - Return commits from value field.
  - Cmd+N opens History.
  - Cmd+, opens Settings.
- VoiceOver:
  - Value field, Save, History, Settings are announced.
- Contrast:
  - Parse hints and error states are distinguishable in both appearances.

## Automated regression guardrails

- `EntryViewSmokeTests.testAccessibilityXXXLStillCanSaveWithStepperFlow` verifies very large Dynamic Type still allows save.
- `EntryViewSmokeTests.testSettingsSheetExposesCoreControls` verifies key settings controls remain reachable.
- `EntryViewSmokeTests.testHistorySheetShowsTrendChart` verifies chart remains present on iOS.

## Known limitations

- `history.chart` currently uses a compact line+point chart without custom VoiceOver summaries. If future accessibility feedback requests richer chart narration, add an explicit summary label (e.g., latest value and 7-day delta).
- `UIScreen.isCaptured` has platform-level detection gaps documented in `Docs/Privacy.md`.
