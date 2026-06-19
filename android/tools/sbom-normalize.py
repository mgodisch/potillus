#!/usr/bin/env python3
# vim: set et ts=4 sw=4:
# =============================================================================
# Libellus Potionis -- Privacy-Friendly Alcohol Tracker
# Copyright (c) 2026 Martin A. Godisch <android@godisch.de>
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
# =============================================================================
"""
sbom-normalize.py -- make a generated CycloneDX SBOM byte-reproducible.

WHY THIS EXISTS
---------------
The CycloneDX Gradle plugin writes two fields that change on every run even when
the dependency graph is identical:

  * ``serialNumber`` -- a random ``urn:uuid:`` value. This is already suppressed
    at the source by ``includeBomSerialNumber = false`` in the
    ``cyclonedxDirectBom`` configuration (see ``app/build.gradle.kts``), so this
    script does not need to touch it.
  * ``metadata.timestamp`` -- the wall-clock build time. Unlike the CycloneDX
    *Maven* plugin (which honours ``project.build.outputTimestamp``), the Gradle
    plugin offers no option to pin or omit this timestamp, so it must be
    normalised after generation.

This script rewrites ``metadata.timestamp`` deterministically:

  * If the ``SOURCE_DATE_EPOCH`` environment variable is set (the
    reproducible-builds.org convention), the timestamp is set to that instant,
    formatted as UTC ISO-8601 (e.g. ``2026-01-01T00:00:00Z``).
  * Otherwise the ``metadata.timestamp`` field is removed entirely. ``metadata``
    and all of its members are optional in the CycloneDX schema, so the result
    is still a valid BOM -- just without a creation time.

Either way the output is identical across repeated builds from the same source,
which is what "reproducible build" requires. The SBOM is a side artifact and is
NOT embedded in the APK, so APK reproducibility is unaffected regardless; this
script only makes the SBOM file itself stable.

USAGE
-----
    python3 tools/sbom-normalize.py <path-to-sbom.json>

Invoked by the ``sbom`` target in ``android/Makefile`` immediately after
``./gradlew :app:cyclonedxDirectBom``.
"""

import datetime
import json
import os
import sys


def iso_utc_from_epoch(epoch_seconds: int) -> str:
    """Format a Unix epoch as a CycloneDX-style UTC ISO-8601 timestamp.

    CycloneDX uses RFC 3339 / ISO-8601; a trailing ``Z`` denotes UTC. We drop
    sub-second precision so the value is stable and easy to read.
    """
    dt = datetime.datetime.fromtimestamp(epoch_seconds, tz=datetime.timezone.utc)
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def normalize(path: str) -> None:
    """Load the SBOM at *path*, normalise its timestamp, and write it back."""
    with open(path, "r", encoding="utf-8") as fh:
        bom = json.load(fh)

    metadata = bom.get("metadata")
    if isinstance(metadata, dict):
        source_date_epoch = os.environ.get("SOURCE_DATE_EPOCH")
        if source_date_epoch:
            # Reproducible-builds convention: pin the timestamp to the supplied
            # epoch. int() also guards against a malformed value (fail loudly
            # rather than write a garbage timestamp).
            metadata["timestamp"] = iso_utc_from_epoch(int(source_date_epoch))
        else:
            # No fixed epoch provided: drop the volatile field so the file is
            # still deterministic.
            metadata.pop("timestamp", None)

    # Re-serialise deterministically: fixed indentation, preserved key order
    # (the plugin already emits components in a stable order), and a single
    # trailing newline. ensure_ascii=False keeps any non-ASCII characters as-is
    # rather than escaping them, which is both smaller and stable.
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(bom, fh, indent=2, ensure_ascii=False)
        fh.write("\n")


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        sys.stderr.write("usage: sbom-normalize.py <path-to-sbom.json>\n")
        return 2

    path = argv[1]
    if not os.path.isfile(path):
        sys.stderr.write(f"sbom-normalize.py: no such file: {path}\n")
        return 1

    normalize(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
