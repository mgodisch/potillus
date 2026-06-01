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

import android.content.Intent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Settings
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.app.ShareCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import de.godisch.potillus.R
import de.godisch.potillus.domain.DayResolver
import de.godisch.potillus.domain.model.*
import de.godisch.potillus.ui.component.*
import de.godisch.potillus.ui.theme.errorColor
import de.godisch.potillus.ui.theme.successColor
import kotlinx.coroutines.delay
import java.time.LocalDate
import java.time.format.TextStyle
import java.util.Locale

/**
 * Statistics tab: KPIs (totals, averages, binge/over-limit days, trends) and
 * charts for the selected [StatsPeriod].
 *
 * @param vm The [StatsViewModel]; defaults to the Activity-scoped instance.
 * @param onOpenSettings Invoked when the top-bar gear icon is tapped.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StatsScreen(vm: StatsViewModel = viewModel(), onOpenSettings: () -> Unit = {}) {
    val state by vm.uiState.collectAsStateWithLifecycle()
    val exportStatus by vm.exportStatus.collectAsStateWithLifecycle()
    val shareTarget  by vm.shareTarget.collectAsStateWithLifecycle()
    val context = LocalContext.current

    // Export date-range dialogs (CSV/PDF export lives on the Statistics screen).
    // rememberSaveable so an open dialog survives a configuration change
    // (rotation, theme/language switch). The dialogs read their initial range from
    // `state` (the ViewModel), so no extra state needs saving.
    var showCsvRangeDialog by rememberSaveable { mutableStateOf(false) }
    var showPdfRangeDialog by rememberSaveable { mutableStateOf(false) }

    // Auto-dismiss the export status banner after 3 seconds.
    exportStatus?.let { status ->
        LaunchedEffect(status) {
            delay(3_000)
            vm.clearExportStatus()
        }
    }

    // Open the share sheet once after a successful export, then clear the target
    // so it does not reappear on recomposition. PDFs get an ACTION_VIEW-based
    // chooser (so PDF readers/printers appear) with an injected ACTION_SEND intent
    // for messengers/cloud apps; CSV uses a plain ACTION_SEND chooser. (This is the
    // same logic that previously lived in SettingsScreen for CSV/PDF.)
    LaunchedEffect(shareTarget) {
        val target = shareTarget ?: return@LaunchedEffect
        val intent = if (target.mimeType == "application/pdf") {
            val sendIntent = Intent(Intent.ACTION_SEND).apply {
                type = target.mimeType
                putExtra(Intent.EXTRA_STREAM, target.uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            Intent.createChooser(
                Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(target.uri, target.mimeType)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                },
                target.fileName
            ).apply {
                putExtra(Intent.EXTRA_INITIAL_INTENTS, arrayOf(sendIntent))
            }
        } else {
            ShareCompat.IntentBuilder(context)
                .setType(target.mimeType)
                .addStream(target.uri)
                .setChooserTitle(target.fileName)
                .createChooserIntent()
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(intent)
        vm.clearShareTarget()
    }

    Scaffold(
        contentWindowInsets = WindowInsets(0),
        topBar = {
            TopAppBar(
                title  = { Text(stringResource(R.string.statistics)) },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor    = MaterialTheme.colorScheme.primary,
                    titleContentColor = MaterialTheme.colorScheme.onPrimary
                ),
                actions = {
                    IconButton(onClick = onOpenSettings) {
                        Icon(Icons.Default.Settings, contentDescription = stringResource(R.string.settings),
                            tint = MaterialTheme.colorScheme.onPrimary)
                    }
                }
            )
        }
    ) { paddingValues ->
        LazyColumn(
            contentPadding      = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            modifier            = Modifier.fillMaxSize().padding(paddingValues)
        ) {
            // ── Period selector ───────────────────────────────────────────
            item {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    StatsPeriod.entries.forEach { p ->
                        val labelRes = when (p) {
                            StatsPeriod.WEEK  -> R.string.week
                            StatsPeriod.MONTH -> R.string.month
                            StatsPeriod.YEAR  -> R.string.year
                        }
                        FilterChip(
                            selected = state.period == p,
                            onClick  = { vm.setPeriod(p) },
                            label    = { Text(stringResource(labelRes)) },
                            modifier = Modifier.weight(1f)
                        )
                    }
                }
            }

            // ── Bar chart ─────────────────────────────────────────────────
            item {
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(16.dp)) {
                        val labelFn: (String) -> String = { date ->
                            when (state.period) {
                                StatsPeriod.WEEK  -> LocalDate.parse(date, DayResolver.DATE_FORMATTER)
                                    .dayOfWeek.getDisplayName(TextStyle.SHORT, Locale.getDefault())
                                StatsPeriod.MONTH -> date.substring(8)   // day-of-month
                                StatsPeriod.YEAR  -> date.substring(5, 7) // month number
                            }
                        }
                        AlcoholBarChart(
                            dataPoints = state.dataPoints,
                            limitGrams = state.limitInfo.limitGrams,
                            labelFn    = labelFn
                        )
                    }
                }
            }

            // ── Key metrics ───────────────────────────────────────────────
            item {
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        StatRow(stringResource(R.string.total_period), "${"%.1f".format(state.totalGrams)} g")
                        HorizontalDivider()
                        StatRow(stringResource(R.string.avg_per_day), "${"%.1f".format(state.avgPerDay)} g")
                        HorizontalDivider()
                        StatRow(stringResource(R.string.avg_per_drink_day), "${"%.1f".format(state.avgPerDrinkDay)} g")
                        HorizontalDivider()
                        StatRow(
                            stringResource(R.string.days_over_daily_limit),
                            state.daysOverDailyLimit.toString(),
                            valueColor = if (state.daysOverDailyLimit > 0) errorColor() else successColor()
                        )
                        HorizontalDivider()
                        StatRow(
                            stringResource(R.string.days_over_weekly_limit),
                            state.daysOverWeeklyLimit.toString(),
                            valueColor = if (state.daysOverWeeklyLimit > 0) errorColor() else successColor()
                        )
                        HorizontalDivider()
                        StatRow(
                            stringResource(R.string.days_over_drink_day_limit),
                            state.daysOverDrinkDayLimit.toString(),
                            valueColor = if (state.daysOverDrinkDayLimit > 0) errorColor() else successColor()
                        )
                        HorizontalDivider()
                        StatRow(
                            stringResource(R.string.abstinent_days),
                            state.abstinentDays.toString(),
                            valueColor = if (state.abstinentDays > 0) successColor() else MaterialTheme.colorScheme.onSurface
                        )
                    }
                }
            }

            // ── Streaks & trend ───────────────────────────────────────────
            item {
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(stringResource(R.string.streak_trend),
                            style = MaterialTheme.typography.titleSmall,
                            color = MaterialTheme.colorScheme.primary)
                        HorizontalDivider()
                        StatRow(
                            stringResource(R.string.current_streak),
                            stringResource(R.string.days_count, state.currentStreak),
                            valueColor = if (state.currentStreak > 0) successColor() else MaterialTheme.colorScheme.onSurface
                        )
                        HorizontalDivider()
                        StatRow(stringResource(R.string.longest_streak), stringResource(R.string.days_count, state.longestStreak))
                        HorizontalDivider()
                        val trendText = when {
                            state.trendPercent > 0 -> "+${"%.0f".format(state.trendPercent)} % ↑"
                            state.trendPercent < 0 -> "${"%.0f".format(state.trendPercent)} % ↓"
                            else                   -> "–"
                        }
                        StatRow(
                            stringResource(R.string.trend_vs_prev),
                            trendText,
                            valueColor = when {
                                state.trendPercent > 0 -> errorColor()
                                state.trendPercent < 0 -> successColor()
                                else                   -> MaterialTheme.colorScheme.onSurface
                            }
                        )
                    }
                }
            }

            // ── Category breakdown donut chart ────────────────────────────
            if (state.categoryBreakdown.isNotEmpty()) {
                item {
                    Card(modifier = Modifier.fillMaxWidth()) {
                        Column(Modifier.padding(16.dp)) {
                            Text(
                                stringResource(R.string.stats_category_breakdown),
                                style = MaterialTheme.typography.titleSmall,
                                color = MaterialTheme.colorScheme.primary
                            )
                            Spacer(Modifier.height(12.dp))
                            CategoryDonutChart(data = state.categoryBreakdown)
                        }
                    }
                }
            }

            // ── Data export (CSV / PDF) ───────────────────────────────────
            // Sits at the bottom of the
            // statistics content; a button opens a date-range dialog, then a
            // share sheet once the file has been written.
            item {
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(16.dp)) {
                        Text(
                            stringResource(R.string.export),
                            style = MaterialTheme.typography.titleSmall,
                            color = MaterialTheme.colorScheme.primary
                        )
                        Spacer(Modifier.height(4.dp))
                        Text(
                            stringResource(R.string.export_desc),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Spacer(Modifier.height(8.dp))
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            OutlinedButton(onClick = { showCsvRangeDialog = true }, modifier = Modifier.weight(1f)) {
                                Text(stringResource(R.string.export_csv))
                            }
                            OutlinedButton(onClick = { showPdfRangeDialog = true }, modifier = Modifier.weight(1f)) {
                                Text(stringResource(R.string.export_pdf))
                            }
                        }
                        exportStatus?.let { status ->
                            Spacer(Modifier.height(8.dp))
                            Text(
                                when (status) {
                                    is ExportStatus.Done -> status.message
                                    is ExportStatus.Err  -> status.message
                                },
                                style = MaterialTheme.typography.bodySmall,
                                color = when (status) {
                                    is ExportStatus.Done -> successColor()
                                    is ExportStatus.Err  -> errorColor()
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    // ── Export date-range dialogs ──────────────────────────────────────────
    // `today` may be empty until the stats flow's first emission; fall back to
    // the calendar date so the pickers always receive a valid initial value.
    val exportToday = state.today.ifEmpty { LocalDate.now().toString() }
    if (showCsvRangeDialog) {
        ExportDateRangeDialog(
            initialFrom = state.statsFromDate.ifEmpty { exportToday },
            initialTo   = exportToday,
            onConfirm   = { from, to ->
                vm.exportCsv(from, to)
                showCsvRangeDialog = false
            },
            onDismiss   = { showCsvRangeDialog = false }
        )
    }
    if (showPdfRangeDialog) {
        ExportDateRangeDialog(
            initialFrom = state.statsFromDate.ifEmpty { exportToday },
            initialTo   = exportToday,
            onConfirm   = { from, to ->
                vm.exportPdf(from, to)
                showPdfRangeDialog = false
            },
            onDismiss   = { showPdfRangeDialog = false }
        )
    }
}

/**
 * A single label/value statistics row (label left, value right).
 *
 * @param label      Row caption.
 * @param value      Formatted value text.
 * @param valueColor Optional colour for the value (e.g. red for over-limit).
 */
@Composable
private fun StatRow(label: String, value: String, valueColor: Color = MaterialTheme.colorScheme.onSurface) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurface)
        Text(value, style = MaterialTheme.typography.bodyMedium, fontWeight = FontWeight.Medium, color = valueColor)
    }
}
