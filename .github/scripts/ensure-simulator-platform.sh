#!/usr/bin/env bash
# Download an Apple simulator platform only when the active Xcode lacks matching destinations.
set -euo pipefail

PLATFORM="${1:?Usage: ensure-simulator-platform.sh iOS|watchOS}"
SCHEME="${2:?Usage: ensure-simulator-platform.sh <platform> <scheme>}"

case "$PLATFORM" in
  iOS)
    DESTINATION_GREP='platform:iOS Simulator'
    ;;
  watchOS)
    DESTINATION_GREP='platform:watchOS Simulator'
    ;;
  *)
    echo "Unknown platform: $PLATFORM (expected iOS or watchOS)" >&2
    exit 1
    ;;
esac

if xcodebuild -showdestinations \
  -project LogWeight.xcodeproj \
  -scheme "$SCHEME" 2>/dev/null | grep -q "$DESTINATION_GREP"; then
  echo "$PLATFORM Simulator destinations available for scheme $SCHEME; skipping download."
  exit 0
fi

echo "$PLATFORM Simulator destinations missing for scheme $SCHEME; downloading platform..."
xcodebuild -downloadPlatform "$PLATFORM"
