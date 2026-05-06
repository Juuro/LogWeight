# JMAT Planning Report: HistoryView sticky chart + topmost-row highlight sync

**Date:** 2026-05-06
**Stack:** Swift / SwiftUI + Charts (iOS 17 / iPadOS 17 / macOS 14 / watchOS 10)
**Branch:** feature/crosshair-chart-overlay
**Confidence:** 90%

## Task

Pin the HistoryView trend chart at the top so it never scrolls away. Only the list scrolls. The topmost 100%-fully-visible list row is highlighted with a colour, and the matching chart point uses the same colour. List rows whose dates fall outside the selected chart range remain in the list with no chart highlight. The "Recent entries" header must not overlay rows. Accessibility preserved. watchOS chart unchanged (no chart there per ADR-009) but the sticky-header fix applies on watchOS too.

## Specialist Debate Summary

### Agreements (High Confidence)

- Lift chart out of List Section into a fixed VStack above the List (architect, pragmatist, resilience, QE).
- Drop the List Section header for "Recent entries" and render as a static label outside the scroll viewport.
- Precedence: drag-driven `hoveredWeight` wins over scroll-driven `topVisibleWeight` when both active.
- Suppress chart-side highlight when `topVisibleWeight` is outside `selectedRange.cutoff`; row highlight persists.
- Accessibility: `.accessibilityAddTraits(.isSelected)` + `.accessibilityValue` on the highlighted row — colour alone insufficient.
- No animation by default; if added, gate on `@Environment(\.accessibilityReduceMotion)`.
- Preserve swipeActions/contextMenu, .privacySensitive(), SecurityLog discipline.

### Conflicts Resolved

- **Highlight colour** — Architect: yellow (distinct from chart teal). Pragmatist: teal (cohesion). **Resolution:** `Color.yellow.opacity(0.20)` — distinct from chart line, conventional for selection, system-adaptive in dark mode.
- **Pure-helper extraction to Core** — QE: extract `topMostFullyVisibleWeightId` + `shouldHighlightInChart` to LogWeightCore. Pragmatist: don't expand Core API for one-line expressions. **Resolution:** Pragmatist wins (YAGNI).
- **Chart-loop highlight** — Resilience: extract overlay to avoid N comparisons per scroll tick. Architect: inline conditional fine. **Resolution:** Inline for now, refactor only if profiling shows jank.
- **Test count** — QE: 18 tests. Pragmatist: don't gold-plate. **Resolution:** 3 high-value UI tests + existing regression tests preserved.
- **mutationError placement** — QE: move out of List. Architect: keep in List. **Resolution:** Keep in List (no header → no overlay issue).

### Adoption Tracking

| Specialist | Adopted | Rejected | Notes |
|---|---|---|---|
| architect | 6 | 1 | Layout, tracking, state shape, precedence, a11y traits, header positioning. Chart-loop overlay extraction deferred. |
| quality-engineer | 5 | 2 | Test invariants + a11y identifiers. Pure-helper extraction rejected; 18-test suite reduced to 3. |
| pragmatist | 4 | 1 | Skip-list adopted. Teal colour rejected (ambiguous with chart line). |
| resilience-performance | 4 | 1 | State separation, Reduce Motion gate, no-animation default. Chart-loop overlay deferred. |

## Devil's Advocate

**Verdict:** CHALLENGES_FOUND — highest severity BLOCKER

**Top 3 challenges (all addressed in revised plan):**

1. **DA-1 BLOCKER — `.onGeometryChange` API ambiguity at iOS 17.** Apple docs vary; MEMORY.md asserts BUILD SUCCEEDED but no commit landed. **Fix:** switch to `GeometryReader + PreferenceKey` (iOS 14+ unambiguous).
2. **DA-2 BLOCKER — Initial-load empty state.** With `listHeight=0` initially, every row reports false; `.onGeometryChange` action only fires on transform-result change, so listHeight arriving later doesn't re-emit. visibleWeights stays empty until user scrolls. **Fix:** use computed property reading `rowFrames` + `listFrame` from PreferenceKey state — both populated naturally on initial layout.
3. **DA-3 HIGH — watchOS Section header still sticky.** The current `Section { … } header: { Text("Recent entries") }` is shared across all platforms; the plan's restructure was scoped to non-watchOS. **Fix:** apply layout restructure on ALL platforms; chart-only code stays `#if !os(watchOS)`.

**Other DA fixes applied:**
- DA-4 HIGH — Use `.global` coordinate space (not `.named`) to avoid macOS NSTableView ambiguity.
- DA-5 HIGH — Filter `topVisibleWeight` by `weights.contains` to eliminate ghost weights after delete.
- DA-6 MEDIUM — Indirectly fixed by DA-2 (no longer empty on first render).
- DA-8 MEDIUM — Add empty-history + single-weight UI tests.

## Implementation Plan

**Files:** 1 modified (`App/Shared/Views/HistoryView.swift`); optional 1 modified (UI tests).

