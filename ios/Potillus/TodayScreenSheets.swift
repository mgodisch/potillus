// vim: set et ts=4:
// =============================================================================
// Libellus Potionis - Privacy-Friendly Alcohol Tracker
// Copyright (c) 2026 Martin A. Godisch <martin@godisch.de>
// =============================================================================
//
// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program.  If not, see <https://www.gnu.org/licenses/>.
//
// In addition, as permitted by section 7 of the GNU General Public License,
// this program may carry additional permissions; any such permissions that
// apply to it are stated in the accompanying COPYING.md file.
//
// =============================================================================

import PotillusKit
import SwiftUI

// =============================================================================
// TodayScreen – the log and edit sheets
// =============================================================================
//
// Split from TodayScreen.swift because that file had reached SwiftLint's length
// limit, the same seam the statistics export took. The two belong together: one
// sheet in two moods, as Android keeps one `AddEditEntryDialog` for both.
//
// THE DAY IS THE SCREEN'S, THE TIME IS THE USER'S. Both hand the sheet the
// logical day they are logging for and the day-change time that defines it, so a
// time typed before that boundary shows the calendar date it will be stored on,
// and the model places it there. See `TodayModel.addEntry`.
// =============================================================================

extension TodayScreen {

    /// The sheet that logs a new entry for today.
    @ViewBuilder
    var logSheet: some View {
        EntrySheet(
            drinks: model.state.drinks,
            // People tend to repeat what they just had.
            preselected: model.state.preselectionForLogging,
            now: Date(),
            // The Today model already holds the day's totals and limits,
            // so the log sheet gets the capacity dot too, as on Android.
            capacity: DrinkCapacity(
                todayGrams: model.state.totalGrams,
                dailyLimitGrams: model.state.limitInfo.limitGrams,
                weeklyTotalGrams: model.state.weeklyTotalGrams,
                weeklyLimitGrams: model.state.limitInfo.weeklyLimitGrams,
                drinkDaysThisWeek: model.state.drinkDaysThisWeek,
                maxDrinkDaysPerWeek: model.state.limitInfo.maxDrinkDaysPerWeek
            ),
            useSymbols: model.state.settings.alternativeStatusSymbols,
            logicalDay: model.state.logicalDate,
            origin: .now,
            dayChangeHour: model.state.settings.dayChangeHour,
            dayChangeMinute: model.state.settings.dayChangeMinute
        ) { drink, volume, millis, offset, note in
            await model.addEntry(
                drink: drink, volumeMl: volume,
                timestampMillis: millis, utcOffsetSeconds: offset, note: note
            )
            return model.failure == nil
        }
    }

    /// The sheet that edits one of today's rows.
    @ViewBuilder
    func editSheet(for entry: ConsumptionEntry) -> some View {
        // Editing offers the whole catalogue with the entry's own drink
        // preselected, as Android's dialog does (v0.86.0; until then a
        // one-element catalogue kept the drink fixed). Choosing another
        // drink rewrites the denormalised name and strength and the grams
        // follow, exactly as when logging. The same scope, and the same
        // code, as the calendar's edit.
        EntrySheet(
            drinks: model.state.drinks,
            preselected: model.state.drinks.first { $0.id == entry.drinkId } ?? drink(from: entry),
            now: Date(),
            editing: entry,
            logicalDay: entry.logicalDate,
            origin: .edit,
            dayChangeHour: model.state.settings.dayChangeHour,
            dayChangeMinute: model.state.settings.dayChangeMinute
        ) { drink, volume, millis, offset, note in
            var updated = entry
            updated.drinkId = drink.id
            updated.drinkName = drink.name
            updated.alcoholPercent = drink.alcoholPercent
            updated.volumeMl = volume
            updated.timestampMillis = millis
            // The frame comes from the sheet, which knows whether the user moved
            // the date: a corrected time keeps the frame the reading was taken in,
            // a new date is read in this one.
            updated.utcOffsetSeconds = offset
            updated.note = note
            updated.gramsAlcohol = AlcoholCalculator.calculateGrams(
                volumeMl: volume, alcoholPercent: drink.alcoholPercent
            )
            await model.updateEntry(updated)
            return model.failure == nil
        }
    }
}
