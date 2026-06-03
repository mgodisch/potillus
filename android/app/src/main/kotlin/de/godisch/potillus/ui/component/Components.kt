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
package de.godisch.potillus.ui.component

// =============================================================================
// Components.kt – Shared, reusable Composables used across multiple screens
// =============================================================================
//
// COMPOSABLE FUNCTIONS:
//   Functions annotated with @Composable describe UI as a function of state.
//   Every time the state changes, Compose calls the function again ("recomposition")
//   and efficiently updates only the parts of the UI that changed.
//
// FILE ORGANISATION:
//   Each section contains composables or helpers for one concern:
//     - Category icon              (DrinkCategory → Material icon)
//     - Favourites quick bar       (TodayScreen & CalendarScreen)
//     - Entry list item            (TodayScreen & CalendarScreen)
//     - Limit progress bar         (TodayScreen & CalendarScreen)
//     - Traffic-light capacity dot (TodayScreen, DrinksScreen, AddEditEntryDialog)
//     - Drink-days progress bar    (TodayScreen)
// =============================================================================

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import de.godisch.potillus.R
import de.godisch.potillus.domain.model.ConsumptionEntry
import de.godisch.potillus.domain.model.DrinkCapacity
import de.godisch.potillus.domain.model.DrinkCategory
import de.godisch.potillus.domain.model.DrinkDefinition
import de.godisch.potillus.domain.model.TrafficLight
import de.godisch.potillus.ui.theme.dangerRedColor
import de.godisch.potillus.ui.theme.errorColor
import de.godisch.potillus.ui.theme.successColor
import de.godisch.potillus.ui.theme.warningColor
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId

// ════════════════════════════════════════════════════════════════════════════
// CATEGORY ICON
// ════════════════════════════════════════════════════════════════════════════

/**
 * Bundles the icon vector and its display size for a given [DrinkCategory].
 *
 * [Liqueur] uses a slightly smaller icon (14.dp vs 18.dp) because its Material
 * icon (LocalBar) has more visual weight and appears oversized at the standard
 * size. All other categories use the same 18.dp baseline.
 */
private data class CategoryIconSpec(val vector: ImageVector, val size: Dp)

/**
 * Maps a [DrinkCategory] to its [CategoryIconSpec] (Material icon + display size).
 *
 * Centralising this `when` here means every place that renders a category icon
 * makes the same icon/size choice. @param category The category to map.
 */
private fun categoryIconSpec(category: DrinkCategory): CategoryIconSpec = when (category) {
    DrinkCategory.BEER      -> CategoryIconSpec(Icons.Default.SportsBar,  18.dp)
    DrinkCategory.WINE      -> CategoryIconSpec(Icons.Default.WineBar,    18.dp)
    DrinkCategory.SPIRITS   -> CategoryIconSpec(Icons.Default.Liquor,     18.dp)
    DrinkCategory.LONGDRINK -> CategoryIconSpec(Icons.Default.LocalDrink, 18.dp)
    DrinkCategory.LIQUEUR   -> CategoryIconSpec(Icons.Default.LocalBar,   14.dp)
    DrinkCategory.OTHER     -> CategoryIconSpec(Icons.Default.Blender,    18.dp)
}

/**
 * Small icon representing a [DrinkCategory], used in drink lists and dialogs.
 *
 * The icon and its size are determined by [categoryIconSpec] so that all
 * category icon decisions are centralised in one place.
 *
 * @param category  The category to display.
 * @param modifier  Optional layout modifier (e.g. for size overrides).
 * @param tint      Icon colour; defaults to [MaterialTheme.colorScheme.onSurfaceVariant]
 *                  (a subdued secondary colour that blends into list items).
 */
@Composable
fun DrinkCategoryIcon(
    category: DrinkCategory,
    modifier: Modifier = Modifier,
    tint: Color = MaterialTheme.colorScheme.onSurfaceVariant
) {
    val spec = categoryIconSpec(category)
    Icon(
        imageVector        = spec.vector,
        contentDescription = category.name,
        modifier           = modifier.size(spec.size),
        tint               = tint
    )
}

/**
 * Returns the localised display label for this [DrinkCategory].
 *
 * Used in [AddEditDrinkDialog] and the category donut chart legend.
 * Like [DrinkCategoryIcon], this is @Composable because it calls
 * [stringResource].
 */
