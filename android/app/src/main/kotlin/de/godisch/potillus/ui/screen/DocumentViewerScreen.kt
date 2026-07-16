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

import androidx.annotation.RawRes
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.produceState
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalResources
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import de.godisch.potillus.R
import de.godisch.potillus.ui.component.MarkdownText
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * A read-only viewer for a bundled text document held in `res/raw`.
 *
 * It backs two kinds of destination:
 *   - **Help**       → the localized user guide `R.raw.usersguide`, rendered as
 *                      Markdown ([renderAsMarkdown] = true).
 *   - **Licences**   → `R.raw.license_gpl3` / `license_apache2` / `license_gpl2`,
 *                      each a verbatim copy of a project-root licence file,
 *                      linked from the About screen. Rendered as Markdown too:
 *                      the texts are plain prose and degrade gracefully.
 *
 * LOCALE RESOLUTION
 *   The text is read from [LocalResources]. Because the app selects a
 *   per-app locale via `AppCompatDelegate.setApplicationLocales`, that resources
 *   instance
 *   already reflects the chosen language, so `openRawResource(R.raw.usersguide)`
 *   returns the matching `raw-<locale>` variant automatically — and falls back
 *   to the default `raw/` (English) for languages without a translated guide.
 *   The licence texts exist only as the default `raw/license_*.md`, so they are
 *   always shown in their original (English) form, as intended: a translated
 *   licence is not the licence.
 *
 * The content is read with [produceState] on [Dispatchers.IO] and cached for the
 * lifetime of the composition (re-read only when `rawRes` changes). The raw
 * resources are a few kilobytes, but keeping even this small decode off the main
 * thread avoids any disk I/O during composition.
 *
 * @param title           Top-bar title, ALREADY RESOLVED. A plain String, not a
 *                        `@StringRes` id, because the two kinds of caller differ:
 *                        the guide passes a localized `stringResource`, while the
 *                        licence viewers pass fixed English literals — their
 *                        titles name legal documents and are not translated. This
 *                        is also the signature the iOS `DocumentViewerScreen`
 *                        already has.
 * @param rawRes          Raw resource holding the document text.
 * @param renderAsMarkdown Whether to render via [MarkdownText] or as plain
 *                        monospaced text.
 * @param onBack          Invoked when the Up arrow is tapped.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DocumentViewerScreen(
    title: String,
    @RawRes rawRes: Int,
    renderAsMarkdown: Boolean,
    onBack: () -> Unit = {},
) {
    val resources = LocalResources.current
    // Read the bundled raw resource OFF the main thread. Although the asset ships
    // inside the APK and is small, reading it inside a remember{} block runs the
    // decode on the main thread during composition. produceState performs the read
    // on Dispatchers.IO and seeds the UI with an empty string until it completes,
    // re-running whenever rawRes changes. The brief empty state is invisible in
    // practice (the read is sub-millisecond) but keeps all I/O off the UI thread.
    //
    // LocalResources.current (not LocalContext.current.resources) is used so the
    // read is re-invalidated on a Configuration change — the per-app locale switch
    // therefore re-reads the correct raw-<locale> variant.
    val text by produceState(initialValue = "", rawRes) {
        value = withContext(Dispatchers.IO) {
            runCatching {
                resources.openRawResource(rawRes)
                    .bufferedReader()
                    .use { it.readText() }
            }.getOrDefault("")
        }
    }

    Scaffold(
        contentWindowInsets = WindowInsets(0),
        topBar = {
            TopAppBar(
                title = { Text(title) },
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
        // No bottom navigation bar on this screen, so the scrolling content adds
        // the system navigation-bar inset itself (mirrors SettingsScreen) to keep
        // the last line above the gesture/button bar. Order of modifiers:
        //   1. consume the Scaffold inset (top app bar height)
        //   2. become vertically scrollable
        //   3. pad the scrollable content by the navigation-bar inset
        //   4. apply a uniform 16dp reading margin
        val scroll = rememberScrollState()
        val contentModifier = Modifier
            .fillMaxSize()
            .padding(paddingValues)
            .verticalScroll(scroll)
            .windowInsetsPadding(WindowInsets.navigationBars)
            .padding(16.dp)

        if (renderAsMarkdown) {
            MarkdownText(markdown = text, modifier = contentModifier)
        } else {
            Text(
                text = text,
                style = MaterialTheme.typography.bodySmall,
                fontFamily = FontFamily.Monospace,
                modifier = contentModifier,
            )
        }
    }
}
