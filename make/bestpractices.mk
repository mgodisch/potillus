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
#  bestpractices.mk -- Libellus Potionis, OpenSSF badge maintenance (included by
#  ./Makefile)
# =============================================================================
#
#  A root-level INCLUDE, not a standalone Makefile: it inherits the root's
#  .ONESHELL and `.SHELLFLAGS -eu -o pipefail`, so the single recipe below runs as
#  one strict bash process.
#
#  The project's OpenSSF badge answers live on bestpractices.dev; the committed
#  .bestpractices.json is the maintainer's source of truth for them. Because
#  bestpractices.dev cannot ingest a file from a Codeberg-hosted repository,
#  keeping the site in step with the committed answers is a manual transcription.
#
#  `make bestpractices` supports exactly that: it downloads the current site
#  export, reduces it to the tracked shape with the SAME filter that produced the
#  committed file (tools/filter-bestpractices.py), and hands both to
#  tools/diff-bestpractices.py, which prints -- WITHOUT writing anything -- the
#  criteria whose answer the site does not yet match, grouped by badge level. The
#  read-only, level-consistency sibling `check-bestpractices-levels` lives in
#  make/checks.mk; the level map both tools share is tools/bestpractices-levels.json.
# =============================================================================

BADGE_ID  := 13480
BADGE_URL := https://www.bestpractices.dev/projects/$(BADGE_ID).json
# Project base for the pre-filled edit links (note the /en/ and no .json); the tool
# appends /<section>/edit?... per criterion.
EDIT_BASE := https://www.bestpractices.dev/en/projects/$(BADGE_ID)
# Git-ignored output page (repository root).
HTML_OUT  := bestpractices-upstream.html

# bestpractices: MANUAL, network. Write an HTML page ($(HTML_OUT)) listing the
# committed badge answers that still differ from what bestpractices.dev publishes;
# each entry links to that criterion's section edit form (anchored at the criterion)
# and shows the committed status plus a Copy-the-justification button, so the
# maintainer transcribes them upstream by hand -- the site does not pre-fill an
# already-answered field from the URL. Read-only w.r.t. the answers: the download
# lands in a temporary file (removed on exit) and neither .bestpractices.json nor the
# working tree is touched (the output page is git-ignored). The curl flags pin HTTPS
# and TLS 1.2; -o pipefail (inherited) fails the recipe if the download fails rather
# than diffing an empty body. The text report and the --check gate remain available by
# running the tool directly.
bestpractices:
	@upstream="$$(mktemp)"
	trap 'rm -f "$$upstream"' EXIT
	curl -fsSL --proto '=https' --tlsv1.2 "$(BADGE_URL)" | python3 tools/filter-bestpractices.py > "$$upstream"
	python3 tools/diff-bestpractices.py --html --edit-base "$(EDIT_BASE)" "$$upstream" > "$(HTML_OUT)"
	echo "bestpractices: wrote $(HTML_OUT) -- open it in a browser and click through the listed criteria to enter them upstream."

.PHONY: bestpractices
