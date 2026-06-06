/* vim: set et ts=4:
 * =============================================================================
 * Libellus Potionis "Potillus" -- Privacy-Friendly Alcohol Tracker
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
 * =============================================================================
 */
package de.godisch.potillus.l10n

import android.content.Context
import androidx.core.os.ConfigurationCompat
import java.util.Locale

// =============================================================================
// LocaleSupport.kt — the locale to use for VALUE formatting (dates, months, …)
// =============================================================================
//
// THE PROBLEM THIS SOLVES
//   Potillus lets the user pick a language *inside the app* (an in-app language
//   selector that calls AppCompatDelegate.setApplicationLocales). That API sets
//   a "per-app locale": it re-configures the app's Context so that string
//   resources — every context.getString(...) — resolve in the chosen language,
//   and it recreates the activity so the UI re-renders.
//
//   It does NOT, however, change Locale.getDefault(). Locale.getDefault() is the
//   process-wide JVM default and keeps reflecting the *system* locale. So code
//   that formats a value with java.time and Locale.getDefault() — for example
//
//       DateTimeFormatter.ofPattern("MMMM yyyy", Locale.getDefault())
//
//   will keep producing month names in the *system* language even though the
//   surrounding labels (drawn from string resources) are in the *app* language.
//   The visible symptom was a PDF report whose "Export Date"/"Period" labels were
//   English while the month names next to them were still German.
//
// THE FIX
//   Read the locale from the Context's own configuration instead of from
//   Locale.getDefault(). The Context that resolved the (correct) labels is the
//   exact same Context whose configuration carries the per-app locale, so the
//   formatted values and their labels are guaranteed to agree.
//
//   ConfigurationCompat.getLocales(...) returns the configuration's locale list
//   (newest API: Configuration.getLocales()); element 0 is the primary locale.
//   We fall back to Locale.getDefault() only for the theoretical case of an empty
//   list, which does not occur on a normally configured device.
//
// HOW TO USE
//   • From a plain Context / Application context / ViewModel:
//         val locale = context.formattingLocale()
//   • From Compose, obtain the Context first (it already reflects the per-app
//     locale because AppCompat wraps the activity's base context):
//         val locale = LocalContext.current.formattingLocale()
//
//   Use the returned Locale for EVERY java.time formatter and every
//   getDisplayName(...) call that produces user-visible text. Never pass
//   Locale.getDefault() to those APIs in this app.
// =============================================================================

/**
 * The [Locale] to use when formatting user-visible values (dates, month and
 * weekday names, locale-sensitive numbers) so they match the language the app's
 * string resources are currently being resolved in.
 *
 * This reflects the *per-app* locale set via
 * `AppCompatDelegate.setApplicationLocales`, unlike [Locale.getDefault], which
 * stays pinned to the system locale and would therefore disagree with the
 * surrounding localized labels.
 *
 * @receiver Any [Context] whose resources are configured for the desired
 *           language — the application context, an activity, or the Compose
 *           `LocalContext`. All of these carry the per-app locale.
 * @return The configuration's primary locale, or [Locale.getDefault] as a
 *         last-resort fallback if the configuration somehow has no locale.
 */
fun Context.formattingLocale(): Locale =
    ConfigurationCompat.getLocales(resources.configuration)[0] ?: Locale.getDefault()
