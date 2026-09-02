<!-- vim: set et ts=4:
=============================================================================
Libellus Potionis - Privacy-Friendly Alcohol Tracker
Copyright (c) 2026 Martin A. Godisch <martin@godisch.de>
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

In addition, as permitted by section 7 of the GNU General Public License,
this program may carry additional permissions; any such permissions that
apply to it are stated in the accompanying COPYING.md file.

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
     fastlane/metadata/android/<locale>/changelogs/<versionCode>.txt for
     EVERY locale, keeping the set identical across locales. release-check.sh §1
     enforces both that the current versionCode's note exists in each locale and
     that all locales carry the same set of changelog files. -->

---

## v0.86.0

### Added

- A shared vector for the sealed-preferences byte layout.
- A shared vector for the weekday chart.
- A shared vector for the calendar's month alignment.

### Changed

- The biometric lock fails closed on Android when the device has lost every
  credential, as it already did on iOS.
- The iOS preferences store no longer treats a Keychain or file that is locked
  as unusable, so a write can no longer replace settings it could not read.
- The abstinence streaks apply the statistics floor themselves, so a drink day
  before the floor can no longer extend a streak across it.
- Android computes the calendar's month alignment in the domain now.
- The weekday chart no longer counts a running day without alcohol as a dry
  day.
- The trend arrow shows a rise against a previous period that existed but was
  abstinent.
- A Nynorsk device locale selects the Bokmål translation on Android.
- A backup with two drinks sharing one id, or an entry without a drink
  reference, is rejected on both platforms instead of being imported onto the
  wrong drink.
- A restored backup arms the biometric lock only on a device that can
  authenticate, and the import message says when it did not.
- On iOS a restored backup leaves the local language, body weight and
  statistics start in place where the backup carries none, as Android does.
- The report charts' headroom factors live in `ReportChart` on both platforms
  and are pinned by a shared vector.
- The bundled fastlane was updated to 2.238.0.

## v0.85.0

Edit drinks from the list's edit mode

### Added

- Shared vectors for how far the statistics screen can page back.
- The statistics start date has a row that clears it.
- The backup export has a switch for the settings block.
- A year heat-map in the calendar, with a month and year toggle, where a month
  opens the month view.
- The Today screen shows the current abstinence while a streak runs.
- `check-typography` gates the apostrophe and the quotation pair per language.
- Shared vectors for the bar height, the donut ring, and the locale's first
  weekday.
- `check-plural-parity` holds the day-count wording of both platforms
  together.
- The README's feature list names the app's accessibility support.
- `SectionTitle`, a card heading that announces its role to screen readers.
- The release gate holds the OpenPGP fingerprint in SECURITY.md and
  `make/publish.mk` together.
- The release gate holds the install guides' tool versions and the README's
  platform floor to the build files.
- The bundled-document renderer decodes the en dash and the middle dot.
- `DayResolver` maps a logical date and a wall-clock time to an instant.

### Changed

- The consumption chart names weekdays, days or months, as Android does.
- The time-of-day axis carries each bucket's starting hour.
- The longest abstinence reads green while it stands.
- The statistics start date reads as all history until one is picked.
- The three time headers share one arrow control.
- The PDF report covers the period picked in the export dialog.
- The report's month table lists every month the period covers.
- The README, CONTRIBUTING.md and the label gate point at the roadmap for
  accessibility.
- The roadmap carries the open work only.
- The roadmap's iOS notes describe the year heat-map the app ships.
- The `json` gem is at 2.21.2 in `fastlane/Gemfile.lock`.
- Every makefile deletes a target whose recipe stops with an error.
- The iOS guide fragment lists the renderer among its prerequisites.
- The calendar opens on the current month, with no day selected.
- The bottom bar is the only way between the four main screens.
- The statistics window can name a period before the current one.
- The statistics screen carries which period it shows, above the cards, on
  the list surface.
- Two arrows on the statistics screen move to another period, each a tinted
  tap target that dims at the edge.
- Update all users guides.
- `render-guide.py --platform` renders Android and iOS from `docs/guide/`,
  called that way by Gradle and by both Makefiles.
- Platform blocks sit on their own lines or inside a sentence.
- A row tap in the drinks list's edit mode opens the editor.
- The toolbar's edit toggle shows a pencil and a checkmark.
- `push-gitlab` creates the release before it signs and uploads.
- The GitLab API calls report the status and the server's answer.
- The push targets check the release tag against the GitLab remote.
- The `api` scope and the Maintainer role required of the GitLab token.
- A TestFlight upload reaches the internal testers without a further act.
- Play's native-debug-symbols warning stays unanswered, with the reason.
- The export dialog offers the visible period when no start date is set, and
  a today fallback before the first load.
- The build script's report-template note names the iOS renderer.
- Revised README.md.
- `AlcoholCalculator.drinkDayLimitReached` answers the drink-day gate on iOS,
  and `alcohol-calculator.json` pins it on both platforms.
- The statistics screen sets its values flush right on iOS, wrapped rows
  included.
- The dry-day tick in the iOS consumption chart is smaller.
- The About screen's License card links to the source repository.
- The roadmap carries an opt-in Android palette on iOS and a guided tour.
- The store descriptions carry the reworked text in all 21 locales.
- The roadmap carries Hebrew as the first right-to-left language.
- `SupportedLocales` names the places an RTL language reaches beyond layout
  mirroring.
- The roadmap carries plausibility guards for the shell gates' extractions.
- The privacy policy describes both platforms: storage protection, the biometric
  lock, the absence of networking, and the permission profile.
- `GOVERNANCE.md` states the continuity arrangement.
- The README states which interfaces are stable and that 19 of the 21 languages
  are machine-generated.
- `SECURITY.md` lists the App Store Connect variables and scopes the release
  verification to the Android artifacts.
- The Android dark theme carries two over-limit reds: `#DD2C2C` for dots, bars
  and icons, `#DF3A3A` for text and the trend arrows. The month grid and the
  calendar's delete confirmation use them too.
- Both dots in the month grid stay visible on a selected day.
- Every Android status colour is a named constant in `theme/Color.kt`, next to
  the contrast reasoning behind it.
- The iOS calendar's toolbar reads "add, edit, overflow" like the other screens.
- The selected day's tint in the iOS calendar is stronger in dark mode.
- `make ios` renders a stale user's guide by itself, as the Android build does.
- Calendar day cells draw a focus ring while focused.
- The year view's low-contrast empty cells and its undersized day targets are
  recorded as decisions in the Android Level AA protocol.
- The iOS Level A protocol carries the VoiceOver setup and the opening
  questions.
- The roadmap records the AGP 10 readiness check and why the Gradle 10
  deprecation waits on AGP.
- The Android Level AA protocol records the measured contrast of that red and of
  the light-theme caption colour.
- The secondary caption colour in the Android light theme is `#5D6C93`.
- The report template's HTML escaping on iOS compares Unicode scalars, with a
  combining-mark case in `template-render.json`.
- The comment-language gate reads the manifest, base-strings, theme, colour,
  extraction-rule, locale-config, and launcher-icon XML comments.
- The coverage prose names the enforced floors and the command that prints the
  current figures.
- The year heat-map draws only the days from the statistics start date through
  today.
- A day of alcohol-free entries is a dry day: no drink day, no break in an
  abstinence streak, and no dot or colour in the calendars.
- `AlcoholCalculator.isDrinkDay` and the drink-date queries carry that
  definition on both platforms.
- The limit bars, the Today summary rows and the statistics figures speak as one
  sentence on both platforms, with their units written out.
- The trend row speaks its label unabbreviated and its figure as a percentage.
- The body-weight note in Settings names what the weight is used for.
- The day-change time speaks as one row on both platforms, with its note
  beneath it.
- The iOS Level A protocol carries the spoken form of those rows.
- Entry rows, calendar days and the statistics period speak their dates and
  units as words, the period as one span; an entry row leads with its time on
  both platforms.
- The blood-alcohol row speaks as one sentence on both platforms.
- Calendar days speak their limit status, their grams to one decimal, and an
  empty day says so.
- Calendar weekday headers and day numbers are silent.
- The selected day speaks as one sentence naming its date, and its heading shows
  a formatted one on both platforms.
- An entry row speaks its time in the clock form of its language.
- The add-entry and drink dialogs name each field once, and the amount carries
  its unit in the label on both platforms.
- The BSD licence names are spoken in full.
- The iOS About screen speaks English, the language it is written in.
- The iOS time picker offers hours and minutes.
- The edit toggle names the list it edits.
- The category ring is silent on both platforms and its legend states each slice
  in one sentence.
- The hour and weekday charts speak one sentence per column, the hours as a span
  and the weekdays by name.
- The consumption chart speaks one sentence per bar, a day as its total and a
  month as its average.
- The weekday axis follows the in-app language.
- The calendar header and month name follow the in-app language.
- The language picker labels its system entry in the system language.
- Settings section headings, the drinking-days row and the statistics start date
  speak as headings, words and one row.
- Notes about the body weight, the backup file and the statistics floor sit in
  the card they explain.
- Gram limits read without a decimal place.
- The drinks list speaks each row as one sentence naming the drink first, ahead
  of the favourite star.
- The favourite star names the state it switches to.
- Drink strength shows one or two decimals in the in-app language.
- Limits, drinking days and body weight on iOS take a typed value, and the
  7-day limit steps by 1.
- Both String Catalogs mark their language-invariant keys as not to translate.
- Shared vectors pin the year heat-map's drawing window on both platforms.
- `check-l10n-parity` compares strings that carry format specifiers.
- App text, report labels and the guide token map spell the apostrophe as `’`.
- Store listings follow the same typography.
- The blood-alcohol estimate spans the day boundary and carries one decimal.
- A backup entry's grams are checked against its volume and ABV.
- An entry records the UTC offset it was logged at, optional in the backup.
- `release-check` counts a check whose input is absent as skipped.
- The UI-string map names the labels that exist on one platform only.
- `check-swift-argument-order`.
- Every language spells the drinking day one way.
- The release checklist names the tasks that resolve every artifact.
- Bar heights and donut slices in the Android report come from named functions.
- The iOS backup reader refuses an entry whose drink the file omits.
- The iOS settings screen names a device-backup setting the database file
  did not take.
- The contrast decisions in `theme/Color.kt` and the year heat-map stand where
  the code is.
- The roadmap names the unmeasured iOS contrast and the pending device pass.
- The assurance case takes its security requirements from SECURITY.md.
- The roadmap carries the open badge criteria and the Scorecard prerequisites.
- The security policy carries the OpenPGP fingerprint once.
- The security policy states the advisory sources and the support terms once
  each.
- The third-party notices point at the build files for what is not
  redistributed.
- The contributing guide states the review requirements, the coverage scope and
  the release steps once each.
- The Gradle and AGP findings sit with the settings they describe.
- The roadmap carries the outstanding work in shorter entries.
- The statistics screen's card titles are headings.
- The year heat-map's drawing window is `domain/YearGrid.kt`.
- The report chart's arithmetic is `domain/ReportChart.kt`, its palette
  `ReportPalette`.
- The two-character weekday cut sits with the other l10n helpers.
- The README states the platform floors, the hardware they imply and a pointer
  to the settings that define them.
- The iOS deployment target carries its reasoning in `ios/project.yml`.
- The install guides state each tool's purpose once.
- The test-vector index is one line per file, and lists `year-grid.json`.
- A calendar entry carries the instant of the day it was booked onto.
- The entry sheet opens on the drink whose row was written last.

### Removed

- The disclaimer beside the blood-alcohol estimate.

### Fixed

- Paging a month, a year or a statistics period from its header, and the
  statistics arrows knowing which periods exist.
- A statistics figure moves below its label when the two do not fit.
- Lists on the Today, Drinks and Calendar screens scroll their last row clear of
  the add button.
- The README's link to the roadmap.
- The last day of a past statistics period counts towards its average,
  its abstinent days and its chart.
- The year heat-map marks today with a ring the eye can find.
- The security footer on iOS follows the in-app language.
- The import dialog on iOS says what each mode does with the drink list.
- The gram-limit bars turn red only past the limit, on iOS as on Android.
- The base `strings.xml` section comments are in English.
- The contrast summary in `theme/Color.kt` matches the measured values.
- The empty cell in the year heat-map stands out from the card behind it.
- The `tgz` exclude derivation reads a trailing slash in `.gitignore` as a
  directory marker, and `__pycache__` directories stay out of the tarball.
- The l10n gate on freshly harvested String Catalog keys.
- A dead link in the best-practices self-assessment.
- French, Japanese, Korean and Chinese wording in four spoken labels.
- The blood-alcohol estimate across a gap between two rounds.
- The stated origin of the 60 g threshold, and the cost of the last-entry query.
- An entry's clock time after a change of time zone or a daylight-saving switch.
- The Room schema check reads the version the exported file states.
- The badge note on running the suites in CI.
- The security documents name the asset the app's own encryption covers.
- The roadmap carries what a dependency-verification attempt established.
- The time-of-day chart on the iOS statistics screen reads the recorded frame.
- The weekday chart averages over every occurrence of the weekday.
- The accessibility justification in the self-assessment names the gaps that
  are open.
- The coverage exclusions name the JVM tests that reach the excluded code.
- The README's platform floor is compared paragraph by paragraph, not line by
  line.
- An empty guide dependency fragment is dropped and rebuilt.
- `make guides` stops with an error when the fragment carries no rules.

---

## v0.84.0

Reach iOS parity and harden the release

This version reworks the iOS interaction model to match Apple's own list apps,
moves the canonical repository to GitLab, absorbs the store-path corrections
drafted for 0.83.1, folds in five quality-assurance rounds covering both
platforms, and revises the project's own texts.

### Added

- A thin root `Makefile` over `android/Makefile`, `ios/Makefile` and `make/*.mk`.
- iOS build, test, lint, format, version and guide targets behind a `require-macos`
  guard.
- `cover-check` on both platforms, at a 90 % line floor over PotillusKit.
- `release-ios`, staging only when two unsigned archives come out byte-identical.
- `qa-android` and `qa-ios`, each capturing one platform's device-free battery
  into a single log.
- `make -C android cover-figures` for the coverage figures alone.
- `make bestpractices`, writing an HTML page naming each criterion the badge site
  does not match.
- `tools/potillus_repo.py`, holding the repository root and the marketing version.
- `push-gitlab`, uploading each staged artifact into the generic package registry
  with a detached OpenPGP signature and an asset link the F-Droid recipe
  interpolates.
- `.gitlab-ci.yml` with three parallel check jobs on a pip-free image: the
  invariant gate, `make check-static`, and osv-scanner over the lockfiles.
- Six GitHub mirror workflows, every action pinned to a commit SHA, described in
  `docs/MIRROR-CHECKS.md`.
- An `osv-scan-sbom` macro over the CycloneDX SBOM, between generation and
  staging.
- `openvex.json` and `tools/check-vex.py`, which fails the build when the two
  drift from `osv-scanner.toml`.
- An "εxodus 0 trackers" badge and `tools/check-trackers.sh`, outside the offline
  release gate.
- `security-insights.yml`, and CodeQL as machine evidence in
  `docs/ASSURANCE_CASE.md`.
- `test-vectors/stats-window.json`, loaded by both platforms.
- Shared vector cases for the weekday label cut, in `report-chart.json`.
- `AppPreferencesDefaultsTest`, pinning what a fresh Android install is handed.

### Changed

- Delete on iOS is the toolbar edit toggle plus swipe on Today, Drinks and
  Calendar, and always asks first.
- Editing moves off the row: a tap opens the editor on Today and Calendar, a swipe
  reveals Edit and Delete on the drink list.
- Calendar is a `List` and can log a drink onto the selected day.
- The iOS overflow menu wears the More idiom, and the lock cover shows the
  device's real unlock glyph.
- Dirty sheets resist a swipe dismissal.
- Store assets split into two strands, the in-app screenshots and the per-locale
  report PDFs.
- `release-android` and `release-ios` are the sole writers of `releases/` and
  refuse to overwrite a staged artifact.
- Both platforms write their CycloneDX SBOM as `*.cdx.json`, staged and uploaded
  under that name.
- `release-android` and `release-ios` open with a check for osv-scanner 2.4.0,
  the version `.gitlab-ci.yml` pins.
- Four store targets, `push-{playstore,appstore}-{testing,production}`, for Play
  open testing, Play production, TestFlight and the App Store listing.
- `VALIDATE_ONLY=1` on the Play targets, a dry run against the Play API.
- Every store upload stops short of review: Play releases arrive as drafts,
  TestFlight builds reach no tester group, App Store versions await submission.
- The iOS TestFlight lane is `testing`, uploading without tester distribution.
- `release-ios` stages the `.ipa` after the SBOM scan.
- `docs/INSTALL-ANDROID.md` and `docs/INSTALL-IOS.md` list osv-scanner.
- `release-check.sh` §9 reads `docs/INSTALL-ANDROID.md` and `docs/INSTALL-IOS.md`.
- The `publish.mk` targets upload what is staged, each gated on the `v<VERSION>`
  tag and the expected signing key.
- `tools/release-check.sh` is decomposed into `tools/release-checks/lib.sh` plus
  one file per check, with identical output.
- `tools/check-ui-string-parity.py` compares labels with format specifiers and
  escapes normalized.
- The canonical repository is `gitlab.com/godisch/potillus`, and every reference
  in the tree carries GitLab's path shapes.
- "Pipelines must succeed" is on, which restores OpenSSF Baseline Level 2 and
  moves `hardened_site` to Met.
- Commit signing is a policy enforced at review; `main` stays protected
  server-side.
- `COPYING.md` holds the copyright, the GPL-3.0 grant, the App Store distribution
  exception and a pointer to where each third-party text sits.
- The tree follows the FSFE REUSE specification, with `REUSE.toml`, the verbatim
  texts under `LICENSES/`, and `make check-reuse`.
- The APK bundles four verbatim license texts, held together by the
  `android/Makefile` copy rules, `licenseDocuments`, `check-guides` and
  `OSPS-LE-03.02`.
- The SBOM resolves `coreLibraryDesugaring`, so `desugar_jdk_libs_configuration`
  is among the bundled texts.
- `docs/NOTICES.md` names every Gradle plugin the app module applies, the
  transitively bundled `kotlin-parcelize` artifacts, and the four CJK sample
  reports as Type 3 glyph outlines carrying no font program.
- The feature graphic carries the GPLv3 logo and no store badge.
- The iOS drink editor accepts comma decimals, and its messages, the Settings
  footers and the edit toggle follow the in-app language.
- The volume message names 5,000 ml on both platforms, the limit the validator
  enforces.
- The four clock-derived models break their ticker on cancellation and re-check it
  before writing.
- The `dataPoints` field is gone from both platforms' statistics state, the chart
  reading `chartBuckets`.
- Kover is at 0.9.9, counting `com.android.*` classes and using the dependency
  notation Gradle 10 requires.
- Branch coverage clears a `koverVerify` floor of 80, and
  `test_statement_coverage90`, `test_branch_coverage80` and `dynamic_analysis` are
  Met. The documents outside `android/app/build.gradle.kts` name the floor and
  `make -C android cover-figures` in place of a figure.
- Each store's release notes name the report changes and the platform's own
  fixes in all 21 languages, and nothing from the sibling platform.
- The iOS export-compliance comment names the sealed preferences blob, the
  Keychain key it uses and the unencrypted database.
- The user's guide count in `.bestpractices.json` reads 21 languages.
- `stats-window.json` carries one description of `invalidToday`.
- `release-check.sh` §5 reads all three Kotlin source sets.
- The comment-language gate reads the declarative build and configuration files,
  reaching every class `tools/check-headers.py` owns except `.md`, `.xml` and
  `.in`.
- `StatsWindows` derives the statistics period, its baseline and the
  statistics-start floor on both platforms, pinned by `stats-window.json`.
- `StatsPeriod` sits in the Kotlin domain package.
- Both reports cut the weekday label to two UTF-16 code units through
  `abbreviateWeekday`.
- The report's KPI labels read Ø and Md and fit their tile on one line in every
  language.
- `tools/check-report-labels.py` measures each KPI label against the tile width
  the template defines.
- Both screenshot runs seed their settings from `fastlane/screenshot-fixture.json`,
  a format-3 export of the demo data.
- `tools/check-fixture-parity.py` holds the two demo fixtures to one set of drinks
  and entries.
- The report's weekday columns follow the report's locale on both platforms.
- The report's day counts carry each language's own plural form.
- `PluralDaysInstrumentedTest` holds Android's plural resolution to
  `plural-days.json`.