@Composable
fun DrinkCategory.displayLabel(): String = when (this) {
    DrinkCategory.BEER      -> stringResource(R.string.category_beer)
    DrinkCategory.WINE      -> stringResource(R.string.category_wine)
    DrinkCategory.SPIRITS   -> stringResource(R.string.category_spirits)
    DrinkCategory.LONGDRINK -> stringResource(R.string.category_longdrink)
    DrinkCategory.LIQUEUR   -> stringResource(R.string.category_liqueur)
    DrinkCategory.OTHER     -> stringResource(R.string.category_other)
}

// ════════════════════════════════════════════════════════════════════════════
// FAVOURITES QUICK BAR
// ════════════════════════════════════════════════════════════════════════════

/**
 * A horizontally scrollable row of chips for the user's favourite drinks.
 *
 * Tapping a chip pre-selects the drink in the Add Entry dialog, saving the
 * user from opening the drink dropdown for frequently consumed drinks.
 *
 * The composable renders nothing (early return) when [favorites] is empty,
 * so call sites do not need to guard against an empty list.
 *
 * @param favorites  Drinks marked as favourite; shown in the order provided
 *                   (the DAO already sorts favourites first).
 * @param onSelect   Called with the tapped [DrinkDefinition] so the parent
 *                   screen can open the Add Entry dialog pre-filled.
 * @param modifier   Optional layout modifier for the outer [Column].
 */
