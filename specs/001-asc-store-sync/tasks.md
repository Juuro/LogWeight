---

description: "Task list for App Store Connect Release Sync"
---

# Tasks: App Store Connect Release Sync

**Input**: Design documents from `/specs/001-asc-store-sync/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/cli.md, contracts/local-content.md, quickstart.md

**Tests**: Included. plan.md chose Python `unittest` with a fake API client for all pure logic (no network). Live-store checks are the quickstart scenarios.

**Organization**: Grouped by user story. US7 (fixed screenshot set and layout) comes first among the P1 stories because US1 and US2 consume its layout rules.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: User story the task belongs to (US1 to US7)
- All paths are relative to the repository root (`/Users/juuro/Repos/LogWeight`)
- Never print `.env` values; never run `--apply` against the live store without the maintainer's go-ahead (preview runs are read-only)

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Package skeleton and test harness

- [X] T001 Create package skeleton: `Tools/asc/__init__.py`, empty modules `config.py api.py locales.py texts.py screenshots.py versions.py build.py plan.py`, and `Tools/asc/tests/__init__.py`
- [X] T002 Create the entry script `Tools/asc-release.py` (executable, `#!/usr/bin/env python3`) with `argparse` subcommands `all build screenshots texts status` and common options `--version --apply --locale --device --env --verbose` exactly as in `specs/001-asc-store-sync/contracts/cli.md`; commands may raise "not implemented" for now
- [X] T003 [P] Add a fake API client for tests in `Tools/asc/tests/fake_api.py` (in-memory store of versions, localizations, screenshot sets, screenshots, builds; records every write call so tests can assert "zero writes")
- [X] T004 [P] Confirm `tmp/` and `.env` are git-ignored in `.gitignore` (add `tmp/` only if missing); document prerequisites (`PyJWT`, `cryptography`, Xcode 27.1) at the top of `Tools/asc-release.py`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Config, API access, locale/device tables and the shared action model that every story uses

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T005 [P] Implement `.env` loading in `Tools/asc/config.py`: read `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH` from the environment or the `--env` file (default `.env`), expand `~`, fail with exit code 1 naming only the variable (never the value) when missing or the key file is unreadable (FR-001)
- [X] T006 [P] Implement version and build resolution in `Tools/asc/config.py`: target version from `--version` else `MARKETING_VERSION` parsed from `project.yml`; build number from `CURRENT_PROJECT_VERSION` in `Config/Version.xcconfig`; read-only, never write either file (FR-002, FR-021)
- [X] T007 Implement the API client in `Tools/asc/api.py`: ES256 JWT (PyJWT, `aud` = `appstoreconnect-v1`, lifetime ≤ 20 min, refresh when expired), `urllib` requests, pagination via `links.next`, retry with backoff on 429 and 5xx, request logging that redacts the `Authorization` header and never logs `.env` values (FR-001, SC-006)
- [X] T008 [P] Implement locale and device tables in `Tools/asc/locales.py`: store locale codes `de-DE en-CA en-GB en-US es-ES fr-FR it ja ko nl-NL pt-BR zh-Hans zh-Hant`; doc-heading aliases (`it-IT`→`it`, `ja-JP`→`ja`, `ko-KR`→`ko`, others identity); English locales use the base English text; device folder to display type and pixel sizes per `contracts/local-content.md` (`iphone-6.5`=`APP_IPHONE_65` 1284×2778, `ipad-13`=`APP_IPAD_PRO_3GEN_129` 2064×2752, `watch-series-11`=`APP_WATCH_SERIES_10` 416×496, Duo types marked "to verify" per research R5); and the required screenshot set table (iphone-6.5, ipad-13, iphone-duo-outer: `01-entry 02-history 03-settings`; iphone-duo-inner adds `04-entry-landscape 05-history-landscape`; watch-series-11: `01-entry 02-history`)
- [X] T009 Implement the action model and reporting in `Tools/asc/plan.py`: `Action(kind, locale, target, reason)` with kinds `create_version update_text upload replace delete reorder archive upload_build wait_processing attach_build skip_unchanged`; one function renders the preview (one line per action grouped per locale, summary counts per kind) and the same list is executed with `--apply`; per-locale summary of uploaded/replaced/deleted/reordered/skipped/failed (FR-010, FR-011); exit codes 0/1/2/3/4 as in `contracts/cli.md`
- [X] T010 [P] Unit tests in `Tools/asc/tests/test_config.py`: missing variable names the variable not the value, `~` expansion, version/build parsing from fixture `project.yml` and `Version.xcconfig`
- [X] T011 [P] Unit tests in `Tools/asc/tests/test_plan.py`: preview equals applied action list; apply with empty plan makes zero fake-API writes

