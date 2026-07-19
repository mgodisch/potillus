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
#  Repository-wide concerns also live in the include fragments under make/ (guard,
#  store, checks, release, publish, bestpractices). Run `make help` for the full
#  target list: it is the single source of truth, so this header no longer
#  duplicates it.
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
	@echo "Daily (per platform, device-free):"
	@echo "  make android          build + JVM tests + lint + guides + l10n parity"
	@echo "  make ios              Mac-free checks + SwiftLint + Swift tests + build  [Mac]"
	@echo "  make device-tests-android  on-device instrumentation tests  [device]"
	@echo "  make install-debug    copy the debug APK to ../downloads/ (sideload; not adb)"
	@echo
	@echo "Checks (read-only, device-free, any host):"
	@echo "  make check-static     every static check in one go (headers, l10n, iOS static, ...)"
	@echo "  make check-ios-static the Mac-free iOS release gate"
	@echo "  make check-makefile   bare-cd check across all makefiles + fragments"
	@echo "  make fix-headers      rewrite missing/wrong license headers (the one writing check)"
	@echo "  make release-check    run the full invariant gate (tools/release-check.sh --Werror)"
	@echo
	@echo "QA (one pass, everything logged; a failing step is recorded, not fatal):"
	@echo "  make qa-android       Android build+tests+lint+coverage+gates+deps -> qa-android.log"
	@echo "  make qa-ios           iOS static gate+lint+tests+coverage+build -> qa-ios.log  [Mac]"
	@echo
	@echo "Store assets (Android):"
	@echo "  make screenshots-android      capture the in-app shots 01..06  [device]"
	@echo "  make report-pdfs-android      export the per-locale report PDFs  [device + manual Save-as-PDF]"
	@echo "  make screenshots-pdf-android  rasterize report pages 07/08 from the PDFs  [no device]"
	@echo "  make feature-graphics-android render every locale's feature graphic  [no device]"
	@echo "  make store-assets-android     the whole set: screenshots + PDFs + feature graphics"
	@echo "  make rokkitt-bold     bake the static Rokkitt Bold for the badge  [one-off; commit it]"
	@echo "Store assets (iOS):"
	@echo "  make screenshots-ios          capture 01..06 (+ report pages 07/08)  [Mac + Simulator]"
	@echo
	@echo "Release (Android):"
	@echo "  make release-android  gate, build (AAB+APK+SBOM) and stage into releases/  [device artifacts required]"
	@echo "  make cover-check      enforce the code-coverage floor (Android Kover + iOS PotillusKit)"
	@echo "Release (iOS, Mac only):"
	@echo "  make release-ios      archive, export a signed IPA + SBOM, stage into releases/"
	@echo "  make ios-sbom         generate the iOS CycloneDX SBOM only"
	@echo
	@echo "Publishing (upload already-staged artifacts; never builds or signs):"
	@echo "  make tgz              build the source release tarball"
	@echo "  make push-playstore   upload the staged AAB to Google Play  [git tag + signature gated]"
	@echo "  make push-appstore    upload the staged IPA to the App Store  [Mac; tag + signature gated]"
	@echo "  make push-codeberg    publish the Codeberg release + verify each asset checksum"
	@echo "  (none of these touch releases/ -- staged artifacts are removed by hand)"
	@echo
	@echo "OpenSSF badge (maintenance; network, run by hand):"
	@echo "  make bestpractices    write bestpractices-upstream.html: section links + copy buttons for the differing answers"
	@echo
	@echo "Housekeeping:"
	@echo "  make clean              clear both platforms' build output"
	@echo "  make distclean          clear build output + generated sources (fresh-clone state)"
	@echo "  make clean-android      Android build output only"
	@echo "  make distclean-android  Android build output + generated sources"
	@echo "  make clean-ios          iOS build output only"
	@echo "  make distclean-ios      iOS build output + generated sources"
	@echo
	@echo "Full first-build walkthrough: docs/INSTALL-ANDROID.md, docs/INSTALL-IOS.md"

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
# OPENSSF BADGE MAINTENANCE
# =============================================================================
# The one manual, network target that reports which committed badge answers still
# differ from bestpractices.dev lives in its own fragment; see make/bestpractices.mk.
# Its read-only, level-consistency sibling check-bestpractices-levels is a static
# check and stays in make/checks.mk. Included here so `make bestpractices` works
# from the repository root.
include make/bestpractices.mk

