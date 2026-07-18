#!/usr/bin/env bash
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
#  release-checks/metadata-lengths.sh -- sourced by tools/release-check.sh (see lib.sh).
# =============================================================================


# -----------------------------------------------------------------------------
# SECTION 10 — STORE METADATA LENGTH LIMITS
# -----------------------------------------------------------------------------
# Google Play / F-Droid (Triple-T) cap the length of the store-listing texts.
# Exceeding them is silently truncated on Play and flagged by the F-Droid MR
# code-quality scan, so catch it here BEFORE tagging. Limits, counted in
# CHARACTERS (not bytes) so multi-byte scripts — Greek, Cyrillic, CJK — are
# measured the way the stores do:
#   short_description.txt   ≤   80   (the listing summary)
#   full_description.txt    ≤ 4000
#   changelogs/<code>.txt   ≤  500   (the per-release "what's new" note)
check_metadata_lengths() {
    section "10 / 15 — STORE METADATA LENGTH LIMITS"

    # python3 is already a prerequisite (see §5); reuse it for correct,
    # locale-independent character counting.
    if ! command -v python3 >/dev/null 2>&1; then
        warn "python3 not found — skipping metadata length check"
        return
    fi

    # Run the checker under an `if`, NOT a bare `output=$(...)` assignment: under
    # `set -euo pipefail` a standalone assignment whose command substitution exits
    # non-zero aborts the WHOLE script here -- before the captured problems can be
    # printed (the same trap documented in check_markdown_syntax). Since the
    # checker deliberately exits 1 when it FINDS violations, the unguarded form
    # silently killed the run on exactly the case this section exists to report.
    local output
    if output=$(python3 - "$FASTLANE_DIR" <<'PYEOF'
import sys, glob, os

root = sys.argv[1]
# (filename glob, character limit). These are Google Play's store-listing limits
# (Play Console Help: title 30, short description 80, full description 4000;
# release notes 500 per language).
FIXED = [("title.txt", 30), ("short_description.txt", 80), ("full_description.txt", 4000)]
problems = []

def length(path):
    # Count the RAW character length, INCLUDING a trailing newline. supply sends
    # the file's bytes to Google verbatim (File.read, no strip), and Google counts
    # what it receives -- an el-GR note of 500 visible chars + "\n" was rejected as
    # 501 > 500. Counting the newline here mirrors that exactly, so the gate fails
    # at build time on the same length Google would reject at push time. Unicode
    # code points (Python str) match Google's rule that limits apply per character
    # regardless of full-/half-width.
    with open(path, encoding="utf-8") as fh:
        return len(fh.read())

for name, limit in FIXED:
    for path in sorted(glob.glob(os.path.join(root, "*", name))):
        n = length(path)
        if n > limit:
            problems.append(f"{path}: {n} chars > {limit}")

for path in sorted(glob.glob(os.path.join(root, "*", "changelogs", "*.txt"))):
    n = length(path)
    if n > 500:
        problems.append(f"{path}: {n} chars > 500")

for p in problems:
    print(p)
sys.exit(1 if problems else 0)
PYEOF
    ); then
        pass "Store metadata within length limits (title ≤30, summary ≤80, full ≤4000, changelog ≤500; counted incl. trailing newline as Google does)"
    else
        # One "path: N chars > LIMIT" per offending file on stdout.
        while IFS= read -r line; do
            [[ -n "$line" ]] && fail "$line"
        done <<< "$output"
    fi
}