**Checkpoint**: Foundation ready; story work can begin

---

## Phase 3: User Story 7 - A fixed, minimal screenshot set per device (Priority: P1) 🎯 MVP part 1

**Goal**: The local screenshots sit in the required layout and are validated against the fixed set before anything is uploaded.

**Independent Test**: `Tools/asc-release.py status` (read-only) reports every device folder in all 13 locales as matching the required set (iPhone 3, iPad 3, Duo outer 3, Duo inner 5, Watch 2); an extra or missing file makes that group fail with exit code 2.

### Tests for User Story 7

- [X] T012 [P] [US7] Unit tests in `Tools/asc/tests/test_screenshot_validation.py` using temp dirs: exact set passes; missing file, extra file, duplicate `NN`, wrong pixel size, RGBA/alpha image, more than 10 images each produce a named error; Duo outer rejects `04-*`/`05-*` (FR-025, FR-026)

### Implementation for User Story 7

- [X] T013 [US7] Implement local scan and validation in `Tools/asc/screenshots.py`: read `docs/store-screenshots/<store-locale>/<device-folder>/`, compute MD5 and pixel size, check PNG RGB without alpha, check names against the required set table from `locales.py`, return a `ScreenshotGroup` per locale/device (see `data-model.md`) or a validation error per group (FR-009, FR-023, FR-025)
- [X] T014 [US7] Add the `status` command in `Tools/asc-release.py` to print per-locale, per-device validation results (no API calls needed for the local part); exit 2 if any group is invalid
- [X] T015 [US7] One-time layout migration (FR-013, FR-027), run by hand not by the tool: `git mv` locale folders to store codes (`de`→`de-DE`, `es`→`es-ES`, `fr`→`fr-FR`, `nl`→`nl-NL`, others unchanged) in `docs/store-screenshots/`; `git mv` per device `entry-after-plus-ten.png`→`01-entry.png`, `history-90d-plateau.png`→`02-history.png`, `settings-default.png`→`03-settings.png` for `iphone-6.5` and `ipad-13`; `watch-entry-default.png`→`01-entry.png`, `watch-history-default.png`→`02-history.png`; Duo `01-entry-portrait.png`→`01-entry.png`, `02-history-portrait.png`→`02-history.png`, `03-settings-portrait.png`→`03-settings.png` (keep `04-entry-landscape.png`, `05-history-landscape.png` in `iphone-duo-inner`); delete `iphone-duo-outer/04-entry-landscape.png` and `05-history-landscape.png` in every locale
- [X] T016 [US7] Run `Tools/asc-release.py status` and fix any reported layout problems; open one entry image per device type and confirm it shows a weight value (FR-024)

**Checkpoint**: Local set validates in all 13 locales (SC-011)

---

## Phase 4: User Story 1 - Publish screenshots to a version in every locale (Priority: P1) 🎯 MVP part 2

**Goal**: Screenshots land in the matching locale and device group of the target version; a missing version is created.

**Independent Test**: Preview then `--apply` for one locale (`screenshots --locale de-DE`) on a version without screenshots; each device group in the store shows the local images.

### Tests for User Story 1

- [X] T017 [P] [US1] Unit tests in `Tools/asc/tests/test_versions.py` with the fake API: version found; version missing is planned as `create_version` first; non-editable state (anything outside PREPARE_FOR_SUBMISSION, DEVELOPER_REJECTED, REJECTED, METADATA_REJECTED) stops with exit 4 and no writes (FR-002, FR-016, US1 scenario 3)
- [X] T018 [P] [US1] Unit tests in `Tools/asc/tests/test_screenshot_upload.py` with the fake API: empty store plans `upload` for every local file; apply performs reserve → part upload → commit with MD5 → state poll, and a FAILED or stuck reservation is deleted and redone (R4, FR-012)

### Implementation for User Story 1

