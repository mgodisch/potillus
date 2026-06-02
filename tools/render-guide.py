#!/usr/bin/env python3
# vim: set et ts=4 sw=4:
# =============================================================================
# Libellus Potionis "Potillus" -- Privacy-Friendly Alcohol Tracker
# Copyright (c) 2026 Martin A. Godisch <android@godisch.de>
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
# =============================================================================
"""
render-guide.py -- build-time renderer for the localized user guides.

WHAT IT DOES
------------
The user guides live as *templates* under ``docs/guide/usersguide.<lang>.md.in``.
The prose in each template is already translated, but every on-screen name
(screen titles, settings-section headers) is written as a ``{{key}}`` token
instead of a hard-coded word. This script resolves those tokens from the
*matching* ``strings.xml`` of the app so the guides can never drift away from
the labels the app actually shows.

For every language it produces:

  * ``app/src/main/res/<raw_dir>/usersguide.md`` -- the in-app copy, with the
    license-comment header stripped (so a Markdown viewer shows clean text).
    Android resolves the locale-qualified ``raw``/``raw-xx`` directory the same
    way it resolves ``values``/``values-xx``, so the running app picks the
    guide for the active (per-app) language automatically.
  * the repository copy at the project root (``USERSGUIDE.md`` /
    ``USERSGUIDE-de.md``) -- only for English and German, and *with* the header
    kept, because those two are the human-maintained GitHub-facing documents.

WHY A SEPARATE STEP (NOT GRADLE ``expand``)
-------------------------------------------
Gradle's resource pipeline does not read values from ``strings.xml`` for us,
and Markdown files are not processed by the Android toolchain at all. A small,
self-contained generator invoked from the Makefile keeps the docs independent
of the heavy Android build and makes the substitution logic explicit and
testable.

TOKEN RESOLUTION & ANDROID ESCAPING
-----------------------------------
String values in ``strings.xml`` carry Android's own escaping on top of XML:
an apostrophe is stored as ``\\'`` (e.g. French ``Aujourd\\'hui``), a quote as
``\\"``, and a literal backslash as ``\\\\``. The XML parser resolves entities
such as ``&amp;`` for us, but the Android-level backslash escapes must be undone
here -- otherwise a stray backslash would leak into the rendered guide.

USAGE
-----
    python3 tools/render-guide.py            # write/refresh all outputs
    python3 tools/render-guide.py --check     # verify outputs are up to date
                                              # (exit 1 if anything would change)
"""

import os
import re
import sys
import xml.etree.ElementTree as ET

# Repository root = parent of the directory holding this script (tools/).
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES  = os.path.join(ROOT, "app", "src", "main", "res")
TPL  = os.path.join(ROOT, "docs", "guide")

# (language tag, values dir, raw dir, repository-root output or None)
#
# English is the resource *default*, so it lives in the unqualified `values`
# and `raw` directories. The remaining entries are the curated core set for
# which a real, human-quality translation exists; every other supported
# language deliberately has no `raw-xx`, so the app falls back to the English
# guide via Android's normal resource resolution.
LANGS = [
    ("en",    "values",        "raw",        "USERSGUIDE.md"),
    ("de",    "values-de",     "raw-de",     "USERSGUIDE-de.md"),
    ("fr",    "values-fr",     "raw-fr",     None),
    ("es",    "values-es",     "raw-es",     None),
    ("it",    "values-it",     "raw-it",     None),
    ("nl",    "values-nl",     "raw-nl",     None),
    ("pt",    "values-pt",     "raw-pt",     None),
    ("pt-BR", "values-pt-rBR", "raw-pt-rBR", None),
    ("ru",    "values-ru",     "raw-ru",     None),
    ("pl",    "values-pl",     "raw-pl",     None),
    ("sv",    "values-sv",     "raw-sv",     None),
    ("da",    "values-da",     "raw-da",     None),
    ("nb",    "values-nb",     "raw-nb",     None),
    ("cs",    "values-cs",     "raw-cs",     None),
]

TOKEN_RE = re.compile(r"\{\{([a-z0-9_]+)\}\}")


