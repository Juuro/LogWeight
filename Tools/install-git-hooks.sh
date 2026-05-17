#!/bin/sh
# Point this clone at versioned hooks in githooks/ (localization parity on commit).
set -eu

ROOT="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "error: not inside a git repository" >&2
  exit 1
fi

git config core.hooksPath githooks
chmod +x githooks/pre-commit githooks/commit-msg
chmod +x Tools/check-localizations.sh Tools/check-commit-message.sh

echo "Installed git hooks via core.hooksPath=githooks"
echo "  - pre-commit:  Tools/check-localizations.sh"
echo "  - commit-msg:  Tools/check-commit-message.sh (Conventional Commits)"