# =============================================================================
# RELEASE
# =============================================================================
# Release staging (gates, artifact build via the platform Makefiles, staging into
# releases/) lives in its own fragment; see make/release.mk. Included after store
# and checks because it reuses their locales/paths. `release-ios` and the
# release-check.sh decomposition are later revisions (see docs/ROADMAP.md).
include make/release.mk

# =============================================================================
# PUBLISHING
# =============================================================================
# Uploading the staged artifacts (Google Play, App Store, Codeberg) and building
# the source tarball live in their own fragment; see make/publish.mk. Included last
# because it reuses release.mk's staged paths and version, and never builds or signs
# anything itself.
include make/publish.mk

# =============================================================================
# TOP-LEVEL TARGETS  (per-platform umbrellas + dev convenience)
# =============================================================================
#
# The umbrellas tie the layers above into one command per platform. They are
# DEVICE-FREE (the Android APK build, JVM tests and lint; the iOS build, Swift
# tests and lint on a Mac): screenshots, coverage, device tests and release each
# have their own target and stay out of the daily run. Placed after the includes
# so the fragments' targets and variables (e.g. VERSION) are already defined.

# android: the device-free daily Android check.
android:
	$(MAKE) -C android debug-apk unit-tests lint check-guides
	$(MAKE) check-l10n-parity

# ios: the daily iOS check. The Mac-free static gate runs FIRST (so a Linux CI
# fails fast on what it can catch), then the Mac-only SwiftLint, PotillusKit tests
# and app build -- each of which carries its own require-macos guard.
ios:
	$(MAKE) check-ios-static
	$(MAKE) -C ios lint swift-tests build

# device-tests-android: the on-device instrumentation tests (Compose UI / Espresso).
# Kept out of the umbrella because they need a connected device; delegates to the
# android `device-tests` target (connectedDebugAndroidTest). The iOS counterpart,
# device-tests-ios (xcodebuild test on the simulator), is on the roadmap.
device-tests-android:
	$(MAKE) -C android device-tests

# install-debug: copy the built debug APK to ../downloads/ under a versioned name,
# for sideloading. It does NOT install to a device -- it just stages the file
# OUTSIDE the repo (build the APK first with `make -C android debug-apk`).
install-debug: ../downloads/potillus-$(VERSION)-debug.apk

../downloads/potillus-$(VERSION)-debug.apk: android/app/build/outputs/apk/debug/app-debug.apk
	cp $< $@

.PHONY: android ios device-tests-android install-debug

# =============================================================================
# QA LOG CAPTURE  (qa-android / qa-ios)
# =============================================================================
#
# The two qa-* targets run one platform's complete device-free QA battery --
# build, unit tests, lint, the coverage gate, the static/invariant gates and
# (Android) the release runtime dependency tree -- and tee EVERY step's output
# into one log file per platform at the repository root (qa-android.log /
# qa-ios.log). Both names fall under .gitignore's `*.log` pattern, so neither
# git nor the tgz exclude set (derived from .gitignore) ever picks them up.
#
# They differ from the daily umbrellas (`android`, `ios`) in one deliberate
# way: a failing step does NOT abort the run. A QA review wants the COMPLETE
# picture from one pass -- a red lint AND a red test AND a green build -- so
# each step runs through qa_step, which records PASS/FAIL and carries on. CI
# semantics are preserved at the end: the target exits non-zero if any step
# failed. The `===== name: ... =====` markers keep the log navigable with a
# plain text search.
#
# QA_PROLOGUE / QA_EPILOGUE hold the shared shell scaffolding ONCE, expanded
# into both recipes (make splices a multi-line variable into a recipe line by
# line, and .ONESHELL then feeds all of them to a single bash). `$$` throughout:
# these are SHELL variables, resolved when the recipe runs, not make variables.
# The prologue expects `log` to be set by the recipe's first line; it truncates
# the log and defines qa_step. qa_step runs `"$@" 2>&1 | tee -a` -- with the
# global `-o pipefail` the `if` sees the STEP's exit status, not tee's -- and
# appends failing step names to `fail` for the epilogue's summary.

