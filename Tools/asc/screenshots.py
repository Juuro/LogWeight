"""Local screenshot scan/validation, diff against the store, upload and ordering.

Spec: User Stories 1, 2, 3, 7; FR-003..FR-006, FR-009, FR-023..FR-026.
"""
from __future__ import annotations

import hashlib
import re
import struct
import time
from dataclasses import dataclass, field
from pathlib import Path

from .config import ROOT
from .errors import StoreError
from .locales import (DEVICE_FOLDERS, DISPLAY_TYPES, MAX_SCREENSHOTS_PER_SET, REQUIRED_SET,
                      STORE_LOCALES, STORE_SETS)
from .plan import Action

SCREENSHOT_ROOT = ROOT / "docs" / "store-screenshots"
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
NAME_RE = re.compile(r"^(\d{2})-[a-z0-9-]+\.png$")


@dataclass(frozen=True)
class LocalScreenshot:
    path: Path
    file_name: str
    md5: str
    size_bytes: int
    pixels: tuple[int, int]


@dataclass
class ScreenshotGroup:
    locale: str
    device: str
    display_type: str
    files: list[LocalScreenshot] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)

    @property
    def valid(self) -> bool:
        return not self.errors


def png_info(path: Path) -> tuple[tuple[int, int], bool]:
    """Returns ((width, height), has_alpha) from the PNG header without extra libraries."""
    with path.open("rb") as handle:
        head = handle.read(33)
        if head[:8] != PNG_SIGNATURE or head[12:16] != b"IHDR":
            raise ValueError("not a PNG file")
        width, height, _depth, color_type = struct.unpack(">IIBB", head[16:26])
        has_alpha = color_type in (4, 6)
        if not has_alpha:  # a tRNS chunk also means transparency
            rest = handle.read()
            has_alpha = b"tRNS" in rest[:4096] or _has_chunk(rest, b"tRNS")
    return (width, height), has_alpha


def _has_chunk(data: bytes, name: bytes) -> bool:
    pos = 0
    while pos + 8 <= len(data):
        length, chunk = struct.unpack(">I4s", data[pos:pos + 8])
        if chunk == name:
            return True
        if chunk == b"IDAT":
            return False
        pos += 12 + length
    return False


def md5_of(path: Path) -> str:
    digest = hashlib.md5()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1 << 20), b""):
            digest.update(block)
    return digest.hexdigest()


def scan_group(root: Path, locale: str, device: str) -> ScreenshotGroup:
    group = ScreenshotGroup(locale, device, DISPLAY_TYPES[device])
    folder = root / locale / device
    required = REQUIRED_SET[device]
    if not folder.is_dir():
        group.errors.append(f"folder missing: {locale}/{device}")
        return group
    present = sorted(p.name for p in folder.iterdir() if not p.name.startswith("."))
    if len(present) > MAX_SCREENSHOTS_PER_SET:
        group.errors.append(f"{len(present)} files, store allows {MAX_SCREENSHOTS_PER_SET}")
    for name in present:
        if name not in required:
            group.errors.append(f"unexpected file: {name}")
    for name in required:
        if name not in present:
            group.errors.append(f"missing file: {name}")
    for name in sorted(required):
        path = folder / name
        if not path.is_file():
            continue
        try:
            pixels, alpha = png_info(path)
        except (OSError, ValueError) as err:
            group.errors.append(f"{name}: {err}")
            continue
        if pixels != required[name]:
            group.errors.append(f"{name}: {pixels[0]}x{pixels[1]} px, expected {required[name][0]}x{required[name][1]}")
        if alpha:
            group.errors.append(f"{name}: has transparency (alpha channel)")
        group.files.append(LocalScreenshot(path, name, md5_of(path), path.stat().st_size, pixels))
    return group


def unknown_locale_folders(root: Path = SCREENSHOT_ROOT) -> list[str]:
    if not root.is_dir():
        return []
    return sorted(p.name for p in root.iterdir() if p.is_dir() and p.name not in STORE_LOCALES)


def scan_all(root: Path = SCREENSHOT_ROOT, locales=STORE_LOCALES, devices=DEVICE_FOLDERS) -> list[ScreenshotGroup]:
    return [scan_group(root, locale, device) for locale in locales for device in devices]


