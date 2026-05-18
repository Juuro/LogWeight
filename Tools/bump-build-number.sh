#!/bin/sh
# Increment CURRENT_PROJECT_VERSION in Config/Version.xcconfig.
# Used by .github/workflows/ci.yml after a green CI run.
set -eu

ROOT="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
XCCONFIG="${1:-$ROOT/Config/Version.xcconfig}"

if [ ! -f "$XCCONFIG" ]; then
  echo "error: missing $XCCONFIG" >&2
  exit 1
fi

current="$(awk -F= '/^[[:space:]]*CURRENT_PROJECT_VERSION[[:space:]]*=/ {
  gsub(/[^0-9]/, "", $2);
  if ($2 != "") print $2;
  exit
}' "$XCCONFIG")"

if [ -z "$current" ]; then
  echo "error: could not parse CURRENT_PROJECT_VERSION from $XCCONFIG" >&2
  exit 1
fi

next=$((current + 1))

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

awk -v build="$next" '
  /^[[:space:]]*CURRENT_PROJECT_VERSION[[:space:]]*=/ {
    sub(/=.*/, "= " build);
  }
  { print }
' "$XCCONFIG" > "$tmp"

mv "$tmp" "$XCCONFIG"
trap - EXIT

echo "$next"
