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
// ReportLabels(language:) - the PDF report's labels in every shipping language.
//
// This file is the committed source of truth, hand-maintained like a native iOS
// app's — the build reads no generator and no android/. It must still match
// Android's report strings word for word; tools/check-l10n-parity.py verifies that
// against android/ in both `make ios` and `make android`, and fails on any drift.
// The report follows the UI language, as Android's does (Context.formattingLocale
// drives both its labels and numbers).
//
// ReportLabels declares an explicit init(), which suppresses the memberwise one,
// so each builder mutates a var. One function per language keeps every function
// under the complexity and length limits a single switch would blow past.
// =============================================================================

extension ReportLabels {

    /// The languages the report can render: the `init(language:)` switch cases below,
    /// plus English. Keep in sync with those cases (and tools/check-l10n-parity.py).
    static let supportedLanguages = [
        "en", "de", "da", "nl", "nb", "sv", "es", "fr", "it", "pt", "pt-BR",
        "ro", "cs", "pl", "ru", "uk", "el", "ja", "ko", "zh-Hans", "zh-Hant",
    ]

    /// The report-label tag for a UI language setting. A concrete supported tag is
    /// returned unchanged. The empty string is the app's "System" choice: like the
    /// screens (localized through the system locale, see `Loc.locale(for:)`), the
    /// report then follows the device's preferred languages instead of defaulting to
    /// English — otherwise a System user, or a per-locale screenshot run, gets
    /// localized screens but an English report. `preferredLocalizations` returns a
    /// member of `supportedLanguages`, so the result always hits a case or English.
    static func reportTag(for language: String) -> String {
        guard language.isEmpty else { return language }
        return Bundle.preferredLocalizations(
            from: supportedLanguages, forPreferences: Locale.preferredLanguages
        ).first ?? "en"
    }

    /// Returns the report labels for a UI language setting. A concrete supported tag
    /// (e.g. `de`, `zh-Hans`) is used directly; the empty "System" choice resolves via
    /// `reportTag(for:)` to the device's language, so the report follows the system
    /// language like the screens do. An unsupported non-empty tag keeps English.
    public init(language: String) {
        self.init()   // English defaults; a known tag overwrites them
        switch Self.reportTag(for: language) {
        case "de": applyde()
        case "da": applyda()
        case "nl": applynl()
        case "nb": applynb()
        case "sv": applysv()
        case "es": applyes()
        case "fr": applyfr()
        case "it": applyit()
        case "pt": applypt()
        case "pt-BR": applyptBR()
        case "ro": applyro()
        case "cs": applycs()
        case "pl": applypl()
        case "ru": applyru()
        case "uk": applyuk()
        case "el": applyel()
        case "ja": applyja()
        case "ko": applyko()
        case "zh-Hans": applyzhHans()
        case "zh-Hant": applyzhHant()
        default: break   // keep the English defaults
        }
    }

    private mutating func applyde() {
        self.title = "Konsumbericht Alkohol"
        self.footer1 =
            "Eigenprotokollierte Schätzwerte – keine ärztliche Diagnose! Nicht für " +
            "Fahreignungsbewertung und Diagnosezwecke!"
        self.sectionKpis = "Kerndaten"
        self.sectionMonths = "Monatsübersicht"
        self.sectionTrend = "Langfristiger Trend (Ø Gramm/Tag)"
        self.sectionCategories = "Konsummuster: Getränkekategorien"
        self.sectionDaytime = "Konsummuster: Tageszeit (Ø Gramm Alkohol)"
        self.sectionWeekday = "Konsummuster: Wochentag (Ø Gramm Alkohol)"
        self.sectionRisk = "Risikokonsum & Abstinenz"
        self.metaExportDate = "Exportdatum"
        self.metaPeriod = "Zeitraum"
        self.metaLimit = "Limits"
        self.metaWeight = "Körpergewicht"
        self.metaLongestAbstinence = "Längste Abstinenzphase"
        self.metaCurrentAbstinence = "Aktuelle Abstinenz"
        self.unitGramsPerDay = "g/Tag"
        self.unitGramsPerWeek = "g/7 Tage"
        self.unitDrinkDaysPerWeek = "Trinktage/7 Tage"
        self.kpiTotal = "Gesamtalkohol"
        self.kpiAvgPerDay = "Ø pro Tag"
        self.kpiAvgPerDrinkDay = "Ø pro Trinktag"
        self.kpiMedianPerDay = "Median pro Tag"
        self.kpiMedianPerDrinkDay = "Median pro Trinktag"
        self.kpiDrinkDays = "Trinktage"
        self.kpiAbstinentDays = "Abstinenztage"
        self.kpiMaxPerDay = "Max. pro Tag"
        self.kpiMaxPer7Days = "Max. pro 7 Tage"
        self.kpiAvgDrinkDaysPerMonth = "Ø Trinktage/Monat"
        self.kpiMedianDrinkDaysPerMonth = "Median Trinktage/Monat"
        self.columnMonth = "Monat"
        self.columnDrinkDays = "Trinktage"
        self.columnTotalGrams = "Gesamt g"
        self.columnAvgPerDay = "Ø g/Tag"
        self.columnOverDaily = "> Tag"
        self.categoryHeading = "Kategorie"
        self.kpiBinge = { "Rauschtage (> \($0) g)" }
        self.riskBingeDays = { "Rauschtage (> \($0) g)" }
        self.kpiOverDaily = { "Tage > \($0) g/Tag" }
        self.kpiOverWeekly = { "Tage > \($0) g/7 Tage" }
        self.kpiOverDrinkDays = { "Tage > \($0)/7 Trinktage" }
        self.category = { name in
            switch name {
            case "BEER": return "Bier"
            case "WINE": return "Wein / Sekt"
            case "SPIRITS": return "Spirituosen"
            case "LONGDRINK": return "Longdrink / Mix"
            case "LIQUEUR": return "Likör"
            default: return "Sonstiges"
            }
        }
    }

    private mutating func applyda() {
        self.title = "Alkohol-oversigt"
        self.footer1 =
            "Skøn – ikke en lægelig diagnose. Ikke til vurdering af køreegnethed eller " +
            "diagnostik."
        self.sectionKpis = "Nøgletal"
        self.sectionMonths = "Månedsoversigt"
        self.sectionTrend = "Langsigtet tendens (gns. g/dag)"
        self.sectionCategories = "Drikkekategorier"
        self.sectionDaytime = "Forbrugsmønster: tidspunkt"
        self.sectionWeekday = "Ugedagsprofil (gns. g alkohol)"
        self.sectionRisk = "Risikoforbrug & Afholdenhed"
        self.metaExportDate = "Eksportdato"
        self.metaPeriod = "Periode"
        self.metaLimit = "Grænser"
        self.metaWeight = "Legemsvægt"
        self.metaLongestAbstinence = "Længste afholdenhed"
        self.metaCurrentAbstinence = "Aktuel afholdenhed"
        self.unitGramsPerDay = "g/dag"
        self.unitGramsPerWeek = "g/7 dage"
        self.unitDrinkDaysPerWeek = "drikkedage/uge"
        self.kpiTotal = "Total alkohol"
        self.kpiAvgPerDay = "Gns. pr. dag"
        self.kpiAvgPerDrinkDay = "Gns. pr. drikkedag"
        self.kpiMedianPerDay = "Median pr. dag"
        self.kpiMedianPerDrinkDay = "Median pr. drikkedag"
        self.kpiDrinkDays = "Drikkedage"
        self.kpiAbstinentDays = "Afholdsdage"
        self.kpiMaxPerDay = "Maks. pr. dag"
        self.kpiMaxPer7Days = "Maks. pr. 7 dage"
        self.kpiAvgDrinkDaysPerMonth = "Gns. drikkedage/måned"
        self.kpiMedianDrinkDaysPerMonth = "Median drikkedage/måned"
        self.columnMonth = "Måned"
        self.columnDrinkDays = "Drikkedage"
        self.columnTotalGrams = "Total g"
        self.columnAvgPerDay = "Gns. g/dag"
        self.columnOverDaily = "> dag"
        self.categoryHeading = "Kategori"
        self.kpiBinge = { "Binge-dage (>\($0) g)" }
        self.riskBingeDays = { "Binge-dage (>\($0) g)" }
        self.kpiOverDaily = { "Dage > dag (\($0) g)" }
        self.kpiOverWeekly = { "Dage > 7 dage (\($0) g)" }
        self.kpiOverDrinkDays = { "Dage > \($0) drikkedage" }
        self.category = { name in
            switch name {
            case "BEER": return "Øl"
            case "WINE": return "Vin / Mousserende"
            case "SPIRITS": return "Spiritus"
            case "LONGDRINK": return "Longdrink / Mix"
            case "LIQUEUR": return "Likør"
            default: return "Andet"
            }
        }
    }

