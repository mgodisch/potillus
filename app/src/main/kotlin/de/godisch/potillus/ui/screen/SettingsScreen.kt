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
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.Locale
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.core.app.ShareCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import de.godisch.potillus.R
import de.godisch.potillus.domain.AlcoholCalculator
import de.godisch.potillus.domain.model.*
import de.godisch.potillus.ui.component.*
import de.godisch.potillus.ui.theme.errorColor
import de.godisch.potillus.ui.theme.successColor
import kotlinx.coroutines.delay
import de.godisch.potillus.l10n.SupportedLocales

/**
 * Settings tab, organised into five sections:
 *   1. Personal data    – body weight (used by the BAC estimate)
 *   2. Limits           – daily / weekly gram limits and max drink-days per week
 *   3. Statistics       – day-change time, week start, statistics-start date
 *   4. Backup           – JSON import / export
 *   5. Appearance       – biometric access lock, theme, language
 *
 * CSV/PDF data export lives on the Statistics screen; only the JSON
 * backup import/export lives here now.
 *
 * @param vm The [SettingsViewModel]; defaults to the Activity-scoped instance.
 * @param onBack Invoked when the top-bar Up arrow is tapped (returns to the
 *               screen from which Settings was opened).
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(vm: SettingsViewModel = viewModel(), onBack: () -> Unit = {}) {
    val state    by vm.uiState.collectAsStateWithLifecycle()
    val context  = LocalContext.current
    val settings = state.settings

    // rememberSaveable so open dialogs and — most importantly — the
    // picked-but-not-yet-confirmed import URI survive a configuration change.
    // `pendingImportUri` is the highest-impact case: a rotation between picking a
    // backup file and choosing REPLACE/MERGE would otherwise drop the URI and
    // silently abort the import. `android.net.Uri` is Parcelable, so the default
    // saver handles it. (The two dropdown-`expanded` flags further below stay plain
    // `remember`: a collapsed menu on recreation is trivially re-openable.)
    var showTimePicker      by rememberSaveable { mutableStateOf(false) }
    var showDailyLimit      by rememberSaveable { mutableStateOf(false) }
    var showWeeklyLimit     by rememberSaveable { mutableStateOf(false) }
    var showMaxDrinkDays    by rememberSaveable { mutableStateOf(false) }
    var showWeightInput     by rememberSaveable { mutableStateOf(false) }
    var showImportMode      by rememberSaveable { mutableStateOf(false) }
    var showStatDatePicker  by rememberSaveable { mutableStateOf(false) }
    var pendingImportUri by rememberSaveable { mutableStateOf<android.net.Uri?>(null) }

    val importLauncher = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) { pendingImportUri = uri; showImportMode = true }
    }

    // Auto-dismiss the export status banner after 3 seconds
    state.exportStatus?.let { status ->
        LaunchedEffect(status) {
            delay(3_000)
            vm.clearExportStatus()
        }
    }

    // Share the exported file immediately after a successful export.
    // The share chooser is opened once and then cleared so it does not
    // reappear on recomposition.
    val shareTarget = state.shareTarget
    LaunchedEffect(shareTarget) {
        shareTarget ?: return@LaunchedEffect

        val intent = if (shareTarget.mimeType == "application/pdf") {
            // For PDFs: base the chooser on ACTION_VIEW so PDF readers, file managers,
            // and the print service appear in the list.
            // Additionally inject an ACTION_SEND intent via EXTRA_INITIAL_INTENTS so
            // messengers and cloud-storage apps (which only register ACTION_SEND) also show.
            //
            // WHY ACTION_VIEW as the base (not ACTION_SEND)?
            //   PDF readers register for ACTION_VIEW + application/pdf.
            //   They do NOT register for ACTION_SEND, so the old ALTERNATE_INTENTS trick
            //   was silently ignored by them on modern Android (API 30+).
            //   Reversing the base intent makes PDF readers the primary targets.
            //
            // WHY EXTRA_INITIAL_INTENTS (not EXTRA_ALTERNATE_INTENTS)?
            //   EXTRA_ALTERNATE_INTENTS was deprecated in API 30 and is unreliable.
            //   EXTRA_INITIAL_INTENTS prepends specific intents to the top of the chooser
            //   list and is the current recommended approach.
            val sendIntent = Intent(Intent.ACTION_SEND).apply {
                type = shareTarget.mimeType
                putExtra(Intent.EXTRA_STREAM, shareTarget.uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            Intent.createChooser(
                Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(shareTarget.uri, shareTarget.mimeType)
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                },
                shareTarget.fileName
            ).apply {
                putExtra(Intent.EXTRA_INITIAL_INTENTS, arrayOf(sendIntent))
            }
        } else {
            // For CSV and JSON: ACTION_SEND is the right base (messengers, email,
            // cloud storage). These file types don't need a dedicated viewer.
            ShareCompat.IntentBuilder(context)
                .setType(shareTarget.mimeType)
                .addStream(shareTarget.uri)
                .setChooserTitle(shareTarget.fileName)
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
                title  = { Text(stringResource(R.string.settings)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = stringResource(R.string.back),
                            tint = MaterialTheme.colorScheme.onPrimary)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor    = MaterialTheme.colorScheme.primary,
                    titleContentColor = MaterialTheme.colorScheme.onPrimary
                )
            )
        }
    ) { paddingValues ->
        LazyColumn(
            // The Settings screen has no bottom navigation bar (unlike the four
            // main screens), so its content would otherwise scroll underneath the
            // system navigation bar. Add that inset to the bottom padding so the
            // last item (and its spacing) stays fully visible above the gesture/
            // button bar.
            contentPadding      = PaddingValues(
                start  = 16.dp,
                top    = 16.dp,
                end    = 16.dp,
                bottom = 16.dp + WindowInsets.navigationBars.asPaddingValues().calculateBottomPadding()
            ),
            verticalArrangement = Arrangement.spacedBy(16.dp),
            modifier            = Modifier.fillMaxSize().padding(paddingValues)
        ) {
            // ── 1. Personal data (body weight) ──────────────────────
            item { SettingsSectionHeader(stringResource(R.string.personal_data)) }
            item {
                SettingsCard {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        Text(
                            stringResource(R.string.body_weight) + ": " +
                            if (settings.weightKg > 0) "${"%.1f".format(settings.weightKg)} kg" else stringResource(R.string.not_set),
                            style = MaterialTheme.typography.bodyMedium
                        )
                        IconButton(onClick = {showWeightInput = true }) { Icon(Icons.Default.Edit, contentDescription = stringResource(R.string.change), tint = MaterialTheme.colorScheme.primary) }
                    }
                }
            }

            // ── 2. Limits (always all three at once) ─────────────
            // Daily gram limit AND weekly gram limit AND max drink-days/week are
            // all in force simultaneously; there is no guideline mode or toggle.
            item { SettingsSectionHeader(stringResource(R.string.limits)) }
            item {
                SettingsCard {
                    // Daily gram limit
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        Text(stringResource(R.string.daily_limit_grams) + ": ${settings.dailyLimitGrams.toInt()} g",
                            style = MaterialTheme.typography.bodyMedium)
                        IconButton(onClick = { showDailyLimit = true }) { Icon(Icons.Default.Edit, contentDescription = stringResource(R.string.change), tint = MaterialTheme.colorScheme.primary) }
                    }
                    Spacer(Modifier.height(4.dp))
                    // Weekly gram limit
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        Text(stringResource(R.string.weekly_limit_grams) + ": ${settings.weeklyLimitGrams.toInt()} g",
                            style = MaterialTheme.typography.bodyMedium)
                        IconButton(onClick = { showWeeklyLimit = true }) { Icon(Icons.Default.Edit, contentDescription = stringResource(R.string.change), tint = MaterialTheme.colorScheme.primary) }
                    }
                    Spacer(Modifier.height(4.dp))
                    // Max drink days per week
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        Text(stringResource(R.string.drink_days_setting) + ": ${settings.maxDrinkDaysPerWeek}",
                            style = MaterialTheme.typography.bodyMedium)
                        IconButton(onClick = { showMaxDrinkDays = true }) {
                            Icon(Icons.Default.Edit, contentDescription = stringResource(R.string.change), tint = MaterialTheme.colorScheme.primary)
                        }
                    }
                }
            }

            // ── 3. Statistics (day-change time + week start + stats-start date) ────
            item { SettingsSectionHeader(stringResource(R.string.statistics)) }
            item {
                SettingsCard {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        Column {
                            Text(stringResource(R.string.day_starts_at), style = MaterialTheme.typography.bodyMedium)
                            Text(
                                stringResource(R.string.day_change_time_value, settings.dayChangeHour, settings.dayChangeMinute),
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.primary
                            )
                        }
                        IconButton(onClick = {showTimePicker = true }) { Icon(Icons.Default.Edit, contentDescription = stringResource(R.string.change), tint = MaterialTheme.colorScheme.primary) }
                    }
                }
            }
            item {
                SettingsCard {
                    var weekMenuExpanded by remember { mutableStateOf(false) }
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        Text(stringResource(R.string.week_starts_on), style = MaterialTheme.typography.bodyMedium)
                        Box {
                            OutlinedButton(onClick = { weekMenuExpanded = true }) {
                                Text(
                                    java.time.DayOfWeek.of(settings.weekStartDay)
                                        .getDisplayName(java.time.format.TextStyle.FULL, java.util.Locale.getDefault())
                                )
                            }
                            DropdownMenu(expanded = weekMenuExpanded, onDismissRequest = { weekMenuExpanded = false }) {
                                // ISO weekdays 1 (Monday) … 7 (Sunday); localised full names.
                                (1..7).forEach { iso ->
                                    DropdownMenuItem(
                                        text = {
                                            Text(
                                                java.time.DayOfWeek.of(iso)
                                                    .getDisplayName(java.time.format.TextStyle.FULL, java.util.Locale.getDefault())
                                            )
                                        },
                                        onClick = { vm.setWeekStartDay(iso); weekMenuExpanded = false }
                                    )
                                }
                            }
                        }
                    }
                }
            }
            item {
                SettingsCard {
                    Text(
                        stringResource(R.string.stats_from_desc),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Spacer(Modifier.height(8.dp))
                    Row(
                        Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment     = Alignment.CenterVertically
                    ) {
                        Column {
                            Text(
                                stringResource(R.string.stats_from_label),
                                style = MaterialTheme.typography.bodyMedium
                            )
                            if (settings.statsFromDate.isNotEmpty()) {
                                Text(
                                    formatStatsDate(settings.statsFromDate),
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.primary
                                )
                            }
                        }
                        IconButton(onClick = {showStatDatePicker = true }) { Icon(Icons.Default.Edit, contentDescription = stringResource(R.string.change), tint = MaterialTheme.colorScheme.primary) }
                    }
                }
            }

            // ── 4. Backup (JSON import/export) ─────────────────
            item { SettingsSectionHeader(stringResource(R.string.backup_section)) }
            item {
                SettingsCard {
                    Text(stringResource(R.string.backup_desc), style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant)
                    Spacer(Modifier.height(8.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedButton(onClick = { vm.exportBackup() }, modifier = Modifier.weight(1f)) {
                            Text(stringResource(R.string.backup_export))
                        }
                        OutlinedButton(onClick = { importLauncher.launch("application/json") }, modifier = Modifier.weight(1f)) {
                            Text(stringResource(R.string.backup_import))
                        }
                    }
                    // Backup/import status banner. Previously this was rendered by the
                    // (now-removed) CSV/PDF export section; since backup shares the same
                    // exportStatus flow, the status line moves here so import/export
                    // results stay visible to the user.
                    state.exportStatus?.let { status ->
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

            // ── 5. Appearance (access lock + theme + language) ──────
            item { SettingsSectionHeader(stringResource(R.string.appearance)) }
            item {
                SettingsCard {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(stringResource(R.string.biometric_lock), style = MaterialTheme.typography.bodyMedium)
                            Text(stringResource(R.string.biometric_desc), style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant)
                        }
                        Switch(checked = settings.biometricEnabled, onCheckedChange = { vm.setBiometric(it) })
                    }
                }
            }
            item {
                SettingsCard {
                    Text(stringResource(R.string.theme_mode), style = MaterialTheme.typography.bodyMedium)
                    Spacer(Modifier.height(8.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        ThemeMode.entries.forEach { mode ->
                            val labelRes = when (mode) {
                                ThemeMode.SYSTEM -> R.string.theme_system
                                ThemeMode.DAY    -> R.string.theme_day
                                ThemeMode.NIGHT  -> R.string.theme_night
                            }
                            FilterChip(
                                selected = settings.themeMode == mode,
                                onClick  = { vm.setThemeMode(mode) },
                                label    = { Text(stringResource(labelRes)) },
                                modifier = Modifier.weight(1f)
                            )
                        }
                    }
                }
            }
            item {
                SettingsCard {
                    Text(stringResource(R.string.language), style = MaterialTheme.typography.bodyMedium)
                    Spacer(Modifier.height(8.dp))
                    LanguageDropdown(
                        selected = settings.language,
                        onSelect = { code ->
                            vm.setLanguage(code)
                            androidx.appcompat.app.AppCompatDelegate.setApplicationLocales(
                                androidx.core.os.LocaleListCompat.forLanguageTags(code)
                            )
                        }
                    )
                }
            }
        }
    }

    // ── Dialogs ───────────────────────────────────────────────────────────────

    if (showTimePicker) {
        TimePickerDialog(
            title         = stringResource(R.string.day_change_time),
            initialHour   = settings.dayChangeHour,
            initialMinute = settings.dayChangeMinute,
            onConfirm     = { h, m -> vm.setDayChangeTime(h, m); showTimePicker = false },
            onDismiss     = { showTimePicker = false }
        )
    }
    if (showDailyLimit) {
        GramsInputDialog(
            title     = stringResource(R.string.daily_limit_grams),
            initial   = settings.dailyLimitGrams,
            onConfirm = { v -> vm.setDailyLimit(v); showDailyLimit = false },
            onDismiss = { showDailyLimit = false }
        )
    }
    if (showWeeklyLimit) {
        GramsInputDialog(
            title     = stringResource(R.string.weekly_limit_grams),
            initial   = settings.weeklyLimitGrams,
            maxValue  = 3500.0,
            onConfirm = { v -> vm.setWeeklyLimit(v); showWeeklyLimit = false },
            onDismiss = { showWeeklyLimit = false }
        )
    }
    if (showMaxDrinkDays) {
        // Integer picker 1–7 reuses the existing GramsInputDialog re-purposed as an int input.
        // The value is stored as an integer but GramsInputDialog takes/returns Double –
        // we round to Int on confirm.
        GramsInputDialog(
            title     = stringResource(R.string.drink_days_setting),
            initial   = settings.maxDrinkDaysPerWeek.toDouble(),
            suffix    = "",
            onConfirm = { v -> vm.setMaxDrinkDaysPerWeek(v.toInt().coerceIn(1, 7)); showMaxDrinkDays = false },
            onDismiss = { showMaxDrinkDays = false }
        )
    }
    if (showWeightInput) {
        GramsInputDialog(
            title        = stringResource(R.string.body_weight),
            initial      = settings.weightKg,
            suffix       = "kg",
            allowDecimal = true,
            onConfirm    = { v -> vm.setWeightKg(v); showWeightInput = false },
            onDismiss    = { showWeightInput = false }
        )
    }
    if (showStatDatePicker) {
        StatsFromDatePickerDialog(
            initialDateStr = settings.statsFromDate,
            onConfirm = { date -> vm.setStatsFromDate(date); showStatDatePicker = false },
            onDismiss = { showStatDatePicker = false }
        )
    }

    if (showImportMode && pendingImportUri != null) {
        AlertDialog(
            onDismissRequest = { showImportMode = false; pendingImportUri = null },
            title  = { Text(stringResource(R.string.backup_import)) },
            text   = { Text(stringResource(R.string.import_mode_question)) },
            confirmButton  = {
                // Primary action: safe merge (non-destructive)
                TextButton(onClick = {
                    vm.importBackup(pendingImportUri!!, ImportMode.MERGE)
                    showImportMode = false; pendingImportUri = null
                }) { Text(stringResource(R.string.import_merge)) }
            },
            dismissButton  = {
                Row {
                    TextButton(onClick = { showImportMode = false; pendingImportUri = null }) {
                        Text(stringResource(R.string.cancel))
                    }
                    // Destructive action: highlighted in red
                    TextButton(onClick = {
                        vm.importBackup(pendingImportUri!!, ImportMode.REPLACE)
                        showImportMode = false; pendingImportUri = null
                    }) { Text(stringResource(R.string.import_replace), color = errorColor()) }
                }
            }
        )
    }
}

/**
 * Formats an ISO-8601 "YYYY-MM-DD" [dateStr] as a localised long date
 * ("d. MMMM yyyy"). Falls back to the raw string if parsing fails.
 */
