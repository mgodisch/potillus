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
 * =============================================================================
 */
package de.godisch.potillus.l10n

import android.content.Context
import android.content.res.Configuration
import android.os.LocaleList
import android.text.format.DateFormat
import androidx.appcompat.app.AppCompatDelegate
import androidx.core.os.ConfigurationCompat
import androidx.core.os.LocaleListCompat
import java.time.format.DateTimeFormatter
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
//   • From Compose or any Activity-derived Context (these DO carry the per-app
//     locale, because AppCompat wraps the activity's base context):
//         val locale = LocalContext.current.formattingLocale()
//   • From a ViewModel or any other place that only holds the APPLICATION
//     context: wrap it first —
//         val ctx = appContext.perAppLocalizedContext()
//         val locale = ctx.formattingLocale()
//     See [perAppLocalizedContext] below for why the raw Application context is
//     NOT sufficient on every supported API level.
//   • From code that holds NO Context and must stay Context-free (e.g.
//     TodayViewModel, kept JVM-testable): read the SAME per-app locale from its
//     persisted source, `Locale.forLanguageTag(AppSettings.language)`. That tag
//     and AppCompatDelegate's application locales are always written together
//     (the Settings language picker and applyLanguageOnFirstLaunch set both), so
//     this yields the same locale as [formattingLocale] without needing a Context.
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
 *           language — an activity, the Compose `LocalContext`, or the result
 *           of [perAppLocalizedContext]. The raw Application context is only
 *           safe on API 33+; wrap it with [perAppLocalizedContext] first (see
 *           that function for the API 30–32 caveat).
 * @return The configuration's primary locale, or [Locale.getDefault] as a
 *         last-resort fallback if the configuration somehow has no locale.
 */
fun Context.formattingLocale(): Locale = ConfigurationCompat.getLocales(resources.configuration)[0] ?: Locale.getDefault()

/**
 * A [Context] whose resources are guaranteed to resolve in the app's per-app
 * locale — safe to use for `getString(...)`, `getQuantityString(...)` and
 * [formattingLocale] from code that only holds the APPLICATION context.
 *
 * WHY THIS EXISTS (API 30–32 caveat):
 *   `AppCompatDelegate.setApplicationLocales(...)` behaves differently across
 *   the supported API range:
 *
 *   - **API 33+**: the call delegates to the system `LocaleManager`; the
 *     framework applies the per-app locale to EVERY context of the app,
 *     including the Application context. No wrapping would be needed.
 *   - **API 30–32** (minSdk is 30): the AppCompat back-port applies the locale
 *     only by wrapping the base context of each `AppCompatActivity` as it is
 *     created. The Application context keeps the SYSTEM configuration, so
 *     `application.getString(...)` silently resolves in the system language —
 *     wrong whenever the in-app language differs from it. The symptom was CSV
 *     column headers, the whole PDF report and ViewModel status messages
 *     appearing in the system language on Android 11–12L.
 *
 *   This helper closes the gap uniformly: it reads the per-app locale list
 *   from [AppCompatDelegate.getApplicationLocales] and derives a context whose
 *   configuration carries exactly those locales. On API 33+ it is a harmless
 *   re-statement of what the framework already did; on API 30–32 it is the fix.
 *
 * API 33+ SUBTLETY (verified against the AndroidX source): on T+ the
 * AppCompatDelegate get/set calls reach the framework `LocaleManager` through
 * the list of ACTIVE AppCompatDelegate instances — with no live
 * `AppCompatActivity`, `getApplicationLocales()` returns the EMPTY list even
 * when a per-app locale is stored. That is harmless here: on those API levels
 * the framework already localizes every context of the app (including the
 * Application context), so the empty-list no-op path below returns a receiver
 * that is ALREADY correct. On API 30–32 the lookup uses process-wide statics
 * and needs no activity. It does mean, however, that this function cannot be
 * exercised end-to-end from an activity-less instrumented test on modern
 * devices — which is why the tests target [localizedContextFor] directly.
 *
 * THREADING: cheap and side-effect free; call it right where a localized
 * string or [formattingLocale] is needed, so it always reflects the CURRENT
 * language selection (never cache the result across a language switch).
 *
 * @receiver Typically the Application context held by a ViewModel.
 * @return The receiver itself when no per-app locale is set (first launch
 *         before detection, or tests), otherwise a configuration context
 *         localized to the stored per-app locale list.
 */
