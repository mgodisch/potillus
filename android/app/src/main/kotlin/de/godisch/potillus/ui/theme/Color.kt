/* vim: set et ts=4:
 * =============================================================================
 * Libellus Potionis - Privacy-Friendly Alcohol Tracker
 * Copyright (c) 2026 Martin A. Godisch <martin@godisch.de>
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

/**
 * RAL 5004 Schwarzblau, darkened – the Nacht theme's canvas.
 *
 * The one brand constant the themes below actually read. Two siblings stood
 * here until the v0.84.0 QA review: `Schwarzblau` (#1A1E2B), which only ever
 * appears as `ic_launcher_background` in res/values/colors.xml where a Kotlin
 * constant cannot reach, and `SchwarzblauHell` (#2D3448), which no theme used
 * at all. Both were removed rather than kept as documentation of a link that
 * did not exist; the launcher keeps its own hex value, as it must.
 */
val SchwarzblauDunkel = Color(0xFF0D1018)

// ── THEME "NACHT" (Dark) ──────────────────────────────────────────────────────

val NachtBackground = SchwarzblauDunkel // near-black canvas
val NachtSurface = Color(0xFF1E2538) // card / sheet surface
val NachtSurfaceVariant = Color(0xFF252D45) // progress track, chip background
val NachtHeatmapEmpty = Color(0xFF303A57) // year heat-map: a day with no entry
val NachtOutline = Color(0xFF2A3050) // dividers, borders
val NachtOnSurface = Color(0xFFE4E8F0) // primary text
val NachtOnSurfaceVariant = Color(0xFF8896B3) // secondary text, captions
val NachtPrimary = Color(0xFF5B8DD9) // steel-blue accent
val NachtOnPrimary = Color(0xFF0D1018) // text on primary (dark bg)
val NachtPrimaryContainer = Color(0xFF1E2A40) // card accent surface
val NachtOnPrimaryContainer = Color(0xFFB8D0F5) // text on primaryContainer

// Status colours, dark theme. Declared here rather than inline in the role
// functions below, so every hex value the app draws lives in exactly one place.
// The measured ratios and the reasoning behind each choice are in the STATUS
// COLOURS note further down; do not change a value here without reading it.
val NachtDanger = Color(0xFFDD2C2C) // over-limit dots, bars, icons
val NachtDangerText = Color(0xFFDF3A3A) // over-limit text and trend glyphs
val NachtDangerOnSelection = Color(0xFF7A0014) // over-limit dot on a selected cell
val NachtSuccess = Color(0xFF4CAF50) // within limits, streaks, dry days
val NachtWarning = Color(0xFFE8A020) // approaching the limit

// ── THEME "SCHIEFER" (Light) ──────────────────────────────────────────────────
//
// SchieferOnSurfaceVariant carries every secondary caption in the light theme,
// and it is the one value here picked against a contrast threshold rather than
// by eye. MEASURED (WCAG 2.2, sRGB):
//
//   #5D6C93  5.21 : 1 on SchieferSurface (#FFFFFF), 4.57 : 1 on SchieferBackground
//
// Both clear the 4.5 : 1 small-text requirement. The predecessor #6878A0 did
// not: 4.39 on the cards and 3.85 on the background. The second figure is the
// one that matters and the one an earlier review missed by measuring against the
// cards alone -- captions appear on both surfaces.
//
// The shade is the smallest step that clears both, deliberately: it keeps 2.83 : 1
// against SchieferOnSurface below, so the caption still reads as subordinate to
// the primary text rather than merging with it. Darkening further would buy
// contrast the criterion does not ask for and spend the hierarchy that makes a
// caption a caption.
//
// SchieferSurfaceVariant is not a text background -- it is the progress-bar track
// only -- so the 4.05 : 1 a caption would have on it does not arise. (3.41 : 1,
// the figure an earlier version of this comment quoted, was the predecessor
// #6878A0 on that track.)

val SchieferBackground = Color(0xFFEDF0F8) // slate-white canvas
val SchieferSurface = Color(0xFFFFFFFF) // pure white cards
val SchieferSurfaceVariant = Color(0xFFDDE3F0) // light bluish-grey
val SchieferOutline = Color(0xFFC8D0E4) // soft blue-grey borders
val SchieferOnSurface = Color(0xFF1C2745) // deep navy text
val SchieferOnSurfaceVariant = Color(0xFF5D6C93) // medium navy-grey captions
val SchieferPrimary = Color(0xFF2F3F6E) // navy accent
val SchieferOnPrimary = Color(0xFFFFFFFF) // white text on primary
val SchieferPrimaryContainer = Color(0xFFD8E0F5) // light blue card accent
val SchieferOnPrimaryContainer = Color(0xFF1C2745) // text on primaryContainer