@Composable
private fun formatStatsDate(dateStr: String): String {
    return try {
        val ld = LocalDate.parse(dateStr, DateTimeFormatter.ofPattern("yyyy-MM-dd"))
        ld.format(DateTimeFormatter.ofPattern("d. MMMM yyyy", Locale.getDefault()))
    } catch (e: Exception) { dateStr }
}

/**
 * Date picker for the "statistics from" date, constrained to today or earlier.
 *
 * @param initialDateStr Pre-selected date ("YYYY-MM-DD").
 * @param onConfirm      Invoked with the chosen ISO date string.
 * @param onDismiss      Invoked when the dialog is dismissed without a choice.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun StatsFromDatePickerDialog(
    initialDateStr: String,
    onConfirm: (String) -> Unit,
    onDismiss: () -> Unit
) {
    val initialMillis = remember(initialDateStr) {
        try {
            LocalDate.parse(initialDateStr, DateTimeFormatter.ofPattern("yyyy-MM-dd"))
                .atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
        } catch (e: Exception) { System.currentTimeMillis() }
    }
    // Prevent selecting a future date: the "Statistik ab" date must be today or earlier.
    // SelectableDates is a Material 3 API for constraining the calendar.
    // The DatePicker works in UTC milliseconds; comparing against System.currentTimeMillis()
    // (also UTC) is correct here.
    val today = remember {
        // Align to start-of-day UTC so a day that "is today" is fully selectable,
        // not blocked by hour/minute of the current time.
        java.time.LocalDate.now(ZoneOffset.UTC)
            .atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
    }
    val pickerState = rememberDatePickerState(
        initialSelectedDateMillis = initialMillis,
        selectableDates = object : androidx.compose.material3.SelectableDates {
            /** Allows only days up to and including today (no future dates). */
            override fun isSelectableDate(utcTimeMillis: Long) = utcTimeMillis <= today
        }
    )

    DatePickerDialog(
        onDismissRequest = onDismiss,
        confirmButton    = {
            TextButton(onClick = {
                pickerState.selectedDateMillis?.let { ms ->
                    val date = Instant.ofEpochMilli(ms)
                        .atZone(ZoneOffset.UTC)
                        .toLocalDate()
                        .format(DateTimeFormatter.ofPattern("yyyy-MM-dd"))
                    onConfirm(date)
                }
            }) { Text(stringResource(R.string.save)) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) } }
    ) {
        DatePicker(state = pickerState)
    }
}

