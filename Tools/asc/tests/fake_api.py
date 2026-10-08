"""In-memory stand-in for the App Store Connect API (only the endpoints the tool uses)."""
from __future__ import annotations

import itertools
import re


class FakeApi:
    def __init__(self):
        self._ids = itertools.count(1)
        self.writes: list[tuple[str, str]] = []
        self.apps = {"app1": {"bundleId": "de.juuronina.logweight"}}
        self.versions: dict[str, dict] = {}          # id -> attrs
        self.version_locs: dict[str, dict] = {}       # id -> {version, locale, promotionalText, description, keywords}
        self.app_info = {"info1": {"appStoreState": "PREPARE_FOR_SUBMISSION"}}
        self.info_locs: dict[str, dict] = {}
        self.sets: dict[str, dict] = {}               # id -> {loc, type, shots: [ids]}
        self.shots: dict[str, dict] = {}
        self.builds: dict[str, dict] = {}
        self.attached: dict[str, str | None] = {}
        self.uploaded_parts: list[tuple[str, int]] = []
        self.fail_processing = False

    # ---- fixtures
    def add_version(self, version="1.1.0", state="PREPARE_FOR_SUBMISSION", locales=("de-DE",)):
        vid = f"v{next(self._ids)}"
        self.versions[vid] = {"versionString": version, "appStoreState": state, "platform": "IOS"}
        for locale in locales:
            self.version_locs[f"vl{next(self._ids)}"] = {"version": vid, "locale": locale,
                                                         "promotionalText": "", "description": "", "keywords": "", "whatsNew": ""}
            self.info_locs[f"il{next(self._ids)}"] = {"locale": locale, "subtitle": ""}
        return vid

    def loc_id(self, locale):
        return next(i for i, v in self.version_locs.items() if v["locale"] == locale)

    def add_build(self, number, state="VALID", version="1.1.0"):
        bid = f"b{next(self._ids)}"
        self.builds[bid] = {"version": number, "processingState": state, "preReleaseVersion": version}
        return bid

    def add_remote_shot(self, set_id, name, checksum, state="COMPLETE"):
        sid = f"s{next(self._ids)}"
        self.shots[sid] = {"fileName": name, "sourceFileChecksum": checksum, "state": state, "set": set_id}
        self.sets[set_id]["shots"].append(sid)
        return sid

    def add_set(self, locale, display_type):
        set_id = f"set{next(self._ids)}"
        self.sets[set_id] = {"loc": self.loc_id(locale), "type": display_type, "shots": []}
        return set_id

    # ---- interface used by the tool
    def get(self, path, params=None):
        params = params or {}
        if m := re.fullmatch(r"/appScreenshotSets/(\w+)/relationships/appScreenshots", path):
            return {"data": [{"type": "appScreenshots", "id": i} for i in self.sets[m[1]]["shots"]]}
        if m := re.fullmatch(r"/appScreenshots/(\w+)", path):
            s = self.shots[m[1]]
            return {"data": {"id": m[1], "attributes": {"fileName": s["fileName"], "assetDeliveryState": {"state": s["state"]}}}}
        if m := re.fullmatch(r"/appStoreVersions/(\w+)/relationships/build", path):
            bid = self.attached.get(m[1])
            return {"data": {"type": "builds", "id": bid} if bid else None}
        if m := re.fullmatch(r"/preReleaseVersions/(\w+)", path):
            return {"data": {"attributes": {"version": m[1]}}}
        raise AssertionError(f"unexpected GET {path}")

    def get_all(self, path, params=None):
        params = params or {}
        if path == "/apps":
            return [{"id": i, "attributes": a} for i, a in self.apps.items()
                    if a["bundleId"] == params.get("filter[bundleId]")]
        if re.fullmatch(r"/apps/\w+/appStoreVersions", path):
            return [{"id": i, "attributes": a} for i, a in self.versions.items()]
        if re.fullmatch(r"/apps/\w+/appInfos", path):
            return [{"id": i, "attributes": a} for i, a in self.app_info.items()]
        if m := re.fullmatch(r"/appStoreVersions/(\w+)/appStoreVersionLocalizations", path):
            return [{"id": i, "attributes": {k: v for k, v in a.items() if k != "version"}}
                    for i, a in self.version_locs.items() if a["version"] == m[1]]
        if re.fullmatch(r"/appInfos/\w+/appInfoLocalizations", path):
            return [{"id": i, "attributes": dict(a)} for i, a in self.info_locs.items()]
        if m := re.fullmatch(r"/appStoreVersionLocalizations/(\w+)/appScreenshotSets", path):
            return [{"id": i, "attributes": {"screenshotDisplayType": s["type"]}}
                    for i, s in self.sets.items() if s["loc"] == m[1]]
        if m := re.fullmatch(r"/appScreenshotSets/(\w+)/appScreenshots", path):
            return [{"id": i, "attributes": {"fileName": self.shots[i]["fileName"],
                                              "sourceFileChecksum": self.shots[i]["sourceFileChecksum"],
                                              "assetDeliveryState": {"state": self.shots[i]["state"]}}}
                    for i in self.sets[m[1]]["shots"]]
        if path == "/builds":
            return [{"id": i, "attributes": {"processingState": b["processingState"],
                                             "preReleaseVersion": b["preReleaseVersion"]},
                     "relationships": {}}
                    for i, b in self.builds.items() if b["version"] == params.get("filter[version]")]
        raise AssertionError(f"unexpected GET-all {path}")

    def post(self, path, body):
        self.writes.append(("POST", path))
        data = body["data"]
        if path == "/appStoreVersions":
            vid = f"v{next(self._ids)}"
            self.versions[vid] = {"versionString": data["attributes"]["versionString"],
                                  "appStoreState": "PREPARE_FOR_SUBMISSION"}
            return {"data": {"id": vid, "attributes": self.versions[vid]}}
        if path == "/appScreenshotSets":
            set_id = f"set{next(self._ids)}"
            self.sets[set_id] = {"loc": data["relationships"]["appStoreVersionLocalization"]["data"]["id"],
                                 "type": data["attributes"]["screenshotDisplayType"], "shots": []}
            return {"data": {"id": set_id, "attributes": {}}}
        if path == "/appScreenshots":
            sid = f"s{next(self._ids)}"
            set_id = data["relationships"]["appScreenshotSet"]["data"]["id"]
            self.shots[sid] = {"fileName": data["attributes"]["fileName"], "sourceFileChecksum": "",
                               "state": "AWAITING_UPLOAD", "set": set_id}
            self.sets[set_id]["shots"].append(sid)
            size = data["attributes"]["fileSize"]
            return {"data": {"id": sid, "attributes": {"uploadOperations": [
                {"method": "PUT", "url": f"https://upload.invalid/{sid}", "offset": 0, "length": size,
                 "requestHeaders": [{"name": "Content-Type", "value": "image/png"}]}]}}}
        raise AssertionError(f"unexpected POST {path}")

    def put_part(self, url, headers, data):
        self.writes.append(("PUT", url))
        self.uploaded_parts.append((url, len(data)))

    def patch(self, path, body):
        self.writes.append(("PATCH", path))
        data = body["data"]
        if m := re.fullmatch(r"/appScreenshots/(\w+)", path):
            self.shots[m[1]]["sourceFileChecksum"] = data["attributes"]["sourceFileChecksum"]
            self.shots[m[1]]["state"] = "FAILED" if self.fail_processing else "COMPLETE"
            return {}
        if m := re.fullmatch(r"/appScreenshotSets/(\w+)/relationships/appScreenshots", path):
            self.sets[m[1]]["shots"] = [d["id"] for d in data]
            return {}
        if m := re.fullmatch(r"/appStoreVersionLocalizations/(\w+)", path):
            self.version_locs[m[1]].update(data["attributes"])
            return {}
        if m := re.fullmatch(r"/appInfoLocalizations/(\w+)", path):
            self.info_locs[m[1]].update(data["attributes"])
            return {}
        if m := re.fullmatch(r"/appStoreVersions/(\w+)/relationships/build", path):
            self.attached[m[1]] = data["id"]
            return {}
        raise AssertionError(f"unexpected PATCH {path}")

    def delete(self, path):
        self.writes.append(("DELETE", path))
        if m := re.fullmatch(r"/appScreenshots/(\w+)", path):
            sid = m[1]
            self.sets[self.shots[sid]["set"]]["shots"].remove(sid)
            del self.shots[sid]
            return
        raise AssertionError(f"unexpected DELETE {path}")

    # ---- assertions helpers
    def write_paths(self):
        return [p for _, p in self.writes]
