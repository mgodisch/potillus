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
filter-bestpractices.py -- reduce a raw badge project dump to the tracked answers.

INPUT
    The full JSON a badge project export carries on stdin
    (https://www.bestpractices.dev/projects/<id>.json). Besides the criteria it
    holds ~60 project-metadata keys (id, homepage_url, timestamps, percentages)
    and a few non-criterion *_status keys (homepage_url_status, report_url_status)
    that are not part of either criteria series.

OUTPUT
    .bestpractices.json: every TRACKED criterion's `_status` and, where the
    criterion has one, its `_justification` -- sorted, so the committed snapshot
    diffs meaningfully.

SELECTION -- COMPLETE, NOT JUST-ANSWERED
    The criteria the badge tracks are exactly the keys of the level map
    (tools/bestpractices-levels.json: `metal` + `baseline`). This tool mirrors
    THAT SET, which matters for two reasons the earlier "keep only Met/Unmet/N/A"
    filter got wrong:
      * an UNANSWERED criterion (status "?"/"Unknown") is KEPT, not dropped, so
        release-check can see it is outstanding and fail;
      * the ~60 metadata keys and the stray non-criterion *_status keys are
        dropped, because they are not in the map.

MERGE SEMANTICS -- UPSTREAM WINS
    The badge site is the source of truth. The output is built solely from the
    incoming dump intersected with the tracked set:
      * a criterion present upstream takes its upstream status/justification,
        overwriting whatever the local file held;
      * a criterion the map tracks but the dump omits is written with status
        "?" and no justification, so it surfaces as outstanding rather than
        silently missing;
      * a key that used to be local but is neither in the dump nor in the map
        simply does not appear -- dropped, per "removed upstream entries are
        deleted locally".
    There is deliberately no read of the existing .bestpractices.json here:
    "upstream always wins" means the previous local content cannot influence the
    result, so re-running is idempotent for a given dump.

USAGE
    curl ... | tools/filter-bestpractices.py > .bestpractices.json
    Exit status: 0 on success, 2 on malformed input.
"""

import json
import os
import sys

from potillus_repo import repo_root

ROOT = str(repo_root())
LEVELS_PATH = os.path.join(ROOT, "tools", "bestpractices-levels.json")

# Status written for a criterion the badge tracks but the dump did not answer.
UNANSWERED = "?"


def main():
    try:
        dump = json.load(sys.stdin)
    except json.JSONDecodeError as error:
        print(f"filter-bestpractices: malformed input JSON: {error}", file=sys.stderr)
        return 2

    with open(LEVELS_PATH, encoding="utf-8") as handle:
        levels = json.load(handle)
    tracked = set(levels["metal"]) | set(levels["baseline"])

    out = {}
    for criterion in tracked:
        status_key = f"{criterion}_status"
        just_key = f"{criterion}_justification"
        # Upstream wins; a tracked-but-absent criterion becomes an explicit "?".
        status = dump.get(status_key)
        out[status_key] = status if status is not None else UNANSWERED
        # Only carry a justification if the dump provides a non-null one. Criteria
        # without a rationale field upstream (levels["no_justification"]) simply
        # never get the key -- and release-check knows not to demand it.
        if just_key in dump and dump[just_key] is not None:
            out[just_key] = dump[just_key]

    json.dump(
        dict(sorted(out.items())),
        sys.stdout,
        indent=2,
        ensure_ascii=False,
    )
    sys.stdout.write("\n")

    answered = sum(
        1
        for criterion in tracked
        if str(dump.get(f"{criterion}_status", "")).strip() in {"Met", "Unmet", "N/A"}
    )
    print(
        f"filter-bestpractices: {len(tracked)} criteria written, "
        f"{answered} answered, {len(tracked) - answered} outstanding",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
