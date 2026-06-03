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
package de.godisch.potillus.ui.screen

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import de.godisch.potillus.R
import de.godisch.potillus.domain.AlcoholCalculator
import de.godisch.potillus.domain.DayResolver
import de.godisch.potillus.domain.model.*
import de.godisch.potillus.ui.component.*
import de.godisch.potillus.ui.theme.errorColor
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.time.format.TextStyle
import java.util.Locale

/**
 * Calendar tab: a month or year grid colour-coded by daily alcohol intake,
 * with a per-day detail/entry sheet.
 *
 * @param vm The [CalendarViewModel]; defaults to the Activity-scoped instance.
 * @param onOpenSettings Invoked when the top-bar gear icon is tapped.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CalendarScreen(
    vm: CalendarViewModel = viewModel(),
    onOpenSettings: () -> Unit = {},
    onOpenHelp: () -> Unit = {},
    onOpenLicense: () -> Unit = {}
) {
    val state   by vm.uiState.collectAsStateWithLifecycle()
    val drinks  by vm.drinks.collectAsStateWithLifecycle()
    // `showAdd` is rememberSaveable so an open add-entry dialog survives
    // a configuration change; it targets the ViewModel's selectedDate (which also
    // survives), so no extra state is needed. `editEntry`/`deleteEntry` hold domain
    // objects (ConsumptionEntry) that are intentionally NOT Parcelable (the domain
    // layer is Android-free), so they stay plain `remember`: on recreation the
    // edit/delete dialog closes cleanly rather than reopening with a lost target.
    var showAdd     by rememberSaveable { mutableStateOf(false) }
    var editEntry   by remember { mutableStateOf<ConsumptionEntry?>(null) }
    var deleteEntry by remember { mutableStateOf<ConsumptionEntry?>(null) }

    val isYear = state.viewMode == CalendarViewMode.YEAR

    Scaffold(
        contentWindowInsets = WindowInsets(0),
        topBar = {
            TopAppBar(
                title  = { Text(stringResource(R.string.calendar)) },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor    = MaterialTheme.colorScheme.primary,
                    titleContentColor = MaterialTheme.colorScheme.onPrimary
                ),
                actions = {
                    TextButton(onClick = { vm.toggleViewMode() }) {
                        Text(
                            if (isYear) stringResource(R.string.month) else stringResource(R.string.year),
                            color = MaterialTheme.colorScheme.onPrimary
                        )
                    }
                    AppOverflowMenu(
                        onOpenSettings = onOpenSettings,
                        onOpenHelp     = onOpenHelp,
                        onOpenLicense  = onOpenLicense,
                        tint           = MaterialTheme.colorScheme.onPrimary
                    )
                }
            )
        },
        floatingActionButton = {
            if (state.selectedDate != null) {
                FloatingActionButton(
                    onClick        = { showAdd = true },
                    containerColor = MaterialTheme.colorScheme.primary,
                    contentColor   = MaterialTheme.colorScheme.onPrimary
                ) {
                    Icon(Icons.Default.Add, contentDescription = stringResource(R.string.add_entry))
                }
            }
        }
    ) { paddingValues ->
        LazyColumn(
            contentPadding      = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            modifier            = Modifier.fillMaxSize().padding(paddingValues)
        ) {
            if (isYear) {
                // ── Year view ─────────────────────────────────────────────────
                item {
                    Card(modifier = Modifier.fillMaxWidth()) {
                        Column(Modifier.padding(12.dp)) {
                            Row(
                                Modifier.fillMaxWidth(),
                                horizontalArrangement = Arrangement.SpaceBetween,
                                verticalAlignment     = Alignment.CenterVertically
                            ) {
                                IconButton(onClick = { vm.prevPeriod() }) {
                                    Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null)
                                }
                                Text(state.currentYear.toString(), style = MaterialTheme.typography.titleMedium)
                                IconButton(onClick = { vm.nextPeriod() }) {
                                    Icon(Icons.AutoMirrored.Filled.ArrowForward, contentDescription = null)
                                }
                            }
                            Spacer(Modifier.height(8.dp))
                            YearCalendarView(
                                year       = state.currentYear,
                                summaries  = state.daySummaries,
                                limitGrams = state.limitInfo.limitGrams,
                                today      = state.today,
                                onDayClick = { date -> vm.selectDate(date) },
                                weekStart  = state.weekStartDay
                            )
                        }
                    }
                }
                state.selectedDate?.let { date ->
                    item {
                        Card(
                            colors   = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(Modifier.padding(16.dp)) {
                                // Show localised date instead of raw ISO string
                                Text(
                                    formatLogicalDate(date),
                                    style = MaterialTheme.typography.titleMedium
                                )
                                Spacer(Modifier.height(4.dp))
                                LimitBar(
                                    // Calendar shows a single historical day: only the
                                    // daily gram limit is meaningful here.
                                    totalGrams = state.totalGramsSelected,
                                    limitGrams = state.limitInfo.limitGrams,
                                    caption    = stringResource(
                                        R.string.limit_caption_day,
                                        "%.0f".format(state.limitInfo.limitGrams)
                                    )
                                )
                            }
                        }
                    }
                    if (state.selectedEntries.isEmpty()) {
                        item {
                            Text(
                                stringResource(R.string.no_entries_day),
                                style    = MaterialTheme.typography.bodyMedium,
                                color    = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.padding(vertical = 8.dp)
                            )
                        }
                    } else {
                        items(state.selectedEntries) { entry ->
                            EntryListItem(
                                entry    = entry,
                                onEdit   = { editEntry = entry },
                                onDelete = { deleteEntry = entry }
                            )
                        }
                    }
                }
            } else {
                // ── Month view ────────────────────────────────────────────────
                item {
                    MonthCalendar(
                        currentMonth = state.currentMonth,
                        daySummaries = state.daySummaries,
                        limitGrams   = state.limitInfo.limitGrams,
                        selectedDate = state.selectedDate,
                        weekStart    = state.weekStartDay,
                        onSelectDate = { vm.selectDate(it) },
                        onPrevMonth  = { vm.prevPeriod() },
                        onNextMonth  = { vm.nextPeriod() }
                    )
                }
                state.selectedDate?.let { date ->
                    item {
                        Card(
                            colors   = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Column(Modifier.padding(16.dp)) {
                                Text(
                                    formatLogicalDate(date),
                                    style = MaterialTheme.typography.titleMedium
                                )
                                Spacer(Modifier.height(4.dp))
                                LimitBar(
                                    // Calendar shows a single historical day: only the
                                    // daily gram limit is meaningful here.
                                    totalGrams = state.totalGramsSelected,
                                    limitGrams = state.limitInfo.limitGrams,
                                    caption    = stringResource(
                                        R.string.limit_caption_day,
                                        "%.0f".format(state.limitInfo.limitGrams)
                                    )
                                )
                            }
                        }
                    }
                    if (state.selectedEntries.isEmpty()) {
                        item {
                            Text(
                                stringResource(R.string.no_entries_day),
                                style    = MaterialTheme.typography.bodyMedium,
                                color    = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.padding(vertical = 8.dp)
                            )
                        }
                    } else {
                        items(state.selectedEntries) { entry ->
                            EntryListItem(
                                entry    = entry,
                                onEdit   = { editEntry = entry },
                                onDelete = { deleteEntry = entry }
                            )
                        }
                    }
                }
            }
        }
    }

    if (showAdd) {
        AddEditEntryDialog(
            entry     = null,
            drinks    = drinks,
            onSave    = { drink, vol, ts, note -> vm.addEntry(drink, vol, ts, note); showAdd = false },
            onDismiss = { showAdd = false }
        )
    }
    editEntry?.let { entry ->
        AddEditEntryDialog(
            entry     = entry,
            drinks    = drinks,
            onSave    = { drink, vol, ts, note ->
                vm.updateEntry(entry.copy(
                    drinkId         = drink.id,
                    drinkName       = drink.name,
                    volumeMl        = vol,
                    alcoholPercent  = drink.alcoholPercent,
                    gramsAlcohol    = AlcoholCalculator.calculateGrams(vol, drink.alcoholPercent),
                    timestampMillis = ts,
                    note            = note
                ))
                editEntry = null
            },
            onDismiss = { editEntry = null }
        )
    }
    deleteEntry?.let { entry ->
        AlertDialog(
            onDismissRequest = { deleteEntry = null },
            title  = { Text(stringResource(R.string.delete)) },
            text   = { Text(stringResource(R.string.delete_confirm, entry.drinkName)) },
            confirmButton  = {
                TextButton(onClick = { vm.deleteEntry(entry); deleteEntry = null }) {
                    Text(stringResource(R.string.delete), color = errorColor())
                }
            },
            dismissButton  = {
                TextButton(onClick = { deleteEntry = null }) { Text(stringResource(R.string.cancel)) }
            }
        )
    }
}

/** Converts a "YYYY-MM-DD" logical date string to a localised, human-readable format. */
@Composable
private fun formatLogicalDate(dateStr: String): String {
    return remember(dateStr) {
        try {
            LocalDate.parse(dateStr, DayResolver.DATE_FORMATTER)
                .format(DateTimeFormatter.ofLocalizedDate(FormatStyle.LONG).withLocale(Locale.getDefault()))
        } catch (e: Exception) {
            dateStr // fallback to raw ISO on parse error
        }
    }
}

