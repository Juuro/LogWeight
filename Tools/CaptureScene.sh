#!/usr/bin/env bash
# CaptureScene.sh — AI-driven simulator screenshot capture for iOS projects.
#
# Usage:
#   Tools/CaptureScene.sh --scene entry-default
#   Tools/CaptureScene.sh --scene history-with-chart-30d --device "iPhone 16 Pro"
#   Tools/CaptureScene.sh --all
#
# Project-specific config (XCODEPROJ, SCREENSHOT_SCHEME, scene_to_test, ALL_SCENES)
# lives in Tools/screenshot-scenes.sh alongside this script.
#
# Each named scene maps to a test method in the screenshot XCUITest target.
# The script runs that single test, exports PNG attachments from the resulting
# .xcresult bundle, and copies them to Docs/ai-screenshots/.
# Absolute paths of produced PNGs are printed to stdout so the AI can Read them.
#
# Prerequisites: xcodegen already run; Xcode 15+ installed.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# --- Load project-specific configuration ---
CONFIG_FILE="$(dirname "${BASH_SOURCE[0]}")/screenshot-scenes.sh"
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Missing config: $CONFIG_FILE" >&2
  echo "Create Tools/screenshot-scenes.sh with XCODEPROJ, SCREENSHOT_SCHEME, scene_to_test(), and ALL_SCENES." >&2
  exit 1
fi
# shellcheck source=Tools/screenshot-scenes.sh
source "$CONFIG_FILE"

PROJECT="${XCODEPROJ}"
SCHEME="${SCREENSHOT_SCHEME}"
RESULT_BUNDLE="$ROOT_DIR/tmp/ai-screenshots-run.xcresult"
ATTACH_TMP="$ROOT_DIR/tmp/ai-screenshots-attachments"
OUT_DIR="$ROOT_DIR/Docs/ai-screenshots"

# --- Argument parsing ---
SCENE=""
DEVICE="iPhone 16 Pro"
RUN_ALL=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scene)    SCENE="$2"; shift 2 ;;
    --device)   DEVICE="$2"; shift 2 ;;
    --all)      RUN_ALL=true; shift ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

if [[ "$RUN_ALL" == false && -z "$SCENE" ]]; then
  echo "Usage: Tools/CaptureScene.sh --scene <name> | --all [--device <simulator name>]" >&2
  echo "" >&2
  echo "Available scenes:" >&2
  printf "  %s\n" "${ALL_SCENES[@]}" >&2
  exit 1
fi

# --- Simulator boot ---
boot_if_needed() {
  local name="$1"
  local udid
  udid="$(xcrun simctl list devices available | awk -F '[()]' "/$name/{print \$2; exit}")"
  if [[ -z "$udid" ]]; then
    echo "Simulator not found: $name" >&2
    echo "Run: xcrun simctl list devices available" >&2
    exit 1
  fi
  xcrun simctl boot "$udid" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  echo "$udid"
}

# --- Run tests ---
run_tests() {
  local udid="$1"
  local only_testing_flag=()
  if [[ "$RUN_ALL" == false ]]; then
    only_testing_flag=("-only-testing" "$(scene_to_test "$SCENE")")
  fi

  rm -rf "$RESULT_BUNDLE"
  mkdir -p "$(dirname "$RESULT_BUNDLE")"

  echo "Building and running tests on: $DEVICE ($udid)"
  xcodebuild test \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "id=$udid" \
    -resultBundlePath "$RESULT_BUNDLE" \
    CODE_SIGNING_ALLOWED=NO \
    "${only_testing_flag[@]}" \
    2>&1 | grep -E "(Test|error:|warning:|Build)" | grep -v "^$" || true

  # xcodebuild exits non-zero when tests fail; we tolerate that because some
  # scenes may fail setup assertions yet still produce an attachment.
  # Re-check that the bundle was actually written.
  if [[ ! -d "$RESULT_BUNDLE" ]]; then
    echo "No result bundle produced — build likely failed." >&2
    exit 1
  fi
}

# --- Extract attachments ---
# manifest.json structure (xcresulttool export attachments output):
#   [ { "testIdentifier": "ClassName/method()",
#       "attachments": [
#         { "exportedFileName": "UUID.png",
#           "suggestedHumanReadableName": "scene-id_N_UUID.png" }
#       ]
#     } ... ]
# The scene ID is derived from suggestedHumanReadableName by stripping
# the trailing _<index>_<UUID>.png suffix via regex.
extract_attachments() {
  rm -rf "$ATTACH_TMP"
  mkdir -p "$ATTACH_TMP"
  mkdir -p "$OUT_DIR"

  xcrun xcresulttool export attachments \
    --path "$RESULT_BUNDLE" \
    --output-path "$ATTACH_TMP" 2>/dev/null || {
    echo "No attachments found in result bundle." >&2
    exit 1
  }

  local manifest="$ATTACH_TMP/manifest.json"
  if [[ ! -f "$manifest" ]]; then
    echo "manifest.json not found in extracted attachments." >&2
    exit 1
  fi

  # Single Python3 call: parse manifest, rename/copy files, print output paths.
  python3 << PYEOF
import json, os, re, shutil

manifest_path = "$manifest"
attach_dir    = "$ATTACH_TMP"
out_dir       = "$OUT_DIR"

with open(manifest_path) as f:
    data = json.load(f)

# suggestedHumanReadableName format: "<scene-id>_<N>_<UUID>.png"
# UUID = 8-4-4-4-12 hex chars separated by hyphens (no underscores).
uuid_suffix = re.compile(r"_\d+_[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\.png\$")

copied = 0
for test in data:
    for a in test.get("attachments", []):
        if a.get("isAssociatedWithFailure", False):
            continue
        exported  = a.get("exportedFileName", "")
        suggested = a.get("suggestedHumanReadableName", "")
        if not exported or not suggested:
            continue
        scene_id = uuid_suffix.sub("", suggested)
        if not scene_id or scene_id == suggested:
            # Fallback: drop last two underscore-separated tokens
            parts = suggested.replace(".png", "").split("_")
            scene_id = "_".join(parts[:-2]) if len(parts) > 2 else suggested.replace(".png", "")
        src = os.path.join(attach_dir, exported)
        dst = os.path.join(out_dir, scene_id + ".png")
        if os.path.isfile(src):
            shutil.copy2(src, dst)
            print(dst)
            copied += 1

print("---")
print(str(copied) + " screenshot(s) written to: " + out_dir)
PYEOF

  rm -rf "$ATTACH_TMP"
  rm -rf "$RESULT_BUNDLE"
}

# --- Main ---
echo "Booting simulator: $DEVICE"
UDID="$(boot_if_needed "$DEVICE")"

run_tests "$UDID"
extract_attachments
