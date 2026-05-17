# CLAUDE.md

Lean guidance for contributors and coding agents. Keep this file short and
focused on non-obvious conventions.

## Hard Rules

- `project.yml` is the source of truth for project config.
  Never edit `.xcodeproj` directly; regenerate with `xcodegen generate`.
- Do not introduce a separate weight database.
  Apple Health (HealthKit) is the only source of truth.
- All HealthKit access must go through `HealthKitStore` in
  `Packages/LogWeightCore`.
  Do not call `HKHealthStore` directly outside adapter implementations.
- Public Core APIs must avoid HealthKit framework types.
  Keep protocol-facing APIs Foundation-friendly and testable.
- Use `SecurityLog` for instrumentation only.
  Never log health values (weights, dates, free-form payloads).
- Keep watchOS compatibility in mind.
  `App/Shared` is reused across platforms; avoid UI APIs unsupported on watchOS.
- Watch/iOS WidgetKit extensions must apply `.containerBackground(..., for: .widget)`
  on every widget configuration. Without it, physical devices show a system placeholder
  (“Please adopt containerBackground API”) instead of your UI; the simulator may still
  look fine. Do not remove it to tweak accent colors—adjust `widgetAccentable` instead.

## Architectural Conventions

- Shared business logic belongs in `Packages/LogWeightCore`.
- UI stays platform-local under `App/iOS`, `App/Watch`, with
  shared SwiftUI views in `App/Shared`.
- Use MV style with `@Observable` state objects near features.
  Do not create a separate ViewModel layer unless explicitly requested.
- For tests and previews, inject `InMemoryHealthKitStore` rather than mocking
  `HKHealthStore`.
- `HealthKitStore.observeChanges()` streams must stop producer work when
  consumer tasks are cancelled (avoid observer leaks).

## UX and Product Gotchas

- Entry flow is stepper-first; keyboard entry is secondary.
- On iOS, Save must remain disabled while keyboard is presented to avoid
  occlusion-related mistakes.
- History chart is additive on iOS/iPadOS; watchOS remains list-only.
  Do not regress list readability or auditability.

## Build and Validation Commands

```bash
# Regenerate project after project.yml changes
xcodegen generate

# Core package tests (fast, entitlement-free)
cd Packages/LogWeightCore && swift test

# iOS build + UI tests
xcodebuild test -scheme LogWeight -destination 'platform=iOS Simulator,name=iPhone 15'

# Platform compile check
xcodebuild build -scheme LogWeightWatch -destination 'generic/platform=watchOS Simulator' CODE_SIGNING_ALLOWED=NO
```

## Screenshot Workflow (UI Changes)

After UI changes, capture simulator evidence:

```bash
Tools/CaptureScene.sh --scene entry-default
Tools/CaptureScene.sh --scene history-with-chart-30d
Tools/CaptureScene.sh --scene settings-default
# or all scenes
Tools/CaptureScene.sh --all
```

- Screenshot runner target: `App/iOSScreenshots`.
- Scene docs: `Docs/AIScreenshotWorkflow.md`.

## Commit Message Convention

Conventional Commits are enforced by a pre-commit hook:

```text
<type>(<scope>): <subject>
```

- Preferred types: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `perf`.
- Subject style: imperative, lowercase start, no trailing period.

## High-Value References

- `Docs/Architecture.md` (ADR rationale)
- `Docs/Privacy.md` (GDPR/health-data constraints)
- `Docs/HealthKitAvailability.md` (platform capabilities)
- `Docs/AIScreenshotWorkflow.md` (scene catalog and usage)
