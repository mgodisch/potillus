/* vim: set et ts=4:
 * =============================================================================
 * Libellus Potionis -- Privacy-Friendly Alcohol Tracker
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
package de.godisch.potillus.l10n

// =============================================================================
// LocaleSyncTest.kt — Locale three-way sync and completeness tests
// =============================================================================
//
// WHAT THESE TESTS GUARD AGAINST
//   In the past, new string-resource directories were added without updating
//   either locale_config.xml (the system language picker) or the in-app
//   LanguageDropdown list in SettingsScreen.kt.  This caused newly translated
//   languages to be completely invisible to users even though the strings.xml
//   files existed.
//
//   These tests enforce three invariants automatically on every build:
//
//     1. REGISTRY COMPLETENESS
//        Every values-<qualifier>/ directory (excluding the base values/ and
//        the night-mode values-night/) has a corresponding entry in
//        SupportedLocales.ALL, and vice-versa.
//        Exception: "en" — the base locale lives in values/, not values-en/.
//
//     2. LOCALE_CONFIG SYNC
//        Every tag in SupportedLocales.ALL appears in locale_config.xml, and
//        vice-versa.  This validates the system-picker registration.
//
//     3. STRING COMPLETENESS
//        Every translated strings.xml contains exactly as many <string> entries
//        as the German base (values-de/strings.xml), which is the source of
//        truth.  Missing keys mean untranslated UI strings that silently fall
//        back to German.
//
//     4. GUIDE ⇄ STRINGS LANGUAGE PARITY
//        The set of user-guide templates (docs/guide/usersguide.<tag>.md.in,
//        with the base usersguide.md.in counting as "en") is identical to the
//        set of string-resource languages.  Otherwise a language would ship UI
//        text without an in-app guide, or vice-versa.  This mirrors, on the
//        JVM/CI path, the same guard that render-guide.py enforces at build
//        time, so the two layers fail in lock-step.
//
// WHY PURE JVM (no Android runtime)?
//   These tests read the project's resource files from disk using java.io.File
//   and parse XML with javax.xml.parsers.  No Android framework classes are
//   needed, so the tests run in the fast JVM unit-test executor
//   (./gradlew :app:test) rather than the slow instrumented test executor.
//
// FILE-PATH STRATEGY
//   The tests locate resources relative to the working directory that Gradle
//   sets when running unit tests, which is the module root
//   (…/app/).  Paths are therefore relative to that root.
//
//   If the tests are ever run from a different working directory (e.g. the
//   repo root), set the system property  potillus.project.dir  to the absolute
//   path of the app module directory, or adjust RES_DIR below.
// =============================================================================

import org.junit.Assert.assertEquals
import org.junit.Assert.fail
import org.junit.Test
import java.io.File
import javax.xml.parsers.DocumentBuilderFactory

class LocaleSyncTest {

    // ── Configuration ─────────────────────────────────────────────────────────

    companion object {
        /**
         * Root of the Android resource directory, relative to the Gradle
         * module working directory (app/).
         *
         * Override via system property  potillus.project.dir  if needed:
         *   -Dpotillus.project.dir=/absolute/path/to/app
         */
        private val RES_DIR: File = run {
            val override = System.getProperty("potillus.project.dir")
            if (override != null) File(override, "src/main/res")
            else File("src/main/res")
        }

        /** The German base strings.xml — source of truth for key count. */
        private val BASE_STRINGS: File = File(RES_DIR, "values-de/strings.xml")

        /** The locale_config.xml that drives the system language picker. */
        private val LOCALE_CONFIG: File = File(RES_DIR, "xml/locale_config.xml")

        /**
         * Directory holding the user-guide templates
         * (docs/guide/usersguide*.md.in). It lives one level ABOVE the app
         * module (…/android/docs/guide), i.e. a sibling of the module that
         * RES_DIR is under, hence the "../docs/guide" hop from the module root.
         */
        private val GUIDE_DIR: File = run {
            val override = System.getProperty("potillus.project.dir")
            if (override != null) File(override, "../docs/guide")
            else File("../docs/guide")
        }

        /**
         * Converts an Android resource qualifier to a plain BCP-47 tag.
         *
         * Android encodes region variants with a lowercase "r" prefix:
         *   values-pt-rBR  →  "pt-BR"
         *   values-zh-rCN  →  "zh-CN"
         *   values-de      →  "de"
         */
        private fun qualifierToBcp47(qualifier: String): String =
            qualifier.replace(Regex("-r([A-Z])"), "-$1")

        /**
         * Counts <string name="…"> elements in an XML file.
         * Returns 0 if the file cannot be parsed.
         */
        private fun countStrings(file: File): Int {
            if (!file.exists()) return 0
            return try {
                val doc = DocumentBuilderFactory.newInstance()
                    .newDocumentBuilder()
                    .parse(file)
                doc.getElementsByTagName("string").length
            } catch (e: Exception) {
                0
            }
        }

        /**
         * Returns the set of `name` attributes of all `<string>` elements in
         * [file], or an empty set if it cannot be parsed.
         *
         * Used by the key-SET completeness test, which is stricter than the
         * key-COUNT test: a locale that is missing one key and has one extra,
         * stray key has the right count but the wrong set.
         */
        private fun parseStringNames(file: File): Set<String> {
            if (!file.exists()) return emptySet()
            return try {
                val doc = DocumentBuilderFactory.newInstance()
                    .newDocumentBuilder()
                    .parse(file)
                val nodes = doc.getElementsByTagName("string")
                (0 until nodes.length)
                    .mapNotNull { nodes.item(it).attributes?.getNamedItem("name")?.nodeValue }
                    .toSet()
            } catch (e: Exception) {
                emptySet()
            }
        }

        /**
         * Parses all  android:name="…"  attribute values from an XML file.
         * Used to extract the locale tags from locale_config.xml.
         */
        private fun parseAndroidNames(file: File): Set<String> {
            if (!file.exists()) return emptySet()
            val doc = DocumentBuilderFactory.newInstance()
                .newDocumentBuilder()
                .parse(file)
            val nodes = doc.getElementsByTagName("locale")
            return (0 until nodes.length)
                .map { nodes.item(it).attributes.getNamedItem("android:name").nodeValue }
                .toSet()
        }
    }

    // ── Helper: collect values-XX dirs from disk ───────────────────────────────

    /**
     * Returns the set of BCP-47 tags derived from  values-XX/  directories
     * that contain a strings.xml file.
     *
     * Excluded:
     *  - values/          (base, no qualifier)
     *  - values-night/    (night-mode colours, not a locale)
     *  - values-vNN/      (API-level qualifiers, e.g. values-v26)
     *
     * The English base locale "en" is added explicitly because it has no
     * values-en/ directory (it lives in values/).
     */
    private fun localeTagsFromDirs(): Set<String> {
        val dirs = RES_DIR.listFiles { f ->
            f.isDirectory &&
            f.name.startsWith("values-") &&
            f.name != "values-night" &&
            !f.name.matches(Regex("values-v\\d+")) &&
            File(f, "strings.xml").exists()
        } ?: emptyArray()

        return dirs.map { qualifierToBcp47(it.name.removePrefix("values-")) }.toSet() + "en"
    }

    // ── Test 1: SupportedLocales.ALL covers every values-XX dir ───────────────

    /**
     * Every  values-<qualifier>/strings.xml  directory must have a matching
     * entry in [SupportedLocales.ALL], and every entry in [SupportedLocales.ALL]
     * must have a corresponding directory (except "en").
     *
     * Failure here means either:
     *  (a) a new strings.xml was added without registering it in SupportedLocales, or
     *  (b) an entry was added to SupportedLocales without creating the strings.xml.
     */
    @Test
    fun `every values directory is registered in SupportedLocales`() {
        val fromDirs = localeTagsFromDirs()
        val fromRegistry = SupportedLocales.TAGS

        val missingFromRegistry = fromDirs - fromRegistry
        val missingDirectory    = fromRegistry - fromDirs - setOf("en") // en has no dir

        val errors = buildString {
            if (missingFromRegistry.isNotEmpty()) {
                appendLine("values-XX/ dirs NOT registered in SupportedLocales.ALL:")
                missingFromRegistry.sorted().forEach { appendLine("  ✗  $it") }
                appendLine("  → Add a Locale(\"${ missingFromRegistry.first() }\", \"<autonym>\") entry to SupportedLocales.kt")
            }
            if (missingDirectory.isNotEmpty()) {
                appendLine("SupportedLocales entries with NO values-XX/ directory:")
                missingDirectory.sorted().forEach { appendLine("  ✗  $it") }
                appendLine("  → Create app/src/main/res/values-<qualifier>/strings.xml")
            }
        }

        if (errors.isNotBlank()) fail(errors.trimEnd())
    }

    // ── Test 2: locale_config.xml mirrors SupportedLocales.ALL ────────────────

    /**
     * The set of  android:name  values in  locale_config.xml  must exactly
     * match [SupportedLocales.TAGS].
     *
     * Failure means the system language picker (Settings → Apps → Potillus →
     * Language, API 33+) and the AppCompatDelegate locale store show a
     * different set of languages than the app actually supports.
     */
    @Test
    fun `locale_config xml mirrors SupportedLocales exactly`() {
        val fromConfig   = parseAndroidNames(LOCALE_CONFIG)
        val fromRegistry = SupportedLocales.TAGS

        val missingFromConfig   = fromRegistry - fromConfig
        val extraInConfig       = fromConfig   - fromRegistry

        val errors = buildString {
            if (missingFromConfig.isNotEmpty()) {
                appendLine("Tags in SupportedLocales but MISSING from locale_config.xml:")
                missingFromConfig.sorted().forEach { appendLine("  ✗  $it") }
                appendLine("  → Add <locale android:name=\"...\"/> to res/xml/locale_config.xml")
            }
            if (extraInConfig.isNotEmpty()) {
                appendLine("Tags in locale_config.xml but NOT in SupportedLocales:")
                extraInConfig.sorted().forEach { appendLine("  ✗  $it") }
                appendLine("  → Remove the entry from locale_config.xml, or add it to SupportedLocales.kt")
            }
        }

        if (errors.isNotBlank()) fail(errors.trimEnd())
    }

    // ── Test 3: every strings.xml has the same number of keys as the base ──────

    /**
     * Every translated  strings.xml  must contain exactly as many
     * `<string>` elements as  values-de/strings.xml  (the German source of
     * truth).
     *
     * A lower count means keys are missing: those strings will silently fall
     * back to German at runtime, which is confusing for non-German speakers.
     *
     * A higher count indicates obsolete or duplicate keys that should be
     * cleaned up to keep translations maintainable.
     *
     * Note: the base locale itself (values-de/) is excluded from this check
     * since it defines the expected count.
     */
    @Test
    fun `every strings xml has the same key count as the base locale`() {
        val expectedCount = countStrings(BASE_STRINGS)
        require(expectedCount > 0) {
            "Base strings file not found or empty: ${BASE_STRINGS.absolutePath}"
        }

        val offenders = mutableListOf<String>()

        RES_DIR.listFiles { f ->
            f.isDirectory &&
            f.name.startsWith("values-") &&
            f.name != "values-de" &&        // exclude the base itself
            f.name != "values-night" &&
            !f.name.matches(Regex("values-v\\d+"))
        }?.sorted()?.forEach { dir ->
            val stringsFile = File(dir, "strings.xml")
            if (!stringsFile.exists()) return@forEach  // no strings.xml → covered by Test 1

            val actualCount = countStrings(stringsFile)
            if (actualCount != expectedCount) {
                offenders += "${dir.name}/strings.xml: $actualCount strings (expected $expectedCount)"
            }
        }

        if (offenders.isNotEmpty()) {
            fail(
                "String count mismatch in ${offenders.size} locale(s):\n" +
                offenders.joinToString("\n") { "  ✗  $it" } + "\n" +
                "  → Translate all missing keys, or remove obsolete ones."
            )
        }
    }

    // ── Test 3b: every strings.xml has the same key SET as the base ───────────

    /**
     * Stricter companion to the key-count test: every translated
     * `strings.xml` must contain exactly the same set of `<string name="…">` keys
     * as the German base, reporting any missing or extra keys by name.
     *
     * WHY in addition to the count test?
     *   The count test passes as long as the totals match. A locale that drops one
     *   real key and adds one stray/duplicate-typo key has the right count but the
     *   wrong keys — the dropped string silently falls back to German and the stray
     *   key is dead weight. Comparing the sets catches both at once and names the
     *   offending keys, which makes the fix obvious.
     */
    @Test
    fun `every strings xml has the same keys as the base locale`() {
        val baseKeys = parseStringNames(BASE_STRINGS)
        require(baseKeys.isNotEmpty()) {
            "Base strings file not found or empty: ${BASE_STRINGS.absolutePath}"
        }

        val offenders = mutableListOf<String>()

        RES_DIR.listFiles { f ->
            f.isDirectory &&
            f.name.startsWith("values-") &&
            f.name != "values-de" &&        // exclude the base itself
            f.name != "values-night" &&
            !f.name.matches(Regex("values-v\\d+"))
        }?.sorted()?.forEach { dir ->
            val stringsFile = File(dir, "strings.xml")
            if (!stringsFile.exists()) return@forEach  // no strings.xml → covered by Test 1

            val keys    = parseStringNames(stringsFile)
            val missing = baseKeys - keys
            val extra   = keys - baseKeys
            if (missing.isNotEmpty() || extra.isNotEmpty()) {
                val parts = buildString {
                    if (missing.isNotEmpty()) append("missing ${missing.sorted()}")
                    if (extra.isNotEmpty()) {
                        if (isNotEmpty()) append("; ")
                        append("extra ${extra.sorted()}")
                    }
                }
                offenders += "${dir.name}/strings.xml: $parts"
            }
        }

        if (offenders.isNotEmpty()) {
            fail(
                "String key-set mismatch in ${offenders.size} locale(s):\n" +
                offenders.joinToString("\n") { "  ✗  $it" } + "\n" +
                "  → Add missing keys (translate from values-de/) or remove stray ones."
            )
        }
    }

    // ── Test 4: SupportedLocales.ALL has no duplicate tags ────────────────────

    /**
     * Duplicate BCP-47 tags in [SupportedLocales.ALL] would cause the dropdown
     * to show the same language twice.  This check is O(n) and catches
     * copy-paste errors when adding a new locale.
     */
    @Test
    fun `SupportedLocales has no duplicate tags`() {
        val tags = SupportedLocales.ALL.map { it.tag }
        val duplicates = tags.groupBy { it }.filter { it.value.size > 1 }.keys

        if (duplicates.isNotEmpty()) {
            fail(
                "Duplicate tags in SupportedLocales.ALL:\n" +
                duplicates.sorted().joinToString("\n") { "  ✗  $it" }
            )
        }
    }

    // ── Test 5: SupportedLocales.ALL has no duplicate autonyms ───────────────

    /**
     * Two locales with the same autonym would be indistinguishable in the
     * dropdown.  Example: if both "pt" and "pt-BR" were labelled "Português"
     * the user could not tell them apart.
     */
    @Test
    fun `SupportedLocales has no duplicate autonyms`() {
        val autonyms = SupportedLocales.ALL.map { it.autonym }
        val duplicates = autonyms.groupBy { it }.filter { it.value.size > 1 }.keys

        if (duplicates.isNotEmpty()) {
            fail(
                "Duplicate autonyms in SupportedLocales.ALL:\n" +
                duplicates.sorted().joinToString("\n") { "  ✗  $it" }
            )
        }
    }

    // ── Test 6: locale_config.xml file exists and is readable ─────────────────

    /**
     * A missing locale_config.xml is a silent failure: the app builds, but
     * the system language picker shows no languages.  This test makes the
     * failure loud and early.
     */
    @Test
    fun `locale_config xml exists and is parseable`() {
        if (!LOCALE_CONFIG.exists()) {
            fail("locale_config.xml not found at: ${LOCALE_CONFIG.absolutePath}")
        }
        val names = parseAndroidNames(LOCALE_CONFIG)
        if (names.isEmpty()) {
            fail("locale_config.xml is empty or could not be parsed: ${LOCALE_CONFIG.absolutePath}")
        }
    }

    // ── Test 7: base strings.xml exists and is non-empty ──────────────────────

    /**
     * If the German base file is missing, Test 3 would silently pass with an
     * expected count of 0, masking all completeness failures.  This guard
     * makes that scenario a loud failure instead.
     */
    // ── Test 8: guide templates and string resources cover the same languages ─

    /**
     * Returns the set of BCP-47 tags that have a user-guide template under
     * [GUIDE_DIR]. Template file names already carry the plain BCP-47 tag
     * (e.g. `usersguide.pt-BR.md.in`, `usersguide.zh-CN.md.in`), so no
     * qualifier conversion is needed. The code-less base `usersguide.md.in`
     * maps to the English base locale `"en"` — matching how
     * [localeTagsFromDirs] treats the unqualified `values/` directory.
     */
    private fun guideTagsFromTemplates(): Set<String> {
        val files = GUIDE_DIR.listFiles { f ->
            f.isFile && f.name.startsWith("usersguide") && f.name.endsWith(".md.in")
        } ?: emptyArray()
        return files.map { f ->
            val middle = f.name.removePrefix("usersguide").removeSuffix(".md.in")
            if (middle.startsWith(".")) middle.substring(1) else "en"
        }.toSet()
    }

    /**
     * The user-guide templates and the string-resource directories must cover
     * exactly the same set of languages (both counting their unqualified base
     * as English, `"en"`). A language with strings but no guide would open an
     * empty/fallback guide; a guide with no strings cannot even be rendered
     * (its `{{tokens}}` have no source). This is the JVM/CI twin of the guard
     * in `render-guide.py`; keeping both means neither a Gradle test run nor a
     * plain `make` build can let the two sets drift apart.
     */
    @Test
    fun `guide templates and string resources cover the same languages`() {
        val guideTags = guideTagsFromTemplates()
        require(guideTags.isNotEmpty()) {
            "No user-guide templates found under: ${GUIDE_DIR.absolutePath}"
        }
        val stringTags = localeTagsFromDirs()

        val missingGuide   = (stringTags - guideTags).sorted()  // strings, no guide
        val missingStrings = (guideTags - stringTags).sorted()  // guide, no strings

        if (missingGuide.isNotEmpty() || missingStrings.isNotEmpty()) {
            val msg = buildString {
                appendLine("Guide languages and string-resource languages are out of sync.")
                if (missingGuide.isNotEmpty()) {
                    appendLine("strings.xml present but NO guide template:")
                    missingGuide.forEach {
                        appendLine("  ✗  $it  → add docs/guide/usersguide.$it.md.in")
                    }
                }
                if (missingStrings.isNotEmpty()) {
                    appendLine("guide template present but NO strings.xml:")
                    missingStrings.forEach {
                        appendLine("  ✗  $it  → add values-<qualifier>/strings.xml or remove the template")
                    }
                }
            }
            fail(msg.trimEnd())
        }
    }
}
