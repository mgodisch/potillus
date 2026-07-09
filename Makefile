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
#
# In addition, as permitted by section 7 of the GNU General Public License,
# this program may carry additional permissions; any such permissions that
# apply to it are stated in the accompanying COPYING.md file.
#
# =============================================================================
#  Makefile -- Libellus Potionis build tooling for Debian GNU/Linux stable
# =============================================================================
#
#  TARGETS AT A GLANCE
#    Convenience
#      debug        (default) local checks (release-check, lint, unit tests,
#                   guide sync) + debug APK, then refresh existing feature graphics
#      device-tests on-device instrumentation tests (connectedDebugAndroidTest),
#                   split out of `debug`                          [needs a device]
#      release      fresh screenshots + feature graphics (no new report PDFs),
#                   then the signed release APK, AAB and SBOM      [needs a device]
#      install      copy the freshly built debug APK to the local install path
#    Store assets
#      store-assets       full set in one go: screenshots + report-pdfs, then
#                         feature graphics rendered exactly once       [device]
#      screenshots        capture the six in-app shots 01..06 per locale, then
#                         refresh the feature graphics                 [device]
#      screenshots-pdf    rasterize report pages 07..08 from the per-locale PDFs
#      feature-graphics           (re)build every locale's featureGraphic*.png
#      feature-graphics-existing  refresh only the graphics already on disk
#      report-pdfs        semi-automatic per-locale PDF export -> 07..08, then
#                         refresh the feature graphics                 [device]
#      rokkitt-bold       bake the static Rokkitt Bold used by the badges
#    Packaging
#      tgz          release source tarball (exclusions derived from .gitignore)
#      push         git push + tags
#    Publishing (upload already-built artifacts; these targets never build)
#      push-playstore  upload the release AAB + store metadata to Google Play
#                      via the fastlane `testing` lane (closed alpha) [AAB + key]
#      push-codeberg   create the Codeberg release for the pushed tag and attach
#                      the built APK + SBOM                    [tag + APK + SBOM]
#    OpenSSF badge
#      bestpractices-json  pull the badge answers from bestpractices.dev into
#                          .bestpractices.json (site -> repo snapshot)
#    Housekeeping
#      clean / distclean
# =============================================================================

# =============================================================================
# CONFIGURATION
# =============================================================================

VERSION = $(shell grep '^## v' CHANGELOG.md | head -n 1 | cut -c5-)

# Run each recipe in ONE bash process with strict error handling
SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.ONESHELL:
.DEFAULT_GOAL := debug