- `tools/check-report-pdfs.py` holds every committed sample report to two pages.
- The Gradle and Makefile references name the screenshot fixture.
- The report's monthly table shows the six most recent months and folds anything
  older into one summary row.
- Both platforms read a logical date only in its canonical spelling, for a day
  that exists.
- `check-l10n.py` holds every key of both String Catalogs to every language they
  ship.
- CONTRIBUTING.md §6.2 carries the store-metadata conventions.
- The fastlane and make files point at CONTRIBUTING.md §7 for the release path.
- CONTRIBUTING.md §7 names the three places that carry the version string.
- Merging a backup on iOS leaves the local settings alone, as on Android.
- A fresh Android install starts at 80 g per week over four drink days, every
  first-run default reading from `AppSettings`.
- The `SettingsSanitizer` ranges' visibility note names the four the settings
  screen reads.
- The vector mirrors in `TestVectors.swift` each carry their own file's
  description.

### Fixed

- Acknowledging the Today screen's error alert on iOS.
- A Chinese language choice surviving an iOS → Android restore.
- The reason on a failed export.
- The iOS CSV export escaping a field that begins with a Windows line ending, and
  doubling a quote that carries a combining mark.
- `ReportFormatting`'s fallback formatting the settled decimal.
- The App Store screenshot of the log-a-drink sheet showing that sheet.
- The iOS report export handing out a document whose last sheet is missing.
- `md-syntax.py` reading indented code blocks, link labels and wrapped code
  spans as prose.

### Removed

- Codeberg as a canonical remote; the GitHub mirror stays.
- The store badge artwork, the DejaVu Sans and Rokkitt faces, the `fdroid/` recipe
  copy and the unreferenced `Bitstream-Vera` and `CC-BY-SA-3.0` texts.
- `View.localizedText(_:)` and its modifier from `ios/Potillus/Localization.swift`.
- Both `fastlane` and the RELEASE-IOS READMEs.

---

## v0.83.0

Fix iOS presets, cold-start lock and freezes

This opens the 0.83.0 cycle with the version bump — `versionCode` 93 → 94, the
human version 0.82.0 → 0.83.0 — to take the iOS app to the public App Store
listing via the `ios testing` lane. The export-compliance declaration
(`ITSAppUsesNonExemptEncryption` = NO in `ios/project.yml`) was already in place.
The iOS app icon is enlarged and regenerated at 1024×1024 from the vector master
at `ios/icon/appicon.svg`, so its glass matches the on-device Android appearance.
The cycle folds in three review rounds, the first to treat Android, iOS and the
seam between them as one subject.

### iOS: the App Store publication path

`make push-appstore` guards the upload the way `push-playstore` guards the Play
one: the staged artifact must exist, and the release tag `vX.Y.Z` must exist
locally and on the push remote. Where the platforms differ it checks what an iOS
signature actually is — the `.ipa`'s own `Info.plist` must agree with the tree on
`CFBundleIdentifier`, `CFBundleVersion` and `CFBundleShortVersionString`, and the
signature must verify and carry our `TeamIdentifier`. A certificate-digest pin is
deliberately not used: Apple rotates that certificate yearly and mints it at
export time under automatic signing.

`SUBMIT=1` switches from the `ios testing` lane to `ios production`, adding the
review submission; the default does not submit. A new `preflight` lane behind
`make push-appstore-preflight` authenticates and makes one read-only
`app_store_build_number` query, so a bad key fails before anything is uploaded.
It is a lane rather than a `fastlane run` one-off because the iOS credential is a
hash and fastlane's CLI takes only primitive types.

The pre-flight is a prerequisite of `push-appstore`, not a `$(MAKE)` call inside
its recipe: under `.ONESHELL` a recipe containing `$(MAKE)` runs even under `-n`,
so `make -n push-appstore` would have published.

`docs/RELEASE-IOS.md` names the target, its guards, the `SUBMIT=1` switch and
what App Store Connect still curates by hand, and says that `ios testing`
overwrites the live listing. `release-ios` prints the App Store destination
beside the TestFlight one.

### iOS: the screens reach parity with Android

A pass over every screen, so someone who switches platforms finds the same
layout, labels and colours. Today gains the headline pair — today's total and the
monthly average with its trend arrow — above thicker limit bars, and its entries
header and empty state match Android's wording. The Drinks rows show the
grams-per-serving Android shows.

Statistics is rebuilt into Android's two-card structure, key metrics then
abstinence and trend, with the dry-day check-marks on the consumption chart. The
chart leads the screen, under the period picker, and draws the dashed
daily-limit line Android has always drawn, reddening the bars above it through
`AlcoholCalculator.isOverLimit` rather than a bare `>`; it is suppressed in the
year view, where the buckets are monthly averages. The categories are a donut
with Android's two-column legend, coloured from `ReportPalette.color(forCategory:)`
— the function the PDF report and `test-vectors/report-chart.json` already share.

The calendar day view gains the daily-limit bar, richer entry rows (time · ml ·
% · g · note), an edit pencil and a red delete, and a tap on the selected day no
longer deselects it. It can also log a drink onto the day you picked:
`EntryLogger.makeEntry` takes an optional `logicalDate`, so the timestamp stays
the moment of typing while the day is the one being recorded, and `CalendarModel`
gained `addEntry` plus the observed drink catalogue its sheet needs. The sheet
omits the capacity dot, because every figure behind it is about today.

Today's rows become the calendar's rows, so today's mistyped entry can finally be
edited; the swipe stays beside the buttons. The Categories card is unconditional,
because an empty ring says "you drank nothing" where a missing section says the
feature does not exist. Settings adopts Android's section order — Personal ·
Limits · Statistics · Backup · Security · Appearance — folds the day-change time
into Statistics, and makes the statistics-start date editable again.

Across these screens the iOS labels use Android's exact wording, so the two
platforms share translations, and a new advisory `make check-ui-string-parity`
reports labels that drift. Two bugs found on the way: the traffic-light green dot
rendered in the accent blue, and the German and other empty-state translations
were dropped because the catalogue key held an escaped rather than a real
newline. Platform-idiomatic differences stay — the overflow menu and add button
keep their iOS positions, and the app-lock hint keeps its Face ID / Touch ID
wording.

### iOS: correctness fixes

The app lock engages on a cold start. `StartupState.make(arming:)` loads the
settings before returning `.ready` and completes
`AppLockModel.armAndLaunch(enabled:reason:)`, which takes the stored setting as a
parameter, strictly before any content view exists; while the prompt is up the
cover overlays a progress spinner.

The screens follow the clock. Today, Statistics and Calendar run a 60-second
ticker as Android has since its own rounds — unconditional on Today, where the
BAC estimate needs every minute, day-keyed on the other two — and reload when the
scene turns active, because `onAppear` does not fire on foregrounding. The
interval is injectable, and a test rolls the day over by advancing the clock
alone.

A fresh install fills the drink catalogue. `AppDatabase.openOrCreate` probes for
the database file before opening it and, when it is absent, inserts the same
fifteen presets Android's `PRESET_DRINKS` carries. The seed stays out of the GRDB
migrator, which every test and the screenshot run share, and an emptied catalogue
on an existing database is left alone — that state is a user's choice.

A fresh install no longer counts the days before it existed as abstinent. A
brand-new installation seeds the statistics floor with the install date, written
down rather than recomputed, triggered by the absence of the preferences file
rather than by an empty floor — empty is what `SettingsModel.clearStatsFromDate()`
writes to mean "cover my whole history". Only `makeDefault()` seeds, so tests,
previews and screenshot runs keep their pristine defaults; Android's three-state
DataStore logic is unchanged.

A restored iPhone no longer hides its own history. `PreferencesStore.load()`
probes `fileExists` before reading, so an unreadable file — the state a device
restore produces, the key being `ThisDeviceOnly` — no longer looks like a
never-asked user and no longer floors the whole restored history at the restore
date. An unreadable file is not rewritten.

Backup and import failures speak the app's language: `describeBackupFailure`
mirrors Android's `import_error_*` strings, four actionable failures getting
their own sentence and everything structural folding into "Read error: %@" with
the typed detail. The in-app guide and licence render as paragraphs — consecutive
non-blank lines join, a list item keeps its wrapped continuation lines. A new
`InfoPlist.xcstrings` carries `NSFaceIDUsageDescription` in every app language,
the `project.yml` value staying as the documented English fallback.

The report's `WKWebView` disables content JavaScript explicitly: WebKit's default
is on, unlike the Android WebView default the report relies on there.
`KeychainKeyProvider` tolerates the first-launch creation race — on
`errSecDuplicateItem` it reads the winning key back instead of failing the
launch.

### Both platforms: the About screen

The screen is rebuilt into two chapters with the same wording on both platforms:
"Licence", holding the GPL notice every source file carries as prose, and
"Open-source components", listing only what the package redistributes. Each
verbatim text is one tap away in its own window. Android links to the GPL-3.0,
the Apache-2.0 and the new `LICENSE.GPL-2.0.md` for `desugar_jdk_libs`, whose
OpenJDK Classpath Exception is stated on the screen because it is not part of the
GPL-2.0 text; iOS links to the GPL-3.0 and keeps GRDB's MIT text inline.

The App Store Distribution Exception now stands on the screen in full. The file
headers end with a pointer to COPYING.md, which worked only while the app bundled
that document; it no longer does, so the exception is stated where it is read.

Each app bundles only the licences it owes. The combined `copyright.md` and its
iOS twin are gone — both were built from COPYING.md, so the APK carried GRDB's
MIT notice for a library it does not ship and the iOS app the Apache text for
libraries it does not have. `render-copyright.py` keeps its concatenation ability
while the build passes it one input per output; COPYING.md stays the exhaustive
inventory and travels with the source.

The whole screen is English. A translated licence is not the licence, and the
screen had been half-and-half; the overflow-menu entry stays localised, because
that label is navigation. `AboutScreen.swift` joins `check-l10n`'s
`UNLOCALISED_VIEWS`, five orphaned catalogue keys and Android's `copyright`
string are gone, and Android's `DocumentViewerScreen` takes `title: String`, the
signature iOS already had.

The tree spells it "license" throughout, the American form the GPL, the Apache
licence and every bundled text use themselves; `LICENSE_OUTPUTS`,
`generateLicenseDocuments` and `Screen.LicenseGpl3` follow. This changelog and
`tools/fonts/Inter/README.txt` keep the British form: one is a record of what was
written when, the other is someone else's document.

### Both platforms: cards, spacing and the overflow menu

`SectionCard` is one shared component in `ui/component/Components.kt`, replacing
the neutral grouping card three screens had written out by hand. Nine cards in
StatsScreen and CalendarScreen that had taken Material 3's default container
colour are `SectionCard` now and inherit `surface` by construction;
TodayScreen's daily summary and CalendarScreen's selected-day panels keep
`primaryContainer` deliberately.

Android's licence cards space their children by 8dp, so a paragraph break is
wider than a line break. On iOS the four paragraphs of the GPL notice are one
row with an explicit `VStack(spacing: 10)` rather than four List rows separated
by rules, and they render at `.callout` rather than `.footnote`. GRDB's MIT text
joins them and loses its `.secondary` grey — that text is a permission notice the
licence obliges us to put in front of a reader.

The overflow menu reads Settings, Help, "Lock app", About on both platforms, with
About last. Help and About share their glyphs across platforms, a question mark
and an "i" in a circle; Android had been drawing a medical cross for Help, which
in an app about drinking reads as medical help. The fill stays
platform-specific, and Android uses `Icons.AutoMirrored.Filled.Help`, the
non-deprecated form. The menu callback is `onOpenAbout`.

### Both platforms: import and language

A REPLACE import truly replaces the drink catalogue. It wipes the whole
catalogue, presets included, before re-inserting the backup, so a drink is
present if and only if the backup defines it; the log is cleared first, so the
entries-to-drinks foreign key cannot trip. Android gained
`DrinkDao.deleteAllDrinks` and iOS dropped the `isPreset == false` filter, both
keeping the narrower helper for callers that clear only the user's own drinks.

Both pickers offer "(System)" as the first language entry, mapping to the empty
tag the data model has always treated as "follow the device". Android calls
`setApplicationLocales` with an empty list; on iOS `Loc.locale(for:)` already
resolved the empty string to `.current`.

### Build system

`clean` and `distclean` become `clean-android`, `distclean-android`, `clean-ios`
and `distclean-ios`, following the `-android`/`-ios` convention the rest of the
file uses. There is no plain `clean`/`distclean`: both had delegated to
`android/` alone, so every iOS artifact survived them. `clean` is build output,
`distclean` additionally the generated sources a build needs before it can start;
none of the four touches `releases/`, whose contents are staged artifacts.

A fresh clone builds, and a source tarball survives a second run.
`render-guide-ios.py --check` and Android's `render-guide.py` tell a missing
guide from a stale one, absent being the normal state of a fresh clone. Outside
a git checkout `check-headers.py` walks the tree, so `SKIP_DIRS` gained `raw` and
`Resources`, both holding build products exclusively — without them the tool
failed in a built tarball and `make fix-headers` would have written this
project's section 7 pointer into the verbatim GPLv3 text.

`tools/render-copyright.py` is gone. With one input per output its remaining job
was creating the output directory, which is the load-bearing part: git cannot
track an empty directory, so `res/raw/` and `ios/Potillus/Resources/` do not
exist after a clone and a bare `cp` fails. The Makefile rules are `mkdir -p` plus
`cp`, and Gradle's three `Exec` tasks are `Copy` tasks.

Store screenshots and report PDFs are never auto-captured. They have hard-fail
sentinels that name the capture command, replacing a missing screenshot's
silent triggering of a full capture mid-build; the derived feature graphics and
rasterised report pages stay dependency-driven but fail cleanly. `make android`,
`make ios`, `make release-android` and `make release-ios` gate up front on the
full per-locale set.

### Gates

`tools/check-ios-a11y.py` is the counterpart of `release-check.sh` §13: brace-
aware, it isolates each `Button` with its argument list, closures and trailing
modifier chain and reports one whose label is an `Image` with no `Text`, `Label`
or `.accessibilityLabel`. All eleven icon-only buttons were already labelled.
Decorative images outside a `Button` are deliberately not checked.

`tools/check-ios-metadata.py` is the counterpart of §10: App Store Connect's
store-listing limits, locale file-set parity, and non-empty name and description.
`release-check.sh` §7 scans the three Gradle build scripts, the Swift sources and
the 5,700 lines of Python and shell under `tools/`, which the English-everywhere
convention had always covered.

`test-vectors/app-lock.json` is loaded by both suites. The arithmetic moves from
`MainActivity` into `domain/AppLock.kt`, testable on the JVM and comparing `>=`
as the vectors pin, so a background gap of exactly 30 seconds prompts on Android
too — a one-millisecond behavioural change. The vector's `_comment` no longer
claims identical arithmetic conditionally nor names the retired `systemUptime`
clock.

`.gitignore` carries `ios/Version.xcconfig` and `ios/Potillus.xcodeproj`, the two
entries the documentation already promised.

### Supply chain

The iOS build produces a CycloneDX 1.6 SBOM. Swift Package Manager has no
first-party generator and the third-party ones would each add a build-time
toolchain, so `tools/gen-ios-sbom.py` emits the format directly from
`Package.resolved`, with the application as metadata component and GRDB as a
library component carrying a `pkg:swift` purl, its commit and its MIT licence. It
runs through the same `tools/sbom-normalize.py`, so the file is byte-reproducible;
`make release-ios` stages it as `<id>_<code>_ios_sbom.json` and the Android one
is renamed to `_android_sbom.json`, and `push-codeberg` attaches it.

`androidx.compose.ui:ui-tooling` joins COPYING.md's build- and test-time list,
and the iOS tools — XcodeGen, SwiftLint and fastlane, all MIT — gain their own
subsection, with the note that `tools.fastlane:screengrab` is a different,
Apache-2.0 artifact. Checked against the actual `releaseRuntimeClasspath`, all
156 shipped artifacts fall into a copyright-holder family COPYING.md already
names.

### The repository's statements about itself

`SettingsModel`'s header no longer promises two settings the screen does not
show; the rule it was built on is stated as met, which is why `SettingsScreen`
shows the app-lock switch only where `BiometricAuthenticator.canEvaluate()` is
true. COPYING.md describes the sample report PDFs as they measure: the seventeen
Latin-, Greek- and Cyrillic-script files embed only Roboto, the four CJK files
only Noto Sans CJK. `test-vectors/README.md` inventories all twelve vector files,
and COPYING.md no longer claims both apps reproduce the GRDB licence in their
about screen — only iOS ships GRDB.

The best-practices answers describe a two-platform project: `copyright_per_file`
and `license_per_file` name Swift, `OSPS-QA-06.02` the Swift suites,
`OSPS-BR-05.01` and `OSPS-QA-02.01` `Package.resolved`, and `OSPS-DO-07.01` no
longer calls the project a standard Android Gradle project. Every criterion was
and stays Met. `OSPS-LE-03.02` cites the bundled verbatim licences and the About
screen, and the internationalization answer counts the 21 languages the app
ships.

CONTRIBUTING.md no longer says the `Makefile` is not needed for iOS work.
`docs/INSTALL-IOS.md` calls `gmake ios-version-check` suitable for a release gate
rather than the release gate, says where it earns its keep, and derives the
version from `CHANGELOG.md` and the Android `versionCode` rather than a `VERSION`
file that never existed. `ios/.swiftlint.yml` no longer cites two scripts absent
from the tree and no longer contradicts the report-label catalogue's
hand-maintained header.

`Fastfile`'s head comment names the seven lanes across two platforms and the
property they share, that no lane builds anything; `Appfile`'s says that it
carries the iOS `app_identifier` as well as the Play values. `upload_appstore`'s
options carry comments stating what `force` and `precheck_include_in_app_purchases`
actually do, in place of a claim about age rating and pricing that described no
code.

`MarkdownText`'s thematic-break branch is justified by the guides under
`docs/guide/*.md.in` being hand-written Markdown whose author may reach for a
`---`. `check-ui-string-parity` skips `AboutScreen.swift`, which is fixed English
by design, mirroring `check-l10n.py`'s `UNLOCALISED_VIEWS`.

### Store metadata

The English Android and iOS release notes for this version are translated into
the 20 further store languages each store lists. Terminology is taken from the
in-app strings, so a store note never names a screen differently from the app
itself, and quotation-mark style follows each locale's existing listing. The two
stores' notes need not match, and do not.

### Badge answers

`crypto_algorithm_agility` and `bus_factor` state why they are not met and what
mitigates it, in place of deferred promises: for the cipher, that the sole sealed
artifact is the preferences blob, that Android's key is generated inside the
Keystore and a second algorithm would risk moving it out, and that the
cross-platform blob framing makes the change risky for no gain; for the bus
factor, that a single-maintainer project is forkable Free Software, that F-Droid
re-signs from source, and that governance and the contribution process are
documented. Both stay `Unmet`, and the roadmap matches.

`make bestpractices-jsonc` writes `.bestpractices.jsonc`, a generated view in
which every criterion is preceded by a comment naming its level, from the
committed map `tools/bestpractices-levels.json`; `.json` stays canonical. The
download target mirrors the full upstream criteria set through
`tools/filter-bestpractices.py`, so retired criteria are dropped.
`check-bestpractices-levels.py` fails on an unmapped criterion and
`release-check.sh` §15 while any criterion is unanswered.

---

## v0.82.0

Add the native Swift/SwiftUI iOS port

This release makes Libellus Potionis multi-platform. A native Swift/SwiftUI port
lives in the same repository under `ios/`, feature-complete for daily use and
pinned to the Android app's behaviour by a shared set of golden test vectors. The
two apps share one human-readable version and the JSON backup interchange format
— not a live sync and not a common binary.

### The iOS port

The health-relevant domain logic — `AlcoholCalculator`, `DayResolver`,
`ChartBucketing` and `Trend` — is re-implemented in Swift rather than shipped as
a Kotlin Multiplatform binary, and a language-neutral golden-vector suite in
`test-vectors/`, loaded by both the JVM and Swift test targets, keeps the two
from drifting. The tricky cases are covered: `isOverLimit`'s floating-point
tolerance, and the timezone- and DST-safe calendar arithmetic behind the logical
day, the rolling seven-day window and the chart buckets.

The data layer is GRDB, the counterpart to Android's Room: the SQLite schema, the
record types, repositories behind protocol seams, the JSON backup (v3)
reader/writer, the CSV export and an encrypted preferences store. The database
files are not interchangeable between platforms — the supported bridge is the
JSON backup, and the suite proves it by parsing and importing a real
Android-written backup of 15 drinks and 85 entries with no orphaned rows.