    private mutating func applynl() {
        self.title = "Alcohol-overzicht"
        self.footer1 =
            "Schattingen – geen medische diagnose. Niet voor beoordeling van rijgeschiktheid of " +
            "diagnostiek."
        self.sectionKpis = "Kerncijfers"
        self.sectionMonths = "Maandoverzicht"
        self.sectionTrend = "Langetermijntrend (gem. g/dag)"
        self.sectionCategories = "Drankcategorieën"
        self.sectionDaytime = "Consumptiepatroon: tijdstip"
        self.sectionWeekday = "Weekdagprofiel (gem. g alcohol)"
        self.sectionRisk = "Risicoverbruik & Onthouding"
        self.metaExportDate = "Exportdatum"
        self.metaPeriod = "Periode"
        self.metaLimit = "Limieten"
        self.metaWeight = "Lichaamsgewicht"
        self.metaLongestAbstinence = "Langste onthouding"
        self.metaCurrentAbstinence = "Huidige onthouding"
        self.unitGramsPerDay = "g/dag"
        self.unitGramsPerWeek = "g/7 dagen"
        self.unitDrinkDaysPerWeek = "drinkdagen/wk"
        self.kpiTotal = "Totaal alcohol"
        self.kpiAvgPerDay = "Gem. per dag"
        self.kpiAvgPerDrinkDay = "Gem. per drinkdag"
        self.kpiMedianPerDay = "Mediaan per dag"
        self.kpiMedianPerDrinkDay = "Mediaan per drinkdag"
        self.kpiDrinkDays = "Drinkdagen"
        self.kpiAbstinentDays = "Onthoudingsdagen"
        self.kpiMaxPerDay = "Max. per dag"
        self.kpiMaxPer7Days = "Max. per 7 dagen"
        self.kpiAvgDrinkDaysPerMonth = "Gem. drinkdagen/maand"
        self.kpiMedianDrinkDaysPerMonth = "Mediaan drinkdagen/maand"
        self.columnMonth = "Maand"
        self.columnDrinkDays = "Drinkdagen"
        self.columnTotalGrams = "Totaal g"
        self.columnAvgPerDay = "Gem. g/dag"
        self.columnOverDaily = "> dag"
        self.categoryHeading = "Categorie"
        self.kpiBinge = { "Bingedagen (>\($0) g)" }
        self.riskBingeDays = { "Bingedagen (>\($0) g)" }
        self.kpiOverDaily = { "Dagen > dag (\($0) g)" }
        self.kpiOverWeekly = { "Dagen > 7 dagen (\($0) g)" }
        self.kpiOverDrinkDays = { "Dagen > \($0) drinkdagen" }
        self.category = { name in
            switch name {
            case "BEER": return "Bier"
            case "WINE": return "Wijn / Bubbels"
            case "SPIRITS": return "Sterke drank"
            case "LONGDRINK": return "Longdrink / Mix"
            case "LIQUEUR": return "Likeur"
            default: return "Overig"
            }
        }
    }

    private mutating func applynb() {
        self.title = "Alkoholsammendrag"
        self.footer1 =
            "Anslag – ikke en medisinsk diagnose. Ikke for vurdering av kjøreegnethet eller " +
            "diagnostikk."
        self.sectionKpis = "Nøkkeltall"
        self.sectionMonths = "Månedlig oversikt"
        self.sectionTrend = "Langsiktig trend (gj.snitt g/dag)"
        self.sectionCategories = "Drikkekategorier"
        self.sectionDaytime = "Konsummønster: Tid på dagen"
        self.sectionWeekday = "Ukedagsprofil (gj.snitt g alkohol)"
        self.sectionRisk = "Risikoforbruk & avholdenhet"
        self.metaExportDate = "Eksportdato"
        self.metaPeriod = "Periode"
        self.metaLimit = "Grenser"
        self.metaWeight = "Kroppsvekt"
        self.metaLongestAbstinence = "Lengste avholdsperiode"
        self.metaCurrentAbstinence = "Nåværende avholdenhet"
        self.unitGramsPerDay = "g/dag"
        self.unitGramsPerWeek = "g/7 dager"
        self.unitDrinkDaysPerWeek = "drikkedager/uke"
        self.kpiTotal = "Total alkohol"
        self.kpiAvgPerDay = "Gj.snitt per dag"
        self.kpiAvgPerDrinkDay = "Gj.snitt per drikkedag"
        self.kpiMedianPerDay = "Median per dag"
        self.kpiMedianPerDrinkDay = "Median per drikkedag"
        self.kpiDrinkDays = "Drikkdager"
        self.kpiAbstinentDays = "Avholdsdager"
        self.kpiMaxPerDay = "Maks. per dag"
        self.kpiMaxPer7Days = "Maks. per 7 dager"
        self.kpiAvgDrinkDaysPerMonth = "Gj.snitt drikkdager/måned"
        self.kpiMedianDrinkDaysPerMonth = "Median drikkdager/måned"
        self.columnMonth = "Måned"
        self.columnDrinkDays = "Drikkdager"
        self.columnTotalGrams = "Total g"
        self.columnAvgPerDay = "Gj.snitt g/dag"
        self.columnOverDaily = "> dag"
        self.categoryHeading = "Kategori"
        self.kpiBinge = { "Binge-dager (>\($0) g)" }
        self.riskBingeDays = { "Episodisk stordrikking-dager (>\($0) g)" }
        self.kpiOverDaily = { "Dager > dag (\($0) g)" }
        self.kpiOverWeekly = { "Dager > 7 dager (\($0) g)" }
        self.kpiOverDrinkDays = { "Dager > \($0) drikkedager" }
        self.category = { name in
            switch name {
            case "BEER": return "Øl"
            case "WINE": return "Vin / Musserende"
            case "SPIRITS": return "Brennevin"
            case "LONGDRINK": return "Longdrink / Mix"
            case "LIQUEUR": return "Likør"
            default: return "Annet"
            }
        }
    }