/**
 * Renders one month as a 7-column day grid.
 *
 * Each day cell is tinted according to its total grams relative to [limitGrams],
 * and the [selectedDate] cell is highlighted.
 *
 * @param currentMonth The month to render.
 * @param daySummaries Map of "YYYY-MM-DD" → [de.godisch.potillus.domain.model.DaySummary].
 * @param limitGrams   Active daily limit, used to pick each cell's colour band.
 * @param selectedDate Currently selected day ("YYYY-MM-DD"), or `null`.
 * @param onSelectDate Invoked with the tapped day's ISO date string.
 */
@Composable
private fun MonthCalendar(
    currentMonth: YearMonth,
    daySummaries: Map<String, de.godisch.potillus.domain.model.DaySummary>,
    limitGrams: Double,
    selectedDate: String?,
    weekStart: Int,
    onSelectDate: (String) -> Unit,
    onPrevMonth: () -> Unit,
    onNextMonth: () -> Unit
) {
    Card(modifier = Modifier.fillMaxWidth()) {
        Column(Modifier.padding(12.dp)) {
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment     = Alignment.CenterVertically
            ) {
                IconButton(onClick = onPrevMonth) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = null)
                }
                Text(
                    currentMonth.format(DateTimeFormatter.ofPattern("MMMM yyyy", Locale.getDefault())),
                    style = MaterialTheme.typography.titleMedium
                )
                IconButton(onClick = onNextMonth) {
                    Icon(Icons.AutoMirrored.Filled.ArrowForward, contentDescription = null)
                }
            }
            Row(Modifier.fillMaxWidth()) {
                // Weekday header rotated so column 0 is the configured first day of
                // the week. weekStart is ISO 1..7; (weekStart - 1 + i) % 7 + 1 walks
                // the seven weekdays in display order.
                (0..6).map { i ->
                    DayOfWeek.of((weekStart - 1 + i) % 7 + 1)
                        .getDisplayName(TextStyle.SHORT, Locale.getDefault()).take(2)
                }.forEach { label ->
                    Text(
                        label,
                        modifier = Modifier.weight(1f),
                        textAlign = TextAlign.Center,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
            val firstDay    = currentMonth.atDay(1)
            val totalDays   = currentMonth.lengthOfMonth()
            val startOffset = (firstDay.dayOfWeek.value - weekStart + 7) % 7
            val rows        = (startOffset + totalDays + 6) / 7

            // Capture composable color before the loop
            val overLimitColor = errorColor()

            repeat(rows) { row ->
                Row(Modifier.fillMaxWidth()) {
                    repeat(7) { col ->
                        val day = row * 7 + col - startOffset + 1
                        if (day in 1..totalDays) {
                            val date       = DayResolver.formatDate(currentMonth.atDay(day))
                            val summary    = daySummaries[date]
                            val isSelected = date == selectedDate
                            Box(
                                modifier = Modifier
                                    .weight(1f).aspectRatio(1f)
                                    .clip(MaterialTheme.shapes.small)
                                    .background(if (isSelected) MaterialTheme.colorScheme.primary else Color.Transparent)
                                    .clickable { onSelectDate(date) },
                                contentAlignment = Alignment.Center
                            ) {
                                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                    Text(
                                        day.toString(),
                                        style = MaterialTheme.typography.bodySmall,
                                        color = if (isSelected) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurface
                                    )
                                    if (summary != null) {
                                        Box(
                                            Modifier.size(5.dp)
                                                .clip(MaterialTheme.shapes.extraSmall)
                                                .background(
                                                    if (summary.totalGrams > limitGrams) overLimitColor
                                                    else MaterialTheme.colorScheme.primary
                                                )
                                        )
                                    }
                                }
                            }
                        } else {
                            Spacer(Modifier.weight(1f).aspectRatio(1f))
                        }
                    }
                }
            }
        }
    }
}
