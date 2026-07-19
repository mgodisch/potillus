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
check-ui-string-parity.py -- surface iOS labels that drift from Android's wording.

WHY THIS EXISTS
    The l10n parity gate (check-l10n-parity.py) guarantees that where the two
    platforms use the SAME English source string, their translations agree. It
    cannot see the other failure mode: the two platforms saying the same thing
    in DIFFERENT words -- Android "Average per Day" vs iOS "Per day", Android
    "Abstinent Days" vs iOS "Dry days in period". Those never share a key, so
    the divergence is invisible to a key-based check, and a platform switcher
    meets two vocabularies for one app (0.83.0 UI-parity pass). This tool is the
    instrument for that: a curated equivalence map of iOS catalogue key <->
    Android string name, reporting where the English texts differ so they can be
    aligned.

    It is a DIAGNOSTIC, deliberately NOT wired into release-check: label wording
    is a judgement call (strict equality vs a shorter iOS idiom), not a
    pass/fail release gate. Run it on demand: `make check-ui-string-parity`.

WHAT IT REPORTS
    1. DRIFT: a mapped pair whose English texts differ -- the alignment work.
       (When they already match, the pair is silent: nothing to do.)
    2. UNMAPPED: iOS catalogue keys that carry real words and are not yet in the
       map -- so a new screen's labels cannot silently escape the audit. Keys
       that are pure format skeletons ("%1$lld ml"), proper nouns, or already
       equal to an Android value are not "unmapped" in this sense, and the
       deliberately unlocalised views (UNLOCALISED_VIEWS) are not scanned at all.
    3. STALE: map entries whose iOS key or Android name no longer exists.

