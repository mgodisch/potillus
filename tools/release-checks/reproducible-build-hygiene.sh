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
#  release-checks/reproducible-build-hygiene.sh -- sourced by tools/release-check.sh (see lib.sh).
# =============================================================================


# =============================================================================
# SECTION 11: REPRODUCIBLE-BUILD HYGIENE
# =============================================================================
# WHY THIS MATTERS:
#   The CycloneDX SBOM must NOT be packaged inside the release APK. Its metadata
#   captures the build ENVIRONMENT (a wall-clock timestamp, the CI job URL, and
#   the VCS remote URL as ssh:// vs https://), none of which can match between
#   the developer's machine and F-Droid's CI. Embedding it therefore breaks the
#   byte-for-byte reproducible-build comparison (it did, for 0.77.3). The SBOM
#   still ships as a standalone file via `cyclonedxDirectBom` / `make sbom` and
#   can be published alongside the APK. This check guards against a regression
#   that re-adds the in-APK SBOM task.
# =============================================================================
check_reproducible_build_hygiene() {
    section "11 / 15 — REPRODUCIBLE-BUILD HYGIENE"

    # The in-APK SBOM was wired via a `GenerateSbomAsset` task; its absence is
    # the signal that the SBOM stays out of the APK. (cyclonedxDirectBom, the
    # standalone generator, is fine and intentionally NOT matched here.)
    if grep -q "GenerateSbomAsset" "$BUILD_GRADLE"; then
        fail "$BUILD_GRADLE embeds the SBOM in the APK (GenerateSbomAsset) — this breaks reproducible builds; keep the SBOM standalone (cyclonedxDirectBom / make sbom)"
    else
        pass "SBOM is not embedded in the APK (reproducible-build safe)"
    fi
}
