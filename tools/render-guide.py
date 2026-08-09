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
render-guide.py -- build-time renderer for the localized user guides.

WHAT IT DOES
------------
The user guides live as *templates* under ``docs/guide/``: a code-less default
``usersguide.md.in`` (English) and one ``usersguide.<tag>.md.in`` per translated
language. ONE template serves BOTH platforms. The prose in each is already
translated, but every on-screen name (screen titles, settings rows, the words a
legend spells out) is written as a ``{{token}}`` instead of a hard-coded word,
and every passage that differs between Android and iOS sits in a platform block.
This script picks the blocks for one platform, resolves the tokens against that
platform's own string store, and writes the result where the app can bundle it.

PLATFORM BLOCKS
---------------
A block is opened by ``{{#android}}`` or ``{{#ios}}`` and closed by
``{{/android}}`` / ``{{/ios}}``, each marker ALONE ON ITS LINE. Blocks of the
other platform are removed whole; the surviving ones lose their markers::

    {{#android}}
    Unten rechts sitzt die Plus-Taste.
    {{/android}}
    {{#ios}}
    Oben rechts sitzt die Plus-Taste.
    {{/ios}}

There is no ``else``: where both platforms speak, two blocks stand next to each
other, which reads better in the source than a branch and keeps the translator's
unit of work a paragraph rather than a construct.

STRIP FIRST, THEN SUBSTITUTE. This order is what lets a block mention a label
that only ONE platform has -- ``{{pure_alcohol}}`` (Android) or
``{{device_backup}}`` (iOS). The tokens of the removed block are gone before any
lookup happens, so neither platform needs a placeholder for a row its app does
not show. A one-platform token used OUTSIDE its block fails the build, which is
the intended alarm.

LANGUAGE DISCOVERY (no hard-coded list)
---------------------------------------
The set of languages is discovered from the template files under ``docs/guide/``.
The code-less ``usersguide.md.in`` is the default and feeds Android's unqualified
``values`` / ``raw`` directories and iOS's ``usersguide_en.md``. Tags are BCP-47:
``de``, ``pt-BR``, ``zh-Hans``. Adding a ``usersguide.xx.md.in`` (with matching
UI strings on both platforms) is picked up automatically.

Android's resource qualifiers are not BCP-47 and are derived here: a bare
language is unchanged (``de``), a region tag becomes ``ll-rRR`` (``pt-BR`` ->
``pt-rBR``), and the two Chinese script tags are mapped by table (``zh-Hans`` ->
``zh-rCN``), because Android names those directories by region. iOS uses the tag
as it stands -- it is the String Catalogue's own key.

LANGUAGE PARITY GUARD
---------------------
The sources of truth for "which languages does Libellus Potionis ship" are these
templates and, per platform, the ``values-<q>/strings.xml`` directories
(Android) or the localizations in ``Localizable.xcstrings`` (iOS). They MUST
describe the same set, or a language could have UI strings but no guide, or a
guide with no UI strings. :func:`check_language_parity` compares them before
rendering and aborts with a precise diff. It runs in every mode, so neither a
build nor CI can let the sets drift.

OUTPUT & WHEN IT IS (RE)GENERATED
---------------------------------
``--platform android`` writes ``android/app/src/main/res/<raw_dir>/usersguide.md``;
``--platform ios`` writes ``ios/Potillus/Resources/usersguide_<tag>.md``. Both
strip the license-comment header so a Markdown viewer shows clean text, and both
are generated (git-ignored). Each platform also refreshes its COMMITTED English
copy, ``docs/guide/usersguide.android.md`` and ``docs/guide/usersguide.ios.md``:
GitLab renders ``.md`` but not ``.md.in``, and the README and the OpenSSF badge
justifications link to them.

In write mode an output is regenerated when it is missing or older than its
inputs (template or string store). ``--check`` ignores timestamps and compares
content, so CI fails whenever a committed guide would differ. A guide that was
never rendered has drifted from nothing and is reported, not failed -- that is
the normal state of a fresh clone.

TOKEN RESOLUTION
----------------
Android reads ``strings.xml`` and undoes Android's own backslash escaping, which
survives XML parsing. iOS reads the String Catalogue, whose keys ARE the English
source strings, through :data:`TOKEN_TO_KEY`.

USAGE
-----
    python3 tools/render-guide.py --platform android
    python3 tools/render-guide.py --platform ios --check
    python3 tools/render-guide.py --platform android --make-deps
"""

import glob
import json
import os
import re
import sys
import xml.etree.ElementTree as ET

from potillus_repo import repo_root

ROOT = str(repo_root())
TPL = os.path.join(ROOT, "docs", "guide")
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
IOS_OUT = os.path.join(ROOT, "ios", "Potillus", "Resources")
CATALOG = os.path.join(ROOT, "ios", "Potillus", "Localizable.xcstrings")

PLATFORMS = ("android", "ios")

# Digits are part of a token name: `weekly_limit_grams` has none, but a future
# `limit_7d` would, and a pattern that did not allow them would leave such a
# token unresolved in the shipped guide instead of failing the build.
TOKEN_RE = re.compile(r"\{\{([a-z0-9_]+)\}\}")

# A block marker owns its line. Anchoring on the line keeps the two jobs apart:
# TOKEN_RE never sees a marker (no `#` or `/` in its character class), and the
# stripper never has to reason about prose around a marker.
MARKER_RE = re.compile(r"^\{\{(#|/)([a-z]+)\}\}$", re.M)

# Each guide token names a screen title, a settings row, a field label or one of
# the words a legend spells out; this maps it to the English catalogue key that
# holds that label on iOS. The map is explicit rather than derived from Android's
# resource names, because the two platforms do not always say the same thing in
# the same place: Android's `week` reads "7 Days" where iOS says "Week", and iOS
# has a row Android has none of (`device_backup`) while Android has labels iOS
# never shows (`pure_alcohol`, `no_data`, `select_drink`), which is why those
# tokens are absent here and must appear only inside an {{#android}} block.
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


# ── Templates and languages ──────────────────────────────────────────────────

def tag_for(path: str) -> str:
    """``usersguide.md.in`` -> ``en``; ``usersguide.<tag>.md.in`` -> ``<tag>``."""
    name = os.path.basename(path)
    middle = name[len("usersguide"):-len(".md.in")]  # "" or ".<tag>"
    return middle[1:] if middle.startswith(".") else "en"


def templates() -> list:
    """Every template under ``docs/guide/``, sorted, as ``(tag, path)``."""
    found = sorted(glob.glob(os.path.join(TPL, "usersguide*.md.in")))
    return [(tag_for(path), path) for path in found]


# Android names its Chinese resource directories by REGION (zh-rCN, zh-rTW)
# while the catalogue -- and therefore the shared template -- uses the SCRIPT
# tags the rest of the world settled on. The pair is listed rather than derived
# because no rule connects "Hans" to "CN"; it is a convention on each side.
SCRIPT_TO_QUALIFIER = {"zh-Hans": "zh-rCN", "zh-Hant": "zh-rTW"}
QUALIFIER_TO_SCRIPT = {v: k for k, v in SCRIPT_TO_QUALIFIER.items()}

QUALIFIER_REGION_RE = re.compile(r"^([a-z]{2,3})-r([A-Za-z0-9]+)$")


def android_qualifier(tag: str) -> str:
    """Map a BCP-47 tag to its Android resource qualifier."""
    if tag in SCRIPT_TO_QUALIFIER:
        return SCRIPT_TO_QUALIFIER[tag]
    parts = tag.split("-")
    return f"{parts[0]}-r{parts[1]}" if len(parts) == 2 else tag


def bcp47_from_qualifier(qualifier: str) -> str:
    """Map an Android resource qualifier back to its BCP-47 tag."""
    if qualifier in QUALIFIER_TO_SCRIPT:
        return QUALIFIER_TO_SCRIPT[qualifier]
    m = QUALIFIER_REGION_RE.match(qualifier)
    return f"{m.group(1)}-{m.group(2)}" if m else qualifier


def android_languages() -> set:
    """BCP-47 tags that ship Android string resources.

    Every ``values-<q>/`` contributes one tag, EXCEPT the non-locale qualifiers
    ``values-night`` and ``values-vNN``. The English base lives in the
    unqualified ``values/``, so ``en`` is added explicitly.
    """
    tags = {"en"}
    for entry in os.listdir(RES):
        if not entry.startswith("values-"):
            continue
        if entry == "values-night" or re.fullmatch(r"values-v\d+", entry):
            continue
        tags.add(bcp47_from_qualifier(entry[len("values-"):]))
    return tags


def ios_languages(catalog: dict) -> set:
    """BCP-47 tags the String Catalogue carries a localization for."""
    tags = set()
    for entry in catalog.values():
        tags |= set(entry.get("localizations", {}).keys())
    return tags


def check_language_parity(tags: set, platform: str, catalog: dict) -> None:
    """Abort when the template languages and the platform's languages diverge."""
    if platform == "android":
        have, source = android_languages(), "values-<q>/strings.xml"
        fix = "add the values-<qualifier>/strings.xml or remove the template"
    else:
        have, source = ios_languages(catalog), "Localizable.xcstrings"
        fix = "add the localization to the catalogue or remove the template"
    if tags == have:
        return
    lines = [f"render-guide: [{platform}] guide languages and UI languages are out of sync."]
    if have - tags:
        lines.append(
            f"  {source} present but NO guide template: " + ", ".join(sorted(have - tags))
            + "\n    -> add docs/guide/usersguide.<tag>.md.in for each"
        )
    if tags - have:
        lines.append(
            f"  guide template present but NO {source}: " + ", ".join(sorted(tags - have))
            + f"\n    -> {fix}"
        )
    sys.exit("\n".join(lines))


# ── Rendering ────────────────────────────────────────────────────────────────

def strip_platform(text: str, platform: str, label: str) -> str:
    """Keep *platform*'s blocks, drop the other's, and validate the markers.

    Validation first, because a silently swallowed half-block is the failure
    mode that would ship: an unclosed ``{{#ios}}`` would otherwise eat the rest
    of the guide on Android and nobody would notice until a reader complained.
    """
    depth = 0
    open_name = None
    for m in MARKER_RE.finditer(text):
        kind, name = m.group(1), m.group(2)
        line = text.count("\n", 0, m.start()) + 1
        if name not in PLATFORMS:
            sys.exit(f"render-guide: [{label}] line {line}: unknown block {{{{{kind}{name}}}}}")
        if kind == "#":
            if depth:
                sys.exit(f"render-guide: [{label}] line {line}: {name} block inside {open_name}")
            depth, open_name = 1, name
        else:
            if not depth or name != open_name:
                sys.exit(f"render-guide: [{label}] line {line}: {{{{/{name}}}}} closes nothing")
            depth, open_name = 0, None
    if depth:
        sys.exit(f"render-guide: [{label}] unclosed {{{{#{open_name}}}}} block")

    other = "ios" if platform == "android" else "android"
    text = re.sub(rf"^\{{\{{#{other}\}}\}}\n.*?^\{{\{{/{other}\}}\}}\n", "", text,
                  flags=re.S | re.M)
    text = re.sub(rf"^\{{\{{[#/]{platform}\}}\}}\n", "", text, flags=re.M)
    # Removing a block between two paragraphs leaves its blank lines behind.
    return re.sub(r"\n{3,}", "\n\n", text)


def unescape_android(value: str) -> str:
    """Undo Android string escaping that survives XML parsing.

    Handles ``\\n`` / ``\\t`` and the literal escapes ``\\'``, ``\\"`` and
    ``\\\\``. Also strips the optional surrounding double quotes Android uses to
    preserve leading/trailing whitespace (not expected for screen names, handled
    defensively).
    """
    if len(value) >= 2 and value[0] == '"' and value[-1] == '"':
        value = value[1:-1]
    return re.sub(r"\\(.)",
                  lambda m: {"n": "\n", "t": "\t"}.get(m.group(1), m.group(1)),
                  value)


def android_strings(tag: str) -> dict:
    """``{name: unescaped text}`` for one language's ``strings.xml``."""
    values = "values" if tag == "en" else f"values-{android_qualifier(tag)}"
    path = os.path.join(RES, values, "strings.xml")
    if not os.path.exists(path):
        sys.exit(f"render-guide: [{tag}] missing {path}")
    root = ET.parse(path).getroot()
    return {el.get("name"): unescape_android(el.text or "") for el in root.findall("string")}


def ios_label(catalog: dict, key: str, tag: str) -> str:
    """The label for *key* in language *tag*, English (the key) as the fallback."""
    entry = catalog.get(key)
    if entry is None:
        raise KeyError(f"catalogue has no key {key!r}")
    locs = entry.get("localizations", {})
    for candidate in (tag, "en"):
        unit = locs.get(candidate, {}).get("stringUnit")
        if unit and unit.get("value"):
            return unit["value"]
    return key  # the source string IS the English text


def strip_header(text: str) -> str:
    """Remove the leading ``<!-- ... -->`` license block and blank lines."""
    if text.lstrip().startswith("<!--"):
        end = text.find("-->")
        if end != -1:
            text = text[end + len("-->"):]
    return text.lstrip("\n")


def render(tag: str, path: str, platform: str, catalog: dict) -> str:
    """One template, one platform: blocks picked, tokens resolved, header gone."""
    with open(path, encoding="utf-8") as fh:
        text = strip_platform(fh.read(), platform, tag)

    if platform == "android":
        strings = android_strings(tag)

        def repl(m):
            key = m.group(1)
            if key not in strings:
                sys.exit(
                    f"render-guide: [{tag}] unknown string key '{{{{{key}}}}}'. "
                    f"Add <string name=\"{key}\"> to the locale or fix the template."
                )
            return strings[key]
    else:
        def repl(m):
            token = m.group(1)
            if token not in TOKEN_TO_KEY:
                sys.exit(
                    f"render-guide: [{tag}] unknown token '{{{{{token}}}}}'. "
                    "Add it to TOKEN_TO_KEY, or move it into an {{#android}} block."
                )
            return ios_label(catalog, TOKEN_TO_KEY[token], tag)

    # A block at the very end leaves the blank line that separated it from the
    # next paragraph; one trailing newline is what every other guide file has.
    return strip_header(TOKEN_RE.sub(repl, text)).rstrip("\n") + "\n"


def output_path(tag: str, platform: str) -> str:
    """Where the in-app copy of one guide belongs."""
    if platform == "android":
        raw = "raw" if tag == "en" else f"raw-{android_qualifier(tag)}"
        return os.path.join(RES, raw, "usersguide.md")
    return os.path.join(IOS_OUT, f"usersguide_{tag}.md")


def source_path(tag: str, platform: str) -> str:
    """The string store a guide is rendered against (a make prerequisite)."""
    if platform == "android":
        values = "values" if tag == "en" else f"values-{android_qualifier(tag)}"
        return os.path.join(RES, values, "strings.xml")
    return CATALOG


# ── Modes ────────────────────────────────────────────────────────────────────

def emit_make_deps(tags, platform: str) -> int:
    """Print a Makefile fragment wiring each output to its inputs.

    Only PREREQUISITES are emitted -- the recipe comes from the platform's
    Makefile, so make (not a phony that runs on every build) decides which
    guides are stale, while the LANGUAGE SET stays discovered here from the
    template files. Paths are relative to the directory where that make runs.
    """
    base = os.path.join(ROOT, platform)
    renderer = os.path.relpath(os.path.abspath(__file__), base)
    variable = "GUIDE_OUTPUTS" if platform == "android" else "IOS_GUIDE_OUTPUTS"
    outputs, rules = [], []
    for tag, tpl in tags:
        out = os.path.relpath(output_path(tag, platform), base)
        rules.append(f"{out}: {os.path.relpath(tpl, base)} "
                     f"{os.path.relpath(source_path(tag, platform), base)} {renderer}")
        outputs.append(out)
    print(f"# Auto-generated by `render-guide.py --platform {platform} --make-deps`; "
          "do not edit or commit.")
    print(f"{variable} := " + " ".join(outputs))
    print("\n".join(rules))
    return 0


def write_if_changed(path: str, content: str, check_only: bool) -> str:
    """Write *content* unless unchanged: ``current``, ``stale`` or ``missing``.

    STALE AND MISSING ARE NOT THE SAME THING, and --check must not confuse them:
    a guide that has never been rendered has drifted from nothing. Absent is the
    normal state of a fresh clone -- git tracks no rendered guide -- and a check
    on such a tree must not report all 21 as out of date.
    """
    if not os.path.exists(path):
        if not check_only:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(content)
        return "missing"
    with open(path, encoding="utf-8") as fh:
        if fh.read() == content:
            return "current"
    if not check_only:
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(content)
    return "stale"


def main() -> int:
    argv = sys.argv[1:]
    check_only = "--check" in argv
    make_deps = "--make-deps" in argv
    platform = None
    if "--platform" in argv:
        idx = argv.index("--platform")
        platform = argv[idx + 1] if idx + 1 < len(argv) else None
    if platform not in PLATFORMS:
        sys.exit("render-guide: --platform android|ios is required")

    found = templates()
    if not found:
        sys.exit(f"render-guide: no usersguide*.md.in templates found under {TPL}")

    catalog = {}
    if platform == "ios":
        with open(CATALOG, encoding="utf-8") as fh:
            catalog = json.load(fh)["strings"]

    # Hard gate in every mode, so a build, CI and the dependency fragment all
    # fail fast on any drift.
    check_language_parity({tag for tag, _ in found}, platform, catalog)

    if make_deps:
        return emit_make_deps(found, platform)

    stale, missing, skipped = [], [], 0
    for tag, tpl in found:
        out_path = output_path(tag, platform)
        src = source_path(tag, platform)
        # Write mode regenerates only what is missing or older than its inputs;
        # --check ignores timestamps and compares content below.
        if not check_only and os.path.exists(out_path):
            if os.path.getmtime(out_path) >= max(os.path.getmtime(tpl), os.path.getmtime(src)):
                skipped += 1
                continue
        outcome = write_if_changed(out_path, render(tag, tpl, platform, catalog), check_only)
        if outcome == "stale":
            stale.append(os.path.relpath(out_path, ROOT))
        elif outcome == "missing":
            missing.append(os.path.relpath(out_path, ROOT))

    # The committed, human-facing English guide. GitLab renders .md but not
    # .md.in, and the README and the OpenSSF badge justifications link to it. It
    # is COMMITTED, so --check treats a missing or stale copy as a hard error;
    # there is no fresh-clone excuse when git tracks the file.
    doc_path = os.path.join(TPL, f"usersguide.{platform}.md")
    english = render("en", os.path.join(TPL, "usersguide.md.in"), platform, catalog)
    doc_stale = write_if_changed(doc_path, english, check_only) != "current"

    if check_only:
        if missing and not stale:
            print(f"render-guide: [{platform}] {len(missing)} guide(s) not rendered yet — "
                  f"`make -C {platform} guides` will create them; nothing to check")
        if stale:
            sys.stderr.write(
                f"render-guide: [{platform}] the following generated guides are out of date:\n"
                + "".join(f"  {p}\n" for p in stale)
                + f"Run `make -C {platform} guides`.\n")
            return 1
        if doc_stale:
            sys.stderr.write(
                "render-guide: the committed English guide is missing or stale:\n"
                f"  {os.path.relpath(doc_path, ROOT)}\n"
                f"Run `make -C {platform} guides`.\n")
            return 1
        print(f"render-guide: [{platform}] all {len(found)} guides up to date.")
        return 0

    written = stale + missing + ([os.path.relpath(doc_path, ROOT)] if doc_stale else [])
    if written:
        print(f"render-guide: [{platform}] wrote {len(written)} file(s):")
        for p in written:
            print(f"  {p}")
    else:
        print(f"render-guide: [{platform}] nothing to do ({skipped} guides already current).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
