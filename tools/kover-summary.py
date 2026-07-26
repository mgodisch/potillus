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
kover-summary.py -- print the measured Android coverage, line AND branch.

WHY
    `:app:koverVerify` answers one question: does the run clear the floors in
    app/build.gradle.kts (LINE >= 90, BRANCH >= 80)? It prints pass or fail and
    no figure. `:app:koverLog` prints a figure, but only the LINE one -- it says
    nothing about branches. So the branch percentage the project quotes about
    itself, in .bestpractices.json and in the ROADMAP, came from a measurement
    nobody could reproduce from a build log.

    This tool closes that: it reads the machine-readable report written by
    `:app:koverXmlReport` and prints both percentages together with the counts
    they are derived from, in a form a reviewer can paste into a justification
    and a later reviewer can re-measure.

WHAT IT READS
    Kover writes a JaCoCo-compatible XML report whose ROOT element carries one
    <counter type="..." missed="..." covered="..."/> per metric, aggregated over
    everything the kover { } filters admitted. Only the root-level counters are
    read: the per-package and per-class counters below them are the same numbers
    split up, and summing those would double-count.

    The path is taken from the command line when given, else the first match of
    the default search list below. It is NOT hard-coded to one location, so a
    Gradle layout change costs an argument rather than an edit here.

WHAT IT PRINTS
    One line per metric found, in this shape:

        kover-summary: LINE   coverage <pct>% (<covered>/<total> lines covered)
        kover-summary: BRANCH coverage <pct>% (<covered>/<total> branches covered)

    Written as placeholders on purpose. Real figures here read as the project's
    current coverage and go stale the next time a test lands; the numbers belong
    in .bestpractices.json and docs/ROADMAP.md, where something checks them.

    plus, when the floors are readable from app/build.gradle.kts, the bound each
    metric is verified against, so the headroom is visible at a glance.

GRACEFUL SKIP
    A missing report is NOT an error: this tool runs inside the QA battery,
    where an environment without an Android SDK legitimately has no build
    output. It then prints an informational line naming the task that produces
    the report and exits 0, the same stance tools/check-vex.py takes towards an
    absent openvex.json. It exits non-zero only when a report EXISTS but cannot
    be parsed, which is a real defect worth surfacing.
"""

import os
import re
import sys
import xml.etree.ElementTree as ElementTree

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# Where `:app:koverXmlReport` puts its report, most specific first. The task's
# own default is the first entry; the second covers a project-level report.
DEFAULT_PATHS = (
    os.path.join(ROOT, "android", "app", "build", "reports", "kover", "report.xml"),
    os.path.join(ROOT, "android", "build", "reports", "kover", "report.xml"),
)

# The metrics worth printing, in the order the floors are stated in the Gradle
# build. Kover reports more (CLASS, METHOD, COMPLEXITY); those are not what the
# project verifies against, so printing them would only dilute the output.
METRICS = ("LINE", "BRANCH")

# What one unit of each metric is called, for a summary line that reads as a
# sentence rather than as a table.
UNITS = {"LINE": "lines", "BRANCH": "branches"}

# The verification floors live in the Gradle build as `minBound(90,
# CoverageUnit.LINE)`. Reading them here keeps the printed headroom honest when
# a floor is raised, instead of repeating a number that would drift.
BOUND_PATTERN = re.compile(
    r"minBound\s*\(\s*(\d+)\s*,\s*CoverageUnit\.([A-Z]+)\s*\)"
)
BUILD_FILE = os.path.join(ROOT, "android", "app", "build.gradle.kts")


def report_path(argv):
    """
    The XML report to read: the argument if given, else the first default that
    exists, else None.

    Returning None rather than raising keeps the "no build output here" case on
    the graceful path; the caller decides that it is not a failure.
    """
    if argv:
        return argv[0]
    for candidate in DEFAULT_PATHS:
        if os.path.isfile(candidate):
            return candidate
    return None


def root_counters(path):
    """
    The root-level counters of a JaCoCo-style report, as
    {metric: (covered, missed)}.

    Only direct children of the root element are read -- see the module
    docstring on why the nested ones must not be summed.
    """
    tree = ElementTree.parse(path)
    counters = {}
    for element in tree.getroot():
        if element.tag != "counter":
            continue
        metric = element.get("type")
        if metric is None:
            continue
        counters[metric] = (
            int(element.get("covered", "0")),
            int(element.get("missed", "0")),
        )
    return counters


def configured_bounds():
    """
    The verification floors per metric from app/build.gradle.kts, or {} when the
    build file is unreadable -- in which case the summary simply omits them.
    """
    try:
        with open(BUILD_FILE, "r", encoding="utf-8") as handle:
            text = handle.read()
    except OSError:
        return {}
    return {metric: int(value) for value, metric in BOUND_PATTERN.findall(text)}


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    path = report_path(argv)

    if path is None or not os.path.isfile(path):
        print(
            "kover-summary: no Kover XML report found -- run "
            "'./gradlew :app:koverXmlReport' (or 'make -C android cover-figures') "
            "first; nothing to summarise."
        )
        return 0

    try:
        counters = root_counters(path)
    except (ElementTree.ParseError, ValueError) as error:
        print(
            f"kover-summary: cannot read the coverage report at {path}: {error}",
            file=sys.stderr,
        )
        return 1

    bounds = configured_bounds()
    printed = False
    for metric in METRICS:
        if metric not in counters:
            continue
        covered, missed = counters[metric]
        total = covered + missed
        if total == 0:
            print(f"kover-summary: {metric} has no counted units in {path}")
            continue
        percent = 100.0 * covered / total
        bound = bounds.get(metric)
        suffix = f" >= {bound}% floor" if bound is not None else ""
        print(
            f"kover-summary: {metric:<6} coverage {percent:.2f}% "
            f"({covered}/{total} {UNITS.get(metric, 'units')} covered){suffix}"
        )
        printed = True

    if not printed:
        print(
            f"kover-summary: the report at {path} carries none of the "
            f"{', '.join(METRICS)} counters -- nothing to summarise."
        )

    return 0


if __name__ == "__main__":
    sys.exit(main())
