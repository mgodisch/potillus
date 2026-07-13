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
#  Makefile -- Libellus Potionis build tooling for Debian GNU/Linux stable
# =============================================================================
#
#  TARGETS AT A GLANCE
#    Platforms
#      help         (default) print this list and do nothing else
#      android      local checks (release-check, lint, unit tests, guide sync)
#                   + debug APK, then refresh existing feature graphics
#      ios          static checks, regenerate the Xcode project, then the kit's
#                   tests and a simulator build of the app              [needs a Mac]
#      check-ios-static   the Mac-free iOS static gates (Swift symbols/tests,
#                   headers, l10n, l10n-parity, report paper). Run it on the Linux
#                   release path so a release-check run never leaves iOS unverified
#    Convenience
#      device-tests on-device instrumentation tests (connectedDebugAndroidTest),
#                   split out of `android`                        [needs a device]
#      release-android  the signed release APK, AAB and SBOM (device-free; does
#                       NOT capture screenshots -- run `make screenshots-android`
#                       first if needed)
#      release-ios  the signed .ipa, archived, exported and staged into releases/
#                   (uploads via the fastlane `ios beta`/`testing` lanes) [Mac]
#      install      copy the freshly built debug APK to the local install path
#    Store assets (Android -> Play Store)
#      store-assets-android  full set in one go: screenshots + report-pdfs, then
#                            feature graphics rendered exactly once      [device]
#      screenshots-android   capture the six in-app shots 01..06 per locale, then
#                            refresh the feature graphics                [device]
#      screenshots-pdf-android    rasterize report pages 07..08 from per-locale PDFs
#      feature-graphics-android   (re)build every locale's featureGraphic*.png
#      feature-graphics-existing-android  refresh only graphics already on disk
#      report-pdfs        semi-automatic per-locale PDF export -> 07..08, then
#                         refresh the feature graphics                 [device]
#      rokkitt-bold       bake the static Rokkitt Bold used by the badges
#    Store assets (iOS -> App Store)
#      screenshots-ios    capture the App Store screenshots via the iOS Simulator
#                         [needs a Mac + the PotillusUITests UI-test target]
#    Packaging
#      tgz          release source tarball (exclusions derived from .gitignore)
#      push         git push + tags
#    Publishing (upload already-built artifacts; these targets never build)
#      push-playstore  upload the release AAB + store metadata to Google Play
#                      via the fastlane `testing` lane (closed alpha) [AAB + key]
#      push-codeberg   create the Codeberg release for the pushed tag and attach
#                      the built APK + SBOM                    [tag + APK + SBOM]
#    OpenSSF badge
#      bestpractices-json  pull the badge answers from bestpractices.dev into
#                          .bestpractices.json (site -> repo snapshot)
#    Housekeeping
#      clean / distclean
# =============================================================================

# =============================================================================
# CONFIGURATION
# =============================================================================

# ── GNU Make version guard ───────────────────────────────────────────────────
# This Makefile needs GNU Make 4.x: it uses .ONESHELL (3.82+) and grouped targets
# (`&:`, 4.3+), and 3.81 additionally mis-parses the `#` inside the $(shell ...)
# just below (it strips from `#` as a comment, truncating the call). macOS still
# ships GNU Make 3.81 as /usr/bin/make -- frozen at the last GPLv2 release -- which
# a non-interactive `ssh host 'make ...'` picks up unless PATH points at a newer
# one. Fire a legible error HERE, before the first line 3.81 chokes on, instead of
# the cryptic "unterminated call to function `shell'" it would raise further down.
# 3.81-safe syntax only: major = first dot-separated field; abort when it is <= 3.
make_major := $(firstword $(subst ., ,$(MAKE_VERSION)))
ifeq ($(filter-out 0 1 2 3,$(make_major)),)
$(error This Makefile needs GNU Make 4.0 or newer, but you are running $(MAKE_VERSION). On macOS the system 'make' is 3.81; install a current GNU Make (brew install make) and run 'gmake' instead of 'make'.)
endif

VERSION = $(shell grep '^## v' CHANGELOG.md | head -n 1 | cut -c5-)

# Run each recipe in ONE bash process with strict error handling
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.ONESHELL:
# The default goal prints the target list and changes nothing. A bare `make` in a
# repository that builds two platforms should not silently pick one of them.
.DEFAULT_GOAL := help

