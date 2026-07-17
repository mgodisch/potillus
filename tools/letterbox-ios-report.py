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
# letterbox-ios-report.py -- fit the A4 report pages onto the device canvas
# =============================================================================
#
# WHY THIS EXISTS
#   `make screenshots-ios` produces eight shots per locale.  Shots 01..06 come
#   out of the simulator at the device's native resolution.  Shots 07..08 are
#   the app's own PDF report, rasterized by pdftoppm, and are therefore A4-
#   shaped: at the project's 200 dpi that is 1654x2339, an aspect ratio of 0.71
#   against the device's 0.46.
#
#   Google Play accepts that.  Its rule is a RANGE -- 320..3840 px per side and
#   at most 2:1 -- which an A4 page at 200 dpi satisfies comfortably, which is
#   why the Android set has always uploaded cleanly and why nothing here ever
#   objected.  The App Store does not have a range.  It accepts an ENUMERATED
#   set of device resolutions and rejects everything else, so the very same page
#   that Play welcomes was refused for all 21 locales:
#
#       Invalid screen size (Screenshot size is not supported.
#       Actual size is 1654x2339.)
#
#   The page cannot simply be scaled to the device shape: A4 and a phone screen
#   have different aspect ratios, and any scale that filled the canvas would
#   distort the report or crop it.  So the page is scaled to the canvas WIDTH,
#   which preserves its proportions, and the leftover height above and below is
#   filled -- the standard letterbox.
#
# WHY IT TAKES THE SIZE FROM SHOT 01 INSTEAD OF A CONSTANT
#   The target size is read from the locale's own in-app screenshot rather than
#   hard-coded, for two reasons.  It cannot drift: IOS_SIM_DEVICE in the
#   Makefile and the device pinned in fastlane/Snapfile can change to a phone
#   with a different resolution, and this then follows without an edit.  And it
#   cannot be wrong: shot 01 came out of the simulator at a real device's real
#   resolution, so it is by construction a size the App Store knows -- a
#   constant in this file would only be as current as the last person to check
#   Apple's table.
#
# THE FILL COLOUR
#   #1A1E2B, the app's identity colour: it is `ic_launcher_background` in
#   android/app/src/main/res/values/colors.xml and ICON_BG in
#   tools/render-feature-graphic.py, i.e. the icon's background and the base of
#   the feature graphics.  A neutral grey would read as a letterbox bar -- as
#   something missing.  The white page on the app's own dark navy reads as a
#   document on a surface, and it holds its edge against the App Store's chrome
#   in both light and dark mode.
#
# USAGE
#   tools/letterbox-ios-report.py <shots-dir> <device-prefix>
#       <shots-dir>       fastlane/screenshots/ios
#       <device-prefix>   the "<device>-" filename prefix fastlane prepends,
#                         e.g. "iPhone 17 Pro"
#
#   Every locale directory below <shots-dir> is processed.  A page already at
#   the target size is left untouched, so the tool is idempotent and safe to
#   re-run over a finished tree.
#
#   Exit status: 0 = done (including nothing to do), 1 = a problem was found.
# =============================================================================

import os
import sys

from PIL import Image

# The app's identity colour; see "THE FILL COLOUR" above for where it comes from.
FILL = "#1A1E2B"

# The shot whose resolution defines the canvas: the first in-app screenshot,
# straight from the simulator. Matched by its number, not its full name, so
# renaming the screen behind it does not silently break the lookup.
REFERENCE_NUMBER = "01"

# The report pages, by number. These are the only shots this tool rewrites.
REPORT_NUMBERS = ("07", "08")


def shot_path(directory, prefix, number):
    """The one PNG in `directory` whose name is "<prefix>-<number>_...png".

    Returns None when there is none. Raises when there is more than one: that
    would mean the naming convention this whole step relies on has broken, and
    guessing which file was meant would be worse than stopping.
    """
    stem = f"{prefix}-{number}_"
    matches = sorted(
        name
        for name in os.listdir(directory)
        if name.startswith(stem) and name.endswith(".png")
    )
    if len(matches) > 1:
        raise RuntimeError(
            f"{directory}: {len(matches)} shots match '{stem}*.png' "
            f"({', '.join(matches)}) -- expected exactly one"
        )
    return os.path.join(directory, matches[0]) if matches else None


def letterbox(path, size):
    """Rewrite the PNG at `path` so it is exactly `size`, page centred on FILL.

    Returns True if the file was rewritten, False if it already had that size.
    """
    with Image.open(path) as source:
        page = source.convert("RGB")

        if page.size == size:
            return False

        # Scale to the canvas WIDTH and let the height follow, which is what
        # keeps the page's proportions. Rounding up avoids a 1-px transparent
        # seam at the edge when the ratio does not divide evenly.
        width, height = size
        scaled_height = round(page.height * width / page.width)
        page = page.resize((width, scaled_height), Image.LANCZOS)

        # A page taller than the canvas would be a report whose aspect ratio is
        # more extreme than the phone's -- not possible for A4, but a silent
        # crop is not the way to find that out.
        if scaled_height > height:
            raise RuntimeError(
                f"{path}: page is {width}x{scaled_height} after scaling to the "
                f"canvas width, which is taller than the {width}x{height} "
                f"canvas -- it would have to be cropped"
            )

        canvas = Image.new("RGB", size, FILL)
        canvas.paste(page, (0, (height - scaled_height) // 2))
        canvas.save(path)
        return True


def main(argv):
    if len(argv) != 3:
        print(
            "usage: letterbox-ios-report.py <shots-dir> <device-prefix>",
            file=sys.stderr,
        )
        return 1

    base, prefix = argv[1], argv[2]
    if not os.path.isdir(base):
        print(f"letterbox-ios-report: {base} is not a directory", file=sys.stderr)
        return 1

    changed = 0
    for locale in sorted(os.listdir(base)):
        directory = os.path.join(base, locale)
        if not os.path.isdir(directory):
            continue

        try:
            reference = shot_path(directory, prefix, REFERENCE_NUMBER)
        except RuntimeError as error:
            print(f"letterbox-ios-report: {error}", file=sys.stderr)
            return 1

        # No 01 means this locale was never captured -- not this tool's problem
        # to diagnose, and not something to guess a canvas size for.
        if reference is None:
            continue
        with Image.open(reference) as image:
            size = image.size

        for number in REPORT_NUMBERS:
            try:
                path = shot_path(directory, prefix, number)
                # A missing page 08 is normal: a short report has one page, and
                # screenshots-ios says so rather than failing.
                if path is not None and letterbox(path, size):
                    print(
                        f"letterbox-ios-report: {locale}/{os.path.basename(path)} "
                        f"-> {size[0]}x{size[1]}"
                    )
                    changed += 1
            except (RuntimeError, OSError) as error:
                print(f"letterbox-ios-report: {error}", file=sys.stderr)
                return 1

    print(f"letterbox-ios-report: {changed} report page(s) fitted to the device canvas")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
