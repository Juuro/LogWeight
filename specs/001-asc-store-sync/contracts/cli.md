# Contract: `Tools/asc-release.py`

```text
Tools/asc-release.py <command> [options]

Commands
  all          build + upload + attach, then screenshots and texts (full release run)
  build        xcodegen, archive, export/upload, wait for processing, attach to version
  screenshots  sync local screenshots to the version
  texts        sync subtitle / promotional text / description / keywords
  status       read-only: show version, build, locales and what differs

Common options
  --version X.Y.Z   target version (default: MARKETING_VERSION in project.yml)
  --apply           perform changes (default is preview: no remote or local writes)
  --locale CODE     limit to one store locale (repeatable)
  --device FOLDER   limit to one device folder (screenshots only)
  --env PATH        credentials file (default: .env)
  --verbose         extra detail; never prints secrets
```

## Behaviour
- Preview prints one line per planned action, grouped per locale, then a summary count per kind. `--apply` runs exactly those actions.
- Output summary per locale: uploaded / replaced / deleted / reordered / skipped / failed (FR-011).
- Reads `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_PATH` from the environment or `--env` file; `~` expanded. Missing or unreadable variable: names the variable only.

## Exit codes
| Code | Meaning |
|---|---|
| 0 | Success, or preview completed |
| 1 | Usage or configuration error (missing credential variable, bad flag) |
| 2 | Validation failed (text length, image size/alpha/count, ordering prefixes, locale mismatch, version/build mismatch); nothing written |
| 3 | Store refused or failed part of the run; partial progress reported, safe to re-run |
| 4 | Target version not editable |

## Guarantees
- Validates every device folder against the required screenshot set before any upload; one bad group is refused, others continue (exit 3) unless `--strict` is used (any invalid group then exits 2 with no writes).
- Never calls review-submission endpoints (FR-014).
- Never edits `project.yml`, `Config/Version.xcconfig`, or git state (FR-021).
- Re-running with no local changes performs zero writes (SC-002).
