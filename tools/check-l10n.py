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
# In addition, as permitted by section 7 of the GNU General Public License,
# this program may carry additional permissions; any such permissions that
# apply to it are stated in the accompanying COPYING.md file.
#
# =============================================================================
#

# =============================================================================
# Fails if a view holds a user-facing string literal that is not routed through
# `Loc.string`. Path (A) — the in-app language picker — only works if EVERY such
# string is looked up against the chosen locale; a stray `Text("New label")` would
# silently show in the system language, and only in that one spot, which is the
# confusing half-translated screen this whole mechanism exists to prevent.
#
# WHAT IS ALLOWED
#   - `Loc.string("...")`            the routed form
#   - the app's proper name          "Libellus Potionis"
#   - pure interpolation / numbers   "\(x)", "%lld", "5 ml"
#   - systemImage / SF Symbol names  never user-visible
#   - the startup failure view       renders before the locale exists (see its note)
# =============================================================================

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VIEWS = sorted((ROOT / "ios" / "Potillus").glob("*.swift"))

CALLS = (
    r"(?:Text|Label|Button|Toggle|navigationTitle|Section|ContentUnavailableView"
    r"|Picker|LabeledContent|TextField|DatePicker|Stepper)"
)
LITERAL = re.compile(CALLS + r'\(\s*"([^"]+)"')

ALLOWED_EXACT = {
    "Libellus Potionis",                       # proper noun
    "Libellus Potionis could not start",       # pre-locale failure view (documented)
    "Libellus Potionis is locked",             # cover, localised via Loc elsewhere
}
# Pure interpolation or number+unit: no words to translate.
NEUTRAL = re.compile(r"^[%\d\$@lld /·.\\()a-z_A-Z]*$")


# Units that carry no translation: they are the same token in every language this
# app ships. A string that is only interpolation plus these is language-neutral.
NEUTRAL_UNITS = ("ml", "g", "%")


def is_pure_interpolation(text):
    """True when nothing translatable survives once interpolations and units go.

    `"\\(x) ml"` leaves `" ml"`, which is a bare unit — neutral. `"\\(x) is used
    by"` leaves `" is used by"`, which is words — not neutral. The catalogue marks
    the neutral ones `shouldTranslate=false`; this mirrors that so the linter and
    the catalogue agree on which literals need no lookup.
    """
    stripped = re.sub(r"\\\((?:[^()]|\([^()]*\))*\)", "", text)
    for unit in NEUTRAL_UNITS:
        stripped = stripped.replace(unit, "")
    return re.fullmatch(r"[\d %lld@\$/·.\s]*", stripped) is not None


def offenders():
    problems = []
    for path in VIEWS:
        if path.name == "Localization.swift":
            continue
        for number, line in enumerate(path.read_text(encoding="utf-8").split("\n"), 1):
            for match in LITERAL.finditer(line):
                start = match.start()
                # Already routed if this call sits inside a Loc.string(...).
                if "Loc.string(" in line[max(0, start - 12):start + 30]:
                    continue
                text = match.group(1)
                if text in ALLOWED_EXACT:
                    continue
                if is_pure_interpolation(text):
                    continue
                problems.append(f"{path.name}:{number}: raw literal {text!r} — route it through Loc.string")
    return problems


def main():
    found = offenders()
    for line in found:
        print(f"check-l10n: {line}", file=sys.stderr)
    if found:
        print(f"check-l10n: {len(found)} unlocalised literal(s)", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
