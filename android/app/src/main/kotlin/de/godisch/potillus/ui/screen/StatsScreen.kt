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

import android.content.Intent
import android.widget.Toast
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.app.ShareCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import de.godisch.potillus.R
import de.godisch.potillus.domain.ChartBucket
import de.godisch.potillus.domain.DayResolver
import de.godisch.potillus.domain.Trend
import de.godisch.potillus.domain.model.*
import de.godisch.potillus.l10n.fmt0
import de.godisch.potillus.l10n.fmt1
import de.godisch.potillus.l10n.formattingLocale
import de.godisch.potillus.ui.component.*
import de.godisch.potillus.ui.theme.dangerRedColor
import de.godisch.potillus.ui.theme.successColor
import de.godisch.potillus.util.WebViewPdfPrinter
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.format.TextStyle

/**
 * Statistics tab: KPIs (totals, averages, binge/over-limit days, trends) and
 * charts for the selected [StatsPeriod].
 *
 * @param vm             The [StatsViewModel]; defaults to the Activity-scoped instance.
 * @param onOpenSettings Invoked when the top-bar gear icon is tapped.
 * @param onOpenHelp     Invoked when the overflow-menu Help item is tapped.
 * @param onOpenCopyright Invoked when the overflow-menu Copyright item is tapped.
 * @param onLockApp      Locks the app immediately (overflow-menu "Lock app").
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StatsScreen(
    vm: StatsViewModel = viewModel(),
    onOpenSettings: () -> Unit = {},
    onOpenHelp: () -> Unit = {},
    onOpenCopyright: () -> Unit = {},
    /** Locks the app immediately (overflow-menu "Lock app"). */
    onLockApp: () -> Unit = {},
) {
    val state by vm.uiState.collectAsStateWithLifecycle()
    val exportStatus by vm.exportStatus.collectAsStateWithLifecycle()
    val shareTarget by vm.shareTarget.collectAsStateWithLifecycle()
    val printRequest by vm.printRequest.collectAsStateWithLifecycle()
    val context = LocalContext.current
    // Per-app locale for chart axis labels (weekday / month names). Derived from
    // the context so it follows the in-app language, not Locale.getDefault().
    val locale = context.formattingLocale()

    // Export date-range dialogs (CSV/PDF export lives on the Statistics screen).
    // rememberSaveable so an open dialog survives a configuration change
    // (rotation, theme/language switch). The dialogs read their initial range from
    // `state` (the ViewModel), so no extra state needs saving.
    var showCsvRangeDialog by rememberSaveable { mutableStateOf(false) }
    var showPdfRangeDialog by rememberSaveable { mutableStateOf(false) }

    // An export that produces no file (e.g. no entries in the chosen range) is
    // reported via [exportStatus]. Surface the ERROR as a short, self-dismissing
    // Toast so it is noticed regardless of scroll position. The SUCCESS case is
    // deliberately NOT surfaced here: a successful CSV export opens the share sheet
    // and a PDF export opens the system print dialog, so the outcome is already
    // obvious; we only consume the status to clear it.
    LaunchedEffect(exportStatus) {
        when (val status = exportStatus) {
            is ExportStatus.Err -> {
                Toast.makeText(context, status.message, Toast.LENGTH_LONG).show()
                vm.clearExportStatus()
            }
            is ExportStatus.Done -> vm.clearExportStatus() // success shown by share/print dialog
            null -> Unit
        }
    }

    // Open the share sheet once after a successful CSV export, then clear the
    // target so it does not reappear on recomposition. As of v0.61.0 only CSV
    // flows through [shareTarget]; the PDF report is handled by the system print
    // dialog (see the printRequest effect below), so no PDF branch is needed here.
    LaunchedEffect(shareTarget) {
        val target = shareTarget ?: return@LaunchedEffect
        val intent = ShareCompat.IntentBuilder(context)
            .setType(target.mimeType)
            .addStream(target.uri)
            .setChooserTitle(target.fileName)
            .createChooserIntent()
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        context.startActivity(intent)
        vm.clearShareTarget()
    }

    // Open the system print dialog once a PDF report has been rendered, then clear
    // the request. The user chooses "Save as PDF" (or a printer) and the file's
    // destination there — the print framework owns saving/sharing for PDFs.
    LaunchedEffect(printRequest) {
        val req = printRequest ?: return@LaunchedEffect
        WebViewPdfPrinter.print(context, req.html, req.jobName)
        vm.clearPrintRequest()
    }

    Scaffold(
        contentWindowInsets = WindowInsets(0),
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.statistics)) },
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
    ) { paddingValues ->
        LazyColumn(
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.fillMaxSize().padding(paddingValues),
        ) {
            // ── Period selector ───────────────────────────────────────────
            item {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    StatsPeriod.entries.forEach { p ->
                        val labelRes = when (p) {
                            StatsPeriod.WEEK -> R.string.week
                            StatsPeriod.MONTH -> R.string.month
                            StatsPeriod.YEAR -> R.string.year
                        }
                        FilterChip(
                            selected = state.period == p,
                            onClick = { vm.setPeriod(p) },
                            label = { Text(stringResource(labelRes)) },
                            modifier = Modifier.weight(1f),
                        )
                    }
                }
            }

            // ── Bar chart ─────────────────────────────────────────────────
            item {
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(16.dp)) {
                        val labelFn: (ChartBucket) -> String = { b ->
                            val d = LocalDate.parse(b.labelDate, DayResolver.DATE_FORMATTER)
                            when (state.period) {
                                StatsPeriod.WEEK -> d.dayOfWeek.getDisplayName(TextStyle.SHORT, locale)
                                StatsPeriod.MONTH -> b.labelDate.substring(8) // day-of-month
                                // YEAR uses one bucket per calendar month, so the
                                // month name of the bucket's first day is the bar's
                                // natural label (one label per month).
                                StatsPeriod.YEAR -> d.month.getDisplayName(TextStyle.SHORT, locale)
                            }
                        }
                        val isYear = state.period == StatsPeriod.YEAR
                        AlcoholBarChart(
                            buckets = state.chartBuckets,
                            limitGrams = state.limitInfo.limitGrams,
                            labelFn = labelFn,
                            // No daily-limit line in the YEAR view: its monthly
                            // per-day averages are not compared against a daily limit.
                            showLimitLine = !isYear,
                            // Print the per-day average above every bar on the sparse
                            // axes the user asked for: WEEK (the day's grams) and YEAR
                            // (the month's grams-per-day). The dense ~30-bar MONTH
                            // view stays unlabelled to avoid clutter.
                            showBarValues = state.period == StatsPeriod.WEEK || isYear,
                        )
                    }
                }
            }

            // ── Key metrics ───────────────────────────────────────────────
            item {
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        StatRow(stringResource(R.string.total_period), "${state.totalGrams.fmt1(locale)} g")
                        HorizontalDivider()
                        StatRow(stringResource(R.string.avg_per_day), "${state.avgPerDay.fmt1(locale)} g")
                        HorizontalDivider()
                        StatRow(stringResource(R.string.avg_per_drink_day), "${state.avgPerDrinkDay.fmt1(locale)} g")
                        HorizontalDivider()
                        StatRow(
                            stringResource(R.string.days_over_daily_limit),
                            state.daysOverDailyLimit.toString(),
                            // Over-limit statistics share the saturated danger red
                            // used by delete icons and traffic-light bullets, instead
                            // of the softer Material `error` colour, so every "over
                            // limit" cue in the app looks identical.
                            valueColor = if (state.daysOverDailyLimit > 0) dangerRedColor() else successColor(),
                        )
                        HorizontalDivider()
                        StatRow(
                            stringResource(R.string.days_over_weekly_limit),
                            state.daysOverWeeklyLimit.toString(),
                            valueColor = if (state.daysOverWeeklyLimit > 0) dangerRedColor() else successColor(),
                        )
                        HorizontalDivider()
                        StatRow(
                            stringResource(R.string.days_over_drink_day_limit),
                            state.daysOverDrinkDayLimit.toString(),
                            valueColor = if (state.daysOverDrinkDayLimit > 0) dangerRedColor() else successColor(),
                        )
                        HorizontalDivider()
                        StatRow(
                            stringResource(R.string.abstinent_days),
                            state.abstinentDays.toString(),
                            valueColor = if (state.abstinentDays > 0) successColor() else MaterialTheme.colorScheme.onSurface,
                        )
                    }
                }
            }

            // ── Streaks & trend ───────────────────────────────────────────
            item {
                Card(modifier = Modifier.fillMaxWidth()) {
                    Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text(
                            stringResource(R.string.streak_trend),
                            style = MaterialTheme.typography.titleSmall,
                            color = MaterialTheme.colorScheme.primary,
                        )
                        HorizontalDivider()
                        StatRow(
                            stringResource(R.string.current_streak),
                            pluralStringResource(R.plurals.days, state.currentStreak, state.currentStreak),
                            valueColor = if (state.currentStreak > 0) successColor() else MaterialTheme.colorScheme.onSurface,
                        )
                        HorizontalDivider()
                        StatRow(stringResource(R.string.longest_streak), pluralStringResource(R.plurals.days, state.longestStreak, state.longestStreak))
                        HorizontalDivider()
                        val trendText = when (state.trend) {
                            Trend.UP -> "+${state.trendPercent.fmt0(locale)} % ↑"
                            Trend.DOWN -> "${state.trendPercent.fmt0(locale)} % ↓"
                            Trend.FLAT -> "–"
                        }
                        StatRow(
                            stringResource(R.string.trend_vs_prev),
                            trendText,
                            valueColor = when (state.trend) {
                                // A rising per-day average is a "bad" signal, shown in
                                // the same saturated danger red as the over-limit stats.
                                Trend.UP -> dangerRedColor()
                                Trend.DOWN -> successColor()
                                Trend.FLAT -> MaterialTheme.colorScheme.onSurface
                            },
                        )
                    }
                }
            }

            // ── Time-of-day (hour) bar chart ──────────────────────────────
            // Placed above the weekday chart and the category donut. Shown only
            // when at least one hour has consumption in the selected period.
            if (state.hourBucketAverages.any { it > 0.0 }) {
                item {
                    Card(modifier = Modifier.fillMaxWidth()) {
                        Column(Modifier.padding(16.dp)) {
                            Text(
                                stringResource(R.string.stats_time_of_day),
                                style = MaterialTheme.typography.titleSmall,
                                color = MaterialTheme.colorScheme.primary,
                            )
                            Spacer(Modifier.height(12.dp))
                            ValueBarChart(
                                // Eight 3-hour buckets; average grams/day printed above.
                                values = state.hourBucketAverages,
                                labelFor = { b -> "${b * 3}\u2013${b * 3 + 3}" },
                                showValues = true,
                                chartLabel = stringResource(R.string.stats_time_of_day),
                            )
                        }
                    }
                }
            }

            // ── Weekday profile bar chart ─────────────────────────────────
            // Sits between the hour chart and the category donut. Shown only when
            // at least one weekday occurred as a drink day in the period.
            if (state.weekdayAverages.any { it != null }) {
                item {
                    Card(modifier = Modifier.fillMaxWidth()) {
                        Column(Modifier.padding(16.dp)) {
                            Text(
                                stringResource(R.string.stats_weekday),
                                style = MaterialTheme.typography.titleSmall,
                                color = MaterialTheme.colorScheme.primary,
                            )
                            Spacer(Modifier.height(12.dp))
                            // Short weekday names for the axis, in the same rotated
                            // order as the values (locale's first weekday first).
                            val weekdayLabels = state.weekdayOrder.map { iso ->
                                DayOfWeek.of(iso)
                                    .getDisplayName(TextStyle.SHORT, locale).take(2)
                            }
                            ValueBarChart(
                                // null (weekday never a drink day) → 0.0 ⇒ empty slot.
                                values = state.weekdayAverages.map { it ?: 0.0 },
                                labelFor = { i -> weekdayLabels.getOrElse(i) { "" } },
                                showValues = true,
                                chartLabel = stringResource(R.string.stats_weekday),
                            )
                        }
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
                                color = MaterialTheme.colorScheme.primary,
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
                            color = MaterialTheme.colorScheme.primary,
                        )
                        Spacer(Modifier.height(4.dp))
                        Text(
                            stringResource(R.string.export_desc),
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
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
                    }
                }
            }
        }
    }

    // ── Export date-range dialogs ──────────────────────────────────────────
    // `today` may be empty until the stats flow's first emission; fall back to
    // a calendar date so the pickers always receive a valid initial value.
    //
    // The fallback reads the clock through DayResolver.clock() (not a bare
    // LocalDate.now()) so it honours the screenshot clock override, matching the
    // app-wide rule that every date-relative surface derives "today" from
    // DayResolver (see DayResolver.clock). This value is only ever a transient
    // placeholder for the picker's initial date: once the flow emits, `today`
    // (which additionally applies the configured day-change boundary) replaces
    // it, so the day-boundary nuance the raw calendar date cannot express is not
    // observable in practice.
    val exportToday = state.today.ifEmpty { LocalDate.now(DayResolver.clock()).toString() }
    if (showCsvRangeDialog) {
        ExportDateRangeDialog(
            initialFrom = state.statsFromDate.ifEmpty { exportToday },
            initialTo = exportToday,
            onConfirm = { from, to ->
                vm.exportCsv(from, to)
                showCsvRangeDialog = false
            },
            onDismiss = { showCsvRangeDialog = false },
        )
    }
    if (showPdfRangeDialog) {
        ExportDateRangeDialog(
            initialFrom = state.statsFromDate.ifEmpty { exportToday },
            initialTo = exportToday,
            onConfirm = { from, to ->
                vm.exportPdf(from, to)
                showPdfRangeDialog = false
            },
            onDismiss = { showPdfRangeDialog = false },
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
    // Layout hardening (v0.78.0 QA): give the LABEL the flexible width and pin the
    // VALUE to a single, unbroken line. Without a weight both Texts are measured at
    // their intrinsic width; a long label (seen with some translations, e.g. the
    // French "Moyenne par jour de consommation") then eats the row and squeezes the
    // value into a sliver, where it wrapped character-by-character into a vertical
    // stack. With the label weighted, the non-weighted value is measured first at
    // its natural width and the label wraps into the space that remains — so the
    // value can never stack, in any locale, whatever the label length. The start
    // padding keeps a gap; the value stays right-aligned because the weighted label
    // fills the rest of the row.
    Row(Modifier.fillMaxWidth()) {
        Text(
            label,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.weight(1f),
        )
        Text(
            value,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Medium,
            color = valueColor,
            softWrap = false,
            maxLines = 1,
            modifier = Modifier.padding(start = 12.dp),
        )
    }
}
