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
#

# =============================================================================
# Builds ios/Potillus/Localizable.xcstrings from two sources:
#
#   1. Verified German harvested from android/.../values-de/strings.xml, for the
#      strings whose English text matches an Android string word for word.
#   2. German written for this port, for the iOS-only and reworded strings, in
#      tools/l10n_de.py.
#
# The English source is the catalogue KEY, as Apple's String Catalog format uses.
# Every UI literal found in the views becomes a key; German is filled where known.
#
# WHY A SCRIPT AND NOT A HAND-EDITED FILE
#   182 Android strings, ~70 iOS literals, 20 languages ahead. Hand-maintaining the
#   JSON would drift from the code the first time a literal changed. This regenerates
#   from the code and the tables, so the catalogue cannot silently disagree with
#   either. Re-run it after adding a literal; the key appears, untranslated.
# =============================================================================

import html
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VIEWS = sorted((ROOT / "ios" / "Potillus").glob("*.swift"))
ANDROID_DE = ROOT / "android/app/src/main/res/values-de/strings.xml"
ANDROID_EN = ROOT / "android/app/src/main/res/values/strings.xml"
OUT = ROOT / "ios" / "Potillus" / "Localizable.xcstrings"

sys.path.insert(0, str(ROOT / "tools"))
from l10n_de import MINE_DE, MINE_DE_INTERP, PURE_INTERP  # noqa: E402

# Languages beyond German each carry one flat table `MINE` in tools/l10n_XX.py,
# keyed by the English source, holding BOTH plain and interpolated strings (the
# split MINE_DE / MINE_DE_INTERP was only needed for the first one). The Android
# resource dir differs from the iOS tag in a few cases; ANDROID_DIR maps them.
LANGUAGES = [
    "da", "nl", "nb", "sv",
    "es", "fr", "it", "pt", "pt-BR", "ro",
    "cs", "pl", "ru", "uk", "el",
    "ja", "ko", "zh-Hans", "zh-Hant",
]
ANDROID_DIR = {
    "nb": "nb", "pt-BR": "pt-rBR", "zh-Hans": "zh-rCN", "zh-Hant": "zh-rTW",
}


def android_map(path):
    d = {}
    xml = path.read_text(encoding="utf-8")
    for m in re.finditer(r'<string name="([^"]+)"[^>]*>(.*?)</string>', xml, re.S):
        v = html.unescape(m.group(2)).replace("\\@", "@").replace("\\'", "'").strip()
        d[m.group(1)] = v
    return d


# Interpolation expressions whose Swift type is Int; SwiftUI's LocalizedStringKey
# renders these as %lld, everything else (String, or Double already turned into a
# String by a helper) as %@. The key the catalogue needs must match what SwiftUI
# generates, or the lookup misses at runtime.
INT_INTERPOLATIONS = ("volumeMl", "entryCount", "maxDrinkDaysPerWeek", "count")


def interpolation_to_placeholder(literal):
    """Turns a Swift interpolation literal into the key SwiftUI generates.

    SwiftUI's `Text("Delete \\(name)")` builds a `LocalizedStringKey` whose stored
    key is `"Delete %@"` for a String and `"Delete %lld"` for an Int. This mirrors
    that: an interpolation of a known Int expression becomes `%lld`, otherwise `%@`.
    Two or more arguments become positional (`%1$@`, `%2$lld`), which is what SwiftUI
    does once there is more than one.
    """
    spans = list(re.finditer(r"\\\((?:[^()]|\([^()]*\))*\)", literal))
    if not spans:
        return literal

    specifiers = []
    for span in spans:
        expr = span.group(0)
        is_int = any(token in expr for token in INT_INTERPOLATIONS)
        specifiers.append("lld" if is_int else "@")

    if len(spans) == 1:
        return literal_re_sub(literal, [f"%{specifiers[0]}"])
    return literal_re_sub(
        literal, [f"%{i + 1}${spec}" for i, spec in enumerate(specifiers)]
    )


def literal_re_sub(literal, replacements):
    out, i = [], 0
    for seg in re.finditer(r"\\\((?:[^()]|\([^()]*\))*\)", literal):
        out.append(literal[i:seg.start()])
        out.append(replacements.pop(0))
        i = seg.end()
    out.append(literal[i:])
    return "".join(out)


def collect_literals():
    # Two shapes: a call whose first argument is a string literal, and a ternary
    # inside accessibilityLabel that holds two. Both contribute keys.
    # A string is a key whether it is still a raw literal in a `Text(...)` or has
    # already been converted to `Loc.string("...")`. Scanning only the raw form
    # would shrink the catalogue as views are converted — a key would vanish the
    # moment its screen started using it. So `Loc.string("...")` is scanned too.
    call = re.compile(
        r'(?:Text|Label|Button|Toggle|navigationTitle|Section'
        r'|ContentUnavailableView|accessibilityLabel|Picker|TextField|DatePicker|Stepper|LabeledContent'
        r'|Loc\.string)'
        r'\(\s*"([^"]+)"'
    )
    ternary = re.compile(r'"([^"]+)"\s*:\s*"([^"]+)"')
    found = {}
    for path in VIEWS:
        text = path.read_text(encoding="utf-8")
        for m in call.finditer(text):
            found[m.group(1)] = interpolation_to_placeholder(m.group(1))
        for line in text.split("\n"):
            if "accessibilityLabel(" in line:
                for m in ternary.finditer(line):
                    for g in (m.group(1), m.group(2)):
                        found[g] = interpolation_to_placeholder(g)
    return found


