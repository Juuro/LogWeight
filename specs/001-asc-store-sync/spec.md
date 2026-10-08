# Feature Specification: App Store Connect Release Sync

**Feature Branch**: `001-asc-store-sync` (spec directory only; work continues on the current branch unless the maintainer decides otherwise)

**Created**: 2026-10-07

**Status**: Draft

**Input**: User description: "I want to upload the screenshots to ASC automatically. The credentials for ASC are in .env. Upload screenshots and associate them with a specific version in each locale. Order the screenshots the same way from locale to locale and from version to version. Don't upload screenshots again that didn't change. Upload all the texts in the different locales to ASC. Don't upload texts again that didn't change. Screenshots live in docs/store-screenshots (folders may be renamed to the exact App Store Connect locale names). Texts are in docs/AppStoreMetadata.md and docs/AppStoreMetadata.localized.md."

## Clarifications

### Session 2026-10-07

- Q (scope addition, requested by maintainer): Should the release process also build the app archive (today: Xcode Product → Archive), upload it, and attach it to the release version? → A: Yes, added to this feature as User Story 6 and FR-017 to FR-022.
- Q (scope addition, requested by maintainer): Which screenshots does each device get, and in what order? → A: See User Story 7 and FR-023 to FR-027: iPhone and iPad 3 each, iPhone Duo 3 per display plus 2 for the unfolded landscape view, Apple Watch 2.
- Q (scope change, requested by maintainer): Is taking the screenshots part of this feature, and must the entry screenshot show an open keyboard? → A: No capturing; the sync only uses the screenshots that already exist locally. The entry screenshot must show a value; an open keyboard is optional.
- Q: When the project's build number is already used by a build in the store, should the release run stop or use the next free number itself? → A: Stop and report; build numbers change only through the existing versioning process.
- Q: For each release, how should the sync pick the target app version? → A: Default to the project's current marketing version; an explicit argument overrides it. If that version does not exist in App Store Connect, the sync creates it (without submitting it).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Publish screenshots to a version in every locale (Priority: P1)

The maintainer has regenerated the store screenshots locally and wants them to appear on the App Store listing of a chosen app version, in every locale and for every device size, without dragging files into the web UI by hand.

**Why this priority**: Manual upload of roughly 13 locales × several device sizes × up to 10 images is the main pain. This alone removes most of the work and is a viable MVP.

**Independent Test**: Run the sync for one locale against a version that has no screenshots; verify in App Store Connect that every device size shows the expected images for that locale and version.

**Acceptance Scenarios**:

1. **Given** local screenshots for a locale and a target app version that is editable, **When** the maintainer runs the sync for that version, **Then** each device-size group of that locale on that version contains exactly the local images.
2. **Given** several locales and device sizes exist locally, **When** the maintainer runs the sync for all, **Then** every locale and device size is populated on the same version and a summary lists what was uploaded per locale and device size.
3. **Given** the target version exists but is not editable (for example already released), **When** the sync runs, **Then** it stops before changing anything and explains why.
4. **Given** no version is named and the project's current marketing version does not exist in the store, **When** the sync runs, **Then** the version is created (preview shows this first) and the content is synced into it.

---

### User Story 2 - Stable, predictable screenshot order (Priority: P1)

Screenshots appear in the same order in every locale and in every version, so the store page always tells the same story (entry, history, settings, then landscape variants).

**Why this priority**: Order is part of the listing quality and must not depend on upload timing or file system quirks.

**Independent Test**: Sync two locales, then a later version; verify the order of images is identical across locales and versions and matches the order defined by the local file names.

**Acceptance Scenarios**:

1. **Given** local files with ordered name prefixes, **When** synced, **Then** the displayed order equals the local order in every locale.
2. **Given** a screenshot is replaced or added locally, **When** synced again, **Then** the resulting order still equals the local order, with no manual reordering needed.
3. **Given** a new version is created later, **When** the sync runs for it, **Then** its order is identical to previous versions.

---

### User Story 3 - Skip unchanged screenshots (Priority: P2)

Re-running the sync after changing only a few images uploads only those images. Unchanged images are left in place.

**Why this priority**: Saves time and avoids needless churn, and makes the sync safe to run repeatedly.

**Independent Test**: Run the sync twice with no local changes; the second run reports zero uploads. Change one image and run again; only that image is uploaded.

**Acceptance Scenarios**:

1. **Given** the listing already matches the local images, **When** the sync runs again, **Then** nothing is uploaded and the run reports everything as up to date.
2. **Given** one local image changed, **When** the sync runs, **Then** only that image is replaced, in its original position.
3. **Given** a local image was removed, **When** the sync runs, **Then** the matching remote image is removed so the listing mirrors the local set.

---