    private mutating func applysv() {
        self.title = "Alkoholsammanfattning"
        self.footer1 =
            "Uppskattningar – inte en medicinsk diagnos. Inte för bedömning av körlämplighet " +
            "eller diagnostik."
        self.sectionKpis = "Nyckeltal"
        self.sectionMonths = "Månadsöversikt"
        self.sectionTrend = "Långsiktig trend (snitt g/dag)"
        self.sectionCategories = "Dryckkategorier"
        self.sectionDaytime = "Konsumtionsmönster: tid på dygnet"
        self.sectionWeekday = "Veckodagsprofil (snitt g alkohol)"
        self.sectionRisk = "Riskkonsumtion & Nykterhet"
        self.metaExportDate = "Exportdatum"
        self.metaPeriod = "Period"
        self.metaLimit = "Gränser"
        self.metaWeight = "Kroppsvikt"
        self.metaLongestAbstinence = "Längsta nykterhet"
        self.metaCurrentAbstinence = "Aktuell nykterhet"
        self.unitGramsPerDay = "g/dag"
        self.unitGramsPerWeek = "g/7 dagar"
        self.unitDrinkDaysPerWeek = "dryckesdagar/v"
        self.kpiTotal = "Total alkohol"
        self.kpiAvgPerDay = "Snitt per dag"
        self.kpiAvgPerDrinkDay = "Snitt per drickdag"
        self.kpiMedianPerDay = "Median per dag"
        self.kpiMedianPerDrinkDay = "Median per drickdag"
        self.kpiDrinkDays = "Drickdagar"
        self.kpiAbstinentDays = "Nyktra dagar"
        self.kpiMaxPerDay = "Max per dag"
        self.kpiMaxPer7Days = "Max per 7 dagar"
        self.kpiAvgDrinkDaysPerMonth = "Snitt drickdagar/månad"
        self.kpiMedianDrinkDaysPerMonth = "Median drickdagar/månad"
        self.columnMonth = "Månad"
        self.columnDrinkDays = "Drickdagar"
        self.columnTotalGrams = "Totalt g"
        self.columnAvgPerDay = "Snitt g/dag"
        self.columnOverDaily = "> dag"
        self.categoryHeading = "Kategori"
        self.kpiBinge = { "Bingedagar (>\($0) g)" }
        self.riskBingeDays = { "Bingedagar (>\($0) g)" }
        self.kpiOverDaily = { "Dagar > dag (\($0) g)" }
        self.kpiOverWeekly = { "Dagar > 7 dagar (\($0) g)" }
        self.kpiOverDrinkDays = { "Dagar > \($0) dryckesdagar" }
        self.category = { name in
            switch name {
            case "BEER": return "Öl"
            case "WINE": return "Vin / Mousserande"
            case "SPIRITS": return "Sprit"
            case "LONGDRINK": return "Longdrink / Mix"
            case "LIQUEUR": return "Likör"
            default: return "Övrigt"
            }
        }
    }

    private mutating func applyes() {
        self.title = "Resumen de alcohol"
        self.footer1 =
            "Estimaciones, no un diagnóstico médico. No sirve para evaluar la aptitud para " +
            "conducir ni con fines diagnósticos."
        self.sectionKpis = "Cifras clave"
        self.sectionMonths = "Resumen mensual"
        self.sectionTrend = "Tendencia a largo plazo (prom. g/día)"
        self.sectionCategories = "Categorías de bebidas"
        self.sectionDaytime = "Patrón de consumo: hora del día"
        self.sectionWeekday = "Perfil semanal (prom. g alcohol)"
        self.sectionRisk = "Consumo de riesgo & abstinencia"
        self.metaExportDate = "Fecha exportación"
        self.metaPeriod = "Período"
        self.metaLimit = "Límites"
        self.metaWeight = "Peso corporal"
        self.metaLongestAbstinence = "Mayor abstinencia"
        self.metaCurrentAbstinence = "Abstinencia actual"
        self.unitGramsPerDay = "g/día"
        self.unitGramsPerWeek = "g/7 días"
        self.unitDrinkDaysPerWeek = "días de consumo/sem."
        self.kpiTotal = "Alcohol total"
        self.kpiAvgPerDay = "Prom. por día"
        self.kpiAvgPerDrinkDay = "Prom. por día de consumo"
        self.kpiMedianPerDay = "Mediana por día"
        self.kpiMedianPerDrinkDay = "Mediana por día de consumo"
        self.kpiDrinkDays = "Días de consumo"
        self.kpiAbstinentDays = "Días de abstinencia"
        self.kpiMaxPerDay = "Máx. por día"
        self.kpiMaxPer7Days = "Máx. en 7 días"
        self.kpiAvgDrinkDaysPerMonth = "Prom. días de consumo/mes"
        self.kpiMedianDrinkDaysPerMonth = "Mediana días de consumo/mes"
        self.columnMonth = "Mes"
        self.columnDrinkDays = "Días de consumo"
        self.columnTotalGrams = "Total g"
        self.columnAvgPerDay = "Prom. g/día"
        self.columnOverDaily = "> día"
        self.categoryHeading = "Categoría"
        self.kpiBinge = { "Días binge (>\($0) g)" }
        self.riskBingeDays = { "Días binge (>\($0) g)" }
        self.kpiOverDaily = { "Días > diario (\($0) g)" }
        self.kpiOverWeekly = { "Días > 7 días (\($0) g)" }
        self.kpiOverDrinkDays = { "Días > \($0) días consumo" }
        self.category = { name in
            switch name {
            case "BEER": return "Cerveza"
            case "WINE": return "Vino / Espumoso"
            case "SPIRITS": return "Licores"
            case "LONGDRINK": return "Combinado / Mix"
            case "LIQUEUR": return "Licor"
            default: return "Otros"
            }
        }
    }

    private mutating func applyfr() {
        self.title = "Résumé alcool"
        self.footer1 =
            "Estimations – pas un diagnostic médical. Ne convient pas à l'évaluation de " +
            "l'aptitude à la conduite ni au diagnostic."
        self.sectionKpis = "Chiffres clés"
        self.sectionMonths = "Aperçu mensuel"
        self.sectionTrend = "Tendance long terme (moy. g/jour)"
        self.sectionCategories = "Catégories de boissons"
        self.sectionDaytime = "Profil horaire de consommation"
        self.sectionWeekday = "Profil hebdomadaire (moy. g alcool)"
        self.sectionRisk = "Consommation à risque & abstinence"
        self.metaExportDate = "Date d'export"
        self.metaPeriod = "Période"
        self.metaLimit = "Limites"
        self.metaWeight = "Poids corporel"
        self.metaLongestAbstinence = "Plus longue abstinence"
        self.metaCurrentAbstinence = "Abstinence actuelle"
        self.unitGramsPerDay = "g/jour"
        self.unitGramsPerWeek = "g/7 j"
        self.unitDrinkDaysPerWeek = "jours de conso./sem."
        self.kpiTotal = "Alcool total"
        self.kpiAvgPerDay = "Moy. par jour"
        self.kpiAvgPerDrinkDay = "Moy. par jour de conso."
        self.kpiMedianPerDay = "Médiane par jour"
        self.kpiMedianPerDrinkDay = "Médiane par jour de conso."
        self.kpiDrinkDays = "Jours de conso."
        self.kpiAbstinentDays = "Jours d'abstinence"
        self.kpiMaxPerDay = "Max. par jour"
        self.kpiMaxPer7Days = "Max. sur 7 jours"
        self.kpiAvgDrinkDaysPerMonth = "Moy. jours de conso./mois"
        self.kpiMedianDrinkDaysPerMonth = "Médiane jours de conso./mois"
        self.columnMonth = "Mois"
        self.columnDrinkDays = "Jours de conso."
        self.columnTotalGrams = "Total g"
        self.columnAvgPerDay = "Moy. g/jour"
        self.columnOverDaily = "> jour"
        self.categoryHeading = "Catégorie"
        self.kpiBinge = { "Jours binge (>\($0) g)" }
        self.riskBingeDays = { "Jours binge (>\($0) g)" }
        self.kpiOverDaily = { "Jours > jour (\($0) g)" }
        self.kpiOverWeekly = { "Jours > 7 j (\($0) g)" }
        self.kpiOverDrinkDays = { "Jours > \($0) jours conso." }
        self.category = { name in
            switch name {
            case "BEER": return "Bière"
            case "WINE": return "Vin / Mousseux"
            case "SPIRITS": return "Spiritueux"
            case "LONGDRINK": return "Long drink / Mix"
            case "LIQUEUR": return "Liqueur"
            default: return "Autre"
            }
        }
    }

