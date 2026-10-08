"""Action model and reporting shared by every command (FR-010, FR-011).

Preview and apply use the same action list, so what is previewed is what runs.
"""
from __future__ import annotations

from collections import Counter, defaultdict
from dataclasses import dataclass, field
from typing import Callable

KINDS = (
    "create_version", "update_text", "upload", "replace", "delete", "reorder",
    "archive", "upload_build", "wait_processing", "attach_build", "skip_unchanged",
)


@dataclass
class Action:
    kind: str
    target: str
    locale: str = "-"
    reason: str = ""
    run: Callable[[], None] | None = field(default=None, repr=False)
    result: str = "planned"  # planned | done | failed
    error: str = ""

    def __post_init__(self):
        if self.kind not in KINDS:
            raise ValueError(f"unknown action kind {self.kind}")

    @property
    def writes(self) -> bool:
        return self.kind != "skip_unchanged"


class Plan:
    def __init__(self, actions: list[Action] | None = None):
        self.actions: list[Action] = list(actions or [])

    def add(self, action: Action) -> Action:
        self.actions.append(action)
        return action

    def extend(self, actions) -> None:
        self.actions.extend(actions)

    def pending_writes(self) -> list[Action]:
        return [a for a in self.actions if a.writes]

    def render(self, applying: bool = False) -> str:
        by_locale: dict[str, list[Action]] = defaultdict(list)
        for action in self.actions:
            by_locale[action.locale].append(action)
        lines: list[str] = []
        for locale in sorted(by_locale):
            lines.append(f"== {locale} ==")
            for a in by_locale[locale]:
                mark = {"planned": "PLAN" if not applying else "TODO", "done": "DONE", "failed": "FAIL"}[a.result]
                suffix = f" ({a.reason})" if a.reason else ""
                suffix += f" -> {a.error}" if a.error else ""
                lines.append(f"  [{mark}] {a.kind}: {a.target}{suffix}")
        lines.append("")
        lines.extend(self.summary_lines())
        return "\n".join(lines)

    def summary_lines(self) -> list[str]:
        per_locale: dict[str, Counter] = defaultdict(Counter)
        for a in self.actions:
            bucket = "failed" if a.result == "failed" else {
                "upload": "uploaded", "replace": "replaced", "delete": "deleted", "reorder": "reordered",
                "skip_unchanged": "skipped",
            }.get(a.kind, a.kind)
            per_locale[a.locale][bucket] += 1
        lines = ["Summary per locale:"]
        for locale in sorted(per_locale):
            counts = ", ".join(f"{k}={v}" for k, v in sorted(per_locale[locale].items()))
            lines.append(f"  {locale}: {counts}")
        return lines

    def execute(self) -> bool:
        """Runs write actions in order. Returns False if any failed (others still run)."""
        ok = True
        for action in self.actions:
            if not action.writes or action.run is None:
                continue
            try:
                action.run()
                action.result = "done"
            except Exception as err:  # keep going: re-run converges (FR-012)
                action.result = "failed"
                action.error = str(err)
                ok = False
        return ok
