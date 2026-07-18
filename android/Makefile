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
#  Makefile -- Libellus Potionis, Android platform build
# =============================================================================
#
#  Runs from the android/ directory, where the Gradle wrapper lives. `make` (or
#  `make help`) prints the full target list -- the help target below is this
#  file's single source of truth for that list, so this header does not repeat it.
#
#  Java 21 and the Android SDK must be installed manually. Override the SDK path:
#    make ANDROID_HOME=/path/to/android-sdk
# =============================================================================

# GNU Make version guard -- see ../make/guard.mk. Included FIRST because the
# .ONESHELL/.SHELLFLAGS settings below are silently ignored on a Make older than
# 3.82, and this Makefile is also invoked directly (`make -C android ...`).
include ../make/guard.mk

# Strict, single-process recipes -- see the identical block in the root Makefile.
SHELL       := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.ONESHELL:
.DEFAULT_GOAL := help

# The default goal, kept at the top so it doubles as this file's target overview:
# a reader scanning here sees every target, and `make` / `make help` prints the
# same list. Kept ONLY here (not repeated in a header comment) so the two cannot
# drift out of sync.
help:
	@echo "Libellus Potionis -- Android build (run from android/)"
	@echo
	@echo "Build:"
	@echo "  make debug-apk        build the debug APK"
	@echo "  make screenshot-apks  build the debug + androidTest APKs"
	@echo "  make unit-tests       run the JVM unit tests"
	@echo "  make lint             run ktlint + Android lint (build-breaking)"
	@echo "  make format           auto-format the Kotlin sources (ktlint)"
	@echo "  make guides           (re)render the localized user guides"
	@echo "  make check-guides     verify guides + license copies are in sync"
	@echo "Release (artifacts only; gates + staging live in the root):"
	@echo "  make release          build the release APK + SBOM"
	@echo "  make bundle           build the release AAB + SBOM"
	@echo "  make sbom             generate the CycloneDX SBOM only"
	@echo "  make cover-check      enforce the Kover coverage floor (koverVerify)"
	@echo "Housekeeping:"
	@echo "  make clean            remove the Gradle build output (app/build, build)"
	@echo "  make distclean        clean + the sources a build generates into the tree"
	@echo
	@echo "Override the SDK path:  make ANDROID_HOME=/path/to/android-sdk"

# =============================================================================
# CONFIGURATION
# =============================================================================

# Pinned toolchain. JAVA_VERSION must match compileOptions.sourceCompatibility and
# compilerOptions.jvmTarget in app/build.gradle.kts (both JavaVersion.VERSION_21).
JAVA_VERSION := 21

# Android SDK location. Supplied via the environment or `make ANDROID_HOME=...`;
# otherwise defaults to ~/android-sdk (a user-owned dir, so no sudo is needed).
# sdkmanager and adb are put on PATH for every recipe.
ANDROID_HOME ?= $(HOME)/android-sdk
export ANDROID_HOME
export ANDROID_SDK_ROOT := $(ANDROID_HOME)
export PATH := $(ANDROID_HOME)/cmdline-tools/latest/bin:$(ANDROID_HOME)/platform-tools:$(PATH)
# Compose builds need a larger heap than a default Gradle invocation.
GRADLE_OPTS ?= -Xmx2g -Xms512m
export GRADLE_OPTS

# =============================================================================
# BUILD PREREQUISITES
# =============================================================================
#
# `prereq` is the shared build prerequisite every build target depends on. It
# asserts the toolchain (java, SDK, Gradle wrapper) and materializes the generated
# sources a build reads (the bundled license copies and the localized guides). It
# holds ONLY what a build consumes. It gains the guide outputs as an ADDITIONAL
# prerequisite further down, on a second dependency line AFTER `-include guides.d`
# -- see the comment there for why it cannot be listed here.
prereq: java android gradle-wrapper $(LICENSE_OUTPUTS)

