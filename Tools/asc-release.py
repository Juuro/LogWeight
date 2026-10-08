#!/usr/bin/env python3
"""LogWeight release sync for App Store Connect (specs/001-asc-store-sync).

Preview is the default: nothing is written unless --apply is given.
Prerequisites: python3.11+, `pip install PyJWT cryptography`, Xcode 27.1 for `build`/`all`,
credentials in .env (ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH). Secrets are never printed.

  Tools/asc-release.py status
  Tools/asc-release.py screenshots --locale de-DE            # preview
  Tools/asc-release.py all --apply                           # full release run
"""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from asc import commands  # noqa: E402
from asc.api import ApiClient  # noqa: E402
from asc.config import load_credentials  # noqa: E402
from asc.errors import AscError, EXIT_USAGE  # noqa: E402

COMMANDS = {
    "all": "build + attach, then screenshots and texts (full release run)",
    "build": "xcodegen, archive, export/upload, wait for processing, attach to the version",
    "screenshots": "sync local screenshots to the version",
    "texts": "sync subtitle / promotional text / description / keywords",
    "status": "read-only: version, build, locales and what differs",
}


def parse(argv):
    parser = argparse.ArgumentParser(prog="asc-release.py", description=__doc__.split("\n\n")[0])
    sub = parser.add_subparsers(dest="command", required=True)
    for name, text in COMMANDS.items():
        p = sub.add_parser(name, help=text, description=text)
        p.add_argument("--version", help="target version (default: MARKETING_VERSION in project.yml)")
        p.add_argument("--apply", action="store_true", help="perform changes (default: preview only)")
        p.add_argument("--locale", action="append", default=[], help="limit to a store locale id (repeatable)")
        p.add_argument("--device", help="limit to one device: iphone-6.5, ipad-13, iphone-duo, watch-series-11 (screenshots only)")
        p.add_argument("--env", help="credentials file (default: .env)")
        p.add_argument("--strict", action="store_true", help="any invalid group refuses the whole run (exit 2)")
        p.add_argument("--verbose", action="store_true")
    return parser.parse_args(argv)


def main(argv=None) -> int:
    args = parse(argv if argv is not None else sys.argv[1:])
    opts = commands.Options(version=args.version, apply=args.apply, locales=args.locale,
                            device=args.device, strict=args.strict, verbose=args.verbose)
    try:
        credentials = None
        api = None
        try:
            credentials = load_credentials(args.env)
            api = ApiClient(credentials)
        except AscError:
            if args.command != "status":
                raise
            print("note: no usable credentials, showing local checks only")
        return commands.run(args.command, api, credentials, opts)
    except AscError as err:
        print(f"error: {err}")
        return err.exit_code
    except KeyboardInterrupt:
        return EXIT_USAGE


if __name__ == "__main__":
    sys.exit(main())
