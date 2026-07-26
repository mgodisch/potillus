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
problems-report.py -- say WHO causes each Gradle deprecation warning.

WHY
    A Gradle build prints its deprecations to the console with no origin, and
    deduplicated: four occurrences from two different plugins arrive as one
    line. That is enough to know a warning exists and not enough to act on it,
    because the answer to "is this ours to fix?" is exactly the origin. Asking
    for a rerun with `--warning-mode all` does not help: that flag controls
    WHICH warnings print, not whether an origin accompanies them.

    Every Gradle 9 build already writes the answer to
    app/build/reports/problems/problems-report.html. This tool reads it, so the
    QA log carries the attribution instead of the bare warning text.

WHAT IT READS
    The HTML page is a viewer around an embedded JSON payload, delimited by the
    marker comments `// begin-report-data` and `// end-report-data`. The payload
    holds one entry per OCCURRENCE (not per distinct message), and an entry
    carries its origin in a `pluginId` field somewhere below it.

    That "somewhere" is deliberate: this tool does NOT walk a fixed key path
    into the payload. Gradle's problems report is an incubating feature and its
    shape has changed between releases; a hard-coded path would break silently
    on the next one and report zero problems, which reads exactly like a clean
    build. Instead the payload is searched recursively for the keys that carry
    meaning -- the message text and the plugin id -- so a reshuffle of the
    surrounding structure costs nothing.

WHAT IT PRINTS
    One line per distinct (message, origin) pair with its occurrence count, e.g.

        problems-report: 3x  com.android.internal.application
            Using a Project object as a dependency notation has been deprecated.
        problems-report: 1x  org.jetbrains.kotlinx.kover
            Using a Project object as a dependency notation has been deprecated.

    An occurrence whose origin the payload does not name is reported as
    `(origin not stated)` rather than dropped: an unattributed warning is still
    a warning, and hiding it would defeat the point of the tool.

EXIT STATUS
    Always 0 on a readable report, including one that lists problems: this is a
    REPORTING step inside the QA battery, not a gate. Turning a Gradle
    deprecation into a build failure is a decision for the ROADMAP, not a side
    effect of looking at it. A missing report exits 0 too (an environment
    without an Android SDK has no build output); only a report that exists and
    cannot be parsed exits 1, because that means this tool is broken.

VERIFICATION NOTE
    The marker names and the `pluginId` field are Gradle's, not this project's,
    and no Gradle build runs in the review sandbox. The recursive search keeps a
    format change from turning into a false "no problems"; the first real proof
    is a `make qa-android` run on a machine with the SDK.
"""

import json
import os
import re
import sys
from collections import Counter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Where a Gradle 9 build writes the report, most specific first.
DEFAULT_PATHS = (
    os.path.join(ROOT, "android", "app", "build", "reports", "problems",
                 "problems-report.html"),
    os.path.join(ROOT, "android", "build", "reports", "problems",
                 "problems-report.html"),
)

# The payload sits between these two marker comments in the generated page.
PAYLOAD = re.compile(
    r"//\s*begin-report-data\s*(?P<json>.*?)//\s*end-report-data",
    re.DOTALL,
)

# Keys that carry the human-readable text of a problem, in preference order.
# Gradle has used several spellings across releases; the first one present wins.
MESSAGE_KEYS = ("contextualLabel", "label", "message", "problemDetails", "details")

# The key naming the plugin an occurrence originated in.
ORIGIN_KEY = "pluginId"

# What to print when the payload states no origin for an occurrence.
UNATTRIBUTED = "(origin not stated)"


def report_path(argv):
    """The report to read: the argument if given, else the first default that
    exists, else None (which the caller treats as "nothing to do")."""
    if argv:
        return argv[0]
    for candidate in DEFAULT_PATHS:
        if os.path.isfile(candidate):
            return candidate
    return None


def embedded_payload(text):
    """
    The JSON payload embedded in the report page, or None when the markers are
    absent.

    Returning None keeps "this is not the page I expected" separate from "this
    page has no problems in it": only the latter is a clean result.
    """
    match = PAYLOAD.search(text)
    if match is None:
        return None
    return json.loads(match.group("json").strip().rstrip(";"))


def find_strings(node, key):
    """
    Every string value stored under `key` anywhere below `node`.

    A recursive search rather than a fixed path -- see the module docstring on
    why the payload's shape is not assumed.
    """
    found = []
    if isinstance(node, dict):
        for name, value in node.items():
            if name == key and isinstance(value, str):
                found.append(value)
            else:
                found.extend(find_strings(value, key))
    elif isinstance(node, list):
        for item in node:
            found.extend(find_strings(item, key))
    return found


def messages_below(node):
    """
    Every problem message anywhere below `node`, in MESSAGE_KEYS preference
    order per object.

    Preference order matters because Gradle carries several spellings at once:
    an entry with both `contextualLabel` and `label` describes ONE problem, and
    counting both would double it.
    """
    found = []
    if isinstance(node, dict):
        for key in MESSAGE_KEYS:
            value = node.get(key)
            if isinstance(value, str) and value.strip():
                found.append(value.strip())
                break
        for name, value in node.items():
            if name in MESSAGE_KEYS and isinstance(value, str):
                continue
            found.extend(messages_below(value))
    elif isinstance(node, list):
        for item in node:
            found.extend(messages_below(item))
    return found


def occurrences(payload):
    """
    The problem occurrences in the payload, as a list of (message, origin).

    An occurrence is the HIGHEST node that carries exactly one message below
    it. That rule is what pairs a message with its origin: the message text and
    the `pluginId` sit in SIBLING branches of the same entry, so a rule that
    stopped at the object holding the text (`{"label": ...}` nested inside
    `problemDetails`) would search for the origin in the wrong subtree and
    report every occurrence as unattributed. Descending only while a node still
    covers several messages splits the payload into one node per problem and no
    finer.
    """
    results = []

    def walk(node):
        count = len(messages_below(node))
        if count == 0:
            return
        if count == 1:
            message = messages_below(node)[0]
            origins = find_strings(node, ORIGIN_KEY)
            results.append((message, origins[0] if origins else UNATTRIBUTED))
            return
        if isinstance(node, dict):
            for value in node.values():
                walk(value)
        elif isinstance(node, list):
            for item in node:
                walk(item)

    walk(payload)
    return results


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    path = report_path(argv)

    if path is None or not os.path.isfile(path):
        print(
            "problems-report: no Gradle problems report found -- it is written "
            "by any Gradle build under app/build/reports/problems/; nothing to "
            "attribute."
        )
        return 0

    try:
        with open(path, "r", encoding="utf-8") as handle:
            payload = embedded_payload(handle.read())
    except (OSError, json.JSONDecodeError) as error:
        print(
            f"problems-report: cannot read the problems report at {path}: "
            f"{error}",
            file=sys.stderr,
        )
        return 1

    if payload is None:
        print(
            f"problems-report: {path} carries no "
            "'// begin-report-data' payload -- the report format has changed "
            "and this tool needs updating.",
            file=sys.stderr,
        )
        return 1

    found = occurrences(payload)
    if not found:
        print(f"problems-report: no problems recorded in {path}.")
        return 0

    counts = Counter(found)
    total = sum(counts.values())
    print(
        f"problems-report: {total} occurrence(s) of {len(counts)} distinct "
        f"problem(s) in {path}:"
    )
    for (message, origin), count in sorted(
        counts.items(), key=lambda item: (-item[1], item[0])
    ):
        print(f"problems-report: {count}x  {origin}")
        print(f"    {message}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
