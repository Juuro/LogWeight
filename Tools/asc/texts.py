"""Parses docs/AppStoreMetadata*.md and plans text updates (FR-007..FR-009, R1)."""
from __future__ import annotations

import re
from dataclasses import dataclass
from pathlib import Path

from .config import ROOT
from .errors import ValidationError
from .locales import ENGLISH_LOCALES, STORE_LOCALES, TEXT_COPIES, doc_locale_to_store

LIMITS = {"subtitle": 30, "promotionalText": 170, "description": 4000, "keywords": 100, "whatsNew": 4000}
FIELDS = tuple(LIMITS)
APP_INFO_FIELDS = ("subtitle",)
VERSION_FIELDS = ("promotionalText", "description", "keywords", "whatsNew")

BASE_DOC = ROOT / "docs" / "AppStoreMetadata.md"
LOCALIZED_DOC = ROOT / "docs" / "AppStoreMetadata.localized.md"
WHATS_NEW_DOC = ROOT / "docs" / "AppStoreWhatsNew.md"


@dataclass(frozen=True)
class TextSet:
    subtitle: str
    promotionalText: str
    description: str
    keywords: str
    whatsNew: str = ""

    def as_dict(self) -> dict[str, str]:
        return {f: getattr(self, f) for f in FIELDS}


def normalize(text: str) -> str:
    lines = [ln.rstrip() for ln in text.replace("\r\n", "\n").replace("\r", "\n").split("\n")]
    return "\n".join(lines).strip()


def _unwrap_backticks(text: str) -> str:
    text = text.strip()
    if text.startswith("`") and text.endswith("`") and len(text) >= 2:
        text = text[1:-1]
    return text


def _sections(markdown: str, level: str = "## ") -> dict[str, str]:
    sections: dict[str, list[str]] = {}
    current = None
    for line in markdown.splitlines():
        if line.startswith(level):
            current = line[len(level):].strip()
            sections[current] = []
        elif current is not None:
            sections[current].append(line)
    return {k: "\n".join(v) for k, v in sections.items()}


def parse_base(markdown: str) -> TextSet:
    sec = _sections(markdown)
    for needed in ("Subtitle", "Promotional text", "Description", "Keywords"):
        if needed not in sec:
            raise ValidationError(f"AppStoreMetadata.md: missing section '## {needed}'")
    # Subtitle section: first bullet line holds the value; later paragraphs are notes.
    first = next((ln for ln in sec["Subtitle"].splitlines() if ln.strip().startswith("- ")), "")
    subtitle = _unwrap_backticks(first.strip()[2:].strip())
    promo = _unwrap_backticks(next((ln for ln in sec["Promotional text"].splitlines() if ln.strip()), ""))
    keywords = _unwrap_backticks(next((ln for ln in sec["Keywords"].splitlines() if ln.strip()), ""))
    return TextSet(normalize(subtitle), normalize(promo), normalize(sec["Description"]), normalize(keywords))


def _bullet_field(block: str, label: str) -> str | None:
    pattern = re.compile(rf"^- \*\*{re.escape(label)}:\*\*\s*(.*?)(?=^- \*\*|\Z)", re.M | re.S)
    match = pattern.search(block)
    if not match:
        return None
    raw = match.group(1)
    lines = [re.sub(r"^ {2}", "", ln) for ln in raw.splitlines()]
    return _unwrap_backticks("\n".join(lines).strip())


def parse_localized(markdown: str) -> dict[str, TextSet]:
    result: dict[str, TextSet] = {}
    for heading, block in _sections(markdown).items():
        if not re.fullmatch(r"[a-z]{2,3}(-[A-Za-z]{2,4})?", heading):
            continue  # "Locales" overview etc.
        values = {}
        missing = []
        for label, key in (("Subtitle", "subtitle"), ("Promotional text", "promotionalText"),
                           ("Description", "description"), ("Keywords", "keywords")):
            value = _bullet_field(block, label)
            if value is None or not normalize(value):
                missing.append(label)
            else:
                values[key] = normalize(value)
        if missing:
            raise ValidationError(f"AppStoreMetadata.localized.md {heading}: missing {', '.join(missing)}")
        result[doc_locale_to_store(heading)] = TextSet(**values)
    return result


def parse_whats_new(markdown: str) -> tuple[str, dict[str, str]]:
    """Returns (version the notes are for, {locale: text}); `en` is the English base."""
    match = re.search(r"^\*\*Version:\*\*\s*(\S+)", markdown, re.M)
    if not match:
        raise ValidationError("AppStoreWhatsNew.md: missing line '**Version:** x.y.z'")
    notes = {}
    for heading, block in _sections(markdown).items():
        if re.fullmatch(r"[a-z]{2,3}(-[A-Za-z]{2,4})?", heading):
            notes[doc_locale_to_store(heading)] = normalize(block)
    return match.group(1), notes


def load_all(base_doc: Path = BASE_DOC, localized_doc: Path = LOCALIZED_DOC,
             whats_new_doc: Path = WHATS_NEW_DOC) -> dict[str, TextSet]:
    base = parse_base(base_doc.read_text())
    localized = parse_localized(localized_doc.read_text())
    _, notes = parse_whats_new(whats_new_doc.read_text())
    texts = {loc: _with_notes(ts, notes.get(loc, "")) for loc, ts in localized.items()}
    for locale in ENGLISH_LOCALES:
        texts[locale] = _with_notes(base, notes.get("en", ""))
    for target, source in TEXT_COPIES.items():
        texts[target] = texts[source]
    return texts


def _with_notes(ts: TextSet, notes: str) -> TextSet:
    return TextSet(ts.subtitle, ts.promotionalText, ts.description, ts.keywords, notes)


def whats_new_version(whats_new_doc: Path = WHATS_NEW_DOC) -> str:
    return parse_whats_new(whats_new_doc.read_text())[0]


def validate(texts: dict[str, TextSet], locales=STORE_LOCALES) -> dict[str, list[str]]:
    """Returns {locale: [problem, ...]}; empty dict when everything is fine."""
    problems: dict[str, list[str]] = {}
    for locale in locales:
        if locale not in texts:
            problems.setdefault(locale, []).append("no text defined in the metadata documents")
            continue
        for field, limit in LIMITS.items():
            value = getattr(texts[locale], field)
            if not value:
                problems.setdefault(locale, []).append(f"{field} is empty")
            elif len(value) > limit:
                problems.setdefault(locale, []).append(f"{field} has {len(value)} characters (limit {limit})")
    return problems


def diff_fields(local: TextSet, remote: dict[str, str | None], fields) -> dict[str, str]:
    """Fields whose normalized value differs from the store (only those are sent)."""
    changed = {}
    for f in fields:
        if normalize(remote.get(f) or "") != getattr(local, f):
            changed[f] = getattr(local, f)
    return changed
