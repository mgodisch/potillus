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
#  Makefile -- Libellus Potionis, iOS platform build
# =============================================================================
#
#  Runs from the ios/ directory, where XcodeGen, xcodebuild and SwiftPM operate.
#  `make` (or `make help`) prints the full target list -- the help target below is
#  this file's single source of truth for that list, so this header does not repeat
#  it. The build/test/lint targets need macOS (the Xcode toolchain); they assert
#  this and fail cleanly off it.
# =============================================================================

# GNU Make version guard -- see ../make/guard.mk. Included FIRST because the
# .ONESHELL/.SHELLFLAGS settings below are silently ignored on a Make older than
# 3.82, and this Makefile is also invoked directly (`make -C ios ...`).
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
	@echo "Libellus Potionis -- iOS build (run from ios/)"
	@echo
	@echo "Project generation (do this first):"
	@echo "  make project       generate the Xcode project (xcodegen) [needs xcodegen]"
	@echo "  make version       regenerate Version.xcconfig from CHANGELOG + versionCode"
	@echo "  make version-check verify Version.xcconfig is current (read-only)"
	@echo "  make guides        (re)render the localized user guides"
	@echo "  make check-guides  verify the rendered guides are in sync (read-only)"
	@echo "Build / test / lint (need macOS):"
	@echo "  make build         compile the app (xcodebuild, Debug)"
	@echo "  make swift-tests   run the PotillusKit unit tests (swift test)"
	@echo "  make cover-check   enforce the PotillusKit line-coverage floor ($(IOS_COVERAGE_MIN_LINE)%)"
	@echo "  make lint          run SwiftLint (--strict, pinned $(SWIFTLINT_VERSION))"
	@echo "  make format        auto-format the Swift sources (swiftlint --fix)"
	@echo "Housekeeping:"
	@echo "  make clean         remove the Xcode/SwiftPM build output"
	@echo "  make distclean     clean + the sources a build generates into the tree"
	@echo
	@echo "Full first-build walkthrough: ../docs/INSTALL-IOS.md"

# =============================================================================
# CONFIGURATION
# =============================================================================

# SwiftLint is PINNED: it changes its rules between releases, so a tree that is
# green on one version can be red on the next. The Kotlin side gets this via the
# Gradle ktlint plugin; Swift has no such mechanism, so the version is checked here.
SWIFTLINT_VERSION := 0.65.0

# The line-coverage floor the iOS coverage gate (cover-check) enforces over
# PotillusKit's OWN sources -- the iOS counterpart of Android's Kover LINE bound.
# Set to the OpenSSF silver target (test_statement_coverage80). Treat it as a
# ratchet: raise it as coverage grows, never lower it. Branch coverage is a
# gold-tier goal and is not measurable from this swift-test path -- see
# docs/ROADMAP.md. `?=` so a spot-check can probe another value without editing.
IOS_COVERAGE_MIN_LINE ?= 80

# =============================================================================
# PROJECT GENERATION (the iOS counterpart of Android's build prerequisites)
# =============================================================================

# version: regenerate Version.xcconfig from the project's sources of truth -- the
# top CHANGELOG.md entry (MARKETING_VERSION) and the Android versionCode
# (CURRENT_PROJECT_VERSION) -- so the iOS build carries the same version as
# Android. gen-ios-version.py self-anchors to the repository root, so it runs
# correctly from ios/. Run before `xcodegen generate` (see `project`).
version:
	python3 ../tools/gen-ios-version.py

# version-check: verify Version.xcconfig exists and is current, writing nothing.
# Read-only, suitable for a release gate.
version-check:
	python3 ../tools/gen-ios-version.py --check

# The verbatim GPLv3 text the About screen's "License" chapter links to: a plain
# copy of the project root's LICENSE.md, the same file Android copies into its
# raw/, so the two platforms show byte-identical text. Generated (git-ignored)
# rather than committed, like Version.xcconfig -- a copy in the tree would drift
# from LICENSE.md. Resources/ is not tracked (every file in it is generated), so
# `mkdir -p` creates it after a fresh clone.
#
# ONE file here, THREE on Android: the iOS app bundles only the GPLv3, the only
# license it must reproduce -- its single third-party dependency, GRDB, has its
# short MIT text inline in the About screen. Android additionally bundles the
# Apache-2.0 and GPL-2.0 texts for the libraries compiled into the APK.
Potillus/Resources/license_gpl3.md: ../LICENSE.md
	@mkdir -p $(@D)
	cp $< $@

