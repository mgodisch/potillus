/* vim: set et ts=4:
 * =============================================================================
 * Libellus Potionis "Potillus" -- Privacy-Friendly Alcohol Tracker
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
// Color.kt – Brand colour palette and semantic colour helpers
// =============================================================================
//
// TWO THEMES:
//   "Nacht"    = dark theme  – deep navy background, steel-blue accent
//   "Schiefer" = light theme – slate-white background, navy accent
//
// COLOUR ROLES (Material 3 naming):
//   primary              – main accent colour (app bar, FAB, buttons, progress bars)
//   onPrimary            – text/icons drawn ON TOP of a primary-coloured surface
//   primaryContainer     – softer variant of primary used for cards
//   onPrimaryContainer   – text drawn on primaryContainer
//   surface              – card and sheet background
//   onSurface            – primary text on surface
//   surfaceVariant       – slightly tinted surface (progress bar track, chips)
//   onSurfaceVariant     – secondary text (labels, captions)
//   background           – overall screen background
//   outline              – borders (dividers, text field outlines)
//   error                – destructive actions, over-limit bars
//
// SEMANTIC COLOUR HELPERS:
//   errorColor(), successColor(), warningColor() are @Composable functions so
//   they always return the correct variant for the active theme at call time.
//   NEVER hard-code a colour value in screen/component code – always use a
//   semantic helper or a MaterialTheme.colorScheme.* slot.
//
// WCAG AA CONTRAST (minimum 4.5:1 for text, 3:1 for UI components):
//   See contrast ratios in the @Composable section below.
// =============================================================================

import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance

// ── Shared foundation colour ──────────────────────────────────────────────────

/** RAL 5004 Schwarzblau – the core brand colour used as the base for both themes. */
val Schwarzblau       = Color(0xFF1A1E2B)
/** Slightly lighter variant used for elevated surfaces in the Nacht theme. */
val SchwarzblauHell   = Color(0xFF2D3448)
/** Darker variant used as the Nacht theme's canvas background. */
val SchwarzblauDunkel = Color(0xFF0D1018)

// ── THEME "NACHT" (Dark) ──────────────────────────────────────────────────────

val NachtBackground         = Color(0xFF0D1018)   // near-black canvas
val NachtSurface            = Color(0xFF1E2538)   // card / sheet surface
val NachtSurfaceVariant     = Color(0xFF252D45)   // progress track, chip background
val NachtOutline            = Color(0xFF2A3050)   // dividers, borders
val NachtOnSurface          = Color(0xFFE4E8F0)   // primary text
val NachtOnSurfaceVariant   = Color(0xFF8896B3)   // secondary text, captions
val NachtPrimary            = Color(0xFF5B8DD9)   // steel-blue accent
val NachtOnPrimary          = Color(0xFF0D1018)   // text on primary (dark bg)
val NachtPrimaryContainer   = Color(0xFF1E2A40)   // card accent surface
val NachtOnPrimaryContainer = Color(0xFFB8D0F5)   // text on primaryContainer

// ── THEME "SCHIEFER" (Light) ──────────────────────────────────────────────────

val SchieferBackground         = Color(0xFFEDF0F8)   // slate-white canvas
val SchieferSurface            = Color(0xFFFFFFFF)   // pure white cards
val SchieferSurfaceVariant     = Color(0xFFDDE3F0)   // light bluish-grey
val SchieferOutline            = Color(0xFFC8D0E4)   // soft blue-grey borders
val SchieferOnSurface          = Color(0xFF1C2745)   // deep navy text
val SchieferOnSurfaceVariant   = Color(0xFF6878A0)   // medium navy-grey captions
val SchieferPrimary            = Color(0xFF2F3F6E)   // navy accent
val SchieferOnPrimary          = Color(0xFFFFFFFF)   // white text on primary
val SchieferPrimaryContainer   = Color(0xFFD8E0F5)   // light blue card accent
val SchieferOnPrimaryContainer = Color(0xFF1C2745)   // text on primaryContainer

// ── Raw semantic colours (used only in Theme.kt) ──────────────────────────────
//
// These are NOT used directly in screen code. Always call errorColor() etc.
// (the @Composable helpers below) so the correct variant is picked for the
// active theme.

/** Error red for the light ("Schiefer") theme. WCAG AA: 5.73:1 on SchieferBackground. */
internal val ErrorColorLight = Color(0xFFB3261E)

/** Error red for the dark ("Nacht") theme. Lightened for WCAG AA: 5.28:1 on NachtBackground. */
internal val ErrorColorDark  = Color(0xFFCF6679)

// ── Semantic colour helpers ───────────────────────────────────────────────────
//
// These @Composable functions return the correct colour for the current theme.
// Using functions (not constants) ensures the colour responds to theme changes
// at runtime (e.g. when the user switches from light to dark in Settings).
//
// Achieved WCAG AA contrast ratios:
//   errorColor   – Slate 5.73:1 ✓ / Night 5.28:1 ✓
//   successColor – Slate 4.50:1 ✓ / Night 6.84:1 ✓
//   warningColor – Slate 4.40:1 ✓ / Night 8.58:1 ✓ (dot needs ≥ 3:1 per WCAG 1.4.11)

/** Returns the theme's error red (set per theme in [de.godisch.potillus.ui.theme.Theme]). */
@Composable fun errorColor()   = MaterialTheme.colorScheme.error

/**
 * Returns `true` when the currently active Material theme is dark.
 *
 * WHY NOT [isSystemInDarkTheme]?
 *   `isSystemInDarkTheme()` reads the device-level OS setting and does NOT
 *   respect the app's own [ThemeMode] override (DAY / NIGHT). A user who
 *   forces Night mode in the app while the system is in Light mode would
 *   receive light-mode colours.
 *
 *   Instead we inspect `MaterialTheme.colorScheme.background.luminance()`:
 *   - [NachtBackground] (#0D1018) has luminance ≈ 0.002 → dark
 *   - [SchieferBackground] (#EDF0F8) has luminance ≈ 0.867 → light
 *   This always reflects the scheme that [PotillusTheme] has actually applied,
 *   regardless of whether the choice was made by the system or by the user.
 *
 * `luminance()` is an extension function on [Color] defined in
 * `androidx.compose.ui.graphics`; no additional import is needed.
 */
@Composable
private fun isDarkTheme() = MaterialTheme.colorScheme.background.luminance() < 0.5f

/**
 * Slightly darker, fully saturated red used for traffic-light bullets,
 * calendar over-limit dots, and delete-action icons.
 */
@Composable fun dangerRedColor() =
    if (isDarkTheme()) Color(0xFFDD2C2C) else Color(0xFF960018)

/** Returns a green that passes WCAG AA against the current theme's background. */
@Composable fun successColor() =
    if (isDarkTheme()) Color(0xFF4CAF50) else Color(0xFF2E7D32)

/**
 * Returns an amber that passes WCAG AA against the current theme's background.
 *
 * The light value is amber-700 (#B45309), not the darker amber-800 (#92400E):
 * on a 12 dp traffic-light dot the very dark amber-800 was almost indistinguishable
 * from the danger red (#960018) — same red channel, hardly any green — so the
 * YELLOW state read as RED in light mode (it looked fine in dark mode, where the
 * amber is bright). amber-700 keeps a clearly amber hue and still clears the 3:1
 * contrast a non-text indicator needs (4.40:1 on the light background).
 */
@Composable fun warningColor() =
    if (isDarkTheme()) Color(0xFFE8A020) else Color(0xFFB45309)
