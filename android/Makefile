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
	@echo "  make sbom           generate the CycloneDX SBOM (reproducible JSON)"
	@echo "  make unit-test      run JVM unit tests (no device needed)"
	@echo "  make lint           run ktlint + Android lint (build-breaking)"
	@echo "  make guides         regenerate the localized user guides"
	@echo "  make check-guides   verify guides and raw/copyright.md are in sync"
	@echo "  make release-check  run the read-only release-readiness gate"
	@echo "  make cover-check    release gate + enforce the Kover coverage floor"
	@echo "  make test-device    run instrumented tests (device/emulator needed)"
	@echo "  make test           run all tests (device needed)"
	@echo "  make screenshot-apks  build the debug + androidTest APKs for screenshot capture"
	@echo "  make install-debug  install debug APK on device (device needed)"
	@echo "  make install        install debug APK on device (device needed)"
	@echo "  make clean          clear the Gradle build cache"
	@echo "  make distclean      clear all non-repo files"
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

# Optional opt-out of the screenshot suite during a normal instrumented-test run.
# `make test-device EXCLUDE_SCREENSHOTS=1` skips every @ScreenshotOnly test.
# See app/build.gradle.kts (defaultConfig) and app/src/androidTest/.../
# screenshot/ScreenshotOnly.kt for the underlying -PexcludeScreenshotTests switch.
ifeq ($(EXCLUDE_SCREENSHOTS),1)
SCREENSHOT_EXCLUDE_FLAG := -PexcludeScreenshotTests
else
SCREENSHOT_EXCLUDE_FLAG :=
endif

# prereq gains the guide outputs as ADDITIONAL prerequisites further down, on a
# second dependency line AFTER `-include guides.d` — see the comment there. The
# reference must not appear here: make expands a rule's prerequisite list the
# moment it reads the rule, and at this line GUIDE_OUTPUTS (defined in guides.d)
# is still empty, so `$(GUIDE_OUTPUTS)` written here would silently contribute
# nothing (found in the v0.81.0 QA review with `make -p`).
prereq: java android gradlew gradle/wrapper/gradle-wrapper.jar app/src/main/res/raw/copyright.md release-check

java:
	# Require Java $(JAVA_VERSION). Print the active version first so a mismatch --
	# or a missing java -- is visible instead of a bare, reason-less test failure.
	java -version
	test "$(shell java -version 2>&1 | head -1 | sed 's/.*version "\([0-9]*\).*/\1/')" -eq "${JAVA_VERSION}"

