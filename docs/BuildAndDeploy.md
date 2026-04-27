# Build and Deploy

## Prerequisites

- macOS 14 (Sonoma) or newer
- Xcode 15 or newer
- Swift 5.9 or newer (bundled with Xcode)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`

## Cloning and first build

```bash
git clone <repo-url>
cd LogWeight
xcodegen generate
open LogWeight.xcodeproj
```

The `.xcodeproj` is **always** generated from `project.yml`. **Do not edit the generated `.xcodeproj` directly** — your changes will be overwritten the next time anyone runs `xcodegen generate`. To change the project structure, edit `project.yml` and re-run.

## Running tests

### Core unit tests (no Xcode required)

```bash
cd Packages/LogWeightCore
swift test
```

### Full iOS build + UI tests

```bash
xcodegen generate
xcodebuild test \
  -scheme LogWeight \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Bundle identifier

The placeholder bundle identifier in Phase 1 is `dev.logweight.LogWeight`. Before TestFlight or App Store submission, change `bundleIdPrefix` in `project.yml` to your real Apple Developer Team prefix and re-run `xcodegen generate`.

## Signing

`project.yml` sets `CODE_SIGN_STYLE: Automatic` with an empty `DEVELOPMENT_TEAM`. After running `xcodegen generate`, open the project in Xcode and select your team in the *Signing & Capabilities* tab. The team setting is per-developer and is intentionally not committed.

## TestFlight

1. Set your real bundle ID prefix and team in `project.yml`.
2. `xcodegen generate`
3. Increment `CURRENT_PROJECT_VERSION` (and `MARKETING_VERSION` for user-facing version bumps).
4. Archive in Xcode (*Product → Archive*).
5. Upload to App Store Connect.
6. Add a privacy policy URL in App Store Connect — see `Docs/Privacy.md` for the canonical statement.

## Continuous Integration

`.github/workflows/ci.yml` runs on every push and PR:

1. `brew install xcodegen`
2. `cd Packages/LogWeightCore && swift test` — Core unit tests.
3. `xcodegen generate`
4. `xcodebuild test -scheme LogWeight -destination 'platform=iOS Simulator,...'` — iOS build + UI smoke.

CI cannot exercise real HealthKit (no entitlements on GitHub-hosted runners). The `--use-in-memory-store` launch argument injects `InMemoryHealthKitStore` for the UI smoke test.
