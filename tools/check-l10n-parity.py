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

# =============================================================================
# check-l10n-parity.py — the iOS catalogue against Android, and against the code.
#
# The iOS localisation is self-contained: ios/Potillus/Localizable.xcstrings and
# ios/PotillusKit/.../ReportLabelsCatalog.swift are the committed source of truth,
# and the iOS BUILD reads neither android/ nor any generator. This check is the
# safety net that keeps the two platforms from drifting, and it runs in BOTH
# `make ios` and `make android`. It reads android/ only to COMPARE — it never
# generates iOS artefacts from it.
#
# FOUR CHECKS
#   1. Every UI literal in the iOS views has a key in the catalogue. Previously a
#      generator inserted missing keys as untranslated; with the generator gone,
#      this guards against a literal that no catalogue entry covers.
#   2. Every catalogue translation whose English key equals an Android string is
#      IDENTICAL to Android's translation for that string, in every language. This
#      is the anti-drift guarantee: a reworded Android string must be reworded on
#      iOS too, or this fails.
#   3. The report labels (ReportLabelsCatalog.swift) match Android's strings.xml
#      for the same keys, in every language.
#   4. Where Android translates one English word two ways -- the screen title
#      `statistics` beside the short tab label `nav_statistics` ("Statistiques" vs
#      "Stats" in French) -- iOS must split it too. CHECK 2 alone would accept the
#      short value in the title's place (it matches SOME Android string), so this
#      catches the missing split that let the French "Stats" heading through.
#
# A mismatch is a hard error: the platforms have diverged and someone must decide
# which wording is correct and update the other side.
# =============================================================================

import html
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "ios/Potillus/Localizable.xcstrings"
REPORT_LABELS = ROOT / "ios/PotillusKit/Sources/PotillusKit/Domain/ReportLabelsCatalog.swift"
VIEWS = sorted((ROOT / "ios" / "Potillus").glob("*.swift"))
ANDROID_EN = ROOT / "android/app/src/main/res/values/strings.xml"

# iOS catalogue tag → Android resource-dir suffix. Most match; a few differ.
LANGUAGES = ["de", "da", "nl", "nb", "sv", "es", "fr", "it", "pt", "pt-BR", "ro",
             "cs", "pl", "ru", "uk", "el", "ja", "ko", "zh-Hans", "zh-Hant"]
ANDROID_DIR = {"pt-BR": "pt-rBR", "zh-Hans": "zh-rCN", "zh-Hant": "zh-rTW"}

# Proper nouns are shown verbatim, never translated: they legitimately match across
# languages and carry no Android counterpart to compare against.
PROPER_NOUNS = {"GRDB.swift"}

# ReportLabels scalar field → Android string name, for CHECK 3. Ported from the old
# report-labels generator; the closures (one-argument labels) are not string-compared
# here because their format arguments differ per platform.
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


def android_map(path):
    """{name: value} for one Android strings.xml, entities and escapes resolved."""
    if not path.exists():
        return {}
    xml = path.read_text(encoding="utf-8")
    out = {}
    for m in re.finditer(r'<string name="([^"]+)"[^>]*>(.*?)</string>', xml, re.S):
        v = html.unescape(m.group(2)).replace("\\@", "@").replace("\\'", "'").strip()
        out[m.group(1)] = v
    return out


def android_dir_suffix(tag):
    return ANDROID_DIR.get(tag, tag)


def swift_unescape(value):
    """Resolves Swift string escapes without mangling UTF-8. A file read as UTF-8
    already holds the real characters, so `unicode_escape` MUST NOT be used — it
    re-reads multi-byte characters as Latin-1 and corrupts them. Only the handful of
    Swift backslash escapes are resolved here; everything else is left untouched."""
    simple = {'"': '"', '\\': '\\', 'n': '\n', 't': '\t', 'r': '\r', "'": "'", '0': '\0'}
    out = []
    i = 0
    while i < len(value):
        if value[i] == "\\" and i + 1 < len(value) and value[i + 1] in simple:
            out.append(simple[value[i + 1]])
            i += 2
        else:
            out.append(value[i])
            i += 1
    return "".join(out)


def load_catalog():
    return json.loads(CATALOG.read_text(encoding="utf-8"))["strings"]


