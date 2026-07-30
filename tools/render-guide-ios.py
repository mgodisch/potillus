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
    the recent-apps overview, a toolbar "+" rather than a floating button).
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
    ``usersguide_en.md``), with the license-comment header stripped so a Markdown
    viewer shows clean text. The outputs are generated (gitignored), exactly like
    Resources/license_gpl3.md; the running app selects the file for its in-app
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

from potillus_repo import repo_root

ROOT = str(repo_root())
TPL = os.path.join(ROOT, "ios", "docs", "guide")
OUT = os.path.join(ROOT, "ios", "Potillus", "Resources")
CATALOG = os.path.join(ROOT, "ios", "Potillus", "Localizable.xcstrings")

# Digits are part of a token name (`weekly_limit_grams` has none, but a future
# `limit_7d` would): the Android renderer has always allowed them, and a pattern
# that did not would leave such a token unresolved in the shipped guide instead
# of failing the build.
TOKEN_RE = re.compile(r"\{\{([a-z0-9_]+)\}\}")

# Each guide token names a screen title, a settings row, a field label or one of
# the words a legend spells out; this maps it to the English catalogue key that
# holds that label. The map is explicit rather than derived from Android's
# resource names, because the two platforms do not always say the same thing in
# the same place: Android's `week` reads "7 Days" where iOS says "Week", and iOS
# has a row Android has none of (`device_backup`) while Android has labels iOS
# never shows (`pure_alcohol`, `no_data`, `select_drink`), which is why those
# tokens are absent here and must not appear in an iOS template.
#
# EVERY VALUE IS A LABEL THE APP ACTUALLY SHOWS. Five of them were not: the map
# pointed `biometric_lock` at "App lock", `backup_export` at "Export backup",
# `backup_import` at "Import backup", `import_replace` at "Replace my data" and
# `import_merge` at "Merge with my data" -- catalogue keys that no view reads, so
# the guide named buttons the user cannot find (0.85.0 QA round). When a label
# changes in a view, it changes here.
TOKEN_TO_KEY = {
    # The four main screens and the overflow menu.
    "today": "Today",
    "calendar": "Calendar",
    "statistics": "Statistics",
    "drinks": "Drinks",
    "settings": "Settings",
    "menu": "Menu",
    "help": "Help",
    "about": "About",
    "lock_app": "Lock app",
    # Settings: personal data, limits, the logical day, the statistics floor.
    "personal_data": "Personal Data",
    "body_weight": "Body Weight",
    "limits": "Limits",
    "daily_limit_grams": "Daily Limit in Grams",
    "weekly_limit_grams": "7-Day Limit in Grams",
    "drink_days_setting": "Max. Drinking Days/7 Days",
    "day_starts_at": "New Day Starts At",
    "stats_from_label": "Statistics From",
    "stats_from_clear": "Include all history",
    # Logging an entry and correcting it.
    "drink": "Drink",
    "volume_ml": "Amount",
    "time": "Time",
    "note": "Note",
    "alcohol_content": "Alcohol Content",
    "edit_entry": "Edit Entry",
    "delete": "Delete",
    "favorites_quick": "Quick Selection Favorites",
    # The Today summary and the capacity dot.
    "total_today": "Today's Total",
    "drink_days_label": "Drinking Days (last 7 days)",
    "capacity_status_ok": "Within your limits",
    "capacity_status_low": "Almost at your limit",
    "capacity_status_reached": "Limit reached",
    # The drink catalogue.
    "add_drink": "Add Drink",
    "edit_drink": "Edit Drink",
    "drink_name": "Name",
    "alcohol_percent": "Alcohol (%)",
    "category": "Category",
    "category_beer": "Beer",
    "category_wine": "Wine / Sparkling Wine",
    "category_spirits": "Spirits",
    "category_longdrink": "Long Drink / Mix",
    "category_liqueur": "Liqueur",
    "category_other": "Other",
    # The year heat-map's legend.
    "year_calendar_no_entry": "no entry",
    "year_calendar_under_limit": "under limit",
    "year_calendar_over_limit": "over limit",
    # Statistics: the period, the figures, the charts.
    "week": "Week",
    "month": "Month",
    "year": "Year",
    "total_period": "Total in Period",
    "avg_per_day": "Average per Day",
    "avg_per_drink_day": "Average per Drinking Day",
    "days_over_daily_limit": "Days Over Daily Limit",
    "days_over_weekly_limit": "Days Over 7-Day Limit",
    "days_over_drink_day_limit": "Days Over Drinking Days Limit",
    "abstinent_days": "Abstinent Days",
    "streak_trend": "Abstinence & Trend",
    "current_streak": "Current Abstinence",
    "longest_streak": "Longest Abstinence",
    "trend_vs_prev": "Trend vs. Previous Period",
    "stats_time_of_day": "Time of Day",
    "stats_weekday": "Weekday",
    "stats_category_breakdown": "Categories",
    # Export and backup.
    "export": "Export",
    "export_csv": "Export CSV",
    "export_pdf": "Export PDF report",
    "backup_section": "Backup",
    "backup_include_settings": "Include settings",
    "backup_export": "Export",
    "backup_import": "Import",
    "import_replace": "Replace",
    "import_merge": "Merge",
    # Security and appearance.
    "security": "Security",
    "biometric_lock": "Biometric Lock",
    "allow_screenshots": "Show in app switcher",
    "device_backup": "Include in device backup",
    "appearance": "Appearance",
    "theme_mode": "Color Scheme",
    "theme_system": "System",
    "theme_day": "Light",
    "theme_night": "Dark",
    "language": "Language",
    "language_system": "(System)",
    "alt_status_symbols": "Alternative Status Symbols",
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


def strip_license_header(text):
    """Drop the leading <!-- ... --> license block and the blank line after it."""
    if text.startswith("<!--"):
        end = text.index("-->") + len("-->")
        text = text[end:].lstrip("\n")
    return text


def render(strings, template_path):
    tag = tag_for(template_path)
    with open(template_path, encoding="utf-8") as handle:
        text = strip_license_header(handle.read())

    def replace(match):
        token = match.group(1)
        if token not in TOKEN_TO_KEY:
            raise KeyError(f"{os.path.basename(template_path)}: unknown token {{{{{token}}}}}")
        return label(strings, TOKEN_TO_KEY[token], tag)

    return tag, TOKEN_RE.sub(replace, text)


def emit_make_deps(templates):
    """Print a self-contained Makefile fragment describing the guide outputs.

    For every language it emits one prerequisite-only rule

        Potillus/Resources/usersguide_<tag>.md: <template>.md.in \\
            Potillus/Localizable.xcstrings ../tools/render-guide-ios.py

    plus an ``IOS_GUIDE_OUTPUTS`` variable listing all outputs. Paths are
    relative to the ``ios/`` directory, where ``make`` runs, so ios/Makefile can
    ``-include`` the fragment.

    Only PREREQUISITES are emitted; the recipe comes from ios/Makefile's single
    shared guide rule. That split is what lets make -- rather than a phony target
    that runs on every build -- decide which guides are stale, while the LANGUAGE
    SET stays discovered here from the template files, so adding a
    ``usersguide.xx.md.in`` makes its rule appear on its own.

    The Android twin is `render-guide.py --make-deps`; the two are deliberately
    the same shape, down to the variable-plus-rules layout, so that a reader who
    has understood one has understood the other.
    """
    ios_dir = os.path.join(ROOT, "ios")
    renderer = os.path.relpath(os.path.abspath(__file__), ios_dir)
    catalog = os.path.relpath(CATALOG, ios_dir)
    outputs, rules = [], []
    for template in templates:
        tag = tag_for(template)
        out = os.path.relpath(os.path.join(OUT, f"usersguide_{tag}.md"), ios_dir)
        tpl = os.path.relpath(template, ios_dir)
        outputs.append(out)
        rules.append(f"{out}: {tpl} {catalog} {renderer}")
    print("# Auto-generated by `render-guide-ios.py --make-deps`; do not edit or commit.")
    print("IOS_GUIDE_OUTPUTS := " + " ".join(outputs))
    print("\n".join(rules))
    return 0


def main():
    check = "--check" in sys.argv[1:]
    make_deps = "--make-deps" in sys.argv[1:]
    strings = load_catalog()
    templates = sorted(glob.glob(os.path.join(TPL, "usersguide*.md.in")))
    if not templates:
        print("render-guide-ios: no templates under ios/docs/guide/", file=sys.stderr)
        return 1

    if make_deps:
        return emit_make_deps(templates)

    stale = []
    missing = []
    english = None
    for template in templates:
        tag, rendered = render(strings, template)
        if tag == "en":
            english = rendered
        out_path = os.path.join(OUT, f"usersguide_{tag}.md")
        if not os.path.exists(out_path):
            # NOT stale. Nothing has drifted from anything -- the build has simply
            # not run yet. This is the normal state of a fresh clone (git tracks
            # no file under Resources/, so the directory does not even exist) and
            # of the Linux release path, where `make ios` never runs. Calling it
            # stale made `make ios` fail on its FIRST run in a fresh tree:
            # `check-guides` (via the root `check-ios-static`) runs BEFORE the
            # `make -C ios project` target that renders them.
            missing.append(os.path.relpath(out_path, ROOT))
            if not check:
                os.makedirs(OUT, exist_ok=True)
                with open(out_path, "w", encoding="utf-8") as handle:
                    handle.write(rendered)
            continue
        with open(out_path, encoding="utf-8") as handle:
            current = handle.read()
        if current == rendered:
            continue
        stale.append(os.path.relpath(out_path, ROOT))
        if not check:
            os.makedirs(OUT, exist_ok=True)
            with open(out_path, "w", encoding="utf-8") as handle:
                handle.write(rendered)

    # The committed, human-facing English guide (ios/docs/guide/usersguide.md): a
    # rendered sibling of usersguide.md.in that GitLab displays (it renders .md,
    # not .md.in) and that the OpenSSF badge justifications link to. Unlike the
    # gitignored app-bundle outputs above, THIS file is committed, so a missing or
    # stale copy is a hard error under --check -- there is no "fresh clone" excuse,
    # because git tracks it.
    doc_path = os.path.join(TPL, "usersguide.md")
    doc_stale = False
    if english is not None:
        exists = os.path.exists(doc_path)
        current = open(doc_path, encoding="utf-8").read() if exists else None
        if current != english:
            doc_stale = True
            if not check:
                with open(doc_path, "w", encoding="utf-8") as handle:
                    handle.write(english)

    if check:
        if stale:
            print(
                "render-guide-ios: these guides are stale; run `make -C ios guides`:\n  "
                + "\n  ".join(stale),
                file=sys.stderr,
            )
            return 1
        if doc_stale:
            print(
                "render-guide-ios: the committed English guide is missing or stale; "
                "run `make -C ios guides`:\n  "
                + os.path.relpath(doc_path, ROOT),
                file=sys.stderr,
            )
            return 1
        if missing:
            print(
                f"render-guide-ios: {len(missing)} guide(s) not rendered yet — "
                "`make -C ios guides` will create them; nothing to check"
            )
    return 0


if __name__ == "__main__":
    sys.exit(main())
