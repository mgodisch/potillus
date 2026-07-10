// vim: set et ts=4:
// =============================================================================
// Libellus Potionis - Privacy-Friendly Alcohol Tracker
// Copyright (c) 2026 Martin A. Godisch <android@godisch.de>
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

import Foundation
import Observation

// =============================================================================
// DrinksModel.swift – the drink catalogue
// =============================================================================
//
// The counterpart of Android's `DrinksViewModel`. Validation goes through
// `DrinkValidator`, the same rules the view consults to decide whether its Save
// button may be tapped — so the button can never offer what the model rejects.
// That symmetry is the whole point: on Android the two disagreed until v0.81.0.
//
// DELETION IS GUARDED, NOT ATTEMPTED
//   `entries.drinkId` references `drinks.id` with ON DELETE RESTRICT, so deleting
//   a drink that has entries fails at the database. Relying on that failure would
//   surface a SQLite error code to the user. The model asks FIRST, and reports
//   how many entries stand in the way, which is the sentence the user needs:
//   "Pils is used by 23 entries."
//
//   Between the count and the delete another entry could in principle be logged.
//   The database still refuses, so the outcome is a caught error rather than a
//   lost entry — the guard improves the message, it does not replace the
//   constraint.
// =============================================================================

/// What the drinks screen shows.
public struct DrinksState: Sendable, Equatable {
    /// The catalogue: favourites first, then alphabetical.
    public var drinks: [DrinkDefinition] = []
    public init() {}
}

/// Why a drink could not be deleted.
public struct DeleteBlocked: Sendable, Equatable, Error {
    public let drinkName: String
    public let entryCount: Int
}

@MainActor
@Observable
public final class DrinksModel {

    public private(set) var state = DrinksState()

    /// A validation failure from the last write, for the view to render next to
    /// the offending field.
    public private(set) var violation: DrinkValidator.Violation?

    /// Set when a delete was refused because entries reference the drink.
    public private(set) var deleteBlocked: DeleteBlocked?

    /// Anything else that went wrong. Never swallowed.
    public private(set) var failure: String?

    private let drinks: any DrinkRepositoryProtocol
    private var observation: Task<Void, Never>?

    public init(drinks: any DrinkRepositoryProtocol) {
        self.drinks = drinks
    }

    // No `deinit` cancelling the task: a `deinit` on a `@MainActor` class is
    // nonisolated, and reaching into isolated state from there is a rule that has
    // shifted between Swift versions. The task captures `self` weakly, so it
    // cannot keep the model alive; the view calls `stop()` when it disappears.

    // ── Observation ──────────────────────────────────────────────────────────

    /// Subscribes to the catalogue. Safe to call more than once; the previous
    /// subscription is cancelled, so a re-appearing view does not accumulate them.
    public func start() {
        observation?.cancel()
        observation = Task { [weak self] in
            guard let self else { return }
            do {
                for try await catalogue in self.drinks.observeDrinks() {
                    self.state.drinks = catalogue
                }
            } catch {
                self.failure = String(describing: error)
            }
        }
    }

    public func stop() {
        observation?.cancel()
        observation = nil
    }

    // ── Writes ───────────────────────────────────────────────────────────────

    /// Adds a drink, or records why it could not be added.
    ///
    /// The name is stored trimmed, by the same helper that measured it. Validating
    /// one string and persisting another is how a 101-character name reaches the
    /// database.
    @discardableResult
    public func add(
        name: String, volumeMl: Int, alcoholPercent: Double, category: DrinkCategory
    ) -> Bool {
        guard accept(name: name, volumeMl: volumeMl, alcoholPercent: alcoholPercent) else {
            return false
        }
        return perform {
            _ = try self.drinks.add(
                DrinkDefinition(
                    name: DrinkValidator.canonicalName(name),
                    volumeMl: volumeMl,
                    alcoholPercent: alcoholPercent,
                    category: category
                )
            )
        }
    }

    /// Updates a drink, validated exactly like `add`.
    ///
    /// Android's `updateDrink` trusted its caller until v0.81.0. The favourite
    /// toggle below is a second caller; a third would have been free to write a
    /// 0 ml drink.
    @discardableResult
    public func update(_ drink: DrinkDefinition) -> Bool {
        guard accept(
            name: drink.name, volumeMl: drink.volumeMl, alcoholPercent: drink.alcoholPercent
        ) else { return false }

        var canonical = drink
        canonical.name = DrinkValidator.canonicalName(drink.name)
        return perform { try self.drinks.update(canonical) }
    }

    /// Flips the favourite flag. Goes through `update`, so it is validated too.
    @discardableResult
    public func toggleFavorite(_ drink: DrinkDefinition) -> Bool {
        var flipped = drink
        flipped.isFavorite.toggle()
        return update(flipped)
    }

    /// Deletes a drink, unless entries reference it.
    ///
    /// Returns false and populates `deleteBlocked` when the drink is in use, so
    /// the view can say how many entries are in the way rather than showing a
    /// database error.
    @discardableResult
    public func delete(_ drink: DrinkDefinition) -> Bool {
        clearErrors()
        do {
            let entryCount = try drinks.countEntries(forDrink: drink.id)
            guard entryCount == 0 else {
                deleteBlocked = DeleteBlocked(drinkName: drink.name, entryCount: entryCount)
                return false
            }
        } catch {
            failure = String(describing: error)
            return false
        }
        return perform { try self.drinks.delete(drink) }
    }

    // ── Error surface ────────────────────────────────────────────────────────

    /// Clears whatever the last write left behind. The view calls this when the
    /// user dismisses an alert, or opens the editor afresh.
    public func clearErrors() {
        violation = nil
        deleteBlocked = nil
        failure = nil
    }

    /// Validates and records the violation. Returns whether the write may proceed.
    private func accept(name: String, volumeMl: Int, alcoholPercent: Double) -> Bool {
        clearErrors()
        violation = DrinkValidator.validate(
            name: name, volumeMl: volumeMl, alcoholPercent: alcoholPercent
        )
        return violation == nil
    }

    /// Runs a write, recording any failure. The catalogue refreshes through the
    /// observation, so nothing is reloaded here.
    private func perform(_ write: () throws -> Void) -> Bool {
        do {
            try write()
            return true
        } catch {
            failure = String(describing: error)
            return false
        }
    }
}