Today, Calendar, Statistics, Drinks, Add-drink, Settings and the document viewer
are built to feature parity in SwiftUI, reactive to database changes, with a
startup-failure path, an app lock via `LocalAuthentication` with an app-switcher
privacy cover, and the two-page PDF report rendered by WebKit from the same HTML
template Android uses. Every screen, the report labels, the CSV headers and the
plurals are localised across the twenty UI languages as String Catalogs with
English as the source, verified against Android's resources by
`tools/check-l10n-parity.py`.

The build derives `MARKETING_VERSION` from this changelog's top entry and its
build number from Android's `versionCode`, so the two stores' counters stay in
step. `make release-ios` archives without code signing and signs only at the
App-Store export, via automatic cloud signing that mints the distribution
certificate and profile without a registered device, then stages the `.ipa` into
`releases/` under the same `<applicationId>_<versionCode>` name as the Android
AAB, with the same guard against overwriting a staged release. The Team ID
resolves like the Android keystore: `DEVELOPMENT_TEAM` wins, else a git-ignored
`ios/signing.properties`, with a committed
`ios/signing.properties.example` template. A new `ios alpha` lane uploads the staged `.ipa` to
TestFlight, and the `ios testing` and `production` lanes take it as `ipa:`,
mirroring the Android `aab:` option; `docs/RELEASE-IOS.md` documents the flow.
`make screenshots-ios` captures the store screenshots non-interactively, pinning
the simulator clock and rasterizing the rendered report pages.

Apple's store terms are reconciled with the GPL by an additional permission under
GPL section 7 — an App-Store distribution exception adapted from the Feeel
project — carried in every file header and stated in `COPYING.md`; GPLv3-or-later
and full copyleft remain intact. The port's only third-party dependency is
GRDB.swift (MIT, no transitive dependencies, no network). The repository's static
checks run without a Mac; compiling Swift is the one step that needs one.

### iOS: untrusted input

The backup reader enforces the same bounds as Android's guards — `volumeMl` in
1…10 000, `alcoholPercent` a finite 0…100, `gramsAlcohol` a finite non-negative,
`timestampMillis` positive, and a `logicalDate` that survives a parse-and-format
round trip — throwing a typed `valueOutOfRange` the UI can localise. The GRDB
schema constrains only nullability, so an out-of-range value would otherwise have
entered the database and corrupted every figure that touched it.

`BackupReader.readData` caps the file at 10 MiB with a fast advertised-size check
plus a bounded read for a misreported size, as Android does, and `parse` keeps a
backstop for callers that hand over bytes directly.

### iOS: localization

The CSV export captions live in `CsvHeaderLabels`, copied verbatim from Android's
`csv_col_*` strings for all twenty languages and resolved from the in-app
language as the PDF report already was. They sit in a keyed table with a flat
lookup rather than a twenty-one-branch `switch`, and `check-l10n-parity`
CHECK 5 enforces column-by-column identity with Android.

Twenty hardcoded English strings across the screens are localized: eight alert
and dialog titles, the drink-row VoiceOver hint, the calendar day-cell VoiceOver
label, three export error messages and a set of `Toggle` and `DatePicker` labels.
`check-l10n` had scanned line by line, so it was blind to any literal whose call
spanned two lines and never looked at alert titles or accessibility strings; it
now scans whole files and covers both. The calendar month chevrons carry
localized "Previous month" and "Next month" labels from Android's
`cd_prev_month` and `cd_next_month`.

On-screen numbers follow the in-app language. Grams, the BAC estimate,
percentages and the body weight had been formatted with POSIX `String(format:)`,
so a German user saw "20.0 g" instead of "20,0 g"; a new
`Loc.number(_:fractionDigits:locale:signed:)` formats every on-screen figure in
the chosen locale. Exports are untouched: CSV and the PDF report keep their fixed
POSIX format by design.

The merge-import plural pluralises on the imported count through an explicit
substitution, matching Android's `import_success_merge`, with the skipped count
rendered as a plain number. Twelve new iOS strings are translated into every
language, best-effort and awaiting native review, as CONTRIBUTING §6 describes.

### iOS: the app lock

The App-lock switch requires Face ID, Touch ID or the passcode both to turn the
lock on and to turn it off, and a cancelled prompt leaves the setting where it
was, matching Android's `authenticateForToggle`. The 30-second re-auth window is
measured with `ContinuousClock`, which keeps counting while the device sleeps,
rather than `ProcessInfo.systemUptime`, which stops.

Manual "Lock app" no longer requires auto-lock to be on: the entry appears, and
locks, whenever a biometric or device passcode is available, and the unlock path
no longer depends on the auto-lock setting, so a manual lock can always be
cleared. The unlock prompt is localized from the language setting, reusing the
"Please authenticate" string Android shows for every biometric prompt.

### iOS: parity with the Android screens

Every screen carries the shared `AppOverflowMenu` — Settings, Copyright, and
while the lock is enabled "Lock app" — where iOS had only a lone gear on Today,
leaving Settings unreachable from three screens. The Help entry opens an in-app
user guide: `ios/docs/guide/usersguide.md.in` is adapted from Android's in the
few spots that differ, and `tools/render-guide-ios.py` resolves the `{{token}}`
labels against the String Catalogue so the guide names the labels the app shows,
writing a gitignored `usersguide_<tag>.md` per language. All twenty translations
are adapted from Android's guides with the four platform-specific passages
rewritten.

The drinks row drops the padlock iOS drew beside preset drinks, which read as
"locked" rather than "built-in", and gains a red trash button beside the edit
pencil; button and swipe open the same confirmation dialog, as on Android.

The capacity traffic-light dots are drawn. `AlcoholCalculator.trafficLight` and
its vectors were already there but no view used them, so the colour-blind status
symbols toggle did nothing. A `DrinkCapacityModel` publishes the day's budget
snapshot; the dot appears in the drinks list and beside the grams preview in the
log sheet on Drinks and Today, reuses the limit bars' colours, adds the
colour-blind glyphs when the toggle is on, and carries a localised VoiceOver
label.

The Today card shows the month's per-day average with an up/down arrow against
the pre-month baseline and a date range on the seven-day figure. `TodayModel`
computes `monthlyAvgPerDay` and `monthTrend` in the kit, a faithful port of
`TodayViewModel` including the `statsFromDate` floor that clips a mid-month
start; the two locale-dependent labels stay in the view, so the kit holds no
`DateFormatter` locale choice. The `g/day` unit and the `Ø %@` caption reuse
Android's `grams_per_day` and `avg_of_month` translations in every language.

### Android: Play publishing

`push-playstore` runs a pre-flight auth check before uploading. It calls
fastlane's `validate_play_store_json_key` and requires its success line, because
that action logs success but does not raise on failure, so a service account not
yet invited to the Play Console fails immediately with an actionable message.

The store-metadata length check in `tools/release-check.sh` §10 counts the
trailing newline the way Google counts it, enforces the `title.txt` limit of 30,
and runs under an `if` guard so a genuine catch reports instead of aborting the
gate under `set -e`. The enforced limits are Google Play's documented ones: title
30, short description 80, full description 4000, release notes 500. The fixed
check caught a latent fr-FR short-description overflow, trimmed by its one
trailing newline with no change to the visible text.

The two publishing recipes keep their rationale in non-recipe header comments,
which make never echoes, leaving short per-step markers in the recipe. The
executed commands are unchanged.

### Gates and build

`make check-ios-static` groups the Mac-free iOS gates — Swift symbols and tests,
headers, l10n, l10n parity, report paper — so a Linux CI can run them beside
`release-check.sh`, which is the Android gate and knows nothing about Swift.
`make ios` reuses it for its own static phase and gains `check-ios-guides`.

`tools/check-swift-length.py` reproduces SwiftLint's length rules in Python —
`type_body_length` 250, `file_length` 500, `line_length` 120 — reading the limits
and roots from `ios/.swiftlint.yml` so the two cannot drift. It is an early
warning beside the Mac's authoritative `--strict` pass, calibrated to agree with
SwiftLint on the whole committed tree, and the non-length rules stay SwiftLint's
alone.

`check-l10n`'s neutral-unit list gained the permille sign, which is as
language-neutral as `%`.

### Documentation

`ios/README.md` is folded into the root `README.md`, and the build walkthrough
then moved on into `docs/INSTALL-IOS.md` — the `ios/` source layout, the
smoke-test bundle, the `Version.xcconfig` confirmation and its "never set it in
`project.yml`" rule, and the GRDB note. The README links both install guides in a
short paragraph and no longer names concrete dependency versions, so it does not
drift on every bump; the Gradle build files stay the single source of truth.

`INSTALL-ANDROID.md`, `INSTALL-IOS.md` and `CODE_OF_CONDUCT.md` move under
`docs/`. Every pointer follows, including `tools/check-headers.py`, whose
licence-header exclusion is matched on the repository-relative path and would
otherwise have demanded a GPL header on the CC-BY-licensed Code of Conduct.
Historical changelog entries keep the old paths as written.

`docs/ASSURANCE_CASE.md` covers the iOS port: every claim resting on a platform
facility names both mechanisms side by side — the Keychain
(`WhenUnlockedThisDeviceOnly`) with CryptoKit beside the Android Keystore,
database backup exclusion beside `allowBackup="false"`, GRDB's parameterized
queries and migrations beside Room's, Swift/ARC beside Kotlin/ART. The screen
boundary is stated honestly: iOS has no `FLAG_SECURE` equivalent, so active
screen capture is an explicit iOS residual risk and the app-switcher cover
addresses only the passive preview. Claims were checked against the iOS sources.

`docs/ROADMAP.md` records the deferred iOS parity items: the calendar year view
was already tracked, and an iOS/VoiceOver counterpart to
`docs/WCAG_LEVEL_A_CHECKLIST.md` is added as future work, noting that the port
labels its controls but has no recorded structured pass and that the
Compose-specific Level-AA gaps do not transfer.

### The iOS app icon

An `AppIcon` asset catalog at `ios/Potillus/Assets.xcassets` carries a single
1024×1024 marketing icon, and `project.yml` names it via
`ASSETCATALOG_COMPILER_APPICON_NAME` so actool writes `CFBundleIconName` and
emits the icon — without which App Store upload validation rejects the build
(90713/90022). The artwork is the Android launcher's white glass-and-straw on
`#1A1E2B`, vectorised to an opaque 1024×1024; the vector master is kept at
`ios/icon/appicon.svg`.

---

## v0.81.0

Add accessible capacity symbols and chart labels

This release improves accessibility for colour-vision deficiency and for
screen-reader users, addressing the roadmap's Level-A chart gap and the "Use of
Color" concern on the traffic-light indicator. It folds in several review rounds,
including user-visible corrections: the statistics trend baseline, the Today
card's monthly average and the PDF report's abstinence figures honour the
"Statistics From" date and the chosen export range, and the date picker for that
setting no longer blocks the local today east of UTC.

### Accessibility

A switch under Settings → Appearance makes the traffic-light capacity dot draw a
glyph inside its coloured circle in addition to the colour: a cross when the
limit is reached, a "1" when one serving remains, an up-arrow when there is room
for more. The shape cue on top of hue lets the three states be told apart without
the red/yellow/green colours alone (WCAG 1.4.1). It is off by default; the flag
is `alternativeStatusSymbols` in `AppSettings`, threaded through `TodayScreen`,
`DrinksScreen` and the log dialog into `TrafficLightDot`.

`TrafficLightDot` carries a localized `contentDescription` announcing the
capacity state regardless of the symbol setting, under `clearAndSetSemantics` so
it reads as a single node rather than leaking a raw glyph.

The three statistics charts — `AlcoholBarChart`, `ValueBarChart` and
`CategoryDonutChart` — are drawn on a bare `Canvas` and were invisible to a
screen reader; each now exposes a summarising `contentDescription` (WCAG 1.1.1).
The generic `ValueBarChart` takes an optional caller-supplied label, which
`StatsScreen` fills from the existing section headings.

The calendar month-grid and year heat-map day cells are plain `clickable` `Box`es
and now declare `role = Role.Button` (WCAG 4.1.2). The month cells gain a "date,
grams, status" `contentDescription`, reusing the year heat-map's caption strings,
which exposes the over/under-limit state previously carried only by colour.

`docs/WCAG_LEVEL_A_CHECKLIST.md` is a manual WCAG 2.2 Level A self-assessment
protocol tailored to the app: per-criterion pass/fail, a per-screen TalkBack
walkthrough and a sign-off template.

Eight new string keys — three capacity states, the toggle title and summary,
three chart descriptions — are added to all 21 locale files.

### Drink validation and the drink-days bar

`DrinksViewModel` and `AddEditDrinkDialog` both consult `DrinkValidator`, which
fixes the serving size at 1…5000 ml, the alcohol content at a finite 0…100 %, and
the name at 1…100 characters measured after trimming. The two had disagreed: the
dialog capped the serving size at 5000 where the ViewModel accepted 10 000, and
it never checked the name length, so an over-long name left Save enabled and the
write was silently dropped. A too-long name now marks the field in error and
disables Save. `updateDrink` is validated as well.

The drink-days bar and the traffic light share one predicate,
`AlcoholCalculator.drinkDayLimitReached`. A spent drink day stays spent for the
whole day: at 5 / 5 with today already a drink day the bar is amber, because
another drink adds no further day; at 5 / 5 with today still dry it is red,
because the first drink would spend a day that is no longer available. The gram
bars are unaffected and stay red at 100 %.

### Statistics honour the statistics-start date

The trend arrow's previous-period baseline is clipped to the same floor as the
current period, and a window entirely before the floor yields no baseline, so the
trend reads FLAT as in the no-history case. The baseline had summed entries the
setting promises are ignored in all statistics.

The Today card's month anchor is clamped to the floor, so sum, filter and divisor
cover the identical span; a start date inside the running month had been ignored
there while the Statistics month view clipped correctly.

The PDF report's abstinence streaks anchor at the period end for a historical
range and keep the real-today anchor when the range ends today. A report over a
past range had counted every day from the last in-range drink until now as
abstinent, including days on which the user did drink.
`StatsViewModel.exportPdf` threads the chosen range end through
`PdfReportBuilder.buildHtml` into `PdfReportData.from`.

The "Statistics From" date picker derives its upper bound from the local calendar
day through `DayResolver.clock()` rather than the UTC day, which had made the
user's local today unselectable east of UTC and the local tomorrow briefly
selectable west of it.

### Backup

The new appearance preference travels in JSON backups within format 3 as an
optional field, so no format bump is needed: an older format-3 backup restores
with the setting off, a REPLACE restore applies it and a MERGE keeps the local
value, as the other settings behave.

A restored `language` value is matched case-insensitively against
`SupportedLocales` and canonicalised; an unknown tag degrades to the
follow-system sentinel instead of being applied verbatim from a hand-edited file.

### Store screenshots

`make screenshots` overrides the capture device's display to 1428×2856 at 640 dpi
— an exact 2:1 at about 357 dp usable width — so Google Play's max-2:1 rule is
met by construction and the shots show the full, uncropped app. The former
`screenshots-crop` step and `tools/crop-screenshots.py` are removed with it, and
any device geometry is acceptable. The sticky `wm size` and `wm density`
overrides are reset in `screenshots-demo-off`, so the EXIT trap restores the
device after a Ctrl-C or a failed capture, and the `require-pillow` pre-flight is
reinstated for `feature-graphics`.

`ScreenshotTest` routes every capture through one helper enforcing a two-stage
readiness contract: the screen must expose a positive, data-derived marker that
cannot exist in the seed state — the month name in the Today caption, the
Calendar's day-detail label, the fixture's period total, a drink row's edit icon
— and that marker must then be visible in the device's accessibility tree with
the device idle. Waiting on static elements had captured the all-empty
`stateIn` seed, and whether a run caught it was timing luck that differed per
locale, because the capture language switch recreates the Activity only in
locales other than the device language. Every expected string resolves through
the same sources production uses, so the markers cannot drift from the rendered
UI in any of the 21 languages. The committed PNGs are the post-fix captures.

### Layout in verbose languages

`DrinkDaysBar`, `LimitBar` and the Today card's caption and headline rows follow
the rule `StatRow` has used since v0.78.0: weight the flexible text, pin the
fixed one to one unbroken line. Both texts had been measured at their intrinsic
width, so a long localized label claimed the whole row and the week range wrapped
mid-token into a ragged second line. In the affected languages the left label now
wraps instead of displacing the range, so those rows are one line taller and no
text is truncated.

The same trap was closed at three further sites found by sweeping every
two-child `Row`: the six Settings rows that put a label ahead of a fixed-size
edit button, and the calendar's month header between two icon buttons, now
weighted, centred and ellipsized.

### Publishing

Two fastlane lanes upload the signed AAB with the full store metadata:
`testing` targets the closed-testing alpha track and `production` the production
track staged as a draft, both sharing a `private_lane :upload_release` helper,
neither building the bundle. The root Makefile gains `push-playstore` and
`push-codeberg`, the latter creating a Codeberg release for the already-pushed
tag over the REST API and attaching the APK and SBOM. Both read their secrets
from git-ignored files.

Both targets prove the signature and pin the signer before doing anything:
`push-playstore` runs `jarsigner -verify` and reads its "jar verified." verdict,
because the exit code alone passes an unsigned archive, then `keytool
-printcert`; `push-codeberg` requires the signed `app-release.apk` name and runs
`apksigner verify --print-certs`. Both compare the certificate SHA-256 against
the fingerprint in SECURITY.md, lowercase-normalized on both sides, with
`release-check.sh` §14 failing on a non-lowercase pin. For the AAB this matters
because signed and unsigned outputs share the name `app-release.aab`.

Both require the release tag `vX.Y.Z` locally and on the push remote, failing
with a named-tag message. `push-playstore` gains `VALIDATE_ONLY=1`, threading
fastlane supply's `validate_only` through both lanes so an upload can be
validated against the Play API without changing anything. `push-codeberg` is
safe to re-run after a partial failure — it reuses an existing release for the
tag and skips already-attached assets — keeps the access token out of
`/proc/<pid>/cmdline` by passing a mode-0600 temp header file removed by an EXIT
trap, and re-downloads each published asset to compare its sha256 with the
staged file.

`make release` stages the signed AAB, APK and SBOM into a git-ignored
`releases/` under canonical names — `de.godisch.potillus_<versionCode>.apk`,
`_<versionCode>.aab`, `_<versionCode>_sbom.json` — and refuses to start if a file
for this versionCode is already staged. The push targets upload exactly those
files, run their checks against the staged bytes, and neither builds nor stages.
The `deploy` target in `android/Makefile` is removed: it duplicated
`push-playstore` while bypassing every safeguard and rebuilt the bundle on the
way; a breadcrumb comment marks the old spot.

The remote-detection line shared by both targets tolerates a checkout with no
configured upstream: under `.SHELLFLAGS := -eu -o pipefail` the failing `git
rev-parse @{u}` killed the recipe on the assignment, before the
`${remote:-origin}` fallback on the same line could run.

### Build hygiene

The on-device instrumentation tests move out of the default build into a
`device-tests` target, and `make release` no longer captures screenshots, so
building the release artifacts needs no device. Store assets are captured on
demand through `make screenshots` or `make store-assets`.

Recipes echo the commands they run, with secrets in shell variables so no token
value is printed. Tool presence is checked with plain `command -v` guards. The
device pre-flight in `screenshots`, `report-pdfs`, `test-device` and
`install-debug` traces its `adb devices` probe with a scoped `set -x` and runs
before the Gradle build, so a stopped emulator fails fast; the `java` target
prints `java -version` before its version test.

`prereq`'s `$(GUIDE_OUTPUTS)` prerequisite is attached on a second dependency
line after `-include guides.d`, because make expands a prerequisite list as it
reads the rule and the variable was still empty there. No build was ever wrong:
Gradle's own `generateUserGuides` task had masked the gap.

The favourite star goes through `DrinksViewModel.setFavorite`, which writes only
the flipped flag and leaves the stored values byte-identical, so a drink imported
with a serving size the reader accepts but the editor does not can still be
favourited; genuine edits keep the full validation.

`tools/render-feature-graphic.py` checks the exact bundled font files up front
and fails with the recovery command, because fontconfig silently substitutes a
missing family and would have set the badge text in the wrong typeface.

### Documentation