# guides: the localized in-app user guides, one per language, rendered from the
# templates under ios/docs/guide/ with the {{token}} labels resolved against the
# String Catalogue -- the iOS counterpart of Android's res/raw-*/usersguide.md.
# Generated (git-ignored). Phony because the output set is one file per language
# rather than one fixed name; render-guide-ios.py rewrites only the guides whose
# template or catalogue entry changed, so a rebuild is a near-no-op.
guides:
	python3 ../tools/render-guide-ios.py

# check-guides: fail if a committed template or catalogue change would leave a
# rendered guide stale. READ-ONLY -- it judges, never renders. A guide not rendered
# YET is not stale (the normal state of a fresh clone), so absence is reported, not
# failed.
check-guides:
	python3 ../tools/render-guide-ios.py --check

# project: the one command that produces a buildable Xcode project. `version`,
# the license copy and `guides` are prerequisites so Version.xcconfig and the
# bundled resources are current BEFORE XcodeGen reads project.yml -- getting the
# version ordering wrong surfaces only as a wrong number in the App Store.
#
# WHY project IS A PREREQUISITE (of build, below), NOT A SUGGESTION: project.yml
# collects the app's sources with a directory glob, which XcodeGen resolves ONCE
# and freezes into the .xcodeproj. A file added under Potillus/ after generation is
# invisible to the frozen project and fails to compile ("Cannot find X in scope").
# Regenerating before every build makes that impossible.
#
# xcodegen resolves project.yml relative to the working directory, which is ios/
# here -- so no `cd` is needed (unlike the old root Makefile, which cd'd in).
project: version Potillus/Resources/license_gpl3.md guides
	@command -v xcodegen >/dev/null || { echo "project: 'xcodegen' not found -- install it (brew install xcodegen)." >&2; exit 1; }
	xcodegen generate

# =============================================================================
# BUILD / TEST / LINT  (the iOS counterpart of Android's build layer)
# =============================================================================
#
# All four targets below need macOS: xcodebuild and swiftlint are macOS-only, and
# the app and its UI tests need Xcode. `require-macos` is a PREREQUISITE (not a
# recipe line) so it fires before any work -- e.g. before `build` regenerates the
# project -- and fails cleanly off macOS instead of a cryptic "command not found"
# deeper in a recipe. (`swift test` could in principle run on Linux, but this
# project's workflow is macOS-only and treats PotillusKit's tests so.)
require-macos:
	@test "$$(uname -s)" = "Darwin" || { echo "This target needs macOS (the Xcode toolchain); host is $$(uname -s)." >&2; exit 1; }

# build: compile the app in Debug -- the iOS counterpart of Android's debug-apk.
# The xcodebuild invocation is non-obvious and deliberate:
#   -scheme (not -target) + -destination 'generic/platform=iOS Simulator' name a
#   destination so xcodebuild computes ONE active architecture. `-target ... -sdk
#   iphonesimulator` names none, builds arm64 AND x86_64, then fails to resolve the
#   GRDB Swift-package module for the second slice -- an error that reads like a
#   missing dependency but is really a missing destination. CODE_SIGNING_ALLOWED=NO
#   because a plain compile needs no signing identity.
build: require-macos project
	@command -v xcodebuild >/dev/null 2>&1 || { echo "build: 'xcodebuild' not found -- install Xcode and its command-line tools." >&2; exit 1; }
	xcodebuild \
	    -project Potillus.xcodeproj \
	    -scheme Potillus \
	    -destination 'generic/platform=iOS Simulator' \
	    -configuration Debug \
	    CODE_SIGNING_ALLOWED=NO \
	    build

