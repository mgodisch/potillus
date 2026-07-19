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
gen-ios-version.py -- derives the iOS build's version numbers from the sources
of truth the rest of the project already uses.

WHY THIS EXISTS
    The project has exactly one human-readable version, and release-check.sh
    SECTION 1 enforces it: the top `## vX.Y.Z` entry in CHANGELOG.md, the
    `versionName` in android/app/build.gradle.kts, and the version in README.md
    must all agree.  Adding an iOS project introduced a fourth place that could
    drift -- `MARKETING_VERSION` in ios/project.yml -- and a hand-maintained
    fourth copy is a fourth chance to forget.

    Rather than invent a new VERSION file and rewrite the Android build around
    it (a change to the one number the release pipeline is built on, for no gain
    on the Android side), this script DERIVES the iOS numbers from what is
    already authoritative:

        MARKETING_VERSION       <- top `## vX.Y.Z` entry of CHANGELOG.md
        CURRENT_PROJECT_VERSION <- `versionCode` of android/app/build.gradle.kts

    Using Android's versionCode for the iOS build number keeps the two stores'
    monotonic counters in step, so "build 214" means the same release on both
    platforms.  That matters when a user reports a bug against a build number.

OUTPUT
    ios/Version.xcconfig, which ios/project.yml includes.  The file is GENERATED
    and therefore git-ignored: it is reproduced from tracked sources on demand,
    so it can never be committed out of date.  Run it before `xcodegen generate`
    (see "Building the iOS app" in README.md), or via `make -C ios version`.

USAGE
    tools/gen-ios-version.py [--check]

    --check  Do not write; exit non-zero if the existing file is missing or
             stale.  Suitable for a release gate.
"""

import os
import re
import sys

from potillus_repo import changelog_marketing_version, repo_root

VERSION_CODE = re.compile(r"versionCode\s*=\s*(\d+)")


def marketing_version(root):
    """The top `## vX.Y.Z` entry of CHANGELOG.md."""
    version = changelog_marketing_version(root)
    if version is None:
        path = os.path.join(root, "CHANGELOG.md")
        raise SystemExit(f"gen-ios-version: no '## vX.Y.Z' heading found in {path}")
    return version


def project_version(root):
    """The `versionCode` of the Android build, reused as the iOS build number."""
    path = os.path.join(root, "android", "app", "build.gradle.kts")
    with open(path, encoding="utf-8") as handle:
        match = VERSION_CODE.search(handle.read())
    if not match:
        raise SystemExit(f"gen-ios-version: no versionCode found in {path}")
    return match.group(1)


def render(root):
    """The full text of ios/Version.xcconfig."""
    return f"""// GENERATED FILE -- DO NOT EDIT, DO NOT COMMIT.
//
// Produced by tools/gen-ios-version.py from the project's sources of truth:
//   MARKETING_VERSION       <- top '## vX.Y.Z' entry of CHANGELOG.md
//   CURRENT_PROJECT_VERSION <- versionCode of android/app/build.gradle.kts
//
// Regenerate with `make -C ios version` before running `xcodegen generate`.

MARKETING_VERSION = {marketing_version(root)}
CURRENT_PROJECT_VERSION = {project_version(root)}
"""


def main(argv):
    root = str(repo_root())
    target = os.path.join(root, "ios", "Version.xcconfig")
    wanted = render(root)

    if "--check" in argv:
        try:
            with open(target, encoding="utf-8") as handle:
                current = handle.read()
        except OSError:
            print(f"gen-ios-version: missing {target}; run 'make -C ios version'", file=sys.stderr)
            return 1
        if current != wanted:
            print(f"gen-ios-version: {target} is stale; run 'make -C ios version'", file=sys.stderr)
            return 1
        print("gen-ios-version: up to date")
        return 0

    with open(target, "w", encoding="utf-8") as handle:
        handle.write(wanted)
    version = marketing_version(root)
    build = project_version(root)
    print(f"gen-ios-version: wrote {target} (version {version}, build {build})")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
