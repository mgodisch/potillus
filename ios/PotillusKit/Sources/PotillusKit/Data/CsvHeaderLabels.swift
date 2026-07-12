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

import Foundation

// =============================================================================
// CsvHeaderLabels.swift – localized CSV column captions, in column order
// =============================================================================
//
// The CSV export follows the in-app language, exactly as Android does: Android
// resolves eight `csv_col_*` string resources at the call site and hands them to
// the shared `buildCsv`. iOS needs the same captions, but `CsvExporter` lives in
// PotillusKit — below the app's String Catalogue — so the captions cannot be
// looked up from `Bundle.main` there. They live here instead, as a small
// language-keyed table, the same way `ReportLabelsCatalog` carries the localized
// PDF-report labels for the same reason.
//
// SOURCE OF TRUTH
//   Every row is copied VERBATIM from Android's `values-<locale>/strings.xml`
//   (`csv_col_date` … `csv_col_note`). Keeping the two identical is what lets a
//   spreadsheet built against one platform's export open against the other's; the
//   `check-l10n-parity` gate enforces that identity so the tables cannot drift.
//   The machine-ish underscored captions (`Amount_ml`, …) are localized too —
//   German exports `Menge_ml`, Japanese `量_ml` — because Android localizes them.
// =============================================================================

public enum CsvHeaderLabels {

    /// The eight column captions in the order `CsvExporter` writes them:
    /// date, time, drink, category, volume, alcohol percent, grams, note.
    ///
    /// English is the source language and the fallback for the "System" setting
    /// (an empty tag) and for any language without its own row.
    public static let englishCells = ["Date", "Time", "Drink", "Category", "Amount_ml", "Alcohol_Percent", "Grams_Alcohol", "Note"]

    /// The localized captions for `language` (an app language tag such as `"de"`
    /// or `"zh-Hant"`), in column order. Falls back to `englishCells`.
    public static func cells(language: String) -> [String] {
        switch language {
        case "de": return ["Datum", "Uhrzeit", "Getränk", "Kategorie", "Menge_ml", "Alkohol_Prozent", "Gramm_Alkohol", "Notiz"]
        case "da": return ["Dato", "Tidspunkt", "Drik", "Kategori", "Mængde_ml", "Alkohol_procent", "Gram_alkohol", "Note"]
        case "nl": return ["Datum", "Tijdstip", "Drank", "Categorie", "Hoeveelheid_ml", "Alcohol_percentage", "Gram_alcohol", "Notitie"]
        case "nb": return ["Dato", "Tidspunkt", "Drikk", "Kategori", "Volum_ml", "Alkohol_prosent", "Gram_alkohol", "Notat"]
        case "sv": return ["Datum", "Tid", "Dryck", "Kategori", "Mängd_ml", "Alkohol_procent", "Gram_alkohol", "Anteckning"]
        case "es": return ["Fecha", "Hora", "Bebida", "Categoría", "Volumen_ml", "Alcohol_porcentaje", "Gramos_alcohol", "Nota"]
        case "fr": return ["Date", "Heure", "Boisson", "Catégorie", "Volume_ml", "Alcool_pourcentage", "Grammes_alcool", "Note"]
        case "it": return ["Data", "Orario", "Bevanda", "Categoria", "Quantità_ml", "Alcol_percentuale", "Grammi_alcol", "Nota"]
        case "pt": return ["Data", "Hora", "Bebida", "Categoria", "Quantidade_ml", "Álcool_percentagem", "Gramas_álcool", "Nota"]
        case "pt-BR": return ["Data", "Horário", "Bebida", "Categoria", "Quantidade_ml", "Álcool_porcentagem", "Gramas_álcool", "Nota"]
        case "ro": return ["Dată", "Oră", "Băutură", "Categorie", "Cantitate_ml", "Alcool_procent", "Grame_alcool", "Notă"]
        case "cs": return ["Datum", "Čas", "Nápoj", "Kategorie", "Množství_ml", "Alkohol_procento", "Gramy_alkoholu", "Poznámka"]
        case "pl": return ["Data", "Godzina", "Napój", "Kategoria", "Ilość_ml", "Alkohol_procent", "Gramy_alkoholu", "Notatka"]
        case "ru": return ["Дата", "Время", "Напиток", "Категория", "Объём_мл", "Алкоголь_процент", "Граммы_алкоголя", "Заметка"]
        case "uk": return ["Дата", "Час", "Напій", "Категорія", "Кількість_мл", "Алкоголь_відсоток", "Грами_алкоголю", "Примітка"]
        case "el": return ["Ημερομηνία", "Ώρα", "Ποτό", "Κατηγορία", "Ποσότητα_ml", "Αλκοόλη_ποσοστό", "Γρ_αλκοόλης", "Σημείωση"]
        case "ja": return ["日付", "時刻", "飲み物", "カテゴリ", "量_ml", "アルコール_パーセント", "グラム_アルコール", "メモ"]
        case "ko": return ["날짜", "시간", "음료", "카테고리", "양_ml", "알코올_퍼센트", "그램_알코올", "메모"]
        case "zh-Hans": return ["日期", "时间", "饮品", "类别", "数量_ml", "酒精_百分比", "克_酒精", "备注"]
        case "zh-Hant": return ["日期", "時間", "飲品", "類別", "份量_毫升", "酒精_百分比", "公克_酒精", "備注"]
        default: return englishCells
        }
    }
}