# swift-tests: the PotillusKit unit tests -- the device-free counterpart of
# Android's unit-tests. (The app-target XCTests that need a simulator are the
# counterpart of Android's device tests, in a later revision.) A SUBSHELL keeps the
# `cd` from leaking under .ONESHELL; PotillusKit is a SwiftPM package resolved from
# its own directory.
swift-tests: require-macos
	@command -v swift >/dev/null 2>&1 || { echo "swift-tests: 'swift' not found -- install the Swift/Xcode toolchain." >&2; exit 1; }
	( cd PotillusKit && swift test )

# cover-check: the iOS coverage gate -- the counterpart of Android's :app:koverVerify.
# It runs the PotillusKit suite with coverage (command-line, NO simulator) and
# enforces the LINE floor (IOS_COVERAGE_MIN_LINE) over the kit's own sources via
# tools/check-ios-coverage.py, which filters to /Sources/PotillusKit/ exactly as the
# manual measurement does. Line-only -- branch coverage is a gold-tier goal not
# available from this swift-test/llvm-cov path (see docs/ROADMAP.md). Kept a PURE
# coverage target so the root `cover-check` gates both platforms symmetrically.
cover-check: require-macos
	@command -v swift >/dev/null 2>&1 || { echo "cover-check: 'swift' not found -- install the Swift/Xcode toolchain." >&2; exit 1; }
	( cd PotillusKit && \
	    swift test --enable-code-coverage && \
	    python3 ../../tools/check-ios-coverage.py \
	        "$$(swift test --enable-code-coverage --show-codecov-path)" \
	        --min-line $(IOS_COVERAGE_MIN_LINE) )

# swiftlint-check: assert swiftlint is present AND is the pinned version, so a
# newer swiftlint with changed rules cannot silently pass or fail the lint below.
swiftlint-check:
	@command -v swiftlint >/dev/null 2>&1 || { echo "swiftlint: not found -- install it (brew install swiftlint), version $(SWIFTLINT_VERSION)." >&2; exit 1; }
	have="$$(swiftlint version)"
	test "$$have" = "$(SWIFTLINT_VERSION)" || { echo "swiftlint: version $$have found, but this project pins $(SWIFTLINT_VERSION) (rules differ between releases)." >&2; exit 1; }

# lint: SwiftLint in --strict mode -- the iOS counterpart of Android's lint. Runs
# from ios/ (this Makefile's directory), where .swiftlint.yml and the sources live,
# so no cd is needed.
lint: require-macos swiftlint-check
	swiftlint lint --strict --quiet --config .swiftlint.yml

# format: auto-fix what SwiftLint can -- the writing counterpart of lint and the
# iOS counterpart of Android's format. Same pinned version, same config.
format: require-macos swiftlint-check
	swiftlint --fix --config .swiftlint.yml

# =============================================================================
# HOUSEKEEPING
# =============================================================================

# clean removes the build OUTPUT. build/ holds the xcarchive, the exported .ipa,
# the generated ExportOptions.plist and the iOS SBOM; PotillusKit/.build and
# PotillusKit/.swiftpm are SwiftPM's own caches from `swift test`. Every path is
# git-ignored (see ios/.gitignore), which is why a plain rm -rf of them is safe.
clean:
	rm -rf build
	rm -rf PotillusKit/.build PotillusKit/.swiftpm

# distclean additionally removes everything a build GENERATES into the source
# tree, so the working copy returns to its fresh-clone state. Each is produced by
# a target above (or by the screenshot capture in a later revision), and each is
# git-ignored:
#   Version.xcconfig                     <- version
#   Potillus.xcodeproj                   <- project (xcodegen)
#   Potillus/Resources/license_gpl3.md   <- the license copy
#   Potillus/Resources/usersguide_*.md   <- guides
#   PotillusUITests/SnapshotHelper.swift <- vendored by the screenshot capture
distclean: clean
	rm -f Version.xcconfig
	rm -rf Potillus.xcodeproj
	rm -f Potillus/Resources/license_gpl3.md
	rm -f Potillus/Resources/usersguide_*.md
	rm -f PotillusUITests/SnapshotHelper.swift

.PHONY: help require-macos swiftlint-check version version-check project guides cover-check \
        check-guides build swift-tests lint format clean distclean
