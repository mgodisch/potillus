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
check-reuse.py -- verify the tree is REUSE-compliant (SPDX licensing metadata).

WHAT IT CHECKS
    Runs `reuse lint`, the reference implementation of the FSFE REUSE
    Specification (https://reuse.software). The lint passes only when EVERY
    file in the repository has both a copyright holder and an SPDX license
    identifier, every referenced license has its verbatim text in LICENSES/,
    and no text in LICENSES/ is left unused. For this project the facts live in
    a single central REUSE.toml (see that file's header for the why and how);
    this gate is what proves REUSE.toml still covers the whole tree after files
    are added, moved or relicensed.

WHY IT IS A LOCAL / PRE-RELEASE GATE, NOT PART OF check-static
    `reuse` is a third-party Python package, not part of the standard library.
    The device-free aggregate (make check-static, written to run on a plain
    `python:3-slim` image once the GitLab pipeline exists) is deliberately kept
    free of any pip install step, so it must not depend on `reuse` being
    present. This gate
    is therefore run locally and before a release -- exactly like the Mac-only
    SwiftLint pass (ios/Makefile `lint`), which is likewise a real external tool
    kept out of the Linux aggregate. Two independent backstops keep a regression
    from slipping through anyway: a maintainer runs `make check-reuse` before
    tagging, and the public REUSE badge (api.reuse.software) re-evaluates the
    canonical repository server-side and would turn red on a lapse.

EXIT STATUS
    0  the tree is REUSE-compliant (or `reuse` is not installed -- see below).
    1  `reuse lint` reported a violation; its own diagnostic is printed above
       this script's summary line.

    A missing `reuse` tool is reported and treated as a SKIP (exit 0), not a
    failure: the gate is opt-in tooling, and failing a checkout merely because
    an optional tool is absent would punish contributors who never touch
    licensing. The badge and the pre-release run remain as the enforcing checks.
"""

import os
import subprocess
import sys

# Self-anchor to the repository root (this file lives in tools/), so the gate
# runs `reuse` against REUSE.toml regardless of the caller's working directory.
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    # Invoke `reuse` through the interpreter (`python3 -m reuse`) rather than a
    # bare `reuse` executable: when the package is installed the module is
    # always importable, whereas a `reuse` console-script may be outside PATH
    # (e.g. a --user install). `cwd=ROOT` points the linter at REUSE.toml.
    try:
        completed = subprocess.run(
            [sys.executable, "-m", "reuse", "lint"],
            cwd=ROOT,
        )
    except FileNotFoundError:  # pragma: no cover - defensive
        # sys.executable itself is missing; nothing sensible we can do.
        print("check-reuse: no Python interpreter to run 'reuse'.", file=sys.stderr)
        return 1

    if completed.returncode == 0:
        print("check-reuse: the tree is REUSE-compliant.")
        return 0

    # `reuse` returns 1 both for a real violation AND for "module not found"
    # would instead raise below; distinguish the two by probing importability.
    try:
        import reuse  # noqa: F401
    except ModuleNotFoundError:
        print(
            "check-reuse: the 'reuse' tool is not installed -- skipping.\n"
            "  Install it to run this gate:  pip install reuse\n"
            "  (This is optional local tooling; it is intentionally not part\n"
            "  of the pip-free CI aggregate. See this script's docstring.)",
            file=sys.stderr,
        )
        return 0

    print(
        "check-reuse: 'reuse lint' reported a violation (see its output above).\n"
        "  Fix it by annotating the offending file(s) in REUSE.toml or adding\n"
        "  the missing license text under LICENSES/. See REUSE.toml's header.",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
