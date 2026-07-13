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
# Fails if a view holds a user-facing string literal that is not routed through
# `Loc.string`. Path (A) — the in-app language picker — only works if EVERY such
# string is looked up against the chosen locale; a stray `Text("New label")` would
# silently show in the system language, and only in that one spot, which is the
# confusing half-translated screen this whole mechanism exists to prevent. The scan
# covers the display calls below plus alert/confirmationDialog titles and the
# accessibilityLabel/Hint/Value strings a screen reader speaks, and is multiline so
# a title on the line after `.alert(` is caught too.
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
    r"|Picker|LabeledContent|TextField|DatePicker|Stepper"
    # Modifiers whose first argument is user-facing but which the earlier version
    # of this linter missed: alert and dialog titles and the accessibility strings
    # a screen reader speaks. They are matched here so a raw literal in any of them
    # fails the build, the same as a stray Text("…").
    r"|alert|confirmationDialog|accessibilityLabel|accessibilityHint|accessibilityValue)"
)
# DOTALL so the `\s*` between the call's `(` and its first `"` may span lines: an
# `.alert(\n    "Title")` is as much a raw literal as a single-line one, and the
# per-line scan this replaced could not see it. Line numbers are recovered from the
# match offset in offenders().
LITERAL = re.compile(CALLS + r'\(\s*"([^"]+)"', re.DOTALL)

ALLOWED_EXACT = {
    "Libellus Potionis",                       # proper noun
    "Libellus Potionis could not start",       # pre-locale failure view (documented)
    "Libellus Potionis is locked",             # cover, localised via Loc elsewhere
    "GRDB.swift",                              # proper noun: the dependency's name
}
# Pure interpolation or number+unit: no words to translate.
NEUTRAL = re.compile(r"^[%\d\$@lld /·.\\()a-z_A-Z]*$")


# Units that carry no translation: they are the same token in every language this
# app ships. A string that is only interpolation plus these is language-neutral.
NEUTRAL_UNITS = ("ml", "g", "%", "‰")  # ‰ = permille, universal like %


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
        source = path.read_text(encoding="utf-8")
        for match in LITERAL.finditer(source):
            start = match.start()
            # Already routed if this call wraps a Loc.string(...): then the first
            # character after the `(` is `L`, not `"`, so LITERAL cannot match in
            # the first place. The window check remains a belt-and-braces guard.
            if "Loc.string(" in source[max(0, start - 12):start + 30]:
                continue
            literal = match.group(1)
            if literal in ALLOWED_EXACT:
                continue
            if is_pure_interpolation(literal):
                continue
            line = source.count("\n", 0, start) + 1
            problems.append(
                f"{path.name}:{line}: raw literal {literal!r} — route it through Loc.string"
            )
    return problems


def plural_placeholder_problems():
    """Every plural form must carry the same %lld placeholders as its English other.

    A harvested plural form with a dropped or added placeholder would crash or
    mis-format at runtime, and only in the language and count that triggers that
    form — the hardest kind of bug to see. This reads the built catalogue and
    fails if any form disagrees with its English `other`.
    """
    import json
    catalogue = ROOT / "ios" / "Potillus" / "Localizable.xcstrings"
    if not catalogue.exists():
        return []
    strings = json.loads(catalogue.read_text(encoding="utf-8"))["strings"]
    problems = []
    for key, entry in strings.items():
        # A String Catalog entry may legitimately carry no `localizations` key at
        # all — e.g. one marked `shouldTranslate: false`, or a freshly harvested key
        # Xcode has not localized yet. Treat that as "no plurals to check" rather
        # than crashing the whole run on a KeyError.
        localizations = entry.get("localizations", {})
        english = localizations.get("en", {})
        plural = english.get("variations", {}).get("plural")
        if not plural:
            continue
        other = plural["other"]["stringUnit"]["value"]
        want = len(re.findall(r"%\d*\$?lld", other))
        for lang, loc in localizations.items():
            for form, unit in loc.get("variations", {}).get("plural", {}).items():
                value = unit["stringUnit"]["value"]
                got = len(re.findall(r"%\d*\$?lld", value))
                if got != want:
                    problems.append(
                        f"{key!r} [{lang}/{form}]: {got} placeholder(s), "
                        f"expected {want} — {value!r}"
                    )
    return problems


def main():
    found = offenders()
    for line in found:
        print(f"check-l10n: {line}", file=sys.stderr)
    plural_problems = plural_placeholder_problems()
    for line in plural_problems:
        print(f"check-l10n: {line}", file=sys.stderr)
    total = len(found) + len(plural_problems)
    if total:
        print(f"check-l10n: {len(found)} unlocalised literal(s), "
              f"{len(plural_problems)} plural placeholder problem(s)", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
