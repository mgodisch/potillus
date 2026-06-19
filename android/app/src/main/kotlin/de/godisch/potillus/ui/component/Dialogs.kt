/* vim: set et ts=4:
 * =============================================================================
 * Libellus Potionis -- Privacy-Friendly Alcohol Tracker
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
// Dialogs.kt – Modal dialogs shared across multiple screens
// =============================================================================
//
// CONTENTS:
//   AddEditEntryDialog   – Log or edit a consumption event (Today + Calendar + Drinks)
//   TimePickerDialog     – Clock-style time picker (entry timestamp + day-change time)
//   AddEditDrinkDialog   – Create or edit a drink definition (Drinks screen)
//   ExportDateRangeDialog– Pick a from/to date range for CSV/PDF export (Settings)
//
// STATE HOISTING: all mutable dialog state lives INSIDE the composable via
//   `remember { mutableStateOf(…) }`. The parent only provides initial data
//   and callbacks, making dialogs stateless from the outside.
//
// TRAFFIC-LIGHT BULLET in AddEditEntryDialog:
//   When the caller passes a non-null [DrinkCapacity], the dialog shows a
//   coloured dot ([TrafficLightDot]) next to the grams preview. The dot
//   reflects how many more servings fit within the active limits for the
//   currently selected drink and volume. It recalculates automatically on
//   every recomposition triggered by a drink or volume change.
// =============================================================================

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material3.*
import androidx.compose.material3.ExposedDropdownMenuDefaults
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import de.godisch.potillus.R
import de.godisch.potillus.domain.AlcoholCalculator
import de.godisch.potillus.domain.model.ConsumptionEntry
import de.godisch.potillus.domain.model.DrinkCapacity
import de.godisch.potillus.domain.model.DrinkCategory
import de.godisch.potillus.domain.model.DrinkDefinition
import de.godisch.potillus.ui.theme.errorColor
import java.time.Instant
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.ZoneOffset

// ════════════════════════════════════════════════════════════════════════════
// ADD / EDIT ENTRY DIALOG
// ════════════════════════════════════════════════════════════════════════════

/**
 * Modal dialog for logging a new consumption entry or editing an existing one.
 *
 * @param entry            Existing entry to edit, or null to create a new one.
 * @param drinks           Full drink catalogue for the dropdown.
 * @param preSelectedDrink Drink pre-selected when the dialog opens (e.g. from
 *                         the quick-bar tap or the DrinksScreen card tap).
 * @param capacity         Today's consumption context for the traffic-light dot.
 *                         Pass null (default) to suppress the indicator.
 * @param onSave           Called with (drink, volumeMl, timestampMs, note) on confirm.
 * @param onDismiss        Called when the user cancels or taps outside.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddEditEntryDialog(
    entry: ConsumptionEntry?,
    drinks: List<DrinkDefinition>,
    preSelectedDrink: DrinkDefinition? = null,
    capacity: DrinkCapacity?           = null,
    onSave: (DrinkDefinition, Int, Long, String) -> Unit,
    onDismiss: () -> Unit
) {
    val isEdit    = entry != null
    val initDrink = preSelectedDrink
        ?: drinks.firstOrNull { it.id == entry?.drinkId }
        ?: drinks.firstOrNull()

    var selectedDrink     by remember { mutableStateOf(initDrink) }
    var volumeText        by remember { mutableStateOf(entry?.volumeMl?.toString() ?: initDrink?.volumeMl?.toString() ?: "") }
    var noteText          by remember { mutableStateOf(entry?.note ?: "") }
    var drinkDropdownOpen by remember { mutableStateOf(false) }

    val initDt = entry?.timestampMillis?.let {
        LocalDateTime.ofInstant(Instant.ofEpochMilli(it), ZoneId.systemDefault())
    } ?: LocalDateTime.now()
    var hour   by remember { mutableIntStateOf(initDt.hour) }
    var minute by remember { mutableIntStateOf(initDt.minute) }
    var showTimePicker by remember { mutableStateOf(false) }

    val volume       = volumeText.toIntOrNull() ?: 0
    val previewGrams = selectedDrink?.let { AlcoholCalculator.calculateGrams(volume, it.alcoholPercent) } ?: 0.0
    val canSave      = selectedDrink != null && (volumeText.toIntOrNull() ?: 0) in 1..5000

    // Traffic-light: recalculated on every recomposition caused by selectedDrink
    // or volumeText change (both are state variables → Compose recomposes automatically).
    // Shown only when capacity is provided AND a drink is selected.
    val trafficLight = if (capacity != null && selectedDrink != null && volume > 0) {
        AlcoholCalculator.trafficLight(
            gramsPerDrink       = previewGrams,
            todayGrams          = capacity.todayGrams,
            dailyLimitGrams     = capacity.dailyLimitGrams,
            weeklyTotalGrams    = capacity.weeklyTotalGrams,
            weeklyLimitGrams    = capacity.weeklyLimitGrams,
            drinkDaysThisWeek   = capacity.drinkDaysThisWeek,
            maxDrinkDaysPerWeek = capacity.maxDrinkDaysPerWeek
        )
    } else null

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (isEdit) stringResource(R.string.edit_entry) else stringResource(R.string.add_entry)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                // ── Drink picker ──────────────────────────────────────────────
                ExposedDropdownMenuBox(
                    expanded         = drinkDropdownOpen,
                    onExpandedChange = { drinkDropdownOpen = it }
                ) {
                    OutlinedTextField(
                        value         = selectedDrink?.name ?: stringResource(R.string.select_drink),
                        onValueChange = {},
                        readOnly      = true,
                        label         = { Text(stringResource(R.string.drink)) },
                        leadingIcon   = selectedDrink?.let { { DrinkCategoryIcon(it.category) } },
                        trailingIcon  = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = drinkDropdownOpen) },
                        modifier      = Modifier.menuAnchor(ExposedDropdownMenuAnchorType.PrimaryNotEditable).fillMaxWidth()
                    )
                    ExposedDropdownMenu(
                        expanded         = drinkDropdownOpen,
                        onDismissRequest = { drinkDropdownOpen = false }
                    ) {
                        drinks.forEach { drink ->
                            DropdownMenuItem(
                                leadingIcon = { DrinkCategoryIcon(drink.category) },
                                text = {
                                    Column {
                                        Text(drink.name, style = MaterialTheme.typography.bodyMedium)
                                        Text(
                                            "${drink.volumeMl} ml · ${drink.alcoholPercent} %",
                                            style = MaterialTheme.typography.bodySmall,
                                            color = MaterialTheme.colorScheme.onSurfaceVariant
                                        )
                                    }
                                },
                                onClick = {
                                    selectedDrink     = drink
                                    volumeText        = drink.volumeMl.toString()
                                    drinkDropdownOpen = false
                                }
                            )
                        }
                    }
                }

                // ── Volume ────────────────────────────────────────────────────
                OutlinedTextField(
                    value           = volumeText,
                    onValueChange   = { volumeText = it.filter { c -> c.isDigit() } },
                    label           = { Text(stringResource(R.string.volume_ml)) },
                    suffix          = { Text("ml") },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    isError         = volumeText.isNotEmpty() && (volumeText.toIntOrNull() ?: 0) !in 1..5000,
                    modifier        = Modifier.fillMaxWidth()
                )

                // ── Time picker ───────────────────────────────────────────────
                // Tapping the HH:MM field opens the Material 3 clock-style picker
                // (TimePickerDialog) — the same interaction as setting an alarm.
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Icon(Icons.Default.AccessTime, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
                    Text(stringResource(R.string.time), style = MaterialTheme.typography.bodyMedium)
                    Spacer(Modifier.weight(1f))
                    OutlinedButton(onClick = { showTimePicker = true }) {
                        Text("%02d:%02d".format(hour, minute))
                    }
                }

                // ── Note ──────────────────────────────────────────────────────
                OutlinedTextField(
                    value         = noteText,
                    onValueChange = { noteText = it },
                    label         = { Text(stringResource(R.string.note)) },
                    maxLines      = 2,
                    modifier      = Modifier.fillMaxWidth()
                )

                // ── Grams preview + traffic-light dot ─────────────────────────
                // Shown only when a drink is selected and the volume is valid.
                if (selectedDrink != null && volume > 0) {
                    Surface(
                        color = MaterialTheme.colorScheme.primaryContainer,
                        shape = MaterialTheme.shapes.small
                    ) {
                        Row(
                            modifier          = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 12.dp, vertical = 8.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            Text(
                                "≈ ${"%.1f".format(previewGrams)} ${stringResource(R.string.pure_alcohol)}",
                                style    = MaterialTheme.typography.bodyMedium,
                                modifier = Modifier.weight(1f)
                            )
                            // Traffic-light dot: appears once a drink is selected and
                            // capacity data is available. Updates on every recomposition
                            // (i.e. whenever selectedDrink or volumeText changes).
                            if (trafficLight != null) {
                                TrafficLightDot(
                                    light    = trafficLight,
                                    modifier = Modifier.padding(start = 4.dp)
                                )
                            }
                        }
                    }
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    val drink = selectedDrink ?: return@TextButton
                    val vol   = volumeText.toIntOrNull()?.takeIf { it > 0 } ?: return@TextButton
                    // Build timestamp from today's calendar date + the user-selected time.
                    // (CalendarScreen overrides logicalDate in the ViewModel; the date component
                    //  of this timestamp is only relevant for TodayScreen and DrinksScreen.)
                    val ts = LocalDateTime.now()
                        .withHour(hour).withMinute(minute).withSecond(0).withNano(0)
                        .atZone(ZoneId.systemDefault()).toInstant().toEpochMilli()
                    onSave(drink, vol, ts, noteText.trim())
                },
                enabled = canSave
            ) { Text(stringResource(R.string.save)) }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) } }
    )

    // Clock-style time picker, opened by tapping the HH:MM field above.
    if (showTimePicker) {
        TimePickerDialog(
            title         = stringResource(R.string.time),
            initialHour   = hour,
            initialMinute = minute,
            onConfirm     = { h, m -> hour = h; minute = m; showTimePicker = false },
            onDismiss     = { showTimePicker = false }
        )
    }
}

// ════════════════════════════════════════════════════════════════════════════
// TIME PICKER DIALOG
// ════════════════════════════════════════════════════════════════════════════

/**
 * Modal dialog hosting the Material 3 clock-style [TimePicker] — the same
 * interaction users know from setting an alarm.
 *
 * Shared by [AddEditEntryDialog] (entry timestamp) and the Settings screen
 * (day-change time), so the time-entry experience is identical everywhere and
 * the picker logic lives in exactly one place.
 *
 * WHY a clock picker instead of two HH/MM dropdowns?
 *   The dropdowns required two separate taps-and-scrolls and felt unlike the
 *   rest of Android. The system clock picker is faster, more familiar, and lets
 *   the user drag the clock hands or type the time directly.
 *
 * The clock is forced to 24-hour mode (`is24Hour = true`) for consistency with
 * the rest of the app (the previous dropdowns were 0–23 / 0–59).
 *
 * @param title         Dialog title (e.g. the localised "Time" or "Day change time").
 * @param initialHour   Pre-selected hour (0–23).
 * @param initialMinute Pre-selected minute (0–59).
 * @param onConfirm     Called with the chosen (hour, minute) when the user confirms.
 * @param onDismiss     Called when the user cancels or taps outside.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TimePickerDialog(
    title: String,
    initialHour: Int,
    initialMinute: Int,
    onConfirm: (Int, Int) -> Unit,
    onDismiss: () -> Unit
) {
    val state = rememberTimePickerState(initialHour, initialMinute, is24Hour = true)
    AlertDialog(
        onDismissRequest = onDismiss,
        title         = { Text(title) },
        text          = { TimePicker(state = state) },
        confirmButton = { TextButton(onClick = { onConfirm(state.hour, state.minute) }) { Text(stringResource(R.string.save)) } },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) } }
    )
}

// ════════════════════════════════════════════════════════════════════════════
// ADD / EDIT DRINK DIALOG
// ════════════════════════════════════════════════════════════════════════════

/**
 * Modal dialog for creating a new drink definition or editing an existing one.
 *
 * Validates all three numeric fields inline and disables the Save button until
 * all inputs are valid. A live alcohol-gram preview updates as the user types
 * to give immediate feedback on the formula `V × (ABV / 100) × 0.789 g/ml`.
 *
 * WHY inline validation (not submit-time)?
 *   Showing red error text while the user is still typing can feel aggressive,
 *   but here the preview grams serve as a positive signal — the user can see the
 *   effect of their input without submitting. The Save button is simply greyed
 *   out until all fields pass; no explicit error label is shown while typing.
 *
 * @param drink      Existing [DrinkDefinition] to edit, or `null` to create a new one.
 *                   When non-null, the form fields are pre-filled with the existing values.
 * @param onSave     Called with the validated (name, volumeMl, alcoholPercent, category) when
 *                   the user confirms. Validation errors are delegated to [DrinksViewModel]
 *                   which emits a [DrinksEvent.ValidationError] if a server-side guard fires.
 * @param onDismiss  Called when the user cancels or taps outside the dialog.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AddEditDrinkDialog(
    drink: DrinkDefinition?,
    onSave: (name: String, volumeMl: Int, alcoholPercent: Double, category: DrinkCategory) -> Unit,
    onDismiss: () -> Unit
) {
    var name        by remember { mutableStateOf(drink?.name ?: "") }
    var volText     by remember { mutableStateOf(drink?.volumeMl?.toString() ?: "") }
    var pctText     by remember { mutableStateOf(drink?.alcoholPercent?.toString() ?: "") }
    var category    by remember { mutableStateOf(drink?.category ?: DrinkCategory.OTHER) }
    var catExpanded by remember { mutableStateOf(false) }

    val volume  = volText.toIntOrNull()
    val percent = pctText.toDoubleOrNull()

    val volumeValid  = volume != null && volume in 1..5000  // 5000 ml = 5 litres max
    val percentValid = percent != null && percent in 0.0..100.0
    val canSave      = name.isNotBlank() && volumeValid && percentValid

    val previewGrams = if (volume != null && percent != null && volumeValid && percentValid)
        AlcoholCalculator.calculateGrams(volume, percent) else null

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (drink != null) stringResource(R.string.edit_drink) else stringResource(R.string.add_drink)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedTextField(
                    value = name, onValueChange = { name = it },
                    label = { Text(stringResource(R.string.drink_name)) },
                    modifier = Modifier.fillMaxWidth(), singleLine = true
                )
                OutlinedTextField(
                    value = volText, onValueChange = { volText = it.filter { c -> c.isDigit() } },
                    label = { Text(stringResource(R.string.volume_ml)) }, suffix = { Text("ml") },
                    isError = volText.isNotEmpty() && !volumeValid,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = pctText, onValueChange = { pctText = it.replace(',', '.') },
                    label = { Text(stringResource(R.string.alcohol_percent)) }, suffix = { Text("Vol.-%") },
                    isError = pctText.isNotEmpty() && !percentValid,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal),
                    modifier = Modifier.fillMaxWidth()
                )
                ExposedDropdownMenuBox(expanded = catExpanded, onExpandedChange = { catExpanded = it }) {
                    OutlinedTextField(
                        value = category.displayLabel(), onValueChange = {}, readOnly = true,
                        label = { Text(stringResource(R.string.category)) },
                        leadingIcon = { DrinkCategoryIcon(category) },
                        trailingIcon = { ExposedDropdownMenuDefaults.TrailingIcon(expanded = catExpanded) },
                        modifier = Modifier.menuAnchor(ExposedDropdownMenuAnchorType.PrimaryNotEditable).fillMaxWidth()
                    )
                    ExposedDropdownMenu(expanded = catExpanded, onDismissRequest = { catExpanded = false }) {
                        DrinkCategory.entries.forEach { cat ->
                            DropdownMenuItem(
                                leadingIcon = { DrinkCategoryIcon(cat) },
                                text = { Text(cat.displayLabel()) },
                                onClick = { category = cat; catExpanded = false }
                            )
                        }
                    }
                }
                if (previewGrams != null) {
                    Surface(color = MaterialTheme.colorScheme.primaryContainer, shape = MaterialTheme.shapes.small) {
                        Text(
                            "≈ ${"%.1f".format(previewGrams)} ${stringResource(R.string.pure_alcohol)}",
                            style = MaterialTheme.typography.bodyMedium,
                            modifier = Modifier.padding(12.dp, 8.dp)
                        )
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = { onSave(name.trim(), volume!!, percent!!, category) }, enabled = canSave) {
                Text(stringResource(R.string.save))
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.cancel)) } }
    )
}

// ════════════════════════════════════════════════════════════════════════════
// EXPORT DATE-RANGE DIALOG
// ════════════════════════════════════════════════════════════════════════════

/**
 * Full-screen date-range picker dialog for selecting the export period.
 *
 * Uses Material 3's [DateRangePicker] which shows both a start and end date
 * on one calendar view. The dialog fills the screen
 * ([DialogProperties.usePlatformDefaultWidth = false]) because the range
 * picker needs the full width to render both months legibly.
 *
 * Pre-filled with [initialFrom] (the "Statistik ab" date) and [initialTo]
 * (today's logical date). Future dates are blocked via [SelectableDates].
 *
 * @param initialFrom  ISO-8601 start date for pre-fill ("YYYY-MM-DD").
 * @param initialTo    ISO-8601 end date for pre-fill (today).
 * @param onConfirm    Called with (from, to) ISO-8601 strings on confirm.
 *                     Enabled only when both start and end are selected.
 * @param onDismiss    Called on cancel / outside tap.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ExportDateRangeDialog(
    initialFrom: String,
    initialTo: String,
    onConfirm: (from: String, to: String) -> Unit,
    onDismiss: () -> Unit
) {
    // Convert ISO-8601 strings to UTC epoch-ms for the picker state.
    // The DateRangePicker operates in UTC, so we parse at UTC midnight.
    /** Parses an ISO-8601 "YYYY-MM-DD" string to UTC-midnight epoch-ms, or `null` if unparseable. */
    fun String.toUtcMillis(): Long? = runCatching {
        java.time.LocalDate.parse(this)
            .atStartOfDay(ZoneOffset.UTC).toInstant().toEpochMilli()
    }.getOrNull()

    /** Formats a UTC epoch-ms value back to an ISO-8601 "YYYY-MM-DD" string. */
    fun Long.toDateString(): String =
        java.time.Instant.ofEpochMilli(this)
            .atZone(ZoneOffset.UTC)
            .toLocalDate()
            .toString()   // ISO-8601 "YYYY-MM-DD"

    val todayMillis = initialTo.toUtcMillis() ?: System.currentTimeMillis()

    val pickerState = rememberDateRangePickerState(
        initialSelectedStartDateMillis = initialFrom.toUtcMillis(),
        initialSelectedEndDateMillis   = initialTo.toUtcMillis(),
        // Prevent selecting future dates: any day after today is greyed out
        selectableDates = object : SelectableDates {
            /** Allows only days up to and including today (no future dates). */
            override fun isSelectableDate(utcTimeMillis: Long) = utcTimeMillis <= todayMillis
        }
    )

    val canConfirm = pickerState.selectedStartDateMillis != null &&
                     pickerState.selectedEndDateMillis   != null

    Dialog(
        onDismissRequest = onDismiss,
        properties       = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Surface(
            modifier = Modifier.fillMaxSize(),
            color    = MaterialTheme.colorScheme.surface,
            shape    = MaterialTheme.shapes.extraLarge
        ) {
            Column(modifier = Modifier.fillMaxSize()) {
                // The DateRangePicker takes all available height via weight(1f),
                // with the button row pinned to the bottom.
                DateRangePicker(
                    state    = pickerState,
                    modifier = Modifier.weight(1f)
                )

                HorizontalDivider()

                Row(
                    modifier              = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                    horizontalArrangement = Arrangement.End,
                    verticalAlignment     = Alignment.CenterVertically
                ) {
                    TextButton(onClick = onDismiss) {
                        Text(stringResource(R.string.cancel))
                    }
                    Spacer(Modifier.width(8.dp))
                    Button(
                        onClick  = {
                            val from = pickerState.selectedStartDateMillis!!.toDateString()
                            val to   = pickerState.selectedEndDateMillis!!.toDateString()
                            onConfirm(from, to)
                        },
                        enabled  = canConfirm
                    ) {
                        Text(stringResource(R.string.backup_export))
                    }
                }
            }
        }
    }
}