### User Story 4 - Publish listing texts for all locales (Priority: P2)

Subtitle, promotional text, description and keywords from the project's metadata documents are written to App Store Connect for each locale, and only texts that changed are sent.

**Why this priority**: Texts are already maintained in the repository; syncing removes copy and paste across ten-plus locales and prevents drift.

**Independent Test**: Edit one locale's subtitle in the metadata document, run the text sync, and verify only that field in that locale changed in App Store Connect.

**Acceptance Scenarios**:

1. **Given** metadata documents with texts for several locales, **When** the text sync runs, **Then** each locale's subtitle, promotional text, description and keywords match the documents.
2. **Given** nothing changed since the last run, **When** the text sync runs, **Then** no text is sent and the run reports everything up to date.
3. **Given** a text exceeds the store's length limit or contains a disallowed value, **When** the sync runs, **Then** it reports the problem for that locale and field before sending anything for it.

---

### User Story 5 - Preview before changing the live listing (Priority: P2)

The maintainer can see exactly what would change (uploads, replacements, removals, text edits) before anything is written.

**Why this priority**: The listing is customer-facing; a safe preview prevents accidents.

**Independent Test**: Run in preview mode and confirm no change appears in App Store Connect while the report lists the planned actions.

**Acceptance Scenarios**:

1. **Given** local changes, **When** run in preview mode, **Then** a per-locale report lists planned actions and nothing is modified remotely.
2. **Given** the preview looks right, **When** the same command is run for real, **Then** the performed actions match the preview.

---

---

### User Story 6 - Build, upload and attach the app build to the release version (Priority: P2)

The maintainer no longer opens Xcode and chooses Product → Archive. The release process produces the same distributable app archive, uploads it to App Store Connect, and associates the processed build with the version that is currently in the release process, the same version used for screenshots and texts.

**Why this priority**: It completes the end-to-end release: after one run, the version has its build, screenshots and texts and only awaits submission. Screenshots and texts are useful on their own, so this is not P1.

**Independent Test**: Run the build step for the current version; verify in App Store Connect that a new build appears for the app, finishes processing, and is selected on the version.

**Acceptance Scenarios**:

1. **Given** a clean checkout at the release commit, **When** the maintainer runs the build step, **Then** a distributable archive for the iOS app (including its embedded Apple Watch app and extensions) is produced without opening Xcode.
2. **Given** the archive was produced, **When** it is uploaded, **Then** the run waits until the store has finished processing it and reports success or the store's rejection reason.
3. **Given** the processed build, **When** the run completes, **Then** the build is attached to the target version (the same version as the listing sync), replacing any previously attached build.
4. **Given** that build number was already uploaded for this version, **When** the build step runs again, **Then** it does not create a duplicate upload and reports that the build already exists.
5. **Given** preview mode, **When** the release process runs, **Then** it reports the planned build, upload and attach steps and produces and uploads nothing.

---

### User Story 7 - A fixed, minimal screenshot set per device (Priority: P1)

The store listing shows only the screenshots that matter, the same story on every device and in every locale: first the entry view, then the history, then settings. The set per device is fixed by the maintainer and the sync enforces it.

**Why this priority**: It defines exactly what "the local set" is, which the whole sync mirrors. A different set means different uploads.

**Independent Test**: After a sync, count and open each device group in any locale and compare it with the table below.

**Required set (in this order, numbers are the display order)**:

| Device | Screenshots |
|--------|-------------|
| iPhone | 1. Entry view showing a weight value (keyboard open or not). 2. History with many entries and a clearly visible graph. 3. Settings. |
| iPad | Same three, same order. |
| iPhone Duo, outer display | Same three, same order. |
| iPhone Duo, inner (unfolded) display | Same three, same order, then 4. Entry view in landscape. 5. History in landscape. |
| Apple Watch | 1. Entry view. 2. History. |

**Acceptance Scenarios**:

1. **Given** the sync ran for a locale, **When** the maintainer views any device group, **Then** it contains exactly the screenshots in the table, in that order, and nothing else.
2. **Given** an extra or outdated local screenshot exists in a device folder, **When** the sync checks the folder, **Then** it reports the unexpected file and refuses that group until it is removed.
3. **Given** a required screenshot is missing locally, **When** the sync checks the folder, **Then** it reports which one is missing and refuses that group.
4. **Given** the entry screenshot, **When** inspected, **Then** it shows a weight value (an open keyboard is not required); the history screenshot shows a dense history with a clearly readable graph.

---

### Edge Cases

