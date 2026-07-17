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
check-ios-metadata.py -- the App Store metadata twin of release-check.sh §10.

WHY THIS EXISTS
    The Android store metadata has a gate: release-check.sh section 10 enforces
    Google Play's length limits and that every locale carries the same file
    set, and its 0.82.0 hardening history shows why (an over-long note was
    rejected only AFTER all 21 locales had been uploaded).  The iOS metadata
    under fastlane/metadata/ios/ had no counterpart, so the same class of
    late, upload-time failure was one careless edit away (0.83.0 QA round).

WHAT IT CHECKS
    1. LENGTH LIMITS, per App Store Connect's documented store-listing limits,
       counted in characters after stripping ONE trailing newline (fastlane's
       deliver sends the file content verbatim; a trailing newline in the file
       is how these files are conventionally saved and is not part of the
       listing text):
           name.txt               30
           subtitle.txt           30
           keywords.txt          100
           promotional_text.txt  170
           description.txt      4000
           release_notes.txt    4000
    2. FILE-SET PARITY: every locale directory carries exactly the same set of
       files, so a note added for one language cannot silently be missing for
       another.  The `review_information/` directory is fastlane's reviewer
       contact folder, not a locale, and is excluded; so is the top-level
       copyright.txt, which deliver reads once for all locales.
    3. NON-EMPTY ESSENTIALS: name.txt and description.txt must not be empty in
       any locale -- deliver would push the empty string.
    4. LOCALE NAMES: every locale directory is one App Store Connect actually
       accepts.  deliver validates this itself, but only once an upload is
       already under way -- 0.83.1 lost two upload attempts to it, because the
       tree had carried `es`, `fr` and `nl` (valid Xcode language tags, and the
       names the app's own Localizable.xcstrings still uses) where the store
       wants `es-ES`, `fr-FR` and `nl-NL`.  Nothing before the upload had an
       opinion, so the names sat there, wrong and quiet, for as long as the app
       had never shipped to the App Store.  The same list also governs
       fastlane/screenshots/ios/, whose directories deliver validates in the
       same breath; the Snapfile derives those names from the metadata ones, so
       checking here covers both.

GRACEFUL SKIP
    A tree without fastlane/metadata/ios/ (an Android-only source drop) is not
    an error: the check prints an informational line and exits 0, following
    the project's gate-design rule that a check must not false-fail in
    environments that lack its inputs.

USAGE
    tools/check-ios-metadata.py
    Exit status: 0 = clean or skipped, 1 = problems found.
"""

import os
import sys

# Repository root: the parent of tools/.
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(ROOT, "fastlane", "metadata", "ios")

# App Store Connect's store-listing limits, per file name.
LIMITS = {
    "name.txt": 30,
    "subtitle.txt": 30,
    "keywords.txt": 100,
    "promotional_text.txt": 170,
    "description.txt": 4000,
    "release_notes.txt": 4000,
}

# Files that must not be empty in any locale.
REQUIRED_NON_EMPTY = ("name.txt", "description.txt")

# Directory entries under BASE that are not locales.
NOT_A_LOCALE = {"review_information"}

# The locale directory names App Store Connect accepts, verbatim from deliver's
# own error message and from the "Available language codes" list in
# docs.fastlane.tools/actions/upload_to_app_store.  These are STORE locales and
# are a different namespace from the app's own language tags in
# ios/Potillus/Localizable.xcstrings -- `es` is a correct catalogue tag and a
# wrong store directory, which is precisely why this needs checking.  The
# platform pseudo-locales deliver also accepts (appleTV, iMessage, default) are
# omitted deliberately: this app ships none of them, and listing them here would
# let a typo like `imessage` pass as intentional.
VALID_LOCALES = {
    "ar-SA", "bn-BD", "ca", "cs", "da", "de-DE", "el", "en-AU", "en-CA",
    "en-GB", "en-US", "es-ES", "es-MX", "fi", "fr-CA", "fr-FR", "gu-IN", "he",
    "hi", "hr", "hu", "id", "it", "ja", "kn-IN", "ko", "ml-IN", "mr-IN", "ms",
    "nl-NL", "no", "or-IN", "pa-IN", "pl", "pt-BR", "pt-PT", "ro", "ru", "sk",
    "sl-SI", "sv", "ta-IN", "te-IN", "th", "tr", "uk", "ur-PK", "vi",
    "zh-Hans", "zh-Hant",
}


def listing_text(path):
    """The characters deliver would send: the file minus ONE trailing newline."""
    with open(path, encoding="utf-8") as handle:
        text = handle.read()
    return text[:-1] if text.endswith("\n") else text


def main():
    if not os.path.isdir(BASE):
        print("check-ios-metadata: fastlane/metadata/ios/ not present -- skipped")
        return 0

    locales = sorted(
        entry
        for entry in os.listdir(BASE)
        if os.path.isdir(os.path.join(BASE, entry)) and entry not in NOT_A_LOCALE
    )
    problems = []

    # 4: locale directory names. Reported first because a wrong name makes every
    # other finding for that directory moot -- deliver rejects the whole upload
    # before it reads a single .txt. The hint lists the valid locales sharing the
    # bad name's language subtag, which is what a name like `es` is usually one
    # region suffix away from; where that yields more than one (es-ES/es-MX), the
    # choice is a reach decision the maintainer makes, not one this gate makes.
    for locale in locales:
        if locale in VALID_LOCALES:
            continue
        subtag = locale.split("-")[0]
        near = sorted(v for v in VALID_LOCALES if v.split("-")[0] == subtag)
        hint = f" -- did you mean {' or '.join(near)}?" if near else ""
        problems.append(
            f"{locale}: not a locale App Store Connect accepts{hint}"
        )

    # 1 + 3: limits and required content, per locale.
    file_sets = {}
    for locale in locales:
        directory = os.path.join(BASE, locale)
        files = sorted(
            name
            for name in os.listdir(directory)
            if os.path.isfile(os.path.join(directory, name))
        )
        file_sets[locale] = tuple(files)
        for name in files:
            limit = LIMITS.get(name)
            if limit is None:
                continue
            text = listing_text(os.path.join(directory, name))
            if len(text) > limit:
                problems.append(
                    f"{locale}/{name}: {len(text)} characters exceeds the "
                    f"App Store limit of {limit}"
                )
        for name in REQUIRED_NON_EMPTY:
            path = os.path.join(directory, name)
            if name in files and not listing_text(path).strip():
                problems.append(f"{locale}/{name}: empty")

    # 2: file-set parity across locales, reported against the majority set so
    # the message names the deviant locale, not all of them.
    if locales:
        counts = {}
        for files in file_sets.values():
            counts[files] = counts.get(files, 0) + 1
        majority = max(counts, key=counts.get)
        for locale, files in sorted(file_sets.items()):
            if files != majority:
                missing = sorted(set(majority) - set(files))
                extra = sorted(set(files) - set(majority))
                detail = []
                if missing:
                    detail.append("missing: " + ", ".join(missing))
                if extra:
                    detail.append("extra: " + ", ".join(extra))
                problems.append(f"{locale}: file set differs ({'; '.join(detail)})")

    if problems:
        for problem in problems:
            print(f"check-ios-metadata: {problem}", file=sys.stderr)
        print(f"check-ios-metadata: {len(problems)} problem(s) found", file=sys.stderr)
        return 1

    print(
        f"check-ios-metadata: OK ({len(locales)} locales, all valid; "
        f"{len(LIMITS)} limits enforced)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
