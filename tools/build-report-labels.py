#!/usr/bin/env python3
# vim: set et ts=4:
# =============================================================================
# Libellus Potionis - Privacy-Friendly Alcohol Tracker
# Copyright (c) 2026 Martin A. Godisch <android@godisch.de>
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

import html
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "ios/PotillusKit/Sources/PotillusKit/Domain/ReportLabelsCatalog.swift"

# iOS tag -> Android res dir suffix.
DIRS = {
    "en": "", "de": "-de", "da": "-da", "nl": "-nl", "nb": "-nb", "sv": "-sv",
    "es": "-es", "fr": "-fr", "it": "-it", "pt": "-pt", "pt-BR": "-pt-rBR",
    "ro": "-ro", "cs": "-cs", "pl": "-pl", "ru": "-ru", "uk": "-uk", "el": "-el",
    "ja": "-ja", "ko": "-ko", "zh-Hans": "-zh-rCN", "zh-Hant": "-zh-rTW",
}

# ReportLabels scalar field -> Android string key.
FIELDS = {
    "title": "pdf_title", "footer1": "pdf_footer1",
    "sectionKpis": "pdf_section_kpis", "sectionMonths": "pdf_section_months",
    "sectionTrend": "pdf_section_trend", "sectionCategories": "pdf_section_categories",
    "sectionDaytime": "pdf_section_daytime", "sectionWeekday": "pdf_section_weekday",
    "sectionRisk": "pdf_section_risk",
    "metaExportDate": "pdf_meta_export_date", "metaPeriod": "pdf_meta_period",
    "metaLimit": "pdf_meta_limit", "metaWeight": "pdf_meta_weight",
    "metaLongestAbstinence": "pdf_meta_longest_abstinence",
    "metaCurrentAbstinence": "pdf_meta_current_abstinence",
    "unitGramsPerDay": "pdf_unit_g_per_day", "unitGramsPerWeek": "pdf_unit_g_per_week",
    "unitDrinkDaysPerWeek": "pdf_meta_drink_days_suffix",
    "kpiTotal": "pdf_kpi_total", "kpiAvgPerDay": "pdf_kpi_avg_day",
    "kpiAvgPerDrinkDay": "pdf_kpi_avg_drink_day", "kpiMedianPerDay": "pdf_kpi_median_day",
    "kpiMedianPerDrinkDay": "pdf_kpi_median_drink_day", "kpiDrinkDays": "pdf_kpi_drink_days",
    "kpiAbstinentDays": "pdf_kpi_abstinent_days", "kpiMaxPerDay": "pdf_kpi_max_day",
    "kpiMaxPer7Days": "pdf_kpi_max_7days",
    "kpiAvgDrinkDaysPerMonth": "pdf_kpi_avg_drink_days_month",
    "kpiMedianDrinkDaysPerMonth": "pdf_kpi_median_drink_days_month",
    "columnMonth": "pdf_col_month", "columnDrinkDays": "pdf_col_drink_days",
    "columnTotalGrams": "pdf_col_total_g", "columnAvgPerDay": "pdf_col_avg_g_day",
    "columnOverDaily": "pdf_col_over_daily", "categoryHeading": "category",
}

# Closures that take one argument. `arg_kind` picks the Swift parameter type;
# `%1$s`/`%1$d` in the harvested value becomes `\\(value)`.
CLOSURES = {
    "kpiBinge": ("pdf_kpi_binge", "String"),
    "riskBingeDays": ("pdf_meta_binge_days", "String"),
    "kpiOverDaily": ("pdf_kpi_over_daily", "String"),
    "kpiOverWeekly": ("pdf_kpi_over_weekly", "String"),
    "kpiOverDrinkDays": ("pdf_kpi_over_drink_days", "Int"),
}

# The stored category key -> Android string key.
CATEGORIES = {
    "BEER": "category_beer", "WINE": "category_wine", "SPIRITS": "category_spirits",
    "LONGDRINK": "category_longdrink", "LIQUEUR": "category_liqueur",
    "OTHER": "category_other",
}


def android_strings(tag):
    path = ROOT / f"android/app/src/main/res/values{DIRS[tag]}/strings.xml"
    text = path.read_text(encoding="utf-8")
    out = {}
    for m in re.finditer(r'<string name="([^"]+)"[^>]*>(.*?)</string>', text, re.S):
        value = html.unescape(m.group(2)).replace("\\@", "@").replace("\\'", "'").strip()
        out[m.group(1)] = value
    return out