/** Renders a small primary-coloured section title in the settings list. @param title Section label. */
@Composable
private fun SettingsSectionHeader(title: String) {
    Text(title, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.primary,
        modifier = Modifier.padding(vertical = 4.dp))
}

/** Surface-coloured card wrapper that groups related settings rows. @param content The card body. */
@Composable
private fun SettingsCard(content: @Composable ColumnScope.() -> Unit) {
    Card(modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface)) {
        Column(Modifier.padding(16.dp), content = content)
    }
}

/**
 * Numeric input dialog used for gram-based limits and body weight.
 *
 * Confirmation is disabled until the parsed value lies in [[minValue], [maxValue]].
 *
 * @param title        Dialog title.
 * @param initial      Pre-filled value.
 * @param suffix       Unit suffix shown after the field (default "g").
 * @param allowDecimal Whether one decimal place is permitted.
 * @param minValue     Inclusive lower bound for a valid value.
 * @param maxValue     Inclusive upper bound for a valid value.
 * @param onConfirm    Invoked with the validated value.
 * @param onDismiss    Invoked when the dialog is cancelled.
 */
@Composable
private fun GramsInputDialog(
    title: String,
    initial: Double,
    suffix: String = "g",
    allowDecimal: Boolean = false,
    minValue: Double = 1.0,
    maxValue: Double = 500.0,
    onConfirm: (Double) -> Unit,
    onDismiss: () -> Unit
) {
    // rememberSaveable so a half-typed value survives a configuration
    // change while the dialog is open (the dialog's visibility flag is also saved).
    var text by rememberSaveable {
        mutableStateOf(if (allowDecimal) "%.1f".format(initial) else initial.toInt().toString())
    }
    val parsed   = text.toDoubleOrNull()
    val inRange  = parsed != null && parsed in minValue..maxValue
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text  = {
            OutlinedTextField(
                value           = text,
                onValueChange   = {
                    text = if (allowDecimal) {
                        it.filter { c -> c.isDigit() || c == '.' || c == ',' }.replace(',', '.')
                    } else {
                        it.filter { c -> c.isDigit() }
                    }
                },
                suffix          = { Text(suffix) },
                isError         = text.isNotEmpty() && !inRange,
                keyboardOptions = KeyboardOptions(keyboardType = androidx.compose.ui.text.input.KeyboardType.Number),
                singleLine      = true
            )
        },
        confirmButton  = {
            TextButton(
                onClick  = { parsed?.let { onConfirm(it) } },
                enabled  = inRange
            ) { Text(stringResource(R.string.save)) }
        },
        dismissButton  = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) } }
    )
}