The Keystore KDoc no longer claims StrongBox backing — the key is TEE-backed,
and StrongBox would require `setIsStrongBoxBacked(true)`, deliberately not
requested. `DrinkDaysBar`'s KDoc describes the trailing 7-day window rather than
the pre-v0.62.0 Mon–Sun week. The unreachable `application/pdf` chooser branch in
`SettingsScreen`'s share effect is removed. COPYING.md's build-time tooling list
gains the KSP, Kover and ktlint Gradle plugins beside CycloneDX.

SECURITY.md states key custody per channel: the maintainer holds the app-signing
key for the Codeberg and F-Droid APK and, under Play App Signing, the upload key
for Play, while Google holds Play's own app-signing key; the published
fingerprint identifies the F-Droid and Codeberg signer, and a Play-delivered APK
carries Google's re-signing key. CONTRIBUTING's release checklist publishes
through `make push-codeberg` and `make push-playstore`.

---

## v0.80.0

Include user settings in JSON backups

The JSON backup carries the user's settings, closing a data-loss gap: a restore
on a fresh install brought back drinks and entries but silently reset every
preference, including the body weight that feeds the blood-alcohol calculation,
because the settings live in a separate encrypted DataStore the backup never
touched.

The format is bumped from 2 to 3 and the export writes a top-level `settings`
object: theme, day-change time, daily and weekly limits, max drink days per week,
statistics start date, biometric lock, screenshot permission, language and body
weight. Older apps reject a v3 file through the existing "version too high"
guard rather than dropping the settings unnoticed.

A REPLACE import applies the backup's settings; a MERGE import keeps the local
ones and only adds data. A pre-v3 backup has no settings block and leaves the
local settings untouched in both modes, its history restoring as before.

On import the settings are validated defensively — enum fallback, range clamping
identical to the preference setters, canonical-date check for the statistics
start date — so a hand-edited backup can never abort the restore of the primary
payload. The `weightKg == 0` and `language == ""` sentinels are preserved rather
than turned into a bogus 1 kg weight or an empty explicit locale. Restoring a
language re-applies it to the framework per-app locale, so it takes effect
immediately instead of drifting out of sync with the stored preference.

`assert()` invariants are added to `AlcoholCalculator` and `DayResolver`: the
non-negative grams, BAC, limit-fraction, serving-count, streak and
effective-day-count postconditions and the `countLimitViolations` sliding-window
invariant. They are checked under `-ea` in the unit-test suite and are no-ops in
release builds.

---

## v0.79.0

Work toward OpenSSF gold badge criteria

Development toward the OpenSSF Best Practices gold level (project 13480), plus
the fixes from three full review rounds of the whole tree. The OpenSSF work is
documentation and process only; the review fixes include user-visible
corrections — Chinese language detection, the report's longest-abstinence figure,
month and date label localization, the day rollover on the Today screen, the PDF
report's CJK glyph orthography, and accessible names for the calendar navigation
arrows, the drink-category icon and the year heat-map's day cells.

### Accessibility

`docs/ROADMAP.md` states that no WCAG 2.2 conformance level is claimed and none
of the W3C conformance logos is used: a logo is a formal claim that all criteria
of a level are met under a thorough human evaluation, there are verified open
Level AA items, and the logos are web-page scoped rather than native-app scoped.
It lists the measured gaps: non-text contrast 1.4.11 (empty heat-map cells
1.1–1.3∶1, today outline 1.2–1.5∶1, against a 3∶1 requirement), text contrast
1.4.3 (`onSurfaceVariant` 4.39∶1, warning-red as text 3.25–4.23∶1), target size
2.5.8 (10 dp cells), and the on-screen chart's missing text alternative 1.1.1.
The README gains a factual Accessibility subsection, CONTRIBUTING §4 documents
the labelling rule, and `accessibility_best_practices` is corrected. The
per-locale store `full_description` is deliberately left alone: a
non-conformance is not marketing copy.

`tools/release-check.sh` §13 fails the build if any `Icon` inside an
`IconButton` has `contentDescription = null`. It is a labelling invariant, not a
WCAG conformance test, and skips gracefully without python3.

Every year heat-map day that carries data exposes a `contentDescription` built
from a new `year_calendar_day_desc` string — date, grams, status — reusing the
under/over-limit legend captions, with the date and number formatted in the
per-app locale; empty days stay inert and silent so a reader is not flooded with
hundreds of "no entry" nodes. The under/over palette is blue against red, not a
red/green pair, so it is already colour-blind distinguishable.

The four calendar navigation arrows carry `cd_prev_month`, `cd_next_month`,
`cd_prev_year` and `cd_next_year`, translated into all 21 languages; they were
the only actionable icons in the app without a localized description.
`DrinkCategoryIcon` uses the localized `DrinkCategory.displayLabel()` rather
than the raw enum constant a screen reader had read out verbatim.

### Localization and formatting

The report template's root element carries a per-locale language hint,
`<html lang="{{REPORT_LANG}}">`, filled by `PdfReportBuilder` from the per-app
locale. The report is rendered by a WebView whose CJK font fallback selects the
glyph orthography — Simplified against Traditional Han, Japanese kanji, Korean
hanja — from the document language, and without the hint Blink defaulted to
Simplified-Chinese forms in Japanese, Korean and Traditional-Chinese reports.
User-visible for those three exports; `PdfReportLangTest` pins the template
invariant and the substitution.

Month-and-year labels in the Calendar header and the PDF's monthly table and
chart are built from the CLDR skeletons `yMMMM` and `yMMM` through a new
`monthYearFormatter`, replacing a literal `"MMMM yyyy"` that showed the wrong
field order for Chinese, Japanese and Korean and the genitive rather than the
standalone form in the inflected languages. The year view's bare month
abbreviations use the standalone `LLL`.

Swedish compact day-and-month labels render day-first. Deriving them from the
SHORT date pattern kept sv's year-first order; the derivation now aligns the
day/month order with the locale's MEDIUM pattern, quoted-literal-safe, and a
property test asserts that alignment for every shipped locale.

`YearCalendarView` builds its month-abbreviation formatter with the per-app
`formattingLocale()`, and `formatStatsDate` uses the locale's LONG date style
instead of a hardcoded `"d. MMMM yyyy"` — passing a locale to a hardcoded
pattern localizes only the month name while field order and punctuation stay
German.

First-launch language detection understands script subtags. Modern Android
reports Chinese as `zh-Hant-TW` or `zh-Hans-CN`, which the previous matcher
could not map to the shipped `zh-TW` and `zh-CN`, so Chinese users were silently
forced to English and stayed there, the detected tag overriding Android's own
resource fallback. `LocaleDetector.detect` matches language and region with the
script dropped, disambiguates the remaining `zh` variants, and folds the
Norwegian macrolanguage alias `no` onto `nb`.

### Domain correctness

Totals exactly at a limit no longer count as exceeded.
`AlcoholCalculator.isOverLimit`, with an epsilon of 1e-6 — three orders below the
0.1 g data grid — is the single definition of "over the limit", used by the
violation counters, the report's over-limit months, binge days, peak-KPI
warnings and chart bars, and the on-screen limit bar, calendar and chart markers.
Day and window totals are binary-double sums, so an exactly-at-limit total could
drift and a strict `>` flagged an exceedance the user cannot see.

The PDF report's longest abstinence includes the ongoing dry streak, as the
Statistics screen does; it had called the legacy no-`today` overload of
`DayResolver.computeLongestAbstinence`, so a report could show a current
abstinence larger than the longest one.

The Today screen rolls over to the new logical day while it stays open. The
minute ticker re-derives the day outside the `flatMapLatest`, behind
`distinctUntilChanged` so database queries restart only at the boundary, and the
Statistics period bounds and the Calendar's today marker follow the same
pattern. "Today" had been computed once per settings emission, so a drink logged
after the configured day-change time was invisible.

`BackupManager` Guard 5 validates referential integrity at parse time: every
entry must reference a drink contained in the backup. A dangling `drinkId` had
reached the repository, where the REPLACE path's remap fallback kept the raw id
— silently attaching the entry to the wrong drink when the number matched a
local preset. The fallback is replaced by a strict lookup that names the
dangling id.

`KeystoreSecretStore.openWithKey` throws `GeneralSecurityException` rather than
`IllegalArgumentException` for a blob too short to contain an IV. `open()`'s
contract promises GSE for any malformed blob and `AppPreferences` catches exactly
that family to translate a decryption failure into a DataStore
`CorruptionException`, so a truncated preferences file had bypassed the
`ReplaceFileCorruptionHandler` and crashed the read instead of self-healing.

### Store metadata

The 14 store-locale directories carrying bare codes Play rejects are renamed to
Play's store-listing codes — `cs-CZ`, `da-DK`, `el-GR`, `es-ES`, `fr-FR`,
`it-IT`, `ja-JP`, `ko-KR`, `no-NO`, `nl-NL`, `pl-PL`, `pt-PT`, `ru-RU`, `sv-SE`.
F-Droid reads region-qualified codes fine. The per-locale sample report PDFs and
`screenshots.html` are renamed along, `render-feature-graphic.py` keys its CJK
font fallback by language and region rather than the directory name, and the
capture suites resolve their resources via the detected app language — `no-NO`
against `nb` is the one pair Android's resource matcher does not bridge.
`release-check.sh` §4 Check D requires every metadata directory to be a valid
Play code and to map 1:1 onto `SupportedLocales.ALL`. The app's resource
qualifiers and the `docs/guide` templates keep their own platform-fixed naming;
the "add a new language" checklists document all three ecosystems.

The versionCode-90 release notes are rewritten in all 21 store languages to
describe this release's user-visible fixes alongside the OpenSSF process work;
the previous note predated the review round and claimed no functional changes.

### Screenshots

The capture date is pinned in-app rather than on the device. `DayResolver` gains
a test-only `clockOverride`, null in production, and the androidTest helper
`ScreenshotClock` pins it to 2026-06-30; both capture suites set it in `@Before`
and clear it in `@After`. The Makefile's `adb shell date` pin only ever worked on
an emulator or a rooted build and silently no-opped on a production phone, so
captures had used the real date. It is demoted to best-effort cosmetics, and a
`screenshots` preflight enforces that `SCREENSHOT_DATE` and
`ScreenshotClock.SCREENSHOT_DATE` agree and that the pinned day is not before the
fixture's last logged day. `DayResolver.clock()` exposes the effective clock, and
the Calendar header and the report's export date read through it, so the whole
date perspective is pinned rather than just `today()`.

The store-image pipeline cascades. `make screenshots` captures the in-app shots
01..06 and refreshes the feature graphics; `make report-pdfs` owns pages 07..08,
rasterizing them from the freshly exported PDFs, and refreshes the graphics too.
A missing device screenshot triggers one guarded capture run on genuine absence
only, never on staleness. `make store-assets` rebuilds the whole set, and a
once-per-run stamp renders the feature graphics exactly once.
`validate-screenshots.py` gains `--in-app` and `--report` modes. screengrab's
`clear_previous_screenshots` is disabled and replaced by a targeted delete of
exactly 01..06, because screengrab globs every `*.png` in each directory and
would have wiped the committed report pages without rebuilding them.

### Build and style

ktlint runs tree-wide and gates the everyday build through `android/Makefile`'s
`lint` target. The non-auto-correctable findings are resolved in `.editorconfig`
rather than by churning idiomatic code: `@Composable` functions are exempt from
the lowercase naming rule, `no-wildcard-imports` and `backing-property-naming`
are disabled, and `ui/screen/ViewModels.kt` is exempt from `no-empty-file`.
Genuine fixes: the `app/build.gradle.kts` script imports are contiguous and
comment-free, an inline value-parameter comment in `DrinkEntity` moved above the
parameter, and `AppDatabase.INSTANCE` renamed to `instance`.

Kover measures statement and branch coverage over the unit-testable code — the
Compose UI, the Android-runtime-bound layers, the app entry points and generated
code are excluded and covered by instrumented tests instead. Statement coverage
reaches about 97 % and branch coverage about 80 %, with a build-breaking
`koverVerify` floor of LINE ≥ 90 and BRANCH ≥ 75 wired into the release gate.
This meets `test_statement_coverage80`, `test_statement_coverage90` and
`test_most`; `test_branch_coverage80` stays a roadmap goal.

The Gradle distribution is pinned by checksum through `distributionSha256Sum`,
keeping the committed `gradle-wrapper.jar` a stock, verifiable wrapper; the
wrapper-regeneration step that refreshes the pin is documented in CONTRIBUTING §7.
fastlane moves from 2.236.1 to 2.237.0.

### OpenSSF gold work

The remaining hand-authored files carry the standard GPL header: eight XML files
and four configuration files, so every hand-authored source file now carries both
a copyright and a licence statement.

CONTRIBUTING.md gains a "Good first issues" subsection and a "Code review
requirements" subsection documenting how review is conducted, what is checked and
the acceptance criteria for merging, and §2 documents the commit-signing and
fast-forward-only merge workflow. The DCO auto-sign-off tip is corrected:
`format.signOff` affects `git format-patch` and `git send-email`, not
`git commit`.

`docs/GOVERNANCE.md` requires cryptographic two-factor authentication on every
account with write access, since the forge offers no per-project enforcement, and
records that collaborators are reviewed and approved before escalated permissions
are granted.

SECURITY.md gains sections on security advisories, secrets and credentials, and
support — the single-maintainer rolling-release model in which only the latest
version is supported — and documents the dependency licence-compatibility
requirement as the project's SCA remediation threshold. `docs/ASSURANCE_CASE.md`
records a dated security review combining the assurance-case analysis with a QA
pass over the security-relevant code.

Every published release is accompanied by the build's CycloneDX SBOM as a release
asset, with `release` and `bundle` printing its path and the release checklist
naming the step. `.bestpractices.json` is a version-controlled snapshot of the
badge answers, refreshed by `make bestpractices-json` in a one-way site-to-repo
mirror; its four justifications that quoted a concrete release are reworded to be
release-agnostic. `docs/ROADMAP.md` records the remaining Baseline Level 3 gaps.

### Documentation corrections

CONTRIBUTING.md §8 records that, since the first F-Droid release (v0.77.4), the
Room database and the JSON backup format are guaranteed backward-compatible:
migrations are forward-only and never destructive, and the importer keeps reading
every `BACKUP_VERSION` from that baseline. Breadcrumbs sit in `AppDatabase` and
`BackupManager`, and `AppDatabase`'s cross-reference points at §8.1.

The export date-range dialogs read `LocalDate.now(DayResolver.clock())` rather
than a bare `LocalDate.now()`, matching the app-wide rule. The manifest's
"HOW TO ADD A NEW LANGUAGE" header says four steps. The build-script comment
claiming the Kover thresholds are not enabled yet is rewritten,
`setDayChangeTime` clamps hour and minute like every other preferences setter,
the committed `fastlane/report.xml` run artifact is removed and gitignored, and
two localization checklists no longer carry a string-key count that
`LocaleSyncTest` owns. `docs/PLAY_STORE.md` is deleted.

The Gradle 9.6.1 deprecation "Using a Project object as a dependency notation"
is attributed to upstream plugins — one occurrence in Kover, two in the Android
Gradle Plugin — with no project build script using the deprecated notation, and
is recorded here so it is tracked for the Gradle 10 upgrade rather than
re-investigated.

---

## v0.78.0

Complete L10N for F-Droid; overhaul build tools

Google Play onboarding, an F-Droid badge in the feature graphic, a relocation of
the build tooling, and a handful of user-facing fixes. The rest is documentation,
store assets, build and release tooling and internal hardening, folded in from
three review passes.

### User-facing

A CSV or PDF export over a date range containing no entries shows a
self-dismissing Toast rather than only a faint inline notice inside the
scrollable statistics list. A successful export is still signalled by the share
sheet or the system print dialog.

On Android 11 to 12L the CSV column headers, the whole PDF report and the
import/export status messages follow the language selected in the app. They had
fallen back to the system language on those API levels, because AppCompat's
per-app locale back-port localizes only Activity contexts, not the Application
context the exporters were handed. Android 13 and later were never affected.

The Today screen's weekly range and the PDF chart's x-axis ticks use the locale's
day/month order and separator — "6/28" for en-US, ja and zh, "6. 28." for ko,
"6-28" for sv — instead of a hard-coded European "d.M." for every language. For
unaffected locales the only visible change is the dropped trailing dot.

A CSV or JSON export reports failure when the file cannot be written. If
MediaStore hands back no output stream the app had claimed success while leaving
an empty file in Downloads; the orphaned file is now removed and the error shown.

The statistics chart leaves the current day as an empty slot until it resolves —
a drink is logged and a bar appears, or the period closes dry and the tick
appears. The green tick promises a completed alcohol-free period, and an
in-progress day may still become a drink day until the day-change time. The rule
lives in the shared series builder `ChartBucketing.bucketize`, so the on-screen
chart and the PDF report cannot drift; WEEK, MONTH and YEAR are all covered.

Statistics rows give the label the flexible width and pin the value to a single
line, so a long translation can no longer squeeze a value into a vertical,
character-by-character stack in any locale. On top of that the French tab label
is the new short `nav_statistics` string ("Stats"), where the full
"Statistiques" wrapped onto two lines, and one long French row label is
shortened to the wording the PDF report already uses.

### Store assets

Every `full_description.txt` is reflowed so each paragraph and list item is a
single line, letting the stores wrap the text themselves; the source's fixed-width
wrapping had produced mid-sentence hard breaks on F-Droid. List markers are the
Unicode bullet, which both stores render, where the previous Markdown `*` showed
literally on Google Play. Line joining is CJK-aware — Chinese and Japanese
fragments rejoin without a space, space-using scripts including Korean with one.
Wording is unchanged and every locale stays within the 4000-character limit.

The feature graphic carries the per-locale "Get it on F-Droid" badge in the
bottom-left corner and the GPLv3 logo in the bottom-right, with mirrored 48 px
margins, a shared baseline and a shared visible height; the badge is cropped to
its ink box before scaling, because its canvas carries a transparent margin that
would otherwise make the two marks different sizes. A 4096×2000
`featureGraphic-4K.png` is rendered beside each 1024×500 store graphic for
press and web use and is embedded in the README; fastlane does not upload it.

Per-locale marketing copy exists for all 21 store locales. Noto Sans CJK Regular
(OFL 1.1) is bundled under `tools/fonts/NotoSansCJK/`, because Inter has no CJK
or Hangul glyphs, and the renderer is CJK-aware: `_char_width` gives Han, kana,
Hangul and fullwidth code points a full-em advance, `_wrap` allows a break
between CJK characters, and `_build_svg` appends the region-appropriate Noto
family after Inter for ja, ko, zh-CN and zh-TW. Latin, Greek and Cyrillic locales
are unaffected.

The four feature boxes share one height, so in el, fr, pl, ru and uk the privacy
bullet's fifth line pushed the stack past the 500 px canvas and was clipped.
Each is trimmed to four lines while keeping the concrete features, and all 21
privacy bullets carry "100 %" again. For ru and uk this shifts a noun to an
adverb, which suits the marketing register but is worth a native review. The ja
and ko copy carries explicit line breaks at word boundaries, because the
width-based wrap split words mid-run and left orphan tails; the exact break
points are a native-review detail. A German phrase that had leaked into the Dutch
tagline is corrected.

The localized `fdroid/get-it-on-<lang>.svg` badges exist for every store
language, and `_badge_for_locale` selects by full tag, then bare language, then
English, so nb and uk still render one. `COPYING.md` attributes the whole set
(CC BY-SA 3.0). DejaVu Sans and Rokkitt are bundled under `tools/fonts/` for the
badge text and documented in `COPYING.md`; the static Rokkitt Bold is instanced
from the upstream variable font by `make rokkitt-bold`, whose source lives in
`tools/fonts-src/` so it never competes with the static instance during the
deterministic render.

### The store-asset pipeline

`make screenshots` captures every store locale. `SCREENSHOT_LOCALES` and
screengrab's `locales` are both derived from the metadata tree by globbing the
`changelogs/` sub-directories, so the two derivations match and adding a locale
directory extends the pipeline automatically.

`screenshots-pdf` renders report pages 07 and 08 from a PDF named exactly for
that store locale under `fastlane/report-pdf/`. There is deliberately no
base-language or English fallback — `zh-CN` and `zh-TW`, or `pt` and `pt-BR`,
must not collapse onto a shared PDF — so a missing per-locale PDF is a hard
error.

The report pages and feature graphics are make file targets in a dependency
graph, so only the locales whose inputs changed are regenerated. Each
`featureGraphic.png` depends on its copy, its `01_today.png` and its
`07_report_page_1.png`, which depends in turn on the source PDF, and on the whole
`tools/fonts/` tree, because the badges draw live text in DejaVu Sans and
Rokkitt. `featureGraphic-4K.png` shares one grouped-target rule with the store
graphic, so a single renderer call produces both.

