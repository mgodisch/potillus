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
render-guide-ios.py -- build-time renderer for the iOS user guides.

The iOS counterpart of tools/render-guide.py. Same idea, different platform:
the guide templates under ios/docs/guide/ carry the (already translated) prose
with every on-screen name written as a ``{{token}}`` instead of a hard-coded
word, and this script resolves those tokens so the guide can never drift from
the labels the app actually shows.

WHY A SEPARATE SCRIPT FROM THE ANDROID ONE
    render-guide.py resolves tokens from Android's ``strings.xml`` and writes
    into ``res/raw-<qualifier>/``. iOS keeps its labels in ``Localizable``
    ``.xcstrings`` (keyed by the English source string, not by a resource name),
    ships one flat resource bundle, and its guide text differs from Android's in
    a few platform-specific spots (Face ID vs a fingerprint, the App Switcher vs
    the recent-apps overview, the menu in the top-left rather than top-right).
    Those differences are why the iOS guide is authored separately, and this
    renderer targets the iOS catalogue and bundle layout instead.

TOKEN -> LABEL
    Each ``{{token}}`` names a screen or a settings row. TOKEN_TO_KEY maps it to
    the English key under which that label lives in the catalogue; the value for
    the guide's language is then read from that key's localizations (falling back
    to English, i.e. the key itself, when a language has no translation yet). An
    unknown token, or a token whose key is missing from the catalogue, is a hard
    error: a guide must never ship a raw ``{{token}}``.

OUTPUT
    For a template ``ios/docs/guide/usersguide[.<tag>].md.in`` it writes
    ``ios/Potillus/Resources/usersguide_<tag>.md`` (the bare template is English,
    ``usersguide_en.md``), with the licence-comment header stripped so a Markdown
    viewer shows clean text. The outputs are generated (gitignored), exactly like
    Resources/copyright.md; the running app selects the file for its in-app
    language, with an English fallback.

USAGE
    python3 tools/render-guide-ios.py           # write/refresh changed outputs
    python3 tools/render-guide-ios.py --check    # verify outputs are up to date
                                                 # (exit 1 if anything would change)
"""

import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TPL = os.path.join(ROOT, "ios", "docs", "guide")
OUT = os.path.join(ROOT, "ios", "Potillus", "Resources")
CATALOG = os.path.join(ROOT, "ios", "Potillus", "Localizable.xcstrings")

TOKEN_RE = re.compile(r"\{\{([a-z_]+)\}\}")

# Each guide token names a screen title or a settings row; this maps it to the
# English catalogue key that holds that label. The iOS wording differs from
# Android's for a few (Android "Biometric Lock" -> iOS "App lock", "Import" ->
# "Import backup"), which is exactly why the map is explicit rather than derived.
TOKEN_TO_KEY = {
    "today": "Today",
    "calendar": "Calendar",
    "statistics": "Statistics",
    "drinks": "Drinks",
    "settings": "Settings",
    "personal_data": "Personal data",
    "limits": "Limits",
    "backup_section": "Backup",
    "backup_export": "Export backup",
    "backup_import": "Import backup",
    "import_replace": "Replace my data",
    "import_merge": "Merge with my data",
    "security": "Security",
    "biometric_lock": "App lock",
    "allow_screenshots": "Show in app switcher",
    "appearance": "Appearance",
}


def load_catalog():
    with open(CATALOG, encoding="utf-8") as handle:
        return json.load(handle)["strings"]


def label(strings, key, tag):
    """The label for `key` in language `tag`, English (the key) as the fallback."""
    entry = strings.get(key)
    if entry is None:
        raise KeyError(f"catalogue has no key {key!r}")
    locs = entry.get("localizations", {})
    for candidate in (tag, "en"):
        unit = locs.get(candidate, {}).get("stringUnit")
        if unit and unit.get("value"):
            return unit["value"]
    return key  # source string IS the English text


def tag_for(path):
    """usersguide.md.in -> 'en'; usersguide.<tag>.md.in -> '<tag>'."""
    name = os.path.basename(path)
    middle = name[len("usersguide"):-len(".md.in")]  # "" or ".<tag>"
    return middle[1:] if middle.startswith(".") else "en"


def strip_licence_header(text):
    """Drop the leading <!-- ... --> licence block and the blank line after it."""
    if text.startswith("<!--"):
        end = text.index("-->") + len("-->")
        text = text[end:].lstrip("\n")
    return text


def render(strings, template_path):
    tag = tag_for(template_path)
    with open(template_path, encoding="utf-8") as handle:
        text = strip_licence_header(handle.read())

    def replace(match):
        token = match.group(1)
        if token not in TOKEN_TO_KEY:
            raise KeyError(f"{os.path.basename(template_path)}: unknown token {{{{{token}}}}}")
        return label(strings, TOKEN_TO_KEY[token], tag)

    return tag, TOKEN_RE.sub(replace, text)


def main():
    check = "--check" in sys.argv[1:]
    strings = load_catalog()
    templates = sorted(glob.glob(os.path.join(TPL, "usersguide*.md.in")))
    if not templates:
        print("render-guide-ios: no templates under ios/docs/guide/", file=sys.stderr)
        return 1

    stale = []
    for template in templates:
        tag, rendered = render(strings, template)
        out_path = os.path.join(OUT, f"usersguide_{tag}.md")
        current = None
        if os.path.exists(out_path):
            with open(out_path, encoding="utf-8") as handle:
                current = handle.read()
        if current == rendered:
            continue
        stale.append(os.path.relpath(out_path, ROOT))
        if not check:
            os.makedirs(OUT, exist_ok=True)
            with open(out_path, "w", encoding="utf-8") as handle:
                handle.write(rendered)

    if check and stale:
        print(
            "render-guide-ios: these guides are stale; run `make ios-guides`:\n  "
            + "\n  ".join(stale),
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
