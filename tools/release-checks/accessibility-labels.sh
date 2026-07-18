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
#  release-checks/accessibility-labels.sh -- sourced by tools/release-check.sh (see lib.sh).
# =============================================================================


# =============================================================================
# SECTION 13 – ACCESSIBILITY LABELS
# =============================================================================
#   Regression guard for the project's accessibility-labelling convention: an
#   icon-only, actionable control must expose an accessible name, or a screen
#   reader (TalkBack) announces only "button". In this codebase that means every
#   Icon inside an IconButton sets a non-null contentDescription; purely
#   decorative icons that sit beside their own visible text label (menu leading
#   glyphs, the bottom-nav icons) may keep contentDescription = null and are not
#   flagged. The check fails ONLY when an Icon that is the direct child of an
#   IconButton { ... } lambda is left with contentDescription = null.
#
#   SCOPE / HONESTY: this is a labelling invariant, NOT a WCAG conformance test.
#   Per W3C, no automated check can determine WCAG conformance — see
#   docs/ROADMAP.md (Accessibility) for the honest status and the open Level AA
#   gaps. The gate exists so the labels the project HAS added cannot silently
#   regress. It skips gracefully (info) where python3 is unavailable and warns
#   only on a real finding.
check_accessibility_labels() {
    section "13 / 15 — ACCESSIBILITY LABELS"

    if ! command -v python3 >/dev/null 2>&1; then
        info "python3 not found — skipping accessibility-label check"
        return
    fi

    local files
    mapfile -t files < <(find app/src/main/kotlin -name '*.kt' 2>/dev/null)
    if [[ "${#files[@]}" -eq 0 ]]; then
        info "No Kotlin sources found — nothing to check"
        return
    fi

    # The scanner is brace-aware: it isolates each IconButton(...) { ... } lambda
    # and only reports contentDescription = null WITHIN that lambda, so decorative
    # icons elsewhere are never false-flagged. Guarded by `if` (not a bare
    # assignment) so the python exit status 1 on findings does not abort the
    # script under `set -e`; see the SECTION 9 note for the same pattern.
    local out err
    err=$(mktemp)
    if out=$(python3 - "${files[@]}" 2>"$err" <<'PYEND'
import re, sys

NULL_DESC = re.compile(r'contentDescription\s*=\s*null')
findings = []

def line_of(text, idx):
    return text.count('\n', 0, idx) + 1

def match_delim(s, start, open_ch, close_ch):
    """Return index of the delimiter that closes the one at s[start]."""
    depth = 0
    i = start
    while i < len(s):
        c = s[i]
        if c == open_ch:
            depth += 1
        elif c == close_ch:
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1

for path in sys.argv[1:]:
    try:
        s = open(path, encoding='utf-8').read()
    except OSError:
        continue
    i = 0
    while True:
        m = re.search(r'\bIconButton\b', s[i:])
        if not m:
            break
        after = i + m.end()
        paren = s.find('(', after)
        if paren < 0:
            break
        end_args = match_delim(s, paren, '(', ')')
        if end_args < 0:
            break
        # Expect a trailing lambda immediately after the argument list.
        k = end_args + 1
        while k < len(s) and s[k] in ' \t\r\n':
            k += 1
        if k >= len(s) or s[k] != '{':
            i = end_args + 1
            continue
        end_lambda = match_delim(s, k, '{', '}')
        if end_lambda < 0:
            break
        block = s[k:end_lambda + 1]
        for nm in NULL_DESC.finditer(block):
            findings.append(
                f"{path}:{line_of(s, k + nm.start())}: "
                "Icon inside IconButton has contentDescription = null "
                "(interactive control needs an accessible name)"
            )
        i = end_lambda + 1

for f in sorted(findings):
    print(f)
sys.exit(1 if findings else 0)
PYEND
    ); then
        pass "All interactive IconButton icons carry a non-null contentDescription"
    elif [[ -s "$err" ]]; then
        fail "accessibility-label check did not run cleanly: $(tr '\n' ' ' <"$err")"
    else
        while IFS= read -r line; do
            [[ -n "$line" ]] && fail "$line"
        done <<< "$out"
    fi
    rm -f "$err"
}