`make report-pdfs` drives the app's own PDF export once per locale. An
instrumented `ReportExportTest` opens the system "Save as PDF" dialog and blocks
until the app is foreground again; the operator taps Save and the run advances,
so the automation never has to read a localized button. The production export
routes through the platform print dialog by design, and a fully silent export
would need a non-public print-framework API. The dialog's file name is pre-filled
by calling the print path with that job name, entirely within the androidTest
source set, and the test is inert unless invoked with `-e reportExport true`. The
APKs are installed with `adb install -t`, any previous copy uninstalled first,
and adb's own failure message is printed.

The generated user guides are no longer rebuilt by a blanket phony target.
`render-guide.py --make-deps` emits one rule per language into `guides.d`, which
`android/Makefile` regenerates and includes, so a guide is rebuilt only when its
own template or `strings.xml` changed. The shared recipe touches its output,
because the renderer writes content-based and the file would otherwise look
perpetually stale.

### Build tooling

The build and packaging tooling moves from `android/tools/` to a repository-root
`tools/`, since these scripts serve the build and release process rather than the
app; `release-check.sh` re-anchors to the sibling `android/`, and the scripts are
`__file__`-anchored so they run from the repository root. Historical changelog
entries intentionally keep referring to `android/tools/`. The `screenshots` and
`feature-graphics` targets move to the root `Makefile`, with the Gradle build
staying in `android/` behind a new `screenshot-apks` target.

`make debug` is the default goal and runs the maximal local verification before
the debug APK: the release-check gate, Android lint, the JVM unit tests, the
on-device instrumentation tests and `check-guides`, then refreshes any feature
graphics already on disk through `feature-graphics-existing`, so a
screenshot-less working copy does not trip the `01_today.png` guard. `make
release` refreshes the store assets and then builds the signed artifact and its
SBOM. The per-tool preflights become `require-device`, `require-pdftoppm`,
`require-rsvg`, `require-pillow` and `require-fonttools` macros, the two
report-page rules fold into one parametrized canned recipe and the
feature-graphic rule into another, and the file is reorganized into labelled
sections with a targets index. Behaviour is verified unchanged against the
`make -p` database.

The `tgz` target derives its `tar` exclude list from `.gitignore` rather than a
hand-kept parallel copy, mapping the patterns faithfully: comments and blank
lines dropped, a negation aborting the build because tar cannot express an
un-exclude, root-anchored patterns matched `--anchored` and the rest
`--no-anchored`, with `--no-wildcards-match-slash` keeping `*` inside one path
segment. `keystore.properties` and `play-store-credentials.json` are excluded.

`release-check.sh` §9 validates `PRIVACY.md` and is `if`-guarded, so a markdown
error prints every offending file and line instead of aborting the run at the
assignment and surfacing as a bare "Error 1". §1 no longer verifies the F-Droid
reference recipe, which is kept only as a static, non-maintained backup with a
banner saying so.

The fastlane `deploy` lane defaults to the `internal` track; production requires
`track:production` explicitly.

### Licensing

`COPYING.md` records the copyright holders and licences of the runtime libraries
actually shipped in the APK — the Apache-2.0 AndroidX, Jetpack, Compose, Room,
DataStore, biometric and tracing stack, the Kotlin and kotlinx runtime, and
`desugar_jdk_libs` under GPL-2.0-with-Classpath-Exception — and names the
transitively pulled holders: Square for okio behind DataStore, The Guava Authors
for listenablefuture behind concurrent-futures, The JSpecify Authors, and
`org.jetbrains:annotations`. Build- and test-time dependencies are listed
separately as non-redistributed, and the CycloneDX SBOM is named as the
authoritative machine-readable inventory. A "Third-Party Assets" paragraph
records the Roboto and Noto Sans CJK subsets embedded in the committed sample
report PDFs.

The verbatim Apache-2.0 text is checked in as `LICENSE.Apache-2.0.md` and
bundled into the in-app copyright document, which is the concatenation of
COPYING.md, LICENSE.md and that file. The file carries no modeline header, so it
is the pure upstream text. The `packaging { excludes }` block explains that the
excluded `META-INF/AL2.0` and `LGPL2.1` entries are duplicated notice files from
the kotlinx-coroutines artifacts, not code, and where the licence text is
delivered instead.

`release-check.sh` §12 is an SBOM-gated scan that resolves every shipped
component to its Gradle-cache artifact and warns on any `META-INF/NOTICE*`
entry, automating the Apache-2.0 §4(d) confirmation COPYING.md had prescribed as
a manual step. Without the SBOM or the cache it reports itself skipped and
passes.

The PDF report footer's English licence and warranty line is documented as
deliberately unlocalized: legal boilerplate is quoted, not paraphrased.

### Hardening

`Context.perAppLocalizedContext()` derives a context carrying the locale list
stored via `AppCompatDelegate.getApplicationLocales()`, used by the
`StringProvider`s in `AppViewModelFactory`, by `SettingsViewModel`'s plural
resolution and by `StatsViewModel` before it hands the context to `CsvExporter`
and `PdfReportBuilder`. `LocaleSupport.kt`'s documentation, which had claimed the
Application context carries the per-app locale, is corrected. The two
instrumented regression tests arrange explicit locale lists rather than going
through `AppCompatDelegate.setApplicationLocales`, which reaches the framework
`LocaleManager` only via active AppCompatDelegate instances and is a silent
no-op in an activity-less test.

`l10n/DatePatterns.kt` derives the compact day-and-month pattern from the
locale's SHORT date pattern in pure java.time, so it is JVM-testable, and is
verified against all 21 shipped locales.

`TodayViewModel.addEntry` and `updateEntry` read the settings from
`prefs.settingsFlow.first()` rather than `uiState.value.settings`, which before
the first combine emission still holds the `AppSettings()` defaults and a 04:00
day change, so an entry added in that window could be filed under the wrong
logical date.

`WebViewPdfPrinter` holds the Activity context through a `WeakReference` and
releases its `retained` field on every callback path, closing a leak in which the
`onPageFinished` closure pinned the whole Activity while the parked WebView
awaited a callback that might never fire. The off-screen WebView is destroyed
deterministically when the print job ends, through a delegating
`DestroyOnFinishAdapter` whose `onFinish()` fires once per job after printing or
cancellation, rather than lingering until GC.

`DrinkDao.insert` uses `ABORT` rather than `REPLACE`, mirroring `EntryDao`. Every
caller inserts with `id = 0`, so Room auto-generates the key and no collision can
occur; `ABORT` makes any future explicit-id collision fail loudly instead of
silently overwriting a row. The previous rationale was inaccurate: the `drinks`
table has no `UNIQUE` constraint on `name`.

`AppDatabase.PrepopulateCallback` launches on an explicit `Dispatchers.IO`,
honouring the convention that every launch site states its dispatcher.
`StatsUiState`'s default `period` is `MONTH`, matching the ViewModel's initial
state, so the `stateIn` seed is plain `StatsUiState()`. Every `LazyColumn` and
`LazyRow` over entries and drinks passes the stable Room id as `key`. The guarded
`!!` assertions in the drink editor, the export date-range confirm and the import
mode dialog give way to elvis-return and `?.let` guards.

`CsvExporter.escapeField` forces RFC 4180 quoting on a field embedding a lone
carriage return, not only a line feed, so an old-Mac line ending in the middle of
a note cannot split the record.

`MarkdownText` renders a thematic break as a `HorizontalDivider` rather than the
literal marker characters, and decodes the `&mdash;` and `&sect;` entities
COPYING.md uses.

App Bundle language splits are disabled: the in-app language switcher needs every
locale's resources on the device, which Play's per-language splits would strip.
The latent mismatch had existed since the switcher shipped and surfaced as the
lint error `AppBundleLocaleChanges` once `perAppLocalizedContext()` introduced a
`Configuration.setLocales` call the detector recognises. F-Droid APKs are unsplit
and unaffected.

Dead API is removed: `AlcoholCalculator.soberByMillis` with its four tests, and
the repository-level `getById` lookups. `DrinkDao.getById` is kept, its sole
consumer being a white-box assertion in an instrumented test, with a KDoc note
saying so. `LimitBar` calls `AlcoholCalculator.limitPercent` instead of
duplicating the fill-fraction division with a subtly different zero-limit guard.

The backup MERGE contract is documented as also bringing over the backup's drink
catalogue: a custom drink whose name is not present locally is inserted even
without entries, which is intentional and idempotent because a later merge
re-matches by name. REPLACE likewise restores the full catalogue.

`TodayViewModel`'s Context-free `Locale.forLanguageTag(settings.language)` and
the Context-based `Context.formattingLocale()` are documented as two views of the
same per-app locale, so a future reader does not reconcile them by injecting a
Context into a deliberately JVM-testable ViewModel.

### New documentation

`PRIVACY.md` is the privacy policy the Play "App content" section requires,
linked from the README: no data collection, no network access, on-device storage
protected at rest by device encryption and the sandbox, and an optional biometric
lock handled by Android. `docs/PLAY_STORE.md` is a repeatable runbook for
publishing to Play alongside F-Droid with a single signing identity.

The user's guide gains a `### {{security}}` section covering the biometric lock
and the screenshot toggle — the latter off by default, so the window stays out of
screenshots and the recent-apps overview — placed before Appearance to match the
Settings screen order, and a sentence for the Today screen's "Ø" badge.
Appearance is trimmed to the colour theme and language. UI labels stay
`{{token}}` references so they track `strings.xml`; only the connective prose is
translated.

The OpenSSF passing and silver groundwork lands as documentation. The README
gains "Feedback & Contributing", "Security", a "Quick start" section and the
badge. CONTRIBUTING.md gains a "Submitting changes" section, the Developer
Certificate of Origin with a sign-off requirement, a mandatory test policy in §5
and in the change-proposal instructions, and an accuracy pass on the architecture
map, the `BINGE_THRESHOLD` figure (48 g corrected to 60 g), the testing-strategy
table and the translation workflow around `l10n/SupportedLocales.kt`. SECURITY.md publishes the
PGP-encrypted private reporting process with a 14-day acknowledgement
commitment, a "Security model" section, "Verifying releases", GPG-signed release
tags and a documented dependency-monitoring process using osv-scanner against the
SBOM. `docs/GOVERNANCE.md` defines the single-maintainer model,
`CODE_OF_CONDUCT.md` adopts Contributor Covenant v2.1, `docs/ROADMAP.md` records
the intended directions and explicit non-goals, and `docs/ASSURANCE_CASE.md`
states the threat model, the trust boundaries and the weakness classes mapped to
countermeasures. ktlint is adopted with a root `.editorconfig`, running under
`check` and off the release-assembly path.

`versionCode` moves 88 → 89 and `versionName` 0.77.4 → 0.78.0, with localized
store notes in `changelogs/89.txt` for all 21 listing locales.

---

## v0.77.4

Drop in-APK SBOM for reproducible builds

The release APK no longer embeds the CycloneDX SBOM under `assets/sbom/`.
F-Droid's from-source rebuild of 0.77.3 verified the signature but failed the
byte-for-byte comparison, and the only differences were in the packaged SBOM: its
metadata captures the build environment, so `metadata.timestamp`, an
auto-injected `build-system` entry carrying the CI job URL, and the VCS URL
recorded as `ssh://` locally against `https://` in CI all differ between
machines. None can be reconciled, so the SBOM ships beside the APK rather than
inside it. `cyclonedxDirectBom` is unchanged, so `make sbom` and `make release`
still produce the standalone document. The APK is otherwise byte-identical to
0.77.3.

`tools/release-check.sh` §11 fails the release if `build.gradle.kts`
reintroduces an in-APK SBOM task.

`AutoName: Libellus Potionis` is added to the reference F-Droid recipe so it
stays in sync with the fdroiddata copy.

`versionCode` 87 → 88, `versionName` 0.77.3 → 0.77.4, with localized store notes
in `changelogs/88.txt` for all 21 locales.

---

## v0.77.3

Refine translations and data-security wording

### Localization

The base `res/values/strings.xml` carries a structured translator and reviewer
context block and a per-entry comment for every string: where it appears, what
each placeholder means, and the typographic-quote convention. The comments are
documentation and do not affect the build.

The in-app strings across the base locale and all 21 translations gained
terminology, grammar and quote-consistency fixes, and twelve localized user-guide
templates gained wording refinements. The Romanian store summary is shortened to
77 characters to meet the 80-character limit. The Ukrainian `import_merge` value
carries an escaped apostrophe, which aapt2 requires.

### Data-at-rest wording

After the removal of SQLCipher the Room database is no longer encrypted at the
application level; it is protected at rest by Android's file-based storage
encryption and the per-app sandbox. Three texts still carried the old claim and
now state that: the README's "Privacy & Security Architecture" section, the
in-app user's guide in all 21 templates, and the fastlane full descriptions,
which drop the half-sentence about preferences being sealed with a
hardware-backed Keystore key.

The source comments needed no change: `AppPreferences.kt` documents the
app-encrypted preferences DataStore accurately, and `AppDatabase.kt` references
only the legacy SQLCipher artefacts that `purgeLegacyEncryptedDatabase()`
deletes.

### Release-check tooling

§1 no longer cross-checks a version comment in `proguard-rules.pro`; the
`# Version:` line is removed from that file, since R8 ignores comments and the
line only added a manual sync point. The README title version stays enforced,
being user-facing.

§2 verifies that the entry's first line, reused verbatim as the commit subject,
is at most 50 characters. New §10 checks every locale's
`short_description.txt` (≤ 80), `full_description.txt` (≤ 4000) and
`changelogs/*.txt` (≤ 500), counted in characters rather than bytes so Greek,
Cyrillic and CJK are measured the way the stores do.

### F-Droid

The reference recipe declares `Binaries` and `AllowedAPKSigningKeys`, so F-Droid
can verify its own from-source build against the developer-signed APK published
on Codeberg. The published asset must be named for its versionCode.

`versionCode` 86 → 87, `versionName` 0.77.2 → 0.77.3, with localized store notes
in `changelogs/87.txt`. The APK is functionally identical to 0.77.2.

---

## v0.77.2

Fix SBOM normalizer path in release build

`generateSbomAsset` resolves `sbom-normalize.py` through
`rootProject.file("tools/sbom-normalize.py")`. It had used
`layout.projectDirectory`, which is the `:app` module directory, so the path
pointed at a file that does not exist and the release build could not complete.

`versionCode` 85 → 86, `versionName` 0.77.1 → 0.77.2, with localized store notes
in `changelogs/86.txt`. No functional change.

---

## v0.77.1

Fix F-Droid release build signing config

The `release` build type looks up its signing config with the nullable
`findByName("release")` and a null-safe check. F-Droid strips the whole
`signingConfigs` block before building, since it signs APKs itself, after which
`getByName` aborted the build — which is why the F-Droid build of 0.77.0 failed
at `assembleRelease`. With the block removed the release build now simply stays
unsigned and F-Droid signs it. Local behaviour is unchanged.

`versionCode` 84 → 85, `versionName` 0.77.0 → 0.77.1, with localized store notes
in `changelogs/85.txt`. This is the first version that builds on F-Droid.

---

## v0.77.0

Rework feature-graphic copy; drop fdroid README

The feature-graphic bullet copy is reworked in both locales: the privacy bullet
spells out the concrete guarantees — "100 % Privacy: App Lock & Offline-only",
"100 % Privacy: App-Sperre, kein Netzwerk" — the limits bullet is title-cased on
en-US, and the final bullet advertises "Open Source". Both graphics are
regenerated, and the README shows the en-US one at the top.

`make screenshots` also runs `make feature-graphics`, so the store graphics are
regenerated with the screenshots rather than as a separate manual step.

The maintainer reference-copy comment header is removed from
`fdroid/de.godisch.potillus.yml` and `fdroid/README.md` is deleted;
`release-check.sh` still keeps the reference copy's version in sync.

`versionCode` 83 → 84, `versionName` 0.76.0 → 0.77.0, with localized store notes
in `changelogs/84.txt`. The APK is functionally identical to 0.76.0.

---

## v0.76.0

Add a deterministic feature-graphic generator

The two AI-generated Play-Store feature graphics give way to a deterministic,
re-localizable generator. This is a store-listing change only; the versionCode is
bumped so the refreshed listing ships under its own code.

`android/tools/render-feature-graphic.py` composes the 1024×500 graphic — the
exact Play feature-graphic size, where the previous images were 1488×720 — from
inputs the project already controls: per-locale marketing copy, the real
screenshots from `make screenshots`, and the launcher icon. It emits SVG and
renders with `rsvg-convert`; the phone is built and perspective-warped with
Pillow and given a depth edge on its near side, because SVG's affine transforms
cannot do perspective. The old images baked in AI-hallucinated text, including a
garbled report page; the embedded shots are the genuine localized captures.

Text is rendered with a pinned bundled font selected through a throwaway
fontconfig that exposes only `android/tools/fonts/`, so output never depends on
the host's installed fonts and repeated renders are byte-identical. The runtime
dependencies are the python3 standard library, `rsvg-convert`, Pillow and the
bundled fonts. Marketing copy lives in
`fastlane/metadata/android/<locale>/feature-graphic.txt`, and tagline line breaks
are computed by the tool, so editors change words rather than layout.

`android/tools/fonts/Inter/` adds static Inter instances (SIL OFL 1.1) used only
by the generator, not shipped in the APK, credited in `COPYING.md`.
`fastlane/gpl-v3-logo.svg` adds the GPLv3 "Free as in Freedom" logo, embedded
recoloured white as a small licence badge in the bottom-left; it is one of the
official GNU licence logos by José Obed, is in the public domain, and is credited
in `COPYING.md`.

The copy addresses the German reader informally, writes "100 %" with a space,
gives the limits bullet a bar chart beneath a downward trend arrow, and leads the
free bullet with "free".

`android/Makefile` gains a `feature-graphics` target with an `rsvg-convert`
pre-flight mirroring the pdftoppm and Pillow checks. It reuses the captures from
`make screenshots` and captures nothing itself.

Two tooling fixes ride along. `validate-screenshots.py` uses
`../fastlane/metadata/android`, matching `crop-screenshots.py`, where the
pre-move path had failed the final validation step after capture, crop and PDF
rendering had all succeeded. `ScreenshotTest` reads screengrab's `testLocale`
argument in its actual camelCase spelling, with a lowercase fallback, so each
locale renders in its own language rather than every run falling back to the
device language; and the per-app locale is applied after each Activity launch
with the Activity foregrounded, because on API 33+ it is applied
asynchronously and seeding it beforehand left the first captured frame in the
device language.

`versionCode` 82 → 83, `versionName` 0.75.0 → 0.76.0, with localized store notes
in `changelogs/83.txt`.

---

## v0.75.0

Disable embedded Google dependency blob, ship SBOM inside the APK

The dependency-metadata block the Android Gradle Plugin embeds by default into
the APK signing block and the App Bundle is disabled through
`dependenciesInfo { }`. That block is encrypted with a Google public key and
readable only by Google Play; for an offline FOSS app it serves no purpose and is
opaque to users, and dropping it removes one non-transparent artefact from the
output.

The CycloneDX SBOM is packaged inside the release APK under
`assets/sbom/libellus-potionis-sbom.json`, so the bill of materials ships with
the artefact it describes; the standalone copy is unchanged. The packaged copy
stays reproducible: a generated-assets task normalises the wall-clock
`metadata.timestamp` with the same `tools/sbom-normalize.py` that `make sbom`
uses, before the asset merge, wired through `addGeneratedSourceDirectory` so it
runs as part of `mergeReleaseAssets`.

### Store screenshots

Four defects in the automated capture are fixed, all test-only.

`03_statistics` spans the full demo history again: `setUp()` clears the
statistics floor, which had defaulted to the APK install date — the capture day,
since screengrab reinstalls per locale — so `StatsViewModel` clamped the period
to a single day while the Calendar, which does not clamp, still showed the whole
month.

`04_drinks` waits through `waitUntilDrinksLoaded()` until the empty-state label
has disappeared, where a bare `waitForIdle()` returned before the first Room
emission and left the screen intermittently blank.

The en-US screenshots render in English: `setUp()` resolves the requested locale
to a supported language tag through the production `LocaleDetector.detect` and
sets both the `language` preference and the live per-app locale, as the last
setup step so it wins over the asynchronous first-launch detection. Relying on
screengrab's system-locale switch had no effect, because the app drives its UI
language through its own per-app locale.

