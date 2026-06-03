# vim: set noet ts=4 sw=4:
# =============================================================================
# Libellus Potionis "Potillus" -- Privacy-Friendly Alcohol Tracker
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
#  Makefile -- Potillus build tooling for Debian GNU/Linux stable
# =============================================================================
#
help:
	@echo "Libellus Potionis build targets:"
	@echo "  make                build debug APK (default)"
	@echo "  make debug          build debug APK"
	@echo "  make release        build release APK (unsigned)"
	@echo "  make unit-test      run JVM unit tests (no device needed)"
	@echo "  make guides         regenerate the localized user guides"
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

# Run each recipe in ONE bash process with strict error handling, mirroring the
# former build.sh "set -euo pipefail".
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
export GRADLE_OPTS

prereq: version-check java android gradlew gradle/wrapper/gradle-wrapper.jar app/src/main/res/raw/license.md guides

java:
	test "$(shell java -version 2>&1 | head -1 | sed 's/.*version "\([0-9]*\).*/\1/')" -eq "${JAVA_VERSION}"

android: \
	${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager \
	${ANDROID_HOME}/build-tools \
	${ANDROID_HOME}/platform-tools \
	${ANDROID_HOME}/platforms/android-35 \
	${ANDROID_HOME}/platforms/android-36

# LICENSE.md is shown verbatim by the in-app "License" viewer. It is NOT
# translated and NOT locale-qualified: always the project-root LICENSE.md,
# copied to the default raw/ so R.raw.license resolves to it for every locale.
app/src/main/res/raw/license.md: ../LICENSE.md
	mkdir -p app/src/main/res/raw
	cp -a $< $@

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
# and strings.xml (does not write anything).
check-guides:
	python3 tools/render-guide.py --check
	cmp -s ../LICENSE.md app/src/main/res/raw/license.md

# Version consistency. The app version is written in several places that must
# all match the top-most "## vX.Y.Z" entry in ../CHANGELOG.md (the single source of
# truth): build.gradle.kts versionName, the app/proguard-rules.pro header, and
# the ../README.md title. This guards against the drift that previously left
# build.gradle.kts on a stale versionName. Runs on every build via `prereq`.
# (release-check.sh §1 performs the same comparison for the release gate; this is
# the fast local pre-build equivalent.)
version-check:
	@ref=$$(grep -m1 '^## v' ../CHANGELOG.md | sed 's/^## v//; s/[[:space:]]*$$//')
	if [ -z "$$ref" ]; then echo "version-check: no '## vX.Y.Z' entry found in ../CHANGELOG.md"; exit 1; fi
	gradle=$$(grep 'versionName' app/build.gradle.kts | grep -v 'Suffix' | grep -oE '"[^"]+"' | head -1 | tr -d '"')
	proguard=$$(grep -E '^# Version:' app/proguard-rules.pro | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
	readme=$$(grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' ../README.md | head -1 | tr -d 'v')
	fail=0
	for entry in "build.gradle.kts versionName:$$gradle" "app/proguard-rules.pro header:$$proguard" "../README.md title:$$readme"; do
	    where=$${entry%%:*}; got=$${entry##*:}
	    if [ "$$got" != "$$ref" ]; then
	        echo "version-check: MISMATCH in $$where — found '$$got', expected '$$ref' (top of ../CHANGELOG.md)"
	        fail=1
	    fi
	done
	if [ "$$fail" -ne 0 ]; then echo "version-check: bring every location in sync with the ../CHANGELOG, then rebuild."; exit 1; fi
	echo "version-check: all version strings consistent at $$ref"

debug: app/build/outputs/apk/debug/app-debug.apk

app/build/outputs/apk/debug/app-debug.apk: prereq
	./gradlew assembleDebug --no-daemon

release: app/build/outputs/apk/release/app-release-unsigned.apk

app/build/outputs/apk/release/app-release-unsigned.apk: prereq
	./gradlew assembleRelease --no-daemon

test: unit-test test-device

unit-test: prereq
	REPORT="app/build/reports/tests/testDebugUnitTest/index.html"
	./gradlew testDebugUnitTest --no-daemon

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
	./gradlew connectedDebugAndroidTest --no-daemon

install: install-debug

install-debug: app/build/outputs/apk/debug/app-debug.apk
	DEV_COUNT=$$(adb devices 2>/dev/null | grep -cw 'device' || true)
	test "$${DEV_COUNT:-0}" -ne 0
	adb install -r $<

clean: prereq
	./gradlew clean --no-daemon

distclean: clean
	rm app/src/main/res/raw*/license.md
	rm app/src/main/res/raw*/usersguide.md

.PHONY: help prereq version-check java android guides check-guides debug release test unit-test test-device install install-debug clean distclean