# Require Java $(JAVA_VERSION). The active version is printed first (informational)
# and parsed from a captured copy -- a here-string, not a pipe, so `-o pipefail`
# cannot trip on a SIGPIPE from an early-closing reader. The major is taken via the
# leading non-digits (`[^0-9]*`) rather than by matching the quoted version token,
# which keeps the recipe's double-quotes balanced (an odd count throws off editor
# syntax highlighting).
java:
	@out="$$(java -version 2>&1)" || { echo "java: 'java' not found -- install a JDK $(JAVA_VERSION)." >&2; exit 1; }
	printf '%s\n' "$$out"
	v="$$(sed -n '1s/[^0-9]*\([0-9]*\).*/\1/p' <<< "$$out")"
	test "$$v" = "$(JAVA_VERSION)" || { echo "java: need Java $(JAVA_VERSION), found '$$v'." >&2; exit 1; }

# Assert the Android SDK is installed with the components a compileSdk=36 build
# needs. These are installed manually (no auto-download), so a missing one fails
# here with an actionable message instead of the cryptic "No rule to make target"
# the previous bare-prerequisite form produced. Only android-36 is required:
# compileSdk and targetSdk are both 36 (app/build.gradle.kts); the SDK-35 mention
# there is a dependency-version comment, not an installed-platform requirement.
android:
	@missing=0
	for p in \
	    "$(ANDROID_HOME)/cmdline-tools/latest/bin/sdkmanager" \
	    "$(ANDROID_HOME)/platform-tools" \
	    "$(ANDROID_HOME)/build-tools" \
	    "$(ANDROID_HOME)/platforms/android-36"; do
	    if [ ! -e "$$p" ]; then echo "android: missing SDK component: $$p" >&2; missing=1; fi
	done
	if [ "$$missing" -ne 0 ]; then
	    echo "android: install the Android SDK (compileSdk=36) under '$(ANDROID_HOME)'," >&2
	    echo "android:   or point make at it: make ANDROID_HOME=/path/to/android-sdk" >&2
	    echo "android:   e.g. sdkmanager platform-tools 'platforms;android-36' 'build-tools;<version>'" >&2
	    exit 1
	fi

# The Gradle wrapper is committed, so this normally passes; the check turns a
# missing/damaged wrapper into a named error rather than a bare exec failure.
gradle-wrapper:
	@test -x ./gradlew || { echo "gradle-wrapper: ./gradlew is missing or not executable in android/." >&2; exit 1; }
	test -f gradle/wrapper/gradle-wrapper.jar || { echo "gradle-wrapper: gradle/wrapper/gradle-wrapper.jar is missing (the committed wrapper)." >&2; exit 1; }

# =============================================================================
# GENERATED SOURCES (bundled license copies + localized user guides)
# =============================================================================

# The in-app About screen links to verbatim license texts, one bundled document
# per license, each a byte-for-byte copy of a project-root file (a plain `cp`):
#   raw/license_gpl3.md    <- LICENSE.md            (the app's own license)
#   raw/license_apache2.md <- LICENSE.Apache-2.0.md (Apache-2.0 libraries in the APK)
#   raw/license_gpl2.md    <- LICENSE.GPL-2.0.md    (desugar_jdk_libs, GPL-2.0+CE)
# res/raw/ is not tracked (every file in it is generated), so a fresh clone lacks
# the directory -- hence the `mkdir -p` before each copy.
LICENSE_OUTPUTS := \
	app/src/main/res/raw/license_gpl3.md \
	app/src/main/res/raw/license_apache2.md \
	app/src/main/res/raw/license_gpl2.md

app/src/main/res/raw/license_gpl3.md: ../LICENSE.md
	@mkdir -p $(@D)
	cp $< $@

app/src/main/res/raw/license_apache2.md: ../LICENSE.Apache-2.0.md
	@mkdir -p $(@D)
	cp $< $@

app/src/main/res/raw/license_gpl2.md: ../LICENSE.GPL-2.0.md
	@mkdir -p $(@D)
	cp $< $@