Duplicate preset drinks are gone: `setUp()` awaits the presets before the
import, so the import's name-based deduplication matches and reuses them. The
prepopulation runs asynchronously when the database is first created, and the
screenshot run's first database access is the import itself, so the two raced.
The race is effectively unreachable through the normal UI.

`make screenshots` reads the device date back and prints a non-fatal warning when
it differs from `SCREENSHOT_DATE`, since the `adb shell date` pin silently
no-ops on non-rooted devices, and it runs a `bundle check` pre-flight in
`../fastlane` so a missing vendored bundle aborts immediately with an actionable
message instead of failing late with Error 127.

`versionCode` 81 → 82, `versionName` 0.74.0 → 0.75.0, with localized store notes
in `changelogs/82.txt`.

---

## v0.74.0

Prepare F-Droid packaging, localize store listing

A packaging, tooling and store-metadata release with no change to the app's
runtime behaviour: no file under `src/main/kotlin` was touched, the schema is
unchanged, and the shipped UI strings are identical to v0.73.4. The version is
bumped so the new store listings ship under their own `versionCode`.

The F-Droid reference recipe's `Builds:` block and its `CurrentVersion` and
`CurrentVersionCode` fields match `build.gradle.kts`, and `release-check.sh` §1
now cross-checks them, so the drift that had left the recipe pinned at 0.73.0
cannot silently reappear. `fdroid/README.md` carries a step-by-step fdroiddata
submission checklist and records that the first F-Droid-published version will
be cut as `1.0.0`, the reference recipe tracking the latest real release until
that tag exists.

`settings.gradle.kts` drops the `foojay-resolver-convention` plugin, which can
fetch a JDK over the network when a Java toolchain is requested — undesirable in
F-Droid's network-restricted build. The project declares no toolchain, so the
plugin never triggered; removing it deletes a latent network path.

`allWarningsAsErrors` is enabled for the Kotlin compiler, the sources being
warning-free, so a future compiler warning fails the build rather than
accumulating. It does not affect Gradle-level deprecation notices.

`navigation-compose` moves 2.8.9 → 2.9.7, and the three navigation lint checks
disabled as tooling-bug workarounds are re-enabled. The 2.8.9 detectors were
compiled against older Compose lint utilities and threw `NoClassDefFoundError`
under AGP 9.2, aborting the whole lint task; 2.9.7 ships detectors built against
the current API. `AppNav.kt` reports no findings, and the type-safe-route API is
unchanged between the two.

Store listings — title, short and full description, and the current changelog
note — are added for the 19 app languages that had none, so the listing covers
all 21 shipped languages. Screenshots are deliberately not duplicated per locale;
F-Droid falls back to the `en-US` images. The `release-check.sh` locale-parity
rule is relaxed accordingly: full changelog history is required only among the
history-bearing locales, while every other listing locale carries only the
current `versionCode` note.

Two test cleanups follow from `allWarningsAsErrors`: `AppViewModelFactoryTest`
drops five `assertTrue(vm is …)` assertions that are statically always true, the
retained `assertNotNull` covering construction, and `LocaleDetectorTest` uses
`Locale.of` in place of the single-argument constructor deprecated since JDK 19.

`import_success_replace` and `import_success_merge` become `<plurals>` across all
21 locales, resolved through a new `quantityStr` helper, and the
`PluralsCandidate` lint check that had masked them is re-enabled. Per-locale
forms mirror the CLDR categories and morphology of each locale's existing
`days` plural. The merge message pluralises on the first count only, the second
number's word being invariant in the sources. The remaining `%d`-bearing strings
are not pluralizable nouns — a backup version number, an invariant `MB` unit and
a `%d/7` ratio — and carry `tools:ignore="PluralsCandidate"`.

`versionCode` 80 → 81, `versionName` 0.73.4 → 0.74.0.

The Gradle deprecation "Using a Project object as a dependency notation" is
traced into AGP's own test-variant wiring rather than this project's build
scripts or any third-party plugin, is harmless on Gradle 9.6.1, and must be
cleared by a future AGP release.

---

## v0.73.4

Fix QA findings: locale-aware numbers, backup robustness, docs

User-visible numbers — grams, BAC, percentages, gram limits — follow the per-app
locale. They had been formatted with `String.format`, which follows
`Locale.getDefault()`, so a device whose system language differed from the in-app
language printed a wrong decimal separator beside correctly localized month
names. A new `l10n/NumberFormat.kt` adds `fmt0`, `fmt1` and `fmt2`, and every
read-only display on Today, Statistics, Calendar and Drinks, the shared chart and
list components and the PDF report passes `Context.formattingLocale()`. The CSV
export and the round-trip-parsed numeric input keep `Locale.ROOT` on purpose,
which also fixes the grams input dialog opening in an error state on a
comma-decimal system locale.

`BackupRepository.importMerge` reads the existing drink name-to-id snapshot
inside its transaction, mirroring `importReplace`. `buildIdMap` indexes freshly
inserted drinks by name within the same import, so a backup containing two
identically named new drinks no longer creates duplicate rows.
`StatsViewModel.uiState` seeds with the actual default period `MONTH`, so the
selector no longer flashes a one-frame `WEEK`.

`IEntryRepository.isDuplicate` and its implementations are removed as dead code;
the only MERGE de-duplication path calls `entryDao.countByTimestampAndDrink`
directly. `AlcoholCalculator.roundTo2Decimals`' KDoc says it rounds the BAC
value, not gram values, and `EntryRepository.addFromDrink`'s no longer mentions
the removed gender setting.

A translation QA pass against the English and German sources verified key
parity, apostrophe escaping, format placeholders, plural categories, brand and
URL invariants and newline parity. Two findings: `values-zh-rCN`'s
`drink_delete_blocked` carried a stray `%` and ASCII straight quotes, which
Android strips as verbatim delimiters, and now uses the curly quotes the English
source uses; and the CSV header `csv_col_alcohol_pct` is spelled out in every
locale to match the `Word_Word` style rather than carrying a literal `%`.

`NumberFormatTest` pins the decimal separator to the passed locale.
`LimitBarUiTest` pins the Compose Context configuration locale rather than only
`Locale.getDefault()`, since `LimitBar` now formats through
`Context.formattingLocale()`.

---

## v0.73.3

Fix QA findings: orphaned directory, German comments, docs, header style

`AppPreferences`' encrypted DataStore flow survives a transient read
`IOException` through a new, unit-tested `recoverIoAsEmpty(...)` helper that
emits `emptyPreferences()` and rethrows any non-IO error, so downstream `map`
falls back to the documented defaults. The `ReplaceFileCorruptionHandler` covers
only `CorruptionException` from the serializer, so a plain `IOException` on the
read path had propagated to every collector, including the start-up reads, and
crashed the app. This is the Jetpack DataStore guidance and matches the app's
degrade-never-crash policy.

`gradle.properties` sets `org.gradle.warning.mode=all`, so per-deprecation
detail is printed on every build in CI, `make` runs and Android Studio alike.
That made the cosmetic `stripDebugDebugSymbols` warning visible, so
`libandroidx.graphics.path.so` and `libdatastore_shared_counter.so` are listed
under `packaging.jniLibs.keepDebugSymbols`; the app ships no native code of its
own, these two transitive prebuilts cannot be stripped without an NDK toolchain
and are packaged unstripped anyway. They are named explicitly rather than
matched by a blanket glob, so a future unstrippable library resurfaces the
warning for a conscious decision.

`MarkdownText`'s pure helpers `decodeHtmlEntities` and `parseOrderedList` and the
`ORDERED_ITEM_RE` pattern become `internal` and `@VisibleForTesting`, so the
parsing logic is JVM-testable. New `MarkdownTextTest` covers entity decoding, the
ordered-item match boundary — a wrapped decimal is not a new item — and
continuation-line reflow, and a new `EntityMappingTest` covers the entity and
domain round trips and the unknown-category fallback to `OTHER`.

The annual info dialog shown on December 27th is removed with every artefact
that existed only for it: the app state and its `checkAnnualInfoDialog()`, the
`AlertDialog` block in `MainActivity`, the three strings in all 21 locales, the
`infoDialogShownYear` preference members, and the suppression in
`ScreenshotTest`. A leftover value in an existing DataStore file is ignored.

`res/raw-la/`, orphaned when Latin was dropped in v0.63.0, and
`ui/screen/Screens.kt`, a content-free documentation placeholder, are deleted.
The remaining German inline comments in `AndroidManifest.xml` and
`gradle.properties` are translated. `AppOverflowMenu.kt`, `MarkdownText.kt` and
`util/GplNotice.kt` adopt the project-standard block header,
`EntryRepository.mostRecentEntry()` gains its missing KDoc, and five stale
comments still claiming the entity mappers are file-private now point at the
`internal` extensions in `EntityMapping.kt`.

---

## v0.73.2

Move fastlane metadata to repo root for F-Droid

The fastlane tree moves from `android/fastlane/` to the repository root, so
F-Droid auto-discovers the store listing, per-version changelogs and screenshots;
it does not look inside the Gradle module tree. fastlane re-anchors to the
repository root, so paths into the Gradle build outputs in `Fastfile` and
`Screengrabfile` gain an `android/` prefix while the metadata output stays under
`fastlane/`, and the `android/`-side references point at `../fastlane/`. No
functional change.

---

## v0.73.1

Fix QA findings: locale, DRY mapping, docs, tests

`TodayViewModel` derives the monthly-average label's locale from
`AppSettings.language` rather than `Locale.getDefault()`, so on a device whose
system language differs from the in-app language the month name matches the rest
of the UI.

The four entity-to-domain conversion helpers live once as `internal` extensions
in a new `EntityMapping.kt` instead of being duplicated across `DrinkRepository`,
`EntryRepository` and `BackupRepository`. The pure locale-detection logic moves
out of `PotillusApp` into a new Android-free `LocaleDetector.detect()`
implementing the three-step BCP-47 match — full tag, base language, English —
covered by ten JVM tests spanning region variants, unsupported locales, empty
sets and case-insensitivity. A new `AppViewModelFactoryTest` verifies that each
registered ViewModel constructs with its injected types and that the factory's
`else` guard throws.

The four main screens gain the missing `@param` entries for `onOpenHelp`,
`onOpenCopyright` and `onLockApp`, and `Screens.kt` gains the package
declaration without which it sat in the default package.

---

## v0.73.0

Remove SQLCipher; add signing and Play tooling

### SQLCipher is gone

The database is a plain Room/SQLite file, relying on Android's file-based storage
encryption and the per-app sandbox at rest. The dependency, the explicit
`androidx.sqlite` pin, all passphrase machinery in `AppDatabase.kt`, the
`net.sqlcipher` ProGuard rules and the `SupportOpenHelperFactory` usage in
`MigrationTest` are removed with it, as is the device-transfer "Settings not
restored?" warning in all 21 locales, which existed only to diagnose a failed
passphrase migration.

There is no data migration. A plaintext SQLite engine cannot open the former
SQLCipher file, so on the first launch after upgrading `AppDatabase` runs a
one-shot `purgeLegacyEncryptedDatabase()`: keyed on the legacy passphrase
marker, it deletes the old encrypted database, the passphrase file and the unused
Keystore key, then lets Room create a fresh, empty one. The routine is idempotent
and a no-op on clean installs. Users upgrading from an encrypted build must
re-import their JSON backup.

`data_extraction_rules.xml` excludes the database and the preferences DataStore
from cloud backup and device transfer and no longer references the obsolete
passphrase file. With `allowBackup="false"` the rules stay inert, but they state
the intent plainly: the only supported way to move data between devices is the
user-initiated JSON backup. The user's guide Backup section is rewritten around
that and translated into all 21 languages.

### Signing and Play tooling

A `signingConfigs { create("release") }` block reads the key material from a
git-ignored `android/keystore.properties` or from environment variables, which
take precedence. The release build type applies the config only when the material
is present, so the default source build — and F-Droid, which signs the APK
itself — keeps producing the unsigned artifact.
`android/keystore.properties.example` documents the four keys and their
environment-variable equivalents.

`make bundle` builds the Android App Bundle Google Play requires for new apps
beside the existing APK target, both generating the SBOM. `make deploy` and a
fastlane `deploy` lane upload the signed AAB and the existing store metadata,
with the track and release status overridable and the service-account key path
read from `SUPPLY_JSON_KEY`. `make release` always invokes `assembleRelease` and
prints the produced artifact path rather than hard-coding a filename that changes
once a signing key is configured.

The guide and copyright resources are generated by two Gradle tasks wired into
`preBuild`, so a bare `./gradlew assembleRelease` — a fresh clone, CI, or an
F-Droid build that does not go through `make` — no longer fails on the missing,
git-ignored `R.raw.*` backing files. The F-Droid build recipe at
`fdroid/de.godisch.potillus.yml` is therefore a plain `gradle: [yes]` build, and
auto-updates track v-prefixed semver tags.

### Fixed

The `signingConfigs` block failed to compile, breaking every Gradle task at
configuration time: inside it the bare identifier `java` resolves to Gradle's
Java-plugin extension accessor, so `java.util.Properties()` was misparsed. An
explicit import fixes it.

Lint aborted the build on the legacy-database cleanup, where
`legacyPrefs.edit().clear().commit()` tripped both `ApplySharedPref` and
`UseKtx`. The call was redundant — the following `deleteSharedPreferences()`
removes the file and its in-memory state — and is dropped.

`MarkdownText` renders `**bold**` inline spans and ordered lists as separate,
hanging-indented items, both of which the rewritten Backup section uses and the
renderer would otherwise have shown literally or collapsed into one paragraph.

The screenshot test moves off the deprecated `createEmptyComposeRule` to its
`junit4.v2` replacement; the v2 rule uses a StandardTestDispatcher, and the test
already synchronizes explicitly. The `WrongStartDestinationType` navigation lint
detector is disabled with a documented rationale, since it throws
`NoClassDefFoundError` under the lint shipped with AGP 9.2 and aborts the
analysis; it is a tooling bug, not a finding in the navigation graph. The three
build-script tasks move off the `val name by tasks.registering { }`
property-delegate syntax Gradle 9.6 deprecated to `tasks.register<Type>("name")`.

Thirteen unused imports are removed, and two stale references in
`AppPreferences.kt` to the former SQLCipher passphrase key alias are corrected;
the preferences DataStore key is now the only persistent Keystore key the app
uses.

### Store metadata and dependencies

The long description no longer claims data is stored fully encrypted using
hardware-backed cryptography, which was true only of the former SQLCipher layer,
and describes the actual model instead. The `changelogs/76.txt` note states the
real user-facing change and warns that data from earlier versions is not migrated
automatically.

The Compose BOM moves 2026.04.01 → 2026.06.00 (core modules 1.11.0 → 1.11.3,
bug-fix only), the Gradle wrapper 9.4.1 → 9.6.1 by `distributionUrl` alone, and
Kotlin 2.3.21 → 2.4.0 — which touches both the catalog key and the hard-coded
`kotlin-gradle-plugin` classpath literal in the root `build.gradle.kts`, since
AGP 9's built-in Kotlin is pinned there. KSP follows to 2.3.9, the release the
Kotlin 2.4.0 notes pair with; the kotlinx-serialization runtime stays at 1.11.0.

`versionCode` 75 → 76, `versionName` 0.72.0 → 0.73.0.

The Play feature graphic is a design asset and cannot be generated here; the
placeholder description still applies. With SQLCipher removed the build ships no
prebuilt native binary.

---

## v0.72.0

Automate Play-Store screenshots via screengrab

`make screenshots` captures the six in-app phone screenshots in both store
locales through fastlane screengrab and an Espresso/Compose UI test, then renders
the two pages of the localized PDF report as screenshots 7 and 8, placing all
eight assets per locale into the fastlane metadata tree.

`ScreenshotTest` seeds the database from the canonical demo fixture, copied into
the androidTest assets at build time by a new `copyDemoBackupFixture` Gradle
task, fixes the theme per phase — screenshots 1 to 3 light, 4 to 6 dark — and
navigates Today, Calendar, Statistics, Drinks, the add-drink dialog and Settings.
It selects navigation targets by their localized label text plus a click action,
the production UI carrying no test tags, so it works unchanged in both locales. A
`ScreenshotOnly` annotation lets the suite be excluded from an ordinary device-test
run through `make test-device EXCLUDE_SCREENSHOTS=1`; by default it runs as part
of `connectedDebugAndroidTest`, so a broken capture flow is caught by the normal
gate.

`tools/validate-screenshots.py` fails the run unless every captured asset meets
Play's phone-screenshot requirements: PNG, each side 320 to 3840 px, aspect ratio
at most 2:1, exactly eight per locale. The six in-app shots are bottom-cropped to
at most 2:1, removing the navigation bar; the report pages keep their A4 ratio and
are never cropped. screengrab's timestamp suffix is disabled, so capture
overwrites the files in place and the committed assets can be regenerated without
churn.

Status-bar hygiene uses the Android Demo Mode API driven from the Makefile over
adb — clock 10:00, full battery, full Wi-Fi, no notifications — with a bash EXIT
trap that disables it again even if the run fails. The device date is pinned
best-effort, which needs an emulator or a rooted build. The
`tools.fastlane:screengrab` and `androidx.test.uiautomator` androidTest
dependencies are added, the UiAutomator full-screen strategy being required for
the cleaned status bar to be part of the saved image, and `FLAG_SECURE` is
cleared for the run by enabling the existing `allowScreenshots` preference from
the test rather than by changing production code.

`versionCode` 74 → 75, `versionName` 0.71.1 → 0.72.0.

---

## v0.71.1

Fix Today-screen trend-arrow baseline

The Today screen's month-trend arrow is `bodyMedium` bold, so it shares the
adjacent "g/day" label's baseline and size. It had been `titleMedium`, and
`Alignment.Bottom` aligns text bounding boxes rather than baselines, so the
larger style left the arrow sitting off the baseline.

`release-check.sh` §1 requires every `## vX.Y.Z` heading added to this changelog
to be accompanied by exactly one increment of `versionCode`, derived from a fixed
reference point in `android/version-anchor` plus the number of entries above it.

`versionCode` 72 → 74, `versionName` 0.71.0 → 0.71.1, with store notes for both
new codes.

---

## v0.71.0

Reorder PDF KPIs; show longest abstinence streak

The PDF report's KPI tiles are reordered so abstinent days and the longest
abstinence phase appear together in the first row, followed by drinking days and
total alcohol, with the peak and average/median rows regrouped accordingly. The
previously empty tile beside abstinent days shows the longest continuous
abstinence streak within the report period. The `max per day` and `max per 7
days` tiles turn red when their value exceeds the configured limit, matching the
existing violation tiles. The page-1 long-term trend chart's heading reads
"Ø Grams/Day" in all 21 locales — the bars and the dashed reference line have
always been per-day averages against the daily limit, independent of the bucket
width — and each bar carries its per-day average on top, blank for abstinent
buckets, matching the page-2 charts.

Settings gains an "Allow Screenshots" toggle under a new "Security" section
placed above Appearance, which now covers the colour scheme and language only.
With the toggle off, the default, `FLAG_SECURE` blocks screenshots and screen
recordings; turning it on clears the flag reactively through the `settingsFlow`
collector without a restart. New `security` and toggle strings ship in all 21
locales.

The Today screen's second row shows today's own total in grams, styled like the
right column's headline figure, in place of the static word "Alcohol", and the
month-trend arrow is bold. The Statistics screen's initial period on first start
is `MONTH` rather than `WEEK`. The document viewer decodes nine HTML character
entities before rendering, so `&copy;` in `LICENSE.md` appears as ©.

---

## v0.70.0

Add monthly trend arrow; fair per-day trend

The Today screen shows a trend arrow beside the month's per-day average: a green
↓ when this month averages fewer grams per day than the baseline, a red ↑ when
more, and nothing at all when the two are equal at 0.1 g precision or there is no
baseline yet. The baseline is the per-day average from the configured statistics
start date up to the day before this month, read by widening the monthly
daily-summary query. It is backed by a new shared `Trend` domain type and a
`monthTrend` field on `TodayUiState`.

The statistics trend is computed on per-day averages rather than period totals
and uses the same `Trend` rule, so an in-progress period compares fairly with the
previous one: the current period is divided by its effective days, today counting
only once it is a drink day, and the previous complete period by its full day
count. A part-month therefore no longer looks artificially lower than a full
previous month, and the two screens always agree. The 7-day view is unaffected in
practice, being two equal-length windows.

The page-1 trend chart draws its x-axis labels in a separate row below the
baseline, matching the page-2 charts, so a label is never overlapped by its bar.
The English report labels use sentence case — "Total alcohol", "Ø per day",
"Longest abstinence phase" — with lowercase units after a slash; the document
title and section headings keep their styling, and localized values are
unchanged, German "g/Tag" staying capitalized because "Tag" is a noun.

