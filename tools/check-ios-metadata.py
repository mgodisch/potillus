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
    5. THE REVIEWER CONTACT in review_information/: present, filled in, and in
       the shape App Store Connect demands.  This directory was excluded from
       the checks above as "not a locale" and so was checked by nothing at all;
       it reached its first real upload still holding the PLACEHOLDER text it
       shipped with.  Apple caught two of the four -- the email had no @, the
       phone no leading + and 51 bytes where 20 are allowed -- and, having no
       format rule for names, would have passed "PLACEHOLDER: reviewer contact
       first name" straight to the review team.  That is the asymmetry this
       section exists for: it checks the two fields Apple checks, and the two it
       does not.
       The four PII files are git-ignored (see .gitignore) and set up per
       machine from the .txt.example files beside them.  Their ABSENCE is
       therefore normal in a fresh clone and reported, not failed; what is not
       normal is a half-filled contact, so if any one of them exists, all four
       must, and all four must be valid.  push-appstore requires them outright,
       which is the moment they actually matter.
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

# ── The reviewer contact ─────────────────────────────────────────────────────
# fastlane's own folder name and file names; deliver reads <key>.txt from here.
REVIEW_DIR = "review_information"

# The four App Store Connect insists on, and that this repository does not keep:
# they are git-ignored and copied per machine from the .txt.example files.
REVIEW_REQUIRED = ("first_name.txt", "last_name.txt", "email_address.txt",
                   "phone_number.txt")

# App Store Connect's limit on the contact phone, quoted from its own rejection:
# "Phone number cannot be longer than 20 bytes". BYTES, not characters -- so it
# is measured after encoding, which is why a '+49 30 ...' with a non-breaking
# space would fail a length check that counted characters and passed.
PHONE_MAX_BYTES = 20

# The marker the shipped placeholders carry. Checked case-insensitively and in
# every file of the directory, including notes.txt and the demo credentials:
# the point is that nothing here reaches Apple still saying PLACEHOLDER.
PLACEHOLDER_MARKER = "placeholder"

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


def check_review_information():
    """Problems with the reviewer contact, as a list of strings.

    Returns an empty list both when everything is right and when the contact is
    simply not set up on this machine -- the caller distinguishes those two by
    asking `review_configured()`, because "absent" is a normal state worth a
    line of its own and a failure worth none.
    """
    directory = os.path.join(BASE, REVIEW_DIR)
    if not os.path.isdir(directory):
        return []

    present = [name for name in REVIEW_REQUIRED
               if os.path.isfile(os.path.join(directory, name))]

    # None of them: a fresh clone. The files are git-ignored by design, so this
    # is what every clone looks like before its first setup.
    if not present:
        return []

    # Some but not all: a half-filled contact, which no clone arrives at by
    # itself. deliver would send whatever it found and let Apple judge the rest.
    missing = [name for name in REVIEW_REQUIRED if name not in present]
    if missing:
        return [
            f"{REVIEW_DIR}/: {', '.join(missing)} missing while "
            f"{', '.join(present)} exist -- copy the .txt.example file(s) beside "
            f"them and fill in; a partial contact is not a contact"
        ]

    problems = []

    # The placeholders that shipped with the repository. Checked across every
    # file here, not just the four: notes.txt is uploaded too.
    for name in sorted(os.listdir(directory)):
        path = os.path.join(directory, name)
        if not os.path.isfile(path) or not name.endswith(".txt"):
            continue
        if PLACEHOLDER_MARKER in listing_text(path).lower():
            problems.append(
                f"{REVIEW_DIR}/{name}: still contains placeholder text -- Apple "
                f"has no format rule for most of these and would pass it to the "
                f"review team verbatim"
            )

    def value(name):
        return listing_text(os.path.join(directory, name)).strip()

    # The two Apple does NOT validate, and therefore the two that need us most.
    for name in ("first_name.txt", "last_name.txt"):
        if not value(name):
            problems.append(f"{REVIEW_DIR}/{name}: empty")

    # The two Apple does validate -- checked here so the answer arrives before
    # the upload rather than 29 seconds into it.
    email = value("email_address.txt")
    # Deliberately not a full RFC 5322 grammar: the aim is to catch a
    # placeholder or a typo'd address, and a stricter pattern would reject valid
    # addresses this project has no business rejecting.
    if email and (email.count("@") != 1 or "." not in email.split("@")[-1]
                  or " " in email):
        problems.append(
            f"{REVIEW_DIR}/email_address.txt: '{email}' is not an email address"
        )

    phone = value("phone_number.txt")
    if phone:
        if not phone.startswith("+"):
            problems.append(
                f"{REVIEW_DIR}/phone_number.txt: '{phone}' does not start with "
                f"'+' -- Apple wants the country code prefixed (e.g. +49 ...)"
            )
        encoded = len(phone.encode("utf-8"))
        if encoded > PHONE_MAX_BYTES:
            problems.append(
                f"{REVIEW_DIR}/phone_number.txt: {encoded} bytes exceeds Apple's "
                f"limit of {PHONE_MAX_BYTES}"
            )

    # Apple asks for demo credentials only when the app has a login. This one has
    # none, and notes.txt says so -- but one credential without the other is a
    # half-answer either way round.
    demo_user = value("demo_user.txt") if os.path.isfile(
        os.path.join(directory, "demo_user.txt")) else ""
    demo_password = value("demo_password.txt") if os.path.isfile(
        os.path.join(directory, "demo_password.txt")) else ""
    if bool(demo_user) != bool(demo_password):
        problems.append(
            f"{REVIEW_DIR}/: demo_user.txt and demo_password.txt must be either "
            f"both set or both empty"
        )

    return problems


def review_configured():
    """True when the reviewer contact exists on this machine at all."""
    directory = os.path.join(BASE, REVIEW_DIR)
    return any(
        os.path.isfile(os.path.join(directory, name)) for name in REVIEW_REQUIRED
    )


def main():
    # --release enforces the checks that only matter when actually cutting a
    # release. The per-locale App Store release notes (release_notes.txt) are the
    # iOS twin of Android's per-versionCode store changelogs (release-check.sh
    # SECTION 1): their translations are needed at push-appstore time, not on the
    # on-every-build `make ios` path. So off release mode this gate ignores
    # release_notes.txt entirely — its length is not checked and it is excluded
    # from the file-set parity comparison — and push-appstore-preflight passes
    # --release to enforce it. Deferred, not dropped: the release path still checks.
    release = "--release" in sys.argv[1:]
    deferred = () if release else ("release_notes.txt",)

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
            and name not in deferred
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

    # 5: the reviewer contact.
    problems.extend(check_review_information())

    if problems:
        for problem in problems:
            print(f"check-ios-metadata: {problem}", file=sys.stderr)
        print(f"check-ios-metadata: {len(problems)} problem(s) found", file=sys.stderr)
        return 1

    contact = (
        "reviewer contact OK"
        if review_configured()
        else "reviewer contact not set up on this machine (git-ignored; copy the "
             "review_information/*.txt.example files before push-appstore)"
    )
    print(
        f"check-ios-metadata: OK ({len(locales)} locales, all valid; "
        f"{len(LIMITS)} limits enforced; {contact})"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