// Status colours, light theme. Same rule as the dark block above: one place per
// value, reasoning in the STATUS COLOURS note below.
val SchieferDanger = Color(0xFF960018) // over-limit dots, bars, icons
val SchieferDangerText = Color(0xFF960018) // over-limit text and trend glyphs
val SchieferDangerOnSelection = Color(0xFFF08080) // over-limit dot on a selected cell
val SchieferSuccess = Color(0xFF2E7D32) // within limits, streaks, dry days
val SchieferWarning = Color(0xFFA67C00) // approaching the limit

// ── Raw semantic colours (used only in Theme.kt) ──────────────────────────────
//
// These are NOT used directly in screen code. Always call errorColor() etc.
// (the @Composable helpers below) so the correct variant is picked for the
// active theme.

/** Error red for the light ("Schiefer") theme. WCAG AA: 5.73:1 on SchieferBackground. */
internal val ErrorColorLight = Color(0xFFB3261E)

/** Error red for the dark ("Nacht") theme. Lightened for WCAG AA: 5.28:1 on NachtBackground. */
internal val ErrorColorDark = Color(0xFFCF6679)

// ── Semantic colour helpers ───────────────────────────────────────────────────
//
// These @Composable functions return the correct colour for the current theme.
// Using functions (not constants) ensures the colour responds to theme changes
// at runtime (e.g. when the user switches from light to dark in Settings).
//
// Achieved WCAG AA contrast ratios:
//   errorColor   – Slate 5.73:1 ✓ / Night 5.28:1 ✓
//   successColor – Slate 4.50:1 ✓ / Night 6.84:1 ✓
//   warningColor – Slate 3.35:1 ✓ / Night 8.58:1 ✓ (dot needs ≥ 3:1 per WCAG 1.4.11)
//
// =============================================================================
// STATUS COLOURS — the reasoning behind the values
// =============================================================================
//
// Read this before changing a status colour or adding one. Every rule below cost
// a round of measurement, and each was reached by rejecting an option that
// looked obvious. Written down so the next change starts from the conclusion
// rather than repeating the argument.
//
// 1. TWO THRESHOLDS, NOT ONE
//    WCAG asks 4.5:1 of a colour that carries small TEXT (1.4.3) and 3:1 of one
//    that fills a shape — a dot, a bar, an icon, a chart line (1.4.11). Large
//    text, meaning ≥ 18 sp normal or ≥ 14 sp BOLD, drops to 3:1 as well. Note
//    that FontWeight.Medium does NOT count as bold; the threshold wants 700.
//    Consequence: the same semantic colour pulls in two directions, which is why
//    there is a separate danger colour for text.
//
// 2. MEASURE AGAINST EVERY BACKGROUND THE COLOUR ACTUALLY MEETS
//    A single figure is almost always the flattering one. The caption colour was
//    recorded at 4.39:1 for two releases — true against the white cards, while
//    the same text on the screen background sat at 3.85:1. Before quoting a
//    ratio, list the surfaces the colour appears on: background, surface,
//    primary (selected cells), primaryContainer. surfaceVariant carries no text
//    in this app; it is the progress-bar track only.
//
// 3. THE TWO THEMES NEED DIFFERENT HEX VALUES
//    A value tuned for one is wrong for the other, and unifying the literal
//    trades one theme away. The dark danger red on the light theme's white cards
//    falls to 4.70:1 (and to 4.12:1 on the background) where the light value
//    has 9.09:1.
//
// 4. LIGHTENING IS NOT ALWAYS THE FIX
//    Contrast rises by moving AWAY from the background's luminance, and which
//    direction that is depends on the background. Against the dark theme's cards
//    a lighter red helps. Against the dark theme's SELECTED cell — a mid-luminance
//    blue — lightening makes it worse: #DD2C2C sits at 1.40:1 there and #E66363
//    at 1.01:1, near-invisible. That is why the selection variant is DARKER in
//    the dark theme and LIGHTER in the light one.
//
// 5. SATURATION IS NOT WHAT CHANGES WHEN A RED "GOES PINK"
//    Across the whole #DD2C2C…#E66363 range the HSL saturation is a constant
//    72 %; only lightness moves. The pink impression is perceptual. It is a real
//    design constraint even so — it is why the danger red stops short of the
//    4.5:1 text threshold instead of reaching it.
//
// 6. HUE DIFFERENCE IS NOT CONTRAST
//    A saturated red on a mid blue reads clearly to normal colour vision and
//    still measures 1.40:1, because the two are close in luminance. Such a pair
//    disappears for a viewer with red-green colour vision deficiency and in
//    greyscale. Trust the measurement over the impression — including the
//    maintainer's own impression on a good display.
//
// 7. NEVER DRAW A DOT IN THE COLOUR OF ITS OWN BACKGROUND
//    The month grid filled a selected cell with `primary` and drew the
//    under-limit dot in `primary` as well: 1.00:1, invisible. Anything painted
//    on a selected cell takes its colour from the container pair instead —
//    primaryContainer for the neutral dot, [dangerOnSelectionColor] for the
//    over-limit one.
//
// 8. WHAT IS DELIBERATELY LEFT UNMET
//    [dangerTextColor] reaches 3.49:1 in the dark theme, short of the 4.5:1 its
//    text sites would need. Closing it needs a red light enough to read as pink,
//    which was measured, compared side by side and rejected. The open question
//    is not which red but whether those sites should carry red text at all — a
//    dot or a bar beside them already carries the state. Do not "fix" this by
//    lightening the red; that decision has been made and reversed once already.
//
// 9. WHEN ADDING A STATUS COLOUR
//    Declare it as a named constant in both theme blocks above. Work out which
//    surfaces it meets, decide text or non-text for each use, measure every
//    pair, and record the figures in the function's KDoc. If a value cannot meet
//    its threshold, say so in the KDoc and add it to the roadmap rather than
//    leaving the reader to assume it conforms.
// =============================================================================