# ── Play-Store screenshot pipeline (see the `screenshots-android` target) ─────────────
# Locales captured: EVERY store locale under the metadata tree. Each locale dir
# carries a changelogs/ sub-dir, so globbing those and stripping the suffix
# yields exactly the locale set (and skips the non-locale screenshots.html file,
# which has no changelogs/). This is self-maintaining -- adding a
# fastlane/metadata/android/<locale>/ directory extends capture automatically --
# and fastlane/Screengrabfile derives the SAME set the same way, so the two can
# never drift.
SCREENSHOT_LOCALES := $(sort $(notdir $(patsubst %/changelogs,%,$(wildcard fastlane/metadata/android/*/changelogs))))
# The demo fixture (fastlane/demo-backup.json) covers 2026-01-01..2026-06-30, so
# the screenshots are captured from the perspective of the last day of that range
# to give the date-relative "Today" screen meaningful content.
#
# AUTHORITATIVE PIN: the capture suite pins this perspective IN-APP
# (DayResolver.clockOverride, set by ScreenshotClock.pin()), so it holds on ANY
# device — including a locked production phone where the `adb shell date` pin in
# the `screenshots-android` recipe is silently rejected. This SCREENSHOT_DATE must stay
# equal to ScreenshotClock.SCREENSHOT_DATE and must not fall before the fixture's
# last logged day (2026-06-30 is a deliberately dry "today", one day after the
# last 2026-06-29 entry); the `screenshots-android` preflight guard enforces both.
SCREENSHOT_DATE  := 2026-06-30

# Display geometry forced onto the capture device (see the `screenshots-android` recipe;
# reset again by `screenshots-demo-off-android`).
#
# WHY FORCE IT AT ALL?
#   Google Play rejects phone screenshots whose long side exceeds twice the short
#   side. Most modern panels are 19.5:9 or 20:9 and thus fail. Instead of trimming
#   the captures afterwards (the former `screenshots-crop` step, dropped together
#   with its Pillow dependency), the panel is overridden to an exactly 2:1
#   geometry, so every capture is compliant by construction and shows the real,
#   uncropped app — including the system navigation row.
#
# WHY 1428x2856 @ 640 dpi?
#   2856 / 1428 = 2.000, i.e. exactly at Play's limit and comfortably inside its
#   320..3840 px per-side bounds. 640 dpi (xxxhdpi) makes the app render at
#   1428 / 640 * 160 = 357 dp of usable width — close to the 360 dp baseline the
#   layouts are designed against, so no locale's strings reflow differently than
#   on a typical device. (Alternatives for the record: 480 dpi → 476 dp is a
#   tablet-like layout width; 560 dpi → 408 dp still reads as a large phone. Both
#   are legal here; 640 was chosen for closest baseline parity.)
SCREENSHOT_SIZE    := 1428x2856
SCREENSHOT_DENSITY := 640
# Inputs the drift guard cross-checks against SCREENSHOT_DATE (see the guard in
# the `screenshots-android` recipe): the in-app capture-date pin and the demo fixture
# whose last logged day the "Today" screenshot must land on.
SCREENSHOT_PIN_KT := android/app/src/androidTest/kotlin/de/godisch/potillus/screenshot/ScreenshotClock.kt
DEMO_BACKUP_JSON  := fastlane/demo-backup.json
# Status-bar clock shown in every shot while Android Demo Mode is active (HHMM).
SCREENSHOT_CLOCK := 1000
# PDF report render resolution. 200 dpi on A4 -> ~1653x2337 px, inside Google
# Play's 320..3840 px / max-2:1 limits (verified by tools/validate-screenshots.py).
SCREENSHOT_PDF_DPI := 200
# Root of the fastlane store-metadata tree (shared by Play `supply` and F-Droid).
META := fastlane/metadata/android
# Directory holding the per-locale source report PDFs (potillus_report_<locale>.pdf)
# that screenshots-pdf rasterizes into the 07/08 report screenshots.
REPORT_PDF_DIR := fastlane/report-pdf

# ── Preflight helpers ── each expands to a one-line "fail fast with an install
# hint if a tool is missing" guard. $(1) is the calling target's name, used as
# the message prefix, so one definition serves every recipe that needs the tool.
require-device    = adb devices 2>/dev/null | grep -q 'device$$' || { echo "$(1): no device/emulator connected (adb) -- connect one first."; exit 1; }
require-pdftoppm  = command -v pdftoppm >/dev/null || { echo "$(1): 'pdftoppm' not found — install poppler-utils"; exit 1; }
require-rsvg      = command -v rsvg-convert >/dev/null 2>&1 || { echo "$(1): 'rsvg-convert' not found — install librsvg2-bin"; exit 1; }
# Still needed after `screenshots-crop` was dropped: tools/render-feature-graphic.py
# imports PIL (it draws the phone mockup and perspective-warps it before embedding
# the result in the SVG). Without this pre-flight the feature-graphic build dies
# with a bare ImportError traceback instead of an actionable message.
require-pillow    = python3 -c 'import PIL' 2>/dev/null || { echo "$(1): Pillow not found — install it (Debian: apt install python3-pil, or: pip install pillow --break-system-packages)"; exit 1; }
require-fonttools = python3 -c 'import fontTools' 2>/dev/null || { echo "$(1): fonttools not found — install it (Debian: apt install fonttools, or: pip install fonttools --break-system-packages)"; exit 1; }

# =============================================================================
# CONVENIENCE & INSTALL
# =============================================================================

# ── help ── the default goal: print the target list, build nothing.
#
# The text is not duplicated here. It is the "TARGETS AT A GLANCE" block at the
# top of this file, printed by stripping the leading `#`. A help text kept
# separately from the comment it paraphrases is a help text that will one day
# describe a target that no longer exists.
#
# The range ends at the block's closing rule line, which `$$d` then drops.
help:
	@sed -n '/^#  TARGETS AT A GLANCE/,/^# ====/p' Makefile | sed -e 's/^#//' -e '$$d'

# ── android ── the everyday Android build. Maximal LOCAL verification, then the
# debug APK. Runs (via android/) the release-check gate, Android lint, the JVM
# unit tests and the guide/copyright sync check, then builds the debug APK and
# refreshes any feature graphics that already exist. The on-device instrumentation
# tests are NOT part of this target — they live in `device-tests` (run that
# separately when a device is attached), so this build needs no device. It is
# deliberately incremental (no `clean`) for fast iteration and FAILS if any code
# or documentation check would require a correction.
#
# Formerly the default goal, and formerly called `debug`. It was renamed when the
# repository grew a second platform: `make debug` no longer says which one.
android:
	$(MAKE) check-l10n-parity
	$(MAKE) -C android debug unit-test lint check-guides
	$(MAKE) feature-graphics-existing-android
	$(MAKE) install

# ── device-tests ── the on-device instrumentation tests (Compose UI / Espresso),
# split out of `debug` so the default build runs device-free. Delegates to the
# android `test-device` target (./gradlew connectedDebugAndroidTest), which wakes
# the device and asserts one is attached before running.
device-tests:
	$(MAKE) -C android test-device

# ── Release staging ── The signed artifacts are copied into a git-ignored
# releases/ directory under stable, self-describing names
# (`<applicationId>_<versionCode>.<ext>`, e.g. de.godisch.potillus_92.apk) by
# `make release-android` (below). The publishing targets upload EXACTLY these
# staged files — never the raw Gradle output — so the bytes that were verified
# and pushed stay on disk, and the names double as the Play/Codeberg asset names.
# RELEASE_ID is the applicationId, read from the same build.gradle.kts the
# versionCode comes from, so the two never drift. VERSION_CODE is also used far
# below by push-codeberg (release-notes filename); defined here so both the
# staging and the push targets see it.
RELEASES_DIR  := releases
RELEASE_ID    := $(shell grep -oE 'applicationId *= *"[^"]+"' android/app/build.gradle.kts | head -1 | grep -oE '"[^"]+"' | tr -d '"')
VERSION_CODE  := $(shell grep -oE 'versionCode *= *[0-9]+' android/app/build.gradle.kts | grep -oE '[0-9]+' | head -1)
GRADLE_AAB    := android/app/build/outputs/bundle/release/app-release.aab
GRADLE_APK    := android/app/build/outputs/apk/release/app-release.apk
GRADLE_SBOM   := android/app/build/outputs/sbom/libellus-potionis-sbom.json
STAGED_AAB    := $(RELEASES_DIR)/$(RELEASE_ID)_$(VERSION_CODE).aab
STAGED_APK    := $(RELEASES_DIR)/$(RELEASE_ID)_$(VERSION_CODE).apk
STAGED_SBOM   := $(RELEASES_DIR)/$(RELEASE_ID)_$(VERSION_CODE)_sbom.json

# iOS release artifact paths (the counterpart of the Android block above). The
# Xcode archive and the exported .ipa are BUILD OUTPUTS under ios/build/ (that
# directory is git-ignored via ios/.gitignore's `build/` rule), and the shippable
# .ipa is STAGED into releases/ under the SAME <applicationId>_<versionCode>
# convention as the AAB/APK, so the release directory holds every platform's
# artifact side by side. IOS_XCODEPROJ is generated by `make ios-project`
# (XcodeGen) and is itself git-ignored; release-ios depends on that target so the
# project and Version.xcconfig are regenerated before archiving.
IOS_XCODEPROJ    := ios/Potillus.xcodeproj
IOS_SCHEME       := Potillus
IOS_BUILD_DIR    := ios/build
IOS_ARCHIVE      := $(IOS_BUILD_DIR)/Potillus.xcarchive
IOS_IPA          := $(IOS_BUILD_DIR)/Potillus.ipa
IOS_EXPORT_PLIST := $(IOS_BUILD_DIR)/ExportOptions.plist
STAGED_IPA       := $(RELEASES_DIR)/$(RELEASE_ID)_$(VERSION_CODE).ipa

# ── release-android ── build the signed release APK, the release AAB and the
# shared SBOM, then STAGE all three into releases/ under their canonical names
# with `cp --archive`. This target is DEVICE-FREE and deliberately does NOT
# (re)capture the store screenshots or feature graphics: those are store assets,
# refreshed on demand (`make screenshots-android`, or `make store-assets-android`
# for the whole set) and then uploaded by `push-playstore` / attached by
# `push-codeberg` — independently of building the artifacts here, exactly as the
# report pages 07/08 already work.
# The android `release` and `bundle` targets produce the APK and AAB; both depend
# on the same `$(SBOM)` file target, so the CycloneDX SBOM is generated once.
#
# Staging happens ONLY here (the push targets read releases/ but never write it).
# To keep a previously staged, possibly already-published release set from being
# silently overwritten, this FAILS FAST at the very start if any of the three
# staged files already exists: clear them deliberately (or bump the versionCode)
# before re-staging. `cp --archive` preserves mode/timestamps, so the staged copy
# is the byte-identical artifact the push targets then verify and upload.
release-android:
	@for f in "$(STAGED_AAB)" "$(STAGED_APK)" "$(STAGED_SBOM)"; do \
		if test -e "$$f"; then echo "release-android: staged file '$$f' already exists -- refusing to overwrite a staged release. Remove the releases/ artifacts for this versionCode (or bump versionCode) and re-run." >&2; exit 1; fi; \
	done
	$(MAKE) -C android release bundle
	mkdir -p "$(RELEASES_DIR)"
	cp --archive "$(GRADLE_AAB)"  "$(STAGED_AAB)"
	cp --archive "$(GRADLE_APK)"  "$(STAGED_APK)"
	cp --archive "$(GRADLE_SBOM)" "$(STAGED_SBOM)"
	@echo "release-android: staged $(STAGED_AAB), $(STAGED_APK), $(STAGED_SBOM)"

# ── release-ios ── the iOS counterpart of release-android: archive the app,
# export a SIGNED .ipa, and STAGE it into releases/ under its canonical name.
# Unlike release-android this needs a MAC with Xcode — xcodebuild cannot run in
# the container — so it is the one release target that is not device-/host-free.
# Like release-android it never touches screenshots (those are `make
# screenshots-ios`) and never uploads (that is the fastlane `ios beta` /
# `ios testing` lanes, which read the staged .ipa).
#
# Signing uses AUTOMATIC signing with the Team ID resolved the same way the
# Android keystore is: the environment variable DEVELOPMENT_TEAM wins, and
# ios/signing.properties is the fallback (see ios/signing.properties.example and
# docs/RELEASE-IOS.md). The Team ID is injected into the archive as an xcodebuild
# COMMAND-LINE build setting — which overrides the empty `DEVELOPMENT_TEAM` in
# project.yml for this one invocation — and written as the `teamID` of a
# generated (git-ignored) ExportOptions.plist so the export re-signs with the
# same team. `manageAppVersionAndBuildNumber` is false there on purpose: the
# version and build number come from Version.xcconfig (CHANGELOG + versionCode),
# the project's single source of truth, and must not be rewritten at export time.
#
# Staging mirrors release-android exactly, including the fail-fast guard that
# refuses to overwrite an already-staged (possibly published) .ipa: clear the
# releases/ artifact for this versionCode, or bump the versionCode, before
# re-staging.
release-ios: ios-project
	@# This recipe runs as ONE bash script under `.SHELLFLAGS := -eu -o pipefail`
	@# (see the .ONESHELL block near the top). Two consequences shape the style
	@# below: independent commands sit on their own lines (backslashes only join a
	@# SINGLE multi-line command), and every step must be errexit/pipefail-clean --
	@# a stray non-zero (e.g. sed on a missing file) would abort the whole target.
	@if test -e "$(STAGED_IPA)"; then \
		echo "release-ios: staged file '$(STAGED_IPA)' already exists -- refusing to overwrite a staged release. Remove the releases/ artifact for this versionCode (or bump versionCode) and re-run." >&2; \
		exit 1; \
	fi
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
	rm -rf "$(IOS_ARCHIVE)" "$(IOS_IPA)"
	mkdir -p "$(IOS_BUILD_DIR)"
	# Generate the (git-ignored) ExportOptions.plist carrying the resolved teamID.
	printf '%s\n' \
		'<?xml version="1.0" encoding="UTF-8"?>' \
		'<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">' \
		'<plist version="1.0">' \
		'<dict>' \
		'    <key>method</key>          <string>app-store</string>' \
		'    <key>destination</key>     <string>export</string>' \
		'    <key>signingStyle</key>    <string>automatic</string>' \
		"    <key>teamID</key>          <string>$$team</string>" \
		'    <key>manageAppVersionAndBuildNumber</key> <false/>' \
		'</dict>' \
		'</plist>' > "$(IOS_EXPORT_PLIST)"
	# Archive WITHOUT code signing, then sign only at the App-Store export. This
	# keeps the whole release device-independent. Signing an archive under
	# automatic signing would provision an iOS App *Development* profile, which
	# Apple issues only once the team has a REGISTERED DEVICE -- a requirement a
	# TestFlight/App-Store build should not carry (and one an MDM-managed device may
	# make impossible). With CODE_SIGNING_ALLOWED=NO the archive needs no profile at
	# all (this also sidesteps Xcode's attempt to code-sign GRDB's SwiftPM resource
	# bundle), and the export step below mints the DISTRIBUTION certificate and the
	# App-Store provisioning profile through -allowProvisioningUpdates -- neither of
	# which is tied to a device. DEVELOPMENT_TEAM is still passed so any team-scoped
	# lookup resolves; the ExportOptions.plist carries the same teamID for the
	# export. errexit aborts the recipe if the archive step fails, so the two
	# commands stand on their own lines rather than in an && chain.
	xcodebuild archive \
		-project "$(IOS_XCODEPROJ)" \
		-scheme "$(IOS_SCHEME)" \
		-configuration Release \
		-destination 'generic/platform=iOS' \
		-archivePath "$(IOS_ARCHIVE)" \
		DEVELOPMENT_TEAM="$$team" \
		CODE_SIGNING_ALLOWED=NO
	xcodebuild -exportArchive \
		-archivePath "$(IOS_ARCHIVE)" \
		-exportPath "$(IOS_BUILD_DIR)" \
		-exportOptionsPlist "$(IOS_EXPORT_PLIST)" \
		-allowProvisioningUpdates
	# Stage the .ipa under its canonical name. `cp -a` (not the GNU-only
	# `cp --archive`) because this target runs on macOS, whose BSD cp accepts the
	# short -a but not the long option.
	mkdir -p "$(RELEASES_DIR)"
	cp -a "$(IOS_IPA)" "$(STAGED_IPA)"
	@echo "release-ios: staged $(STAGED_IPA)"
	@echo "release-ios: upload to TestFlight with:  ( cd fastlane && bundle exec fastlane ios beta ipa:\"../$(STAGED_IPA)\" )"

install: ../downloads/potillus-$(VERSION)-debug.apk

../downloads/potillus-$(VERSION)-debug.apk: android/app/build/outputs/apk/debug/app-debug.apk
	cp $< $@

# =============================================================================
# PLAY-STORE SCREENSHOTS
# =============================================================================
#   Fully automated capture of the eight Google-Play phone screenshots per
#   locale (every store locale under the metadata tree; see SCREENSHOT_LOCALES),
#   placed straight into the fastlane metadata tree:
#
#     01_today  02_calendar  03_statistics   (LIGHT) ─┐ captured in-app by the
#     04_drinks 05_add_drink 06_settings     (DARK)  ─┘ screengrab/Espresso suite
#     07_report_page_1  08_report_page_2             ─ rendered from the PDF report
#
#   The status bar is cleaned for the in-app shots via the Android Demo Mode API
#   (clock 10:00, 100 % battery, full Wi-Fi, no notifications). Demo Mode is
#   ALWAYS switched off again at the end, even on failure, via a bash EXIT trap.
#
#   Prerequisites on the build host (see fastlane/Gemfile and the project README):
#     * a connected device/emulator — ANY panel geometry will do: the recipe
#       overrides the display to $(SCREENSHOT_SIZE) @ $(SCREENSHOT_DENSITY) (an
#       exact 2:1) for the duration of the capture and resets it afterwards, so
#       Play's max-2:1 rule is satisfied by construction rather than by cropping;
#     * Ruby + bundler with fastlane installed: `cd fastlane && bundle install`;
#     * poppler-utils (`pdftoppm`) for rendering the PDF report pages.
#     * Pillow (`python3-pil`) for the feature graphics rebuilt by the final
#       cascade step (tools/render-feature-graphic.py draws the phone mockup).
#
#   The capture perspective (logical "today") is pinned IN-APP by the capture
#   suite (ScreenshotClock.pin() → DayResolver.clockOverride = $(SCREENSHOT_DATE)),
#   so the date-relative screens are correct on ANY device. The extra
#   `adb shell date` pin below is only best-effort cosmetics for anything that
#   might read the raw device clock; it needs an emulator or a rooted userdebug
#   build and is skipped (|| true) on a locked production device WITHOUT affecting
#   the captured screenshots.
screenshots-android:
	# A connected device/emulator (state "device") is required; fail fast BEFORE
	# the expensive build below. `set -x` traces the probe so the actual
	# `adb devices` command is visible AT the point it runs -- .ONESHELL echoes the
	# whole recipe once, up front and far from any failure, so the trace (not that
	# echo) is what shows next to the error. grep aborts here if none is ready.
	set -x
	adb devices
	adb devices | grep -qw device
	{ set +x; } 2>/dev/null
	$(MAKE) -C android prereq
	# 0) Pre-flight: the BUNDLED fastlane must be installed in fastlane before any
	#    expensive work (the Gradle build and the device / Demo-Mode setup below).
	#    The gems are vendored under fastlane/.vendor via `cd fastlane && bundle
	#    install`; if that bundle is missing, the `bundle exec fastlane` capture in
	#    step 5 aborts late with the cryptic "bundler: command not found: fastlane"
	#    (Error 127) AFTER a full build and after toggling Demo Mode. Fail fast with
	#    an actionable message instead — mirrors the pdftoppm pre-flight
	#    checks in screenshots-pdf. `bundle check` only verifies
	#    the bundle is satisfied (it does not load fastlane), so it is cheap.
	command -v bundle >/dev/null 2>&1 || { echo "screenshots-android: 'bundle' (Ruby Bundler) not found -- install Ruby + Bundler 4.0.15, then run 'cd fastlane && bundle install'."; exit 1; }
	( cd fastlane && bundle check >/dev/null 2>&1 ) || { echo "screenshots-android: fastlane gems are not installed in fastlane -- run 'cd fastlane && bundle install' (gems vendor into fastlane/.vendor; Bundler 4.0.15 is pinned in fastlane/Gemfile.lock)."; exit 1; }
	# 0b) Perspective-pin consistency guard (cheap; runs before the expensive build).
	#     The captured perspective is pinned IN-APP (ScreenshotClock.pin() sets
	#     DayResolver.clockOverride), so it no longer depends on the device date.
	#     Two invariants must hold or the capture is subtly wrong:
	#       (1) the two pins agree: Makefile SCREENSHOT_DATE == ScreenshotClock's;
	#       (2) the pinned day is NOT BEFORE the demo fixture's last logged day,
	#           so no seeded entry falls on a 'future' day the pinned Today cannot
	#           show. (The pinned day MAY be later than the last entry on purpose:
	#           2026-06-30 is a deliberately dry 'today' one day after the last
	#           2026-06-29 drink.) Enforced here so the sources cannot drift.
	pin_kt="$$(sed -n 's/.*SCREENSHOT_DATE[^"]*"\([0-9-]*\)".*/\1/p' "$(SCREENSHOT_PIN_KT)" | head -n1)"
	last_entry="$$(grep -oE '"logicalDate"[[:space:]]*:[[:space:]]*"[0-9]{4}-[0-9]{2}-[0-9]{2}"' "$(DEMO_BACKUP_JSON)" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | sort | tail -n1)"
	newest="$$(printf '%s\n%s\n' "$$last_entry" "$(SCREENSHOT_DATE)" | sort | tail -n1)"
	if [ "$$pin_kt" != "$(SCREENSHOT_DATE)" ]; then
		echo "screenshots-android: capture-date pins disagree -- Makefile SCREENSHOT_DATE='$(SCREENSHOT_DATE)' vs ScreenshotClock.SCREENSHOT_DATE='$$pin_kt'. Align the two and re-run."
		exit 1
	fi
	if [ "$$newest" != "$(SCREENSHOT_DATE)" ]; then
		echo "screenshots-android: capture date '$(SCREENSHOT_DATE)' is BEFORE the demo fixture's last logged day '$$last_entry' -- seeded entries would fall on a future day the pinned Today cannot show. Move SCREENSHOT_DATE to on/after '$$last_entry'."
		exit 1
	fi
	# 1) Build the app + instrumentation APKs that screengrab installs.
	$(MAKE) -C android screenshot-apks
	# 2) Demo Mode is torn down no matter how this recipe exits.
	trap '$(MAKE) screenshots-demo-off-android' EXIT
	# 3) Prepare the device: wake, disable animations, pin clock (and, best-effort,
	#    the device date — the capture PERSPECTIVE itself is already pinned in-app).
	adb shell svc power stayon true
	adb shell input keyevent KEYCODE_WAKEUP
	# Force an exactly-2:1 panel so the captures satisfy Play's aspect rule
	# without any post-processing (see SCREENSHOT_SIZE / SCREENSHOT_DENSITY).
	# Both overrides are sticky and are undone by the EXIT trap's
	# `screenshots-demo-off-android`, which runs even on Ctrl-C or a failed capture.
	adb shell wm size $(SCREENSHOT_SIZE)
	adb shell wm density $(SCREENSHOT_DENSITY)
	adb shell wm dismiss-keyguard
	adb shell settings put global window_animation_scale 0
	adb shell settings put global transition_animation_scale 0
	adb shell settings put global animator_duration_scale 0
	adb shell settings put global auto_time 0 || true
	adb root >/dev/null 2>&1 || true
	adb shell "date $$(date -u -d '$(SCREENSHOT_DATE) 10:00:00' +%m%d%H%M%Y.%S)" || true
	adb shell am broadcast -a android.intent.action.TIME_SET >/dev/null 2>&1 || true
	# Report whether the (best-effort) device-date pin took. `date` is rejected on
	# non-rooted physical devices (the `adb root` above then also fails), so the pin
	# silently no-ops there. This NO LONGER affects the screenshots: the capture
	# perspective is pinned in-app (see ScreenshotClock / DayResolver.clockOverride),
	# so the date-relative screens still render from $(SCREENSHOT_DATE) regardless.
	# The line below is therefore informational only — it never fails the build.
	dev_date="$$(adb shell date +%Y-%m-%d 2>/dev/null | tr -d '\r' || true)"
	if [ "$$dev_date" != "$(SCREENSHOT_DATE)" ]; then
		echo "note: device date is '$$dev_date' (not $(SCREENSHOT_DATE)); the device-date pin needs an emulator/rooted build. Screenshots are unaffected — their date is pinned in-app to $(SCREENSHOT_DATE)."
	fi
	# 4) Enter Android Demo Mode and clean the status bar.
	adb shell settings put global sysui_demo_allowed 1
	adb shell am broadcast -a com.android.systemui.demo -e command enter
	adb shell am broadcast -a com.android.systemui.demo -e command clock        -e hhmm $(SCREENSHOT_CLOCK)
	adb shell am broadcast -a com.android.systemui.demo -e command battery      -e plugged false -e level 100
	adb shell am broadcast -a com.android.systemui.demo -e command network      -e wifi show -e level 4
	adb shell am broadcast -a com.android.systemui.demo -e command network      -e mobile hide
	adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false
	# 5) Clear ONLY the in-app shots 01..06 for every locale before capturing.
	#    screengrab's own clear_previous_screenshots is disabled (see the
	#    Screengrabfile) because it globs and deletes ALL *.png in each
	#    phoneScreenshots/ dir — including the committed report pages 07/08 that
	#    this target does not regenerate. Deleting exactly 01..06 here keeps the
	#    "no stale in-app shot survives a re-run" guarantee without touching the
	#    report pages. The glob nullglob-guards so a locale mid-migration (no old
	#    shots yet) is not an error.
	shopt -s nullglob
	rm -f $(META)/*/images/phoneScreenshots/0[1-6]_*.png
	shopt -u nullglob
	# 6) Capture the six in-app screenshots in every configured locale
	#    (SCREENSHOT_LOCALES, derived from the metadata tree).
	#    The BUNDLED fastlane is mandatory (reproducible, pinned in fastlane/
	#    Gemfile) — install it once with `cd fastlane && bundle install`. It runs
	#    in a SUBSHELL so the `cd fastlane` does not leak into the following steps
	#    or the EXIT trap (which must run from the repository root, otherwise
	#    `$(MAKE) screenshots-demo-off-android` finds no such target).
	( cd fastlane && bundle exec fastlane screenshots )
	# 7) Enforce the Google Play phone-screenshot requirements on the in-app shots.
	#    Only 01..06 are (re)captured here; the report pages 07/08 are owned by
	#    `make report-pdfs` (rendered from the per-locale PDFs, not the device),
	#    which validates them there.
	python3 tools/validate-screenshots.py --in-app $(SCREENSHOT_LOCALES)
	# 8) Cascade: fresh 01..06 feed the feature graphics (their 01_today input just
	#    changed), so rebuild every locale's now-stale graphic ("renew screenshots
	#    -> renew feature graphics"). Routed through the once-per-run guard so a
	#    combined run (`make screenshots-android report-pdfs`, or `store-assets-android`) renders
	#    the graphics only ONCE, not after each producer. feature-graphics is
	#    file-timestamp driven, so unchanged locales are a no-op regardless.
	$(MAKE) _cascade-feature-graphics-android

# Leave Android Demo Mode and restore the normal device state. Each step is
# tolerant (|| true) so tear-down never fails the build; invoked from the
# `screenshots-android` EXIT trap.
#
# The display overrides deserve special mention: `screenshots-android` forces the panel
# to $(SCREENSHOT_SIZE) / $(SCREENSHOT_DENSITY) so every capture is exactly 2:1
# (see the recipe). Those overrides are STICKY — they survive the make run, a
# reboot and, on a physical phone, the rest of the day. Resetting them here (and
# not at the end of the recipe) means a Ctrl-C or a failed capture leaves the
# device usable, exactly like the Demo Mode teardown. `wm size|density reset`
# restores the panel's native values and is a no-op when nothing was overridden.
screenshots-demo-off-android:
	adb shell am broadcast -a com.android.systemui.demo -e command exit || true
	adb shell settings put global sysui_demo_allowed 0 || true
	adb shell wm size reset || true
	adb shell wm density reset || true
	adb shell settings put global auto_time 1 || true
	adb shell settings put global window_animation_scale 1 || true
	adb shell settings put global transition_animation_scale 1 || true
	adb shell settings put global animator_duration_scale 1 || true

# =============================================================================
# REPORT PAGES & FEATURE GRAPHICS  (dependency pipeline)
# =============================================================================

# Render report pages 1 & 2 of the localized PDF into screenshots 07/08, for
# EVERY locale in $(SCREENSHOT_LOCALES). Runs AFTER screengrab (whose
# clear_previous_screenshots wipes only the in-app PNGs 01..06), so these survive.
#
# Report source per locale: the report PDF is named EXACTLY for the store locale,
# $(REPORT_PDF_DIR)/potillus_report_<locale>.pdf -- so `de-DE` uses
# potillus_report_de-DE.pdf, `zh-CN` uses potillus_report_zh-CN.pdf, etc. There is
# deliberately NO base-language/English fallback: a `fr` graphic MUST use the `fr`
# report, and `zh-CN`/`zh-TW` must not collapse onto a shared `zh` PDF. If a
# locale's own PDF is missing that is an error -- run `make report-pdfs` (which
# exports each PDF under that exact name) first.
#
# `-singlefile` makes pdftoppm write exactly <root>.png (no page-number suffix).
#
# DEPENDENCY-DRIVEN PIPELINE: the report pages and feature graphics are proper
# FILE targets, so `make screenshots-pdf-android` / `make feature-graphics-android` rebuild ONLY
# the locales whose inputs actually changed:
#
#   $(REPORT_PDF_DIR)/potillus_report_<locale>.pdf (source PDF; named exactly)
#        |  pdftoppm
#        v
#   $(META)/<loc>/images/phoneScreenshots/07_report_page_1.png   (and 08)
#        |                                    +-- feature-graphic.txt
#        |                                    +-- 01_today.png (from screengrab)
#        v  render-feature-graphic.py         +-- $(FG_SHARED_DEPS)
#   $(META)/<loc>/images/featureGraphic.png <-'
#
# So dropping a newer source PDF makes `make feature-graphics-android` re-rasterize that
# locale's report page AND re-render its feature graphic, with no extra step.

# Per-locale source PDF, named EXACTLY for the store locale. No fallback: 07/08
# depend on this precise file, so a missing per-locale PDF is a hard make error.
report_src = $(REPORT_PDF_DIR)/potillus_report_$(1).pdf

# Shared inputs every feature graphic depends on. The whole tools/fonts/ tree is
# pulled in because the renderer pins fontconfig to it and the badges draw live
# text (DejaVuSans for "GET IT ON", Rokkitt for "F-Droid") -- so DejaVuSans and
# Rokkitt are inputs too, not just Inter/NotoSansCJK. Over-approximated on
# purpose: an unnecessary rebuild is cheap, a MISSED dependency ships a stale asset.
FG_RENDERER    := tools/render-feature-graphic.py
FG_SHARED_DEPS := $(FG_RENDERER) \
                  android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png \
                  fastlane/gpl-v3-logo.svg \
                  $(wildcard fdroid/get-it-on-*.svg) \
                  $(wildcard tools/fonts/*/*)

REPORT_PAGE_PNGS     :=
FEATURE_GRAPHIC_PNGS :=

# ── Per-locale rules, generated for every store locale via $(eval). One canned
# recipe per artifact kind. The two report pages differ only in the page number,
# so a SINGLE parametrized recipe emits both (07 = page 1, 08 = page 2).

# report_page_rule: $(1)=locale  $(2)=sequence (07|08)  $(3)=page number (1|2)
define report_page_rule
$(META)/$(1)/images/phoneScreenshots/$(2)_report_page_$(3).png: $(call report_src,$(1))
	@$(call require-pdftoppm,screenshots-pdf)
	@mkdir -p "$$(@D)"
	@echo "screenshots-pdf-android: $(1) p$(3) <- $$(notdir $$<)"
	@pdftoppm -png -singlefile -r $(SCREENSHOT_PDF_DPI) -f $(3) -l $(3) "$$<" "$$(@:.png=)"
endef

# feature_graphic_rule: $(1)=locale. Grouped target (&:, GNU Make 4.3+) so the
# single renderer call produces BOTH the 1024x500 PNG and its 4K companion.
define feature_graphic_rule
$(META)/$(1)/images/featureGraphic.png $(META)/$(1)/images/featureGraphic-4K.png &: $(META)/$(1)/feature-graphic.txt $(META)/$(1)/images/phoneScreenshots/01_today.png $(META)/$(1)/images/phoneScreenshots/07_report_page_1.png $(FG_SHARED_DEPS)
	@$(call require-rsvg,feature-graphics)
	@$(call require-pillow,feature-graphics)
	@echo "feature-graphics-android: $(1)"
	@python3 $(FG_RENDERER) $(1)
endef

# Instantiate all three rules per locale and collect the outputs.
define potillus_pipeline_rules
$(call report_page_rule,$(1),07,1)
$(call report_page_rule,$(1),08,2)
$(call feature_graphic_rule,$(1))
REPORT_PAGE_PNGS     += $(META)/$(1)/images/phoneScreenshots/07_report_page_1.png $(META)/$(1)/images/phoneScreenshots/08_report_page_2.png
FEATURE_GRAPHIC_PNGS += $(META)/$(1)/images/featureGraphic.png $(META)/$(1)/images/featureGraphic-4K.png
endef
$(foreach loc,$(SCREENSHOT_LOCALES),$(eval $(call potillus_pipeline_rules,$(loc))))

# Device screenshots (01..06) come from `make screenshots-android` (screengrab on a
# device) and have no per-file build rule of their own. If any is MISSING when a
# feature graphic needs it, capture the whole set automatically — screengrab
# always grabs every locale at once, so a missing shot means the set is
# incomplete and one full recapture is the correct repair. This triggers ONLY on
# a truly absent file, never on a merely stale one: staleness of device
# screenshots is not reliably detectable (the project's long-standing reason for
# capturing them by hand), but absence is unambiguous. Because `screenshots-android`
# itself now cascades into `feature-graphics-android` (see that target), the graphics are
# refreshed as part of the same capture.
#
# WHY THE MARKER FILE. If this recipe ran `$(MAKE) screenshots-android` directly, Make
# would fire it once PER missing target — up to 14 full recaptures when a new
# locale set is empty. Every missing screenshot instead order-only-depends on the
# single marker $(SCREENSHOTS_CAPTURED_MARKER), whose recipe runs the one capture
# and is built AT MOST ONCE per `make` invocation; the sentinels then merely
# assert their file now exists. The marker lives under android/app/build/
# (already git-ignored, removed by `make clean`), so a later invocation
# re-checks the tree afresh instead of trusting an earlier run's capture.
SCREENSHOTS_CAPTURED_MARKER := android/app/build/.screenshots-captured

$(SCREENSHOTS_CAPTURED_MARKER):
	$(call require-device,screenshots)
	@echo "feature-graphics-android: device screenshots missing — capturing all locales via 'make screenshots-android'."
	$(MAKE) screenshots-android
	@mkdir -p "$(@D)"
	@touch "$@"

# One sentinel per in-app screenshot kind (01..06): order-only-depend on the
# marker so the capture runs (once) before the file is needed, then assert the
# file is really present afterwards — if the capture did not produce it, fail
# loudly rather than let a downstream renderer read a missing input.
define device_screenshot_sentinel
$(META)/%/images/phoneScreenshots/$(1).png: | $$(SCREENSHOTS_CAPTURED_MARKER)
	@test -f "$$@" || { echo "feature-graphics-android: $$@ still missing after 'make screenshots-android' — capture did not produce it." >&2; exit 1; }
endef
$(foreach shot,01_today 02_calendar 03_statistics 04_drinks 05_add_drink 06_settings,$(eval $(call device_screenshot_sentinel,$(shot))))

# Aggregators: build every locale's outputs but ONLY the stale ones (real file
# prerequisites -> timestamp-driven; an up-to-date tree is a no-op).
screenshots-pdf-android: $(REPORT_PAGE_PNGS)
feature-graphics-android: $(FEATURE_GRAPHIC_PNGS)
# Refresh ONLY the feature graphics already on disk (used by the `debug` build,
# which captures no screenshots): $(wildcard) never lists a locale without a
# featureGraphic.png yet, so this can never trip the 01_today guard above.
feature-graphics-existing-android: $(wildcard $(META)/*/images/featureGraphic.png)

# ── Once-per-run feature-graphics cascade ─────────────────────────────────────
# `screenshots-android` (producer of 01..06) and `report-pdfs` (producer of 07..08) each
# must refresh the feature graphics afterwards — but when BOTH run in one
# invocation (the `store-assets-android` orchestrator, or `make screenshots-android report-pdfs`)
# the graphics must render only ONCE, not after each producer. They are separate
# interactive recipes in separate recursive $(MAKE) subprocesses, so they cannot
# share make's in-process target dedup; a filesystem STAMP coordinates them
# instead. The first cascade in a run renders `feature-graphics-android` and drops the
# stamp; a second cascade in the SAME run sees the stamp and skips. `store-assets-android`
# creates the stamp up front (so neither producer renders early) and does the
# single real render at the end; a lone `make screenshots-android` or `make report-pdfs`
# finds no stamp and renders exactly once itself. The stamp lives under
# android/app/build/ (git-ignored, cleared by `make clean`) and — because
# feature-graphics is file-timestamp driven anyway — the worst case if a stale
# stamp ever survived is a skipped no-op render, never a stale asset.
CASCADE_FG_STAMP := android/app/build/.feature-graphics-cascaded

# Internal: render feature-graphics unless this run already did (or was told to
# defer by store-assets). Not for direct use.
_cascade-feature-graphics-android:
	if [ -f "$(CASCADE_FG_STAMP)" ]; then \
	    echo "feature-graphics-android: already refreshed in this run — skipping duplicate cascade."; \
	else \
	    mkdir -p "$(dir $(CASCADE_FG_STAMP))"; \
	    touch "$(CASCADE_FG_STAMP)"; \
	    $(MAKE) feature-graphics-android; \
	fi

# ── store-assets ── refresh the COMPLETE store-image set in one go: capture the
# in-app screenshots (01..06), export+rasterize the report pages (07..08), then
# render every feature graphic EXACTLY once. Use this instead of running
# `screenshots-android` and `report-pdfs` separately when you want the whole set rebuilt;
# both need a device, and report-pdfs is human-in-the-loop ("Save as PDF").
store-assets-android:
	# Defer both producers' cascades, then do the single real render at the end.
	# The EXIT trap removes the stamp even if a producer aborts, so a stale stamp
	# can never suppress the cascade in a LATER run (belt-and-suspenders — the
	# stamp lives under the git-ignored build dir and feature-graphics is
	# timestamp-driven anyway, so an orphan would cost only one skipped no-op).
	@mkdir -p "$(dir $(CASCADE_FG_STAMP))"
	trap 'rm -f "$(CASCADE_FG_STAMP)"' EXIT
	@touch "$(CASCADE_FG_STAMP)"          # defer: neither producer renders early
	$(MAKE) screenshots-android
#	$(MAKE) report-pdfs
	@rm -f "$(CASCADE_FG_STAMP)"           # arm the single real render
	$(MAKE) _cascade-feature-graphics-android

# ── screenshots-ios ── capture the App Store screenshots on the iOS Simulator.
# The iOS counterpart to `screenshots-android`. Run it from the repo root ON THE
# MAC (the simulator, Xcode and the Homebrew tools are macOS-only). In order it
#   0) pre-flights the tools and materializes the fastlane SnapshotHelper if it is
#      not already vendored (it is git-ignored, one copy per machine),
#   1) (re)generates the buildable Xcode project (`ios-project`),
#   2) drives the fastlane `ios screenshots` lane, which builds the app plus the
#      PotillusUITests target and captures 01..06 into
#      fastlane/screenshots/ios/<locale>/ (configuration in fastlane/Snapfile), then
#   3) renders the two trailing report pages 07..08 so the iOS set matches
#      Android's eight.
#
# The app writes one PDF report per locale DURING the capture (see
# ScreenshotMode.swift) into its Documents container as screenshot_report_<loc>.pdf.
# Step 3 pulls those back out with `simctl get_app_container` and rasterizes them
# with pdftoppm, exactly as screenshots-pdf-android does for the Android report.
#
# IOS_SIM_DEVICE must match the device pinned in fastlane/Snapfile: it names both
# the simulator to query and the "<device>-" filename prefix fastlane prepends to
# every shot, so 07..08 must carry it too or they would sort before 01 instead of
# after 06.
IOS_SIM_DEVICE ?= iPhone 17 Pro
IOS_APP_ID     := de.godisch.potillus
IOS_SHOTS      := fastlane/screenshots/ios
IOS_SCREENSHOT_LOCALES := $(patsubst fastlane/metadata/ios/%/name.txt,%,$(wildcard fastlane/metadata/ios/*/name.txt))

screenshots-ios:
	# A non-interactive `ssh mini make screenshots-ios` gets a minimal PATH, so the
	# Homebrew tools (bundle, xcodegen, pdftoppm, python3) must be put on it first.
	export PATH="/opt/homebrew/bin:$$PATH"
	# 0) Pre-flight the macOS-only tools before any expensive build, mirroring the
	#    screenshots-android checks. xcodegen is verified by `ios-project` itself.
	command -v xcrun  >/dev/null 2>&1 || { echo "screenshots-ios: 'xcrun' not found -- install Xcode and its command-line tools."; exit 1; }
	command -v bundle >/dev/null 2>&1 || { echo "screenshots-ios: 'bundle' (Ruby Bundler) not found -- install Homebrew Ruby + Bundler, then run 'cd fastlane && bundle install'."; exit 1; }
	( cd fastlane && bundle check >/dev/null 2>&1 ) || { echo "screenshots-ios: fastlane gems are not installed -- run 'cd fastlane && bundle install'."; exit 1; }
	$(call require-pdftoppm,screenshots-ios)
	# 0b) The fastlane SnapshotHelper is git-ignored and vendored once per machine by
	#     `fastlane snapshot init`. Create it on first run; `snapshot init` also drops
	#     a sample Snapfile next to it that we do not want (the real one lives in
	#     fastlane/), so remove that again. A SUBSHELL keeps the cd from leaking.
	if [ ! -f ios/PotillusUITests/SnapshotHelper.swift ]; then
	    ( cd ios/PotillusUITests && BUNDLE_GEMFILE=../../fastlane/Gemfile bundle exec fastlane snapshot init )
	    rm -f ios/PotillusUITests/Snapfile ios/PotillusUITests/SnapfileExample
	fi
	# 1) The one command that produces a buildable Xcode project.
	$(MAKE) ios-project
	# 2) Capture 01..06 for every locale. fastlane runs from fastlane/ so it finds
	#    its Snapfile/Appfile; a SUBSHELL keeps the cd from leaking (.ONESHELL).
	( cd fastlane && bundle exec fastlane ios screenshots )
	# 3) Render report pages 07..08 from the PDFs the app left in its data container.
	#    `|| true` guards the lookups so a clean, explained failure replaces the raw
	#    grep/simctl exit under `set -e -o pipefail`.
	UDID="$$(xcrun simctl list devices available | grep -F "$(IOS_SIM_DEVICE) (" | grep -oE '[0-9A-Fa-f-]{36}' | head -n1 || true)"
	if [ -z "$$UDID" ]; then echo "screenshots-ios: no available '$(IOS_SIM_DEVICE)' simulator found."; exit 1; fi
	CONTAINER="$$(xcrun simctl get_app_container "$$UDID" $(IOS_APP_ID) data 2>/dev/null || true)"
	if [ -z "$$CONTAINER" ] || [ ! -d "$$CONTAINER/Documents" ]; then
	    echo "screenshots-ios: no Documents container for $(IOS_APP_ID) on $$UDID -- did the capture install and run the app?"; exit 1
	fi
	for loc in $(IOS_SCREENSHOT_LOCALES); do
	    pdf="$$CONTAINER/Documents/screenshot_report_$$loc.pdf"
	    dir="$(IOS_SHOTS)/$$loc"
	    if [ -f "$$pdf" ]; then
	        mkdir -p "$$dir"
	        pdftoppm -png -singlefile -r $(SCREENSHOT_PDF_DPI) -f 1 -l 1 "$$pdf" "$$dir/$(IOS_SIM_DEVICE)-07_report_page_1"
	        pdftoppm -png -singlefile -r $(SCREENSHOT_PDF_DPI) -f 2 -l 2 "$$pdf" "$$dir/$(IOS_SIM_DEVICE)-08_report_page_2" || echo "screenshots-ios: $$loc report has no page 2" >&2
	        echo "screenshots-ios: $$loc <- report pages 07,08"
	    else
	        echo "screenshots-ios: WARNING no report PDF for $$loc ($$pdf)" >&2
	    fi
	done

# =============================================================================
# REPORT PDF EXPORT  (semi-automatic, human-in-the-loop)
# =============================================================================

# Semi-automatic per-locale PDF report export (feeds screenshots-pdf).
#
#   The 07/08 report pages are rasterized by `screenshots-pdf-android` from per-locale
#   source PDFs `$(REPORT_PDF_DIR)/potillus_report_<locale>.pdf`. Exporting those
#   for 21 locales is tedious, so this target drives the app's export ONCE per
#   locale and leaves only the system "Save as PDF" dialog to you — with the file
#   name PRE-FILLED as potillus_report_<locale>.pdf (see the androidTest class
#   ReportExportTest; production keeps its timestamped name, unchanged).
#
#   FLOW: for each locale the instrumented ReportExportTest opens the print dialog
#   and then BLOCKS until the app is foreground again. You tap "Save as PDF" ->
#   Save (name is pre-filled) into the device Downloads folder; the automation
#   then advances to the next locale. Afterwards the saved PDFs are pulled into
#   $(REPORT_PDF_DIR)/, where the dependency graph picks them up automatically.
#
#   It is a HUMAN-IN-THE-LOOP target: the ReportExportTest is skipped in every
#   other run (a `-e reportExport true` Assume guard), so ordinary `make test` and
#   `make screenshots-android` never open a dialog. Run it explicitly, on a device/emulator
#   whose print stack offers "Save as PDF".
#
#   INSTR is the instrumentation component: the debug applicationId
#   (de.godisch.potillus + the `.debug` suffix from app/build.gradle.kts) plus the
#   `.test` androidTest suffix, with the AndroidX JUnit runner.
INSTR := de.godisch.potillus.debug.test/androidx.test.runner.AndroidJUnitRunner
report-pdfs:
	# A connected device/emulator (state "device") is required; fail fast BEFORE
	# the expensive build below. `set -x` traces the probe so the actual
	# `adb devices` command is visible AT the point it runs -- .ONESHELL echoes the
	# whole recipe once, up front and far from any failure, so the trace (not that
	# echo) is what shows next to the error. grep aborts here if none is ready.
	set -x
	adb devices
	adb devices | grep -qw device
	{ set +x; } 2>/dev/null
	$(MAKE) -C android prereq
	# 1) Build, then (re)install the app + instrumentation APKs. Any prior copy is
	#    removed first so a signature/downgrade mismatch cannot block the install
	#    (that failure prints an empty reason after "Performing Streamed Install"),
	#    and `-t` is required because the instrumentation APK is marked testOnly.
	#    adb's own message is surfaced on failure instead of a bare "Error 1".
	$(MAKE) -C android screenshot-apks
	adb uninstall de.godisch.potillus.debug      >/dev/null 2>&1 || true
	adb uninstall de.godisch.potillus.debug.test >/dev/null 2>&1 || true
	for apk in android/app/build/outputs/apk/debug/app-debug.apk \
	           android/app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk; do \
	    echo "report-pdfs: installing $$(basename "$$apk")"; \
	    out=$$(adb install -t -r "$$apk" 2>&1) || { \
	        echo "report-pdfs: adb install failed for $$apk:"; \
	        printf '%s\n' "$$out" | sed 's/^/    /'; \
	        exit 1; \
	    }; \
	done
	# 2) Keep the screen awake for the interactive run.
	adb shell svc power stayon true
	adb shell input keyevent KEYCODE_WAKEUP
	adb shell wm dismiss-keyguard
	echo
	echo ">>> For EACH locale: tap 'Save as PDF' -> Save (name is pre-filled) into"
	echo ">>> the Downloads folder. The run advances automatically after each save."
	echo
	# 3) Trigger the export once per locale (blocks until you finish the dialog).
	@for loc in $(SCREENSHOT_LOCALES); do \
	    echo "report-pdfs: === $$loc — waiting for your 'Save as PDF' ==="; \
	    adb shell am instrument -w \
	        -e class de.godisch.potillus.screenshot.ReportExportTest \
	        -e reportExport true -e testLocale "$$loc" \
	        $(INSTR) >/dev/null || true; \
	done
	# 4) Pull the saved PDFs from Downloads into $(REPORT_PDF_DIR) (best effort; a
	#    missing file just means that locale was skipped/cancelled — re-run it).
	@mkdir -p "$(REPORT_PDF_DIR)"
	@for loc in $(SCREENSHOT_LOCALES); do \
	    if adb pull "/sdcard/Download/potillus_report_$$loc.pdf" "$(REPORT_PDF_DIR)/potillus_report_$$loc.pdf" >/dev/null 2>&1; then \
	        echo "report-pdfs: pulled potillus_report_$$loc.pdf"; \
	    else \
	        echo "report-pdfs: (no potillus_report_$$loc.pdf in Downloads — skipped?)"; \
	    fi; \
	done
	adb shell svc power stayon false || true
	# 5) Rasterize the two report pages 07/08 from the freshly pulled per-locale
	#    PDFs. This is report-pdfs' OWN half of the screenshot set (01..06 belong
	#    to `make screenshots-android`); screenshots-pdf is file-timestamp driven, so only
	#    locales whose PDF actually changed are re-rendered.
	$(MAKE) screenshots-pdf-android
	# 6) Validate the report pages against Play's phone-screenshot rules.
	python3 tools/validate-screenshots.py --report $(SCREENSHOT_LOCALES)
	# 7) Cascade: fresh 07/08 feed the feature graphics (their 07_report_page_1
	#    input just changed), so rebuild every now-stale graphic ("renew PDFs ->
	#    renew 07/08 -> renew feature graphics"). Via the once-per-run guard, so a
	#    combined screenshots+report-pdfs run renders the graphics only ONCE.
	$(MAKE) _cascade-feature-graphics-android

# =============================================================================
# FONTS
# =============================================================================

# Instantiate the STATIC Rokkitt Bold used for the "F-Droid" wordmark in the
# feature-graphic badge, from the upstream VARIABLE font checked in under
# tools/fonts-src/Rokkitt/. Rationale for this split:
#   * The badge's <text> requests family "Rokkitt" at weight 700. The renderer
#     pins fontconfig to tools/fonts/ ONLY (for reproducibility), so a resolvable
#     STATIC Bold must live there.
#   * A variable font would let freetype/fontconfig pick the 700 instance in a
#     version-dependent way — not reproducible. So the variable source is kept
#     OUTSIDE the scanned dir (tools/fonts-src/) and this target bakes a fixed
#     static instance INTO tools/fonts/Rokkitt/, where the renderer finds it.
# You run this ONCE and COMMIT the generated Rokkitt-Bold.ttf; everyone else then
# renders byte-identically without needing fonttools installed.
ROKKITT_VF  = tools/fonts-src/Rokkitt/Rokkitt[wght].ttf
ROKKITT_OUT = tools/fonts/Rokkitt/Rokkitt-Bold.ttf
rokkitt-bold:
	$(call require-fonttools,rokkitt-bold)
	@test -f "$(ROKKITT_VF)" || { echo "rokkitt-bold: variable source missing: $(ROKKITT_VF) — download Rokkitt[wght].ttf (see tools/fonts-src/Rokkitt/README.txt / COPYING.md)"; exit 1; }
	mkdir -p tools/fonts/Rokkitt
	python3 -m fontTools.varLib.instancer "$(ROKKITT_VF)" wght=700 --update-name-table --output "$(ROKKITT_OUT)"
	cp tools/fonts-src/Rokkitt/OFL.txt tools/fonts/Rokkitt/OFL.txt
	@echo "rokkitt-bold: wrote $(ROKKITT_OUT) — COMMIT it so the feature-graphic build is deterministic for everyone."

# =============================================================================
# PACKAGING & DEPLOY
# =============================================================================

tgz: potillus-$(VERSION).tar.gz

# Release tarball. The set of files to leave out is derived DYNAMICALLY from
# .gitignore instead of being duplicated here, so the two can never drift.
#
# Mapping .gitignore patterns to tar --exclude patterns faithfully needs care:
#   * Comments (# ...), trailing whitespace and blank lines are stripped.
#   * A negation (!pattern) cannot be expressed with tar --exclude, so we abort
#     rather than silently over-exclude. (There are none today.)
#   * git treats a pattern that contains a '/' as anchored to the repo root and
#     one without any '/' as matching at ANY depth. tar's default is the
#     opposite (all patterns float), so we split the list: anchored patterns get
#     the archive's top directory (this repo dir) prepended and are matched with
#     --anchored; the rest are matched with --no-anchored.
#   * tar lets '*' cross '/' by default, which would make e.g. '/*.pdf' (root
#     PDFs only) also swallow nested PDFs; --no-wildcards-match-slash restores
#     git's single-'*'-stays-in-one-segment semantics.
#   * .git itself is not in .gitignore (git implies it), so it is excluded
#     explicitly.
# The two pattern files are written under a mktemp dir OUTSIDE the archived tree
# so they never end up inside the tarball.
potillus-$(VERSION).tar.gz: CHANGELOG.md
	@if grep -q '^[[:space:]]*!' .gitignore; then \
	    echo "tgz: .gitignore has a negation (!) that tar --exclude cannot express — aborting." >&2; \
	    exit 1; \
	fi
	@top=`basename "$$PWD"`; td=`mktemp -d`; \
	clean=`sed -e 's/#.*$$//' -e 's/[[:space:]]*$$//' -e '/^$$/d' .gitignore`; \
	printf '%s\n' "$$clean" | grep '/'    | sed -e 's#^/##' -e "s#^#$$top/#" > "$$td/anchored"   || true; \
	printf '%s\n' "$$clean" | grep -v '/'                                    > "$$td/unanchored" || true; \
	tar czf ../potillus-$(VERSION).tar.gz -C .. \
		--no-wildcards-match-slash \
		--anchored    --exclude="$$top/.git" --exclude-from="$$td/anchored" \
		--no-anchored --exclude-from="$$td/unanchored" \
		"$$top"; \
	rm -rf "$$td"

push:
	git push && git push --tags

# ── push-playstore ── upload the ALREADY-BUILT release AAB to Google Play and
# OVERWRITE the store listing there (localized titles, short/full descriptions,
# feature graphics, screenshots) plus the release notes, from
# fastlane/metadata/android/. The fastlane OPTIONS (track alpha, status
# completed, metadata-overwriting) live in the fastlane `testing` lane, NOT here —
# override them there or via `fastlane testing track:...`.
#
# DELIBERATELY NOT A DEPENDENCY BUILD: this target has NO prerequisites, so it
# never triggers a rebuild of the AAB or SBOM. It FAILS FAST if a precondition
# is missing — the signed AAB, the bundled fastlane, or the Play service-account
# key — so the push only runs against artifacts you built explicitly
# (`make release-android`, or `make -C android bundle`) with credentials in place. Build
# the AAB yourself first; this target purely uploads it.
#
# The credential path mirrors the Appfile: SUPPLY_JSON_KEY if set, else
# fastlane/play-store-credentials.json.
#
# VALIDATE_ONLY=1 makes this a NON-PUBLISHING dry run: fastlane supply validates
# the upload against the Play API without changing anything on Google Play
# (supply's validate_only). Use it to exercise credentials and metadata safely.
# Expected release signing-key fingerprint (SHA-256 of the DER signing
# certificate, bare lowercase hex). SINGLE SOURCE: it is read from SECURITY.md's
# "Verifying releases" section rather than duplicated here, so the pin and the
# document that publishes it to users can never drift. release-check.sh §14
# guards that SECURITY.md carries exactly one such token in canonical (lowercase)
# form, so a reformat is caught at build time instead of at push time. The
# `tr` mirrors the normalization the push targets apply to the MEASURED
# fingerprint, so the comparison stays case-insensitive end to end even if an
# uppercase pin ever slips past the gate. The same key signs
# the Play upload bundle (its role as the Play upload key) and the Codeberg/
# F-Droid release APK, so both publishing targets pin against this one value.
SIGNING_KEY_FINGERPRINT := $(shell grep -oiE '\b[0-9a-f]{64}\b' SECURITY.md | head -1 | tr 'A-F' 'a-f')

# ── push-playstore ── upload the STAGED release bundle to Google Play via the
# fastlane `testing` lane. Never builds or stages (that is `make release-android`); FAILS
# FAST if the staged AAB is missing. Uploads only the staged bundle so the exact
# verified bytes reach Play.
#
# Guards, in order: (1) staged AAB present; (2) release tag v$(VERSION) exists
# locally AND on the push remote -- a RELEASE-HYGIENE gate mirroring push-codeberg
# (Play itself has no notion of git tags), so a build only reaches Play when its
# exact version is a reproducible, pushed tag; (3) the AAB is signed with the
# EXPECTED key. For (3): jarsigner -verify prints "jar verified." for a signed
# archive but returns 0 even for an UNSIGNED one, so grepping the verdict line is
# what fails an unsigned bundle; -strict is avoided (the self-signed upload key
# would trip its chain check and fail a correct bundle); keytool then prints the
# signer SHA-256 (colon/upper), normalized to bare lowercase hex and required to
# equal the pin in SECURITY.md. Then (4) a real PRE-FLIGHT auth check against the
# Play API (validate_play_store_json_key) so a missing/again-misconfigured key or
# revoked access fails HERE, before any metadata is uploaded -- that action logs
# a success line but does NOT raise on failure, so its success line is required
# explicitly. The remote pick uses `|| true` inside the substitution because,
# under `.SHELLFLAGS := -eu -o pipefail`, `git rev-parse @{u}` with no upstream
# would abort the recipe on the assignment before the `${remote:-origin}` fallback
# runs. fastlane runs actions from the PROJECT ROOT (chdir one level up from
# fastlane/), so the staged path passed to the lane's aab: option is
# repo-root-relative -- exactly $(STAGED_AAB), no ../ prefix.
push-playstore:
	# 1) staged AAB must exist (never builds/stages)
	@test -f "$(STAGED_AAB)" || { echo "push-playstore: staged AAB not found at '$(STAGED_AAB)' -- run 'make release-android' first (it builds and stages the bundle). This target does NOT build or stage it." >&2; exit 1; }
	# 2) release tag must exist locally and on the push remote
	@git rev-parse -q --verify "refs/tags/v$(VERSION)" >/dev/null || { echo "push-playstore: git tag 'v$(VERSION)' not found -- create and push it first (git tag -s v$(VERSION) -m 'v$(VERSION)' && make push). This target does NOT create the tag." >&2; exit 1; }
	remote="$$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null | cut -d/ -f1 || true)"; remote="$${remote:-origin}"
	git ls-remote --exit-code --tags "$$remote" "refs/tags/v$(VERSION)" >/dev/null || { echo "push-playstore: tag 'v$(VERSION)' not found on remote '$$remote' -- push it first (make push)." >&2; exit 1; }
	# 3) staged AAB must be signed with the expected key (jarsigner verdict + keytool SHA-256 pin)
	js="$${JARSIGNER:-$$(command -v jarsigner || echo "$${JAVA_HOME:+$$JAVA_HOME/bin/}jarsigner")}"
	"$$js" -verify "$(STAGED_AAB)" | grep '^jar verified\.'
	kt="$${KEYTOOL:-$$(command -v keytool || echo "$${JAVA_HOME:+$$JAVA_HOME/bin/}keytool")}"
	got="$$("$$kt" -printcert -jarfile "$(STAGED_AAB)" | grep -oiE 'SHA-?256:[[:space:]]*[0-9A-F:]+' | sed -E 's/.*SHA-?256:[[:space:]]*//I; s/://g' | tr 'A-F' 'a-f' | sort -u)"
	echo "push-playstore: AAB signer certificate SHA-256: $$got"
	test "$$got" = "$(SIGNING_KEY_FINGERPRINT)"
	@( cd fastlane && bundle check >/dev/null 2>&1 ) || { echo "push-playstore: fastlane gems not installed -- run 'cd fastlane && bundle install'." >&2; exit 1; }
	@key="$${SUPPLY_JSON_KEY:-fastlane/play-store-credentials.json}"; test -f "$$key" || { echo "push-playstore: Play service-account key not found at '$$key' -- place the JSON key there or set SUPPLY_JSON_KEY (see fastlane/Appfile)." >&2; exit 1; }
	# 4) pre-flight: prove the key can actually reach the Play API BEFORE uploading
	#    (the action never raises, so its success line is required explicitly)
	key="$${SUPPLY_JSON_KEY:-fastlane/play-store-credentials.json}"; ( cd fastlane && bundle exec fastlane run validate_play_store_json_key json_key:"$$key" ) | grep -q 'Successfully established connection to Google Play Store' || { echo "push-playstore: the Play service-account key at '$$key' could not connect to the Play API -- check that the service account is invited to the Play Console with 'Manage testing track releases' permission for this app (see fastlane/Appfile)." >&2; exit 1; }
	# 5) upload the staged bundle (repo-root-relative aab: for fastlane's chdir)
	( cd fastlane && bundle exec fastlane testing aab:"$(STAGED_AAB)" $(if $(VALIDATE_ONLY),validate_only:true) )

# ── push-codeberg ── create a Codeberg (Forgejo) release for the ALREADY-PUSHED
# release tag from the command line instead of the web UI, and attach the release
# APK + SBOM. It uses the Forgejo REST API (Gitea-compatible): one GET looks the
# release up by tag, one POST creates it when absent, then the assets are
# uploaded. Title is "Libellus Potionis vX.Y.Z" and the body is the en-US Play
# release notes for this versionCode.
#
# The assets are the STAGED files from releases/ (produced by `make release-android`),
# uploaded under their canonical names releases/<applicationId>_<versionCode>.apk
# and _<versionCode>_sbom.json (e.g. de.godisch.potillus_92.apk). After each
# upload the published asset is re-downloaded from its public release URL and its
# sha256 is diffed against the staged file, so a corrupted upload is caught.
#
# SAFE TO RE-RUN: a previous invocation may have created the release and then
# died on an asset upload (network). The recipe therefore REUSES an existing
# release for the tag instead of failing on Forgejo's duplicate-release 409, and
# it skips any asset that is already attached — so a rerun completes exactly the
# missing steps and never duplicates anything. (The download check runs only for
# assets uploaded in the same run.)
#
# Like push-playstore, this never builds and never stages: `make release-android`
# builds and stages the artifacts. It FAILS FAST if the tag, the staged APK, the
# staged SBOM, the release notes, curl/python3 or the Codeberg token file are
# missing. Build+stage first (`make release-android`) and push the tag first
# (`git tag -s vX.Y.Z ... && make push`); this only publishes.
#
# The Codeberg access token is READ FROM $(CODEBERG_TOKEN_FILE) (Settings ->
# Applications, repository read+write scope). That file is a SECRET, git-ignored
# and never committed -- mirroring the Play service-account key. The recipe's
# commands are echoed (so you can see what runs), but that does NOT leak the
# token: it lives in a SHELL variable -- written $$token in the recipe, i.e. the
# shell's own $token -- read from the file at run time. make expands its own
# make-variables when it echoes a line, but never shell-variables, so the echo
# shows the literal "$token" and never the token VALUE. The token also never
# appears on a curl COMMAND LINE (which any local process could read from
# /proc/<pid>/cmdline while curl runs): it is written into a mode-0600 temp file
# and passed with curl's `-H @file` form (curl >= 7.55; Debian stable qualifies),
# removed again by an EXIT trap.
CODEBERG_API  := https://codeberg.org/api/v1
CODEBERG_REPO := godisch/potillus
CODEBERG_TOKEN_FILE := fastlane/codeberg-credentials.txt
# (VERSION_CODE and the staged/Gradle artifact paths are defined in the "Release
# staging" section above -- the staged files, not the raw Gradle outputs, are
# what this uploads.)
push-codeberg:
	# require curl + python3 (Codeberg REST + JSON encoding)
	command -v curl
	command -v python3
	@test -f "$(CODEBERG_TOKEN_FILE)" || { echo "push-codeberg: token file '$(CODEBERG_TOKEN_FILE)' not found -- create it containing your Codeberg access token (Settings > Applications, repository read+write scope). It is git-ignored." >&2; exit 1; }
	token="$$(tr -d '[:space:]' < "$(CODEBERG_TOKEN_FILE)")"
	@test -n "$$token" || { echo "push-codeberg: token file '$(CODEBERG_TOKEN_FILE)' is empty." >&2; exit 1; }
	# token -> mode-0600 header file (never on argv); removed by the EXIT trap
	hdr="$$(mktemp)"
	trap 'rm -f "$$hdr"' EXIT
	printf 'Authorization: token %s\n' "$$token" > "$$hdr"
	# release tag must exist locally and on the push remote (server resolves the release against it)
	@git rev-parse -q --verify "refs/tags/v$(VERSION)" >/dev/null || { echo "push-codeberg: git tag 'v$(VERSION)' not found -- create and push it first (git tag -s v$(VERSION) -m 'v$(VERSION)' && make push). This target does NOT create the tag." >&2; exit 1; }
	remote="$$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null | cut -d/ -f1 || true)"; remote="$${remote:-origin}"
	git ls-remote --exit-code --tags "$$remote" "refs/tags/v$(VERSION)" >/dev/null || { echo "push-codeberg: tag 'v$(VERSION)' not found on remote '$$remote' -- push it first (make push)." >&2; exit 1; }
	notes="$(META)/en-US/changelogs/$(VERSION_CODE).txt"
	@test -f "$$notes" || { echo "push-codeberg: en-US release notes '$$notes' not found (versionCode $(VERSION_CODE))." >&2; exit 1; }
	# staged, signed APK must exist (canonical name = proof a key was used; never builds/stages)
	apk="$(STAGED_APK)"
	@test -f "$(STAGED_APK)" || { echo "push-codeberg: staged APK not found at '$(STAGED_APK)' -- run 'make release-android' first (it builds and stages the APK). This target does NOT build or stage it." >&2; exit 1; }
	# verify APK signature and pin its signer SHA-256 to SECURITY.md (apksigner from PATH, else ANDROID_HOME build-tools)
	aps="$${APKSIGNER:-$$(command -v apksigner || ls -1 "$${ANDROID_HOME:-$$HOME/android-sdk}"/build-tools/*/apksigner 2>/dev/null | sort -V | tail -1)}"
	"$$aps" verify "$$apk"
	got="$$("$$aps" verify --print-certs "$$apk" | grep -oiE 'SHA-?256 digest:[[:space:]]*[0-9a-f]{64}' | grep -oiE '[0-9a-f]{64}' | tr 'A-F' 'a-f' | sort -u)"
	echo "push-codeberg: APK signer certificate SHA-256: $$got"
	test "$$got" = "$(SIGNING_KEY_FINGERPRINT)"
	@test -f "$(STAGED_SBOM)" || { echo "push-codeberg: staged SBOM not found at '$(STAGED_SBOM)' -- run 'make release-android' first (it builds and stages the SBOM). This target does NOT build or stage it." >&2; exit 1; }
	# 1) look the release up by tag and REUSE it if present (rerun-safe; 404 body = not created yet)
	release_json="$$(curl -sS --proto '=https' --tlsv1.2 -H @"$$hdr" "$(CODEBERG_API)/repos/$(CODEBERG_REPO)/releases/tags/v$(VERSION)" || true)"
	rel_id="$$(printf '%s' "$$release_json" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("id",""))' 2>/dev/null || true)"
	have_assets="$$(printf '%s' "$$release_json" | python3 -c 'import json,sys; d=json.load(sys.stdin); print("\n".join(a.get("name","") for a in d.get("assets") or []))' 2>/dev/null || true)"
	if [ -n "$$rel_id" ]; then
		echo "push-codeberg: release for tag v$(VERSION) already exists (id $$rel_id) -- reusing it"
	else
		# 2) create the release for the existing tag (body = JSON-encoded en-US notes)
		body="$$(python3 -c 'import json,sys; print(json.dumps(open(sys.argv[1], encoding="utf-8").read()))' "$$notes")"
		payload="$$(printf '{"tag_name":"v%s","name":"Libellus Potionis v%s","body":%s,"draft":false,"prerelease":false}' "$(VERSION)" "$(VERSION)" "$$body")"
		rel_id="$$(curl -fsS --proto '=https' --tlsv1.2 -X POST -H @"$$hdr" -H "Content-Type: application/json" -d "$$payload" "$(CODEBERG_API)/repos/$(CODEBERG_REPO)/releases" | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')"
		echo "push-codeberg: created release 'Libellus Potionis v$(VERSION)' (id $$rel_id)"
	fi
	# 3) upload staged APK + SBOM under canonical names, skip already-attached, verify published sha256
	dl_base="https://codeberg.org/$(CODEBERG_REPO)/releases/download/v$(VERSION)"
	for staged in "$$apk" "$(STAGED_SBOM)"; do
		asset="$$(basename "$$staged")"
		if printf '%s\n' "$$have_assets" | grep -qxF "$$asset"; then
			echo "push-codeberg: asset $$asset already attached -- skipping"
			continue
		fi
		curl -fsS --proto '=https' --tlsv1.2 -X POST -H @"$$hdr" -F "attachment=@$$staged" "$(CODEBERG_API)/repos/$(CODEBERG_REPO)/releases/$$rel_id/assets?name=$$asset" >/dev/null
		echo "push-codeberg: attached $$asset"
		# download the published asset and diff its sha256 against the staged file (one 2s retry for endpoint lag)
		want="$$(sha256sum "$$staged" | cut -d' ' -f1)"
		got_dl=""
		for attempt in 1 2; do
			got_dl="$$(curl -fsSL --proto '=https' --tlsv1.2 "$$dl_base/$$asset" | sha256sum | cut -d' ' -f1 || true)"
			[ "$$got_dl" = "$$want" ] && break
			sleep 2
		done
		test "$$got_dl" = "$$want" || { echo "push-codeberg: sha256 mismatch for published asset $$asset (staged $$want, downloaded $$got_dl) -- the upload is corrupt; re-run after deleting the asset on Codeberg." >&2; exit 1; }
		echo "push-codeberg: verified $$asset sha256 $$want"
	done
	echo "push-codeberg: done -> https://codeberg.org/$(CODEBERG_REPO)/releases/tag/v$(VERSION)"

# =============================================================================
# OPENSSF BEST PRACTICES BADGE
# =============================================================================
#
# The project's badge answers live on bestpractices.dev. `.bestpractices.json`
# in the repository root is a version-controlled SNAPSHOT of them, pulled from
# the site's own JSON export (served by bestpractices.dev, so it is independent
# of the code host). This is a one-way mirror site -> repo: answers are edited on
# bestpractices.dev, and this target pulls them into version control. The reverse
# (the badge ingesting a committed .bestpractices.json) is NOT available for
# Codeberg-hosted repositories, and the URL-based proposal path is impractical
# because the server rejects the long URLs the full answer set produces.
BADGE_ID  := 13480
BADGE_URL := https://www.bestpractices.dev/projects/$(BADGE_ID).json

# ── bestpractices-json ── MANUAL, network. Download the badge answers and keep
# only the answered criteria (<name>_status in Met/Unmet/N/A plus the matching
# _justification), sorted, so the committed snapshot diffs meaningfully. Review
# `git diff .bestpractices.json` before committing.
# ios-version: regenerates ios/Version.xcconfig from the project's sources of
# truth (the top CHANGELOG.md entry and the Android versionCode), so the iOS
# build carries the same version as the Android one. Run before `xcodegen
# generate`. `ios-version-check` verifies the file exists and is current, and is
# suitable for a release gate.
ios-version:
	python3 tools/gen-ios-version.py

ios-version-check:
	python3 tools/gen-ios-version.py --check

# ios-project: the one command that produces a buildable Xcode project. The
# `ios-version` prerequisite guarantees Version.xcconfig is regenerated BEFORE
# XcodeGen reads it -- the ordering matters, and getting it wrong is the kind of
# mistake that only surfaces as a wrong version number in the App Store.
# `xcodegen` resolves project.yml relative to the working directory, hence the cd.
ios-project: ios-version ios/Potillus/Resources/copyright.md ios-guides
	command -v xcodegen
	cd ios && xcodegen generate

# The combined copyright/licence document the About screen shows, built from the
# SAME three files Android joins into raw/copyright.md via the SAME renderer, so the
# two platforms show byte-identical text. Generated (gitignored) rather than checked
# in, exactly like Version.xcconfig: a copy in the tree would drift from COPYING.md.
ios/Potillus/Resources/copyright.md: COPYING.md LICENSE.md LICENSE.Apache-2.0.md tools/render-copyright.py
	python3 tools/render-copyright.py $@ COPYING.md LICENSE.md LICENSE.Apache-2.0.md

# The localized in-app user guides, one per language, generated from the
# templates under ios/docs/guide/ with the {{token}} labels resolved against the
# String Catalogue — the iOS counterpart of Android's res/raw-*/usersguide.md.
# Generated (gitignored) like copyright.md above; the app picks the file for its
# in-app language, English as the fallback. Phony because the output set is one
# file per language rather than one fixed name: the renderer rewrites only the
# guides whose template or catalogue entry changed, so a rebuild is a near-no-op.
ios-guides:
	python3 tools/render-guide-ios.py

# The build-time counterpart: fail if any committed template or catalogue change
# would leave a rendered guide stale. Part of the Mac-free iOS static gate.
check-ios-guides:
	python3 tools/render-guide-ios.py --check

# ── ios ── the everyday iOS build, and the counterpart of `android`.
#
# WHY ios-project IS A PREREQUISITE AND NOT A SUGGESTION
#   `ios/project.yml` collects the app's sources with a directory glob, which
#   XcodeGen resolves ONCE, at generation time, and freezes into the .xcodeproj.
#   A newly added file under ios/Potillus/ is therefore invisible to a project
#   generated before it existed, and the build fails with "Cannot find X in
#   scope" — a compile error that looks like a code error and is not one. The
#   package under ios/PotillusKit/ does not suffer from this, because SwiftPM
#   rereads its directory on every build, which is exactly why the mistake only
#   ever surfaces in the app target.
#
#   Making it a prerequisite means the failure cannot recur: the project is
#   regenerated before anything is compiled.
#
# The cheap checks run first: a grep that costs milliseconds should not wait
# behind a Swift build that costs minutes.
# check-ios-static: every iOS gate that needs no Mac — the pure-Python static
# checks. It exists so the LINUX release path can verify iOS too. release-check.sh
# is the Android gate and knows nothing about Swift, and `make ios` cannot run on
# Linux because it ends in `swift test` and `xcodebuild`. Splitting the Mac-free
# checks out lets CI run BOTH `release-check.sh` (Android) and `check-ios-static`
# (iOS) on Linux, while a Mac runs `make ios` for the compile-and-test steps.
# Neither gate alone covers a release; together they do. Each sub-check already
# skips gracefully when its inputs are absent, so this is safe in any checkout.
check-ios-static: check-headers check-makefile check-swift-tests check-swift-symbols \
                  check-swift-length check-report-paper check-l10n-parity check-l10n \
                  check-ios-guides

ios: check-ios-static check-swiftlint ios-project
	# A SUBSHELL, because .ONESHELL runs the whole recipe in one process and a
	# bare `cd` would leak into every step below it -- xcodebuild would then look
	# for ios/Potillus.xcodeproj underneath ios/PotillusKit/. The `screenshots-android`
	# target learned this first; see the note beside its `cd fastlane`.
	( cd ios/PotillusKit && swift test )
	command -v xcodebuild
	# -scheme, not -target, and -destination, not -sdk.
	#
	#   `-target Potillus -sdk iphonesimulator` names no destination, so xcodebuild
	#   cannot compute an active architecture. It then honours ARCHS in full and
	#   builds arm64 AND x86_64 -- while the Swift package's GRDB module is
	#   resolved for one slice only. The build dies with
	#
	#       error: Unable to resolve module dependency: 'GRDB'
	#
	#   which reads like a missing dependency and is really a missing destination.
	#   The `ONLY_ACTIVE_ARCH=YES ... no active architecture could be computed`
	#   warning above it is the actual diagnosis.
	#
	#   `generic/platform=iOS Simulator` fixes one architecture without naming a
	#   simulator device, so the build does not depend on which runtimes happen to
	#   be installed. The Potillus scheme already exists in ios/project.yml.
	xcodebuild \
	    -project ios/Potillus.xcodeproj \
	    -scheme Potillus \
	    -destination 'generic/platform=iOS Simulator' \
	    -configuration Debug \
	    CODE_SIGNING_ALLOWED=NO \
	    build

# ── debug ── the old name of `android`, kept as a shim.
#
# Removing it outright would turn years of muscle memory and every stale README
# into a confusing "No rule to make target". It says so and then does the right
# thing, rather than doing nothing loudly or something silently.
debug:
	@echo "make debug: renamed to 'make android' (this repository now builds two platforms)" >&2
	$(MAKE) android

# check-makefile: catches a bare `cd` inside a .ONESHELL recipe, which silently
# changes the working directory for every line below it. Cost one green test run
# followed by "'ios/Potillus.xcodeproj' does not exist".
check-makefile:
	python3 tools/check-makefile.py

# check-swiftlint: the Swift counterpart to ktlint. Install with
# `brew install swiftlint`.
#
#   PINNED, because SwiftLint changes its rules between releases and a build that
#   is green on one version can be red on the next. The Kotlin side gets this for
#   free through the Gradle plugin; Swift has no such mechanism, so the version is
#   checked here.
#
#   --strict, because a warning nobody must act on is a warning nobody reads.
#
#   REQUIRED, not optional. A target that skips itself when the tool is absent
#   reports success for work it never did.
SWIFTLINT_VERSION := 0.65.0

check-swiftlint:
	command -v swiftlint >/dev/null 2>&1 || { echo "check-swiftlint: swiftlint not found -- install it with 'brew install swiftlint' (version $(SWIFTLINT_VERSION))." >&2; exit 1; }
	@have=$$(swiftlint version); \
	  test "$$have" = "$(SWIFTLINT_VERSION)" || { echo "check-swiftlint: swiftlint $$have found, but this project pins $(SWIFTLINT_VERSION). Rules differ between releases." >&2; exit 1; }
	( cd ios && swiftlint lint --strict --quiet --config .swiftlint.yml )

# check-swift-symbols: catches an invented type (`Backup.parse`, where only
# `BackupReader` and `BackupWriter` exist) and a missing module import (`UTType`
# without UniformTypeIdentifiers). Both are compile errors; both were shipped by
# someone writing Swift on a machine that could not build it. Milliseconds.
check-swift-symbols:
	python3 tools/check-swift-symbols.py

# check-swift-length: SwiftLint's length rules -- type_body_length, file_length,
# line_length -- reproduced in Python, because SwiftLint is a macOS binary and
# cannot run on the Linux gate. An early warning that catches an overrun here,
# with the other static checks, instead of one round-trip later on the Mac; the
# Mac's --strict SwiftLint pass stays the authority for every rule.
check-swift-length:
	python3 tools/check-swift-length.py

# check-report-paper: the report template and the iOS printer both describe one
# sheet of paper, and only one of them is read by the printer. Android's print
# framework honours the template's `@page` margins; UIViewPrintFormatter honours
# nothing but the rectangle it is handed, so ReportPdfPrinter restates them.
#
# Two truths about one thing drift. This one drifted silently: patch -59 printed a
# two-page report on four pages, and nothing warned. Milliseconds to check.
check-report-paper:
	python3 tools/check-report-paper.py

# check-l10n: path (A) — the in-app language picker — only works if every
# user-facing string is looked up against the chosen locale via Loc.string. A
# stray Text("literal") would show in the system language in that one spot,
# producing the half-translated screen the whole mechanism exists to avoid. This
# fails the build on any raw localizable literal in a view.
check-l10n:
	python3 tools/check-l10n.py

# check-l10n-parity: the iOS catalogue is self-contained (the build reads neither
# android/ nor any generator), so this is the anti-drift safety net. It runs in BOTH
# `make ios` and `make android`, reading android/ ONLY to compare: every UI literal
# has a catalogue key, every catalogue translation whose English matches an Android
# string is identical to Android's, and the report labels match Android too.
check-l10n-parity:
	python3 tools/check-l10n-parity.py

# check-swift-tests: catches `await` inside an XCTAssert autoclosure, which the
# Swift compiler rejects but only after a full build -- and which is easy to
# re-introduce. A grep is cheaper than a compile, and runs without a Mac.
#
# It walks the FILE SYSTEM, not `git ls-files`. It used to ask the index, and so
# passed silently over any file not yet added -- which is the state every new
# file is in while it is being written. Patch -39 shipped uncompilable tests
# through that gap.
check-swift-tests:
	python3 tools/check-swift-tests.py

# check-headers: verifies that every project-owned file carries the canonical
# licence header, including the section 7 pointer to the App Store distribution
# exception in COPYING.md. Warnings (a file with no header at all) do not fail;
# a stale header -- GPL notice present, pointer missing -- does. Run
# `make fix-headers` to repair those in place.
check-headers:
	python3 tools/check-headers.py

# fix-headers: inserts the missing section 7 pointer into any header that lacks
# it, reusing that file's own comment leader. Never invents a whole header for
# an unlicensed file; that stays a human decision.
fix-headers:
	python3 tools/check-headers.py --fix

bestpractices-json:
	# curl is required for the download below; a missing curl aborts here.
	command -v curl
	curl -fsSL --proto '=https' --tlsv1.2 "$(BADGE_URL)" | python3 -c 'import json,sys; d=json.load(sys.stdin); a={k[:-7] for k,v in d.items() if k.endswith("_status") and str(v).strip() in {"Met","Unmet","N/A"}}; o={k:v for k,v in d.items() if (k.endswith("_status") and k[:-7] in a) or (k.endswith("_justification") and k[:-14] in a)}; json.dump(dict(sorted(o.items())), open(".bestpractices.json","w",encoding="utf-8"), indent=2, ensure_ascii=False); open(".bestpractices.json","a",encoding="utf-8").write(chr(10)); print("bestpractices-json: %d criteria written"%len(a), file=sys.stderr)'
	@echo "bestpractices-json: review 'git diff .bestpractices.json' before committing."

# =============================================================================
# HOUSEKEEPING
# =============================================================================

clean:
	$(MAKE) -C android $@
	rm -f *.patch *.log *.orig

distclean:
	$(MAKE) -C android $@
	rm -f *.patch *.orig

.PHONY: help android ios debug device-tests release-android release-ios install check-headers fix-headers check-makefile check-swift-tests check-swift-symbols check-swiftlint check-swift-length check-l10n check-l10n-parity ios-version ios-version-check ios-project ios-guides check-ios-guides store-assets-android screenshots-android screenshots-ios screenshots-demo-off-android screenshots-pdf-android feature-graphics-android feature-graphics-existing-android _cascade-feature-graphics-android report-pdfs rokkitt-bold tgz push push-playstore push-codeberg bestpractices-json clean distclean check-report-paper
