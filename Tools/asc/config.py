"""Credentials, target version and build number (FR-001, FR-002, FR-021).

Values from `.env` are never printed. Version and build number are read-only inputs.
"""
from __future__ import annotations

import os
import re
from dataclasses import dataclass, field
from pathlib import Path

from .errors import ConfigError

ROOT = Path(__file__).resolve().parents[2]
BUNDLE_ID = "de.juuronina.logweight"
REQUIRED_VARS = ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_PATH")


@dataclass(frozen=True)
class Credentials:
    key_id: str = field(repr=False)
    issuer_id: str = field(repr=False)
    key_path: Path = field(repr=False)

    def __repr__(self) -> str:  # never leak values
        return "Credentials(<redacted>)"

    def read_private_key(self) -> str:
        try:
            return self.key_path.read_text()
        except OSError:
            raise ConfigError("ASC_KEY_PATH: key file is missing or unreadable") from None

    def secret_values(self) -> list[str]:
        return [self.key_id, self.issuer_id, str(self.key_path)]


def _parse_env_file(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    try:
        text = path.read_text()
    except OSError:
        return values
    for raw in text.splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        if line.startswith("export "):
            line = line[len("export "):]
        name, _, value = line.partition("=")
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        values[name.strip()] = value
    return values


def load_credentials(env_path: str | os.PathLike | None = None, environ=None) -> Credentials:
    """Reads the three variables from the environment first, then the env file."""
    environ = os.environ if environ is None else environ
    path = Path(env_path) if env_path else ROOT / ".env"
    file_values = _parse_env_file(path)
    resolved: dict[str, str] = {}
    for name in REQUIRED_VARS:
        value = environ.get(name) or file_values.get(name)
        if not value:
            raise ConfigError(f"{name} is not set (environment or {path.name})")
        resolved[name] = value
    key_path = Path(os.path.expanduser(resolved["ASC_KEY_PATH"]))
    if not key_path.is_file():
        raise ConfigError("ASC_KEY_PATH does not point to a readable file")
    return Credentials(resolved["ASC_KEY_ID"], resolved["ASC_ISSUER_ID"], key_path)


def read_marketing_version(project_yml: Path | None = None) -> str:
    path = project_yml or ROOT / "project.yml"
    match = re.search(r'^\s*MARKETING_VERSION:\s*"?([0-9][0-9A-Za-z.\-]*)"?', path.read_text(), re.M)
    if not match:
        raise ConfigError(f"MARKETING_VERSION not found in {path.name}")
    return match.group(1)


def read_build_number(xcconfig: Path | None = None) -> str:
    path = xcconfig or ROOT / "Config" / "Version.xcconfig"
    match = re.search(r"^\s*CURRENT_PROJECT_VERSION\s*=\s*([0-9]+)", path.read_text(), re.M)
    if not match:
        raise ConfigError(f"CURRENT_PROJECT_VERSION not found in {path.name}")
    return match.group(1)


def resolve_version(explicit: str | None, project_yml: Path | None = None) -> str:
    return explicit or read_marketing_version(project_yml)