    private mutating func applyit() {
        self.title = "Riepilogo alcol"
        self.footer1 =
            "Stime – non una diagnosi medica. Non per la valutazione dell'idoneità alla guida né " +
            "per scopi diagnostici."
        self.sectionKpis = "Dati chiave"
        self.sectionMonths = "Panoramica mensile"
        self.sectionTrend = "Tendenza a lungo termine (media g/giorno)"
        self.sectionCategories = "Categorie bevande"
        self.sectionDaytime = "Schema di consumo: orario"
        self.sectionWeekday = "Profilo giorno della settimana (media g alcol)"
        self.sectionRisk = "Consumo a rischio & Astinenza"
        self.metaExportDate = "Data esportazione"
        self.metaPeriod = "Periodo"
        self.metaLimit = "Limiti"
        self.metaWeight = "Peso corporeo"
        self.metaLongestAbstinence = "Periodo di astinenza più lungo"
        self.metaCurrentAbstinence = "Astinenza attuale"
        self.unitGramsPerDay = "g/giorno"
        self.unitGramsPerWeek = "g/7 gg"
        self.unitDrinkDaysPerWeek = "giorni di consumo/sett."
        self.kpiTotal = "Alcol totale"
        self.kpiAvgPerDay = "Media al giorno"
        self.kpiAvgPerDrinkDay = "Media per giorno di consumo"
        self.kpiMedianPerDay = "Mediana al giorno"
        self.kpiMedianPerDrinkDay = "Mediana per giorno di consumo"
        self.kpiDrinkDays = "Giorni di consumo"
        self.kpiAbstinentDays = "Giorni di astinenza"
        self.kpiMaxPerDay = "Max al giorno"
        self.kpiMaxPer7Days = "Max su 7 giorni"
        self.kpiAvgDrinkDaysPerMonth = "Media giorni di consumo/mese"
        self.kpiMedianDrinkDaysPerMonth = "Mediana giorni di consumo/mese"
        self.columnMonth = "Mese"
        self.columnDrinkDays = "Giorni di consumo"
        self.columnTotalGrams = "Totale g"
        self.columnAvgPerDay = "Media g/giorno"
        self.columnOverDaily = "> giorno"
        self.categoryHeading = "Categoria"
        self.kpiBinge = { "Giorni binge (>\($0) g)" }
        self.riskBingeDays = { "Giorni binge (>\($0) g)" }
        self.kpiOverDaily = { "Giorni > giorno (\($0) g)" }
        self.kpiOverWeekly = { "Giorni > 7 gg (\($0) g)" }
        self.kpiOverDrinkDays = { "Giorni > \($0) giorni consumo" }
        self.category = { name in
            switch name {
            case "BEER": return "Birra"
            case "WINE": return "Vino / Spumante"
            case "SPIRITS": return "Superalcolici"
            case "LONGDRINK": return "Longdrink / Mix"
            case "LIQUEUR": return "Liquore"
            default: return "Altro"
            }
        }
    }

    private mutating func applypt() {
        self.title = "Resumo de álcool"
        self.footer1 =
            "Estimativas – não é um diagnóstico médico. Não serve para avaliação de aptidão para " +
            "conduzir nem para fins de diagnóstico."
        self.sectionKpis = "Dados principais"
        self.sectionMonths = "Visão geral mensal"
        self.sectionTrend = "Tendência a longo prazo (média g/dia)"
        self.sectionCategories = "Categorias de bebidas"
        self.sectionDaytime = "Padrão de consumo: hora do dia"
        self.sectionWeekday = "Perfil por dia da semana (média g de álcool)"
        self.sectionRisk = "Consumo de risco & Abstinência"
        self.metaExportDate = "Data de exportação"
        self.metaPeriod = "Período"
        self.metaLimit = "Limites"
        self.metaWeight = "Peso corporal"
        self.metaLongestAbstinence = "Maior período de abstinência"
        self.metaCurrentAbstinence = "Abstinência atual"
        self.unitGramsPerDay = "g/dia"
        self.unitGramsPerWeek = "g/7 dias"
        self.unitDrinkDaysPerWeek = "dias de consumo/sem."
        self.kpiTotal = "Álcool total"
        self.kpiAvgPerDay = "Média por dia"
        self.kpiAvgPerDrinkDay = "Média por dia de consumo"
        self.kpiMedianPerDay = "Mediana por dia"
        self.kpiMedianPerDrinkDay = "Mediana por dia de consumo"
        self.kpiDrinkDays = "Dias de consumo"
        self.kpiAbstinentDays = "Dias de abstinência"
        self.kpiMaxPerDay = "Máx. por dia"
        self.kpiMaxPer7Days = "Máx. em 7 dias"
        self.kpiAvgDrinkDaysPerMonth = "Média dias de consumo/mês"
        self.kpiMedianDrinkDaysPerMonth = "Mediana dias de consumo/mês"
        self.columnMonth = "Mês"
        self.columnDrinkDays = "Dias de consumo"
        self.columnTotalGrams = "Total g"
        self.columnAvgPerDay = "Média g/dia"
        self.columnOverDaily = "> dia"
        self.categoryHeading = "Categoria"
        self.kpiBinge = { "Dias de binge (>\($0) g)" }
        self.riskBingeDays = { "Dias de binge (>\($0) g)" }
        self.kpiOverDaily = { "Dias > dia (\($0) g)" }
        self.kpiOverWeekly = { "Dias > 7 dias (\($0) g)" }
        self.kpiOverDrinkDays = { "Dias > \($0) dias consumo" }
        self.category = { name in
            switch name {
            case "BEER": return "Cerveja"
            case "WINE": return "Vinho / Espumante"
            case "SPIRITS": return "Bebidas espirituosas"
            case "LONGDRINK": return "Longdrink / Mix"
            case "LIQUEUR": return "Licor"
            default: return "Outro"
            }
        }
    }

