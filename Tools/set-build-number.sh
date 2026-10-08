#!/bin/sh
# Xcode Run Script phase: writes the git-derived build number into the built Info.plist.
# Runs for Release/archive builds only (Debug keeps the placeholder from Config/Version.xcconfig).
# Works in Xcode (Product > Archive) and xcodebuild alike. Every target runs it, so the app,
# watch app and extensions always share one CFBundleVersion.
set -eu

[ "${CONFIGURATION:-Debug}" = "Debug" ] && exit 0

PLIST="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
[ -f "$PLIST" ] || { echo "error: set-build-number: $PLIST not found" >&2; exit 1; }

if ! number="$("${SRCROOT}/Tools/build-number.sh")"; then
  echo "warning: set-build-number: keeping CURRENT_PROJECT_VERSION=${CURRENT_PROJECT_VERSION:-?} (could not derive a build number)" >&2
  exit 0
fi

/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $number" "$PLIST"
echo "set-build-number: ${PRODUCT_NAME} CFBundleVersion = $number"
