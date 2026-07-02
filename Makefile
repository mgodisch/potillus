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

# ── Play-Store screenshot pipeline (see the `screenshots` target) ─────────────
# Locales captured; MUST match fastlane/Screengrabfile and the metadata tree.
SCREENSHOT_LOCALES := de-DE en-US
# The demo fixture (fastlane/demo-backup.json) covers 2026-01-01..2026-06-30, so
# the device clock is pinned to the last day of that range to give the
# date-relative "Today" screen meaningful content. (Setting the date needs an
# emulator / rooted userdebug build; on a locked device the step is skipped.)
SCREENSHOT_DATE  := 2026-06-30
# Status-bar clock shown in every shot while Android Demo Mode is active (HHMM).
SCREENSHOT_CLOCK := 1000
# PDF report render resolution. 200 dpi on A4 -> ~1653x2337 px, inside Google
# Play's 320..3840 px / max-2:1 limits (verified by tools/validate-screenshots.py).
SCREENSHOT_PDF_DPI := 200
# Root of the fastlane store-metadata tree (shared by Play `supply` and F-Droid).
META := fastlane/metadata/android

# =============================================================================
# PLAY-STORE SCREENSHOTS
# =============================================================================
#   Fully automated capture of the eight Google-Play phone screenshots per
#   locale (de-DE, en-US), placed straight into the fastlane metadata tree:
#
#     01_today  02_calendar  03_statistics   (LIGHT) ─┐ captured in-app by the
#     04_drinks 05_add_drink 06_settings     (DARK)  ─┘ screengrab/Espresso suite
#     07_report_page_1  08_report_page_2             ─ rendered from the PDF report
#
#   The status bar is cleaned for the in-app shots via the Android Demo Mode API
#   (clock 10:00, 100 % battery, full Wi-Fi, no notifications). Demo Mode is
#   ALWAYS switched off again at the end, even on failure, via a bash EXIT trap.
#
#   Prerequisites on the build host (see fastlane/Gemfile and the project README):
#     * a connected device/emulator with an aspect ratio <= 2:1
#       (e.g. 1080x2160) so the captures satisfy Play's max-2:1 rule;
#     * Ruby + bundler with fastlane installed: `cd fastlane && bundle install`;
#     * poppler-utils (`pdftoppm`) for rendering the PDF report pages.
#     * Pillow (`python3-pil`) for bottom-cropping the in-app shots to <= 2:1.
#
#   Pinning the device date to $(SCREENSHOT_DATE) needs an emulator or a rooted
#   userdebug build; on a locked production device that single step is skipped
#   (|| true) and the "Today" screen simply reflects the real date.
screenshots:
	$(MAKE) -C android prereq
	DEV_COUNT=$$(adb devices 2>/dev/null | grep -cw 'device' || true)
	test "$${DEV_COUNT:-0}" -ne 0
	# 0) Pre-flight: the BUNDLED fastlane must be installed in fastlane before any
	#    expensive work (the Gradle build and the device / Demo-Mode setup below).
	#    The gems are vendored under fastlane/.vendor via `cd fastlane && bundle
	#    install`; if that bundle is missing, the `bundle exec fastlane` capture in
	#    step 5 aborts late with the cryptic "bundler: command not found: fastlane"
	#    (Error 127) AFTER a full build and after toggling Demo Mode. Fail fast with
	#    an actionable message instead — mirrors the Pillow / pdftoppm pre-flight
	#    checks in screenshots-crop / screenshots-pdf. `bundle check` only verifies
	#    the bundle is satisfied (it does not load fastlane), so it is cheap.
	command -v bundle >/dev/null 2>&1 || { echo "screenshots: 'bundle' (Ruby Bundler) not found -- install Ruby + Bundler 4.0.15, then run 'cd fastlane && bundle install'."; exit 1; }
	( cd fastlane && bundle check >/dev/null 2>&1 ) || { echo "screenshots: fastlane gems are not installed in fastlane -- run 'cd fastlane && bundle install' (gems vendor into fastlane/.vendor; Bundler 4.0.15 is pinned in fastlane/Gemfile.lock)."; exit 1; }
	# 1) Build the app + instrumentation APKs that screengrab installs.
	$(MAKE) -C android screenshot-apks
	# 2) Demo Mode is torn down no matter how this recipe exits.
	trap '$(MAKE) screenshots-demo-off' EXIT
	# 3) Prepare the device: wake, disable animations, pin date/clock.
	adb shell svc power stayon true
	adb shell input keyevent KEYCODE_WAKEUP
	adb shell wm dismiss-keyguard
	adb shell settings put global window_animation_scale 0
	adb shell settings put global transition_animation_scale 0
	adb shell settings put global animator_duration_scale 0
	adb shell settings put global auto_time 0 || true
	adb root >/dev/null 2>&1 || true
	adb shell "date $$(date -u -d '$(SCREENSHOT_DATE) 10:00:00' +%m%d%H%M%Y.%S)" || true
	adb shell am broadcast -a android.intent.action.TIME_SET >/dev/null 2>&1 || true
	# Verify the date pin actually took. `date` is rejected on non-rooted physical
	# devices (the `adb root` above then also fails), so the pin silently no-ops and
	# the date-relative screens (Today / Calendar / Statistics) reflect the REAL
	# device date instead of $(SCREENSHOT_DATE). Warn loudly rather than ship
	# off-date screenshots unnoticed; run on an emulator or rooted device to pin it.
	dev_date="$$(adb shell date +%Y-%m-%d 2>/dev/null | tr -d '\r' || true)"
	if [ "$$dev_date" != "$(SCREENSHOT_DATE)" ]; then
		echo "WARNING: device date is '$$dev_date', expected '$(SCREENSHOT_DATE)' -- the date pin did not take (non-rooted device?). Date-relative screenshots will use the real device date."
	fi
	# 4) Enter Android Demo Mode and clean the status bar.
	adb shell settings put global sysui_demo_allowed 1
	adb shell am broadcast -a com.android.systemui.demo -e command enter
	adb shell am broadcast -a com.android.systemui.demo -e command clock        -e hhmm $(SCREENSHOT_CLOCK)
	adb shell am broadcast -a com.android.systemui.demo -e command battery      -e plugged false -e level 100
	adb shell am broadcast -a com.android.systemui.demo -e command network      -e wifi show -e level 4
	adb shell am broadcast -a com.android.systemui.demo -e command network      -e mobile hide
	adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false
	# 5) Capture the six in-app screenshots in both locales (de-DE, en-US).
	#    The BUNDLED fastlane is mandatory (reproducible, pinned in fastlane/
	#    Gemfile) — install it once with `cd fastlane && bundle install`. It runs
	#    in a SUBSHELL so the `cd fastlane` does not leak into the following steps
	#    or the EXIT trap (which must run from the repository root, otherwise
	#    `$(MAKE) screenshots-demo-off` finds no such target).
	( cd fastlane && bundle exec fastlane screenshots )
	# 6) Bottom-crop the six in-app screenshots to <= 2:1 (removes the Android
	#    navigation bar at the bottom and satisfies Google Play's max-2:1 rule on
	#    tall phones/emulators). The PDF report pages are added in the next step
	#    and are never cropped.
	$(MAKE) screenshots-crop
	# 7) Render the two PDF report pages per locale into the phoneScreenshots dirs.
	$(MAKE) screenshots-pdf
	# 8) Enforce the Google Play phone-screenshot requirements on all eight assets.
	python3 tools/validate-screenshots.py $(SCREENSHOT_LOCALES)

