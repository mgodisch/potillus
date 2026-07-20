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
#  checks.mk -- Libellus Potionis, static checks (included by ./Makefile)
# =============================================================================
#
#  A root-level INCLUDE, not a standalone Makefile: the check tools self-anchor to
#  the repository root, so they run from here regardless of cwd. Every target below
#  is a read-only, DEVICE-FREE check that runs on any host (Linux included) -- which
#  is the whole point: the Linux release path can verify the shared invariants AND
#  everything about iOS that does not need a Mac. The Mac-only SwiftLint pass lives
#  in ios/Makefile as `lint`, and the Android release gate (tools/release-check.sh)
#  is wired in a later revision; neither is duplicated here.
#
#  Each check writes NOTHING (fix-headers is the sole, explicit exception) and
#  fails loudly on a violation, so any of them is safe to run at any time.
# =============================================================================

# =============================================================================
# REPO-WIDE CHECKS (cross-cutting; neither platform-specific)
# =============================================================================

# check-headers: every project-owned file carries the canonical license header.
check-headers:
	python3 tools/check-headers.py

# check-makefile: no bare `cd` leaks under .ONESHELL, across ALL makefiles and
# make/*.mk fragments (the tool discovers them itself; see tools/check-makefile.py).
check-makefile:
	python3 tools/check-makefile.py

# check-report-paper: the report template's page geometry and the iOS
# ReportPdfPrinter must describe the SAME sheet of paper. Two truths about one
# thing drift silently otherwise (a two-page report once printed on four).
check-report-paper:
	python3 tools/check-report-paper.py

# check-l10n: fail if a view holds a user-facing string literal not routed through
# `Loc.string` -- such a literal would show in the system language, defeating the
# in-app language picker in that one spot.
check-l10n:
	python3 tools/check-l10n.py

# check-l10n-parity: the Android strings.xml, the iOS String Catalogue and the
# report label catalogue must stay in parity -- a key present in one and missing in
# another is a half-translated screen waiting to happen.
check-l10n-parity:
	python3 tools/check-l10n-parity.py

# check-ui-string-parity: the allow-list of views that carry fixed English literals
# BY DESIGN (not catalogue keys) must stay in sync -- the companion to check-l10n,
# which would otherwise flag those intentional literals.
check-ui-string-parity:
	python3 tools/check-ui-string-parity.py

# check-bestpractices-levels: the OpenSSF .bestpractices criteria map is complete
# and consistent (every criterion mapped to a level).
check-bestpractices-levels:
	python3 tools/check-bestpractices-levels.py

# check-vex: every advisory ignored in osv-scanner.toml has a matching statement
# in openvex.json, so the scanner's triage is always also recorded in the VEX
# document (OSPS-VM-04.02). Passes trivially while both are empty.
check-vex:
	python3 tools/check-vex.py

# =============================================================================
# iOS STATIC CHECKS (Mac-free; reproduce on Linux what the Mac would catch)
# =============================================================================

# check-swift-symbols: catch an invented Swift type or a missing module import --
# compile errors shipped by someone writing Swift on a machine that cannot build it.
check-swift-symbols:
	python3 tools/check-swift-symbols.py

# check-swift-length: SwiftLint's length rules (type_body/file/line) reproduced in
# Python, so an overrun is caught here with the other static checks instead of one
# Mac round-trip later; the Mac's --strict SwiftLint pass stays the authority.
check-swift-length:
	python3 tools/check-swift-length.py

# check-swift-tests: catch a Swift test that wraps `await` inside an XCTest
# assertion (e.g. XCTAssertEqual(await x, y)) in a way XCTest mishandles.
check-swift-tests:
	python3 tools/check-swift-tests.py

# check-ios-metadata: the App Store metadata is present and within Apple's limits
# for every locale.
check-ios-metadata:
	python3 tools/check-ios-metadata.py

# check-ios-screenshots: every iOS screenshot is a real, accepted App Store device
# size (Apple accepts only exact resolutions where Play accepts a range).
check-ios-screenshots:
	python3 tools/check-ios-screenshots.py

# check-ios-a11y: the iOS views carry the accessibility annotations the app relies on.
check-ios-a11y:
	python3 tools/check-ios-a11y.py

# =============================================================================
# CONVENIENCE (the only writing target here)
# =============================================================================

# fix-headers: rewrite any file whose license header is missing or wrong -- the
# writing counterpart of check-headers.
fix-headers:
	python3 tools/check-headers.py --fix

# =============================================================================
# AGGREGATES
# =============================================================================

# check-ios-static: every Mac-free check relevant to an iOS release -- the shared
# invariants plus the iOS-specific static checks -- so the LINUX release path can
# verify iOS without a Mac. The guide freshness check lives in ios/Makefile (its
# renderer and templates are there), so it is invoked as a sub-make rather than
# duplicated. release-check.sh is the Android counterpart; together they cover a
# release, neither alone.
check-ios-static: check-headers check-makefile check-swift-tests check-swift-symbols \
                  check-swift-length check-report-paper check-l10n-parity check-l10n \
                  check-ios-metadata check-ios-screenshots check-ios-a11y
	$(MAKE) -C ios check-guides

# release-check: the full read-only invariant gate (tools/release-check.sh) run in
# one shot -- the Android counterpart of the per-check tools above: version
# consistency, changelog, room migrations, locale/doc sync, log guards, headers,
# backup version, markdown, metadata lengths, reproducible-build hygiene, third-party
# notices, a11y labels and the signing-key fingerprint. `--Werror` turns warnings
# into errors. It is NOT a per-build gate (the everyday build gates on lint and
# check-guides alone); run it here during development, and `release-android` runs it
# with --release before an artifact is staged.
release-check:
	bash tools/release-check.sh --Werror

# check-static: every device-free check in one go -- check-ios-static plus the two
# repo-wide checks it does not include (the UI-literal allow-list and the OpenSSF
# levels map). The broadest "is the tree consistent?" gate that needs no device,
# no Mac and no network.
check-static: check-ios-static check-ui-string-parity check-bestpractices-levels check-vex

.PHONY: check-headers check-makefile check-report-paper check-l10n check-l10n-parity \
        check-ui-string-parity check-bestpractices-levels check-vex check-swift-symbols \
        check-swift-length check-swift-tests check-ios-metadata check-ios-screenshots \
        check-ios-a11y fix-headers release-check check-ios-static check-static