fun Context.perAppLocalizedContext(): Context = localizedContextFor(AppCompatDelegate.getApplicationLocales())

/**
 * The pure transformation behind [perAppLocalizedContext]: derives a context
 * whose configuration carries exactly [locales].
 *
 * Split out (and `internal`) so instrumented tests can verify the actual
 * configuration-context derivation with EXPLICIT locale lists — deterministic
 * on every API level, no activity required, no global or persisted device
 * state touched. Arranging the same coverage through
 * [AppCompatDelegate.setApplicationLocales] is impossible on API 33+ without
 * a live `AppCompatActivity` (see the API 33+ SUBTLETY note above).
 *
 * @param locales The locale list to impose; the empty list is the documented
 *                "nothing stored" case and yields the receiver unchanged.
 * @return The receiver itself for an empty [locales], otherwise a
 *         configuration context localized to [locales].
 */
internal fun Context.localizedContextFor(locales: LocaleListCompat): Context {
    val tags = locales.toLanguageTags()
    if (tags.isEmpty()) return this
    val config = Configuration(resources.configuration)
    // Lint's AppBundleLocaleChanges check pattern-matches this setLocales call:
    // dynamic locale changes require that every locale's resources are present
    // at runtime. That is guaranteed by `bundle { language { enableSplit =
    // false } }` in app/build.gradle.kts (see the rationale there) — Play never
    // strips languages from this app's AAB, and F-Droid APKs are unsplit anyway.
    config.setLocales(LocaleList.forLanguageTags(tags))
    return createConfigurationContext(config)
}

// =============================================================================
// Month + year labels ("June 2026") — CLDR skeletons instead of literal patterns
// =============================================================================
//
// WHY NOT DateTimeFormatter.ofPattern("MMMM yyyy", locale)?
//   A literal pattern localizes only the month NAME. Two whole language groups
//   need more (found in the v0.79.0 QA review, the same fault class as the
//   fixed formatStatsDate/"d.M." labels):
//     • FIELD ORDER — CJK writes the year first: "2026年6月" (zh/ja), "2026년
//       6월" (ko). The literal pattern rendered "6月 2026".
//     • GRAMMATICAL FORM — in inflected languages the "MMMM" (format-context)
//       month is the GENITIVE, meant to follow a day number: "28 czerwca". A
//       bare month+year label needs the STANDALONE form ("czerwiec 2026",
//       "июнь 2026 г."), pattern letter "LLLL". Which form (and where the
//       year's era suffix like the Russian "г." goes) is locale data, not
//       something a hand-written pattern can know.
//   ICU's getBestDateTimePattern solves both: given the SKELETON "yMMMM" (just
//   the fields wanted), it returns the locale's own pattern for that field
//   combination from CLDR — "y年M月" for zh/ja, "LLLL y 'г'." for ru,
//   "MMMM y" for de. The TodayViewModel month caption solves the same problem
//   with Month.getDisplayName(FULL_STANDALONE) — that API covers a month name
//   WITHOUT a year, so it cannot be used here.
//
// WHY THESE LIVE IN THIS FILE
//   android.text.format.DateFormat is an Android API, so the helpers cannot be
//   JVM-unit-tested; this file's class (LocaleSupportKt) is already excluded
//   from the Kover floor for exactly that reason, and the behaviour is asserted
//   on-device in LocaleFormattingInstrumentedTest instead.
// =============================================================================

/**
 * A formatter producing the locale's own "month + year" label — full month name
 * ([abbreviated] = false, e.g. Calendar header "June 2026" / "2026年6月" /
 * "czerwiec 2026") or abbreviated ([abbreviated] = true, e.g. the PDF's monthly
 * rows "Jun 2026") — via the CLDR skeletons "yMMMM" / "yMMM" (see the section
 * header above for why a literal "MMMM yyyy" is wrong in 6+ shipped languages).
 */
fun monthYearFormatter(locale: Locale, abbreviated: Boolean = false): DateTimeFormatter {
    val skeleton = if (abbreviated) "yMMM" else "yMMMM"
    val pattern = DateFormat.getBestDateTimePattern(locale, skeleton)
    return DateTimeFormatter.ofPattern(pattern, locale)
}
