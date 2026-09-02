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
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.hideFromAccessibility
import androidx.compose.ui.semantics.isTraversalGroup
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.traversalIndex
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import de.godisch.potillus.R
import de.godisch.potillus.domain.AlcoholCalculator
import de.godisch.potillus.domain.DayResolver
import de.godisch.potillus.domain.model.*
import de.godisch.potillus.l10n.fmt1
import de.godisch.potillus.l10n.fmtPercent
import de.godisch.potillus.l10n.formattingLocale
import de.godisch.potillus.ui.component.*
import de.godisch.potillus.ui.theme.dangerRedColor
import de.godisch.potillus.ui.theme.dangerTextColor
import de.godisch.potillus.ui.theme.warningColor

/**
 * Drinks tab: the catalogue of preset and user-defined drinks, with add/edit/
 * delete and quick-log actions.
 *
 * @param vm             The [DrinksViewModel] (catalogue + validation).
 * @param todayVm        The [TodayViewModel], used to quick-log a drink for today.
 * @param onOpenSettings Invoked when the top-bar gear icon is tapped.
 * @param onOpenHelp     Invoked when the overflow-menu Help item is tapped.
 * @param onOpenAbout    Invoked when the overflow-menu About item is tapped.
 * @param onLockApp      Locks the app immediately (overflow-menu "Lock app").
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DrinksScreen(
    vm: DrinksViewModel = viewModel(),
    todayVm: TodayViewModel = viewModel(),
    onOpenSettings: () -> Unit = {},
    onOpenHelp: () -> Unit = {},
    onOpenAbout: () -> Unit = {},
    /** Locks the app immediately (overflow-menu "Lock app"). */
    onLockApp: () -> Unit = {},
) {
    val state by vm.uiState.collectAsStateWithLifecycle()
    val todayState by todayVm.uiState.collectAsStateWithLifecycle()
    val todayDrinks by todayVm.drinks.collectAsStateWithLifecycle()
    val snackbarHost = remember { SnackbarHostState() }
    val drinks = state.drinks
    // Per-app locale for the per-drink gram preview, so its decimal separator
    // matches the in-app language rather than the system locale (l10n/NumberFormat.kt).
    val locale = LocalContext.current.formattingLocale()
    // `showAdd` is rememberSaveable so an open "add drink" dialog survives
    // a configuration change (its form has no pre-selected domain object). The
    // object-valued targets below hold domain models that are intentionally NOT
    // Parcelable (the domain layer is Android-free), so they stay plain `remember`:
    // on recreation the edit/delete/quick-log dialog closes cleanly rather than
    // reopening with a lost target.
    var showAdd by rememberSaveable { mutableStateOf(false) }
    var editDrink by remember { mutableStateOf<DrinkDefinition?>(null) }
    var deleteDrink by remember { mutableStateOf<DrinkDefinition?>(null) }
    var logDrink by remember { mutableStateOf<DrinkDefinition?>(null) }

    // Build the capacity snapshot once per recomposition so all traffic-light dots
    // on the list stay consistent with the current day's consumption.
    val capacity = DrinkCapacity(
        todayGrams = todayState.totalGrams,
        dailyLimitGrams = todayState.limitInfo.limitGrams,
        weeklyTotalGrams = todayState.weeklyTotalGrams,
        weeklyLimitGrams = todayState.limitInfo.weeklyLimitGrams,
        drinkDaysThisWeek = todayState.drinkDaysThisWeek,
        maxDrinkDaysPerWeek = todayState.limitInfo.maxDrinkDaysPerWeek,
    )

    // Collect one-shot events from the ViewModel and show a Snackbar when a
    // deletion is blocked by the FK RESTRICT constraint.
    //
    // WHY showSnackbar() is called directly (not via an extra launch{}):
    //   LaunchedEffect runs in its own coroutine. showSnackbar() is a suspend
    //   function that waits until the snackbar is dismissed. Calling it directly
    //   inside collect{} suspends only the current collect iteration; the next
    //   event will be picked up once the snackbar is gone. This is the correct
    //   pattern for sequential one-shot events.
    //   (The previous version wrapped it in rememberCoroutineScope().launch{},
    //   which was redundant since LaunchedEffect is already a coroutine scope.)
    val deleteBlockedMsg = stringResource(R.string.drink_delete_blocked)
    val validationNameBlank = stringResource(R.string.drink_validation_name_blank)
    val validationNameTooLong = stringResource(R.string.drink_validation_name_too_long)
    val validationVolumeRange = stringResource(R.string.drink_validation_volume_range)
    val validationAlcoholRange = stringResource(R.string.drink_validation_alcohol_range)
    val validationAlcoholBad = stringResource(R.string.drink_validation_alcohol_invalid)
    LaunchedEffect(vm) {
        vm.events.collect { event ->
            when (event) {
                is DrinksEvent.DeleteBlocked -> {
                    snackbarHost.showSnackbar(
                        // String is pre-formatted with drink name and entry count
                        message = deleteBlockedMsg
                            .replace("{name}", event.drinkName)
                            .replace("{count}", event.entryCount.toString()),
                        duration = SnackbarDuration.Long,
                    )
                }
                // Map the machine-readable FieldId + Reason pair emitted by
                // DrinksViewModel.addDrink() to a localised error message. The ViewModel
                // stays free of string resources; all localisation happens here.
                is DrinksEvent.ValidationError -> {
                    val msg = when (event.field) {
                        DrinksEvent.ValidationError.FieldId.NAME -> when (event.reason) {
                            DrinksEvent.ValidationError.Reason.BLANK -> validationNameBlank
                            DrinksEvent.ValidationError.Reason.TOO_LONG -> validationNameTooLong
                            else -> validationNameBlank
                        }
                        DrinksEvent.ValidationError.FieldId.VOLUME_ML -> validationVolumeRange
                        DrinksEvent.ValidationError.FieldId.ALCOHOL_PERCENT -> when (event.reason) {
                            DrinksEvent.ValidationError.Reason.NOT_FINITE -> validationAlcoholBad
                            else -> validationAlcoholRange
                        }
                    }
                    snackbarHost.showSnackbar(message = msg, duration = SnackbarDuration.Long)
                }
            }
        }
    }

    Scaffold(
        contentWindowInsets = WindowInsets(0),
        snackbarHost = { SnackbarHost(snackbarHost) },
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.drinks)) },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    titleContentColor = MaterialTheme.colorScheme.onPrimary,
                ),
                actions = {
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
            FloatingActionButton(
                onClick = { showAdd = true },
                containerColor = MaterialTheme.colorScheme.primary,
                contentColor = MaterialTheme.colorScheme.onPrimary,
            ) {
                Icon(Icons.Default.Add, contentDescription = stringResource(R.string.add_drink))
            }
        },
    ) { paddingValues ->
        LazyColumn(
            // Room to scroll the last row clear of the floating button; see
            // FabListBottomPadding for why Scaffold's own padding is not enough.
            contentPadding = PaddingValues(
                start = 16.dp,
                top = 16.dp,
                end = 16.dp,
                bottom = FabListBottomPadding,
            ),
            verticalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.fillMaxSize().padding(paddingValues),
        ) {
            if (drinks.isEmpty()) {
                item {
                    Text(
                        stringResource(R.string.no_drinks),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(vertical = 24.dp),
                    )
                }
            } else {
                // Stable Room id as key: drinks can be added, deleted, and — via
                // the favourite toggle — REORDERED (favourites sort first); keyed
                // items let Compose MOVE the affected card instead of rebinding
                // every position in between.
                items(drinks, key = { it.id }) { drink ->
                    // Tapping the card body opens the Add Entry dialog with this
                    // drink pre-selected (same behaviour as the quick-bar in TodayScreen).
                    // Tapping the star/edit/delete icon buttons works independently –
                    // nested clickable modifiers in Compose resolve to the innermost
                    // target, so the icons are not affected by the card's clickable.
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surface),
                        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp),
                        onClick = { logDrink = drink },
                    ) {
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 10.dp)
                                // READING ORDER, not drawing order. The star is drawn
                                // first because that is where the eye wants it, but a
                                // screen reader user meets it before anything has said
                                // WHICH drink it belongs to. traversalIndex reorders the
                                // announcement without moving a pixel; iOS does the same
                                // through accessibilitySortPriority, only counting the
                                // other way (higher first there, lower first here).
                                //
                                // isTraversalGroup fences the indices to this row --
                                // without it they are weighed against every other node
                                // on the screen, and the rows interleave.
                                //
                                // The three are stated even though 0f is the default:
                                // an override like this is fragile against later edits,
                                // and a child moved within the Row would otherwise take
                                // the announcement back to drawing order in silence.
                                .semantics { isTraversalGroup = true },
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            // ── Favourite star ────────────────────────────────────────
                            // Deliberately setFavorite, NOT updateDrink: the star changes
                            // no validated field, and an imported drink may sit outside
                            // the editor's bounds (see the setFavorite KDoc) — a full
                            // re-validation here made such a drink un-favouritable.
                            IconButton(
                                onClick = { vm.setFavorite(drink, !drink.isFavorite) },
                                modifier = Modifier.semantics { traversalIndex = 1f },
                            ) {
                                Icon(
                                    imageVector = if (drink.isFavorite) Icons.Default.Star else Icons.Default.StarBorder,
                                    // The state is in the WORD, not only in the shape:
                                    // filled and outlined stars look different and sound
                                    // identical, so one label for both told a screen
                                    // reader user nothing about which one this is.
                                    contentDescription = stringResource(
                                        if (drink.isFavorite) R.string.favorite_remove else R.string.favorite_add,
                                    ),
                                    tint = if (drink.isFavorite) warningColor() else MaterialTheme.colorScheme.onSurfaceVariant,
                                )
                            }
                            // ── Traffic-light dot: between star and name ──────────────
                            // Shows capacity status for this drink's default serving
                            // against today's remaining budget. Updated on every
                            // recomposition (new entry, day change, settings change).
                            val light = AlcoholCalculator.trafficLight(
                                gramsPerDrink = AlcoholCalculator.calculateGrams(drink.volumeMl, drink.alcoholPercent),
                                todayGrams = capacity.todayGrams,
                                dailyLimitGrams = capacity.dailyLimitGrams,
                                weeklyTotalGrams = capacity.weeklyTotalGrams,
                                weeklyLimitGrams = capacity.weeklyLimitGrams,
                                drinkDaysThisWeek = capacity.drinkDaysThisWeek,
                                maxDrinkDaysPerWeek = capacity.maxDrinkDaysPerWeek,
                            )
                            // ONE SENTENCE FOR TALKBACK, in the order a reader
                            // searches: the drink, its category, its figures, its
                            // capacity status. Left alone the row announced the dot
                            // FIRST (it comes first on screen), so every card opened
                            // with a warning and named the drink two swipes later.
                            //
                            // The dot, the name row and the detail line hide
                            // themselves; the wrapper states the sentence. The three
                            // icon buttons stay outside it and keep their own focus.
                            val spokenDrink = stringResource(
                                R.string.a11y_drink_row,
                                drink.name,
                                drink.category.displayLabel(),
                                drink.volumeMl,
                                drink.alcoholPercent.fmtPercent(locale),
                                AlcoholCalculator.calculateGrams(drink.volumeMl, drink.alcoholPercent).fmt1(locale),
                                light.displayLabel(),
                            )
                            TrafficLightDot(
                                light = light,
                                modifier = Modifier.padding(end = 8.dp).semantics { hideFromAccessibility() },
                                useSymbols = todayState.settings.alternativeStatusSymbols,
                            )
                            // ── Name + category + volume info ─────────────────────────
                            Column(
                                modifier = Modifier.weight(1f)
                                    .semantics(mergeDescendants = true) {
                                        contentDescription = spokenDrink
                                        traversalIndex = 0f
                                    },
                            ) {
                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    modifier = Modifier.semantics { hideFromAccessibility() },
                                ) {
                                    Text(drink.name, style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.Medium)
                                    Spacer(Modifier.width(6.dp))
                                    DrinkCategoryIcon(drink.category)
                                }
                                Text(
                                    "${drink.volumeMl} ml · ${drink.alcoholPercent.fmtPercent(locale)} % · ≈ ${AlcoholCalculator.calculateGrams(drink.volumeMl, drink.alcoholPercent).fmt1(locale)} g",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                                    modifier = Modifier.semantics { hideFromAccessibility() },
                                )
                            }
                            // ── Edit / Delete buttons ─────────────────────────────────
                            // The index belongs on the enclosing Row, not on the two
                            // buttons: traversalIndex only ranks siblings WITHIN one
                            // group, so an index on a child of this inner Row would rank
                            // it against its neighbour here and leave the Row itself at
                            // the default 0f in the row above -- read before the star it
                            // is supposed to follow. isTraversalGroup keeps the pair
                            // together, and inside it drawing order already reads right.
                            Row(
                                modifier = Modifier.semantics {
                                    isTraversalGroup = true
                                    traversalIndex = 2f
                                },
                            ) {
                                IconButton(onClick = { editDrink = drink }) {
                                    Icon(Icons.Default.Edit, contentDescription = stringResource(R.string.edit_drink), tint = MaterialTheme.colorScheme.primary)
                                }
                                IconButton(onClick = { deleteDrink = drink }) {
                                    // Not R.string.delete: the bare word names no
                                    // object, as on the entry rows.
                                    Icon(Icons.Default.Delete, contentDescription = stringResource(R.string.delete_drink), tint = dangerRedColor())
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    if (showAdd) {
        AddEditDrinkDialog(
            drink = null,
            onSave = { n, v, p, cat ->
                vm.addDrink(n, v, p, cat)
                showAdd = false
            },
            onDismiss = { showAdd = false },
        )
    }
    editDrink?.let { drink ->
        AddEditDrinkDialog(
            drink = drink,
            onSave = { n, v, p, cat ->
                vm.updateDrink(drink.copy(name = n, volumeMl = v, alcoholPercent = p, category = cat))
                editDrink = null
            },
            onDismiss = { editDrink = null },
        )
    }
    deleteDrink?.let { drink ->
        AlertDialog(
            onDismissRequest = { deleteDrink = null },
            title = { Text(stringResource(R.string.delete)) },
            text = { Text(stringResource(R.string.delete_confirm, drink.name)) },
            confirmButton = {
                TextButton(onClick = {
                    vm.deleteDrink(drink)
                    deleteDrink = null
                }) {
                    Text(stringResource(R.string.delete), color = dangerTextColor())
                }
            },
            dismissButton = {
                TextButton(onClick = { deleteDrink = null }) { Text(stringResource(R.string.cancel)) }
            },
        )
    }

    // Tap-to-log: the card body tap opens this dialog with the drink pre-selected.
    // Uses TodayViewModel.addEntry() so the entry lands on today's logical date,
    // identical to logging from the Today screen.
    logDrink?.let { drink ->
        AddEditEntryDialog(
            entry = null,
            drinks = todayDrinks,
            preSelectedDrink = drink,
            capacity = capacity,
            useStatusSymbols = todayState.settings.alternativeStatusSymbols,
            logicalDay = DayResolver.today(todayState.settings.dayChangeHour, todayState.settings.dayChangeMinute),
            dayChangeHour = todayState.settings.dayChangeHour,
            dayChangeMinute = todayState.settings.dayChangeMinute,
            onSave = { d, vol, ts, note ->
                todayVm.addEntry(d, vol, ts, note)
                logDrink = null
            },
            onDismiss = { logDrink = null },
        )
    }
}