- [X] T019 [US1] Implement app and version lookup in `Tools/asc/versions.py`: find app by bundle id `de.juuronina.logweight`, find `appStoreVersions` by version string (platform IOS), report a format mismatch (`1.1.0` vs `1.1`) instead of guessing, check editable state, plan `create_version` when absent (FR-002, FR-016)
- [X] T020 [US1] Implement locale reconciliation in `Tools/asc/versions.py`: list `appStoreVersionLocalizations` for the version, compare with local locale folders, report locales that exist on only one side (exit 3 for that locale, others continue) (spec edge cases)
- [X] T021 [US1] Implement screenshot set lookup/creation in `Tools/asc/screenshots.py`: per localization list `appScreenshotSets`, create a missing set with the display type for the device folder; if the store rejects a display type (expected for Duo, R5), report the group as skipped with the store's message, not as a run failure
- [X] T022 [US1] Implement the upload flow in `Tools/asc/screenshots.py`: `POST appScreenshots` (fileName, fileSize) → `PUT` each upload operation part with the returned headers → `PATCH uploaded=true` with `sourceFileChecksum` (MD5) → poll `assetDeliveryState` until COMPLETE; delete and redo reservations in FAILED or stuck AWAITING_UPLOAD state (R4)
- [X] T023 [US1] Wire `screenshots` in `Tools/asc-release.py` incl. `--locale` and `--device` filters (FR-015), preview by default, `--apply` to execute, per-locale summary (FR-011)
- [X] T024 [US1] Probe the Duo display types: run `Tools/asc-release.py screenshots --locale en-US --device iphone-duo-outer` preview, then (with maintainer approval) one `--apply` attempt; record the accepted or rejected type names in `specs/001-asc-store-sync/research.md` R5 and update `Tools/asc/locales.py`
- [X] T025 [US1] Quickstart step 3 and 4 against the live store for `de-DE` only, with the maintainer's go-ahead; verify images and order in the web UI

**Checkpoint**: One locale fully published; version created if missing

---

## Phase 5: User Story 2 - Stable, predictable screenshot order (Priority: P1)

**Goal**: Order equals the numeric file prefix in every locale and version.

**Independent Test**: Sync two locales, change one file, sync again; remote order always equals local order.

### Tests for User Story 2

- [X] T026 [P] [US2] Unit tests in `Tools/asc/tests/test_screenshot_order.py`: remote order differing from local plans exactly one `reorder`; same order plans none; replaced image keeps its position (FR-004, FR-006)

### Implementation for User Story 2

- [X] T027 [US2] Implement ordering in `Tools/asc/screenshots.py`: target order = local files sorted by name; read remote order from the set's screenshot relationship; when different, `PATCH appScreenshotSets/{id}/relationships/appScreenshots` once with the full ordered id list, after uploads finish (R3)
- [X] T028 [US2] Apply to all 13 locales with the maintainer's go-ahead; compare the order in at least three locales and one earlier version in the web UI (SC-004)

**Checkpoint**: Order stable across locales

---

## Phase 6: User Story 3 - Skip unchanged screenshots (Priority: P2)

**Goal**: Re-runs upload only changed images and remove images that no longer exist locally.

**Independent Test**: Run twice with no changes (zero writes); change one image and run (exactly one replace); remove one local image and run (matching remote image deleted).

### Tests for User Story 3

- [X] T029 [P] [US3] Unit tests in `Tools/asc/tests/test_screenshot_diff.py`: all MD5 equal plans only `skip_unchanged` and the fake API records zero writes (SC-002); one changed file plans one `replace`; removed local file plans one `delete`; renamed file with identical content plans no upload (spec Assumptions)

### Implementation for User Story 3

- [X] T030 [US3] Implement the diff in `Tools/asc/screenshots.py`: match local to remote by file name, compare MD5 with `sourceFileChecksum`, produce `skip_unchanged`, `replace` (delete remote then upload, then restore position via the reorder step), `upload`, `delete`; treat remote screenshots whose state is FAILED as changed (FR-005, FR-006, R2)
- [X] T031 [US3] Run quickstart step 5 for `de-DE` with the maintainer's go-ahead: second run reports zero uploads; change one image copy in a scratch checkout path (not the repo files) or use the fake API to prove single-replace behaviour (SC-003)

**Checkpoint**: Idempotent screenshot sync

---

## Phase 7: User Story 4 - Publish listing texts for all locales (Priority: P2)

**Goal**: Subtitle, promotional text, description and keywords are written per locale, only when changed.

**Independent Test**: Edit one locale's subtitle in `docs/AppStoreMetadata.localized.md`, run `texts --locale de-DE --apply`; only that field is written; a second run writes nothing.

### Tests for User Story 4

- [X] T032 [P] [US4] Unit tests in `Tools/asc/tests/test_texts.py` using copies of `docs/AppStoreMetadata.md` and `docs/AppStoreMetadata.localized.md` as fixtures: all 13 locales parse; English base applies to `en-US`, `en-GB`, `en-CA`; aliases map (`it-IT`→`it`); description bullet indentation is normalised; limits are enforced (`subtitle` ≤30, `promotionalText` ≤170, `description` ≤4000, `keywords` ≤100 characters total, comma separated); a missing field is a validation error, not an empty write (FR-009)
- [X] T033 [P] [US4] Unit tests in `Tools/asc/tests/test_text_diff.py` with the fake API: equal texts plan `skip_unchanged`; one changed field plans one `update_text`; subtitle targets app info localizations while the other three target version localizations (R1, SC-003)

