#!/usr/bin/env python3
# vim: set et ts=4:
# =============================================================================
# Libellus Potionis - Privacy-Friendly Alcohol Tracker
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
#
# =============================================================================
# validate-screenshots.py -- Google Play phone-screenshot conformance gate
# =============================================================================
#
# WHAT THIS CHECKS
#   After `make screenshots` has captured the six in-app shots and rendered the
#   two PDF report pages, this script verifies every phone screenshot against
#   Google Play's published requirements, so a non-conformant asset is caught
#   locally instead of being rejected on upload.
#
#   For each locale's fastlane/metadata/android/<locale>/images/phoneScreenshots
#   directory it asserts:
#     * exactly EXPECTED_COUNT (8) PNG files are present,
#     * each file is a real PNG (verified by signature, not by extension),
#     * each side is within Play's [MIN_SIDE, MAX_SIDE] = [320, 3840] px range,
#     * the long:short side ratio does not exceed MAX_RATIO (2:1).
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
EXPECTED_COUNT = 8   # the task requires exactly eight assets per locale

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"

# Root of the fastlane metadata tree. It lives at the repository root (a sibling
# of android/ and of this script's tools/ dir). Anchor to it from __file__ so the
# script is cwd-independent (the parent of tools/ is the repository root) --
# matching crop-screenshots.py; it no longer relies on being invoked from the
# android/ project dir.
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


def validate_locale(locale):
    """Validate one locale's phoneScreenshots directory.

    Returns a list of human-readable error strings (empty when the locale is
    fully conformant).
    """
    errors = []
    shots_dir = os.path.join(META_ROOT, locale, "images", "phoneScreenshots")

    if not os.path.isdir(shots_dir):
        return [f"{locale}: directory not found: {shots_dir}"]

    pngs = sorted(
        f for f in os.listdir(shots_dir) if f.lower().endswith(".png")
    )

    if len(pngs) != EXPECTED_COUNT:
        errors.append(
            f"{locale}: expected {EXPECTED_COUNT} PNG screenshots, found {len(pngs)} "
            f"({', '.join(pngs) or 'none'})"
        )

    for name in pngs:
        path = os.path.join(shots_dir, name)
        try:
            width, height = png_dimensions(path)
        except (ValueError, OSError) as exc:
            errors.append(f"{locale}/{name}: {exc}")
            continue

        long_side, short_side = max(width, height), min(width, height)
        ratio = long_side / short_side if short_side else float("inf")

        if not (MIN_SIDE <= width <= MAX_SIDE) or not (MIN_SIDE <= height <= MAX_SIDE):
            errors.append(
                f"{locale}/{name}: {width}x{height}px outside the allowed "
                f"{MIN_SIDE}..{MAX_SIDE}px range"
            )
        if ratio > MAX_RATIO + 1e-9:
            errors.append(
                f"{locale}/{name}: aspect ratio {ratio:.3f}:1 exceeds the "
                f"{MAX_RATIO:.0f}:1 maximum (use a device/emulator no taller "
                f"than 2:1, e.g. 1080x2160)"
            )

    return errors


def main(argv):
    """Validate every locale passed on the command line; non-zero on any failure."""
    locales = argv[1:]
    if not locales:
        print("usage: validate-screenshots.py <locale> [<locale> ...]", file=sys.stderr)
        return 2

    all_errors = []
    for locale in locales:
        locale_errors = validate_locale(locale)
        if locale_errors:
            all_errors.extend(locale_errors)
        else:
            print(f"  \u2713 {locale}: {EXPECTED_COUNT} screenshots conform to Play limits")

    if all_errors:
        print("\nGoogle Play screenshot validation FAILED:", file=sys.stderr)
        for err in all_errors:
            print(f"  \u2717 {err}", file=sys.stderr)
        return 1

    print("\nAll screenshots satisfy the Google Play phone-screenshot requirements.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
