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
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
// Reached from the overflow menu. The twin of the iOS AboutScreen: same
// chapters, same wording, same order. What differs is the component list, and
// only because the two packages genuinely contain different libraries.
//
// WHY THE WHOLE SCREEN IS ENGLISH, NOT LOCALISED
//   Licence text is a legal artifact: paraphrasing or machine-translating it
//   changes its meaning, and a translated licence is not the licence. Once the
//   licence prose is fixed English, translating the labels AROUND it would give
//   a screen that switches language halfway down. So the whole body is fixed
//   English string literals — the same treatment the codebase gives fixed tokens
//   like Text("ml"). Only the TITLE IN THE OVERFLOW MENU is localised (R.string
//   .about, "Über" in German): that label is navigation, not licence text, and a
//   user has to recognise it to get here. The screen's own top bar then says
//   "About", in English, because it is the first line of an English document.
//
// WHY THE LICENCE CHAPTER IS NOT THE FILE HEADER VERBATIM
//   The first three paragraphs are exactly the GPL notice every source file
//   carries. The fourth is not: the file headers end with a POINTER — "any such
//   permissions ... are stated in the accompanying COPYING.md file" — which made
//   sense while the app bundled COPYING.md inside a combined copyright document.
//   It no longer does (0.83.0), so that sentence would send a reader to a file
//   that is not on their phone. The actual App Store Distribution Exception text
//   from COPYING.md stands here instead: the permission is stated where it is
//   read, which is what GPL section 7 asks for.
//
// WHY THE COMPONENT LIST IS SHORTER THAN COPYING.md
//   Only what the APK REDISTRIBUTES is listed. Build- and test-time
//   dependencies carry no redistribution obligation, and the fonts and badge
//   artwork behind the store listing are rasterised into a PNG at build time —
//   the font files themselves never leave the repository. COPYING.md remains the
//   exhaustive inventory and travels with the source.
// =============================================================================

/**
 * The About screen: the app's name and version, its licence stated in full, and
 * the licences of the components compiled into the APK — each linking to its
 * verbatim text. Twin of the iOS AboutScreen.
 *
 * @param onOpenGpl3    Invoked for the "GNU General Public License" link in the
 *                      Licence chapter (pushes `R.raw.license_gpl3`).
 * @param onOpenApache2 Invoked for the "Apache License 2.0" link (pushes
 *                      `R.raw.license_apache2`).
 * @param onOpenGpl2    Invoked for the "GNU General Public License, version 2"
 *                      link (pushes `R.raw.license_gpl2`).
 * @param onBack        Invoked when the Up arrow is tapped.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AboutScreen(
    onOpenGpl3: () -> Unit = {},
    onOpenApache2: () -> Unit = {},
    onOpenGpl2: () -> Unit = {},
    onBack: () -> Unit = {},
) {
    Scaffold(
        contentWindowInsets = WindowInsets(0),
        topBar = {
            TopAppBar(
                // "About", not stringResource(R.string.about): the screen body is
                // an English document, so its own title is too. The MENU entry
                // that leads here is localised.
                title = { Text("About") },
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
            // Identity: the Latin title of the work and the version. The version
            // drops any build suffix, as the report footer does.
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

            SectionHeading("Licence")
            // Paragraphs one to three: the GPL notice, word for word as every
            // source file carries it.
            BodyText(
                "This program is free software: you can redistribute it and/or " +
                    "modify it under the terms of the GNU General Public License as " +
                    "published by the Free Software Foundation, either version 3 of " +
                    "the License, or (at your option) any later version.",
            )
            BodyText(
                "This program is distributed in the hope that it will be useful, " +
                    "but WITHOUT ANY WARRANTY; without even the implied warranty of " +
                    "MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the " +
                    "GNU General Public License for more details.",
            )
            BodyText(
                "You should have received a copy of the GNU General Public License " +
                    "along with this program. If not, see https://www.gnu.org/licenses/.",
            )
            // Paragraph four: the exception itself, from COPYING.md.
            BodyText(
                "As an additional permission under section 7 of the GNU General " +
                    "Public License, version 3, you are allowed to distribute the " +
                    "software through an app store, even if that store has " +
                    "restrictive terms and conditions that are incompatible with the " +
                    "GPL, provided that the source is also available under the GPL " +
                    "with or without this permission through a channel without those " +
                    "restrictive terms and conditions.",
            )
            LicenceLink("GNU General Public License", onOpenGpl3)

            HorizontalDivider()

            SectionHeading("Open-source components")
            BodyText(
                "The libraries below are compiled into this application and are " +
                    "therefore redistributed with it.",
            )
            BodyText(
                "Under the Apache License 2.0: AndroidX / Jetpack (Copyright © The " +
                    "Android Open Source Project); the Kotlin standard library and " +
                    "the kotlinx libraries (Copyright © JetBrains s.r.o. and " +
                    "contributors); Okio (Copyright © Square, Inc.); Guava " +
                    "ListenableFuture (Copyright © The Guava Authors); and JSpecify " +
                    "(Copyright © The JSpecify Authors).",
            )
            LicenceLink("Apache License 2.0", onOpenApache2)
            BodyText(
                "Under the GNU General Public License, version 2, with the OpenJDK " +
                    "Classpath Exception: desugar_jdk_libs (Copyright © Oracle and/or " +
                    "its affiliates and The Android Open Source Project). Only the " +
                    "backported java.time classes selected by core-library desugaring " +
                    "are included. The Classpath Exception permits linking these " +
                    "classes into an independent work without extending the GPLv2 to " +
                    "it.",
            )
            LicenceLink("GNU General Public License, version 2", onOpenGpl2)
        }
    }
}

/** A chapter heading, in the app's primary colour. */
@Composable
private fun SectionHeading(text: String) {
    Text(
        text = text,
        style = MaterialTheme.typography.titleSmall,
        color = MaterialTheme.colorScheme.primary,
    )
}

/**
 * One paragraph of the screen's fixed English prose. Body text, NOT monospaced:
 * these are sentences to read, not a code listing.
 */
@Composable
private fun BodyText(text: String) {
    Text(text = text, style = MaterialTheme.typography.bodySmall)
}

/**
 * A tappable line that opens a verbatim licence text.
 *
 * A [TextButton] rather than an inline `AnnotatedString` link: the paragraphs
 * above are fixed literals, and threading a `LinkAnnotation` through them would
 * mean splitting each sentence around its link. A button on its own line names
 * the document and is a bigger touch target.
 */
@Composable
private fun LicenceLink(text: String, onClick: () -> Unit) {
    TextButton(onClick = onClick, modifier = Modifier.fillMaxWidth()) {
        Text(text)
    }
}
