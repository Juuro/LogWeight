"""Command orchestration: builds one action list per command, previews or applies it.

Preview is the default; only `apply=True` runs write actions (FR-010).
"""
from __future__ import annotations

import time
from dataclasses import dataclass, field
from pathlib import Path

from . import build as build_mod
from . import screenshots as shots
from . import texts as texts_mod
from . import versions as ver
from .config import BUNDLE_ID, ROOT, Credentials, read_build_number, resolve_version
from .errors import (EXIT_OK, EXIT_STORE, EXIT_VALIDATION, AscError, NotEditableError, StoreError, ValidationError)
from .locales import DEVICE_ALIASES, DEVICE_FOLDERS, STORE_LOCALES, STORE_SETS
from .plan import Action, Plan


@dataclass
class Options:
    version: str | None = None
    apply: bool = False
    locales: list[str] = field(default_factory=list)
    device: str | None = None
    strict: bool = False
    allow_unmerged: bool = False
    verbose: bool = False
    screenshot_root: Path = shots.SCREENSHOT_ROOT
    project_yml: Path | None = None
    xcconfig: Path | None = None
    base_doc: Path = texts_mod.BASE_DOC
    localized_doc: Path = texts_mod.LOCALIZED_DOC
    whats_new_doc: Path = texts_mod.WHATS_NEW_DOC


def _locales(opts: Options) -> list[str]:
    for loc in opts.locales:
        if loc not in STORE_LOCALES:
            raise AscError(f"unknown locale '{loc}'. Valid: {', '.join(STORE_LOCALES)}")
    return opts.locales or list(STORE_LOCALES)


def _devices(opts: Options) -> list[str]:
    """Device folders to scan. Folders of one store set always travel together (iPhone Duo)."""
    if not opts.device:
        return list(DEVICE_FOLDERS)
    set_name = DEVICE_ALIASES.get(opts.device, opts.device)
    if set_name not in STORE_SETS:
        raise AscError(f"unknown device '{opts.device}'. Valid: {', '.join(STORE_SETS)}")
    return [folder for folder, _ in STORE_SETS[set_name]]


class Problems:
    """Validation problems that refuse a group/locale but not the whole run (exit 3), or all (--strict, exit 2)."""

    def __init__(self):
        self.items: list[str] = []

    def add(self, text: str) -> None:
        self.items.append(text)


def local_screenshot_groups(opts: Options, problems: Problems):
    groups = shots.merge_groups(shots.scan_all(opts.screenshot_root, _locales(opts), _devices(opts)))
    valid = []
    for g in groups:
        if g.valid:
            valid.append(g)
        else:
            for e in g.errors:
                problems.add(f"{g.locale}/{g.device}: {e}")
    for name in shots.unknown_locale_folders(opts.screenshot_root):
        problems.add(f"unknown locale folder in {opts.screenshot_root.name}: {name} (use store locale ids)")
    return valid


def plan_screenshots(api, app_id: str, ctx: ver.Context, opts: Options, problems: Problems, sleep=time.sleep) -> list[Action]:
    groups = local_screenshot_groups(opts, problems)
    actions: list[Action] = []
    if ctx.version is None:
        for g in groups:
            def deferred(grp=g):
                locs = ver.version_localizations(api, ctx.require().id)
                if grp.locale not in locs:
                    raise StoreError(f"locale {grp.locale} is not enabled in the store")
                sub = Plan(shots.plan_group(api, grp, locs[grp.locale]["id"], sleep))
                if not sub.execute():
                    raise StoreError("; ".join(a.error for a in sub.actions if a.result == "failed"))
            actions.append(Action("upload", f"{g.device} ({len(g.files)} files, planned after the version exists)", g.locale, "", deferred))
        return actions
    locs = ver.version_localizations(api, ctx.version.id)
    for g in groups:
        if g.locale not in locs:
            problems.add(f"{g.locale}: locale not enabled in the store for {ctx.version.version_string}; not created")
            continue
        try:
            actions.extend(shots.plan_group(api, g, locs[g.locale]["id"], sleep))
        except StoreError as err:
            problems.add(f"{g.locale}/{g.device}: {err}")
    return actions


def check_whats_new_version(opts: Options, target: str) -> None:
    """The release notes file is rewritten per release; a stale one must never ship (exit 2)."""
    doc_version = texts_mod.whats_new_version(opts.whats_new_doc)
    if not ver.same_version(doc_version, target):
        raise ValidationError(f"{opts.whats_new_doc.name} is for version {doc_version}, target is {target}; "
                              "rewrite the release notes for this release first")


