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
// Theme.kt – Material 3 colour scheme assembly and PotillusTheme entry point
// =============================================================================
//
// MATERIAL 3 DESIGN TOKENS:
//   Material 3 defines a set of semantic "colour roles" (primary, surface,
//   error, …) rather than hard-coded hex values. Each role is referenced
//   throughout the UI via MaterialTheme.colorScheme.primary etc.
//   By plugging in different [ColorScheme] objects, the entire app switches
//   theme without changing a single line of screen code.
//
// darkColorScheme / lightColorScheme:
//   Helper functions from the material3 library that return a [ColorScheme]
//   with sensible defaults for all 27 colour roles. We override only the
//   roles we customise; the rest fall back to Material's built-in values.
//
// PotillusTheme COMPOSABLE:
//   Wraps the app's composition tree with [MaterialTheme], providing the
//   colour scheme and typography to all descendant composables.
//   Called once at the top level in MainActivity.MainContent.
// =============================================================================

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import de.godisch.potillus.domain.model.ThemeMode

/**
 * Material 3 colour scheme for the "Nacht" (dark) theme.
 *
 * Based on RAL 5004 Schwarzblau. All colour values are defined in [Color.kt].
 * Roles not listed here fall back to Material 3's default dark-theme values.
 */
private val NachtColors = darkColorScheme(
    primary = NachtPrimary,
    onPrimary = NachtOnPrimary,
    primaryContainer = NachtPrimaryContainer,
    onPrimaryContainer = NachtOnPrimaryContainer,
    secondary = NachtOnSurfaceVariant,
    onSecondary = NachtOnPrimary,
    secondaryContainer = NachtSurfaceVariant,
    onSecondaryContainer = NachtOnSurface,
    surface = NachtSurface,
    onSurface = NachtOnSurface,
    surfaceVariant = NachtSurfaceVariant,
    onSurfaceVariant = NachtOnSurfaceVariant,
    background = NachtBackground,
    onBackground = NachtOnSurface,
    outline = NachtOutline,
    error = ErrorColorDark, // lightened red passes WCAG AA on dark bg
)

/**
 * Material 3 colour scheme for the "Schiefer" (light) theme.
 *
 * Named after the slate-blue (Schieferblau) tint of the background.
 */
private val SchieferColors = lightColorScheme(
    primary = SchieferPrimary,
    onPrimary = SchieferOnPrimary,
    primaryContainer = SchieferPrimaryContainer,
    onPrimaryContainer = SchieferOnPrimaryContainer,
    secondary = SchieferOnSurfaceVariant,
    onSecondary = SchieferOnPrimary,
    secondaryContainer = SchieferSurfaceVariant,
    onSecondaryContainer = SchieferOnSurface,
    surface = SchieferSurface,
    onSurface = SchieferOnSurface,
    surfaceVariant = SchieferSurfaceVariant,
    onSurfaceVariant = SchieferOnSurfaceVariant,
    background = SchieferBackground,
    onBackground = SchieferOnSurface,
    outline = SchieferOutline,
    error = ErrorColorLight,
)

/**
 * Root theme composable for Libellus Potionis.
 *
 * Selects the correct [ColorScheme] based on [themeMode]:
 * - [ThemeMode.SYSTEM] → follows the OS dark/light setting via [isSystemInDarkTheme].
 * - [ThemeMode.DAY]    → always [SchieferColors].
 * - [ThemeMode.NIGHT]  → always [NachtColors].
 *
 * All screens and components inherit the resulting [MaterialTheme] via Compose's
 * ambient (implicit) parameter mechanism.
 *
 * @param themeMode  User's theme preference; defaults to [ThemeMode.SYSTEM].
 * @param content    The composition tree to theme (the entire app).
 */
@Composable
fun PotillusTheme(
    themeMode: ThemeMode = ThemeMode.SYSTEM,
    content: @Composable () -> Unit,
) {
    val darkTheme = when (themeMode) {
        ThemeMode.SYSTEM -> isSystemInDarkTheme()
        ThemeMode.DAY -> false
        ThemeMode.NIGHT -> true
    }
    val colorScheme = if (darkTheme) NachtColors else SchieferColors

    MaterialTheme(
        colorScheme = colorScheme,
        typography = AppTypography,
        content = content,
    )
}