    private mutating func applyptBR() {
        self.title = "Resumo de álcool"
        self.footer1 =
            "Estimativas – não é um diagnóstico médico. Não serve para avaliação de aptidão para " +
            "dirigir nem para fins de diagnóstico."
        self.sectionKpis = "Dados principais"
        self.sectionMonths = "Visão geral mensal"
        self.sectionTrend = "Tendência de longo prazo (média g/dia)"
        self.sectionCategories = "Categorias de bebidas"
        self.sectionDaytime = "Padrão de consumo: horário do dia"
        self.sectionWeekday = "Perfil por dia da semana (média g de álcool)"
        self.sectionRisk = "Consumo de risco & Abstinência"
        self.metaExportDate = "Data de exportação"
        self.metaPeriod = "Período"
        self.metaLimit = "Limites"
        self.metaWeight = "Peso corporal"
        self.metaLongestAbstinence = "Maior período de abstinência"
        self.metaCurrentAbstinence = "Abstinência atual"
        self.unitGramsPerDay = "g/dia"
        self.unitGramsPerWeek = "g/7 dias"
        self.unitDrinkDaysPerWeek = "dias de consumo/sem."
        self.kpiTotal = "Álcool total"
        self.kpiAvgPerDay = "Média por dia"
        self.kpiAvgPerDrinkDay = "Média por dia de consumo"
        self.kpiMedianPerDay = "Mediana por dia"
        self.kpiMedianPerDrinkDay = "Mediana por dia de consumo"
        self.kpiDrinkDays = "Dias de consumo"
        self.kpiAbstinentDays = "Dias de abstinência"
        self.kpiMaxPerDay = "Máx. por dia"
        self.kpiMaxPer7Days = "Máx. em 7 dias"
        self.kpiAvgDrinkDaysPerMonth = "Média dias de consumo/mês"
        self.kpiMedianDrinkDaysPerMonth = "Mediana dias de consumo/mês"
        self.columnMonth = "Mês"
        self.columnDrinkDays = "Dias de consumo"
        self.columnTotalGrams = "Total g"
        self.columnAvgPerDay = "Média g/dia"
        self.columnOverDaily = "> dia"
        self.categoryHeading = "Categoria"
        self.kpiBinge = { "Dias de binge (>\($0) g)" }
        self.riskBingeDays = { "Dias de binge (>\($0) g)" }
        self.kpiOverDaily = { "Dias > dia (\($0) g)" }
        self.kpiOverWeekly = { "Dias > 7 dias (\($0) g)" }
        self.kpiOverDrinkDays = { "Dias > \($0) dias consumo" }
        self.category = { name in
            switch name {
            case "BEER": return "Cerveja"
            case "WINE": return "Vinho / Espumante"
            case "SPIRITS": return "Destilados"
            case "LONGDRINK": return "Longdrink / Mix"
            case "LIQUEUR": return "Licor"
            default: return "Outros"
            }
        }
    }

    private mutating func applyro() {
        self.title = "Rezumat alcool"
        self.footer1 =
            "Estimări – nu reprezintă un diagnostic medical. Nu se foloseşte pentru evaluarea " +
            "aptitudinii de a conduce sau în scop diagnostic."
        self.sectionKpis = "Cifre cheie"
        self.sectionMonths = "Prezentare lunară"
        self.sectionTrend = "Tendință pe termen lung (medie g/zi)"
        self.sectionCategories = "Categorii băuturi"
        self.sectionDaytime = "Model de consum: ora zilei"
        self.sectionWeekday = "Profil zile săptămână (medie g alcool)"
        self.sectionRisk = "Consum de risc și abstinență"
        self.metaExportDate = "Data export"
        self.metaPeriod = "Perioadă"
        self.metaLimit = "Limite"
        self.metaWeight = "Greutate corporală"
        self.metaLongestAbstinence = "Cea mai lungă perioadă de abstinență"
        self.metaCurrentAbstinence = "Abstinență curentă"
        self.unitGramsPerDay = "g/zi"
        self.unitGramsPerWeek = "g/7 zile"
        self.unitDrinkDaysPerWeek = "zile de consum/săpt."
        self.kpiTotal = "Alcool total"
        self.kpiAvgPerDay = "Medie pe zi"
        self.kpiAvgPerDrinkDay = "Medie pe zi de băut"
        self.kpiMedianPerDay = "Mediană pe zi"
        self.kpiMedianPerDrinkDay = "Mediană pe zi de băut"
        self.kpiDrinkDays = "Zile de băut"
        self.kpiAbstinentDays = "Zile de abstinență"
        self.kpiMaxPerDay = "Max. pe zi"
        self.kpiMaxPer7Days = "Max. în 7 zile"
        self.kpiAvgDrinkDaysPerMonth = "Medie zile de băut/lună"
        self.kpiMedianDrinkDaysPerMonth = "Mediană zile de băut/lună"
        self.columnMonth = "Lună"
        self.columnDrinkDays = "Zile de băut"
        self.columnTotalGrams = "Total g"
        self.columnAvgPerDay = "Medie g/zi"
        self.columnOverDaily = "> zi"
        self.categoryHeading = "Categorie"
        self.kpiBinge = { "Zile binge (>\($0) g)" }
        self.riskBingeDays = { "Zile binge (>\($0) g)" }
        self.kpiOverDaily = { "Zile > zi (\($0) g)" }
        self.kpiOverWeekly = { "Zile > 7 zile (\($0) g)" }
        self.kpiOverDrinkDays = { "Zile > \($0) zile de consum" }
        self.category = { name in
            switch name {
            case "BEER": return "Bere"
            case "WINE": return "Vin / Spumos"
            case "SPIRITS": return "Spirtoase"
            case "LONGDRINK": return "Longdrink / Mix"
            case "LIQUEUR": return "Lichior"
            default: return "Altele"
            }
        }
    }

    private mutating func applycs() {
        self.title = "Přehled alkoholu"
        self.footer1 =
            "Odhady – nejde o lékařskou diagnózu. Nepoužívat k posouzení způsobilosti k řízení " +
            "ani k diagnostice."
        self.sectionKpis = "Klíčové údaje"
        self.sectionMonths = "Měsíční přehled"
        self.sectionTrend = "Dlouhodobý trend (prům. g/den)"
        self.sectionCategories = "Kategorie nápojů"
        self.sectionDaytime = "Vzorec konzumace: denní doba"
        self.sectionWeekday = "Profil dne v týdnu (prům. g alkoholu)"
        self.sectionRisk = "Rizikové pití & Abstinence"
        self.metaExportDate = "Datum exportu"
        self.metaPeriod = "Období"
        self.metaLimit = "Limity"
        self.metaWeight = "Tělesná hmotnost"
        self.metaLongestAbstinence = "Nejdelší abstinence"
        self.metaCurrentAbstinence = "Současná abstinence"
        self.unitGramsPerDay = "g/den"
        self.unitGramsPerWeek = "g/7 dní"
        self.unitDrinkDaysPerWeek = "dny pití/týd."
        self.kpiTotal = "Celkový alkohol"
        self.kpiAvgPerDay = "Prům. za den"
        self.kpiAvgPerDrinkDay = "Prům. za den pití"
        self.kpiMedianPerDay = "Medián za den"
        self.kpiMedianPerDrinkDay = "Medián za den pití"
        self.kpiDrinkDays = "Dny pití"
        self.kpiAbstinentDays = "Dny abstinence"
        self.kpiMaxPerDay = "Max. za den"
        self.kpiMaxPer7Days = "Max. za 7 dní"
        self.kpiAvgDrinkDaysPerMonth = "Prům. dny pití/měs."
        self.kpiMedianDrinkDaysPerMonth = "Medián dny pití/měs."
        self.columnMonth = "Měsíc"
        self.columnDrinkDays = "Dny pití"
        self.columnTotalGrams = "Celkem g"
        self.columnAvgPerDay = "Prům. g/den"
        self.columnOverDaily = "> den"
        self.categoryHeading = "Kategorie"
        self.kpiBinge = { "Dny binge (>\($0) g)" }
        self.riskBingeDays = { "Dny binge (>\($0) g)" }
        self.kpiOverDaily = { "Dny > den (\($0) g)" }
        self.kpiOverWeekly = { "Dny > 7 dní (\($0) g)" }
        self.kpiOverDrinkDays = { "Dny > \($0) dnů pití" }
        self.category = { name in
            switch name {
            case "BEER": return "Pivo"
            case "WINE": return "Víno / Sekt"
            case "SPIRITS": return "Lihoviny"
            case "LONGDRINK": return "Longdrink / Mix"
            case "LIQUEUR": return "Likér"
            default: return "Ostatní"
            }
        }
    }

