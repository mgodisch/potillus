# vim: set noet ts=4 sw=4:
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
#  Makefile -- Libellus Potionis build tooling (repository root)
# =============================================================================
#
#  This is the ROOT orchestrator. It owns repository-wide concerns and delegates
#  each platform's build to that platform's own Makefile:
#
#      make -C android <target>     the Android build (Gradle)
#      make -C ios     <target>     the iOS build (XcodeGen / xcodebuild)
#
#  The tooling is being rebuilt one target group at a time. THIS revision defines
#  the HOUSEKEEPING targets only; the other groups (build, test, store assets,
#  publishing, checks) are added in later steps. The previous, monolithic Makefile
#  is preserved verbatim under attic/ as a reference while the rebuild proceeds.
#
#  TARGETS IN THIS REVISION
#    help               (default) print this list and do nothing else
#    clean              build OUTPUT of BOTH platforms (fans out)
#    distclean          clean + generated sources of BOTH platforms (fans out)
#    clean-android      Android build output only
#    distclean-android  Android build output + generated sources
#    clean-ios          iOS build output only
#    distclean-ios      iOS build output + generated sources
# =============================================================================

# =============================================================================
# CONFIGURATION
# =============================================================================

# GNU Make version guard -- see make/guard.mk. Included FIRST so a Make that is
# too old to honor the .ONESHELL/.SHELLFLAGS settings below aborts with a legible
# message before any of them (silently ignored on such a Make) can take effect.
include make/guard.mk

# Run each recipe in ONE bash process with strict error handling. The same three
# lines head all three Makefiles so a recipe behaves identically wherever it runs:
#   .ONESHELL       -- the whole recipe is a single shell invocation, so
#                      `set -euo pipefail` (below) governs every line of it.
#   .SHELLFLAGS -eu -o pipefail -c
#                   -- -e aborts on the first failing command, -u on an unset
#                      variable, -o pipefail on any failure inside a pipeline.
SHELL       := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.ONESHELL:

# A bare `make` in a two-platform repository must not silently build one of them,
# so the default goal only prints the target list and changes nothing.
.DEFAULT_GOAL := help

help:
	@echo "Libellus Potionis -- repository build tooling"
	@echo
	@echo "Housekeeping:"
	@echo "  make clean              clear both platforms' build output"
	@echo "  make distclean          clear build output + generated sources (fresh-clone state)"
	@echo "  make clean-android      Android build output only"
	@echo "  make distclean-android  Android build output + generated sources"
	@echo "  make clean-ios          iOS build output only"
	@echo "  make distclean-ios      iOS build output + generated sources"
	@echo
	@echo "Store assets (Android):"
	@echo "  make screenshots-android      capture the in-app shots 01..06  [device]"
	@echo "  make report-pdfs-android      export the per-locale report PDFs  [device + manual Save-as-PDF]"
	@echo "  make screenshots-pdf-android  rasterize report pages 07/08 from the PDFs  [no device]"
	@echo "  make feature-graphics-android render every locale's feature graphic  [no device]"
	@echo "  make store-assets-android     the whole set: screenshots + PDFs + feature graphics"
	@echo "Store assets (iOS):"
	@echo "  make screenshots-ios          capture 01..06 (+ report pages 07/08)  [Mac + Simulator]"
	@echo
	@echo "Checks (read-only, device-free, any host):"
	@echo "  make check-static     every static check in one go (headers, l10n, iOS static, ...)"
	@echo "  make check-ios-static the Mac-free iOS release gate"
	@echo "  make check-makefile   bare-cd check across all makefiles + fragments"
	@echo "  make fix-headers      rewrite missing/wrong license headers (the one writing check)"
	@echo
	@echo "Release (Android):"
	@echo "  make release-android  gate, build (AAB+APK+SBOM) and stage into releases/  [device artifacts required]"
	@echo "  make cover-check      enforce the code-coverage floor (Android Kover today)"
	@echo
	@echo "None of these touch releases/ -- staged release artifacts are removed by hand."

# =============================================================================
# HOUSEKEEPING
# =============================================================================
#
# The naming split follows the repository convention: each per-platform CHILD
# Makefile exposes a bare `clean`/`distclean` (it knows only its own platform),
# while the ROOT disambiguates with a -android/-ios suffix. The two verbs mean the
# same thing on both sides:
#   clean      -- build OUTPUT: regenerated by the next build, costs only time.
#   distclean  -- clean, plus the GENERATED SOURCES a build needs before it can
#                 start, i.e. back to a fresh-clone state.
#
# What NONE of them touch is releases/: those are staged, possibly already
# published artifacts. Clearing them is a deliberate act, never a side effect of
# housekeeping -- remove them by hand when you mean it.

# Aggregate: fan out to BOTH platforms. This is honest only now that iOS has a
# Makefile of its own: the previous root deliberately had no bare `clean`, because
# back then it would have cleaned Android and left the entire iOS tree standing --
# a name that promised twice what it delivered.
clean: clean-android clean-ios

distclean: distclean-android distclean-ios

clean-android:
	$(MAKE) -C android clean

distclean-android:
	$(MAKE) -C android distclean

clean-ios:
	$(MAKE) -C ios clean

distclean-ios:
	$(MAKE) -C ios distclean

.PHONY: help clean distclean clean-android distclean-android clean-ios distclean-ios

# =============================================================================
# STORE ASSETS
# =============================================================================
# Device/manual store-asset generation lives in its own fragment; see make/store.mk.
# Included here so `make report-pdfs-android` works from the repository root. As the
# store grows (Android screenshots 01..06, the iOS store assets) it stays in that
# fragment rather than swelling this file.
include make/store.mk

# =============================================================================
# CHECKS
# =============================================================================
# Static, device-free checks (headers, l10n, the Mac-free iOS gate, ...) live in
# their own fragment; see make/checks.mk. Included here so `make check-static` and
# the individual `check-*` targets work from the repository root.
include make/checks.mk

# =============================================================================
# RELEASE
# =============================================================================
# Release staging (gates, artifact build via the platform Makefiles, staging into
# releases/) lives in its own fragment; see make/release.mk. Included after store
# and checks because it reuses their locales/paths. `release-ios` and the
# release-check.sh decomposition are later revisions (see docs/ROADMAP.md).
include make/release.mk
