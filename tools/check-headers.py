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
check-headers.py -- verifies that every file the project owns carries the
canonical license header, and can repair the ones that do not.

WHY THIS EXISTS
    The header is two things at once: the GPL-3.0 notice, and -- since the
    App Store distribution exception was added -- a generic pointer to the
    additional permissions granted under section 7 (see COPYING.md).  Both
    must appear on every source file the project owns, in every comment
    style, so a reader who extracts a single file still sees them.

    release-check.sh SECTION 5a already asserts that every Kotlin file has a
    GPL notice.  That is narrower than what is needed once a second platform
    (ios/) and a second permission (the exception) exist: the pointer must be
    present too, and it must be present in Swift, YAML, shell and Markdown
    files as well.  Keeping that in a dedicated tool means a new file added on
    any branch cannot quietly miss it, which matters most when merging a
    long-running branch back into a tree that has grown new files meanwhile.

WHAT IT CHECKS
    1. ERROR -- a file carries the GPL notice but NOT the section 7 pointer.
       This is a stale header, most often a file created before the exception
       existed, or copied from an older template.

    2. WARNING -- a file has an extension the project normally licenses, but
       carries no header at all.  Reported separately because the fix is a
       judgement call: some files (generated output, third-party verbatim
       text, strict JSON that cannot hold a comment) legitimately have none.

    Files that are verbatim third-party texts, binary assets, or strict JSON
    are skipped entirely; see EXCLUDED_PATHS and SKIP_SUFFIXES.

WHICH FILES ARE CONSIDERED
    Only files GIT TRACKS.  "The project owns it" and "the repository tracks it"
    are the same statement, and .gitignore is where that is already written down:
    vendored gems under fastlane/.vendor/, a developer's local
    android/keystore.properties, scratch output -- none of these are ours to
    annotate, and walking the file system finds all of them.  The list comes from
    `git ls-files`, so the two can never disagree.

    Outside a git checkout (an exported tarball, say) the tool falls back to
    walking the tree, skipping dot-directories and the paths in SKIP_DIRS.  That
    is a best effort, and it is why the git list is preferred.

WHAT --fix DOES
    Repairs case 1 only: it inserts the pointer paragraph directly after the
    "If not, see <...>" line of an existing header, reusing that line's own
    comment leader, so the result is correct in every comment style.  It never
    invents a whole header for a file that has none (case 2), because guessing
    the right comment syntax and copyright line for an unknown file type is
    exactly the sort of thing a human should decide.

USAGE
    tools/check-headers.py [--fix] [PATH ...]

    With no PATH, walks the repository root (the parent of tools/).
    Exit status: 0 = clean, 1 = problems found (warnings alone do not fail).
"""

import os
import subprocess
import sys
from potillus_repo import repo_root

# The anchor: the last line of the standard GPL notice.  The pointer is
# inserted directly after it.
ANCHOR = "If not, see <https://www.gnu.org/licenses/>"

# Presence of this substring means the pointer is already there.
POINTER_GUARD = "any such permissions that"

# The pointer paragraph, wrapped to match the surrounding header.
POINTER = (
    "In addition, as permitted by section 7 of the GNU General Public License,",
    "this program may carry additional permissions; any such permissions that",
    "apply to it are stated in the accompanying COPYING.md file.",
)

# A file carrying this is considered to have a license header at all.
GPL_MARK = "GNU General Public License"

# Verbatim third-party texts and the file that *contains* the exception:
# adding a self-referential pointer to COPYING.md would be circular.
EXCLUDED_PATHS = {
    "COPYING.md",
    "LICENSE.md",
    "docs/LICENSE.GPL-2.0.md",
    "docs/NOTICES.md",
    "docs/CODE_OF_CONDUCT.md",
}

# Strict JSON cannot hold a comment; binaries and generated artefacts are not
# ours to annotate.
SKIP_SUFFIXES = (
    ".json", ".png", ".jpg", ".jpeg", ".webp", ".gif", ".svg", ".ico",
    ".ttf", ".otf", ".woff", ".woff2", ".jar", ".keystore", ".apk", ".aab",
    ".zip", ".gz", ".pdf",
)

# Directories that never contain project-owned sources.
SKIP_DIRS = {
    ".git", "build", ".gradle", "node_modules", "DerivedData", ".build",
    "fonts", "fonts-src", "metadata", "raw", "Resources",
    "LICENSES",  # the REUSE license store -- canonical SPDX texts, not our sources
}

# Generated or third-party files that live in the tree but are not ours to
# annotate.  The in-app guides are rendered from the .md.in templates (which DO
# carry the header) and are git-ignored; render-guide.py strips the header on
# purpose, so the rendered copies must not be flagged.
SKIP_BASENAMES = {
    "usersguide.md",          # generated by render-guide.py into res/raw-<locale>/
    "gradle-wrapper.properties",  # Gradle's own file
}

# Files that carry no header by deliberate convention.
SKIP_RELATIVE = {
    "fastlane/README.md",     # regenerated by fastlane
    "fdroid/de.godisch.potillus.yml",  # F-Droid metadata, upstream schema
    "fastlane/metadata/android/screenshots.html",  # written by fastlane screengrab
}

# Extensions the project normally licenses.  Used only for the WARNING pass.
SOURCE_SUFFIXES = (
    ".kt", ".kts", ".swift", ".java", ".py", ".sh", ".md", ".xml", ".yml",
    ".yaml", ".toml", ".properties", ".pro", ".html", ".in", ".mk",
)

# Extensionless source files the project licenses, matched by basename since
# they carry no suffix for SOURCE_SUFFIXES to catch.  The Makefile rebuild split
# the build across a root Makefile, per-platform Makefiles and make/*.mk
# fragments (the .mk ones are covered above); every one carries the header, so
# the warning pass must see them too.
SOURCE_BASENAMES = (
    "Makefile",
)


def git_tracked_files(root):
    """
    Every file git tracks, as absolute paths, or None outside a checkout.

    `git ls-files` lists exactly the tracked files, so .gitignore is honoured
    without this tool having to reimplement its matching rules.
    """
    try:
        result = subprocess.run(
            ["git", "-C", root, "ls-files", "-z"],
            capture_output=True, check=True,
        )
    except (OSError, subprocess.CalledProcessError):
        return None
    names = result.stdout.decode("utf-8").split("\0")
    return [os.path.join(root, name) for name in names if name]


def walked_files(paths):
    """Fallback for a tree that is not a git checkout."""
    for path in paths:
        if os.path.isfile(path):
            yield path
            continue
        for root, dirs, files in os.walk(path):
            # Dot-directories (.vendor, .github, .gradle) are never ours.
            dirs[:] = [
                d for d in dirs if d not in SKIP_DIRS and not d.startswith(".")
            ]
            for name in sorted(files):
                yield os.path.join(root, name)


def iter_files(paths, root):
    """
    Yields every candidate file: the tracked ones under `paths`, or, outside a
    checkout, whatever walking finds there.
    """
    tracked = git_tracked_files(root)
    if tracked is None:
        yield from walked_files(paths)
        return

    wanted = [os.path.abspath(path) for path in paths]
    for path in tracked:
        absolute = os.path.abspath(path)
        if any(absolute == w or absolute.startswith(w + os.sep) for w in wanted):
            yield path


def is_skipped(path, root):
    """True when the file is deliberately outside the header convention."""
    relative = os.path.relpath(path, root)
    if relative in EXCLUDED_PATHS or relative in SKIP_RELATIVE:
        return True
    # The REUSE license store holds canonical third-party SPDX texts, never our
    # sources. git_tracked_files() bypasses SKIP_DIRS (that guards only the
    # non-git walk), so exclude the whole directory here, by path prefix -- else
    # LICENSES/GPL-3.0-or-later.txt trips the "GPL notice without §7 pointer" rule.
    if relative == "LICENSES" or relative.startswith("LICENSES" + os.sep):
        return True
    if os.path.basename(path) in SKIP_BASENAMES:
        return True
    return path.endswith(SKIP_SUFFIXES)


def read_text(path):
    """Returns the file's text, or None when it is not UTF-8 (i.e. binary)."""
    try:
        with open(path, encoding="utf-8") as handle:
            return handle.read()
    except (UnicodeDecodeError, OSError):
        return None