# Bottom-crop the in-app screenshots (01..06) to at most a 2:1 aspect ratio. Runs
# AFTER capture and BEFORE the PDF pages are rendered, so it only ever sees the
# in-app shots; the tool additionally skips any "report" page and any image that
# is already <= 2:1, so re-runs and the PDF pages are safe.
screenshots-crop:
	python3 -c 'import PIL' 2>/dev/null || { echo "screenshots-crop: Pillow not found — install it (Debian: apt install python3-pil, or: pip install pillow --break-system-packages)"; exit 1; }
	python3 tools/crop-screenshots.py $(SCREENSHOT_LOCALES)

# Render report pages 1 & 2 of the localized PDF into screenshots 07/08. Runs
# AFTER screengrab (whose clear_previous_screenshots wipes only the in-app PNGs),
# so these survive. `-singlefile` makes pdftoppm write exactly <root>.png.
screenshots-pdf:
	command -v pdftoppm >/dev/null || { echo "screenshots-pdf: 'pdftoppm' not found — install poppler-utils"; exit 1; }
	pdftoppm -png -singlefile -r $(SCREENSHOT_PDF_DPI) -f 1 -l 1 fastlane/potillus_report_de.pdf $(META)/de-DE/images/phoneScreenshots/07_report_page_1
	pdftoppm -png -singlefile -r $(SCREENSHOT_PDF_DPI) -f 2 -l 2 fastlane/potillus_report_de.pdf $(META)/de-DE/images/phoneScreenshots/08_report_page_2
	pdftoppm -png -singlefile -r $(SCREENSHOT_PDF_DPI) -f 1 -l 1 fastlane/potillus_report_en.pdf $(META)/en-US/images/phoneScreenshots/07_report_page_1
	pdftoppm -png -singlefile -r $(SCREENSHOT_PDF_DPI) -f 2 -l 2 fastlane/potillus_report_en.pdf $(META)/en-US/images/phoneScreenshots/08_report_page_2

