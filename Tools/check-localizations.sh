#!/bin/sh
# Verify every locale has the same keys as en.lproj/Localizable.strings.
set -eu

ROOT="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
RESOURCES="$ROOT/App/Shared/Resources"
EN_FILE="$RESOURCES/en.lproj/Localizable.strings"

if [ ! -f "$EN_FILE" ]; then
  echo "error: missing $EN_FILE" >&2
  exit 1
fi

exec python3 - "$RESOURCES" <<'PY'
import re
import sys
from pathlib import Path

resources = Path(sys.argv[1])
en_file = resources / "en.lproj" / "Localizable.strings"

KEY_RE = re.compile(r'^"((?:\\.|[^"\\])*)"\s*=')


def keys(path: Path) -> set[str]:
    text = path.read_text(encoding="utf-8")
    found: set[str] = set()
    duplicates: list[str] = []
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

if failed:
    print(
        "\nFix: add each missing key to every *.lproj/Localizable.strings "
        "(same key as en, translated value).",
        file=sys.stderr,
    )
    sys.exit(1)

print(f"ok: {len(en_keys)} keys in {len(locales) + 1} locales")
PY
