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
package de.godisch.potillus.domain.model

// =============================================================================
// Models.kt – Domain model types for Libellus Potionis
// =============================================================================
//
// These are pure Kotlin data classes and enums with no Android or Room
// dependencies. They live in the domain layer, which means:
//   - ViewModels accept and return these types.
//   - Room entities (DrinkEntity, EntryEntity) are converted to/from these
//     types in the repository layer and never escape into the UI.
//   - Unit tests can instantiate these types without an Android runtime.
//
// NAMING CONVENTION:
//   Types that describe "what something is" (DrinkDefinition, ConsumptionEntry)
//   use nouns. Types that describe "a computed result" (LimitInfo, DrinkCapacity)
//   use the result noun. Enums use singular form (Gender, ThemeMode).
// =============================================================================

/**
 * Beverage category used for statistics breakdowns and PDF export grouping.
 *
 * Stored in the database as the enum [name] string (e.g. "BEER") rather than
 * the ordinal integer so that reordering constants in a future version does
 * not corrupt existing data. Unknown strings are parsed defensively with
 * `runCatching { DrinkCategory.valueOf(name) }.getOrDefault(OTHER)`.
 */
enum class DrinkCategory { BEER, WINE, SPIRITS, LONGDRINK, LIQUEUR, OTHER }

/**
 * A drink template from the user's catalogue.
 *
 * Immutable value type used throughout the domain and UI layers.
 * Persisted as [de.godisch.potillus.data.db.entity.DrinkEntity]; the repository
 * layer converts between the two representations via private extension
 * functions (`toDomain` / `toEntity`).
 *
 * @param id             Database primary key (0 = not yet persisted).
 * @param name           User-visible display name.
 * @param volumeMl       Default serving size in millilitres.
 * @param alcoholPercent Alcohol by volume (ABV) as a percentage, e.g. 5.0 for 5 %.
 * @param isPreset       `true` for built-in drinks that the user cannot delete.
 * @param isFavorite     `true` when the user has starred the drink for quick access.
 * @param category       Beverage category used for statistics breakdowns.
 */
data class DrinkDefinition(
    val id: Long = 0,
    val name: String,
    val volumeMl: Int,
    val alcoholPercent: Double,
    val isPreset: Boolean   = false,
    val isFavorite: Boolean = false,
    val category: DrinkCategory = DrinkCategory.OTHER
)

/**
 * A single recorded consumption event (denormalised for historical stability).
 *
 * WHY DENORMALISED?
 *   Fields like [drinkName], [volumeMl], and [alcoholPercent] are copied from
 *   the [DrinkDefinition] at log time. If the user later edits the drink
 *   definition, historical records are unaffected. This is the same principle
 *   as a paper receipt: it captures the facts at the time of purchase, not a
 *   live reference to a product catalogue that may change.
 *
 * Persisted as [de.godisch.potillus.data.db.entity.EntryEntity].
 *
 * @param id              Database primary key (0 = not yet persisted).
 * @param drinkId         Foreign key → [DrinkDefinition.id] (RESTRICT on delete).
 * @param drinkName       Snapshot of the drink's name at log time.
 * @param volumeMl        Actual volume consumed in ml (may differ from the
 *                        drink template's default if the user adjusted it).
 * @param alcoholPercent  ABV snapshot at log time, as a percentage.
 * @param gramsAlcohol    Pre-calculated pure-alcohol mass in grams. Stored so
 *                        that SQL SUM() queries are numerically stable without
 *                        re-deriving the value from volume × ABV on every read.
 * @param timestampMillis Unix epoch milliseconds (UTC) of the consumption event.
 * @param logicalDate     ISO-8601 "YYYY-MM-DD" resolved by
 *                        [de.godisch.potillus.domain.DayResolver], which attributes
 *                        late-night entries to the previous calendar day when
 *                        the timestamp is before the configured day-change time.
 * @param note            Optional free-text annotation (empty string if absent).
 */
data class ConsumptionEntry(
    val id: Long = 0,
    val drinkId: Long,
    val drinkName: String,
    val volumeMl: Int,
    val alcoholPercent: Double,
    val gramsAlcohol: Double,
    val timestampMillis: Long,
    val logicalDate: String,
    val note: String = ""
)

/**
 * Aggregated per-day drinking summary produced by a SQL GROUP BY query.
 *
 * Only days with at least one entry appear; zero-gram days are omitted
 * (the database query uses `GROUP BY logicalDate` without a CROSS JOIN).
 *
 * @param date        ISO-8601 logical date ("YYYY-MM-DD").
 * @param totalGrams  SUM of [ConsumptionEntry.gramsAlcohol] for this date.
 * @param entryCount  Number of individual [ConsumptionEntry] records for this date.
 */
data class DaySummary(
    val date: String,
    val totalGrams: Double,
    val entryCount: Int
)

/**
 * Alcohol-limit guideline to apply.
 *
 * - [WHO]    – World Health Organisation daily guidelines (20 g ♂ / 10 g ♀).
 * - [DHS]    – Deutsche Hauptstelle für Suchtfragen (24 g ♂ / 12 g ♀).
 * - [CUSTOM] – User-defined daily gram limit and max drink-days per week.
 */
enum class LimitMode { WHO, DHS, CUSTOM }