@Composable
fun FavoriteQuickBar(
    favorites: List<DrinkDefinition>,
    onSelect: (DrinkDefinition) -> Unit,
    modifier: Modifier = Modifier
) {
    if (favorites.isEmpty()) return
    Column(modifier = modifier) {
        Text(
            text     = stringResource(R.string.favorites_quick),
            style    = MaterialTheme.typography.labelSmall,
            color    = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(horizontal = 16.dp)
        )
        Spacer(Modifier.height(4.dp))
        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            contentPadding        = PaddingValues(horizontal = 16.dp)
        ) {
            items(favorites) { drink ->
                SuggestionChip(
                    onClick = { onSelect(drink) },
                    label   = {
                        Row(
                            verticalAlignment     = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp)
                        ) {
                            DrinkCategoryIcon(category = drink.category, modifier = Modifier.size(14.dp))
                            Column {
                                Text(drink.name, maxLines = 1, overflow = TextOverflow.Ellipsis, fontSize = 12.sp)
                                Text(
                                    "${drink.volumeMl} ml · ${drink.alcoholPercent} %",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                )
            }
        }
    }
}

// ════════════════════════════════════════════════════════════════════════════
// ENTRY LIST ITEM
// ════════════════════════════════════════════════════════════════════════════

/**
 * A card displaying one [ConsumptionEntry] with edit and delete action buttons.
 *
 * Used in TodayScreen's lazy column and CalendarScreen's selected-date detail.
 *
 * COMPOSE PERFORMANCE – `remember(entry.timestampMillis)`:
 *   Formatting the time string is cheap, but `remember` caches the result
 *   and recalculates only when [entry.timestampMillis] changes. This avoids
 *   redundant work when an unrelated state change triggers recomposition.
 *
 * @param entry     The consumption entry to display.
 * @param onEdit    Called when the user taps the edit (pencil) icon.
 * @param onDelete  Called when the user taps the delete (trash) icon. The
 *                  parent screen is responsible for showing a confirmation
 *                  dialog before actually deleting.
 */
@Composable
fun EntryListItem(entry: ConsumptionEntry, onEdit: () -> Unit, onDelete: () -> Unit) {
    val time = remember(entry.timestampMillis) {
        val ldt = LocalDateTime.ofInstant(Instant.ofEpochMilli(entry.timestampMillis), ZoneId.systemDefault())
        "%02d:%02d".format(ldt.hour, ldt.minute)
    }
    Card(
        modifier  = Modifier.fillMaxWidth(),
        colors    = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
    ) {
        Row(
            modifier          = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    entry.drinkName,
                    style      = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.Medium,
                    maxLines   = 1,
                    overflow   = TextOverflow.Ellipsis
                )
                Text(
                    "$time · ${entry.volumeMl} ml · ${entry.alcoholPercent} % · ${"%.1f".format(entry.gramsAlcohol)} g",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                if (entry.note.isNotBlank()) {
                    Text(
                        entry.note,
                        style    = MaterialTheme.typography.bodySmall,
                        color    = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }
            Row {
                IconButton(onClick = onEdit) {
                    Icon(Icons.Default.Edit, contentDescription = stringResource(R.string.edit_entry), tint = MaterialTheme.colorScheme.primary)
                }
                IconButton(onClick = onDelete) {
                    Icon(Icons.Default.Delete, contentDescription = stringResource(R.string.delete), tint = dangerRedColor())
                }
            }
        }
    }
}

// ════════════════════════════════════════════════════════════════════════════
// LIMIT PROGRESS BAR
// ════════════════════════════════════════════════════════════════════════════

/**
 * A labelled horizontal progress bar showing how much of a gram limit has been consumed.
 *
 * This is a generic bar used for both the daily and the weekly gram limit; the
 * caller supplies the consumed amount, the limit, and a pre-formatted right-hand
 * [caption] (e.g. "20 g/day" or "100 g/week").
 *
 * Colour semantics:
 *   - < 75 %  → primary (calm blue)
 *   - 75–99 % → warning (amber)
 *   - ≥ 100 % → error (red)  – limit reached or exceeded
 *
 * The [LinearProgressIndicator] receives a clamped [0f, 1f] fraction so it never
 * overflows visually, even when [totalGrams] > [limitGrams]. The colour switch at
 * exactly 1.0f still signals the violation.
 *
 * @param totalGrams  Grams consumed in the current period.
 * @param limitGrams  The threshold to compare against. Clamped to ≥ 1.0 internally
 *                    to prevent division-by-zero when the limit is not yet configured.
 * @param caption     Right-hand caption shown above the bar (already formatted).
 * @param leftSuffix  Optional text appended to the consumed-grams label on the left,
 *                    e.g. a week range "(25.5.–31.5.)". Empty by default.
 * @param modifier    Optional layout modifier for the outer [Column].
 */
@Composable
fun LimitBar(
    totalGrams: Double,
    limitGrams: Double,
    caption: String,
    leftSuffix: String = "",
    modifier: Modifier = Modifier
) {
    // coerceAtLeast(1.0): guard against limitGrams = 0 (not configured).
    // A limit of 0 would produce NaN; show 0 % fill visually instead.
    val fraction = (totalGrams / limitGrams.coerceAtLeast(1.0)).toFloat().coerceAtLeast(0f)
    // Red only when the limit is *exceeded* (strictly greater), matching
    // AlcoholCalculator.countLimitViolations and the calendar/chart over-limit
    // markers, which all use `totalGrams > limitGrams`. Reaching the limit exactly
    // is allowed (the limit is what you may consume), so it stays amber. Using the
    // gram comparison rather than `fraction >= 1f` also avoids float-rounding at
    // the boundary.
    val barColor = when {
        totalGrams > limitGrams -> dangerRedColor()
        fraction < 0.75f        -> MaterialTheme.colorScheme.primary
        else                    -> warningColor()
    }
    Column(modifier = modifier) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            val leftText = if (leftSuffix.isNotEmpty())
                "${"%.1f".format(totalGrams)} g $leftSuffix"
            else
                "${"%.1f".format(totalGrams)} g"
            Text(leftText, style = MaterialTheme.typography.bodySmall)
            Text(
                caption,
                style    = MaterialTheme.typography.bodySmall,
                color    = MaterialTheme.colorScheme.onSurfaceVariant,
                // Guaranteed minimum visual gap from the left text so the two
                // values never visually merge in SpaceBetween layout.
                modifier = Modifier.padding(start = 8.dp)
            )
        }
        Spacer(Modifier.height(4.dp))
        LinearProgressIndicator(
            progress   = { fraction.coerceIn(0f, 1f) },
            modifier   = Modifier.fillMaxWidth().height(8.dp),
            color      = barColor,
            trackColor = MaterialTheme.colorScheme.surfaceVariant,
        )
    }
}

// ════════════════════════════════════════════════════════════════════════════
// TRAFFIC-LIGHT CAPACITY DOT
// ════════════════════════════════════════════════════════════════════════════

/**
 * A 12 dp sphere-shaped indicator showing how many more servings of a drink
 * can be logged before the active limits are exceeded.
 *
 * Colour semantics:
 *   - [TrafficLight.GREEN]  → two or more servings remain.
 *   - [TrafficLight.YELLOW] → exactly one serving remains.
 *   - [TrafficLight.RED]    → no servings remain (uses [dangerRedColor]).
 *
 * 3-D EFFECT:
 *   Rendered on a [Canvas] with two draw calls:
 *   1. Base filled circle in the status colour.
 *   2. A semi-transparent white highlight spot placed in the upper-left
 *      quadrant, simulating a point light source at 10 o'clock.
 *   This gives a subtle sphere/ball appearance without requiring a shader or
 *   bitmap resource.
 *
 * All three colours (red, yellow, green) use [dangerRedColor], [warningColor],
 * and [successColor] respectively – the same palette used by calendar
 * over-limit dots and the delete-action icon, ensuring visual consistency.
 *
 * @param light     The pre-calculated traffic-light status.
 * @param modifier  Optional layout modifier.
 */
@Composable
fun TrafficLightDot(
    light: TrafficLight,
    modifier: Modifier = Modifier
) {
    val baseColor = when (light) {
        TrafficLight.GREEN  -> successColor()
        TrafficLight.YELLOW -> warningColor()
        TrafficLight.RED    -> dangerRedColor()
    }
    // Capture color BEFORE entering the Canvas lambda (DrawScope is not Composable)
    val highlight = androidx.compose.ui.graphics.Color.White.copy(alpha = 0.52f)

    androidx.compose.foundation.Canvas(modifier = modifier.size(12.dp)) {
        val r  = size.minDimension / 2f
        val cx = size.width  / 2f
        val cy = size.height / 2f

        // 1. Filled base circle
        drawCircle(color = baseColor, radius = r,
            center = androidx.compose.ui.geometry.Offset(cx, cy))

        // 2. Specular highlight – smaller circle offset to upper-left.
        //    Radius = 35 % of sphere radius; offset = 28 % in each axis.
        //    Creates the illusion of a convex surface lit from the top-left.
        drawCircle(
            color  = highlight,
            radius = r * 0.35f,
            center = androidx.compose.ui.geometry.Offset(cx - r * 0.28f, cy - r * 0.28f)
        )
    }
}

// ════════════════════════════════════════════════════════════════════════════
// DRINK-DAYS PROGRESS BAR
// ════════════════════════════════════════════════════════════════════════════

/**
 * A labelled horizontal progress bar showing how many days this Mon–Sun week
 * have already included alcohol consumption.
 *
 * Colour semantics mirror [LimitBar]:
 *   - < 75 % used   → primary (blue)
 *   - 75–100 % used → warning (amber) – up to and including the last allowed day
 *   - > 100 % used  → dangerRed – allowance exceeded
 *
 * The bar is always shown (0 drink days is displayed as an empty bar) so the
 * limit is visible even when the week has just started.
 *
 * @param drinkDays    Days this week on which alcohol was consumed (including today
 *                     when today has entries).
 * @param maxDrinkDays Maximum allowed drink days (from [LimitInfo.maxDrinkDaysPerWeek]).
 * @param weekLabel    Formatted week-range label, e.g. "19.5.–25.5." for display.
 * @param modifier     Optional layout modifier.
 */
@Composable
fun DrinkDaysBar(
    drinkDays: Int,
    maxDrinkDays: Int,
    weekLabel: String    = "",
    modifier: Modifier   = Modifier
) {
    val fraction = (drinkDays.toFloat() / maxDrinkDays.toFloat().coerceAtLeast(1f))
        .coerceAtLeast(0f)
    // Red only when the allowance is *exceeded* (strictly more drink days than
    // permitted), consistent with LimitBar and countLimitViolations. Using exactly
    // the last allowed drink day (drinkDays == maxDrinkDays) is still within the
    // limit and stays amber ("at cap, none left"); the next drink day is over.
    val barColor = when {
        drinkDays > maxDrinkDays -> dangerRedColor()
        fraction < 0.75f         -> MaterialTheme.colorScheme.primary
        else                     -> warningColor()
    }
    Column(modifier = modifier) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(
                "$drinkDays / $maxDrinkDays ${stringResource(R.string.drink_days_label)}",
                style = MaterialTheme.typography.bodySmall
            )
            if (weekLabel.isNotEmpty()) {
                Text(weekLabel, style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        Spacer(Modifier.height(4.dp))
        LinearProgressIndicator(
            progress   = { fraction.coerceIn(0f, 1f) },
            modifier   = Modifier.fillMaxWidth().height(8.dp),
            color      = barColor,
            trackColor = MaterialTheme.colorScheme.surfaceVariant,
        )
    }
}
