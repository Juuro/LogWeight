#!/bin/sh
# Prints the build number (CFBundleVersion) for the current commit.
#
#   BUILD_NUMBER=<n>  wins when set (explicit override, e.g. CI)
#   otherwise         number of commits reachable from HEAD (rises with every merge to main,
#                     identical for the same commit, so a release re-run is repeatable)
#
# Nothing is stored in git, so no bot has to push to the protected main branch.
# Exits 1 (printing nothing) in a shallow clone or outside git: the commit count would be wrong.
set -eu

ROOT="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"

if [ -n "${BUILD_NUMBER:-}" ]; then
  case "$BUILD_NUMBER" in *[!0-9]*) echo "build-number: BUILD_NUMBER must be a positive integer" >&2; exit 1 ;; esac
  printf '%s\n' "$BUILD_NUMBER"
  exit 0
fi

if [ "$(git -C "$ROOT" rev-parse --is-shallow-repository 2>/dev/null || echo true)" != "false" ]; then
  echo "build-number: shallow or non-git checkout, cannot count commits" >&2
  exit 1
fi

git -C "$ROOT" rev-list --count HEAD
