#!/usr/bin/env python3
# vim: set et ts=4 sw=4:
# =============================================================================
# Libellus Potionis - Privacy-Friendly Alcohol Tracker
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
The user guides live as *templates* under ``docs/guide/``: a code-less default
``usersguide.md.in`` (English) and one ``usersguide.<tag>.md.in`` per translated
language. The prose in each template is already translated, but every on-screen
name (screen titles, settings-section headers) is written as a ``{{key}}`` token
instead of a hard-coded word. This script resolves those tokens from the
*matching* ``strings.xml`` so the guides can never drift from the labels the app
actually shows.

LANGUAGE DISCOVERY (no hard-coded list)
---------------------------------------
The set of languages is discovered automatically from the template files present
under ``docs/guide/``. The code-less ``usersguide.md.in`` is the default and
feeds the unqualified ``values`` / ``raw`` resource directories. Each
``usersguide.<tag>.md.in`` feeds ``values-<q>`` / ``raw-<q>``, where ``<q>`` is
the Android resource qualifier for the BCP-47 tag: a bare language is unchanged
(``de`` -> ``de``) and a region tag ``ll-RR`` becomes ``ll-rRR`` (``pt-BR`` ->
``pt-rBR``). Adding a new ``usersguide.xx.md.in`` (with a matching ``values-xx``)
is therefore picked up automatically -- no edit to this script needed.

LANGUAGE PARITY GUARD
---------------------
The two independent sources of truth for "which languages does Potillus ship"
are these guide templates and the ``values-<q>/strings.xml`` resource
directories. They MUST describe exactly the same set of languages (both
counting the unqualified base, ``values`` / ``usersguide.md.in``, as English
``en``); otherwise a language could have UI strings but no guide, or a guide
with no UI strings. Before rendering, :func:`check_language_parity` compares the
two sets and aborts the build with a precise diff if they diverge. This runs in
both write and ``--check`` mode, so neither a normal build nor CI can let the
sets drift apart. (The complementary :class:`LocaleSyncTest` guards the
strings ⇄ locale_config ⇄ SupportedLocales side on the JVM/CI path.)

OUTPUT & WHEN IT IS (RE)GENERATED
---------------------------------
For every language it writes ``app/src/main/res/<raw_dir>/usersguide.md`` -- the
in-app copy, with the license-comment header stripped so a Markdown viewer shows
clean text. Android resolves the locale-qualified ``raw``/``raw-xx`` directory
the same way it resolves ``values``/``values-xx``, so the running app picks the
guide for the active (per-app) language automatically.

In normal (write) mode an output is regenerated only when it is missing or older
than its inputs -- that is, when the template **or** the matching ``strings.xml``
has a newer modification time than the existing ``usersguide.md``. ``--check``
ignores timestamps and compares *content* (so CI fails whenever a committed guide
would differ, regardless of file mtimes).

TOKEN RESOLUTION & ANDROID ESCAPING
-----------------------------------
String values in ``strings.xml`` carry Android's own escaping on top of XML:
an apostrophe is stored as ``\\'``, a quote as ``\\"``, and a literal backslash
as ``\\\\``. The XML parser resolves entities such as ``&amp;`` for us, but the
Android-level backslash escapes must be undone here.

USAGE
-----
    python3 tools/render-guide.py            # write/refresh outputs whose
                                             # template or strings.xml changed
    python3 tools/render-guide.py --check    # verify outputs are up to date
                                             # (exit 1 if anything would change)
