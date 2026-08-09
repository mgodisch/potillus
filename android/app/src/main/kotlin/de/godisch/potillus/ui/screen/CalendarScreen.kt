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

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import de.godisch.potillus.R
import de.godisch.potillus.domain.AlcoholCalculator
import de.godisch.potillus.domain.DayResolver
import de.godisch.potillus.domain.model.*
import de.godisch.potillus.l10n.fmt0
import de.godisch.potillus.l10n.formattingLocale
import de.godisch.potillus.l10n.monthYearFormatter
import de.godisch.potillus.ui.component.*
import de.godisch.potillus.ui.theme.dangerOnSelectionColor
import de.godisch.potillus.ui.theme.dangerRedColor
import de.godisch.potillus.ui.theme.dangerTextColor
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.time.format.TextStyle

/**
 * Calendar tab: a month or year grid colour-coded by daily alcohol intake,
 * with a per-day detail/entry sheet.
 *
 * @param vm             The [CalendarViewModel]; defaults to the Activity-scoped instance.
 * @param onOpenSettings Invoked when the top-bar gear icon is tapped.
 * @param onOpenHelp     Invoked when the overflow-menu Help item is tapped.
 * @param onOpenAbout    Invoked when the overflow-menu About item is tapped.
 * @param onLockApp      Locks the app immediately (overflow-menu "Lock app").
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CalendarScreen(
    vm: CalendarViewModel = viewModel(),
    onOpenSettings: () -> Unit = {},
    onOpenHelp: () -> Unit = {},
    onOpenAbout: () -> Unit = {},
    /** Locks the app immediately (overflow-menu "Lock app"). */
    onLockApp: () -> Unit = {},
) {
    val state by vm.uiState.collectAsStateWithLifecycle()
    val drinks by vm.drinks.collectAsStateWithLifecycle()
    // `showAdd` is rememberSaveable so an open add-entry dialog survives
    // a configuration change; it targets the ViewModel's selectedDate (which also
    // survives), so no extra state is needed. `editEntry`/`deleteEntry` hold domain
    // objects (ConsumptionEntry) that are intentionally NOT Parcelable (the domain
    // layer is Android-free), so they stay plain `remember`: on recreation the
    // edit/delete dialog closes cleanly rather than reopening with a lost target.
    var showAdd by rememberSaveable { mutableStateOf(false) }
    var editEntry by remember { mutableStateOf<ConsumptionEntry?>(null) }
    var deleteEntry by remember { mutableStateOf<ConsumptionEntry?>(null) }

    // ENTERING THE SCREEN RETURNS TO THE CURRENT MONTH, a rotation does not.
    //
    // The month and the day selection live in the ViewModel, which outlives both:
    // it is created in AppNav and survives a configuration change as well as a trip
    // to another screen. So the reset cannot hang off the model's lifetime and
    // needs something that tells the two apart — this marker does, exactly as on
    // the statistics screen. rememberSaveable is restored from the saved state
    // after a rotation (marker present: the same screen, keep the user's place)
    // and starts out false when the composable was discarded and rebuilt, which is
    // what a return from another screen looks like (marker absent: start at today).
    //
    // Why the calendar resets at all: the plus button logs to the SELECTED day. A
    // selection left over from browsing March would turn the next tap on it into an
    // entry booked three months back. See CalendarViewModel.resetToCurrentMonth.
    var visited by rememberSaveable { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        if (!visited) {
            vm.resetToCurrentMonth()
            visited = true
        }
    }

    val isYear = state.viewMode == CalendarViewMode.YEAR

    // Per-app locale for the daily-limit caption number, so its formatting matches
    // the in-app language rather than the system locale (see l10n/NumberFormat.kt).
    val locale = LocalContext.current.formattingLocale()

    Scaffold(
        contentWindowInsets = WindowInsets(0),
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.calendar)) },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    titleContentColor = MaterialTheme.colorScheme.onPrimary,
                ),
                actions = {
                    TextButton(onClick = { vm.toggleViewMode() }) {
                        Text(
                            if (isYear) stringResource(R.string.month) else stringResource(R.string.year),
                            color = MaterialTheme.colorScheme.onPrimary,
                        )
                    }
                    AppOverflowMenu(
                        onOpenSettings = onOpenSettings,
                        onOpenHelp = onOpenHelp,
                        onOpenAbout = onOpenAbout,
                        onLockApp = onLockApp,
                        tint = MaterialTheme.colorScheme.onPrimary,
                    )
                },
            )
        },
        floatingActionButton = {
            if (state.selectedDate != null) {
                FloatingActionButton(
                    onClick = { showAdd = true },
                    containerColor = MaterialTheme.colorScheme.primary,
                    contentColor = MaterialTheme.colorScheme.onPrimary,
                ) {
                    Icon(Icons.Default.Add, contentDescription = stringResource(R.string.add_entry))
                }
            }
        },
    ) { paddingValues ->
        LazyColumn(
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.fillMaxSize().padding(paddingValues),
        ) {
            if (isYear) {
                // ── Year view ─────────────────────────────────────────────────
                item {
                    SectionCard(contentPadding = 12.dp) {
                        Row(
                            Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            IconButton(onClick = { vm.prevPeriod() }) {
                                // Accessible name for the icon-only navigation
                                // button: without it a screen reader announces
                                // just "button" (WCAG 4.1.2 / name-role-value).
                                Icon(
                                    Icons.AutoMirrored.Filled.ArrowBack,
                                    contentDescription = stringResource(R.string.cd_prev_year),
                                )
                            }
                            Text(state.currentYear.toString(), style = MaterialTheme.typography.titleMedium)
                            IconButton(onClick = { vm.nextPeriod() }) {
                                Icon(
                                    Icons.AutoMirrored.Filled.ArrowForward,
                                    contentDescription = stringResource(R.string.cd_next_year),
                                )
                            }
                        }
                        Spacer(Modifier.height(8.dp))
                        YearCalendarView(
                            year = state.currentYear,
                            summaries = state.daySummaries,
                            limitGrams = state.limitInfo.limitGrams,
                            today = state.today,
                            onMonthClick = { month -> vm.showMonth(month) },
                            weekStart = state.weekStartDay,
                            statsFrom = state.statsFrom,
                        )
                    }
                }
                state.selectedDate?.let { date ->
                    item {
                        Card(
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer),
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Column(Modifier.padding(16.dp)) {
                                // Show localised date instead of raw ISO string
                                Text(
                                    formatLogicalDate(date),
                                    style = MaterialTheme.typography.titleMedium,
                                )
                                Spacer(Modifier.height(4.dp))
                                LimitBar(
                                    // Calendar shows a single historical day: only the
                                    // daily gram limit is meaningful here.
                                    totalGrams = state.totalGramsSelected,
                                    limitGrams = state.limitInfo.limitGrams,
                                    caption = stringResource(
                                        R.string.limit_caption_day,
                                        state.limitInfo.limitGrams.fmt0(locale),
                                    ),
                                )
                            }
                        }
                    }
                    if (state.selectedEntries.isEmpty()) {
                        item {
                            Text(
                                stringResource(R.string.no_entries_day),
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.padding(vertical = 8.dp),
                            )
                        }
                    } else {
                        // Stable Room id as key: entries of the selected day can be
                        // deleted in place; keyed items let Compose remove exactly the
                        // affected row instead of rebinding all following positions.
                        items(state.selectedEntries, key = { it.id }) { entry ->
                            EntryListItem(
                                entry = entry,
                                onEdit = { editEntry = entry },
                                onDelete = { deleteEntry = entry },
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
                        limitGrams = state.limitInfo.limitGrams,
                        selectedDate = state.selectedDate,
                        weekStart = state.weekStartDay,
                        onSelectDate = { vm.selectDate(it) },
                        onPrevMonth = { vm.prevPeriod() },
                        onNextMonth = { vm.nextPeriod() },
                    )
                }
                state.selectedDate?.let { date ->
                    item {
                        Card(
                            colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.primaryContainer),
                            modifier = Modifier.fillMaxWidth(),
                        ) {
                            Column(Modifier.padding(16.dp)) {
                                Text(
                                    formatLogicalDate(date),
                                    style = MaterialTheme.typography.titleMedium,
                                )
                                Spacer(Modifier.height(4.dp))
                                LimitBar(
                                    // Calendar shows a single historical day: only the
                                    // daily gram limit is meaningful here.
                                    totalGrams = state.totalGramsSelected,
                                    limitGrams = state.limitInfo.limitGrams,
                                    caption = stringResource(
                                        R.string.limit_caption_day,
                                        state.limitInfo.limitGrams.fmt0(locale),
                                    ),
                                )
                            }
                        }
                    }
                    if (state.selectedEntries.isEmpty()) {
                        item {
                            Text(
                                stringResource(R.string.no_entries_day),
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.padding(vertical = 8.dp),
                            )
                        }
                    } else {
                        // Stable Room id as key: entries of the selected day can be
                        // deleted in place; keyed items let Compose remove exactly the
                        // affected row instead of rebinding all following positions.
                        items(state.selectedEntries, key = { it.id }) { entry ->
                            EntryListItem(
                                entry = entry,
                                onEdit = { editEntry = entry },
                                onDelete = { deleteEntry = entry },
                            )
                        }
                    }
                }
            }
        }
    }

    if (showAdd) {
        AddEditEntryDialog(
            entry = null,
            drinks = drinks,
            onSave = { drink, vol, ts, note ->
                vm.addEntry(drink, vol, ts, note)
                showAdd = false
            },
            onDismiss = { showAdd = false },
        )
    }
    editEntry?.let { entry ->
        AddEditEntryDialog(
            entry = entry,
            drinks = drinks,
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
                    Text(stringResource(R.string.delete), color = dangerTextColor())
                }
            },
            dismissButton = {
                TextButton(onClick = { deleteEntry = null }) { Text(stringResource(R.string.cancel)) }
            },
        )
    }
}

