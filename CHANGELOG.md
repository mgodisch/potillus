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
