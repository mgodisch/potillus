# vim: set noet ts=4 sw=4:
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
#  Makefile -- Libellus Potionis build tooling for Debian GNU/Linux stable
# =============================================================================
#
help:
	@echo "Libellus Potionis build targets:"
	@echo "  make                build debug APK (default)"
	@echo "  make debug          build debug APK"
	@echo "  make release        build release APK (signed if a key is configured, else unsigned)"
	@echo "  make bundle         build release App Bundle/AAB for Google Play (needs signing key)"
	@echo "  make deploy         upload the signed AAB + metadata to Google Play (needs fastlane + key)"
	@echo "  make sbom           generate the CycloneDX SBOM (reproducible JSON)"
	@echo "  make unit-test      run JVM unit tests (no device needed)"
	@echo "  make guides         regenerate the localized user guides"
	@echo "  make check-guides   verify guides and raw/copyright.md are in sync"
	@echo "  make release-check  run the read-only release-readiness gate"
	@echo "  make test-device    run instrumented tests (device/emulator needed)"
	@echo "  make test           run all tests (device needed)"
	@echo "  make screenshots    capture Play-Store screenshots (device + fastlane + poppler)"
	@echo "  make install-debug  install debug APK on device (device needed)"
	@echo "  make install        install debug APK on device (device needed)"
	@echo "  make clean          clear the Gradle build cache"
	@echo "  make dist-clean     clear all non-repo files"
	@echo ""
	@echo "Override the SDK path with:  make ANDROID_HOME=/path/to/android-sdk"
	@echo "Skip the screenshot suite in a device-test run:  make test-device EXCLUDE_SCREENSHOTS=1"
#
#  Every build/test target first ensures Java 21, the Android SDK and the
#  Gradle wrapper are present. Java 21 and Android SDK must be installed
#  manually.
#
#  OVERRIDE THE SDK LOCATION:
#    make ANDROID_HOME=/path/to/android-sdk
#
#  OUTPUT:
#    Debug:        app/build/outputs/apk/debug/app-debug.apk
#    Release APK:  app/build/outputs/apk/release/app-release-unsigned.apk
#                  (or app-release.apk once a release signing key is configured —
#                   see android/keystore.properties.example)
#    Release AAB:  app/build/outputs/bundle/release/app-release.aab  (`make bundle`)
# =============================================================================

# Run each recipe in ONE bash process with strict error handling
SHELL         := /bin/bash
.SHELLFLAGS   := -eu -o pipefail -c
.ONESHELL:
.DEFAULT_GOAL := debug

# ── Pinned tool versions ----------------------------─────────────────────────
JAVA_VERSION  := 21

# ── Android SDK location (override on the command line if desired) ───────────
# ANDROID_HOME can be supplied via the environment or `make ANDROID_HOME=...`;
# otherwise it defaults to ~/android-sdk (a user-owned dir, so no sudo needed).
ANDROID_HOME ?= $(HOME)/android-sdk
export ANDROID_HOME
export ANDROID_SDK_ROOT := $(ANDROID_HOME)
# Put sdkmanager and adb on PATH for every recipe.
export PATH := $(ANDROID_HOME)/cmdline-tools/latest/bin:$(ANDROID_HOME)/platform-tools:$(PATH)
# Compose builds need a larger heap than a default Gradle invocation.
GRADLE_OPTS ?= -Xmx2g -Xms512m
#GRADLE_OPTS += --no-daemon
export GRADLE_OPTS

# Output path of the generated CycloneDX SBOM (see the `sbom` target and the
# cyclonedxDirectBom block in app/build.gradle.kts). Kept under app/build/outputs/
# alongside the APK so a release ships its bill of materials next to the binary.
SBOM := app/build/outputs/sbom/libellus-potionis-sbom.json

