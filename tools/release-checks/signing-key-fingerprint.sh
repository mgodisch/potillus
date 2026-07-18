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
#  release-checks/signing-key-fingerprint.sh -- sourced by tools/release-check.sh (see lib.sh).
# =============================================================================


# =============================================================================
# SECTION 14 – SIGNING-KEY FINGERPRINT (SECURITY.md ↔ release tooling)
# =============================================================================
# WHY THIS MATTERS:
#   The publishing targets `push-playstore` and `push-codeberg` pin the release
#   signer to the SHA-256 fingerprint recorded in SECURITY.md ("Verifying
#   releases"), extracting it with `grep -oiE '\b[0-9a-f]{64}\b' | head -1`. That
#   extraction is only well-defined when SECURITY.md carries EXACTLY ONE such
#   64-character lowercase-hex token in canonical form. If a future edit drops
#   it, adds a second one, or reformats it (spaces, colons, uppercase), the pin
#   would silently read the wrong value — or nothing — and that would surface
#   only at push time. This check moves the failure forward to build time.
#
#   The fingerprint is deliberately NOT duplicated into the Makefile: SECURITY.md
#   is the single source that also publishes it to users, so the pin and the
#   document cannot drift. This section guards the one invariant that coupling
#   relies on.
# =============================================================================
check_signing_key_fingerprint() {
    section "14 / 15 — SIGNING-KEY FINGERPRINT"

    local security="../SECURITY.md"
    if [[ ! -f "$security" ]]; then
        info "SECURITY.md not found ($security) — fingerprint check skipped"
        pass "Signing-key fingerprint check is gated on SECURITY.md being present"
        return
    fi

    # Canonical form the release tooling greps for: a bare 64-char lowercase-hex
    # token (SHA-256 of the DER signing certificate). Count them; the pin needs
    # exactly one. The `|| true` guards the pipeline under `set -euo pipefail`
    # (grep exits non-zero when there is no match, which is a legitimate count 0).
    local count lower_count
    count=$(grep -oiE '\b[0-9a-f]{64}\b' "$security" | grep -c . || true)
    # Lowercase is part of the canonical form, not just a style choice: the
    # Makefile pin now normalizes (v0.81.0 QA fix), but downstream consumers of
    # the published document (users copying the value into `apksigner verify
    # --print-certs` comparisons) get the exact bytes printed here, and apksigner
    # itself reports lowercase. An uppercase token — e.g. pasted from keytool
    # with only the colons stripped — is therefore a reformat this gate must
    # catch, exactly per its charter ("caught at build time instead of at push
    # time"). Counted separately so the failure message can name the problem.
    lower_count=$(grep -oE '\b[0-9a-f]{64}\b' "$security" | grep -c . || true)

    if [[ "$count" -eq 1 && "$lower_count" -eq 1 ]]; then
        pass "SECURITY.md carries exactly one canonical signing-key fingerprint"
    elif [[ "$count" -eq 1 ]]; then
        fail "SECURITY.md's signing-key fingerprint is not lowercase — canonicalize it (tr 'A-F' 'a-f'); apksigner prints lowercase and users compare byte-for-byte"
    elif [[ "$count" -eq 0 ]]; then
        fail "SECURITY.md has no 64-hex signing-key fingerprint — push-playstore/push-codeberg cannot pin the signer (see the 'Verifying releases' section)"
    else
        fail "SECURITY.md has $count 64-hex tokens; the release tooling's 'head -1' pin is ambiguous — keep exactly one canonical signing-key fingerprint"
    fi
}
