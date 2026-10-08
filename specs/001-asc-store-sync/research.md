# Research: App Store Connect Release Sync

## R1. Where each text field lives
- **Decision**: `subtitle` is written to `appInfoLocalizations` (app-level, per locale). `promotionalText`, `description`, `keywords` are written to `appStoreVersionLocalizations` (per version, per locale).
- **Rationale**: That is where the store keeps them. Subtitle lives on the app info, which must also be editable.
- **Alternatives**: Treat all four as version fields: wrong, the API rejects subtitle there.

## R2. Detecting unchanged screenshots
- **Decision**: Compare local MD5 against `sourceFileChecksum` of each remote screenshot; match by position after sorting by name. A mismatch replaces only that image. Remote images with no local counterpart are deleted; missing remote images are uploaded.
- **Rationale**: The store reports the checksum it received at upload, so no download is needed. File name is also stored (`fileName`), used to match identity when order changes.
- **Alternatives**: Local state/manifest file: drifts from reality after manual web edits. Re-uploading everything: slow, violates FR-005.

## R3. Order and required set
- **Decision**: The required set per device is a constant table in `locales.py` (iPhone/iPad/Duo outer: `01-entry 02-history 03-settings`; Duo inner adds `04-entry-landscape 05-history-landscape`; Watch: `01-entry 02-history`). A folder must match it exactly (names and count) or the group is refused (FR-023, FR-025). Order is the numeric prefix; after uploads, compare the remote order to the target and send one relationship PATCH on the screenshot set only when it differs.
- **Rationale**: Deterministic, same in every locale and version (FR-004). A fixed table also catches stale files (old outer landscape images, old scene names) instead of silently uploading them. Files are moved into this layout once (R11).
- **Alternatives**: Alphabetical by scene name (fragile); explicit manifest (extra file to maintain).

## R4. Upload mechanics
- **Decision**: Reserve (`POST appScreenshots` with fileName, fileSize) → PUT each returned part with the given headers → `PATCH uploaded=true` with `sourceFileChecksum`. Poll `assetDeliveryState` until COMPLETE or FAILED; a stuck or FAILED reservation is deleted and redone on re-run (FR-012).
- **Rationale**: Documented flow. Re-runs clean up half-finished reservations rather than duplicating.

## R5. Device display types
- **Decision**: Map folders to display types: `iphone-6.5` to `APP_IPHONE_65` (1284×2778), `ipad-13` to `APP_IPAD_PRO_3GEN_129` (2064×2752), `watch-series-11` to `APP_WATCH_SERIES_10` (416×496), `iphone-duo-outer` / `iphone-duo-inner` to the Duo display types. Validate pixel size against the table before upload.
- **Verified 2026-10-08 (live, de-DE, version 1.1)**: the store accepts `APP_IPHONE_DUO`, and there is only ONE Duo type for both displays. Outer (1398×2034) and inner (2007×2853 / 2853×2007) images live in the same set (max 10, 8 used). The tool therefore merges `iphone-duo-outer` and `iphone-duo-inner` into one store set, outer first, with store file names `1-outer-NN-…` and `2-inner-NN-…`; a set is refused if either folder is invalid. `--device iphone-duo` selects both.
- **Alternatives**: Skip Duo entirely: loses the goal that started this work.

## R6. Locale identifiers
- **Decision**: Local folders use the exact store locale codes: `de-DE`, `en-CA`, `en-GB`, `en-US`, `es-ES`, `fr-FR`, `it`, `ja`, `ko`, `nl-NL`, `pt-BR`, `zh-Hans`, `zh-Hant`. The text document headings (`de-DE`, `it-IT`, `nl-NL`, …) are mapped through a small alias table in `locales.py`; English locales use the base English text from `AppStoreMetadata.md`. Capture scripts' `LOCALE_KEYS` change to the same codes.
- **Rationale**: Removes mapping at sync time, as requested. Exact set of enabled store locales is read from the API and compared (FR edge case).
- **Alternatives**: Keep short folder names plus a map: more places to drift.

## R7. Version and build resolution
- **Decision**: Target version = `--version` or `MARKETING_VERSION` from `project.yml` (now `1.1.0`). If absent in the store, create `appStoreVersions` (platform IOS, versionString, release type left to the store default) and report it first in preview. Build number read from `Config/Version.xcconfig`; if a build with that number already exists for the version: if processed, skip upload and go to attach; if the number exists for a different state or version, stop (clarification: no automatic renumbering).
- **Open item**: confirm whether the store lists version strings as `1.1` or `1.1.0` (already `1.0` shipped?). The tool uses the project value verbatim and reports a mismatch with existing versions rather than guessing.

## R8. Archive and upload
- **Decision**: `xcodebuild archive -project LogWeight.xcodeproj -scheme LogWeight -configuration Release -destination 'generic/platform=iOS' -archivePath tmp/release/LogWeight.xcarchive -allowProvisioningUpdates` with the API key flags, then `xcodebuild -exportArchive -exportOptionsPlist Tools/asc/ExportOptions.plist` with `method = app-store-connect` and `destination = upload`. Run `xcodegen generate` first (project.yml is source of truth). Only Apple Development identities exist locally; automatic signing with the API key provisions cloud-managed distribution signing, so no manual certificates.
- **Rationale**: Same artifact as Product → Archive; a single tool uploads it; no `altool` needed.
- **Alternatives**: `altool`/Transporter upload of an exported IPA: extra step, deprecated paths.

## R9. Attach build and wait
- **Decision**: Poll `builds?filter[app]=…&filter[version]=<build number>&filter[preReleaseVersion.version]=<marketing>` until `processingState` is VALID (bounded wait, default 30 min, re-run continues), then `PATCH appStoreVersions/{id}/relationships/build`. Refuse if the build's pre-release version differs from the target version (FR-019).

## R10. Safety defaults
- **Decision**: Preview is the default; `--apply` required to write. Never request submission endpoints. Credentials only through `.env` (`ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH`, with `~` expansion); error messages name the variable, never the value. Retry 429/5xx with backoff.

## R11. Screenshot capture is out of scope
- **Decision**: No changes to capture scenes or capture scripts. The existing images are used as they are; today's entry images already show a value, which is all FR-024 needs. A one-time move puts existing files into the required layout: store-locale folder names, `01-entry.png`, `02-history.png`, `03-settings.png` (Duo inner also `04-entry-landscape.png`, `05-history-landscape.png`; Watch `01-entry.png`, `02-history.png`), and deletes files outside the required set (old outer-display landscape images).
- **Rationale**: Scope decision by the maintainer. Keeps this feature to listing and build delivery.
- **Consequence**: The capture scripts still write the old names and locale keys. The sync validates the layout and reports mismatches; aligning the scripts is separate follow-up work.

## R12. Extra store locales
- **Decision**: The store also has `en-AU`, `es-MX`, `fr-CA`, `pt-PT`. They are now first-class locales: screenshot folders copied from `en-GB`, `es-ES`, `fr-FR`, `pt-BR`; texts copied the same way (`TEXT_COPIES` in `Tools/asc/locales.py`; `en-AU` uses the English base text). Maintainer's decision; `fr-CA` from `fr-FR` was added to match the store. Update the copy sources there if dedicated content is written later.
