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

VERSION = $(shell grep '^## v' android/CHANGELOG.md | head -n 1 | cut -c5-)

default:
	@echo make default does nothing

install: /home/godisch/FRITZ/USB-SanDisk3-2Gen1-01/Martin/Downloads/potillus-$(VERSION)-debug.apk

/home/godisch/FRITZ/USB-SanDisk3-2Gen1-01/Martin/Downloads/potillus-$(VERSION)-debug.apk: potillus/app/build/outputs/apk/debug/app-debug.apk
	cp $< $@

tgz: distclean potillus-$(VERSION).tar.gz

potillus-$(VERSION).tar.gz: potillus/CHANGELOG.md
	cd ..
	test ! -e potillus-$(VERSION)
	mv potillus potillus-$(VERSION)
	tar czf potillus-$(VERSION).tar.gz --exclude .gradle --exclude .kotlin --exclude android/app/build potillus-$(VERSION)
	mv potillus-$(VERSION) potillus
	cd potillus

clean:
	$(MAKE) -C android $@
	rm -f *.patch *.orig

distclean:
	$(MAKE) -C android $@
	rm -f *.patch *.orig

.PHONY: default install tgz clean distclean
