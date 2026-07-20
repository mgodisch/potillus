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
#  release-checks/markdown-syntax.sh -- sourced by tools/release-check.sh (see lib.sh).
# =============================================================================


# =============================================================================
# SECTION 9 – MARKDOWN SYNTAX
#
# WHY THIS MATTERS:
#   The in-app guide/license viewer renders Markdown with a small, permissive
#   in-house renderer.  A stray emphasis marker — an asterisk or underscore
#   meant literally but left outside an inline-code span — silently becomes
#   italics/bold there.  Generic Markdown tools do not catch this (renderers
#   just convert; style linters check layout), so we run a tiny standard-library
#   checker, tools/md-syntax.py, over the authored docs and the rendered guides.
#
#   Left out on purpose: the verbatim license texts (LICENSE.md,
#   licenses/LICENSE.Apache-2.0.md, licenses/LICENSE.GPL-2.0.md) and COPYING.md.  Their GNU
#   `quoted' style uses single backticks that no balance check can satisfy, and
#   they are never reformatted anyway.  "Left out" and not "excluded": the check
#   runs over an explicit file list (see below), so they are simply not named.
# =============================================================================
check_markdown_syntax() {
    section "9 / 15 — MARKDOWN SYNTAX"

    # python3 is already a prerequisite (see §5); reuse it here.
    if ! command -v python3 >/dev/null 2>&1; then
        warn "python3 not found — skipping markdown syntax check"
        return
    fi

    # Authored docs (repo root) + the per-language guides rendered from *.md.in
    # into res/raw*/ earlier in the build. Guides are added only if present, so
    # a standalone run before `make guides` simply checks the authored docs.
    # PRIVACY.md is included because it is hosted verbatim as the store listing's
    # privacy-policy page (see docs/PLAY_STORE.md), so a stray emphasis marker
    # would misrender on the public page just as it would in the in-app guides.
    local files=("$CHANGELOG" "$README" "$CONTRIBUTING" "$PRIVACY")
    local g
    for g in app/src/main/res/raw*/usersguide.md; do
        [[ -f "$g" ]] && files+=("$g")
    done

    # Run the checker. This MUST be guarded by `if` rather than a bare
    # `output=$(...)` assignment: under `set -e` a standalone assignment whose
    # command substitution exits non-zero aborts the WHOLE script at this line —
    # before the problems captured on stdout can be printed. That is why a
    # markdown error used to surface only as a bare "Error 1" naming no file. The
    # `if` puts the command in a tested context, so a non-zero exit is handled
    # here instead of killing the run. Its stderr is captured so an unexpected
    # crash of the checker itself is surfaced rather than failing silently.
    local output err
    err=$(mktemp)
    if output=$(python3 ../tools/md-syntax.py "${files[@]}" 2>"$err"); then
        pass "Markdown syntax OK in ${#files[@]} file(s) (docs + rendered guides)"
    elif [[ -n "$output" ]]; then
        # md-syntax.py prints one "path:line: message" per problem on stdout, so
        # each FAIL below names the offending FILE and LINE.
        while IFS= read -r line; do
            [[ -n "$line" ]] && fail "$line"
        done <<< "$output"
    else
        # Non-zero exit with no per-problem output means the checker itself failed
        # (e.g. crashed); surface its stderr so the failure is never silent.
        fail "md-syntax.py did not run cleanly: $(tr '\n' ' ' <"$err")"
    fi
    rm -f "$err"
}