### Implementation for User Story 4

- [X] T034 [US4] Implement the text parser in `Tools/asc/texts.py` for the formats in `contracts/local-content.md` (English base sections `## Subtitle`, `## Promotional text`, `## Description`, `## Keywords`; localized `## <locale>` sections with `**Subtitle:**`, `**Promotional text:**`, `**Description:**`, `**Keywords:**`), normalising whitespace/line endings before comparison
- [X] T035 [US4] Implement text validation in `Tools/asc/texts.py` with the verbatim limits from `data-model.md`: `subtitle` (≤30), `promotionalText` (≤170), `description` (≤4000), `keywords` (≤100 chars total, comma separated); errors name locale and field and cause exit 2 with no writes for that locale
- [X] T036 [US4] Implement text sync in `Tools/asc/versions.py` and `Tools/asc/texts.py`: GET current `appInfoLocalizations` (subtitle) and `appStoreVersionLocalizations` (promotionalText, description, keywords), compare field by field after normalisation, `PATCH` only changed fields; create a missing localization only when the locale exists locally and is enabled in the store (never auto-create unlisted locales); the app info must be in an editable state (R1)
- [X] T037 [US4] Wire `texts` in `Tools/asc-release.py` with `--locale`, preview by default
- [X] T038 [US4] Run quickstart step 6 for `de-DE` with the maintainer's go-ahead

**Checkpoint**: Texts idempotent in all locales

---

## Phase 8: User Story 5 - Preview before changing the live listing (Priority: P2)

**Goal**: Every command previews first; preview equals what runs.

**Independent Test**: Preview makes zero writes (fake API recorder and live store); the applied action list equals the preview.

### Tests for User Story 5

- [X] T039 [P] [US5] Unit tests in `Tools/asc/tests/test_preview.py`: for each of `screenshots`, `texts`, `build`, `all` the default invocation makes zero fake-API writes and zero subprocess calls (xcodebuild mocked); `--apply` runs exactly the previewed actions (SC-005, US5 scenarios)

### Implementation for User Story 5

- [X] T040 [US5] Complete the `status` command in `Tools/asc-release.py`: with credentials, show target version (exists/editable/state), attached build, locales present on each side, and per-group differences; read-only
- [X] T041 [US5] Add the `--strict` option (any invalid group exits 2 with no writes) and verify exit codes 1 to 4 per `contracts/cli.md` with tests in `Tools/asc/tests/test_cli.py`
- [X] T042 [US5] Secret hygiene check (SC-006): run all commands in preview with `--verbose` and confirm output contains none of the three `.env` values (compare programmatically, do not echo values); add a test in `Tools/asc/tests/test_redaction.py` that feeds fake secrets and asserts they never appear in captured stdout/stderr

**Checkpoint**: Safe-by-default behaviour proven

---

## Phase 9: User Story 6 - Build, upload and attach the app build (Priority: P2)

**Goal**: One command archives, uploads, waits for processing and attaches the build to the target version.

**Independent Test**: `build --apply` produces the archive, a new build appears and reaches VALID, and it is the selected build on the version; rerun does not upload twice.

### Tests for User Story 6

- [X] T043 [P] [US6] Unit tests in `Tools/asc/tests/test_build.py` with mocked subprocess and the fake API: build number already in the store with VALID state skips archive/upload and goes to attach; build number already used in an incompatible way stops with a report and changes no file and creates no commit (FR-020, FR-021, clarification); pre-release version different from target refuses to attach (FR-019); wait is bounded and a re-run resumes at the first incomplete step

### Implementation for User Story 6

