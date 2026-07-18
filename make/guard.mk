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
#  guard.mk -- GNU Make version guard, shared by every Makefile in this repo
# =============================================================================
#
#  Included at the top of the root Makefile and of each platform Makefile
#  (android/, ios/). WHY it must be in all of them, and only in one file:
#
#  All three Makefiles declare .ONESHELL and .SHELLFLAGS as load-bearing settings.
#  Both are GNU Make 3.82+ features, and a Make that predates them does NOT error
#  on encountering them -- it silently IGNORES them and runs each recipe line in
#  its own shell WITHOUT the `set -euo pipefail` the recipes assume. The recipe
#  then runs as a weaker program than it is written to be, with no warning. This
#  project additionally uses grouped targets (`&:`, 4.3+) and $(shell ...) calls
#  that contain `#` (which 3.81 mis-parses, truncating the call), so it requires
#  GNU Make 4.x outright.
#
#  Stating the guard ONCE, here, and including it everywhere means no Makefile can
#  run in that silent degraded mode, and the rule lives in a single place instead
#  of being copied into three files that would drift. The syntax below is
#  3.81-safe (only firstword/subst/filter-out), so even a 3.81 that reads this
#  file via `include` evaluates the guard and aborts with a legible message rather
#  than misbehaving further down.
# =============================================================================

# The major version is the first dot-separated field of $(MAKE_VERSION); abort
# when it is 0, 1, 2 or 3 (filter-out leaves the empty string for those, and a
# non-empty number -- so no abort -- for 4 and up).
make_major := $(firstword $(subst ., ,$(MAKE_VERSION)))
ifeq ($(filter-out 0 1 2 3,$(make_major)),)
$(error This project needs GNU Make 4.0 or newer, but you are running $(MAKE_VERSION). On macOS the system 'make' is 3.81; install a current GNU Make (brew install make) and run 'gmake' instead of 'make'.)
endif
