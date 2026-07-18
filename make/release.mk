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
#  release.mk -- Libellus Potionis, release staging (included by ./Makefile)
# =============================================================================
#
#  A root-level INCLUDE, not a standalone Makefile: it runs from the repository
#  root and reuses the store locales/paths from make/store.mk (included before it).
#  It orchestrates a RELEASE: run the gates, delegate the artifact build to the
#  platform Makefile, then STAGE the results into releases/ under canonical names.
#  Building the artifacts stays in android/Makefile (`release`/`bundle`/`sbom`);
#  the gates and staging live here so the per-platform Makefile carries no release
#  policy.
#
#  THIS revision covers Android. release-ios and the decomposition of the
#  tools/release-check.sh monolith are later revisions (both tracked in
#  docs/ROADMAP.md).
# =============================================================================

# ── Version + identity (single sources of truth) ─────────────────────────────
# VERSION is the human version from the top CHANGELOG entry; RELEASE_ID and
# VERSION_CODE come from app/build.gradle.kts. (These $(shell) calls contain `#`
# via the `## v` grep, which is why ../make/guard.mk requires GNU Make 4.3.)
VERSION      := $(shell grep '^## v' CHANGELOG.md | head -n 1 | cut -c5-)
RELEASE_ID   := $(shell grep -oE 'applicationId *= *"[^"]+"' android/app/build.gradle.kts | head -1 | grep -oE '"[^"]+"' | tr -d '"')
VERSION_CODE := $(shell grep -oE 'versionCode *= *[0-9]+' android/app/build.gradle.kts | grep -oE '[0-9]+' | head -1)

# ── Staging layout ───────────────────────────────────────────────────────────
# The artifacts Gradle produces (GRADLE_*) are copied to canonical, versionCode-
# stamped names under releases/ (STAGED_*), the tree the fastlane upload lanes read.
RELEASES_DIR := releases
GRADLE_AAB   := android/app/build/outputs/bundle/release/app-release.aab
GRADLE_APK   := android/app/build/outputs/apk/release/app-release.apk
GRADLE_SBOM  := android/app/build/outputs/sbom/libellus-potionis-sbom.json
STAGED_AAB   := $(RELEASES_DIR)/$(RELEASE_ID)_$(VERSION_CODE).aab
STAGED_APK   := $(RELEASES_DIR)/$(RELEASE_ID)_$(VERSION_CODE).apk
STAGED_SBOM  := $(RELEASES_DIR)/$(RELEASE_ID)_$(VERSION_CODE)_android_sbom.json

# ── Release gates (presence of the device artifacts) ─────────────────────────
# A release must ship the store screenshots and the report PDFs, and neither is
# refreshed automatically (both need a device). These assert every locale's set is
# present and fail with the capture/export command otherwise. $(1) = calling target.
require-android-screenshots = \
	missing=""; \
	for loc in $(SCREENSHOT_LOCALES); do \
	    for shot in 01_today 02_calendar 03_statistics 04_drinks 05_add_drink 06_settings; do \
	        f="$(META)/$$loc/images/phoneScreenshots/$$shot.png"; \
	        test -f "$$f" || missing="$$missing $$f"; \
	    done; \
	done; \
	if [ -n "$$missing" ]; then \
	    echo "$(1): required device screenshots are missing:" >&2; \
	    for f in $$missing; do echo "    $$f" >&2; done; \
	    echo "  These are captured on a device and never refreshed automatically." >&2; \
	    echo "  Capture them first:  make screenshots-android" >&2; \
	    exit 1; \
	fi

require-android-report-pdfs = \
	missing=""; \
	for loc in $(SCREENSHOT_LOCALES); do \
	    f="$(REPORT_PDF_DIR)/potillus_report_$$loc.pdf"; \
	    test -f "$$f" || missing="$$missing $$f"; \
	done; \
	if [ -n "$$missing" ]; then \
	    echo "$(1): required report PDFs are missing:" >&2; \
	    for f in $$missing; do echo "    $$f" >&2; done; \
	    echo "  These are exported from the running app and never refreshed automatically." >&2; \
	    echo "  Export them first:  make report-pdfs-android" >&2; \
	    exit 1; \
	fi

# =============================================================================
# COVERAGE GATE
# =============================================================================

# cover-check: the coverage gate, one target per platform. Today it runs Android's
# Kover floor (:app:koverVerify, in android/Makefile). The iOS xccov floor will join
# here as `$(MAKE) -C ios cover-check` once that target exists -- see docs/ROADMAP.md.
# Kept separate from release-check.sh (rather than its --coverage flag) precisely so
# the iOS side can be added symmetrically.
cover-check:
	$(MAKE) -C android cover-check

# =============================================================================
# ANDROID RELEASE
# =============================================================================

# release-android: gate, build, stage. In order it (1) asserts the store
# screenshots and report PDFs are present, (2) refuses to overwrite an already-
# staged (possibly published) artifact for this versionCode, (3) runs the read-only
# invariant gate (tools/release-check.sh --release) and the coverage gate, (4)
# builds the AAB, APK and SBOM via the Android Makefile, and (5) copies them into
# releases/ under their canonical names. It never uploads -- that is the fastlane
# lanes (push-playstore), which read the staged AAB.
release-android:
	@$(call require-android-screenshots,release-android)
	@$(call require-android-report-pdfs,release-android)
	@for f in "$(STAGED_AAB)" "$(STAGED_APK)" "$(STAGED_SBOM)"; do \
	    if test -e "$$f"; then echo "release-android: staged file '$$f' already exists -- refusing to overwrite a staged release. Remove the releases/ artifacts for this versionCode (or bump versionCode) and re-run." >&2; exit 1; fi; \
	done
	bash tools/release-check.sh --Werror --release
	$(MAKE) -C android cover-check
	$(MAKE) -C android release bundle
	mkdir -p "$(RELEASES_DIR)"
	cp --archive "$(GRADLE_AAB)"  "$(STAGED_AAB)"
	cp --archive "$(GRADLE_APK)"  "$(STAGED_APK)"
	cp --archive "$(GRADLE_SBOM)" "$(STAGED_SBOM)"
	@echo "release-android: staged $(STAGED_AAB), $(STAGED_APK), $(STAGED_SBOM)"

.PHONY: cover-check release-android
