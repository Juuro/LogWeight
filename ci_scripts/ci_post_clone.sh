#!/bin/sh
set -eu

# Xcode Cloud clones without LogWeight.xcodeproj (gitignored; project.yml is canonical).
# Generate the project before dependency resolution / archive (see ADR-005, .github/workflows/ci.yml).
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "Installing XcodeGen via Homebrew…"
  brew install xcodegen
fi

xcodegen generate
