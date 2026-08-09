<!-- vim: set et ts=4:
=============================================================================
Libellus Potionis - Privacy-Friendly Alcohol Tracker
Copyright (c) 2026 Martin A. Godisch <martin@godisch.de>
=============================================================================

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
details.

You should have received a copy of the GNU General Public License along with
this program.  If not, see <https://www.gnu.org/licenses/>.

In addition, as permitted by section 7 of the GNU General Public License,
this program may carry additional permissions; any such permissions that
apply to it are stated in the accompanying COPYING.md file.

=============================================================================
-->

# Libellus Potionis — WCAG 2.2 Level AA self-assessment protocol (iOS)

Purpose: a guided, repeatable manual evaluation for WCAG 2.2 **Level AA** on the
iOS app. This is a **self-assessment**, not an independent audit, and an AA claim
needs [WCAG_LEVEL_A_IOS.md](WCAG_LEVEL_A_IOS.md) to pass first.

The Android AA findings do not transfer. Android's status palette is a set of
hand-tuned hexes measured against each theme background, recorded in
`ui/theme/Color.kt`; iOS draws the same states from the system semantic palette —
the accent colour, `.orange` and `.red` for the limit bars and the traffic light,
`Color(.systemFill)` for the bar track, `.secondary` for captions. Those adapt to
the appearance and to the accessibility contrast settings, which is the right
default for a native app and also means **no contrast ratio in this app has been
measured on iOS**. Sections 1.4.3 and 1.4.11 below are therefore first
measurements, not re-measurements.

## 0. Setup (do once)

As for [Level A](WCAG_LEVEL_A_IOS.md), plus:

- [ ] A contrast meter, and a way to capture the rendered colours (a screenshot
      read at pixel level is enough).
- [ ] One pass with **Increase Contrast** off and one with it on, since the system
      palette answers differently to each.
- [ ] Dynamic Type at 200 % for 1.4.4, and at the largest accessibility size for
      1.4.10.

## 1. Perceivable

- [ ] **1.2.4 Captions (Live) (AA)**, **1.2.5 Audio Description (AA).** N/A — no
      media.
- [ ] **1.3.4 Orientation (AA).** The layouts are written adaptively and the app
      locks no orientation. Rotate every screen and every sheet.
- [ ] **1.3.5 Identify Input Purpose (AA).** No field collects identity data in the
      criterion's sense. N/A with that reason.
- [ ] **1.4.3 Contrast (Minimum) (AA).** **Unmeasured.** Capture and measure, in
      both appearances:
  - The `LimitBar` value and its "caption · limit" pair — the latter is
    `.secondary`, which is the likeliest shortfall in the app.
  - The BAC readout and the statistics values, whose emphasis colour comes from
    the same `Emphasis` palette as the bars.
  - The chart axis labels and the dashed red limit line's label.
  - Where a value falls short, the Android decision is available as precedent but
    not as an answer: it kept a signal red at 3.49 : 1 deliberately, and the same
    trade-off has to be made again against a different palette.
- [ ] **1.4.4 Resize Text (AA).** Everything uses the system text styles, so
      Dynamic Type applies throughout. Confirm at 200 % that the `LimitBar`'s right
      group — pinned to one line with a minimum scale factor — still reads, and
      that Greek and Russian do not clip.
- [ ] **1.4.5 Images of Text (AA).** No text is drawn as an image. Confirm for the
      Swift Charts axes and the PDF report preview.
- [ ] **1.4.10 Reflow (AA).** At the largest accessibility size, no screen may need
      two-dimensional scrolling. The statistics charts, the calendar's seven-column
      grid and the year heat-map are the candidates.
- [ ] **1.4.11 Non-text Contrast (AA).** **Unmeasured.** The graphical objects that
      carry information are the traffic-light dot, the `LimitBar` fill against its
      `Color(.systemFill)` track, the calendar day cells, the year heat-map cells,
      and the chart bars against the plot background. Measure each against what
      sits behind it. Note that Android reached a deliberate exception here for its
      empty heat-map cells; whether iOS lands in the same place depends on the
      system fill colour, so measure before deciding.
