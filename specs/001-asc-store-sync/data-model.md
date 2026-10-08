# Data Model: App Store Connect Release Sync

All entities are in memory for the duration of a run; nothing is persisted locally.

## ReleaseTarget
- `version_string` (from `--version` or `project.yml`), `build_number` (from `Config/Version.xcconfig`), `app_id` (looked up by bundle id `de.juuronina.logweight`).
- Rule: version string must match the store's format exactly; build number is read-only input (FR-021).

## StoreVersion (remote)
- `id`, `versionString`, `appStoreState` (editable states: PREPARE_FOR_SUBMISSION, DEVELOPER_REJECTED, REJECTED, METADATA_REJECTED, WAITING_FOR_REVIEW is NOT edited), `attached_build`.
- Transition used by the tool: absent → created in PREPARE_FOR_SUBMISSION. Never moved further (FR-014).

## LocaleListing
- `locale` (store code), local text set, `version_localization_id`, `app_info_localization_id`.
- Rule: locale must exist locally and in the store; mismatches are reported, never auto-created or skipped silently.

## TextSet (local)
- Fields: `subtitle` (≤30), `promotionalText` (≤170), `description` (≤4000), `keywords` (≤100 chars total, comma separated).
- Source: `docs/AppStoreMetadata.md` (English, applied to en-US/en-GB/en-CA) and `docs/AppStoreMetadata.localized.md` (per heading). Formats in [contracts/local-content.md](contracts/local-content.md).
- Rule: normalised (trimmed, line endings, bullet indentation) before comparison so formatting-only differences do not trigger writes.

## ScreenshotGroup
- `locale`, `device_folder`, `display_type`, ordered list of `LocalScreenshot`, `remote_set_id`.
- Rules: the folder must equal the required set for its device exactly (iPhone/iPad/Duo outer: `01-entry`, `02-history`, `03-settings`; Duo inner: those plus `04-entry-landscape`, `05-history-landscape`; Watch: `01-entry`, `02-history`); no extra files; pixel size is in the display type's allowed list; RGB without alpha. Violations refuse the group (exit 2).

## LocalScreenshot / RemoteScreenshot
- Local: `path`, `file_name`, `md5`, `size_bytes`, `pixels`.
- Remote: `id`, `file_name`, `source_file_checksum`, `asset_delivery_state` (AWAITING_UPLOAD, UPLOAD_COMPLETE, COMPLETE, FAILED), `position`.
- Identity: content (md5). A rename without content change is not a re-upload (spec Assumptions).

## Action (the plan)
- `kind` ∈ {create_version, update_text, upload, replace, delete, reorder, archive, upload_build, wait_processing, attach_build, skip_unchanged}, with `locale`, `target`, `reason`. The same list is printed in preview and executed with `--apply`, so preview equals what runs (US5).

## ArchiveBuild / StoreBuild
- Local archive path under `tmp/release/`; remote `id`, `version` (build number), `processingState` (PROCESSING, VALID, INVALID, FAILED), `preReleaseVersion`.
- Resume point = first step whose remote effect is missing (FR-020).