/**
 * Language selector backed by [SupportedLocales.ALL] (single source of truth).
 *
 * @param selected Currently selected BCP-47 tag.
 * @param onSelect Invoked with the chosen BCP-47 tag.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun LanguageDropdown(selected: String, onSelect: (String) -> Unit) {
    // Language list is sourced from SupportedLocales.ALL (de.godisch.potillus.l10n).
    // To add a language: follow the four-step guide in SupportedLocales.kt.
    // Do NOT add entries here directly — the list is now the single source of truth.
    val languages = SupportedLocales.ALL.map { it.tag to it.autonym }
    val currentLabel = languages.find { it.first == selected }?.second ?: selected
    var expanded by remember { mutableStateOf(false) }

    ExposedDropdownMenuBox(expanded = expanded, onExpandedChange = { expanded = it }) {
        OutlinedTextField(
            value         = currentLabel,
            onValueChange = {},
            readOnly      = true,
            trailingIcon  = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = expanded) },
            modifier      = Modifier.menuAnchor(MenuAnchorType.PrimaryNotEditable).fillMaxWidth()
        )
        ExposedDropdownMenu(expanded = expanded, onDismissRequest = { expanded = false }) {
            languages.forEach { (code, label) ->
                DropdownMenuItem(
                    text = { Text(label) },
                    onClick = { onSelect(code); expanded = false },
                    trailingIcon = if (code == selected) ({
                        Icon(
                            imageVector        = Icons.Default.Check,
                            contentDescription = null,
                            tint               = MaterialTheme.colorScheme.primary,
                            modifier           = Modifier.size(16.dp)
                        )
                    }) else null
                )
            }
        }
    }
}