    private mutating func applypl() {
        self.title = "Podsumowanie alkoholu"
        self.footer1 =
            "Szacunki – nie są diagnozą lekarską. Nie do oceny zdolności do prowadzenia pojazdów " +
            "ani do celów diagnostycznych."
        self.sectionKpis = "Kluczowe dane"
        self.sectionMonths = "Przegląd miesięczny"
        self.sectionTrend = "Długoterminowy trend (śr. g/dzień)"
        self.sectionCategories = "Kategorie napojów"
        self.sectionDaytime = "Wzorzec spożycia: pora dnia"
        self.sectionWeekday = "Profil dnia tygodnia (śr. g alkoholu)"
        self.sectionRisk = "Ryzykowne spożycie & Abstynencja"
        self.metaExportDate = "Data eksportu"
        self.metaPeriod = "Okres"
        self.metaLimit = "Limity"
        self.metaWeight = "Masa ciała"
        self.metaLongestAbstinence = "Najdłuższa abstynencja"
        self.metaCurrentAbstinence = "Bieżąca abstynencja"
        self.unitGramsPerDay = "g/dzień"
        self.unitGramsPerWeek = "g/7 dni"
        self.unitDrinkDaysPerWeek = "dni picia/tydz."
        self.kpiTotal = "Łączny alkohol"
        self.kpiAvgPerDay = "Śr. dziennie"
        self.kpiAvgPerDrinkDay = "Śr. w dzień spożycia"
        self.kpiMedianPerDay = "Mediana dziennie"
        self.kpiMedianPerDrinkDay = "Mediana w dzień spożycia"
        self.kpiDrinkDays = "Dni spożycia"
        self.kpiAbstinentDays = "Dni abstynencji"
        self.kpiMaxPerDay = "Maks. dziennie"
        self.kpiMaxPer7Days = "Maks. w 7 dni"
        self.kpiAvgDrinkDaysPerMonth = "Śr. dni spożycia/mies."
        self.kpiMedianDrinkDaysPerMonth = "Mediana dni spożycia/mies."
        self.columnMonth = "Miesiąc"
        self.columnDrinkDays = "Dni spożycia"
        self.columnTotalGrams = "Łącznie g"
        self.columnAvgPerDay = "Śr. g/dzień"
        self.columnOverDaily = "> dzień"
        self.categoryHeading = "Kategoria"
        self.kpiBinge = { "Dni binge (>\($0) g)" }
        self.riskBingeDays = { "Dni binge (>\($0) g)" }
        self.kpiOverDaily = { "Dni > dzień (\($0) g)" }
        self.kpiOverWeekly = { "Dni > 7 dni (\($0) g)" }
        self.kpiOverDrinkDays = { "Dni > \($0) dni picia" }
        self.category = { name in
            switch name {
            case "BEER": return "Piwo"
            case "WINE": return "Wino / Musujące"
            case "SPIRITS": return "Mocne alkohole"
            case "LONGDRINK": return "Longdrink / Mix"
            case "LIQUEUR": return "Likier"
            default: return "Inne"
            }
        }
    }

    private mutating func applyru() {
        self.title = "Сводка по алкоголю"
        self.footer1 =
            "Оценочные значения — не медицинский диагноз. Не для оценки годности к вождению и не " +
            "для диагностики."
        self.sectionKpis = "Ключевые показатели"
        self.sectionMonths = "Обзор по месяцам"
        self.sectionTrend = "Долгосрочный тренд (ср. г/день)"
        self.sectionCategories = "Категории напитков"
        self.sectionDaytime = "Паттерн потребления: время суток"
        self.sectionWeekday = "Профиль по дням недели (ср. г алкоголя)"
        self.sectionRisk = "Рискованное потребление & Воздержание"
        self.metaExportDate = "Дата экспорта"
        self.metaPeriod = "Период"
        self.metaLimit = "Лимиты"
        self.metaWeight = "Масса тела"
        self.metaLongestAbstinence = "Наибольший период воздержания"
        self.metaCurrentAbstinence = "Текущее воздержание"
        self.unitGramsPerDay = "г/день"
        self.unitGramsPerWeek = "г/7 дней"
        self.unitDrinkDaysPerWeek = "питейных дней/нед."
        self.kpiTotal = "Всего алкоголя"
        self.kpiAvgPerDay = "Ср. в день"
        self.kpiAvgPerDrinkDay = "Ср. в день потребления"
        self.kpiMedianPerDay = "Медиана в день"
        self.kpiMedianPerDrinkDay = "Медиана в день потребления"
        self.kpiDrinkDays = "Дней с алкоголем"
        self.kpiAbstinentDays = "Дней без алкоголя"
        self.kpiMaxPerDay = "Макс. в день"
        self.kpiMaxPer7Days = "Макс. за 7 дней"
        self.kpiAvgDrinkDaysPerMonth = "Ср. дней с алкоголем/мес."
        self.kpiMedianDrinkDaysPerMonth = "Медиана дней с алкоголем/мес."
        self.columnMonth = "Месяц"
        self.columnDrinkDays = "Дней с алкоголем"
        self.columnTotalGrams = "Всего г"
        self.columnAvgPerDay = "Ср. г/день"
        self.columnOverDaily = "> день"
        self.categoryHeading = "Категория"
        self.kpiBinge = { "Дней бинджа (>\($0) г)" }
        self.riskBingeDays = { "Дней бинджа (>\($0) г)" }
        self.kpiOverDaily = { "Дней > день (\($0) г)" }
        self.kpiOverWeekly = { "Дней > 7 дней (\($0) г)" }
        self.kpiOverDrinkDays = { "Дней > \($0) питейных дней" }
        self.category = { name in
            switch name {
            case "BEER": return "Пиво"
            case "WINE": return "Вино / Игристое"
            case "SPIRITS": return "Крепкие напитки"
            case "LONGDRINK": return "Лонгдринк / Микс"
            case "LIQUEUR": return "Ликёр"
            default: return "Прочее"
            }
        }
    }

    private mutating func applyuk() {
        self.title = "Підсумок алкоголю"
        self.footer1 =
            "Оцінкові значення — не медичний діагноз. Не для оцінювання придатності до керування " +
            "транспортом і не для діагностики."
        self.sectionKpis = "Ключові показники"
        self.sectionMonths = "Місячний огляд"
        self.sectionTrend = "Довгостроковий тренд (сер. г/день)"
        self.sectionCategories = "Категорії напоїв"
        self.sectionDaytime = "Модель споживання: час доби"
        self.sectionWeekday = "Профіль за днями тижня (сер. г алкоголю)"
        self.sectionRisk = "Ризикове споживання & Утримання"
        self.metaExportDate = "Дата експорту"
        self.metaPeriod = "Період"
        self.metaLimit = "Ліміти"
        self.metaWeight = "Вага тіла"
        self.metaLongestAbstinence = "Найдовше утримання"
        self.metaCurrentAbstinence = "Поточне утримання"
        self.unitGramsPerDay = "г/день"
        self.unitGramsPerWeek = "г/7 днів"
        self.unitDrinkDaysPerWeek = "питних днів/тиж."
        self.kpiTotal = "Загальний алкоголь"
        self.kpiAvgPerDay = "Сер. за день"
        self.kpiAvgPerDrinkDay = "Сер. за день вживання"
        self.kpiMedianPerDay = "Медіана за день"
        self.kpiMedianPerDrinkDay = "Медіана за день вживання"
        self.kpiDrinkDays = "Дні вживання"
        self.kpiAbstinentDays = "Дні утримання"
        self.kpiMaxPerDay = "Макс. за день"
        self.kpiMaxPer7Days = "Макс. за 7 днів"
        self.kpiAvgDrinkDaysPerMonth = "Сер. дні вживання/міс."
        self.kpiMedianDrinkDaysPerMonth = "Медіана дні вживання/міс."
        self.columnMonth = "Місяць"
        self.columnDrinkDays = "Дні вживання"
        self.columnTotalGrams = "Всього г"
        self.columnAvgPerDay = "Сер. г/день"
        self.columnOverDaily = "> день"
        self.categoryHeading = "Категорія"
        self.kpiBinge = { "Дні надмірного вживання (>\($0) г)" }
        self.riskBingeDays = { "Дні надмірного вживання (>\($0) г)" }
        self.kpiOverDaily = { "Днів > день (\($0) г)" }
        self.kpiOverWeekly = { "Днів > 7 днів (\($0) г)" }
        self.kpiOverDrinkDays = { "Днів > \($0) питних днів" }
        self.category = { name in
            switch name {
            case "BEER": return "Пиво"
            case "WINE": return "Вино / Ігристе"
            case "SPIRITS": return "Міцні напої"
            case "LONGDRINK": return "Лонгдринк / Мікс"
            case "LIQUEUR": return "Лікер"
            default: return "Інше"
            }
        }
    }

