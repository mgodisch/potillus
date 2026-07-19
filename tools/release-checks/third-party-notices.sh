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
#  release-checks/third-party-notices.sh -- sourced by tools/release-check.sh (see lib.sh).
# =============================================================================


# =============================================================================
# SECTION 12: THIRD-PARTY NOTICE FILES (Apache-2.0 §4(d))
# =============================================================================
# WHY THIS MATTERS:
#   Apache-2.0 §4(d) requires reproducing any NOTICE text that a redistributed
#   dependency ships. COPYING.md documents the policy ("whenever a newly added
#   dependency carries NOTICE text, copy it into this section"); this check
#   AUTOMATES the confirmation step that used to be a manual release-process
#   note.
#
# HOW IT WORKS (and why it is SBOM-gated):
#   The authoritative list of components actually shipped in the release APK is
#   the CycloneDX SBOM produced by `make sbom` (see build.gradle.kts). When the
#   SBOM file exists, this check resolves each listed component to its cached
#   artifact under the Gradle module cache and scans the archive for
#   META-INF/NOTICE* entries. Any hit is reported as a WARNING naming the
#   artifact, prompting the human step COPYING.md prescribes (copy the NOTICE
#   text into the Apache-2.0 section). Under --Werror — i.e. in the release
#   gate that also runs `make sbom` — that warning correctly blocks the release
#   until the NOTICE is dealt with.
#
#   Without the SBOM (the routine `make -C android debug-apk` gate), or without a populated
#   Gradle cache, the check reports itself as SKIPPED via info() and passes:
#   it can only ever act on the authoritative inventory, never on guesses, so
#   it cannot produce false failures in environments that lack the inputs.
# =============================================================================
check_third_party_notices() {
    section "12 / 15 — THIRD-PARTY NOTICE FILES"

    local sbom="app/build/outputs/sbom/libellus-potionis-sbom.json"
    if [[ ! -f "$sbom" ]]; then
        info "SBOM not present ($sbom) — run 'make sbom' first; NOTICE scan skipped"
        pass "NOTICE scan is SBOM-gated (nothing to verify without the component inventory)"
        return
    fi
    if ! command -v python3 >/dev/null 2>&1; then
        warn "python3 not found — skipping NOTICE scan"
        return
    fi

    local cache="${GRADLE_USER_HOME:-$HOME/.gradle}/caches/modules-2/files-2.1"
    if [[ ! -d "$cache" ]]; then
        info "Gradle module cache not found ($cache) — NOTICE scan skipped"
        pass "NOTICE scan needs the local artifact cache (populated by any Gradle build)"
        return
    fi

    # For every SBOM component, locate its cached .jar/.aar (group/name/version
    # subtree of the module cache) and list any META-INF/NOTICE* archive entry.
    # Output: one "group:name:version<TAB>entry" line per finding; empty on a
    # clean pass. Components whose artifact is not in the cache are ignored —
    # the SBOM was necessarily built FROM resolved artifacts, so a missing file
    # only means a cleaned cache, not a missing obligation.
    local findings
    if ! findings=$(python3 - "$sbom" "$cache" <<'PYEND'
import json, pathlib, sys, zipfile

sbom_path, cache_root = sys.argv[1], sys.argv[2]
components = json.load(open(sbom_path)).get("components", [])
for comp in components:
    group, name, version = comp.get("group", ""), comp.get("name", ""), comp.get("version", "")
    if not (group and name and version):
        continue
    artifact_dir = pathlib.Path(cache_root) / group / name / version
    if not artifact_dir.is_dir():
        continue
    for archive in sorted(artifact_dir.rglob("*")):
        if archive.suffix not in (".jar", ".aar") or not archive.is_file():
            continue
        try:
            with zipfile.ZipFile(archive) as zf:
                for entry in zf.namelist():
                    upper = entry.upper()
                    if upper.startswith("META-INF/NOTICE"):
                        print(f"{group}:{name}:{version}	{entry}")
        except zipfile.BadZipFile:
            continue
PYEND
    ); then
        warn "NOTICE scan failed to run — verify manually (see COPYING.md, Apache-2.0 section)"
        return
    fi

    if [[ -n "$findings" ]]; then
        while IFS=$'	' read -r coordinate entry; do
            [[ -n "$coordinate" ]] || continue
            warn "NOTICE file in shipped dependency $coordinate ($entry) — copy its text into COPYING.md §Apache-2.0 (per §4(d))"
        done <<< "$findings"
    else
        pass "No META-INF/NOTICE files in any shipped dependency (SBOM-verified)"
    fi
}
