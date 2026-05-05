# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Quick Start: Build and Test

### Prerequisites
- macOS 14+ (Sonoma), Xcode 15+, Swift 5.9+
- Install XcodeGen: `brew install xcodegen`

### First build
```bash
xcodegen generate
open LogWeight.xcodeproj
```

**Important:** The `.xcodeproj` is always generated from `project.yml`. Never edit `.xcodeproj` directly — run `xcodegen generate` after any changes to `project.yml`.

### Core tests (Swift Package, no Xcode required)
```bash
cd Packages/LogWeightCore
swift test
# Run a single test:
swift test --filter TestClass.testMethod
```

### iOS build + UI tests
```bash
xcodegen generate
xcodebuild test -scheme LogWeight -destination 'platform=iOS Simulator,name=iPhone 15'
```

### watchOS build
```bash
xcodebuild build -scheme LogWeightWatch -destination 'generic/platform=watchOS Simulator' CODE_SIGNING_ALLOWED=NO
```

### macOS menu-bar app
```bash
xcodebuild build -scheme LogWeightMac -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
```

### App icons (regenerate after changes to `Tools/GenerateAppIcons.swift`)
```bash
swift Tools/GenerateAppIcons.swift
xcodegen generate
```

## Project Structure

```
LogWeight/
├── project.yml                      # XcodeGen config — source of truth for Xcode project
├── Packages/LogWeightCore/          # Shared SPM: models, HealthKit store, state, formatting
│   ├── Sources/LogWeightCore/       # Public API (no HealthKit types exposed)
│   └── Tests/LogWeightCoreTests/    # Core unit tests
├── App/
│   ├── iOS/                         # iOS app target
│   ├── Watch/                       # watchOS companion app (embedded in iOS distribution)
│   ├── WatchWidget/                 # watchOS WidgetKit complications extension
│   ├── macOS/                       # macOS menu-bar app (LSUIElement, no dock)
│   ├── Shared/                      # SwiftUI views shared across platforms
│   │   ├── HistoryView.swift        # List + optional chart (Phase 4)
│   │   ├── SettingsView.swift       # iOS/macOS settings (excluded from watchOS)
│   │   ├── WatchSettingsView.swift  # watchOS-specific settings
│   │   └── ...
│   └── iOSUITests/                  # iOS UI tests (smoke + accessibility)
├── Docs/
│   ├── Architecture.md              # ADR-001 through ADR-010 decisions
│   ├── BuildAndDeploy.md            # Detailed build, signing, TestFlight, CI setup
│   ├── Privacy.md                   # GDPR Art. 9 health data handling
│   ├── HealthKitAvailability.md     # Platform-specific HealthKit support
│   └── jmat-reports/                # Multi-agent planning archives
└── Tools/GenerateAppIcons.swift     # Icon generation from symbol + color
```

## Architecture & Key Decisions

### ADR-001: Shared SPM, one multiplatform Xcode project
- Business logic lives in `Packages/LogWeightCore/` (shared across iOS, watchOS, macOS)
- Per-platform UI in `App/<Platform>/`
- Watch target compiles `App/Shared` but excludes `SettingsView` (no `.pickerStyle(.segmented)` on watchOS)

### ADR-002: MV pattern with `@Observable`, no separate ViewModel layer
- State classes use `@Observable` and live alongside views (e.g. `EntryState.swift`)
- No `ViewModel` folder, no Combine boilerplate
- Tests inject `HealthKitStore` directly into state classes

### ADR-003: `HealthKitStore` protocol abstracts real HealthKit
- `HealthKitStore` protocol in `LogWeightCore` is the only entry point to HealthKit
- **Production:** `HKHealthStoreAdapter` (real `HKHealthStore`)
- **Tests/Previews:** `InMemoryHealthKitStore` (no entitlements needed)
- Protocol API uses only Foundation types — **no HealthKit types in public API**
- This keeps every code path except actual HK calls testable in CI

