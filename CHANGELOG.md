<!-- vim: set et ts=4:
=============================================================================
Libellus Potionis "Potillus" -- Privacy-Friendly Alcohol Tracker
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

# Libellus Potionis (Potillus) – Changelog

<!-- Add new entries on top! -->

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
  scheme (since KSP 2.3.0 a single release supports Kotlin 2.2.* and newer), so
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
- Not built or tested in this environment (no Android SDK). Run `make test` and
  `make test-device` before tagging.