- Build step: signing identity or provisioning is missing or expired: stop before uploading, with a clear message.
- Build step: the build number to upload was already used in the store: stop and report, rather than uploading a build the store will reject (the project's build-number rules stay in force: no manual bumping).
- Build step: the store keeps processing the build for a long time or marks it invalid: report status and exit unsuccessfully after a bounded wait; a re-run continues waiting rather than uploading again.
- Build step: the archive's marketing version differs from the target version: refuse to attach and report both values.
- Build step: the uploaded build is missing required export-compliance or privacy declarations: report what the store still needs; do not guess answers.

- Credentials missing, malformed or rejected: stop with a clear message that never prints the secret values.
- Network failure or interruption mid-upload: re-running resumes and converges to the correct state without duplicates or half-uploaded images.
- A locale exists locally but is not enabled for the app in App Store Connect (or the other way round): report it; do not silently create or skip.
- Local locale folders named differently from App Store Connect (for example `en-US` versus `de`, `ja`, `zh-Hans`): names must match App Store Connect exactly or be reported as unmapped.
- A device size has no local images, or more than the store allows (10 per size): report and refuse that group rather than truncating silently.
- Image rejected by the store (wrong dimensions, transparency): report per file and continue with other files.
- Watch screenshots and iPhone Duo (not formally documented as a store device size) may be refused by the store: report clearly per group.
- Locales present in the localized text document but with no counterpart in App Store Connect, such as regional English variants that only inherit the base English text: define how they are covered (see Assumptions).
- Version has screenshots added manually in the web UI: the sync treats the local set as the source of truth and reports differences before replacing.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST read the store account credentials from the local, untracked `.env` file and MUST NOT print, log or commit their values.
- **FR-002**: The system MUST default the target version to the project's current marketing version, MUST let the user override it with an explicit version, and MUST refuse versions that cannot be edited.
- **FR-003**: The system MUST upload screenshots into the matching locale and device-size group of the target version.
- **FR-004**: The system MUST define screenshot order from local file names so that the order is identical across locales and across versions.
- **FR-005**: The system MUST compare local images to what is already on the listing and MUST NOT re-upload images whose content is unchanged.
- **FR-006**: The system MUST replace changed images in their original position and remove remote images that no longer exist locally, so the listing mirrors the local set.
- **FR-007**: The system MUST sync subtitle, promotional text, description and keywords for every locale defined in the metadata documents.
- **FR-008**: The system MUST compare local texts to the live listing and MUST NOT resend texts whose content is unchanged.
- **FR-009**: The system MUST validate texts and images against store limits (character counts, image count per device size, image dimensions, no transparency) before sending, and report violations per locale and item.
- **FR-010**: The system MUST offer a preview mode that reports all planned changes and makes none.
- **FR-011**: The system MUST produce a per-locale summary after every run showing uploaded, replaced, removed, skipped (unchanged) and failed items.
- **FR-012**: The system MUST be safe to re-run after any failure and converge to the same final state.
- **FR-013**: The local screenshot folders for each locale MUST use the exact locale identifiers of App Store Connect so no mapping step is needed.
- **FR-014**: The system MUST NOT submit the version for review or otherwise move it beyond its initial editable state.
- **FR-015**: The system MUST allow syncing a single locale or a single device size for quick checks.
- **FR-016**: If the target version does not exist in the store, the system MUST create it as a new, unsubmitted version (shown in the preview first) and then sync into it; the whole flow MUST be repeatable unchanged for every release.
- **FR-017**: The system MUST produce the same distributable app archive the maintainer currently creates with Xcode's Archive command, from the command line, for the iOS app including its Apple Watch companion and extensions.
- **FR-018**: The system MUST upload that archive to App Store Connect and wait until the store reports processing complete (or failed), reporting the outcome.
- **FR-019**: The system MUST attach the processed build to the target version, which is the same version resolved for the screenshot and text sync (FR-002), and MUST refuse to attach a build whose marketing version differs from it.
- **FR-020**: The system MUST NOT upload the same build number twice and MUST be safe to re-run: a re-run resumes at the first incomplete step (archive, upload, processing, attach).
- **FR-021**: The system MUST NOT bump the marketing version or the build number by hand; it uses the values defined by the project's existing versioning process and MUST stop with a clear report, changing no project file and creating no commit, when that build number is already used in the store.
- **FR-022**: The user MUST be able to run the steps independently (build and upload only, attach only, screenshots only, texts only) or together as one release run, and preview mode (FR-010) MUST cover all steps.
- **FR-023**: The screenshot set per device MUST be exactly the set in User Story 7, in that order: iPhone 3, iPad 3, iPhone Duo outer display 3, iPhone Duo inner display 5, Apple Watch 2.
- **FR-024**: Entry screenshots on iPhone, iPad and both iPhone Duo displays MUST show a weight value (an open keyboard is optional); history screenshots MUST show a dense history with a clearly visible graph; the watch set has no settings screenshot.
- **FR-025**: The system MUST validate each device folder against the required set (names and count) before uploading, and MUST refuse the group on any missing or unexpected file (FR-009 style report).
- **FR-026**: The system MUST NOT upload the landscape screenshots for the iPhone Duo outer display; landscape applies only to the inner (unfolded) display.
- **FR-027**: Capturing screenshots and changing the capture tooling are out of scope. The one-time move of the existing local screenshots into the required folder and file layout (store locale names, numbered files), and removal of files that are not part of the required set, is included as preparation.

### Key Entities

- **Store version**: The app version on the store that listings are attached to; has an editable or locked state.
- **Locale listing**: Per-locale texts and screenshot groups of one version.
- **Screenshot group**: Ordered set of images for one device size within a locale listing (maximum 10).
- **App archive**: The distributable package produced from the release commit for one version and build number.
- **Store build**: The uploaded and processed build in the store, identified by version and build number, that can be attached to a version.
- **Required screenshot set**: The fixed list of screenshots per device and display, with order (User Story 7), against which local folders are validated.
- **Local screenshot set**: Image files on disk per locale and device size; file name prefixes define order.
- **Local text set**: Per-locale subtitle, promotional text, description and keywords parsed from the metadata documents.
- **Sync state**: The comparison between local content and the live listing used to decide what to upload, replace, remove or skip.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A full screenshot sync for all locales and device sizes completes without any manual action in the store web UI.
- **SC-002**: A second run with no local changes performs zero uploads and zero text writes and reports all items up to date.
- **SC-003**: After changing one image, exactly one image is uploaded; after changing one text field, exactly one text field is written.
- **SC-004**: In 100% of synced locales and versions, the displayed screenshot order matches the local order.
- **SC-005**: Preview mode makes zero changes to the live listing in every run.
- **SC-006**: No credential value appears in any console output, log or repository file.
- **SC-007**: Re-running after an interrupted run produces a listing with no duplicate or half-uploaded images.
- **SC-008**: A release can be taken from a clean checkout to "version has build, screenshots and texts, ready for submission" with a single command and no Xcode interaction.
- **SC-009**: Running the build step twice for the same build number results in exactly one build in the store.
- **SC-010**: The build attached to the version always has the same marketing version as the version being released.
- **SC-011**: In 100% of locales, every device group contains exactly the required number of screenshots (iPhone 3, iPad 3, Duo outer 3, Duo inner 5, Watch 2) in the required order.

## Assumptions

- Credentials (key identifier, issuer identifier and private key location) are already present in the local `.env`, which is git-ignored.
- The target version defaults to the project's current marketing version and is created in App Store Connect if missing; the version string format used by the store is matched exactly (for example `1.1.0` versus `1.1`).
- Metadata documents are the source of truth for subtitle, promotional text, description and keywords. The base English text in `docs/AppStoreMetadata.md` covers the English locales; `docs/AppStoreMetadata.localized.md` covers the others. Regional English variants (en-US, en-GB, en-CA) reuse the base English text unless the maintainer later adds dedicated text.
- App name, privacy and support URLs, categories, age rating, review notes and "What's New" are out of scope for this version; they can be added later.
- "Unfolded landscape" means the iPhone Duo inner display in landscape; the outer display gets no landscape screenshots. This replaces the earlier plan of 10 Duo screenshots per locale (5 per display) with 8 (3 outer, 5 inner).
- Taking new screenshots is out of scope: the existing captured images are used as they are. Today's entry images already show a value, so they qualify. Future captures by the existing capture scripts may write the old file names; bringing those scripts in line with the required layout is a separate task and not part of this feature (the sync reports a layout mismatch instead of guessing).
- Local screenshots are limited to device groups that are already produced (iPhone 6.5", iPad 13", Apple Watch, iPhone Duo outer and inner); other sizes are out of scope.
- Local locale folders will be renamed to the exact App Store Connect locale identifiers (for example `de-DE` instead of `de`); the rename is part of this feature.
- The App Store may not accept iPhone Duo screenshots in the currently supported device-size groups; if refused, that group is reported and skipped, not treated as a whole-run failure.
- Image identity is decided by file content, so renaming a file without changing content does not trigger a re-upload.
- Signing credentials (distribution certificate and provisioning, or automatic signing with the store API key) are available on the maintainer's Mac; the build step runs locally, not in the hosted CI, in this feature.
- The build number comes from the project's existing versioning process (the project file holds the value; CI increments it on green runs); this feature reads it and never edits it. If the current build number is already in the store, the build step stops (see Edge Cases).
- Export-compliance and similar one-time store declarations were already answered for the app; the build step does not answer them.
- Submitting the version for review, pricing, availability, and in-app purchases are out of scope.
