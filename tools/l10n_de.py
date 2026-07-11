#!/usr/bin/env python3
# vim: set et ts=4:
# =============================================================================
# Libellus Potionis - Privacy-Friendly Alcohol Tracker
# Copyright (c) 2026 Martin A. Godisch <martin@godisch.de>
# =============================================================================
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <https://www.gnu.org/licenses/>.
#
# In addition, as permitted by section 7 of the GNU General Public License,
# this program may carry additional permissions; any such permissions that
# apply to it are stated in the accompanying COPYING.md file.
#
# =============================================================================
#

# German for the iOS-only / reworded strings. Harvested German (19) is merged in
# separately by the builder. Pure-interpolation strings are intentionally ABSENT
# here: they carry no words and are the same in every language.
MINE_DE = {
    # About screen (patch -81)
    "Include in device backup": "In Gerätesicherung einschließen",
    "About": "Über",
    "Version": "Version",
    "Licence": "Lizenz",
    "Copyright & licence": "Copyright & Lizenz",
    "Open-source components": "Open-Source-Komponenten",
    "Libellus Potionis is free software under the GNU GPL, version 3 or later.": "Libellus Potionis ist freie Software unter der GNU GPL, Version 3 oder höher.",
    "This document could not be loaded.": "Dieses Dokument konnte nicht geladen werden.",
    'Alcohol': 'Alkohol',
    'Alcohol (%)': 'Alkohol (%)',
    'Category': 'Kategorie',
    'Current streak': 'Aktuelle Serie',
    'Drink': 'Getränk',
    'Drink days': 'Trinktage',
    'Dry days in period': 'Trockene Tage im Zeitraum',
    'Estimated BAC': 'Geschätzter BAK',
    'Longest streak': 'Längste Serie',
    'Name': 'Name',
    'Note': 'Notiz',
    'Per day': 'Pro Tag',
    'Per drink day': 'Pro Trinktag',
    'Time': 'Uhrzeit',
    'Total': 'Gesamt',
    'Trend': 'Trend',
    'Volume (ml)': 'Volumen (ml)',
    "A drink logged before this time counts towards the previous day.":
        "Ein Getränk vor dieser Uhrzeit zählt zum Vortag.",
    "Abstinence": "Abstinenz",
    "Add to favourites": "Zu Favoriten hinzufügen",
    "Add": "Hinzufügen",
    "Add a drink to start logging.": "Füge ein Getränk hinzu, um zu beginnen.",
    "Alternative status symbols": "Alternative Statussymbole",
    "App lock": "App-Sperre",
    "App lock needs Face ID, Touch ID, or a device passcode.":
        "Die App-Sperre benötigt Face ID, Touch ID oder einen Gerätecode.",
    "By category": "Nach Kategorie",
    "By weekday": "Nach Wochentag",
    "Clear body weight": "Körpergewicht löschen",
    "Body weight": "Körpergewicht",
    "Consumption": "Konsum",
    "Daily limit": "Tageslimit",
    "Day starts at": "Tag beginnt um",
    "Drink days per week": "Trinktage pro Woche",
    "Day change": "Tageswechsel",
    "Days after today cannot be selected.":
        "Tage nach heute können nicht gewählt werden.",
    "Days before this date are ignored in statistics. Entries are not deleted.":
        "Tage vor diesem Datum werden in der Statistik ignoriert. Einträge werden nicht gelöscht.",
    "Days over limit": "Tage über Limit",
    "Done": "Fertig",
    "Entries": "Einträge",
    "Export CSV": "CSV exportieren",
    "Export PDF report": "PDF-Bericht exportieren",
    "Export backup": "Backup exportieren",
    "Favourites": "Favoriten",
    "From": "Von",
    "Import backup": "Backup importieren",
    "Include all history": "Gesamten Verlauf einbeziehen",
    "Include settings": "Einstellungen einbeziehen",
    "Libellus Potionis could not start": "Libellus Potionis konnte nicht starten",
    "Libellus Potionis is locked": "Libellus Potionis ist gesperrt",
    "Log a drink": "Getränk erfassen",
    "Merge with my data": "Mit meinen Daten zusammenführen",
    "No drinks yet": "Noch keine Getränke",
    "Nothing logged on this day.": "An diesem Tag nichts erfasst.",
    "Nothing logged yet.": "Noch nichts erfasst.",
    "OK": "OK",
    "Period": "Zeitraum",
    "Personal data": "Persönliche Daten",
    "Preset": "Vorlage",
    "Remove from favourites": "Aus Favoriten entfernen",
    "Replace my data": "Meine Daten ersetzen",
    "Replacing deletes your log and the drinks you created. Presets are kept.":
        "Beim Ersetzen werden dein Logbuch und die von dir erstellten Getränke gelöscht. Vorlagen bleiben erhalten.",
    "Set body weight": "Körpergewicht festlegen",
    "Show in app switcher": "In App-Übersicht anzeigen",
    "Statistics cover the whole history.": "Die Statistik umfasst den gesamten Verlauf.",
    "Statistics start": "Statistikbeginn",
    "Theme": "Design",
    "Time of day": "Tageszeit",
    "Weekly limit": "Wochenlimit",
    "To": "Bis",
    "Unlock": "Entsperren",
    "Week": "Woche",
    "g": "g",
    "g / day": "g/Tag",
}

# Strings that contain interpolation and DO carry words needing translation.
# Placeholders are converted to iOS format by the builder; keys stay as the
# English source with %-placeholders.
MINE_DE_INTERP = {
    "Delete %@": "%@ löschen",
    "Edit %@": "%@ bearbeiten",
    "%1$@ is used by %2$lld entries.": "%1$@ wird von %2$lld Einträgen verwendet.",
    "%1$lld ml · %2$@": "%1$lld ml · %2$@",
    "The volume must be between ": "Das Volumen muss liegen zwischen ",
}

# Pure-interpolation, no words: same in every language, no catalog entry with a
# fixed translation. Listed so the builder can mark them source-only.
PURE_INTERP = {
    "%lld ml",           # \(drink.volumeMl) ml
    "%lld",              # \(model.settings.maxDrinkDaysPerWeek), \(value)
    "%@",                # \(value) as string
    "%1$@ / %2$@",       # \(value) / \(limit)
}
