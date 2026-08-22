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
check-typography.py -- every user-facing text quotes and elides the way its
language does.

WHY THIS EXISTS
    Quotation marks and the apostrophe are not decoration: `„…“` is what a
    German reader expects, `«…»` a French one, `「…」` a Japanese one, and the
    apostrophe in `aujourd'hui` or `об'єм` is a letter-level part of the word,
    not a typewriter stand-in. Before the 0.85.0 pass the tree carried all of it
    at once -- 33 backslash-escaped `\\'` in strings.xml, 930 straight quotes
    across the 21 user guides, three languages that OPENED with `„` and CLOSED
    with `"` in the same sentence -- because nothing looked. Every text source is
    hand-edited by a different pair of hands at a different time, so the drift is
    not a mistake anyone makes, it is what happens without a gate.

    The 0.85.0 pass fixed the tree. This tool is what keeps it fixed: the next
    new string, guide paragraph or store description is checked the moment it
    lands, not in another audit round.

WHAT IT CHECKS, PER LANGUAGE
    1. STRAIGHT: no `'` and no `"` in user-facing text. The apostrophe is U+2019;
       quotation marks are the pair the language uses.
    2. FOREIGN: no quotation mark belonging to ANOTHER language's convention --
       a stray `“` in the French guide is as wrong as a straight one.
    3. UNBALANCED: opener and closer occur equally often. This is what catches
       the `„…"` mix, where a correct opener hides a wrong closer.

