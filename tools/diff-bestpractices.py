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
diff-bestpractices.py -- show which committed badge answers still differ upstream.

WHY THIS EXISTS
    The project's OpenSSF badge answers live in two places: the committed
    .bestpractices.json (the maintainer's SOURCE OF TRUTH, edited by hand) and
    the live bestpractices.dev form (what the badge site actually publishes).
    bestpractices.dev does not ingest the committed file, so
    keeping the two in step is a manual transcription: the maintainer edits the
    committed file, then copies each changed answer into the web form.

    The old workflow ran `make bestpractices-json`, which OVERWROTE the committed
    file with a fresh download and left the maintainer to read `git diff` to see
    what the site still lacked -- a pull that could clobber unpushed local edits
    (exactly the hazard the v0.84.0 changelog warns about). This tool replaces
    that with a READ-ONLY report: it compares the committed answers against a
    fresh download WITHOUT touching the working tree, and prints exactly the
    criteria whose answer the site does not yet match, so the maintainer knows
    precisely what to enter upstream.

INPUTS
    1. .bestpractices.json          -- the committed answers (the desired state).
    2. UPSTREAM.json (an argument)  -- the current site export, already reduced
       to the tracked shape by filter-bestpractices.py. Keeping the network out
       of this tool (the Makefile does the `curl ... | filter-bestpractices.py`)
       makes the comparison offline-testable and normalizes BOTH sides through
       the very same filter, so a difference is a real answer change, never a
       formatting artifact.
    3. tools/bestpractices-levels.json -- criterion -> badge level, used to group
       and order the report.

COMPARISON
    Both inputs are filter-bestpractices.py outputs, so each tracked criterion
    carries a `<c>_status` (defaulting to "?" when the site left it unanswered)
    and, when answered, a `<c>_justification`. A criterion DIFFERS when either its
    status or its justification text differs between the committed file and the
    download. For each differing criterion the report prints one fixed block --
    its level, its name, then the UPSTREAM answer (status + justification, what the
    site holds now) and the COMMITTED answer (status + justification, the values to
    enter upstream). Both statuses and both justifications appear even when only
    one of them differs, so every block has the same shape; an absent justification
    is shown as a tab-indented "(none)". Printing upstream before committed makes
    the direction of every change explicit -- including the reverse case, where the
    site is ahead of a not-yet-updated committed file.

ORDERING
    Sorted by badge level in the fixed order the badge form presents them -- the
    metal series passing -> silver -> gold, then the OSPS Baseline level 1 ->
    level 2 -> level 3 -- and by criterion name within a level. Each block names
    its own level; there are no level group headers.

USAGE
    tools/diff-bestpractices.py [--check] UPSTREAM.json
        Text report (default). Without --check it is informational and exits 0;
        with --check it exits 1 while any answer still differs, so it can gate a
        release.
    tools/diff-bestpractices.py --html --edit-base URL UPSTREAM.json
        Emit (to stdout) a standalone HTML page for transcribing the differing answers
        upstream by hand: one entry per criterion, grouped by level, with a link to that
        criterion's section edit form (anchored at the criterion), the committed status
        to select, and the committed justification in a Copy-to-clipboard box. (The site
        does not pre-fill an already-answered field from the URL, so the answer is not
        carried in the link.) URL is the project base, e.g.
        https://www.bestpractices.dev/en/projects/13480 .
    Exit status: 0 = in sync / informational / html, 1 = differences under --check,
    2 = bad invocation or unreadable/malformed input.
"""

import html
import json
import os
import sys

from potillus_repo import repo_root

ROOT = str(repo_root())
ANSWERS_PATH = os.path.join(ROOT, ".bestpractices.json")
LEVELS_PATH = os.path.join(ROOT, "tools", "bestpractices-levels.json")

# Status filter-bestpractices.py writes for a tracked-but-unanswered criterion.
# Mirrored here so a criterion missing from one side compares as "?" rather than
# raising, matching what the committed file already stores.
UNANSWERED = "?"

# The badge form's own level order. A criterion whose level string is not in this
# table sorts LAST (and is still reported), so a levels-map gap stays visible
# rather than silently dropping the criterion from the report.
LEVEL_ORDER = {
    "passing": 0,
    "silver": 1,
    "gold": 2,
    "level 1": 3,
    "level 2": 4,
    "level 3": 5,
}

# Badge level -> the URL path segment bestpractices.dev uses for that section's
# edit form. A criterion's pre-filled edit link is <edit-base>/<slug>/edit?..., so
# it lands on the section the criterion belongs to; without the slug the site first
# makes the maintainer pick a section by hand (a criterion can recur across levels).
SECTION_SLUG = {
    "passing": "passing",
    "silver": "silver",
    "gold": "gold",
    "level 1": "baseline-1",
    "level 2": "baseline-2",
    "level 3": "baseline-3",
}


def load_json(path):
    """Parse a JSON file, raising OSError/JSONDecodeError for the caller to map
    onto exit code 2."""
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def level_of_criterion(levels):
    """Flatten the two-series level map (metal + baseline) into one
    criterion -> level-string dictionary spanning every tracked criterion."""
    mapping = {}
    mapping.update(levels["metal"])
    mapping.update(levels["baseline"])
    return mapping


def answer_of(data, criterion):
    """The (status, justification) a filtered answers file holds for one
    criterion. status defaults to UNANSWERED (filter's own default for an absent
    criterion); justification is None when the file carries no rationale."""
    status = data.get(f"{criterion}_status", UNANSWERED)
    justification = data.get(f"{criterion}_justification")
    return status, justification


def indent_block(text):
    """Render a (possibly multi-line, possibly empty) justification, each line
    indented by one tab under its status line. None or "" becomes a tab-indented
    "(none)" so an absent rationale reads explicitly rather than as a blank line."""
    if not text:
        return "\t(none)"
    return "\n".join(f"\t{line}" for line in text.splitlines())


def collect_differences(local, upstream, level_map):
    """Every tracked criterion whose committed answer differs from the download,
    as (criterion, level, local_status, local_just, upstream_status,
    upstream_just), sorted by badge level then criterion name."""
    differences = []
    for criterion, level in level_map.items():
        local_status, local_just = answer_of(local, criterion)
        upstream_status, upstream_just = answer_of(upstream, criterion)
        same_status = local_status == upstream_status
        same_just = (local_just or "") == (upstream_just or "")
        if same_status and same_just:
            continue
        differences.append(
            (criterion, level, local_status, local_just, upstream_status, upstream_just)
        )
    differences.sort(key=lambda row: (LEVEL_ORDER.get(row[1], len(LEVEL_ORDER)), row[0]))
    return differences


def report(differences):
    """Print one fixed block per differing criterion. "upstream" is what the site
    currently holds; "committed" is the text to enter upstream. Both statuses and
    both justifications are printed for every entry, so the block shape is uniform
    even when only one of the two differs. Each block names its own level (there
    are no level group headers); blocks are separated by a blank line."""
    print(
        f"diff-bestpractices: {len(differences)} criterion(s) differ from the "
        f"current bestpractices.dev answers."
    )
    print('For each, "committed" is the text to enter upstream; '
          '"upstream" is what the site holds now.')
    print()

    for criterion, level, l_status, l_just, u_status, u_just in differences:
        print(f"level: {level}")
        print(f"name: {criterion}")
        print(f"upstream: {u_status}")
        print(indent_block(u_just))
        print(f"committed: {l_status}")
        print(indent_block(l_just))
        print()


def param_name(criterion):
    """The query-parameter stem bestpractices.dev expects for a criterion. The metal
    criteria are already the field names (e.g. test_most), so they pass through
    unchanged; the OSPS Baseline ids (OSPS-AC-01.01) are lower-cased with '-' and '.'
    turned into '_' (osps_ac_01_01), matching the site's field names."""
    if criterion.startswith("OSPS-"):
        return criterion.lower().replace("-", "_").replace(".", "_")
    return criterion


def edit_url(edit_base, criterion, level):
    """The edit-form URL for one criterion's section, anchored at the criterion so the
    browser scrolls to it: <edit-base>/<section>/edit#<anchor>. Returns None if the
    level has no known edit section. The anchor is the criterion's field stem (metal
    names as-is, OSPS ids normalised); it is best-effort for the Baseline tiers -- if it
    does not match, the link still lands on the correct section. No answer is passed in
    the URL: bestpractices.dev does not overwrite an already-answered field from query
    parameters, so the committed value is copied into the form by hand instead."""
    section = SECTION_SLUG.get(level)
    if section is None:
        return None
    return f"{edit_base}/{section}/edit#{param_name(criterion)}"


def html_report(differences, edit_base):
    """A standalone HTML page for transcribing the committed answers upstream by hand.
    One entry per differing criterion, grouped by level: a link to that criterion's
    section edit form (anchored at the criterion), the committed status to select, and
    the committed justification in a read-only box with a Copy button. bestpractices.dev
    does not pre-fill an already-answered field from the URL, so this keeps the manual
    step -- open the section, pick the status, paste the justification -- as short as
    possible. Returns the page as a string."""
    esc = html.escape
    out = [
        "<!DOCTYPE html>",
        '<html lang="en"><head><meta charset="utf-8">',
        f"<title>bestpractices upstream sync -- {len(differences)} to transcribe</title>",
        "<style>"
        "body{font-family:system-ui,sans-serif;max-width:64rem;margin:2rem auto;"
        "padding:0 1rem;line-height:1.5}h1{font-size:1.4rem}h2{margin-top:1.6rem;"
        "border-bottom:1px solid #ccc;text-transform:capitalize}ul{list-style:none;"
        "padding:0}li{margin:1rem 0;padding:.6rem .8rem;border:1px solid #ddd;"
        "border-radius:6px}.hd{display:flex;align-items:center;gap:.6rem;flex-wrap:wrap}"
        ".hd a{font-weight:600}.st{color:#555;font-variant:small-caps}"
        "button{cursor:pointer;padding:.15rem .5rem}textarea{width:100%;"
        "box-sizing:border-box;margin-top:.4rem;font-family:ui-monospace,monospace;"
        "font-size:.85rem}</style></head><body>",
        "<h1>OpenSSF badge: committed answers to transcribe upstream</h1>",
    ]
    if not differences:
        out.append("<p>In sync with upstream -- nothing to transcribe.</p></body></html>")
        return "\n".join(out)

    out.append(
        f"<p>{len(differences)} criterion(s) differ from what bestpractices.dev currently "
        "holds. For each: open the linked section (it scrolls to the criterion), set the "
        "status shown, then use Copy and paste the justification into the form. The site "
        "does not fill an answered field from the URL, so this last part is manual.</p>"
    )
    current_level = None
    for criterion, level, l_status, l_just, _u_status, _u_just in differences:
        if level != current_level:
            if current_level is not None:
                out.append("</ul>")
            out.append(f"<h2>{esc(level)}</h2>")
            out.append("<ul>")
            current_level = level
        url = edit_url(edit_base, criterion, level)
        link = (f'<a href="{esc(url)}">{esc(criterion)}</a>' if url
                else f"{esc(criterion)} (no edit section for level {esc(level)})")
        just = l_just or ""
        rows = min(12, max(2, just.count("\n") + len(just) // 90 + 1))
        out.append("<li>")
        out.append(
            f'<div class="hd">{link}'
            f'<span class="st">status: {esc(l_status)}</span>'
            '<button type="button" onclick="cp(this)">Copy justification</button></div>'
        )
        out.append(f'<textarea readonly rows="{rows}">{esc(just)}</textarea>')
        out.append("</li>")
    out.append("</ul>")
    out.append(
        "<script>\n"
        "function done(b){var o=b.textContent;b.textContent='Copied';"
        "setTimeout(function(){b.textContent=o;},1200);}\n"
        "function legacy(t){var ro=t.readOnly;t.readOnly=false;t.focus();t.select();"
        "try{document.execCommand('copy');}catch(e){}t.readOnly=ro;"
        "window.getSelection().removeAllRanges();}\n"
        "function cp(b){var t=b.closest('li').querySelector('textarea');"
        "if(navigator.clipboard&&navigator.clipboard.writeText){"
        "navigator.clipboard.writeText(t.value).then(function(){done(b);},"
        "function(){legacy(t);done(b);});}else{legacy(t);done(b);}}\n"
        "</script>"
    )
    out.append("</body></html>")
    return "\n".join(out)


def main(argv):
    args = argv[1:]
    check = "--check" in args
    want_html = "--html" in args
    edit_base = None
    positional = []
    index = 0
    while index < len(args):
        arg = args[index]
        if arg == "--edit-base":
            index += 1
            if index >= len(args):
                print("diff-bestpractices: --edit-base needs a URL", file=sys.stderr)
                return 2
            edit_base = args[index].rstrip("/")
        elif arg in ("--check", "--html"):
            pass
        elif arg.startswith("-"):
            print(f"diff-bestpractices: unknown option {arg}", file=sys.stderr)
            return 2
        else:
            positional.append(arg)
        index += 1

    if len(positional) != 1:
        print("usage: diff-bestpractices.py [--check] [--html --edit-base URL] "
              "UPSTREAM.json", file=sys.stderr)
        return 2
    if want_html and not edit_base:
        print("diff-bestpractices: --html requires --edit-base URL", file=sys.stderr)
        return 2

    try:
        local = load_json(ANSWERS_PATH)
        upstream = load_json(positional[0])
        levels = load_json(LEVELS_PATH)
    except (OSError, json.JSONDecodeError) as error:
        print(f"diff-bestpractices: cannot read input: {error}", file=sys.stderr)
        return 2

    differences = collect_differences(local, upstream, level_of_criterion(levels))

    if want_html:
        print(html_report(differences, edit_base))
        return 0

    if not differences:
        print("diff-bestpractices: in sync with upstream -- nothing to transcribe.")
        return 0

    report(differences)
    return 1 if check else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