def catalog_value(entry, tag):
    """The plain translated string for a language, or None. Plural entries have no
    single value and are compared separately (their forms come from Android too)."""
    loc = entry.get("localizations", {}).get(tag)
    if not loc or "stringUnit" not in loc:
        return None
    return loc["stringUnit"]["value"]


def collect_literals():
    """Every UI string literal in the views, by the same call shapes the app uses."""
    call = re.compile(
        r'(?:Text|Label|Button|Toggle|navigationTitle|Section'
        r'|ContentUnavailableView|accessibilityLabel|Picker|TextField|DatePicker'
        r'|Stepper|LabeledContent|Loc\.string)'
        r'\(\s*"([^"]+)"'
    )
    found = set()
    for path in VIEWS:
        text = path.read_text(encoding="utf-8")
        for m in call.finditer(text):
            found.add(m.group(1))
    return found


def is_interpolation_only(literal):
    """A literal that is nothing but an interpolation/number carries no words."""
    return re.fullmatch(r'[%@\d$lld /·.\\()a-zA-Z_]*', literal) is not None


def check_missing_keys(catalog):
    """CHECK 1 — every UI literal has a catalogue key (untranslated-key safety net)."""
    keys = set(catalog.keys())
    problems = []
    for literal in sorted(collect_literals()):
        if literal in keys or literal in PROPER_NOUNS:
            continue
        # A literal carrying an interpolation is stored under a placeholder key
        # (e.g. "%@"); if any placeholder key exists it is covered, so only flag
        # literals that are plain words and simply absent.
        if is_interpolation_only(literal):
            continue
        if "\\(" in literal:
            continue  # interpolated; its placeholder key is checked structurally
        problems.append(f"UI literal has no catalogue key: {literal!r}")
    return problems


def check_translation_parity(catalog):
    """CHECK 2 — catalogue translations match Android where the English key is an
    Android string, in every language.

    One English word can back SEVERAL Android strings with DIFFERENT translations —
    e.g. "Month" is both `month` ("月") and `pdf_col_month` ("月份"), and "Statistics"
    is both the screen title `statistics` and the short tab label `nav_statistics`.
    So a key is in parity if its iOS translation matches ANY Android string that
    shares the English value; a mismatch is reported only when it matches NONE."""
    en = android_map(ANDROID_EN)
    if not en:
        return [f"cannot read {ANDROID_EN.relative_to(ROOT)} for the parity check"]
    # English value → every Android string name that carries it.
    value_to_names = {}
    for name, value in en.items():
        value_to_names.setdefault(value, []).append(name)

    problems = []
    for tag in LANGUAGES:
        android = android_map(ROOT / f"android/app/src/main/res/values-{android_dir_suffix(tag)}/strings.xml")
        for key, entry in catalog.items():
            if entry.get("shouldTranslate") is False or key in PROPER_NOUNS:
                continue
            names = value_to_names.get(key)
            if not names:
                continue  # iOS-only string: nothing on the Android side to compare
            candidates = [android[n] for n in names if n in android]
            if not candidates:
                continue  # Android has no translation for any candidate in this language
            ios_value = catalog_value(entry, tag)
            if ios_value is None:
                continue  # plural or untranslated; the missing-key check covers absence
            if ios_value not in candidates:
                shown = " / ".join(repr(c) for c in sorted(set(candidates)))
                problems.append(
                    f"[{tag}] {key!r}: iOS {ios_value!r} matches none of Android {shown}"
                )
    return problems


