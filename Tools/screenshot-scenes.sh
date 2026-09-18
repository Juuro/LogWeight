#!/usr/bin/env bash
# LogWeight-specific screenshot configuration.
# Sourced by Tools/CaptureScene.sh — do not execute directly.
#
# To adapt for another iOS project:
#   1. Copy Tools/CaptureScene.sh and this file into the project's Tools/ directory.
#   2. Update XCODEPROJ, SCREENSHOT_SCHEME, scene_to_test(), and ALL_SCENES below.
#   3. Add matching XCUITest methods in your screenshot target (see Docs/AIScreenshotWorkflow.md).

XCODEPROJ="${ROOT_DIR}/LogWeight.xcodeproj"
SCREENSHOT_SCHEME="LogWeightScreenshots"

# Maps a scene ID to its XCTest identifier (Target/Class/method).
scene_to_test() {
  case "$1" in
    entry-default)             echo "LogWeightScreenshots/EntryScreenshots/test_entry_default" ;;
    entry-after-plus-ten)      echo "LogWeightScreenshots/EntryScreenshots/test_entry_after_plus_ten" ;;
    entry-keyboard-up)         echo "LogWeightScreenshots/EntryScreenshots/test_entry_keyboard_up" ;;
    history-empty)             echo "LogWeightScreenshots/HistoryScreenshots/test_history_empty" ;;
    history-with-chart-30d)    echo "LogWeightScreenshots/HistoryScreenshots/test_history_with_chart_30d" ;;
    history-90d-plateau)       echo "LogWeightScreenshots/HistoryScreenshots/test_history_90d_plateau" ;;
    history-list-scrolled)     echo "LogWeightScreenshots/HistoryScreenshots/test_history_list_scrolled" ;;
    history-list-small-scroll) echo "LogWeightScreenshots/HistoryScreenshots/test_history_list_small_scroll" ;;
    settings-default)          echo "LogWeightScreenshots/SettingsScreenshots/test_settings_default" ;;
    settings-lbs-unit)         echo "LogWeightScreenshots/SettingsScreenshots/test_settings_lbs_unit" ;;
    # Not in ALL_SCENES: an App Store Connect IAP-review screenshot, not a
    # marketing scene — must stay out of the App Store screenshot set.
    settings-tipjar)           echo "LogWeightScreenshots/SettingsScreenshots/test_settings_tipjar" ;;
    *)
      echo "Unknown scene: $1" >&2
      echo "Run Tools/CaptureScene.sh with no arguments to see available scenes." >&2
      return 1
      ;;
  esac
}

# All scene IDs — used by --all, and by Tools/CaptureStoreScreenshots.sh to
# build the App Store screenshot set (Apple caps uploads at 10 per device
# size, so keep this list at exactly 10).
ALL_SCENES=(
  entry-default
  entry-after-plus-ten
  entry-keyboard-up
  history-empty
  history-with-chart-30d
  history-90d-plateau
  history-list-scrolled
  history-list-small-scroll
  settings-default
  settings-lbs-unit
)