define QA_PROLOGUE
: > "$$log"
fail=""
qa_step() {
    name="$$1"; shift
    printf '\n===== %s: %s =====\n' "$$name" "$$*" | tee -a "$$log"
    if "$$@" 2>&1 | tee -a "$$log"; then
        printf '===== %s: PASS =====\n' "$$name" | tee -a "$$log"
    else
        fail="$$fail $$name"
        printf '===== %s: FAIL (recorded; the run continues) =====\n' "$$name" | tee -a "$$log"
    fi
}
endef

define QA_EPILOGUE
printf '\n===== summary =====\n' | tee -a "$$log"
if [ -n "$$fail" ]; then
    printf 'FAILED steps:%s\n' "$$fail" | tee -a "$$log"
    printf 'full output: %s\n' "$$log" | tee -a "$$log"
    exit 1
fi
printf 'all steps passed\n' | tee -a "$$log"
printf 'full output: %s\n' "$$log" | tee -a "$$log"
endef

# qa-android: the Android QA battery. It mirrors the daily `android` umbrella
# step by step (debug APK, JVM unit tests, ktlint + Android lint, check-guides),
# then adds what a full review needs beyond the daily run: the Kover coverage
# gate, the repo-wide static checks, the full invariant gate (release-check)
# and the release runtime dependency tree (`make -C android deps`) -- the
# licensing-audit input. The environment step records the toolchain first, so
# the log is self-describing.
qa-android:
	@log="qa-android.log"
	$(QA_PROLOGUE)
	qa_step environment bash -c 'uname -a; $(MAKE) --version | sed -n 1p; java -version 2>&1; python3 --version'
	qa_step debug-apk $(MAKE) -C android debug-apk
	qa_step unit-tests $(MAKE) -C android unit-tests
	qa_step lint $(MAKE) -C android lint
	qa_step cover-check $(MAKE) -C android cover-check
	qa_step check-guides $(MAKE) -C android check-guides
	qa_step check-static $(MAKE) check-static
	qa_step release-check $(MAKE) release-check
	qa_step deps $(MAKE) -C android deps
	$(QA_EPILOGUE)

# qa-ios: the iOS QA battery. The Mac-free static gate runs FIRST, so even a
# Linux host contributes everything it can catch; the SwiftLint, unit-test,
# coverage and build steps then each carry ios/Makefile's own require-macos
# guard, so off macOS they are recorded as FAIL with that guard's message
# instead of aborting the log run. Run it on a Mac for the full picture. The
# environment probes are individually guarded (`|| echo not found`): an absent
# tool is itself a QA datum, not a reason to lose the rest of the step.
qa-ios:
	@log="qa-ios.log"
	$(QA_PROLOGUE)
	qa_step environment bash -c 'uname -a; sw_vers 2>/dev/null || true; xcodebuild -version 2>/dev/null || echo "xcodebuild: not found"; swift --version 2>/dev/null || echo "swift: not found"; swiftlint version 2>/dev/null || echo "swiftlint: not found"; command -v xcodegen || echo "xcodegen: not found"; python3 --version'
	qa_step check-ios-static $(MAKE) check-ios-static
	qa_step lint $(MAKE) -C ios lint
	qa_step swift-tests $(MAKE) -C ios swift-tests
	qa_step cover-check $(MAKE) -C ios cover-check
	qa_step build $(MAKE) -C ios build
	$(QA_EPILOGUE)

.PHONY: qa-android qa-ios
