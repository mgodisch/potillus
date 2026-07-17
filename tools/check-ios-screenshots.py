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
# check-ios-screenshots.py -- App Store screenshot conformance gate
# =============================================================================
#
# WHY THIS EXISTS
#   tools/validate-screenshots.py says so in its own first line: it is the
#   "Google Play phone-screenshot conformance gate", and it reads only
#   fastlane/metadata/android/.  fastlane/screenshots/ios/ had no counterpart,
#   and in 0.83.1 that cost two upload attempts: the report pages 07..08 had
#   been A4-shaped since the day they were first rendered, Play had always
#   accepted them, and nothing here had an opinion until App Store Connect
#   refused all 21 locales at once.  This is that opinion, held early.
#
# WHAT IT CHECKS
#   1. REAL PNGs, by signature rather than by extension.
#   2. UNIFORM SIZE within a locale: every screenshot in a locale directory has
#      the same pixel size.
#   3. UNIFORM SIZE across locales: every locale agrees with every other.
#
# WHY UNIFORMITY AND NOT APPLE'S SIZE TABLE
#   The honest gate is the one whose facts this repository can actually hold.
#   The App Store accepts an ENUMERATED set of device resolutions; that table is
#   Apple's, it changes with each device generation, and a copy of it here would
#   be exactly as current as the last person to check it -- a gate that goes
#   subtly wrong on its own is worse than no gate.  Uniformity needs no table
#   and still catches the whole failure: shots 01..06 come out of the simulator
#   at a real device's real resolution, so they are a valid size BY
#   CONSTRUCTION, and anything that disagrees with them is the thing that is
#   wrong.  That is precisely the shape the defect had -- six good shots and two
#   A4 pages beside them.
#
#   The honest limit, stated rather than hidden: if IOS_SIM_DEVICE ever named a
#   device the App Store does not know, every shot would be uniformly wrong and
#   this would pass.  deliver still checks the table at upload time; this gate
#   exists to make sure that check has nothing left to find.
#
# GRACEFUL SKIP
#   A tree without fastlane/screenshots/ios/ (an Android-only source drop, or a
#   clone where the screenshots have not been captured yet) is not an error: the
#   check prints an informational line and exits 0, following the project's
#   gate-design rule that a check must not false-fail in environments that lack
#   its inputs.
#
# WHY NO PILLOW
#   The same reason validate-screenshots.py gives: PNG width and height live at
#   a fixed offset in the IHDR chunk, so the standard library is enough, and a
#   gate should run on a plain box without being installed into first.
#
# USAGE
#   tools/check-ios-screenshots.py
#   Exit status: 0 = clean or skipped, 1 = problems found.
# =============================================================================

import os
import struct
import sys

# Repository root: the parent of tools/.
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(ROOT, "fastlane", "screenshots", "ios")

# The first eight bytes of every PNG, per the PNG specification.
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"

# Non-locale entries fastlane and its tooling leave in the screenshots tree.
NOT_A_LOCALE = {"screenshots.html"}


def png_size(path):
    """(width, height) from the IHDR chunk, or None if this is not a PNG.

    The layout is fixed by the spec: 8 bytes of signature, then the IHDR chunk
    whose length and type occupy 8 more, so width and height are the two
    big-endian uint32s at offset 16.
    """
    with open(path, "rb") as handle:
        header = handle.read(24)
    if len(header) < 24 or not header.startswith(PNG_SIGNATURE):
        return None
    return struct.unpack(">II", header[16:24])


def main():
    if not os.path.isdir(BASE):
        print("check-ios-screenshots: fastlane/screenshots/ios/ not present -- skipped")
        return 0

    problems = []
    sizes = {}          # locale -> the size its shots agree on
    shot_count = 0

    for locale in sorted(os.listdir(BASE)):
        directory = os.path.join(BASE, locale)
        if not os.path.isdir(directory) or locale in NOT_A_LOCALE:
            continue

        shots = sorted(
            name for name in os.listdir(directory) if name.lower().endswith(".png")
        )
        if not shots:
            continue

        # 1 + 2: real PNGs, agreeing with each other. The first shot in filename
        # order is the reference, which is 01 -- the in-app shot straight from
        # the simulator, i.e. the one size known to be real.
        locale_sizes = {}
        for name in shots:
            size = png_size(os.path.join(directory, name))
            if size is None:
                problems.append(f"{locale}/{name}: not a PNG (bad signature)")
                continue
            locale_sizes[name] = size
            shot_count += 1

        if not locale_sizes:
            continue
        reference_name = next(iter(locale_sizes))
        reference = locale_sizes[reference_name]
        sizes[locale] = reference

        for name, size in locale_sizes.items():
            if size != reference:
                problems.append(
                    f"{locale}/{name}: {size[0]}x{size[1]} does not match "
                    f"{reference[0]}x{reference[1]} from {reference_name} -- the "
                    f"App Store takes only real device resolutions, and rejects "
                    f"the whole upload over one stray size"
                )

    # 3: and the locales agree with each other. Reported against the majority so
    # the message names the deviant locale rather than all of them.
    if sizes:
        counts = {}
        for size in sizes.values():
            counts[size] = counts.get(size, 0) + 1
        majority = max(counts, key=counts.get)
        for locale, size in sorted(sizes.items()):
            if size != majority:
                problems.append(
                    f"{locale}: shots are {size[0]}x{size[1]} but the other "
                    f"locales are {majority[0]}x{majority[1]} -- one locale was "
                    f"captured on a different device"
                )

    if problems:
        for problem in problems:
            print(f"check-ios-screenshots: {problem}", file=sys.stderr)
        print(
            f"check-ios-screenshots: {len(problems)} problem(s) found",
            file=sys.stderr,
        )
        return 1

    if not sizes:
        print("check-ios-screenshots: no screenshots captured yet -- skipped")
        return 0

    size = next(iter(sizes.values()))
    print(
        f"check-ios-screenshots: OK ({len(sizes)} locales, {shot_count} shots, "
        f"all {size[0]}x{size[1]})"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
