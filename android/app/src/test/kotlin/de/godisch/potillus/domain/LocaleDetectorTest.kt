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
 * In addition, as permitted by section 7 of the GNU General Public License,
 * this program may carry additional permissions; any such permissions that
 * apply to it are stated in the accompanying COPYING.md file.
 *
 * =============================================================================
 */
package de.godisch.potillus.domain

// =============================================================================
// LocaleDetectorTest.kt – Unit tests for LocaleDetector (T-03)
// =============================================================================
//
// WHAT IS TESTED:
//   The five-step matching strategy of LocaleDetector.detect():
//     1. Exact full-tag match          ("zh-CN"      → "zh-CN")
//     2. Language+region, script-free  ("zh-Hant-TW" → "zh-TW")
//     3. Chinese script/region mapping ("zh-Hant-HK" → "zh-TW")
//     4. Base-language match           ("de-AT"      → "de", alias "no" → "nb")
//     5. English fallback              ("ar"         → "en")
//
// WHY PURE JVM (no Android, no Robolectric):
//   LocaleDetector has zero Android dependencies. java.util.Locale is part of
//   the JDK. All tests run as fast plain-JVM tests without any device or
//   emulator. This is the teaching-app demonstration that extracting pure logic
//   out of Android-coupled classes pays off immediately in test simplicity.
//
// SUPPORTED-TAGS FIXTURE:
//   Tests use a small hard-coded fixture set instead of the real
//   SupportedLocales.TAGS to keep the tests independent of the production
//   locale list. The full production set is exercised implicitly by
//   LocaleSyncTest (which reads the real SupportedLocales.TAGS and compares
//   it against locale_config.xml and the values-XX/ directories).
// =============================================================================

import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.Locale

/**
 * Unit tests for [LocaleDetector.detect].
 *
 * Covers all five matching steps and several edge cases.
 */
class LocaleDetectorTest {

    /** A minimal fixture set that includes region variants and a base-only tag. */
    private val supported = setOf("en", "de", "fr", "pt-BR", "zh-CN", "zh-TW")

    // ── Step 1: exact full-tag match ─────────────────────────────────────────

    /**
     * A locale whose full IETF tag matches exactly (e.g. "de" system → "de").
     *
     * Locale.of("de") produces toLanguageTag() = "de", which is in the supported set.
     */
    @Test fun `exact tag match returns the matching tag`() {
        val result = LocaleDetector.detect(Locale.of("de"), supported)
        assertEquals("de", result)
    }

    /**
     * A region-specific tag that exists as-is (e.g. "pt-BR" system → "pt-BR").
     *
     * Without the exact-match step a "pt-BR" system locale would fall through
     * to the base-language step and return "pt" — which is NOT in this fixture
     * set, ultimately falling back to "en". The exact match must fire first.
     */
    @Test fun `region variant exact match returns region tag`() {
        val result = LocaleDetector.detect(Locale.forLanguageTag("pt-BR"), supported)
        assertEquals("pt-BR", result)
    }

    /**
     * Chinese Simplified: "zh-CN" system locale → "zh-CN".
     * Chinese Traditional: "zh-TW" system locale → "zh-TW".
     * Both are distinct entries in the supported set; the full tag must be used.
     */
    @Test fun `zh-CN exact match returns zh-CN not zh-TW`() {
        assertEquals("zh-CN", LocaleDetector.detect(Locale.forLanguageTag("zh-CN"), supported))
        assertEquals("zh-TW", LocaleDetector.detect(Locale.forLanguageTag("zh-TW"), supported))
    }

    // ── Step 2: base-language match ──────────────────────────────────────────

    /**
     * A locale whose full tag is NOT in the set but whose base language is
     * (e.g. "de-AT" → base "de" → "de").
     *
     * Austrian German has no dedicated translation; falling back to German is
     * the correct behaviour.
     */
    @Test fun `dialect falls back to base language`() {
        val result = LocaleDetector.detect(Locale.forLanguageTag("de-AT"), supported)
        assertEquals("de", result)
    }

    /**
     * "fr-CA" is not in the fixture set, but "fr" is → returns "fr".
     */
    @Test fun `fr-CA falls back to fr`() {
        val result = LocaleDetector.detect(Locale.forLanguageTag("fr-CA"), supported)
        assertEquals("fr", result)
    }

    // ── Step 3: English fallback ─────────────────────────────────────────────

    /**
     * A locale whose full tag AND base language are both absent from the set
     * must fall through to the "en" fallback (e.g. Arabic).
     */
    @Test fun `unsupported language falls back to en`() {
        val result = LocaleDetector.detect(Locale.forLanguageTag("ar"), supported)
        assertEquals("en", result)
    }

    /**
     * A region-specific unsupported locale (e.g. "ar-SA") also falls back
     * to "en" because neither "ar-SA" nor "ar" is in the fixture set.
     */
    @Test fun `unsupported region variant falls back to en`() {
        val result = LocaleDetector.detect(Locale.forLanguageTag("ar-SA"), supported)
        assertEquals("en", result)
    }

