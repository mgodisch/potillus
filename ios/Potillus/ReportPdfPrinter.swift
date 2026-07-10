// vim: set et ts=4:
// =============================================================================
// Libellus Potionis - Privacy-Friendly Alcohol Tracker
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
//
// In addition, as permitted by section 7 of the GNU General Public License,
// this program may carry additional permissions; any such permissions that
// apply to it are stated in the accompanying COPYING.md file.
//
// =============================================================================

import PotillusKit
import UIKit
import WebKit

// =============================================================================
// ReportPdfPrinter – HTML into a paginated PDF
// =============================================================================
//
// Android hands its HTML to the system print framework, which loads it in a
// WebView and paginates it. This is the same road on iOS: a WKWebView renders the
// page, `viewPrintFormatter()` hands it to `UIPrintPageRenderer`, and the renderer
// draws one PDF page at a time. What comes out is what Safari would print.
//
// WHY NOT `WKWebView.createPDF`?
//   Because it is not printing. It captures a rectangle, and the rectangle is
//   usually the whole scroll height: one very long sheet. The template is written
//   as two A4 pages with `page-break` rules and a running footer, and a single
//   endless page would be a different document.
//
// PAPER SIZE WITHOUT KVC
//   `paperRect` and `printableRect` are read-only, and the recipes on the web all
//   set them with `setValue(_:forKey:)` — key-value coding, a contract Apple never
//   offered. They are also `open`, so a subclass may simply override the getters,
//   which is what `PaperSizedRenderer` below does. Same result, no reflection, and
//   the compiler checks it.
//
// This file cannot be unit-tested: it needs a screen, a web engine and a run loop.
// Everything that could be tested was moved out of it — the HTML into
// `ReportRenderer`, the file name into `ReportJob`.
// =============================================================================

@MainActor
final class ReportPdfPrinter: NSObject {

    enum Failure: Error, LocalizedError {
        case webViewFailed(String)
        case emptyDocument

        var errorDescription: String? {
            switch self {
            case .webViewFailed(let reason): return "The report could not be laid out: \(reason)"
            case .emptyDocument: return "The report came out empty."
            }
        }
    }

    /// A4 at 72 points per inch, which is the unit `UIPrintPageRenderer` draws in.
    /// 595.2 × 841.8 pt is 210 × 297 mm.
    private static let a4Paper = CGRect(x: 0, y: 0, width: 595.2, height: 841.8)

    /// The margin the template does NOT draw itself. Its own padding sits inside.
    private static let margin: CGFloat = 24

    /// Held for the duration of the render. A `WKWebView` with no owner is
    /// deallocated mid-load, and its delegate is never called.
    private var webView: WKWebView?
    private var continuation: CheckedContinuation<Data, Error>?

    /// Lays out `html` and returns the finished PDF.
    ///
    /// Suspends until the web view reports the page loaded. A load that fails
    /// resumes the continuation with the error rather than hanging the caller.
    func pdfData(html: String) async throws -> Data {
        let webView = WKWebView(frame: Self.a4Paper)
        webView.navigationDelegate = self
        self.webView = webView

        defer {
            self.webView = nil
            self.continuation = nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            // `nil` base URL: the template is self-contained, and a base URL would
            // let a future edit reach the network from a report about drinking.
            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    /// Draws every page the formatter produces into one PDF.
    private func render(_ webView: WKWebView) throws -> Data {
        let renderer = PaperSizedRenderer(
            paper: Self.a4Paper, printable: Self.a4Paper.insetBy(dx: Self.margin, dy: Self.margin)
        )
        renderer.addPrintFormatter(webView.viewPrintFormatter(), startingAtPageAt: 0)

        let output = NSMutableData()
        UIGraphicsBeginPDFContextToData(output, Self.a4Paper, nil)

        // THE CONTEXT MUST BE CLOSED BEFORE THE BUFFER IS READ, and `defer` is too
        // late: it runs after the return value has been evaluated. A PDF whose
        // context was never ended has a `%PDF-` header, page objects, and no
        // cross-reference table or `%%EOF` — a file every reader calls corrupt.
        //
        // The flag is not decoration. `drawPage` can throw its way out of the loop,
        // and a context left open leaks its drawing surface for the life of the
        // process, so the deferred close still has to exist for that path.
        var contextIsOpen = true
        defer { if contextIsOpen { UIGraphicsEndPDFContext() } }

        // `numberOfPages` is what the formatter decided, honouring the template's
        // page breaks. Asking is what makes it decide; nothing paginates before.
        let pages = renderer.numberOfPages
        guard pages > 0 else { throw Failure.emptyDocument }

        for page in 0..<pages {
            UIGraphicsBeginPDFPage()
            renderer.drawPage(at: page, in: renderer.paperRect)
        }

        UIGraphicsEndPDFContext()
        contextIsOpen = false

        // A file that starts `%PDF-` and ends `%%EOF` is not proof of a good report,
        // but the absence of either is proof of a broken one. `ReportJob` holds the
        // check because it is pure, and this file is the one place that can be wrong
        // about it.
        guard output.length > 0, ReportJob.isWellFormed(output as Data) else {
            throw Failure.emptyDocument
        }
        return output as Data
    }
}

// ── The web view's side of the conversation ──────────────────────────────────

extension ReportPdfPrinter: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let continuation else { return }
        self.continuation = nil

        do {
            continuation.resume(returning: try render(webView))
        } catch {
            continuation.resume(throwing: error)
        }
    }

    func webView(
        _ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error
    ) {
        continuation?.resume(throwing: Failure.webViewFailed(error.localizedDescription))
        continuation = nil
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        continuation?.resume(throwing: Failure.webViewFailed(error.localizedDescription))
        continuation = nil
    }
}

// =============================================================================
// PaperSizedRenderer
// =============================================================================
//
// A renderer not driven by a print job has no paper, and `UIPrintPageRenderer`
// exposes `paperRect` and `printableRect` as read-only. The usual advice is to
// write them through key-value coding. That works by reflection, silently, and
// stops working silently.
//
// Both properties are `open`, so overriding the getters says the same thing to the
// compiler, which then checks it. No private symbol, no undeclared selector, no
// string that has to stay spelled right.
// =============================================================================

private final class PaperSizedRenderer: UIPrintPageRenderer {

    private let paper: CGRect
    private let printable: CGRect

    init(paper: CGRect, printable: CGRect) {
        self.paper = paper
        self.printable = printable
        super.init()
    }

    override var paperRect: CGRect { paper }
    override var printableRect: CGRect { printable }
}
