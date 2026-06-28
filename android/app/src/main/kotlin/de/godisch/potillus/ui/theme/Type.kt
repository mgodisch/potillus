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
package de.godisch.potillus.ui.theme

// =============================================================================
// Type.kt – Material 3 typography scale
// =============================================================================
//
// MATERIAL 3 TYPOGRAPHY SCALE:
//   Material 3 defines a set of named text styles organised in three groups:
//     Display   – very large titles (not used in Potillus; default values apply)
//     Headline  – screen-level titles (28sp, 22sp, 18sp)
//     Body      – paragraph text     (16sp, 14sp, 12sp)
//     Label     – captions, chips    (14sp, 11sp)
//     Title     – section headings   (default Material 3 values retained)
//
//   Styles are referenced throughout the UI as:
//     MaterialTheme.typography.headlineLarge
//     MaterialTheme.typography.bodyMedium
//     etc.
//
// FONT CHOICE:
//   FontFamily.Default uses the system default font (Roboto on most Android
//   devices). No external font files are bundled, keeping the APK small and
//   ensuring the app adapts automatically to accessibility font settings.
//
// LETTER SPACING:
//   Negative letter spacing (-0.5sp on headlineLarge) tightens headlines for
//   a more compact, professional appearance. Body text uses the default (0sp).
//   Labels use slightly positive spacing (0.1–0.5sp) for legibility at small sizes.
// =============================================================================

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

/**
 * Custom typography scale for Potillus.
 *
 * Uses the system default font (Roboto / device default) with manual size,
 * weight, and letter-spacing overrides. Unspecified roles (Display, Title)
 * fall back to Material 3's built-in defaults.
 */
val AppTypography = Typography(
    // Headings
    headlineLarge = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.SemiBold,
        fontSize   = 28.sp,
        lineHeight = 36.sp,
        letterSpacing = (-0.5).sp
    ),
    headlineMedium = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.SemiBold,
        fontSize   = 22.sp,
        lineHeight = 28.sp,
        letterSpacing = (-0.3).sp
    ),
    headlineSmall = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Medium,
        fontSize   = 18.sp,
        lineHeight = 24.sp
    ),

    // Body text
    bodyLarge = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Normal,
        fontSize   = 16.sp,
        lineHeight = 24.sp
    ),
    bodyMedium = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Normal,
        fontSize   = 14.sp,
        lineHeight = 20.sp
    ),
    bodySmall = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Normal,
        fontSize   = 12.sp,
        lineHeight = 16.sp
    ),

    // Labels
    labelLarge = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Medium,
        fontSize   = 14.sp,
        letterSpacing = 0.1.sp
    ),
    labelSmall = TextStyle(
        fontFamily = FontFamily.Default,
        fontWeight = FontWeight.Medium,
        fontSize   = 11.sp,
        letterSpacing = 0.5.sp
    )
)