# Localized user guides. render-guide.py resolves the {{screen-name}} tokens in
# docs/guide/usersguide*.md.in against the matching strings.xml, so the in-app
# res/raw[-xx]/usersguide.md copies can never drift from the labels the app shows.
#
# Each guide is a real FILE target, not one blanket phony: `render-guide.py
# --make-deps` emits one `output: template strings.xml render-guide.py` rule per
# language into guides.d, so make -- not a phony that runs every build -- decides
# which guides are stale. guides.d is auto-regenerated whenever a template, a
# strings.xml or the renderer changes, and pulled in with `-include`.
-include guides.d

# The guide outputs as prerequisites of `prereq` -- on a SECOND dependency line,
# placed AFTER the include: make expands a prerequisite list the moment it reads
# the rule, and on the `prereq:` rule above $(GUIDE_OUTPUTS) is not yet defined and
# would expand to nothing. Here the include has run (make rebuilds a missing
# guides.d and RESTARTS, so on the parse that matters the variable is populated).
prereq: $(GUIDE_OUTPUTS)

guides.d: $(wildcard docs/guide/usersguide*.md.in) $(wildcard app/src/main/res/values*/strings.xml) ../tools/render-guide.py
	python3 ../tools/render-guide.py --make-deps > $@

# Shared recipe for every guide output (prerequisites come from guides.d). Guarded
# so the empty-goal parse BEFORE guides.d exists is harmless. render-guide.py
# writes content-based (it leaves a file untouched when its text would not change),
# which would leave the mtime older than the inputs and make the target look
# perpetually stale -- so `touch` records that it is now up to date. The outputs
# are git-ignored, so the touch causes no VCS churn.
ifneq ($(GUIDE_OUTPUTS),)
$(GUIDE_OUTPUTS):
	python3 ../tools/render-guide.py
	touch $@
endif

# Convenience alias: build any stale guide (dependency-driven).
guides: $(GUIDE_OUTPUTS)

# CI helper: fail if the committed guides are out of sync with the templates and
# strings.xml (writes nothing), and verify each bundled raw/license_*.md still
# matches its project-root source byte-for-byte. A copy that does not exist YET is
# not stale -- nothing has drifted, the build simply has not run -- so it is
# reported and skipped, not failed (which used to break a fresh clone).
check-guides:
	python3 ../tools/render-guide.py --check
	for pair in \
	    "license_gpl3.md:../LICENSE.md" \
	    "license_apache2.md:../LICENSE.Apache-2.0.md" \
	    "license_gpl2.md:../LICENSE.GPL-2.0.md"; do
	    out="app/src/main/res/raw/$${pair%%:*}"
	    src="$${pair#*:}"
	    if [ ! -f "$$out" ]; then
	        echo "check-guides: $$out not built yet -- 'make $$out' will create it"
	        continue
	    fi
	    cmp -s "$$src" "$$out" || { echo "check-guides: $$out is stale -- run 'make $$out'" >&2; exit 1; }
	done

# =============================================================================
# BUILD
# =============================================================================

debug-apk: app/build/outputs/apk/debug/app-debug.apk

app/build/outputs/apk/debug/app-debug.apk: prereq
	./gradlew assembleDebug

# The debug app + instrumentation (androidTest) APKs that screengrab installs and
# that the report-pdf export drives. Depends on `prereq` so `make -C android
# screenshot-apks` is self-sufficient (the previous split relied on the caller
# running prereq first, which a direct invocation would skip).
screenshot-apks: prereq
	./gradlew assembleDebug assembleDebugAndroidTest

unit-tests: prereq
	./gradlew testDebugUnitTest

# ktlintCheck enforces the Kotlin style (otherwise only wired into Gradle's
# `check`); lintDebug runs Android lint. Both are build-breaking here, so a style
# or lint regression fails the everyday build instead of slipping to release time.
lint: prereq
	./gradlew ktlintCheck lintDebug

