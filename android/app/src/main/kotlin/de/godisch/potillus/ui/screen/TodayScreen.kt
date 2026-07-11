/* vim: set et ts=4:
 * =============================================================================
 * Libellus Potionis - Privacy-Friendly Alcohol Tracker
 * Copyright (c) 2026 Martin A. Godisch <martin@godisch.de>
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
package de.godisch.potillus.ui.screen

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import de.godisch.potillus.R
import de.godisch.potillus.domain.AlcoholCalculator
import de.godisch.potillus.domain.Trend
import de.godisch.potillus.domain.model.*
import de.godisch.potillus.l10n.fmt0
import de.godisch.potillus.l10n.fmt1
import de.godisch.potillus.l10n.fmt2
import de.godisch.potillus.l10n.formattingLocale
import de.godisch.potillus.ui.component.*
import de.godisch.potillus.ui.theme.dangerRedColor
import de.godisch.potillus.ui.theme.successColor
import de.godisch.potillus.ui.theme.warningColor

/**
 * Today tab: the current logical day's entries, running gram total / limit
 * progress and estimated BAC, with quick add/edit/delete actions.
 *
 * @param vm             The [TodayViewModel]; defaults to the Activity-scoped instance.
 * @param onOpenSettings Invoked when the top-bar gear icon is tapped.
 * @param onOpenHelp     Invoked when the overflow-menu Help item is tapped.
 * @param onOpenCopyright Invoked when the overflow-menu Copyright item is tapped.
 * @param onLockApp      Locks the app immediately (overflow-menu "Lock app").
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TodayScreen(
    vm: TodayViewModel = viewModel(),
    onOpenSettings: () -> Unit = {},
    onOpenHelp: () -> Unit = {},
    onOpenCopyright: () -> Unit = {},
    /** Locks the app immediately (overflow-menu "Lock app"). */
    onLockApp: () -> Unit = {},
) {
    val state by vm.uiState.collectAsStateWithLifecycle()
    val drinks by vm.drinks.collectAsStateWithLifecycle()
    val lastUsedDrink by vm.lastUsedDrink.collectAsStateWithLifecycle()

    // Per-app locale for number formatting (grams, BAC, limits), so the decimal
    // separator matches the in-app language rather than the system locale — see
    // l10n/NumberFormat.kt.
    val locale = LocalContext.current.formattingLocale()

    // these stay plain `remember` on purpose. `showAdd` is coupled to
    // `preSelectedDrink` (a domain DrinkDefinition, intentionally NOT Parcelable),
    // so saving `showAdd` alone would reopen the add dialog after a configuration
    // change with a lost pre-selection. Keeping all four un-saved means they reset
    // together — the dialog simply closes on recreation, with no inconsistent state.
    var showAdd by remember { mutableStateOf(false) }
    var preSelectedDrink by remember { mutableStateOf<DrinkDefinition?>(null) }
    var editEntry by remember { mutableStateOf<ConsumptionEntry?>(null) }
    var deleteEntry by remember { mutableStateOf<ConsumptionEntry?>(null) }

    // Capacity snapshot for traffic-light indicators in AddEditEntryDialog
    val capacity = DrinkCapacity(
        todayGrams = state.totalGrams,
        dailyLimitGrams = state.limitInfo.limitGrams,
        weeklyTotalGrams = state.weeklyTotalGrams,
        weeklyLimitGrams = state.limitInfo.weeklyLimitGrams,
        drinkDaysThisWeek = state.drinkDaysThisWeek,
        maxDrinkDaysPerWeek = state.limitInfo.maxDrinkDaysPerWeek,
    )

    Scaffold(
        contentWindowInsets = WindowInsets(0),
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.today)) },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    titleContentColor = MaterialTheme.colorScheme.onPrimary,
                ),
                actions = {
                    AppOverflowMenu(
                        onOpenSettings = onOpenSettings,
                        onOpenHelp = onOpenHelp,
                        onOpenCopyright = onOpenCopyright,
                        onLockApp = onLockApp,
                        tint = MaterialTheme.colorScheme.onPrimary,
                    )
                },
            )
        },
        floatingActionButton = {
            FloatingActionButton(
                onClick = {
                    preSelectedDrink = lastUsedDrink
                    showAdd = true
                },
                containerColor = MaterialTheme.colorScheme.primary,
                contentColor = MaterialTheme.colorScheme.onPrimary,
            ) {
                Icon(Icons.Default.Add, contentDescription = stringResource(R.string.add_entry))
            }
        },
    ) { paddingValues ->
        LazyColumn(
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.fillMaxSize().padding(paddingValues),
        ) {
            // ── Daily summary card ────────────────────────────────────────────
            item {
                Card(
                    colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer),
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Column(Modifier.padding(16.dp)) {
                        // Row 1: captions — "Today's total" (left) vs "Ø <month>"
                        // (right, the current month's per-day average), mirrored
                        // across the card width.
                        //
                        // LAYOUT HARDENING (v0.81.0 QA, eighth round): the left
                        // caption carries the weight, the right one is pinned to a
                        // single line — the same rule LimitBar / DrinkDaysBar and
                        // StatsScreen's StatRow follow. Both captions are localized
                        // and the right one additionally embeds a month name, so in
                        // a verbose language pair (e.g. el "Σύνολο σήμερα" +
                        // "Ø Σεπτέμβριος") the unweighted layout would let the left
                        // caption eat the row and break the month name across lines.
                        Row(modifier = Modifier.fillMaxWidth()) {
                            Text(
                                stringResource(R.string.total_today),
                                style = MaterialTheme.typography.titleMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.weight(1f),
                            )
                            Text(
                                stringResource(R.string.avg_of_month, state.currentMonthLabel),
                                style = MaterialTheme.typography.titleMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.padding(start = 8.dp),
                                softWrap = false,
                                maxLines = 1,
                            )
                        }
                        Spacer(Modifier.height(4.dp))
                        // Row 2: left shows today's own total in grams, right shows
                        // the month's per-day average. Both use the same headline
                        // figure + unit styling so the two values read as a pair.
                        //
                        // LAYOUT HARDENING (v0.81.0 QA, eighth round): the left
                        // figure+unit group is weighted so the right group — whose
                        // unit string is localized and can be long (el "γρ./ημέρα",
                        // ru "г/день") — is measured first at its natural width and
                        // never wraps. Without the weight the two headline figures
                        // are measured in order and the right group can be squeezed.
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            verticalAlignment = Alignment.Bottom,
                        ) {
                            Row(verticalAlignment = Alignment.Bottom, modifier = Modifier.weight(1f)) {
                                Text(
                                    state.totalGrams.fmt1(locale),
                                    style = MaterialTheme.typography.headlineLarge,
                                    color = MaterialTheme.colorScheme.onSurface,
                                    softWrap = false,
                                    maxLines = 1,
                                )
                                Spacer(Modifier.width(4.dp))
                                Text(
                                    "g",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.padding(bottom = 4.dp),
                                )
                            }
                            Row(verticalAlignment = Alignment.Bottom) {
                                Text(
                                    state.monthlyAvgPerDay.fmt1(locale),
                                    style = MaterialTheme.typography.headlineLarge,
                                    color = MaterialTheme.colorScheme.onSurface,
                                )
                                Spacer(Modifier.width(4.dp))
                                Text(
                                    stringResource(R.string.grams_per_day),
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.padding(bottom = 4.dp),
                                )
                                // Trend vs. last month: ↓ green = fewer grams/day,
                                // ↑ red = more. Nothing when equal (at 0.1 g) or when
                                // there is no previous-month value (Trend.FLAT). Same
                                // convention as the Statistics screen's month trend.
                                if (state.monthTrend != Trend.FLAT) {
                                    Spacer(Modifier.width(4.dp))
                                    Text(
                                        if (state.monthTrend == Trend.DOWN) "↓" else "↑",
                                        // Same text style as the "g/day" label beside it
                                        // (bodyMedium) so the arrow shares its baseline and
                                        // size; only the weight differs. Using a larger style
                                        // here (e.g. titleMedium) misaligns the glyph because
                                        // Alignment.Bottom aligns bounding boxes, not baselines.
                                        style = MaterialTheme.typography.bodyMedium,
                                        fontWeight = FontWeight.Bold,
                                        color = if (state.monthTrend == Trend.DOWN) {
                                            successColor()
                                        } else {
                                            dangerRedColor()
                                        },
                                        modifier = Modifier.padding(bottom = 4.dp),
                                    )
                                }
                            }
                        }
                        // A little extra breathing room (~half a line) between the
                        // headline figures and the limit bars below.
                        Spacer(Modifier.height(16.dp))
                        // Three progress bars, one per active limit:
                        //   1. Daily gram limit   – today's grams vs. daily limit.
                        //   2. Weekly gram limit  – this week's grams vs. weekly limit.
                        //   3. Drink days         – distinct drink days vs. max per week.
                        LimitBar(
                            totalGrams = state.totalGrams,
                            limitGrams = state.limitInfo.limitGrams,
                            caption = stringResource(
                                R.string.limit_caption_day,
                                state.limitInfo.limitGrams.fmt0(locale),
                            ),
                        )
                        Spacer(Modifier.height(10.dp))
                        LimitBar(
                            totalGrams = state.weeklyTotalGrams,
                            limitGrams = state.limitInfo.weeklyLimitGrams,
                            caption = stringResource(
                                R.string.limit_caption_week,
                                state.limitInfo.weeklyLimitGrams.fmt0(locale),
                            ),
                            leftSuffix = if (state.weeklyRangeLabel.isNotEmpty()) "(${state.weeklyRangeLabel})" else "",
                        )
                        // Drink-days bar: distinct drink days this week vs. the max.
                        Spacer(Modifier.height(10.dp))
                        DrinkDaysBar(
                            drinkDays = state.drinkDaysThisWeek,
                            maxDrinkDays = state.limitInfo.maxDrinkDaysPerWeek,
                            // Today's own status decides whether a full bar means
                            // "stop": a day already spent costs nothing further.
                            todayIsDrinkDay = state.totalGrams > 0.0,
                            weekLabel = state.weeklyRangeLabel,
                        )
                        // BAC estimate (Widmark formula) – only shown when weight is configured
                        state.bacPermille?.let { bac ->
                            Spacer(Modifier.height(10.dp))
                            HorizontalDivider(color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.2f))
                            Spacer(Modifier.height(8.dp))
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Column(Modifier.weight(1f)) {
                                    Text(
                                        stringResource(R.string.bac_estimate),
                                        style = MaterialTheme.typography.labelMedium,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    )
                                    Text(
                                        "${bac.fmt2(locale)} ‰",
                                        style = MaterialTheme.typography.titleLarge,
                                        color = when {
                                            bac >= 0.5 -> dangerRedColor()
                                            bac >= 0.3 -> warningColor()
                                            else -> successColor()
                                        },
                                    )
                                }
                                Text(
                                    stringResource(R.string.bac_disclaimer),
                                    style = MaterialTheme.typography.labelSmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.weight(1f),
                                    textAlign = TextAlign.End,
                                )
                            }
                        }
                    }
                }
            }

            // ── Favourites quick bar ──────────────────────────────────────────
            if (state.favorites.isNotEmpty()) {
                item {
                    FavoriteQuickBar(
                        favorites = state.favorites,
                        onSelect = { drink ->
                            preSelectedDrink = drink
                            showAdd = true
                        },
                    )
                }
            }

            item {
                Text(
                    stringResource(R.string.entries_today),
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.onSurface,
                )
            }

            if (state.entries.isEmpty()) {
                item {
                    Text(
                        stringResource(R.string.no_entries_today),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth().padding(vertical = 24.dp),
                    )
                }
            } else {
                // Stable Room id as key — same rationale as the calendar's entry
                // list: deletions remove one keyed row instead of rebinding all.
                items(state.entries, key = { it.id }) { entry ->
                    EntryListItem(
                        entry = entry,
                        onEdit = { editEntry = entry },
                        onDelete = { deleteEntry = entry },
                    )
                }
            }
        }
    }

    if (showAdd) {
        AddEditEntryDialog(
            entry = null,
            drinks = drinks,
            preSelectedDrink = preSelectedDrink,
            capacity = capacity,
            useStatusSymbols = state.settings.alternativeStatusSymbols,
            onSave = { drink, vol, ts, note ->
                vm.addEntry(drink, vol, ts, note)
                showAdd = false
                preSelectedDrink = null
            },
            onDismiss = {
                showAdd = false
                preSelectedDrink = null
            },
        )
    }
    editEntry?.let { entry ->
        AddEditEntryDialog(
            entry = entry,
            drinks = drinks,
            capacity = capacity,
            onSave = { drink, vol, ts, note ->
                vm.updateEntry(
                    entry.copy(
                        drinkId = drink.id,
                        drinkName = drink.name,
                        volumeMl = vol,
                        alcoholPercent = drink.alcoholPercent,
                        gramsAlcohol = AlcoholCalculator.calculateGrams(vol, drink.alcoholPercent),
                        timestampMillis = ts,
                        note = note,
                    ),
                )
                editEntry = null
            },
            onDismiss = { editEntry = null },
        )
    }
    deleteEntry?.let { entry ->
        AlertDialog(
            onDismissRequest = { deleteEntry = null },
            title = { Text(stringResource(R.string.delete)) },
            text = { Text(stringResource(R.string.delete_confirm, entry.drinkName)) },
            confirmButton = {
                TextButton(onClick = {
                    vm.deleteEntry(entry)
                    deleteEntry = null
                }) {
                    Text(stringResource(R.string.delete), color = dangerRedColor())
                }
            },
            dismissButton = {
                TextButton(onClick = { deleteEntry = null }) { Text(stringResource(R.string.cancel)) }
            },
        )
    }
}