    private mutating func applyel() {
        self.title = "Σύνοψη αλκοόλης"
        self.footer1 =
            "Εκτιμήσεις – όχι ιατρική διάγνωση. Όχι για αξιολόγηση ικανότητας οδήγησης ή " +
            "διαγνωστικούς σκοπούς."
        self.sectionKpis = "Βασικά στοιχεία"
        self.sectionMonths = "Μηνιαία επισκόπηση"
        self.sectionTrend = "Μακροπρόθεσμη τάση (μέσος g/ημέρα)"
        self.sectionCategories = "Κατηγορίες ποτών"
        self.sectionDaytime = "Πρότυπο κατανάλωσης: ώρα ημέρας"
        self.sectionWeekday = "Προφίλ ημέρας εβδομάδας (μέσος g αλκοόλης)"
        self.sectionRisk = "Επικίνδυνη κατανάλωση & Αποχή"
        self.metaExportDate = "Ημερομηνία εξαγωγής"
        self.metaPeriod = "Περίοδος"
        self.metaLimit = "Όρια"
        self.metaWeight = "Σωματικό βάρος"
        self.metaLongestAbstinence = "Μεγαλύτερη περίοδος αποχής"
        self.metaCurrentAbstinence = "Τρέχουσα αποχή"
        self.unitGramsPerDay = "g/ημέρα"
        self.unitGramsPerWeek = "g/7 ημ."
        self.unitDrinkDaysPerWeek = "ημέρες κατανάλωσης/εβδ."
        self.kpiTotal = "Συνολική αλκοόλη"
        self.kpiAvgPerDay = "Μέσος ανά ημέρα"
        self.kpiAvgPerDrinkDay = "Μέσος ανά ημέρα κατανάλωσης"
        self.kpiMedianPerDay = "Διάμεσος ανά ημέρα"
        self.kpiMedianPerDrinkDay = "Διάμεσος ανά ημέρα κατανάλωσης"
        self.kpiDrinkDays = "Ημέρες κατανάλωσης"
        self.kpiAbstinentDays = "Ημέρες αποχής"
        self.kpiMaxPerDay = "Μέγ. ανά ημέρα"
        self.kpiMaxPer7Days = "Μέγ. σε 7 ημέρες"
        self.kpiAvgDrinkDaysPerMonth = "Μέσος ημέρες κατανάλωσης/μήνα"
        self.kpiMedianDrinkDaysPerMonth = "Διάμεσος ημέρες κατανάλωσης/μήνα"
        self.columnMonth = "Μήνας"
        self.columnDrinkDays = "Ημέρες κατανάλωσης"
        self.columnTotalGrams = "Σύνολο g"
        self.columnAvgPerDay = "Μέσος g/ημέρα"
        self.columnOverDaily = "> ημέρα"
        self.categoryHeading = "Κατηγορία"
        self.kpiBinge = { "Ημέρες binge (>\($0) g)" }
        self.riskBingeDays = { "Ημέρες binge (>\($0) g)" }
        self.kpiOverDaily = { "Ημέρες > ημέρα (\($0) g)" }
        self.kpiOverWeekly = { "Ημέρες > 7 ημ. (\($0) g)" }
        self.kpiOverDrinkDays = { "Ημέρες > \($0) ημέρες κατανάλωσης" }
        self.category = { name in
            switch name {
            case "BEER": return "Μπύρα"
            case "WINE": return "Κρασί / Αφρώδες"
            case "SPIRITS": return "Οινοπνευματώδη"
            case "LONGDRINK": return "Longdrink / Mix"
            case "LIQUEUR": return "Λικέρ"
            default: return "Άλλο"
            }
        }
    }

    private mutating func applyja() {
        self.title = "アルコール摂取まとめ"
        self.footer1 = "推定値であり、医学的診断ではありません。運転適性評価や診断目的には使用できません。"
        self.sectionKpis = "主要データ"
        self.sectionMonths = "月別概要"
        self.sectionTrend = "長期トレンド（平均 g／日）"
        self.sectionCategories = "飲み物カテゴリ"
        self.sectionDaytime = "摂取パターン：時間帯"
        self.sectionWeekday = "曜日別プロフィール（平均 g アルコール）"
        self.sectionRisk = "危険な飲酒 & 断酒"
        self.metaExportDate = "エクスポート日"
        self.metaPeriod = "期間"
        self.metaLimit = "上限"
        self.metaWeight = "体重"
        self.metaLongestAbstinence = "最長断酒期間"
        self.metaCurrentAbstinence = "現在の断酒期間"
        self.unitGramsPerDay = "g／日"
        self.unitGramsPerWeek = "g/7日"
        self.unitDrinkDaysPerWeek = "飲酒日/週"
        self.kpiTotal = "総アルコール量"
        self.kpiAvgPerDay = "1日平均"
        self.kpiAvgPerDrinkDay = "飲酒日平均"
        self.kpiMedianPerDay = "1日中央値"
        self.kpiMedianPerDrinkDay = "飲酒日中央値"
        self.kpiDrinkDays = "飲酒日数"
        self.kpiAbstinentDays = "断酒日数"
        self.kpiMaxPerDay = "1日最大"
        self.kpiMaxPer7Days = "7日間最大"
        self.kpiAvgDrinkDaysPerMonth = "平均 飲酒日数／月"
        self.kpiMedianDrinkDaysPerMonth = "中央値 飲酒日数／月"
        self.columnMonth = "月"
        self.columnDrinkDays = "飲酒日数"
        self.columnTotalGrams = "合計 g"
        self.columnAvgPerDay = "平均 g／日"
        self.columnOverDaily = "> 日"
        self.categoryHeading = "カテゴリ"
        self.kpiBinge = { "過度飲酒日数（>\($0) g）" }
        self.riskBingeDays = { "過度飲酒日数（>\($0) g）" }
        self.kpiOverDaily = { "日 > 日 (\($0) g)" }
        self.kpiOverWeekly = { "日 > 7日 (\($0) g)" }
        self.kpiOverDrinkDays = { "日 > \($0) 飲酒日" }
        self.category = { name in
            switch name {
            case "BEER": return "ビール"
            case "WINE": return "ワイン / スパークリング"
            case "SPIRITS": return "スピリッツ"
            case "LONGDRINK": return "ロングドリンク / ミックス"
            case "LIQUEUR": return "リキュール"
            default: return "その他"
            }
        }
    }