WHERE IT LOOKS
    android/app/src/main/res/values*/strings.xml   text nodes only
    ios/Potillus/Localizable.xcstrings             keys and every translation
    ReportLabelsCatalog.swift, CsvHeaderLabels.swift   string literals
    docs/guide/usersguide.*.md.in                  body, minus code
    fastlane/metadata/{android,ios}/**             listings

WHAT IT SKIPS, AND WHY
    XML comments and Swift comments are TRANSLATOR NOTES in English, addressed to
    whoever edits the file -- not text any user sees; `locale's` there is correct
    English prose about the file, and rewriting it would only churn the diff.
    Markdown code spans and fenced blocks hold literal input, where a straight
    quote is the character the reader must type. The guide license headers are
    verbatim GPL boilerplate. And the published release notes -- the Play
    changelogs under changelogs/, the App Store release_notes.txt -- are a record
    of what was shipped; they are not edited after the fact, so they are read-only
    here by intent, not by oversight.

USAGE
    python3 tools/check-typography.py        # exit 1 on any finding
"""

import glob
import json
import os
import re
import sys
import xml.etree.ElementTree as ET

from potillus_repo import repo_root

ROOT = repo_root()

APOSTROPHE = "\u2019"

# The quotation pair each language uses, as an (opener, closer) tuple. This is
# not a style preference invented here: it is the convention the app catalogue
# already carries in `delete_confirm` and `drink_delete_blocked`, which is where
# these values were read from. Swedish is the reason the code never assumes the
# two differ -- `”…”` uses one character for both ends.
QUOTES = {
    "cs": ("\u201e", "\u201c"),      # „ “
    "da": ("\u201e", "\u201c"),
    "de": ("\u201e", "\u201c"),
    "pl": ("\u201e", "\u201d"),
    "ro": ("\u201e", "\u201d"),
    "el": ("\u00ab", "\u00bb"),      # « »
    "es": ("\u00ab", "\u00bb"),
    "fr": ("\u00ab", "\u00bb"),
    "it": ("\u00ab", "\u00bb"),
    "nb": ("\u00ab", "\u00bb"),
    "pt": ("\u00ab", "\u00bb"),
    "ru": ("\u00ab", "\u00bb"),
    "uk": ("\u00ab", "\u00bb"),
    "en": ("\u201c", "\u201d"),      # “ ”
    "ko": ("\u201c", "\u201d"),
    "nl": ("\u201c", "\u201d"),
    "pt-BR": ("\u201c", "\u201d"),
    "zh-Hans": ("\u201c", "\u201d"),
    "sv": ("\u201d", "\u201d"),      # ” ” -- same character both ends
    "ja": ("\u300c", "\u300d"),      # 「 」
    "zh-Hant": ("\u300c", "\u300d"),
}

# Every quotation character any of the conventions above uses. A text may carry
# only the two its own language asks for; anything else in here is FOREIGN.
ALL_QUOTES = {c for pair in QUOTES.values() for c in pair}

# Android resource qualifiers and store locale directories both name languages
# their own way. Anything not listed is not a language directory (values-night,
# values-v31, the ios review_information folder is mapped to English on purpose:
# its notes.txt is English prose for the reviewer).
ANDROID_QUALIFIER = {"nb": "nb", "pt-BR": "pt-rBR", "zh-Hans": "zh-rCN", "zh-Hant": "zh-rTW"}
STORE_LOCALE = {
    "cs-CZ": "cs", "cs": "cs", "da-DK": "da", "da": "da", "de-DE": "de",
    "el-GR": "el", "el": "el", "en-US": "en", "es-ES": "es", "fr-FR": "fr",
    "it-IT": "it", "it": "it", "ja-JP": "ja", "ja": "ja", "ko-KR": "ko", "ko": "ko",
    "nl-NL": "nl", "no-NO": "nb", "no": "nb", "pl-PL": "pl", "pl": "pl",
    "pt-BR": "pt-BR", "pt-PT": "pt", "ro": "ro", "ru-RU": "ru", "ru": "ru",
    "sv-SE": "sv", "sv": "sv", "uk": "uk", "zh-CN": "zh-Hans", "zh-TW": "zh-Hant",
    "zh-Hans": "zh-Hans", "zh-Hant": "zh-Hant", "review_information": "en",
}


def findings_for(text, lang, where):
    """Every typography problem in one piece of user-facing text."""
    if lang not in QUOTES:
        return []
    opener, closer = QUOTES[lang]
    out = []
    if "'" in text:
        out.append(f"{where}: straight apostrophe ' -- use {APOSTROPHE}")
    if '"' in text:
        out.append(f'{where}: straight quotation mark " -- use {opener}…{closer}')
    foreign = sorted(c for c in ALL_QUOTES if c not in (opener, closer) and c in text)
    if foreign:
        marks = " ".join(foreign)
        out.append(f"{where}: quotation mark(s) {marks} from another language -- use {opener}…{closer}")
    # Balance. With one character at both ends (sv) the count must be even
    # instead; a lone `”` is then the only detectable failure.
    if opener == closer:
        if text.count(opener) % 2:
            out.append(f"{where}: odd number of {opener}")
    elif text.count(opener) != text.count(closer):
        out.append(f"{where}: {text.count(opener)}x {opener} against {text.count(closer)}x {closer}")
    return out


def android_texts():
    """(language, label, text) for every string and plural item, comments excluded."""
    reverse = {v: k for k, v in ANDROID_QUALIFIER.items()}
    for path in sorted(glob.glob(os.path.join(ROOT, "android/app/src/main/res/values*/strings.xml"))):
        qualifier = os.path.basename(os.path.dirname(path))[len("values"):].lstrip("-")
        lang = reverse.get(qualifier, qualifier) or "en"
        if lang not in QUOTES:
            continue
        root = ET.parse(path).getroot()
        rel = os.path.relpath(path, ROOT)
        # .itertext() walks text nodes only: an XML comment is not one, so the
        # English translator notes never reach the check.
        for node in root.iter("string"):
            yield lang, f"{rel} <{node.get('name')}>", "".join(node.itertext())
        for plural in root.iter("plurals"):
            for item in plural:
                yield lang, f"{rel} <{plural.get('name')}/{item.get('quantity')}>", "".join(item.itertext())


