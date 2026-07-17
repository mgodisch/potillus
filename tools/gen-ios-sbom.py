#!/usr/bin/env python3
# vim: set et ts=4 sw=4:
# =============================================================================
# Libellus Potionis - Privacy-Friendly Alcohol Tracker
# Copyright (c) 2026 Martin A. Godisch <martin@godisch.de>
# =============================================================================
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <https://www.gnu.org/licenses/>.
#
# In addition, as permitted by section 7 of the GNU General Public License,
# this program may carry additional permissions; any such permissions that
# apply to it are stated in the accompanying COPYING.md file.
# =============================================================================

"""
gen-ios-sbom.py -- a CycloneDX 1.6 SBOM for the iOS application.

WHY A HAND-WRITTEN GENERATOR, NOT A TOOL
    Android gets its SBOM from the first-party CycloneDX Gradle plugin. Swift
    Package Manager has no first-party CycloneDX generator; the third-party
    options (cdxgen, Syft) are each a new build-time toolchain, which this
    project avoids for reproducibility. GRDB is the app's ONE direct dependency,
    pinned exactly in Package.resolved, so a faithful CycloneDX document is a few
    lines of deterministic JSON. "Analog to Android" here means the SAME format
    (CycloneDX 1.6 JSON), the SAME metadata shape (application component + the
    dependency as a library), and the SAME normaliser flow (sbom-normalize.py)
    — produced without a new dependency.

WHAT IT EMITS
    A CycloneDX 1.6 document with:
      - bomFormat / specVersion / version, and NO serialNumber (matching the
        Android task's includeBomSerialNumber = false, so the file is stable).
      - metadata.component: the application ("Libellus Potionis", the version
        passed in), the same projectType Android uses.
      - components: one entry per pin in Package.resolved — for GRDB, a library
        component with a pkg:swift purl, the resolved version, the commit as a
        source-control reference, and its MIT license.
    The timestamp is left to sbom-normalize.py (dropped, or set from
    SOURCE_DATE_EPOCH), exactly as the Android SBOM is normalised, so both are
    byte-reproducible.

USAGE
    tools/gen-ios-sbom.py <output.json> --version <marketing-version> \\
        [--resolved ios/PotillusKit/Package.resolved]
    Then run tools/sbom-normalize.py <output.json>, as the Makefile does.
"""

import argparse
import json
import sys
from pathlib import Path

# The license each known dependency ships under, by Package.resolved identity.
# GRDB is MIT (recorded in COPYING.md). A pin not listed here still appears in
# the SBOM, without a license field, and the generator warns — so a newly added
# dependency cannot slip in silently unlicensed.
KNOWN_LICENSES = {
    "grdb.swift": "MIT",
}


def purl(location: str, version: str) -> str:
    """A pkg:swift purl from a Git location and resolved version.

    CycloneDX/Package-URL spell Swift packages as
    pkg:swift/<host>/<path>@<version>, so the namespace is the repository host
    and path with the trailing ``.git`` removed.
    """
    stripped = location
    for prefix in ("https://", "http://", "git@"):
        if stripped.startswith(prefix):
            stripped = stripped[len(prefix):]
    if stripped.endswith(".git"):
        stripped = stripped[: -len(".git")]
    stripped = stripped.replace(":", "/")
    return f"pkg:swift/{stripped}@{version}"


def component_for(pin: dict) -> dict:
    """One CycloneDX library component for a Package.resolved pin."""
    identity = pin.get("identity", "")
    location = pin.get("location", "")
    state = pin.get("state", {})
    version = state.get("version") or state.get("revision", "")
    revision = state.get("revision", "")

    component = {
        "type": "library",
        "name": identity,
        "version": version,
        "purl": purl(location, version),
    }
    if location:
        # The exact commit, as an external source-control reference — the same
        # provenance Package.resolved pins.
        component["externalReferences"] = [
            {"type": "vcs", "url": f"{location}@{revision}"},
        ]
    license = KNOWN_LICENSES.get(identity)
    if license:
        component["licenses"] = [{"license": {"id": license}}]
    else:
        sys.stderr.write(
            f"gen-ios-sbom.py: warning: no license recorded for {identity!r}; "
            "add it to KNOWN_LICENSES and COPYING.md\n"
        )
    return component


def build_bom(resolved: dict, version: str) -> dict:
    pins = resolved.get("pins", [])
    components = [component_for(pin) for pin in pins]
    return {
        "bomFormat": "CycloneDX",
        "specVersion": "1.6",
        "version": 1,
        "metadata": {
            # sbom-normalize.py fills or drops this; a fixed placeholder keeps the
            # key present so the normaliser has something to replace.
            "timestamp": "1970-01-01T00:00:00Z",
            "component": {
                "type": "application",
                "name": "Libellus Potionis",
                "version": version,
            },
        },
        "components": components,
    }


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="Generate the iOS CycloneDX SBOM.")
    parser.add_argument("output", help="path to write the SBOM JSON to")
    parser.add_argument("--version", required=True, help="marketing version string")
    parser.add_argument(
        "--resolved",
        default="ios/PotillusKit/Package.resolved",
        help="path to Package.resolved (default: ios/PotillusKit/Package.resolved)",
    )
    args = parser.parse_args(argv)

    resolved_path = Path(args.resolved)
    if not resolved_path.is_file():
        sys.stderr.write(f"gen-ios-sbom.py: no such file: {resolved_path}\n")
        return 1

    resolved = json.loads(resolved_path.read_text(encoding="utf-8"))
    bom = build_bom(resolved, args.version)

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8") as fh:
        json.dump(bom, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
