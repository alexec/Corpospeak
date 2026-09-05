#!/usr/bin/env python3
"""Checks whether a connected iPhone or iPad meets Apple's minimum hardware for
Apple Intelligence, which Corpospeak's on-device rewrite (the Foundation Models
framework) also needs.

Per Apple's own compatibility page (https://support.apple.com/en-us/121115):

    iPhone 15 Pro or later; iPad mini (A17 Pro), or any iPad with M1 or later.

There is no reliable App Store or Info.plist mechanism that gates installation on
this (the closest Info.plist key, UIRequiredDeviceCapabilities'
"iphone-performance-gaming-tier", checks GPU tier rather than the Neural Engine
Foundation Models actually needs — an Apple DTS engineer confirmed as much on the
developer forums). `devicectl` does not check it either: it will happily install
on any connected device that meets the OS version, whether or not Apple
Intelligence will ever run there. So: run this before installing a build on a
physical device with `devicectl device install app`, rather than relying on the
tooling to catch it.

Usage:
    scripts/check_apple_intelligence_eligible.py                 # list every connected device
    scripts/check_apple_intelligence_eligible.py <id-or-name-substring>

With no argument, lists every connected device and its eligibility, exit 0.
With an argument, exits 0 if every matching device is eligible, 1 if any matching
device is not (printing why to stderr), 2 if nothing matches.
"""
import json
import os
import re
import subprocess
import sys
import tempfile

IPHONE_GENERATION = re.compile(r"^iPhone (\d+)")
IPAD_M_CHIP = re.compile(r"\bM([1-9]\d*)\b")


def list_devices():
    fd, path = tempfile.mkstemp(suffix=".json")
    os.close(fd)
    try:
        subprocess.run(
            ["xcrun", "devicectl", "list", "devices", "--json-output", path],
            check=True, capture_output=True, text=True,
        )
        with open(path) as f:
            return json.load(f)["result"]["devices"]
    finally:
        os.unlink(path)


def iphone_eligible(marketing_name):
    if "15 Pro" in marketing_name:  # iPhone 15 Pro, iPhone 15 Pro Max
        return True
    if "Air" in marketing_name:  # iPhone Air
        return True
    match = IPHONE_GENERATION.match(marketing_name)
    if match:
        return int(match.group(1)) >= 16  # iPhone 16 and later, including 16e/17e
    return False


def ipad_eligible(marketing_name):
    if "A17 Pro" in marketing_name:  # iPad mini (A17 Pro)
        return True
    return IPAD_M_CHIP.search(marketing_name) is not None  # M1 and later


def eligibility(device):
    """True/False if this is an iPhone or iPad, None if the check doesn't apply
    (Mac, etc.)."""
    hardware = device["hardwareProperties"]
    device_type = hardware.get("deviceType")
    name = hardware.get("marketingName", "")
    if device_type == "iPhone":
        return iphone_eligible(name)
    if device_type == "iPad":
        return ipad_eligible(name)
    return None


def describe(device):
    hardware = device["hardwareProperties"]
    name = device.get("deviceProperties", {}).get("name", "?")
    marketing = hardware.get("marketingName", "?")
    return f"{name} — {marketing} ({device['identifier']})"


def main():
    devices = list_devices()
    query = sys.argv[1] if len(sys.argv) > 1 else None

    if query is None:
        for device in devices:
            ok = eligibility(device)
            status = "eligible" if ok else "NOT eligible" if ok is False else "n/a (not an iPhone/iPad)"
            print(f"{describe(device)}: {status}")
        return 0

    matches = [
        d for d in devices
        if query in d["identifier"] or query in d.get("deviceProperties", {}).get("name", "")
    ]
    if not matches:
        print(f"No connected device matches {query!r}.", file=sys.stderr)
        return 2

    exit_code = 0
    for device in matches:
        ok = eligibility(device)
        if ok is False:
            print(
                f"NOT eligible for Apple Intelligence: {describe(device)}. "
                "Corpospeak will install but its rewrite step will never work there.",
                file=sys.stderr,
            )
            exit_code = 1
        elif ok is True:
            print(f"Eligible: {describe(device)}")
        else:
            print(f"Not an iPhone/iPad, skipping: {describe(device)}")
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
