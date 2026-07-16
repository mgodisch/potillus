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
package de.godisch.potillus.ui.component

import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG
import androidx.biometric.BiometricManager.Authenticators.DEVICE_CREDENTIAL
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Help
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LocalContentColor
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import de.godisch.potillus.R

/**
 * The top-bar overflow menu shared by all four main screens.
 *
 * WHY A SINGLE SHARED COMPOSABLE?
 *   Previously each of the four screens (Today / Calendar / Statistics / Drinks)
 *   carried an identical settings `IconButton` in its `TopAppBar`. That was four
 *   copies of the same UI to keep in sync. This composable replaces all of them
 *   with one definition, so the menu's icon, entries and order live in exactly
 *   one place.
 *
 * BEHAVIOUR
 *   The button shows a "burger" icon ([Icons.Default.Menu]). Tapping it opens a
 *   [DropdownMenu] (an Android "overflow menu") anchored to the button, with
 *   four entries in this order: Settings, Help, "Lock app" and About. Selecting
 *   an entry closes the menu and invokes the matching callback; the actual
 *   navigation is the caller's responsibility (see
 *   [de.godisch.potillus.ui.nav.AppNavigation]), which keeps this component free
 *   of any navigation dependency.
 *
 * WHY ABOUT COMES LAST
 *   It is the entry a user reaches for least often -- version and licences are
 *   looked up once, not daily -- so it yields the prime positions to the three
 *   entries that do real work. iOS orders the same menu identically.
 *
 * WHY THESE GLYPHS
 *   A question mark in a circle for Help and an "i" in a circle for About are
 *   the conventional pair, and the same metaphors iOS uses (`questionmark.circle`
 *   and `info.circle`). The FILL differs by platform on purpose: this menu's
 *   other entries are filled glyphs, so an outlined circle between them would
 *   read as a different weight class, whereas on iOS the outlined SF Symbols are
 *   what sits naturally beside `gearshape` and `lock`. Metaphor is shared; fill
 *   follows each platform's own convention.
 *
 *   Note [Icons.AutoMirrored.Filled.Help], not `Icons.Filled.Help`: the latter
 *   is deprecated in favour of the auto-mirrored set, because a question mark
 *   mirrors in right-to-left layouts. [Icons.Filled.Info] has no auto-mirrored
 *   variant -- an "i" in a circle looks the same either way -- and lives in
 *   material-icons-core rather than -extended.
 *
 * @param onOpenSettings Invoked when the "Settings" entry is chosen.
 * @param onOpenHelp     Invoked when the "Help" entry is chosen (opens the
 *                       in-app user guide viewer).
 * @param onOpenAbout    Invoked when the "About" entry is chosen (opens the
 *                       About screen: version, licence and components).
 * @param onLockApp      Invoked when the "Lock app" entry is chosen (manually locks
 *                       the app). The entry is only shown when an authenticator
 *                       (biometric or device credential) is available — otherwise
 *                       locking would strand the user (Variant A).
 * @param tint           Colour for the burger icon. Defaults to the ambient
 *                       content colour; the main screens pass their top-bar
 *                       `onPrimary` colour so the icon matches the former gear.
 */
@Composable
fun AppOverflowMenu(
    onOpenSettings: () -> Unit,
    onOpenHelp: () -> Unit,
    onOpenAbout: () -> Unit,
    onLockApp: () -> Unit,
    tint: Color = LocalContentColor.current,
) {
    // `expanded` is the only piece of state this component owns: whether the
    // dropdown is currently shown. `remember` keeps it across recompositions;
    // it intentionally does NOT survive process death, which is correct for a
    // transient menu.
    var expanded by remember { mutableStateOf(false) }

    // Variant A: the "Lock app" entry is shown only when the device can actually
    // authenticate (strong biometric OR device credential). Without an
    // authenticator, manually locking would leave no way back in, so the entry is
    // hidden. Computed once per composition instance (cheap binder call, cached).
    val context = LocalContext.current
    val canLock = remember {
        BiometricManager.from(context)
            .canAuthenticate(BIOMETRIC_STRONG or DEVICE_CREDENTIAL) ==
            BiometricManager.BIOMETRIC_SUCCESS
    }

    IconButton(onClick = { expanded = true }) {
        Icon(
            imageVector = Icons.Default.Menu,
            contentDescription = stringResource(R.string.menu),
            tint = tint,
        )
    }

    DropdownMenu(
        expanded = expanded,
        onDismissRequest = { expanded = false },
    ) {
        // Each item closes the menu BEFORE invoking its callback so the dropdown
        // is already dismissed by the time the destination is pushed.
        DropdownMenuItem(
            text = { Text(stringResource(R.string.settings)) },
            leadingIcon = { Icon(Icons.Filled.Settings, contentDescription = null) },
            onClick = {
                expanded = false
                onOpenSettings()
            },
        )
        DropdownMenuItem(
            text = { Text(stringResource(R.string.help)) },
            // A question mark in a circle. No explicit `tint` is set, so the icon
            // inherits the menu's ambient content colour and blends in with the
            // theme.
            leadingIcon = { Icon(Icons.AutoMirrored.Filled.Help, contentDescription = null) },
            onClick = {
                expanded = false
                onOpenHelp()
            },
        )
        // "Lock app" — manual lock (Variant A). Only present when an authenticator
        // is available, so it never leaves the user unable to get back in.
        if (canLock) {
            DropdownMenuItem(
                text = { Text(stringResource(R.string.lock_app)) },
                leadingIcon = { Icon(Icons.Filled.Lock, contentDescription = null) },
                onClick = {
                    expanded = false
                    onLockApp()
                },
            )
        }
        // About LAST, after the conditional "Lock app": on a device with no
        // authenticator the menu simply closes up around the gap, and About is
        // the final entry either way.
        DropdownMenuItem(
            text = { Text(stringResource(R.string.about)) },
            // An "i" in a circle — the conventional glyph for "information about
            // this app", and the metaphor iOS uses with `info.circle`.
            leadingIcon = { Icon(Icons.Filled.Info, contentDescription = null) },
            onClick = {
                expanded = false
                onOpenAbout()
            },
        )
    }
}