def insert_pointer(text):
    """
    Returns the text with the pointer inserted after the anchor line.

    The anchor line's own prefix -- everything before "this program" -- is the
    comment leader (" * ", "// ", "# ", or "" inside an HTML comment).  Reusing
    it verbatim is what makes one routine correct for every comment style.

    A blank separator line is added only when the anchor is not already followed
    by one, so repairing a header that lost only its pointer paragraph does not
    leave a doubled blank line behind.
    """
    lines = text.split("\n")
    index = next(i for i, line in enumerate(lines) if ANCHOR in line)
    anchor_line = lines[index]
    cut = anchor_line.find("this program")
    leader = anchor_line[:cut] if cut != -1 else ""

    separator = leader.rstrip()
    follows_blank = (
        index + 1 < len(lines) and lines[index + 1].rstrip() == separator
    )
    block = ([] if follows_blank else [separator]) + [leader + line for line in POINTER]

    # Insert after the anchor, and after its blank separator when one exists.
    at = index + 2 if follows_blank else index + 1
    lines[at:at] = block
    return "\n".join(lines)


def check_file(path, root, fix):
    """
    Classifies one file.

    Returns (errors, warnings, repaired) where errors/warnings are message
    strings and repaired is True when --fix rewrote the file.
    """
    if is_skipped(path, root):
        return [], [], False

    text = read_text(path)
    if text is None:
        return [], [], False

    relative = os.path.relpath(path, root)
    has_gpl = GPL_MARK in text
    has_anchor = ANCHOR in text
    has_pointer = POINTER_GUARD in text

    if has_anchor and not has_pointer:
        if fix:
            with open(path, "w", encoding="utf-8") as handle:
                handle.write(insert_pointer(text))
            return [], [], True
        return [f"{relative}: header lacks the section 7 pointer"], [], False

    if not has_gpl and (
        path.endswith(SOURCE_SUFFIXES)
        or os.path.basename(path) in SOURCE_BASENAMES
    ):
        return [], [f"{relative}: no license header"], False

    return [], [], False


def main(argv):
    fix = "--fix" in argv
    paths = [a for a in argv if a != "--fix"] or [str(repo_root())]
    root = str(repo_root())

    errors, warnings, repaired = [], [], 0
    for path in iter_files(paths, root):
        file_errors, file_warnings, was_repaired = check_file(path, root, fix)
        errors.extend(file_errors)
        warnings.extend(file_warnings)
        repaired += was_repaired

    for message in sorted(warnings):
        print(f"check-headers: warning: {message}")
    for message in sorted(errors):
        print(f"check-headers: {message}")

    if repaired:
        print(f"check-headers: repaired {repaired} file(s)", file=sys.stderr)
    if errors:
        print(
            f"check-headers: {len(errors)} file(s) missing the section 7 "
            "pointer; re-run with --fix",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