- [ ] **1.4.12 Text Spacing (AA).** Check the rows where a value and a caption
      share a line — the limit bars, the statistics rows, the drink list.
- [ ] **1.4.13 Content on Hover or Focus (AA).** N/A — no hover-revealed content.

## 2. Operable

- [ ] **2.4.5 Multiple Ways (AA).** Web-scoped; N/A for a tab-bar app.
- [ ] **2.4.6 Headings and Labels (AA).** Every section header and control label
      describes its purpose. The settings screen is the long one; read it top to
      bottom.
- [ ] **2.4.7 Focus Visible (AA).** With Full Keyboard Access, the focus ring must
      be visible on every control, including the calendar's day cells and the
      heat-map cells, whose backgrounds vary. This is where Android needed a
      deliberate fix; confirm what SwiftUI's default ring does over a filled cell.
- [ ] **2.4.11 Focus Not Obscured (Minimum) (AA, new in 2.2).** Tab through each
      screen and confirm the focused control is never hidden behind the tab bar,
      the keyboard or a sheet's grabber.
- [ ] **2.5.7 Dragging Movements (AA, new in 2.2).** The statistics swipe has arrow
      buttons; the drink list's swipe-to-delete has the edit mode. Confirm both.
- [ ] **2.5.8 Target Size (Minimum) (AA, new in 2.2).** 24 by 24 px. Measure the
      year heat-map's day cells — this is the criterion Android answered with the
      Spacing exception, and the iOS grid is a separate implementation whose pitch
      has to be measured rather than assumed. The month grid's cells and the
      toolbar buttons should clear it comfortably; confirm.

## 3. Understandable

- [ ] **3.1.2 Language of Parts (AA).** Single-language per run. The chart labels
      noted in the Level A protocol are the exception to check: if they stay
      English inside a localised UI, decide whether that is a 3.1.1 failure to fix
      or a 3.1.2 marking to add. Fixing it is the better answer.
- [ ] **3.2.3 Consistent Navigation (AA).** The tab bar keeps its order and place
      on all four screens.
- [ ] **3.2.4 Consistent Identification (AA).** The same function carries the same
      symbol everywhere. The calendar's toolbar reads "add, edit, overflow" like
      the others; confirm nothing has drifted since.
- [ ] **3.3.3 Error Suggestion (AA).** The drink editor's validation messages say
      what would be valid, not only that the value is not.
- [ ] **3.3.4 Error Prevention (Legal, Financial, Data) (AA).** Deleting an entry
      or a drink is confirmed, on both the swipe path and the edit-mode path. The
      import modes are the other data-destroying action: confirm the sheet says
      what each mode does to the drink list before it runs.
- [ ] **3.3.7 Redundant Entry (AA, new in 2.2).** The entry sheet pre-fills the
      drink and the time; the export range sheet offers the visible period. Confirm
      nothing asks twice.
- [ ] **3.3.8 Accessible Authentication (Minimum) (AA, new in 2.2).** The app lock
      uses biometrics or the device passcode and sets no cognitive function test of
      its own. Record it under the criterion's own exception.

## 4. Robust

- [ ] **4.1.3 Status Messages (AA).** With VoiceOver on, confirm that the result of
      an export, an import and a delete is announced without stealing focus. The
      Today screen's error alert is the one place that does take focus by design;
      record it as an alert, which the criterion treats separately.

## 5. Sign-off

- Evaluator (author): ____________________  Date: __________
- Device / iOS version / VoiceOver settings: ____________________
- Contrast pass run with Increase Contrast: [ ] off  [ ] on
- Result: [ ] All in-scope Level A and AA SC Pass
- Outstanding fails (link follow-ups): ____________________
