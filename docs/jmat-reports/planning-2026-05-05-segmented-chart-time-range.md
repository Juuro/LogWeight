# JMAT Planning Report: Segmented chart time-range controls in HistoryView

**Date:** 2026-05-05  
**Stack:** swift / swiftui  
**Branch:** feature/segmented-chart-time-range  
**Confidence:** 91%

## Specialist Debate Summary

### Agreements (High Confidence)
- Use a native segmented Picker for mutually exclusive range selection.
- Keep one always-selected state via `@State` with default `oneMonth`.
- Filter chart data in `HistoryView` based on selected range cutoff.
- Increase fetch limit beyond 50 so the `All` option is meaningful.
- Keep scope minimal and local to avoid unnecessary architecture changes.

### Conflicts Resolved
- **Protocol change vs local-only implementation**: Architect proposed extending `HealthKitStore`; Pragmatist proposed local filtering only.  
  - **Resolution:** Local filtering only in this feature.
  - **Reasoning:** Acceptance criteria are met with one-file change and lower risk.

- **Shared enum file vs local enum**: Architect suggested extraction; frontend focus accepted local placement.  
  - **Resolution:** Keep `ChartRange` local to `HistoryView` for now.
  - **Reasoning:** One consumer currently; extract only if reuse appears.

- **Extra resilience complexity now vs later**: Resilience suggested caching/retry additions; Pragmatist favored minimum change.  
  - **Resolution:** Defer retry/caching additions.
  - **Reasoning:** Existing behavior and expected data sizes do not justify extra complexity now.

### Adoption Tracking
| Specialist | Adopted | Rejected | Notes |
|------------|---------|----------|-------|
| Architect | 2 | 2 | Segmented UI/range model adopted; protocol extension deferred |
| Quality Engineer | 3 | 2 | Naming/default/no-PII retained; extra tests deferred |
| Pragmatist | 4 | 0 | Core approach fully adopted |
| Frontend Specialist | 4 | 0 | Picker UX and label plan adopted |
| Resilience & Performance | 2 | 2 | Risk awareness kept; advanced hardening deferred |

## Implementation Plan

**Files:** 0 new, 1 modified  
**Order:**
1. Add `ChartRange` enum + `selectedRange` state in `HistoryView`
2. Add segmented Picker UI in chart section
3. Filter chart input data by selected range cutoff
4. Increase `load()` fetch limit from 50 to 5000
5. Run verification checks

### Files
- **MODIFY** `App/Shared/Views/HistoryView.swift`
  - Add `ChartRange` (`1W`, `1M`, `3M`, `6M`, `1Y`, `All`)
  - Add `@State private var selectedRange: ChartRange = .oneMonth`
  - Render segmented Picker and bind to selected range
  - Filter chart weights by computed cutoff
  - Increase `recentWeights(limit:)` call to `5000`

## Quality Gates
- Critical items addressed:
  - No PII logging introduced
  - No unhandled errors introduced
  - No API/schema breaking changes
- High items addressed:
  - Single-file, low blast radius implementation
  - One-option-always-selected invariant
  - Practical data-volume support for `All`
- Unaddressed:
  - Dedicated new tests for range behavior (candidate follow-up)

## Risks
- **LOW**: `All` range may still be bounded for users with >5000 entries  
  **Mitigation:** Add paged/date-predicate retrieval in future if needed.
- **LOW**: Edge behavior around cutoff boundaries/timezones  
  **Mitigation:** Use calendar-based date math and verify with known sample dates.

## Devil's Advocate
**Verdict:** CHALLENGES_FOUND (fallback)

Devil's Advocate automated run was unavailable due to model limit, so fallback challenge checks were recorded:
- **MEDIUM / Coverage:** dedicated tests for segmented filtering deferred.
- **LOW / Data completeness:** `All` depends on fetch cap.

No blocking architectural or security challenge identified for this scoped change.
