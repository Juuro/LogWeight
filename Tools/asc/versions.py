"""App/version lookup and creation, localizations, text updates, build attach.

Spec: FR-002, FR-007, FR-008, FR-014, FR-016, FR-019; research R1, R7, R9.
Nothing in here calls review-submission endpoints (FR-014).
"""
from __future__ import annotations

from dataclasses import dataclass

from .errors import AscError, NotEditableError, StoreError
from .plan import Action
from .texts import APP_INFO_FIELDS, VERSION_FIELDS, TextSet, diff_fields

EDITABLE_STATES = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED"}


@dataclass
class StoreVersion:
    id: str
    version_string: str
    state: str

    @property
    def editable(self) -> bool:
        return self.state in EDITABLE_STATES


def find_app(api, bundle_id: str) -> str:
    apps = api.get_all("/apps", {"filter[bundleId]": bundle_id})
    if not apps:
        raise StoreError(f"no app with bundle id {bundle_id} in this account")
    return apps[0]["id"]


def _state(attrs: dict) -> str:
    return attrs.get("appVersionState") or attrs.get("appStoreState") or ""


def find_version(api, app_id: str, version: str) -> StoreVersion | None:
    for item in api.get_all(f"/apps/{app_id}/appStoreVersions", {"filter[platform]": "IOS"}):
        attrs = item["attributes"]
        if attrs.get("versionString") == version:
            return StoreVersion(item["id"], version, _state(attrs))
    return None


def existing_version_strings(api, app_id: str) -> list[str]:
    return [i["attributes"]["versionString"]
            for i in api.get_all(f"/apps/{app_id}/appStoreVersions", {"filter[platform]": "IOS"})]


def create_version(api, app_id: str, version: str) -> StoreVersion:
    body = {"data": {"type": "appStoreVersions",
                     "attributes": {"platform": "IOS", "versionString": version},
                     "relationships": {"app": {"data": {"type": "apps", "id": app_id}}}}}
    item = api.post("/appStoreVersions", body)["data"]
    return StoreVersion(item["id"], version, _state(item["attributes"]) or "PREPARE_FOR_SUBMISSION")


def require_editable(version: StoreVersion) -> None:
    if not version.editable:
        raise NotEditableError(f"version {version.version_string} is in state {version.state or 'unknown'} and cannot be edited")


def _normalized(version: str) -> str:
    parts = version.split(".")
    while len(parts) > 1 and parts[-1] == "0":
        parts.pop()
    return ".".join(parts)


def same_version(a: str, b: str) -> bool:
    """1.1 and 1.1.0 name the same release; the store decides at attach time whether it accepts that."""
    return a == b or _normalized(a) == _normalized(b)


class Context:
    """Shared between actions of one run: the target version once it exists."""

    def __init__(self, version: StoreVersion | None = None):
        self.version = version

    def require(self) -> StoreVersion:
        if self.version is None:
            raise StoreError("target version does not exist (preview only?)")
        return self.version


def plan_version(api, app_id: str, version: str, ctx: Context) -> list[Action]:
    """Sets ctx.version when the version exists; otherwise plans its creation (FR-016)."""
    found = find_version(api, app_id, version)
    if found is not None:
        require_editable(found)
        ctx.version = found
        return []
    others = existing_version_strings(api, app_id)
    lookalike = [o for o in others if _normalized(o) == _normalized(version)]
    if lookalike:  # never create a second, near-identical version (R7)
        raise AscError(f"the store has version {lookalike[0]} but the target is {version}; "
                       f"re-run with --version {lookalike[0]} or align the project version")
    hint = f" (store has: {', '.join(others)})" if others else ""

    def run():
        ctx.version = create_version(api, app_id, version)

    return [Action("create_version", version, "-", "version not in the store" + hint, run)]


def version_localizations(api, version_id: str) -> dict[str, dict]:
    """locale -> {id, promotionalText, description, keywords}."""
    result = {}
    for item in api.get_all(f"/appStoreVersions/{version_id}/appStoreVersionLocalizations"):
        attrs = item["attributes"]
        result[attrs["locale"]] = {"id": item["id"], **{f: attrs.get(f) for f in VERSION_FIELDS}}
    return result


def editable_app_info(api, app_id: str) -> str:
    infos = api.get_all(f"/apps/{app_id}/appInfos")
    for info in infos:
        if _state(info["attributes"]) in EDITABLE_STATES | {""}:
            return info["id"]
    raise NotEditableError("the app info (subtitle) is not editable in the current store state")


def app_info_localizations(api, app_info_id: str) -> dict[str, dict]:
    result = {}
    for item in api.get_all(f"/appInfos/{app_info_id}/appInfoLocalizations"):
        attrs = item["attributes"]
        result[attrs["locale"]] = {"id": item["id"], "subtitle": attrs.get("subtitle")}
    return result


def plan_texts(api, version: StoreVersion, app_id: str, texts: dict[str, TextSet], locales) -> list[Action]:
    version_locs = version_localizations(api, version.id)
    info_locs = app_info_localizations(api, editable_app_info(api, app_id))
    actions: list[Action] = []
    for locale in locales:
        local = texts[locale]
        if locale not in version_locs or locale not in info_locs:
            actions.append(Action("skip_unchanged", "texts", locale, "locale not enabled in the store, not created"))
            continue
        vchanged = diff_fields(local, version_locs[locale], VERSION_FIELDS)
        ichanged = diff_fields(local, info_locs[locale], APP_INFO_FIELDS)
        if not vchanged and not ichanged:
            actions.append(Action("skip_unchanged", "texts", locale, "all four fields identical"))
            continue
        if vchanged:
            loc_id = version_locs[locale]["id"]
            actions.append(Action("update_text", ", ".join(sorted(vchanged)), locale, "version localization",
                                  lambda i=loc_id, c=vchanged: api.patch(
                                      f"/appStoreVersionLocalizations/{i}",
                                      {"data": {"type": "appStoreVersionLocalizations", "id": i, "attributes": c}})))
        if ichanged:
            loc_id = info_locs[locale]["id"]
            actions.append(Action("update_text", ", ".join(sorted(ichanged)), locale, "app info localization",
                                  lambda i=loc_id, c=ichanged: api.patch(
                                      f"/appInfoLocalizations/{i}",
                                      {"data": {"type": "appInfoLocalizations", "id": i, "attributes": c}})))
    return actions


def attached_build_id(api, version_id: str) -> str | None:
    data = api.get(f"/appStoreVersions/{version_id}/relationships/build").get("data")
    return data["id"] if data else None


def attach_build(api, version_id: str, build_id: str) -> None:
    api.patch(f"/appStoreVersions/{version_id}/relationships/build",
              {"data": {"type": "builds", "id": build_id}})
