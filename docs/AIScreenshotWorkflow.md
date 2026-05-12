# AI Screenshot Workflow

## Purpose

After making a UI change, an AI coding assistant can run a single shell command to capture a PNG of the relevant screen state in the iOS Simulator, then visually inspect it and iterate until the result matches intent.

This is possible because Claude Code's `Read` tool supports PNG and JPEG image files — the AI reads the captured screenshot directly, evaluates it, adjusts code, and recaptures in a loop without human intervention.

---

## Quick start

```bash
# Capture one scene (builds if needed, boots simulator, runs the test, writes PNG)
Tools/CaptureScene.sh --scene entry-default

# Capture on a specific device (default: iPhone 16 Pro)
Tools/CaptureScene.sh --scene history-with-chart-30d --device "iPhone 16"

# Capture all scenes at once
Tools/CaptureScene.sh --all
```

Output PNGs land in `Docs/ai-screenshots/` (gitignored). The script prints the absolute path of each PNG so the AI can `Read` it immediately.

---

## Scene catalog

| Scene ID | Class | What it shows |
|---|---|---|
| `entry-default` | `EntryScreenshots` | Entry surface, splash dismissed, empty store |
| `entry-after-plus-ten` | `EntryScreenshots` | Entry surface after 10 `+` taps — Save enabled |
| `entry-keyboard-up` | `EntryScreenshots` | Entry surface with decimal-pad keyboard open |
| `entry-xxxl-dynamic-type` | `EntryScreenshots` | Entry surface at XXXL accessibility text size |
| `history-empty` | `HistoryScreenshots` | History sheet, no entries |
| `history-with-chart-30d` | `HistoryScreenshots` | History sheet, 30-day linear trend chart |
| `history-90d-plateau` | `HistoryScreenshots` | History sheet, 90-day plateau-then-drop chart |
| `history-chart-crosshair` | `HistoryScreenshots` | History chart with crosshair/tooltip engaged |
| `settings-default` | `SettingsScreenshots` | Settings sheet, default state (kg) |
| `settings-lbs-unit` | `SettingsScreenshots` | Settings sheet after switching to lbs |

---

## AI iteration loop

```
1. Implement UI change (edit Swift views, modifiers, layout)
2. Run:  Tools/CaptureScene.sh --scene <name>
3. Read the printed PNG path with the Read tool
4. Evaluate: does the screen match intent?
   - Yes → done
   - No  → adjust code, go to step 2
```

Typical iteration is 30–60 s per cycle (build is incremental after the first run).

---

## How scenes work

Scenes live in `App/iOSScreenshots/` as a dedicated XCUITest target (`LogWeightScreenshots`). Unlike the behavioral tests in `LogWeightUITests`, scene tests are designed to **always pass** — they drive the UI to a target state and attach a named `XCTAttachment` screenshot. Assertions are minimal (element existence only, to confirm navigation succeeded).

Each scene:
1. Launches `LogWeight` with `--use-in-memory-store --skip-splash` (optionally `--seed=<fixture>`).
2. Drives the UI via accessibility IDs (tap, long-press, type).
3. Calls `attachScreenshot(named: "<scene-id>")` — the wrapper script matches on this name.

---

## Adding a new scene

1. **Add a test method** to the appropriate file in `App/iOSScreenshots/`:

   ```swift
   func test_my_new_scene() throws {
       launchApp(seed: "linearTrend30Days")
       let button = app.buttons["some.accessibility.id"]
       waitForElement(button, named: "some.accessibility.id")
       button.tap()
       Thread.sleep(forTimeInterval: 0.3)
       attachScreenshot(named: "my-new-scene")  // kebab-case, matches the scene ID
   }
   ```

2. **Register the scene** in `Tools/CaptureScene.sh` inside the `scene_to_test` case statement:

   ```bash
   my-new-scene) echo "LogWeightScreenshots/ClassName/test_my_new_scene" ;;
   ```

3. **Update the scene catalog** in this document.

---

## Seed fixtures

The `--seed=<rawValue>` launch argument preloads `InMemoryHealthKitStore` with canned data from `ScreenshotFixtures.swift` (in `LogWeightCore`). Available fixtures:

| Raw value | Description |
|---|---|
| `empty` | No entries |
| `singleEntry` | One entry at 78.4 kg |
| `linearTrend30Days` | 30-day linear descent 82.0 → 78.5 kg |
| `plateauThenDrop90Days` | 90-day plateau (84 kg) then gradual drop to 76 kg |

All fixtures use a fixed anchor date (`ScreenshotFixture.referenceDate = 2026-05-01 12:00 UTC`) so chart x-axes never drift with the wall clock.

---

## Prerequisites

- macOS 14+, Xcode 15+
- `xcodegen generate` already run (or run it first: `xcodegen generate`)
- The target simulator must appear in `xcrun simctl list devices available`
- No HealthKit entitlements needed (uses `InMemoryHealthKitStore`)