Day counts are pluralized through a shared `days` resource with the correct forms
for every locale, including the multi-form Slavic plurals; the report and the
Statistics streaks had always used the plural. The unused `pdf_days_suffix` and
`days_count` strings are removed.

`release-check.sh` §9, backed by `tools/md-syntax.py`, verifies that
`CHANGELOG.md`, `README.md`, `CONTRIBUTING.md` and the rendered guides are well
formed: inline-code backticks and `*` emphasis balanced, and code-looking tokens
wrapped in backticks so a stray marker cannot turn into accidental emphasis in
the in-app renderer. Changelog headings must read `## vMAJOR.MINOR.PATCH` in
descending order. The verbatim GPL texts are excluded. Several identifiers in
recent entries are wrapped in backticks to satisfy it.

`versionCode` 71 → 72, `versionName` 0.69.0 → 0.70.0.

---

## v0.69.0

Label chart bars; add monthly per-day average

On the two sparse chart axes each bar is annotated with its grams per day,
commercially rounded to a whole number and printed without a unit: the 7-day view
labels each daily bar with that day's grams, the year view each monthly bar with
the month's grams averaged over its calendar days. The dense month view stays
unlabelled.

The year view no longer draws the dashed daily-limit line or the over-limit red
colouring, a month's per-day average not being comparable against a daily limit.
Bar heights remain the per-day average on the same scale as the other views, so a
bar's height matches its label.

The Today card's right column shows the current month's average grams per day
under an "Ø <month>" caption with the full localized month name. The left column
keeps its caption but no longer repeats today's gram figure, which already
appears on the daily-limit bar just below. New `avg_of_month`, `alcohol` and
`grams_per_day` strings ship in all locales; the unused `grams_alcohol` is
removed.

Per-day averages agree across the app. The Today card, the Statistics summary and
the year-view bar for the current month had used different denominators, so the
same month could read 18.8 against 19.6. They share one rule in
`DayResolver.effectivePeriodDays`: the current day counts only once a drink has
been logged on it. `bucketize` gained an optional `inProgressDay` parameter for
this; the PDF export passes none and is unchanged.

`versionCode` 70 → 71, `versionName` 0.68.2 → 0.69.0.

---

## v0.68.2

Rename app, fix year chart, add SBOM tooling

The Statistics YEAR view aggregates by calendar month, at most twelve bars and
exactly one per month. It had aggregated by ISO week while labelling each weekly
bar with its month name, so a single month could appear as several identically
named bars. The PDF export is deliberately unchanged: it derives its granularity
from the chosen span, so a one-year report still shows weekly bars.

The user-visible application name is "Libellus Potionis"; the informal "Potillus"
nickname is dropped from the `app_name` string in every locale, the project
document titles, all header comments, `GplNotice.HEADER_LINES` — reproduced in
exported reports and JSON backups — the rendered guide titles and the store
descriptions. The technical identifiers stay: the application id and Kotlin
package, the repository URL and the tarball name, so the update channel, the
signing identity and existing installations are unaffected.

The CycloneDX Gradle plugin emits a CycloneDX 1.6 SBOM for the release runtime
classpath, exactly the components packaged in the release APK. No SBOM is
committed; it is generated on demand by `make sbom` and as part of `make
release`. Generation is pinned to the resolved `releaseRuntimeClasspath`, which
avoids the variant-ambiguity resolution error. For reproducibility the random
serial number is disabled and the volatile `metadata.timestamp` is normalized by
the new `tools/sbom-normalize.py`, honouring `SOURCE_DATE_EPOCH` when set and
dropping the timestamp otherwise. The plugin is build-time only, so the APK is
unchanged.

`versionCode` 69 → 70, `versionName` 0.68.1 → 0.68.2.

---

## v0.68.1

Fix lock bypass on warm start; add manual lock

The biometric app lock could be bypassed after a warm start. `backgroundedAt` was
a per-Activity field, reset to 0 on the recreated Activity, while
`isAuthenticatedThisSession` is process-global and still true — so `onCreate`'s
gate, checking only the boolean, skipped the prompt, and `onStart` saw a zero
timestamp and skipped too. `backgroundedAt` is now process-global and the
staleness check runs in `onCreate` as well as `onStart`, so re-authentication is
required once the threshold has elapsed regardless of Activity recreation. The
timestamp is consumed on a valid foreground return, so a later configuration
change cannot re-prompt spuriously. It reproduces deterministically with
Developer Options → "Don't keep activities".

The shared overflow menu gains a "Lock app" entry that clears the authenticated
state and prompts at once. It works regardless of the auto-lock setting as long
as a biometric or device credential is available, and is hidden when no
authenticator is enrolled, so it can never strand the user. The new `lock_app`
string ships in all 21 locales.

---

## v0.68.0

Add biometric toggle auth; fix bugs and lint

Toggling the biometric app lock requires biometric or device-credential
authorisation in both directions, and the switch changes only when authentication
succeeds; cancelling leaves the setting unchanged, the switch being bound to the
stored value. `MainActivity` exposes a dedicated `authenticateForToggle()` that,
unlike the app-start gate, never finishes the Activity on cancel. It reuses the
existing prompt strings, so no new translations are needed, and the toggle is
left unchanged when no authenticator is enrolled.

The CSV export formats the grams column with `Locale.ROOT`. The default-locale
formatter produced a comma on comma-decimal locales, and that unquoted comma
split the value across two columns, misaligning every following one. The
localised column headers are escaped too, so a comma in a translated caption
cannot add a stray column. Importing a JSON backup runs the file read and parse
on `Dispatchers.IO`, removing an ANR risk on large backups and matching the
export path.

The lock reflects the live preference: enabling it during a running session arms
the inactivity re-authentication immediately rather than only after the next cold
start, `MainActivity` keeping its cached flag in sync through a
`repeatOnLifecycle` collector.

`WebViewPdfPrinter` creates its off-screen WebView from the application context
and abandons any still-pending previous WebView before starting a new job,
preventing an Activity context leak when the page-finished callback never fires.
`DocumentViewerScreen` reads its bundled raw resource on `Dispatchers.IO` through
`produceState` rather than synchronously during composition.

`data_extraction_rules.xml` uses `domain="file"` with the real on-disk path
rather than an invalid `domain="datastore"`, which lint rejected and which would
have matched nothing had `allowBackup` ever been turned on, defeating the
intended exclusion. No runtime behaviour changes while `allowBackup` stays false.

Lint warnings are driven to zero and the check becomes a strict gate through
`warningsAsErrors = true`. In the sources: the launcher, limit and chart
composables declare `modifier` as the first optional parameter;
`DocumentViewerScreen` reads the guide via `LocalResources.current` so a
configuration change re-invalidates it; the passphrase write uses the KTX
`edit(commit = true)` form, keeping the deliberate synchronous commit; the
adaptive-icon XMLs move out of `mipmap-anydpi-v26`, minSdk 30 making the
qualifier redundant, and the legacy density launcher bitmaps are deleted as dead
fallbacks; the `localeConfig` attribute carries `tools:targetApi="33"`; the
`WebViewPdfPrinter` singleton carries a documented `@SuppressLint`; and five
genuinely unused strings are removed from all 21 locales. Opted out by documented
policy rather than a baseline: the version-update nags, the launcher-icon design
hints and `PluralsCandidate`, each with a rationale, with dependency upgrades and
a proper plural conversion tracked as separate changes.

New tests: `ChartBucketingTest` for gap filling, per-day averaging, period
clamping and month snapping; `CsvExporterBuildTest`, run under `Locale.GERMANY`,
for the `Locale.ROOT` formatting, the eight-column invariant and header escaping,
which required extracting the CSV assembly into an internal, Context-free
`buildCsv()`; and `LimitBarUiTest` plus `LocaleFormattingInstrumentedTest`.

The stale string-key count comments are corrected, the manifest's biometric
comment says minSdk 30, and the remaining German inline comments are translated.

---

## v0.67.2

Fix locale-sensitive text to follow the in-app language

Month names, weekday names and long dates follow the in-app language rather than
the system language. `AppCompatDelegate.setApplicationLocales` re-configures the
Context but not the JVM default, so `Locale.getDefault()` still reflected the
system locale: with the app set to English the PDF report printed German month
names beside its English labels.

`PdfReportBuilder` builds its two locale-sensitive formatters per report from the
Context's locale, and the weekday and month axis labels use the same. They had
also been object-level values frozen at class-load time, so this removes a
stale-locale hazard as well. `CalendarScreen`, `StatsScreen` and `SettingsScreen`
format with the per-app locale taken from the Compose `LocalContext`.

A new `Context.formattingLocale()` in `l10n/LocaleSupport.kt` is the single
documented source for the locale to format user-visible values in, resolved from
the Context configuration so it always agrees with the localized string
resources. All formatting code goes through it.

`versionCode` 66 → 67, `versionName` 0.67.1 → 0.67.2.

---

## v0.67.1

Resolve character entities in the Markdown viewer

`MarkdownText` decodes HTML and Markdown character entities — named and numeric —
in headings and visible text, never in URLs. Unknown names and out-of-range
numeric values are left verbatim, and a stray ampersand without a trailing
semicolon is untouched.

`release-check.sh` §1 verifies locale parity: all changelog directories must
carry the same set of `<versionCode>.txt` notes, so a release note added to one
language but forgotten in another is caught before release. Previously only the
current versionCode's presence per locale was checked. A maintainer reminder is
added at the top of this file.

`versionCode` 65 → 66, `versionName` 0.67.0 → 0.67.1.

---

## v0.67.0

Rename the License menu entry to Copyright

The overflow-menu entry reads "Copyright" and the viewer shows the project's
`COPYING.md` notice together with the full `LICENSE.md` GPL text, joined at build
time and separated by a blank line, still untranslated. The string key `license`
becomes `copyright` in all 21 locales with the deliberately untranslated value,
and `Screen.License`, `onOpenLicense` and `R.raw.license` are renamed to match, so
no identifier still calls the feature a licence. The Makefile rule concatenates
the two documents into `raw/copyright.md`, and `check-guides`, `.gitignore`,
`distclean` and the `prereq` list follow.

`MarkdownText` gives level-1 headings a 20 dp top inset, larger than the 16 dp of
`##`, so the `# GNU GENERAL PUBLIC LICENSE` heading at the document seam no longer
sits closer to the text above it than the `## Preamble` heading below.

A new `android/fastlane/metadata/android/` tree carries the `en-US` and `de-DE`
store listings: title, short and full description, and a per-versionCode release
note, each within the store limits. The texts derive from `README.md` and
deliberately omit the version to avoid churn. The `images/` folder per locale
carries the launcher icon and documented placeholders for the binary assets that
must be supplied before publishing.

`release-check.sh` moves to `android/tools/`, re-anchors to `android/`, gains a
`--Werror` switch that makes warnings fail, and is wired into `prereq`, so the
full read-only gate runs on every build. §1 additionally verifies that every
fastlane locale ships a changelog note matching the current `versionCode`. The
§5 documentation heuristic skips multi-line annotation arguments, so KDoc placed
above an annotation is found, and excludes local functions as it already excluded
private ones, which removes two false positives. The Makefile `version-check`
target is dropped as fully covered by §1.

The README gains a "Source Code Documentation" section explaining the
KDoc-everywhere style and how the gate enforces it.

`versionCode` 64 → 65, `versionName` 0.66.0 → 0.67.0.

---

## v0.66.0

Improve the PDF report's charts and KPIs

The time-of-day chart labels every hour beneath the axis. It is split into a bars
row and a separate axis row rendered below the baseline, where the labels had sat
inside the plot area and were overlapped by tall bars, and all 24 hours are
labelled where previously only every third was. The weekday profile becomes a bar
chart in the same shape, with the average value above each bar and the weekday
names on the axis row; bar heights leave 15 % headroom so the tallest bar's label
still fits.

The category breakdown is a half-width table paired with a colour-matched donut
built with the stroke-dasharray technique, so it needs no raster image and
survives the template's HTML escaping, with a colour swatch in each table row as
an inline legend. The donut had rendered every slice as a full ring: the dash
values were formatted with the default locale, so on a comma-decimal device SVG
parsed `40,00 60,00` as four numbers and painted the whole circle. The geometry
is formatted with `Locale.ROOT`.

Two peak KPIs are added: `maxPerDay`, the heaviest single calendar day, and
`maxPer7Days`, the heaviest rolling seven-day window — the whole-period total
when the period is shorter than seven days. Both strings are translated into all
21 locales.

The on-screen time-of-day chart shows eight three-hour buckets, each the average
grams per day over the period, using the same `effectivePeriodDays` divisor as
the per-day rate; the PDF keeps all 24 hourly bars. Limit lines are red dashed
rather than amber in both the PDF and the app, matching the over-limit cue. Body
weight is integer-only in Settings and in the report.

A once-per-year info dialog is shown when the app is opened on December 27th; a
missed day is not caught up later. The decision is made once per process start
and the last shown year is persisted, with the three strings in all 21 locales.

---

## v0.65.0

Add hour and weekday charts; add median KPIs

A new reusable `ValueBarChart` — no time axis, no limit line, no abstinence ticks
— backs two new Statistics cards: a 24-hour chart of grams per clock hour and a
weekday chart of average grams per weekday, rotated to the locale's first
weekday. A bar of value at most zero is drawn as an empty slot, which is how "no
data for this slot" reads. Each card is hidden when it has no data.
`StatsUiState` gains `hourlyGrams`, `weekdayOrder` and `weekdayAverages`, where
null means the weekday was never a drink day, all computed in the existing
`combine`.

The PDF report replaces the "Ø first/last drink" and before/after-17:00 figures
with a 24-bar chart of grams per clock hour, mirroring the on-screen one, and
prints four median KPIs beside the means: median per day, median per drinking
day, average and median drinking days per month. Medians are robust to the
occasional very heavy day that inflates an average. The six new strings are
translated into all 21 locales and the four now-unused ones removed, so the key
count moves uniformly.

A new `PdfTemplatePlaceholderTest` reads the template and the builder as source
and fails the build if any `{{PLACEHOLDER}}` used in the template is never
initialised, which would otherwise print raw in the PDF. Comments are stripped
before scanning, and a second test asserts that a few structural placeholders are
seen, so a broken scan cannot pass vacuously.

The monthly Ø g/day divides each month's grams by the days of that month that
actually fall inside the report period, not by the full calendar-month length; a
started first or last month had counted its unrecorded days as abstinent and
deflated the figure.

The light-theme caution colour moves from amber-700 to gold `#A67C00`. The amber
still read as orange-red on the small dot, its red channel dominating its green,
sitting too close to the danger red. The gold clears 3.35:1 against the light
background, above the 3:1 a non-text indicator needs, and 2.38:1 against the
danger red. Dark mode is unchanged.

The PDF's second footer names the running Android version from
`Build.VERSION.RELEASE`, falling back to the numeric API level when blank.

Three `StatsViewModelTest` cases are hardened against two time-dependent
fragilities: they dated their entry with `LocalDate.now()` while the ViewModel
derives its period from the logical day, so a run between midnight and 04:00 put
the entry outside the period; and they assumed the first Turbine emission is the
computed state rather than the `stateIn` seed, for which an `awaitComputed()`
helper now skips any leading seed.

---

## v0.64.0

Rework the consumption chart onto a real time axis

A new Android-free `domain/ChartBucketing.kt`, shared by the Statistics screen
and the PDF export, expands the sparse per-day summaries into a continuous,
gap-free series covering every day in the period, so abstinent days become
explicit zero buckets. A bucket may be a day, a week or a month, and its value is
the mean grams per calendar day inside it — a per-day average rather than a
bucket total, so the dashed daily-limit line stays directly comparable at every
granularity. It is pure `java.time` and plain data, hence JVM-testable.

WEEK and MONTH render one bar per day and YEAR aggregates into weekly buckets.
Days with zero consumption are drawn as a small green tick at the baseline, so
"recorded, nothing consumed" is visually distinct from a tiny bar, and axis
labels are thinned for dense charts: up to twelve buckets get one aligned label
each, beyond that a handful of evenly spaced labels. `AlcoholBarChart` takes a
bucket list and a label function in place of the daily summaries.

The PDF's monthly-average trend chart is replaced by the same time-axis chart and
is shown unconditionally, where it had been hidden below two months of data. The
export picks its granularity from the recorded span: daily up to 35 days, weekly
up to 366, monthly beyond. The existing monthly list is kept for the table.

The report's footers are overhauled. Footer 1, the medical disclaimer, is
translated into all 21 locales with new wording. Footer 2 is English-only and
never translated, built in code rather than from a string resource, and names the
version shortened to `MAJOR.MINOR.PATCH` so a debug build's suffix is stripped;
the separate running GPL footer is removed and its no-warranty notice folded in.
Both are pinned to the bottom of their page through per-page flex wrappers. The
pinning is best-effort and tuned for A4, so on US Letter the `min-height` may need
adjusting.

The light-theme caution colour moves from amber-800 to amber-700. On a 12 dp dot
the very dark amber-800 was almost indistinguishable from the danger red, sharing
its red channel with little green, so the yellow state read as red; amber-700
keeps a clearly amber hue and clears 4.40:1 against the light background. Dark
mode is unchanged.

The 19 non-German and non-English `pdf_footer1` translations are best-effort and
await native review, consistent with the project's translation policy.

---

## v0.63.1

Enable core library desugaring to fix a crash

The app crashed with `NoSuchMethodError: No virtual method datesUntil(...)`
shortly after a non-Today main screen was shown. On Android `java.time` comes
from the updatable ART mainline module, and `datesUntil()` was backported into a
later revision, so at one and the same API level a device whose module has been
updated exposes the method while an older emulator image does not — which is why
it reproduced on an API 30 emulator but not on physical devices.

Core library desugaring removes the dependency on the device's module version:
D8/R8 rewrites the affected `java.*` calls against the bundled
`desugar_jdk_libs`, shipped inside the APK and available uniformly down to
`minSdk`. That fixes the crashing call site and every other Java 9+ `java.time`
usage at once, with no change to the Kotlin sources.
`isCoreLibraryDesugaringEnabled` is set and the dependency added at 2.1.5, whose
2.x line requires AGP 7.4.0 or later.

The effects are a small APK-size increase, only the used classes surviving R8,
and an additional L8 dex step at build time. The supported device range is
unchanged: desugaring works down to API 21, well below the project's minSdk 30.

`versionCode` 60 → 61, `versionName` 0.63.0 → 0.63.1.

---

## v0.63.0

Reduce the shipped languages to 21

The app ships 21 languages — 20 locales plus the English base: `cs da de el en es
fr it ja ko nb nl pl pt pt-BR ro ru sv uk zh-CN zh-TW`. It had shipped 51, but
only a subset could be reviewed to a level the project is willing to vouch for
across both the UI strings and the long-form guide, and shipping a translation
that cannot be quality-assured is worse than not shipping it. The other 31
languages are dropped from `values-XX/`, `locale_config.xml` and
`SupportedLocales.kt`, Latin's guide template and rendered guide with them.

Seven new user-guide translations are authored from the German source with the
token placeholders preserved, so every kept language ships a guide. The English
base stays listed as `en` without a `values-en/`, resolving to the base
resources, which remains best practice for the per-app language picker.

A build-time parity guard requires the guide-template language set and the
string-resource language set to be identical, both counting the base as English.
It is enforced on two layers: `render-guide.py` aborts with a precise diff in
both write and `--check` modes, and a new `LocaleSyncTest` case does the same on
the Gradle path.

`versionCode` 59 → 60, `versionName` 0.62.1 → 0.63.0.

---

## v0.62.1

Unify the danger red; add the PDF file extension

`PdfReportBuilder.jobName()` appends `.pdf`, so the system "Save as PDF" dialog
pre-fills a complete file name; it derives that name from the print-job name,
which had carried no extension.

The over-limit chart bars, the over-limit statistics and the rising-trend
percentage use `dangerRedColor()` — the saturated red already used by the delete
icons, traffic-light bullets and calendar over-limit dots — rather than the
softer Material `error` colour. Export-error text keeps `errorColor()`, denoting
a genuine error state rather than a statistic.

The overflow menu's License entry uses the open-book glyph and Help a
medical-cross glyph, which inherits the menu's content colour rather than being
drawn red. The German user's guide and `values-de/strings.xml` are revised.

`versionCode` 58 → 59, `versionName` 0.62.0 → 0.62.1.

---

## v0.62.0

