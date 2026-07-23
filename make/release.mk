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

# ── iOS release (Mac only) ───────────────────────────────────────────────────
IOS_XCODEPROJ    := ios/Potillus.xcodeproj
IOS_SCHEME       := Potillus
XCODE_VERSION    := 26
IOS_BUILD_DIR    := ios/build
IOS_ARCHIVE      := $(IOS_BUILD_DIR)/Potillus.xcarchive
IOS_REPRO_DIR    := $(IOS_BUILD_DIR)/repro
IOS_IPA          := $(IOS_BUILD_DIR)/Potillus.ipa
IOS_EXPORT_PLIST := $(IOS_BUILD_DIR)/ExportOptions.plist
STAGED_IPA       := $(RELEASES_DIR)/$(RELEASE_ID)_$(VERSION_CODE).ipa
IOS_SBOM         := $(IOS_BUILD_DIR)/libellus-potionis-ios-sbom.json
STAGED_IOS_SBOM  := $(RELEASES_DIR)/$(RELEASE_ID)_$(VERSION_CODE)_ios_sbom.json

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

# iOS release gate: all of 01..08 are captured together by screenshots-ios, so
# the gate checks the whole set for every iOS store locale.
require-ios-screenshots = \
	missing=""; \
	for loc in $(IOS_SCREENSHOT_LOCALES); do \
	    for shot in 01_today 02_calendar 03_statistics 04_drinks 05_add_drink 06_settings 07_report_page_1 08_report_page_2; do \
	        f="$(IOS_SHOTS)/$$loc/$(IOS_SIM_DEVICE)-$$shot.png"; \
	        test -f "$$f" || missing="$$missing $$f"; \
	    done; \
	done; \
	if [ -n "$$missing" ]; then \
	    echo "$(1): required iOS screenshots are missing:" >&2; \
	    for f in $$missing; do echo "    $$f" >&2; done; \
	    echo "  These are captured on the simulator and never refreshed automatically." >&2; \
	    echo "  Capture them first:  make screenshots-ios" >&2; \
	    exit 1; \
	fi

# osv-scan-sbom: the release-time Software Composition Analysis gate. $(1) is the
# calling target (for the error message), $(2) is the CycloneDX SBOM to scan.
#
# WHY HERE AND NOT IN CI: the check runs against the SBOM each platform's build
# produces, and producing that SBOM needs the full toolchain (the Android SDK /
# Gradle, or Xcode via Package.resolved) — far more than a lightweight CI job is
# meant to carry (see docs/ROADMAP.md; the project currently has no CI pipeline
# at all, the GitLab one being still to build). Wiring the scan into staging,
# where the SBOM already exists, gates every release against the OSV database
# over the COMPLETE transitive dependency set — stronger than a manifest-only CI
# scan — at zero CI cost. A release cannot be staged while osv-scanner reports an
# unresolved finding.
#
# osv-scanner exits 0 when nothing is found and 1 when it reports vulnerabilities
# (its documented contract), so a bare invocation under this recipe's errexit is
# already a hard gate. `--config=osv-scanner.toml` applies the project's triage:
# a finding assessed as non-exploitable in this app (SECURITY.md, "Dependency
# monitoring") is recorded there with its reason and ignored, so a known but
# harmless transitive advisory does not block a release — the documented policy,
# made machine-enforced. Network access to osv.dev is required; the scan is the
# one release step that reaches the network.
osv-scan-sbom = \
	command -v osv-scanner >/dev/null 2>&1 || { \
	    echo "$(1): 'osv-scanner' not found -- install it (https://google.github.io/osv-scanner/installation/, e.g. 'go install github.com/google/osv-scanner/cmd/osv-scanner@v2') so the release SCA gate can run." >&2; \
	    exit 1; \
	}; \
	echo "$(1): scanning $(2) against the OSV database (osv-scanner)…"; \
	osv-scanner scan source --config=osv-scanner.toml -L "$(2)"

# =============================================================================
# COVERAGE GATE
# =============================================================================