# Auto-format the Kotlin sources in place (the writing counterpart of `lint`'s
# ktlintCheck). Configuring the ktlint task still configures the Android project,
# so the SDK/wrapper/JDK must be present -- but not the full prereq: you run
# `format` to fix the tree, not to gate it.
format: java gradle-wrapper android
	./gradlew ktlintFormat

# =============================================================================
# RELEASE  (build the release artifacts + SBOM; gates/staging live in the root)
# =============================================================================
#
# These build the RELEASE artifacts. The release GATES (invariants, coverage,
# screenshot/PDF presence) and the staging into releases/ live one level up, in the
# root's `release-android` (make/release.mk), which calls these. Signed when a
# release key is configured in the Gradle build, unsigned otherwise.

# The reproducible CycloneDX SBOM for the release runtime. cyclonedxDirectBom writes
# it deterministically (see the cyclonedxDirectBom block in app/build.gradle.kts);
# sbom-normalize.py drops the one remaining non-deterministic field, so identical
# builds produce byte-identical SBOMs.
SBOM := app/build/outputs/sbom/libellus-potionis-sbom.json

sbom: $(SBOM)

$(SBOM): prereq
	./gradlew :app:cyclonedxDirectBom
	python3 ../tools/sbom-normalize.py "$(SBOM)"

# release: the release APK (F-Droid and direct install). bundle: the release AAB
# (Google Play requires the bundle format for new apps). Both carry the SBOM as a
# prerequisite so it is produced alongside the artifact.
release: prereq $(SBOM)
	./gradlew assembleRelease
	@echo "Release APK: $$(find app/build/outputs/apk/release -maxdepth 1 -name 'app-release*.apk' | head -1)"
	@echo "SBOM:        $(SBOM)"

bundle: prereq $(SBOM)
	./gradlew bundleRelease
	@echo "Release AAB: $$(find app/build/outputs/bundle/release -maxdepth 1 -name '*.aab' | head -1)"
	@echo "SBOM:        $(SBOM)"

# cover-check: the Kover coverage gate -- runs the unit tests and enforces the floor
# configured in app/build.gradle.kts (koverVerify: LINE >= 90 / BRANCH >= 75). Kept
# a PURE coverage target (just :app:koverVerify, not the whole release-check) so the
# release path can gate coverage per platform: the iOS counterpart -- an xccov-based
# `cover-check` in ios/Makefile -- will slot in beside it (see docs/ROADMAP.md).
cover-check: prereq
	./gradlew :app:koverVerify

# =============================================================================
# HOUSEKEEPING
# =============================================================================

# clean removes the build OUTPUT by DELETING the output directories directly,
# rather than invoking `./gradlew clean`. Every artifact this project produces --
# APK, AAB, CycloneDX SBOM, and every test/lint/coverage report -- lives under
# app/build/, so removing that (plus the top-level Gradle project build/ dir)
# clears them all, with no JVM, SDK or Gradle configuration required. It also
# matches how the iOS side cleans (a plain rm -rf).
#
# Deliberately NOT removed: the Gradle/Kotlin tool caches (.gradle/, .kotlin/) --
# expensive-to-refill caches, not this project's output. Both are git-ignored and
# re-created on demand; delete them by hand for a true cold start.
clean:
	rm -rf app/build build

# distclean additionally removes the sources a build GENERATES into the tree, so
# the working copy returns to its fresh-clone state. Each is git-ignored, so
# removing it loses nothing. `rm -f` (not a bare `rm`) is deliberate for the guide
# glob: raw*/usersguide.md matches nothing in a tree that never rendered the
# guides, and a bare `rm` on the then-unexpanded pattern would abort under `set -e`.
distclean: clean
	rm -f app/src/main/res/raw/license_gpl3.md
	rm -f app/src/main/res/raw/license_apache2.md
	rm -f app/src/main/res/raw/license_gpl2.md
	rm -f app/src/main/res/raw*/usersguide.md
	rm -f guides.d

.PHONY: help prereq java android gradle-wrapper guides check-guides \
        debug-apk screenshot-apks unit-tests lint format \
        sbom release bundle cover-check clean distclean
