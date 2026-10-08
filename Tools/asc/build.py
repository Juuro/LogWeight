"""Archive, export+upload, wait for processing, attach (User Story 6, R8, R9).

Resume rule for an existing build with the same number and marketing version:
VALID -> skip archive/upload, go on to attach; PROCESSING -> skip upload, wait;
INVALID/FAILED -> stop, because only the versioning process may change the number.
"""
from __future__ import annotations

import plistlib
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


def _bundle_version(bundle: Path) -> str:
    with (bundle / "Info.plist").open("rb") as handle:
        return str(plistlib.load(handle).get("CFBundleVersion", ""))


def verify_archive(archive: Path, expected_number: str | None = None, check_signature: bool = False) -> None:
    """The archive must embed the Watch app and the extensions (FR-017), every bundle must carry the
    expected build number, and the signature must still verify (the number is written after compile)."""
    apps = list((archive / "Products" / "Applications").glob("*.app"))
    if not apps:
        raise StoreError("archive contains no application")
    app = apps[0]
    watch_apps = list((app / "Watch").glob("*.app"))
    if not watch_apps:
        raise StoreError("archive does not embed the Apple Watch app")
    extensions = list((app / "PlugIns").glob("*.appex"))
    if not extensions:
        raise StoreError("archive contains no app extensions (widget)")
    if expected_number is not None:
        bundles = [app, *watch_apps, *extensions, *(b for w in watch_apps for b in (w / "PlugIns").glob("*.appex"))]
        wrong = [f"{b.name}={_bundle_version(b) or '?'}" for b in bundles if _bundle_version(b) != expected_number]
        if wrong:
            raise StoreError(f"archive build number mismatch (expected {expected_number}): {', '.join(wrong)}")
    if check_signature:
        result = subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], capture_output=True, text=True)
        if result.returncode != 0:
            raise StoreError("archive signature does not verify: " + result.stderr.strip().splitlines()[-1])


def check_release_commit(run_git=None) -> None:
    """Builds for the store come from a clean checkout of a commit that is already on origin/main:
    the git-derived build number is only unique per main history (spec FR-020/FR-021)."""
    from .errors import ValidationError

    def git(*args):
        if run_git is not None:
            return run_git(*args)
        return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True)

    if git("status", "--porcelain", "--untracked-files=no").stdout.strip():
        raise ValidationError("working tree has uncommitted changes; commit or stash them before building a release")
    if git("merge-base", "--is-ancestor", "HEAD", "origin/main").returncode != 0:
        raise ValidationError("HEAD is not on origin/main (fetch first); store builds must come from merged commits "
                              "(override with --allow-unmerged)")


def auth_flags(credentials: Credentials) -> list[str]:
    return ["-allowProvisioningUpdates", "-authenticationKeyPath", str(credentials.key_path),
            "-authenticationKeyID", credentials.key_id, "-authenticationKeyIssuerID", credentials.issuer_id]


def default_runner(cmd: list[str]) -> None:
    result = subprocess.run(cmd, cwd=ROOT)
    if result.returncode != 0:
        raise StoreError(f"{cmd[0]} {cmd[1] if len(cmd) > 1 else ''} failed with exit code {result.returncode}")


def redacting_runner(secrets: list[str]):
    """Runs a command and streams its output with credential values replaced (xcodebuild echoes
    its own command line, which contains the key id, issuer id and key path)."""
    needles = [s for s in secrets if s]

    def run(cmd: list[str]) -> None:
        proc = subprocess.Popen(cmd, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
        assert proc.stdout is not None
        with proc.stdout:
            for line in proc.stdout:
                for needle in needles:
                    line = line.replace(needle, "<redacted>")
                print(line, end="", flush=True)
        if proc.wait() != 0:
            raise StoreError(f"{cmd[0]} {cmd[1] if len(cmd) > 1 else ''} failed with exit code {proc.returncode}")

    return run


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
            verify_archive(ARCHIVE_PATH, number, check_signature=True)

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
