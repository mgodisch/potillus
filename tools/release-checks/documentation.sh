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
#  release-checks/documentation.sh -- sourced by tools/release-check.sh (see lib.sh).
# =============================================================================


# =============================================================================
# SECTION 5 – SOURCE CODE DOCUMENTATION
#
# WHY THIS MATTERS:
#   This project doubles as a teaching app.  Every source file must carry the
#   GPL-3.0 header (copyright notice, license notice) and every public function
#   must be documented with KDoc so readers can understand the code without
#   needing to trace call sites.
#
# 5a. FILE HEADERS
#   The canonical header starts with the vim modeline comment.
#   We check for the presence of "GNU General Public License" as the unique
#   identifier rather than the exact vim modeline, which makes the check
#   robust against minor formatting variations.
#
# 5b. FUNCTION KDOC (heuristic)
#   We scan for public/internal/top-level function declarations and verify each
#   is preceded by a KDoc block (a line ending in "*/"). The look-behind skips
#   blank lines, single-line annotations, AND multi-line annotation arguments
#   such as @Query("""…""") so that KDoc placed above the annotation is still
#   found. Excluded from the requirement (documented with inline comments, not
#   KDoc): private functions, trivial set/clear/dismiss one-liners, and LOCAL
#   (nested) functions — detected as declarations indented more than 8 spaces,
#   i.e. deeper than any top-level, class-member or companion-object member.
# =============================================================================
check_documentation() {
    section "5 / 15 — SOURCE CODE DOCUMENTATION"

    # ── 5a: GPL file headers ──────────────────────────────────────────────────
    local missing_headers=0 total_kt=0

    while IFS= read -r kt_file; do
        total_kt=$(( total_kt + 1 ))
        if ! grep -q "GNU General Public License" "$kt_file"; then
            fail "Missing GPL header: $kt_file"
            missing_headers=$(( missing_headers + 1 ))
        fi
    done < <(find "$SOURCE_ROOT" "app/src/test" -name '*.kt' 2>/dev/null | sort)

    if [[ "$missing_headers" -eq 0 ]]; then
        pass "All $total_kt Kotlin files have GPL-3.0 file headers"
    fi

    # ── 5b: KDoc on public/internal functions (heuristic) ────────────────────
    # Strategy:
    #   For every line that starts a public or internal fun (not private, not
    #   override-only-private, not a lambda), look at the non-empty line
    #   immediately above it.  If that line ends with "*/" it is the closing
    #   line of a KDoc block → documented.  Otherwise → report as missing.
    #
    # We use Python for the multi-line context scan because bash is awkward
    # for look-behind parsing of text files.
    local missing_kdoc
    missing_kdoc=$(python3 - "$SOURCE_ROOT" <<'PYEOF'
import sys, os, re

source_root = sys.argv[1]

# Patterns: match public/internal function lines.
# We exclude:  private, override (typically inherits doc from interface),
#              lambda shorthand (fun () = ...), and @JvmStatic boilerplate.
fun_re   = re.compile(r'^\s*((?:internal\s+)?(?:suspend\s+)?fun\s+\w)')
skip_re  = re.compile(r'^\s*(private|override|//)')
anno_re  = re.compile(r'^\s*@')   # annotation line — not a doc line
kdoc_re  = re.compile(r'\*/')     # end of a KDoc block

results = []

for dirpath, _, filenames in os.walk(source_root):
    for fname in sorted(filenames):
        if not fname.endswith('.kt'):
            continue
        fpath = os.path.join(dirpath, fname)
        with open(fpath, encoding='utf-8', errors='replace') as fh:
            lines = fh.readlines()

        for i, line in enumerate(lines):
            if not fun_re.match(line):
                continue
            if skip_re.match(line):
                continue
            # Skip trivial one-liner setter/delegate functions:
            # these are boilerplate that forward to a repository or preference
            # method, and their purpose is self-evident from the function name.
            # Pattern: the entire function body is on the same line (contains
            # "= " or "{ " and ends without a separate closing brace).
            # Examples: fun setTheme(m) = launch { prefs.setTheme(m) }
            #           fun toggleViewMode() { _mode.value = … }
            stripped = line.rstrip()
            is_one_liner = (
                re.search(r"fun\s+set[A-Z]", stripped) or
                re.search(r"fun\s+clear[A-Z]", stripped) or
                re.search(r"fun\s+dismiss[A-Z]", stripped)
            ) and (stripped.endswith("}") or stripped.endswith(")"))
            if is_one_liner:
                continue

            # Skip LOCAL (nested) functions. Like private functions, local
            # helpers declared inside another function's body are documented
            # with inline comments, not KDoc. Under the project's 4-space
            # indentation, every API-level function is a top-level (0 spaces),
            # class-member (4) or companion/object-member (8) declaration, so a
            # leading indent of MORE than 8 spaces reliably marks a local helper
            # (e.g. `fun svg(...)` defined inside a `run { … }` block).
            indent = len(line) - len(line.lstrip(' '))
            if indent > 8:
                continue

            # Walk upwards over blank lines and annotation lines to find the most
            # recent non-trivial preceding line.
            j = i - 1
            while j >= 0:
                prev = lines[j]
                if prev.strip() == '' or anno_re.match(prev):
                    j -= 1
                    continue
                # A MULTI-LINE annotation argument — e.g.
                #     @Query("""
                #         SELECT …
                #     """)
                # — ends on a line such as `    """)` or `    )`. Those body
                # lines are neither blank nor start with '@', so without this
                # they would stop the look-behind before reaching the KDoc that
                # sits above the annotation, producing a false positive (e.g.
                # EntryDao.getDailySummaries). When the preceding line closes
                # such an argument, rewind past the matching `@Name(` opener
                # (bounded to 30 lines) and keep scanning above it.
                if prev.rstrip().endswith(')'):
                    k, limit = j, max(0, j - 30)
                    while k >= limit and not re.match(r'^\s*@\w+\s*\(', lines[k]):
                        k -= 1
                    if k >= limit and re.match(r'^\s*@\w+\s*\(', lines[k]):
                        j = k - 1
                        continue
                break

            if j < 0 or not kdoc_re.search(lines[j]):
                # No KDoc found above this function.
                rel = os.path.relpath(fpath, source_root)
                func_snippet = line.strip()[:80]
                results.append(f"  {rel}:{i+1}: {func_snippet}")

for r in results[:20]:   # cap at 20 to avoid flooding output
    print(r)
if len(results) > 20:
    print(f"  … and {len(results)-20} more (run with --verbose to see all)")
PYEOF
)

    if [[ -n "$missing_kdoc" ]]; then
        warn "Public/internal functions without KDoc (heuristic — review manually):"
        echo "$missing_kdoc" | while IFS= read -r line; do
            echo -e "    ${YELLOW}$line${NC}"
        done
    else
        pass "All detected public/internal functions appear to have KDoc"
    fi
}
