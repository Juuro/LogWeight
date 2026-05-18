#!/usr/bin/env bash
# Download an Apple simulator platform only when no matching runtime is installed.
set -euo pipefail

PLATFORM="${1:?Usage: ensure-simulator-platform.sh iOS|watchOS}"
# Scheme arg kept for workflow call sites; destination checks proved unreliable for embedded targets.
_SCHEME="${2:-}"

case "$PLATFORM" in
  iOS)
    RUNTIME_GREP='^iOS '
    ;;
  watchOS)
    RUNTIME_GREP='^watchOS '
    ;;
  *)
    echo "Unknown platform: $PLATFORM (expected iOS or watchOS)" >&2
    exit 1
    ;;
esac

if xcrun simctl list runtimes available 2>/dev/null | grep -qE "$RUNTIME_GREP"; then
  echo "$PLATFORM simulator runtime already installed; skipping download."
  exit 0
fi

echo "No available $PLATFORM simulator runtime; downloading platform..."
if ! xcodebuild -downloadPlatform "$PLATFORM"; then
  echo "xcodebuild -downloadPlatform $PLATFORM failed." >&2
  exit 1
fi

if xcrun simctl list runtimes available 2>/dev/null | grep -qE "$RUNTIME_GREP"; then
  echo "$PLATFORM simulator runtime ready after download."
  exit 0
fi

echo "No available $PLATFORM simulator runtime after download." >&2
exit 1