### Key changes to HistoryView.swift

| Section | Change |
|---|---|
| File-scope (private, `#if !os(watchOS)`) | Add `RowFramePreferenceKey: PreferenceKey` (`[Weight: CGRect]`) and `ListFrameKey: PreferenceKey` (`CGRect`). |
| `@State` (`#if !os(watchOS)`) | Add `rowFrames: [Weight: CGRect]`, `listFrame: CGRect`. |
| Computed (`#if !os(watchOS)`) | `topVisibleWeight` (filters by weights.contains; max recordedAt of visible rows). `listHighlightedWeight = hoveredWeight ?? topVisibleWeight`. `chartHighlightedWeight = listHighlightedWeight if its date >= selectedRange.cutoff`. |
| `content` else-branch | Replace with `VStack(spacing: 0) { #if !os(watchOS) chartSection #endif; "Recent entries" label; List { mutationError + ForEach(rows) }.background(GeometryReader for ListFrameKey on non-watchOS) }`. Drop the List Section header on every platform. |
| Row body | Extract `historyRow(for:)`. Apply `.background(GeometryReader publishing RowFramePreferenceKey)` on non-watchOS. Apply `.listRowBackground(yellow if highlighted)`, `.accessibilityAddTraits(.isSelected)`, `.accessibilityValue("Selected")`, `.onDisappear { rowFrames[weight] = nil }` on non-watchOS. Preserve swipeActions and contextMenu. |
| Chart `PointMark` | Conditional `.foregroundStyle(yellow if chartHighlightedWeight == weight else .teal)` and `.symbolSize(140 if highlighted else existing logic)`. |
| `onPreferenceChange` handlers | Update `rowFrames` and `listFrame` from the two preference keys. |

### Implementation order

1. Add preference keys at file scope (`#if !os(watchOS)`).
2. Add `@State` for `rowFrames`, `listFrame`.
3. Add computed properties.
4. Restructure `content` else-branch (VStack).
5. Extract `historyRow(for:)`.
6. Wire `.onPreferenceChange` handlers.
7. Update chart PointMark with conditional highlight.
8. Build: `cd Packages/LogWeightCore && swift test` → 49/49 pass.
9. Build: `xcodebuild build -scheme LogWeight -destination 'platform=iOS Simulator,name=iPhone 15'`.
10. Build: `xcodebuild build -scheme LogWeightWatch -destination 'generic/platform=watchOS Simulator' CODE_SIGNING_ALLOWED=NO`.
11. Build: `xcodebuild build -scheme LogWeightMac -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO`.
12. Manual QA: chart pinned, highlight on load (no scroll required), scroll up/down syncs highlight, drag crosshair takes precedence, range switch suppresses chart highlight for out-of-range rows, dark-mode contrast.
13. Optional: add 3 UI tests + run `xcodebuild test -scheme LogWeight`.

## Quality Gates

**Critical:** No PII in logs — SecurityLog API enforces structurally; `.privacySensitive()` preserved everywhere.

**High:**
- Separation of Concerns — view-private helpers; no Core API expansion.
- Testing — 3 new XCUITest cases cover the riskiest invariants; 2 existing regression tests preserved.
- Naming — `topVisibleWeight`, `listHighlightedWeight`, `chartHighlightedWeight`, `historyRow`, `RowFramePreferenceKey` all self-documenting.
- Accessibility — `.accessibilityAddTraits(.isSelected)` + `.accessibilityValue("Selected")`; `Color.yellow.opacity(0.20)` adapts in dark mode; .privacySensitive() preserved; Reduce Motion satisfied trivially (no animation).

**Deferred (acceptable):** Instruments performance pass (revisit if QA shows jank); extended Reduce-Motion / contrast XCUITests.

## Risks (after DA fixes)

| ID | Severity | Description | Mitigation |
|---|---|---|---|
| R-PERF | MEDIUM | Per-row GeometryReader fires preferences during scroll. ~50 visible rows × 120 Hz ProMotion ≈ 6k updates/sec. | PreferenceKey diffs by Equatable; onPreferenceChange fires only on aggregate change. Profile during QA. Fallback: coalesce via DispatchQueue.main.async or reintroduce Bool transform with explicit re-emission on listFrame change. |
| R-MEM | LOW | `rowFrames` retains entries for rows whose `.onDisappear` may not fire (UITableView reuse quirks). | Steady-state bounded by visible + dequeued cells. Not a leak concern. |
| R-CONTRAST | LOW | `Color.yellow.opacity(0.20)` WCAG AA contrast in dark mode requires verification. | Manual QA with Accessibility Inspector. If insufficient, bump to 0.30 or use explicit light/dark variants. |

## Open Questions for User

1. **Highlight colour confirmation** — `Color.yellow.opacity(0.20)` (system-adaptive yellow). Confirm or pick a different colour?
2. **UI tests** — include in this commit or follow-up?
