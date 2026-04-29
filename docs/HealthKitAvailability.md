# HealthKit Availability Matrix

Per Apple's documentation as of the Phase 1 cut.

| Platform | HealthKit | Notes |
|---|---|---|
| iOS 17+ | ✅ Yes | Full read/write. Phase 1 target. |
| iPadOS 17+ | ✅ Yes | Same APIs as iOS. Phase 1 reuses iOS view tree. |
| watchOS 10+ | ✅ Yes | Full read/write. **Phase 2:** companion `LogWeightWatchApp` + read-only complication extension query `recentWeights(limit: 1)`. |
| macOS 14+ | ✅ Yes | Native HealthKit support added in macOS 13; we require 14 for `@Observable`. **Phase 3:** menu-bar `LogWeightMac` (sandbox + entitlements). |
| **tvOS** | ❌ **No** | HealthKit is **not** available on tvOS at any version. **LogWeight does not target tvOS.** |
| visionOS | ❓ Unverified | Not in scope for Phase 1–4. |

## Decision: tvOS is out of scope

LogWeight does not ship a tvOS target. The honest reason: there is no useful tvOS UI for a weight-logging app when HealthKit is unavailable on tvOS. Re-litigate this only if Apple ships HealthKit on tvOS.

## Re-validating

This file should be re-checked at every WWDC. Apple historically expands HealthKit platform availability conservatively; do not assume a future SDK lifts these constraints without verifying against the current release notes.
