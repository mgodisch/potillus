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
check-dependency-verification.py -- keep the Gradle checksum file in step with
the version catalogue.

WHY
    android/gradle/verification-metadata.xml pins a SHA-256 for every artifact
    the build resolves, so a tampered or substituted dependency fails the build
    rather than reaching an APK. Gradle regenerates it only when asked
    (`./gradlew --write-verification-metadata sha256 …`), and it does not warn
    when the file has fallen behind: it simply fails the first build that needs
    an artifact the file does not list.

    That failure comes late and lands on whoever builds next -- which includes
    F-Droid, who build the published APK from this repository. Raising a version
    in libs.versions.toml without regenerating the file is the way this happens,
    and it is exactly the kind of omission a check can catch in a second.

WHAT IT CHECKS
    1. The file exists and its <configuration> still asks for metadata
       verification. A file that verifies nothing is worse than none: it looks
       like a control while enforcing nothing.
    2. Every library and plugin in the version catalogue appears in it at its
       CURRENT version. A plugin resolves through its marker artifact
       (`<id>:<id>.gradle.plugin`), so that is the coordinate looked up.

WHAT IT DOES NOT CHECK
    Completeness. The catalogue names the DIRECT dependencies; the file also
    carries transitive ones, whose set only Gradle knows. So this check catches
    the common omission (a version raised, the file left behind) and not the
    rarer one (a new transitive artifact pulled in by an unchanged direct
    dependency). Gradle itself is the backstop for that, and the release path
    runs the real build before an artifact is staged.

    KSP is the concrete example of what stays out of reach here: it resolves
    `symbol-processing-aa-embeddable` and its coroutines through a DETACHED
    configuration at task-execution time, so those artifacts belong to no
    configuration the catalogue names and no amount of reading the catalogue
    reveals them. They are also the ones a regeneration forgets most easily --
    which is why the regeneration command lives in one place, the
    `verification-metadata` target of android/Makefile, rather than in prose.

    Signatures are not checked either, here or by Gradle: `verify-signatures` is
    false, so integrity rests on the checksums rather than on publisher keys.
    That is a deliberate scope, documented in SECURITY.md.

WHY IT PARSES THE CATALOGUE ITSELF
    `tomllib` arrived in Python 3.11, and the Mac runs whatever Xcode ships --
    3.9 at the time of writing. check-vex.py may skip itself when the module is
    absent, because its own subject (an empty triage list) is advisory; a gate
    that silently skips on one of the two machines is not a gate. The catalogue
    uses three table shapes and nothing else, so they are read directly, and an
    entry this parser does not recognise is an ERROR rather than a silent miss.

USAGE
    tools/check-dependency-verification.py
    Exit status: 0 when the file covers every catalogue entry, 1 otherwise. Run
    from `make check-static` and, as a gate, from `make release-android`.