    /**
     * An English locale already in the set must be returned via the exact-tag
     * step, not via the fallback (both lead to "en", but the path matters for
     * coverage: the fallback should only be reached for truly unrecognised locales).
     */
    @Test fun `English locale matches exactly`() {
        val result = LocaleDetector.detect(Locale.ENGLISH, supported)
        assertEquals("en", result)
    }

    // ── Edge cases ───────────────────────────────────────────────────────────

    /**
     * An empty supported set has nothing to match; must return "en" regardless
     * of the system locale (the fallback is unconditional).
     */
    @Test fun `empty supported set always returns en`() {
        val result = LocaleDetector.detect(Locale.GERMAN, emptySet())
        assertEquals("en", result)
    }

    /**
     * A set containing only "en" must return "en" for any locale.
     */
    @Test fun `en-only set returns en for any locale`() {
        val result = LocaleDetector.detect(Locale.forLanguageTag("ja"), setOf("en"))
        assertEquals("en", result)
    }

    /**
     * Match is case-insensitive, matching [String.equals] with ignoreCase = true
     * as documented in [LocaleDetector.detect].
     */
    @Test fun `matching is case-insensitive`() {
        val mixedCaseSupported = setOf("EN", "DE", "PT-BR")
        assertEquals("EN", LocaleDetector.detect(Locale.of("en"), mixedCaseSupported))
        assertEquals("DE", LocaleDetector.detect(Locale.of("de"), mixedCaseSupported))
        assertEquals("PT-BR", LocaleDetector.detect(Locale.forLanguageTag("pt-BR"), mixedCaseSupported))
    }

    // ── Step 2/3: script-carrying Chinese locales (v0.79.0 QA regression) ────
    //
    // Modern Android reports Chinese WITH a script subtag ("zh-Hant-TW",
    // "zh-Hans-CN"), which the original full-tag/base-language strategy could
    // not match: Traditional- and Simplified-Chinese users were silently forced
    // to English on first launch. These tests pin the script-aware steps.

    /** Language+region matching must drop the script: zh-Hant-TW → zh-TW. */
    @Test fun `zh-Hant-TW resolves to zh-TW`() {
        assertEquals("zh-TW", LocaleDetector.detect(Locale.forLanguageTag("zh-Hant-TW"), supported))
    }

    /** Language+region matching must drop the script: zh-Hans-CN → zh-CN. */
    @Test fun `zh-Hans-CN resolves to zh-CN`() {
        assertEquals("zh-CN", LocaleDetector.detect(Locale.forLanguageTag("zh-Hans-CN"), supported))
    }

    /** No supported language+region, but Hant script → Traditional (zh-TW). */
    @Test fun `zh-Hant-HK and zh-Hant-MO resolve to zh-TW via the script`() {
        assertEquals("zh-TW", LocaleDetector.detect(Locale.forLanguageTag("zh-Hant-HK"), supported))
        assertEquals("zh-TW", LocaleDetector.detect(Locale.forLanguageTag("zh-Hant-MO"), supported))
    }

    /** Without a script, the traditionally Traditional regions map to zh-TW. */
    @Test fun `scriptless zh-HK resolves to zh-TW via the region`() {
        assertEquals("zh-TW", LocaleDetector.detect(Locale.forLanguageTag("zh-HK"), supported))
    }

    /** Bare "zh" and Simplified-leaning variants resolve to zh-CN. */
    @Test fun `bare zh and zh-SG resolve to zh-CN`() {
        assertEquals("zh-CN", LocaleDetector.detect(Locale.forLanguageTag("zh"), supported))
        assertEquals("zh-CN", LocaleDetector.detect(Locale.forLanguageTag("zh-SG"), supported))
        assertEquals("zh-CN", LocaleDetector.detect(Locale.forLanguageTag("zh-Hans"), supported))
    }

    /**
     * The Chinese step must never invent a tag the app does not ship: with only
     * zh-CN supported, a Traditional locale still falls back through the
     * remaining steps (here: to "en") instead of returning an unshipped zh-TW.
     */
    @Test fun `zh step returns only supported tags`() {
        val simplifiedOnly = setOf("en", "zh-CN")
        assertEquals("en", LocaleDetector.detect(Locale.forLanguageTag("zh-Hant-TW"), simplifiedOnly))
    }

    // ── Step 4 alias: Norwegian macrolanguage code (v0.79.0 QA) ──────────────

    /**
     * "no" / "no-NO" (the macrolanguage code Google Play's store locale uses)
     * must find the Bokmål translation shipped as "nb" — Android's own resource
     * matcher treats the two as compatible, and the screenshot suite feeds the
     * store locale "no-NO" through this function.
     */
    @Test fun `no and no-NO resolve to nb`() {
        val withNorwegian = supported + "nb"
        assertEquals("nb", LocaleDetector.detect(Locale.forLanguageTag("no"), withNorwegian))
        assertEquals("nb", LocaleDetector.detect(Locale.forLanguageTag("no-NO"), withNorwegian))
        // The direct code keeps working, of course.
        assertEquals("nb", LocaleDetector.detect(Locale.forLanguageTag("nb-NO"), withNorwegian))
    }
}
