// vim: set et ts=4 sw=4:
// =============================================================================
// Libellus Potionis "Potillus" -- Privacy-Friendly Alcohol Tracker
// Copyright (c) 2026 Martin A. Godisch <android@godisch.de>
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
// =============================================================================

package de.godisch.potillus.ui.screen

import androidx.annotation.RawRes
import androidx.annotation.StringRes
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
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.unit.dp
import de.godisch.potillus.R
import de.godisch.potillus.ui.component.MarkdownText

/**
 * A read-only viewer for a bundled text document held in `res/raw`.
 *
 * It backs both overflow-menu entries added alongside Settings:
 *   - **Help**    → the localized user guide `R.raw.usersguide`, rendered as
 *                   Markdown ([renderAsMarkdown] = true).
 *   - **License** → `R.raw.license` (a verbatim copy of the project's
 *                   `LICENSE.md`), shown as plain monospaced text
 *                   ([renderAsMarkdown] = false) because the GPL text is not
 *                   Markdown and must be displayed exactly as written.
 *
 * LOCALE RESOLUTION
 *   The text is read from [LocalContext]'s resources. Because the app selects a
 *   per-app locale via `AppCompatDelegate.setApplicationLocales`, that context
 *   already reflects the chosen language, so `openRawResource(R.raw.usersguide)`
 *   returns the matching `raw-<locale>` variant automatically — and falls back
 *   to the default `raw/` (English) for languages without a translated guide.
 *   The license has only the default `raw/license.md`, so it is always shown in
 *   its original (English) form, as intended.
 *
 * The content is read once and cached with [remember]; the raw resources are a
 * few kilobytes, so a single synchronous read on first composition is fine and
 * avoids the complexity of a background load.
 *
 * @param titleRes        String resource for the top-bar title.
 * @param rawRes          Raw resource holding the document text.
 * @param renderAsMarkdown Whether to render via [MarkdownText] (guide) or as
 *                        plain monospaced text (license).
 * @param onBack          Invoked when the Up arrow is tapped.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun DocumentViewerScreen(
    @StringRes titleRes: Int,
    @RawRes rawRes: Int,
    renderAsMarkdown: Boolean,
    onBack: () -> Unit = {}
) {
    val context = LocalContext.current
    val text = remember(rawRes) {
        runCatching {
            context.resources.openRawResource(rawRes)
                .bufferedReader()
                .use { it.readText() }
        }.getOrDefault("")
    }

    Scaffold(
        contentWindowInsets = WindowInsets(0),
        topBar = {
            TopAppBar(
                title = { Text(stringResource(titleRes)) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = stringResource(R.string.back),
                            tint = MaterialTheme.colorScheme.onPrimary
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor    = MaterialTheme.colorScheme.primary,
                    titleContentColor = MaterialTheme.colorScheme.onPrimary
                )
            )
        }
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
                modifier = contentModifier
            )
        }
    }
}
