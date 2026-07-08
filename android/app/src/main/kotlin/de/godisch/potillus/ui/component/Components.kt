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
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import de.godisch.potillus.R
import de.godisch.potillus.domain.AlcoholCalculator
import de.godisch.potillus.domain.model.ConsumptionEntry
import de.godisch.potillus.domain.model.DrinkCategory
import de.godisch.potillus.domain.model.DrinkDefinition
import de.godisch.potillus.domain.model.TrafficLight
import de.godisch.potillus.l10n.fmt1
import de.godisch.potillus.l10n.formattingLocale
import de.godisch.potillus.ui.theme.dangerRedColor
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
    DrinkCategory.BEER -> CategoryIconSpec(Icons.Default.SportsBar, 18.dp)
    DrinkCategory.WINE -> CategoryIconSpec(Icons.Default.WineBar, 18.dp)
    DrinkCategory.SPIRITS -> CategoryIconSpec(Icons.Default.Liquor, 18.dp)
    DrinkCategory.LONGDRINK -> CategoryIconSpec(Icons.Default.LocalDrink, 18.dp)
    DrinkCategory.LIQUEUR -> CategoryIconSpec(Icons.Default.LocalBar, 14.dp)
    DrinkCategory.OTHER -> CategoryIconSpec(Icons.Default.Blender, 18.dp)
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
    tint: Color = MaterialTheme.colorScheme.onSurfaceVariant,
) {
    val spec = categoryIconSpec(category)
    Icon(
        imageVector = spec.vector,
        // Accessible name = the LOCALISED category label (via displayLabel),
        // never the raw enum constant. `category.name` would make a screen
        // reader announce the developer-facing token ("BEER"/"WINE"), which is
        // both unlocalised and jarring; displayLabel() resolves the same
        // strings.xml captions the rest of the UI uses, so the icon is voiced in
        // the app's own language with no new string keys (see [displayLabel]).
        contentDescription = category.displayLabel(),
        modifier = modifier.size(spec.size),
        tint = tint,
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
    DrinkCategory.BEER -> stringResource(R.string.category_beer)
    DrinkCategory.WINE -> stringResource(R.string.category_wine)
    DrinkCategory.SPIRITS -> stringResource(R.string.category_spirits)
    DrinkCategory.LONGDRINK -> stringResource(R.string.category_longdrink)
    DrinkCategory.LIQUEUR -> stringResource(R.string.category_liqueur)
    DrinkCategory.OTHER -> stringResource(R.string.category_other)
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
    modifier: Modifier = Modifier,
) {
    if (favorites.isEmpty()) return
    Column(modifier = modifier) {
        Text(
            text = stringResource(R.string.favorites_quick),
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(horizontal = 16.dp),
        )
        Spacer(Modifier.height(4.dp))
        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            contentPadding = PaddingValues(horizontal = 16.dp),
        ) {
            // Stable key: favourites can be toggled on/off in the Drinks screen
            // while this row is visible; keying by the Room id lets Compose move
            // the surviving chips instead of rebinding every position.
            items(favorites, key = { it.id }) { drink ->
                SuggestionChip(
                    onClick = { onSelect(drink) },
                    label = {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(4.dp),
                        ) {
                            DrinkCategoryIcon(category = drink.category, modifier = Modifier.size(14.dp))
                            Column {
                                Text(drink.name, maxLines = 1, overflow = TextOverflow.Ellipsis, fontSize = 12.sp)
                                Text(
                                    "${drink.volumeMl} ml · ${drink.alcoholPercent} %",
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                        }
                    },
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
    // Per-app locale for the gram value, so its decimal separator matches the
    // in-app language rather than the system locale (see l10n/NumberFormat.kt).
    val locale = LocalContext.current.formattingLocale()
    val time = remember(entry.timestampMillis) {
        val ldt = LocalDateTime.ofInstant(Instant.ofEpochMilli(entry.timestampMillis), ZoneId.systemDefault())
        "%02d:%02d".format(ldt.hour, ldt.minute)
    }
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    entry.drinkName,
                    style = MaterialTheme.typography.bodyLarge,
                    fontWeight = FontWeight.Medium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    "$time · ${entry.volumeMl} ml · ${entry.alcoholPercent} % · ${entry.gramsAlcohol.fmt1(locale)} g",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
                if (entry.note.isNotBlank()) {
                    Text(
                        entry.note,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
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
 * @param limitGrams  The threshold to compare against. A non-positive value
 *                    (limit not configured) shows an empty bar — the guard lives
 *                    in [AlcoholCalculator.limitPercent].
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
    modifier: Modifier = Modifier,
    leftSuffix: String = "",
) {
    // Per-app locale for the consumed-grams label (see l10n/NumberFormat.kt).
    val locale = LocalContext.current.formattingLocale()
    // Fill fraction from the domain layer's single source of truth. The guard
    // for an unconfigured limit (≤ 0 → empty bar instead of NaN) lives THERE,
    // not here — this composable used to duplicate the division with a subtly
    // different guard (coerceAtLeast(1.0)), which the v0.78.0 QA review
    // unified into AlcoholCalculator.limitPercent.
    val fraction = AlcoholCalculator.limitPercent(totalGrams, limitGrams)
    // Red only when the limit is *exceeded*, decided by the domain layer's ONE
    // definition of "over the limit" (AlcoholCalculator.isOverLimit) — the same
    // check countLimitViolations, the calendar/chart over-limit markers and the
    // PDF report use. Reaching the limit exactly is allowed (the limit is what
    // you may consume), so it stays amber; the helper's epsilon keeps a total
    // that DISPLAYS as exactly the limit from flipping red through binary
    // floating-point drift (see isOverLimit's KDoc).
    val barColor = when {
        AlcoholCalculator.isOverLimit(totalGrams, limitGrams) -> dangerRedColor()
        fraction < 0.75f -> MaterialTheme.colorScheme.primary
        else -> warningColor()
    }
    Column(modifier = modifier) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            val leftText = if (leftSuffix.isNotEmpty()) {
                "${totalGrams.fmt1(locale)} g $leftSuffix"
            } else {
                "${totalGrams.fmt1(locale)} g"
            }
            Text(leftText, style = MaterialTheme.typography.bodySmall)
            Text(
                caption,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                // Guaranteed minimum visual gap from the left text so the two
                // values never visually merge in SpaceBetween layout.
                modifier = Modifier.padding(start = 8.dp),
            )
        }
        Spacer(Modifier.height(4.dp))
        LinearProgressIndicator(
            progress = { fraction.coerceIn(0f, 1f) },
            modifier = Modifier.fillMaxWidth().height(8.dp),
            color = barColor,
            trackColor = MaterialTheme.colorScheme.surfaceVariant,
        )
    }
}

// ════════════════════════════════════════════════════════════════════════════
// TRAFFIC-LIGHT CAPACITY DOT
// ════════════════════════════════════════════════════════════════════════════

/**
 * A 12 dp indicator showing how many more servings of a drink can be logged
 * before the active limits are exceeded.
 *
 * COLOUR SEMANTICS (always applied):
 *   - [TrafficLight.GREEN]  → two or more servings remain (uses [successColor]).
 *   - [TrafficLight.YELLOW] → exactly one serving remains (uses [warningColor]).
 *   - [TrafficLight.RED]    → no servings remain (uses [dangerRedColor]).
 *
 *   These three colours are the same palette used by the calendar over-limit
 *   dots and the delete-action icon, keeping every status cue in the app
 *   visually consistent.
 *
 * TWO VISUAL STYLES, selected by [useSymbols]:
 *   - `false` (default) — a coloured *sphere*: a filled base circle plus a
 *     semi-transparent white highlight spot in the upper-left quadrant, which
 *     simulates a point light source at 10 o'clock and gives a convex ball look
 *     without a shader or bitmap resource.
 *   - `true` — a *flat* coloured circle carrying a white glyph that redundantly
 *     encodes the same state by SHAPE, so the indicator no longer relies on hue
 *     alone (WCAG 1.4.1 "Use of Color", an aid for red–green colour-vision
 *     deficiency): a cross for RED, a "1" for YELLOW, an up-arrow for GREEN.
 *     The specular highlight is dropped in this style so it does not compete
 *     with the glyph. RED/GREEN are drawn as vector [Icon]s overlaid on the
 *     circle; the YELLOW "1" is drawn straight onto the [Canvas] and centred via
 *     the font metrics (baseline = centre − (ascent + descent) / 2), because an
 *     overlaid [Text] sits a hair too low inside the small box. The user opts in
 *     via Settings → Appearance; the flag is threaded down from
 *     [de.godisch.potillus.domain.model.AppSettings.alternativeStatusSymbols].
 *
 * ACCESSIBILITY (independent of [useSymbols]):
 *   The whole indicator carries a localised [contentDescription] announcing the
 *   capacity state, so a screen reader (TalkBack) conveys the status that sighted
 *   users read from the colour/glyph. [clearAndSetSemantics] collapses the dot to
 *   this single, meaningful node — the overlaid icons expose no description of
 *   their own and the canvas-drawn digit has no semantics — instead of leaking a
 *   raw glyph to assistive technology.
 *
 * @param light      The pre-calculated traffic-light status.
 * @param modifier   Optional layout modifier.
 * @param useSymbols When `true`, overlay the state-specific glyph (flat style);
 *                   when `false`, render the plain coloured sphere.
 */
@Composable
fun TrafficLightDot(
    light: TrafficLight,
    modifier: Modifier = Modifier,
    useSymbols: Boolean = false,
) {
    val baseColor = when (light) {
        TrafficLight.GREEN -> successColor()
        TrafficLight.YELLOW -> warningColor()
        TrafficLight.RED -> dangerRedColor()
    }
    // Localised, state-specific text alternative for screen readers. Resolved in
    // the composable scope (stringResource is @Composable) before the Canvas.
    val statusDescription = when (light) {
        TrafficLight.GREEN -> stringResource(R.string.capacity_status_ok)
        TrafficLight.YELLOW -> stringResource(R.string.capacity_status_low)
        TrafficLight.RED -> stringResource(R.string.capacity_status_reached)
    }
    // Capture colours BEFORE entering the Canvas lambda (DrawScope is not Composable).
    val highlight = androidx.compose.ui.graphics.Color.White.copy(alpha = 0.52f)
    val glyphColor = androidx.compose.ui.graphics.Color.White

    Box(
        modifier = modifier
            .size(12.dp)
            // clearAndSetSemantics: expose ONE capacity description to assistive
            // technology and drop any semantics from the child glyphs (the vector
            // icons pass contentDescription = null; the "1" is canvas-drawn), so
            // the dot reads as a single, meaningful node.
            .clearAndSetSemantics { contentDescription = statusDescription },
        contentAlignment = Alignment.Center,
    ) {
        androidx.compose.foundation.Canvas(modifier = Modifier.matchParentSize()) {
            val r = size.minDimension / 2f
            val cx = size.width / 2f
            val cy = size.height / 2f

            // 1. Filled base circle in the status colour.
            drawCircle(
                color = baseColor,
                radius = r,
                center = androidx.compose.ui.geometry.Offset(cx, cy),
            )

            // 2. Specular highlight – only in the plain sphere style. A smaller
            //    circle offset to the upper-left (radius 35 %, offset 28 % per
            //    axis) fakes a convex surface lit from the top-left. Skipped when
            //    a glyph is drawn so the two do not visually clash.
            if (!useSymbols) {
                drawCircle(
                    color = highlight,
                    radius = r * 0.35f,
                    center = androidx.compose.ui.geometry.Offset(cx - r * 0.28f, cy - r * 0.28f),
                )
            }

            // 3. YELLOW glyph "1" — drawn directly on the canvas (not as an
            //    overlaid Compose Text). A Text sits a hair too low inside the
            //    12 dp box because of its line-box padding; drawing here lets us
            //    place the baseline from the font metrics so the digit's optical
            //    centre lands exactly on the circle centre:
            //        baseline = centreY − (ascent + descent) / 2   (ascent < 0)
            //    This mirrors how the statistics charts render their centred
            //    on-bar value labels. RED/GREEN use vector icons (see the overlay
            //    below); only the text digit needs metric-based centring.
            if (useSymbols && light == TrafficLight.YELLOW) {
                val glyphPaint = android.graphics.Paint().apply {
                    isAntiAlias = true
                    color = android.graphics.Color.WHITE
                    textAlign = android.graphics.Paint.Align.CENTER
                    // 8 sp (a touch smaller than the 10 dp vector icons) at normal
                    // weight: synthetic bold (isFakeBoldText) thickened the strokes
                    // so the "1" read heavier than the cross/arrow, so it is left off.
                    textSize = 8.sp.toPx()
                }
                val baselineY = cy - (glyphPaint.ascent() + glyphPaint.descent()) / 2f
                drawContext.canvas.nativeCanvas.drawText("1", cx, baselineY, glyphPaint)
            }
        }

        // Redundant SHAPE cue for colour-vision deficiency. RED/GREEN are vector
        // icons overlaid on the circle; contentDescription = null because the
        // parent Box already carries the single, meaningful description. YELLOW's
        // "1" is drawn on the canvas above (font-metric centring), so it is a no-op
        // here.
        if (useSymbols) {
            when (light) {
                TrafficLight.RED -> Icon(
                    imageVector = Icons.Filled.Close,
                    contentDescription = null,
                    tint = glyphColor,
                    modifier = Modifier.size(10.dp),
                )
                TrafficLight.GREEN -> Icon(
                    imageVector = Icons.Filled.ArrowUpward,
                    contentDescription = null,
                    tint = glyphColor,
                    modifier = Modifier.size(10.dp),
                )
                TrafficLight.YELLOW -> Unit
            }
        }
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
    modifier: Modifier = Modifier,
    weekLabel: String = "",
) {
    val fraction = (drinkDays.toFloat() / maxDrinkDays.toFloat().coerceAtLeast(1f))
        .coerceAtLeast(0f)
    // Red only when the allowance is *exceeded* (strictly more drink days than
    // permitted), consistent with LimitBar and countLimitViolations. Using exactly
    // the last allowed drink day (drinkDays == maxDrinkDays) is still within the
    // limit and stays amber ("at cap, none left"); the next drink day is over.
    val barColor = when {
        drinkDays > maxDrinkDays -> dangerRedColor()
        fraction < 0.75f -> MaterialTheme.colorScheme.primary
        else -> warningColor()
    }
    Column(modifier = modifier) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(
                "$drinkDays / $maxDrinkDays ${stringResource(R.string.drink_days_label)}",
                style = MaterialTheme.typography.bodySmall,
            )
            if (weekLabel.isNotEmpty()) {
                Text(
                    weekLabel,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        Spacer(Modifier.height(4.dp))
        LinearProgressIndicator(
            progress = { fraction.coerceIn(0f, 1f) },
            modifier = Modifier.fillMaxWidth().height(8.dp),
            color = barColor,
            trackColor = MaterialTheme.colorScheme.surfaceVariant,
        )
    }
}
