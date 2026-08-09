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

# Libellus Potionis — WCAG 2.2 Level AA self-assessment protocol (Android)

Purpose: a guided, repeatable manual evaluation you (the author) run on-device for
WCAG 2.2 **Level AA** on the Android app. This is a **self-assessment**, not an
independent audit. An AA *conformance claim* needs every in-scope Level A **and**
Level AA success criterion (SC) to pass under a thorough human evaluation, so
[WCAG_LEVEL_A_ANDROID.md](WCAG_LEVEL_A_ANDROID.md) has to pass first.

Four SC below carry a measurement and a recorded decision rather than an open
question. They were measured in the sixth QA review, and the reasoning is kept here
rather than in the roadmap so the number and the judgement sit in the same place.
Two of them are met by a documented exception rather than by enlargement or
repaint; that is a claim about the criterion's own wording and has to survive
re-reading, not just re-measuring.

## 0. Setup (do once)

- [ ] Build a **release-style debug** build and install on a physical phone.
- [ ] Enable **TalkBack**, and pair a Bluetooth keyboard for the focus SC.
- [ ] Set **Font size** and **Display size** to the largest step, and confirm the
      200 % text case of 1.4.4 separately from the 400 % reflow case of 1.4.10.
- [ ] Prepare data spanning several days, with **one day over the daily limit and
      one under**, so every status cue has something to show.
- [ ] Test in **both themes** and in **at least one RTL locale** plus
      German/English.
- [ ] Have a contrast meter to hand; the values recorded below are to be
      re-measured, not inherited, whenever a colour changes.

Record for each SC: **Pass / Fail / N/A** + a note. Screens as in the Level A
protocol.

## 1. Perceivable

- [ ] **1.2.4 Captions (Live) (AA)**, **1.2.5 Audio Description (AA).** N/A — no
      media of any kind.
- [ ] **1.3.4 Orientation (AA).** The app does not lock orientation. Rotate every
      screen and confirm both orientations work, including the dialogs.
- [ ] **1.3.5 Identify Input Purpose (AA).** No field collects data about the
      *user* in the sense of the criterion's input-purpose list (name, address,
      payment). The weight field is app data, not identity data. Record as N/A
      with that reason.
- [ ] **1.4.3 Contrast (Minimum) (AA).** Measured; one open question remains.
  - The dark theme carries two reds by design: `dangerRedColor` for dots, bars,
    the chart limit line and delete icons, and `dangerTextColor` for the
    days-over-limit values, the trend value in `StatRow`, the month-trend arrow,
    the BAC readout and the two delete confirmations. Both are defined in
    `ui/theme/Color.kt` next to their measured ratios.
  - The text red reaches 3.49 : 1, short of the 4.5 : 1 small-text threshold.
    Reaching it needs roughly `#E66363`, which reads as pink; that was measured,
    compared side by side and rejected.
  - **The open question is therefore not which red, but whether those sites should
    carry red text at all**, given that a dot or a bar beside them already carries
    the state. Decide this on device.
  - The BAC readout conforms on its own: `titleLarge` is 22 sp SemiBold, so the
    large-text threshold of 3 : 1 applies.
  - The light-theme caption colour is settled: `SchieferOnSurfaceVariant` is
    `#5D6C93`, 5.21 : 1 on the cards and 4.57 : 1 on the background.
- [ ] **1.4.4 Resize Text (AA).** All text is `sp`-based and follows the system
      font scale. Confirm at 200 % that nothing is clipped or overlapped, with
      Greek and Russian as the worst cases for line length.
- [ ] **1.4.5 Images of Text (AA).** No text is drawn as an image; the chart axis
      labels are real text. Confirm.
- [ ] **1.4.10 Reflow (AA).** At the largest display size plus 200 % font, no
      screen may require two-dimensional scrolling. The statistics charts and the
      calendar grids are the candidates to check.
- [ ] **1.4.11 Non-text Contrast (AA).** Measured and **left as it is,
      deliberately**.
  - Empty heat-map cells (`surfaceVariant`) sit at 1.12 : 1 against the card in
    the dark theme and 1.29 : 1 in the light one, below the 3 : 1 the criterion
    asks for.
  - The DATA cells are not affected: an over-limit cell has 3.25 : 1 and an
    under-limit one more, so the information the view exists to show clears the
    bar.
  - Lifting the empty grid to 3 : 1 would turn a quiet year of mostly-blank
    squares into a visible lattice of 365 tiles competing with the data drawn on
    it. The maintainer looked at the view on device and judged the current balance
    right (0.85.0 QA round). This is a decision about what the year view is for: the
    heat-map answers "when did I drink", and a day with no entry answers it by
    staying quiet.
  - The ring around today was once part of this decision, at 1.06 : 1 and
    1.20 : 1, on the same reasoning. It did not survive the device: the marker was
    invisible in both themes, which is a different matter from a grid that is
    quiet on purpose. It had the same shape of problem as the focus ring — it
    surrounds a cell whose fill varies, so no single colour clears 3 : 1 against
    all fills — and it took the same fix: drawn before the padding it lies on the
    card surface alone, where `onSurfaceVariant` gives 5.13 : 1 dark and
    5.21 : 1 light. Re-measure it here rather than inheriting the number.