Replace the calendar week with a gliding 7-day window

Every consumption metric uses a trailing 7-day window — today plus the previous
six calendar days — evaluated continuously. The weekly gram limit and the
drink-day limit had been evaluated per calendar week with a user-chosen reset
weekday, which is easy to game by splitting heavy drinking across the boundary
and does not reflect continuous risk. A trailing window never resets, is
stricter, and matches how low-risk-drinking guidance is generally framed.

The Today screen's totals and range label, the Statistics WEEK period — now
labelled "7 days", with its previous period being the seven days before it — and
the traffic light and days-over-limit figures all follow.
`AlcoholCalculator.countLimitViolations` is rewritten from a per-calendar-week
grouping into an O(n) two-pointer sliding window and no longer takes a
`weekStartDay`. The calendar grid and the PDF weekday profile keep a fixed first
weekday for layout only, now following the device locale through the new
`DayResolver.firstDayOfWeekIso()`.

The "Week starts on" setting is removed with its entire plumbing: the settings
field, the preference key whose stored value is now ignored — no migration and no
schema change — the setter and the UI control. The obsolete `week_starts_on`
string is deleted from the base locale and all 51 translations. Eight
user-facing strings are reworded from "week" to "7 days" in every bundled locale,
preserving each language's existing terminology and swapping only the period
token. The in-app guide and the crypto-key startup message keep their English
fallback by agreement.

`AlcoholCalculatorTest`'s violation suite is rewritten for the rolling window,
adding window-boundary inclusivity — a 6-day gap shares a window, a 7-day gap
does not — no gram carry-over beyond the window, and the drink-day count not
resetting across a weekday boundary; the expected values were cross-checked
against an independent reference implementation. `PdfReportDataTest`'s weekday
order asserts against `DayResolver.firstDayOfWeekIso()` rather than a hard-coded
Monday, so it passes regardless of the build machine's default locale.

---

## v0.61.3

Fix the PDF export and the limit-bar threshold

The PDF export had failed on every device since v0.61.0. `SimpleTemplate`'s
placeholder regex left its closing braces unescaped; the desktop JVM regex engine
that unit tests run against accepts a bare `}`, but Android's stricter ICU engine
rejects it, which threw inside the static initialiser, failed every
`buildHtml` call, and was swallowed by `runCatching` into a brief "export failed"
banner. All braces are escaped, which is valid under both engines. A new
`SimpleTemplateInstrumentedTest` exercises `render` on-device, so this
JVM-against-ICU divergence is caught by the device-test phase in future; the JVM
unit test cannot detect it.

`LimitBar` and `DrinkDaysBar` turn red only when a limit is strictly exceeded,
matching `countLimitViolations` and the calendar and chart markers; they had
coloured red at exactly the limit. Reaching a limit exactly stays amber.

The documentation block at the top of `report_template.html` described its
`repeat` example with literal HTML-comment delimiters, whose first close sequence
ended the doc comment early and leaked prose into the rendered page; the example
avoids literal delimiters now. This had been masked by the export crashing before
it could render.

Two build-tooling paths missed by the move into `android/` are corrected:
`release-check.sh` reads `../CHANGELOG.md` and `../README.md`, and the root
`Makefile` `install` target points at `android/app/build/...`.

---

## v0.61.2

- Moved Android code base into subdirectory android/.

---

## v0.61.1

Make abstinence and average calculations agree

The abstinent-days KPI, the average per day and the current and longest
abstinence streaks follow one rule for the in-progress day. A day counts as a
drink day the moment its first drink is logged, at which point today joins the
observable period with the amount consumed so far. A day counts as abstinent only
once it has finished alcohol-free, having reached the next day-change time
without consumption. While today has no drink it is undetermined and stays out of
the period entirely. Formally
`effectivePeriodDays = completedDays + (today is a drink day ? 1 : 0)`, and every
rate and count derives from it.

`DayResolver`'s tail-gap calculation subtracts the last drink day, floored at
zero, matching the inter-drink-gap convention: both endpoints must be excluded,
the last drink day being itself a drink day and today still in progress. A last
drink two days ago with none since therefore reads 1, the single completed dry
day, where it had read 2.

`avgPerDay` divides by `effectivePeriodDays`, having divided by the completed days
only — so logging a drink today spread today's grams over a period that did not
include today, overstating the average and showing zero when the period was just
today. `abstinentDays` is `effectivePeriodDays − drinkDays`, so the in-progress
day is never counted as abstinent; per-drink-day averaging still includes today.

The behaviour deliberately differs from a naive "days since last drink": the day
immediately after a drink day shows 0 and becomes 1 only once the following day
has also finished dry. That is the rule which makes the KPI and the streaks
consistent.

Four `DayResolverTest` expectations move to the completed-day semantics, with
regression tests for the reported scenario and a `StatsViewModelTest` case
asserting that a drink logged today extends the period.

---

## v0.61.0

Rework the PDF report onto a hand-editable template

The report's layout can be edited without touching report code. It is authored as
an HTML/CSS template under `app/src/main/assets/report_template.html`, which
defines the two-page A4 structure and styling with `{{PLACEHOLDER}}` tokens and
`<!-- repeat:NAME -->` row blocks, its contract documented in the file header;
editing it needs only a rebuild. Computed numbers and localised labels are
injected at runtime, and the result becomes a PDF through the Android system
print dialog: the HTML is loaded into an off-screen `WebView` and printed through
`PrintManager`, the user picking "Save as PDF" and the destination in the system
UI. No third-party PDF library and no extra permission were added.

Three new pieces carry it: `PdfReportData` computes every figure Context-free,
reusing `AlcoholCalculator` and `DayResolver` so the PDF and the on-screen
statistics still agree exactly; `SimpleTemplate` is a dependency-free templating
engine with scalar placeholders, repeat blocks and HTML escaping; and
`PdfReportBuilder` resolves the localised labels and fills the template. Both
pure pieces are JVM-unit-tested. The previous `PdfExporter`, which hard-coded the
layout in Kotlin and drew each element by pixel coordinate, is removed.

The export no longer writes a file straight to Downloads or opens a share sheet;
saving and sharing happen in the print dialog. CSV export is unchanged. Long
monthly tables are no longer truncated to a fixed row budget, the HTML report
paginating automatically. The now-unreachable PDF branch is removed from the
Statistics share effect, and the stale KDoc in `ExportResult.kt` and
`GplNotice.kt` that referenced the deleted exporter is corrected.

The `WebView` and `PrintManager` path is runtime-only and cannot be exercised in
unit tests; it needs verification on a device.

---

## v0.60.1

Lower minSdk from 35 to 30

`minSdk` moves from 35 to 30, roughly doubling the reachable install base while
`targetSdk` stays at 36. No functional code changed. The previous floor was a
policy choice rather than a technical requirement: the codebase contains no
`Build.VERSION.SDK_INT`, `@RequiresApi` or `@TargetApi` usage, and every
version-sensitive API it relies on is available at API 30 or lower — MediaStore
Downloads with `RELATIVE_PATH` at 29, Keystore AES-256-GCM and
`androidx.biometric` at 23, the edge-to-edge insets at all levels, and
`AppCompatDelegate` locale switching back-ported.

API 30 is a principled floor rather than the lowest possible one: 29 is the level
at which the exporters can write to the public Downloads folder through
`MediaStore` without any storage permission, so going lower would force a storage
permission and break the minimal-permission design.

Two things degrade gracefully on API 30 to 32 without a code change. The system
per-app language picker is an API 33+ feature and is absent there, but the in-app
language selector works on every supported version. Cloud and device-transfer
backup is disabled on all versions, so `dataExtractionRules` being ignored below
API 31 has no privacy impact; the manifest says so.

The `minSdk` rationale comment in `app/build.gradle.kts` enumerates each
version-sensitive API with its availability level, and the README gains a
"Supported Android versions" section.

`versionCode` 53 → 54, `versionName` 0.60.0 → 0.60.1.

---

## v0.60.0

Fix invisible limit exceedance from rounding

Alcohol grams are computed at 0.1 g precision. `calculateGrams` had rounded to
two decimals, so 188 ml at 13.5 % stored 20.02 g while the UI displayed
"20.0 g" — and the daily-limit and binge checks compared the stored value, so a
20 g limit read as exceeded on a screen that showed exactly 20.0. Display and
comparison now use the same number. BAC keeps its 0.01 ‰ precision. There is no
data migration: only newly logged entries are stored at 0.1 g, existing ones
being left to a manual backup edit.

The version strings had drifted and are corrected: `versionName` was still
0.58.0 and the ProGuard header still v0.56.0. A new `version-check` Make target,
wired into `prereq`, reads the version from the top changelog entry and fails the
build when `build.gradle.kts`, the ProGuard header or the README title disagree,
so drift is caught on every local build rather than only at the release gate. The
README carries the version under its title, having had none.

`tools/render-guide.py` discovers languages from the `docs/guide/usersguide*.md.in`
templates instead of a hard-coded list, so adding a language needs no script
edit. The English default template is the code-less `usersguide.md.in`, mapping
to the unqualified resources, while a tag maps to the Android region form.
Outputs are regenerated on a timestamp basis — rewritten only when the template
or the matching `strings.xml` is newer — while `--check` still compares content.

The device-transfer warning is translated into 26 locales, having been English
everywhere. The wording uses the app's neutral register, and the "Settings → …"
breadcrumb uses each locale's actual `settings` label so it matches what the app
shows.

`MarkdownText` separates paragraphs by 12 dp rather than 8 dp, matching the blank
lines in the guide source. The overflow-menu items gain decorative leading icons.

`versionCode` 51 → 53, `versionName` 0.58.0 → 0.60.0.

---

## v0.59.0

Modernise the toolchain for 2026

A sequence of incremental steps under one version, each building on the last.

### Compiler and Compose

Kotlin moves 2.0.21 → 2.3.21. Because the Compose and serialization plugins are
versioned by the same catalog key, the Compose compiler follows to 2.3.21, which
pairs with the Compose 1.11 runtime the BOM 2025.05.01 → 2026.04.01 pins. KSP
moves to 2.3.7, adopting the Kotlin-decoupled version scheme in which one release
supports Kotlin 2.2 and newer, so it no longer mirrors the compiler version; the
catalog comment claiming otherwise is corrected.

Three runtimes had to follow Kotlin's forward-compatibility rule, under which a
runtime built with 2.Y supports 2.(Y+1) but not 2.(Y+2):
`kotlinx-serialization-core` and `kotlinx-coroutines-test` move to 1.11.0, and
the literal `kotlin-test` pin to 2.3.21.

The Kotlin 2.3 plugin turns `kotlinOptions { jvmTarget = "21" }` from a
deprecation into a hard script-compilation error, so the build migrates to the
type-safe `compilerOptions` DSL in a top-level `kotlin { }` block.

The BOM enables the Compose v2 testing APIs by default, switching the test
dispatcher from an eager `UnconfinedTestDispatcher` to a queued
`StandardTestDispatcher`. `EntryListItemUiTest`'s two click tests asserted on a
plain counter immediately after `performClick()`, a read that could now race the
queued click, and are wrapped in `runOnIdle { }`; node-based assertions are
unchanged, finders synchronising implicitly. The test also moves to the v2
`createAndroidComposeRule`, which is an import change only.

### Build system

Gradle moves 8.14.5 → 9.4.1 and AGP 8.13.2 → 9.2.0 together — a lock-step major
upgrade that cannot be bypassed. AGP 9 compiles Kotlin itself, so
`org.jetbrains.kotlin.android` is no longer applied or declared; keeping it would
be a hard error rather than a warning. AGP 9 bundles KGP 2.2.10 as a floor, so
the root `build.gradle.kts` pins the compiler to 2.3.21 on the buildscript
classpath. That pin is a hard-coded literal, a buildscript block being unable to
read the version catalog, and both spots carry a comment saying it must stay in
sync.

The androidTest schema-assets line migrates from `assets.srcDirs(...)` to
`assets.directories += ...`, the AGP 9 form. `android.builtInKotlin=false` is
deliberately not set: built-in Kotlin is adopted, not opted out of. No use of the
removed AGP 9 variant APIs was found.

### Database stack

`net.zetetic:android-database-sqlcipher` 4.5.4 gives way to the maintained
`net.zetetic:sqlcipher-android`, and the coordinated set then moves to
sqlcipher-android 4.15.0, androidx.sqlite 2.6.2 and Room 2.8.4 together — the
versions Google and Zetetic document for each other, so no Room-to-sqlite binary
skew arises. The old artifact was deprecated in 2022 and end-of-life in 2023, and
its native libraries are not built for 16 KB memory pages, which Android 15+
devices can run with and which Play requires for apps targeting Android 15+.

`AppDatabase` follows the new API: the package moved, the Room integration class
changed from `SupportFactory` to `SupportOpenHelperFactory` with the same
passphrase constructor, and the native library must be loaded explicitly before
the factory is built. No schema, passphrase or Keystore logic changed, so
existing encrypted databases open unchanged. `MigrationTest` migrates too, and
uses the single-argument constructor: the old third argument was
`clearPassphrase`, the new one is unrelated (`enableWriteAheadLogging`), and the
new library has no passphrase-clearing toggle.

`room-ktx` is removed; as of Room 2.8 its coroutine and Flow APIs are merged into
room-runtime and the standalone artifact is empty. Room 2.8.x is the final Room
2.x line, Room 3.0 being a separate package that is deliberately not adopted.

### AndroidX and hygiene

core-ktx moves to 1.18.0, activity-compose to 1.12.3 and lifecycle to 2.10.0,
all current stable; the latter two are bumped together because activity 1.12
depends transitively on a recent lifecycle. navigation-compose stays at 2.8.9,
2.9.x still being in alpha. appcompat, biometric and DataStore are current
stables and are left alone.

Eight dependencies previously declared as string literals move into the version
catalog, with `kotlin-test` now referencing the `kotlin` version so it cannot
drift from the compiler. The obsolete `android.suppressUnsupportedCompileSdk`
flag is removed, AGP 9.2 officially supporting compileSdk 36.1. The Gradle
configuration cache is deliberately not enabled here; it can surface
incompatibilities with the buildscript Kotlin override, KSP or Room and belongs
in its own tested change.

### The device-transfer warning

The warning no longer fires on a genuine first install. It had been driven by a
heuristic — install younger than 15 minutes, empty language, zero weight — which
a fresh install satisfies in full. It now uses an authoritative signal: a sealed
passphrase envelope is present in storage but cannot be decrypted with this
device's Keystore key, the actual signature of a transfer where the
hardware-bound key did not migrate. A first install has no envelope at all.

`AppDatabase` gains the read-only probes `hasSealedPassphrase()` and
`canOpenSealedPassphrase()`, the latter attempting a decrypt and zeroing the
plaintext, and the pure decision is `present && !decryptable`. The recency window
and the settings-based heuristic are removed. `PotillusAppHeuristicTest` locks in
the new truth table. The dialog resolves against the system locale, which is
correct here: in the failure case the user's stored language preference lives in
the store that cannot be read.

A Latin translation of the user guide is added and rendered to `res/raw-la/`.

---

## v0.58.0

Add localized in-app guides and an overflow menu

The user guide ships as a locale-qualified raw resource, the English one in
`res/raw/usersguide.md` and each translation in `res/raw-<locale>/`. Since the app
sets a per-app locale, Android resolves the matching directory automatically —
the mechanism already used for strings.

The guides are single-sourced from `docs/guide/usersguide.<lang>.md.in`, in which
every on-screen name is a `{{key}}` token rather than a hard-coded word, so a
guide cannot drift from the label the app shows. A build-time renderer resolves
each token against the matching locale's `strings.xml`, undoes Android's string
escaping, and fails loudly on an unknown key. It writes the in-app copies with
the licence header stripped for clean on-device rendering and regenerates the
repository-facing copies with the header and a generated-do-not-edit banner.
Writes are content-diffed, and a `--check` mode lets CI verify the committed
guides are in sync. Fourteen languages carry a real translation.

The four main screens share one `AppOverflowMenu` with Settings, Help and
License, replacing the identical settings gear each carried. The menu holds no
navigation logic of its own — it invokes callbacks supplied by `AppNavigation` —
so the screens stay free of navigation dependencies. A single reusable
`DocumentViewerScreen` backs both new entries, rendering the guide as Markdown
and the licence as plain monospaced text, pushed on top of Home with an Up arrow.

A small dependency-free `MarkdownText` renders exactly the subset the guides use
— ATX headings, reflowed paragraphs and links — its unsupported-syntax boundary
documented in the file. Adding no third-party library keeps the app
dependency-light. `res/raw/license.md` is a verbatim copy of the project-root
`LICENSE.md` produced by a `cp` step, deliberately neither translated nor
locale-qualified, and `check-guides` fails if the copy drifts.

Exports carry the project's GPLv3 header as a non-evaluated notice. The JSON
backup gains a top-level `_comment` array, JSON having no comment syntax and the
importer already ignoring unknown keys, and the PDF report a one-line footer
notice on every page. The CSV export deliberately carries none: CSV has no
portable comment convention and a leading line would surface as a spurious data
row in spreadsheet importers. The notice stays English on purpose, being a legal
notice rather than UI chrome, so it lives in code rather than in the translatable
resources.

Three new UI strings ship across all 52 locales, and the guide wording is updated
from "gear/cog icon" to "menu icon (☰)" so the shipped text describes the actual
UI. Several paragraphs of the English source guide ended with a duplicated
fragment of the following heading; those echoes are removed.

---

## v0.57.0

Replace gender and limit modes with three limits

Limits are three independent values that always apply together: a daily limit in
grams, a weekly limit in grams and a maximum number of drink days per week,
defaulting to 20 g, 100 g and 5 days. The WHO/DHS/custom limit-mode selector and
the separate daily-against-weekly gram-mode toggle are removed; all three are
always evaluated at once.

Biological sex is no longer stored or used. The Widmark estimate uses a fixed,
conservative distribution coefficient of 0.6 — the smaller of the two classic
coefficients, so it yields the worst-case blood-alcohol estimate — and body
weight is still used. The binge threshold is the sex-independent constant 48 g.

The Today screen shows three progress bars. The traffic-light capacity dots
consider all three limits: free servings are the minimum of the daily and weekly
gram headroom, and the drink-day limit acts as a gate that forces red once the
week's budget is used up — both when today is not yet a drink day and the week
already holds the maximum, and when today is one but the maximum had already been
reached earlier. The Statistics screen shows three violation rows, and the PDF
report drops the sex row and the guideline-mode line, its limit line reading
"X g/day · Y g/week · N drink days/wk". Settings keeps only body weight under
Personal data and gains a Limits section with three numeric inputs.

A new unit-tested `AlcoholCalculator.countLimitViolations` counts the three
violation kinds over a list of day summaries, grouping weeks by the configured
week-start day, and is used by both the Statistics screen and the PDF export so
they always report identical figures. Thirteen new strings ship in all 51
locales, translated best-effort for the less common languages.

Removed with the old model: the `Gender` and `LimitMode` enums, the three
settings fields, the WHO/DHS and per-sex constants, the `DrinkCapacity`
gram-mode field and its helpers, and 24 orphaned string resources. The
`IAppPreferences` setters are replaced by `setDailyLimit`, `setWeeklyLimit` and
`setMaxDrinkDaysPerWeek`; the DataStore keys for the daily limit and the drink-day
count are reused under their historical names so existing values survive, and
obsolete keys are ignored.

A dead-code review found `soberByMillis` and `limitPercent` referenced only by
tests. They predate this change and are left in place as public, tested domain
API.

---

## v0.56.0

Establish the first sanitized public baseline

This is the starting point of the public, forward-only changelog. The internal
development history that preceded it has been removed — it is not part of the
published source — and the knowledge it carried, in particular the reasons behind
design decisions, lives in the source code itself, in the KDoc and comments next
to the code each decision affects.

All references to concrete past app versions and to internal review issue codes
are gone from the comments, KDoc, file headers, the project documents, the build
script, the ProGuard rules, the localization resources and `release-check.sh`.
Functional version tokens are kept deliberately, being data contracts rather than
release history: the Room schema version with its migration and committed
schemas, and `BACKUP_VERSION`. Explanations that had lived only in the changelog,
or were referenced indirectly through an issue code, are rewritten in present
tense as self-contained rationale at the relevant code site.

The version string is `MAJOR.MINOR.PATCH`, starting at 0.56.0 with `versionCode`
49. Routine changes bump PATCH and larger feature sets MINOR, with `versionName`,
this changelog's top entry, the README title and the ProGuard header staying in
lock-step.

No application behaviour changed in this baseline.
