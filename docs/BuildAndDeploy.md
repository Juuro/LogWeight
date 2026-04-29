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

Phase 4 expands iOS UI coverage beyond the original smoke test. Current UI suite checks:

- stepper-primary save flow,
- keyboard-disabled Save behavior (DA1 guard),
- history trend chart presence,
- settings control reachability,
- large Dynamic Type (`Accessibility XXXL`) save path.

## App icons (iOS, iPad, watchOS, macOS)

Icons live in Asset Catalogs and are generated from a small Swift tool (no extra dependencies beyond macOS + Xcode):

- `App/iOS/Resources/Assets.xcassets/AppIcon.appiconset/` — iPhone + iPad + App Store marketing sizes.
- `App/Watch/Resources/Assets.xcassets/AppIcon.appiconset/` — watch roles + `watch-marketing` 1024×1024.
- `App/macOS/Resources/Assets.xcassets/AppIcon.appiconset/` — macOS icon slots (1×/2×).

Regenerate after changing colours or the symbol in `Tools/GenerateAppIcons.swift`:

```bash
swift Tools/GenerateAppIcons.swift
xcodegen generate
```

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

### watchOS build (Phase 2)

The **`LogWeightWatch`** scheme builds the Watch app and its WidgetKit extension without requiring a paired iPhone simulator destination:

```bash
xcodegen generate
xcodebuild build \
  -project LogWeight.xcodeproj \
  -scheme LogWeightWatch \
  -destination 'generic/platform=watchOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
```

To run on a paired simulator, choose the **LogWeightWatchApp** run destination in Xcode after opening the generated project. On a physical Watch, install via the iOS app’s Watch companion flow once signing is configured for both targets.

### macOS build (Phase 3)

Use the **`LogWeightMac`** scheme. The app is a menu-bar utility (`LSUIElement`); after launch, choose the **scalemass** item in the menu bar. HealthKit prompts the first time you save.

```bash
xcodegen generate
xcodebuild build \
  -project LogWeight.xcodeproj \
  -scheme LogWeightMac \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
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
7. Fill App Store listing fields from `Docs/AppStoreMetadata.md`.
8. Use localized listing variants from `Docs/AppStoreMetadata.localized.md`.

## Store screenshots (Phase 4)

Baseline simulator captures:

```bash
bash Tools/CaptureStoreScreenshots.sh
```

Output folder: `Docs/store-screenshots/`

## Continuous Integration

`.github/workflows/ci.yml` runs on every push and PR:

1. `brew install xcodegen`
2. `cd Packages/LogWeightCore && swift test` — Core unit tests.
3. `xcodegen generate`
4. `xcodebuild test -scheme LogWeight -destination 'platform=iOS Simulator,...'` — iOS build + UI smoke.
5. `xcodebuild build -scheme LogWeightWatch -destination 'generic/platform=watchOS Simulator' ...` — watchOS app + widget extension compile check.
6. `xcodebuild build -scheme LogWeightMac -destination 'platform=macOS' ...` — macOS menu-bar app compile check.

CI cannot exercise real HealthKit (no entitlements on GitHub-hosted runners). The `--use-in-memory-store` launch argument injects `InMemoryHealthKitStore` for UI tests.
