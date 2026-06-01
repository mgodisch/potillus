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

// =============================================================================
// DrinksViewModel.kt – ViewModel for the Drinks screen
// =============================================================================
//
// RESPONSIBILITIES:
//   - Exposes [DrinksUiState] (the current drink catalogue) as a [StateFlow].
//   - Handles add / update / delete with input validation and FK-guard logic.
//   - Emits one-shot [DrinksEvent] values for side effects the UI must handle
//     exactly once (e.g. "delete blocked because entries exist").
//
// See ViewModels.kt (package overview) for the shared Flow → StateFlow
// pattern, @Immutable contract, manual-DI rationale, and Log-guard rule.
// =============================================================================

import android.util.Log
import androidx.compose.runtime.Immutable
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import de.godisch.potillus.BuildConfig
import de.godisch.potillus.data.repository.IDrinkRepository
import de.godisch.potillus.domain.model.*
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

// ════════════════════════════════════════════════════════════════════════════
// DRINKS
// ════════════════════════════════════════════════════════════════════════════

/**
 * One-shot UI events emitted by [DrinksViewModel] and consumed by [DrinksScreen].
 *
 * WHY a sealed class instead of a nullable State field?
 *   State is persistent: the UI re-renders the same message every time it
 *   recomposes. Events are consumed once and should not reappear after the
 *   user dismisses them or after a screen rotation.
 *
 * HOW it is consumed:
 *   [DrinksScreen] uses `LaunchedEffect(vm) { vm.events.collect { … } }` to
 *   listen for events. [SharedFlow] with `extraBufferCapacity = 1` ensures
 *   the event is not lost if the collector is momentarily suspended
 *   (e.g. while the snackbar from the previous event is still visible).
 *
 * KOTLIN "sealed class":
 *   All subclasses must be declared in the same file. This makes `when`
 *   expressions exhaustive – the compiler will warn if a new subtype is
 *   added but not handled in the screen.
 */
sealed class DrinksEvent {
    /** The drink has referenced entries and cannot be deleted due to the FK RESTRICT constraint. */
    data class DeleteBlocked(val drinkName: String, val entryCount: Int) : DrinksEvent()

    /**
     * A field in the Add/Edit Drink form failed validation.
     *
     * Validation failures in [DrinksViewModel.addDrink] are surfaced as this typed
     * event rather than swallowed with a logcat warning: swallowing would leave the
     * UI with no feedback, so the form would simply do nothing when the user tapped
     * "Save" with invalid input.
     *
     * Using a typed event keeps the ViewModel free of string resources (the ViewModel
     * emits a machine-readable [FieldId]; the screen maps it to a localised error
     * message). The [FieldId] enum makes the `when` in [DrinksScreen] exhaustive.
     *
     * @param field   Which input field failed validation.
     * @param reason  Machine-readable failure code for the screen to localise.
     */
    data class ValidationError(val field: FieldId, val reason: Reason) : DrinksEvent() {
        enum class FieldId { NAME, VOLUME_ML, ALCOHOL_PERCENT }
        enum class Reason  { BLANK, TOO_LONG, OUT_OF_RANGE, NOT_FINITE }
    }
}

@Immutable
data class DrinksUiState(val drinks: List<DrinkDefinition> = emptyList())

/** Maximum length of a user-defined drink name. */
private const val MAX_DRINK_NAME_LEN   = 100
/** Accepted volume range in ml (1 ml … 10 l). */
private val VALID_VOLUME_ML_RANGE      = 1..10_000
/** Accepted alcohol-by-volume range (0 % … 100 %). */
private val VALID_ALCOHOL_PCT_RANGE    = 0.0..100.0

class DrinksViewModel(private val drinkRepo: IDrinkRepository) : ViewModel() {

    companion object {
        private const val TAG = "DrinksViewModel"
    }

    private val _events = MutableSharedFlow<DrinksEvent>(extraBufferCapacity = 1)
    val events: SharedFlow<DrinksEvent> = _events