/** Returns the theme's error red (set per theme in [de.godisch.potillus.ui.theme.Theme]). */
@Composable fun errorColor() = MaterialTheme.colorScheme.error

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
 * The red for GRAPHICAL over-limit elements: traffic-light bullets, calendar
 * over-limit dots, the limit line and the over-limit bars in the charts, and the
 * delete icons. Text uses [dangerTextColor] instead — see there for why the two
 * differ in the dark theme.
 *
 * MEASURED (WCAG 2.2 contrast, sRGB):
 *
 *   dark  #DD2C2C  3.25 : 1 on NachtSurface (#1E2538), 4.05 : 1 on NachtBackground
 *   light #960018  9.09 : 1 on SchieferSurface (#FFFFFF), 7.97 : 1 on the background
 *
 * A dot, a bar and an icon are non-text, so the requirement is 3 : 1 (WCAG
 * 1.4.11) and both values clear it. This is the fully saturated shade the app is
 * designed around; lightening it to serve the text threshold as well was tried
 * and reverted, because a red light enough for 4.5 : 1 reads as pink and the
 * signal loses its character exactly where it matters most.
 *
 * The two themes carry different hex values on purpose. A single value cannot
 * serve both: the dark theme's red on the light theme's white cards falls to
 * 4.70 : 1, far below the 9.09 : 1 it has today.
 */
@Composable fun dangerRedColor() = if (isDarkTheme()) NachtDanger else SchieferDanger

/**
 * The fill of a year heat-map cell with nothing logged.
 *
 * MEASURED (CIE L*, sRGB), against the card the grid sits on:
 *
 *   light #DDE3F0  L* 90.1 on SchieferSurface (#FFFFFF)  -> delta L* 9.9
 *   dark  #303A57  L* 24.8 on NachtSurface   (#1E2538)  -> delta L* 9.9
 *
 * WHY DELTA L* AND NOT A CONTRAST RATIO
 *   This cell has to be distinguishable from the card BEHIND it, because a day
 *   with no entry and a day outside the drawn window (which is not painted at
 *   all) must not look alike. Reported as a WCAG ratio, the light theme sits at
 *   1.29 : 1 and reads well on a device, while the dark theme sat at 1.12 : 1 and
 *   read as nothing at all — the ratio barely separates the two cases, so it is
 *   the wrong instrument here. Lightness difference does separate them: 9.9
 *   against 3.9. The dark value is chosen to match the light theme's 9.9, which
 *   was judged good on hardware, keeping the same hue as the surface it sits on.
 *
 *   The 3:1 of WCAG 1.4.11 is deliberately NOT the target. It would make an empty
 *   day compete with the days that carry data (4.54 : 1 and 3.25 : 1 in the dark
 *   theme), which inverts the grid's meaning: the reading is in the filled cells.
 *
 *   Judge changes to these two values on a device, in both themes, and re-measure
 *   delta L* rather than the ratio.
 */
@Composable fun heatmapEmptyColor() = if (isDarkTheme()) NachtHeatmapEmpty else SchieferSurfaceVariant

