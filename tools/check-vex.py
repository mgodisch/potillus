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
check-vex.py -- keep the VEX document in step with the scanner's triage.

WHY
    The project triages a known-but-non-exploitable dependency advisory in TWO
    places, because two different consumers need it:

      * osv-scanner.toml -- the GATE mechanism. An [[IgnoredVulns]] entry here
        tells the enforced osv-scanner scan (CI per change, and release staging)
        NOT to block on that advisory. This is what actually keeps a release or
        a merge unblocked.

      * openvex.json -- the COMPLIANCE / communication artifact. A `not_affected`
        statement here is the standardised, machine-readable VEX record the
        OSPS Baseline asks for (OSPS-VM-04.02), and what a downstream consumer
        or a VEX-aware scanner would read.

    These are separate today because osv-scanner does not yet consume VEX (VEX
    support is announced but unreleased upstream), so the .toml cannot be
    generated FROM the VEX. That separation is a trap: it is easy to silence a
    finding in osv-scanner.toml to unblock a release and forget to record the
    matching VEX statement, quietly leaving OSPS-VM-04.02 unmet again. This gate
    closes that gap. It FAILS when an advisory is ignored in osv-scanner.toml
    but has no matching statement in openvex.json, naming the missing id and the
    file to update. Once osv-scanner consumes VEX upstream, the two sources can
    be unified and this cross-check retired.

WHAT IT CHECKS
    For every vulnerability id ignored in osv-scanner.toml ([[IgnoredVulns]].id),
    openvex.json MUST carry a statement naming that id (statements[].vulnerability
    .name). The reverse direction (a VEX statement with no .toml ignore) is only
    WARNED about, not failed: a `fixed` or `under_investigation` statement, or a
    documented `not_affected` the gate does not need to suppress, is legitimate.

GRACEFUL SKIP
    If openvex.json is absent, the check prints an informational line and exits
    0 -- a source drop without the VEX artifact is not this gate's failure to
    report. If osv-scanner.toml is absent or has no ignores (the common, clean
    case), there is nothing to cross-check and the gate passes.
"""

import json
import os
import sys

try:
    import tomllib  # Python >= 3.11 (the project's and CI's interpreter)
except ModuleNotFoundError:  # pragma: no cover - defensive, not expected
    tomllib = None

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOML_PATH = os.path.join(ROOT, "osv-scanner.toml")
VEX_PATH = os.path.join(ROOT, "openvex.json")


def ignored_ids_from_toml(path):
    """The set of vulnerability ids ignored in osv-scanner.toml."""
    if not os.path.isfile(path):
        return set()
    if tomllib is None:
        print(
            "check-vex: tomllib unavailable (need Python >= 3.11) -- cannot "
            "read osv-scanner.toml; skipping the cross-check.",
        )
        return None
    with open(path, "rb") as handle:
        data = tomllib.load(handle)
    ids = set()
    for entry in data.get("IgnoredVulns", []):
        vid = entry.get("id")
        if vid:
            ids.add(vid)
    return ids


def statement_ids_from_vex(path):
    """The set of vulnerability ids named by statements in openvex.json."""
    with open(path, "r", encoding="utf-8") as handle:
        data = json.load(handle)
    ids = set()
    for statement in data.get("statements", []):
        name = statement.get("vulnerability", {}).get("name")
        if name:
            ids.add(name)
    return ids


def main():
    if not os.path.isfile(VEX_PATH):
        print(f"check-vex: {VEX_PATH} absent -- skipping (informational).")
        return 0

    try:
        vex_ids = statement_ids_from_vex(VEX_PATH)
    except (OSError, ValueError) as exc:
        print(f"check-vex: cannot read {VEX_PATH}: {exc}", file=sys.stderr)
        return 1

    ignored_ids = ignored_ids_from_toml(TOML_PATH)
    if ignored_ids is None:  # tomllib missing; already reported
        return 0

    missing = sorted(ignored_ids - vex_ids)
    if missing:
        print(
            "check-vex: these advisories are ignored in osv-scanner.toml but "
            "have no matching VEX statement in openvex.json:",
            file=sys.stderr,
        )
        for vid in missing:
            print(f"    {vid}", file=sys.stderr)
        print(
            "  Add a statement for each to openvex.json (status not_affected, "
            "with a machine-readable justification and the affected product's "
            "PURL) so the triage recorded for the scanner is also captured in "
            "the VEX document (OSPS-VM-04.02). See SECURITY.md, 'Dependency "
            "monitoring'.",
            file=sys.stderr,
        )
        return 1

    # Reverse direction: statements with no corresponding ignore. Legitimate
    # (e.g. a `fixed` record), so warn only -- never fail.
    extra = sorted(vex_ids - ignored_ids)
    if extra:
        print(
            "check-vex: note -- openvex.json documents advisories not ignored "
            "in osv-scanner.toml (fine if they are fixed/under_investigation, "
            "or not_affected findings the gate need not suppress): "
            + ", ".join(extra)
        )

    return 0


if __name__ == "__main__":
    sys.exit(main())
