#!/usr/bin/env bash
set -euo pipefail

# Captures baseline App Store screenshots for LogWeight on iPhone/iPad.
# Usage:
#   bash Tools/CaptureStoreScreenshots.sh

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/Docs/store-screenshots"
SCHEME="LogWeight"
PROJECT="$ROOT_DIR/LogWeight.xcodeproj"

mkdir -p "$OUT_DIR"

boot_if_needed() {
  local name="$1"
  local udid
  udid="$(xcrun simctl list devices available | awk -F '[()]' "/$name/{print \$2; exit}")"
  if [[ -z "$udid" ]]; then
    echo "Simulator not found: $name" >&2
    exit 1
  fi
  xcrun simctl boot "$udid" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$udid" -b
  echo "$udid"
}

capture() {
  local name="$1"
  local filename="$2"
  local udid
  udid="$(boot_if_needed "$name")"

  xcodebuild build \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "id=$udid" \
    -configuration Debug \
    CODE_SIGNING_ALLOWED=NO >/dev/null

  xcrun simctl launch "$udid" de.juuronina.logweight --use-in-memory-store >/dev/null
  sleep 2
  xcrun simctl io "$udid" screenshot "$OUT_DIR/$filename"
}

capture "iPhone 17 Pro Max" "iphone-6.9-entry.png"
capture "iPhone 17" "iphone-6.1-entry.png"
capture "iPad Pro 13-inch (M4)" "ipad-13-entry.png"

echo "Screenshots written to: $OUT_DIR"