# ── Play-Store screenshot pipeline (see the `screenshots` target) ─────────────
# Locales captured; MUST match fastlane/Screengrabfile and the metadata tree.
SCREENSHOT_LOCALES := de-DE en-US
# The demo fixture (fastlane/demo-backup.json) covers 2026-01-01..2026-06-30, so
# the device clock is pinned to the last day of that range to give the
# date-relative "Today" screen meaningful content. (Setting the date needs an
# emulator / rooted userdebug build; on a locked device the step is skipped.)
SCREENSHOT_DATE  := 2026-06-30
# Status-bar clock shown in every shot while Android Demo Mode is active (HHMM).
SCREENSHOT_CLOCK := 1000
# PDF report render resolution. 200 dpi on A4 -> ~1653x2337 px, inside Google
# Play's 320..3840 px / max-2:1 limits (verified by tools/validate-screenshots.py).
SCREENSHOT_PDF_DPI := 200
# Root of the fastlane store-metadata tree (shared by Play `supply` and F-Droid).
META := fastlane/metadata/android

# Optional opt-out of the screenshot suite during a normal instrumented-test run.
# `make test-device EXCLUDE_SCREENSHOTS=1` skips every @ScreenshotOnly test.
# See app/build.gradle.kts (defaultConfig) and app/src/androidTest/.../
# screenshot/ScreenshotOnly.kt for the underlying -PexcludeScreenshotTests switch.
ifeq ($(EXCLUDE_SCREENSHOTS),1)
SCREENSHOT_EXCLUDE_FLAG := -PexcludeScreenshotTests
else
SCREENSHOT_EXCLUDE_FLAG :=
endif

prereq: java android gradlew gradle/wrapper/gradle-wrapper.jar app/src/main/res/raw/copyright.md guides release-check

java:
	test "$(shell java -version 2>&1 | head -1 | sed 's/.*version "\([0-9]*\).*/\1/')" -eq "${JAVA_VERSION}"

