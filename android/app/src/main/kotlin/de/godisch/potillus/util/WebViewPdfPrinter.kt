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
package de.godisch.potillus.util

import android.annotation.SuppressLint
import android.content.Context
import android.print.PrintAttributes
import android.print.PrintManager
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.annotation.MainThread

// =============================================================================
// WebViewPdfPrinter – renders report HTML to PDF via the system print dialog
// =============================================================================
//
// WHY THE SYSTEM PRINT DIALOG (and not a silent write to Downloads)?
//   Turning an HTML document into a PDF on Android, without any third-party
//   library, goes through the platform print framework: a WebView produces a
//   PrintDocumentAdapter, and PrintManager.print() hands it to the system. The
//   system then shows its print UI, where the user picks "Save as PDF" (or a
//   real printer) and chooses where the file goes.
//
//   The alternative — driving the PrintDocumentAdapter ourselves to write a file
//   silently — is not cleanly possible from app code, because the framework's
//   LayoutResultCallback / WriteResultCallback constructors are not public. The
//   only workarounds are a third-party dependency or declaring a helper class in
//   the framework's own `android.print` package (a fragile hack). We deliberately
//   chose the fully-supported system-dialog route instead. Consequence: the PDF
//   export no longer returns an ExportResult to share — the print UI owns saving
//   and sharing from here on.
//
// PRIVACY:
//   loadDataWithBaseURL(null, …) renders the in-memory HTML with NO base URL and
//   NO network access; JavaScript stays disabled (the WebView default). Nothing
//   leaves the device. This matches the app's no-network design.
//
// THREADING:
//   WebView and PrintManager are main-thread-only. Call [print] from the UI
//   (a LaunchedEffect in StatsScreen does exactly this).
// =============================================================================

// StaticFieldLeak: WebViewPdfPrinter is a singleton (object), so its `retained`
// WebView field is effectively a static reference to a View — which lint flags as a
// context leak, anchored on the object declaration. It is safe here and deliberately
// suppressed: the WebView is created from the APPLICATION context (see [print]),
// never an Activity, and is cleared as soon as the print adapter is handed over (any
// stale instance is destroyed on re-entry), so no Activity / short-lived context can
// be retained. The annotation sits on the object because lint reports the finding at
// the object declaration; that scope also covers the `retained` field below.
@SuppressLint("StaticFieldLeak")
object WebViewPdfPrinter {

    /**
     * Holds the most recent WebView until its print adapter has been handed to the
     * system. A WebView that is garbage-collected before [PrintManager.print] has
     * taken its adapter can abort the print job, so we keep a strong reference for
     * the brief window between [WebView.loadDataWithBaseURL] and the page-finished
     * callback. It is cleared again as soon as the job is submitted.
     *
     * The retained WebView is created from the APPLICATION context (see [print]),
     * never an Activity context: if the page-finished callback never fires (e.g. a
     * load failure) this field would otherwise pin the whole Activity for the
     * process lifetime. [print] also abandons any still-pending previous WebView
     * before starting a new job, so a rapid second call cannot silently drop a live
     * reference.
     */
    private var retained: WebView? = null

    /**
     * Loads [html] into an off-screen WebView and, once it has finished laying out,
     * opens the system print dialog for it.
     *
     * @param context A UI (Activity) context; the print dialog is an Activity, so an
     *                Activity context is the reliable choice (Compose's
     *                `LocalContext.current` provides one).
     * @param html    The complete report HTML produced by [PdfReportBuilder.buildHtml].
     * @param jobName Print-job name; print services derive the saved PDF's file name
     *                from it (see [PdfReportBuilder.jobName]).
     */
    @MainThread
    fun print(context: Context, html: String, jobName: String) {
        // Re-entrancy guard: if a previous job's WebView is still awaiting its
        // page-finished callback, abandon it (destroy + release) before starting a
        // new one, so the static field never silently drops a live reference.
        retained?.destroy()
        retained = null

        // Create the off-screen WebView from the APPLICATION context, not the
        // passed Activity context. The WebView is parked in the static [retained]
        // field for the async load → page-finished round-trip; parking an
        // Activity-scoped WebView there would leak the entire Activity if the
        // callback never fires. The application context lives for the process
        // lifetime, so retaining it is harmless. The system PrintManager is still
        // obtained from the Activity [context] below, because the print dialog is
        // Activity-scoped UI.
        val webView = WebView(context.applicationContext)

        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView, url: String?) {
                val printManager = context.getSystemService(Context.PRINT_SERVICE) as? PrintManager
                if (printManager == null) {
                    // No print service available; release the reference and bail out.
                    retained = null
                    return
                }
                val adapter = view.createPrintDocumentAdapter(jobName)
                val attributes = PrintAttributes.Builder()
                    .setMediaSize(PrintAttributes.MediaSize.ISO_A4)
                    // Margins are controlled by the template's CSS @page rule, so the
                    // print framework itself adds none.
                    .setMinMargins(PrintAttributes.Margins.NO_MARGINS)
                    .build()

                printManager.print(jobName, adapter, attributes)
                // The system now holds the adapter; we no longer need the WebView.
                retained = null
            }
        }

        // Keep alive across the asynchronous load → page-finished round-trip.
        retained = webView
        // baseUrl = null keeps rendering local and offline.
        webView.loadDataWithBaseURL(null, html, "text/html", "UTF-8", null)
    }
}