- [ ] **1.4.12 Text Spacing (AA).** No layout relies on a fixed line height that
      would break under the criterion's spacing overrides. Check the statistics
      rows and the drink list, where a value and a caption share a line.
- [ ] **1.4.13 Content on Hover or Focus (AA).** N/A — touch app, no hover-revealed
      content.

## 2. Operable

- [ ] **2.4.5 Multiple Ways (AA).** Web-scoped (multiple ways to locate a *page*).
      For a native app with a bottom bar as the single navigation model, record as
      N/A with that reason.
- [ ] **2.4.6 Headings and Labels (AA).** Every section heading and every control
      label describes its topic or purpose. Read the Settings screen top to bottom
      and confirm each row says what it changes. Note the related Level A item:
      the headings are not yet exposed with the `heading()` role, which is 1.3.1's
      question, not this one.
- [ ] **2.4.7 Focus Visible (AA).** **Settled.** Both custom `clickable` surfaces
      draw a ring while focused. The heat-map ring sits on the outer box, outside
      the padding, so it lies on the card surface (12.42 : 1 dark, 14.73 : 1
      light) instead of on the cell colour, where no single ring colour clears
      3 : 1 against all four fills. The month cell fills its slot, so its ring
      follows the fill: `onPrimary` when selected, `onSurface` otherwise. Confirm
      on device in both themes.
- [ ] **2.4.11 Focus Not Obscured (Minimum) (AA, new in 2.2).** With a keyboard,
      tab through each screen and confirm the focused control is never hidden
      behind the bottom bar, a snackbar or the keyboard.
- [ ] **2.5.7 Dragging Movements (AA, new in 2.2).** Anything reachable by dragging
      must also be reachable by a single tap. Check the statistics screen's swipe
      between periods, which has arrow buttons as its tap alternative, and the
      drink list's swipe-to-delete, which has the edit mode.
- [ ] **2.5.8 Target Size (Minimum) (AA, new in 2.2).** Claimed under the
      criterion's own **Spacing** exception rather than met by enlargement.
  - The year heat-map's day cells are 10 dp with a 2 dp gap, below the 24 px
    minimum. Wrapping each in a 24 dp target would make neighbouring targets
    overlap — 24 dp of target around a 12 dp pitch cannot do otherwise — and where
    targets overlap the last one drawn wins, so a tap near the edge of the 14th
    would open the 15th. Trading an undersized target for a wrong one is not an
    improvement.
  - The exception applies on its terms: the targets are in a dense arrangement
    whose spatial layout is essential (a calendar year IS its grid; the position of
    a day carries its meaning), and the same action is available at a comfortable
    size elsewhere — the month grid's cells fill a seventh of the screen width and
    reach the same day.
  - Standard Material `IconButton`s throughout the app meet the minimum on their
    own. Confirm no custom control was added since that does not.

## 3. Understandable

- [ ] **3.1.2 Language of Parts (AA).** The UI is single-language per run. The one
      place a second language can appear is a user-typed drink name or note, which
      the criterion does not cover. Record with that reason.
- [ ] **3.2.3 Consistent Navigation (AA).** The bottom bar is in the same place
      with the same order on all four main screens. Confirm after any navigation
      change.
- [ ] **3.2.4 Consistent Identification (AA).** The same function carries the same
      icon and label everywhere — the edit toggle, the overflow menu, the delete
      action. Check the calendar's toolbar against the other three screens.
- [ ] **3.3.3 Error Suggestion (AA).** Where an input error is detected and a
      correction is known, it is offered. Trigger each validation path in the
      drink editor and confirm the message says what would be valid, not only that
      the value is not.
- [ ] **3.3.4 Error Prevention (Legal, Financial, Data) (AA).** Deleting an entry
      or a drink is reversible or confirmed. Both delete paths ask first; confirm
      that is still true, including the swipe path.
- [ ] **3.3.7 Redundant Entry (AA, new in 2.2).** No step asks again for
      information already given in the same process. The entry sheet pre-fills the
      drink and the time; confirm.
- [ ] **3.3.8 Accessible Authentication (Minimum) (AA, new in 2.2).** The app lock
      authenticates with biometrics or the device credential and asks no cognitive
      function test of its own. That is the criterion's own exception; record it
      with that reason rather than as a pass by absence.

## 4. Robust

- [ ] **4.1.3 Status Messages (AA).** A status message must reach assistive
      technology without taking focus. Check the snackbars after an export, an
      import and a delete: with TalkBack on, each should be announced without the
      screen jumping.

## 5. Sign-off

- Evaluator (author): ____________________  Date: __________
- Device / Android version / TalkBack version: ____________________
- Result: [ ] All in-scope Level A and AA SC Pass
- Outstanding fails (link follow-ups): ____________________

State the claim honestly, e.g.: *"Self-assessed conformant to WCAG 2.2 Level AA as
of <date>, evaluated on <device> with TalkBack; no independent audit; no W3C
conformance logo used."* Two of the SC above rest on a documented exception rather
than on a measurement; a claim that does not say so overstates what was found.
