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
//   use the result noun. Enums use singular form (ThemeMode, TrafficLight).
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
 * The three limit-violation day counts for a statistics period, produced by
 * [de.godisch.potillus.domain.AlcoholCalculator.countLimitViolations].
 *
 * @param daysOverDailyLimit     Days whose own total exceeds the daily gram limit.
 * @param daysOverWeeklyLimit    Consumption days on which the running weekly total
 *                               had already reached or was pushed past the weekly
 *                               gram limit (the over-shooting day and every later
 *                               consumption day in that week).
 * @param daysOverDrinkDayLimit  Consumption days beyond the allowed number of drink
 *                               days in their week (e.g. the 6th and 7th drink day
 *                               when the limit is 5).
 */
data class LimitViolations(
    val daysOverDailyLimit: Int,
    val daysOverWeeklyLimit: Int,
    val daysOverDrinkDayLimit: Int
)

/**
 * Application colour-scheme preference.
 *
 * - [SYSTEM] – follow the OS dark-mode toggle.
 * - [DAY]    – always use the light theme.
 * - [NIGHT]  – always use the dark theme.
 */
enum class ThemeMode { SYSTEM, DAY, NIGHT }

/**
 * The resolved set of active drinking limits.
 *
 * All three limits are always in force simultaneously (there is no longer a
 * WHO / DHS / custom mode and no daily-vs-weekly toggle): a day or a week is
 * "within limits" only when none of the three thresholds is exceeded.
 *
 * @param limitGrams           Daily pure-alcohol limit in grams.
 * @param weeklyLimitGrams     Pure-alcohol limit in grams for a gliding 7-day
 *                             window (today plus the previous six days), evaluated
 *                             continuously rather than reset on a fixed weekday.
 *                             Independent of [limitGrams] rather than derived from it.
 * @param maxDrinkDaysPerWeek  Maximum number of distinct drink days within any
 *                             7-day window (a drink day is any day with > 0 g consumed).
 */
data class LimitInfo(
    val limitGrams: Double,
    val weeklyLimitGrams: Double,
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
 * All three limits ([dailyLimitGrams], [weeklyLimitGrams], [maxDrinkDaysPerWeek])
 * are evaluated together; see [AlcoholCalculator.trafficLight].
 *
 * @param todayGrams           Grams consumed today. Used for the daily gram check
 *                             and to decide whether today already counts as a drink day.
 * @param dailyLimitGrams      Daily gram limit.
 * @param weeklyTotalGrams     Grams consumed in the trailing 7-day window (including today).
 * @param weeklyLimitGrams     Gram limit for the trailing 7-day window.
 * @param drinkDaysThisWeek    Distinct days with > 0 g in the trailing 7-day window (today
 *                             included when today already has alcohol entries).
 * @param maxDrinkDaysPerWeek  Maximum allowed drink days within the 7-day window.
 *
 * COMPUTED HELPER:
 *   [todayIsDrinkDay] – whether today already counts as a drink day, derived from
 *   [todayGrams]. The traffic-light drink-day check uses this so that a day which
 *   is already "spent" does not get blocked for further drinks, while still blocking
 *   a brand-new drink day once the weekly drink-day budget is exhausted.
 */
data class DrinkCapacity(
    val todayGrams: Double,
    val dailyLimitGrams: Double,
    val weeklyTotalGrams: Double,
    val weeklyLimitGrams: Double,
    val drinkDaysThisWeek: Int,
    val maxDrinkDaysPerWeek: Int
) {
    /** True when today already has > 0 g of alcohol logged, i.e. it is already a drink day. */
    val todayIsDrinkDay: Boolean
        get() = todayGrams > 0.0
}

/**
 * A snapshot of all user preferences.
 *
 * Default values match the first-launch state before any key is written to
 * DataStore, so the UI always has a consistent initial state.
 *
 * LIMITS:
 *   Three independent limits are always active at the same time — there is no
 *   guideline mode (WHO/DHS/custom) and no daily-vs-weekly toggle any more:
 *     - [dailyLimitGrams]     pure-alcohol grams allowed per day (default 20).
 *     - [weeklyLimitGrams]    pure-alcohol grams allowed per gliding 7-day window (default 100).
 *     - [maxDrinkDaysPerWeek] distinct drink days allowed per gliding 7-day window (default 5).
 *
 * @param dailyLimitGrams     Daily pure-alcohol limit in grams.
 * @param weeklyLimitGrams    Pure-alcohol limit in grams for a gliding 7-day window.
 * @param maxDrinkDaysPerWeek Maximum number of drink days within any 7-day window (1–7).
 */
data class AppSettings(
    val themeMode: ThemeMode        = ThemeMode.SYSTEM,
    val dayChangeHour: Int          = 4,
    val dayChangeMinute: Int        = 0,
    val dailyLimitGrams: Double     = 20.0,
    val weeklyLimitGrams: Double    = 100.0,
    val maxDrinkDaysPerWeek: Int    = 5,
    val statsFromDate: String       = "",
    val biometricEnabled: Boolean   = false,
    /**
     * When `true`, [WindowManager.LayoutParams.FLAG_SECURE] is cleared so the
     * OS permits screenshots and screen recordings of the app window.
     *
     * Default is `false` (flag active, screenshots blocked) to protect
     * health-sensitive data. The user must consciously opt in via Settings.
     */
    val allowScreenshots: Boolean   = false,
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
    val weightKg: Double            = 0.0
)