/** Converts a "YYYY-MM-DD" logical date string to a localised, human-readable format. */
@Composable
private fun formatLogicalDate(dateStr: String): String {
    // Use the per-app locale (not Locale.getDefault(), which stays on the system
    // locale) so the formatted month name matches the rest of the localized UI.
    // The locale is a remember key so the date re-formats when the user switches
    // the in-app language.
    val locale = LocalContext.current.formattingLocale()
    return remember(dateStr, locale) {
        try {
            LocalDate.parse(dateStr, DayResolver.DATE_FORMATTER)
                .format(DateTimeFormatter.ofLocalizedDate(FormatStyle.LONG).withLocale(locale))
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
    onNextMonth: () -> Unit,
) {
    // Per-app locale for the month header and weekday names (see formattingLocale).
    val locale = LocalContext.current.formattingLocale()
    SectionCard(contentPadding = 12.dp) {
        Row(
            Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = onPrevMonth) {
                // Accessible name for the icon-only navigation button (see the
                // year navigation above; WCAG 4.1.2 name-role-value).
                Icon(
                    Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = stringResource(R.string.cd_prev_month),
                )
            }
            Text(
                // monthYearFormatter (NOT a literal "MMMM yyyy"): the label's
                // field order and month FORM are locale data — CJK is
                // year-first ("2026年6月") and inflected languages need the
                // standalone month ("czerwiec 2026"), see l10n/LocaleSupport.kt.
                currentMonth.format(monthYearFormatter(locale)),
                style = MaterialTheme.typography.titleMedium,
                // LAYOUT HARDENING (v0.81.0 QA, eighth round): between two
                // fixed-size IconButtons an unweighted Text is measured at its
                // intrinsic width and can claim everything the previous sibling
                // left over, pushing the "next month" arrow off the row. The
                // weight bounds it; centring is preserved explicitly because the
                // weighted child now fills the gap that SpaceBetween used to
                // create, and a long name (el "Σεπτέμβριος 2026") ellipsizes
                // instead of displacing a control.
                modifier = Modifier.weight(1f),
                textAlign = TextAlign.Center,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            IconButton(onClick = onNextMonth) {
                Icon(
                    Icons.AutoMirrored.Filled.ArrowForward,
                    contentDescription = stringResource(R.string.cd_next_month),
                )
            }
        }
        Row(Modifier.fillMaxWidth()) {
            // Weekday header rotated so column 0 is the configured first day of
            // the week. weekStart is ISO 1..7; (weekStart - 1 + i) % 7 + 1 walks
            // the seven weekdays in display order.
            (0..6).map { i ->
                DayOfWeek.of((weekStart - 1 + i) % 7 + 1)
                    .getDisplayName(TextStyle.SHORT, locale).take(2)
            }.forEach { label ->
                Text(
                    label,
                    modifier = Modifier.weight(1f),
                    textAlign = TextAlign.Center,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        val firstDay = currentMonth.atDay(1)
        val totalDays = currentMonth.lengthOfMonth()
        val startOffset = (firstDay.dayOfWeek.value - weekStart + 7) % 7
        val rows = (startOffset + totalDays + 6) / 7

        // Capture composable color before the loop.
        //
        // dangerRedColor(), not errorColor(): an over-limit day is the same fact
        // the traffic-light dot, the year heat-map cell and the chart's bar
        // report, and it carries the same shade. errorColor() is Material's error
        // ROLE -- an invalid input, a failed export -- and this grid states no
        // error. The two were the same colour to the eye until the dark theme's
        // reds were measured; #CF6679 reads pink beside #DD2C2C.
        val overLimitColor = dangerRedColor()
        // Long, localized date used in each day cell's accessibility label
        // (built once per grid composition rather than per cell).
        val dayDescFmt = DateTimeFormatter.ofLocalizedDate(FormatStyle.LONG).withLocale(locale)

        repeat(rows) { row ->
            Row(Modifier.fillMaxWidth()) {
                repeat(7) { col ->
                    val day = row * 7 + col - startOffset + 1
                    if (day in 1..totalDays) {
                        val date = DayResolver.formatDate(currentMonth.atDay(day))
                        val summary = daySummaries[date]
                        val isSelected = date == selectedDate
                        // Accessibility label: the under/over-limit state is shown
                        // on screen by the dot's COLOUR only, so a screen reader
                        // would otherwise miss it (WCAG 1.4.1 / 1.1.1). Reuse the
                        // year heat-map's "date, grams, status" caption strings so
                        // no new locale keys are needed. Empty days stay unlabelled.
                        // Only a day with alcohol carries a status: the dot below is
                        // drawn for exactly those days, and "0.0 g, under limit"
                        // spoken over a cell that shows no dot would put label and
                        // display at odds. A day of alcohol-free entries stays
                        // silent like an empty one; its entries are one tap away in
                        // the day list below the grid.
                        val drinkSummary =
                            summary?.takeIf { AlcoholCalculator.isDrinkDay(it.totalGrams) }
                        val dayDesc: String? = drinkSummary?.let { s ->
                            val statusRes = if (AlcoholCalculator.isOverLimit(s.totalGrams, limitGrams)) {
                                R.string.year_calendar_over_limit
                            } else {
                                R.string.year_calendar_under_limit
                            }
                            stringResource(
                                R.string.year_calendar_day_desc,
                                dayDescFmt.format(currentMonth.atDay(day)),
                                s.totalGrams.fmt0(locale),
                                stringResource(statusRes),
                            )
                        }
                        var focused by remember { mutableStateOf(false) }
                        Box(
                            modifier = Modifier
                                .weight(1f).aspectRatio(1f)
                                .clip(MaterialTheme.shapes.small)
                                .background(if (isSelected) MaterialTheme.colorScheme.primary else Color.Transparent)
                                // FOCUS VISIBILITY (WCAG 2.4.7). Unlike the year
                                // heat-map's cells this one fills its whole slot,
                                // so the ring has to sit ON the cell and its
                                // colour follows the fill: onPrimary over a
                                // selected cell (5.67:1 dark, 10.21:1 light),
                                // onSurface over an unselected one, which is the
                                // card surface (12.42:1 and 14.73:1). Both are
                                // existing role colours; no new value is needed
                                // because here, unlike the heat-map, there are
                                // only two possible backgrounds.
                                .onFocusChanged { focused = it.isFocused }
                                .then(
                                    if (focused) {
                                        Modifier.border(
                                            2.dp,
                                            if (isSelected) {
                                                MaterialTheme.colorScheme.onPrimary
                                            } else {
                                                MaterialTheme.colorScheme.onSurface
                                            },
                                            MaterialTheme.shapes.small,
                                        )
                                    } else {
                                        Modifier
                                    },
                                )
                                .then(
                                    // Rich label for days with data; day-number text
                                    // remains the name for empty days.
                                    dayDesc?.let { d -> Modifier.semantics { contentDescription = d } } ?: Modifier,
                                )
                                // role = Button so assistive tech announces the cell as
                                // an actionable control (WCAG 4.1.2 Name, Role, Value).
                                .clickable(role = Role.Button) { onSelectDate(date) },
                            contentAlignment = Alignment.Center,
                        ) {
                            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                Text(
                                    day.toString(),
                                    style = MaterialTheme.typography.bodySmall,
                                    color = if (isSelected) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurface,
                                )
                                // The dot means alcohol, not "something is logged":
                                // it is drawn in the neutral or the over-limit colour,
                                // and neither reading fits a day of alcohol-free
                                // entries. Such a day looks like a dry one here, as it
                                // does in the year heat map.
                                if (drinkSummary != null) {
                                    // On a selected cell the background is
                                    // `primary`, so neither of the normal dot
                                    // colours works there: the neutral dot IS
                                    // `primary` (1.00:1, invisible) and the
                                    // over-limit red sits within 1.4:1 of it.
                                    // Both therefore switch to the container
                                    // pair while the cell is selected. See the
                                    // STATUS COLOURS note in theme/Color.kt.
                                    val over = AlcoholCalculator.isOverLimit(drinkSummary.totalGrams, limitGrams)
                                    val dotColor = when {
                                        isSelected && over -> dangerOnSelectionColor()
                                        isSelected -> MaterialTheme.colorScheme.primaryContainer
                                        over -> overLimitColor
                                        else -> MaterialTheme.colorScheme.primary
                                    }
                                    Box(
                                        Modifier.size(5.dp)
                                            .clip(MaterialTheme.shapes.extraSmall)
                                            .background(dotColor),
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