    private mutating func applyko() {
        self.title = "알코올 요약"
        self.footer1 = "추정치이며 의학적 진단이 아닙니다. 운전 적합성 평가나 진단 목적으로 사용할 수 없습니다."
        self.sectionKpis = "핵심 데이터"
        self.sectionMonths = "월별 개요"
        self.sectionTrend = "장기 추세 (평균 g/일)"
        self.sectionCategories = "음료 카테고리"
        self.sectionDaytime = "소비 패턴: 시간대"
        self.sectionWeekday = "요일별 프로필 (평균 g 알코올)"
        self.sectionRisk = "위험 음주 & 금주"
        self.metaExportDate = "내보내기 날짜"
        self.metaPeriod = "기간"
        self.metaLimit = "한도"
        self.metaWeight = "체중"
        self.metaLongestAbstinence = "최장 금주 기간"
        self.metaCurrentAbstinence = "현재 금주 기간"
        self.unitGramsPerDay = "g/일"
        self.unitGramsPerWeek = "g/7일"
        self.unitDrinkDaysPerWeek = "음주일/주"
        self.kpiTotal = "총 알코올"
        self.kpiAvgPerDay = "일 평균"
        self.kpiAvgPerDrinkDay = "음주일 평균"
        self.kpiMedianPerDay = "일 중앙값"
        self.kpiMedianPerDrinkDay = "음주일 중앙값"
        self.kpiDrinkDays = "음주일 수"
        self.kpiAbstinentDays = "금주일 수"
        self.kpiMaxPerDay = "일 최대"
        self.kpiMaxPer7Days = "7일 최대"
        self.kpiAvgDrinkDaysPerMonth = "평균 음주일 수/월"
        self.kpiMedianDrinkDaysPerMonth = "중앙값 음주일 수/월"
        self.columnMonth = "월"
        self.columnDrinkDays = "음주일 수"
        self.columnTotalGrams = "합계 g"
        self.columnAvgPerDay = "평균 g/일"
        self.columnOverDaily = "> 일"
        self.categoryHeading = "카테고리"
        self.kpiBinge = { "과음일 (>\($0) g)" }
        self.riskBingeDays = { "과음일 (>\($0) g)" }
        self.kpiOverDaily = { "일 > 일일 (\($0) g)" }
        self.kpiOverWeekly = { "일 > 7일 (\($0) g)" }
        self.kpiOverDrinkDays = { "일 > \($0) 음주일" }
        self.category = { name in
            switch name {
            case "BEER": return "맥주"
            case "WINE": return "와인 / 스파클링"
            case "SPIRITS": return "증류주"
            case "LONGDRINK": return "롱드링크 / 믹스"
            case "LIQUEUR": return "리큐르"
            default: return "기타"
            }
        }
    }

    private mutating func applyzhHans() {
        self.title = "酒精摘要"
        self.footer1 = "仅为估算值，并非医学诊断。不可用于驾驶适性评估或诊断用途。"
        self.sectionKpis = "核心数据"
        self.sectionMonths = "月度概览"
        self.sectionTrend = "长期趋势（平均克/天）"
        self.sectionCategories = "饮品类别"
        self.sectionDaytime = "消费模式：一天中的时间"
        self.sectionWeekday = "工作日分布（平均克酒精）"
        self.sectionRisk = "风险饮酒 & 戒断"
        self.metaExportDate = "导出日期"
        self.metaPeriod = "时间段"
        self.metaLimit = "限额"
        self.metaWeight = "体重"
        self.metaLongestAbstinence = "最长戒酒期"
        self.metaCurrentAbstinence = "当前戒酒期"
        self.unitGramsPerDay = "克/天"
        self.unitGramsPerWeek = "克/7天"
        self.unitDrinkDaysPerWeek = "饮酒天数/周"
        self.kpiTotal = "总酒精量"
        self.kpiAvgPerDay = "每日平均"
        self.kpiAvgPerDrinkDay = "每饮酒日平均"
        self.kpiMedianPerDay = "每日中位数"
        self.kpiMedianPerDrinkDay = "每饮酒日中位数"
        self.kpiDrinkDays = "饮酒天数"
        self.kpiAbstinentDays = "戒酒天数"
        self.kpiMaxPerDay = "每日最大"
        self.kpiMaxPer7Days = "7天最大"
        self.kpiAvgDrinkDaysPerMonth = "平均饮酒天数/月"
        self.kpiMedianDrinkDaysPerMonth = "中位数饮酒天数/月"
        self.columnMonth = "月份"
        self.columnDrinkDays = "饮酒天数"
        self.columnTotalGrams = "总克数"
        self.columnAvgPerDay = "平均克/天"
        self.columnOverDaily = "> 日"
        self.categoryHeading = "类别"
        self.kpiBinge = { "暴饮天数（>\($0) 克）" }
        self.riskBingeDays = { "暴饮天数（>\($0) 克）" }
        self.kpiOverDaily = { "天 > 日 (\($0) 克)" }
        self.kpiOverWeekly = { "天 > 7天 (\($0) 克)" }
        self.kpiOverDrinkDays = { "天 > \($0) 饮酒天" }
        self.category = { name in
            switch name {
            case "BEER": return "啤酒"
            case "WINE": return "葡萄酒 / 起泡酒"
            case "SPIRITS": return "烈酒"
            case "LONGDRINK": return "长饮 / 混合"
            case "LIQUEUR": return "利口酒"
            default: return "其他"
            }
        }
    }

    private mutating func applyzhHant() {
        self.title = "飲酒摘要"
        self.footer1 = "僅為估算值，並非醫學診斷。不可用於駕駛適性評估或診斷用途。"
        self.sectionKpis = "關鍵數據"
        self.sectionMonths = "每月概覽"
        self.sectionTrend = "長期趨勢（平均 公克／日）"
        self.sectionCategories = "飲品類別"
        self.sectionDaytime = "飲用模式：一天時段"
        self.sectionWeekday = "星期分布（平均 公克 酒精）"
        self.sectionRisk = "高風險飲用 & 戒酒"
        self.metaExportDate = "匯出日期"
        self.metaPeriod = "期間"
        self.metaLimit = "上限"
        self.metaWeight = "體重"
        self.metaLongestAbstinence = "最長戒酒期"
        self.metaCurrentAbstinence = "目前戒酒期"
        self.unitGramsPerDay = "公克／天"
        self.unitGramsPerWeek = "公克/7天"
        self.unitDrinkDaysPerWeek = "飲酒天數/週"
        self.kpiTotal = "總酒精攝取量"
        self.kpiAvgPerDay = "每日平均"
        self.kpiAvgPerDrinkDay = "飲酒日平均"
        self.kpiMedianPerDay = "每日中位數"
        self.kpiMedianPerDrinkDay = "飲酒日中位數"
        self.kpiDrinkDays = "飲酒日數"
        self.kpiAbstinentDays = "戒酒日數"
        self.kpiMaxPerDay = "每日最大"
        self.kpiMaxPer7Days = "7天最大"
        self.kpiAvgDrinkDaysPerMonth = "平均飲酒日數/月"
        self.kpiMedianDrinkDaysPerMonth = "中位數飲酒日數/月"
        self.columnMonth = "月份"
        self.columnDrinkDays = "飲酒日數"
        self.columnTotalGrams = "總計 公克"
        self.columnAvgPerDay = "平均 公克／日"
        self.columnOverDaily = "> 日"
        self.categoryHeading = "類別"
        self.kpiBinge = { "豪飲日數（>\($0) 公克）" }
        self.riskBingeDays = { "豪飲日數（>\($0) 公克）" }
        self.kpiOverDaily = { "天 > 日 (\($0) 公克)" }
        self.kpiOverWeekly = { "天 > 7天 (\($0) 公克)" }
        self.kpiOverDrinkDays = { "天 > \($0) 飲酒天" }
        self.category = { name in
            switch name {
            case "BEER": return "啤酒"
            case "WINE": return "葡萄酒／氣泡酒"
            case "SPIRITS": return "烈酒"
            case "LONGDRINK": return "長飲／調酒"
            case "LIQUEUR": return "利口酒"
            default: return "其他"
            }
        }
    }
}
