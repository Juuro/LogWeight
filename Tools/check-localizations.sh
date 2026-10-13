#!/bin/sh
# Verify every locale has the same keys as en.lproj/Localizable.strings, and that the
# spoken App Shortcut phrases (App/iOS/Resources/<locale>.lproj/AppShortcuts.strings)
# have the same keys everywhere and keep the ${applicationName} token.
set -eu

ROOT="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
RESOURCES="$ROOT/App/Shared/Resources"
EN_FILE="$RESOURCES/en.lproj/Localizable.strings"

if [ ! -f "$EN_FILE" ]; then
  echo "error: missing $EN_FILE" >&2
  exit 1
fi

exec python3 - "$RESOURCES" "$ROOT/App/iOS/Resources" <<'PY'
import re
import sys
from pathlib import Path
from typing import List, Set

resources = Path(sys.argv[1])
shortcuts_resources = Path(sys.argv[2])
en_file = resources / "en.lproj" / "Localizable.strings"

KEY_RE = re.compile(r'^"((?:\\.|[^"\\])*)"\s*=')


def keys(path: Path) -> Set[str]:
    text = path.read_text(encoding="utf-8")
    found: Set[str] = set()
    duplicates: List[str] = []
    for line in text.splitlines():
        match = KEY_RE.match(line)
        if not match:
            continue
        key = bytes(match.group(1), "utf-8").decode("unicode_escape")
        if key in found:
            duplicates.append(key)
        found.add(key)
    if duplicates:
        print(f"error: duplicate keys in {path}:", file=sys.stderr)
        for key in sorted(set(duplicates)):
            print(f"  - {key}", file=sys.stderr)
        sys.exit(1)
    return found


en_keys = keys(en_file)
if not en_keys:
    print(f"error: no keys found in {en_file}", file=sys.stderr)
    sys.exit(1)

locales = sorted(
    p for p in resources.iterdir()
    if p.is_dir() and p.suffix == ".lproj" and p.name != "en.lproj"
)

failed = False
for locale in locales:
    path = locale / "Localizable.strings"
    if not path.is_file():
        print(f"error: missing {path}", file=sys.stderr)
        failed = True
        continue
    other_keys = keys(path)
    missing = en_keys - other_keys
    extra = other_keys - en_keys
    if missing or extra:
        failed = True
        print(f"error: {locale.name} is out of sync with en.lproj", file=sys.stderr)
        for key in sorted(missing):
            print(f"  missing: {key}", file=sys.stderr)
        for key in sorted(extra):
            print(f"  extra:   {key}", file=sys.stderr)

PAIR_RE = re.compile(r'^"((?:\\.|[^"\\])*)"\s*=\s*"((?:\\.|[^"\\])*)"\s*;')
TOKEN = "${applicationName}"


def phrases(path: Path) -> dict:
    found: dict = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        match = PAIR_RE.match(line)
        if not match:
            continue
        key, value = match.group(1), match.group(2)
        if key in found:
            print(f"error: duplicate phrase key in {path}: {key}", file=sys.stderr)
            sys.exit(1)
        found[key] = value
    return found


shortcut_dirs = sorted(
    p for p in shortcuts_resources.glob("*.lproj") if (p / "AppShortcuts.strings").exists()
)
en_phrases = {}
if shortcut_dirs:
    en_path = shortcuts_resources / "en.lproj" / "AppShortcuts.strings"
    if not en_path.is_file():
        print(f"error: missing {en_path}", file=sys.stderr)
        sys.exit(1)
    en_phrases = phrases(en_path)
    for locale in sorted(p for p in resources.iterdir() if p.is_dir() and p.suffix == ".lproj"):
        path = shortcuts_resources / locale.name / "AppShortcuts.strings"
        if not path.is_file():
            print(f"error: missing {path}", file=sys.stderr)
            failed = True
            continue
        found = phrases(path)
        if set(found) != set(en_phrases):
            failed = True
            print(f"error: {locale.name} AppShortcuts.strings is out of sync with en", file=sys.stderr)
            for key in sorted(set(en_phrases) - set(found)):
                print(f"  missing: {key}", file=sys.stderr)
            for key in sorted(set(found) - set(en_phrases)):
                print(f"  extra:   {key}", file=sys.stderr)
        for key, value in found.items():
            if key.count(TOKEN) != 1 or value.count(TOKEN) != 1:
                failed = True
                print(
                    f"error: {locale.name} phrase must contain {TOKEN} exactly once: {value}",
                    file=sys.stderr,
                )
            if "%" in value:
                failed = True
                print(
                    f"error: {locale.name} phrase must not contain a placeholder: {value}",
                    file=sys.stderr,
                )

if failed:
    print(
        "\nFix: add each missing key to every *.lproj/Localizable.strings "
        "(same key as en, translated value); spoken phrases live in "
        "App/iOS/Resources/<locale>.lproj/AppShortcuts.strings and must keep "
        "${applicationName} exactly once.",
        file=sys.stderr,
    )
    sys.exit(1)

print(
    f"ok: {len(en_keys)} keys in {len(locales) + 1} locales"
    + (f"; {len(en_phrases)} spoken phrases" if en_phrases else "")
)
PY
