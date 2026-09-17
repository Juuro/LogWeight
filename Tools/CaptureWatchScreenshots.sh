#!/usr/bin/env bash
# Captures Apple Watch App Store screenshots for LogWeight: Entry + History,
# on Apple Watch Series 11, in each required locale.
#
# Usage:
#   bash Tools/CaptureWatchScreenshots.sh
#
# Output: Docs/store-screenshots/<locale>/watch-series-11/<scene>.png
#
# Locale is set via `xcodebuild test -testLanguage -testRegion`, same
# mechanism as Tools/CaptureStoreScreenshots.sh (env vars don't cross into
# the simulator-hosted XCTest process, so this is the only reliable way).

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PROJECT="$ROOT_DIR/LogWeight.xcodeproj"
SCHEME="LogWeightWatchScreenshots"
OUT_ROOT="$ROOT_DIR/Docs/store-screenshots"
OUT_KEY="watch-series-11"

DEVICE_NAME="Apple Watch Series 11 (46mm)"

# All scene ids the watch test target produces — see App/WatchScreenshots/.
ALL_SCENES=(
  watch-entry-default
  watch-history-default
)

# Locales to capture: language code -> region code. Each must have an
# App/Shared/Resources/<language>.lproj.
LOCALE_LANGUAGES=("en" "de")
LOCALE_REGIONS=("US" "DE")

boot_if_needed() {
  local name="$1"
  local udid
  udid="$(xcrun simctl list devices available | grep -F "$name (" | grep -oE '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}' | head -1)"
  if [[ -z "$udid" ]]; then
    echo "Simulator not found: $name" >&2
    echo "Run: xcrun simctl list devices available" >&2
    exit 1
  fi
  xcrun simctl boot "$udid" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  echo "$udid"
}

run_all_scenes() {
  local udid="$1"
  local result_bundle="$2"
  local language="$3"
  local region="$4"

  rm -rf "$result_bundle"
  mkdir -p "$(dirname "$result_bundle")"

  xcodebuild test \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "id=$udid" \
    -resultBundlePath "$result_bundle" \
    -testLanguage "$language" \
    -testRegion "$region" \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | grep -E "(Test|error:|warning:|Build)" | grep -v "^$" || true

  if [[ ! -d "$result_bundle" ]]; then
    echo "No result bundle produced — build likely failed." >&2
    exit 1
  fi
}

extract_attachments() {
  local result_bundle="$1"
  local attach_tmp="$2"
  local out_dir="$3"

  rm -rf "$attach_tmp"
  mkdir -p "$attach_tmp"
  mkdir -p "$out_dir"

  xcrun xcresulttool export attachments \
    --path "$result_bundle" \
    --output-path "$attach_tmp" 2>/dev/null || {
    echo "No attachments found in result bundle." >&2
    exit 1
  }

  local manifest="$attach_tmp/manifest.json"
  if [[ ! -f "$manifest" ]]; then
    echo "manifest.json not found in extracted attachments." >&2
    exit 1
  fi

  local known_scenes
  known_scenes="$(IFS=,; echo "${ALL_SCENES[*]}")"

  python3 << PYEOF
import json, os, re, shutil

manifest_path = "$manifest"
attach_dir    = "$attach_tmp"
out_dir       = "$out_dir"
known_scenes  = set("$known_scenes".split(","))

with open(manifest_path) as f:
    data = json.load(f)

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
            parts = suggested.replace(".png", "").split("_")
            scene_id = "_".join(parts[:-2]) if len(parts) > 2 else suggested.replace(".png", "")
        if scene_id not in known_scenes:
            continue
        src = os.path.join(attach_dir, exported)
        dst = os.path.join(out_dir, scene_id + ".png")
        if os.path.isfile(src):
            shutil.copy2(src, dst)
            print(dst)
            copied += 1

print(str(copied) + " screenshot(s) written to: " + out_dir)
PYEOF

  rm -rf "$attach_tmp"
  rm -rf "$result_bundle"
}

echo "Apple Watch screenshot set: ${#LOCALE_LANGUAGES[@]} locale(s), ${#ALL_SCENES[@]} scene(s)."

for l in "${!LOCALE_LANGUAGES[@]}"; do
  language="${LOCALE_LANGUAGES[$l]}"
  region="${LOCALE_REGIONS[$l]}"
  out_dir="$OUT_ROOT/$language/$OUT_KEY"
  result_bundle="$ROOT_DIR/tmp/watch-screenshots-$language.xcresult"
  attach_tmp="$ROOT_DIR/tmp/watch-screenshots-$language-attachments"

  echo ""
  echo "=== $DEVICE_NAME [$language-$region] ==="
  udid="$(boot_if_needed "$DEVICE_NAME")"
  run_all_scenes "$udid" "$result_bundle" "$language" "$region"
  extract_attachments "$result_bundle" "$attach_tmp" "$out_dir"
done

echo ""
echo "Apple Watch screenshot set written to: $OUT_ROOT/<locale>/$OUT_KEY"