"""

import re
import sys
from potillus_repo import repo_root

ROOT = repo_root()
CATALOG = ROOT / "android" / "gradle" / "libs.versions.toml"
METADATA = ROOT / "android" / "gradle" / "verification-metadata.xml"

# One component element per artifact group/name/version. Attribute order is
# Gradle's own and stable across the versions that write this file.
_COMPONENT = re.compile(
    r'<component\s+group="([^"]+)"\s+name="([^"]+)"\s+version="([^"]+)"'
)


def parse_catalogue(text):
    """The [versions], [libraries] and [plugins] tables of a Gradle version
    catalogue, as {table: {key: value}}.

    Deliberately narrow. A value is either a quoted string or an inline table,
    and an inline table's members are `key = "value"` or the dotted
    `version.ref = "value"`. That is every form this catalogue uses; anything
    else raises, so a shape this parser cannot read stops the check instead of
    quietly passing it.
    """
    tables = {"versions": {}, "libraries": {}, "plugins": {}}
    current = None
    for number, raw in enumerate(text.splitlines(), 1):
        line = raw.split("#", 1)[0].strip() if not raw.lstrip().startswith("#") else ""
        if not line:
            continue
        table = re.fullmatch(r"\[(\w+)\]", line)
        if table:
            current = table.group(1)
            continue
        if current not in tables:
            continue
        entry = re.fullmatch(r'([\w.-]+)\s*=\s*(.+)', line)
        if not entry:
            raise ValueError(f"{CATALOG.name}:{number}: cannot read {line!r}")
        key, value = entry.group(1), entry.group(2).strip()
        tables[current][key] = parse_value(value, number)
    return tables


def parse_value(value, number):
    """A quoted string, or an inline table as a dict (`version.ref` nested)."""
    quoted = re.fullmatch(r'"([^"]*)"', value)
    if quoted:
        return quoted.group(1)
    if not (value.startswith("{") and value.endswith("}")):
        raise ValueError(f"{CATALOG.name}:{number}: cannot read {value!r}")
    result = {}
    for member in re.finditer(r'([\w.-]+)\s*=\s*"([^"]*)"', value[1:-1]):
        name, text = member.group(1), member.group(2)
        if "." in name:
            outer, inner = name.split(".", 1)
            result.setdefault(outer, {})[inner] = text
        else:
            result[name] = text
    if not result:
        raise ValueError(f"{CATALOG.name}:{number}: empty inline table {value!r}")
    return result


def resolve_version(spec, versions):
    """The concrete version string a catalogue entry names, or None.

    An entry spells its version as a plain string, as a {version.ref} pointing
    into [versions], or as a {require}/{strictly} constraint. A range or an
    absent version yields None and is skipped: there is no single coordinate to
    look up, and the catalogue does not use either form today.
    """
    if isinstance(spec, str):
        return spec
    if not isinstance(spec, dict):
        return None
    if "ref" in spec:
        return versions.get(spec["ref"])
    return spec.get("require") or spec.get("strictly")


def main():
    if not METADATA.exists():
        print(
            f"check-dependency-verification: {METADATA} is missing -- generate it with\n"
            "  make -C android verification-metadata",
            file=sys.stderr,
        )
        return 1

    xml = METADATA.read_text(encoding="utf-8")
    if not re.search(r"<verify-metadata>\s*true\s*</verify-metadata>", xml):
        print(
            "check-dependency-verification: <verify-metadata> is not true -- the "
            "file is present but verifies nothing",
            file=sys.stderr,
        )
        return 1

    try:
        catalog = parse_catalogue(CATALOG.read_text(encoding="utf-8"))
    except ValueError as error:
        print(f"check-dependency-verification: {error}", file=sys.stderr)
        return 1
    versions = catalog.get("versions", {})
    components = set(_COMPONENT.findall(xml))

    missing = []
    for key, lib in catalog.get("libraries", {}).items():
        version = resolve_version(lib.get("version"), versions)
        if version is None:
            continue
        coordinate = (lib["group"], lib["name"], version)
        if coordinate not in components:
            missing.append(f"library {key}: {':'.join(coordinate)}")

    for key, plugin in catalog.get("plugins", {}).items():
        version = resolve_version(plugin.get("version"), versions)
        if version is None:
            continue
        # A plugin id resolves through its marker artifact, whose group and name
        # are both derived from the id.
        marker = (plugin["id"], f"{plugin['id']}.gradle.plugin", version)
        if marker not in components:
            missing.append(f"plugin {key}: {':'.join(marker)}")

    if missing:
        print(
            f"check-dependency-verification: {len(missing)} catalogue entry(ies) "
            "have no checksum at their current version:",
            file=sys.stderr,
        )
        for line in sorted(missing):
            print(f"  {line}", file=sys.stderr)
        print(
            "\nRegenerate after every version bump:\n"
            "  make -C android verification-metadata",
            file=sys.stderr,
        )
        return 1

    entries = len(catalog.get("libraries", {})) + len(catalog.get("plugins", {}))
    print(
        f"check-dependency-verification: OK ({entries} catalogue entries covered, "
        f"{len(components)} components pinned)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
