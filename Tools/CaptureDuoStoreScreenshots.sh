#!/usr/bin/env bash
# Captures the iPhone Duo App Store screenshots for every locale.
#
# Per display (outer or inner) this produces 5 screenshots per locale:
#   01-entry-portrait, 02-history-portrait, 03-settings-portrait,
#   04-entry-landscape, 05-history-landscape
# so a full Duo set (outer + inner) is 10 per locale.
#
# Usage (one orientation per run; the simulator must already be in that orientation/pose):
#   bash Tools/CaptureDuoStoreScreenshots.sh --pose outer --orientation portrait
#   bash Tools/CaptureDuoStoreScreenshots.sh --pose outer --orientation landscape
#   bash Tools/CaptureDuoStoreScreenshots.sh --pose inner --orientation portrait   # unfolded
#   bash Tools/CaptureDuoStoreScreenshots.sh --pose outer --orientation portrait --locale de
#
# The iPhone Duo simulator renders on whichever display is active, and there is no CLI
# to fold or unfold it: switch the pose in Device Hub. Rotation is also tied to Device Hub:
# XCUIDevice can rotate to landscape only while the simulator is attached in Device Hub, and
# it cannot rotate back to portrait afterwards, so run all portrait scenes first, then
# (with the Duo open in Device Hub) all landscape scenes. A simulator reboot resets rotation
# to portrait but detaches Device Hub. The script checks the captured size so a wrong pose
# fails loudly, and the portrait scenes fail if the device is not actually upright.
#
# Output: Docs/store-screenshots/<locale>/iphone-duo-<pose>/NN-<view>-<orientation>.png
# Landscape frames come out of the simulator in the display's native portrait buffer and
# are rotated upright here. Always light mode, status bar pinned to 9:41.
#
# Needs an "iPhone Duo" simulator on the iOS 27.1 runtime:
#   xcrun simctl create "iPhone Duo" com.apple.CoreSimulator.SimDeviceType.iPhone-Duo \
#     com.apple.CoreSimulator.SimRuntime.iOS-27-1

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=Tools/screenshot-scenes.sh
source "$(dirname "${BASH_SOURCE[0]}")/screenshot-scenes.sh"

PROJECT="${XCODEPROJ}"
SCHEME="${SCREENSHOT_SCHEME}"
OUT_ROOT="$ROOT_DIR/Docs/store-screenshots"
DEVICE="iPhone Duo"
POSE=""
ORIENTATION=""
ONLY_LOCALE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pose)   POSE="$2"; shift 2 ;;
    --orientation) ORIENTATION="$2"; shift 2 ;;
    --locale) ONLY_LOCALE="$2"; shift 2 ;;
    --device) DEVICE="$2"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

case "$POSE" in
  outer) PORTRAIT_SIZE="1398x2034" ;;
  inner) PORTRAIT_SIZE="2007x2853" ;;
  *) echo "Usage: $0 --pose outer|inner --orientation portrait|landscape [--locale <key>] [--device <name>]" >&2; exit 1 ;;
esac

case "$ORIENTATION" in
  portrait)  RUN_SCENES=(duo-entry-portrait duo-history-portrait duo-settings-portrait) ;;
  landscape) RUN_SCENES=(duo-entry-landscape duo-history-landscape) ;;
  *) echo "Usage: $0 --pose outer|inner --orientation portrait|landscape [--locale <key>] [--device <name>]" >&2; exit 1 ;;
esac

