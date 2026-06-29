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
# crop-screenshots.py -- bottom-crop the in-app screenshots to <= 2:1
# =============================================================================
#
# WHY THIS EXISTS
#   Google Play rejects phone screenshots whose long side is more than twice the
#   short side (max aspect ratio 2:1). Many phones/emulators (e.g. Pixel-class
#   19.5:9 or 20:9 panels) produce full-screen captures taller than that — a
#   1080x2340 shot is 2.167:1 and fails validation.
#
#   Rather than forcing a specific capture device, this step trims the BOTTOM of
#   each in-app screenshot down to exactly 2:1. The bottom strip is where the
#   Android navigation bar sits, so cropping it both satisfies the ratio rule and
#   removes the system navigation row, leaving the app content and the cleaned
#   (demo-mode) status bar at the top intact.
#
# WHAT IT TOUCHES
#   Only the in-app screenshots (01..06). The two PDF report pages (07/08,
#   filenames containing "report") are produced at A4 ratio (~1.41:1), are
#   already compliant, and represent fixed document pages that must NOT be
#   cropped — they are skipped both by name AND by the ratio guard below.
#
#   For each remaining PNG with height H and width W:
#     * if H > 2*W  -> crop to the top W x (2*W) region (remove the bottom),
#                      overwriting the file in place;
#     * otherwise   -> leave untouched (already <= 2:1).
#   Only a portrait, too-tall crop is performed; landscape inputs (W > 2*H) are
#   reported as an error rather than silently altered, since the store assets
#   here are portrait by design.
#
# WHY Pillow
#   Cropping requires decoding and re-encoding the PNG, so unlike the
#   header-only validator this tool uses Pillow (Debian: `apt install
#   python3-pil`). The crop is lossless: the kept pixels are copied verbatim and
#   re-saved as a 24/32-bit PNG, matching Play's format expectations.
#
# EXIT STATUS
#   0  success (all targeted screenshots are <= 2:1 afterwards).
#   1  an image could not be processed, or a landscape input was found.
#   2  usage / I/O error (e.g. a locale directory is missing, Pillow absent).
# =============================================================================

import os
import sys

try:
    from PIL import Image
except ImportError:
    print(
        "crop-screenshots: Pillow is required (Debian: apt install python3-pil, "
        "or: pip install pillow --break-system-packages)",
        file=sys.stderr,
    )
    sys.exit(2)

# Google Play's hard cap: the long side may be at most twice the short side.
MAX_RATIO = 2.0

# Root of the fastlane metadata tree, relative to the android/ project dir from
# which the Makefile invokes this script.
META_ROOT = os.path.join("fastlane", "metadata", "android")

# Filename marker for the PDF report pages (07/08) that must never be cropped.
REPORT_MARKER = "report"


def crop_one(path):
    """Bottom-crop a single screenshot to <= 2:1 if it is too tall.

    Returns a short status string for the run summary. Raises ValueError for a
    landscape (too-wide) input, which is unexpected for these portrait assets.
    """
    with Image.open(path) as img:
        width, height = img.size

        if width > MAX_RATIO * height:
            raise ValueError(
                f"{width}x{height}px is landscape/too wide; bottom-crop only "
                f"handles too-tall portrait images"
            )

        if height <= MAX_RATIO * width:
            return f"kept   {os.path.basename(path)} ({width}x{height}, <= 2:1)"

        # Trim the bottom: keep the top W x (2*W) region (the Android navigation
        # bar lives in the removed bottom strip).
        new_height = int(MAX_RATIO * width)
        cropped = img.crop((0, 0, width, new_height))
        # load() detaches the crop from the source file handle before we
        # overwrite it in place.
        cropped.load()

    cropped.save(path, format="PNG")
    return f"cropped {os.path.basename(path)} ({width}x{height} -> {width}x{new_height})"


def crop_locale(locale):
    """Bottom-crop every in-app screenshot in one locale directory.

    Returns (status_lines, error_lines).
    """
    statuses, errors = [], []
    shots_dir = os.path.join(META_ROOT, locale, "images", "phoneScreenshots")

    if not os.path.isdir(shots_dir):
        return statuses, [f"{locale}: directory not found: {shots_dir}"]

    for name in sorted(os.listdir(shots_dir)):
        if not name.lower().endswith(".png"):
            continue
        if REPORT_MARKER in name.lower():
            statuses.append(f"skip   {name} (PDF report page)")
            continue
        try:
            statuses.append(crop_one(os.path.join(shots_dir, name)))
        except (ValueError, OSError) as exc:
            errors.append(f"{locale}/{name}: {exc}")

    return statuses, errors


def main(argv):
    """Bottom-crop the in-app screenshots for every locale on the command line."""
    locales = argv[1:]
    if not locales:
        print("usage: crop-screenshots.py <locale> [<locale> ...]", file=sys.stderr)
        return 2

    all_errors = []
    for locale in locales:
        statuses, errors = crop_locale(locale)
        for line in statuses:
            print(f"  {locale}: {line}")
        all_errors.extend(errors)

    if all_errors:
        print("\nScreenshot cropping FAILED:", file=sys.stderr)
        for err in all_errors:
            print(f"  \u2717 {err}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
