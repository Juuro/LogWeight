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
- `AccessibilityAuditTests` (`App/iOSUITests/AccessibilityAuditTests.swift`) runs XCTest's
  `performAccessibilityAudit()` against Entry (first-time and post-save), History (with chart),
  and Settings — catches contrast, hit-region, missing-trait, and clipped-text regressions
  automatically instead of relying on the manual matrix alone. Excludes `.dynamicType` (covered
  manually above) since that audit type needs simulator support not available on every runtime.

### Findings fixed from the automated audit (2026-09-17)

- Save button: white label on default accent blue measured ~4.0:1, under the 4.5:1 AA
  threshold for regular-weight text. Fixed in `EntryView.saveButtonBackground` by darkening the
  accent color (HSB brightness -0.15) specifically for that button, so the fix still tracks
  whatever `AccentColor` the app ships.
- First-weight prompt ("Enter your first weight"): flagged as clippable at larger Dynamic Type
  sizes. Fixed by adding `.fixedSize(horizontal: false, vertical: true)` so the text wraps
  instead of being clipped by the VStack's ideal-size negotiation.
- Settings "Open Apple Health" label: flagged as clippable at larger Dynamic Type sizes. Fixed
  by adding `.fixedSize(horizontal: false, vertical: true)` to the `Label` so its title wraps
  instead of being clipped by the `Link`'s ideal-size negotiation.

## Known limitations

- `history.chart` currently uses a compact line+point chart without custom VoiceOver summaries. If future accessibility feedback requests richer chart narration, add an explicit summary label (e.g., latest value and 7-day delta).
- `UIScreen.isCaptured` has platform-level detection gaps documented in `Docs/Privacy.md`.
- Two automated-audit findings are accepted as-is rather than patched:
  - History row timestamp and the post-save "Saved to Apple Health" status text both use the
    system `.secondary` semantic color at `.callout` size, which the audit reports as
    "Contrast nearly passed." `.secondary` is Apple's own HIG-sanctioned secondary-label color
    and automatically adapts to Increase Contrast / Reduce Transparency; overriding it with a
    custom color would fight the platform's semantic color system for a borderline warning, not
    a hard failure.
  - Settings' toolbar "Done" button reports "Contrast failed" on iOS 26. The button has zero
    custom styling in `SettingsView.swift` — a screenshot confirms it renders as a stock
    Liquid Glass toolbar capsule (translucent pill, primary-label text). This is iOS 26 system
    chrome, not app code; forcing a custom `.buttonStyle` to appease the audit would fight the
    platform's Liquid Glass design language rather than fix an app bug.
  - "Pre-fill with" row's trailing value text ("Last saved" / "Fixed value") reports "Text
    clipped" at the largest Dynamic Type sizes. That text is SwiftUI's own default `Form`
    `Picker` trailing-value label, not custom app layout; forcing a different picker style
    to work around it would change the row's tap behavior platform-wide for a cosmetic
    clip at an extreme text size.
