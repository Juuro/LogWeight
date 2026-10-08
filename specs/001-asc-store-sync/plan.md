# Implementation Plan: App Store Connect Release Sync

**Branch**: `001-asc-store-sync` (spec directory; implementation lands on the maintainer's chosen branch) | **Date**: 2026-10-07 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-asc-store-sync/spec.md`

## Summary

One repeatable, preview-first command line tool, `Tools/asc-release.py`, takes a release from a clean checkout to "version has build, screenshots and texts". It talks to the App Store Connect REST API with the key in `.env`, and drives `xcodebuild` for the archive and upload. Unchanged content is detected by comparing local files and texts against what the store reports (MD5 checksums for screenshots, field-by-field comparison for texts), so every run converges to the same state and a re-run after a failure resumes safely. Order comes from numeric file name prefixes. Local locale and device folders are renamed to the exact store identifiers so no mapping layer is needed at run time. The screenshot set is fixed per device (spec User Story 7); the tool validates folders against it. Capturing screenshots is out of scope: existing images are only moved into the required layout once.

## Technical Context

**Language/Version**: Python 3.11 (stdlib `urllib`, `hashlib`, `argparse`, `unittest`) plus `PyJWT` + `cryptography` for ES256 tokens (both already installed on the maintainer's Mac; documented as prerequisites). Shell only for thin wrappers.

**Primary Dependencies**: App Store Connect API v1 (JWT, 20 min max token life); `xcodebuild archive` and `xcodebuild -exportArchive` (Xcode 27.1) with `-authenticationKeyPath/-authenticationKeyID/-authenticationKeyIssuerID` and `-allowProvisioningUpdates`.

**Storage**: Files only. No local database or state file: the store listing is the single comparison baseline (checksums reported by the store). `.env` for credentials (git-ignored). Build products under `tmp/` (already git-ignored; verify).

**Testing**: `python3 -m unittest` for pure logic (text parsing, locale/device mapping, ordering, diff planning, validation, version/build resolution) with a fake API client; manual `--apply` on a real version for end-to-end; quickstart.md scenarios.

**Target Platform**: macOS developer machine (the build step needs Xcode and signing); listing sync is OS-independent.

**Project Type**: single-repo developer tooling (CLI) beside existing `Tools/` scripts.

**Performance Goals**: Full no-change run (13 locales, ~5 groups) finishes in well under 2 minutes; only checksum/metadata requests, no image transfer.

**Constraints**: Preview is the default; writes require `--apply`. Secrets never printed. Idempotent, resumable. Must not submit for review. Must not edit `project.yml`, `Config/Version.xcconfig`, or create commits.

**Scale/Scope**: 13 locales × 5 device groups with a fixed set (iPhone 3, iPad 3, Duo outer 3, Duo inner 5, Watch 2 = 16 images per locale, 208 total), 4 text fields × 13 locales.

## Constitution Check

*GATE: passes before Phase 0; re-checked after Phase 1 design.*

| Principle | Result |
|---|---|
| I. Apple Health only source of truth | N/A. No weight data touched. |
| II. Privacy and health-data protection | Pass. Only marketing assets and store copy leave the machine; no user or health data. Credentials stay in git-ignored `.env`, never logged. No analytics or third-party SDKs added. `docs/Privacy.md` unaffected. |
| III. Shared core, platform-local UI | N/A. No app code changed. Tooling lives under `Tools/`. |
| IV. Testable by construction | Pass with note: Swift `swift test` does not apply; logic is covered by Python unit tests with a fake API client (no network). |
| V. Accessible, localized UX | Pass. Store texts for all 11 app locales plus en-GB/en-CA get synced; `Tools/check-localizations.sh` unaffected. |
| VI. Reproducible project, disciplined change | Pass. No `.xcodeproj` edits, no manual version bumps (FR-021); Conventional Commits for the work. |

Post-design re-check: unchanged. No violations, so Complexity Tracking stays empty.

## Project Structure

### Documentation (this feature)

```text
specs/001-asc-store-sync/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── cli.md              # commands, flags, exit codes, output
│   └── local-content.md    # on-disk screenshot layout, text document format, locale map
└── tasks.md                # created by /speckit-tasks
```

### Source Code (repository root)

```text
Tools/
├── asc-release.py              # entry point (argparse subcommands)
└── asc/
    ├── __init__.py
    ├── config.py               # .env loading (no printing), version/build resolution
    ├── api.py                  # JWT, HTTP, pagination, retry/backoff
    ├── locales.py              # store locale ids, doc-heading aliases, device-folder to display type
    ├── texts.py                # parse docs/AppStoreMetadata*.md, validate limits
    ├── screenshots.py          # scan local set, validate, plan, upload, reorder
    ├── versions.py             # find/create version, editability, attach build
    ├── build.py                # archive, export+upload, wait for processing
    └── plan.py                 # shared Action model + preview/apply reporting
Tools/asc/tests/                # unittest, fake API client
Tools/asc/ExportOptions.plist   # app-store-connect method, upload destination
docs/store-screenshots/<store-locale>/<device>/NN-name.png   # renamed folders and files, fixed set per device
docs/BuildAndDeploy.md, docs/AIScreenshotWorkflow.md, docs/AppStoreReleaseChecklist.md  # updated
```

**Structure Decision**: Python package under `Tools/asc/` with one entry script. Existing Tools are shell with embedded Python; this feature has real API logic and tests, so a small package is clearer than more embedded heredocs. No app target or Core package change.

## Complexity Tracking

No violations to justify.