boot_if_needed() {
  local udid
  udid="$(xcrun simctl list devices available | grep -F "$DEVICE (" | grep -oE '[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}' | head -1)"
  if [[ -z "$udid" ]]; then
    echo "Simulator not found: $DEVICE" >&2
    exit 1
  fi
  xcrun simctl boot "$udid" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  echo "$udid"
}

UDID="$(boot_if_needed)"
xcrun simctl ui "$UDID" appearance light
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularMode active --cellularBars 4 --wifiBars 3 >/dev/null 2>&1 || true

capture_locale() {
  local language="$1" region="$2" locale_key="$3"
  local out_dir="$OUT_ROOT/$locale_key/iphone-duo-$POSE"
  local result_bundle="$ROOT_DIR/tmp/duo-$POSE-$locale_key.xcresult"
  local attach_tmp="$ROOT_DIR/tmp/duo-$POSE-$locale_key-attachments"

  rm -rf "$result_bundle" "$attach_tmp"
  mkdir -p "$ROOT_DIR/tmp" "$out_dir"

  local only_testing_flags=()
  for scene in "${RUN_SCENES[@]}"; do
    only_testing_flags+=("-only-testing" "$(scene_to_test "$scene")")
  done

  TEST_RUNNER_SCREENSHOT_DISPLAY="$POSE" xcodebuild test \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "id=$UDID" \
    -resultBundlePath "$result_bundle" \
    -testLanguage "$language" \
    -testRegion "$region" \
    CODE_SIGNING_ALLOWED=NO \
    "${only_testing_flags[@]}" \
    2>&1 | grep -E "(error:|\*\* TEST)" || true

  if [[ ! -d "$result_bundle" ]]; then
    echo "No result bundle produced — build likely failed." >&2
    exit 1
  fi

  xcrun xcresulttool export attachments --path "$result_bundle" --output-path "$attach_tmp" >/dev/null 2>&1

  python3 - "$attach_tmp" "$out_dir" "$PORTRAIT_SIZE" "${RUN_SCENES[*]}" <<'PYEOF'
import json, os, re, sys
from PIL import Image

attach_dir, out_dir, portrait_size, run_scenes = sys.argv[1:5]
run_scenes = run_scenes.split()
pw, ph = (int(v) for v in portrait_size.split("x"))
# XCUIScreen reports the inner display one pixel short (668.67 pt x 3): 2006x2852 instead
# of 2007x2853. Pad the last column/row by edge replication to reach Apple's exact size.
def fit(im):
    if im.size == (pw, ph) or im.size == (ph, pw):
        return im
    if abs(im.size[0] - pw) <= 1 and abs(im.size[1] - ph) <= 1:
        out = Image.new("RGB", (pw, ph))
        out.paste(im, (0, 0))
        if im.size[0] < pw:
            out.paste(im.crop((im.size[0] - 1, 0, im.size[0], im.size[1])), (im.size[0], 0))
        if im.size[1] < ph:
            out.paste(out.crop((0, im.size[1] - 1, pw, im.size[1])), (0, im.size[1]))
        return out
    return im
names = {
    "duo-entry-portrait": "01-entry-portrait",
    "duo-history-portrait": "02-history-portrait",
    "duo-settings-portrait": "03-settings-portrait",
    "duo-entry-landscape": "04-entry-landscape",
    "duo-history-landscape": "05-history-landscape",
}
suffix = re.compile(r"_\d+_[0-9A-Fa-f-]{36}\.png$")
with open(os.path.join(attach_dir, "manifest.json")) as f:
    data = json.load(f)

done = set()
for test in data:
    for a in test.get("attachments", []):
        if a.get("isAssociatedWithFailure", False):
            continue
        scene = suffix.sub("", a.get("suggestedHumanReadableName", ""))
        if scene not in names:
            continue
        im = fit(Image.open(os.path.join(attach_dir, a["exportedFileName"])).convert("RGB"))
        if scene.endswith("landscape"):
            # Native buffer is portrait with the UI drawn rotated; rotate it upright.
            if im.size != (pw, ph):
                sys.exit(f"{scene}: captured {im.size}, expected {(pw, ph)} — is the {sys.argv[3]} display active?")
            im = im.rotate(-90, expand=True)
            want = (ph, pw)
        else:
            want = (pw, ph)
        if im.size != want:
            sys.exit(f"{scene}: size {im.size}, expected {want} — is the right display active?")
        dst = os.path.join(out_dir, names[scene] + ".png")
        im.save(dst)
        done.add(scene)
        print(dst)

missing = set(run_scenes) - done
if missing:
    sys.exit("Missing scenes: " + ", ".join(sorted(missing)))
PYEOF

  rm -rf "$attach_tmp" "$result_bundle"
}

echo "iPhone Duo ($POSE display, $ORIENTATION): ${#RUN_SCENES[@]} scene(s) x locale(s)."
for l in "${!LOCALE_LANGUAGES[@]}"; do
  [[ -n "$ONLY_LOCALE" && "${LOCALE_KEYS[$l]}" != "$ONLY_LOCALE" ]] && continue
  echo ""
  echo "=== ${LOCALE_KEYS[$l]} (${LOCALE_LANGUAGES[$l]}-${LOCALE_REGIONS[$l]}) ==="
  capture_locale "${LOCALE_LANGUAGES[$l]}" "${LOCALE_REGIONS[$l]}" "${LOCALE_KEYS[$l]}"
done

echo ""
echo "Done. Output: $OUT_ROOT/<locale>/iphone-duo-$POSE/"
