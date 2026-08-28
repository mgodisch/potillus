#!/usr/bin/env python3
# vim: set et ts=4:
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
#
# =============================================================================

"""check-plural-parity.py -- the two platforms spell a day count the same way.

WHY THIS EXISTS
    `test-vectors/plural-days.json` is a shared vector file that only ONE side
    can assert. iOS carries its own CLDR plural selection (`DayPlural`) and a
    Swift test reads the vectors directly. Android has no such code: the count is
    spelled by an Android `<plurals>` resource, which the framework resolves and
    a JVM unit test cannot reach without an emulator. So the file has an iOS test
    and no Android twin, and the wording on the two platforms could drift apart
    with every gate still green -- "3 dni" here, "3 dnia" there, for the same
    Polish user (0.85.0 QA round).

    The comparison itself needs neither platform: the vectors hold the expected
    string per language and count, and the resources hold the string per language
    and plural category. Both are text. This tool reads them and reports where
    they disagree, which is what closes the gap the vector file leaves open.

WHAT IS COMPARED
    For every language and count in the vector file, the vector's `expected`
    string against the Android `<plurals name="days">` item for the vector's
    `category`, with `%1$d` substituted by the count. Android falls back to the
    `other` item when a category is absent, and so does this tool, because that
    is what a device does.

    The plural CATEGORY per count is the vector's own; this tool does not
    re-derive CLDR rules. Android's ICU picks the category at runtime, and
    pinning the app against a private re-implementation of ICU would assert this
    tool's rules rather than the platform's. What is checked here is the WORDING
    behind each category, which is where a translation actually drifts.

EXIT
    0 when every pair agrees, 1 on the first disagreement or a missing resource.
"""

import json
import sys
import xml.etree.ElementTree as ET

from potillus_repo import repo_root

#: The plurals resource the shared vectors describe.
PLURALS_NAME = "days"

#: BCP-47 tags whose Android resource directory does not follow the mechanical
#: `values-<tag>` / `values-<lang>-r<REGION>` derivation. `en` is the base
#: resource set, and the two Chinese scripts are shipped under region qualifiers
#: because Android's script qualifiers need API 21+ resource aliasing the project
#: does not use.
DIRECTORY_OVERRIDES = {
    "en": "values",
    "zh-Hans": "values-zh-rCN",
    "zh-Hant": "values-zh-rTW",
}


def resource_dirs(tag):
    """Candidate `res/values*` directory names for a BCP-47 tag, best first."""
    if tag in DIRECTORY_OVERRIDES:
        return [DIRECTORY_OVERRIDES[tag]]
    if "-" in tag:
        language, region = tag.split("-", 1)
        return [f"values-{language}-r{region.upper()}", f"values-{tag}"]
    return [f"values-{tag}"]


def android_forms(root, tag):
    """The `<plurals name="days">` items of one language, keyed by quantity.

    Returns None when no resource directory for the tag exists, which the caller
    reports rather than skipping: a language in the vectors with no Android
    resource is exactly the drift this tool is for.
    """
    for name in resource_dirs(tag):
        path = root / "android/app/src/main/res" / name / "strings.xml"
        if not path.is_file():
            continue
        for plurals in ET.parse(path).getroot().findall("plurals"):
            if plurals.get("name") == PLURALS_NAME:
                return {i.get("quantity"): i.text for i in plurals.findall("item")}
        return {}
    return None


def main():
    root = repo_root()
    vectors = json.loads(
        (root / "test-vectors/plural-days.json").read_text(encoding="utf-8")
    )["cases"]

    problems = []
    compared = 0

    for tag in sorted(vectors):
        forms = android_forms(root, tag)
        if forms is None:
            problems.append(
                f"{tag}: no Android resource directory "
                f"(looked for {', '.join(resource_dirs(tag))})"
            )
            continue
        if not forms:
            problems.append(f"{tag}: strings.xml carries no <plurals name=\"{PLURALS_NAME}\">")
            continue

        for case in vectors[tag]:
            category, count, expected = case["category"], case["count"], case["expected"]
            template = forms.get(category, forms.get("other"))
            if template is None:
                problems.append(
                    f"{tag}: no item for quantity '{category}' and no 'other' fallback"
                )
                continue
            android = template.replace("%1$d", str(count))
            compared += 1
            if android != expected:
                problems.append(
                    f"{tag} n={count} ({category}): "
                    f"iOS vectors say {expected!r}, Android says {android!r}"
                )

    if problems:
        print("check-plural-parity: the two platforms disagree about a day count:")
        for problem in problems:
            print(f"  {problem}")
        return 1

    print(
        f"check-plural-parity: OK -- {compared} count(s) across "
        f"{len(vectors)} language(s) read the same on both platforms."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