def plan_texts(api, app_id: str, ctx: ver.Context, opts: Options, problems: Problems, target: str) -> list[Action]:
    check_whats_new_version(opts, target)
    texts = texts_mod.load_all(opts.base_doc, opts.localized_doc, opts.whats_new_doc)
    locales = _locales(opts)
    bad = texts_mod.validate(texts, locales)
    for locale, items in bad.items():
        for item in items:
            problems.add(f"{locale}: {item}")
    ok_locales = [l for l in locales if l not in bad]
    if ctx.version is None:
        return [Action("update_text", "subtitle, promotionalText, description, keywords", l,
                       "planned after the version exists",
                       (lambda loc=l: _deferred_texts(api, app_id, ctx, texts, loc))) for l in ok_locales]
    return ver.plan_texts(api, ctx.version, app_id, texts, ok_locales)


def _deferred_texts(api, app_id, ctx, texts, locale) -> None:
    sub = Plan(ver.plan_texts(api, ctx.require(), app_id, texts, [locale]))
    if not sub.execute():
        raise StoreError("; ".join(a.error for a in sub.actions if a.result == "failed"))


def run(command: str, api, credentials: Credentials | None, opts: Options, out=print,
        runner=build_mod.default_runner, sleep=time.sleep) -> int:
    problems = Problems()
    if runner is build_mod.default_runner and credentials is not None:
        runner = build_mod.redacting_runner(credentials.secret_values())
    try:
        if command == "status":
            return _status(api, opts, problems, out)
        target = resolve_version(opts.version, opts.project_yml)
        number = read_build_number(opts.xcconfig)
        app_id = ver.find_app(api, BUNDLE_ID)
        ctx = ver.Context()
        plan = Plan(ver.plan_version(api, app_id, target, ctx))
        if command in ("build", "all"):
            if opts.apply and not opts.allow_unmerged:
                build_mod.check_release_commit()
            plan.extend(build_mod.plan_build(api, app_id, ctx, target, number, credentials, runner, sleep))
        if command in ("screenshots", "all"):
            plan.extend(plan_screenshots(api, app_id, ctx, opts, problems, sleep))
        if command in ("texts", "all"):
            plan.extend(plan_texts(api, app_id, ctx, opts, problems, target))
    except NotEditableError as err:
        out(f"error: {err}")
        return err.exit_code
    except AscError as err:
        out(f"error: {err}")
        return err.exit_code

    for p in problems.items:
        out(f"problem: {p}")
    if problems.items and opts.strict:
        out("--strict: refusing the whole run, nothing written")
        return EXIT_VALIDATION

    out(f"Target: version {target}, build {number}" + ("" if opts.apply else "  [PREVIEW - nothing is written; add --apply]"))
    if not opts.apply:
        out(plan.render())
        return EXIT_STORE if problems.items else EXIT_OK

    ok = plan.execute()
    out(plan.render(applying=True))
    return EXIT_OK if ok and not problems.items else EXIT_STORE


def _status(api, opts: Options, problems: Problems, out) -> int:
    groups = shots.scan_all(opts.screenshot_root, _locales(opts), _devices(opts))
    for g in groups:
        for e in g.errors:
            problems.add(f"{g.locale}/{g.device}: {e}")
    for name in shots.unknown_locale_folders(opts.screenshot_root):
        problems.add(f"unknown locale folder: {name}")
    try:
        check_whats_new_version(opts, resolve_version(opts.version, opts.project_yml))
    except ValidationError as err:
        problems.add(str(err))
    texts = texts_mod.load_all(opts.base_doc, opts.localized_doc, opts.whats_new_doc)
    for locale, items in texts_mod.validate(texts, _locales(opts)).items():
        for item in items:
            problems.add(f"{locale}: {item}")
    good = sum(1 for g in groups if g.valid)
    out(f"Local screenshots: {good}/{len(groups)} groups match the required set")
    for p in problems.items:
        out(f"problem: {p}")
    target = resolve_version(opts.version, opts.project_yml)
    out(f"Target version: {target}, build number: {read_build_number(opts.xcconfig)}")
    if api is not None:
        app_id = ver.find_app(api, BUNDLE_ID)
        found = ver.find_version(api, app_id, target)
        if found is None:
            out(f"Store: version {target} does not exist yet (store has: {', '.join(ver.existing_version_strings(api, app_id)) or 'none'})")
        else:
            out(f"Store: version {target} state {found.state} ({'editable' if found.editable else 'not editable'}), "
                f"attached build: {ver.attached_build_id(api, found.id) or 'none'}")
            store_locales = set(ver.version_localizations(api, found.id))
            out("Store locales missing locally: " + (", ".join(sorted(store_locales - set(STORE_LOCALES))) or "none"))
            out("Local locales missing in the store: " + (", ".join(sorted(set(STORE_LOCALES) - store_locales)) or "none"))
    return EXIT_VALIDATION if problems.items else EXIT_OK
