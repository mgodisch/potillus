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

# Shared test vectors

Language-neutral golden input/output cases for the health-relevant domain logic,
loaded by **both** platforms so the Android (JVM) and iOS (Swift) implementations
can never silently diverge.

Each file is a JSON document with a `cases` array; every case pairs an `input`
with its `expected` output. Adding or changing a case here is a deliberate,
reviewable change, and both test suites assert against these files.

The vectors are seeded from the existing Android domain tests as the logic is
ported. That is a hazard as well as a guarantee: a vector encodes *current*
behaviour, so if the Android code has a bug, the vector enshrines it. When
Android fixes a bug, regenerate the affected vectors and re-check the Swift port
— and add a regression vector for the fixed case.

## Files

One line each; every file carries its own `_comment` with the reasoning, the
scope and the cases that were deliberately left out.

- `alcohol-calculator.json` — the Widmark estimate, gram conversion, limit
  fractions, the traffic-light status, the drink-day gate and the rolling
  seven-day counts.
- `app-lock.json` — the biometric lock's re-auth threshold, including the
  boundary itself and the refusal to trust a backwards clock reading.
- `backup-settings.json` — the clamping every value from a backup's `settings`
  block passes through, and (`apply`) what a REPLACE then does with it against
  the local settings: absence sentinels leave the local value standing, and the
  biometric lock is armed only on a device that can authenticate.
  `localeTags` is generated from `SupportedLocales.kt`.
- `chart-bucketing.json` — `Trend` classification, granularity selection and the
  bucketing rules, including the two consequences of the in-progress day.
- `csv-export.json` — RFC 4180 escaping, the formula-injection guard and whole
  CSV documents. The `buildCsv` cases carry a `zoneId`.
- `day-resolver.json` — the logical-day boundary in both directions, period
  length and abstinence streaks, with DST transitions and cross-timezone
  instants.
- `db-schema.json` — the SQLite schema contract, generated from Android's Room
  export, which is authoritative. iOS introspects what GRDB builds.
- `drink-validation.json` — the rules a drink definition must satisfy. The
  `bounds` block is generated from `DrinkValidator.kt`.
- `limit-gauge.json` — the Today screen's two progress bars: fill (clamped) and
  emphasis (calm, warning, danger) for grams and for drink days.
- `month-grid.json` — the calendar's month alignment: blanks before day 1 under
  the locale's first weekday, day count, and the rows of seven a month needs.
- `month-rollup.json` — the monthly table's cap at six months and the weighted
  summary row that folds the rest.
- `plural-days.json` — the report's day counts in all 21 languages, forms from
  Android's `<plurals>`, categories from CLDR.
- `report-chart.json` — the report chart's label picking and bar scaling,
  computed in 32-bit float to match the Kotlin original.
- `report-data.json` — the report's computed dataset, for the slice of
  `PdfReportData` that reads no zone, locale or clock.
- `report-format.json` — the report's number formatting. Every expected string
  was produced by the JVM, not written by hand.
- `sealed-blob.json` — the `nonce || ciphertext || tag` layout of the sealed
  preferences file, opened under a fixed key on both platforms. The blobs were
  produced by a third AES-GCM implementation, not by either port.
- `stats-aggregator.json` — the category breakdown, the 24-hour histogram and
  the eight 3-hour buckets behind the Statistics screen and the report; the
  clock hour is read in the frame the drink was logged in.
- `stats-window.json` — which days a statistics period covers: the three
  periods, the baseline, and the statistics-start floor over both.
- `template-render.json` — the two-feature template engine behind
  `report/report_template.html`.
- `weekday-profile.json` — the weekday chart's column order and averages, dry
  occurrences of a weekday included, absent weekdays as `null`.
- `year-grid.json` — which days the year heat-map draws at all: a day after the
  logical today, or before the statistics start date, is not drawn.

## Loading

The iOS suite reads these files directly from the repository root, locating it
from the compile-time path of its loader (`ios/PotillusKit/Tests/.../
TestVectors.swift`). SwiftPM can only bundle resources inside a target, so
`Bundle.module` cannot reach up here — deriving the path is the standard
technique for shared fixtures and stays confined to test code.

A missing or malformed vector file is a hard test failure on both platforms: a
silently skipped parity suite would defeat the purpose.