android: \
	${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager \
	${ANDROID_HOME}/build-tools \
	${ANDROID_HOME}/platform-tools \
	${ANDROID_HOME}/platforms/android-35 \
	${ANDROID_HOME}/platforms/android-36

# The in-app "Copyright" viewer shows a single bundled document that is the
# concatenation of three project-root files:
#
#     COPYING.md            – the short copyright/licence notice (Markdown)
#     <blank line>
#     LICENSE.md            – the full, verbatim GNU GPL text
#     <blank line>
#     LICENSE.Apache-2.0.md – the full, verbatim Apache-2.0 text; bundled
#                             because Apache-2.0 §4(a) requires shipping a copy
#                             of the licence alongside the Apache-licensed
#                             runtime libraries compiled into the APK (see the
#                             "Third-Party Software" section of COPYING.md)
#
# The result is written to the DEFAULT raw/ (not locale-qualified) so that
# R.raw.copyright resolves to the same English legal text for every locale: the
# copyright/licence text is deliberately NOT translated.
#
# The concatenation is delegated to tools/render-copyright.py so that this rule,
# its check-guides verification, and the Gradle generateCopyrightDocument task
# all share one generator (the blocks are joined by a Markdown horizontal rule).
app/src/main/res/raw/copyright.md: ../COPYING.md ../LICENSE.md ../LICENSE.Apache-2.0.md ../tools/render-copyright.py
	python3 ../tools/render-copyright.py $@ ../COPYING.md ../LICENSE.md ../LICENSE.Apache-2.0.md

# Regenerate the localized user guides from their templates in docs/guide/,
# resolving the {{screen-name}} tokens against the matching strings.xml so the
# in-app res/raw[-xx]/usersguide.md copies can never drift from the labels the app
# actually shows. The language set is discovered from the template files (no hard-
# coded list).
#
# Each guide is a proper FILE target rather than one blanket phony: render-guide.py
# --make-deps emits, from that same discovery, one `output: template strings.xml
# render-guide.py` rule per language into guides.d. That fragment is auto-
# regenerated whenever a template, a strings.xml or the renderer changes and pulled
# in with `-include`, so make (not a phony that runs every build) decides which
# guides are stale, and `prereq` depends on the real $(GUIDE_OUTPUTS) via the
# second dependency line below (it must come AFTER this include — see there). The
# shared recipe renders on demand; render-guide.py rewrites only the outputs whose
# inputs are newer, so a per-target re-invocation is a cheap near-no-op after the
# first.
-include guides.d

# The guide outputs as prerequisites of `prereq` — as a SECOND dependency line
# (make merges prerequisite lists for the same target), placed after the include
# because prerequisite lists expand immediately: on the `prereq:` rule near the
# top of this file GUIDE_OUTPUTS is not yet defined and would expand to nothing.
# Here the include has run (make rebuilds a missing guides.d and RESTARTS, so on
# the parse that matters the variable is populated) and the dependency is real.
prereq: $(GUIDE_OUTPUTS)

guides.d: $(wildcard docs/guide/usersguide*.md.in) $(wildcard app/src/main/res/values*/strings.xml) ../tools/render-guide.py
	python3 ../tools/render-guide.py --make-deps > $@

# Shared recipe for every guide output (prerequisites come from guides.d above).
# Guarded so the empty-goal parse BEFORE guides.d exists is harmless; make then
# builds guides.d, restarts, and this rule is defined with the populated list.
# render-guide.py writes content-based (it leaves a file untouched when its text
# would not change), which would leave the mtime older than the inputs and make
# the target look perpetually stale -- so `touch` the target to record that it is
# now up to date. The outputs are gitignored, so the touch causes no VCS churn.
ifneq ($(GUIDE_OUTPUTS),)
$(GUIDE_OUTPUTS):
	python3 ../tools/render-guide.py
	touch $@
endif

# Convenience alias: `make guides` builds any stale guide (dependency-driven).
guides: $(GUIDE_OUTPUTS)

# CI helper: fail if the committed guides are not in sync with the templates
# and strings.xml (does not write anything). Also verifies that the generated
# raw/copyright.md matches the current COPYING.md + LICENSE.md +
# LICENSE.Apache-2.0.md concatenation (horizontal-rule separated, via
# tools/render-copyright.py), by rebuilding it into a temporary file and
# comparing byte-for-byte.
check-guides:
	python3 ../tools/render-guide.py --check
	tmp=$$(mktemp); python3 ../tools/render-copyright.py "$$tmp" ../COPYING.md ../LICENSE.md ../LICENSE.Apache-2.0.md; \
	    cmp -s "$$tmp" app/src/main/res/raw/copyright.md; rc=$$?; rm -f "$$tmp"; \
	    test $$rc -eq 0 || { echo "check-guides: raw/copyright.md is stale — run 'make app/src/main/res/raw/copyright.md'"; exit 1; }

# Release gate (tools/release-check.sh, at the repository root; runs from android/).
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
	bash ../tools/release-check.sh --Werror

# Release gate WITH the Kover coverage floor enforced (:app:koverVerify, LINE >= 90
# / BRANCH >= 75). Kept separate from `release-check` (and thus from the
# on-every-build `prereq` path) because it launches Gradle and runs the unit-test
# suite; run it before tagging a release and in CI.
cover-check:
	bash ../tools/release-check.sh --Werror --coverage

debug: app/build/outputs/apk/debug/app-debug.apk

app/build/outputs/apk/debug/app-debug.apk: prereq
	./gradlew assembleDebug

# Build the debug app + instrumentation (androidTest) APKs that fastlane
# screengrab installs. Invoked by the ROOT Makefile's `screenshots` target (which
# runs `prereq` itself first), so this target only drives Gradle; the build must
# run here in android/ where gradlew lives.
screenshot-apks:
	./gradlew assembleDebug assembleDebugAndroidTest

# Build the release APK plus its SBOM. This is a PHONY target (not a file target)
# on purpose: once a release signing key is configured (see
# android/keystore.properties.example) the Gradle output is renamed from
# app-release-unsigned.apk to app-release.apk, so hard-coding either filename as
# a Make target would break for the other case. Gradle is itself up-to-date
# aware, so re-running assembleRelease when nothing changed is a cheap no-op.
release: prereq $(SBOM)
	./gradlew assembleRelease
	@echo "Release APK: $$(find app/build/outputs/apk/release -maxdepth 1 -name 'app-release*.apk' | head -1)"
	@echo "SBOM:        $(SBOM)  (attach to the Codeberg release)"

# Build the release Android App Bundle (AAB). Google Play requires the AAB format
# for new apps; F-Droid never uses it. Signed when a release key is configured,
# unsigned otherwise (an unsigned AAB cannot be uploaded to Play, but building it
# is still useful for inspection). The SBOM is generated alongside, mirroring the
# `release` target.
bundle: prereq $(SBOM)
	./gradlew bundleRelease
	@echo "Release AAB: $$(find app/build/outputs/bundle/release -maxdepth 1 -name '*.aab' | head -1)"
	@echo "SBOM:        $(SBOM)  (attach to the Codeberg release)"

# The former `deploy` target (bundle + fastlane `testing` upload in one step) was
# removed in the v0.81.0 QA review: it duplicated the root Makefile's
# `push-playstore` while bypassing every safeguard that target adds — the
# jarsigner signature check, the signer-fingerprint pin against SECURITY.md and
# the pushed-release-tag guards — and it rebuilt the bundle on the way, against
# the publishing targets' "upload only what you built explicitly" doctrine.
# Upload with `make push-playstore` from the repository root instead (build first
# with `make release` or `make -C android bundle`; dry-run with VALIDATE_ONLY=1).

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
	python3 ../tools/sbom-normalize.py "$(SBOM)"

test: unit-test lint test-device

unit-test: prereq
	REPORT="app/build/reports/tests/testDebugUnitTest/index.html"
	./gradlew testDebugUnitTest

# Static analysis run as part of the default `debug` path (debug -> test -> lint):
# ktlintCheck enforces the Kotlin coding style (it is otherwise only wired into
# Gradle's `check`), and lintDebug runs Android lint. Both are build-breaking here,
# so a style or lint regression fails the everyday build instead of slipping
# through to release time.
lint: prereq
	./gradlew ktlintCheck lintDebug

test-device: prereq
	# A connected device/emulator (state "device") is required. `set -x` traces the
	# probe so the actual `adb devices` command is visible AT the point it runs
	# (.ONESHELL echoes the whole recipe once, up front and far from any failure);
	# grep aborts the recipe here if none is ready.
	set -x
	adb devices
	adb devices | grep -qw device
	{ set +x; } 2>/dev/null
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
	# A connected device/emulator (state "device") is required. `set -x` traces the
	# probe so the actual `adb devices` command is visible AT the point it runs
	# (.ONESHELL echoes the whole recipe once, up front and far from any failure);
	# grep aborts the recipe here if none is ready.
	set -x
	adb devices
	adb devices | grep -qw device
	{ set +x; } 2>/dev/null
	adb install -r $<

clean: prereq
	./gradlew clean

distclean: clean
	rm app/src/main/res/raw*/copyright.md
	rm app/src/main/res/raw*/usersguide.md
	rm -f guides.d

.PHONY: help prereq release-check java android guides check-guides debug release bundle sbom test unit-test lint test-device screenshot-apks install install-debug clean distclean