def merge_groups(groups: list[ScreenshotGroup]) -> list[ScreenshotGroup]:
    """Folders -> store sets. A set is refused as a whole when any of its folders is invalid,
    so a half-valid merge can never delete the other half's images."""
    index = {(g.locale, g.device): g for g in groups}
    merged: list[ScreenshotGroup] = []
    for locale in dict.fromkeys(g.locale for g in groups):
        for set_name, parts in STORE_SETS.items():
            present = [(index[(locale, folder)], prefix) for folder, prefix in parts if (locale, folder) in index]
            if not present:
                continue
            group = ScreenshotGroup(locale, set_name, DISPLAY_TYPES[parts[0][0]])
            for part, prefix in present:
                group.errors.extend(part.errors)
                for f in part.files:
                    group.files.append(LocalScreenshot(f.path, prefix + f.file_name, f.md5, f.size_bytes, f.pixels))
            if len(present) != len(parts) and not group.errors:
                group.errors.append("set needs all of its folders: " + ", ".join(p[0] for p in parts))
            if len(group.files) > MAX_SCREENSHOTS_PER_SET:
                group.errors.append(f"{len(group.files)} files in one store set, store allows {MAX_SCREENSHOTS_PER_SET}")
            merged.append(group)
    return merged


# ---------------------------------------------------------------- store side

@dataclass
class RemoteScreenshot:
    id: str
    file_name: str
    checksum: str
    state: str


def fetch_remote(api, set_id: str) -> list[RemoteScreenshot]:
    """Remote screenshots of a set in display order."""
    order = [d["id"] for d in api.get(f"/appScreenshotSets/{set_id}/relationships/appScreenshots",
                                       {"limit": 200}).get("data", [])]
    items = {d["id"]: d for d in api.get_all(f"/appScreenshotSets/{set_id}/appScreenshots")}
    result = []
    for sid in order + [i for i in items if i not in order]:
        attrs = items.get(sid, {}).get("attributes", {})
        state = (attrs.get("assetDeliveryState") or {}).get("state", "")
        result.append(RemoteScreenshot(sid, attrs.get("fileName", ""), (attrs.get("sourceFileChecksum") or "").lower(), state))
    return result


@dataclass
class GroupDiff:
    keep: list[str] = field(default_factory=list)          # local file names unchanged
    upload: list[str] = field(default_factory=list)        # not on the store
    replace: list[tuple[str, str]] = field(default_factory=list)  # (file name, remote id to delete)
    delete: list[RemoteScreenshot] = field(default_factory=list)

    @property
    def changed(self) -> bool:
        return bool(self.upload or self.replace or self.delete)


BAD_STATES = {"FAILED", "AWAITING_UPLOAD"}


def diff_group(local: list[LocalScreenshot], remote: list[RemoteScreenshot]) -> GroupDiff:
    diff = GroupDiff()
    unmatched_remote = list(remote)
    unmatched_local: list[LocalScreenshot] = []

    def take(predicate):
        for r in unmatched_remote:
            if predicate(r):
                unmatched_remote.remove(r)
                return r
        return None

    for item in local:  # pass 1: by file name
        r = take(lambda x, n=item.file_name: x.file_name == n)
        if r is None:
            unmatched_local.append(item)
        elif r.checksum == item.md5 and r.state not in BAD_STATES:
            diff.keep.append(item.file_name)
        else:
            diff.replace.append((item.file_name, r.id))
    for item in unmatched_local:  # pass 2: renamed but identical content is not re-uploaded
        r = take(lambda x, m=item.md5: x.checksum == m and x.state not in BAD_STATES)
        if r is not None:
            diff.keep.append(item.file_name)
        else:
            diff.upload.append(item.file_name)
    diff.delete = unmatched_remote  # remote images with no local counterpart
    return diff


def target_order(local: list[LocalScreenshot]) -> list[str]:
    return [s.file_name for s in sorted(local, key=lambda s: s.file_name)]


def matched_ids(local: list[LocalScreenshot], remote: list[RemoteScreenshot]) -> list[str]:
    """Remote ids for the local files, in local (file name) order. Same matching as diff_group;
    local files without a good remote counterpart are left out."""
    pool = [r for r in remote if r.state not in BAD_STATES]
    ordered = sorted(local, key=lambda s: s.file_name)
    by_slot: dict[str, str] = {}
    for item in ordered:
        for r in pool:
            if r.file_name == item.file_name and r.checksum == item.md5:
                by_slot[item.file_name] = r.id
                pool.remove(r)
                break
    for item in ordered:
        if item.file_name in by_slot:
            continue
        for r in pool:
            if r.checksum == item.md5:
                by_slot[item.file_name] = r.id
                pool.remove(r)
                break
    return [by_slot[s.file_name] for s in ordered if s.file_name in by_slot]