def unescape_android(value: str) -> str:
    """Undo Android string escaping that survives XML parsing.

    Handles ``\\n`` / ``\\t`` and the literal escapes ``\\'``, ``\\"`` and
    ``\\\\``. Also strips the optional surrounding double quotes Android uses to
    preserve leading/trailing whitespace (not expected for screen names, handled
    defensively).
    """
    if len(value) >= 2 and value[0] == '"' and value[-1] == '"':
        value = value[1:-1]
    return re.sub(
        r"\\(.)",
        lambda m: {"n": "\n", "t": "\t"}.get(m.group(1), m.group(1)),
        value,
    )


def load_strings(values_dir: str) -> dict:
    """Return {name: unescaped text} for one ``strings.xml``."""
    path = os.path.join(RES, values_dir, "strings.xml")
    root = ET.parse(path).getroot()
    out = {}
    for el in root.findall("string"):
        name = el.get("name")
        out[name] = unescape_android(el.text or "")
    return out


def strip_header(text: str) -> str:
    """Remove the leading ``<!-- ... -->`` license block and blank lines."""
    if text.lstrip().startswith("<!--"):
        end = text.find("-->")
        if end != -1:
            text = text[end + len("-->"):]
    return text.lstrip("\n")


def banner_after_header(text: str, lang: str) -> str:
    """Insert a 'generated file' banner right after the license header.

    Used only for the repository-root copies so a maintainer who opens
    ``USERSGUIDE.md`` is told to edit the template instead. The in-app ``raw``
    copies are left banner-free for the cleanest possible on-device rendering.
    """
    note = (
        f"<!-- GENERATED FILE -- do not edit. "
        f"Source: docs/guide/usersguide.{lang}.md.in (run `make guides`). -->"
    )
    end = text.find("-->")
    if text.lstrip().startswith("<!--") and end != -1:
        head, tail = text[: end + 3], text[end + 3:]
        return f"{head}\n\n{note}{tail}"
    return f"{note}\n\n{text}"


def render(template_text: str, strings: dict, lang: str) -> str:
    """Replace every ``{{key}}`` with the matching, unescaped string value."""
    def repl(m):
        key = m.group(1)
        if key not in strings:
            sys.exit(
                f"render-guide: [{lang}] unknown string key '{{{{{key}}}}}'. "
                f"Add <string name=\"{key}\"> to the locale or fix the template."
            )
        return strings[key]

    return TOKEN_RE.sub(repl, template_text)


def write_if_changed(path: str, content: str, check_only: bool) -> bool:
    """Write *content* to *path* unless unchanged. Returns True if it differed.

    In ``check_only`` mode nothing is written; the return value just reports
    whether the file is stale.
    """
    existing = None
    if os.path.exists(path):
        with open(path, encoding="utf-8") as fh:
            existing = fh.read()
    if existing == content:
        return False
    if not check_only:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(content)
    return True


def main() -> int:
    check_only = "--check" in sys.argv[1:]
    stale = []

    for lang, values_dir, raw_dir, root_out in LANGS:
        tpl_path = os.path.join(TPL, f"usersguide.{lang}.md.in")
        if not os.path.exists(tpl_path):
            sys.exit(f"render-guide: missing template {tpl_path}")
        with open(tpl_path, encoding="utf-8") as fh:
            template_text = fh.read()

        strings = load_strings(values_dir)
        rendered = render(template_text, strings, lang)

        # In-app copy: header stripped, under res/<raw_dir>/usersguide.md
        raw_path = os.path.join(RES, raw_dir, "usersguide.md")
        if write_if_changed(raw_path, strip_header(rendered), check_only):
            stale.append(os.path.relpath(raw_path, ROOT))

        # Repository copy (English + German only): header kept + generated banner.
        if root_out:
            root_path = os.path.join(ROOT, root_out)
            if write_if_changed(root_path, banner_after_header(rendered, lang), check_only):
                stale.append(root_out)

    if check_only:
        if stale:
            sys.stderr.write(
                "render-guide: the following generated guides are out of date:\n"
                + "".join(f"  {p}\n" for p in stale)
                + "Run `make guides` and commit the result.\n"
            )
            return 1
        print("render-guide: all guides up to date.")
        return 0

    if stale:
        print(f"render-guide: wrote {len(stale)} file(s):")
        for p in stale:
            print(f"  {p}")
    else:
        print("render-guide: nothing to do (all guides already current).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