- [X] T044 [US6] Create `Tools/asc/ExportOptions.plist` with `method` = `app-store-connect`, `destination` = `upload`, `teamID` = `A8L9TRSZCR`, `signingStyle` = `automatic`, `uploadSymbols` = true (R8)
- [X] T045 [US6] Implement archive in `Tools/asc/build.py`: run `xcodegen generate`, then `xcodebuild archive -project LogWeight.xcodeproj -scheme LogWeight -configuration Release -destination 'generic/platform=iOS' -archivePath tmp/release/LogWeight.xcarchive -allowProvisioningUpdates -authenticationKeyPath … -authenticationKeyID … -authenticationKeyIssuerID …` with credentials passed from config without echoing them; stop before uploading if signing fails with a clear message (FR-017)
- [X] T046 [US6] Implement export and upload in `Tools/asc/build.py`: `xcodebuild -exportArchive -archivePath tmp/release/LogWeight.xcarchive -exportOptionsPlist Tools/asc/ExportOptions.plist -exportPath tmp/release/export -allowProvisioningUpdates` with the same auth flags (FR-018)
- [X] T047 [US6] Implement processing wait and attach in `Tools/asc/build.py` and `Tools/asc/versions.py`: poll `builds` filtered by app, build number and pre-release version until `processingState` is VALID (bounded, default 30 minutes, report INVALID/FAILED), compare the build's marketing version to the target and refuse a mismatch, then `PATCH appStoreVersions/{id}/relationships/build` (R9, FR-019)
- [X] T048 [US6] Detect existing build in the store before archiving (same build number for this version): skip archive and upload, continue at wait/attach; never edit `Config/Version.xcconfig` or `project.yml`, never commit (FR-020, FR-021)
- [X] T049 [US6] Wire `build` and `all` in `Tools/asc-release.py`: `all` runs build → attach → screenshots → texts; steps are individually runnable (FR-022); preview covers all steps
- [X] T050 [US6] Run quickstart step 7 on the next real release with the maintainer's go-ahead (archive takes minutes and uploads a real build); record any signing or export-compliance issue in `specs/001-asc-store-sync/research.md`

**Checkpoint**: Build delivered and attached repeatably

---

## Phase 10: Polish & Cross-Cutting Concerns

- [X] T051 [P] Update `docs/BuildAndDeploy.md` with a "Release to App Store Connect" section: prerequisites, the commands from `contracts/cli.md`, preview-first rule, exit codes
- [X] T052 [P] Update `docs/AppStoreReleaseChecklist.md`: replace manual screenshot upload and archive steps with `Tools/asc-release.py`, and note that the capture scripts still write old names until aligned (spec Assumptions)
- [X] T053 [P] Update `docs/AIScreenshotWorkflow.md`: new store layout (`docs/store-screenshots/<store-locale>/<device>/NN-name.png`) and the required set per device
- [X] T054 [P] Add `Tools/asc/tests` to CI only if the maintainer wants it (propose a `python3 -m unittest discover Tools/asc/tests` job in `.github/workflows/ci.yml`; do not add secrets to CI)
- [X] T055 Run `Tools/check-localizations.sh` and `python3 -m unittest discover Tools/asc/tests`; both must pass
- [X] T056 Run the full quickstart (`specs/001-asc-store-sync/quickstart.md` steps 1 to 9) against the next release version; tick SC-001 to SC-011

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (1)** → **Foundational (2)** blocks everything.
- **US7 (3)** needs Foundational; **US1 (4)** needs US7 (layout and validation) and Foundational.
- **US2 (5)** and **US3 (6)** build on US1's upload code in `screenshots.py` (same file: sequential, not parallel).
- **US4 (7)** needs only Foundational and can run in parallel with US1 to US3 (different files: `texts.py`).
- **US5 (8)** needs the commands from US1, US4 and US6 to exist for its tests; do its tests last among stories.
- **US6 (9)** needs Foundational and the version lookup from T019; independent of screenshots and texts.
- **Polish (10)** after the desired stories.

### Parallel Opportunities

- Setup: T003, T004 together.
- Foundational: T005, T006, T008 together; T010, T011 together after their targets exist.
- After Foundational: US4 (T032 to T038) in parallel with US7/US1 work; US6 (T043 to T050) in parallel once T019 is done.
- Tests marked [P] within a phase can be written together.

### Parallel Example: Foundational

```text
Task: "Implement .env loading in Tools/asc/config.py"          (T005)
Task: "Implement locale and device tables in Tools/asc/locales.py"  (T008)
```

## Implementation Strategy

### MVP First (US7 + US1 + US2)

1. Phases 1 and 2.
2. US7: layout migration and validation (T012 to T016).
3. US1 and US2: publish screenshots in the right order for one locale, then all.
4. **Stop and validate** with quickstart steps 3 to 4 on one locale before touching others.

### Incremental Delivery

1. MVP above → screenshots in all locales.
2. US3 (idempotence) → US4 (texts) → US5 (preview/safety proofs) → US6 (build) → polish.
3. Each live step (`--apply`) happens only with the maintainer's explicit go-ahead; preview runs are always safe.

## Notes

- Total tasks: 56 (T001 to T056).
- `screenshots.py` is shared by US7, US1, US2, US3: do not parallelise those phases.
- Open items to resolve during implementation: Duo display-type names (T024) and the store's version string format (T019).
- Commit after each task or logical group using Conventional Commits (`feat(release): …`, `docs(release): …`, `chore(store): …`).
