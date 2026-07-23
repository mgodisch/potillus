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
#  store.mk -- Libellus Potionis, store-asset generation (included by ./Makefile)
# =============================================================================
#
#  A root-level INCLUDE, not a standalone Makefile: it runs from the repository
#  root (adb, the fastlane paths and the metadata tree are root-relative) and
#  shares the root Makefile's strict shell settings. It is not invoked as
#  `make -C make/ ...`; you run `make report-pdfs-android` at the root.
#
#  THIS revision covers store STRAND B for Android: the per-locale report PDFs and
#  the report-page screenshots 07/08 derived from them. (Android STRAND A --
#  screenshots 01..06 -- and the iOS store assets are later revisions. Per project
#  decision the iOS report PDFs stay TRANSIENT, produced inside the iOS screenshot
#  run, so there is deliberately no report-pdfs-ios.)
#
#  Nothing here runs automatically. Exporting the PDFs needs a device AND manual
#  "Save as PDF" interaction, so report-pdfs-android runs ONLY when invoked by
#  name; the rasterization is device-free but still explicit.
# =============================================================================

# ── Store locales ────────────────────────────────────────────────────────────
# EVERY store locale under the metadata tree. Each locale dir carries a
# changelogs/ sub-dir, so globbing those and stripping the suffix yields exactly
# the locale set (and skips non-locale files, which have no changelogs/). This is
# self-maintaining -- adding fastlane/metadata/android/<locale>/ extends the set
# automatically -- and fastlane/Screengrabfile derives the SAME set the same way,
# so the two cannot drift.
SCREENSHOT_LOCALES := $(sort $(notdir $(patsubst %/changelogs,%,$(wildcard fastlane/metadata/android/*/changelogs))))

META               := fastlane/metadata/android
# The per-locale report PDFs live under report-pdf/android/. The report-pdf/ios/
# sibling is reserved for a possible future iOS export; today the iOS report PDFs
# stay transient (produced inside the iOS screenshot run), so it does not exist.
REPORT_PDF_DIR     := fastlane/report-pdf/android
SCREENSHOT_PDF_DPI := 200
# The instrumentation component: the debug applicationId (de.godisch.potillus + the
# `.debug` suffix from app/build.gradle.kts) plus the `.test` androidTest suffix,
# with the AndroidX JUnit runner.
INSTR := de.godisch.potillus.debug.test/androidx.test.runner.AndroidJUnitRunner

# ── In-app screenshot capture, Android (strand A) ────────────────────────────
# The capture pins its perspective in-app (ScreenshotClock/DayResolver) to match
# SCREENSHOT_DATE; the demo fixture (fastlane/demo-backup.json) covers 2026-01-01
# ..2026-06-30, so the pinned "today" has meaningful content.
SCREENSHOT_DATE    := 2026-06-30
# Force an exactly-2:1 panel so every capture satisfies Play's aspect rule with no
# post-crop; both overrides are reset by screenshots-demo-off-android.
SCREENSHOT_SIZE    := 1428x2856
SCREENSHOT_DENSITY := 640
SCREENSHOT_CLOCK   := 1000
# The in-app clock pin (must agree with SCREENSHOT_DATE) and the demo fixture.
SCREENSHOT_PIN_KT  := android/app/src/androidTest/kotlin/de/godisch/potillus/screenshot/ScreenshotClock.kt
DEMO_BACKUP_JSON   := fastlane/demo-backup.json

# ── In-app screenshot capture, iOS (strand A) ────────────────────────────────
# IOS_SIM_DEVICE must match fastlane/Snapfile: it names both the simulator to query
# and the "<device>-" filename prefix fastlane prepends to every shot, so 07/08
# carry it too and sort after 06.
IOS_SIM_DEVICE ?= iPhone 17 Pro
IOS_APP_ID     := de.godisch.potillus
IOS_SHOTS      := fastlane/screenshots/ios
IOS_SCREENSHOT_LOCALES := $(patsubst fastlane/metadata/ios/%/name.txt,%,$(wildcard fastlane/metadata/ios/*/name.txt))

# ── Feature graphics (derived from strands A + B; no device) ──────────────────
# The renderer draws each locale's 1024x500 Play feature graphic from the app
# icon, the GPLv3 logo, the localized F-Droid badges and the pinned fonts. Every
# input is a prerequisite -- over-approximated on purpose: an unnecessary rebuild
# is cheap, a MISSED dependency ships a stale asset.
FG_RENDERER    := tools/render-feature-graphic.py
FG_SHARED_DEPS := $(FG_RENDERER) \
                  android/app/src/main/res/drawable-xxxhdpi/ic_launcher_foreground.png \
                  fastlane/gpl-v3-logo.svg \
                  $(wildcard fdroid/get-it-on-*.svg) \
                  $(wildcard tools/fonts/*/*)

# The per-locale source PDF for a locale.
report_src = $(REPORT_PDF_DIR)/potillus_report_$(1).pdf

# Pre-flight: pdftoppm (poppler-utils) rasterizes the report pages. $(1) is the
# calling target's name, used as the message prefix.
require-pdftoppm = command -v pdftoppm >/dev/null || { echo "$(1): 'pdftoppm' not found -- install poppler-utils"; exit 1; }

# Pre-flight: Pillow (PIL), used by the iOS report-page letterboxing. $(1) is the
# calling target's name, used as the message prefix.
require-pillow = python3 -c 'import PIL' 2>/dev/null || { echo "$(1): Pillow not found -- install it (Debian: apt install python3-pil, or: pip install pillow --break-system-packages)"; exit 1; }

# Pre-flight: rsvg-convert (librsvg2-bin), used by the feature-graphic renderer to
# rasterize the GPLv3 logo and the F-Droid badges. $(1) is the message prefix.
require-rsvg = command -v rsvg-convert >/dev/null 2>&1 || { echo "$(1): 'rsvg-convert' not found -- install librsvg2-bin"; exit 1; }

# Pre-flight: fonttools, used only by the one-off rokkitt-bold font bake below.
require-fonttools = python3 -c 'import fontTools' 2>/dev/null || { echo "$(1): fonttools not found -- install it (Debian: apt install fonttools, or: pip install fonttools --break-system-packages)"; exit 1; }

# ── Per-locale rules, generated for every store locale via $(eval) ────────────

# report_pdf_sentinel: the per-locale source PDF is a DEVICE artifact -- exporting
# it needs the app running on a device and a manual "Save as PDF" -- so it is never
# produced automatically. Without a rule a missing PDF is a cryptic "No rule to
# make target"; this sentinel replaces that with a friendly hard error naming
# `make report-pdfs-android`. The recipe only ASSERTS presence: a PDF that exists
# is up to date and the recipe never fires, so this does not disturb the
# timestamp-driven rasterization of 07/08 that depends on it.
define report_pdf_sentinel
$(call report_src,$(1)):
	@test -f "$$@" || { \
	    echo "screenshots-pdf-android: required report PDF '$$@' is missing." >&2; \
	    echo "  This is a device artifact and is never exported automatically." >&2; \
	    echo "  Export the per-locale report PDFs first:  make report-pdfs-android" >&2; \
	    exit 1; \
	}
endef

# report_page_rule: rasterize ONE report page. $(1)=locale $(2)=sequence (07|08)
# $(3)=page number (1|2). 07 = page 1, 08 = page 2, both from the same source PDF.
define report_page_rule
$(META)/$(1)/images/phoneScreenshots/$(2)_report_page_$(3).png: $(call report_src,$(1))
	@$(call require-pdftoppm,screenshots-pdf-android)
	@mkdir -p "$$(@D)"
	@echo "screenshots-pdf-android: $(1) p$(3) <- $$(notdir $$<)"
	@pdftoppm -png -singlefile -r $(SCREENSHOT_PDF_DPI) -f $(3) -l $(3) "$$<" "$$(@:.png=)"
endef

# device_screenshot_sentinel: the in-app shots 01..06 come from screenshots-android
# (screengrab on a device) and have NO per-file build rule -- producing them needs a
# device, so a build must never capture them automatically. The pattern rule below
# only ASSERTS presence: a missing shot is a HARD ERROR naming the capture command.
# feature_graphic_rule depends on 01_today.png, so this is what makes a feature-graphics
# build fail cleanly when the screenshots are absent.
define device_screenshot_sentinel
$(META)/%/images/phoneScreenshots/$(1).png:
	@test -f "$$@" || { \
	    echo "feature-graphics-android: required device screenshot '$$@' is missing." >&2; \
	    echo "  This is a device artifact and is never captured automatically." >&2; \
	    echo "  Capture the whole set first:  make screenshots-android" >&2; \
	    exit 1; \
	}
endef
$(foreach shot,01_today 02_calendar 03_statistics 04_drinks 05_add_drink 06_settings,$(eval $(call device_screenshot_sentinel,$(shot))))

# feature_graphic_rule: $(1)=locale. Renders the 1024x500 feature graphic from the
# per-locale caption, 01_today (strand A) and 07 (strand B), plus the shared inputs.
# A GROUPED target (&:, GNU Make 4.3+) so the SINGLE renderer call declares BOTH
# outputs it writes: featureGraphic.png and its high-res companion
# featureGraphic-4K.png. The 4K file is not uploaded to Play, but it IS committed
# and consumed -- README.md links it and GitLab renders it, per locale for the
# translated READMEs -- so make must track and rebuild it too, not treat it as a
# throwaway. (This grouped target is why ../make/guard.mk requires 4.3.)
define feature_graphic_rule
$(META)/$(1)/images/featureGraphic.png $(META)/$(1)/images/featureGraphic-4K.png &: $(META)/$(1)/feature-graphic.txt $(META)/$(1)/images/phoneScreenshots/01_today.png $(META)/$(1)/images/phoneScreenshots/07_report_page_1.png $(FG_SHARED_DEPS)
	@$(call require-rsvg,feature-graphics)
	@$(call require-pillow,feature-graphics)
	@echo "feature-graphics-android: $(1)"
	@python3 $(FG_RENDERER) $(1)
endef

# Instantiate the whole per-locale store pipeline (report sentinel, 07/08, feature
# graphic) and collect the outputs.
REPORT_PAGE_PNGS     :=
FEATURE_GRAPHIC_PNGS :=
define store_pipeline_rules
$(call report_pdf_sentinel,$(1))
$(call report_page_rule,$(1),07,1)
$(call report_page_rule,$(1),08,2)
$(call feature_graphic_rule,$(1))
REPORT_PAGE_PNGS     += $(META)/$(1)/images/phoneScreenshots/07_report_page_1.png $(META)/$(1)/images/phoneScreenshots/08_report_page_2.png
FEATURE_GRAPHIC_PNGS += $(META)/$(1)/images/featureGraphic.png $(META)/$(1)/images/featureGraphic-4K.png
endef
$(foreach loc,$(SCREENSHOT_LOCALES),$(eval $(call store_pipeline_rules,$(loc))))

# screenshots-pdf-android: rasterize 07/08 from the per-locale PDFs. DEVICE-FREE --
# it re-renders only the pages whose source PDF changed (real file prerequisites,
# timestamp-driven) and fails via the sentinel above if a required PDF is absent.
# Run it on its own to refresh 07/08 without re-exporting, or let report-pdfs-android
# call it after a fresh export.
screenshots-pdf-android: $(REPORT_PAGE_PNGS)

# feature-graphics-android: render every locale's feature graphic, but ONLY the
# stale ones (real file prerequisites, timestamp-driven; an up-to-date tree is a
# no-op). Explicit -- it is never cascaded from the screenshot/PDF producers.
feature-graphics-android: $(FEATURE_GRAPHIC_PNGS)

# feature-graphics-existing-android: refresh ONLY the feature graphics already on
# disk. $(wildcard) never lists a locale without a featureGraphic.png yet, so this
# can never trip the 01_today sentinel -- handy to re-render after a shared input
# (icon, badge, font) changed without re-capturing anything.
feature-graphics-existing-android: $(wildcard $(META)/*/images/featureGraphic.png)

# report-pdfs-android: the human-in-the-loop per-locale PDF export (STRAND B). It
# drives the app's export once per locale and leaves only the system "Save as PDF"
# dialog to you, with the file name PRE-FILLED as potillus_report_<locale>.pdf.
# The ReportExportTest is gated by `-e reportExport true`, so ordinary test runs
# never open a dialog. Run it on a device whose print stack offers "Save as PDF".
report-pdfs-android:
	# A connected device/emulator (state "device") is required; fail fast BEFORE the
	# build. `set -x` traces the probe so the adb command is visible AT the point it
	# runs (.ONESHELL echoes the whole recipe once, up front); grep aborts here if
	# none is ready.
	set -x
	adb devices
	adb devices | grep -qw device
	{ set +x; } 2>/dev/null
	# Build + (re)install the app + instrumentation APKs. screenshot-apks depends on
	# the android prereq, so this one call also covers the toolchain (no separate
	# `-C android prereq` needed). Any prior copy is removed first so a signature/
	# downgrade mismatch cannot block the install; `-t` is required because the
	# instrumentation APK is marked testOnly. adb's own message is surfaced on failure.
	$(MAKE) -C android screenshot-apks
	adb uninstall de.godisch.potillus.debug      >/dev/null 2>&1 || true
	adb uninstall de.godisch.potillus.debug.test >/dev/null 2>&1 || true
	for apk in android/app/build/outputs/apk/debug/app-debug.apk \
	           android/app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk; do
	    echo "report-pdfs-android: installing $$(basename "$$apk")"
	    out=$$(adb install -t -r "$$apk" 2>&1) || { echo "report-pdfs-android: adb install failed for $$apk:"; printf '%s\n' "$$out" | sed 's/^/    /'; exit 1; }
	done
	# Keep the screen awake for the interactive run.
	adb shell svc power stayon true
	adb shell input keyevent KEYCODE_WAKEUP
	adb shell wm dismiss-keyguard
	echo
	echo ">>> For EACH locale: tap 'Save as PDF' -> Save (name is pre-filled) into"
	echo ">>> the Downloads folder. The run advances automatically after each save."
	echo
	# Trigger the export once per locale (blocks until you finish each dialog).
	# -e testLocale drives the per-locale strings and the pre-filled file name.
	for loc in $(SCREENSHOT_LOCALES); do
	    echo "report-pdfs-android: === $$loc -- waiting for your 'Save as PDF' ==="
	    adb shell am instrument -w -e class de.godisch.potillus.screenshot.ReportExportTest -e reportExport true -e testLocale "$$loc" $(INSTR) >/dev/null || true
	done
	# Pull the saved PDFs from Downloads into report-pdf/android/ (best effort; a
	# missing file just means that locale was skipped/cancelled -- re-run it).
	mkdir -p "$(REPORT_PDF_DIR)"
	for loc in $(SCREENSHOT_LOCALES); do
	    if adb pull "/sdcard/Download/potillus_report_$$loc.pdf" "$(REPORT_PDF_DIR)/potillus_report_$$loc.pdf" >/dev/null 2>&1; then
	        echo "report-pdfs-android: pulled potillus_report_$$loc.pdf"
	    else
	        echo "report-pdfs-android: (no potillus_report_$$loc.pdf in Downloads -- skipped?)"
	    fi
	done
	adb shell svc power stayon false || true
	# Rasterize 07/08 from the freshly pulled PDFs (timestamp-driven), then validate
	# the report pages against Play's phone-screenshot rules. Deliberately does NOT
	# cascade the feature graphics: strand B is independent of strand A (01..06),
	# which the feature graphics also need, so refreshing them is a separate step.
	$(MAKE) screenshots-pdf-android
	python3 tools/validate-screenshots.py --report $(SCREENSHOT_LOCALES)


# =============================================================================
# STRAND A -- in-app screenshots 01..06 (device / simulator; explicit only)
# =============================================================================
#
# The capture needs a device (Android) or the iOS Simulator, which YOU start --
# make never launches one. Independent of strand B: capturing 01..06 neither
# exports report PDFs nor refreshes the feature graphics (that is an explicit
# `make feature-graphics-android`). On iOS, per project decision, the same capture
# run also renders the transient report pages 07/08 (Option C), since the iOS app
# writes them during the screenshot-mode launch that captures 01..06.

screenshots-android:
	# A connected device/emulator (state "device") is required; fail fast BEFORE
	# the expensive build below. `set -x` traces the probe so the actual
	# `adb devices` command is visible AT the point it runs -- .ONESHELL echoes the
	# whole recipe once, up front and far from any failure, so the trace (not that
	# echo) is what shows next to the error. grep aborts here if none is ready.
	set -x
	adb devices
	adb devices | grep -qw device
	{ set +x; } 2>/dev/null
	# 0) Pre-flight: the BUNDLED fastlane must be installed in fastlane before any
	#    expensive work (the Gradle build and the device / Demo-Mode setup below).
	#    The gems are vendored under fastlane/.vendor via `cd fastlane && bundle
	#    install`; if that bundle is missing, the `bundle exec fastlane` capture in
	#    step 5 aborts late with the cryptic "bundler: command not found: fastlane"
	#    (Error 127) AFTER a full build and after toggling Demo Mode. Fail fast with
	#    an actionable message instead — mirrors the pdftoppm pre-flight
	#    checks in screenshots-pdf. `bundle check` only verifies
	#    the bundle is satisfied (it does not load fastlane), so it is cheap.
	command -v bundle >/dev/null 2>&1 || { echo "screenshots-android: 'bundle' (Ruby Bundler) not found -- install Ruby + Bundler 4.0.15, then run 'cd fastlane && bundle install'."; exit 1; }
	( cd fastlane && bundle check >/dev/null 2>&1 ) || { echo "screenshots-android: fastlane gems are not installed in fastlane -- run 'cd fastlane && bundle install' (gems vendor into fastlane/.vendor; Bundler 4.0.15 is pinned in fastlane/Gemfile.lock)."; exit 1; }
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
	# pin_kt reads the date via a [0-9]{4}-[0-9]{2}-[0-9]{2} class rather than by
	# matching the quoted token, so this recipe's double-quotes stay balanced (an odd
	# count throws off editor syntax highlighting).
	pin_kt="$$(sed -n 's/.*SCREENSHOT_DATE[^0-9]*\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\).*/\1/p' "$(SCREENSHOT_PIN_KT)" | head -n1)"
	last_entry="$$(grep -oE '"logicalDate"[[:space:]]*:[[:space:]]*"[0-9]{4}-[0-9]{2}-[0-9]{2}"' "$(DEMO_BACKUP_JSON)" | grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | sort | tail -n1)"
	newest="$$(printf '%s\n%s\n' "$$last_entry" "$(SCREENSHOT_DATE)" | sort | tail -n1)"
	if [ "$$pin_kt" != "$(SCREENSHOT_DATE)" ]; then
		echo "screenshots-android: capture-date pins disagree -- Makefile SCREENSHOT_DATE='$(SCREENSHOT_DATE)' vs ScreenshotClock.SCREENSHOT_DATE='$$pin_kt'. Align the two and re-run."
		exit 1
	fi
	if [ "$$newest" != "$(SCREENSHOT_DATE)" ]; then
		echo "screenshots-android: capture date '$(SCREENSHOT_DATE)' is BEFORE the demo fixture's last logged day '$$last_entry' -- seeded entries would fall on a future day the pinned Today cannot show. Move SCREENSHOT_DATE to on/after '$$last_entry'."
		exit 1
	fi
	# 1) Build the app + instrumentation APKs that screengrab installs.
	$(MAKE) -C android screenshot-apks
	# 2) Demo Mode is torn down no matter how this recipe exits.
	trap '$(MAKE) screenshots-demo-off-android' EXIT
	# 3) Prepare the device: wake, disable animations, pin clock (and, best-effort,
	#    the device date — the capture PERSPECTIVE itself is already pinned in-app).
	adb shell svc power stayon true
	adb shell input keyevent KEYCODE_WAKEUP
	# Force an exactly-2:1 panel so the captures satisfy Play's aspect rule
	# without any post-processing (see SCREENSHOT_SIZE / SCREENSHOT_DENSITY).
	# Both overrides are sticky and are undone by the EXIT trap's
	# `screenshots-demo-off-android`, which runs even on Ctrl-C or a failed capture.
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
	#    `$(MAKE) screenshots-demo-off-android` finds no such target).
	( cd fastlane && bundle exec fastlane screenshots )
	# 7) Enforce the Google Play phone-screenshot requirements on the in-app shots.
	#    Only 01..06 are (re)captured here; the report pages 07/08 are owned by
	#    `make report-pdfs-android` (rendered from the per-locale PDFs, not the device),
	#    which validates them there.
	python3 tools/validate-screenshots.py --in-app $(SCREENSHOT_LOCALES)

# Leave Android Demo Mode and restore the normal device state. Each step is
# tolerant (|| true) so tear-down never fails the build; invoked from the
# `screenshots-android` EXIT trap.
#
# The display overrides deserve special mention: `screenshots-android` forces the panel
# to $(SCREENSHOT_SIZE) / $(SCREENSHOT_DENSITY) so every capture is exactly 2:1
# (see the recipe). Those overrides are STICKY — they survive the make run, a
# reboot and, on a physical phone, the rest of the day. Resetting them here (and
# not at the end of the recipe) means a Ctrl-C or a failed capture leaves the
# device usable, exactly like the Demo Mode teardown. `wm size|density reset`
# restores the panel's native values and is a no-op when nothing was overridden.
screenshots-demo-off-android:
	adb shell am broadcast -a com.android.systemui.demo -e command exit || true
	adb shell settings put global sysui_demo_allowed 0 || true
	adb shell wm size reset || true
	adb shell wm density reset || true
	adb shell settings put global auto_time 1 || true
	adb shell settings put global window_animation_scale 1 || true
	adb shell settings put global transition_animation_scale 1 || true
	adb shell settings put global animator_duration_scale 1 || true

screenshots-ios:
	# A non-interactive `ssh mini make screenshots-ios` gets a minimal PATH, so the
	# Homebrew tools (bundle, xcodegen, pdftoppm, python3) must be put on it first.
	export PATH="/opt/homebrew/bin:$$PATH"
	# 0) Pre-flight the macOS-only tools before any expensive build, mirroring the
	#    screenshots-android checks. xcodegen is verified by `ios-project` itself.
	command -v xcrun  >/dev/null 2>&1 || { echo "screenshots-ios: 'xcrun' not found -- install Xcode and its command-line tools."; exit 1; }
	command -v bundle >/dev/null 2>&1 || { echo "screenshots-ios: 'bundle' (Ruby Bundler) not found -- install Homebrew Ruby + Bundler, then run 'cd fastlane && bundle install'."; exit 1; }
	( cd fastlane && bundle check >/dev/null 2>&1 ) || { echo "screenshots-ios: fastlane gems are not installed -- run 'cd fastlane && bundle install'."; exit 1; }
	$(call require-pdftoppm,screenshots-ios)
	# Step 4 letterboxes the rendered report pages with Pillow, the same
	# dependency the Android feature graphics already require.
	$(call require-pillow,screenshots-ios)
	# 0b) The fastlane SnapshotHelper is git-ignored and vendored once per machine by
	#     `fastlane snapshot init`. Create it on first run; `snapshot init` also drops
	#     a sample Snapfile next to it that we do not want (the real one lives in
	#     fastlane/), so remove that again. A SUBSHELL keeps the cd from leaking.
	if [ ! -f ios/PotillusUITests/SnapshotHelper.swift ]; then
	    ( cd ios/PotillusUITests && BUNDLE_GEMFILE=../../fastlane/Gemfile bundle exec fastlane snapshot init )
	    rm -f ios/PotillusUITests/Snapfile ios/PotillusUITests/SnapfileExample
	fi
	# 1) The one command that produces a buildable Xcode project.
	$(MAKE) -C ios project
	# 2) Capture 01..06 for every locale. fastlane runs from fastlane/ so it finds
	#    its Snapfile/Appfile; a SUBSHELL keeps the cd from leaking (.ONESHELL).
	( cd fastlane && bundle exec fastlane ios screenshots )
	# 3) Render report pages 07..08 from the PDFs the app left in its data container.
	#    `|| true` guards the lookups so a clean, explained failure replaces the raw
	#    grep/simctl exit under `set -e -o pipefail`.
	UDID="$$(xcrun simctl list devices available | grep -F "$(IOS_SIM_DEVICE) (" | grep -oE '[0-9A-Fa-f-]{36}' | head -n1 || true)"
	if [ -z "$$UDID" ]; then echo "screenshots-ios: no available '$(IOS_SIM_DEVICE)' simulator found."; exit 1; fi
	CONTAINER="$$(xcrun simctl get_app_container "$$UDID" $(IOS_APP_ID) data 2>/dev/null || true)"
	if [ -z "$$CONTAINER" ] || [ ! -d "$$CONTAINER/Documents" ]; then
	    echo "screenshots-ios: no Documents container for $(IOS_APP_ID) on $$UDID -- did the capture install and run the app?"; exit 1
	fi
	for loc in $(IOS_SCREENSHOT_LOCALES); do
	    pdf="$$CONTAINER/Documents/screenshot_report_$$loc.pdf"
	    dir="$(IOS_SHOTS)/$$loc"
	    if [ -f "$$pdf" ]; then
	        mkdir -p "$$dir"
	        pdftoppm -png -singlefile -r $(SCREENSHOT_PDF_DPI) -f 1 -l 1 "$$pdf" "$$dir/$(IOS_SIM_DEVICE)-07_report_page_1"
	        pdftoppm -png -singlefile -r $(SCREENSHOT_PDF_DPI) -f 2 -l 2 "$$pdf" "$$dir/$(IOS_SIM_DEVICE)-08_report_page_2" || echo "screenshots-ios: $$loc report has no page 2" >&2
	        echo "screenshots-ios: $$loc <- report pages 07,08"
	    else
	        echo "screenshots-ios: WARNING no report PDF for $$loc ($$pdf)" >&2
	    fi
	done
	# 4) Fit those A4 pages onto the device canvas. Unlike Play, which takes any
	#    side in 320..3840 at up to 2:1, the App Store accepts only real device
	#    resolutions -- so the pages must become exactly as big as 01..06 before
	#    they can be uploaded. See tools/letterbox-ios-report.py for the why.
	python3 tools/letterbox-ios-report.py "$(IOS_SHOTS)" "$(IOS_SIM_DEVICE)"
	# 5) ...and prove it, the way screenshots-android proves its own set with
	#    validate-screenshots.py. This is the last chance to catch a bad size
	#    before App Store Connect does.
	python3 tools/check-ios-screenshots.py

# =============================================================================
# ORCHESTRATOR
# =============================================================================

# store-assets-android: refresh the COMPLETE Android store-image set in one go --
# the in-app screenshots 01..06 (strand A), the report PDFs + pages 07/08 (strand B,
# human-in-the-loop), then every feature graphic. Feature graphics run LAST so their
# inputs (01_today from A, 07 from B) are already fresh; they are timestamp-driven,
# so unchanged locales are a no-op. Each strand needs a device; report-pdfs-android
# additionally needs you to tap "Save as PDF". Run the three separately instead when
# you only want part of the set rebuilt.
store-assets-android:
	$(MAKE) screenshots-android
	$(MAKE) report-pdfs-android
	$(MAKE) feature-graphics-android

# =============================================================================
# FONTS  (one-off; run once and COMMIT the result)
# =============================================================================

# rokkitt-bold: bake the STATIC Rokkitt Bold used for the "F-Droid" wordmark in the
# feature-graphic badge from the upstream VARIABLE font under tools/fonts-src/. The
# renderer pins fontconfig to tools/fonts/ only (for reproducibility), so a
# resolvable static Bold must live there -- a variable font would let freetype pick
# the 700 instance version-dependently. The variable source therefore stays OUTSIDE
# the scanned dir and this target bakes a fixed weight-700 instance INTO
# tools/fonts/Rokkitt/. Run it ONCE and COMMIT the generated Rokkitt-Bold.ttf;
# everyone else then renders byte-identically without needing fonttools installed.
ROKKITT_VF  = tools/fonts-src/Rokkitt/Rokkitt[wght].ttf
ROKKITT_OUT = tools/fonts/Rokkitt/Rokkitt-Bold.ttf

rokkitt-bold:
	$(call require-fonttools,rokkitt-bold)
	@test -f "$(ROKKITT_VF)" || { echo "rokkitt-bold: variable source missing: $(ROKKITT_VF) -- download Rokkitt[wght].ttf (see tools/fonts-src/Rokkitt/README.txt / docs/NOTICES.md)"; exit 1; }
	mkdir -p tools/fonts/Rokkitt
	python3 -m fontTools.varLib.instancer "$(ROKKITT_VF)" wght=700 --update-name-table --output "$(ROKKITT_OUT)"
	cp tools/fonts-src/Rokkitt/OFL.txt tools/fonts/Rokkitt/OFL.txt
	@echo "rokkitt-bold: wrote $(ROKKITT_OUT) -- COMMIT it so the feature-graphic build is deterministic for everyone."

.PHONY: screenshots-pdf-android report-pdfs-android \
        feature-graphics-android feature-graphics-existing-android \
        screenshots-android screenshots-demo-off-android screenshots-ios \
        store-assets-android \
        rokkitt-bold