/**
 * Biological sex used in the Widmark BAC formula and limit selection.
 *
 * The Widmark r-coefficient differs between [MALE] (0.7) and [FEMALE] (0.6),
 * reflecting differences in average body-water ratio. Medical guidelines
 * (WHO, DHS) also specify different daily gram limits per sex.
 */
enum class Gender    { MALE, FEMALE }

/**
 * Application colour-scheme preference.
 *
 * - [SYSTEM] – follow the OS dark-mode toggle.
 * - [DAY]    – always use the light theme.
 * - [NIGHT]  – always use the dark theme.
 */
enum class ThemeMode { SYSTEM, DAY, NIGHT }

/**
 * The resolved, active limit.
 *
 * @param mode                 Which guideline is active.
 * @param limitGrams           Daily pure-alcohol limit in grams.
 * @param maxDrinkDaysPerWeek  Max drink days / week. WHO and DHS always use 5
 *                             (mandating at least 2 abstinent days per week).
 *                             Custom mode uses [AppSettings.customMaxDrinkDays].
 */
data class LimitInfo(
    val mode: LimitMode,
    val limitGrams: Double,
    val maxDrinkDaysPerWeek: Int = 5
)

/**
 * Traffic-light capacity status for a single drink serving.
 * - [GREEN]  two or more servings still fit within the active limit.
 * - [YELLOW] exactly one serving fits (today or this week, depending on mode).
 * - [RED]    no serving fits; the limit is already reached or exceeded.
 */
enum class TrafficLight { GREEN, YELLOW, RED }

/**
 * Today's consumption snapshot used for traffic-light calculation.
 *
 * @param todayGrams           Grams consumed today (used for the drink-day check
 *                             and as the base gram value in daily mode).
 * @param dailyLimitGrams      Daily gram limit as configured.
 * @param drinkDaysThisWeek    Distinct Mon–Sun days with ≥1 entry this week.
 * @param maxDrinkDaysPerWeek  Max drink days/week from [LimitInfo].
 * @param weeklyTotalGrams     Grams consumed Mon–Sun this week (used in weekly mode).
 * @param weeklyGramMode       When true the gram check uses [weeklyTotalGrams] vs
 *                             [maxDrinkDaysPerWeek] × [dailyLimitGrams].
 *
 * COMPUTED HELPERS:
 *   [effectiveConsumedGrams] – the "used" side of the gram comparison.
 *   [effectiveBudgetGrams]   – the "budget" side of the gram comparison.
 *   Both automatically select the correct values for the current mode.
 *
 * NOTE: the drink-day check always uses raw [todayGrams], NOT the effective value,
 * because it must know whether *today specifically* already counts as a drink day.
 * In weekly mode a drink logged on Monday must not make Tuesday look like a drink day.
 */
data class DrinkCapacity(
    val todayGrams: Double,
    val dailyLimitGrams: Double,
    val drinkDaysThisWeek: Int,
    val maxDrinkDaysPerWeek: Int,
    val weeklyTotalGrams: Double = 0.0,
    val weeklyGramMode: Boolean  = false
) {
    /** Grams to compare against the budget (daily total or weekly total). */
    val effectiveConsumedGrams: Double
        get() = if (weeklyGramMode) weeklyTotalGrams else todayGrams

    /** Gram budget to compare against (daily limit or weekly budget). */
    val effectiveBudgetGrams: Double
        get() = if (weeklyGramMode) maxDrinkDaysPerWeek * dailyLimitGrams else dailyLimitGrams
}

/**
 * A snapshot of all user preferences.
 *
 * Default values match the first-launch state before any key is written to
 * DataStore, so the UI always has a consistent initial state.
 *
 * @param weeklyGramMode  When true the gram progress bar and traffic-light bullets
 *                        use the weekly total vs. [customMaxDrinkDays × dailyLimit].
 *                        Abstinent-days-per-week logic is unaffected by this flag.
 */
data class AppSettings(
    val themeMode: ThemeMode        = ThemeMode.SYSTEM,
    val dayChangeHour: Int          = 4,
    val dayChangeMinute: Int        = 0,
    val gender: Gender              = Gender.MALE,
    val limitMode: LimitMode        = LimitMode.WHO,
    val customLimitGrams: Double    = 20.0,
    val customMaxDrinkDays: Int     = 5,
    val weeklyGramMode: Boolean     = false,
    val statsFromDate: String       = "",
    val biometricEnabled: Boolean   = false,
    /**
     * Selected UI language as a BCP-47 tag, or `""` when the user has not chosen
     * one yet.
     *
     * The empty string is the deliberate "not yet set" sentinel: it matches the
     * `?:` fallback in [de.godisch.potillus.data.prefs.AppPreferences.settingsFlow]
     * and is what [de.godisch.potillus.PotillusApp.applyLanguageOnFirstLaunch] and
     * the device-transfer heuristic test against. A non-empty default such as
     * `"en"` would contradict the flow fallback and those checks, so it stays empty.
     */
    val language: String            = "",
    val weightKg: Double            = 0.0,
    /**
     * First day of the week, as an ISO-8601 weekday number (1 = Monday …
     * 7 = Sunday). Affects the weekly statistics window, the "this week"
     * summary on the Today screen, the calendar grid alignment, and the PDF
     * weekday profile. Defaults to Monday, which reproduces the app's previous
     * hard-coded ISO-week behaviour.
     */
    val weekStartDay: Int           = 1
)
