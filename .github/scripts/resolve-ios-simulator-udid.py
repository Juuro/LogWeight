#!/usr/bin/env python3
"""Print UDID of the first available iOS simulator matching preferred device names."""

from __future__ import annotations

import json
import subprocess
import sys

# Match historical CI (~8m runs): iPad (10th generation) with tabBarOnly in MainTabView.
PREFERRED_NAMES = (
    "iPad (10th generation)",
    "iPad (A16)",
    "iPhone 16",
    "iPhone 16 Pro",
)


def main() -> None:
    raw = subprocess.check_output(
        ["xcrun", "simctl", "list", "devices", "available", "-j"],
        text=True,
    )
    data = json.loads(raw)

    for preferred in PREFERRED_NAMES:
        for runtime, devices in data.get("devices", {}).items():
            if "iOS" not in runtime:
                continue
            for device in devices:
                if device.get("isAvailable") and device.get("name") == preferred:
                    print(device["udid"])
                    return

    sys.stderr.write(
        "No available iOS simulator found for: " + ", ".join(PREFERRED_NAMES) + "\n"
    )
    sys.exit(1)


if __name__ == "__main__":
    main()