/**
 * The red for over-limit TEXT and for the trend arrow glyphs that sit inside a
 * line of text: the days-over-limit values and the trend value in the statistics
 * screen, the month-trend arrow and the BAC readout on the today screen, and the
 * delete confirmations.
 *
 * MEASURED (WCAG 2.2 contrast, sRGB):
 *
 *   dark  #DF3A3A  3.49 : 1 on NachtSurface (#1E2538), 4.35 : 1 on NachtBackground
 *   light #960018  9.09 : 1 on SchieferSurface (#FFFFFF), 7.97 : 1 on the background
 *
 * WHY THIS IS A SEPARATE FUNCTION
 *   WCAG asks more of a colour that carries letters than of one that fills a
 *   shape: 4.5 : 1 for small text against 3 : 1 for a non-text indicator. The two
 *   uses therefore pull the shade in opposite directions, and one value cannot
 *   sit at the optimum of both. Splitting them lets the graphical red stay
 *   saturated while the text red moves a step toward the threshold.
 *
 *   3.49 : 1 does not reach 4.5 : 1, and this function does not pretend it does.
 *   The question left open is whether those sites should carry red text at all,
 *   given that a dot or a bar beside them already carries the state. Until that
 *   is decided, this is the closest step to the threshold that keeps the colour
 *   recognisably the same red as the dots beside it.
 *
 *   The arrow glyphs are grouped with text, not with graphics, because they are
 *   drawn as characters inside a text run and must match the value they sit next
 *   to. In the light theme both functions return the same value; the split
 *   exists for the dark theme, where the backgrounds are close to the red.
 */
@Composable fun dangerTextColor() = if (isDarkTheme()) NachtDangerText else SchieferDangerText

/**
 * The over-limit red for a dot drawn ON a selected calendar cell, where the
 * background is the theme's `primary` rather than a surface.
 *
 * MEASURED against the selected cell (WCAG 2.2, sRGB):
 *
 *   dark  #7A0014 on NachtPrimary (#5B8DD9)     3.40 : 1
 *   light #F08080 on SchieferPrimary (#2F3F6E)  3.94 : 1
 *
 * Both clear the 3 : 1 that WCAG 1.4.11 asks of a non-text indicator.
 *
 * WHY A FOURTH RED EXISTS
 *   None of the three others reaches the threshold on this background. Measured
 *   there, [dangerRedColor] gives 1.40 (dark) and 1.12 (light), [dangerTextColor]
 *   1.30 and 1.12, and Material's error role 1.07 and 1.56. The selected cell is
 *   a mid-luminance blue in the dark theme and a dark navy in the light one, so
 *   the reds sit either side of it without ever clearing it; see rule 4 in the
 *   STATUS COLOURS note above. Material's `onError` was checked too and rules
 *   itself out: it is white in the light theme, which would make the over-limit
 *   dot indistinguishable from the neutral one.
 *
 *   The name says "on selection" rather than naming a shade, so it stays clear
 *   that this is an exception for one state and not a third red in the palette.
 *   The claim "the app uses two reds" holds everywhere a cell is not selected.
 */
@Composable fun dangerOnSelectionColor() =
    if (isDarkTheme()) NachtDangerOnSelection else SchieferDangerOnSelection

/** Returns a green that passes WCAG AA against the current theme's background. */
@Composable fun successColor() = if (isDarkTheme()) NachtSuccess else SchieferSuccess

/**
 * Returns an amber/gold that passes WCAG AA against the current theme's background.
 *
 * LIGHT value = gold #A67C00 (R166 G124 B0).
 *   The earlier amber-700 (#B45309) still read as orange-red on the small
 *   traffic-light dot: its red channel (180) dominated its green (83), so YELLOW
 *   sat too close to the danger red (#960018). #A67C00 raises the green channel
 *   relative to red and drops blue to zero, shifting the hue clearly towards
 *   gold/yellow while staying dark enough to keep contrast.
 *
 *   The tension is fundamental on this bluish-white canvas: a *brighter* yellow
 *   has higher luminance and therefore LOWER contrast against the light
 *   background, so a pure neon yellow can never satisfy WCAG. #A67C00 is the
 *   compromise — visibly yellow yet still compliant:
 *     • vs background #EDF0F8 : 3.35:1  (≥ 3:1 required for a non-text indicator,
 *                                        WCAG 1.4.11); vs a white card it is 3.82:1.
 *     • vs danger red #960018 : 2.38:1  (well separated, so the two dots no longer
 *                                        look alike).
 *
 * DARK value = #E8A020 (unchanged): on the near-black Nacht canvas a bright amber
 * already has ample contrast and an unmistakably yellow hue.
 */
@Composable fun warningColor() = if (isDarkTheme()) NachtWarning else SchieferWarning