# cover-check: the coverage gate, one target per platform -- Android's Kover LINE
# floor (:app:koverVerify) and the iOS line floor (swift test coverage over
# PotillusKit, in ios/Makefile). Kept separate from release-check.sh (rather than its
# --coverage flag) so the two platforms are gated symmetrically. Line-only on both;
# branch coverage and UI/instrumented coverage are roadmap goals (see docs/ROADMAP.md).
cover-check:
	$(MAKE) -C android cover-check
	$(MAKE) -C ios cover-check

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
	@# SCA gate: scan the freshly built CycloneDX SBOM against OSV before anything
	@# is staged. A finding fails the release here (see the osv-scan-sbom macro).
	@$(call osv-scan-sbom,release-android,$(GRADLE_SBOM))
	mkdir -p "$(RELEASES_DIR)"
	cp --archive "$(GRADLE_AAB)"  "$(STAGED_AAB)"
	cp --archive "$(GRADLE_APK)"  "$(STAGED_APK)"
	cp --archive "$(GRADLE_SBOM)" "$(STAGED_SBOM)"
	@echo "release-android: staged $(STAGED_AAB), $(STAGED_APK), $(STAGED_SBOM)"

# =============================================================================
# iOS RELEASE (Mac only)
# =============================================================================

# ios-sbom: the iOS CycloneDX SBOM from Package.resolved, normalized byte-stably by
# the same sbom-normalize.py the Android SBOM uses. Standalone (build/inspect it
# without a full release); release-ios invokes it before staging. Not Mac-gated --
# it only reads Package.resolved with Python.
ios-sbom:
	mkdir -p "$(IOS_BUILD_DIR)"
	python3 tools/gen-ios-sbom.py "$(IOS_SBOM)" --version "$(VERSION)"
	python3 tools/sbom-normalize.py "$(IOS_SBOM)"
	@echo "ios-sbom: wrote $(IOS_SBOM)"

