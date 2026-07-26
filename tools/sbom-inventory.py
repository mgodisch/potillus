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
sbom-inventory.py -- print a CycloneDX SBOM as one line per component.

WHY
    The SBOM is the authoritative answer to "what does the app redistribute",
    and a licensing review is the place that question gets asked. But the SBOM
    is written into a build directory that no reviewer receives: it is
    git-ignored, it is not in the source tarball, and the QA log -- the one
    artifact a review DOES get -- never mentioned it.

    Printing it makes the inventory travel with the log. The verbatim JSON
    would too, but the Android SBOM covers 158 components against a QA log of
    about 1500 lines, so the document would outweigh everything else in it. A
    licensing audit reads three fields per component: what it is called, which
    version ships, and under which license. Those fit on one line.

    The generated file stays where it was; this tool only reads it. Its other
    consumers are unaffected -- the release-time OSV scan and the SBOM-gated
    META-INF/NOTICE scan in tools/release-check.sh SECTION 12 both open the
    file itself.

WHAT IT PRINTS
    A header naming the document and what it says about itself, then the
    components sorted by name, then a count:

        sbom-inventory: android/app/build/outputs/sbom/....json
        sbom-inventory:   document: CycloneDX 1.6, Libellus Potionis 0.84.0
        sbom-inventory:   androidx.activity:activity 1.12.3  [Apache-2.0]
        ...
        sbom-inventory:   158 component(s), 2 distinct license(s)

    A component whose `licenses` array is empty or absent prints
    `[license not stated]` rather than being dropped or silently blanked: an
    unlicensed entry in a redistribution inventory is precisely what a review
    is looking for, and it is also how a generator that lost a field announces
    itself.

LICENSE FIELDS
    CycloneDX spells a license three ways and this project's two generators use
    two of them: `licenses[].license.id` (an SPDX identifier, what
    tools/gen-ios-sbom.py writes), `licenses[].license.name` (free text, what
    the Gradle plugin falls back to when a POM names a license it cannot map)
    and `licenses[].expression` (an SPDX expression). All three are read; a
    component carrying several is printed with all of them, comma-separated, in
    document order, because which of them applies is a question for the
    reviewer and not one this tool should answer by picking one.

EXIT STATUS
    0 on a readable document, and 0 when the file is absent -- this is a
    REPORTING step inside the QA battery, like tools/problems-report.py, and
    the batteries run on hosts that cannot generate every SBOM. 1 only when a
    file exists and cannot be read or parsed, because that means the inventory
    it was asked to print is broken.

VERIFICATION NOTE
    Probed against the iOS SBOM (one component, SPDX id) and against a
    synthetic CycloneDX document exercising the paths the iOS one does not: the
    `name` and `expression` spellings, several licenses on one component, a
    component with no `licenses` key at all, and a missing `version`. No Gradle
    runs in the review sandbox, so the Android document's first real pass is a
    `make qa-android` run on a machine with the SDK.
"""

import json
import sys
from pathlib import Path

# The three places CycloneDX stores a license, in the order they are tried per
# `licenses[]` entry. `expression` sits on the entry itself, the other two
# inside its `license` object -- see the LICENSE FIELDS note above.
LICENSE_KEYS = ("id", "name")

# What to print for a component that names no license at all.
UNLICENSED = "license not stated"


def licenses_of(component):
    """
    Every license named by `component`, in document order, as a list of
    strings.

    Returns an empty list when the component names none, which the caller turns
    into UNLICENSED. Malformed entries (a `licenses` value that is not a list,
    an entry that is not an object) are skipped rather than raising: this tool
    reports on a document it does not own, and one odd entry should not cost
    the other 157 their line.
    """
    found = []
    entries = component.get("licenses")
    if not isinstance(entries, list):
        return found
    for entry in entries:
        if not isinstance(entry, dict):
            continue
        expression = entry.get("expression")
        if isinstance(expression, str) and expression.strip():
            found.append(expression.strip())
            continue
        license_object = entry.get("license")
        if not isinstance(license_object, dict):
            continue
        for key in LICENSE_KEYS:
            value = license_object.get(key)
            if isinstance(value, str) and value.strip():
                found.append(value.strip())
                break
    return found


def component_line(component):
    """
    One component as `name version  [license, license]`.

    `version` is optional in CycloneDX and absent for some component types, so
    it is omitted rather than printed as an empty string or a placeholder that
    could be mistaken for a version.
    """
    name = str(component.get("name", "(unnamed)"))
    version = component.get("version")
    label = f"{name} {version}" if version else name
    names = licenses_of(component) or [UNLICENSED]
    return f"{label}  [{', '.join(names)}]"


def document_line(document):
    """
    What the document says about itself: the CycloneDX spec version, and the
    application `metadata.component` describes.

    Recorded because both are claims a review checks -- the spec version
    against the generator's configured one, the application version against the
    release being built.
    """
    spec = document.get("specVersion", "?")
    metadata = document.get("metadata")
    subject = metadata.get("component") if isinstance(metadata, dict) else None
    if isinstance(subject, dict):
        name = subject.get("name", "(unnamed)")
        version = subject.get("version")
        described = f"{name} {version}" if version else str(name)
    else:
        described = "(no metadata.component)"
    return f"CycloneDX {spec}, {described}"


def report(path):
    """
    Print the inventory of one SBOM file and return its exit status.

    An absent file is reported and returns 0; see EXIT STATUS in the module
    docstring for why the two failure kinds are graded differently.
    """
    if not path.is_file():
        print(f"sbom-inventory: {path}: not present -- nothing to inventory.")
        return 0

    try:
        document = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, ValueError) as error:
        print(
            f"sbom-inventory: {path}: cannot read the SBOM: {error}",
            file=sys.stderr,
        )
        return 1

    components = document.get("components")
    if not isinstance(components, list):
        components = []

    print(f"sbom-inventory: {path}")
    print(f"sbom-inventory:   document: {document_line(document)}")

    # Sorted by name so two runs of the same tree print identical inventories
    # and a diff of two QA logs shows only what actually changed. The generator
    # already emits a stable order; this does not depend on it.
    lines = sorted(component_line(c) for c in components if isinstance(c, dict))
    for line in lines:
        print(f"sbom-inventory:   {line}")

    distinct = {
        name
        for component in components
        if isinstance(component, dict)
        for name in (licenses_of(component) or [UNLICENSED])
    }
    print(
        f"sbom-inventory:   {len(lines)} component(s), "
        f"{len(distinct)} distinct license(s)"
    )
    return 0


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if not argv:
        print(
            "usage: sbom-inventory.py SBOM.json [SBOM.json ...]",
            file=sys.stderr,
        )
        return 1

    # Every file is reported even if an earlier one failed, so one broken
    # document does not hide the inventory of the others; the worst status wins.
    status = 0
    for name in argv:
        status = max(status, report(Path(name)))
    return status


if __name__ == "__main__":
    sys.exit(main())
