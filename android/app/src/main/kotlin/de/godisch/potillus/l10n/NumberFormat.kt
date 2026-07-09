/* vim: set et ts=4:
 * =============================================================================
 * Libellus Potionis - Privacy-Friendly Alcohol Tracker
 * Copyright (c) 2026 Martin A. Godisch <android@godisch.de>
 * =============================================================================
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 * In addition, as permitted by section 7 of the GNU General Public License,
 * this program may carry additional permissions; any such permissions that
 * apply to it are stated in the accompanying COPYING.md file.
 *
 * =============================================================================
 */
package de.godisch.potillus.l10n

import java.util.Locale

// =============================================================================
// NumberFormat.kt — locale-aware decimal formatting for user-visible numbers
// =============================================================================
//
// THE PROBLEM THIS SOLVES (the numeric twin of LocaleSupport.kt)
//   Kotlin's `"%.1f".format(x)` (and `String.format("%.1f", x)`) formats with
//   Locale.getDefault() — the process-wide *system* locale. It does NOT follow
//   the *per-app* locale chosen in Settings via
//   AppCompatDelegate.setApplicationLocales.
//
//   Dates and month/weekday names in this app already follow the per-app locale
//   (see [formattingLocale]). Numbers, however, were formatted with the system
//   default, so on a device whose system language differs from the in-app
//   language the decimal separator disagreed with the surrounding text: a user
//   who picks "Deutsch" in-app on an English-system phone saw "Juni 2026"
//   (per-app locale) next to "19.6 g" (system locale) — a point where a comma
//   was expected. The same mismatch appeared on the Statistics, Today, Calendar
//   and Drinks screens and inside the PDF report.
//
// THE FIX
//   These helpers take the [Locale] explicitly, so the caller can pass the same
//   per-app locale the labels are resolved in (from [Context.formattingLocale]
//   for composables / Context-bound code, or the BCP-47 locale a ViewModel
//   already holds). The number's decimal separator then always matches the
//   language the surrounding labels are rendered in.
//
//   They are pure, Android-free functions and therefore unit-testable on the JVM
//   without a device or a Context (see NumberFormatTest).
//
// WHAT DELIBERATELY DOES NOT USE THESE
//   - CSV export keeps Locale.ROOT (a '.' separator) because CSV is a
//     machine-readable interchange format (see CsvExporter).
//   - Round-trip-parsed numeric INPUT fields keep Locale.ROOT too, so a value
//     formatted for display can always be parsed back with String.toDouble()
//     (see GramsInputDialog in SettingsScreen). Formatting such a field with a
//     comma-decimal locale would make its initial value unparseable.
// =============================================================================

/**
 * Formats [this] with exactly one decimal place using [locale]'s decimal
 * separator (e.g. `"19.6"` for en, `"19,6"` for de). Used for gram values shown
 * to the user.
 *
 * @param locale The locale whose decimal separator to use — normally the per-app
 *               locale from [Context.formattingLocale], never [Locale.getDefault].
 */
fun Double.fmt1(locale: Locale): String = String.format(locale, "%.1f", this)

/**
 * Formats [this] with no decimal places using [locale] (e.g. a whole-gram limit
 * `"20"`). HALF_UP rounding via `%.0f`; the app's inputs are non-negative.
 *
 * @param locale The per-app locale (see [fmt1]).
 */
fun Double.fmt0(locale: Locale): String = String.format(locale, "%.0f", this)

/**
 * Formats [this] with two decimal places using [locale] (e.g. a BAC value
 * `"0.42"` for en, `"0,42"` for de).
 *
 * @param locale The per-app locale (see [fmt1]).
 */
fun Double.fmt2(locale: Locale): String = String.format(locale, "%.2f", this)
