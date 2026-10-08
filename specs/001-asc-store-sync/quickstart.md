# Quickstart: validating the release sync

Prerequisites: `.env` with `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH`; `pip` packages `PyJWT cryptography` (installed); Xcode 27.1; signing team `A8L9TRSZCR`; folders renamed per [contracts/local-content.md](contracts/local-content.md).

0. **Prepare the screenshot set** (one-time, no recapture; spec FR-027): rename locale folders to store codes and `git mv` the existing images to the numbered names in [contracts/local-content.md](contracts/local-content.md); delete files outside the required set. Open one entry image per device: it shows a weight value.
1. **Unit tests** (no network): `python3 -m unittest discover Tools/asc/tests` passes.
1b. **Set validation**: `Tools/asc-release.py status` reports every device folder as matching the required set (iPhone 3, iPad 3, Duo outer 3, Duo inner 5, Watch 2) in all 13 locales (SC-011); an extra file makes the group fail.
2. **Read-only status**: `Tools/asc-release.py status` prints target version, whether it exists, editable state, and per-locale differences. Expect no writes.
3. **Preview, one locale**: `Tools/asc-release.py screenshots --locale de-DE` lists planned uploads; confirm nothing changed in App Store Connect.
4. **Apply, one locale**: add `--apply`; verify order and images in the web UI (SC-001, SC-004).
5. **Idempotence**: rerun step 4; expect zero uploads (SC-002). Change one image, rerun; exactly one replace (SC-003).
6. **Texts**: `Tools/asc-release.py texts --locale de-DE --apply`, then edit one subtitle and confirm one write.
7. **Build**: `Tools/asc-release.py build` (preview), then `--apply`; wait for VALID and check the build is selected on the version (SC-009, SC-010). Rerun: no second upload.
8. **Full run**: `Tools/asc-release.py all --apply` on the next release version from a clean checkout (SC-008).
9. **Secret hygiene**: `grep -R "$ASC_KEY_ID" -r .` outside `.env` returns nothing; run output contains no secret values (SC-006).
