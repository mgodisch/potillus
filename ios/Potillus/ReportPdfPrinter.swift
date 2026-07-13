// vim: set et ts=4:
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

    // ── Paper, and the one number that decides everything ────────────────────
    //
    // The template measures in MILLIMETRES:
    //
    //     @page  { size: A4; margin: 14mm 12mm 16mm 12mm; }
    //     .sheet { min-height: 267mm; }        /* 297 − 14 − 16 */
    //
    // CSS resolves a millimetre at 96 dpi. `UIPrintPageRenderer` draws at 72. Left
    // alone, one CSS pixel prints as one point, every millimetre comes out 4/3 too
    // large, and each 267 mm sheet needs 356 mm of a 267 mm page. Two sheets, four
    // pages. That is what the report did.
    //
    // TWO WRONG FIXES CAME FIRST, and both are worth remembering.
    //
    //   Patch -59 inset the printable box by an invented 24 pt and let the scale
    //   fall where it may.
    //
    //   Patch -61 assumed `UIViewPrintFormatter` SCALES the view down to the
    //   printable width, and sized the view in CSS pixels so that the scale would
    //   land on 0.75. It does not scale. It RE-LAYS-OUT the content for the page
    //   width, so the view's width changed the line breaks and nothing else. Still
    //   four pages, and the type never looked too large — which is exactly why the
    //   wrong theory survived a round.
    //
    // `pageZoom` ends the argument. It scales the CONTENT, whatever the formatter
    // then does with it, and 72/96 is 0.75 exactly. One CSS millimetre becomes one
    // printed millimetre, and `min-height: 267mm` is precisely the printable height.

    /// Points per millimetre: 72 dpi over 25.4 mm per inch.
    private static let pointsPerMm: CGFloat = 72.0 / 25.4

    /// Points per CSS pixel: 72 over 96, which is 0.75.
    ///
    /// The whole bug, as a fraction. Given to `pageZoom`, it makes the web view lay
    /// out in CSS pixels and print in points at the same physical size.
    private static let printScale: CGFloat = 72.0 / 96.0

    /// A4: 210 × 297 mm, in points.
    private static let a4Paper = CGRect(
        x: 0, y: 0, width: 210 * pointsPerMm, height: 297 * pointsPerMm
    )

    /// The template's `@page` margins, in millimetres: top, right, bottom, left.
    ///
    /// `UIViewPrintFormatter` ignores `@page`, so the margins are applied here
    /// instead. They are duplicated from the template, and `tools/check-report-paper.py`
    /// fails the build if the two ever disagree.
    private static let pageMarginsMm = (top: 14.0, right: 12.0, bottom: 16.0, left: 12.0)

    /// The margin box: what `@page` would have left to draw in.
    private static var printableBox: CGRect {
        CGRect(
            x: CGFloat(pageMarginsMm.left) * pointsPerMm,
            y: CGFloat(pageMarginsMm.top) * pointsPerMm,
            width: a4Paper.width
                - CGFloat(pageMarginsMm.left + pageMarginsMm.right) * pointsPerMm,
            height: a4Paper.height
                - CGFloat(pageMarginsMm.top + pageMarginsMm.bottom) * pointsPerMm
        )
    }

    /// Held for the duration of the render. A `WKWebView` with no owner is
    /// deallocated mid-load, and its delegate is never called.
    private var webView: WKWebView?
    private var continuation: CheckedContinuation<Data, Error>?

    /// Lays out `html` and returns the finished PDF.
    ///
    /// Suspends until the web view reports the page loaded. A load that fails
    /// resumes the continuation with the error rather than hanging the caller.
    func pdfData(html: String) async throws -> Data {
        // JavaScript stays OFF. The template ships no scripts, every substituted
        // value is HTML-escaped (vector-pinned), and the base URL below is nil —
        // but WKWebView's DEFAULT is JavaScript ON, unlike Android's WebView,
        // whose disabled default the report render there simply keeps. One line
        // makes the two platforms' stance identical and turns "escaping holds"
        // from the only line of defence into one of two (0.83.0 QA round).
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false

        // The view is exactly the printable box, in points. `pageZoom` then gives
        // the page a layout viewport of box ÷ 0.75 CSS pixels — 703 px for 186 mm —
        // so the template's millimetres survive the trip onto the paper.
        let webView = WKWebView(frame: Self.printableBox, configuration: configuration)
        webView.pageZoom = Self.printScale
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
            // `ReportPageBox` restates the sheet height in page units. WebKit's
            // print layout inflates absolute lengths by a factor a little over 1.2
            // — measured, not guessed — and `100vh` is one page whatever that
            // factor is. See ReportPageBox.swift.
            webView.loadHTMLString(ReportPageBox.inject(into: html), baseURL: nil)
        }
    }

    /// Draws every page the formatter produces into one PDF.
    private func render(_ webView: WKWebView) throws -> Data {
        let renderer = PaperSizedRenderer(paper: Self.a4Paper, printable: Self.printableBox)
        // THE FORMATTER HAS MARGINS OF ITS OWN, and they default to a full inch on
        // every side. 72 pt top and bottom is 50.8 mm taken out of a printable box
        // that already carries the template's `@page` margins — so a 267 mm sheet
        // never fit the 216 mm it was actually given, and printed on two pages.
        //
        // The same inch on each side is why patch -61's change to the view's width
        // moved the line breaks and nothing else: the formatter was re-flowing the
        // text inside its own narrower column all along.
        //
        // `printableBox` is the margin box. Nothing else may add to it.
        let formatter = webView.viewPrintFormatter()
        formatter.perPageContentInsets = .zero
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)

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
