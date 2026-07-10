<!-- vim: set et ts=4:
=============================================================================
Libellus Potionis - Privacy-Friendly Alcohol Tracker
Copyright (c) 2026 Martin A. Godisch <android@godisch.de>
=============================================================================

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
details.

You should have received a copy of the GNU General Public License along with
this program.  If not, see <https://www.gnu.org/licenses/>.

=============================================================================
-->

# Libellus Potionis – Changelog

<!-- Add new entries on top! -->
<!-- HEADING CONVENTION: directly below each "## vX.Y.Z" header, write a one-line
     summary formatted as a git commit subject — imperative mood, capitalized, no
     trailing period, at most 50 characters. Leave a blank line, then the detailed
     notes. This makes the entry's first line directly reusable as the subject of
     the release commit/tag (git's recommended ≤50-char subject limit). -->
<!-- RELEASE REMINDER: on every version bump, also add a localized store note
     android/fastlane/metadata/android/<locale>/changelogs/<versionCode>.txt for
     EVERY locale, keeping the set identical across locales. release-check.sh §1
     enforces both that the current versionCode's note exists in each locale and
     that all locales carry the same set of changelog files. -->

---

## v0.81.0

Add accessible capacity symbols and chart labels

This release improves accessibility for colour-vision deficiency and for
screen-reader users, addressing the roadmap's Level-A chart gap and the
"Use of Color" concern on the traffic-light indicator. It additionally folds
in the fixes from the seventh full QA review of the whole tree; those include
user-visible corrections — the statistics trend baseline, the Today card's
monthly average and the PDF report's abstinence figures now honour the
"Statistics From" date and the chosen export range, and the date picker for
that setting no longer blocks the local today on timezones east of UTC — each
listed individually below.

- Drink-days bar: fix the colour at exactly the allowance. The bar turned red
  only once the drink-day count strictly exceeded the maximum, so a user who had
  already spent every permitted drink day but had not yet drunk today saw an
  amber bar next to a red traffic-light dot — the two indicators answered the
  same question, "may I drink now?", differently. A drink day, once spent, stays
  spent for the whole day: at 5 / 5 with today already a drink day the bar is
  amber, because another drink adds no further drink day; at 5 / 5 with today
  still dry it is now red, because the first drink would spend a day that is no
  longer available. Both displays now share one predicate,
  `AlcoholCalculator.drinkDayLimitReached`, extracted from the traffic light's
  own gate, and a test walks the whole grid to keep them in step. The gram bars
  are unaffected: reaching a gram limit leaves no room for the next drink, so
  they stay red at 100 %.

- Alternative status symbols (opt-in). A switch under Settings → Appearance
  makes the traffic-light capacity dot draw a distinct glyph inside its coloured
  circle in addition to the colour: a cross when the limit is reached, a "1"
  when one serving remains, and an up-arrow when there is room for more. This
  adds a shape cue on top of hue, so the three states can be told apart without
  relying on the red/yellow/green colours alone — an aid for red–green
  colour-vision deficiency (WCAG 1.4.1 "Use of Color") when enabled. It is off
  by default; the plain coloured sphere is shown until the user turns it on. The
  flag is `alternativeStatusSymbols` in `AppSettings`, threaded from the setting
  through `TodayScreen`, `DrinksScreen` and the log dialog into `TrafficLightDot`.
- Screen-reader description for the capacity dot. `TrafficLightDot` now carries
  a localized `contentDescription` announcing the capacity state regardless of
  the symbol setting, so TalkBack conveys what sighted users read from the
  colour/glyph. It uses `clearAndSetSemantics` so the dot reads as a single node
  rather than leaking a raw glyph.
- Chart text alternatives (WCAG 1.1.1, Level A). The three statistics charts —
  `AlcoholBarChart`, `ValueBarChart` and `CategoryDonutChart` — are drawn on a
  bare `Canvas` and were previously invisible to a screen reader. Each now
  exposes a summarising `contentDescription` via `semantics`; the generic
  `ValueBarChart` takes an optional caller-supplied label, which `StatsScreen`
  fills from the existing "time of day" and "weekday" section headings.
- Custom clickable surfaces get a button role (WCAG 4.1.2 Name, Role, Value).
  The calendar month-grid day cells and the year heat-map day cells are plain
  `clickable` `Box`es; they now declare `role = Role.Button` so assistive tech
  announces them as actionable. The month cells additionally gain a "date,
  grams, status" `contentDescription` (reusing the year heat-map's caption
  strings, so no new locale keys), exposing the over/under-limit state that was
  previously conveyed only by the dot's colour.
- Backups. The new preference is written into JSON backups within backup
  format 3 as an optional field, so no format bump is needed: an older
  format-3 backup that lacks the key restores with the setting defaulting to
  off, and a REPLACE (full) restore applies it while a MERGE keeps the local
  value — matching how the other settings behave.
- Localization. Eight new string keys (three capacity-state descriptions, the
  toggle title and summary, and three chart descriptions) were added to all 21
  locale files, keeping every locale complete for `LocaleSyncTest`.
- Tests. `SettingsViewModelTest` covers the new setter and its round-trip
  through restore; `BackupManagerTest` covers the settings round-trip with the
  new field and the tolerant default when a format-3 backup omits the key.
- Docs. Added `docs/WCAG_LEVEL_A_CHECKLIST.md`, a manual WCAG 2.2 Level A
  self-assessment protocol tailored to the app (per-criterion pass/fail, a
  per-screen TalkBack walkthrough and a sign-off template) to guide the
  on-device evaluation these accessibility changes prepare for.
- Build & release tooling (Makefile / fastlane). Two new fastlane lanes in
  `fastlane/Fastfile` upload the signed AAB together with the full store
  metadata to Google Play: `testing` targets the closed-testing alpha track
  (status completed) and `production` targets the production track staged as a
  draft for manual review; both share a `private_lane :upload_release` helper
  and neither builds the bundle. The root Makefile gained matching upload-only
  targets `push-playstore` (drives the `testing` lane) and `push-codeberg`
  (creates a Codeberg/Forgejo release for the already-pushed tag over the REST
  API and attaches the release APK + SBOM). Both fail fast when a prerequisite
  is missing and read their secrets from git-ignored files
  (`fastlane/play-store-credentials.json`, `fastlane/codeberg-credentials.txt`).
- Device-free default build. The on-device instrumentation tests were split out
  of the default `debug` target into a separate `device-tests` target, so the
  everyday build (release gate, lint, JVM unit tests, guide/copyright sync,
  debug APK) no longer needs a device; `release` now refreshes the screenshots
  and feature graphics and then builds the signed APK, AAB and SBOM in one step.
- Makefile hygiene. Recipes now echo the commands they run (secrets stay in
  shell variables, so no token value is printed); tool-presence checks were
  reduced to plain `command -v` guards that fail fast under the Makefiles'
  strict shell flags; a redundant `-` ignore-errors prefix was dropped from the
  Demo-Mode tear-down, where the per-command `|| true` already makes each step
  best-effort; and the in-Makefile target overviews / `help` texts were
  brought back in sync with the current target set.
- Statistics trend vs. "Statistics From" (seventh QA round): the trend arrow
  and percentage on the Statistics screen compared the current period against
  a previous-period baseline that ignored the configured statistics start
  date. With a floor inside or after the previous window, the baseline summed
  entries the setting promises are "ignored in all statistics"
  (`stats_from_desc`). The baseline query and its per-day divisor are now
  clipped to the same floor as the current period; a window entirely before
  the floor yields no baseline and the trend reads FLAT, exactly like the
  no-history case. Pinned by a new `StatsViewModelTest` regression test.
- Today card monthly average vs. mid-month "Statistics From" (seventh QA
  round): a statistics start date INSIDE the running month was ignored by the
  Today card — its monthly average kept anchoring at the 1st of the month, so
  excluded entries and days entered sum and divisor, disagreeing with the
  Statistics screen's correctly clipped MONTH view. The card's month anchor is
  now clamped to the floor; sum, filter and divisor cover the identical span.
  Pinned by a new `TodayViewModelTest` regression test.
- PDF report abstinence figures for historical export ranges (seventh QA
  round): a report over a range that ended in the past anchored its "current"
  and "longest abstinence" at the REAL today, counting every day from the last
  in-range drink until now as abstinent — including post-period days on which
  the user did drink. The streaks now anchor at the period end (range end + 1
  day) for historical ranges and keep the real-today anchor when the range
  ends today, preserving the Statistics-screen parity for the default export.
  `StatsViewModel.exportPdf` threads the chosen range end through
  `PdfReportBuilder.buildHtml` into `PdfReportData.from`; two new
  `PdfReportDataTest` cases pin both anchors.
- "Statistics From" date picker timezone bound (seventh QA round): the picker
  capped selectable days at the UTC calendar day, so east of UTC the user's
  local today was unselectable for up to the zone offset after midnight, and
  west of UTC the local tomorrow was briefly selectable. The bound now derives
  from the local calendar day (read through `DayResolver.clock()`, matching
  the export range dialog and the screenshot-pinning convention).
- Backup restore validates the language tag (seventh QA round): a restored
  `language` value is now matched case-insensitively against
  `SupportedLocales` and canonicalised; unknown tags degrade to the
  follow-system sentinel instead of being persisted and applied verbatim from
  a hand-edited file. Covered by new `BackupManagerTest` cases.
- Feature-graphic renderer refuses to run with missing bundled fonts (seventh
  QA round): fontconfig silently substitutes a missing family, so an absent
  face under `tools/fonts/` (e.g. the statically instanced Rokkitt Bold, see
  `make rokkitt-bold` and COPYING.md) would have set the F-Droid badge text in
  the wrong typeface without any warning. `tools/render-feature-graphic.py`
  now checks the exact bundled font files up front and fails loudly with the
  recovery command.
- Documentation corrections (seventh QA round): the Keystore KDoc no longer
  claims StrongBox backing (`KeystoreSecretStore` / `AppPreferences` — the key
  is TEE-backed; StrongBox would require `setIsStrongBoxBacked(true)`, which
  is deliberately not requested); the `DrinkDaysBar` KDoc now describes the
  trailing 7-day window instead of the pre-v0.62.0 "Mon–Sun week"; the
  unreachable `application/pdf` chooser branch in `SettingsScreen`'s share
  effect (dead since CSV/PDF export moved to Statistics and the PDF path
  stopped producing a file) was removed; and COPYING.md's build-time tooling
  list gained the KSP, Kover and ktlint Gradle plugins alongside the already
  listed CycloneDX plugin.
- Screenshot pipeline captures at an exact 2:1 instead of cropping (seventh QA
  round, follow-up): `make screenshots` now overrides the capture device's
  display to 1428x2856 @ 640 dpi (`SCREENSHOT_SIZE` / `SCREENSHOT_DENSITY`, an
  exact 2:1 at ~357 dp usable width), so Google Play's max-2:1 rule is met by
  construction and the store shots show the full, uncropped app. The former
  `screenshots-crop` step and `tools/crop-screenshots.py` are removed with it,
  and any device geometry is now acceptable. Two robustness fixes on top of that
  change: the sticky `wm size` / `wm density` overrides are reset in
  `screenshots-demo-off`, so the EXIT trap restores the device even after a
  Ctrl-C or a failed capture (previously a phone stayed scaled indefinitely);
  and the `require-pillow` pre-flight — dropped with the crop step — is
  reinstated for `feature-graphics`, because `tools/render-feature-graphic.py`
  still imports PIL for the phone mockup and would otherwise fail with a bare
  ImportError. All 21 locales' in-app screenshots 01..06 are recaptured at the
  new geometry; store assets only, no app behaviour change.
- Screenshot capture waited on the wrong signals (eighth QA round): the store
  assets disagreed across languages although every locale renders the same
  `fastlane/demo-backup.json` — e.g. `01_today.png` showed a monthly average of
  0.0 g/day in 14 of 21 locales and the correct 8.0 g/day in the other 7. The
  captures waited for STATIC elements (a nav label, or the mere disappearance of
  an empty-state label), which are laid out in the very first frame; every screen
  ViewModel, however, publishes its state through `stateIn(..., <UiState>())`,
  whose all-empty SEED is shown until the backing Room Flow emits. Whether a run
  caught the seed frame was pure timing luck, and the luck differed per locale
  because the capture language switch recreates the Activity — and its
  ViewModels — only in locales other than the device language. Two further
  symptoms had the same root: `02_calendar.png` was captured without day markers
  and without the day-detail card in 6 locales, and `04_drinks.png` showed the
  empty "no drinks" screen in 7 (its wait for the DISAPPEARANCE of that label was
  satisfied vacuously while the page had not composed yet, so its timeout never
  fired). `ScreenshotTest` now routes every capture through one helper that
  enforces a two-stage readiness contract: the screen must expose a POSITIVE,
  data-derived marker that cannot exist in the seed state (the month name in the
  Today caption, the Calendar's day-detail label, the fixture's period total on
  Statistics, a drink row's edit icon), and that marker must then be visible in
  the device's own accessibility tree with the device idle. The second stage also
  fixes `06_settings.png`, which showed the Drinks screen in 9 locales: the
  previous wait proved only that the Settings destination had COMPOSED, while
  screengrab grabs the compositor's surface, which was still drawing the
  predecessor. Both stages now fail loudly instead of silently saving a wrong
  asset. Every expected string is resolved through the same sources production
  uses (localized context, `FULL_STANDALONE` month names on the detected app
  language tag, `Double.fmt1`), so the markers cannot drift from the rendered UI
  in any of the 21 languages. Test-only change; no production code is touched.
  The committed PNGs still show the old captures and must be refreshed with
  `make screenshots`.
- Two-text rows no longer break in verbose languages (eighth QA round): on the
  Today card the drink-days label and its week range shared a `SpaceBetween` row
  in which BOTH texts were measured at their intrinsic width. A long localized
  label ("3 / 5 дней с алкоголем (последние 7 дней)", "0 / 5 μέρες κατανάλωσης
  (τελευταίες 7 ημέρες)") then claimed the whole row and the week range was
  squeezed into the remainder, where it wrapped mid-token into a ragged second
  line touching the label. The fix applies the rule `StatRow` has followed since
  v0.78.0 — weight the FLEXIBLE text, pin the FIXED one to one unbroken line — to
  `DrinkDaysBar`, `LimitBar` and the Today card's caption and headline rows. In
  the affected languages the left label now wraps to a second line instead of
  displacing the range, so those rows are one line taller; no text is truncated.
  The same measurement trap was closed at three further sites found by sweeping
  every two-child `Row` in the UI: the Settings rows for body weight, daily
  limit, 7-day limit, max drink days, day-change time and statistics-start date
  put their label ahead of a fixed-size edit button without a weight (the sibling
  switch rows already had one), and the calendar's month header sat between two
  icon buttons unweighted — a long month name could have pushed the "next month"
  arrow off the row; it is now weighted, centred and ellipsized. Layout only, no
  behavioural or data change.

---

## v0.80.0

Include user settings in JSON backups

The JSON backup now carries the user's settings, closing a data-loss gap:
until now a "restore" on a fresh install brought back drinks and entries but
silently reset every preference — including the body weight that feeds the
blood-alcohol calculation — because the settings live in a separate encrypted
DataStore that the backup never touched.

- Backup format bumped from 2 to 3. The export writes a new top-level
  `settings` object (theme, day-change time, daily/weekly limits, max drink
  days per week, statistics start date, biometric lock, screenshot permission,
  language and body weight). Older apps that only understand versions 1–2
  reject a v3 file via the existing "version too high" guard rather than
  dropping the settings unnoticed.
- Restore semantics: a REPLACE import (full restore) applies the backup's
  settings; a MERGE import keeps the local settings and only adds data, so it
  never surprises the user by overwriting their current configuration. A
  pre-v3 backup has no settings block and leaves the local settings untouched
  in both modes — its drink/entry history still restores exactly as before.
- On import the settings are validated defensively (enum fallback, range
  clamping identical to the preference setters, canonical-date check for the
  statistics start date), so a slightly corrupt or hand-edited backup can
  never abort the restore of the primary drink/entry payload. The
  `weightKg == 0` (not set) and `language == ""` (follow system) sentinels are
  preserved rather than turned into a bogus 1 kg weight or an empty explicit
  locale.
- Restoring a language also re-applies it to the framework per-app locale
  (AppCompatDelegate), matching what the in-app language picker does, so the
  restored language takes effect immediately instead of drifting out of sync
  with the stored preference.
- Dynamic-analysis assertions: added `assert()` invariants to the domain layer
  (`AlcoholCalculator`, `DayResolver`) — the non-negative grams / BAC / limit-
  fraction / serving-count / streak / effective-day-count postconditions and the
  countLimitViolations sliding-window invariant. They are checked under `-ea` in
  the unit-test suite (fault detection during testing) and are no-ops in release
  builds, addressing the gold `dynamic_analysis_enable_assertions` item.
- Tests: settings round-trip and pre-v3 tolerance in BackupManagerTest;
  REPLACE-applies / MERGE-keeps and the weight/language sentinel guards in
  SettingsViewModelTest.

---

## v0.79.0

Work toward OpenSSF gold badge criteria

Development toward the OpenSSF Best Practices gold level (project 13480),
plus the fixes from full QA reviews of the whole tree (the fourth, fifth and
sixth review rounds folded into this release; the fourth was the first covering
every source, resource, tooling and store-metadata file at once, the fifth a
follow-up full pass, the sixth a further full pass focused on accessibility and
data-compatibility documentation). The OpenSSF work is documentation and process
only; the QA fixes include user-visible corrections — Chinese language
detection, the report's longest-abstinence figure, month/date label
localization, the day rollover on the Today screen, the PDF report's CJK glyph
orthography for Japanese/Korean/Traditional-Chinese, and accessible names for
the calendar navigation arrows, the drink-category icon and the year heat-map's
day cells (screen-reader only) — each listed individually below.

- Accessibility — honest conformance documentation (sixth QA round): documented
  the app's accessibility state truthfully and added a regression guard, without
  claiming any WCAG level. `docs/ROADMAP.md` (Accessibility) now states plainly
  that NO WCAG 2.2 conformance level is claimed and NONE of the W3C conformance
  logos is used — because a logo is a formal claim that ALL criteria of a level
  are met under a thorough human evaluation (not done here; W3C is explicit that
  no tool check suffices), there are verified open Level AA items, and the logos
  are web-page scoped rather than native-app scoped — and it lists the measured
  gaps: non-text contrast 1.4.11 (empty heat-map cells 1.1–1.3∶1, today outline
  1.2–1.5∶1, below 3∶1), text contrast 1.4.3 (`onSurfaceVariant` 4.39∶1;
  warning-red as text 3.25–4.23∶1), target size 2.5.8 (10 dp cells), and the
  on-screen chart's missing text alternative 1.1.1 (Level A). README gains a
  factual Accessibility subsection (capabilities, no claim, pointer to the
  roadmap); CONTRIBUTING §4 documents the labelling rule; and
  `.bestpractices.json` (`accessibility_best_practices`) is corrected — the
  heat-map labels are no longer a to-do, the over-broad "adequate touch targets"
  wording is scoped to standard controls, and the entry now states no WCAG level
  is claimed. A new `tools/release-check.sh` §13 (ACCESSIBILITY LABELS) fails the
  build if any `Icon` inside an `IconButton` has `contentDescription = null`, so
  the labels added in this release cannot silently regress (sections renumbered
  "/ 12" → "/ 13"; the check skips gracefully without python3 and is a labelling
  invariant only, not a WCAG conformance test). DELIBERATELY NOT changed: the
  per-locale store `full_description` — a non-conformance is not marketing copy,
  so the accessibility status lives in the roadmap, not the store listing.
  Documentation and tooling only; no app-behaviour change.
- Accessibility — year heat-map day cells (sixth QA round, accessibility
  follow-up): the year calendar's day squares in `YearCalendarView` encoded the
  under- vs. over-limit state by cell COLOUR alone, with no per-cell screen-reader
  label — the last documented accessibility gap on docs/ROADMAP.md
  (`accessibility_best_practices`, WCAG 1.4.1). Each day that carries data now
  exposes a `contentDescription` built from a new `year_calendar_day_desc` string
  ("date, grams, status"), where the status reuses the existing under/over-limit
  legend captions and the date/number are formatted in the per-app locale; empty
  days stay inert and silent so a reader is not flooded with hundreds of "no
  entry" nodes. `year_calendar_day_desc` is a locale-neutral skeleton
  (`%1$s, %2$s g, %3$s`) whose words come from already-localized sub-strings, but
  it is still added to all 21 languages to satisfy `LocaleSyncTest` key parity.
  No on-screen change. NOTE on the colour channel: the under/over palette is blue
  (`primary`) vs. red (`dangerRed`), not a red/green pair, so it is already
  colour-blind distinguishable; an additional non-colour VISUAL indicator is left
  as an optional, low-priority roadmap nicety rather than forced onto the 10 dp
  cells. (docs/ROADMAP.md updated to record the item as screen-reader-done.)
- Accessibility — calendar navigation buttons (sixth QA round): the icon-only
  previous/next arrows for the month view and the year view in `CalendarScreen`
  set `contentDescription = null`, so a screen reader announced only "button",
  with no way to tell previous from next or month from year (WCAG 4.1.2,
  name-role-value). Every other actionable icon in the app already carries a
  localized `contentDescription`; these four were the only exceptions. Added
  four accessibility strings (`cd_prev_month`, `cd_next_month`, `cd_prev_year`,
  `cd_next_year`), translated into all 21 languages, and wired them onto the
  four arrow `Icon`s. Screen-reader only; nothing changes on screen.
- Accessibility — drink-category icon (sixth QA round): `DrinkCategoryIcon`
  used the raw enum constant (`category.name`, e.g. "BEER") as its
  `contentDescription`, which a screen reader read out verbatim and unlocalized.
  Switched it to the localized `DrinkCategory.displayLabel()` already defined in
  the same file, so the icon is voiced in the app's own language. No new strings;
  screen-reader only.
- Statistics export — clock consistency (sixth QA round): the CSV/PDF export
  date-range dialogs fell back to a bare `LocalDate.now()` while the stats flow
  had not yet emitted its `today`, bypassing `DayResolver.clock()` (the
  screenshot clock override) and the configured day-change boundary that every
  other date-relative surface honors. The fallback now reads
  `LocalDate.now(DayResolver.clock())`. It is only a transient placeholder for
  the picker's initial date and is replaced the moment the flow emits, so there
  is no user-visible change; the fix removes an inconsistency with the app-wide
  "derive today from DayResolver" rule.
- Documentation — data-compatibility guarantee (sixth QA round): CONTRIBUTING.md
  §8 now records that, since the first F-Droid release (v0.77.4), the Room
  database and the JSON backup format are guaranteed backward-compatible — Room
  migrations are forward-only and never destructive, and the backup importer
  keeps reading every `BACKUP_VERSION` from that baseline onward. Matching
  breadcrumbs were added to `AppDatabase` and `BackupManager`. While there, a
  stale cross-reference in `AppDatabase` was corrected: the migration workflow
  is documented in CONTRIBUTING.md §8.1, not the §7.1 the comment pointed at.
  Documentation only; no functional change.
- Roadmap — accessibility status (sixth QA round): docs/ROADMAP.md now notes
  that the two accessible-name gaps above are closed, leaving the accessible
  year heatmap (WCAG 1.4.1, color-only day cells) as the remaining documented
  accessibility item. Documentation only.
- Store release notes (sixth QA round): the per-locale versionCode-90 store
  changelogs are deliberately left unchanged. This round's only user-visible
  effect is screen-reader accessible names (nothing changes on screen), which
  the existing "Fixes from a full code review" framing already covers; and the
  English master already sits at 464/500 characters, so adding a sentence would
  breach the store's 500-character limit across locales. versionCode is
  unchanged (these fixes fold into the unreleased v0.79.0).
- PDF report — CJK glyph orthography: the report template's root element now
  carries a per-locale language hint (`<html lang="{{REPORT_LANG}}">`, filled
  by `PdfReportBuilder` from the per-app locale via `Locale.toLanguageTag()`).
  The report is rendered by a WebView (Blink), whose CJK font fallback selects
  the glyph ORTHOGRAPHY — Simplified vs Traditional Han, Japanese kanji, Korean
  hanja — from the document language. Han-unified code points are shared across
  zh/ja/ko but prefer region-specific glyph shapes, so without a `lang` hint
  Blink defaulted to Simplified-Chinese forms: Japanese, Korean and
  Traditional-Chinese reports rendered Chinese-style glyphs for those shared
  characters. Verified in the fifth QA round with `pdffonts` on the committed
  sample reports, which embedded `NotoSansCJKSC` (Simplified) even for `ja`,
  `ko` and `zh-TW`. `PdfReportBuilder` already formats every number/date/label
  with the same per-app locale, so only the glyph orthography was off; the fix
  makes it deterministic on every device. User-visible for Japanese, Korean and
  Traditional-Chinese report exports; Latin locales are unaffected. A new
  `PdfReportLangTest` pins both the template invariant and the substitution
  behaviour (the placeholder⇄builder sync is already enforced by
  `PdfTemplatePlaceholderTest`). NOTE: the pre-rendered sample PDFs under
  `fastlane/report-pdf/` are regenerated on a device by the `ReportExportTest`
  flow and are refreshed on the next screenshot/report run; they are repository
  assets and are not shipped inside the APK.
- `AndroidManifest.xml`: corrected the "HOW TO ADD A NEW LANGUAGE" checklist
  header, which said "all three steps are required" while the checklist lists
  four steps (Step 3 applies to RTL languages only). Comment only; no
  functional change. (Fifth QA round.)
- Build hygiene: investigated the Gradle 9.6.1 deprecation warning "Using a
  Project object as a dependency notation" seen during `:app` configuration.
  A `--warning-mode all --stacktrace` run attributes it to upstream plugins,
  not this project's build scripts: one occurrence originates in Kover
  (`PrepareKover.kt`) and two in the Android Gradle Plugin itself
  (`VariantDependenciesBuilder` while wiring test components). No project build
  script uses the deprecated notation, so there is nothing to fix in-repo;
  recorded here so the warning is not re-investigated and is tracked for the
  eventual Gradle 10 upgrade (to be resolved by future Kover/AGP releases). No
  change. (Fifth QA round.)
- `.bestpractices.json`: reworded the four justifications that quoted a
  concrete release ("currently 0.78.0" in `OSPS-BR-02.01`/`OSPS-BR-02.02`/
  `version_unique`, "e.g. v0.78.0" in `version_tags`) to be release-agnostic
  — the versionName/versionCode statements now point at their defining
  location (`android/app/build.gradle.kts`) and the tag statement describes
  the `v<versionName>` scheme. The self-assessment can no longer go stale on
  version bumps; the substance of the answers is unchanged. (Found by the
  claims-vs-tree consistency scan of the QA delta review; the file said
  0.78.0 while the tree was 0.79.0.)
- QA delta review (three verified findings against v0.79.0, independently
  reported by a skill-guided review run and confirmed at the source):
  - `KeystoreSecretStore.openWithKey` now throws `GeneralSecurityException`
    (instead of `require`'s `IllegalArgumentException`) for a blob too short to
    contain an IV. `open()`'s public contract promises GSE for ANY malformed
    blob and `AppPreferences` catches exactly that family to translate
    decryption failures into a DataStore `CorruptionException` — so a truncated
    (partially written) preferences file used to BYPASS the
    `ReplaceFileCorruptionHandler` and crash the read instead of self-healing.
    The unit test that had pinned the wrong exception type was corrected and a
    boundary-case test (exactly IV-sized blob → authentication failure, not
    length failure) added; both executed on the JVM.
  - `YearCalendarView` builds its month-abbreviation formatter with the per-app
    `formattingLocale()`; the pattern previously carried no locale, so the year
    calendar's month labels followed the SYSTEM language on every API level —
    against the project's own "never Locale.getDefault() for user-visible
    text" rule.
  - `formatStatsDate` (Settings/Stats date range) uses the locale's LONG date
    style instead of the hardcoded `"d. MMMM yyyy"` pattern: passing a locale
    to a hardcoded pattern localizes only the month NAME, while field order and
    punctuation stayed German for every language ("28. June 2026" instead of
    "June 28, 2026"). Minor visible change for German users: none (LONG for de
    is "28. Juni 2026").
- Per-file licensing: added the project's standard GPL copyright-and-licence
  header to the remaining hand-authored source files that lacked it — eight XML
  files (the manifest, the two adaptive-icon mipmaps, the colour and theme
  resources, `data_extraction_rules.xml`, and `locale_config.xml`) and four
  configuration files (`libs.versions.toml`, `gradle-daemon-jvm.properties`,
  `.editorconfig`, and `version-anchor`). Every hand-authored source file now
  carries both a copyright statement and a licence statement (gold criteria
  `copyright_per_file` and `license_per_file`). No functional change.
- Contributor onboarding: added a "Good first issues" subsection to
  CONTRIBUTING.md that identifies small, self-contained tasks for new or casual
  contributors (native-speaker translation review, documentation, and test
  cases) and points to the tracker's `good first issue` label (gold criterion
  `small_tasks`).
- Security policy: docs/GOVERNANCE.md now documents that any account with write
  access to the canonical repository must have cryptographic two-factor
  authentication (a TOTP app or a hardware key, not SMS) enabled, since the forge
  offers no per-project 2FA enforcement (gold criteria `require_2FA` and
  `secure_2FA`).
- Code review: added a "Code review requirements" subsection to CONTRIBUTING.md
  documenting how review is conducted (single reviewer and merger; the reviewer
  runs the build, tests, and release gate locally), an explicit checklist of what
  is checked, and the acceptance criteria for merging (gold criterion
  `code_review_standards`).
- Security review: `docs/ASSURANCE_CASE.md` now records a dated security review
  (2026) that takes into account the security requirements (SECURITY.md,
  "Security model") and the security boundary (threat model and trust
  boundaries), combining the assurance-case analysis with an Android-focused QA
  pass over the security-relevant code (gold criterion `security_review`).
- Test coverage: integrated Kover and expanded the JVM unit-test suite to measure
  statement and branch coverage over the unit-testable code (the Compose UI, the
  Android-runtime-bound layers — database, preferences, Keystore, PDF/WebView, and
  the MediaStore import/export marked `@AndroidIoBound` — the app entry points,
  and generated code are excluded and covered by instrumented tests instead).
  Statement coverage now reaches ~97% and branch coverage ~80%. A build-breaking
  floor (`koverVerify`: LINE >= 90, BRANCH >= 75 over that scope) is wired into the
  release gate (`tools/release-check.sh --coverage`, `make cover-check`) so
  coverage cannot silently regress. This meets silver `test_statement_coverage80`,
  gold `test_statement_coverage90`, and passing `test_most`; the gold
  `test_branch_coverage80` criterion (and the `dynamic_analysis` it unlocks)
  remains a priority-2 roadmap goal, as the last branches sit in
  Android-/Compose-adjacent code.
- Supply-chain hardening: pinned the Gradle distribution by checksum
  (`distributionSha256Sum` in `gradle-wrapper.properties`) so Gradle verifies every
  download against a known-good hash, and documented the wrapper-regeneration step
  that refreshes the pin on a Gradle bump (CONTRIBUTING.md §7). This keeps the
  committed `gradle-wrapper.jar` a stock, verifiable wrapper (OSPS Baseline
  `OSPS-QA-05.02`). No functional change.
- Documented the commit-signing and fast-forward-only merge workflow now enforced
  by branch protection — signed commits required on every branch except `main`,
  `main` merged fast-forward-only — in CONTRIBUTING.md §2, and noted commit-signature
  verification (`git log --show-signature`) in SECURITY.md. Also corrected the DCO
  auto-sign-off tip: `format.signOff` affects `git format-patch`/`git send-email`,
  not `git commit`, so it does not sign off ordinary commits; use a `commit -s`
  alias or a `prepare-commit-msg` hook instead. Documentation only; no functional
  change.
- Added `.bestpractices.json` (repository root) as a version-controlled snapshot
  of the project's OpenSSF badge answers — the metal series (passing, silver, gold)
  and OSPS Baseline Levels 1 and 2 — together with a manual
  `make bestpractices-json` target that refreshes it from bestpractices.dev's own
  JSON export. This is a one-way site -> repo mirror: the badge automation does not
  ingest a `.bestpractices.json` from a Codeberg repository, and the URL-based
  proposal path is impractical because the server rejects the long URLs. No
  credentials are used. Metadata/tooling only; no functional change.
- SECURITY.md: added a "Security advisories" section documenting that confirmed,
  fixed vulnerabilities are published through predictable public channels — the
  CHANGELOG release notes and the corresponding Codeberg release — stating the
  affected version(s), how a user can determine whether they are affected, and the
  remediation. Satisfies OSPS Baseline Level 2 `OSPS-VM-04.01`. Documentation only;
  no functional change.
- SECURITY.md: reworded the link to the assurance case to use human-readable link
  text (matching the rest of the docs), resolving a `tools/md-syntax.py` warning.
- SECURITY.md: added a "Secrets and credentials" section defining the project's
  policy for its secrets (release signing keystore, Google Play upload credentials,
  and the maintainer's OpenPGP key) — how they are stored (never committed;
  git-ignored with structure-only templates; environment-variable injection),
  accessed (held solely by the maintainer on trusted machines), and rotated.
  Satisfies OSPS Baseline Level 3 `OSPS-BR-07.02`. Documentation only; no functional
  change.
- SECURITY.md: added a "Support" section stating the project's support model — a
  single-maintainer rolling release in which only the latest version is supported,
  the scope (best-effort bug fixes and security updates shipped in new releases, no
  back-porting) and duration of support, and when a version stops receiving security
  updates. Satisfies OSPS Baseline Level 3 `OSPS-DO-04.01` and `OSPS-DO-05.01`.
  Documentation only; no functional change.
- docs/GOVERNANCE.md: extended "Repository access and account security" with a
  policy that code collaborators are reviewed and approved before being granted
  escalated permissions to sensitive resources (write/merge access, release
  secrets), with least-privilege grants and identity vetting. Satisfies OSPS
  Baseline Level 3 `OSPS-GV-04.01`. Documentation only; no functional change.
- Release process: every published Codeberg release is accompanied by the build's
  CycloneDX SBOM as a release asset. `android/Makefile` `release`/`bundle` (which
  already build the SBOM alongside the artifact) now also print its path, and
  CONTRIBUTING.md §7 adds attaching it as a release-checklist step. Every released
  version is thus delivered with its software bill of materials, satisfying OSPS
  Baseline Level 3 `OSPS-QA-02.02`. No change to the build artifacts themselves.
- docs/ROADMAP.md: added a "Working toward OpenSSF Baseline Level 3" section
  recording the remaining Level 3 gaps — the structural walls shared with the gold
  tier and a future VEX feed for `OSPS-VM-04.02` — and marked Level 3 as in
  progress. Documentation only; no functional change.
- SECURITY.md ("Dependency monitoring"): documented that every dependency must be
  under a license compatible with the project's GPL-3.0-or-later distribution and
  that incompatible-license findings are remediated before release, defining the
  project's SCA remediation threshold for both vulnerabilities and licenses (OSPS
  Baseline Level 3 `OSPS-VM-05.01`). docs/ROADMAP.md: recorded the future
  CI-based automated, blocking policy gates (`OSPS-VM-05.03`, strengthening
  `OSPS-VM-06.02`). Documentation only; no functional change.
- Screenshots: pin the capture date in-app so `make screenshots` no longer
  depends on the device date. Every date-relative surface derives "today" from
  `DayResolver.today()`, which read the raw device clock; the `screenshots`
  target tried to pin that clock via `adb shell date`, but that only works on an
  emulator or a rooted userdebug build and silently no-ops on a locked
  production phone — so captures used the REAL date instead of the intended
  perspective (2026-06-30, the last day of the demo period). Fix: `DayResolver`
  gains a test-only `clockOverride` (null in production, so shipped behaviour is
  unchanged); a new androidTest helper `ScreenshotClock` pins it to 2026-06-30,
  and both capture tests (`ScreenshotTest`, `ReportExportTest`) set it in
  `@Before` and clear it in `@After`. The perspective is now correct on ANY
  device. The Makefile's device-date pin is demoted to best-effort cosmetics
  (its former "will use the real date" WARNING was made accurate — screenshots
  are unaffected), and a cheap `screenshots` preflight now enforces that the
  Makefile `SCREENSHOT_DATE` and `ScreenshotClock.SCREENSHOT_DATE` agree and
  that the pinned day is not before the fixture's last logged day (2026-06-29,
  so 2026-06-30 is a deliberately dry "today"), preventing the sources from
  drifting apart unnoticed. Test-tooling only; no change to the shipped APK.
  - Follow-up: the in-app pin initially covered only `DayResolver.today()`, but a
    few date-relative surfaces read the wall clock directly and so still showed
    the real date — most visibly the Calendar header/grid (seeded from
    `YearMonth.now()`), which displayed the real month while the day cells showed
    the pinned day, plus the PDF report's "export date" (`LocalDate.now()`).
    `DayResolver` now exposes the effective clock via `clock()` (the pinned test
    clock when set, else the real system clock), and these call sites read
    `YearMonth.now(DayResolver.clock())` / `LocalDate.now(DayResolver.clock())`.
    Production behaviour is unchanged (the clock is the real system clock when
    unpinned). The add-drink dialog's default time-of-day and a non-visible
    export-range fallback were deliberately left as-is (time-of-day, governed by
    Demo Mode; not the date perspective).
