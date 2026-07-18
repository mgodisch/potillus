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
#  This is a NEW file: until now the iOS housekeeping lived in the root Makefile
#  as clean-ios/distclean-ios, which left Android with its own Makefile but iOS
#  without one. It now lives with the platform it cleans. The tooling is rebuilt
#  one target group at a time; THIS revision defines HOUSEKEEPING only.
#
#  TARGETS IN THIS REVISION
#    help       (default) print this list and do nothing else
#    clean      build OUTPUT (build/, the SwiftPM caches)
#    distclean  clean + the GENERATED SOURCES a build creates into the tree
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

help:
	@echo "Libellus Potionis -- iOS build (run from ios/)"
	@echo
	@echo "Housekeeping (this revision):"
	@echo "  make clean      remove the Xcode/SwiftPM build output"
	@echo "  make distclean  clean + the sources a build generates into the tree"

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
# an iOS target added in a later revision, and each is git-ignored:
#   Version.xcconfig                     <- generated from CHANGELOG.md + versionCode
#   Potillus.xcodeproj                   <- xcodegen, from project.yml
#   Potillus/Resources/license_gpl3.md   <- copy of ../LICENSE.md
#   Potillus/Resources/usersguide_*.md   <- the rendered localized user guides
#   PotillusUITests/SnapshotHelper.swift <- vendored from the installed fastlane
distclean: clean
	rm -f Version.xcconfig
	rm -rf Potillus.xcodeproj
	rm -f Potillus/Resources/license_gpl3.md
	rm -f Potillus/Resources/usersguide_*.md
	rm -f PotillusUITests/SnapshotHelper.swift

.PHONY: help clean distclean