THE MAP
    tools/ui-string-parity.json: {"pairs": {"<iOS catalogue key>": "<android
    string name>", ...}}. Hand-curated -- semantic equivalence cannot be
    guessed. A pair means "these must read the same to the user"; the fix for a
    drift is normally to change the iOS key to Android's wording (and move its
    translations), which then also lets check-l10n-parity enforce them.

USAGE
    tools/check-ui-string-parity.py
    Exit status: 0 always for DRIFT/UNMAPPED (advisory); 1 only on STALE map
    entries (a real inconsistency in the map itself). The advisory findings are
    printed for the human to act on.
"""

import html
import json
import re
import sys
from potillus_repo import repo_root

ROOT = repo_root()
CATALOG = ROOT / "ios" / "Potillus" / "Localizable.xcstrings"
ANDROID = ROOT / "android" / "app" / "src" / "main" / "res" / "values" / "strings.xml"
MAP = ROOT / "tools" / "ui-string-parity.json"

# Views that carry fixed English literals BY DESIGN, and whose literals are
# therefore not catalogue keys and have no Android counterpart to drift from.
# The canonical list and the full reasoning live in check-l10n.py
# (UNLOCALISED_VIEWS); this mirrors it, because a scan that does not skip them
# reports their prose as "an iOS label not yet in the map" -- which invites
# someone to map a legal heading onto an Android string and translate it, the
# exact outcome the About screen exists to prevent (0.83.0 QA round: this gate
# was reporting AboutScreen's Section("Open-source components")).
UNLOCALISED_VIEWS = {
    "Localization.swift",
    "AboutScreen.swift",
}

VIEWS = sorted(
    path
    for path in (ROOT / "ios" / "Potillus").glob("*.swift")
    if path.name not in UNLOCALISED_VIEWS
)


def android_strings():
    """Android string name -> English value, escapes resolved."""
    text = ANDROID.read_text(encoding="utf-8")
    out = {}
    for m in re.finditer(r'<string name="([^"]+)"[^>]*>(.*?)</string>', text, re.S):
        value = html.unescape(m.group(2))
        value = value.replace("\\'", "'").replace('\\"', '"').replace("\\n", "\n")
        out[m.group(1)] = value
    return out


def catalog_source_values():
    """iOS catalogue key -> its English (source) value."""
    strings = json.loads(CATALOG.read_text(encoding="utf-8"))["strings"]
    out = {}
    for key, entry in strings.items():
        loc = entry.get("localizations", {}).get("en", {})
        unit = loc.get("stringUnit")
        out[key] = unit["value"] if unit else key
    return out


def used_label_keys():
    """Catalogue keys referenced by a UI call that carry real words.

    Uses the same call shapes as check-l10n-parity, but resolves the referenced
    KEY (not the raw literal) so multi-line and multi-argument calls are caught
    by intersecting with the catalogue.
    """
    call = re.compile(
        r'(?:Text|Label|Button|Toggle|navigationTitle|Section'
        r'|ContentUnavailableView|accessibilityLabel|Picker|TextField|DatePicker'
        r'|Stepper|LabeledContent|Loc\.string)\(\s*"([^"]+)"'
    )
    found = set()
    for path in VIEWS:
        for m in call.finditer(path.read_text(encoding="utf-8")):
            found.add(m.group(1))
    return found


def is_skeleton(text):
    """A literal that is only placeholders/units/punctuation carries no words."""
    return re.fullmatch(r"[%@\d$lld /·.,\\()≈a-zA-Z_ø]*", text) is not None


# A printf/String Catalog format specifier: an optional positional "N$", optional
# flags/width/precision/length, then a conversion. Matches %@, %d, %lld, %1$s,
# %2$@, %1$.1f and the like -- but NOT a bare "%" that is not a conversion (e.g.
# "50% done", where a space follows), because a conversion letter must follow
# immediately. The space printf flag is deliberately excluded from the flag set:
# it never appears in these UI strings, and allowing it would let "% done" match
# as "space-flag + d", swallowing a real word.
_SPECIFIER = re.compile(
    r"%(?:\d+\$)?[-+0#]*\d*(?:\.\d+)?(?:hh|h|ll|l|q|L|z|j|t)?[@diouxXeEfgGaAcspn%]"
)


def normalize(text):
    """Collapse the representation differences that are NOT wording differences,
    so a label reads equal across platforms when only its FORMATTING differs.

    Three sources of spurious inequality are folded out, and nothing else -- word
    order, punctuation and every actual character stay significant, so a genuine
    wording divergence still shows:

      * format specifiers -> a single '%' sentinel. iOS spells an argument '%@' /
        '%lld', Android spells the same argument '%1$s' / '%1$d'; this checker
        verifies WORDING, not specifier syntax (other checks cover that), so the
        specifier's exact form is not a wording difference.
      * '\\uXXXX' escapes -> the character. android_strings() resolves HTML
        entities and \\n but leaves \\u201c ("curly quote") literal; the iOS JSON
        is already decoded, so this evens the two sides.
      * a literal backslash-n -> a real newline, matching android_strings()'s own
        \\n handling (the intentional line break in the empty-state label).
    """
    text = re.sub(
        r"\\u([0-9a-fA-F]{4})", lambda m: chr(int(m.group(1), 16)), text
    )
    text = text.replace("\\n", "\n")
    return _SPECIFIER.sub("%", text)


def main():
    android = android_strings()
    android_values = {normalize(v) for v in android.values()}
    catalog = catalog_source_values()
    pairs = json.loads(MAP.read_text(encoding="utf-8"))["pairs"] if MAP.exists() else {}

    drift = []
    stale = []
    for ios_key, android_name in sorted(pairs.items()):
        if ios_key not in catalog:
            stale.append(f"iOS key not in catalogue: {ios_key!r}")
            continue
        if android_name not in android:
            stale.append(f"Android name not found: {android_name!r} (for {ios_key!r})")
            continue
        ios_text = catalog[ios_key]
        android_text = android[android_name]
        if normalize(ios_text) != normalize(android_text):
            drift.append((ios_key, ios_text, android_name, android_text))

    mapped_keys = set(pairs.keys())
    unmapped = []
    for key in sorted(used_label_keys()):
        # The catalogue is keyed by the English source string, so the key IS the
        # label's English. A used key can differ from its catalogue form only in
        # representation (a source-literal "\n" vs the catalogue's real newline),
        # so normalize the key itself and ask whether that wording exists on
        # Android -- if it does, the label is in parity and needs no map entry.
        if key in mapped_keys or normalize(key) in android_values:
            continue
        if is_skeleton(key) or "\\(" in key:
            continue
        unmapped.append(key)

    if drift:
        print(f"DRIFT — {len(drift)} mapped label(s) whose wording differs:")
        for ios_key, ios_text, android_name, android_text in drift:
            print(f"  iOS  {ios_key!r} = {ios_text!r}")
            print(f"  ↔ Android {android_name!r} = {android_text!r}")
    if unmapped:
        print(f"\nUNMAPPED — {len(unmapped)} iOS label(s) not yet in the map:")
        for key in unmapped:
            print(f"  {key!r}")
    if stale:
        print(f"\nSTALE — {len(stale)} map entry(ies) pointing at nothing:", file=sys.stderr)
        for line in stale:
            print(f"  {line}", file=sys.stderr)

    if not drift and not unmapped and not stale:
        print("check-ui-string-parity: OK (no drift, nothing unmapped)")

    # Only a broken map is a hard failure; drift/unmapped are advisory work items.
    return 1 if stale else 0


if __name__ == "__main__":
    sys.exit(main())