# ── Play-Store screenshot pipeline (see the `screenshots` target) ─────────────
# Locales captured: EVERY store locale under the metadata tree. Each locale dir
# carries a changelogs/ sub-dir, so globbing those and stripping the suffix
# yields exactly the locale set (and skips the non-locale screenshots.html file,
# which has no changelogs/). This is self-maintaining -- adding a
# fastlane/metadata/android/<locale>/ directory extends capture automatically --
# and fastlane/Screengrabfile derives the SAME set the same way, so the two can
# never drift.
SCREENSHOT_LOCALES := $(sort $(notdir $(patsubst %/changelogs,%,$(wildcard fastlane/metadata/android/*/changelogs))))
# The demo fixture (fastlane/demo-backup.json) covers 2026-01-01..2026-06-30, so
# the screenshots are captured from the perspective of the last day of that range
# to give the date-relative "Today" screen meaningful content.
#
# AUTHORITATIVE PIN: the capture suite pins this perspective IN-APP
# (DayResolver.clockOverride, set by ScreenshotClock.pin()), so it holds on ANY
# device — including a locked production phone where the `adb shell date` pin in
# the `screenshots` recipe is silently rejected. This SCREENSHOT_DATE must stay
# equal to ScreenshotClock.SCREENSHOT_DATE and must not fall before the fixture's
# last logged day (2026-06-30 is a deliberately dry "today", one day after the
# last 2026-06-29 entry); the `screenshots` preflight guard enforces both.
SCREENSHOT_DATE  := 2026-06-30

# Display geometry forced onto the capture device (see the `screenshots` recipe;
# reset again by `screenshots-demo-off`).
#
# WHY FORCE IT AT ALL?
#   Google Play rejects phone screenshots whose long side exceeds twice the short
#   side. Most modern panels are 19.5:9 or 20:9 and thus fail. Instead of trimming
#   the captures afterwards (the former `screenshots-crop` step, dropped together
#   with its Pillow dependency), the panel is overridden to an exactly 2:1
#   geometry, so every capture is compliant by construction and shows the real,
#   uncropped app — including the system navigation row.
#
# WHY 1428x2856 @ 640 dpi?
#   2856 / 1428 = 2.000, i.e. exactly at Play's limit and comfortably inside its
#   320..3840 px per-side bounds. 640 dpi (xxxhdpi) makes the app render at
#   1428 / 640 * 160 = 357 dp of usable width — close to the 360 dp baseline the
#   layouts are designed against, so no locale's strings reflow differently than
#   on a typical device. (Alternatives for the record: 480 dpi → 476 dp is a
#   tablet-like layout width; 560 dpi → 408 dp still reads as a large phone. Both
#   are legal here; 640 was chosen for closest baseline parity.)
SCREENSHOT_SIZE    := 1428x2856
SCREENSHOT_DENSITY := 640
# Inputs the drift guard cross-checks against SCREENSHOT_DATE (see the guard in
# the `screenshots` recipe): the in-app capture-date pin and the demo fixture
# whose last logged day the "Today" screenshot must land on.
SCREENSHOT_PIN_KT := android/app/src/androidTest/kotlin/de/godisch/potillus/screenshot/ScreenshotClock.kt
DEMO_BACKUP_JSON  := fastlane/demo-backup.json
# Status-bar clock shown in every shot while Android Demo Mode is active (HHMM).
SCREENSHOT_CLOCK := 1000
# PDF report render resolution. 200 dpi on A4 -> ~1653x2337 px, inside Google
# Play's 320..3840 px / max-2:1 limits (verified by tools/validate-screenshots.py).
SCREENSHOT_PDF_DPI := 200
# Root of the fastlane store-metadata tree (shared by Play `supply` and F-Droid).
META := fastlane/metadata/android
# Directory holding the per-locale source report PDFs (potillus_report_<locale>.pdf)
# that screenshots-pdf rasterizes into the 07/08 report screenshots.
REPORT_PDF_DIR := fastlane/report-pdf

# ── Preflight helpers ── each expands to a one-line "fail fast with an install
# hint if a tool is missing" guard. $(1) is the calling target's name, used as
# the message prefix, so one definition serves every recipe that needs the tool.
require-device    = adb devices 2>/dev/null | grep -q 'device$$' || { echo "$(1): no device/emulator connected (adb) -- connect one first."; exit 1; }
require-pdftoppm  = command -v pdftoppm >/dev/null || { echo "$(1): 'pdftoppm' not found — install poppler-utils"; exit 1; }
require-rsvg      = command -v rsvg-convert >/dev/null 2>&1 || { echo "$(1): 'rsvg-convert' not found — install librsvg2-bin"; exit 1; }
# Still needed after `screenshots-crop` was dropped: tools/render-feature-graphic.py
# imports PIL (it draws the phone mockup and perspective-warps it before embedding
# the result in the SVG). Without this pre-flight the feature-graphic build dies
# with a bare ImportError traceback instead of an actionable message.
require-pillow    = python3 -c 'import PIL' 2>/dev/null || { echo "$(1): Pillow not found — install it (Debian: apt install python3-pil, or: pip install pillow --break-system-packages)"; exit 1; }
require-fonttools = python3 -c 'import fontTools' 2>/dev/null || { echo "$(1): fonttools not found — install it (Debian: apt install fonttools, or: pip install fonttools --break-system-packages)"; exit 1; }

# =============================================================================
# CONVENIENCE & INSTALL
# =============================================================================

# ── debug ── the everyday build. Maximal LOCAL verification, then the debug APK.
# Runs (via android/) the release-check gate, Android lint, the JVM unit tests
# and the guide/copyright sync check, then builds the debug APK and refreshes any
# feature graphics that already exist. The on-device instrumentation tests are
# NOT part of this target — they live in `device-tests` (run that separately when
# a device is attached), so the default build no longer needs a device. It is
# deliberately incremental (no `clean`) for fast iteration and FAILS if any code
# or documentation check would require a correction.
debug:
	$(MAKE) -C android debug unit-test lint check-guides
	$(MAKE) feature-graphics-existing
	$(MAKE) install

# ── device-tests ── the on-device instrumentation tests (Compose UI / Espresso),
# split out of `debug` so the default build runs device-free. Delegates to the
# android `test-device` target (./gradlew connectedDebugAndroidTest), which wakes
# the device and asserts one is attached before running.
device-tests:
	$(MAKE) -C android test-device

# ── release ── fresh in-app screenshots (01..06) + feature graphics WITHOUT
# re-exporting the report PDFs (07/08 are left as-is), then build the signed
# release APK, the release AAB and the shared SBOM. `screenshots` recaptures
# every locale's in-app shots and refreshes the feature graphics but does NOT
# touch the report pages 07/08 or their source PDFs; the android `release` and
# `bundle` targets then produce the release APK and AAB. Both depend on the same
# `$(SBOM)` file target, so the CycloneDX SBOM is generated exactly once. Needs a
# device (for the capture).
release:
	$(MAKE) screenshots
	$(MAKE) -C android release bundle

install: ../downloads/potillus-$(VERSION)-debug.apk

../downloads/potillus-$(VERSION)-debug.apk: android/app/build/outputs/apk/debug/app-debug.apk
	cp $< $@

# =============================================================================
# PLAY-STORE SCREENSHOTS
# =============================================================================
#   Fully automated capture of the eight Google-Play phone screenshots per
#   locale (every store locale under the metadata tree; see SCREENSHOT_LOCALES),
#   placed straight into the fastlane metadata tree:
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
#     * a connected device/emulator — ANY panel geometry will do: the recipe
#       overrides the display to $(SCREENSHOT_SIZE) @ $(SCREENSHOT_DENSITY) (an
#       exact 2:1) for the duration of the capture and resets it afterwards, so
#       Play's max-2:1 rule is satisfied by construction rather than by cropping;
#     * Ruby + bundler with fastlane installed: `cd fastlane && bundle install`;
#     * poppler-utils (`pdftoppm`) for rendering the PDF report pages.
#     * Pillow (`python3-pil`) for the feature graphics rebuilt by the final
#       cascade step (tools/render-feature-graphic.py draws the phone mockup).
#
#   The capture perspective (logical "today") is pinned IN-APP by the capture
#   suite (ScreenshotClock.pin() → DayResolver.clockOverride = $(SCREENSHOT_DATE)),
#   so the date-relative screens are correct on ANY device. The extra
#   `adb shell date` pin below is only best-effort cosmetics for anything that
#   might read the raw device clock; it needs an emulator or a rooted userdebug
#   build and is skipped (|| true) on a locked production device WITHOUT affecting
#   the captured screenshots.
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
	#    an actionable message instead — mirrors the pdftoppm pre-flight
	#    checks in screenshots-pdf. `bundle check` only verifies
	#    the bundle is satisfied (it does not load fastlane), so it is cheap.
	command -v bundle >/dev/null 2>&1 || { echo "screenshots: 'bundle' (Ruby Bundler) not found -- install Ruby + Bundler 4.0.15, then run 'cd fastlane && bundle install'."; exit 1; }
	( cd fastlane && bundle check >/dev/null 2>&1 ) || { echo "screenshots: fastlane gems are not installed in fastlane -- run 'cd fastlane && bundle install' (gems vendor into fastlane/.vendor; Bundler 4.0.15 is pinned in fastlane/Gemfile.lock)."; exit 1; }
	# 0b) Perspective-pin consistency guard (cheap; runs before the expensive build).
	#     The captured perspective is pinned IN-APP (ScreenshotClock.pin() sets
	#     DayResolver.clockOverride), so it no longer depends on the device date.
	#     Two invariants must hold or the capture is subtly wrong:
	#       (1) the two pins agree: Makefile SCREENSHOT_DATE == ScreenshotClock's;
	#       (2) the pinned day is NOT BEFORE the demo fixture's last logged day,
	#           so no seeded entry falls on a 'future' day the pinned Today cannot
	#           show. (The pinned day MAY be later than the last entry on purpose:
	#           2026-06-30 is a deliberately dry 'today' one day after the last
	#           2026-06-29 drink.) Enforced here so the sources cannot drift.
	pin_kt="$$(sed -n 's/.*SCREENSHOT_DATE[^"]*"\([0-9-]*\)".*/\1/p' "$(SCREENSHOT_PIN_KT)" | head -n1)"
	last_entry="$$(grep -oE '"logicalDate"[[:space:]]*:[[:space:]]*"[0-9]{4}-[0-9]{2}-[0-9]{2}"' "$(DEMO_BACKUP_JSON)" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | sort | tail -n1)"
	newest="$$(printf '%s\n%s\n' "$$last_entry" "$(SCREENSHOT_DATE)" | sort | tail -n1)"
	if [ "$$pin_kt" != "$(SCREENSHOT_DATE)" ]; then
		echo "screenshots: capture-date pins disagree -- Makefile SCREENSHOT_DATE='$(SCREENSHOT_DATE)' vs ScreenshotClock.SCREENSHOT_DATE='$$pin_kt'. Align the two and re-run."
		exit 1
	fi
	if [ "$$newest" != "$(SCREENSHOT_DATE)" ]; then
		echo "screenshots: capture date '$(SCREENSHOT_DATE)' is BEFORE the demo fixture's last logged day '$$last_entry' -- seeded entries would fall on a future day the pinned Today cannot show. Move SCREENSHOT_DATE to on/after '$$last_entry'."
		exit 1
	fi
	# 1) Build the app + instrumentation APKs that screengrab installs.
	$(MAKE) -C android screenshot-apks
	# 2) Demo Mode is torn down no matter how this recipe exits.
	trap '$(MAKE) screenshots-demo-off' EXIT
	# 3) Prepare the device: wake, disable animations, pin clock (and, best-effort,
	#    the device date — the capture PERSPECTIVE itself is already pinned in-app).
	adb shell svc power stayon true
	adb shell input keyevent KEYCODE_WAKEUP
	# Force an exactly-2:1 panel so the captures satisfy Play's aspect rule
	# without any post-processing (see SCREENSHOT_SIZE / SCREENSHOT_DENSITY).
	# Both overrides are sticky and are undone by the EXIT trap's
	# `screenshots-demo-off`, which runs even on Ctrl-C or a failed capture.
	adb shell wm size $(SCREENSHOT_SIZE)
	adb shell wm density $(SCREENSHOT_DENSITY)
	adb shell wm dismiss-keyguard
	adb shell settings put global window_animation_scale 0
	adb shell settings put global transition_animation_scale 0
	adb shell settings put global animator_duration_scale 0
	adb shell settings put global auto_time 0 || true
	adb root >/dev/null 2>&1 || true
	adb shell "date $$(date -u -d '$(SCREENSHOT_DATE) 10:00:00' +%m%d%H%M%Y.%S)" || true
	adb shell am broadcast -a android.intent.action.TIME_SET >/dev/null 2>&1 || true
	# Report whether the (best-effort) device-date pin took. `date` is rejected on
	# non-rooted physical devices (the `adb root` above then also fails), so the pin
	# silently no-ops there. This NO LONGER affects the screenshots: the capture
	# perspective is pinned in-app (see ScreenshotClock / DayResolver.clockOverride),
	# so the date-relative screens still render from $(SCREENSHOT_DATE) regardless.
	# The line below is therefore informational only — it never fails the build.
	dev_date="$$(adb shell date +%Y-%m-%d 2>/dev/null | tr -d '\r' || true)"
	if [ "$$dev_date" != "$(SCREENSHOT_DATE)" ]; then
		echo "note: device date is '$$dev_date' (not $(SCREENSHOT_DATE)); the device-date pin needs an emulator/rooted build. Screenshots are unaffected — their date is pinned in-app to $(SCREENSHOT_DATE)."
	fi
	# 4) Enter Android Demo Mode and clean the status bar.
	adb shell settings put global sysui_demo_allowed 1
	adb shell am broadcast -a com.android.systemui.demo -e command enter
	adb shell am broadcast -a com.android.systemui.demo -e command clock        -e hhmm $(SCREENSHOT_CLOCK)
	adb shell am broadcast -a com.android.systemui.demo -e command battery      -e plugged false -e level 100
	adb shell am broadcast -a com.android.systemui.demo -e command network      -e wifi show -e level 4
	adb shell am broadcast -a com.android.systemui.demo -e command network      -e mobile hide
	adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false
	# 5) Clear ONLY the in-app shots 01..06 for every locale before capturing.
	#    screengrab's own clear_previous_screenshots is disabled (see the
	#    Screengrabfile) because it globs and deletes ALL *.png in each
	#    phoneScreenshots/ dir — including the committed report pages 07/08 that
	#    this target does not regenerate. Deleting exactly 01..06 here keeps the
	#    "no stale in-app shot survives a re-run" guarantee without touching the
	#    report pages. The glob nullglob-guards so a locale mid-migration (no old
	#    shots yet) is not an error.
	shopt -s nullglob
	rm -f $(META)/*/images/phoneScreenshots/0[1-6]_*.png
	shopt -u nullglob
	# 6) Capture the six in-app screenshots in every configured locale
	#    (SCREENSHOT_LOCALES, derived from the metadata tree).
	#    The BUNDLED fastlane is mandatory (reproducible, pinned in fastlane/
	#    Gemfile) — install it once with `cd fastlane && bundle install`. It runs
	#    in a SUBSHELL so the `cd fastlane` does not leak into the following steps
	#    or the EXIT trap (which must run from the repository root, otherwise
	#    `$(MAKE) screenshots-demo-off` finds no such target).
	( cd fastlane && bundle exec fastlane screenshots )
	# 7) Enforce the Google Play phone-screenshot requirements on the in-app shots.
	#    Only 01..06 are (re)captured here; the report pages 07/08 are owned by
	#    `make report-pdfs` (rendered from the per-locale PDFs, not the device),
	#    which validates them there.
	python3 tools/validate-screenshots.py --in-app $(SCREENSHOT_LOCALES)
	# 8) Cascade: fresh 01..06 feed the feature graphics (their 01_today input just
	#    changed), so rebuild every locale's now-stale graphic ("renew screenshots
	#    -> renew feature graphics"). Routed through the once-per-run guard so a
	#    combined run (`make screenshots report-pdfs`, or `store-assets`) renders
	#    the graphics only ONCE, not after each producer. feature-graphics is
	#    file-timestamp driven, so unchanged locales are a no-op regardless.
	$(MAKE) _cascade-feature-graphics

# Leave Android Demo Mode and restore the normal device state. Each step is
# tolerant (|| true) so tear-down never fails the build; invoked from the
# `screenshots` EXIT trap.
#
# The display overrides deserve special mention: `screenshots` forces the panel
# to $(SCREENSHOT_SIZE) / $(SCREENSHOT_DENSITY) so every capture is exactly 2:1
# (see the recipe). Those overrides are STICKY — they survive the make run, a
# reboot and, on a physical phone, the rest of the day. Resetting them here (and
# not at the end of the recipe) means a Ctrl-C or a failed capture leaves the
# device usable, exactly like the Demo Mode teardown. `wm size|density reset`
# restores the panel's native values and is a no-op when nothing was overridden.
screenshots-demo-off:
	adb shell am broadcast -a com.android.systemui.demo -e command exit || true
	adb shell settings put global sysui_demo_allowed 0 || true
	adb shell wm size reset || true
	adb shell wm density reset || true
	adb shell settings put global auto_time 1 || true
	adb shell settings put global window_animation_scale 1 || true
	adb shell settings put global transition_animation_scale 1 || true
	adb shell settings put global animator_duration_scale 1 || true

# =============================================================================
# REPORT PAGES & FEATURE GRAPHICS  (dependency pipeline)
# =============================================================================

# Render report pages 1 & 2 of the localized PDF into screenshots 07/08, for
# EVERY locale in $(SCREENSHOT_LOCALES). Runs AFTER screengrab (whose
# clear_previous_screenshots wipes only the in-app PNGs 01..06), so these survive.
#
# Report source per locale: the report PDF is named EXACTLY for the store locale,
# $(REPORT_PDF_DIR)/potillus_report_<locale>.pdf -- so `de-DE` uses
# potillus_report_de-DE.pdf, `zh-CN` uses potillus_report_zh-CN.pdf, etc. There is
# deliberately NO base-language/English fallback: a `fr` graphic MUST use the `fr`
# report, and `zh-CN`/`zh-TW` must not collapse onto a shared `zh` PDF. If a
# locale's own PDF is missing that is an error -- run `make report-pdfs` (which
# exports each PDF under that exact name) first.
#
# `-singlefile` makes pdftoppm write exactly <root>.png (no page-number suffix).
#
# DEPENDENCY-DRIVEN PIPELINE: the report pages and feature graphics are proper
# FILE targets, so `make screenshots-pdf` / `make feature-graphics` rebuild ONLY
# the locales whose inputs actually changed:
#
#   $(REPORT_PDF_DIR)/potillus_report_<locale>.pdf (source PDF; named exactly)
#        |  pdftoppm
#        v
#   $(META)/<loc>/images/phoneScreenshots/07_report_page_1.png   (and 08)
#        |                                    +-- feature-graphic.txt
#        |                                    +-- 01_today.png (from screengrab)
#        v  render-feature-graphic.py         +-- $(FG_SHARED_DEPS)
#   $(META)/<loc>/images/featureGraphic.png <-'
#
# So dropping a newer source PDF makes `make feature-graphics` re-rasterize that
# locale's report page AND re-render its feature graphic, with no extra step.

# Per-locale source PDF, named EXACTLY for the store locale. No fallback: 07/08
# depend on this precise file, so a missing per-locale PDF is a hard make error.
report_src = $(REPORT_PDF_DIR)/potillus_report_$(1).pdf

# Shared inputs every feature graphic depends on. The whole tools/fonts/ tree is
# pulled in because the renderer pins fontconfig to it and the badges draw live
# text (DejaVuSans for "GET IT ON", Rokkitt for "F-Droid") -- so DejaVuSans and
# Rokkitt are inputs too, not just Inter/NotoSansCJK. Over-approximated on
# purpose: an unnecessary rebuild is cheap, a MISSED dependency ships a stale asset.
FG_RENDERER    := tools/render-feature-graphic.py
FG_SHARED_DEPS := $(FG_RENDERER) \
                  android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png \
                  fastlane/gpl-v3-logo.svg \
                  $(wildcard fdroid/get-it-on-*.svg) \
                  $(wildcard tools/fonts/*/*)

REPORT_PAGE_PNGS     :=
FEATURE_GRAPHIC_PNGS :=

# ── Per-locale rules, generated for every store locale via $(eval). One canned
# recipe per artifact kind. The two report pages differ only in the page number,
# so a SINGLE parametrized recipe emits both (07 = page 1, 08 = page 2).

# report_page_rule: $(1)=locale  $(2)=sequence (07|08)  $(3)=page number (1|2)
define report_page_rule
$(META)/$(1)/images/phoneScreenshots/$(2)_report_page_$(3).png: $(call report_src,$(1))
	@$(call require-pdftoppm,screenshots-pdf)
	@mkdir -p "$$(@D)"
	@echo "screenshots-pdf: $(1) p$(3) <- $$(notdir $$<)"
	@pdftoppm -png -singlefile -r $(SCREENSHOT_PDF_DPI) -f $(3) -l $(3) "$$<" "$$(@:.png=)"
endef

# feature_graphic_rule: $(1)=locale. Grouped target (&:, GNU Make 4.3+) so the
# single renderer call produces BOTH the 1024x500 PNG and its 4K companion.
define feature_graphic_rule
$(META)/$(1)/images/featureGraphic.png $(META)/$(1)/images/featureGraphic-4K.png &: $(META)/$(1)/feature-graphic.txt $(META)/$(1)/images/phoneScreenshots/01_today.png $(META)/$(1)/images/phoneScreenshots/07_report_page_1.png $(FG_SHARED_DEPS)
	@$(call require-rsvg,feature-graphics)
	@$(call require-pillow,feature-graphics)
	@echo "feature-graphics: $(1)"
	@python3 $(FG_RENDERER) $(1)
endef

# Instantiate all three rules per locale and collect the outputs.
define potillus_pipeline_rules
$(call report_page_rule,$(1),07,1)
$(call report_page_rule,$(1),08,2)
$(call feature_graphic_rule,$(1))
REPORT_PAGE_PNGS     += $(META)/$(1)/images/phoneScreenshots/07_report_page_1.png $(META)/$(1)/images/phoneScreenshots/08_report_page_2.png
FEATURE_GRAPHIC_PNGS += $(META)/$(1)/images/featureGraphic.png $(META)/$(1)/images/featureGraphic-4K.png
endef
$(foreach loc,$(SCREENSHOT_LOCALES),$(eval $(call potillus_pipeline_rules,$(loc))))

# Device screenshots (01..06) come from `make screenshots` (screengrab on a
# device) and have no per-file build rule of their own. If any is MISSING when a
# feature graphic needs it, capture the whole set automatically — screengrab
# always grabs every locale at once, so a missing shot means the set is
# incomplete and one full recapture is the correct repair. This triggers ONLY on
# a truly absent file, never on a merely stale one: staleness of device
# screenshots is not reliably detectable (the project's long-standing reason for
# capturing them by hand), but absence is unambiguous. Because `screenshots`
# itself now cascades into `feature-graphics` (see that target), the graphics are
# refreshed as part of the same capture.
#
# WHY THE MARKER FILE. If this recipe ran `$(MAKE) screenshots` directly, Make
# would fire it once PER missing target — up to 14 full recaptures when a new
# locale set is empty. Every missing screenshot instead order-only-depends on the
# single marker $(SCREENSHOTS_CAPTURED_MARKER), whose recipe runs the one capture
# and is built AT MOST ONCE per `make` invocation; the sentinels then merely
# assert their file now exists. The marker lives under android/app/build/
# (already git-ignored, removed by `make clean`), so a later invocation
# re-checks the tree afresh instead of trusting an earlier run's capture.
SCREENSHOTS_CAPTURED_MARKER := android/app/build/.screenshots-captured

$(SCREENSHOTS_CAPTURED_MARKER):
	$(call require-device,screenshots)
	@echo "feature-graphics: device screenshots missing — capturing all locales via 'make screenshots'."
	$(MAKE) screenshots
	@mkdir -p "$(@D)"
	@touch "$@"

# One sentinel per in-app screenshot kind (01..06): order-only-depend on the
# marker so the capture runs (once) before the file is needed, then assert the
# file is really present afterwards — if the capture did not produce it, fail
# loudly rather than let a downstream renderer read a missing input.
define device_screenshot_sentinel
$(META)/%/images/phoneScreenshots/$(1).png: | $$(SCREENSHOTS_CAPTURED_MARKER)
	@test -f "$$@" || { echo "feature-graphics: $$@ still missing after 'make screenshots' — capture did not produce it." >&2; exit 1; }
endef
$(foreach shot,01_today 02_calendar 03_statistics 04_drinks 05_add_drink 06_settings,$(eval $(call device_screenshot_sentinel,$(shot))))

# Aggregators: build every locale's outputs but ONLY the stale ones (real file
# prerequisites -> timestamp-driven; an up-to-date tree is a no-op).
screenshots-pdf: $(REPORT_PAGE_PNGS)
feature-graphics: $(FEATURE_GRAPHIC_PNGS)
# Refresh ONLY the feature graphics already on disk (used by the `debug` build,
# which captures no screenshots): $(wildcard) never lists a locale without a
# featureGraphic.png yet, so this can never trip the 01_today guard above.
feature-graphics-existing: $(wildcard $(META)/*/images/featureGraphic.png)

# ── Once-per-run feature-graphics cascade ─────────────────────────────────────
# `screenshots` (producer of 01..06) and `report-pdfs` (producer of 07..08) each
# must refresh the feature graphics afterwards — but when BOTH run in one
# invocation (the `store-assets` orchestrator, or `make screenshots report-pdfs`)
# the graphics must render only ONCE, not after each producer. They are separate
# interactive recipes in separate recursive $(MAKE) subprocesses, so they cannot
# share make's in-process target dedup; a filesystem STAMP coordinates them
# instead. The first cascade in a run renders `feature-graphics` and drops the
# stamp; a second cascade in the SAME run sees the stamp and skips. `store-assets`
# creates the stamp up front (so neither producer renders early) and does the
# single real render at the end; a lone `make screenshots` or `make report-pdfs`
# finds no stamp and renders exactly once itself. The stamp lives under
# android/app/build/ (git-ignored, cleared by `make clean`) and — because
# feature-graphics is file-timestamp driven anyway — the worst case if a stale
# stamp ever survived is a skipped no-op render, never a stale asset.
CASCADE_FG_STAMP := android/app/build/.feature-graphics-cascaded

# Internal: render feature-graphics unless this run already did (or was told to
# defer by store-assets). Not for direct use.
_cascade-feature-graphics:
	if [ -f "$(CASCADE_FG_STAMP)" ]; then \
	    echo "feature-graphics: already refreshed in this run — skipping duplicate cascade."; \
	else \
	    mkdir -p "$(dir $(CASCADE_FG_STAMP))"; \
	    touch "$(CASCADE_FG_STAMP)"; \
	    $(MAKE) feature-graphics; \
	fi

# ── store-assets ── refresh the COMPLETE store-image set in one go: capture the
# in-app screenshots (01..06), export+rasterize the report pages (07..08), then
# render every feature graphic EXACTLY once. Use this instead of running
# `screenshots` and `report-pdfs` separately when you want the whole set rebuilt;
# both need a device, and report-pdfs is human-in-the-loop ("Save as PDF").
store-assets:
	# Defer both producers' cascades, then do the single real render at the end.
	# The EXIT trap removes the stamp even if a producer aborts, so a stale stamp
	# can never suppress the cascade in a LATER run (belt-and-suspenders — the
	# stamp lives under the git-ignored build dir and feature-graphics is
	# timestamp-driven anyway, so an orphan would cost only one skipped no-op).
	@mkdir -p "$(dir $(CASCADE_FG_STAMP))"
	trap 'rm -f "$(CASCADE_FG_STAMP)"' EXIT
	@touch "$(CASCADE_FG_STAMP)"          # defer: neither producer renders early
	$(MAKE) screenshots
#	$(MAKE) report-pdfs
	@rm -f "$(CASCADE_FG_STAMP)"           # arm the single real render
	$(MAKE) _cascade-feature-graphics

# =============================================================================
# REPORT PDF EXPORT  (semi-automatic, human-in-the-loop)
# =============================================================================

# Semi-automatic per-locale PDF report export (feeds screenshots-pdf).
#
#   The 07/08 report pages are rasterized by `screenshots-pdf` from per-locale
#   source PDFs `$(REPORT_PDF_DIR)/potillus_report_<locale>.pdf`. Exporting those
#   for 21 locales is tedious, so this target drives the app's export ONCE per
#   locale and leaves only the system "Save as PDF" dialog to you — with the file
#   name PRE-FILLED as potillus_report_<locale>.pdf (see the androidTest class
#   ReportExportTest; production keeps its timestamped name, unchanged).
#
#   FLOW: for each locale the instrumented ReportExportTest opens the print dialog
#   and then BLOCKS until the app is foreground again. You tap "Save as PDF" ->
#   Save (name is pre-filled) into the device Downloads folder; the automation
#   then advances to the next locale. Afterwards the saved PDFs are pulled into
#   $(REPORT_PDF_DIR)/, where the dependency graph picks them up automatically.
#
#   It is a HUMAN-IN-THE-LOOP target: the ReportExportTest is skipped in every
#   other run (a `-e reportExport true` Assume guard), so ordinary `make test` and
#   `make screenshots` never open a dialog. Run it explicitly, on a device/emulator
#   whose print stack offers "Save as PDF".
#
#   INSTR is the instrumentation component: the debug applicationId
#   (de.godisch.potillus + the `.debug` suffix from app/build.gradle.kts) plus the
#   `.test` androidTest suffix, with the AndroidX JUnit runner.
INSTR := de.godisch.potillus.debug.test/androidx.test.runner.AndroidJUnitRunner
report-pdfs:
	$(MAKE) -C android prereq
	DEV_COUNT=$$(adb devices 2>/dev/null | grep -cw 'device' || true)
	test "$${DEV_COUNT:-0}" -ne 0
	# 1) Build, then (re)install the app + instrumentation APKs. Any prior copy is
	#    removed first so a signature/downgrade mismatch cannot block the install
	#    (that failure prints an empty reason after "Performing Streamed Install"),
	#    and `-t` is required because the instrumentation APK is marked testOnly.
	#    adb's own message is surfaced on failure instead of a bare "Error 1".
	$(MAKE) -C android screenshot-apks
	adb uninstall de.godisch.potillus.debug      >/dev/null 2>&1 || true
	adb uninstall de.godisch.potillus.debug.test >/dev/null 2>&1 || true
	for apk in android/app/build/outputs/apk/debug/app-debug.apk \
	           android/app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk; do \
	    echo "report-pdfs: installing $$(basename "$$apk")"; \
	    out=$$(adb install -t -r "$$apk" 2>&1) || { \
	        echo "report-pdfs: adb install failed for $$apk:"; \
	        printf '%s\n' "$$out" | sed 's/^/    /'; \
	        exit 1; \
	    }; \
	done
	# 2) Keep the screen awake for the interactive run.
	adb shell svc power stayon true
	adb shell input keyevent KEYCODE_WAKEUP
	adb shell wm dismiss-keyguard
	echo
	echo ">>> For EACH locale: tap 'Save as PDF' -> Save (name is pre-filled) into"
	echo ">>> the Downloads folder. The run advances automatically after each save."
	echo
	# 3) Trigger the export once per locale (blocks until you finish the dialog).
	@for loc in $(SCREENSHOT_LOCALES); do \
	    echo "report-pdfs: === $$loc — waiting for your 'Save as PDF' ==="; \
	    adb shell am instrument -w \
	        -e class de.godisch.potillus.screenshot.ReportExportTest \
	        -e reportExport true -e testLocale "$$loc" \
	        $(INSTR) >/dev/null || true; \
	done
	# 4) Pull the saved PDFs from Downloads into $(REPORT_PDF_DIR) (best effort; a
	#    missing file just means that locale was skipped/cancelled — re-run it).
	@mkdir -p "$(REPORT_PDF_DIR)"
	@for loc in $(SCREENSHOT_LOCALES); do \
	    if adb pull "/sdcard/Download/potillus_report_$$loc.pdf" "$(REPORT_PDF_DIR)/potillus_report_$$loc.pdf" >/dev/null 2>&1; then \
	        echo "report-pdfs: pulled potillus_report_$$loc.pdf"; \
	    else \
	        echo "report-pdfs: (no potillus_report_$$loc.pdf in Downloads — skipped?)"; \
	    fi; \
	done
	adb shell svc power stayon false || true
	# 5) Rasterize the two report pages 07/08 from the freshly pulled per-locale
	#    PDFs. This is report-pdfs' OWN half of the screenshot set (01..06 belong
	#    to `make screenshots`); screenshots-pdf is file-timestamp driven, so only
	#    locales whose PDF actually changed are re-rendered.
	$(MAKE) screenshots-pdf
	# 6) Validate the report pages against Play's phone-screenshot rules.
	python3 tools/validate-screenshots.py --report $(SCREENSHOT_LOCALES)
	# 7) Cascade: fresh 07/08 feed the feature graphics (their 07_report_page_1
	#    input just changed), so rebuild every now-stale graphic ("renew PDFs ->
	#    renew 07/08 -> renew feature graphics"). Via the once-per-run guard, so a
	#    combined screenshots+report-pdfs run renders the graphics only ONCE.
	$(MAKE) _cascade-feature-graphics

# =============================================================================
# FONTS
# =============================================================================

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
	$(call require-fonttools,rokkitt-bold)
	@test -f "$(ROKKITT_VF)" || { echo "rokkitt-bold: variable source missing: $(ROKKITT_VF) — download Rokkitt[wght].ttf (see tools/fonts-src/Rokkitt/README.txt / COPYING.md)"; exit 1; }
	mkdir -p tools/fonts/Rokkitt
	python3 -m fontTools.varLib.instancer "$(ROKKITT_VF)" wght=700 --update-name-table --output "$(ROKKITT_OUT)"
	cp tools/fonts-src/Rokkitt/OFL.txt tools/fonts/Rokkitt/OFL.txt
	@echo "rokkitt-bold: wrote $(ROKKITT_OUT) — COMMIT it so the feature-graphic build is deterministic for everyone."

# =============================================================================
# PACKAGING & DEPLOY
# =============================================================================

tgz: potillus-$(VERSION).tar.gz

# Release tarball. The set of files to leave out is derived DYNAMICALLY from
# .gitignore instead of being duplicated here, so the two can never drift.
#
# Mapping .gitignore patterns to tar --exclude patterns faithfully needs care:
#   * Comments (# ...), trailing whitespace and blank lines are stripped.
#   * A negation (!pattern) cannot be expressed with tar --exclude, so we abort
#     rather than silently over-exclude. (There are none today.)
#   * git treats a pattern that contains a '/' as anchored to the repo root and
#     one without any '/' as matching at ANY depth. tar's default is the
#     opposite (all patterns float), so we split the list: anchored patterns get
#     the archive's top directory (this repo dir) prepended and are matched with
#     --anchored; the rest are matched with --no-anchored.
#   * tar lets '*' cross '/' by default, which would make e.g. '/*.pdf' (root
#     PDFs only) also swallow nested PDFs; --no-wildcards-match-slash restores
#     git's single-'*'-stays-in-one-segment semantics.
#   * .git itself is not in .gitignore (git implies it), so it is excluded
#     explicitly.
# The two pattern files are written under a mktemp dir OUTSIDE the archived tree
# so they never end up inside the tarball.
potillus-$(VERSION).tar.gz: CHANGELOG.md
	@if grep -q '^[[:space:]]*!' .gitignore; then \
	    echo "tgz: .gitignore has a negation (!) that tar --exclude cannot express — aborting." >&2; \
	    exit 1; \
	fi
	@top=`basename "$$PWD"`; td=`mktemp -d`; \
	clean=`sed -e 's/#.*$$//' -e 's/[[:space:]]*$$//' -e '/^$$/d' .gitignore`; \
	printf '%s\n' "$$clean" | grep '/'    | sed -e 's#^/##' -e "s#^#$$top/#" > "$$td/anchored"   || true; \
	printf '%s\n' "$$clean" | grep -v '/'                                    > "$$td/unanchored" || true; \
	tar czf ../potillus-$(VERSION).tar.gz -C .. \
		--no-wildcards-match-slash \
		--anchored    --exclude="$$top/.git" --exclude-from="$$td/anchored" \
		--no-anchored --exclude-from="$$td/unanchored" \
		"$$top"; \
	rm -rf "$$td"

push:
	git push && git push --tags

# ── push-playstore ── upload the ALREADY-BUILT release AAB to Google Play and
# OVERWRITE the store listing there (localized titles, short/full descriptions,
# feature graphics, screenshots) plus the release notes, from
# fastlane/metadata/android/. The fastlane OPTIONS (track alpha, status
# completed, metadata-overwriting) live in the fastlane `testing` lane, NOT here —
# override them there or via `fastlane testing track:...`.
#
# DELIBERATELY NOT A DEPENDENCY BUILD: this target has NO prerequisites, so it
# never triggers a rebuild of the AAB or SBOM. It FAILS FAST if a precondition
# is missing — the signed AAB, the bundled fastlane, or the Play service-account
# key — so the push only runs against artifacts you built explicitly
# (`make release`, or `make -C android bundle`) with credentials in place. Build
# the AAB yourself first; this target purely uploads it.
#
# The credential path mirrors the Appfile: SUPPLY_JSON_KEY if set, else
# fastlane/play-store-credentials.json.
PLAYSTORE_AAB := android/app/build/outputs/bundle/release/app-release.aab
push-playstore:
	test -f "$(PLAYSTORE_AAB)" || { echo "push-playstore: release AAB not found at '$(PLAYSTORE_AAB)' -- build it first with 'make release' or 'make -C android bundle'. This target does NOT build it." >&2; exit 1; }
	command -v bundle
	@( cd fastlane && bundle check >/dev/null 2>&1 ) || { echo "push-playstore: fastlane gems not installed -- run 'cd fastlane && bundle install'." >&2; exit 1; }
	@key="$${SUPPLY_JSON_KEY:-fastlane/play-store-credentials.json}"; test -f "$$key" || { echo "push-playstore: Play service-account key not found at '$$key' -- place the JSON key there or set SUPPLY_JSON_KEY (see fastlane/Appfile)." >&2; exit 1; }
	( cd fastlane && bundle exec fastlane testing )

# ── push-codeberg ── create a Codeberg (Forgejo) release for the ALREADY-PUSHED
# release tag from the command line instead of the web UI, and attach the built
# APK + SBOM. It uses the Forgejo REST API (Gitea-compatible): one POST creates
# the release, two more upload the assets. Title is "Libellus Potionis vX.Y.Z"
# and the body is the en-US Play release notes for this versionCode.
#
# Like push-playstore, this has NO build prerequisites and never builds: it FAILS
# FAST if the tag, the APK, the SBOM, the release notes, curl/python3 or the
# Codeberg token file are missing. Build the artifacts first (`make release`) and
# push the tag first (`git tag -s vX.Y.Z ... && make push`); this only publishes.
#
# The Codeberg access token is READ FROM $(CODEBERG_TOKEN_FILE) (Settings ->
# Applications, repository read+write scope). That file is a SECRET, git-ignored
# and never committed -- mirroring the Play service-account key. The recipe's
# commands are echoed (so you can see what runs), but that does NOT leak the
# token: it lives in a SHELL variable -- written $$token in the recipe, i.e. the
# shell's own $token -- read from the file at run time. make expands its own
# make-variables when it echoes a line, but never shell-variables, so the echo
# shows the literal "$token" and never the token VALUE.
CODEBERG_API  := https://codeberg.org/api/v1
CODEBERG_REPO := godisch/potillus
CODEBERG_TOKEN_FILE := fastlane/codeberg-credentials.txt
RELEASE_SBOM  := android/app/build/outputs/sbom/libellus-potionis-sbom.json
VERSION_CODE  := $(shell grep -oE 'versionCode *= *[0-9]+' android/app/build.gradle.kts | grep -oE '[0-9]+' | head -1)
push-codeberg:
	command -v curl
	command -v python3
	@test -f "$(CODEBERG_TOKEN_FILE)" || { echo "push-codeberg: token file '$(CODEBERG_TOKEN_FILE)' not found -- create it containing your Codeberg access token (Settings > Applications, repository read+write scope). It is git-ignored." >&2; exit 1; }
	token="$$(tr -d '[:space:]' < "$(CODEBERG_TOKEN_FILE)")"
	@test -n "$$token" || { echo "push-codeberg: token file '$(CODEBERG_TOKEN_FILE)' is empty." >&2; exit 1; }
	@git rev-parse -q --verify "refs/tags/v$(VERSION)" >/dev/null || { echo "push-codeberg: git tag 'v$(VERSION)' not found -- create and push it first (git tag -s v$(VERSION) -m 'v$(VERSION)' && make push). This target does NOT create the tag." >&2; exit 1; }
	notes="$(META)/en-US/changelogs/$(VERSION_CODE).txt"
	@test -f "$$notes" || { echo "push-codeberg: en-US release notes '$$notes' not found (versionCode $(VERSION_CODE))." >&2; exit 1; }
	apk="$$(find android/app/build/outputs/apk/release -maxdepth 1 -name 'app-release*.apk' 2>/dev/null | sort | tail -1)"
	@test -n "$$apk" || { echo "push-codeberg: no release APK under android/app/build/outputs/apk/release -- build it first with 'make release'. This target does NOT build it." >&2; exit 1; }
	@test -f "$(RELEASE_SBOM)" || { echo "push-codeberg: SBOM '$(RELEASE_SBOM)' not found -- build it first with 'make release' (or 'make -C android sbom')." >&2; exit 1; }
	# 1) Create the release for the existing tag; capture its numeric id. The body
	#    is JSON-encoded from the en-US release-notes file (handles quotes/newlines).
	body="$$(python3 -c 'import json,sys; print(json.dumps(open(sys.argv[1], encoding="utf-8").read()))' "$$notes")"
	payload="$$(printf '{"tag_name":"v%s","name":"Libellus Potionis v%s","body":%s,"draft":false,"prerelease":false}' "$(VERSION)" "$(VERSION)" "$$body")"
	rel_id="$$(curl -fsS --proto '=https' --tlsv1.2 -X POST -H "Authorization: token $$token" -H "Content-Type: application/json" -d "$$payload" "$(CODEBERG_API)/repos/$(CODEBERG_REPO)/releases" | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')"
	echo "push-codeberg: created release 'Libellus Potionis v$(VERSION)' (id $$rel_id)"
	# 2) Attach the APK and the SBOM as release assets (name= sets the asset name).
	curl -fsS --proto '=https' --tlsv1.2 -X POST -H "Authorization: token $$token" -F "attachment=@$$apk" "$(CODEBERG_API)/repos/$(CODEBERG_REPO)/releases/$$rel_id/assets?name=potillus-$(VERSION).apk" >/dev/null
	echo "push-codeberg: attached $$(basename "$$apk") as potillus-$(VERSION).apk"
	curl -fsS --proto '=https' --tlsv1.2 -X POST -H "Authorization: token $$token" -F "attachment=@$(RELEASE_SBOM)" "$(CODEBERG_API)/repos/$(CODEBERG_REPO)/releases/$$rel_id/assets?name=potillus-$(VERSION)-sbom.json" >/dev/null
	echo "push-codeberg: attached SBOM as potillus-$(VERSION)-sbom.json"
	echo "push-codeberg: done -> https://codeberg.org/$(CODEBERG_REPO)/releases/tag/v$(VERSION)"

# =============================================================================
# OPENSSF BEST PRACTICES BADGE
# =============================================================================
#
# The project's badge answers live on bestpractices.dev. `.bestpractices.json`
# in the repository root is a version-controlled SNAPSHOT of them, pulled from
# the site's own JSON export (served by bestpractices.dev, so it is independent
# of the code host). This is a one-way mirror site -> repo: answers are edited on
# bestpractices.dev, and this target pulls them into version control. The reverse
# (the badge ingesting a committed .bestpractices.json) is NOT available for
# Codeberg-hosted repositories, and the URL-based proposal path is impractical
# because the server rejects the long URLs the full answer set produces.
BADGE_ID  := 13480
BADGE_URL := https://www.bestpractices.dev/projects/$(BADGE_ID).json

# ── bestpractices-json ── MANUAL, network. Download the badge answers and keep
# only the answered criteria (<name>_status in Met/Unmet/N/A plus the matching
# _justification), sorted, so the committed snapshot diffs meaningfully. Review
# `git diff .bestpractices.json` before committing.
# ios-version: regenerates ios/Version.xcconfig from the project's sources of
# truth (the top CHANGELOG.md entry and the Android versionCode), so the iOS
# build carries the same version as the Android one. Run before `xcodegen
# generate`. `ios-version-check` verifies the file exists and is current, and is
# suitable for a release gate.
ios-version:
	python3 tools/gen-ios-version.py

ios-version-check:
	python3 tools/gen-ios-version.py --check

# check-headers: verifies that every project-owned file carries the canonical
# licence header, including the section 7 pointer to the App Store distribution
# exception in COPYING.md. Warnings (a file with no header at all) do not fail;
# a stale header -- GPL notice present, pointer missing -- does. Run
# `make fix-headers` to repair those in place.
check-headers:
	python3 tools/check-headers.py

# fix-headers: inserts the missing section 7 pointer into any header that lacks
# it, reusing that file's own comment leader. Never invents a whole header for
# an unlicensed file; that stays a human decision.
fix-headers:
	python3 tools/check-headers.py --fix

bestpractices-json:
	command -v curl
	curl -fsSL --proto '=https' --tlsv1.2 "$(BADGE_URL)" | python3 -c 'import json,sys; d=json.load(sys.stdin); a={k[:-7] for k,v in d.items() if k.endswith("_status") and str(v).strip() in {"Met","Unmet","N/A"}}; o={k:v for k,v in d.items() if (k.endswith("_status") and k[:-7] in a) or (k.endswith("_justification") and k[:-14] in a)}; json.dump(dict(sorted(o.items())), open(".bestpractices.json","w",encoding="utf-8"), indent=2, ensure_ascii=False); open(".bestpractices.json","a",encoding="utf-8").write(chr(10)); print("bestpractices-json: %d criteria written"%len(a), file=sys.stderr)'
	@echo "bestpractices-json: review 'git diff .bestpractices.json' before committing."

# =============================================================================
# HOUSEKEEPING
# =============================================================================

clean:
	$(MAKE) -C android $@
	rm -f *.patch *.log *.orig

distclean:
	$(MAKE) -C android $@
	rm -f *.patch *.orig

.PHONY: debug device-tests release install store-assets screenshots screenshots-demo-off screenshots-pdf feature-graphics feature-graphics-existing _cascade-feature-graphics report-pdfs rokkitt-bold tgz push push-playstore push-codeberg bestpractices-json clean distclean
