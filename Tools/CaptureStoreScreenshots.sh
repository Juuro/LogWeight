#!/usr/bin/env bash
# Captures a full App Store screenshot set for LogWeight: every scene from
# Tools/screenshot-scenes.sh, captured on each required App Store device
# size, in each required locale. Reuses the same LogWeightScreenshots
# XCUITest target as Tools/CaptureScene.sh, just run once per device+locale
# instead of once per scene.
#
# Usage:
#   bash Tools/CaptureStoreScreenshots.sh
#
# Output: Docs/store-screenshots/<locale>/<device-key>/<scene>.png
#
# Locale is set via `xcodebuild test -testLanguage -testRegion`, which boots
# the simulator with that system language/region for the whole test run.
# (A SCREENSHOT_LOCALE env var doesn't work here: env vars set by the calling
# shell don't cross into the simulator-hosted XCTest process.)
#
# Note: Apple caps uploads at 10 screenshots per device size. STORE_SCENES
# below is a curated subset (currently 3) of ALL_SCENES in
# screenshot-scenes.sh — stay under 10 if it grows.
#
# Always captured in light mode (forced per-device below) — that's the
# storefront's chosen presentation, independent of whatever appearance a
# given simulator happens to be left in.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

CONFIG_FILE="$(dirname "${BASH_SOURCE[0]}")/screenshot-scenes.sh"
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Missing config: $CONFIG_FILE" >&2
  exit 1
fi
# shellcheck source=Tools/screenshot-scenes.sh
source "$CONFIG_FILE"

PROJECT="${XCODEPROJ}"
SCHEME="${SCREENSHOT_SCHEME}"
OUT_ROOT="$ROOT_DIR/Docs/store-screenshots"

# App Store required device sizes: simulator name -> output key.
STORE_DEVICE_NAMES=("iPhone 14 Plus" "iPad Pro 13-inch (M4)")
STORE_DEVICE_KEYS=("iphone-6.5" "ipad-13")

# Scenes captured for the store set — a curated subset of ALL_SCENES, not the
# full ten (App Store screenshots don't need every scene, just the ones that
# sell best on the listing).
STORE_SCENES=(entry-after-plus-ten history-90d-plateau settings-default)

# App Store locales to capture: language code -> region code, one pair per
# locale in docs/AppStoreMetadata.localized.md. Each must have an
# App/Shared/Resources/<language>.lproj.
LOCALE_LANGUAGES=("de" "fr" "es" "it" "pt-BR" "ja" "ko" "zh-Hans" "zh-Hant" "nl")
LOCALE_REGIONS=("DE" "FR" "ES" "IT" "BR" "JP" "KR" "CN" "TW" "NL")

boot_if_needed() {
  local name="$1"
  local udid
  # grep -F for the literal name (device names like "iPad Pro 13-inch (M4)"
  # contain parentheses that would otherwise be parsed as regex groups),
  # then pull out the UDID by shape rather than by position.
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

  local only_testing_flags=()
  for scene in "${STORE_SCENES[@]}"; do
    only_testing_flags+=("-only-testing" "$(scene_to_test "$scene")")
  done

  xcodebuild test \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "id=$udid" \
    -resultBundlePath "$result_bundle" \
    -testLanguage "$language" \
    -testRegion "$region" \
    CODE_SIGNING_ALLOWED=NO \
    "${only_testing_flags[@]}" \
    2>&1 | grep -E "(Test|error:|warning:|Build)" | grep -v "^$" || true

  # xcodebuild exits non-zero when any scene test fails; tolerated here
  # since other scenes in the same run may still have produced attachments.
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

  # Whitelist by known scene id — xcodebuild also auto-attaches failure
  # diagnostics (UI Snapshot, Screen Recording, Synthesized Event, Debug
  # description, App UI hierarchy) whose "isAssociatedWithFailure" flag is
  # not reliably set, so filtering on that alone lets them leak through.
  local known_scenes
  known_scenes="$(IFS=,; echo "${STORE_SCENES[*]}")"

  python3 << PYEOF
import json, os, re, shutil

manifest_path = "$manifest"
attach_dir    = "$attach_tmp"
out_dir       = "$out_dir"
known_scenes  = set("$known_scenes".split(","))

with open(manifest_path) as f:
    data = json.load(f)

# suggestedHumanReadableName format: "<scene-id>_<N>_<UUID>.png"
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

echo "Full App Store screenshot set: ${#STORE_DEVICE_NAMES[@]} device size(s) x ${#LOCALE_LANGUAGES[@]} locale(s) x ${#STORE_SCENES[@]} scene(s)."

for l in "${!LOCALE_LANGUAGES[@]}"; do
  language="${LOCALE_LANGUAGES[$l]}"
  region="${LOCALE_REGIONS[$l]}"

  for i in "${!STORE_DEVICE_NAMES[@]}"; do
    device="${STORE_DEVICE_NAMES[$i]}"
    key="${STORE_DEVICE_KEYS[$i]}"
    out_dir="$OUT_ROOT/$language/$key"
    result_bundle="$ROOT_DIR/tmp/store-screenshots-$language-$key.xcresult"
    attach_tmp="$ROOT_DIR/tmp/store-screenshots-$language-$key-attachments"

    echo ""
    echo "=== $device ($key) [$language-$region] ==="
    udid="$(boot_if_needed "$device")"
    # App Store screenshots are always captured in light mode — set explicitly
    # rather than relying on whatever appearance the simulator happened to be
    # left in (that state is per-simulator and doesn't travel with this repo).
    xcrun simctl ui "$udid" appearance light
    run_all_scenes "$udid" "$result_bundle" "$language" "$region"
    extract_attachments "$result_bundle" "$attach_tmp" "$out_dir"
  done
done

echo ""
echo "Full App Store screenshot set written to: $OUT_ROOT"