### ADR-004: Apple Health is the sole source of truth
- **No separate weight database.** Every read queries `HKHealthStore` directly
- No caching in `UserDefaults`, Keychain, files, or memory beyond entry surface lifetime
- Simplifies sync (HealthKit syncs natively across user's devices)

### ADR-005: XcodeGen for reproducible project
- `project.yml` is the source of truth for all targets, settings, dependencies
- `.xcodeproj` is generated and `.gitignore`d
- CI regenerates on every build to verify consistency

### ADR-006: Privacy enforced by API surface, not convention
- `SecurityLog` only accepts `StaticString` for events and `Int` for codes
- **No overloads for `Double`, `String`, `Date`, or `Weight`** — health values cannot be logged at compile time
- GDPR Art. 9 defence-in-depth: API rejects values instead of relying on developer convention

### ADR-007: Stepper-primary entry, keyboard secondary
- Primary entry path is ± stepper
- Large number is tappable (opens decimal pad)
- Save button **disabled while keyboard is up** — guard against keyboard occlusion on small iPhones
- "Done" button in keyboard toolbar dismisses before Save

### ADR-008: `AsyncStream` from `HKObserverQuery` stops on consumer cancellation
- `HealthKitStore.observeChanges()` returns `AsyncStream<Void>` with explicit producer lifecycle
- Cancelling the consuming `Task` MUST stop the underlying observer (verified by test)
- Prevents memory leaks and silent termination

### ADR-009: History chart is additive (Phase 4)
- Swift Charts trend (`LineMark` + `PointMark`) renders above the list on iOS/iPadOS/macOS
- watchOS remains list-only
- List stays authoritative, auditable view of each sample

### ADR-010: iOS UI tests cover accessibility-critical paths (Phase 4)
- Stepper save, keyboard-Save guard, chart visibility, settings reachability, XXXL Dynamic Type
- Captures common regressions without excessive CI runtime

## Common Development Patterns

### State Management
- **Entry state:** `EntryState.swift` — `@MainActor @Observable` class holding current weight input
- **History queries:** Direct `HealthKitStore.recentWeights()` calls; no separate history state
- **Settings:** `@AppStorage` for simple toggles, `UserDefaults` migrations via `SettingsMigrator`

### Testing
- **Unit tests** live in `Packages/LogWeightCore/Tests/`
- **Inject `InMemoryHealthKitStore`** in tests instead of mocking (`HKHealthStore` is untestable in CI)
- **UI tests** in `App/iOSUITests/` use `--use-in-memory-store` launch argument
- Run tests via `swift test` (Core) or `xcodebuild test` (full iOS suite)

### View Patterns
- **Shared views** (History, Settings) live in `App/Shared/`
- **Platform-specific variants** (e.g., `WatchSettingsView`) live in the platform folder
- **watchOS exclusions:** Configure in `project.yml` via the `excludes` array under `App/Watch`

### HealthKit Integration
- **All queries** go through `HealthKitStore` protocol
- **Public API** uses Foundation types: `Weight`, `Date`, `[HKQuantitySample]` metadata (never `HKHealthStore` directly)
- **Entitlements:** Bundle IDs map to `NSHealthShareUsageDescription` + `NSHealthUpdateUsageDescription` in `Info.plist` files (see `project.yml` for template)

### Gesture Handling
- **Long-press buttons:** `LongPressStepButton` (iOS/watchOS/macOS) wraps `+` and `−` steppers with acceleration
- **Double-tap gestures:** `WatchEntryView` uses `TapGesture` for double-tap on weight display to restore last logged weight
- **Keyboard guards:** Save button state checks `UIResponder` focus stack to prevent occlusion

## Security & Privacy

### Health Data
- Article 9 (GDPR) special-category data — see `Docs/Privacy.md` for lawful basis and data-flow
- No analytics, telemetry, crash reporters, or third-party SDKs
- All data stays on device; HealthKit syncs via iCloud natively

### Logging
- `SecurityLog` in Core is the only logger; use only for instrumentation
- **Never log values:** API design prevents it (`StaticString` only)
- Common events: `"entry:saved"`, `"entry:failed"`, `"history:fetched"`

### Code Signing
- `project.yml` uses `CODE_SIGN_STYLE: Automatic` with empty `DEVELOPMENT_TEAM` (per-developer, not committed)
- After `xcodegen generate`, set your Apple Developer Team in Xcode's *Signing & Capabilities*

## Testing Strategy

### Core tests (CI-enabled, no HealthKit entitlements needed)
- Entry state transitions, HealthKit protocol behavior, formatting logic
- Run in `Packages/LogWeightCore/` via `swift test` or full suite via Xcode

### UI tests (iOS only, Phase 4)
- Stepper-primary save flow, keyboard-disabled Save guard, chart rendering, settings discovery
- Large Dynamic Type (XXXL) accessibility path
- **Use `-use-in-memory-store` launch argument** to inject `InMemoryHealthKitStore`

### Platform-specific compile checks (CI)
- watchOS: `xcodebuild build -scheme LogWeightWatch` (no device required)
- macOS: `xcodebuild build -scheme LogWeightMac` (compile only, HealthKit untestable without entitlements)

## Continuous Integration

`.github/workflows/ci.yml` on every push and PR:
1. `swift test` — Core unit tests in `Packages/LogWeightCore/`
2. `xcodegen generate` — Verify project consistency
3. `xcodebuild test -scheme LogWeight` — iOS build + UI smoke tests (in-memory HealthKit)
4. `xcodebuild build -scheme LogWeightWatch` — watchOS compile check
5. `xcodebuild build -scheme LogWeightMac` — macOS compile check

CI runs with `--use-in-memory-store` to avoid HealthKit entitlement failures on GitHub-hosted runners.

## Deployment

### Versioning
- `MARKETING_VERSION` in `project.yml` is user-facing (e.g., `0.1.1`)
- `CURRENT_PROJECT_VERSION` is internal build count (integer)
- Increment both before TestFlight / App Store submission

### TestFlight / App Store
1. Update bundle ID prefix and team in `project.yml`
2. Run `xcodegen generate`
3. Increment versions
4. Archive in Xcode
5. Upload to App Store Connect
6. Fill metadata from `Docs/AppStoreMetadata.md` and localized variants
7. Add Privacy Policy URL (canonical statement in `Docs/Privacy.md`)

### Store screenshots
```bash
bash Tools/CaptureStoreScreenshots.sh
# Output: Docs/store-screenshots/
```

## Important Files & Their Roles

| File | Purpose |
|------|---------|
| `project.yml` | XcodeGen source of truth; defines all targets, schemes, dependencies |
| `Packages/LogWeightCore/Sources/LogWeightCore/HealthKit/HealthKitStore.swift` | Protocol definition; only entry point to HealthKit |
| `Packages/LogWeightCore/Sources/LogWeightCore/HealthKit/HKHealthStoreAdapter.swift` | Prod adapter (real `HKHealthStore`) |
| `Packages/LogWeightCore/Sources/LogWeightCore/HealthKit/InMemoryHealthKitStore.swift` | Test & preview adapter (no entitlements) |
| `Packages/LogWeightCore/Sources/LogWeightCore/State/EntryState.swift` | Observable state for entry UI |
| `Packages/LogWeightCore/Sources/LogWeightCore/Input/LongPressStepButton.swift` | Reusable stepper with acceleration |
| `App/Shared/HistoryView.swift` | Shared history list + chart (Phase 4) |
| `App/iOS/Views/EntryView.swift` | iOS-specific entry surface |
| `App/Watch/Views/WatchEntryView.swift` | watchOS entry surface (stepper + digital crown) |
| `App/macOS/Views/EntryWindow.swift` | macOS menu-bar entry window |
| `Docs/Architecture.md` | ADRs and design rationale (read before major changes) |
| `Docs/Privacy.md` | GDPR compliance & lawful basis |

## Performance Notes

- **HealthKit queries:** `recentWeights()` queries recent samples; paginate for large histories if needed
- **Observing changes:** `observeChanges()` returns `AsyncStream<Void>` — subscribe in `Task` with cancellation guard
- **UI rendering:** SwiftUI handles History list virtualization; chart rendering delegated to Swift Charts
- **Memory:** No caching beyond view lifetime; HealthKit syncs provide eventual consistency

## Before Making Changes

1. **Read `Docs/Architecture.md`** to understand the ADRs — they document *why*, not just *what*
2. **Check `project.yml`** if modifying targets, schemes, or platform exclusions
3. **Inject `HealthKitStore` protocol**, never reference `HKHealthStore` directly outside Core
4. **Use `SecurityLog` only** for instrumentation; API prevents logging health values
5. **Test against `InMemoryHealthKitStore`** in Core tests; CI uses it for UI tests
6. **Verify `xcodegen generate` consistency** after any `project.yml` changes
7. **Add UI test coverage** if modifying entry flow, keyboard behavior, or accessibility

## Commit Messages: Conventional Commits

All commits must follow [Conventional Commits](https://www.conventionalcommits.org/) format. The format is enforced by a pre-commit hook:

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Type
- `feat` — new feature
- `fix` — bug fix
- `refactor` — code restructuring (no behavior change)
- `test` — add or update tests
- `docs` — documentation changes
- `chore` — build, dependencies, tooling, version bumps
- `style` — code style (formatting, semicolons) — rarely used; prefer `refactor`
- `perf` — performance optimization

### Scope
Optional but encouraged. Examples: `entry-view`, `healthkit`, `watch-app`, `core`, `ui-tests`. Scope clarifies *which* part of the codebase changed.

### Subject
- Imperative mood ("add feature", not "adds feature" or "added feature")
- Lowercase start (unless proper noun)
- No period at end
- ≤50 characters for good git log readability

### Body
Optional. Explain *why*, not *what*. Wrap at ~72 characters.

### Footer
Optional. Reference issues: `Closes #123`, `Fixes #456`, `Related-to #789`

### Examples
```
feat(entry-view): implement double-tap to restore last weight
fix(healthkit): handle observer query cancellation safely
refactor(core): extract timing constants from LongPressStepButton
test(core): add coverage for SettingsMigrator edge cases
docs: update Architecture.md with ADR-011 reasoning
chore: bump Xcode requirement to 15.4
```

### Enforcement
A pre-commit hook validates your commit message format before allowing the commit. If your message doesn't match the pattern, the commit is rejected with an error message showing the expected format.

## Current Phase

**Phase 4 (In Progress):** Swift Charts in history, broader XCUITests, accessibility audit docs, App Store metadata prep.
- History view now includes trend chart (iOS/iPadOS/macOS)
- UI test coverage expanded beyond smoke tests
- Accessibility audit in progress (`Docs/AccessibilityAudit.md`)
- App Store metadata prep (`Docs/AppStoreMetadata.md`, localized variants)

**Next:** Phase 4 completion (release to App Store), then Phase 5 (Lock Screen widget on iOS 16+, if feasible).

## Useful References

- **JMAT Planning:** `docs/jmat-reports/2026-04-27-logweight-multiplatform-plan.md` — Architecture & roadmap synthesis
- **Privacy Manifest:** `Docs/Privacy.md` — GDPR Art. 9 statement, lawful basis, data-flow diagram
- **HealthKit Availability:** `Docs/HealthKitAvailability.md` — Platform-specific HealthKit coverage
- **Recent Changes:** Use `git log --oneline` to track development momentum; recent commits focus on gesture refinement (long-press acceleration, double-tap restore)