def swift_literal(value):
    """Escapes a harvested value for a Swift double-quoted string literal."""
    return value.replace("\\", "\\\\").replace('"', '\\"')


def closure_body(value):
    """Turns a harvested `%1$s`/`%1$d` value into a Swift interpolation `\\($0)`."""
    escaped = swift_literal(value)
    return re.sub(r"%1\$[sd]", r"\\($0)", escaped)


def header():
    return Path("/tmp/SWHDR").read_text(encoding="utf-8")


def build():
    langs = list(DIRS)
    def wrap(value, indent):
        """Splits a long Swift literal into concatenated chunks under the line limit."""
        literal = swift_literal(value)
        limit = 96 - len(indent)
        if len(literal) <= limit:
            return [f'{indent}"{literal}"']
        # break on spaces so each piece stays a valid literal
        pieces, current = [], ""
        for word in literal.split(" "):
            candidate = (current + " " + word).strip()
            if len(candidate) > limit and current:
                pieces.append(current)
                current = word
            else:
                current = candidate
        if current:
            pieces.append(current)
        # Each piece but the last keeps a trailing space, so concatenation restores
        # the original spacing exactly.
        out = []
        for i, piece in enumerate(pieces):
            text = piece if i == len(pieces) - 1 else piece + " "
            sep = "" if i == len(pieces) - 1 else " +"
            out.append(f'{indent}"{text}"{sep}')
        return out

    data = {tag: android_strings(tag) for tag in langs}

    lines = [header().rstrip(), "", "import Foundation", "",
             "// =============================================================================",
             "// ReportLabels(language:) - the PDF report's labels in every shipping language.",
             "//",
             "// GENERATED by tools/build-report-labels.py from Android's strings.xml. Do not",
             "// edit by hand: the report must match Android's word for word, and a hand edit",
             "// would drift on the next regeneration. The report follows the UI language, as",
             "// Android's does (Context.formattingLocale drives both its labels and numbers).",
             "//",
             "// ReportLabels declares an explicit init(), which suppresses the memberwise one,",
             "// so each builder mutates a var. One function per language keeps every function",
             "// under the complexity and length limits a single switch would blow past.",
             "// =============================================================================",
             "",
             "extension ReportLabels {",
             "",
             "    /// Returns the report labels for a UI language tag (e.g. `de`, `zh-Hans`).",
             "    /// An unknown or empty tag yields the English labels, matching how the rest",
             "    /// of the app treats \"System\" and unsupported tags.",
             "    public init(language: String) {",
             "        self.init()   // English defaults; a known tag overwrites them",
             "        switch language {"]
    for tag in langs:
        if tag == "en":
            continue
        method = "apply" + tag.replace("-", "")
        lines.append(f'        case "{tag}": {method}()')
    lines.append("        default: break   // keep the English defaults")
    lines.append("        }")
    lines.append("    }")

    for tag in langs:
        if tag == "en":
            continue
        strings = data[tag]
        method = "apply" + tag.replace("-", "")
        lines.append("")
        lines.append(f'    private mutating func {method}() {{')
        for field, key in FIELDS.items():
            chunks = wrap(strings[key], "            ")
            if len(chunks) == 1:
                lines.append(f'        self.{field} = {chunks[0].strip()}')
            else:
                lines.append(f'        self.{field} =')
                lines.extend(chunks)
        for name, (key, _) in CLOSURES.items():
            lines.append(f'        self.{name} = {{ "{closure_body(strings[key])}" }}')
        lines.append("        self.category = { name in")
        lines.append("            switch name {")
        for ck, ak in CATEGORIES.items():
            if ck == "OTHER":
                continue
            lines.append(f'            case "{ck}": return "{swift_literal(strings[ak])}"')
        lines.append(f'            default: return "{swift_literal(strings[CATEGORIES["OTHER"]])}"')
        lines.append("            }")
        lines.append("        }")
        lines.append("    }")

    lines.append("}")
    lines.append("")

    OUT.write_text("\n".join(lines), encoding="utf-8")
    scalars = len(FIELDS)
    print(f"  wrote {OUT.relative_to(ROOT)}")
    print(f"  {len(langs)} languages, {scalars} scalar fields + "
          f"{len(CLOSURES)} closures + {len(CATEGORIES)} categories each")


if __name__ == "__main__":
    build()
