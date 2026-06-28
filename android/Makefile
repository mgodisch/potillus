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
	@echo "  make release        build release APK (unsigned)"
	@echo "  make sbom           generate the CycloneDX SBOM (reproducible JSON)"
	@echo "  make unit-test      run JVM unit tests (no device needed)"
	@echo "  make guides         regenerate the localized user guides"
	@echo "  make check-guides   verify guides and raw/copyright.md are in sync"
	@echo "  make release-check  run the read-only release-readiness gate"
	@echo "  make test-device    run instrumented tests (device/emulator needed)"
	@echo "  make test           run all tests (device needed)"
	@echo "  make install-debug  install debug APK on device (device needed)"
	@echo "  make install        install debug APK on device (device needed)"
	@echo "  make clean          clear the Gradle build cache"
	@echo "  make dist-clean     clear all non-repo files"
	@echo ""
	@echo "Override the SDK path with:  make ANDROID_HOME=/path/to/android-sdk"
#
#  Every build/test target first ensures Java 21, the Android SDK and the
#  Gradle wrapper are present. Java 21 and Android SDK must be installed
#  manually.
#
#  OVERRIDE THE SDK LOCATION:
#    make ANDROID_HOME=/path/to/android-sdk
#
#  OUTPUT:
#    Debug:   app/build/outputs/apk/debug/app-debug.apk
#    Release: app/build/outputs/apk/release/app-release-unsigned.apk
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

release: app/build/outputs/apk/release/app-release-unsigned.apk $(SBOM)

app/build/outputs/apk/release/app-release-unsigned.apk: prereq
	./gradlew assembleRelease

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
	./gradlew connectedDebugAndroidTest

install: install-debug

install-debug: app/build/outputs/apk/debug/app-debug.apk
	DEV_COUNT=$$(adb devices 2>/dev/null | grep -cw 'device' || true)
	test "$${DEV_COUNT:-0}" -ne 0
	adb install -r $<

clean: prereq
	./gradlew clean

distclean: clean
	rm app/src/main/res/raw*/copyright.md
	rm app/src/main/res/raw*/usersguide.md

.PHONY: help prereq release-check java android guides check-guides debug release sbom test unit-test lint test-device install install-debug clean distclean
