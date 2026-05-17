#!/bin/sh
set -eu

# Xcode Cloud runs this script from ci_scripts/; project.yml lives at the repo root.
REPO_ROOT="${CI_PRIMARY_REPOSITORY_PATH:-$(CDPATH= cd "$(dirname "$0")/.." && pwd)}"
cd "$REPO_ROOT"

# Xcode Cloud clones without LogWeight.xcodeproj (gitignored; project.yml is canonical).
# Generate the project before dependency resolution / archive (see ADR-005, .github/workflows/ci.yml).
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Installing XcodeGen via Homebrew…"
  brew install xcodegen
fi

xcodegen generate
