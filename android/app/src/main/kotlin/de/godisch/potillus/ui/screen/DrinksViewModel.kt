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
import de.godisch.potillus.domain.DrinkValidator
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
        enum class Reason { BLANK, TOO_LONG, OUT_OF_RANGE, NOT_FINITE }
    }
}

@Immutable
data class DrinksUiState(val drinks: List<DrinkDefinition> = emptyList())

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
     * @param name           Drink name (non-blank, ≤ [DrinkValidator.MAX_NAME_LENGTH] chars).
     * @param volumeMl       Serving volume in millilitres (in [DrinkValidator.VOLUME_ML_RANGE]).
     * @param alcoholPercent Alcohol by volume, percent (finite, in [DrinkValidator.ALCOHOL_PERCENT_RANGE]).
     * @param category       The drink category.
     */
    fun addDrink(name: String, volumeMl: Int, alcoholPercent: Double, category: DrinkCategory) {
        val violation = DrinkValidator.validate(name, volumeMl, alcoholPercent)
        if (violation != null) {
            reject("addDrink", violation)
            return
        }
        viewModelScope.launch {
            drinkRepo.add(
                DrinkDefinition(
                    name = name.trim(),
                    volumeMl = volumeMl,
                    alcoholPercent = alcoholPercent,
                    category = category,
                ),
            )
        }
    }

    /**
     * Persists an edited drink.
     *
     * Validated exactly like [addDrink]. Before v0.81.0 this trusted its caller,
     * which happened to be a dialog that validated — any third caller would have
     * been free to write a 0 ml drink straight into the database.
     *
     * The favourite STAR does not go through here: it changes none of the
     * validated fields, and a drink imported from a backup may legitimately sit
     * outside the editor's bounds (see [setFavorite] for the full rationale).
     * This function is for edits of the validated fields themselves.
     */
    fun updateDrink(drink: DrinkDefinition) {
        val violation = DrinkValidator.validate(drink.name, drink.volumeMl, drink.alcoholPercent)
        if (violation != null) {
            reject("updateDrink", violation)
            return
        }
        viewModelScope.launch { drinkRepo.update(drink.copy(name = drink.name.trim())) }
    }

    /**
     * Sets or clears the favourite flag of an existing [drink] WITHOUT running
     * [DrinkValidator] over the other fields.
     *
     * WHY A SEPARATE, VALIDATION-FREE PATH?
     *   The star toggle changes exactly one field that no validation rule covers.
     *   Routing it through [updateDrink] (as the screen did until the v0.81.0 QA
     *   review) re-validated the UNTOUCHED name/volume/alcohol values — and those
     *   may legitimately violate the editor's bounds: [de.godisch.potillus.util.BackupManager]
     *   deliberately imports drinks up to 10 000 ml (wider than
     *   [DrinkValidator.VOLUME_ML_RANGE]) so a backup from a foreign or future
     *   version is not refused, and documents that such a drink "stays usable".
     *   Tapping the star on such an imported drink then failed with a VOLUME
     *   validation error for a field the user never touched, and the toggle was
     *   impossible. Writing only the flipped flag keeps the stored (already
     *   accepted) values byte-identical, so no invalid data can enter the
     *   database through this path.
     *
     * @param drink    The stored drink whose flag to change (all other fields are
     *                 written back unmodified).
     * @param favorite The new favourite state.
     */
    fun setFavorite(drink: DrinkDefinition, favorite: Boolean) {
        viewModelScope.launch { drinkRepo.update(drink.copy(isFavorite = favorite)) }
    }

    /**
     * Reports a [DrinkValidator.Violation] to the UI as a [DrinksEvent].
     *
     * The domain's enums are mapped onto the UI's rather than shared: the domain
     * must not depend on the presentation layer. The two vocabularies coincide
     * only because they describe the same rules.
     */
    private fun reject(caller: String, violation: DrinkValidator.Violation) {
        if (BuildConfig.DEBUG) Log.w(TAG, "$caller: rejected - $violation")
        viewModelScope.launch {
            _events.emit(
                DrinksEvent.ValidationError(
                    when (violation.field) {
                        DrinkValidator.Field.NAME -> DrinksEvent.ValidationError.FieldId.NAME
                        DrinkValidator.Field.VOLUME_ML -> DrinksEvent.ValidationError.FieldId.VOLUME_ML
                        DrinkValidator.Field.ALCOHOL_PERCENT ->
                            DrinksEvent.ValidationError.FieldId.ALCOHOL_PERCENT
                    },
                    when (violation.reason) {
                        DrinkValidator.Reason.BLANK -> DrinksEvent.ValidationError.Reason.BLANK
                        DrinkValidator.Reason.TOO_LONG -> DrinksEvent.ValidationError.Reason.TOO_LONG
                        DrinkValidator.Reason.OUT_OF_RANGE ->
                            DrinksEvent.ValidationError.Reason.OUT_OF_RANGE
                        DrinkValidator.Reason.NOT_FINITE ->
                            DrinksEvent.ValidationError.Reason.NOT_FINITE
                    },
                ),
            )
        }
    }

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
