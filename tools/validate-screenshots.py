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
# validate-screenshots.py -- Google Play phone-screenshot conformance gate
# =============================================================================
#
# WHAT THIS CHECKS
#   After `make screenshots-android` has captured the six in-app shots and rendered the
#   two PDF report pages, this script verifies every phone screenshot against
#   Google Play's published requirements, so a non-conformant asset is caught
#   locally instead of being rejected on upload.
#
#   For each locale's fastlane/metadata/android/<locale>/images/phoneScreenshots
#   directory it asserts:
#     * the REQUIRED shots for the selected mode are present (see below),
#     * each file is a real PNG (verified by signature, not by extension),
#     * each side is within Play's [MIN_SIDE, MAX_SIDE] = [320, 3840] px range,
#     * the long:short side ratio does not exceed MAX_RATIO (2:1).
#
#   MODES (optional leading flag): the eight shots have two producers, each of
#   which validates only its own half right after generating it —
#     --in-app   requires 01..06  (`make screenshots-android`)
#     --report   requires 07..08  (`make report-pdfs-android`)
#     (default)  requires all 8   (full-set validation)
#   Any other PNG already on disk is still geometry-checked in every mode.
#
# WHY NO PILLOW / EXTERNAL DEPS
#   The project's build tooling targets a plain Debian box and already relies on
#   python3 (see android/Makefile `guides`/`sbom`). PNG width/height live in the
#   fixed-offset IHDR chunk, so we read them with the standard library alone and
#   avoid adding a Pillow dependency just for a header peek.
#
# EXIT STATUS
#   0  every locale passes.
#   1  at least one violation (details printed); used as a hard Make gate.
#   2  usage / I/O error (e.g. a locale directory is missing).
# =============================================================================

import os
import struct
import sys

# ── Google Play phone-screenshot limits (and our own count expectation) ───────
MIN_SIDE = 320       # px – Play minimum for any side
MAX_SIDE = 3840      # px – Play maximum for any side
MAX_RATIO = 2.0      # long:short side – Play maximum aspect ratio

# The eight per-locale phone screenshots split by PRODUCER: the in-app shots
# 01..06 come from `make screenshots-android` (screengrab on a device); the report pages
# 07..08 come from `make report-pdfs-android` (rasterized from the per-locale PDF). Each
# producer validates only its own half right after generating it, so a partial
# set is not spuriously failed; the full eight are checked when both are present.
IN_APP_SHOTS = (
    "01_today", "02_calendar", "03_statistics",
    "04_drinks", "05_add_drink", "06_settings",
)
REPORT_SHOTS = ("07_report_page_1", "08_report_page_2")
ALL_SHOTS = IN_APP_SHOTS + REPORT_SHOTS

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"

# Root of the fastlane metadata tree. It lives at the repository root (a sibling
# of android/ and of this script's tools/ dir). Anchor to it from __file__ so the
# script is cwd-independent (the parent of tools/ is the repository root); it
# does not rely on being invoked from the android/ project dir.
META_ROOT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "fastlane", "metadata", "android",
)


def png_dimensions(path):
    """Return (width, height) of a PNG file by reading its IHDR chunk.

    Raises ValueError if the file is not a valid PNG. The PNG signature is the
    first 8 bytes; the IHDR chunk starts at byte 8 with a 4-byte length and the
    4-byte type "IHDR", followed by width and height as big-endian uint32 — so
    width is at offset 16 and height at offset 20.
    """
    with open(path, "rb") as fh:
        header = fh.read(24)
    if len(header) < 24 or header[:8] != PNG_SIGNATURE:
        raise ValueError("not a PNG file (bad signature)")
    if header[12:16] != b"IHDR":
        raise ValueError("malformed PNG (missing IHDR)")
    width, height = struct.unpack(">II", header[16:24])
    return width, height


def validate_locale(locale, expected_shots):
    """Validate one locale's phoneScreenshots directory.

    ``expected_shots`` is the tuple of shot base names (without the .png suffix)
    that must be present and conformant — the in-app set, the report set, or all
    eight, depending on the caller's mode. Extra shots on disk are still checked
    (an oversized 07 must fail even during an in-app run if it happens to exist),
    but only the expected ones are REQUIRED.

    Returns a list of human-readable error strings (empty when conformant).
    """
    errors = []
    shots_dir = os.path.join(META_ROOT, locale, "images", "phoneScreenshots")

    if not os.path.isdir(shots_dir):
        return [f"{locale}: directory not found: {shots_dir}"]

    present = {
        os.path.splitext(f)[0]
        for f in os.listdir(shots_dir)
        if f.lower().endswith(".png")
    }

    missing = [f"{name}.png" for name in expected_shots if name not in present]
    if missing:
        errors.append(
            f"{locale}: missing {len(missing)} required screenshot(s): "
            f"{', '.join(missing)}"
        )

    # Check the geometry of every expected shot that IS present, plus any other
    # PNG on disk (so a stray or oversized file never slips through unchecked).
    to_check = sorted(present.union(expected_shots).intersection(present))
    for name in to_check:
        path = os.path.join(shots_dir, name + ".png")
        try:
            width, height = png_dimensions(path)
        except (ValueError, OSError) as exc:
            errors.append(f"{locale}/{name}.png: {exc}")
            continue

        long_side, short_side = max(width, height), min(width, height)
        ratio = long_side / short_side if short_side else float("inf")

        if not (MIN_SIDE <= width <= MAX_SIDE) or not (MIN_SIDE <= height <= MAX_SIDE):
            errors.append(
                f"{locale}/{name}.png: {width}x{height}px outside the allowed "
                f"{MIN_SIDE}..{MAX_SIDE}px range"
            )
        if ratio > MAX_RATIO + 1e-9:
            errors.append(
                f"{locale}/{name}.png: aspect ratio {ratio:.3f}:1 exceeds the "
                f"{MAX_RATIO:.0f}:1 maximum (use a device/emulator no taller "
                f"than 2:1, e.g. 1080x2160)"
            )

    return errors


def main(argv):
    """Validate every locale passed on the command line; non-zero on any failure.

    An optional leading mode flag selects which shot set is REQUIRED:
      --in-app   only the in-app shots 01..06 (used by `make screenshots-android`)
      --report   only the report pages 07..08 (used by `make report-pdfs-android`)
      (default)  all eight (used when validating a complete set)
    """
    args = argv[1:]
    expected, label = ALL_SHOTS, "8"
    if args and args[0] == "--in-app":
        expected, label, args = IN_APP_SHOTS, "6 in-app", args[1:]
    elif args and args[0] == "--report":
        expected, label, args = REPORT_SHOTS, "2 report", args[1:]

    locales = args
    if not locales:
        print(
            "usage: validate-screenshots.py [--in-app|--report] <locale> [<locale> ...]",
            file=sys.stderr,
        )
        return 2

    all_errors = []
    for locale in locales:
        locale_errors = validate_locale(locale, expected)
        if locale_errors:
            all_errors.extend(locale_errors)
        else:
            print(f"  \u2713 {locale}: {label} screenshots conform to Play limits")

    if all_errors:
        print("\nGoogle Play screenshot validation FAILED:", file=sys.stderr)
        for err in all_errors:
            print(f"  \u2717 {err}", file=sys.stderr)
        return 1

    print("\nAll checked screenshots satisfy the Google Play phone-screenshot requirements.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
