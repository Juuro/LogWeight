"""Thin App Store Connect REST client: ES256 JWT, pagination, retry, redaction (R10).

Everything else talks to this small interface (get, get_all, post, patch, delete,
put_part), which tests replace with an in-memory fake.
"""
from __future__ import annotations

import json
import time
import urllib.error
import urllib.parse
import urllib.request

from .config import Credentials
from .errors import StoreError

BASE_URL = "https://api.appstoreconnect.apple.com"
TOKEN_LIFETIME = 15 * 60
RETRY_STATUSES = {429, 500, 502, 503, 504}


class ApiError(StoreError):
    def __init__(self, status: int, detail: str):
        super().__init__(f"App Store Connect API error {status}: {detail}")
        self.status = status
        self.detail = detail


class ApiClient:
    def __init__(self, credentials: Credentials, sleep=time.sleep, max_attempts: int = 5):
        self._credentials = credentials
        self._sleep = sleep
        self._max_attempts = max_attempts
        self._token: str | None = None
        self._token_expiry = 0.0

    def _auth_header(self) -> str:
        now = time.time()
        if self._token is None or now > self._token_expiry - 60:
            import jwt  # PyJWT, lazy so tests and `--help` need no crypto

            self._token_expiry = now + TOKEN_LIFETIME
            self._token = jwt.encode(
                {"iss": self._credentials.issuer_id, "iat": int(now), "exp": int(self._token_expiry),
                 "aud": "appstoreconnect-v1"},
                self._credentials.read_private_key(),
                algorithm="ES256",
                headers={"kid": self._credentials.key_id, "typ": "JWT"},
            )
        return f"Bearer {self._token}"

    def _url(self, path: str, params: dict | None) -> str:
        url = path if path.startswith("http") else f"{BASE_URL}/v1{path}"
        if params:
            url += ("&" if "?" in url else "?") + urllib.parse.urlencode(params)
        return url

    def _send(self, method: str, url: str, body: dict | None = None, headers: dict | None = None,
              raw: bytes | None = None, auth: bool = True) -> dict:
        data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
        hdrs = dict(headers or {})
        if auth:
            hdrs["Authorization"] = self._auth_header()
        if body is not None:
            hdrs["Content-Type"] = "application/json"
        for attempt in range(1, self._max_attempts + 1):
            request = urllib.request.Request(url, data=data, method=method, headers=hdrs)
            try:
                with urllib.request.urlopen(request, timeout=120) as response:
                    payload = response.read()
                    return json.loads(payload) if payload and auth else {}
            except urllib.error.HTTPError as err:
                if err.code in RETRY_STATUSES and attempt < self._max_attempts:
                    self._sleep(min(2 ** attempt, 30))
                    continue
                detail = _error_detail(err)
                raise ApiError(err.code, detail) from None
            except urllib.error.URLError as err:
                if attempt < self._max_attempts:
                    self._sleep(min(2 ** attempt, 30))
                    continue
                raise StoreError(f"network error: {err.reason}") from None
        raise StoreError("unreachable")

    def get(self, path: str, params: dict | None = None) -> dict:
        return self._send("GET", self._url(path, params))

    def get_all(self, path: str, params: dict | None = None) -> list[dict]:
        params = dict(params or {})
        params.setdefault("limit", 200)
        url = self._url(path, params)
        items: list[dict] = []
        while url:
            page = self._send("GET", url)
            items.extend(page.get("data", []))
            url = page.get("links", {}).get("next")
        return items

    def post(self, path: str, body: dict) -> dict:
        return self._send("POST", self._url(path, None), body)

    def patch(self, path: str, body: dict) -> dict:
        return self._send("PATCH", self._url(path, None), body)

    def delete(self, path: str) -> None:
        self._send("DELETE", self._url(path, None))

    def put_part(self, url: str, headers: dict, data: bytes) -> None:
        self._send("PUT", url, headers=headers, raw=data, auth=False)


def _error_detail(err: urllib.error.HTTPError) -> str:
    try:
        errors = json.loads(err.read()).get("errors", [])
        return "; ".join(f"{e.get('code', '?')}: {e.get('detail') or e.get('title', '')}" for e in errors) or err.reason
    except Exception:
        return str(err.reason)