- Enforce the ktlint Kotlin-style gate tree-wide and wire it into the default
  build. `./gradlew ktlintFormat` reformatted the whole codebase to the pinned
  ktlint ruleset (long-whitespace, trailing commas, argument wrapping, newline and
  indentation rules). The non-auto-correctable findings were resolved WITHOUT
  churning idiomatic code, via `.editorconfig`: Jetpack Compose `@Composable`
  functions are exempted from the lowercase function-naming rule (PascalCase is the
  Compose convention), and `no-wildcard-imports` (Compose imports whole packages)
  and `backing-property-naming` (the ViewModels expose state through a combined
  `uiState`, so their private `_x` MutableStateFlows have no public `x`) are
  disabled; the intentional package-overview file `ui/screen/ViewModels.kt` is
  exempted from `no-empty-file`. Genuine code fixes: `app/build.gradle.kts` script
  imports made contiguous and comment-free so ktlint can order them; an inline
  value-parameter comment in `DrinkEntity` moved above the parameter; the singleton
  holder `AppDatabase.INSTANCE` renamed to `instance`. Finally `android/Makefile`'s
  `lint` target — on the default `debug` path via `test` — now runs
  `./gradlew ktlintCheck lintDebug`, so a style regression breaks the everyday
  build instead of surfacing only at release time. Style/build-tooling only; no
  functional change to the app.
- Update fastlane v2.236.1 to v2.237.0.
- QA: the PDF report's "longest abstinence" now includes the ongoing dry
  streak, exactly like the Statistics screen. The report called the legacy
  no-`today` overload of `DayResolver.computeLongestAbstinence`, which ignores
  the tail gap after the last drink — so a report could show a *current*
  abstinence larger than the *longest* one (impossible by definition) whenever
  the ongoing run was the user's best. `PdfReportDataTest` pins the tail
  inclusion and the `longest >= current` invariant with a pinned clock.
