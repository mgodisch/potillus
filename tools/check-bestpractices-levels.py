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
check-bestpractices-levels.py -- keep the level map in step with the answers.

WHY
    filter-bestpractices.py and diff-bestpractices.py both look up every
    criterion in .bestpractices.json against the badge level map in
    tools/bestpractices-levels.json. If the badge site ever adds a criterion
    that ends up in the answers file but not in the map, those tools would
    misplace or drop it -- but only if someone happens to run them. This
    gate makes the coupling a first-class release check: it FAILS whenever the
    answers file contains a criterion the map cannot place, pointing at the map
    as the thing to update (from the upstream sources named in its _comment).

    It also warns (does not fail) on the reverse: map entries no longer present
    in the answers file. That is harmless -- an over-complete map still renders
    correctly -- but flagging it keeps the map from accreting dead entries.

GRACEFUL SKIP
    If .bestpractices.json is absent (a source drop without the badge
    snapshot), the check prints an informational line and exits 0.

USAGE
    tools/check-bestpractices-levels.py
    Exit status: 0 = clean or skipped, 1 = a criterion has no level.
"""

import json
import os
import re
import sys

from potillus_repo import repo_root

ROOT = str(repo_root())
ANSWERS_PATH = os.path.join(ROOT, ".bestpractices.json")
LEVELS_PATH = os.path.join(ROOT, "tools", "bestpractices-levels.json")

_SUFFIX = re.compile(r"_(status|justification)$")


def main():
    if not os.path.isfile(ANSWERS_PATH):
        print("check-bestpractices-levels: .bestpractices.json not present -- skipped")
        return 0

    with open(ANSWERS_PATH, encoding="utf-8") as handle:
        answers = json.load(handle)
    with open(LEVELS_PATH, encoding="utf-8") as handle:
        levels = json.load(handle)

    mapped = set(levels["metal"]) | set(levels["baseline"])
    # The criteria actually answered (each has a `_status`; `_justification` is
    # optional), recovered by stripping the suffix.
    answered = {
        _SUFFIX.sub("", key) for key in answers if key.endswith("_status")
    }

    unmapped = sorted(answered - mapped)
    for criterion in unmapped:
        print(
            f"check-bestpractices-levels: '{criterion}' has no level in "
            f"tools/bestpractices-levels.json",
            file=sys.stderr,
        )

    stale = sorted(mapped - answered)
    for criterion in stale:
        print(
            f"check-bestpractices-levels: WARN map entry '{criterion}' is not in "
            f"the answers file (harmless, but consider pruning)",
            file=sys.stderr,
        )

    if unmapped:
        print(
            f"check-bestpractices-levels: {len(unmapped)} unmapped criterion(s) -- "
            f"regenerate the map from the sources named in its _comment",
            file=sys.stderr,
        )
        return 1

    print(
        f"check-bestpractices-levels: OK ({len(answered)} criteria, all mapped)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
