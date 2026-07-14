// vim: set et ts=4 sw=4:
// =============================================================================
// Libellus Potionis - Privacy-Friendly Alcohol Tracker
// Copyright (c) 2026 Martin A. Godisch <martin@godisch.de>
// =============================================================================
//
// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program.  If not, see <https://www.gnu.org/licenses/>.
//
// In addition, as permitted by section 7 of the GNU General Public License,
// this program may carry additional permissions; any such permissions that
// apply to it are stated in the accompanying COPYING.md file.
// =============================================================================

package de.godisch.potillus.ui.screen

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Button
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import de.godisch.potillus.BuildConfig
import de.godisch.potillus.R

// =============================================================================
// AboutScreen — the app's name, version, and the licences it must show.
//
// Reached from the overflow menu (the entry that used to be "Copyright"). This
// is the twin of the iOS AboutScreen: the app's own GPL notice, one line per
// DIRECT dependency grouped by licence, and a button into the full combined
// copyright/GPL document (res/raw/copyright.md, built from COPYING.md +
// LICENSE.md + LICENSE.Apache-2.0.md). The exhaustive licence texts — and the
// transitive closure — live in that document; this screen is the short overview.
//
// WHY THE LICENCE TEXT IS ENGLISH-ONLY, NOT localised.
//   Licence text is a legal artifact: paraphrasing or machine-translating it
//   changes its meaning, and COPYING.md (the source of the bundled document) is
//   itself English-only. So the licence sentences here are fixed English string
//   literals — the same treatment the codebase already gives fixed tokens like
//   Text("ml"). Only the two STRUCTURAL labels a user navigates by — the screen
//   title and the button into the full document — are localised via R.string,
//   matching the iOS about screen's split.
// =============================================================================

@Composable
fun AboutScreen(
    onOpenCopyright: () -> Unit = {},
    onBack: () -> Unit = {},
) {
    Scaffold(
        contentWindowInsets = WindowInsets(0),
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.about)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = stringResource(R.string.back),
                            tint = MaterialTheme.colorScheme.onPrimary,
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    titleContentColor = MaterialTheme.colorScheme.onPrimary,
                ),
            )
        },
    ) { paddingValues ->
        val scroll = rememberScrollState()
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .verticalScroll(scroll)
                .windowInsetsPadding(WindowInsets.navigationBars)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            // Identity: the Latin title and the version, the same two facts the
            // iOS about screen leads with. The version drops any build suffix,
            // as the report footer does. The app name is a proper noun (already
            // unlocalised); "Version" is a fixed English label here.
            Text(
                text = stringResource(R.string.app_name),
                style = MaterialTheme.typography.titleLarge,
                modifier = Modifier.fillMaxWidth(),
                textAlign = TextAlign.Center,
            )
            Text(
                text = "Version ${BuildConfig.VERSION_NAME.substringBefore("-")}",
                style = MaterialTheme.typography.bodyMedium,
                modifier = Modifier.fillMaxWidth(),
                textAlign = TextAlign.Center,
            )

            HorizontalDivider()

            // The app's own licence, stated plainly. English-only (legal text);
            // the full GPL is in the linked document.
            Text(
                text = "Licence",
                style = MaterialTheme.typography.titleSmall,
                color = MaterialTheme.colorScheme.primary,
            )
            Text(
                text = "Libellus Potionis is free software under the GNU GPL, " +
                    "version 3 or later.",
                style = MaterialTheme.typography.bodySmall,
            )

            HorizontalDivider()

            // Open-source components: the DIRECT dependencies, grouped by licence.
            // English-only, one line per group; the exhaustive text and the
            // transitive closure are in the copyright document reachable below.
            Text(
                text = "Open-source components",
                style = MaterialTheme.typography.titleSmall,
                color = MaterialTheme.colorScheme.primary,
            )
            Text(
                text = "AndroidX / Jetpack, the Kotlin runtime, Okio, Guava " +
                    "ListenableFuture and JSpecify — Apache License 2.0.",
                style = MaterialTheme.typography.bodySmall,
            )
            Text(
                text = "desugar_jdk_libs — GNU GPL v2 with the Classpath Exception.",
                style = MaterialTheme.typography.bodySmall,
            )

            Button(
                onClick = onOpenCopyright,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Text(stringResource(R.string.copyright))
            }
        }
    }
}