"""

import glob
import os
import re
import sys
import xml.etree.ElementTree as ET

# Repository root = parent of the directory holding this script (tools/).
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES  = os.path.join(ROOT, "app", "src", "main", "res")
TPL  = os.path.join(ROOT, "docs", "guide")

TOKEN_RE = re.compile(r"\{\{([a-z0-9_]+)\}\}")


def android_qualifier(tag: str) -> str:
    """Map a BCP-47-ish language tag to its Android resource qualifier.

    A bare language ("de", "el") is returned unchanged; a language+region tag
    ("pt-BR") becomes the Android form with the region marked by ``r``
    ("pt-rBR"). This mirrors how ``values-xx`` / ``raw-xx`` directories are named.
    """
    parts = tag.split("-")
    if len(parts) == 2:
        return f"{parts[0]}-r{parts[1]}"
    return tag


def discover_languages():
    """Discover guide templates and derive their resource directories.

    Returns a list of ``(label, template_path, values_dir, raw_dir)`` sorted by
    file name. The code-less ``usersguide.md.in`` yields the unqualified
    ``values`` / ``raw`` directories (the English default); ``label`` is a human
    string used only in messages.
    """
    langs = []
    for path in sorted(glob.glob(os.path.join(TPL, "usersguide*.md.in"))):
        name = os.path.basename(path)
        # Strip the fixed prefix/suffix; what remains is ".<tag>" or "".
        middle = name[len("usersguide"):-len(".md.in")]
        tag = middle[1:] if middle.startswith(".") else ""
        if tag:
            q = android_qualifier(tag)
            values_dir, raw_dir, label = f"values-{q}", f"raw-{q}", tag
        else:
            values_dir, raw_dir, label = "values", "raw", "en (default)"
        langs.append((label, path, values_dir, raw_dir))
    return langs


# Inverse of android_qualifier(): an Android resource qualifier with a region
# ("pt-rBR", "zh-rCN") maps back to its BCP-47 tag ("pt-BR", "zh-CN"); a bare
# language qualifier ("de") is its own tag. Used by the parity guard so the
# string-resource side and the guide side are compared in the same notation.
QUALIFIER_REGION_RE = re.compile(r"^([a-z]{2,3})-r([A-Za-z0-9]+)$")


def bcp47_from_qualifier(qualifier: str) -> str:
    """Map an Android resource qualifier back to its BCP-47 tag."""
    m = QUALIFIER_REGION_RE.match(qualifier)
    return f"{m.group(1)}-{m.group(2)}" if m else qualifier


def strings_languages() -> set:
    """Set of BCP-47 tags that ship string resources.

    Every ``values-<q>/`` directory contributes one tag, EXCEPT the non-locale
    qualifiers ``values-night`` and API-level ``values-vNN``. The English base
    lives in the unqualified ``values/`` (there is deliberately no
    ``values-en/``), so ``"en"`` is added explicitly -- mirroring how the
    per-app language picker and :class:`LocaleSyncTest` treat the base locale.
    """
    tags = {"en"}
    for entry in os.listdir(RES):
        if not entry.startswith("values-"):
            continue
        if entry == "values-night" or re.fullmatch(r"values-v\d+", entry):
            continue
        tags.add(bcp47_from_qualifier(entry[len("values-"):]))
    return tags


def guide_languages(langs) -> set:
    """Set of BCP-47 tags that ship a guide template (base template -> ``en``)."""
    tags = set()
    for _label, _tpl, values_dir, _raw in langs:
        if values_dir == "values":
            tags.add("en")
        else:
            tags.add(bcp47_from_qualifier(values_dir[len("values-"):]))
    return tags


def check_language_parity(langs) -> None:
    """Abort the build when guide languages and string languages diverge.

    See the module docstring's "LANGUAGE PARITY GUARD" section. Both sets count
    the unqualified base as English (``en``). On any mismatch the build stops
    with a message naming exactly which side is missing which language, so the
    fix is unambiguous.
    """
    guides = guide_languages(langs)
    strings = strings_languages()
    if guides == strings:
        return
    lines = ["render-guide: guide languages and string languages are out of sync."]
    missing_guide = sorted(strings - guides)   # have strings.xml, lack a template
    missing_strings = sorted(guides - strings)  # have a template, lack strings.xml
    if missing_guide:
        lines.append(
            "  strings.xml present but NO guide template: "
            + ", ".join(missing_guide)
            + "\n    -> add docs/guide/usersguide.<tag>.md.in for each"
        )
    if missing_strings:
        lines.append(
            "  guide template present but NO strings.xml: "
            + ", ".join(missing_strings)
            + "\n    -> add the values-<qualifier>/strings.xml or remove the template"
        )
    sys.exit("\n".join(lines))


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


def render(template_text: str, strings: dict, label: str) -> str:
    """Replace every ``{{key}}`` with the matching, unescaped string value."""
    def repl(m):
        key = m.group(1)
        if key not in strings:
            sys.exit(
                f"render-guide: [{label}] unknown string key '{{{{{key}}}}}'. "
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

    langs = discover_languages()
    if not langs:
        sys.exit(f"render-guide: no usersguide*.md.in templates found under {TPL}")

    # Hard gate: the guide-template language set and the strings.xml language set
    # must be identical (see check_language_parity). Runs in both modes so a
    # normal build and CI both fail fast on any drift.
    check_language_parity(langs)

    stale = []
    skipped = 0
    for label, tpl_path, values_dir, raw_dir in langs:
        strings_path = os.path.join(RES, values_dir, "strings.xml")
        if not os.path.exists(strings_path):
            sys.exit(f"render-guide: [{label}] missing {strings_path}")
        out_path = os.path.join(RES, raw_dir, "usersguide.md")

        # Write mode: regenerate only when the output is missing or older than
        # its inputs (template OR strings.xml). --check ignores timestamps and
        # always compares content below.
        if not check_only and os.path.exists(out_path):
            newest_src = max(os.path.getmtime(tpl_path), os.path.getmtime(strings_path))
            if os.path.getmtime(out_path) >= newest_src:
                skipped += 1
                continue

        with open(tpl_path, encoding="utf-8") as fh:
            template_text = fh.read()
        strings = load_strings(values_dir)
        rendered = strip_header(render(template_text, strings, label))

        if write_if_changed(out_path, rendered, check_only):
            stale.append(os.path.relpath(out_path, ROOT))

    if check_only:
        if stale:
            sys.stderr.write(
                "render-guide: the following generated guides are out of date:\n"
                + "".join(f"  {p}\n" for p in stale)
                + "Run `make guides` and commit the result.\n"
            )
            return 1
        print(f"render-guide: all {len(langs)} guides up to date.")
        return 0

    if stale:
        print(f"render-guide: wrote {len(stale)} file(s):")
        for p in stale:
            print(f"  {p}")
    else:
        print(f"render-guide: nothing to do ({skipped} guides already current).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