# release-ios: the iOS counterpart of release-android -- archive, export a SIGNED
# .ipa, and stage it (plus the iOS SBOM) into releases/. MAC ONLY (xcodebuild), so
# it opens with a macOS guard. It archives TWICE without signing and stages only if
# the two unsigned .app payloads are byte-identical -- the iOS analogue of Android's
# F-Droid reproducible-build check -- then signs at export via the resolved Team ID
# (DEVELOPMENT_TEAM env or ios/signing.properties). Like release-android it never
# uploads (that is the fastlane ios lanes) and refuses to overwrite a staged .ipa.
release-ios:
	@test "$$(uname -s)" = "Darwin" || { echo "release-ios: needs macOS (the Xcode toolchain); host is $$(uname -s)." >&2; exit 1; }
	@# This recipe runs as ONE bash script under `.SHELLFLAGS := -eu -o pipefail`
	@# (see the .ONESHELL block near the top). Two consequences shape the style
	@# below: independent commands sit on their own lines (backslashes only join a
	@# SINGLE multi-line command), and every step must be errexit/pipefail-clean --
	@# a stray non-zero (e.g. sed on a missing file) would abort the whole target.
	@if test -e "$(STAGED_IPA)"; then \
		echo "release-ios: staged file '$(STAGED_IPA)' already exists -- refusing to overwrite a staged release. Remove the releases/ artifact for this versionCode (or bump versionCode) and re-run." >&2; \
		exit 1; \
	fi
	@# CLASS-1 store assets must already be captured (never refreshed here).
	$(call require-ios-screenshots,release-ios)
	@# Store release notes must be translated for THIS version before staging --
	@# the iOS twin of release-android's --release changelog gate. Run it fail-fast,
	@# before the two expensive archive builds; push-appstore re-checks at upload.
	python3 tools/check-ios-metadata.py --release
	# Resolve the signing Team ID: the DEVELOPMENT_TEAM environment variable wins,
	# else read it from ios/signing.properties. The `${VAR:-}` default keeps `-u`
	# (nounset) happy when the variable is unset, and the file is read ONLY when it
	# exists -- running sed on a missing file would fail under `-o pipefail -e` and
	# abort this .ONESHELL recipe before the friendly check below could report.
	team="$${DEVELOPMENT_TEAM:-}"
	if [ -z "$$team" ] && [ -f ios/signing.properties ]; then \
		team="$$(sed -n 's/^[[:space:]]*DEVELOPMENT_TEAM[[:space:]]*=[[:space:]]*//p' ios/signing.properties | head -n 1)"; \
	fi
	if [ -z "$$team" ] || [ "$$team" = "XXXXXXXXXX" ]; then \
		echo "release-ios: no Apple Developer Team ID -- set DEVELOPMENT_TEAM or copy ios/signing.properties.example to ios/signing.properties and fill it in (see docs/RELEASE-IOS.md)." >&2; \
		exit 1; \
	fi
	# Enforce the pinned major Xcode version, hard -- like the android/ Java-21 gate.
	# `xcodebuild -version` prints e.g. "Xcode 26.5" on its first line; a different
	# major means a different compiler and SDK than this release is defined against.
	xcode_major="$$(xcodebuild -version | sed -n '1s/^Xcode \([0-9][0-9]*\).*/\1/p')"
	if [ "$$xcode_major" != "$(XCODE_VERSION)" ]; then \
		echo "release-ios: Xcode $(XCODE_VERSION).x required, but 'xcodebuild -version' reports '$$(xcodebuild -version | head -n1)'. Select it with xcode-select (see docs/INSTALL-IOS.md)." >&2; \
		exit 1; \
	fi
	rm -rf "$(IOS_ARCHIVE)" "$(IOS_IPA)" "$(IOS_REPRO_DIR)" "$(IOS_BUILD_DIR)/dd"
	mkdir -p "$(IOS_BUILD_DIR)"
	# Generate the (git-ignored) ExportOptions.plist carrying the resolved teamID.
	printf '%s\n' \
		'<?xml version="1.0" encoding="UTF-8"?>' \
		'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
		'<plist version="1.0">' \
		'<dict>' \
		'    <key>method</key>          <string>app-store-connect</string>' \
		'    <key>destination</key>     <string>export</string>' \
		'    <key>signingStyle</key>    <string>automatic</string>' \
		"    <key>teamID</key>          <string>$$team</string>" \
		'    <key>manageAppVersionAndBuildNumber</key> <false/>' \
		'</dict>' \
		'</plist>' > "$(IOS_EXPORT_PLIST)"
	# Build the release archive TWICE and stage only if the two are byte-for-byte
	# identical -- the iOS analogue of the F-Droid reproducible-build check on Android.
	# With no third-party rebuilder for App Store binaries, the release proves its own
	# reproducibility by rebuilding from the same source and diffing the result.
	#
	# Both archives are built WITHOUT code signing (CODE_SIGNING_ALLOWED=NO); the
	# signature is added only at the App-Store export below, so the comparison is over
	# the reproducible unit: the unsigned .app payload. (A signature embeds a signing
	# time and, for ECDSA identities, a random nonce, and Apple re-signs on delivery,
	# so the signed .ipa is intentionally not byte-stable.) CODE_SIGNING_ALLOWED=NO also
	# needs no provisioning profile (an automatic-signing archive would provision a
	# *Development* profile, issued only for a REGISTERED DEVICE) and sidesteps signing
	# GRDB's SwiftPM resource bundle; the export step mints the DISTRIBUTION certificate
	# through -allowProvisioningUpdates. Both builds use the SAME derivedDataPath,
	# cleaned before each: Apple's linker folds the input object files' PATHS into the
	# Mach-O LC_UUID, so two builds under DIFFERENT derivedDataPaths emit byte-identical
	# code but a different UUID -- the only bytes that then differ, which this very check
	# would (and first did) reject. One clean shared path makes the .o paths, and thus
	# the UUID, identical; the rm below keeps each build clean. DEVELOPMENT_TEAM is passed
	# so team-scoped lookups resolve. The FIRST archive is the throwaway reference; the
	# SECOND is the one exported and staged. errexit aborts the release if an archive fails.
	# Coverage gate, the iOS counterpart of release-android's cover-check: fail
	# before the expensive archive if PotillusKit line coverage is below the floor.
	$(MAKE) -C ios cover-check
	# (Re)generate the Xcode project from project.yml before archiving (was the
	# `ios-project` prerequisite in the old root Makefile).
	$(MAKE) -C ios project
	xcodebuild archive \
		-project "$(IOS_XCODEPROJ)" \
		-scheme "$(IOS_SCHEME)" \
		-configuration Release \
		-destination 'generic/platform=iOS' \
		-archivePath "$(IOS_REPRO_DIR)/Potillus.xcarchive" \
		-derivedDataPath "$(IOS_BUILD_DIR)/dd" \
		DEVELOPMENT_TEAM="$$team" \
		CODE_SIGNING_ALLOWED=NO
	# Clean the shared derivedDataPath so build #2 is independent of build #1 yet uses
	# the identical intermediate paths (see the UUID note above); build into $(IOS_ARCHIVE).
	rm -rf "$(IOS_BUILD_DIR)/dd"
	xcodebuild archive \
		-project "$(IOS_XCODEPROJ)" \
		-scheme "$(IOS_SCHEME)" \
		-configuration Release \
		-destination 'generic/platform=iOS' \
		-archivePath "$(IOS_ARCHIVE)" \
		-derivedDataPath "$(IOS_BUILD_DIR)/dd" \
		DEVELOPMENT_TEAM="$$team" \
		CODE_SIGNING_ALLOWED=NO
	# Compare the two unsigned .app payloads. `diff -r` is silent and exits 0 when the
	# trees are identical; any divergent, missing, or extra file is a FATAL
	# reproducibility failure and the release is NOT staged. On success the throwaway
	# reference is removed; on mismatch both archives are kept for inspection.
	repro_app="$(IOS_REPRO_DIR)/Potillus.xcarchive/Products/Applications/$(IOS_SCHEME).app"
	staged_app="$(IOS_ARCHIVE)/Products/Applications/$(IOS_SCHEME).app"
	if diff -r "$$repro_app" "$$staged_app"; then \
		echo "release-ios: reproducible build verified -- the two archives' unsigned $(IOS_SCHEME).app payloads are byte-for-byte identical."; \
		rm -rf "$(IOS_REPRO_DIR)"; \
	else \
		echo "release-ios: FATAL -- the two release archives differ, so the build is not reproducible; refusing to stage. The diff above lists the divergent files; both archives are kept ($(IOS_REPRO_DIR)/ and $(IOS_ARCHIVE)) for inspection." >&2; \
		exit 1; \
	fi
	# Authenticate the export with Apple. -allowProvisioningUpdates needs either a
	# signed-in Xcode account or an App Store Connect API key passed EXPLICITLY --
	# xcodebuild does not read the APP_STORE_CONNECT_API_KEY_* variables itself
	# (those are a fastlane convention). When all three are set we pass them via
	# -authenticationKey*, so the export -- and thus the whole release -- runs
	# head-less (e.g. over SSH) with the same key the upload lane uses; otherwise we
	# omit the flags and fall back to the Xcode-signed-in account. The ${VAR:-}
	# defaults keep -u (nounset) happy, and the two full invocations keep every
	# value quoted (a key path may contain spaces) rather than splitting a string.
	if [ -n "$${APP_STORE_CONNECT_API_KEY_KEY_ID:-}" ] && \
	   [ -n "$${APP_STORE_CONNECT_API_KEY_ISSUER_ID:-}" ] && \
	   [ -n "$${APP_STORE_CONNECT_API_KEY_KEY_FILEPATH:-}" ]; then \
		xcodebuild -exportArchive \
			-archivePath "$(IOS_ARCHIVE)" \
			-exportPath "$(IOS_BUILD_DIR)" \
			-exportOptionsPlist "$(IOS_EXPORT_PLIST)" \
			-allowProvisioningUpdates \
			-authenticationKeyID "$$APP_STORE_CONNECT_API_KEY_KEY_ID" \
			-authenticationKeyIssuerID "$$APP_STORE_CONNECT_API_KEY_ISSUER_ID" \
			-authenticationKeyPath "$$APP_STORE_CONNECT_API_KEY_KEY_FILEPATH"; \
	else \
		xcodebuild -exportArchive \
			-archivePath "$(IOS_ARCHIVE)" \
			-exportPath "$(IOS_BUILD_DIR)" \
			-exportOptionsPlist "$(IOS_EXPORT_PLIST)" \
			-allowProvisioningUpdates; \
	fi
	# Stage the .ipa under its canonical name. `cp -a` (not the GNU-only
	# `cp --archive`) because this target runs on macOS, whose BSD cp accepts the
	# short -a but not the long option.
	mkdir -p "$(RELEASES_DIR)"
	cp -a "$(IOS_IPA)" "$(STAGED_IPA)"
	# Generate the iOS SBOM from Package.resolved and normalise it with the same
	# tool the Android SBOM uses, then stage it beside the .ipa. Analogous to the
	# Android SBOM, which release-android stages as _android_sbom.json.
	$(MAKE) ios-sbom
	@# SCA gate: scan the iOS SBOM against OSV before staging it, mirroring the
	@# Android gate in release-android. A finding fails the release here.
	@$(call osv-scan-sbom,release-ios,$(IOS_SBOM))
	cp -a "$(IOS_SBOM)" "$(STAGED_IOS_SBOM)"
	@echo "release-ios: staged $(STAGED_IPA)"
	@echo "release-ios: staged $(STAGED_IOS_SBOM)"
	@echo "release-ios: upload to TestFlight with:  ( cd fastlane && bundle exec fastlane ios alpha ipa:\"$(STAGED_IPA)\" )"
	@echo "release-ios: upload to the App Store listing with:  make push-appstore"

.PHONY: cover-check release-android release-ios ios-sbom
