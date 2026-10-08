"""Archive, export+upload, wait for processing, attach (User Story 6, R8, R9).

Resume rule for an existing build with the same number and marketing version:
VALID -> skip archive/upload, go on to attach; PROCESSING -> skip upload, wait;
INVALID/FAILED -> stop, because only the versioning process may change the number.
"""
from __future__ import annotations

import subprocess
import time
from dataclasses import dataclass
from pathlib import Path

from .config import ROOT, Credentials
from .errors import StoreError
from .plan import Action
from .versions import attach_build, attached_build_id, same_version

ARCHIVE_PATH = ROOT / "tmp" / "release" / "LogWeight.xcarchive"
EXPORT_PATH = ROOT / "tmp" / "release" / "export"
EXPORT_OPTIONS = ROOT / "Tools" / "asc" / "ExportOptions.plist"
WAIT_SECONDS = 30 * 60


@dataclass
class StoreBuild:
    id: str
    number: str
    marketing_version: str
    state: str


def find_builds(api, app_id: str, number: str) -> list[StoreBuild]:
    items = api.get_all("/builds", {"filter[app]": app_id, "filter[version]": number, "include": "preReleaseVersion"})
    result = []
    for item in items:
        pre = item.get("relationships", {}).get("preReleaseVersion", {}).get("data") or {}
        result.append(StoreBuild(item["id"], number, _pre_version(api, item, pre), item["attributes"].get("processingState", "")))
    return result


def _pre_version(api, item: dict, pre: dict) -> str:
    inline = item["attributes"].get("preReleaseVersion")
    if inline:
        return inline
    if pre.get("id"):
        return api.get(f"/preReleaseVersions/{pre['id']}")["data"]["attributes"]["version"]
    return ""


def verify_archive(archive: Path) -> None:
    """The archive must embed the Watch app and the extensions (FR-017)."""
    apps = list((archive / "Products" / "Applications").glob("*.app"))
    if not apps:
        raise StoreError("archive contains no application")
    app = apps[0]
    if not any((app / "Watch").glob("*.app")):
        raise StoreError("archive does not embed the Apple Watch app")
    if not any((app / "PlugIns").glob("*.appex")):
        raise StoreError("archive contains no app extensions (widget)")


def auth_flags(credentials: Credentials) -> list[str]:
    return ["-allowProvisioningUpdates", "-authenticationKeyPath", str(credentials.key_path),
            "-authenticationKeyID", credentials.key_id, "-authenticationKeyIssuerID", credentials.issuer_id]


def default_runner(cmd: list[str]) -> None:
    result = subprocess.run(cmd, cwd=ROOT)
    if result.returncode != 0:
        raise StoreError(f"{cmd[0]} {cmd[1] if len(cmd) > 1 else ''} failed with exit code {result.returncode}")


def archive_commands(credentials: Credentials) -> list[list[str]]:
    return [
        ["xcodegen", "generate"],
        ["xcodebuild", "archive", "-project", "LogWeight.xcodeproj", "-scheme", "LogWeight",
         "-configuration", "Release", "-destination", "generic/platform=iOS",
         "-archivePath", str(ARCHIVE_PATH), *auth_flags(credentials)],
    ]


def export_command(credentials: Credentials) -> list[str]:
    return ["xcodebuild", "-exportArchive", "-archivePath", str(ARCHIVE_PATH),
            "-exportOptionsPlist", str(EXPORT_OPTIONS), "-exportPath", str(EXPORT_PATH), *auth_flags(credentials)]


def wait_for_build(api, app_id: str, number: str, marketing: str, sleep=time.sleep,
                   timeout: float = WAIT_SECONDS, interval: float = 30) -> StoreBuild:
    waited = 0.0
    while True:
        for b in find_builds(api, app_id, number):
            if (b.marketing_version == "" or same_version(b.marketing_version, marketing)) and b.state == "VALID":
                return b
            if b.state in ("INVALID", "FAILED"):
                raise StoreError(f"build {number} was rejected by the store (state {b.state})")
        if waited >= timeout:
            raise StoreError(f"build {number} is still processing after {int(timeout // 60)} minutes; re-run to keep waiting")
        sleep(interval)
        waited += interval


def plan_build(api, app_id: str, ctx, marketing: str, number: str, credentials: Credentials,
               runner=default_runner, sleep=time.sleep, wait_timeout: float = WAIT_SECONDS) -> list[Action]:
    """ctx.version may still be None at plan time (created by an earlier action in the same run)."""
    builds = find_builds(api, app_id, number)
    for b in builds:
        if b.marketing_version and not same_version(b.marketing_version, marketing):
            raise StoreError(f"build number {number} is already used by version {b.marketing_version}, not {marketing}; "
                             "the number can only be changed by the versioning process")
        if b.state in ("INVALID", "FAILED"):
            raise StoreError(f"build number {number} is already used by an unusable build ({b.state}); "
                             "the number can only be changed by the versioning process")
    existing = builds[0] if builds else None
    found: dict = {"build": existing if existing and existing.state == "VALID" else None}
    actions: list[Action] = []

    if existing:
        actions.append(Action("skip_unchanged", f"archive+upload of build {number}", "-", f"already in the store ({existing.state})"))
    else:
        def do_archive():
            for cmd in archive_commands(credentials):
                runner(cmd)
            verify_archive(ARCHIVE_PATH)

        actions.append(Action("archive", f"{marketing} ({number})", "-", "xcodegen + xcodebuild archive", do_archive))
        actions.append(Action("upload_build", f"{marketing} ({number})", "-", "xcodebuild -exportArchive (upload)",
                              lambda: runner(export_command(credentials))))
    if found["build"] is None:
        def do_wait():
            found["build"] = wait_for_build(api, app_id, number, marketing, sleep, wait_timeout)

        actions.append(Action("wait_processing", f"build {number}", "-", "until processing is VALID", do_wait))

    if ctx.version is not None and found["build"] is not None and attached_build_id(api, ctx.version.id) == found["build"].id:
        actions.append(Action("skip_unchanged", f"attach build {number}", "-", "already attached"))
        return actions

    def do_attach():
        build = found["build"]
        if build.marketing_version and not same_version(build.marketing_version, marketing):
            raise StoreError(f"build is for {build.marketing_version}, target is {marketing}; not attaching")
        version = ctx.require()
        if attached_build_id(api, version.id) != build.id:
            attach_build(api, version.id, build.id)

    actions.append(Action("attach_build", f"build {number} -> {marketing}", "-", "", do_attach))
    return actions
