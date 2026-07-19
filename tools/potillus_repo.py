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
#
# potillus_repo.py -- the tools/ shared library (the Python counterpart of the
# shell tools' tools/release-checks/lib.sh).
#
# PURPOSE
#   Two facts about the repository were, until this module, copied into almost
#   every tool by hand:
#
#     * where the repository root is, relative to a tool -- fifteen tools each
#       carried their own one-line `repository_root()` (or a `ROOT = ...`
#       constant) in one of three interchangeable idioms; and
#     * how the marketing version is spelled in CHANGELOG.md -- the top
#       `## vX.Y.Z` entry, whose regex two tools (gen-ios-version.py and
#       check-ios-metadata.py) had each written out identically.
#
#   Both are single facts about the project, so they belong in one place where
#   a change (a new root layout, a version-string format change) is made once
#   rather than hunted across the tree. This module is that place; new shared
#   helpers land here as they are found.
#
# IMPORTING IT
#   A tool is run as `python3 tools/<name>.py` (directly or via a Makefile that
#   `cd`s elsewhere first, e.g. `python3 ../tools/<name>.py`). Python puts the
#   SCRIPT's own directory -- always tools/ -- on sys.path[0], never the current
#   working directory, so a plain `from potillus_repo import repo_root` resolves
#   regardless of where make invoked the tool from. No sys.path juggling needed.
#
# NOT FOR EVERY TOOL
#   render-guide.py is a deliberate NON-consumer: its `ROOT` points at android/,
#   not the repository root (it self-anchors one level deeper on purpose), so it
#   keeps its own constant. See the comment at its definition.
# =============================================================================

import re
from pathlib import Path

# The top `## vX.Y.Z` entry of CHANGELOG.md is the project's single
# human-readable version (release-check.sh SECTION 1 enforces that build.gradle
# versionName, README.md and ios/project.yml MARKETING_VERSION all agree with
# it). Anchored at the line start so only a heading matches, and capturing the
# three dotted numbers so a stray suffix cannot slip in.
CHANGELOG_VERSION_RE = re.compile(r"^## v(\d+\.\d+\.\d+)")


def repo_root():
    """The repository root: the directory above tools/, where this module lives.

    Returned as a ``pathlib.Path`` -- callers that build paths with ``root /
    "sub"`` use it directly, callers that use ``os.path.join(root, "sub")`` get
    the same result (os.path accepts a Path transparently), and callers that
    call ``.relative_to(root)`` need the Path form this provides.
    """
    return Path(__file__).resolve().parent.parent


def changelog_marketing_version(root=None):
    """The marketing version from the top ``## vX.Y.Z`` entry of CHANGELOG.md,
    e.g. ``"0.84.0"``, or ``None`` if no such heading is found.

    ``root`` defaults to :func:`repo_root`; pass one to avoid recomputing it.
    """
    if root is None:
        root = repo_root()
    changelog = Path(root) / "CHANGELOG.md"
    for line in changelog.read_text(encoding="utf-8").splitlines():
        match = CHANGELOG_VERSION_RE.match(line)
        if match:
            return match.group(1)
    return None