def unit(value, state="translated"):
    return {"stringUnit": {"state": state, "value": value}}

# The three plurals live in Android's <plurals> blocks. Their keys in the catalogue
# are the English "other" form with iOS placeholders, matching what the call site
# passes to Loc.plural. Every form for every language is harvested — none invented,
# since Android defines them all.
PLURALS = {
    # catalogue key            android <plurals name=...>
    "%lld days": "days",
    "%lld entries imported.": "import_success_replace",
    "%lld entries imported, %lld skipped.": "import_success_merge",
}

# Android locale dir per catalogue tag, reusing ANDROID_DIR where it differs.
PLURAL_DIRS = {
    "en": "", "de": "-de", "da": "-da", "nl": "-nl", "nb": "-nb", "sv": "-sv",
    "es": "-es", "fr": "-fr", "it": "-it", "pt": "-pt", "pt-BR": "-pt-rBR",
    "ro": "-ro", "cs": "-cs", "pl": "-pl", "ru": "-ru", "uk": "-uk", "el": "-el",
    "ja": "-ja", "ko": "-ko", "zh-Hans": "-zh-rCN", "zh-Hant": "-zh-rTW",
}


def android_plurals(tag):
    """Returns {plural_name: {form: value}} for one language, placeholders converted."""
    path = ROOT / f"android/app/src/main/res/values{PLURAL_DIRS[tag]}/strings.xml"
    if not path.exists():
        return {}
    text = path.read_text(encoding="utf-8")
    out = {}
    for name, body in re.findall(r'<plurals name="([^"]+)">(.*?)</plurals>', text, re.S):
        forms = {}
        for form, value in re.findall(r'<item quantity="(\w+)">(.*?)</item>', body, re.S):
            import html as _html
            v = _html.unescape(value).strip()
            # Android %1$d / %2$d -> iOS %lld positional; single arg stays %lld.
            v = re.sub(r"%(\d+)\$d", lambda m: f"%{m.group(1)}$lld", v)
            v = v.replace("%d", "%lld")
            forms[form] = v
        out[name] = forms
    return out


def plural_entry(catalogue_key, android_name):
    """Builds one catalogue entry whose localisations carry plural variations."""
    localizations = {}
    for tag in ["en", "de"] + LANGUAGES:
        forms = android_plurals(tag).get(android_name)
        if not forms:
            continue
        variations = {
            form: {"stringUnit": {"state": "translated", "value": value}}
            for form, value in forms.items()
        }
        localizations[tag] = {"variations": {"plural": variations}}
    return {"extractionState": "manual", "localizations": localizations}



def load_language(tag):
    """Returns {english_key: translation} for one language.

    Harvested Android values (where the English matched an Android string) merged
    UNDER the port's own table, so a hand-written translation wins over a harvested
    one if both exist — the port's wording is the source of truth for its own keys.
    """
    module = __import__(f"l10n_{tag.replace('-', '_')}")
    andr = ANDROID_DIR.get(tag, tag)
    translated = android_map(ROOT / f"android/app/src/main/res/values-{andr}/strings.xml")
    en = android_map(ANDROID_EN)
    harvested = {en[k]: translated[k] for k in en if k in translated}
    return {**harvested, **module.MINE}


def build():
    en = android_map(ANDROID_EN)
    de = android_map(ANDROID_DE)
    harvested_de = {en[k]: de[k] for k in en if k in de}

    # German keeps its original two-table shape; the rest use the flat loader.
    extra = {tag: load_language(tag) for tag in LANGUAGES}

    literals = collect_literals()          # raw literal -> catalogue key
    strings = {}

    for raw, key in sorted(literals.items()):
        entry = {"extractionState": "manual",
                 "localizations": {"en": unit(key)}}

        # Pure-interpolation keys carry no words: source only, do not translate.
        if key in PURE_INTERP:
            entry["shouldTranslate"] = False
            strings[key] = entry
            continue

        german = None
        if raw in harvested_de:            # exact English match to an Android string
            german = harvested_de[raw]
        elif raw in MINE_DE:               # plain iOS-only string
            german = MINE_DE[raw]
        elif key in MINE_DE_INTERP:        # interpolated, words translated
            german = MINE_DE_INTERP[key]

        if german is not None:
            entry["localizations"]["de"] = unit(german)

        # Every other language: its table is keyed by the English source (`raw` for
        # plain strings, `key` for interpolated ones, since the interpolated table
        # stores the %-placeholder form under the catalogue key).
        for tag, table in extra.items():
            value = table.get(raw) or table.get(key)
            if value is not None:
                entry["localizations"][tag] = unit(value)

        strings[key] = entry

    for catalogue_key, android_name in PLURALS.items():
        strings[catalogue_key] = plural_entry(catalogue_key, android_name)

    catalogue = {"sourceLanguage": "en", "version": "1.0", "strings": strings}
    OUT.write_text(json.dumps(catalogue, ensure_ascii=False, indent=2) + "\n",
                   encoding="utf-8")

    total = len(strings)
    source_only = sum(1 for v in strings.values() if v.get("shouldTranslate") is False)
    print(f"  wrote {OUT.relative_to(ROOT)}")
    print(f"  keys: {total}   source-only: {source_only}")
    for tag in ["de"] + LANGUAGES:
        n = sum(1 for v in strings.values() if tag in v["localizations"])
        print(f"    {tag}: {n} translated")


if __name__ == "__main__":
    build()