# Render the Play-Store feature graphic (one 1024x500 PNG per locale) into the
# fastlane metadata tree at $(META)/<locale>/images/featureGraphic.png.
#
#   It is fully deterministic: it composes the per-locale marketing copy
#   ($(META)/<locale>/feature-graphic.txt), the REAL screenshots produced by
#   `make screenshots` (01_today as the phone, 07_report_page_1 as the report
#   page) and the app's launcher icon, then renders with rsvg-convert under a
#   PINNED bundled font (tools/fonts/Inter) so the output never depends on the
#   fonts installed on the build host.
#
#   Run it AFTER `make screenshots`, since it reuses those captures — it does NOT
#   trigger a capture itself (that needs a device); the script fails with an
#   actionable message if a required screenshot is missing. Re-run it whenever the
#   screenshots or the copy change. The pre-flight check mirrors the pdftoppm /
#   Pillow checks in screenshots-pdf / screenshots-crop.
feature-graphics:
	command -v rsvg-convert >/dev/null 2>&1 || { echo "feature-graphics: 'rsvg-convert' not found — install it (Debian: apt install librsvg2-bin)"; exit 1; }
	python3 -c 'import PIL' 2>/dev/null || { echo "feature-graphics: Pillow not found — install it (Debian: apt install python3-pil, or: pip install pillow --break-system-packages)"; exit 1; }
	python3 tools/render-feature-graphic.py $(SCREENSHOT_LOCALES)

# Instantiate the STATIC Rokkitt Bold used for the "F-Droid" wordmark in the
# feature-graphic badge, from the upstream VARIABLE font checked in under
# tools/fonts-src/Rokkitt/. Rationale for this split:
#   * The badge's <text> requests family "Rokkitt" at weight 700. The renderer
#     pins fontconfig to tools/fonts/ ONLY (for reproducibility), so a resolvable
#     STATIC Bold must live there.
#   * A variable font would let freetype/fontconfig pick the 700 instance in a
#     version-dependent way — not reproducible. So the variable source is kept
#     OUTSIDE the scanned dir (tools/fonts-src/) and this target bakes a fixed
#     static instance INTO tools/fonts/Rokkitt/, where the renderer finds it.
# You run this ONCE and COMMIT the generated Rokkitt-Bold.ttf; everyone else then
# renders byte-identically without needing fonttools installed.
ROKKITT_VF  = tools/fonts-src/Rokkitt/Rokkitt[wght].ttf
ROKKITT_OUT = tools/fonts/Rokkitt/Rokkitt-Bold.ttf
rokkitt-bold:
	python3 -c 'import fontTools' 2>/dev/null || { echo "rokkitt-bold: fonttools not found — install it (Debian: apt install fonttools, or: pip install fonttools --break-system-packages)"; exit 1; }
	@test -f "$(ROKKITT_VF)" || { echo "rokkitt-bold: variable source missing: $(ROKKITT_VF) — download Rokkitt[wght].ttf (see tools/fonts-src/Rokkitt/README.txt / COPYING.md)"; exit 1; }
	mkdir -p tools/fonts/Rokkitt
	python3 -m fontTools.varLib.instancer "$(ROKKITT_VF)" wght=700 --update-name-table --output "$(ROKKITT_OUT)"
	cp tools/fonts-src/Rokkitt/OFL.txt tools/fonts/Rokkitt/OFL.txt
	@echo "rokkitt-bold: wrote $(ROKKITT_OUT) — COMMIT it so the feature-graphic build is deterministic for everyone."

# Leave Android Demo Mode and restore the normal device state. Each step is
# tolerant (|| true) so tear-down never fails the build; invoked from the
# `screenshots` EXIT trap.
screenshots-demo-off:
	-adb shell am broadcast -a com.android.systemui.demo -e command exit || true
	-adb shell settings put global sysui_demo_allowed 0 || true
	-adb shell settings put global auto_time 1 || true
	-adb shell settings put global window_animation_scale 1 || true
	-adb shell settings put global transition_animation_scale 1 || true
	-adb shell settings put global animator_duration_scale 1 || true
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

.PHONY: default install screenshots screenshots-crop screenshots-pdf screenshots-demo-off feature-graphics rokkitt-bold tgz push clean distclean
