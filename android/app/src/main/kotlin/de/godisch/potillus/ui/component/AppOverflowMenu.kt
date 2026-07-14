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
import androidx.compose.material.icons.automirrored.filled.MenuBook
import androidx.compose.material.icons.filled.LocalHospital
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
 *   three entries: Settings, Help and Copyright. Selecting an entry closes the
 *   menu and invokes the matching callback; the actual navigation is the
 *   caller's responsibility (see [de.godisch.potillus.ui.nav.AppNavigation]),
 *   which keeps this component free of any navigation dependency.
 *
 * @param onOpenSettings Invoked when the "Settings" entry is chosen.
 * @param onOpenHelp     Invoked when the "Help" entry is chosen (opens the
 *                       in-app user guide viewer).
 * @param onOpenCopyright Invoked when the "Copyright" entry is chosen (opens the
 *                       Copyright viewer: the combined COPYING.md + LICENSE.md).
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
    onOpenCopyright: () -> Unit,
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
            // The help entry uses a medical-cross glyph (the "Red Cross" cross
            // shape). No explicit `tint` is set, so the icon inherits the menu's
            // ambient content colour and blends in with the theme — i.e. it is
            // NOT drawn red, only cross-shaped.
            leadingIcon = { Icon(Icons.Filled.LocalHospital, contentDescription = null) },
            onClick = {
                expanded = false
                onOpenHelp()
            },
        )
        DropdownMenuItem(
            text = { Text(stringResource(R.string.about)) },
            // The about entry carries the open-book glyph (formerly used by the
            // help entry); a book reads naturally as "read about the app and its
            // licences". It opens the About screen, which links on to the full
            // copyright and licence document.
            leadingIcon = { Icon(Icons.AutoMirrored.Filled.MenuBook, contentDescription = null) },
            onClick = {
                expanded = false
                onOpenCopyright()
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
    }
}