    val uiState: StateFlow<DrinksUiState> = drinkRepo.drinks
        .map { DrinksUiState(it) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), DrinksUiState())

    /**
     * Validates the supplied fields and, if all pass, persists a new user drink.
     *
     * Each validation failure emits a [DrinksEvent.ValidationError] (field id +
     * reason) so the screen can show a localised message; nothing is written to
     * the database unless every field is valid.
     *
     * @param name           Drink name (non-blank, ≤ [MAX_DRINK_NAME_LEN] chars).
     * @param volumeMl       Serving volume in millilitres (in [VALID_VOLUME_ML_RANGE]).
     * @param alcoholPercent Alcohol by volume in percent (finite, in [VALID_ALCOHOL_PCT_RANGE]).
     * @param category       The drink category.
     */
    fun addDrink(name: String, volumeMl: Int, alcoholPercent: Double, category: DrinkCategory) {
        // Validation failures emit a [DrinksEvent.ValidationError] so the UI can
        // show a localised error message instead of only writing a logcat warning
        // (which would leave the user with no feedback when "Save" did nothing).
        // The ViewModel emits a machine-readable FieldId + Reason pair; DrinksScreen
        // maps those to string resources, keeping the ViewModel free of resources.
        if (name.isBlank()) {
            if (BuildConfig.DEBUG) Log.w(TAG, "addDrink: rejected – name blank")
            viewModelScope.launch {
                _events.emit(DrinksEvent.ValidationError(
                    DrinksEvent.ValidationError.FieldId.NAME,
                    DrinksEvent.ValidationError.Reason.BLANK
                ))
            }
            return
        }
        if (name.length > MAX_DRINK_NAME_LEN) {
            if (BuildConfig.DEBUG) Log.w(TAG, "addDrink: rejected – name too long (${name.length})")
            viewModelScope.launch {
                _events.emit(DrinksEvent.ValidationError(
                    DrinksEvent.ValidationError.FieldId.NAME,
                    DrinksEvent.ValidationError.Reason.TOO_LONG
                ))
            }
            return
        }
        if (volumeMl !in VALID_VOLUME_ML_RANGE) {
            if (BuildConfig.DEBUG) Log.w(TAG, "addDrink: rejected – volumeMl=$volumeMl out of range")
            viewModelScope.launch {
                _events.emit(DrinksEvent.ValidationError(
                    DrinksEvent.ValidationError.FieldId.VOLUME_ML,
                    DrinksEvent.ValidationError.Reason.OUT_OF_RANGE
                ))
            }
            return
        }
        if (!alcoholPercent.isFinite()) {
            if (BuildConfig.DEBUG) Log.w(TAG, "addDrink: rejected – alcoholPercent=$alcoholPercent not finite")
            viewModelScope.launch {
                _events.emit(DrinksEvent.ValidationError(
                    DrinksEvent.ValidationError.FieldId.ALCOHOL_PERCENT,
                    DrinksEvent.ValidationError.Reason.NOT_FINITE
                ))
            }
            return
        }
        if (alcoholPercent !in VALID_ALCOHOL_PCT_RANGE) {
            if (BuildConfig.DEBUG) Log.w(TAG, "addDrink: rejected – alcoholPercent=$alcoholPercent out of range")
            viewModelScope.launch {
                _events.emit(DrinksEvent.ValidationError(
                    DrinksEvent.ValidationError.FieldId.ALCOHOL_PERCENT,
                    DrinksEvent.ValidationError.Reason.OUT_OF_RANGE
                ))
            }
            return
        }
        viewModelScope.launch {
            drinkRepo.add(DrinkDefinition(
                name           = name.trim(),
                volumeMl       = volumeMl,
                alcoholPercent = alcoholPercent,
                category       = category
            ))
        }
    }

    /**
     * Persists edits to an existing [drink].
     *
     * @param drink The modified drink definition (validation is the caller's
     *              responsibility; the edit dialog reuses the same field checks).
     */
    fun updateDrink(drink: DrinkDefinition) { viewModelScope.launch { drinkRepo.update(drink) } }

    /**
     * Deletes [drink] if no entries reference it.
     *
     * If entries exist, a [DrinksEvent.DeleteBlocked] event is emitted so the
     * screen can show an informative message without relying on the FK constraint
     * exception propagating to the UI.
     */
    fun deleteDrink(drink: DrinkDefinition) {
        viewModelScope.launch {
            val count = drinkRepo.countEntriesForDrink(drink.id)
            if (count > 0) {
                _events.emit(DrinksEvent.DeleteBlocked(drink.name, count))
            } else {
                drinkRepo.delete(drink)
            }
        }
    }
}
