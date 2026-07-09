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
 * In addition, as permitted by section 7 of the GNU General Public License,
 * this program may carry additional permissions; any such permissions that
 * apply to it are stated in the accompanying COPYING.md file.
 *
 * =============================================================================
 */
package de.godisch.potillus.util

import android.annotation.SuppressLint
import android.content.Context
import android.os.Bundle
import android.os.CancellationSignal
import android.os.ParcelFileDescriptor
import android.print.PageRange
import android.print.PrintAttributes
import android.print.PrintDocumentAdapter
import android.print.PrintManager
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.annotation.MainThread
import java.lang.ref.WeakReference

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
// stale instance is destroyed on re-entry). The one remaining Activity reference —
// the context the page-finished callback needs to reach the PrintManager — is held
// only through a [WeakReference] (see [print]), so a never-firing callback cannot pin
// the Activity either. The annotation sits on the object because lint reports the
// finding at the object declaration; that scope also covers the `retained` field below.
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
     * never an Activity context, so the WebView itself holds no Activity. The only
     * Activity reference in flight — the context the page-finished callback uses to
     * obtain the [PrintManager] — is captured through a [WeakReference], so even if
     * the callback never fires (e.g. a load failure) this field cannot pin the
     * Activity for the process lifetime. [print] also abandons any still-pending
     * previous WebView before starting a new job, so a rapid second call cannot
     * silently drop a live reference.
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
        // lifetime, so retaining it is harmless.
        val webView = WebView(context.applicationContext)

        // The print dialog is Activity-scoped UI, so the PrintManager must be
        // obtained from the Activity [context] — but capturing that context STRONGLY
        // in the WebViewClient closure below would tie the Activity's lifetime to the
        // retained WebView, leaking it if onPageFinished never fires. Hold it weakly
        // instead: when the callback fires normally the Activity is still alive and
        // the reference resolves; if the Activity is already gone there is nothing to
        // print anyway, so bailing out is correct.
        val activityRef = WeakReference(context)

        webView.webViewClient = object : WebViewClient() {
            override fun onPageFinished(view: WebView, url: String?) {
                // Release the retained WebView on EVERY path. `view` (the method
                // parameter) keeps it strongly reachable for the duration of this
                // callback, so the synchronous createPrintDocumentAdapter/print calls
                // below still run against a live WebView even after this clear.
                retained = null

                // Activity gone (weak reference collected): nothing to print.
                val activityContext = activityRef.get() ?: return
                // No print service on this device: bail out (WebView already released).
                val printManager =
                    activityContext.getSystemService(Context.PRINT_SERVICE) as? PrintManager
                        ?: return

                val adapter = view.createPrintDocumentAdapter(jobName)
                val attributes = PrintAttributes.Builder()
                    .setMediaSize(PrintAttributes.MediaSize.ISO_A4)
                    // Margins are controlled by the template's CSS @page rule, so the
                    // print framework itself adds none.
                    .setMinMargins(PrintAttributes.Margins.NO_MARGINS)
                    .build()

                // Hand the framework a DELEGATING adapter whose only addition is
                // deterministic cleanup: the WebView must stay alive while the
                // print framework lays out and writes pages through the real
                // adapter, so it cannot be destroyed here — but once the framework
                // calls onFinish() (job printed, saved OR cancelled), nothing
                // references the WebView any more and destroy() releases its
                // native resources immediately instead of waiting for a GC of an
                // unreachable, never-destroyed WebView.
                printManager.print(jobName, DestroyOnFinishAdapter(adapter, view), attributes)
            }
        }

        // Keep alive across the asynchronous load → page-finished round-trip.
        retained = webView
        // baseUrl = null keeps rendering local and offline.
        webView.loadDataWithBaseURL(null, html, "text/html", "UTF-8", null)
    }

    /**
     * A [PrintDocumentAdapter] that forwards every callback to [delegate] and,
     * when the print framework signals the END of the job via [onFinish],
     * additionally destroys the off-screen [webView] that backs the delegate.
     *
     * onFinish() is invoked exactly once per print job — after successful
     * printing/saving as well as after cancellation — which makes it the one
     * reliable hook for releasing the WebView's native resources (see the
     * comment at the print() call above).
     */
    private class DestroyOnFinishAdapter(
        private val delegate: PrintDocumentAdapter,
        private val webView: WebView,
    ) : PrintDocumentAdapter() {

        /** Forwards the job-start notification unchanged. */
        override fun onStart() = delegate.onStart()

        /** Forwards the layout pass unchanged. */
        override fun onLayout(
            oldAttributes: PrintAttributes?,
            newAttributes: PrintAttributes,
            cancellationSignal: CancellationSignal?,
            callback: LayoutResultCallback,
            extras: Bundle?,
        ) = delegate.onLayout(oldAttributes, newAttributes, cancellationSignal, callback, extras)

        /** Forwards the page-write pass unchanged. */
        override fun onWrite(
            pages: Array<out PageRange>,
            destination: ParcelFileDescriptor,
            cancellationSignal: CancellationSignal?,
            callback: WriteResultCallback,
        ) = delegate.onWrite(pages, destination, cancellationSignal, callback)

        /** Forwards the job-end notification, then releases the WebView. */
        override fun onFinish() {
            delegate.onFinish()
            webView.destroy()
        }
    }
}