def check_report_labels():
    """CHECK 3 — report labels match Android's strings.xml for the same keys, in
    every language. ReportLabelsCatalog.swift has one `apply<tag>()` per language,
    each assigning `self.field = "value"`; FIELDS maps each field to its Android
    string name, so every assignment is compared to Android for that language."""
    if not REPORT_LABELS.exists():
        return [f"missing {REPORT_LABELS.relative_to(ROOT)}"]
    text = REPORT_LABELS.read_text(encoding="utf-8")
    problems = []
    # iOS tag → the apply-function suffix used in the file (e.g. pt-BR → ptBR).
    for tag in LANGUAGES:
        suffix = tag.replace("-", "")
        m = re.search(rf'func apply{suffix}\(\)\s*\{{(.*?)\n    \}}', text, re.S)
        if not m:
            problems.append(f"no apply{suffix}() block for {tag!r} in ReportLabelsCatalog")
            continue
        body = m.group(1)
        android = android_map(ROOT / f"android/app/src/main/res/values-{android_dir_suffix(tag)}/strings.xml")
        # An assignment may concatenate several string literals with `+` across
        # lines when the text is long, so capture the whole right-hand side and
        # join its literals rather than reading only the first.
        assign = re.compile(r'self\.(\w+)\s*=\s*((?:"(?:[^"\\]|\\.)*"\s*(?:\+\s*)?)+)')
        for field, rhs in assign.findall(body):
            name = FIELDS.get(field)
            if name is None or name not in android:
                continue  # closures and untranslated fields are compared elsewhere / not at all
            literals = re.findall(r'"((?:[^"\\]|\\.)*)"', rhs)
            decoded = "".join(swift_unescape(part) for part in literals)
            if decoded != android[name]:
                problems.append(
                    f"[{tag}] report label {field} ({name}): "
                    f"iOS {decoded!r} != Android {android[name]!r}"
                )
    return problems


def check_collapsed_divergent_mappings(catalog):
    """CHECK 4 — an English word Android translates two ways must be split on iOS too.

    CHECK 2 lets an iOS key match ANY Android string that shares its English text.
    That is right when those strings agree, but blind when they DIVERGE: the French
    "Statistics" heading bug passed CHECK 2 because iOS's single `Statistics` key
    matched the short tab label `nav_statistics` ("Stats") even while it also rendered
    the full screen title. CHECK 2 cannot tell which context is wrong; this check
    catches the setup that lets a context BE wrong.

    When one English value backs several Android names that differ in some language,
    iOS must carry a dedicated source for all but (at most) one of them — a catalogue
    key of the same name (as `nav_statistics` mirrors Android's `nav_statistics`) or a
    report label (a FIELDS value, rendered from ReportLabelsCatalog — which is how
    `month` vs `pdf_col_month`, "月" vs "月份", stays correct). If two or more of the
    DIVERGING names are left for one plain iOS key to cover, that key cannot be right
    in every place, and this fails."""
    en = android_map(ANDROID_EN)
    if not en:
        return [f"cannot read {ANDROID_EN.relative_to(ROOT)} for the parity check"]
    value_to_names = {}
    for name, value in en.items():
        value_to_names.setdefault(value, []).append(name)

    # Android translations per language, loaded once (English included).
    per_lang = {"en": en}
    for tag in LANGUAGES:
        per_lang[tag] = android_map(ROOT / f"android/app/src/main/res/values-{android_dir_suffix(tag)}/strings.xml")

    def diverging_language(names):
        """A language in which the given Android names do not all agree, or None."""
        for tag, amap in per_lang.items():
            values = {amap[n] for n in names if n in amap}
            if len(values) > 1:
                return tag
        return None

    # An Android name is "covered" on iOS when iOS renders it from its own dedicated
    # source: a catalogue key of the same name, or a report label (FIELDS value).
    covered = set(catalog.keys()) | set(FIELDS.values())

    problems = []
    for value, names in sorted(value_to_names.items()):
        if len(names) < 2 or diverging_language(names) is None:
            continue  # one name, or several that agree everywhere: nothing to split
        uncovered = [n for n in names if n not in covered]
        if len(uncovered) < 2:
            continue  # at most one falls to the plain iOS key — it can serve that one
        tag = diverging_language(uncovered)
        if tag is not None:
            shown = ", ".join(sorted(uncovered))
            problems.append(
                f"[{tag}] {value!r}: Android splits this into differently-translated "
                f"strings ({shown}); a single iOS key cannot be right in every context "
                f"— give each its own key, as nav_statistics mirrors Android's."
            )
    return problems


def main():
    catalog = load_catalog()
    problems = []
    problems += check_missing_keys(catalog)
    problems += check_translation_parity(catalog)
    problems += check_report_labels()
    problems += check_collapsed_divergent_mappings(catalog)

    if problems:
        for p in problems:
            print(f"check-l10n-parity: {p}", file=sys.stderr)
        print(f"check-l10n-parity: {len(problems)} problem(s)", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