android: \
	${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager \
	${ANDROID_HOME}/build-tools \
	${ANDROID_HOME}/platform-tools \
	${ANDROID_HOME}/platforms/android-35 \
	${ANDROID_HOME}/platforms/android-36

# The in-app "Copyright" viewer shows a single bundled document that is the
# concatenation of two project-root files:
#
#     COPYING.md   – the short copyright/licence notice (Markdown)
#     <blank line>
#     LICENSE.md   – the full, verbatim GNU GPL text
#
# The result is written to the DEFAULT raw/ (not locale-qualified) so that
# R.raw.copyright resolves to the same English legal text for every locale: the
# copyright/licence text is deliberately NOT translated.
#
# The `echo` between the two `cat`s emits the single separating blank line. This
# assumes COPYING.md ends with exactly one trailing newline (the repository
# convention); if it did not, the separation would be off by a line.
app/src/main/res/raw/copyright.md: ../COPYING.md ../LICENSE.md
	mkdir -p app/src/main/res/raw
	{ cat ../COPYING.md; echo; cat ../LICENSE.md; } > $@

# Regenerate the localized user guides from their templates in docs/guide/.
# Resolves the {{screen-name}} tokens against the matching strings.xml so the
# in-app res/raw[-xx]/usersguide.md copies can never drift from the labels the
# app actually shows. The language set is discovered from the template files
# (no hard-coded list). Runs on every build (a prerequisite of `prereq`); the
# renderer rewrites an output only when its template or strings.xml is newer, so
# it is a cheap no-op when nothing changed.
guides:
	python3 tools/render-guide.py

# CI helper: fail if the committed guides are not in sync with the templates
# and strings.xml (does not write anything). Also verifies that the generated
# raw/copyright.md matches the current COPYING.md + blank line + LICENSE.md, by
# rebuilding the concatenation into a temporary file and comparing byte-for-byte.
check-guides:
	python3 tools/render-guide.py --check
	tmp=$$(mktemp); { cat ../COPYING.md; echo; cat ../LICENSE.md; } > "$$tmp"; \
	    cmp -s "$$tmp" app/src/main/res/raw/copyright.md; rc=$$?; rm -f "$$tmp"; \
	    test $$rc -eq 0 || { echo "check-guides: raw/copyright.md is stale — run 'make app/src/main/res/raw/copyright.md'"; exit 1; }

# Release gate (moved from android/release-check.sh to tools/release-check.sh).
# It is a pure read-only check of all release invariants (version consistency,
# changelog body, Room migrations, locale three-way sync, source documentation,
# guarded Log calls, no German in source, backup format version, and the
# fastlane changelog coupling). Per project decision it now runs on EVERY build
# as part of `prereq`: any hard FAIL aborts the build (the script exits non-zero
# and `set -e`-style make semantics propagate it). It is invoked with --Werror
# so that warnings are treated as errors too and cannot slip into a build. The
# script self-anchors to the android/ directory, so it can be invoked from here
# regardless of cwd. This single gate also subsumes the former `version-check`
# target: §1 of the script already performs the full version-string consistency
# and fastlane-changelog coupling check, so a separate Make target would only
# duplicate it.
release-check:
	bash tools/release-check.sh --Werror

debug: app/build/outputs/apk/debug/app-debug.apk

app/build/outputs/apk/debug/app-debug.apk: prereq
	./gradlew assembleDebug

# Build the release APK plus its SBOM. This is a PHONY target (not a file target)
# on purpose: once a release signing key is configured (see
# android/keystore.properties.example) the Gradle output is renamed from
# app-release-unsigned.apk to app-release.apk, so hard-coding either filename as
# a Make target would break for the other case. Gradle is itself up-to-date
# aware, so re-running assembleRelease when nothing changed is a cheap no-op.
release: prereq $(SBOM)
	./gradlew assembleRelease
	@echo "Release APK: $$(find app/build/outputs/apk/release -maxdepth 1 -name 'app-release*.apk' | head -1)"

# Build the release Android App Bundle (AAB). Google Play requires the AAB format
# for new apps; F-Droid never uses it. Signed when a release key is configured,
# unsigned otherwise (an unsigned AAB cannot be uploaded to Play, but building it
# is still useful for inspection). The SBOM is generated alongside, mirroring the
# `release` target.
bundle: prereq $(SBOM)
	./gradlew bundleRelease
	@echo "Release AAB: $$(find app/build/outputs/bundle/release -maxdepth 1 -name '*.aab' | head -1)"

# Upload the signed AAB and the store metadata to Google Play via the fastlane
# `deploy` lane (see fastlane/Fastfile). Depends on `bundle` so the AAB is fresh.
# Requires: a configured signing key (keystore.properties / env), the bundled
# fastlane (`cd fastlane && bundle install`), and a Play service-account key
# (fastlane/play-store-credentials.json or $SUPPLY_JSON_KEY — see fastlane/Appfile).
# Runs fastlane in a SUBSHELL so the `cd fastlane` does not leak into make state.
# Override the track/status, e.g.:  make deploy DEPLOY_ARGS="track:internal status:completed"
deploy: bundle
	( cd fastlane && bundle exec fastlane deploy $(DEPLOY_ARGS) )

# Generate a standardized CycloneDX 1.6 JSON SBOM for the release runtime
# classpath (configuration lives in app/build.gradle.kts). Two steps:
#   1. cyclonedxDirectBom writes the SBOM with includeBomSerialNumber=false.
#   2. A post-step removes the volatile metadata.timestamp so the file is
#      byte-stable across identical builds (the Gradle CycloneDX plugin has no
#      reproducible-timestamp option, unlike the Maven plugin). metadata and all
#      of its fields are optional in CycloneDX, so dropping the timestamp leaves
#      a valid BOM. python3 is already a build prerequisite (see `guides`), so
#      this adds no new tooling dependency.
sbom: $(SBOM)

$(SBOM): prereq
	./gradlew :app:cyclonedxDirectBom
	python3 tools/sbom-normalize.py "$(SBOM)"

test: unit-test lint test-device

unit-test: prereq
	REPORT="app/build/reports/tests/testDebugUnitTest/index.html"
	./gradlew testDebugUnitTest

lint: prereq
	./gradlew lintDebug

test-device: prereq
	DEV_COUNT=$$(adb devices 2>/dev/null | grep -cw 'device' || true)
	test "$${DEV_COUNT:-0}" -ne 0
	# Compose UI tests need the host Activity RESUMED and VISIBLE. On a device whose
	# screen is OFF or LOCKED the Activity is immediately paused/stopped (logcat:
	# isSleeping=true) and no Compose hierarchy attaches -> "No compose hierarchies
	# found". Wake the device, keep the screen on, and dismiss a NON-secure keyguard.
	# A secure lock (PIN/pattern/password) cannot be bypassed by adb -- unlock manually.
	adb shell svc power stayon true
	adb shell input keyevent KEYCODE_WAKEUP
	adb shell wm dismiss-keyguard
	REPORT="app/build/reports/androidTests/connected/index.html"
	./gradlew connectedDebugAndroidTest $(SCREENSHOT_EXCLUDE_FLAG)

install: install-debug

install-debug: app/build/outputs/apk/debug/app-debug.apk
	DEV_COUNT=$$(adb devices 2>/dev/null | grep -cw 'device' || true)
	test "$${DEV_COUNT:-0}" -ne 0
	adb install -r $<

# =============================================================================
# PLAY-STORE SCREENSHOTS
# =============================================================================
#   Fully automated capture of the eight Google-Play phone screenshots per
#   locale (de-DE, en-US), placed straight into the fastlane metadata tree:
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
#     * a connected device/emulator with an aspect ratio <= 2:1
#       (e.g. 1080x2160) so the captures satisfy Play's max-2:1 rule;
#     * Ruby + bundler with fastlane installed: `cd fastlane && bundle install`;
#     * poppler-utils (`pdftoppm`) for rendering the PDF report pages.
#     * Pillow (`python3-pil`) for bottom-cropping the in-app shots to <= 2:1.
#
#   Pinning the device date to $(SCREENSHOT_DATE) needs an emulator or a rooted
#   userdebug build; on a locked production device that single step is skipped
#   (|| true) and the "Today" screen simply reflects the real date.
screenshots: prereq
	DEV_COUNT=$$(adb devices 2>/dev/null | grep -cw 'device' || true)
	test "$${DEV_COUNT:-0}" -ne 0
	# 1) Build the app + instrumentation APKs that screengrab installs.
	./gradlew assembleDebug assembleDebugAndroidTest
	# 2) Demo Mode is torn down no matter how this recipe exits.
	trap '$(MAKE) screenshots-demo-off' EXIT
	# 3) Prepare the device: wake, disable animations, pin date/clock.
	adb shell svc power stayon true
	adb shell input keyevent KEYCODE_WAKEUP
	adb shell wm dismiss-keyguard
	adb shell settings put global window_animation_scale 0
	adb shell settings put global transition_animation_scale 0
	adb shell settings put global animator_duration_scale 0
	adb shell settings put global auto_time 0 || true
	adb root >/dev/null 2>&1 || true
	adb shell "date $$(date -u -d '$(SCREENSHOT_DATE) 10:00:00' +%m%d%H%M%Y.%S)" || true
	adb shell am broadcast -a android.intent.action.TIME_SET >/dev/null 2>&1 || true
	# 4) Enter Android Demo Mode and clean the status bar.
	adb shell settings put global sysui_demo_allowed 1
	adb shell am broadcast -a com.android.systemui.demo -e command enter
	adb shell am broadcast -a com.android.systemui.demo -e command clock        -e hhmm $(SCREENSHOT_CLOCK)
	adb shell am broadcast -a com.android.systemui.demo -e command battery      -e plugged false -e level 100
	adb shell am broadcast -a com.android.systemui.demo -e command network      -e wifi show -e level 4
	adb shell am broadcast -a com.android.systemui.demo -e command network      -e mobile hide
	adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false
	# 5) Capture the six in-app screenshots in both locales (de-DE, en-US).
	#    The BUNDLED fastlane is mandatory (reproducible, pinned in fastlane/
	#    Gemfile) — install it once with `cd fastlane && bundle install`. It runs
	#    in a SUBSHELL so the `cd fastlane` does not leak into the following steps
	#    or the EXIT trap (which must run from the android/ dir, otherwise
	#    `$(MAKE) screenshots-demo-off` finds no such target).
	( cd fastlane && bundle exec fastlane screenshots )
	# 6) Bottom-crop the six in-app screenshots to <= 2:1 (removes the Android
	#    navigation bar at the bottom and satisfies Google Play's max-2:1 rule on
	#    tall phones/emulators). The PDF report pages are added in the next step
	#    and are never cropped.
	$(MAKE) screenshots-crop
	# 7) Render the two PDF report pages per locale into the phoneScreenshots dirs.
	$(MAKE) screenshots-pdf
	# 8) Enforce the Google Play phone-screenshot requirements on all eight assets.
	python3 tools/validate-screenshots.py $(SCREENSHOT_LOCALES)

# Bottom-crop the in-app screenshots (01..06) to at most a 2:1 aspect ratio. Runs
# AFTER capture and BEFORE the PDF pages are rendered, so it only ever sees the
# in-app shots; the tool additionally skips any "report" page and any image that
# is already <= 2:1, so re-runs and the PDF pages are safe.
screenshots-crop:
	python3 -c 'import PIL' 2>/dev/null || { echo "screenshots-crop: Pillow not found — install it (Debian: apt install python3-pil, or: pip install pillow --break-system-packages)"; exit 1; }
	python3 tools/crop-screenshots.py $(SCREENSHOT_LOCALES)

# Render report pages 1 & 2 of the localized PDF into screenshots 07/08. Runs
# AFTER screengrab (whose clear_previous_screenshots wipes only the in-app PNGs),
# so these survive. `-singlefile` makes pdftoppm write exactly <root>.png.
screenshots-pdf:
	command -v pdftoppm >/dev/null || { echo "screenshots-pdf: 'pdftoppm' not found — install poppler-utils"; exit 1; }
	pdftoppm -png -singlefile -r $(SCREENSHOT_PDF_DPI) -f 1 -l 1 fastlane/potillus_report_de.pdf $(META)/de-DE/images/phoneScreenshots/07_report_page_1
	pdftoppm -png -singlefile -r $(SCREENSHOT_PDF_DPI) -f 2 -l 2 fastlane/potillus_report_de.pdf $(META)/de-DE/images/phoneScreenshots/08_report_page_2
	pdftoppm -png -singlefile -r $(SCREENSHOT_PDF_DPI) -f 1 -l 1 fastlane/potillus_report_en.pdf $(META)/en-US/images/phoneScreenshots/07_report_page_1
	pdftoppm -png -singlefile -r $(SCREENSHOT_PDF_DPI) -f 2 -l 2 fastlane/potillus_report_en.pdf $(META)/en-US/images/phoneScreenshots/08_report_page_2

# Leave Android Demo Mode and restore the normal device state. Each step is
# tolerant (|| true) so tear-down never fails the build; invoked from the
# `screenshots` EXIT trap.
screenshots-demo-off:
	-adb shell am broadcast -a com.android.systemui.demo -e command exit || true
	-adb shell settings put global sysui_demo_allowed 0 || true
	-adb shell settings put global auto_time 1 || true
	-adb shell settings put global window_animation_scale 1 || true
	-adb shell settings put global transition_animation_scale 1 || true
	-adb shell settings put global animator_duration_scale 1 || true

clean: prereq
	./gradlew clean

distclean: clean
	rm app/src/main/res/raw*/copyright.md
	rm app/src/main/res/raw*/usersguide.md

.PHONY: help prereq release-check java android guides check-guides debug release bundle deploy sbom test unit-test lint test-device screenshots screenshots-crop screenshots-pdf screenshots-demo-off install install-debug clean distclean
