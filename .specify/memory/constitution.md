# LogWeight Constitution

## Core Principles

### I. Apple Health Is the Only Source of Truth (NON-NEGOTIABLE)

- Weight data MUST live only in Apple Health (HealthKit). A separate weight database, cache-of-record,
  or sync store MUST NOT be introduced.
- All HealthKit access MUST go through `HealthKitStore` in `Packages/LogWeightCore`. `HKHealthStore`
  MUST NOT be called directly outside adapter implementations.
- Public Core APIs MUST NOT expose HealthKit framework types; protocol-facing APIs stay
  Foundation-friendly and testable.
- `HealthKitStore.observeChanges()` streams MUST stop producer work when the consumer task is
  cancelled (no observer leaks).

Rationale: one authoritative store removes sync/conflict bugs and keeps the privacy surface minimal.
(See ADR-003, ADR-004, ADR-008 in `docs/Architecture.md`.)

### II. Privacy & Health-Data Protection (NON-NEGOTIABLE)

- `SecurityLog` is for instrumentation only. Health values (weights, dates, free-form payloads)
  MUST NEVER be logged.
- Features MUST comply with `docs/Privacy.md` (GDPR / health-data constraints). Anything that sends
  user data off-device, adds analytics/tracking, or adds third-party SDKs MUST be flagged in the
  spec and requires a privacy-doc update before release.
- Privacy is enforced by API surface, not convention (ADR-006).

Rationale: weight is special-category health data; a single leak is a legal and trust failure.

### III. Shared Core, Platform-Local UI

- Shared business logic belongs in `Packages/LogWeightCore`. UI stays platform-local under
  `App/iOS` and `App/Watch`; shared SwiftUI views live in `App/Shared`.
- `App/Shared` MUST remain watchOS-compatible (no UI APIs unavailable on watchOS).
- State uses MV with `@Observable` objects near the feature. A separate ViewModel layer MUST NOT be
  introduced unless explicitly requested.
- WidgetKit configurations (iOS and watchOS) MUST apply `.containerBackground(..., for: .widget)`;
  adjust accent via `widgetAccentable`, never by removing the background.

### IV. Testable by Construction

- Tests and previews MUST inject `InMemoryHealthKitStore`; `HKHealthStore` MUST NOT be mocked.
- Core logic ships with `swift test` coverage in `Packages/LogWeightCore` (fast, entitlement-free).
- UI behaviour changes are covered by iOS UI tests where feasible.

### V. Considered, Accessible, Localized UX

- Entry is stepper-first; keyboard entry only after a successful HealthKit read confirms no
  body-mass samples exist. On iOS first entry, Save commits the typed value and dismisses the
  keyboard in one tap.
- The history chart is additive on iOS/iPadOS; watchOS stays list-only. List readability and
  auditability MUST NOT regress.
- UI MUST support Dynamic Type, VoiceOver, and Apple HIG conventions (see `docs/AccessibilityAudit.md`).
- All user-facing strings MUST exist in every locale of
  `App/Shared/Resources/<locale>.lproj/Localizable.strings` (en, de, fr, es, it, nl, pt-BR, ja, ko,
  zh-Hans, zh-Hant); `Tools/check-localizations.sh` MUST pass.

### VI. Reproducible Project & Disciplined Change

- `project.yml` is the source of truth for project config. `.xcodeproj` MUST NOT be edited by hand;
  regenerate with `xcodegen generate`.
- Commits MUST follow Conventional Commits (`<type>(<scope>): <subject>`); release-please drives
  versions. `MARKETING_VERSION` and the build number MUST NOT be bumped by hand.

## Quality Gates

A change is ready only when, as applicable:

- `cd Packages/LogWeightCore && swift test` passes.
- iOS build + UI tests pass (`xcodebuild test -scheme LogWeight ...`).
- watchOS compile check passes (`xcodebuild build -scheme LogWeightWatch ...`).
- UI changes include simulator evidence via `Tools/CaptureScene.sh` (relevant scenes, or `--all`).
- `Tools/check-localizations.sh` passes.

## Development Workflow

- New features go through spec-kit: `/speckit-specify` → `/speckit-plan` → `/speckit-tasks` →
  `/speckit-implement`. Plans MUST include a Constitution Check against the principles above.
- Decisions with consequences beyond one feature are recorded as a new `ADR-NNN` section in
  `docs/Architecture.md`; ordinary feature detail belongs in the spec.

## Governance

This constitution supersedes ad-hoc practice. Amendments require a PR that updates this file, bumps
the version (MAJOR: principle removed/redefined; MINOR: principle or section added/expanded; PATCH:
wording), and updates `CLAUDE.md` if its Hard Rules are affected. Reviews MUST check compliance;
violations require explicit, documented justification in the plan's Complexity Tracking.

**Version**: 1.0.0 | **Ratified**: 2026-10-07 | **Last Amended**: 2026-10-07