- QA: first-launch language detection now understands script subtags. Modern
  Android reports Chinese as `zh-Hant-TW` / `zh-Hans-CN`, which the full-tag /
  base-language matcher could not map to the shipped `zh-TW` / `zh-CN` — so
  Chinese users were silently forced to English, persistently (the detected
  tag overrides Android's own resource fallback). `LocaleDetector.detect` now
  matches language+region with the script dropped, disambiguates the remaining
  `zh` variants by script/region (`Hant`/TW/HK/MO → `zh-TW`, otherwise
  `zh-CN`), and folds the Norwegian macrolanguage alias `no` onto `nb`; seven
  new unit tests cover the added steps.
- QA: the Today screen now rolls over to the new logical day while it stays
  open. "Today" was computed once per settings emission, so with the app open
  across the configured day-change time (04:00 by default — late evenings are
  the point of that setting) every date-scoped query stayed pinned to the
  previous day and a drink logged after the boundary was invisible. The
  minute ticker now re-derives the day *outside* the `flatMapLatest` (behind
  `distinctUntilChanged`, so DB queries restart only at the boundary), and the
  Statistics period bounds and the Calendar's today marker follow the same
  pattern. A new `TodayViewModelTest` drives a pinned mutable clock across the
  boundary on virtual time to pin the rollover.
- QA: totals that are exactly AT a limit no longer count as exceeded. Gram
  amounts are stored on a 0.1 g grid, but day/window totals are binary-double
  sums (the 7-day window even incrementally maintained), so an
  exactly-at-limit total could drift to e.g. 100.000000000000014 and a strict
  `>` flagged an exceedance the user cannot see — against the app's "displayed
  number == compared number" principle. The new
  `AlcoholCalculator.isOverLimit` (epsilon 1e-6, three orders below the data
  grid) is now the single definition of "over the limit", used by the
  violation counters, the report's over-limit months / binge days / peak-KPI
  warnings / chart bars, and the on-screen limit bar, calendar and chart
  markers. A regression test replays a provably drifting sequence.
- QA: month+year labels (Calendar header, the PDF's monthly table and chart)
  are now built from the CLDR skeletons `yMMMM`/`yMMM` via the new
  `monthYearFormatter` (l10n/LocaleSupport.kt) instead of a literal
  `"MMMM yyyy"` — which showed the wrong field order for Chinese, Japanese
  and Korean ("6月 2026" instead of "2026年6月") and the wrong grammatical
  form for the inflected languages (genitive "czerwca 2026" instead of the
  standalone "czerwiec 2026"). The year view's bare month abbreviations
  switched from `MMM` to the standalone `LLL` for the same reason. Asserted
  on-device by three new `LocaleFormattingInstrumentedTest` cases.
- QA: Swedish compact day+month labels (Today's week range, chart ticks) now
  render day-first ("28/6") as Swedish convention demands. Deriving the label
  from the SHORT date pattern kept sv's ISO-like year-first order, yielding
  "6-28" — and the test suite even pinned that wrong order as expected. The
  derivation now aligns the day/month order with the locale's MEDIUM pattern
  (quoted-literal-safe); a new property test asserts that alignment for every
  shipped locale, so future locales cannot re-enter through the same gap.
- QA: backup import now validates referential integrity at parse time
  (`BackupManager` Guard 5): every entry must reference a drink contained in
  the backup. Previously a dangling `drinkId` (hand-edited or truncated file)
  reached the repository, where the REPLACE path's remap fallback kept the raw
  id — silently attaching the entry to the wrong drink when the number
  happened to match a local preset, or aborting the whole transaction with
  only a generic error otherwise. The repository's fallback is replaced by a
  strict lookup that names the dangling id; two new parser tests cover the
  reject and accept paths.
- QA: store-locale directories renamed to Google Play's store-listing codes.
  The `deploy` lane pushes `fastlane/metadata/android/` to Play, which accepts
  only its fixed language list — 14 of the 21 directories carried bare codes
  Play rejects (`cs`→`cs-CZ`, `da`→`da-DK`, `el`→`el-GR`, `es`→`es-ES`,
  `fr`→`fr-FR`, `it`→`it-IT`, `ja`→`ja-JP`, `ko`→`ko-KR`, `nb`→`no-NO`,
  `nl`→`nl-NL`, `pl`→`pl-PL`, `pt`→`pt-PT`, `ru`→`ru-RU`, `sv`→`sv-SE`);
  F-Droid reads region-qualified codes fine, so nothing is lost there. The
  per-locale sample report PDFs and `screenshots.html` were renamed/retargeted
  along, `render-feature-graphic.py` now keys its CJK font fallback by
  language/region instead of the literal directory name, the capture suites
  resolve their resources via the detected APP language rather than the raw
  store code — `no-NO` vs `nb` is the one pair Android's resource matcher
  does not bridge, which made the screenshot run wait for an English label
  the Norwegian UI never shows and the Norwegian sample report silently
  render in English — and `release-check.sh` §4 gained Check D: every metadata directory must be a
  valid Play code AND map 1:1 (full tag first, then language subtag, `no`→`nb`)
  onto `SupportedLocales.ALL`. The app's resource qualifiers and the
  `docs/guide` templates keep their own — platform-fixed — naming; the
  "add a new language" checklists now document all three ecosystems.
- QA: hygiene — the stale build-script comment claiming the Kover verify
  thresholds are "deliberately NOT enabled yet" (they are enabled and gate
  releases) rewritten; `setDayChangeTime` clamps hour/minute like every other
  preferences setter (belt-and-suspenders, per the class contract); the
  committed `fastlane/report.xml` run artifact removed and gitignored; the
  "170 string keys" counts in two localization checklists made count-free
  (`LocaleSyncTest` owns the number — it is 169 today).
- Rewrote the versionCode-90 user release notes in all 21 store languages:
  they now describe this release's user-visible QA fixes alongside the
  OpenSSF process work (the previous note predated the QA round and claimed
  "no functional changes").
- Build tooling: the store-image pipeline now auto-generates and cascades.
  Missing device screenshots (01..06) are captured automatically the first
  time a feature graphic needs one — a single guarded `make screenshots`
  run (device required), triggered ONLY by genuine absence, never by mere
  staleness (which stays manual, as before). The eight shots are split by
  producer: `make screenshots` now captures only the in-app shots 01..06 and
  then refreshes the feature graphics; `make report-pdfs` owns the report
  pages 07..08 (it now rasterizes them from the freshly exported PDFs) and
  likewise refreshes the graphics — so renewing either half always renews the
  graphics that depend on it. A new `make store-assets` target rebuilds the
  whole set in one go, and a once-per-run stamp guarantees the feature
  graphics render exactly once even when both producers run together (it also
  removes the former double build in `make release`). `validate-screenshots.py`
  gained `--in-app`/`--report` modes so each producer validates only its own
  half. screengrab's own `clear_previous_screenshots` is disabled and replaced
  by a targeted delete of exactly 01..06 in the `screenshots` recipe: screengrab
  globs and deletes ALL `*.png` in each `phoneScreenshots/` directory, so with
  the report pages no longer regenerated by `make screenshots` it would have
  wiped the committed 07/08 without rebuilding them — the recipe now clears only
  the six in-app shots it recaptures and never touches the report pages.
- Deleted `docs/PLAY_STORE.md`.

---

## v0.78.0

Complete L10N for F-Droid; overhaul build tools

Google Play onboarding, an F-Droid badge in the feature graphic, a relocation of
the build tooling, and a handful of user-facing fixes. Beyond those the release
makes no user-facing behavioural change; the rest is documentation, store
assets, build/release tooling and internal QA hardening (see "Licensing, QA
review & hardening" and "Second QA pass" below).

User-facing:
- CSV/PDF export: when the chosen date range contains no entries, show a short,
  self-dismissing Toast ("No entries available.") instead of doing nothing
  visible. Previously this was only a faint inline notice inside the scrollable
  statistics list, so it was easily missed. A successful export is still
  signalled only by the share sheet (CSV) or the system print dialog (PDF).
- In-app language on Android 11–12L (API 30–32): CSV column headers, the whole
  PDF report (labels, date and number formats) and import/export status
  messages now follow the language selected IN THE APP. They previously fell
  back to the SYSTEM language on those API levels, because AppCompat's per-app
  locale back-port localizes only Activity contexts, not the Application
  context the exporters were handed (fixed via `perAppLocalizedContext()`, see
  the second QA pass below). Android 13+ was never affected.
- Locale-correct compact date labels: the Today screen's weekly range and the
  PDF report chart's x-axis ticks now use the LOCALE's day/month order and
  separator ("6/28" for en-US/ja/zh, "6. 28." for ko, "6-28" for sv) instead of
  the hard-coded European "d.M." for every language. For unaffected locales the
  only visible change is the dropped trailing dot ("28.6–4.7" instead of
  "28.6.–4.7.").
- CSV/JSON export reports FAILURE when the file cannot be written: if MediaStore
  hands back no output stream, the app previously claimed success while leaving
  an EMPTY file in Downloads — a silent data-loss trap for a health backup. The
  orphaned file is now removed and the error message shown.
- Statistics chart: the current day no longer shows a green "abstinent" tick
  before it is over. The tick promises a completed, alcohol-free period, but an
  in-progress day is in superposition — it may still become a drink day until the
  configured day-change time. The chart now leaves the current day/period as an
  empty slot until it resolves: a drink is logged (a bar appears) or the period
  closes dry (the tick appears). The rule is enforced in the single shared series
  builder (`ChartBucketing.bucketize`), so the on-screen chart and the PDF report
  cannot drift apart; the PDF, whose range ends at the last recorded day, was not
  visibly affected but now shares the same guarantee. WEEK/MONTH (daily bars) and
  YEAR (monthly bars) are all covered.
- French localization polish (cosmetic, fr only): the bottom-navigation
  "Statistics" tab used the full screen title "Statistiques", which wrapped onto
  two lines in the narrow tab. It now uses a dedicated short tab label ("Stats");
  the screen title and the Settings section header keep the full "Statistiques".
  A new `nav_statistics` string backs the tab in every locale (most repeat their
  full word; only French shortens it). Also, the Statistics row label "Moyenne
  par jour de consommation" was long enough to squeeze its value into a vertical,
  character-by-character stack; it is shortened to "Moy. par jour de conso.",
  matching the wording the PDF report already uses. Regenerated screenshots and
  feature graphics.
- Statistics rows are now hardened against that value-stacking regardless of
  language: the label takes the flexible width (and wraps if long) while the
  value is pinned to a single line. Previously a translation long enough to fill
  the row could squeeze any statistic's value into a vertical, per-character
  stack; this is now structurally impossible in every locale, whatever the label
  length. The French shortening above is the cosmetic nicety on top of this
  general safety net.

New documentation:
- `PRIVACY.md`: the privacy policy required by the Play "App content" section,
  linked from `README.md`. It states the app's actual behaviour — no data
  collection, no network access, on-device storage protected at rest by device
  encryption and the sandbox, and an optional biometric lock handled by Android —
  using the corrected data-at-rest wording (no database-level-encryption
  over-claim; the JSON backup is described plainly).
- `docs/PLAY_STORE.md`: a repeatable runbook for publishing to Google Play
  alongside F-Droid with a single signing identity (own app signing key via PEPK;
  a separate upload key), package-name registration, Play App Signing enrolment,
  the App-content declarations, the closed-testing gate, and versionCode
  discipline.

Store descriptions (all locales):
- Reflow every `full_description.txt` so each paragraph and list item is a single
  line, letting F-Droid and Google Play wrap the text themselves. This fixes the
  mid-sentence hard breaks that F-Droid rendered from the source's fixed-width
  (~80-column) wrapping. List markers are now the Unicode bullet "•", which
  displays as a real bullet on both stores; the previous Markdown `*` showed
  literally on Google Play, which renders no Markdown. Blank lines between
  sections are preserved. Line joining is CJK-aware — Chinese/Japanese fragments
  are rejoined without a space, space-using scripts (including Korean) with one —
  so no spurious spaces are introduced into CJK text. Wording is unchanged; every
  locale stays within the 4000-character store limit.

Feature graphic (`tools/render-feature-graphic.py`):
- Embed the per-locale "Get it on F-Droid" badge (`fdroid/get-it-on-de.svg` and
  `fdroid/get-it-on-en.svg`, both new in this release) in the bottom-LEFT corner
  and the GPLv3 logo in the bottom-RIGHT, with mirrored 48 px margins, a shared
  baseline and a shared visible height. The bottom-right logo is drawn after the
  report "paper" so it sits in front of the tilted PDF screenshot.
- Factored SVG parsing into `_svg_box_and_inner`; added a colour-preserving
  `_badge_nested` (F-Droid brand colours are kept, unlike the recoloured logo)
  and `_svg_ink_bbox`. The badge canvas carries a ~43 px transparent margin, so
  the badge is cropped to its ink box before scaling — otherwise its visible
  height would not match the logo. The shared mark size is kept reduced
  (`logo_w` 96).
- Also render a 4x high-resolution companion (`featureGraphic-4K.png`,
  4096x2000) next to each 1024x500 store graphic, for press/web/print; fastlane
  supply does not upload it, and the `README.md` header embeds this high-res
  version. (Named `featureGraphic-4K.png`; an earlier draft in this cycle called
  it `featureGraphic-hq.png` — the renderer, the `README.md` embed and the two
  committed companion PNGs were renamed to match.)

Feature-graphic localisation:
- Add per-locale marketing copy
  (`fastlane/metadata/android/<locale>/feature-graphic.txt`) for all 19 further
  store locales (cs, da, el, es, fr, it, ja, ko, nb, nl, pl, pt, pt-BR, ro, ru,
  sv, uk, zh-CN, zh-TW), so the deterministic renderer now produces a localized
  feature graphic for every one of the 21 store locales.
- CJK support: bundle Noto Sans CJK Regular (OFL 1.1) under
  `tools/fonts/NotoSansCJK/` — Inter has no CJK/Hangul glyphs — and make the
  renderer CJK-aware. `_char_width` now gives Han/kana/Hangul/fullwidth code
  points a full-em advance, `_wrap` allows a line break between CJK characters
  (they carry no spaces, so a CJK tagline was previously one unbreakable,
  oversized line), and `_build_svg` appends the region-appropriate Noto family
  (SC/TC/JP/KR) after Inter in the text `font-family` for `ja`/`ko`/`zh-CN`/
  `zh-TW`. The CJK glyphs in those locales' F-Droid badges resolve via
  fontconfig's per-glyph fallback to the same bundled font. Latin/Greek/Cyrillic
  locales are unaffected (font-family stays `Inter`).
- Quality pass on the supplied copy: fixed a German phrase that had leaked into
  the Dutch tagline ("ohne kompromissen" → "zonder compromissen"); shortened two
  bullets that overflowed the fixed 150 px label column (nl "app-vergrendeling"
  → "app-slot"; ro reworded to a clean three-line form); and normalized the
  privacy bullet to a spaced "100 %" across the Latin locales, matching
  de-DE/en-US (CJK locales keep their locale-conventional spacing).
- Data-security bullet height fix (el, fr, pl, ru, uk): the feature boxes all
  share one height (the tallest bullet's line count), and in these five wordier
  languages the privacy bullet wrapped to FIVE lines, pushing the four-box stack
  to ~530 px — taller than the 500 px canvas, so it was clipped top and bottom.
  Trimmed each to four lines while keeping the concrete features ("app lock",
  "offline") intact: pl moves the "&" onto the offline line so the app-lock fits
  one line (no word dropped); fr drops the redundant "uniquement"; el/ru/uk drop
  the "100 %" emphasis (already echoed by their "full control" tagline). The
  four-line stack is ~442 px and sits within the canvas (verified against the
  renderer's own wrap and stack-height math).
- Follow-up harmonization: el/ru/uk had dropped the "100 %" prefix above (their
  app-lock term is inherently two lines, so "100 %" was the cheapest line to
  cut). Restored it uniformly by shortening the privacy word so "100 %" fits one
  line again while keeping the full app-lock term: el uses the noun "απόρρητο"
  (confidentiality); ru/uk use "приватно". All 21 privacy bullets now carry
  "100 %" and still render at four lines. NOTE: for ru/uk this shifts a noun to
  an adverb ("приватно" = "privately"), which is fine in marketing register but
  worth a native review; el stays a noun.
- ja/ko feature-graphic polish: the width-based CJK wrap split words mid-run and
  left tiny orphan tails on their own line (ja "プライバシー" → "…プライバシ"+"ー：",
  "レポート" → "…レポ"+"ート"; ko lone "：", "보고서" → "…보고"+"서"). Added explicit
  line breaks at word boundaries in the ja/ko copy (no renderer change) so each
  line ends on a natural boundary and "100 %" sits on its own line, matching the
  Latin locales. NOTE: the exact break points are a native-review detail.
- Each new file carries the same English format-header comment as de-DE/en-US
  (ignored by the renderer) so editors see the title/tagline/bullet contract.
- Add the localized "Get it on F-Droid" badges (`fdroid/get-it-on-<lang>.svg`)
  for every store language, and generalize `_badge_for_locale`: it now selects
  the badge whose tag matches the locale (region kept and lower-cased, e.g.
  `pt-BR` → `pt-br`), then falls back to the bare language and finally to the
  English badge, so locales without their own badge (nb, uk) still render one.
  de-DE/en-US keep resolving to the de/en badge, so the two already-published
  graphics are unchanged. `COPYING.md` now attributes the whole localized badge
  set (same F-Droid artwork source, CC BY-SA 3.0). The CJK badges (ja, ko,
  zh-CN, zh-TW) render correctly via the bundled Noto Sans CJK font (see the
  CJK note above).

Badge fonts (build tooling; not shipped in the app package):
- Bundle the two fonts the badge text needs under `tools/fonts/`: DejaVu Sans
  (DejaVu Fonts license) for "GET IT ON" and Rokkitt (SIL Open Font License 1.1)
  for the "F-Droid" wordmark; both are documented in `COPYING.md`. The static
  Rokkitt Bold is instanced from the checked-in upstream variable font via the
  new `make rokkitt-bold`; the variable source lives outside the pinned font dir
  (`tools/fonts-src/`) so it never competes with the static instance during the
  deterministic render.

Release-check tooling (`tools/release-check.sh`):
- Section 9 (markdown syntax) now also validates `PRIVACY.md`.
- Section 9 no longer swallows its own findings: the checker was invoked as a
  bare `output=$(md-syntax.py …)` assignment, and under the script's `set -e` a
  non-zero exit from that substitution aborted the whole run AT that line —
  before the captured `path:line: message` problems could be printed — so a
  markdown error surfaced only as a bare "Error 1" naming no file. The call is
  now `if`-guarded (a tested context, where `set -e` does not abort), so every
  offending FILE and LINE is printed; an unexpected crash of `md-syntax.py` also
  surfaces its stderr instead of failing silently.
- Section 1 (version consistency) no longer verifies the F-Droid reference
  recipe: the recipe cross-check and its path variable are removed, and the
  recipe (`fdroid/de.godisch.potillus.yml`) is kept only as a static,
  non-maintained backup (a banner in the file states this).

Screenshot pipeline (all store locales):
- `make screenshots` now captures every store locale, not just de-DE/en-US.
  `SCREENSHOT_LOCALES` (Makefile) and the screengrab `locales` (Screengrabfile)
  are both DERIVED from the metadata tree — every
  `fastlane/metadata/android/<locale>/` has a `changelogs/` sub-dir, so globbing
  those yields exactly the locale set and skips the non-locale `screenshots.html`.
  The two derivations match, so capture, cropping, validation and the feature
  graphic always cover the same set, and adding a locale directory extends the
  pipeline automatically. The screenshot instrumentation test already applies
  whatever locale screengrab passes, so no test change was needed.
- `screenshots-pdf` renders report pages 07/08 for every locale from a report PDF
  named EXACTLY for that store locale,
  `fastlane/report-pdf/potillus_report_<locale>.pdf` (`de-DE` uses
  `potillus_report_de-DE.pdf`, `zh-CN` uses `potillus_report_zh-CN.pdf`). There is
  deliberately NO base-language or English fallback: a `fr` graphic must use the
  `fr` report, and `zh-CN`/`zh-TW` (or `pt`/`pt-BR`) must not collapse onto a
  shared PDF -- so a missing per-locale PDF is a hard `make` error (run
  `make report-pdfs`, which exports each PDF under that exact name). The two
  committed reports were renamed from `potillus_report_de.pdf` /
  `potillus_report_en.pdf` to `potillus_report_de-DE.pdf` /
  `potillus_report_en-US.pdf` to match.
- The report pages and feature graphics are proper make FILE targets wired into
  a dependency graph, so `make screenshots-pdf` and `make feature-graphics`
  regenerate only the locales whose inputs actually changed. Each
  `featureGraphic.png` depends on its `feature-graphic.txt`, its `01_today.png`
  capture and its `07_report_page_1.png`; that report page in turn depends on the
  source report PDF, so dropping a newer PDF re-rasterizes the locale's report
  page AND re-renders its feature graphic on the next `make` -- with no separate
  `screenshots-pdf` step. A missing device screenshot now fails with an
  actionable message rather than make's terse "No rule to make target".
- The source report PDFs moved from `fastlane/` into `fastlane/report-pdf/` (the
  `REPORT_PDF_DIR` variable); `make report-pdfs` pulls exports straight there.
- Every feature graphic now tracks the WHOLE `tools/fonts/` tree, not only Inter
  and NotoSansCJK: the badges draw live text in DejaVuSans ("GET IT ON") and
  Rokkitt ("F-Droid"), so those font files are genuine inputs too. Changing any
  bundled font -- or generating the Rokkitt bold via `make rokkitt-bold` --
  rebuilds the affected graphics, closing a stale-asset gap in the earlier deps.
- `featureGraphic-4K.png`, the high-resolution companion the README embeds, is now
  a first-class output: it shares one grouped-target rule with `featureGraphic.png`
  (GNU Make 4.3+), so a single renderer call produces both and `make` tracks both.

Build dependencies -- localized user guides (android/):
- The generated guides (`res/raw*/usersguide.md`) are no longer rebuilt by a
  blanket phony `guides` target on every build. `render-guide.py --make-deps`
  emits, from its single language discovery, one
  `output: template strings.xml render-guide.py` rule per language into `guides.d`,
  which `android/Makefile` auto-regenerates and `-include`s. `prereq` now depends
  on the real `$(GUIDE_OUTPUTS)`, so `make` regenerates a guide only when its own
  template or `strings.xml` changed -- specific per-target prerequisites instead of
  one global catch-all. The shared recipe `touch`es its output because
  `render-guide.py` writes content-based and the file would otherwise look
  perpetually stale; `distclean` also removes `guides.d`.

Report export (semi-automatic, human-in-the-loop):
- New `make report-pdfs` drives the app's PDF report export once per locale so
  producing the 21 source PDFs no longer means 21 fully manual exports. For each
  locale an instrumented test (`ReportExportTest`) opens the system "Save as PDF"
  dialog and then BLOCKS until the app is foreground again; the operator taps
  Save (nothing else) and the run advances. Afterwards the saved files are pulled
  into `fastlane/report-pdf/`, where `screenshots-pdf` already resolves them.
- Why semi-automatic: the production export deliberately routes through the
  platform print dialog (see util/WebViewPdfPrinter), and both fully-silent export
  (needs a non-public print-framework API) and automating the localized dialog
  itself are fragile. So the automation only triggers the export and waits for the
  app to return to the foreground — it never has to read a localized button.
- The dialog's file name is pre-filled as `potillus_report_<locale>.pdf`: the test
  calls the print path directly with that job name. This lives ENTIRELY in the
  androidTest source set; production keeps its timestamped name (unchanged).
- `ReportExportTest` is inert in every other run: an Assume guard skips it unless
  invoked with `-e reportExport true`, so `make test` and `make screenshots` never
  open a dialog. It seeds the same `demo-backup.json` fixture and localizes the
  report via a Context configured for the requested `testLocale`, so the output
  matches the committed de/en reports.
- NOTE: this instrumented test + Makefile target could not be compiled or run in
  the authoring environment (no Android SDK/Gradle/device); it is written against
  the existing ScreenshotTest/screengrab patterns and is to be validated on-device.
- Install step hardened after a first on-device run: the APKs are now installed
  with `adb install -t` (the instrumentation APK is testOnly and is rejected
  without it), any previously installed copy is uninstalled first so a signature
  or downgrade mismatch cannot block the install, and adb's own failure message
  is printed instead of the bare, reason-less "Error 1" seen after "Performing
  Streamed Install". The unused `-g` (no dangerous runtime permissions) was
  dropped.

Root `Makefile` convenience targets and readability:
- Redesigned the everyday entry points into two convenience targets and made
  `debug` the default goal (`.DEFAULT_GOAL`). `make debug` runs the maximal LOCAL
  verification and then the debug APK: through `android/` it drives the
  `release-check` gate (via `prereq`), Android `lint`, the JVM `unit-test`s, the
  on-device instrumentation tests (`test-device`) and the `check-guides` doc-sync
  check, then refreshes any feature graphics already on disk. It is incremental (no
  `clean`) and needs a connected device, since the instrumentation tests do; it
  fails if any code or documentation check requires a correction. The former
  bespoke `default` target (clean + debug + test + copy-to-USB) is gone.
- `make release` refreshes the store assets and then builds the signed artifact:
  `screenshots` (recaptures every locale and rasterizes the report pages from the
  PDFs you exported), `feature-graphics` (rebuilds each locale's graphic whose
  inputs changed), and finally the `android` `release` target (signed release APK
  plus its CycloneDX SBOM). You still supply the per-locale report PDFs yourself.
- New `feature-graphics-existing` target refreshes ONLY the feature graphics that
  already exist on disk (a `$(wildcard)` over the metadata tree). `debug` uses it so
  a screenshot-less working copy never trips the `01_today.png` guard for the many
  locales whose device screenshots are not committed; `release` keeps using the full
  `feature-graphics`, since it captures screenshots for every locale first.
- Removed duplication: the per-tool preflight checks are now single `require-device`,
  `require-pdftoppm`, `require-rsvg`, `require-pillow` and `require-fonttools` helper
  macros (called with the target name as the message prefix), replacing the roughly
  six inline copies. The two report-page rules were folded into one parametrized
  canned recipe (`report_page_rule`; page 1 renders `07_report_page_1.png`, page 2
  renders `08_report_page_2.png`) and the feature-graphic rule into
  `feature_graphic_rule`, both instantiated per locale by `potillus_pipeline_rules`.
  Behaviour is unchanged, verified against the `make -p` database.
- Reorganized the file into labelled sections (configuration, convenience/install,
  screenshots, the report-page/feature-graphic pipeline, PDF export, fonts,
  packaging/deploy, housekeeping) with a targets-at-a-glance index at the top; the
  configuration variables are consolidated together and `screenshots-demo-off` now
  sits beside `screenshots`.

User's guide (all 21 locales):
- Document the app-visibility/lock features and the monthly-average badge. A new
  `### {{security}}` section (rendered from the `security` string) describes the
  `{{biometric_lock}}` and `{{allow_screenshots}}` toggles — the latter is off by
  default (`FLAG_SECURE`), so the window stays out of screenshots and the recent-
  apps overview. It is placed before `### {{appearance}}`, matching the Settings
  screen order (backup → security → appearance).
- The `### {{appearance}}` section is trimmed to what it still covers (color
  theme + language); its former biometric-lock sentence now lives under Security.
- The "{{today}}" screen gains a sentence for the new "Ø" badge (average grams of
  pure alcohol per day for the current month).
- Applied to the English source template and translated into all 20 other
  guide templates (`android/docs/guide/usersguide.<lang>.md.in`). UI labels stay
  as `{{token}}` references so they track `strings.xml`; only the connective
  prose is translated. All required string keys already exist in every locale, so
  `render-guide.py` regenerates all 21 guides cleanly (verified).

Build tooling relocation:
- Move the build/packaging tooling from `android/tools/` to a repo-root `tools/`
  directory (a sibling of `android/`, `fastlane/`, `fdroid/`, `docs/`), since
  these scripts serve the build/release process rather than the app. Re-anchor
  `release-check.sh` (it now cd's to the sibling `android/`),
  `render-feature-graphic.py` and `render-guide.py`, and update the invocations
  in `android/Makefile` and `app/build.gradle.kts` to `../tools/...`. Historical
  CHANGELOG entries are intentionally left referring to `android/tools/`.
- Move the `screenshots` and `feature-graphics` targets (with their screenshot
  helper targets and variables) from `android/Makefile` to the root `Makefile`,
  since they orchestrate repo-wide assets rather than the app build; the Gradle
  build stays in android/ via a new `screenshot-apks` target invoked with
  `$(MAKE) -C android`. `crop-screenshots.py` and `validate-screenshots.py` are
  made cwd-independent (`__file__`-anchored) so they run from the repository root.

Release packaging (`Makefile`):
- Exclude `keystore.properties` and `play-store-credentials.json` from the
  release tarball, and drop the `distclean` dependency of the `tgz` target.
- Derive the `tar` exclude list for the `tgz` target DYNAMICALLY from
  `.gitignore` instead of hard-coding a parallel copy, so the tarball can no
  longer ship files the repository ignores. `.gitignore` patterns are mapped to
  `tar` faithfully: comments/blank lines are dropped; a negation (`!`) aborts the
  build (tar cannot express an un-exclude); root-anchored patterns (those with a
  `/`) get the repo dir prepended and are matched `--anchored`, the rest
  `--no-anchored`; and `--no-wildcards-match-slash` keeps `*` inside one path
  segment (so `/*.pdf` excludes only root PDFs). `.git` is excluded explicitly
  since git does not list it.

Fastlane (`fastlane/Fastfile`):
- The `deploy` lane now defaults to the `internal` track instead of `production`;
  reaching production requires passing `track:production` explicitly. Removed a
  stale reference to a no-longer-existing `PLACEHOLDERS.txt`.

Licensing, QA review & hardening:
- `COPYING.md`: added a "Third-Party Software (bundled in the release APK)"
  section that records the copyright holders and licenses of the runtime
  libraries actually shipped in the APK — the Apache-2.0 AndroidX / Jetpack /
  Compose / Room / DataStore / biometric / tracing stack and the Kotlin +
  kotlinx runtime, plus `desugar_jdk_libs` under GPL-2.0-with-Classpath-Exception
  — and points to the CycloneDX SBOM as the authoritative machine-readable
  inventory. Build- and test-time-only dependencies are listed separately as
  non-redistributed. Previously only the build-time font/badge/logo assets were
  documented; the APK-embedded dependencies were covered by the SBOM alone.
  Documentation only — no code, resource or build change, so nothing user-facing
  or functional is affected.
- `WebViewPdfPrinter`: closed a latent Activity leak in the PDF-export path. The
  off-screen `WebView` was already created from the application context, but the
  `WebViewClient.onPageFinished` closure captured the Activity context strongly to
  reach the `PrintManager`; while the `WebView` was parked in the static `retained`
  field awaiting its page-finished callback, that chain pinned the whole Activity,
  and if the callback never fired (e.g. a load failure) the Activity leaked until
  the next export. The Activity context is now held through a `WeakReference` (the
  print dialog is Activity-scoped UI, so a collected Activity simply means there is
  nothing to print), and `retained` is released on every callback path. No change
  to the successful-export flow (the system print dialog still opens exactly as
  before); the fix only affects the error/never-fires path. The class KDoc and the
  `StaticFieldLeak` suppression rationale were updated to match.
- Backup MERGE: documented that merging also brings over the backup's drink
  catalogue — a custom drink whose name is not present locally is inserted even
  when it has no entries — and that this is intentional and idempotent (a later
  merge re-matches the drink by name). Clarifies the previously entries-only
  wording of the MERGE contract in `BackupManager`, `IBackupRepository` and
  `BackupRepository.buildIdMap`. Documentation only — the import behaviour is
  unchanged; REPLACE likewise restores the full catalogue.
- `DrinkDao.insert`: changed the conflict strategy from `REPLACE` to `ABORT`,
  mirroring `EntryDao.insert`, and corrected the KDoc. Every caller inserts with
  `id = 0` (new-drink add, backup remap, preset pre-population), so Room always
  auto-generates the primary key and no collision can occur — `ABORT` is thus
  behaviourally identical here while making any future explicit-id collision fail
  loudly instead of silently overwriting a row. The previous rationale ("re-insert
  presets without failing on the unique constraint") was inaccurate: the `drinks`
  table has no `UNIQUE` constraint on `name`, and backup de-duplication is done by
  name in `BackupRepository`. No schema/migration impact (the conflict strategy
  affects the generated INSERT statement, not the table definition).

Second QA pass (full-scope re-audit of v0.78.0; folded into this release):
- Per-app locale plumbing: new `Context.perAppLocalizedContext()`
  (`l10n/LocaleSupport.kt`) derives a context carrying the locale list stored
  via `AppCompatDelegate.getApplicationLocales()`. Used per call by the
  `StringProvider`s in `AppViewModelFactory`, by `SettingsViewModel`'s plural
  resolution, and by `StatsViewModel` before handing the context to
  `CsvExporter`/`PdfReportBuilder` — fixing the API 30–32 system-language
  fallback described under "User-facing". The `LocaleSupport.kt` documentation,
  which incorrectly claimed the Application context carries the per-app locale,
  was corrected. The transformation itself lives in an `internal`
  `localizedContextFor(locales)` behind the one-line public facade, and two
  instrumented regression tests (`LocaleFormattingInstrumentedTest`) cover its
  no-op (empty list) and locale-carrying paths with EXPLICIT locale lists —
  deliberately not arranged through `AppCompatDelegate.setApplicationLocales`,
  which on API 33+ reaches the framework `LocaleManager` only via ACTIVE
  AppCompatDelegate instances (verified in the AndroidX source) and is
  therefore a silent no-op in an activity-less instrumented test; an earlier
  test iteration failed on-device for exactly that reason. Production is
  unaffected by that gate: on API 33+ the framework already localizes every
  context, so the facade's empty-read fallback is already correct there.
- New `l10n/DatePatterns.kt` (`shortDayMonthPattern(locale)`): derives the
  compact day+month pattern from the locale's SHORT date pattern via pure
  java.time (JVM-testable, unlike `DateFormat.getBestDateTimePattern`);
  verified against all 21 shipped locales in the new `DatePatternsTest`. Used
  by `TodayViewModel` (weekly range label) and `PdfReportBuilder` (chart tick
  labels).
- `TodayViewModel.addEntry`/`updateEntry` read the settings snapshot from
  `prefs.settingsFlow.first()` instead of `uiState.value.settings`: before the
  first combine emission the hot StateFlow still holds the `AppSettings()`
  DEFAULTS (04:00 day change), so an entry added through that window could be
  filed under the wrong logical date. Matches `CalendarViewModel.addEntry`; the
  comment that argued the opposite was corrected.
- `WebViewPdfPrinter`: the off-screen WebView is now destroyed deterministically
  when the print job ends, via a delegating `PrintDocumentAdapter`
  (`DestroyOnFinishAdapter`) whose `onFinish()` — fired once per job, after
  printing/saving AND after cancellation — releases the native resources.
  Previously the WebView was merely dereferenced and lingered until GC.
- `AppDatabase.PrepopulateCallback` launches on an explicit `Dispatchers.IO`,
  honouring the documented `applicationScope` convention that every launch site
  states its dispatcher (it silently fell back to `Dispatchers.Default`).
- `StatsUiState` default `period` unified to `MONTH`, matching the ViewModel's
  actual initial state; the `stateIn` seed is now plain `StatsUiState()`. This
  also makes `StatsViewModelTest.awaitComputed()`'s documented seed-detection
  assumption (`state == StatsUiState()`) actually hold.
- Compose list hygiene: all `LazyColumn`/`LazyRow` `items()` over entries and
  drinks now pass the stable Room id as `key` (Today, Calendar ×2, Drinks,
  favourites quick-bar), so deletions/reorderings move keyed rows instead of
  rebinding every following position.
- Removed all guarded `!!` not-null assertions from UI code (drink editor save,
  export date-range confirm, import mode dialog) in favour of elvis-return /
  `?.let` guards — crash-free even if the guarding `enabled` conditions are
  ever refactored.
- Dead API removed: `AlcoholCalculator.soberByMillis` (never wired into any
  screen; its four unit tests removed with it) and the repository-level
  `getById` lookups (`IEntryRepository`/`IDrinkRepository`, implementations,
  fakes, `EntryDao.getById`). `DrinkDao.getById` is kept — its sole consumer is
  a white-box assertion in `BackupRepositoryInstrumentedTest` — with a KDoc
  note saying so. `LimitBar` now calls `AlcoholCalculator.limitPercent` instead
  of duplicating the fill-fraction division inline with a subtly different
  zero-limit guard; the domain function is the single source of truth.
- Licensing (COPYING.md): the Apache-2.0 runtime inventory now also names the
  copyright holders pulled in transitively — Square, Inc. (`okio`, via
  DataStore), The Guava Authors (`listenablefuture`, via concurrent-futures),
  The JSpecify Authors (`jspecify`) and `org.jetbrains:annotations` — and a new
  "Third-Party Assets" paragraph records the Roboto (Apache-2.0) and Noto Sans
  CJK (OFL-1.1) subsets embedded in the committed `fastlane/report-pdf/*.pdf`
  samples (verified with pdffonts).
- Licensing (Apache-2.0 §4(a)): the verbatim licence text is checked in as
  `LICENSE.Apache-2.0.md` and bundled into the in-app copyright document —
  `res/raw/copyright.md` is now the three-file concatenation COPYING.md +
  LICENSE.md + LICENSE.Apache-2.0.md (android/Makefile rule, `check-guides`
  comparison and the `generateCopyrightDocument` Gradle task updated in
  lock-step). The `packaging { excludes }` block gained a licence-compliance
  note explaining that the excluded META-INF/AL2.0 + LGPL2.1 entries are
  duplicated notice FILES from the kotlinx-coroutines artifacts, not code, and
  where the licence text is delivered instead.
- Licensing (Apache-2.0 §4(d)): `tools/release-check.sh` gained SECTION 12,
  "THIRD-PARTY NOTICE FILES" — an SBOM-gated scan that resolves every shipped
  component to its Gradle-cache artifact and WARNs on any `META-INF/NOTICE*`
  entry, automating the confirmation step COPYING.md previously prescribed as a
  manual release-process note. Without the SBOM or cache the check reports
  itself as skipped and passes, so the routine debug gate cannot false-fail.
- App Bundle language splits disabled (`bundle { language { enableSplit =
  false } }`): the in-app language switcher requires every locale's resources
  on the device, which Play's default per-language AAB splits would strip — a
  LATENT mismatch that existed ever since the switcher shipped. It surfaced as
  the lint error `AppBundleLocaleChanges` once `perAppLocalizedContext()`
  introduced a `Configuration.setLocales` call the detector recognises
  (`AppCompatDelegate` alone never triggered it); with `warningsAsErrors` that
  failed `lintDebug`/`make debug`. F-Droid APKs are unsplit and unaffected;
  the AAB now carries all 21 locales' string resources (negligible size).
- PDF report footer: the English licence/warranty line is documented as
  DELIBERATELY not localized (legal boilerplate is quoted, not paraphrased).
- Known upstream issue (documented, not fixable in-repo): the Gradle 9.6
  configuration-phase deprecation "Using a Project object as a dependency
  notation" originates in AGP 9.2's internal test-variant wiring — this build
  declares no `project(...)` dependency — and will disappear with a future AGP
  update; tracked at the `allWarningsAsErrors` note in `build.gradle.kts`.

Third QA pass (delta re-audit of v0.78.0; folded into this release):
- CSV export: `CsvExporter.escapeField` now forces RFC 4180 quoting on a field
  that embeds a lone carriage return, not only a line feed. RFC 4180 §2 mandates
  quoting for CR *or* LF; the previous guard tested only `\n`, so an old-Mac
  line ending (a bare `\r` with no accompanying `\n`) in the middle of a note
  could split the record. A leading `\r` was already neutralised as a
  formula-injection trigger; this closes the mid-field case. New unit cases in
  `CsvExporterTest` (`carriageReturn_forcesQuoting`) cover both positions.
- `TodayViewModel`: documentation only. Clarified that its Context-free
  `Locale.forLanguageTag(settings.language)` derivation and the Context-based
  `Context.formattingLocale()` used elsewhere are two views of the SAME per-app
  locale (the language tag and `AppCompatDelegate`'s application locales are
  always written together), so a future reader does not "reconcile" them by
  injecting a Context into this deliberately Context-free, JVM-testable
  ViewModel. A matching cross-reference was added to `LocaleSupport.kt`'s
  "HOW TO USE" note. No behavioural change.
- In-app document viewer (`MarkdownText`): render a Markdown thematic break
  (`---`, `***`, `___`) as a `HorizontalDivider` instead of the literal marker
  characters. The in-app licenses screen concatenates COPYING.md, the GPL text
  and the Apache-2.0 text separated by `---` (see `tools/render-copyright.py`),
  which previously showed as "---" between the sections. Detection is via the
  new `THEMATIC_BREAK_RE`, unit-tested in `MarkdownTextTest`.
- In-app document viewer: decode the `&mdash;` (—) and `&sect;` (§) HTML
  entities, which COPYING.md uses (e.g. "&sect;4(a)") and which previously
  rendered verbatim. Added to the existing `HTML_ENTITIES` table with matching
  `MarkdownTextTest` cases.
- `LICENSE.Apache-2.0.md`: dropped the leading `<!-- … -->` modeline/preamble
  header so the file is now the pure, verbatim upstream Apache-2.0 text. That
  header was concatenated into the in-app copyright document and rendered as a
  literal HTML comment after the second `---` seam. The licence body is
  unchanged (still byte-identical to the upstream original), so the &sect;4(a)
  "copy of the licence" obligation is still satisfied — more cleanly than before.
- Licensing (COPYING.md): the Apache-2.0 &sect;4(d) paragraph now points at the
  automated `release-check.sh` Section 12 NOTICE scan instead of describing the
  confirmation as a manual "the release process should confirm" step, which had
  become stale once that gate was added earlier in this release. Documentation
  only; the transitive runtime inventory was re-verified complete against the
  resolved `releaseRuntimeClasspath` (no missing copyright holder).


- `versionCode` 88 → 89 and `versionName` 0.77.4 → 0.78.0 in `build.gradle.kts`
  and the `README.md` title; localized store notes in `changelogs/89.txt` for all
  21 listing locales now describe the export fix above (all 21 locales are now
  localized; the previously English-only locales were translated).
  The F-Droid recipe is intentionally NOT updated — it is a static backup.

OpenSSF Best Practices (bestpractices.dev) passing- and silver-badge groundwork
(documentation only; no code or user-facing behaviour change):
- README: new "Feedback & Contributing" and "Security" sections. The former
  documents how to obtain the app, report bugs/enhancements (the Codeberg
  issue tracker, or android@godisch.de), and contribute (CONTRIBUTING.md);
  the latter points to the new SECURITY.md.
- CONTRIBUTING.md: new "Submitting changes" section describing the
  contribution process (open an issue first, submit a Codeberg pull request
  or an e-mailed patch, meet the acceptance requirements, pass maintainer
  review); later sections were renumbered and a stale table-of-contents
  anchor was fixed. Accuracy pass to match the code: the architecture map
  now lists the `l10n/` and `data/security/` packages; the `BINGE_THRESHOLD`
  example was corrected from `48.0` g to `60.0` g; the testing-strategy table
  was replaced with the real unit/instrumented test layout; and the
  translation workflow was rewritten around `l10n/SupportedLocales.kt` as the
  single source of truth, noting that only English and German are
  hand-authored while all other locales are machine-generated (native-speaker
  corrections welcome).
- SECURITY.md: new security policy publishing the private
  vulnerability-reporting process — PGP-encrypted e-mail to android@godisch.de,
  the maintainer's key fetched from the official Debian keyserver
  (keyring.debian.org), and a 14-day acknowledgement commitment.
- CONTRIBUTING.md: adopted the Developer Certificate of Origin (DCO) for
  contributions (silver criterion `dco`). Section 2 now requires every commit to
  be signed off (`git commit -s`, adding a `Signed-off-by` line) and links to
  developercertificate.org, clarifying that sign-off is a plain-text DCO
  agreement, not a cryptographic signature. It also notes the
  `git config format.signOff true` convenience setting.
- `docs/GOVERNANCE.md`: new document defining the project's governance model (silver
  criterion `governance`). It states the single-maintainer (benevolent-dictator)
  model, how decisions are made (open discussion on Codeberg, maintainer
  decides and is sole merger), and the key project roles; it is linked from
  CONTRIBUTING.md.
- `CODE_OF_CONDUCT.md`: adopted the Contributor Covenant v2.1 (silver criterion
  `code_of_conduct`), reproduced verbatim under CC BY 4.0 with the enforcement
  contact set to android@godisch.de; linked from CONTRIBUTING.md and recorded in
  COPYING.md's third-party inventory.
- `docs/ROADMAP.md`: new documented roadmap (silver criterion `documentation_roadmap`)
  describing the project's intended directions for roughly the next year and its
  explicit non-goals; the specific items are listed in the file. It also serves
  as the project's task list, tracking the open near-term items ordered by
  criticality. Linked from the README.
- SECURITY.md: added a "Security model" section documenting the software's
  security requirements (silver criterion `documentation_security`) — what users
  can expect (no network/data transmission, least privilege, on-device encrypted
  storage, optional biometric lock, no tracking) and cannot expect (no defence
  on a compromised device, biometric lock is only an access gate, exported files
  leave the app's control, BAC figures are informational).
- README: added a "Quick start" section (silver criterion
  `documentation_quick_start`) — a short numbered guide for new users to install
  the app and log their first drink, see their status, and optionally set limits
  or export data.
- Build: adopted ktlint for automatic Kotlin style enforcement (silver criterion
  `coding_standards_enforced`) via the org.jlleitschuh.gradle.ktlint plugin
  (14.2.0), a repository-root .editorconfig selecting the official Kotlin
  conventions, and a CONTRIBUTING.md §4 note. ktlintCheck runs under `check`
  and is build-time only (not on the release-assembly path), so the APK and
  reproducible builds are unaffected.
- SECURITY.md / CONTRIBUTING.md: documented a periodic dependency
  vulnerability-monitoring process (silver criterion `dependency_monitoring`) —
  external dependencies are scanned with osv-scanner against the CycloneDX SBOM
  before each release, with a matching item added to the §7 release checklist.
- CONTRIBUTING.md: added a formal, mandatory test policy to §5 (silver criterion
  `test_policy_mandated`) — as major new functionality is added, automated tests
  covering it MUST be added in the same change, or it will not be merged.
- CONTRIBUTING.md: made the add-tests policy explicit in the change-proposal
  instructions in §2 (silver criterion `tests_documented_added`), stating that
  major new functionality MUST include automated tests in the same change.
- SECURITY.md: added a "Verifying releases" section (silver criterion
  `signed_releases`) documenting that releases are signed with the maintainer's
  own reproducible-build signing key (private key never on distribution sites)
  and how users can verify a release — automatically via the F-Droid client, by
  comparing the APK signing certificate SHA-256 fingerprint with the published
  value, or by reproducing the build.
- CONTRIBUTING.md / SECURITY.md: adopted GPG-signed release tags (silver
  criterion `version_tags_signed`) — the §7 release checklist now creates a
  signed annotated tag (`git tag -s`) with the maintainer's key, and "Verifying
  releases" documents verification via `git tag -v`. It also notes the
  `git config tag.gpgSign true` convenience setting.
- `docs/ASSURANCE_CASE.md`: new security assurance case (silver criterion
  `assurance_case`) — states the threat model, identifies the trust boundaries,
  argues that secure design principles were applied, and maps common
  implementation weakness classes to the countermeasures in the app; linked from
  SECURITY.md.
- Build: the in-app copyright document (`res/raw/copyright.md`) now separates its
  three concatenated parts (COPYING.md, the GPL text, and the Apache-2.0 text)
  with Markdown horizontal rules, and normalizes the spacing between them, for
  clearer rendering in the in-app licenses view. The concatenation moved into a
  single shared generator, `tools/render-copyright.py`, which both the Makefile
  rule (and its `check-guides` verification) and the Gradle
  `generateCopyrightDocument` task now call, so the two build paths can no longer
  disagree about the generated bytes. Generated output only; no licensing content
  changes.
- README: added the OpenSSF Best Practices badge (project 13480) under the title
  (silver criterion `documentation_achievements`), so the project's badge status
  is shown on the repository front page and updates automatically as the level
  changes.

---

## v0.77.4

Drop in-APK SBOM for reproducible builds

Reproducible builds:
- The release APK no longer embeds the CycloneDX SBOM under `assets/sbom/`.
  F-Droid's from-source rebuild of 0.77.3 verified the signature but failed the
  byte-for-byte reproducibility comparison, and the *only* differences were in
  the packaged SBOM. Its CycloneDX metadata captures the build environment and
  therefore differs between the developer's machine and F-Droid's CI:
  `metadata.timestamp` (dropped locally when `SOURCE_DATE_EPOCH` is unset, but
  pinned to it in CI), an auto-injected `build-system` entry carrying the GitLab
  CI job URL, and the VCS URL recorded as `ssh://…` locally vs `https://…` in
  CI. None of these can be reconciled across environments, so the robust fix is
  to stop shipping the SBOM *inside* the APK.
- `build.gradle.kts`: removed section 5 (`GenerateSbomAsset` and its
  `androidComponents` asset wiring) together with the imports it alone used
  (`java.io.File`, `javax.inject.Inject`, `ExecOperations`). Section 4
  (`cyclonedxDirectBom`) is unchanged, so `make sbom` / `make release` still
  produce the standalone `build/outputs/sbom/libellus-potionis-sbom.json`, which
  can be published as a separate release asset alongside the APK.
- The in-APK SBOM was never read at runtime and is not checked by
  `release-check.sh`, so nothing else depends on it; the APK is otherwise
  byte-identical to 0.77.3.

Release-check tooling (`tools/release-check.sh`):
- New §11 (REPRODUCIBLE-BUILD HYGIENE) fails the release if `build.gradle.kts`
  reintroduces an in-APK SBOM task (`GenerateSbomAsset`), so this regression
  cannot silently return. Sections renumbered from "/ 10" to "/ 11".

F-Droid recipe:
- `AutoName: Libellus Potionis` added to the reference recipe so it stays in
  sync with the fdroiddata copy (where `fdroid checkupdates` populates it) and
  no longer disappears from the recipe diff.

Versioning:
- `versionCode` 87 → 88 and `versionName` 0.77.3 → 0.77.4 across
  `build.gradle.kts`, `README.md` and the F-Droid recipe; localized store notes
  added as `changelogs/88.txt` for all 21 locales. No user-facing or functional
  change — this is a build-reproducibility fix.

---

## v0.77.3

Refine translations and data-security wording

Localization QA:
- A localization quality-assurance pass reviewed the in-app UI strings and
  several user-guide translations for terminology, grammar and typography:
  - `res/values/strings.xml` (base/English): added a structured translator and
    reviewer context block plus a per-entry `<!-- … -->` note for every string —
    where it appears in the UI, what each `%1$s`/`{name}` placeholder means, and
    the typographic-quote convention. These comments are documentation-only and
    do not affect the build. Stray German-style quote escapes in a couple of
    English strings were normalized to standard curly quotes.
  - In-app UI strings across the base locale and all 21 translations
    (`res/values*/strings.xml`): terminology, grammar and quote-consistency
    fixes (e.g. aligning the PDF-report field labels).
  - 12 localized user-guide templates (cs, da, es, fr, it, nb, nl, pl, pt,
    pt-BR, ru, sv): wording and grammar refinements.
  - The Romanian store summary was shortened to 77 characters to meet the
    80-character store limit: "Jurnal de alcool axat pe confidențialitate:
    limite, alcoolemie, rapoarte PDF."
  - Build fix: the Ukrainian `import_merge` value ("Об'єднати") introduced by
    the pass had its apostrophe escaped (`\'`) so the Android resource compiler
    (aapt2) accepts the string.

Documentation accuracy (data-at-rest wording):
- After the earlier removal of SQLCipher, the Room database is no longer
  encrypted at the application level — it is protected at rest only by Android's
  file-based storage encryption and the per-app sandbox. A few texts still
  carried the old "everything is encrypted" claim and were corrected so the
  project no longer overstates its guarantees:
  - `README.md`: the "Privacy & Security Architecture" section no longer says
    security is enforced "through fully encrypted data storage via hardware-backed
    cryptography". It now states that data rests in the app's private, sandboxed
    storage, protected at rest by Android's device storage encryption, with an
    optional biometric fingerprint lock.
  - In-app User's Guide (`docs/guide/usersguide.md.in` and all 21 localized
    `usersguide.<locale>.md.in` templates): the clause "All data is stored in
    encrypted form" was replaced by an accurate wording ("your data stays in the
    app's private storage on your device, protected by your device's
    encryption"), translated per locale.
  - Fastlane full descriptions (all 21 locales): dropped the now-superfluous
    half-sentence stating the preferences are "additionally sealed with a
    hardware-backed Android Keystore key", leaving the accurate device-encryption
    + sandbox statement.
- No source-code comments needed changes: `AppPreferences.kt` still correctly
  documents the app-encrypted preferences DataStore (AES-256-GCM, Keystore-backed
  — unchanged and accurate), and `AppDatabase.kt` only references the *legacy*
  SQLCipher artefacts that `purgeLegacyEncryptedDatabase()` deletes.

Release-check tooling (`tools/release-check.sh`):
- §1 (VERSION CONSISTENCY) no longer cross-checks a version comment in
  `proguard-rules.pro`. That header line merely duplicated `versionName` for no
  functional benefit — R8 ignores `#` comments — yet had to be re-synced on
  every release. The `# Version:` line was removed from `proguard-rules.pro`,
  and the corresponding check (together with the file's pre-flight existence
  entry and the doc references) was dropped from the script, removing one manual
  sync point per release. The README title version stays enforced because it is
  user-facing.
- §2 (CHANGELOG ENTRY) now also verifies the entry's first line — reused verbatim
  as the git commit subject — is ≤ 50 characters (git's subject-length
  convention).
- New §10 (STORE METADATA LENGTH LIMITS) checks every locale's
  `short_description.txt` (≤ 80), `full_description.txt` (≤ 4000) and
  `changelogs/*.txt` (≤ 500), counted in CHARACTERS (not bytes) so Greek,
  Cyrillic and CJK are measured the way the stores do. Existing sections were
  renumbered from "/ 9" to "/ 10".

F-Droid reproducible build:
- The reference recipe (`fdroid/de.godisch.potillus.yml`) now declares `Binaries`
  (the Codeberg release-asset URL, `de.godisch.potillus_%c.apk`) and
  `AllowedAPKSigningKeys`, enabling F-Droid to verify its own from-source build
  against the developer-signed APK published on Codeberg. The published release
  asset must be named for its versionCode (`de.godisch.potillus_87.apk`).

Versioning:
- `versionCode` 86 → 87 and `versionName` 0.77.2 → 0.77.3 across
  `build.gradle.kts`, `README.md` and the F-Droid recipe;
  localized store notes added as `changelogs/87.txt` for all 21 locales (the
  listing-only locales drop the previous `86.txt`). Documentation and metadata
  only — the APK is functionally identical to 0.77.2.

---

## v0.77.2

Fix SBOM normalizer path in release build

Bug fix:
- The `generateSbomAsset` task resolved its `sbom-normalize.py` helper with
  `layout.projectDirectory.file("tools/sbom-normalize.py")`.
  `layout.projectDirectory` is the `:app` module directory (`android/app/`), so
  this pointed at a non-existent `android/app/tools/sbom-normalize.py`; the
  script actually lives at the Gradle root, `android/tools/sbom-normalize.py`.
  The path now resolves via `rootProject.file("tools/sbom-normalize.py")`,
  matching the idiom already used elsewhere in this file. The full release
  build, including SBOM generation, R8 and resource shrinking, now completes.

Versioning:
- `versionCode` 85 → 86 and `versionName` 0.77.1 → 0.77.2 across
  `build.gradle.kts`, `proguard-rules.pro`, `README.md` and the F-Droid recipe
  (`commit: v0.77.2`); localized store notes added as `changelogs/86.txt` for
  all 21 locales (the listing-only locales drop the previous `85.txt`). No
  functional change to the app.

---

## v0.77.1

Fix F-Droid release build signing config

Bug fix:
- The `release` build type looked up its signing config with
  `signingConfigs.getByName("release")`. Before building, F-Droid strips the
  whole `signingConfigs { … }` block out of `build.gradle.kts` (it signs APKs
  itself), after which the named config no longer exists and `getByName` aborts
  the build with "SigningConfig with name 'release' not found". As a result the
  F-Droid build of 0.77.0 failed at `assembleRelease`. The lookup now uses the
  nullable `findByName("release")` with a null-safe check, so when the block has
  been removed the release build simply stays unsigned and F-Droid signs it.
  Local behaviour is unchanged: with a keystore the build is signed, without one
  it stays unsigned, exactly as before.

Versioning:
- `versionCode` 84 → 85 and `versionName` 0.77.0 → 0.77.1 across
  `build.gradle.kts`, `proguard-rules.pro`, `README.md` and the F-Droid recipe
  (`commit: v0.77.1`); localized store notes added as `changelogs/85.txt` for
  all 21 locales (the listing-only locales drop the previous `84.txt`). No
  functional change to the app; this is the first version that builds on F-Droid.

---

## v0.77.0

Rework feature-graphic copy; drop fdroid README

Store assets:
- Reworked the feature-graphic bullet copy in both locales. The privacy bullet
  now spells out the concrete guarantees instead of a generic label — en-US
  "100 % Privacy: App Lock & Offline-only", de-DE "100 % Privacy: App-Sperre,
  kein Netzwerk" — the limits bullet is title-cased on en-US ("Set & Maintain
  Limits"), and the final bullet now also advertises "Open Source". Both
  `featureGraphic.png` were regenerated from the updated copy.
- `README.md` now shows the en-US feature graphic at the top.

Build wiring:
- `Makefile`: `make screenshots` now also runs `make feature-graphics`, so the
  store graphics are regenerated together with the screenshots instead of as a
  separate manual step.

F-Droid:
- Removed the maintainer reference-copy comment header from
  `fdroid/de.godisch.potillus.yml` (it is plain metadata now) and deleted
  `fdroid/README.md`; the recipe no longer references it, and `release-check.sh`
  still keeps the reference copy's version in sync with `build.gradle.kts`.

Versioning:
- `versionCode` 83 → 84 and `versionName` 0.76.0 → 0.77.0 across
  `build.gradle.kts`, `proguard-rules.pro`, `README.md` and the F-Droid recipe;
  localized store notes added as `changelogs/84.txt` for all 21 locales (the
  listing-only locales drop the previous `83.txt`). Store-asset/tooling change
  only — the APK is functionally identical to 0.76.0.

---

## v0.76.0

Add a deterministic feature-graphic generator

Replace the two AI-generated Play-Store feature graphics with a deterministic,
re-localizable generator. This is a store-listing change only: the APK is
functionally identical to v0.75.0, and the versionCode is bumped purely so the
refreshed listing ships under its own code (same approach as v0.74.0).

Feature-graphic generator:
- New `android/tools/render-feature-graphic.py` composes the 1024x500 graphic
  (the exact Google Play feature-graphic size; the previous AI images were
  1488x720) from inputs the project already controls, so the result is
  reproducible and trivially re-localizable: per-locale marketing copy, the REAL
  screenshots from `make screenshots` (`01_today` as the phone, `07_report_page_1`
  as the report page) and the app's launcher icon. It emits SVG and renders with
  `rsvg-convert`; the phone is built and perspective-warped with Pillow (turned
  slightly about its vertical axis, left edge receding) and given a perspective
  depth edge on its near side, since SVG's affine transforms cannot do perspective. The old
  images baked in AI-hallucinated text (e.g. a garbled report page); the embedded
  shots are now the genuine, localized captures.
- Determinism: text is rendered with a PINNED bundled font (see below), selected
  via a throwaway fontconfig that exposes only `android/tools/fonts/`, so output
  never depends on the fonts installed on the build host. Repeated renders are
  byte-identical.
- Runtime dependencies are deliberately small: the python3 standard library,
  `rsvg-convert` (Debian `librsvg2-bin`), Pillow (already a project prerequisite)
  and the bundled fonts. Marketing copy
  lives in `fastlane/metadata/android/<locale>/feature-graphic.txt`; tagline line
  breaks are computed by the tool, so editors change words, not layout.

Bundled font:
- `android/tools/fonts/Inter/` adds static Inter instances (Regular/SemiBold/Bold,
  SIL OFL 1.1) used ONLY by the generator. They are build tooling and are NOT
  shipped in the APK. Credited in `COPYING.md`.

GPLv3 logo:
- `fastlane/gpl-v3-logo.svg` adds the GPLv3 "Free as in Freedom" logo, embedded
  (recoloured white) as a small license badge in the bottom-left of the graphic. It
  is one of the
  official GNU license logos by José Obed and is in the public domain; sourced from
  <https://www.gnu.org/graphics/license-logos> and credited in `COPYING.md`.

Copy / design tweaks (both locales unless noted):
- de-DE now addresses the reader informally ("Dein …" rather than "Ihr …").
- "100 %" is written with a space (was "100%").
- The "limits" bullet icon is a bar chart beneath a DOWNWARD trend arrow (the goal
  of keeping limits is to bring consumption down).
- The free/ad-free bullet leads with "free" (de "Kostenlos & Werbefrei",
  en "Free & Ad-free").

Build wiring:
- `android/Makefile`: new `feature-graphics` target renders the graphic for the
  screenshot locales, with an `rsvg-convert` pre-flight check mirroring the
  pdftoppm / Pillow checks; added to `.PHONY` and `make help`. It reuses the
  captures from `make screenshots` and does not capture anything itself.

Versioning:
- `versionCode` 82 → 83 and `versionName` 0.75.0 → 0.76.0 across
  `build.gradle.kts`, `proguard-rules.pro`, `README.md` and the F-Droid recipe;
  localized store notes added as `changelogs/83.txt` for all 21 locales.

Also in this release (unrelated tooling fixes):
- `android/tools/validate-screenshots.py` still pointed at the pre-move metadata
  path (`fastlane/metadata/android`), so `make screenshots` failed its final
  Google Play validation step even though capture, crop and PDF rendering had all
  succeeded. It now uses `../fastlane/metadata/android`, matching
  `crop-screenshots.py`.
- `ScreenshotTest` read screengrab's locale from the `testlocale` instrumentation
  argument, but screengrab passes it as `testLocale` (camelCase). Argument keys
  are case-sensitive, so the lookup returned null and every locale run fell back
  to the device language — both stores' captures came out identical (the device
  language). It now reads `testLocale` (with a lowercase fallback), so each
  locale renders in its own language again. Test-only; not in the release APK.
- Follow-up to the above: on API 33+ the per-app locale
  (`AppCompatDelegate.setApplicationLocales`) is applied ASYNCHRONOUSLY, so seeding
  it before launching the Activity left the first captured frame in the device
  language and the English run timed out. The locale is now applied AFTER each
  Activity launch, with the Activity foregrounded (mirroring the in-app language
  picker, the one path that switches reliably on the capture device). Test-only.

---

## v0.75.0

Disable embedded Google dependency blob, ship SBOM inside the APK

Privacy / transparency:
- `android/app/build.gradle.kts` (`android { dependenciesInfo { } }`): disabled
  the dependency-metadata block that the Android Gradle Plugin embeds by default
  into the APK signing block (`includeInApk = false`) and the App Bundle
  (`includeInBundle = false`). That block is encrypted with a Google public key
  and readable only by Google Play; for an offline, network-free FOSS app it
  serves no purpose and is opaque to users. Dropping it also removes one
  non-transparent artefact from the output, which is friendlier to
  reproducible-build verification.

Reproducible builds / SBOM packaging:
- `android/app/build.gradle.kts` (new section 5: `GenerateSbomAsset` +
  `androidComponents`): the CycloneDX SBOM is now packaged INSIDE the release APK
  under `assets/sbom/libellus-potionis-sbom.json`, so the bill of materials ships
  with the artefact it describes. The standalone copy under `build/outputs/sbom/`
  (used by `make sbom`) is unchanged.
- The packaged copy is kept reproducible: the raw CycloneDX output carries a
  wall-clock `metadata.timestamp`, so a generated-assets task normalises it with
  the same `tools/sbom-normalize.py` used by `make sbom` (`SOURCE_DATE_EPOCH`-aware;
  strips the timestamp otherwise) BEFORE the asset merge. The task is wired via
  `addGeneratedSourceDirectory`, so it runs as part of `mergeReleaseAssets` with no
  manual task dependencies. `python3` is already a build prerequisite (see the
  `Makefile`), so no new toolchain requirement is introduced.

Store screenshots (`make screenshots`):
- Fixed four defects in the automated Play-Store screenshot capture
  (`android/app/src/androidTest/kotlin/de/godisch/potillus/screenshot/ScreenshotTest.kt`)
  plus two build-tooling diagnostics (`android/Makefile`). All app-facing fixes are
  test-only; no production code changed.
- `03_statistics` showed a single bar (the capture day) instead of the whole
  month: `AppSettings.statsFromDate` falls back to the APK install date when unset
  (`AppPreferences.installDate`); screengrab reinstalls the app per locale, so that
  default is the capture day, and `StatsViewModel` clamps the period start to it —
  collapsing the chart and the period totals to one day. The Calendar (which does
  not clamp) still showed the full month, which is why the two screens disagreed.
  `setUp()` now clears the floor (`setStatsFromDate("")`) so the statistics period
  spans the full demo history again.
- `04_drinks` was intermittently empty (blank in one locale run, populated in the
  other — the signature of a race). `DrinksViewModel.uiState` starts from an empty
  `DrinksUiState()` that is filled by a Room `Flow` via `stateIn(...)`; the bare
  `composeRule.waitForIdle()` returns before that first database emission arrives.
  A new `waitUntilDrinksLoaded()` gate waits until the empty-state label
  (`R.string.no_drinks`) has disappeared before capturing.
- The `en-US` screenshots rendered in German: the app drives its UI language via
  its own per-app locale (`AppCompatDelegate.setApplicationLocales`), so relying on
  screengrab's `LocaleTestRule` system-locale switch had no effect on the rendered
  language and both locale runs came out in the device language. `setUp()` now
  resolves the requested `testlocale` to a supported language tag (reusing the
  production `LocaleDetector.detect` against `SupportedLocales.TAGS`) and sets BOTH
  the `language` preference and the live per-app locale to it. This is the last
  setup step, so it reliably wins over the asynchronous first-launch language
  detection in `PotillusApp.applyLanguageOnFirstLaunch`.
- Duplicate preset drinks appeared on the Drinks screen: the preset prepopulation
  runs asynchronously (`AppDatabase.PrepopulateCallback` launches it on the
  application scope when the database is first created), and the screenshot run's
  first database access is the import itself, so seeding and import raced and both
  inserted the presets. `setUp()` now awaits the presets (by collecting the drinks
  `Flow` until they are present) before `importReplace`, so the import's name-based
  deduplication matches and reuses them. (This race is effectively unreachable
  through the normal UI, where an import happens seconds after first launch.)
- `android/Makefile` (`screenshots`): the device date pin (`adb shell date`)
  silently no-ops on non-rooted physical devices, leaving the date-relative screens
  (Today / Calendar / Statistics) on the real device date instead of
  `SCREENSHOT_DATE`. The recipe now reads the device date back and prints a
  non-fatal WARNING when it differs from `SCREENSHOT_DATE`, so the condition is no
  longer silent; run on an emulator or rooted device to pin the date.
- `android/Makefile` (`screenshots`): added a fast-failing pre-flight check for the
  bundled fastlane. The fastlane tree moved to the repository root, so a vendored
  bundle installed under the old `android/fastlane/.vendor` no longer applies; the
  capture step then failed late (after a full build and after toggling Demo Mode)
  with the cryptic `bundler: command not found: fastlane` (Error 127). The recipe
  now runs `bundle check` in `../fastlane` up front and, if the bundle is missing,
  aborts immediately with an actionable message (`cd fastlane && bundle install`),
  mirroring the existing Pillow / pdftoppm pre-flight checks.

Version:
- Bumped to `0.75.0` / versionCode `82` across `build.gradle.kts`,
  `proguard-rules.pro`, the `README.md` title and the F-Droid recipe
  (`fdroid/de.godisch.potillus.yml`: `Builds` seed entry and
  `CurrentVersion`/`CurrentVersionCode`); added the per-locale fastlane `82.txt`
  store-changelog notes.

---

## v0.74.0

Prepare F-Droid packaging, localize store listing

This is a packaging, tooling and store-metadata release. It contains **no
changes to the app's runtime behaviour**: no source file under `src/main/kotlin`
was touched, the database schema is unchanged, and the set of shipped UI string
resources is identical to v0.73.4. The version is bumped purely so the new store
listings ship under their own `versionCode`.

Packaging (F-Droid):
- `fdroid/de.godisch.potillus.yml`: the reference build recipe lagged the source
  tree (it still pinned `versionName 0.73.0` / `versionCode 76`). Its single
  `Builds:` block and the `CurrentVersion` / `CurrentVersionCode` fields are now
  synced to the current release (`0.74.0` / `81`, `commit: v0.74.0`). A new
  release-check invariant (see Tooling) keeps them in lock-step from now on, so
  this class of drift cannot silently reappear.
- `fdroid/README.md`: added a step-by-step **fdroiddata submission checklist**
  (fork, copy recipe, local `fdroid lint` / `fdroid build -l`, open the merge
  request, address CI) and recorded the project decision that the FIRST
  F-Droid-published version will be cut as `1.0.0`. The reference recipe
  deliberately tracks the latest real release until that `1.0.0` tag exists.

Changed (build configuration):
- `android/settings.gradle.kts`: removed the `foojay-resolver-convention`
  plugin. It can fetch a JDK over the network when a Java toolchain is requested
  that is not installed locally — undesirable in F-Droid's network-restricted
  build. The project declares no `toolchain {}` / `jvmToolchain(...)`, so the
  plugin was never actually triggered (Gradle uses the build environment's JDK
  21); removing it deletes a latent network path and a future foot-gun with no
  change to how any build resolves Java.
- `android/app/build.gradle.kts`: enabled `allWarningsAsErrors` in the Kotlin
  `compilerOptions` block. The sources are warning-free, so every future Kotlin
  compiler warning (unused import/symbol, deprecated API, always-true `is`
  check, …) now fails the build instead of accumulating silently. Scope is the
  Kotlin compiler only (all source sets and build types); it does not affect
  Gradle-level deprecation notices (see "Known upstream issue" below).
- `gradle/libs.versions.toml` + `android/app/build.gradle.kts` (`lint { }`):
  bumped `navigation-compose` 2.8.9 → 2.9.7 and re-enabled the three navigation
  lint checks that had been disabled as tooling-bug workarounds
  (`WrongStartDestinationType`, `ComposableDestinationInComposeScope`,
  `ComposableNavGraphInComposeScope`). navigation-compose 2.8.9 shipped lint
  detectors compiled against older Compose lint utilities, which under AGP 9.2 /
  `compose-bom` 2026.06.00 threw `NoClassDefFoundError`
  (`androidx/navigation/lint/UtilKt`, `androidx/compose/lint/PsiUtilsKt`) and
  aborted the whole lint task while analysing `AppNav.kt`. 2.9.7 ships detectors
  built against the current Compose lint API, so the checks run instead of
  crashing — making the previous `disable` workarounds unnecessary. `AppNav.kt`
  is a single flat `NavHost` with top-level type-safe `composable<…>`
  destinations and a `@Serializable` start destination, so the re-enabled checks
  report no findings, and the type-safe-route API is unchanged between 2.8 and
  2.9 (no source edits required).

Store metadata (L10N):
- Added fastlane store listings (`title`, `short_description`, `full_description`
  and the `versionCode 81` changelog note) for the **19 app languages that had
  no store listing yet**: `cs`, `da`, `el`, `es`, `fr`, `it`, `ja`, `ko`, `nb`,
  `nl`, `pl`, `pt`, `pt-BR`, `ro`, `ru`, `sv`, `uk`, `zh-CN`, `zh-TW`. The store
  listing now covers all 21 shipped app languages (`en` and `de` already
  existed). Screenshots are intentionally NOT duplicated per locale — F-Droid
  falls back to the `en-US` images — so only text was added.
- Added the `versionCode 81` changelog note (`changelogs/81.txt`) to the
  existing `en-US` and `de-DE` listings as well, as required by the release
  gate.

Tooling (`android/tools/release-check.sh`):
- SECTION 1 now cross-checks the F-Droid reference recipe: the recipe's
  `CurrentVersion` / `CurrentVersionCode` and its latest `Builds:` block must
  equal the `build.gradle.kts` `versionName` / `versionCode` (which SECTION 1
  already ties to the top CHANGELOG entry). This is the enforcing half of the
  recipe-sync fix above.
- SECTION 1 fastlane **locale-parity** rule relaxed: full changelog *history*
  parity is now required only among the history-bearing locales (`en-US`,
  `de-DE`); every other listing locale must carry only the CURRENT
  `versionCode` note. Without this, adding 19 listing locales would have
  demanded ~320 back-dated changelog files for `versionCode`s those locales
  never shipped under. The current-version coverage check (every locale must
  have `<versionCode>.txt`) is unchanged.

Tests (warning cleanup, required by `allWarningsAsErrors` above):
- `AppViewModelFactoryTest`: removed five `assertTrue(vm is …)` assertions (and
  the now-unused `assertTrue` import). Each `vm` is already statically typed by
  its constructor's return type, so the runtime `is` check is always true and
  the Kotlin compiler flagged it as "Check for instance is always 'true'". The
  meaningful guarantee — that each ViewModel's constructor signature stays
  callable with the injected types — is enforced at compile time (the test would
  not compile otherwise) and the retained `assertNotNull(vm)` covers successful
  construction.
- `LocaleDetectorTest`: replaced the deprecated single-argument
  `java.util.Locale("…")` constructor (deprecated since JDK 19) with the
  equivalent `Locale.of("…")` at the three remaining call sites. Behaviour is
  identical; the file already used `Locale.of` / `Locale.forLanguageTag`
  elsewhere. (The many `Locale("xx", "Autonym")` calls in
  `l10n/SupportedLocales.kt` are unaffected: they construct the app's own
  `data class Locale(tag, autonym)`, not `java.util.Locale`.)

Localization (plurals) and re-enabled lint check:
- Converted `import_success_replace` ("%1$d entries imported.") and
  `import_success_merge` ("%1$d entries imported, %2$d skipped.") from flat
  `<string>`s into `<plurals>` across all 21 locales, and re-enabled the
  `PluralsCandidate` lint check that previously masked them (removed from the
  `lint { disable }` set). `SettingsViewModel` now resolves them via a new
  `quantityStr` helper (`resources.getQuantityString`, selecting on the imported
  count). Per-locale plural forms mirror the CLDR category set and morphology of
  each locale's existing `<plurals name="days">` (the flat translation becomes the
  high-count form; singular/few/many forms derived accordingly). The merge message
  is pluralized on the FIRST count only — the second number's word is invariant in
  the en/de sources (an invariant past participle), so a single `<plurals>` is
  correct there; in several locales (e.g. `cs`, `pl`, `ru`, `uk`) both clauses are
  impersonal and do not inflect, so their categories carry identical text.
- The remaining `%d`-bearing strings are NOT pluralizable nouns —
  `import_error_version_too_high` (a backup version number),
  `import_error_file_too_large` (`%d MB`, an invariant unit) and
  `pdf_kpi_over_drink_days` (`%d/7`, a ratio) — so each is annotated
  `tools:ignore="PluralsCandidate"` (with `xmlns:tools` added to the base
  `values/strings.xml`) rather than forced into a meaningless plural.

Known upstream issue (documented, not fixed here):
- The Android Gradle Plugin emits "Using a Project object as a dependency
  notation has been deprecated" during configuration. A deprecation trace places
  it inside AGP itself
  (`com.android.build.gradle.internal.dependency.VariantDependenciesBuilder`,
  reached from `VariantManager.createTestComponents`) while it wires the tested
  project as a dependency of the test variant — not in this project's build
  scripts, and not in any applied third-party plugin (CycloneDX 3.2.4, the
  latest, was ruled out). It is harmless on the current Gradle 9.6.1 and will
  only become an error on Gradle 10, so the fix must come from a future AGP
  release. `allWarningsAsErrors` does not promote it, as it is a Gradle
  configuration-phase notice rather than a Kotlin compiler warning.

---

## v0.73.4

Fix QA findings: locale-aware numbers, backup robustness, docs

Fixed:
- L10N: user-visible numbers (grams, BAC, percentages, gram limits) were
  formatted with `String.format` / `"%.1f".format`, which follow
  `Locale.getDefault()` (the system locale) instead of the per-app locale set
  via `AppCompatDelegate.setApplicationLocales`. On a device whose system
  language differed from the in-app language this printed a wrong decimal
  separator next to correctly localized month/weekday names (e.g. "Juni 2026"
  beside "19.6 g"). A new `l10n/NumberFormat.kt` adds locale-aware `fmt0` /
  `fmt1` / `fmt2` helpers, and every read-only display on the Today, Statistics,
  Calendar and Drinks screens, the shared chart and list components, and the PDF
  report now passes the per-app locale (`Context.formattingLocale()`). CSV
  export and the round-trip-parsed numeric input field keep `Locale.ROOT` on
  purpose (machine-readable / `String.toDouble()`-parseable); the latter also
  fixes a latent bug where the grams input dialog opened in an error state on a
  comma-decimal system locale (F-1).
- Backup: `BackupRepository.importMerge` now reads the existing drink
  name-to-id snapshot INSIDE its database transaction, mirroring
  `importReplace`, closing a read-outside-write (TOCTOU) gap (F-5).
- Backup: `buildIdMap` now indexes freshly inserted drinks by name within the
  same import, so a backup containing two identically named new drinks no longer
  creates duplicate drink rows (F-6).
- `StatsViewModel.uiState` now seeds its initial value with the actual default
  period (`MONTH`) instead of `WEEK`, so the period selector no longer flashes a
  one-frame `WEEK` selection before the first emission (F-7).

Changed:
- Removed the unused `IEntryRepository.isDuplicate` and its `EntryRepository` /
  `FakeEntryRepository` implementations: the only MERGE de-duplication path
  calls `entryDao.countByTimestampAndDrink` directly, so the method was dead
  code (F-2).

Docs:
- `AlcoholCalculator.roundTo2Decimals` KDoc corrected: it rounds the BAC value
  to two decimals, not gram values (which use `roundTo1Decimal`) (F-4).
- `EntryRepository.addFromDrink` KDoc no longer mentions the removed gender
  setting (F-3).

L10N (comprehensive translation QA against `en` + `de` as the authoritative
sources; key parity, apostrophe escaping, format placeholders, plural CLDR
categories, brand/URL invariants and newline parity all verified clean):
- `values-zh-rCN`: `drink_delete_blocked` started with a stray `%` and wrapped
  the drink name in ASCII straight quotes (`"…"`). Android treats `"` as a
  verbatim delimiter and strips it, so the user saw `%<name>有 …` with the
  quotes gone and a leftover percent sign. Replaced with the same
  `\u201c…\u201d` curly quotes the `en` source uses, dropping the stray `%`
  (L-1). The string is filled via `String.replace("{name}"/"{count}")`, not
  `String.format`, so there was never a crash — only wrong on-screen text.
- CSV header `csv_col_alcohol_pct` is now spelled out in every locale to match
  the `en`/`de` `Word_Word` style (e.g. `Alcohol_Percent` / `Alkohol_Prozent`)
  instead of a literal `%` (e.g. `Alcool_%` → `Alcool_pourcentage`,
  `酒精_%` → `酒精_百分比`). Purely a header-naming consistency change; the value
  carries no format arguments, so behaviour is unchanged.

Tests:
- Added `NumberFormatTest` (JVM) pinning the decimal separator to the passed
  locale (en-US "." vs de-DE ",").
- `LimitBarUiTest` now pins the Compose **Context configuration** locale to US
  (via a `createConfigurationContext` Context provided through `LocalContext`),
  not just `Locale.getDefault()`. Since `LimitBar` now formats grams for the
  per-app locale through `Context.formattingLocale()` — which is decoupled from
  the JVM default — the previous `Locale.setDefault(US)` alone no longer made the
  expected "20.0 g" deterministic on a comma-decimal device.

---

## v0.73.3

Fix QA findings: orphaned directory, German comments, docs, header style

Changed:
- `app/src/main/res/raw-la/` — removed the empty, orphaned directory left
  behind when Latin (`la`) was dropped from the supported-locale set in
  v0.63.0. The directory had no content and served no purpose, but its
  presence could mislead `render-guide.py` if it ever changed to scan
  output directories instead of template files (B-01).
- `AndroidManifest.xml` — translated the only remaining German inline comment
  (`<!-- CSV-Export in Downloads-Ordner … -->`) to English, consistent with
  CONTRIBUTING.md §3 and `release-check.sh` §7 (D-01).
- `ui/component/AppOverflowMenu.kt`, `ui/component/MarkdownText.kt` — unified
  the vim modeline and file-header comment style with the rest of the codebase:
  `// vim: set et ts=4 sw=4:` / `// =====` block replaced by the project-standard
  `/* vim: set et ts=4: */` / `/* * ===== */` block (D-04).
- `data/repository/EntryRepository.kt` — added the missing KDoc block to
  `mostRecentEntry()`, making it consistent with the other `override` functions
  in the same file that all carry explanatory KDoc (D-02).
- `gradle.properties` — added `org.gradle.warning.mode=all` so that the
  per-deprecation detail Gradle previously suppressed behind the summary line
  *"Deprecated Gradle features were used … use `--warning-mode all`"* is
  printed on every build run. The property is the canonical project-wide way
  to set the flag (rather than a per-invocation CLI argument) and ensures the
  warnings surface in CI, `make` runs, and Android Studio alike.
- `gradle.properties` — translated the three remaining German inline comments
  (`# AndroidX aktivieren …`, `# Gradle-Daemon und Parallelbuilds`,
  `# Kotlin-Code-Style`) to English, consistent with CONTRIBUTING.md §3 (D-01).
- `data/prefs/AppPreferences.kt` — made the encrypted DataStore flow resilient
  to a transient read `IOException`. `settingsFlow` previously mapped
  `dataStore.data` directly, so a plain `IOException` raised on
  the read path (which the `ReplaceFileCorruptionHandler` does NOT cover — it
  only handles `CorruptionException` from the serializer) would propagate to
  every collector, including the start-up reads in `MainActivity.onCreate` and
  `PotillusApp.onCreate`, and crash the app. It is now routed through a
  new, unit-tested `recoverIoAsEmpty(...)` helper that emits `emptyPreferences()`
  on an `IOException` (downstream `map` then falls back to the documented
  defaults) and rethrows any non-IO error. This is the Jetpack DataStore
  guidance and matches the app's existing "degrade, never crash" policy.
  Covered by the new `AppPreferencesIoSafetyTest` (R-01).
- `app/build.gradle.kts` — silenced the cosmetic `stripDebugDebugSymbols`
  build warning *"Unable to strip the following libraries, packaging them as
  they are: `libandroidx.graphics.path.so`, `libdatastore_shared_counter.so`"*.
  The app ships no native code of its own; these two transitive prebuilt `.so`
  files cannot be stripped when no NDK toolchain is present (as in the F-Droid
  build image) and are then packaged unstripped anyway, so the message is purely
  cosmetic — but it became visible on every build once
  `org.gradle.warning.mode=all` was enabled in v0.73.3. They are now listed under
  `packaging.jniLibs.keepDebugSymbols`, which removes them from the strip set so
  AGP no longer attempts (and fails) to strip them. The packaged output is
  unchanged. The two names are listed explicitly rather than a blanket `**/*.so`
  so a future unstrippable library re-surfaces the warning for a conscious
  decision (B-02).
- `util/GplNotice.kt` — converted the file header from the `//` line-comment
  form to the project-standard `/* … */` block header used by the other Kotlin
  files, completing the header-style unification this release already applied to
  `AppOverflowMenu.kt` and `MarkdownText.kt` (F2).
- `ui/component/MarkdownText.kt` — promoted the pure helpers `decodeHtmlEntities`
  and `parseOrderedList` (and the `ORDERED_ITEM_RE` pattern) from `private` to
  `internal` + `@VisibleForTesting`, so the renderer's parsing logic is unit
  testable on the JVM without a device. No behavioural change (F3).
- Documentation accuracy: corrected five stale comments left by the earlier
  C-01 refactor (which moved `toDomain`/`toEntity` to `EntityMapping.kt` as
  `internal`). `BackupRepository.kt` and `DrinkRepository.kt` no longer claim the
  mappers are file-private and re-declared per repository; `Models.kt`,
  `DrinkEntity.kt` and `EntryEntity.kt` now point readers to the `internal`
  extensions in `EntityMapping.kt` instead of the (no-longer-correct) repository
  classes. Comments only — no code or behaviour change (G1).

Added:
- `app/src/test/kotlin/.../data/repository/EntityMappingTest.kt` — JVM unit
  tests for the shared entity ↔ domain conversions: `toDomain`/`toEntity` round
  trips and the unknown-category → `OTHER` fallback, the only non-trivial logic
  in the otherwise pass-through repositories (F3).
- `app/src/test/kotlin/.../ui/component/MarkdownTextTest.kt` — JVM unit tests for
  the in-app Markdown renderer's pure helpers: HTML-entity decoding, the
  ordered-item match boundary (a wrapped decimal is not a new item), and
  continuation-line reflow (F3).

Removed:
- The annual info dialog (the one-shot dialog shown on December 27th) and every
  artefact that existed only to support it (F1). Removed: `PotillusApp`'s
  `infoDialog`/`_infoDialog` state, `dismissInfoDialog()` and
  `checkAnnualInfoDialog()` (plus the now-unused `MutableStateFlow`/`StateFlow`/
  `asStateFlow`/`LocalDate` imports); the `AlertDialog` block and its
  `AlertDialog`/`Text`/`TextButton`/`stringResource` imports in `MainActivity`;
  the `info_dialog_title` / `info_dialog_body` / `info_dialog_ok` strings in
  `values/strings.xml` and all 20 `values-*/strings.xml` (per-locale key count
  170, still in sync); the `infoDialogShownYear` / `setInfoDialogShownYear`
  members of `IAppPreferences`, `AppPreferences` (`KEY_INFO_YEAR`,
  `info_dialog_shown_year`) and `FakeAppPreferences`; and the now-obsolete
  suppression call and notes in `ScreenshotTest`. A leftover
  `info_dialog_shown_year` value in an existing DataStore file is simply ignored.
  The two "translate all N keys" comments (`AndroidManifest.xml`,
  `app/build.gradle.kts`) were updated 173 → 170.
- `ui/screen/Screens.kt` — deleted the content-free documentation placeholder.
  The `Screen` sealed interface and all navigation routes live in
  `ui/nav/AppNav.kt`, which is already self-documenting. The placeholder added
  no information and could confuse readers expecting a `Screens` class (D-03).

---

## v0.73.2

Move fastlane metadata to repo root for F-Droid

Changed (project layout):
- Moved the fastlane tree from `android/fastlane/` to the repository root
  (`fastlane/`, a sibling of `android/`) so F-Droid auto-discovers the store
  listing, per-version changelogs and screenshots from the source repo (F-Droid
  does not look inside the Gradle module tree). The directory move itself is a
  `git mv`; this entry accompanies the path updates that follow from it. fastlane
  re-anchors to the new parent (the repo root), so paths into the Gradle build
  outputs in `Fastfile`/`Screengrabfile` gain an `android/` prefix, while the
  metadata output stays under `fastlane/`. The `android/`-side references
  (`Makefile`, `app/build.gradle.kts`, `tools/release-check.sh`,
  `tools/crop-screenshots.py`, `libs.versions.toml`, the screenshot test and
  `.gitignore`) now point at `../fastlane/`. No functional change to the app.

---

## v0.73.1

Fix QA findings: locale, DRY mapping, docs, tests

Changed:
- `TodayViewModel`: replace `Locale.getDefault()` with a locale derived from
  `AppSettings.language` (BCP-47 tag) for the monthly-average label on the Today
  card. On devices where the system language differs from the in-app language the
  month name now matches the rest of the UI rather than the OS locale (A-01).
- `DrinkRepository`, `EntryRepository`, `BackupRepository`: the four entity ↔
  domain conversion helpers (`toDomain` / `toEntity`) are now defined once as
  `internal` extension functions in the new `EntityMapping.kt` file instead of
  being duplicated across three files (C-01 DRY fix). The behaviour is unchanged.
- `PotillusApp.applyLanguageOnFirstLaunch`: the pure locale-detection logic is
  delegated to the new `LocaleDetector.detect()` function so it is unit-testable
  without an Android runtime (T-03).
- `DrinksScreen`, `TodayScreen`, `StatsScreen`, `CalendarScreen`: added missing
  `@param` KDoc entries for `onOpenHelp`, `onOpenCopyright`, and `onLockApp` (D-02).
- `Screens.kt`: added the missing `package de.godisch.potillus.ui.screen` declaration;
  without it the file resided in the default package, inconsistent with every other
  source file in the project (D-01 / S-01).

Added:
- `EntityMapping.kt` (`data/repository`): single source of truth for the four
  entity ↔ domain conversion helpers, replacing the previously scattered private
  and class-private copies (C-01).
- `LocaleDetector.kt` (`domain`): pure, Android-free singleton that implements the
  three-step BCP-47 matching strategy (full tag → base language → "en") extracted
  from `PotillusApp` (T-03).
- `LocaleDetectorTest.kt`: 10 JVM unit tests for `LocaleDetector.detect` covering
  all three matching steps, region variants (zh-CN/zh-TW, pt-BR), unsupported
  locales, empty sets, and case-insensitivity (T-03).
- `AppViewModelFactoryTest.kt`: unit tests that verify each registered ViewModel
  can be constructed with its injected dependency types, and that the factory's
  `else` guard throws `IllegalArgumentException` for unregistered classes (T-02).

---

## v0.73.0

Remove SQLCipher; add signing and Play tooling

Added:
- Conditional release code-signing in `android/app/build.gradle.kts`. A new
  `signingConfigs { create("release") }` block reads the key material either from
  a git-ignored `android/keystore.properties` file or from environment variables
  (the latter take precedence, which is convenient for CI). The release build
  type applies the config ONLY when the material is present, so the default
  source build — and F-Droid, which signs the APK itself — keeps producing the
  unsigned `app-release-unsigned.apk` with no key configured.
- `android/keystore.properties.example`: a documented template listing the four
  keys (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`) and their
  environment-variable equivalents (`POTILLUS_KEYSTORE_FILE` etc.). The real
  `keystore.properties` and the Play service-account JSON are now git-ignored.
- `make bundle` (`android/Makefile`): builds the Android App Bundle
  (`bundleRelease`) that Google Play requires for new apps, alongside the
  existing `make release` APK target; both also generate the SBOM.
- `make deploy` plus a fastlane `deploy` lane (`android/fastlane/Fastfile`) and
  `android/fastlane/Appfile`: upload the signed AAB and the existing store
  metadata to Google Play via `upload_to_play_store`. The Play track and release
  status are overridable (defaults: `production` / `draft`, i.e. staged for
  manual publish) and the service-account key path is read from the
  `SUPPLY_JSON_KEY` environment variable (falling back to
  `fastlane/play-store-credentials.json`).
- Per-locale Play/F-Droid release notes `…/changelogs/76.txt` (de-DE, en-US) for
  the new versionCode.

Changed:
- `make release` is now a phony target that always invokes `assembleRelease` and
  prints the produced artifact path, instead of hard-coding the
  `app-release-unsigned.apk` filename (which becomes `app-release.apk` once a
  signing key is configured).
- Bumped versionName 0.72.0 → 0.73.0 and versionCode 75 → 76, with the matching
  README, `proguard-rules.pro` and fastlane changelog updates that
  `tools/release-check.sh` couples to the version.

Removed:
- **SQLCipher** (`net.zetetic:sqlcipher-android`) and the explicit
  `androidx.sqlite` pin are gone, together with all passphrase machinery
  (`getOrCreatePassphrase` / `hasSealedPassphrase` / `canOpenSealedPassphrase`
  and the `KeystoreSecretStore`-sealed passphrase in `AppDatabase.kt`), the
  `-keep class net.sqlcipher.**` ProGuard rules, and the `SupportOpenHelperFactory`
  usage in `MigrationTest`. The database is now a plain Room/SQLite file, relying
  on Android's file-based storage encryption and the per-app sandbox at rest.
- The **device-transfer "Settings not restored?" warning** (its detection,
  `PotillusApp` state/flow, the `MainActivity` dialog, the
  `device_transfer_warning_title`/`_body` strings in all 21 locales, and the
  `PotillusAppHeuristicTest`). The warning existed only to diagnose a failed
  SQLCipher-passphrase migration, which can no longer occur.

Changed (data & security):
- `data_extraction_rules.xml` now **excludes** the database and the preferences
  DataStore from both cloud-backup and device-transfer (and no longer references
  the obsolete passphrase file). With `allowBackup="false"` these rules stay
  inert, but they now state the intent plainly: personal data never leaves the
  device automatically. The **only** supported way to move data between devices
  is the user-initiated JSON backup (Settings → Backup → Export / Import).
- The user's guide **Backup** section was rewritten to explain, emphatically,
  why export/import is the sole transfer path and how to perform it, and was
  translated into all 21 supported languages.

Security:
- **Clean break, no data migration.** A plaintext SQLite engine cannot open the
  former SQLCipher file, so on the first launch after upgrading, `AppDatabase`
  runs a one-shot `purgeLegacyEncryptedDatabase()`: keyed on the legacy
  passphrase SharedPreferences marker, it deletes the old encrypted database, the
  passphrase file, and the now-unused Keystore key, then lets Room create a fresh,
  empty database. The routine is idempotent and a no-op on clean installs. Users
  upgrading from an encrypted build must re-import their JSON backup.

Fixed:
- The release `signingConfigs` block in `android/app/build.gradle.kts` failed to
  compile, breaking every Gradle task at configuration time (`Unresolved reference
  'util'`). Inside that block the bare identifier `java` resolves to Gradle's
  Java-plugin extension accessor, so the fully-qualified `java.util.Properties()`
  was misparsed. Added an explicit `import java.util.Properties` and now reference
  it as `Properties()`.
- Lint (run with `warningsAsErrors = true`) aborted the build on the legacy-database
  cleanup in `AppDatabase.kt`: `legacyPrefs.edit().clear().commit()` tripped both
  `ApplySharedPref` (prefer `apply()` over `commit()`) and `UseKtx` (prefer the
  `SharedPreferences.edit` KTX extension). The call was redundant — the following
  `deleteSharedPreferences()` already removes the file and its in-memory state — so
  the line was dropped entirely.
- The in-app guide viewer (`MarkdownText`) now renders `**bold**` inline spans.
  The rewritten Backup section uses bold for emphasis; previously the renderer
  handled only headings, paragraphs and `[text](url)` links, so the `**` markers
  would have appeared literally. Bold is now parsed alongside links in
  `renderInline` via a combined regex and a `FontWeight.Bold` span.
- The guide viewer now also renders ordered lists (`1.`, `2.`, …) as separate,
  hanging-indented items instead of collapsing them into a single paragraph, so
  the rewritten Backup section's device-transfer steps display as a proper
  numbered list with inline bold preserved per item.
- Migrated the screenshot test off the deprecated `createEmptyComposeRule` (the
  Compose UI-test rule) to its `…junit4.v2` replacement. The v2 rule uses a
  StandardTestDispatcher; the test is unaffected because it already synchronizes
  explicitly via `waitUntil`/`waitForIdle` and drives a real Activity rather than
  relying on immediate composition.
- Worked around a crash in the bundled navigation lint detector
  (`WrongStartDestinationType` / `BaseWrongStartDestinationTypeDetector`), which
  throws `NoClassDefFoundError: androidx/navigation/lint/UtilKt` under the lint
  shipped with AGP 9.2 and aborts `lintAnalyzeDebug` (the project runs lint with
  `abortOnError`/`warningsAsErrors`). The check is disabled in the `lint {}` block
  with a documented rationale; it is a tooling bug, not a finding in the app's
  navigation graph. The crash only surfaced once a source change invalidated the
  previously cached lint result.
- Migrated the three build-script tasks (`copyDemoBackupFixture`,
  `generateUserGuides`, `generateCopyrightDocument`) off the `val name by
  tasks.registering { }` Kotlin-DSL property-delegate syntax, which Gradle 9.6
  deprecated (scheduled for removal in Gradle 10), to the equivalent
  `tasks.register<Type>("name") { }` form. Task names and wiring are unchanged.
  (One remaining Gradle 10 deprecation — "Using a Project object as a dependency
  notation" — originates inside the Android Gradle Plugin, not this build script,
  and will clear with a future AGP release.)

Cleanup:
- Removed 13 unused imports across the UI and test sources, and corrected two
  stale KDoc/comment references in `AppPreferences.kt` that still mentioned the
  former SQLCipher "DB passphrase key alias" (which no longer exists). The
  preferences DataStore key is now the only persistent Keystore key the app uses.

Changed (build and distribution):
- **Guide and copyright resources are now generated by Gradle.** Two tasks
  (`generateUserGuides`, `generateCopyrightDocument`) render
  `res/raw[-xx]/usersguide.md` and `res/raw/copyright.md` and are wired into
  `preBuild`, so a bare `./gradlew assembleRelease` (a fresh clone, CI, or an
  F-Droid build that does not go through `make`) no longer fails on the missing,
  git-ignored `R.raw.*` backing files — previously only the Makefile produced them.
- **Added the F-Droid build recipe** at `fdroid/de.godisch.potillus.yml` (a
  reference copy of the fdroiddata metadata) with `fdroid/README.md`. Because the
  generation is wired into Gradle, the recipe is a plain `gradle: [yes]` build;
  the release stays unsigned when no keystore is configured, so F-Droid signs it.
  Auto-updates track v-prefixed semver tags.

Changed (store metadata):
- Corrected the store texts that the SQLCipher removal had made inaccurate. The
  long description no longer claims data is "stored fully encrypted using
  hardware-backed cryptography" (true only of the former SQLCipher layer); it now
  describes the actual model — on-device private storage under Android's storage
  encryption and the app sandbox, with the preferences additionally sealed by a
  hardware-backed Keystore key. The versionCode 76 store note
  (`changelogs/76.txt`, de + en), previously "developer tooling only", now states
  the real user-facing change and warns that data from earlier versions is not
  migrated automatically.

Changed (dependencies):
- Bumped the Jetpack Compose BOM from 2026.04.01 to 2026.06.00 (core Compose
  modules 1.11.0 → 1.11.3, bug-fix only). The Compose compiler stays paired with
  the Kotlin plugin, and the v2 UI-test rule adopted earlier is unaffected.
- Bumped the Gradle wrapper from 9.4.1 to 9.6.1 (`gradle-wrapper.properties`).
  9.6.1 is a patch release of the 9.6 line and stays well within AGP 9.2's Gradle
  requirement. Only `distributionUrl` is changed; the bundled wrapper JAR boots
  any 9.x distribution, so it needs no regeneration.
- Bumped Kotlin from 2.3.21 to 2.4.0. Because AGP 9's built-in Kotlin is pinned on
  the buildscript classpath, this touches two coupled spots that must stay in
  sync: the `kotlin` catalog key and the hard-coded `kotlin-gradle-plugin`
  classpath literal in the root `build.gradle.kts`. The Compose compiler and the
  serialization compiler plugin follow the `kotlin` key automatically. KSP is
  moved 2.3.7 → 2.3.9 (the release the Kotlin 2.4.0 notes pair with). The
  kotlinx-serialization runtime stays at 1.11.0; it must satisfy the
  forward-compatibility rule under the 2.4.0 compiler — if a build reports a
  serialization version mismatch, that runtime needs bumping too.

Note:
- The Google Play *feature graphic* (1024×500 px) is a design asset and cannot
  be generated here; the placeholder description in
  `android/fastlane/metadata/android/en-US/images/PLACEHOLDERS.txt` still
  applies. The F-Droid build-recipe metadata (for the fdroiddata repository) is
  intentionally NOT included yet — it needs the agreed tag/versioning convention.
  (With SQLCipher removed, the build no longer ships any prebuilt native binary,
  so the earlier prebuilt-binary concern no longer applies.)

---

## v0.72.0

Automate Play-Store screenshots via screengrab

Added:
- Fully automated Play-Store screenshot pipeline, runnable as `make screenshots`
  (root) which delegates to `make -C android screenshots`. It captures the six
  in-app phone screenshots in both store locales (`de-DE`, `en-US`) via Fastlane
  `screengrab` plus an Espresso/Compose UI test, then renders the two pages of
  the localized PDF report as screenshots 7 and 8, placing all eight assets per
  locale straight into `fastlane/metadata/android/<locale>/images/phoneScreenshots/`.
- `app/src/androidTest/.../screenshot/ScreenshotTest.kt`: the capture suite. It
  seeds the database from the canonical demo fixture (`fastlane/demo-backup.json`,
  copied into the androidTest assets at build time by the new
  `copyDemoBackupFixture` Gradle task), fixes the theme per phase (screenshots
  1–3 in light mode, 4–6 in dark mode), and navigates Today → Calendar →
  Statistics → Drinks → Add-drink dialog → Settings. It selects navigation
  targets by their localized label text plus a click action (the production UI
  has no test tags) so it works unchanged in both locales.
- `app/src/androidTest/.../screenshot/ScreenshotOnly.kt`: a runtime annotation
  tagging the suite so it can be excluded from an ordinary device-test run via
  the documented switch `make test-device EXCLUDE_SCREENSHOTS=1`
  (`-PexcludeScreenshotTests`). By default the suite still runs as part of
  `connectedDebugAndroidTest`, so a broken capture flow is caught by the normal
  gate.
- `tools/validate-screenshots.py`: a pure-stdlib gate that fails the run unless
  every captured asset meets Google Play's phone-screenshot requirements (PNG,
  each side 320–3840 px, aspect ratio ≤ 2:1, exactly eight per locale).
- Fastlane Ruby configuration: `fastlane/Fastfile` (lane `screenshots`),
  `fastlane/Screengrabfile` (locales, packages, output dir), `fastlane/Gemfile`
  (declares the fastlane gem) and the resolved `fastlane/Gemfile.lock` that pins
  the exact gem versions for the mandatory `bundle exec` run.

Changed:
- Status-bar hygiene during capture uses the Android Demo Mode API, driven from
  the `screenshots` Makefile target via adb: clock 10:00, 100 % battery, full
  Wi-Fi and no notifications. A bash `EXIT` trap guarantees Demo Mode is disabled
  again afterwards (`screenshots-demo-off`), even if the run fails. The device
  date is pinned to 2026-06-30 so the date-relative Today screen shows the demo
  period (best-effort; needs an emulator/rooted build).
- `app/build.gradle.kts` / `gradle/libs.versions.toml`: added the
  `tools.fastlane:screengrab` and `androidx.test.uiautomator` androidTest
  dependencies. The UiAutomator full-screen capture strategy is required so the
  cleaned Demo-Mode status bar is part of the saved image. `FLAG_SECURE` is cleared
  for the run by enabling the existing `allowScreenshots` preference from the
  test — no production code change.
- Screenshot filenames are stable across runs: screengrab's timestamp suffix is
  disabled (`use_timestamp_suffix(false)`), so capture overwrites
  `01_today.png` … `06_settings.png` in place instead of emitting a new
  timestamped file every run. The committed store screenshots can therefore be
  re-generated and checked in without churn or duplicates.
- The six in-app screenshots are bottom-cropped to at most a 2:1 aspect ratio
  (`tools/crop-screenshots.py`, Make step `screenshots-crop`). This removes the
  Android navigation bar at the bottom and satisfies Google Play's max-2:1 rule
  even when captured on a tall phone/emulator (e.g. 19.5:9). The PDF report pages
  (07/08) keep their A4 ratio and are never cropped.

Release process:
- versionName 0.71.1 → 0.72.0, versionCode 74 → 75 (anchor v0.70.0 = 72 plus
  three releases since). README title and `proguard-rules.pro` header updated to
  v0.72.0.
- Added fastlane store notes `changelogs/75.txt` in both locales (covers 0.72.0).

---

## v0.71.1

Fix Today-screen trend-arrow baseline

Fixed:
- Today screen, second row: the month-trend arrow (↑/↓) next to the per-day
  average was rendered in `titleMedium` while the adjacent "g/day" label uses
  `bodyMedium`. Because `Alignment.Bottom` aligns text bounding boxes rather
  than baselines, the larger style left the arrow sitting off the "g/day"
  baseline. The arrow now uses `bodyMedium` (bold), so it shares the label's
  baseline and size.

Release process:
- New rule, enforced by `release-check.sh` (SECTION 1): every `## vX.Y.Z`
  heading added to this changelog must be accompanied by exactly one increment
  of `versionCode`. The check derives the expected `versionCode` from a fixed
  reference point in `android/version-anchor` (anchored at v0.70.0 = 72) plus
  the number of changelog entries above it. versionName 0.71.0 → 0.71.1,
  versionCode 72 → 74 (0.71.0 = 73, 0.71.1 = 74).
- Added fastlane store notes for the new versionCodes in both locales:
  `changelogs/73.txt` (covers 0.71.0) and `changelogs/74.txt` (covers 0.71.1).

---

## v0.71.0

Reorder PDF KPIs; show longest abstinence streak

Changed:
- PDF report, KPI section: reordered tiles so that `abstinent days` and
  `longest abstinence phase` appear together in the first row, followed by
  `drinking days` and `total alcohol`. The consumption-peak and average/median
  rows are regrouped accordingly. (Patch `reorder.diff`.)

Added:
- PDF report, KPI section: the previously empty tile next to `abstinent days`
  now shows the longest continuous abstinence streak (in days) within the
  report period, using the already-computed `PdfReportData.longestAbstinence`
  field and the existing `pdf_meta_longest_abstinence` string resource
  (available in all 21 locales).
- PDF report, KPI section: `max per day` and `max per 7 days` tiles are now
  highlighted in red (warn flag) when their value exceeds the corresponding
  configured limit (`LimitInfo.limitGrams` and `LimitInfo.weeklyLimitGrams`
  respectively), consistent with the existing colouring of the
  `days > g/day` and `days > g/7 days` violation tiles.
- Statistics screen: initial period on first app start changed from `WEEK` to
  `MONTH` (`StatsViewModel._period` default).
- Document viewer: HTML character entities (`&copy;`, `&amp;`, `&lt;`,
  `&gt;`, `&quot;`, `&apos;`, `&nbsp;`, `&reg;`, `&trade;`) are now decoded
  to their Unicode equivalents before rendering, so e.g. `&copy;` in
  `LICENSE.md` appears as `©` instead of literal markup
  (`MarkdownText.decodeHtmlEntities`).
- Settings screen, Appearance section: new "Allow Screenshots" toggle.
  When off (default) `FLAG_SECURE` blocks screenshots and screen recordings
  to protect health-sensitive data. When on, the flag is cleared reactively
  via the `settingsFlow` collector in `MainActivity` without requiring a
  restart (`AppSettings.allowScreenshots`, `KEY_ALLOW_SCREENSHOTS`,
  `IAppPreferences.setAllowScreenshots`, `SettingsViewModel.setAllowScreenshots`).
  String resources added in all 21 locales.
- Today screen, second row: the left column now shows today's own total in
  grams (e.g. `0.0 g`) styled like the right column's headline figure, instead
  of the static word "Alcohol". The month-trend arrow (↑/↓) on the right is now
  rendered in bold.
- Settings screen: the access-lock and screenshot toggles moved out of the
  "Appearance" section into a new "Security" section placed above it, so
  "Appearance" now precedes the colour-scheme (theme) and language controls
  only. New `security` string resource added in all 21 locales.
- PDF report, page 1 long-term trend chart: corrected the section heading unit
  from "Ø Grams/Month" to "Ø Grams/Day" in all 21 locales — the bars (and the
  dashed reference line) have always been per-day averages against the daily
  limit, independent of the span-derived bucket width. Each bar now also carries
  its per-day average on top (one decimal, blank for abstinent buckets),
  matching the page-2 hour/weekday charts (`BAR_VALUE`).

---

## v0.70.0

Add monthly trend arrow; fair per-day trend

Added:
- Today screen, monthly trend arrow. Next to the month's per-day average a small
  arrow now shows how it compares with the baseline period — the per-day average
  over the whole time from the configured statistics start date up to the day
  before this month: a green ↓ when this month is averaging fewer grams of
  alcohol per day than that baseline, a red ↑ when it is more, and nothing (no
  arrow, no extra space) when the two are equal at 0.1 g precision or there is no
  baseline yet (statistics started this month). Backed by a new shared domain
  type Trend (Trend.of(currentAvg, prevAvg)) and a monthTrend field on
  TodayUiState; the baseline is read by widening the monthly daily-summary query
  to start at the statistics start date.
- Release gate now checks Markdown syntax. A new check (`release-check.sh`
  section 9, backed by `tools/md-syntax.py`, standard library only) verifies that
  `CHANGELOG.md`, `README.md`, `CONTRIBUTING.md` and the per-language guides
  rendered from `*.md.in` are well formed: inline-code backticks and `*` emphasis
  balanced, and code-looking tokens (`snake_case`, glob `*`) wrapped in backticks
  so a stray marker cannot turn into accidental emphasis in the in-app renderer.
  `CHANGELOG.md` headings must additionally read `## vMAJOR.MINOR.PATCH` in
  descending order. The verbatim GPL texts (`LICENSE.md`, `COPYING.md`,
  `copyright.md`) are excluded.

Changed:
- Statistics trend is now computed on a per-day-AVERAGE basis instead of period
  totals, and its arrow uses the same shared Trend rule as the Today card. This
  makes an in-progress period compare fairly with the previous one: the current
  period is divided by its effective days (today counts only once it is a drink
  day) and the previous, complete period by its full day count. As a result a
  part-month no longer looks artificially lower than a full previous month, and
  the two screens always agree. The "trend vs. previous" percentage is now the
  change in the per-day averages; equal-at-0.1 g shows "–" (no arrow). The 7-day
  view is unaffected in practice (two equal-length windows).

Fixed:
- PDF report, page-1 trend chart: the x-axis labels are now drawn in a separate
  row BELOW the baseline, matching the page-2 hour/weekday charts (previously they
  sat above the axis, inside the plot area). The trend chart was switched to the
  same .barchart layout (a .bars plot area plus a .axis label row), so a label is
  never overlapped by its bar and both pages are laid out consistently.
- English PDF report capitalization. Report labels now use sentence case
  (lowercase except the first word and proper nouns) instead of Title Case —
  e.g. "Total alcohol", "Ø per day", "Longest abstinence phase", "Binge days",
  "Drinking days" — and units after a slash are lowercase ("g/day", "g/7 days",
  "Ø g/day", "… days/month"). Document title and section headings keep their
  Title-Case / all-caps styling. Only the report-only (`pdf_*`) English strings
  were touched; localized values are unchanged (e.g. German "g/Tag" stays
  capitalized, since "Tag" is a noun).
- Day counts are now correctly pluralized. The abstinence values in the PDF
  report (e.g. "Longest abstinence: 1 day", "Current: 0 days") and the streak
  values on the Statistics screen previously always used the plural form ("1
  Days"). They now use a shared `days` plural resource with the correct forms for
  every locale (including the multi-form Slavic plurals: cs/pl/ru/uk and ro).
  The now-unused `pdf_days_suffix` and `days_count` strings were removed.
- CHANGELOG escaping. Several code identifiers in recent entries were written
  without backticks; their `_` and `*` characters could render as unintended
  emphasis in a Markdown viewer. They are now wrapped in backticks (along with a
  stray `2.2.*` version glob), matching the file's convention. The new section-9
  check above guards against regressions.

Release housekeeping:
- versionName 0.69.0 → 0.70.0 (minor bump), versionCode 71 → 72.
- Synced proguard-rules.pro and the README title line; added Fastlane store
  notes 72.txt for de-DE and en-US.

---

## v0.69.0

Label chart bars; add monthly per-day average

Added:
- Statistics chart, per-bar value labels. On the two sparse axes each bar is now
  annotated with its grams of alcohol per day, commercially rounded to a whole
  number and printed without a unit to stay compact: the 7-day view labels each
  daily bar with that day's grams, and the year view labels each monthly bar
  with the month's grams averaged over its calendar days. The dense ~30-bar
  month view is left unlabelled to avoid clutter.
- Today screen, monthly per-day average. The summary card's right-hand column
  now shows the current month's average grams per day: a caption "Ø <month>"
  (the full localized month name) above the figure "<x> g/day". The left column
  keeps the "Today's Total" caption but no longer repeats today's gram figure —
  that number already appears on the daily-limit bar just below, so the card
  shows only the label "Alcohol" there. The per-day average uses the same rule
  as the chart and the statistics summary (see Fixed). Backed by new
  monthlyAvgPerDay and currentMonthLabel fields on TodayUiState.
- New/renamed string resources, translated into all 20 locales: `avg_of_month`
  ("Ø %1$s" format), `alcohol` and `grams_per_day`; the now-unused `grams_alcohol` was
  removed.

Changed:
- Statistics chart, year view: the dashed daily-limit line and the over-limit
  red colouring are no longer drawn, because a month's per-day average is not
  compared against a daily limit. Bar heights remain the per-day average (the
  same scale as the 7-day and month views), so a bar's height matches its label.
  The 7-day and month views keep the daily-limit line unchanged.

Fixed:
- Per-day averages now agree across the app. The Today card's monthly average,
  the Statistics summary's "average per day" and the year-view chart bar for the
  current month previously used different denominators (the chart and Today
  counted the in-progress day; the summary did not), so the same month could
  read as e.g. 18.8 vs 19.6. They now share one rule, centralised in
  DayResolver.effectivePeriodDays: the current day counts only once a drink has
  been logged on it (otherwise the unfinished day is left out of the average).
  bucketize gained an optional inProgressDay parameter for this; the PDF export
  passes none and is unchanged.

Release housekeeping:
- versionName 0.68.2 → 0.69.0 (minor bump), versionCode 70 → 71.
- Synced proguard-rules.pro and the README title line; added Fastlane store
  notes 71.txt for de-DE and en-US.

---

## v0.68.2

Rename app, fix year chart, add SBOM tooling

Fixed:
- Statistics screen, YEAR view: the consumption chart aggregated by ISO week
  (~52 bars) while labelling each weekly bar with its month name, so a single
  month could appear as several identically-named bars (e.g. three "Jun" bars
  for entries spread across June). The on-screen YEAR view now aggregates by
  calendar month (≤ 12 bars, exactly one bar per month). Implemented by
  selecting `ChartGranularity.MONTHLY` instead of `WEEKLY` for the YEAR period
  in StatsViewModel; the existing month-name axis label is the natural label for
  a monthly bucket. The PDF export is deliberately unchanged — it derives its
  granularity from the chosen span via `ChartBucketing.granularityForSpan()`, so
  a one-year report still shows ~52 weekly bars.

Changed:
- The user-visible application name is now simply "Libellus Potionis"; the
  informal "Potillus" nickname has been dropped. This affects the `app_name`
  string in the base locale and every translated `values-<code>/strings.xml`,
  the README/CONTRIBUTING/COPYING/CHANGELOG titles, all source- and build-file
  header comments, `GplNotice.HEADER_LINES` (the header reproduced in exported
  reports and JSON backups), the rendered User's Guide titles, and the Fastlane
  store descriptions (de-DE, en-US).
- Technical identifiers are intentionally left unchanged: the application id and
  Kotlin package (`de.godisch.potillus`), the canonical repository URL
  (`codeberg.org/godisch/potillus`) and the source tarball name stay "potillus",
  so the update channel, signing identity and existing installations are
  unaffected.

Added:
- Standardized SBOM generation. The CycloneDX Gradle plugin (org.cyclonedx.bom
  3.2.4, the Gradle-9-compatible line) is wired into the build to emit a
  CycloneDX 1.6 JSON Software Bill of Materials for the release runtime
  classpath, i.e. exactly the third-party components packaged in app-release.
  No SBOM file is committed to source; the SBOM is generated on demand via the
  new `make sbom` target and is also produced as part of `make release`,
  landing next to the APK at app/build/outputs/sbom/. The plugin is build-time
  only, so the APK and versionCode are unchanged.
  - Android scoping: generation is pinned to the resolved `releaseRuntimeClasspath`
    configuration, which avoids the well-known "cannot choose between the
    following variants of project :app" resolution error.
  - Reproducible builds: the random serial number is disabled
    (`includeBomSerialNumber = false`) and the volatile `metadata.timestamp` is
    normalized by the new tools/sbom-normalize.py post-step (honoring
    SOURCE\_DATE\_EPOCH when set, otherwise dropping the timestamp), so the SBOM
    is byte-stable across identical builds. python3 was already a build
    prerequisite, so no new tooling dependency is introduced.

Release housekeeping:
- versionName 0.68.1 → 0.68.2, versionCode 69 → 70.
- Kept the version string in `proguard-rules.pro` and the README title line in
  sync (release-check.sh §1).
- Added Fastlane store notes `70.txt` for de-DE and en-US (release-check.sh §1
  requires the changelog-file set to be identical across all locales).

---

## v0.68.1

Fix lock bypass on warm start; add manual lock

Fixed (security):
- The biometric app lock could be bypassed after a "warm start". When Android
  destroyed the Activity but kept the process cached (common after the phone has
  been locked or used for other things for hours), reopening the app sometimes
  revealed it WITHOUT a prompt. Cause: the inactivity timestamp `backgroundedAt`
  was a per-Activity-instance field (reset to 0 on the recreated Activity), while
  `isAuthenticatedThisSession` is process-global (still true) — so onCreate's gate,
  which only checked the boolean, skipped the prompt, and onStart saw `backgroundedAt
  == 0` and also skipped. `backgroundedAt` is now process-global (companion object)
  and the staleness check runs in onCreate as well as onStart, so re-authentication
  is required once the threshold has elapsed regardless of whether the Activity was
  recreated. The timestamp is consumed on a valid foreground return, so a later
  configuration change (which skips onStop) cannot re-prompt spuriously.
  Reproducible deterministically with Developer Options → "Don't keep activities".

Added:
- "Lock app" entry in the shared overflow menu, for locking the app on demand. It
  clears the authenticated state and shows the prompt immediately. Variant A: it
  works regardless of the auto-lock setting, as long as a biometric or device
  credential is available; the entry is hidden when no authenticator is enrolled,
  so it can never strand the user. MainActivity exposes `lockNow()`, threaded
  through AppNavigation to the four main screens' `AppOverflowMenu`. New string
  `lock_app` added to all 21 locales (per-locale key count 172 → 173).

---

## v0.68.0

Add biometric toggle auth; fix bugs and lint

Quality-assurance release plus one small feature: two functional bugfixes, a
security-feature responsiveness fix, biometric authorisation for the lock toggle,
resource-handling hardening, additional tests, and documentation corrections. No
schema change, no UI redesign.

Added:
- Toggling the biometric app lock now requires biometric (or device-credential)
  authorisation in BOTH directions: enabling AND disabling the lock prompts, and
  the switch only changes when authentication succeeds. Cancelling leaves the
  setting unchanged (the switch is bound to the stored value and snaps back).
  MainActivity exposes a dedicated `authenticateForToggle()` that — unlike the
  app-start gate — never finishes the Activity on cancel; the capability is threaded
  through AppNavigation to the Settings switch. It reuses the existing biometric
  prompt strings, so no new translations are needed. If no authenticator is
  enrolled, the toggle is left unchanged (the lock could not be satisfied anyway).

Fixed (functional):
- CSV export now formats the grams column with a locale-independent dot decimal
  separator (Locale.ROOT). Previously the default-locale formatter produced a
  comma on comma-decimal locales (e.g. de, fr, es), and that unquoted comma split
  the grams value across two columns, misaligning every following column in the
  exported file. The localised column headers are now also escaped, so a comma in
  a translated caption can no longer add a stray column.
- Importing a JSON backup now runs the file read and JSON parse on Dispatchers.IO
  instead of the main thread, removing an ANR risk on large backups. This matches
  the export path, which already moved its I/O off the main thread.

Fixed (security / behaviour):
- The biometric app lock now reflects the live preference: enabling it during a
  running session arms the inactivity re-authentication immediately, rather than
  only after the next cold start. MainActivity keeps its cached flag in sync via a
  repeatOnLifecycle collector.

Hardened:
- WebViewPdfPrinter now creates its off-screen WebView from the application
  context (not the Activity context) and abandons any still-pending previous
  WebView before starting a new print job, preventing an Activity context leak if
  the page-finished callback never fires.
- DocumentViewerScreen reads its bundled raw resource on Dispatchers.IO via
  produceState instead of synchronously during composition, keeping all disk I/O
  off the UI thread.

Tests:
- Added ChartBucketingTest (JVM) for gap filling, per-day averaging, period
  clamping and calendar-month snapping.
- Added CsvExporterBuildTest (JVM, run under Locale.GERMANY) covering the new
  Locale.ROOT grams formatting, the eight-column invariant and header escaping.
  CsvExporter's CSV assembly was extracted into an internal, Context-free
  buildCsv() to make this testable without an Android Context.
- Added LimitBarUiTest (instrumented Compose UI) and LocaleFormattingInstrumented-
  Test (instrumented) for Context.formattingLocale().

Fixed (lint / backup-rule correctness):
- `res/xml/data_extraction_rules.xml` used `domain="datastore"`, which is not a
  valid data-extraction domain. Android Lint rejected it as a `FullBackupContent`
  error (build-blocking once Lint runs), and the rule would have silently matched
  nothing if `android:allowBackup` were ever turned on, defeating the intended
  exclusion of the encrypted preferences file from cloud backup and its inclusion
  in a device transfer. Both rules now use `domain="file"` with the real on-disk
  path `datastore/potillus_settings.preferences_pb` (the `file` domain is rooted
  at `getFilesDir()`, where DataStore stores its file). No runtime behaviour
  changes while `allowBackup` stays `false`.

Lint cleanup (warnings driven to zero):
- Fixed in the sources: launcher/limit/chart composables now declare `modifier`
  as the first optional parameter (ModifierParameter); DocumentViewerScreen reads
  the user guide via `LocalResources.current` so a configuration change
  re-invalidates it (LocalContextResourcesRead); the passphrase write uses the KTX
  `SharedPreferences.edit(commit = true) { … }` form, keeping the deliberate
  synchronous commit (UseKtx, ApplySharedPref); the adaptive-icon XMLs moved from
  `mipmap-anydpi-v26` to `mipmap-anydpi` since minSdk 30 makes the `-v26` qualifier
  redundant (ObsoleteSdkInt), and the legacy pre-API-26 density launcher bitmaps
  (`mipmap-*dpi/ic_launcher*.png`) were deleted — at minSdk 30 the adaptive icon is
  always used, so they were dead fallbacks whose continued presence alongside the
  unqualified `mipmap-anydpi` XML triggered an IconXmlAndPng error; the
  `localeConfig` attribute is annotated
  `tools:targetApi="33"` and the backup-rules advisory is suppressed with
  `tools:ignore="DataExtractionRules"` (allowBackup is off, so a legacy
  full-backup-content file would be dead config); the WebViewPdfPrinter singleton
  carries a documented `@SuppressLint("StaticFieldLeak")` on its object declaration
  (it holds only the application context and is cleared after use — see its KDoc); and
  five genuinely unused strings (`stats_from_section`, `bac_section`, `bac_desc`,
  `biometric`, `pdf_months_truncated`) were removed from all 21 locales
  (UnusedResources), lowering the per-locale key count from 177 to 172.
- Opted out by explicit policy in a documented `lint { }` block (NOT a baseline):
  the dependency/AGP/Gradle/targetSdk version-update nags (GradleDependency,
  NewerVersionAvailable, AndroidGradlePluginVersion, OldTargetApi), the launcher-
  icon design hints (IconLauncherShape, IconDuplicates), and PluralsCandidate.
  Each carries a rationale in build.gradle.kts; dependency upgrades and a proper
  plural conversion across 21 locales are tracked as separate, tested changes.
- Made the lint check a strict gate: `lint { warningsAsErrors = true }` (with the
  default `abortOnError = true`) so `./gradlew lintDebug` now fails on warnings,
  not just errors. The disabled checks above never report, so only genuinely new
  warnings can break the build.

Documentation:
- Corrected the stale "181 string keys" comment to 177 in AndroidManifest.xml and
  app/build.gradle.kts (LocaleSyncTest remains the authoritative source).
- Corrected the "minSdk 35" remark in the AndroidManifest biometric comment to the
  actual minSdk 30.
- Translated the remaining German inline comments in AndroidManifest.xml and
  app/build.gradle.kts to English, matching the project's English-documentation
  convention.

---

## v0.67.2

Bugfix: locale-sensitive text (month names, weekday names, long dates) now follows
the in-app language instead of the system language. Previously, with the app set
to English, the PDF report still printed German month names next to its English
"Export Date" and "Period" labels.

### Fixed

- **PDF report dates follow the in-app language.** `PdfReportBuilder` formatted
  dates and month labels with `Locale.getDefault()`, which reflects the *system*
  locale and is unaffected by the in-app language picker
  (`AppCompatDelegate.setApplicationLocales` only re-configures the Context, not
  the JVM default). Labels (drawn from string resources via the Context) were
  therefore localized while the adjacent month names were not. The two
  locale-sensitive formatters are now built per report from the Context's locale,
  and the weekday/month axis labels use the same locale. The formatters were also
  `object`-level `val`s frozen at class-load time, so this additionally removes a
  stale-locale hazard.
- **Calendar and statistics screens follow the in-app language.** The same
  `Locale.getDefault()` mismatch was present on screen: `CalendarScreen` (long
  dates, the "MMMM yyyy" month header and weekday header), `StatsScreen` (the
  week/year chart axis and the weekday-chart labels) and `SettingsScreen` (the
  statistics from/to date). All now format with the per-app locale, taken from the
  Compose `LocalContext`.

### Added

- **`Context.formattingLocale()` helper** (`l10n/LocaleSupport.kt`) — a single,
  documented source for "the locale to format user-visible values in", resolved
  from the Context configuration so it always agrees with the localized string
  resources. All formatting code now goes through it instead of
  `Locale.getDefault()`.

### Changed

- **Version bump** to `0.67.2` / `versionCode 67` across `build.gradle.kts`,
  `README.md` and `proguard-rules.pro`, with matching localized store changelog
  notes (`fastlane/.../changelogs/67.txt`) for de-DE and en-US.

---

## v0.67.1

Bugfix: the in-app Markdown viewer (Copyright and Help) now resolves HTML/Markdown
character entities such as `&copy;`, which were previously shown verbatim.

### Fixed

- **`MarkdownText` resolves character entities.** The viewer now decodes
  HTML/Markdown character entities — named (`&copy;` → `©`, `&amp;`, `&mdash;`,
  …) and numeric (`&#169;`, `&#xA9;`) — in headings and visible text, never in
  URLs. Unknown names and out-of-range numeric values are left verbatim. Stray
  ampersands without a trailing `;` (e.g. "AT&T") are untouched.

### Changed

- **Fastlane changelog sync check.** `release-check.sh` §1 now additionally
  verifies LOCALE PARITY: all `fastlane/metadata/android/<locale>/changelogs/`
  directories must carry the same set of `<versionCode>.txt` notes, so a release
  note added to one language but forgotten in another is caught before release
  (previously only the current versionCode's presence per locale was checked). A
  maintainer reminder was added at the top of this CHANGELOG.
- **Version bump** to `0.67.1` / `versionCode 66` across `build.gradle.kts`,
  `proguard-rules.pro`, the `README.md` title and this CHANGELOG, with new
  fastlane `changelogs/66.txt` notes for `en-US` and `de-DE`.

---

## v0.67.0

Renamed the overflow-menu **License** entry to **Copyright** and broadened the
document it shows: the viewer now displays the project's `COPYING.md` notice and
the full `LICENSE.md` GPL text, joined at build time and separated by a single
blank line, still untranslated. Added a README section describing the project's
textbook-grade source documentation, introduced a fastlane store-metadata tree
for Google Play and F-Droid (English and German), and hardened the build: the
release gate now runs on every build and its fastlane release notes are tied to
the `versionCode`.

### Added

- **Fastlane store metadata.** New `android/fastlane/metadata/android/` tree with
  `en-US` and `de-DE` listings, each providing `title.txt` (≤30 chars),
  `short_description.txt` (≤80), `full_description.txt` (≤4000) and a
  `changelogs/<versionCode>.txt` release note (≤500, F-Droid's limit). Texts are
  derived from `README.md`; titles and descriptions deliberately omit the version
  to avoid churn. An `images/` folder per locale carries the launcher icon and
  documented placeholders for the feature graphic and screenshots (the binary
  assets must be supplied before publishing). Layout follows the conventions both
  `fastlane supply` and F-Droid consume.
- **README documentation section.** New *Source Code Documentation* subsection
  under *Technical Aspects*, explaining the literate, KDoc-everywhere style, how
  `release-check.sh` enforces it, and the benefits for newcomers, reviewers and
  long-term maintenance.

### Changed

- **"License" → "Copyright" in the overflow menu.** The string key `license` was
  renamed to `copyright` in all 21 locales with the (intentionally untranslated)
  value `Copyright`. The navigation route `Screen.License`, the callback
  `onOpenLicense`, and the raw resource `R.raw.license` were renamed to
  `Screen.Copyright`, `onOpenCopyright` and `R.raw.copyright` so no identifier
  still calls the feature "license". KDoc/comments in `AppNav.kt`,
  `AppOverflowMenu.kt` and `DocumentViewerScreen.kt` were updated to describe the
  combined document accurately (and to correct a stale note that claimed the text
  was rendered as plain, non-Markdown monospace).
- **Build-time copyright document.** The Makefile rule that copied
  `../LICENSE.md` to `raw/license.md` now concatenates `../COPYING.md`, a blank
  line, and `../LICENSE.md` into `raw/copyright.md`. `check-guides`, `.gitignore`,
  `distclean` and the `prereq` prerequisite list were updated accordingly.
- **`MarkdownText` h1 top spacing.** Level-1 (`#`) headings gained a top inset
  (20.dp, larger than the `##` heading's 16.dp). Previously an h1 had no top
  inset, so the `# GNU GENERAL PUBLIC LICENSE` heading at the COPYING/LICENSE
  seam sat closer to the text above it than the `## Preamble` heading below —
  now its gap is at least as large.
- **`release-check.sh` moved to `android/tools/`** and re-anchored to `android/`
  (one line: `cd "$SCRIPT_DIR/.."`); all other relative paths are unchanged. A
  new Makefile `release-check` target runs it, and it was added to `prereq`, so
  the full read-only release gate now runs on **every** build and aborts on any
  hard failure.
- **`release-check.sh --Werror`.** New switch that treats warnings as errors
  (non-zero exit on any warning). The Makefile `release-check` target passes it,
  so warnings can no longer slip silently into a build. Without the flag warnings
  remain advisory (exit 0); an invalid option exits 2; `--help` is supported.
- **Sharper §5 documentation heuristic.** The KDoc look-behind now skips
  multi-line annotation arguments (e.g. `@Query("""…""")`) so KDoc placed above
  the annotation is found, and it excludes local (nested) functions the same way
  it already excludes private ones. This removes two false positives
  (`EntryDao.getDailySummaries`, `PdfReportBuilder`'s local `svg`) so the gate is
  clean under `--Werror`.
- **Version coupling for fastlane.** `release-check.sh` §1 verifies that every
  fastlane locale directory ships a `changelogs/<versionCode>.txt` note matching
  the current `versionCode`, alongside the existing version-string consistency
  check across `build.gradle.kts`, the CHANGELOG, `README.md` and
  `proguard-rules.pro`.
- **Removed the Makefile `version-check` target.** Its checks are fully covered
  by `release-check.sh` §1, which already runs in `prereq`; keeping a separate
  Make target would only duplicate that logic. The target and its entry in
  `prereq`/`.PHONY` were dropped, and the documentation that pointed at it now
  points at the script.
- **Version bump** to `0.67.0` / `versionCode 65` across `build.gradle.kts`,
  `proguard-rules.pro`, the `README.md` title and this CHANGELOG.

---

## v0.66.0

PDF-report improvements: the time-of-day chart now labels every hour beneath the
axis, the weekday profile is shown as a bar chart, the category breakdown is a
half-width table paired with a colour-matched donut, and two peak-consumption KPIs
(max per day, max per 7 days) were added. Follow-up changes: a donut rendering fix,
average-grams bar labels, red limit lines, an eight-bucket on-screen time-of-day
chart, an annual info dialog, and integer-only body weight.

### Added

- **Annual info dialog.** A once-per-year dialog ("Do you like this App?") shown
  only when the app is opened on December 27th (device-local date); if that day is
  missed it is not caught up later. `PotillusApp` decides this once per process
  start (`checkAnnualInfoDialog()`) and `MainActivity` renders it over the content,
  mirroring the existing device-transfer dialog. The "last shown year" is persisted
  through `IAppPreferences.infoDialogShownYear` (new DataStore key
  `info_dialog_shown_year`; `FakeAppPreferences` updated). New strings
  `info_dialog_title` / `info_dialog_body` (placeholder) / `info_dialog_ok` in all
  21 locales, with title and OK localised per language.
- **Bar value labels.** PDF time-of-day bars and the on-screen `ValueBarChart`
  (time-of-day + weekday) now print the average grams above each bar
  (`ValueBarChart` gains a `showValues` flag; bars reserve headroom so labels are
  not clipped).
- **Peak-consumption KPIs.** `util/PdfReportData.kt` gains `maxPerDay` (heaviest
  single calendar day) and `maxPer7Days` (heaviest *rolling* 7-consecutive-day
  window; the whole-period total when the period is shorter than 7 days).
  `util/PdfReportBuilder.kt` shows them as two new KPI tiles. New strings
  `pdf_kpi_max_day`, `pdf_kpi_max_7days` translated into **all 21 locales**.
- **Category donut in the PDF.** Beside the (now half-width) category table the
  report draws an SVG donut matching the on-screen chart, using the same per-category
  colours (`util/PdfReportBuilder.kt` `categoryColor()`, mirroring
  `ui/component/categoryColors`). The ring is built with the stroke-dasharray
  technique (`PIE_SLICES` block: `PIE_FILL`, `PIE_DASH`, `PIE_GAP`, `PIE_OFFSET`) so
  it needs no raster image and survives SimpleTemplate's HTML-escaping. Each table
  row gets a matching colour swatch (`C_COLOR`) as an inline legend.

### Fixed

- **Donut rendered every slice as a full ring.** The SVG dash values were formatted
  with the default locale, so on a comma-decimal device `stroke-dasharray="40,00
  60,00"` was parsed by SVG as four numbers (`40 0 60 0`) — a zero gap that paints
  the whole circle. The pie geometry is now formatted with `Locale.ROOT`
  (`util/PdfReportBuilder.kt`).

### Changed

- **On-screen time-of-day chart → eight 3-hour buckets.** The Statistics screen now
  shows eight buckets (0–3, 3–6 … 21–24), each the **average grams per day** in the
  period (`StatsViewModel`: `hourBucketAverages` replaces the 24 hourly sums in
  `StatsUiState`; the divisor is the same `effectivePeriodDays` used for the per-day
  rate). The PDF time-of-day chart keeps all 24 hourly bars, each labelled with its
  average grams per day.
- **Limit lines are now red dashed** (were amber/orange) in both the PDF
  (`.chart .limit` → `#c83232`) and the app (`AlcoholBarChart` limit line →
  `dangerRedColor()`), matching the over-limit cue colour.
- **Body weight is integer-only.** Settings accepts whole numbers only
  (`GramsInputDialog(allowDecimal = false)`) and displays an integer; the PDF shows
  the weight as an integer (`roundToInt()`).
- **Time-of-day chart: all hours labelled, below the axis.**
  `assets/report_template.html` + `util/PdfReportBuilder.kt`: the chart is split into
  a bars row (`HBARS`) and a separate axis row (`HLABELS`) rendered *beneath* the
  baseline, and every hour 0..23 is labelled (previously only every third hour, and
  the labels sat inside the plot area where tall bars overlapped them). New CSS
  `.barchart` family; the obsolete `.chart.hours` variant was removed.
- **Weekday profile is now a bar chart.** Replaces the former one-row table with a
  bar chart analogous to the hour chart: bars (`WDBARS`) with the average value
  printed above each bar and the weekday names on the axis row (`WDLABELS`). Bar
  heights leave 15 % headroom so the value label above the tallest bar still fits.
- **Category breakdown layout.** The table is now half width (`.cat-row` /
  `.cat-table`, ~48 %) with the donut occupying the right half.

### Tests

- `test/.../util/PdfReportDataTest.kt`: added a test for `maxPerDay` / `maxPer7Days`.
- `PdfTemplatePlaceholderTest` continues to guard the template ⇄ builder placeholder
  contract; it automatically covers the new `HBARS`/`HLABELS`/`WDBARS`/`WDLABELS`/
  `PIE_SLICES`/`C_COLOR`/`H_VALUE` placeholders and the removal of the old
  `HOURS`/`WEEKDAY_*` blocks.

---

## v0.65.0

Feature release. Adds two new charts to the Statistics screen, reworks the PDF
report's time-of-day section into a 24-hour chart, adds median KPIs alongside the
existing means, fixes the per-day average of partial (started) months, shows the
running Android version in the PDF footer, makes the light-mode "caution" colour
clearly yellow, and adds a build-time guard that every PDF template placeholder is
initialised. The PDF layout/design in `assets/report_template.html` was also
updated (visual styling), independently of the structural edits listed here.

### Added

- **`ui/component/ChartComponents.kt` – `ValueBarChart`.** A small, reusable
  vertical bar chart (no time axis, no limit line, no abstinence ticks) used by the
  Statistics screen for the new hour-of-day and weekday charts. A bar of value ≤ 0
  is drawn as an empty slot, which is how "no data for this slot" is shown.
- **Statistics screen: hour-of-day and weekday charts.** Above the category donut
  the screen now shows, in order, a **24-hour** chart (grams per clock hour) and a
  **weekday** chart (average grams per weekday, rotated to the locale's first
  weekday). Each card is hidden when it has no data.
  - `ui/screen/StatsViewModel.kt`: `StatsUiState` gains `hourlyGrams` (24 buckets),
    `weekdayOrder` (ISO 1..7, rotated) and `weekdayAverages` (null = weekday never a
    drink day); all computed in the existing `combine`.
  - `ui/screen/StatsScreen.kt`: renders the two new cards; weekday labels use the
    locale's short `DayOfWeek` names.
- **PDF report: median KPIs.** Beside the mean tiles the report now prints
  **Median per Day**, **Median per Drinking Day**, **Ø Drinking Days/Month** and
  **Median Drinking Days/Month**. Medians are robust to the occasional very heavy
  day that can inflate a plain average.
  - `util/PdfReportData.kt`: adds `medianPerDay`, `medianPerDrinkDay`,
    `avgDrinkDaysPerMonth`, `medianDrinkDaysPerMonth`, plus a private `median()`
    helper (even count → mean of the two central values).
  - `util/PdfReportBuilder.kt`: emits the four extra KPI tiles.
  - `res/values*/strings.xml`: new keys `pdf_kpi_median_day`,
    `pdf_kpi_median_drink_day`, `pdf_kpi_avg_drink_days_month`,
    `pdf_kpi_median_drink_days_month` – translated into **all 21 locales**.
- **PDF report: 24-hour time-of-day chart.** The former "Ø first/last drink" and
  "share before/after 17:00" figures are replaced by a 24-bar chart of **grams of
  pure alcohol per clock hour** (0..23), mirroring the on-screen chart.
  - `util/PdfReportData.kt`: adds `hourlyGrams: List<Double>` (24 buckets).
  - `util/PdfReportBuilder.kt`: fills the new `HOURS` repeat block (height = grams
    relative to the busiest hour; axis thinned to every third hour plus hour 23).
  - `assets/report_template.html`: new `.chart.hours` CSS variant and `HOURS`
    repeat block; the old before/after meta table is removed.
  - `res/values*/strings.xml`: new screen titles `stats_time_of_day`,
    `stats_weekday` – translated into **all 21 locales**.
- **`test/.../util/PdfTemplatePlaceholderTest.kt` (new).** A pure-JVM guard that
  reads `report_template.html` and `PdfReportBuilder.kt` as source, then fails the
  build if any `{{PLACEHOLDER}}` used in the template is never initialised in the
  builder (which would otherwise print as a raw `{{…}}` in the PDF). Comments are
  stripped before scanning, and a second test asserts a few structural placeholders
  are seen so a broken scan cannot pass vacuously.

### Changed

- **Light-mode "caution" colour is now clearly yellow.** `ui/theme/Color.kt`: the
  light-theme `warningColor()` changed from amber-700 `#B45309` to gold `#A67C00`.
  The previous amber still read as orange-red on the small dot (its red channel
  dominated its green), sitting too close to the danger red. `#A67C00` shifts the
  hue towards gold while staying compliant: **3.35:1** vs the light background
  (≥ 3:1 required for a non-text indicator; 3.82:1 vs a white card) and **2.38:1**
  vs the danger red `#960018`. Dark mode (`#E8A020`) is unchanged.
- **PDF footer 2 carries the running Android version.** `util/PdfReportBuilder.kt`:
  the line now reads *"… on Android &lt;release&gt;, …"* using
  `Build.VERSION.RELEASE` (falling back to the numeric API level when blank),
  replacing the static *"for Android"*.
- **`assets/report_template.html` – heavier documentation (teaching detail).**
  Added a top-of-body **placeholder & block inventory** and richer per-section
  comments. (Separately, the file's visual design was updated manually by the
  author; see the note at the top of this entry.)

### Fixed

- **Partial-month g/day no longer diluted by not-yet-recorded days.**
  `util/PdfReportData.kt`: the monthly **Ø g/day** now divides each month's grams by
  the number of that month's calendar days that actually fall inside the report
  period `[firstDate, lastDate]` (via `ChronoUnit.DAYS.between(…)`), not by the full
  calendar-month length. Previously a started first/last month counted its
  remaining, unrecorded days as abstinent and deflated the figure.

### Localisation

- **`res/values*/strings.xml`**: removed the four now-unused keys
  `pdf_meta_first_drink`, `pdf_meta_last_drink`, `pdf_meta_before_18`,
  `pdf_meta_after_18`; added the six new keys above, translated into every locale.
  Net change is uniform across all 21 files (`168 → 172` strings), so
  `LocaleSyncTest` stays green.

### Tests

- `test/.../util/PdfReportDataTest.kt`: removed the obsolete *"time-of-day
  percentages are complementary"* test (the fields no longer exist); added tests
  for the 24-bucket hourly histogram (sums to the total), the new medians/means,
  and the partial-month g/day fix.
- Added `PdfTemplatePlaceholderTest` (see *Added*).
- `test/.../ui/screen/StatsViewModelTest.kt`: hardened the three data-bearing tests
  (`single over-limit day`, `drink today extends the effective period`,
  `categoryBreakdown sums grams`) against two pre-existing, time/scheduling-dependent
  fragilities (no production behaviour changed):
  - They dated their entry with `LocalDate.now()` (the real calendar date) while the
    ViewModel derives its period from the LOGICAL day (shifted by `dayChangeHour`,
    `4` in these tests). Run between midnight and 04:00 the entry fell one calendar
    day outside the period, so the computed state had no data and the assertions saw
    zeros. They now date the entry with `DayResolver.today(4, 0)`, matching the
    period — which was the tests' own documented intent ("use today's date as the
    logical date").
  - They assumed the first Turbine emission is already the computed state rather than
    the `stateIn(WhileSubscribed)` seed. A small `awaitComputed()` helper now skips
    any leading seed emission.

---

## v0.64.0

Feature release. Reworks the consumption chart (Statistics screen **and** PDF
report) into a real, gap-free time axis that also shows abstinent days,
overhauls the PDF footers, and fixes a colour bug that made the traffic-light
"caution" state look like "danger" in light mode.

### Added

- **`domain/ChartBucketing.kt`** – a small, Android-free helper shared by the
  Statistics screen and the PDF export. It expands the sparse per-day summaries
  (which only contain days *with* entries) into a continuous, gap-free series of
  buckets covering every day in the period, so abstinent days become explicit
  zero buckets on a proper time axis. A bucket may be a day, a week or a month;
  its value is the **mean grams of pure alcohol per calendar day** inside the
  bucket. Using a per-day average (rather than a per-bucket total) keeps the
  dashed **daily-limit** reference line directly comparable across all
  granularities. The object is pure `java.time` + plain data, hence JVM
  unit-testable.

### Changed

- **Statistics chart now uses a real time axis incl. abstinent days.** WEEK and
  MONTH render one bar per day; YEAR aggregates into weekly buckets (≈ 52 bars)
  spanning `max(1 Jan, statsFrom) … today`. Days/weeks with zero consumption are
  no longer omitted: they are drawn as a small **green tick** at the baseline, so
  "recorded, nothing consumed" is visually distinct from a tiny bar. Axis labels
  are **thinned** for dense charts (≤ 12 buckets → one aligned label per bar;
  more → a handful of evenly spaced labels for context).
  - `ui/component/ChartComponents.kt`: `AlcoholBarChart` now takes a
    `List<ChartBucket>` and a `(ChartBucket) -> String` label function instead of
    a `List<DaySummary>`; renders the abstinence tick and the thinned labels.
  - `ui/screen/StatsViewModel.kt`: builds the bucket series (`chartBuckets`,
    `chartGranularity`) in the same `combine` that produces the rest of the UI
    state. The legacy `dataPoints` field is retained unchanged.
  - `ui/screen/StatsScreen.kt`: feeds `chartBuckets` to the chart and formats the
    label per period (weekday / day-of-month / month name).
- **PDF report: the monthly-average trend chart is replaced by the same
  time-axis chart and is now shown unconditionally** (previously hidden when
  there were fewer than two months of data). The export picks a granularity from
  the recorded span (`≤ 35 days` daily, `≤ 366 days` weekly, else monthly).
  Abstinent buckets are drawn as a green tick, matching the on-screen chart.
  - `util/PdfReportData.kt`: adds `chartBuckets` + `chartGranularity` (the
    existing `months` list is kept for the monthly *table*).
  - `util/PdfReportBuilder.kt`: emits the bucket bars with per-bucket tick
    visibility and thinned labels.
  - `assets/report_template.html`: adds the green-tick markup/CSS to the chart.
- **PDF footers overhauled.**
  - **Footer 1** (medical disclaimer) is now translated and present in **all 21
    locales** (`pdf_footer1`), with new wording: *"Estimates – not a medical
    diagnosis. Not for fitness-to-drive assessment or diagnostic purposes."*
  - **Footer 2** is **English-only and never translated**: it is built in code
    (no longer a string resource) and reads *"Created with Libellus Potionis
    v&lt;version&gt;, free software under the GNU GPL v3, WITHOUT ANY WARRANTY."*
    The version is **shortened** to `MAJOR.MINOR.PATCH` via
    `BuildConfig.VERSION_NAME.substringBefore("-")`, so the debug build's
    `-debug` suffix is stripped from the printed line.
  - The separate **running GPL footer was removed**; its GPL / no-warranty notice
    is folded into Footer 2.
  - Both footers are now **pinned to the bottom of their page** (page 1 / page 2)
    regardless of how much content precedes them, via per-page flex `.sheet`
    wrappers in the template.
- **Traffic-light "caution" colour fixed in light mode.** `ui/theme/Color.kt`:
  the light-theme `warningColor()` changed from amber-800 `#92400E` to amber-700
  `#B45309`. On a 12 dp dot the very dark amber-800 was almost indistinguishable
  from the danger red `#960018` (same red channel, little green), so the YELLOW
  state read as RED in light mode. amber-700 keeps a clearly amber hue and still
  clears the ≥ 3:1 contrast a non-text indicator needs (4.40:1 on the light
  background). Dark mode was already fine and is unchanged.
- **`res/values*/strings.xml`**: `pdf_footer1` updated/translated in all locales;
  `pdf_footer2` removed from all locales (key count drops uniformly 171 → 170, so
  `LocaleSyncTest` stays green).

### Assumptions

- **Per-day average.** Weekly/monthly bars show the bucket's mean grams per day
  (not the bucket total), so the daily-limit line stays meaningful at every
  granularity. A daily bar therefore equals that day's own total, unchanged.
- **Abstinent = zero in the period, including today.** The current (in-progress)
  day's empty bucket is also shown as a green tick.
- **Footer pinning is best-effort and tuned for A4** (`.sheet { min-height:
  267mm }` = A4 height minus the existing 14/16 mm `@page` margins). On US Letter
  the printable height differs; per-page footer placement should be verified by
  exporting a PDF and the `min-height` adjusted if needed.

### Known follow-ups

- The 19 non-German/English `pdf_footer1` translations are **best-effort and
  should be reviewed by native speakers** before release (consistent with the
  project's translation-quality policy).
- The PDF chart heading string `pdf_section_trend` ("…avg g/month") was left
  untouched to avoid a 21-locale translation churn; its unit wording is now
  slightly imprecise for daily/weekly charts and is a candidate for a future
  copy pass.

---

## v0.63.1

Bug-fix release. Resolves a runtime crash when switching between the bottom-bar
main screens, and hardens the app against a whole class of `java.time`
availability problems by enabling **core library desugaring**.

### Rationale

The app crashed with `java.lang.NoSuchMethodError: No virtual method
datesUntil(...)` shortly after a non-Today main screen was shown. The trigger is
`java.time.LocalDate.datesUntil(...)`, a Java 9 API used by `StatsViewModel`,
`DayResolver` and `PdfReportData`.

On Android, `java.time` is provided by the *updatable* ART mainline module
(`/apex/com.android.art/.../core-oj.jar`). `datesUntil()` was backported into a
later ART revision, so at one and the same API level a device whose module has
been updated (e.g. via Google Play system updates) exposes the method, while an
older emulator system image does not. This is exactly why the crash reproduced
on an API 30 emulator yet not on physical API 29/30 devices: identical API
level, different ART module version. Relying on the platform's `java.time` for
Java 9+ methods is therefore fragile across runtimes.

Core library desugaring removes this dependency on the device's module version:
D8/R8 rewrites the affected `java.*` calls to resolve against the bundled
`desugar_jdk_libs` implementation, which is shipped inside the APK and available
uniformly down to `minSdk`. This fixes the crashing call site **and** every
other `datesUntil()` (and future Java 9+ `java.time`) usage at once, with no
changes to the Kotlin sources.

### Fixed

- **App no longer crashes when switching main screens.** Enabling core library
  desugaring makes `LocalDate.datesUntil(...)` resolve on all supported
  runtimes, eliminating the `NoSuchMethodError` raised from
  `StatsViewModel.uiState` (and latent in `DayResolver` and `PdfReportData`).

### Changed

- **`app/build.gradle.kts`**: set `isCoreLibraryDesugaringEnabled = true` in
  `compileOptions` and added the `coreLibraryDesugaring(libs.desugar.jdk.libs)`
  dependency.
- **`gradle/libs.versions.toml`**: added the `desugar-jdk-libs` version
  (`2.1.5`, 2.x requires AGP 7.4.0+ — satisfied by AGP 9.2.0) and the matching
  `com.android.tools:desugar_jdk_libs` library coordinate.
- **Version bump to 0.63.1**: `versionName` (`app/build.gradle.kts`) and the
  version strings in the README title and the `proguard-rules.pro` header
  brought in sync with this CHANGELOG (enforced by the `version-check` build
  step); `versionCode` advanced `60 → 61` for the published APK.

### Notes

- Side effects of desugaring are limited to a small APK-size increase (only the
  used classes survive R8 shrinking in release builds) and an additional L8 dex
  step at build time. The supported device range is **unchanged**: desugaring
  does not raise `minSdk` (it works down to API 21, well below the project's
  `minSdk = 30`).

---

## v0.63.0

Localisation-scope release. Reduces the shipped languages to the set whose
translations can be quality-assured against the German/English originals for
**both** the UI strings and the in-app user guide, and adds a build-time guard
that keeps the two language sets identical from now on.

### Rationale

Previously the app shipped 51 translated locales, but only a subset could be
reviewed to a level the project is willing to vouch for across *both* surfaces
(strings and the long-form guide). Shipping a translation that cannot be
quality-assured is worse than not shipping it. This release keeps only the
languages that clear that bar for both surfaces, and writes the missing guides
for the kept languages so that every shipped language now has a guide.

### Changed

- **Supported languages reduced to 21** (20 locales + the English base):
  `cs da de el en es fr it ja ko nb nl pl pt pt-BR ro ru sv uk zh-CN zh-TW`.
- **Seven new user-guide translations** authored from the German source
  (`usersguide.de.md.in`), token placeholders preserved:
  `el ja ko ro uk zh-CN zh-TW`. Every kept language now ships a guide.
- `locale_config.xml` and `SupportedLocales.kt` trimmed to the kept set. The
  English base stays listed as `en` (no `values-en/`; it resolves to the base
  `values/`), which remains best practice for the per-app language picker.

### Removed

- **31 languages** dropped from `values-XX/`, `locale_config.xml` and
  `SupportedLocales.kt` (including Latin, whose guide template and rendered
  guide were removed too):
  `ar bg bn cy et fi fo ga ha he hi hr hu id is la lb lt lv mr ms mt sk sl sw ta te th tr vi yo`.

### Added

- **Build-time language-parity guard.** The guide-template language set and the
  string-resource language set must now be identical (both counting the base as
  English). Enforced on two layers: `render-guide.py` aborts the build (write
  and `--check` modes) with a precise diff, and a new `LocaleSyncTest` case does
  the same on the Gradle/CI path.

### Release bookkeeping

- `versionName` → `0.63.0`, `versionCode` → `60`; README title and
  `proguard-rules.pro` header updated to match (release-check.sh §1 /
  `make version-check`).

---

## v0.62.1

Maintenance release. Small UI consistency fixes, a clearer PDF export file name,
a menu-icon refresh, and refreshed German localisation.

### Fixed

- **PDF export file name now carries the `.pdf` extension.** The system "Save as
  PDF" dialog derives its default file name from the print-job name, which
  previously lacked an extension (e.g. `potillus_report_20260603_1430`).
  `PdfReportBuilder.jobName()` now appends `.pdf`, so the dialog pre-fills a
  complete file name.

### Changed

- **Unified the "danger" red across the Statistics screen.** The over-limit
  chart bars and the over-limit statistics (e.g. *Days over daily limit*,
  *over weekly limit*, *over drink-day limit*) and the rising-trend percentage
  now use `dangerRedColor()` — the same saturated red already used by the delete
  trash icons, traffic-light bullets and calendar over-limit dots — instead of
  the softer Material `error` colour. Export-error text still uses `errorColor()`,
  as it denotes a genuine error state rather than a statistic.
- **Overflow-menu icons refreshed.** The *License* entry now uses the open-book
  glyph (`MenuBook`), and the *Help* entry uses a medical-cross glyph
  (`LocalHospital`). The cross inherits the menu's content colour (it is not
  drawn red), so it blends with the active theme.
- **German localisation updated.** The German user's guide and
  `values-de/strings.xml` were revised (provided by the maintainer).

### Release bookkeeping

- `versionName` bumped to `0.62.1`, `versionCode` to `59`; README title and
  `proguard-rules.pro` header updated to match (release-check.sh §1).

---

## v0.62.0

Feature release. Replaces the fixed, configurable calendar week with a gliding
**7-day window** throughout the app, and removes the *"Week starts on …"* setting.

### Rationale

The weekly gram limit and the maximum-drink-days limit were previously evaluated
per calendar week, resetting on a user-chosen weekday. A fixed reset is easy to
game (heavy drinking split across the Sunday/Monday boundary landed in two
separate buckets) and does not reflect continuous health risk. A trailing 7-day
window — every day judged against itself plus the previous six days — never
resets, is stricter, and matches how low-risk-drinking guidance is generally
framed. Removing the setting also simplifies the Settings screen.

### Changed

- **All consumption metrics now use a trailing 7-day window** (today + the
  previous six calendar days), evaluated continuously:
  - *Today screen* — the "this week" gram total, drink-day count and the range
    label now cover the last seven days instead of the current calendar week.
  - *Statistics screen* — the **WEEK** period is now the rolling last-7-days
    window (its previous period, used for the trend %, is the seven days before
    that); MONTH and YEAR are unchanged. The period chip is relabelled **"7 days"**.
  - *Limits* — the traffic light and the "days over limit" statistics/PDF figures
    use the rolling window. `AlcoholCalculator.countLimitViolations` was rewritten
    from a per-calendar-week grouping into an O(n) two-pointer sliding window and
    no longer takes a `weekStartDay` parameter.
- **Calendar grid and PDF weekday profile** keep a fixed first weekday for *layout
  only*; it now follows the **device locale** (via the new
  `DayResolver.firstDayOfWeekIso()`) instead of the removed setting.
- User-facing strings reworded from "week" to "7 days" in the English base, German
  and — best-effort — all other bundled locales:
  `weekly_limit_grams`, `drink_days_setting`, `drink_days_label`,
  `limit_caption_week`, `days_over_weekly_limit`, `pdf_unit_g_per_week`,
  `pdf_kpi_over_weekly`, and the stats period label `week`.

### Removed

- The **"Week starts on <weekday>"** setting and its entire plumbing:
  `AppSettings.weekStartDay`, `IAppPreferences.setWeekStartDay`,
  `AppPreferences` key `week_start_day` (its stored value is now ignored — no
  migration needed; no DB schema change), `SettingsViewModel.setWeekStartDay`,
  and the Settings UI control.
- The obsolete `week_starts_on` string was deleted from the base locale **and all
  51 translations** so the `LocaleSyncTest` key-count/key-set checks stay green.

### Fixed

- Nothing was found broken during the accompanying review pass; see *Notes* for a
  pre-existing observation that was left as-is to keep this change focused.

### Tests

- `AlcoholCalculatorTest`: the `countLimitViolations` suite was rewritten for the
  rolling window, adding cases for window-boundary inclusivity (a 6-day gap shares
  a window, a 7-day gap does not), no gram carry-over beyond the window, and the
  drink-day count not resetting across a weekday boundary. Expected values were
  cross-checked against an independent reference implementation.
- `PdfReportDataTest`: the weekday-order test is now locale-deterministic (asserts
  against `DayResolver.firstDayOfWeekIso()` instead of a hard-coded Monday), so it
  passes regardless of the JVM default locale on the build machine.

### Notes / follow-ups

- **Translations:** the reworded limit strings were translated (best-effort) for
  every bundled locale, preserving each language's existing terminology and only
  swapping the period token to "7 days". Placeholders (`%1$s`) and locale key sets
  are unchanged, so the format-arg and `LocaleSyncTest` checks stay green. Two areas
  intentionally keep their English fallback for now, by agreement: the in-app
  user's guide (`usersguide*.md`) and the "crypto key unavailable" startup message.
- **Build not run in this environment.** The change was made and statically
  reviewed without executing the Android/Gradle toolchain (unavailable in the
  authoring sandbox). Please run `./gradlew testDebugUnitTest lint` before release.
- **Pre-existing observation (not changed):** `TodayViewModel` and `StatsViewModel`
  each retain a `java.time.LocalDate` import that already appeared unused before
  this change. Left untouched to avoid widening the diff; safe to drop later.

---

## v0.61.3

Bug-fix release. Fixes the PDF export (broken on every device since v0.61.0), the
limit progress bars turning red one step too early, a self-terminating comment in
the report template, and two build-tooling paths missed when the code base moved
into `android/`.

### Fixed

- **PDF export failed on every device** ("Export fehlgeschlagen"). The placeholder
  regex in `SimpleTemplate` left its closing braces unescaped (`\{\{(\w+)}}`). The
  desktop JVM regex engine — which local unit tests and `make test` run against —
  accepts a bare `}`, but the stricter ICU engine on Android devices
  (`com.android.icu.util.regex`) rejects it with `PatternSyntaxException`. That
  threw inside `SimpleTemplate`'s static initialiser, failed every
  `PdfReportBuilder.buildHtml` call, and the exception was swallowed by
  `runCatching`, surfacing only as a brief "export failed" banner. All braces are
  now escaped (`\{\{(\w+)\}\}`), which is valid under both engines.
- **Progress bars turned red when a limit was exactly *reached*** rather than
  exceeded. `LimitBar` (daily and weekly gram limits) and `DrinkDaysBar` coloured
  the bar red at `fraction >= 1.0`. Red now means *strictly over* the limit
  (`totalGrams > limitGrams` / `drinkDays > maxDrinkDays`), matching
  `AlcoholCalculator.countLimitViolations` and the calendar/chart over-limit
  markers. Reaching the limit exactly stays amber.
- **Self-terminating comment in `report_template.html`.** The documentation block
  at the top contained a literal `repeat:NAME` / `end:NAME` example written with
  real HTML-comment delimiters, whose first close sequence ended the doc comment
  early and leaked explanatory prose into the rendered page. The example is now
  described without literal delimiters. (This was previously masked by the PDF
  export crashing before it could render.)

### Fixed (build tooling, after the move into `android/`)

- `release-check.sh` looked for `CHANGELOG.md` / `README.md` in its own directory
  (`android/`), but they live at the repository root; it now reads `../CHANGELOG.md`
  and `../README.md`, matching the `version-check` Make target.
- The root `Makefile` `install` target referenced the pre-move APK path
  `potillus/app/build/...`; corrected to `android/app/build/...`.

### Added

- `SimpleTemplateInstrumentedTest` (androidTest) exercises `SimpleTemplate.render`
  on-device, so the JVM-vs-ICU regex divergence that caused the PDF crash is caught
  by `make test`'s `test-device` phase in future — the JVM unit test cannot detect
  it.

### Notes

- Root cause of the PDF regression was confirmed from an on-device logcat stack
  trace (`PatternSyntaxException` in `SimpleTemplate.<clinit>`); the pure pipeline
  (`PdfReportData`, template fill) was never at fault.
- The WebView + system-print path itself still warrants the usual on-device check
  now that the report can be generated again: trigger the PDF export, confirm the
  system print dialog opens, A4 pagination looks right, and "Save as PDF" works.

---

## v0.61.2

- Moved Android code base into subdirectory android/.

## v0.61.1

Bug-fix release: corrected off-by-one errors in the abstinence and average
calculations so that the **abstinent-days KPI**, the **average per day**, and the
**current / longest abstinence streaks** all agree and follow a single, consistent
rule for how the in-progress current day is treated:

- A day counts as a **drink day** the moment its first drink is logged. At that
  point today joins the observable period (with the amount consumed so far), so
  the period is one day longer than the completed days.
- A day counts as an **abstinent day** only once it has *finished* alcohol-free,
  i.e. it has reached the next day-change time without any consumption.
- While today has no drink yet it is undetermined (it may still become either a
  drink or an abstinent day) and stays out of the period entirely until it finishes.

Formally the period length is `effectivePeriodDays = completedDays + (today is a
drink day ? 1 : 0)`, and every rate / count is derived from it.

### Fixed

- **Current / longest abstinence over-counted by one day.** `DayResolver`'s
  tail-gap calculation (last drink day → today) counted the span *including* the
  last drink day. Since the last drink day is itself a drink day (and today is
  still in progress), both endpoints must be excluded; the gap now subtracts the
  drink day (`− 1`, floored at 0), matching the inter-drink-gap convention that
  already did this. Example: last drink two days ago, none since → current
  abstinence is now `1` (the single completed dry day), previously `2`.
- **Abstinent-days KPI and average-per-day were inconsistent with the
  drink-today case.** The Statistics view divided by / subtracted from a period
  that excluded the in-progress day, while `totalGrams` and `drinkDays` already
  *included* a drink logged today. Both are now derived from one explicit
  `effectivePeriodDays = completedDays + (today is a drink day ? 1 : 0)`:
  - `avgPerDay = totalGrams / effectivePeriodDays` — previously divided by the
    completed days only, so logging a drink today divided today's grams over a
    period that did not include today, overstating the daily average (and showing
    `0` when the period was just today). Now today extends the period exactly when
    it is a drink day.
  - `abstinentDays = effectivePeriodDays − drinkDays` (= completed dry days) — the
    in-progress day is never counted as abstinent. Per-drink-day averaging still
    includes today, as intended.

### Changed (documentation / tests)

- Clarified the `DayResolver` KDoc for both abstinence functions to state
  explicitly that the last drink day and the in-progress current day are both
  excluded, and rewrote the `StatsViewModel` comment around the previously
  misleading `coerceAtLeast(0)` note to document the single `effectivePeriodDays`
  model from which the average and the abstinent-day count are derived.
- Updated four `DayResolverTest` expectations to the completed-day semantics
  (last-drink-3-days-ago 3→2, drank-yesterday 1→0, statsFrom-ignored 3→2,
  tail-gap-included 9→8) and added regression tests for the reported scenario
  (drink on T−2, today T → current and longest tail = 1) plus a `StatsViewModelTest`
  case asserting that a drink logged today extends the period for `avgPerDay`.

### Notes

- Behaviour intentionally differs from a naive "days since last drink": the day
  immediately after a drink day shows `0` and becomes `1` only once the following
  day has also finished dry. This is the rule that makes the KPI and the streaks
  consistent.
- A drink logged before the day-change time on the "statistics start" date falls
  on the previous logical day and is correctly excluded from the period — this was
  already handled by the logical-date model and needed no change.

---

## v0.61.0

Reworked the PDF report so its **layout can be edited by hand** without touching
report code. The report is now authored as an HTML/CSS template under
`app/src/main/assets/`; computed numbers and localised labels are injected into
it at runtime, and the result is turned into a PDF through the **Android system
print dialog**. No third-party PDF library and no extra permission were added,
preserving the app's no-network, minimal-permission design.

### Changed (PDF export architecture)

- **Hand-editable template.** `app/src/main/assets/report_template.html` defines
  the two-page A4 report's structure and styling (fonts, colours, spacing, column
  widths, section order, page breaks). It uses `{{PLACEHOLDER}}` tokens and
  `<!-- repeat:NAME -->…<!-- end:NAME -->` row blocks; the contract is documented
  in the file header. Editing it requires only a rebuild, not code changes.
- **System print dialog instead of silent file write.** The PDF is produced by
  loading the report HTML into an off-screen `WebView` and calling
  `PrintManager.print(...)` (`WebViewPdfPrinter`). The user picks *Save as PDF*
  (or a printer) and the destination in the system UI.
- **Behaviour preserved.** All figures are computed by the new pure
  `PdfReportData` layer, which reuses `AlcoholCalculator` and `DayResolver`, so
  the PDF and the on-screen statistics still agree exactly.

### Added

- `util/PdfReportData.kt` – Context-free computation of every report figure
  (KPIs, monthly aggregates, category shares, time-of-day, weekday profile,
  streaks). Unit-tested on the JVM (`PdfReportDataTest`).
- `util/SimpleTemplate.kt` – a tiny, dependency-free HTML templating engine
  (scalar placeholders + repeat blocks, with HTML escaping). Unit-tested
  (`SimpleTemplateTest`).
- `util/PdfReportBuilder.kt` – resolves localised labels, formats numbers and
  fills the template; replaces the old canvas-drawing `PdfExporter`.
- `util/WebViewPdfPrinter.kt` – renders the report HTML via the system print
  dialog.

### Removed

- `util/PdfExporter.kt` – the previous `android.graphics.Canvas`/`PdfDocument`
  exporter that hard-coded the layout in Kotlin and drew each element by pixel
  coordinate.

### UX / behavioural notes

- The PDF export no longer writes a file straight to *Downloads* and no longer
  opens a share sheet; saving/sharing happen inside the system print dialog. CSV
  export is unchanged (still writes to Downloads and offers a share sheet).
- Long monthly tables are no longer truncated to a fixed row budget: the HTML
  report paginates automatically across pages. The `pdf_months_truncated` string
  is consequently no longer referenced (left in place; harmless).
- Per-page footers use the running GPL notice (fixed at the page foot) plus a
  trailing per-page disclaimer; this is a minor cosmetic change from the old
  absolute pixel placement and can be restyled in the template.

### Fixed / cleanup

- Removed the now-unreachable PDF branch from the Statistics share effect (PDF no
  longer flows through `shareTarget`).
- Updated stale KDoc in `ExportResult.kt` and `GplNotice.kt` that referenced the
  deleted `PdfExporter`.

### Known limitation (needs on-device QA)

- The `WebView` + `PrintManager` path is runtime-only and **cannot be exercised
  in unit tests or in this build environment**; it requires verification on a
  physical device / emulator (report renders, A4 pagination, "Save as PDF"). The
  pure pieces (`PdfReportData`, `SimpleTemplate`) are covered by JVM unit tests.

### Observation (not changed)

- `SettingsScreen` still contains a dead `application/pdf` branch in its share
  effect; Settings only exports JSON backups, so it never fires. Left untouched
  to keep this change scoped to the Statistics PDF export.

---

## v0.60.1

Lowered the minimum supported Android version from 15 to 11 to make the app
installable on a much larger share of devices, with no functional code changes —
every version-sensitive API the app uses is already available at the new floor.

### Changed (minimum supported Android version)

- **`minSdk` lowered from 35 (Android 15) to 30 (Android 11)** in
  `app/build.gradle.kts`. This roughly doubles the reachable worldwide install
  base (≈41% → ≈87%, per apilevels.com / Statcounter, April 2026 data) while
  `targetSdk` stays at 36. The previous floor was a policy choice (GrapheneOS
  Pixel devices), not a technical requirement: the codebase contains no
  `Build.VERSION.SDK_INT`, `@RequiresApi`, or `@TargetApi` usage, and every
  version-sensitive API it relies on is available at API 30 or lower
  (MediaStore Downloads + `RELATIVE_PATH` — API 29; Android Keystore AES-256-GCM
  — API 23; `androidx.biometric` — API 23; `WindowCompat` edge-to-edge insets —
  all levels; `AppCompatDelegate` locale switching — back-ported). API 30 is a
  *principled* floor rather than the lowest possible one: API 29 is the level at
  which the exporters can write to the public Downloads folder via `MediaStore`
  **without** any storage permission, so going lower would force a storage
  permission and break the app's minimal-permission design.
- **Bumped `versionCode` 53 → 54 and `versionName` 0.60.0 → 0.60.1**, kept in
  lock-step with the `proguard-rules.pro` header and the `README.md` title
  (enforced by `release-check.sh §1` / the `version-check` Make target).

### Changed (documentation)

- **Rewrote the `minSdk` rationale comment in `app/build.gradle.kts`** to a
  teaching-grade explanation: it now enumerates each version-sensitive API with
  its availability level, explains why no `SDK_INT` branches are needed, and
  documents the two graceful-degradation cases on API 30–32 (see below).
- **Added a "Supported Android versions" section to `README.md`** stating the
  Android 11+ requirement and the reason API 30 is the floor.
- **Added an API-level note in `AndroidManifest.xml`** explaining that
  `android:dataExtractionRules` is honoured only on API 31+ and is silently
  ignored on API 30, which is harmless because `android:allowBackup="false"`
  disables backup on every supported version.

### Notes (graceful degradation on API 30–32, no code change required)

- The **system per-app language picker** (`android:localeConfig`) is an API 33+
  feature. On Android 11–12 it is absent, but the in-app language selector in
  `SettingsScreen` (via `AppCompatDelegate`) works on every supported version.
- **Cloud/device-transfer backup** is disabled on all versions
  (`allowBackup="false"`), so the API-31+ `dataExtractionRules` being ignored on
  API 30 has no security or privacy impact.

### Follow-up (recommended before release)

- Run the unit **and** instrumented test suites (`MigrationTest`,
  `BackupRepositoryInstrumentedTest`, `EntryListItemUiTest`) on emulators for API
  30, 31/32, 33, and 34, plus a manual smoke test of CSV/PDF/backup export,
  biometric unlock, database encryption, and runtime language switching. This QA
  pass — not code changes — is the main remaining effort of the version drop.

---

## v0.60.0

A round of fixes and refinements: localized the device-transfer warning, a daily
limit rounding fix, build-tooling and in-app guide-viewer improvements, and
overflow-menu icons.

### Changed (version metadata)

- **Corrected the version strings, which had drifted.** `versionName` was still
  `0.58.0` (a leftover) and is set to `0.60.0`; `versionCode` is bumped 51 → 53;
  the `app/proguard-rules.pro` header is synced from `v0.56.0` to `v0.60.0`. These
  must stay in lock-step with the top CHANGELOG entry (enforced by
  `release-check.sh §1`).
- **Added the app version to `README.md`** (`v0.60.0` under the title), which had
  carried no version string at all.
- **New `version-check` target in the `Makefile`, wired into `prereq`.** It reads
  the version from the top-most `## vX.Y.Z` CHANGELOG entry and fails the build if
  `build.gradle.kts` (versionName), the `proguard-rules.pro` header, or the
  `README.md` title disagree — so version drift is caught on every local build,
  not just at the release gate.

### Changed (in-app guide viewer)

- **Paragraphs in the Markdown guide viewer now have a clear blank-line gap.**
  `MarkdownText` separated paragraphs with only 8.dp, which read as cramped; the
  inter-paragraph spacing is now 12.dp, matching the blank lines that separate
  paragraphs in the guide source.

### Changed (overflow menu)

- **Leading icons added to the overflow menu items:** a gear before Settings
  (`Icons.Filled.Settings`), a book before Help (`Icons.AutoMirrored.Filled.MenuBook`)
  and a gavel before License (`Icons.Filled.Gavel`). The icons are decorative
  (`contentDescription = null`) since each sits next to its text label. All three
  come from the already-included `material-icons-extended`.

### Fixed (invisible daily-limit exceedance from rounding)

- **Alcohol grams are now computed at 0.1 g precision instead of 0.01 g.**
  `AlcoholCalculator.calculateGrams` rounded to two decimals, so e.g. 188 ml at
  13.5 % stored 20.02 g. The UI displays one decimal ("20.0 g"), but the daily
  limit and binge checks compared the stored 20.02 g, so a 20 g limit showed as
  exceeded while the screen still read "20.0 g" — an exceedance the user could not
  see. `calculateGrams` now rounds to 0.1 g (new `roundTo1Decimal`), so the
  displayed value and every comparison use the same number. BAC keeps its 0.01 ‰
  precision (`roundTo2Decimals` is unchanged for `calculateBAC`).
- **No data migration.** Only newly logged entries are stored at 0.1 g; existing
  entries are left as-is (to be adjusted manually via a backup edit if desired),
  per request — no migration code was added.
- Unit tests in `AlcoholCalculatorTest` updated to the 0.1 g precision, including
  a regression test for the 188 ml / 13.5 % → 20.0 g case.

### Changed (guide build tooling)

- **`tools/render-guide.py` now discovers languages automatically** from the
  `docs/guide/usersguide*.md.in` templates instead of a hard-coded list, so
  adding a language (e.g. the new Latin guide) needs no script edit. The English
  default template is now the code-less `docs/guide/usersguide.md.in` (renamed
  from `usersguide.en.md.in`), mapping to the unqualified `values`/`raw`; a tag
  maps to `values-<q>`/`raw-<q>` with the Android region form (`pt-BR` →
  `pt-rBR`).
- **Outputs are regenerated on a timestamp basis:** an in-app `usersguide.md` is
  rewritten only when its template **or** the matching `strings.xml` is newer
  than the existing file. `--check` still compares content (for CI).
- Dropped the dead code for the former root-level `USERSGUIDE.md` /
  `USERSGUIDE-de.md` copies (those outputs were already removed) and updated the
  `Makefile` `guides` comment accordingly.

### Changed (localized device-transfer warning)

- **Translated the device-transfer warning** (`device_transfer_warning_title` /
  `device_transfer_warning_body`), which had been English in every locale, into
  the major languages: de, fr, es, it, nl, pt, pt-BR, ru, pl, sv, da, nb, cs, fi,
  el, tr, uk, hu, ro, sk, ja, ko, zh-rCN, zh-rTW, ar, id (26 locales). The
  remaining locales keep the English text for now. The wording uses the app's
  neutral/impersonal register (no informal/formal pronoun, matching the existing
  strings), and the "Settings → …" breadcrumb uses each locale's actual
  `settings` label so it matches what the app shows.

---

## v0.59.0

Toolchain modernisation for 2026, delivered as a sequence of incremental,
build-on-each-other steps under one version:

  - **Part 1:** raise the Kotlin compiler, KSP, the Compose BOM
    and the Kotlin-coupled test libraries, and adapt the instrumented UI tests
    to the Compose v2 testing APIs. The build system (AGP 8.13.2, Gradle
    8.14.5) is deliberately left untouched.
  - **Part 2:** Gradle 8.14.5 → 9.4.1 + AGP 8.13.2 → 9.2.0
    together (lock-step major upgrade), removing the now-redundant
    `kotlin-android` plugin and adopting AGP 9 built-in Kotlin, with the Kotlin
    compiler version pinned to 2.3.21 via a buildscript override; plus the AGP 9
    `srcDirs` → `directories` source-set fix.
  - **SQLCipher migration (this change):** move off the deprecated, EOL
    `android-database-sqlcipher` to the maintained `sqlcipher-android` for
    16 KB page-size compliance.
  - **Part 3 — hygiene (this change):** consolidate the inline-pinned
    dependency versions into the version catalog and drop the obsolete
    `suppressUnsupportedCompileSdk` flag. (Enabling the Gradle configuration
    cache is kept as a separate, optional follow-up.)
  - **Dependency freshening:** raise the explicitly-versioned
    AndroidX core libraries (core-ktx, activity-compose, lifecycle) to current
    stable. (navigation-compose stays at 2.8.9 — androidx.navigation 2.9 is still
    in alpha, so 2.8.9 is the current stable.)
  - **SQLCipher / SQLite / Room currency (this change):** raise the database
    stack to the current coordinated set — sqlcipher-android 4.15.0,
    androidx.sqlite 2.6.2 and Room 2.8.4 — and drop the merged room-ktx artifact.

### Changed

- **Kotlin 2.0.21 → 2.3.21.** Current patch of the Kotlin 2.3 line. Because the
  Compose compiler plugin and the serialization plugin are versioned via the
  same catalog key, this also moves the Compose compiler to 2.3.21, which is the
  compiler that pairs with the Compose 1.11 runtime (see below).
- **KSP 2.0.21-1.0.28 → 2.3.7.** Adopts KSP's new, Kotlin-decoupled version
  scheme (since KSP 2.3.0 a single release supports Kotlin `2.2.*` and newer), so
  the version no longer mirrors the compiler version.
- **Compose BOM 2025.05.01 → 2026.04.01.** Pins the core Compose modules to
  1.11.0.

### Fixed

- **Serialization runtime incompatible with the new compiler.**
  `kotlinx-serialization-core` was pinned to 1.7.3 (built against Kotlin 2.0).
  Kotlin's forward-compatibility rule (a runtime built with 2.Y supports 2.(Y+1)
  but not 2.(Y+2)) makes 1.7.3 invalid under the 2.3.21 compiler. Bumped to
  1.11.0 (built against Kotlin 2.2.x).
- **Coroutines test runtime incompatible with the new compiler.**
  `kotlinx-coroutines-test` 1.9.0 (Kotlin 2.0) falls under the same rule; bumped
  to 1.11.0. Dispatcher semantics are unchanged, so the JVM unit tests behave
  identically.
- **`kotlin-test` version drift.** The literal `2.0.21` test dependency was
  updated to `2.3.21` to match the compiler and avoid a metadata mismatch.
- **Build script: removed `kotlinOptions` String setter.** The Kotlin 2.3
  Gradle plugin turns `android { kotlinOptions { jvmTarget = "21" } }` from a
  deprecation warning into a hard script-compilation error. Migrated to the
  type-safe `compilerOptions` DSL in a new top-level `kotlin { }` block
  (`jvmTarget.set(JvmTarget.JVM_21)`), with the matching
  `org.jetbrains.kotlin.gradle.dsl.JvmTarget` import. This DSL migration was
  originally earmarked for part 3 but is mandatory here because the 2.3 compiler
  makes the old form non-compiling.
- **Instrumented UI tests under the Compose v2 testing APIs.** BOM 2026.04.01
  enables the v2 testing APIs by default, switching the Compose test
  dispatcher from `UnconfinedTestDispatcher` (eager) to `StandardTestDispatcher`
  (queued). In `EntryListItemUiTest`, the two click tests asserted on a plain
  counter immediately after `performClick()`; that read could now race the
  queued click. The assertions are wrapped in `composeTestRule.runOnIdle { }`,
  which drains the queue before reading. Node-based assertions
  (`assertIsDisplayed()`) were left unchanged because finders synchronise
  implicitly.
- **Stale documentation.** The `libs.versions.toml` comment claiming KSP must
  use the `<kotlin-version>-<ksp-patch>` format and "must exactly match the
  Kotlin version" was corrected to describe the decoupled scheme.

### Notes

- Building part 1 on AGP 8.13.2 emits a deprecation warning about the
  `org.jetbrains.kotlin.android` plugin: from Kotlin 2.3.0 onward the plugin is
  redundant on AGP versions that ship built-in Kotlin. This is expected and is
  resolved in part 2; it is a warning, not an error, on AGP 8.x.
- Room (2.7.1) and SQLite (2.4.0) are unchanged and run on KSP 2.3.7. A full
  compile + `connectedDebugAndroidTest` on the target toolchain is the
  authoritative verification step for this part.

### Changed (part 2 — build system)

- **Gradle 8.14.5 → 9.4.1.** Mandatory lock-step partner for AGP 9: moving from
  AGP 8.x to 9.x requires a Gradle 8.x → 9.x major upgrade that cannot be
  bypassed. 9.4.1 is the version Google's current AGP setup guide recommends.
- **AGP 8.13.2 → 9.2.0.** Major upgrade. JDK 17+ (we use 21) and compileSdk up
  to API 36.1 (we use 36) are satisfied.
- **Adopted AGP 9 built-in Kotlin; removed the `kotlin-android` plugin.** AGP 9
  compiles Kotlin itself, so `org.jetbrains.kotlin.android` is no longer applied
  (app and root) nor declared in the version catalog. Keeping it under AGP 9
  would be a hard error (duplicate `kotlin` extension), not just a warning —
  this resolves the deprecation warning noted for part 1.
- **Pinned the built-in Kotlin compiler to 2.3.21 via a buildscript override.**
  AGP 9 bundles KGP 2.2.10 as a floor. To keep the 2.3.21 compiler established
  in part 1 (the Compose/serialization plugins and test libraries are aligned to
  it), the root `build.gradle.kts` adds the officially documented override
  `buildscript { dependencies { classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.3.21") } }`.
  The Compose, serialization and KSP plugins continue to be applied via the
  version catalog and are unchanged.
- **Fixed AGP 9 source-set deprecation.** The first green AGP 9 build emitted
  `'fun srcDirs(...)' is deprecated. Use 'directories' mutable set instead`.
  The androidTest schema-assets line was migrated from
  `assets.srcDirs(files("$projectDir/schemas"))` to
  `assets.directories += "$projectDir/schemas"`. Same resolved location, AGP 9
  DSL. (The build also logs an informational note that `libsqlcipher.so` and two
  other prebuilt native libraries cannot be stripped of debug symbols; that is
  expected and requires no change.)

### Notes (part 2)

- The buildscript Kotlin pin is a hard-coded literal because a Gradle
  `buildscript` block cannot read the version catalog. It must be kept in sync
  with `kotlin` in `libs.versions.toml` on every future Kotlin bump; both spots
  carry a comment to that effect.
- KGP 2.3.21 is officially fully tested with Gradle only up to 9.3.0, so on
  9.4.1 benign Kotlin deprecation warnings are possible. Dropping the wrapper to
  9.3.0 would avoid them if AGP 9.2 accepts it; 9.4.1 was chosen to match
  Google's recommendation.
- KSP (2.3.7) is applied via the plugins block as before. Because 2.3.7 is above
  AGP's built-in KSP floor it is not force-upgraded; if a build ever reports a
  KGP/KSP mismatch, add the commented KSP `classpath(...)` line provided in the
  root `build.gradle.kts`.
- `android.builtInKotlin=false` is deliberately NOT set: built-in Kotlin is
  adopted, not opted out of (the opt-out is removed in AGP 10, mid-2026).
- No use of the removed AGP 9 variant APIs (`applicationVariants`, etc.) was
  found, so no DSL changes were required to configure under AGP 9. As always, a
  full compile + `connectedDebugAndroidTest` on the target toolchain is the
  authoritative verification step.

### Changed (SQLCipher migration — 16 KB page-size compliance)

- **`net.zetetic:android-database-sqlcipher:4.5.4` → `net.zetetic:sqlcipher-android:4.10.0`.**
  The old artifact was deprecated in 2022 and reached end-of-life in 2023; its
  native libraries are not built for 16 KB memory pages. Android 15+ devices can
  run with 16 KB pages and Google Play requires 16 KB support for apps targeting
  Android 15+, so the unaligned `libsqlcipher.so` (flagged by the strip step in
  the build log) is a real runtime/release risk. The maintained replacement
  `sqlcipher-android` ships 16 KB-aligned libraries (since 4.6.1).
- **`AppDatabase.kt` adapted to the new API.** The package moved from
  `net.sqlcipher.database` to `net.zetetic.database.sqlcipher`, and the Room
  integration class changed from `SupportFactory` to `SupportOpenHelperFactory`
  (same constructor: a passphrase `ByteArray`, zeroed immediately after). The
  new library also requires the native library to be loaded explicitly, so
  `System.loadLibrary("sqlcipher")` is called once before the factory is built.
  No schema, passphrase, or Keystore logic changed, so existing encrypted
  databases open unchanged.
- **Instrumented test (`MigrationTest.kt`) migrated too.** It also used the old
  `net.sqlcipher.database.SupportFactory`. Switched to `SupportOpenHelperFactory`
  with `System.loadLibrary("sqlcipher")` in the companion `init`. IMPORTANT
  semantic change: the old `SupportFactory(passphrase, hook, clearPassphrase)`
  third argument was `clearPassphrase` (the test passed `false` to keep the
  passphrase reusable across multiple opens); the new
  `SupportOpenHelperFactory(passphrase, hook, enableWriteAheadLogging)` third
  argument is unrelated (WAL). The new library has no passphrase-clearing toggle
  and does not zero the passphrase, so the single-argument constructor is now
  used and is safe across the test's repeated opens.

### Notes (SQLCipher migration)

- `androidx.sqlite` is deliberately left at 2.4.0 to keep this step a focused
  artifact swap. Newer `sqlcipher-android` releases (4.15.0) are paired with
  `androidx.sqlite` 2.6.2; raising both together is deferred to the optional
  dependency-freshening step. If the build reports a `SupportSQLiteOpenHelper`
  API mismatch, bump `sqlite` alongside.
- If Gradle fails to resolve the native AAR, append `@aar` to the `sqlcipher`
  library coordinate (a comment in `libs.versions.toml` notes this).
- Verification is necessarily on-device: a `connectedDebugAndroidTest` run
  (which exercises the encrypted Room database and the migration test) confirms
  the native library loads and decryption still works.

### Changed (part 3 — hygiene)

- **Consolidated inline-pinned dependency versions into the version catalog.**
  Eight dependencies were previously declared as string literals in
  `app/build.gradle.kts` (`androidx.tracing`, `junit`, `kotlin-test`,
  `kotlinx-coroutines-test`, `turbine`, `org.json`, `androidx.test:runner`,
  `espresso-core`). They now live in `gradle/libs.versions.toml` and are
  referenced via `libs.*` accessors. Resolved versions are unchanged, so this is
  behaviour-neutral; the per-dependency rationale comments stay at the usage
  site. `kotlin-test` now references the `kotlin` version (`version.ref`), so it
  can no longer drift from the compiler version.
- **Removed the obsolete `android.suppressUnsupportedCompileSdk=36` flag.** It
  silenced an "untested compileSdk" warning that no longer applies: AGP 9.2
  officially supports compileSdk up to API 36.1, and the project uses 36.

### Notes (part 3)

- This step touches only `gradle.properties`, the version catalog and dependency
  declarations; no source code changes. It is behaviour-neutral and should not
  alter the build graph beyond removing the (now unnecessary) warning
  suppression.
- The Gradle configuration cache (suggested by the build output) is intentionally
  not enabled here. It can surface incompatibilities (e.g. with the buildscript
  Kotlin override, KSP, or Room) and is best introduced as its own isolated,
  separately-tested change.

### Changed (dependency freshening — AndroidX core)

- **core-ktx 1.13.1 → 1.18.0**, **activity-compose 1.9.0 → 1.12.3**,
  **lifecycle 2.8.2 → 2.10.0** (current stable as of mid-2026). These were a year
  or more behind the SDK-36 / Kotlin-2.3 / Compose-1.11 baseline. Verified against
  the official AndroidX release notes; pre-release versions were deliberately
  avoided (core 1.19, lifecycle 2.11 are still rc/beta).
- **navigation-compose kept at 2.8.9.** androidx.navigation 2.9.x is still in
  alpha, so 2.8.9 is the current stable — no bump warranted. (Not to be confused
  with the JetBrains `org.jetbrains.androidx.navigation` 2.9.x KMP fork, which is
  a different artifact.)

### Notes (dependency freshening)

- This is a pure version bump in the catalog; no source changes. Still, it crosses
  real minor versions (notably lifecycle 2.9's Kotlin-Multiplatform repackaging),
  so it must be built and instrument-tested. The APIs this app uses
  (`collectAsStateWithLifecycle`, `viewModel()`, `setContent`) are unchanged.
- activity-compose and lifecycle were bumped together on purpose: activity 1.12
  depends transitively on a recent lifecycle, so pinning lifecycle to 2.10.0 keeps
  the catalog's declared version aligned with what actually resolves.
- Other explicitly-versioned libraries were left as-is: appcompat 1.7.0 and
  biometric 1.1.0 are the current stables; Room 2.7.1, DataStore 1.1.1 and the
  SQLCipher/SQLite pair are working and were out of scope here. Raising the
  SQLCipher/SQLite pair to the very latest (`sqlcipher-android` 4.15.0 +
  `androidx.sqlite` 2.6.2) remains available as a separate, coordinated change.

### Changed (SQLCipher / SQLite / Room currency)

- **sqlcipher-android 4.10.0 → 4.15.0**, **androidx.sqlite 2.4.0 → 2.6.2**,
  **Room 2.7.1 → 2.8.4** — bumped together as one coordinated set. 2.6.2 is the
  androidx.sqlite version Google documents for Room 2.8.4 and Zetetic documents
  for sqlcipher-android 4.15.0, so the three move in lockstep to avoid a
  Room ↔ androidx.sqlite binary-compatibility skew.
- **Removed the `room-ktx` dependency and catalog entry.** As of Room 2.8 the
  room-ktx APIs (coroutine/Flow support, suspend DAOs) are merged into
  room-runtime and the standalone artifact is empty. No code change is needed —
  the same APIs now resolve from room-runtime.
- **Corrected a stale comment** in `app/build.gradle.kts` that still referred to
  the old `SupportFactory` and an `@aar` classifier; it now describes
  `SupportOpenHelperFactory` and the explicit `System.loadLibrary` step.

### Notes (SQLCipher / SQLite / Room currency)

- Room 2.8.x is the final Room 2.x line (maintenance mode); Room 3.0 is a
  separate package (`androidx.room3`) and is deliberately not adopted. 2.8.x
  retains the SupportSQLite APIs, so the SQLCipher `SupportOpenHelperFactory`
  integration in `AppDatabase` and `MigrationTest` works unchanged.
- This crosses a Room minor version and the androidx.sqlite 2.5→2.6 line, so it
  must be built and instrument-tested. The migration test (which opens the
  encrypted DB through SQLCipher and validates the Room schema migration) is the
  key check. No schema, DAO, entity, passphrase or Keystore code changed.
- Verified against the official Room and sqlcipher-android documentation; no
  pre-release versions were used.

### Changed (Compose v2 test rule)

- **`EntryListItemUiTest` now uses the v2 `createAndroidComposeRule`.** Since
  Compose 1.11 (Compose BOM 2026.04.01, adopted in part 1) the v1 test
  environment factories are deprecated in favour of the
  `androidx.compose.ui.test.junit4.v2` package. Only the import changed: the v2
  factories are the sole part of the testing surface that moved, while the
  finders, actions, `setContent` and `runOnIdle` stay on their existing APIs. The
  v2 environment runs composition on a StandardTestDispatcher; the
  recomposition-dependent assertions were already wrapped in `runOnIdle {}` in
  part 1, so no test logic needed to change.

### Fixed (false "Settings not restored?" on first install)

- **The device-transfer warning no longer fires on a genuine first install.**
  Previously the warning was driven by a heuristic — install younger than 15
  minutes AND `language` empty AND `weightKg == 0.0` — and a fresh install
  satisfies all three, so every first launch showed "Settings not restored?".
  The check now uses an authoritative signal instead: a sealed passphrase
  envelope is *present* in storage (restored from an Android backup) but cannot
  be *decrypted* with this device's Keystore key — the actual signature of a
  transfer where the hardware-bound key did not migrate. A first install has no
  envelope at all, so the warning stays silent.
- **Implementation.** `AppDatabase` gains two read-only probes,
  `hasSealedPassphrase()` and `canOpenSealedPassphrase()` (the latter attempts
  `KeystoreSecretStore.open` and returns false on `GeneralSecurityException` /
  malformed blob, zeroing the plaintext). `PotillusApp.checkForDeviceTransferFailure()`
  consumes them; the pure decision `shouldWarnDeviceTransfer(present, decryptable)`
  is `present && !decryptable`. The install-recency window (`INSTALL_RECENCY_MS`)
  and the settings-based heuristic are removed, and `onCreate` no longer needs the
  pre-write settings snapshot for this check.
- **Tests.** `PotillusAppHeuristicTest` was rewritten to lock in the new truth
  table (present+undecryptable → warn; absent → silent; present+decryptable →
  silent). It remains a pure JVM test.
- **Display language unchanged but worth noting:** the dialog is shown via
  `stringResource`, i.e. resolved against the system/configuration locale. That is
  the correct behaviour here, because in the failure scenario the user's stored
  language preference lives in the encrypted store that cannot be read. The
  message strings are currently English in every locale (translation is tracked
  separately).

### Added

- **`docs/guide/usersguide.la.md.in` — a Latin translation of the user guide.**
  The build-time renderer (`tools/render-guide.py`) now emits the Latin guide to
  `res/raw-la/usersguide.md` (with `values-la` for the on-screen labels), so the
  app shows it for users whose per-app language is Latin.

---

## v0.58.0

Added a localized, build-time-templated in-app user guide system and an
in-app viewer for it; replaced the per-screen settings gear with a single
overflow (burger) menu that also opens the guide and the license; embedded a
GPLv3 notice in the JSON and PDF exports; and fixed a text bug in the English
source guide.

### Added

- **In-app user guides under `res/raw`.** The user guide now ships as a raw
  resource (`R.raw.usersguide`) so it can be displayed inside the app later. As
  with `strings.xml`, the file is locale-qualified: the English guide lives in
  `res/raw/usersguide.md` (the resource default) and each translated guide in
  `res/raw-<locale>/usersguide.md`. Because the app sets a per-app locale via
  `AppCompatDelegate.setApplicationLocales`, Android resolves the matching
  `raw-xx` directory automatically — exactly the mechanism already used for
  strings.
- **Single-source guide templates** in `docs/guide/usersguide.<lang>.md.in`.
  Every on-screen name (screen titles, settings-section headers) is written as a
  `{{key}}` token instead of a hard-coded word, so a guide can never drift away
  from the label the app actually shows.
- **Build-time renderer `tools/render-guide.py`.** It resolves each `{{key}}`
  against the *matching* locale's `strings.xml`, undoes Android's string
  escaping (e.g. French `Aujourd\'hui` → `Aujourd'hui`), and fails loudly on an
  unknown key. It writes the in-app `res/raw[-xx]/usersguide.md` copies (license
  header stripped for clean on-device rendering) and regenerates the
  repository-facing `USERSGUIDE.md` / `USERSGUIDE-de.md` (header kept, plus a
  "generated — do not edit" banner). Writes are content-diffed (no needless
  touches) and a `--check` mode lets CI verify the committed guides are in sync.
- **Curated 14-language core set** with real translations: English (base), plus
  German, French, Spanish, Italian, Dutch, Portuguese, Brazilian Portuguese,
  Russian, Polish, Swedish, Danish, Norwegian Bokmål and Czech. Every other
  supported language deliberately has no `raw-xx`, so the app falls back to the
  English guide via normal resource resolution rather than showing
  machine-quality text.
- **Makefile integration.** A new `guides` target regenerates the guides and is
  now a prerequisite of every build, so the shipped guides are always in sync;
  `check-guides` runs the renderer in verification mode for CI. Help text and
  `.PHONY` updated accordingly.
- **Overflow menu (`AppOverflowMenu`).** The four main screens previously each
  carried an identical settings gear in their top bar. They now share one
  composable that shows a burger icon (`Icons.Default.Menu`) opening a dropdown
  with three entries: **Settings**, **Help** and **License**. The menu holds no
  navigation logic of its own — it invokes callbacks supplied by
  `AppNavigation` — so the four screens stay free of navigation dependencies.
- **In-app guide & license viewer (`DocumentViewerScreen`).** A single,
  reusable read-only screen backs both new menu entries. *Help* renders the
  locale-resolved `R.raw.usersguide` as Markdown; *License* shows
  `R.raw.license` as plain monospaced text. Both are pushed on top of Home with
  an Up arrow, mirroring Settings, and are wired as two new type-safe routes
  (`Screen.Help`, `Screen.License`).
- **Minimal Markdown renderer (`MarkdownText`).** A small, dependency-free
  composable renders exactly the Markdown subset the guides use (ATX headings,
  reflowed paragraphs, `[text](url)` links). Adding no third-party library keeps
  the app dependency-light, in line with its privacy-minimal design; the
  unsupported-syntax boundary is documented in the file.
- **Bundled license (`res/raw/license.md`).** A verbatim copy of the
  project-root `LICENSE.md`, produced by a `cp` step in the Makefile's `guides`
  target. It is intentionally **not** translated or locale-qualified, so
  `R.raw.license` always resolves to the original (English) GPLv3 text;
  `check-guides` now also fails if the copy drifts from the root file.
- **GPLv3 notice in exports (`GplNotice`).** Exports now carry the project's
  GPLv3 header as a non-evaluated notice. The **JSON backup** gains a top-level
  `_comment` array (JSON has no comment syntax, and the importer already ignores
  unknown keys, so this round-trips safely). The **PDF report** gains a small
  one-line notice in the footer of every page (`FOOTER_RESERVE` raised from 30
  to 42 pt to make room). The **CSV export deliberately carries no notice**, as
  CSV has no portable comment convention and a leading line would surface as a
  spurious data row in spreadsheet importers.
- **Three new UI strings** (`menu`, `help`, `license`) added across all 52
  locales (the base plus 51 translations), so per-locale `strings.xml` parity is
  preserved (now 172 strings each, up from 169).

### Changed

- **Settings is now reached via the overflow menu**, not a dedicated gear icon.
  The gear `IconButton` was removed from all four main screens; `StatsScreen`'s
  now-unused icon imports were dropped.
- **Guide wording updated to match the new menu.** Every guide template's
  "gear/cog icon" phrasing was replaced with "menu icon (☰)" and the guides
  regenerated, so the shipped text describes the actual UI.

- **English source guide had stray heading echoes.** Several paragraphs ended
  with a duplicated fragment of the following heading (e.g. "… functions of the
  app. Highlights", "… on a Fairphone 4. \"Today\" Screen", "… the Widmark
  formula. Limits"). These were removed while templating; the German guide was
  already clean.

### Notes

- The in-app Markdown *viewer* deferred when the guide files were first added
  is now implemented (see `DocumentViewerScreen` / `MarkdownText` above), so the
  guide is readable directly inside the app rather than only via
  `resources.openRawResource`.
- This version *does* change `strings.xml`: three UI strings were added to every
  locale, raising the `LocaleSyncTest`-checked parity from 169 to 172 strings.
  `res/raw` (the guide and license copies) remains outside that test.
- The GPLv3 notice embedded in exports is kept in English on purpose — it is a
  legal notice rather than UI chrome, so it lives in code (`GplNotice`), not in
  the translatable `strings.xml`.

---

## v0.57.0

Replaced the gender + guideline-mode limit system with three always-active,
user-defined limits.

### Changed

- **Limits are now three independent values that always apply together:** a
  daily limit (g), a weekly limit (g) and a maximum number of drink days per
  week. Defaults are 20 g / 100 g / 5 days. The previous WHO / DHS / custom
  *limit mode* selector and the separate daily-vs-weekly *gram mode* toggle have
  been removed; all three limits are always evaluated at once.
- **Biological sex is no longer stored or used.** The Widmark BAC estimate now
  uses a fixed, conservative distribution coefficient r = 0.6 (the smaller of
  the two classic coefficients), which yields the higher — i.e. worst-case —
  blood-alcohol estimate. Body weight is still used.
- **Binge threshold** is now the sex-independent constant 48 g
  (`AlcoholCalculator.BINGE_THRESHOLD`), replacing the former per-sex values.
- **Today screen** now shows three progress bars (daily grams, weekly grams,
  drink days) instead of one gram bar plus the drink-days bar.
- **Traffic-light capacity dots** consider all three limits. Free servings are
  the minimum of the daily and weekly gram headroom; the drink-day limit acts as
  a gate that forces red once the week's drink-day budget is used up. The gate
  fires both when today is not yet a drink day and the week already holds the
  maximum number of drink days, and when today *is* a drink day but the maximum
  had already been reached on earlier days.
- **Statistics screen** replaces the single "days over limit" row with three
  rows: days over the daily limit, days over the weekly limit, and days over the
  drink-day limit (see the new `AlcoholCalculator.countLimitViolations`).
- **PDF report** drops the "Sex" metadata row and the guideline-mode line; the
  limit line now reads "X g/day · Y g/week · N drink days/wk", the KPI grid shows
  the three violation counts plus the (fixed-threshold) binge count, and the
  monthly table's over-limit column and the trend sparkline reference line now
  use the daily limit.
- **Settings screen** "Personal data" now contains only body weight; the new
  "Limits" section offers three numeric inputs (daily / weekly / drink days).

### Added

- `AlcoholCalculator.countLimitViolations(...)` — shared, unit-tested helper that
  counts the three violation kinds over a list of day summaries, grouping weeks
  by the configured week-start day. Used by both the Statistics screen and the
  PDF export so they always report identical figures.
- `LimitViolations` domain model holding the three counts.
- New, fully translated string resources across all 51 locales:
  `limits`, `daily_limit_grams`, `limit_caption_day`, `limit_caption_week`,
  `days_over_daily_limit`, `days_over_weekly_limit`, `days_over_drink_day_limit`,
  `pdf_unit_g_per_week`, `pdf_meta_drink_days_suffix`, `pdf_kpi_over_daily`,
  `pdf_kpi_over_weekly`, `pdf_kpi_over_drink_days`, `pdf_col_over_daily`.

### Removed

- Domain enums `Gender` and `LimitMode`; `AppSettings.gender`,
  `AppSettings.limitMode`, `AppSettings.weeklyGramMode`; the WHO/DHS limit
  constants and per-sex binge/Widmark constants; the `LimitMode` label
  extensions; the `DrinkCapacity.weeklyGramMode` field and its `effective*`
  helpers; and the now-orphaned `unit_g_per_day` plus all WHO/DHS/gender/
  weekly-mode string resources (24 keys).
- The corresponding `IAppPreferences` setters (`setGender`, `setLimitMode`,
  `setCustomLimit`, `setCustomMaxDrinkDays`, `setWeeklyGramMode`) were replaced
  by `setDailyLimit`, `setWeeklyLimit` and `setMaxDrinkDaysPerWeek`. The DataStore
  keys for the daily limit and drink-day count are reused under their historical
  names so existing values survive; obsolete keys are ignored.

### Documentation

- Updated `README.md`, `CONTRIBUTING.md` and the in-code KDoc to reflect the new
  model. The user guides already described the three-limit design.

### Notes / known issues

- A static **dead-code review** found two pre-existing functions in
  `AlcoholCalculator` that are referenced only by tests and never in production:
  `soberByMillis` and `limitPercent`. They predate this change and were left in
  place (public, tested domain API); removal is recommended if they are not
  intended for upcoming features. (`MILLIS_PER_HOUR`, by contrast, is live.) A
  handful of string resources (`bac_section`, `bac_desc`, `biometric`,
  `stats_from_section`) also appear unused; these are pre-existing and were not
  touched.
- The domain layer (`Models.kt`, `AlcoholCalculator.kt`) was compiled and its
  unit tests (39 cases, including the new BAC, limit, traffic-light and
  violation-counting tests) were executed and pass. The Android/Compose layers
  could not be compiled in this environment (no Android SDK); they were reviewed
  statically for signature and resource consistency.
- The new locale strings were translated on a best-effort basis for the less
  common languages; native review is recommended.

---

## v0.56.0

First sanitized, public baseline.

This is the starting point of the public, forward-only changelog. The internal
development history that preceded it has been removed — it is not part of the
published source — and the knowledge it carried, in particular the *reasons*
behind design decisions, now lives in the source code itself, in the KDoc and
comments next to the code each decision affects.

What was done to produce this baseline:

- **Source documentation sanitized.** All references to concrete past app
  versions and to internal review issue codes were removed from comments, KDoc,
  file headers, the README, CONTRIBUTING, the build script, the ProGuard rules,
  the localization resources and `release-check.sh`. Functional version tokens
  are intentionally kept because they are data contracts, not release history:
  the Room schema version (`@Database(version = 2)`, `MIGRATION_1_2`, the
  committed `app/schemas/*.json`) and the backup-format version
  (`BACKUP_VERSION`).
- **Design rationale folded into the code.** Explanations that previously lived
  only in the changelog (or were referenced indirectly through an issue code)
  were rewritten in present tense as self-contained rationale at the relevant
  code site, so the code explains itself without this file.
- **Three-part versioning.** The version string is now `MAJOR.MINOR.PATCH`,
  starting at `0.56.0` (`versionCode` 49). Going forward, routine changes bump
  PATCH and larger feature sets bump MINOR; `versionName`, this changelog's top
  entry, the README title and the ProGuard header stay in lock-step (CONTRIBUTING
  §6).

### Notes

- No application behaviour changed in this baseline: the edits are limited to
  documentation/comments, the version strings, and the version-format check.