def catalogue_texts():
    """(language, label, text) for the String Catalogue: keys are English source."""
    path = os.path.join(ROOT, "ios/Potillus/Localizable.xcstrings")
    catalogue = json.load(open(path, encoding="utf-8"))["strings"]
    rel = os.path.relpath(path, ROOT)
    for key, entry in catalogue.items():
        yield "en", f"{rel} key", key
        for tag, loc in entry.get("localizations", {}).items():
            if tag not in QUOTES:
                continue
            unit = loc.get("stringUnit")
            if unit and unit.get("value"):
                yield tag, f"{rel} [{tag}] {key[:40]!r}", unit["value"]
            for form, plural in loc.get("variations", {}).get("plural", {}).items():
                yield tag, f"{rel} [{tag}] {key[:30]!r} ({form})", plural["stringUnit"]["value"]


SWIFT_LITERAL = re.compile(r'"((?:[^"\\]|\\.)*)"')


def swift_catalogue_texts():
    """(language, label, text) for the two hand-maintained Swift label catalogues.

    Language is not knowable per literal here -- the file interleaves all of them
    -- so each literal is checked against EVERY convention and reported only when
    it fails all of them. That still catches a straight quote or apostrophe,
    which no convention allows, while never faulting a correct `«…»`.
    """
    for name in ("Domain/ReportLabelsCatalog.swift", "Data/CsvHeaderLabels.swift"):
        path = os.path.join(ROOT, "ios/PotillusKit/Sources/PotillusKit", name)
        if not os.path.exists(path):
            continue
        rel = os.path.relpath(path, ROOT)
        text = open(path, encoding="utf-8").read()
        # Comments would otherwise contribute their English prose apostrophes.
        text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
        text = re.sub(r"^\s*//.*$", "", text, flags=re.M)
        for match in SWIFT_LITERAL.finditer(text):
            literal = match.group(1)
            if "'" not in literal and '"' not in literal:
                continue
            line = text.count("\n", 0, match.start()) + 1
            yield "en", f"{rel}:{line}", literal


def guide_texts():
    """(language, label, body) per guide template, license header and code removed."""
    for path in sorted(glob.glob(os.path.join(ROOT, "docs/guide/usersguide.*.md.in"))):
        stem = os.path.basename(path)[len("usersguide."):-len(".md.in")]
        lang = stem or "en"
        if lang not in QUOTES:
            continue
        text = open(path, encoding="utf-8").read()
        header = re.match(r"^<!--.*?-->", text, re.S)
        body = text[header.end():] if header else text
        body = re.sub(r"```.*?```", "", body, flags=re.S)
        body = re.sub(r"`[^`\n]*`", "", body)
        yield lang, os.path.relpath(path, ROOT), body


def store_texts():
    """(language, label, text) for the listings, published release notes excluded."""
    patterns = ["fastlane/metadata/android/*/*.txt",
                "fastlane/metadata/ios/*/*.txt",
                "fastlane/metadata/ios/*.txt"]
    for pattern in patterns:
        for path in sorted(glob.glob(os.path.join(ROOT, pattern))):
            base = os.path.basename(path)
            if base == "release_notes.txt":
                continue
            rel = os.path.relpath(path, ROOT)
            parts = rel.split(os.sep)
            lang = STORE_LOCALE.get(parts[3]) if len(parts) > 4 else None
            if lang is None:
                continue
            yield lang, rel, open(path, encoding="utf-8").read()


def main():
    problems = []
    for source in (android_texts, catalogue_texts, swift_catalogue_texts,
                   guide_texts, store_texts):
        for lang, where, text in source():
            problems.extend(findings_for(text, lang, where))

    if problems:
        sys.stderr.write("check-typography: %d finding(s):\n" % len(problems))
        for problem in problems:
            sys.stderr.write(f"  {problem}\n")
        sys.stderr.write("The apostrophe is \u2019; each language quotes its own way "
                         "(see QUOTES in this file).\n")
        return 1
    print("check-typography: all user-facing text follows its language's typography.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
