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

VERSION = $(shell grep '^## v' CHANGELOG.md | head -n 1 | cut -c5-)

# Run each recipe in ONE bash process with strict error handling
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.ONESHELL:
.DEFAULT_GOAL := default

default:
	adb devices | grep -q 'device$$'
	$(MAKE) -C android clean
	$(MAKE) -C android debug 2>&1 | tee ../build.log
	$(MAKE) -C android test  2>&1 | tee ../test.log
	$(MAKE) install

install: /home/godisch/FRITZ/USB-SanDisk3-2Gen1-01/Martin/Downloads/potillus-$(VERSION)-debug.apk

/home/godisch/FRITZ/USB-SanDisk3-2Gen1-01/Martin/Downloads/potillus-$(VERSION)-debug.apk: android/app/build/outputs/apk/debug/app-debug.apk
	cp $< $@

# Capture the eight Google-Play phone screenshots per locale. Delegates to the
# android/ Makefile, which drives Android Demo Mode, Fastlane screengrab and the
# PDF-report rendering. See `make -C android help` for prerequisites and the
# EXCLUDE_SCREENSHOTS switch.
screenshots:
	$(MAKE) -C android screenshots
	$(MAKE) -C android feature-graphics

tgz: potillus-$(VERSION).tar.gz

potillus-$(VERSION).tar.gz: CHANGELOG.md
	tar czf ../potillus-$(VERSION).tar.gz -C .. \
		--exclude .git \
		--exclude .gradle \
		--exclude .kotlin \
		--exclude .bundle \
		--exclude .vendor \
		--exclude build \
		--exclude short \
		--exclude TODO.md \
		--exclude keystore.properties \
		--exclude play-store-credentials.json \
		potillus

push:
	git push && git push --tags

clean:
	$(MAKE) -C android $@
	rm -f *.patch *.log *.orig

distclean:
	$(MAKE) -C android $@
	rm -f *.patch *.orig

.PHONY: default install screenshots tgz push clean distclean