# ---------------------------------------------------------------- operations

def ensure_set(api, localization_id: str, display_type: str, create: bool) -> str | None:
    for item in api.get_all(f"/appStoreVersionLocalizations/{localization_id}/appScreenshotSets"):
        if item["attributes"]["screenshotDisplayType"] == display_type:
            return item["id"]
    if not create:
        return None
    body = {"data": {"type": "appScreenshotSets", "attributes": {"screenshotDisplayType": display_type},
                     "relationships": {"appStoreVersionLocalization": {
                         "data": {"type": "appStoreVersionLocalizations", "id": localization_id}}}}}
    return api.post("/appScreenshotSets", body)["data"]["id"]


def upload_one(api, set_id: str, shot: LocalScreenshot, sleep=time.sleep, timeout: float = 300) -> str:
    """Reserve -> upload parts -> commit with MD5 -> wait for processing (R4)."""
    reservation = api.post("/appScreenshots", {"data": {
        "type": "appScreenshots",
        "attributes": {"fileName": shot.file_name, "fileSize": shot.size_bytes},
        "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": set_id}}}}})
    shot_id = reservation["data"]["id"]
    data = shot.path.read_bytes()
    for op in reservation["data"]["attributes"].get("uploadOperations") or []:
        headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        api.put_part(op["url"], headers, data[op["offset"]:op["offset"] + op["length"]])
    api.patch(f"/appScreenshots/{shot_id}", {"data": {"type": "appScreenshots", "id": shot_id,
              "attributes": {"uploaded": True, "sourceFileChecksum": shot.md5}}})
    waited = 0.0
    while True:
        state = (api.get(f"/appScreenshots/{shot_id}")["data"]["attributes"].get("assetDeliveryState") or {}).get("state")
        if state == "COMPLETE":
            return shot_id
        if state == "FAILED" or waited >= timeout:
            api.delete(f"/appScreenshots/{shot_id}")  # next run starts clean (FR-012)
            raise StoreError(f"{shot.file_name}: store reported {state or 'timeout'} while processing")
        sleep(2)
        waited += 2


def apply_order(api, set_id: str, local: list[LocalScreenshot]) -> bool:
    """Sets the order once, only if it differs. Returns True when a write happened."""
    remote = fetch_remote(api, set_id)
    ids = matched_ids(local, remote)
    if [r.id for r in remote] == ids:
        return False
    api.patch(f"/appScreenshotSets/{set_id}/relationships/appScreenshots",
              {"data": [{"type": "appScreenshots", "id": i} for i in ids]})
    return True


def plan_group(api, group: ScreenshotGroup, localization_id: str, sleep=time.sleep) -> list[Action]:
    """Actions that make the store group equal the local group (read-only until run)."""
    locale, device = group.locale, group.device
    label = f"{device}"
    set_id = ensure_set(api, localization_id, group.display_type, create=False)
    remote = fetch_remote(api, set_id) if set_id else []
    diff = diff_group(group.files, remote)
    by_name = {s.file_name: s for s in group.files}
    state: dict[str, str | None] = {"set_id": set_id}
    actions: list[Action] = []

    def need_set():
        if state["set_id"] is None:
            state["set_id"] = ensure_set(api, localization_id, group.display_type, create=True)
        return state["set_id"]

    for name in diff.keep:
        actions.append(Action("skip_unchanged", f"{label}/{name}", locale, "content identical"))
    for name, remote_id in diff.replace:
        def run(n=name, rid=remote_id):
            api.delete(f"/appScreenshots/{rid}")
            upload_one(api, need_set(), by_name[n], sleep)
        actions.append(Action("replace", f"{label}/{name}", locale, "content changed or broken upload", run))
    for name in diff.upload:
        actions.append(Action("upload", f"{label}/{name}", locale, "", lambda n=name: upload_one(api, need_set(), by_name[n], sleep)))
    for r in diff.delete:
        actions.append(Action("delete", f"{label}/{r.file_name or r.id}", locale, "not in local set",
                              lambda rid=r.id: api.delete(f"/appScreenshots/{rid}")))
    ids_now = [r.id for r in remote]
    if diff.changed or (set_id is not None and matched_ids(group.files, remote) != ids_now):
        actions.append(Action("reorder", label, locale, "only if order differs",
                              lambda: apply_order(api, need_set(), group.files)))
    return actions
