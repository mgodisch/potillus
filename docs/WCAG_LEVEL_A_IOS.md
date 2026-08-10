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

# Libellus Potionis — WCAG 2.2 Level A self-assessment protocol (iOS)

Purpose: a guided, repeatable manual evaluation you (the author) run on-device with
**VoiceOver** to establish WCAG 2.2 **Level A** for the iOS app. This is a
**self-assessment**; record it as such (not an independent audit). A Level-A
*conformance claim* requires that **every** in-scope Level-A success criterion (SC)
passes **and** a thorough human evaluation. Automated checks alone are not
sufficient (per W3C).

This is the iOS counterpart of [WCAG_LEVEL_A_ANDROID.md](WCAG_LEVEL_A_ANDROID.md),
forked rather than shared: the two ports are separate implementations, and a
finding on one does not transfer. Where Android draws Compose `Canvas` charts, iOS
uses Swift Charts; where Android names a `contentDescription`, SwiftUI derives a
label from the `Text` it renders. **The question here is therefore rarely whether a
label is missing. It is whether the derived ones carry** — a screen can read
perfectly to the eye and announce a row of bare numbers to VoiceOver.

Scope note: the app is native and offline, with no media, no timers, no hyperlinks
outside the documentation screens, and no login. Several Level-A SC are therefore
**N/A**; record them as such with the reason.

## 0. Setup (do once)

- [ ] Build and install on a physical phone (the test device is an **iPhone SE 3rd
      generation**).
- [ ] Settings → Accessibility → **Accessibility Shortcut → VoiceOver**, so a
      triple-click of the Home button toggles it. Do this **before** switching
      VoiceOver on: without it, turning VoiceOver off again is itself an exercise,
      because every gesture changes.
- [ ] Set the **speaking rate low**.
- [ ] Learn the six gestures the walkthrough needs: single tap selects and speaks,
      swipe right and left move to the next and previous element, double tap
      activates, three-finger swipe scrolls, two-finger swipe down reads from the
      top, two-finger tap pauses.
- [ ] Pair a Bluetooth keyboard and enable **Full Keyboard Access** for the
      keyboard SC.
- [ ] Set **Dynamic Type** to the largest step, including the Larger Accessibility
      Sizes.
- [ ] Prepare data: at least one drink, several logged entries across multiple days
      including **one day over the daily limit and one under**, so the calendar and
      the traffic light have something to show.
- [ ] Test in **both light and dark appearance** and in **at least one RTL locale**
      plus German/English.

Record for each SC: **Pass / Fail / N/A** + a note. Screens to cover: Today,
Drinks, Calendar (month), Calendar (year heat-map), Statistics, Settings, the
entry sheet, the drink editor, the export range sheet, the document viewer, and
the app-lock cover.

### What the port annotates explicitly

Everything else relies on SwiftUI's derived labels, so this list is where to start
and not where to stop:

- `TrafficLightDot` is one accessibility element carrying a localised description
  of the capacity state; the colour-blind glyph is decorative.
- The favourite star in `DrinksScreen` labels both directions and carries a hint.
- The calendar's month arrows and day cells are labelled, and the day cell's label
  is assembled from the date and the day's summary.
- The year heat-map labels its arrows, combines each cell's children into one
  element, hides every cell that is not a drink day — deliberately, so a reader
  does not meet 365 "no entry" nodes — and offers a named accessibility action per
  month.
- The statistics screen labels its period arrows and combines one row group.
- Every `LimitBar` is a single element whose label states the caption, the value
  and the limit as one sentence with the unit spelled out; the track behind it is
  hidden as decoration. The date range in the seven-day caption is shown and not
  spoken.
- The two summary rows on Today carry the same kind of sentence, so "Ø" and
  "g/day" reach a reader as the words they abbreviate. The trend arrow beside the
  average is silent.
- The day-change time in Settings is one element carrying its title and its time.

## 1. Perceivable

- [ ] **1.1.1 Non-text Content (A).** Every informative non-text element has a text
      alternative.
  - Traffic-light dot → announces its capacity state, not "image". Confirm in both
    styles (Settings → Appearance → alternative status symbols, off and on).
  - The three `LimitBar`s on Today → the bar itself is deliberately hidden, on the
    reasoning that the numbers above it already say the same thing. That reasoning
    was checked on device and the row did arrive in pieces: the value and the
    "caption · limit" pair were announced as two unrelated elements, with no
    statement of which limit the figures belonged to. Each row is now one element
    with a spoken sentence, and the capsule stays hidden. **Confirm the new
    wording**, including the drinking-days row, whose caption carries the counted
    noun so the sentence needs no plural agreement.
  - The statistics charts → Swift Charts derives its spoken output from the labels
    passed to `.value(...)`. **Those labels are English literals in the source**
    ("Date", "Grams per day", "Daily limit"), while the axis label beside them goes
    through `Loc.string`. Confirm what VoiceOver actually says with the app set to
    German, and record it: if the chart speaks English inside a German UI, that is
    this criterion and 3.1.1 at once.
  - The drink-category icons and the toolbar icons → each must announce something
    other than its SF Symbol name.
- [ ] **1.3.1 Info and Relationships (A).** Structure is programmatically
      determinable.
  - **Verify:** section headers on Settings and Statistics are exposed with the
    heading trait (`accessibilityAddTraits(.isHeader)`), so VoiceOver's heading
    rotor can reach them. SwiftUI's `Form` sections give this for free where the
    section has a real header; check the hand-built card headers.
  - Form fields in the entry sheet and the drink editor are associated with their
    labels. `TextField`, `Picker`, `DatePicker` and `Stepper` all receive a
    localised title in the source; confirm the title is what VoiceOver speaks. A
    title alone does not make the row one element — the day-change `DatePicker`
    read its title and its hour as two, and now combines its children.
  - The footnote about the day-change time sits in the Section it explains, as a
    row under the control rather than in the Section footer, which a reader
    reaches after the last row and therefore after the wrong setting.
- [ ] **1.3.2 Meaningful Sequence (A).** VoiceOver reading order matches the visual
      order on every screen. **Start on Today**: does focus run top to bottom, or
      does it jump into the toolbar and back? This was the first question the
      earlier attempt raised and it was not answered.
- [ ] **1.3.3 Sensory Characteristics (A).** No instruction relies on shape,
      position or colour alone. Scan the user's guide and the empty-state texts.
- [ ] **1.4.1 Use of Color (A).** Colour is never the only visual means of
      conveying information.
  - The traffic-light dot has the opt-in shape glyph, as on Android. Record
    whether the setting was on or off for the pass.
  - **Open:** the `LimitBar` tint carries the state through `Emphasis` — the accent
    colour, orange, red — and nothing else. The number beside it says the value but
    not whether the value is over the limit. Decide whether the row needs a
    non-colour cue.
  - **Open:** the calendar day cells and the year heat-map cells encode over- and
    under-limit by colour. Same question as Android's, on a separate
    implementation.
- [ ] **1.4.2 Audio Control (A).** N/A — no audio.

## 2. Operable

- [ ] **2.1.1 Keyboard (A).** With Full Keyboard Access, every control is reachable
      and operable, including the calendar's day cells and the year heat-map's
      cells, whose month action is a named accessibility action rather than a
      button.
- [ ] **2.1.2 No Keyboard Trap (A).** Focus can always leave a sheet, a picker or
      the app-lock cover.
- [ ] **2.1.4 Character Key Shortcuts (A).** N/A — no single-character shortcuts.
- [ ] **2.4.1 Bypass Blocks (A).** Web-scoped; N/A for a native app.
- [ ] **2.4.2 Page Titled (A).** Each screen has a navigation title. Confirm the
      titles are localised and that the sheets carry one too.
- [ ] **2.4.3 Focus Order (A).** VoiceOver and keyboard focus order is logical on
      every screen and sheet.
- [ ] **2.4.4 Link Purpose (In Context) (A).** The documentation screens and the
      About screen's repository link are the only hyperlinks; their purpose must be
      clear from the link text.
- [ ] **2.5.1 Pointer Gestures (A).** Anything reachable by a path-based gesture
      needs a single-pointer alternative. The statistics screen's swipe between
      periods has its arrow buttons; the drink list's swipe-to-delete has the edit
      mode. Confirm both alternatives are reachable with VoiceOver on, where the
      swipe gesture is intercepted anyway.
- [ ] **2.5.2 Pointer Cancellation (A).** Actions fire on the up event and a press
      can be aborted by dragging off. SwiftUI's `Button` does this by default;
      confirm no custom gesture recogniser acts on the down event.
- [ ] **2.5.3 Label in Name (A).** For every control with a visible text label, the
      accessible name **contains** that visible text. The favourite star has no
      visible text and is exempt; the sheet's confirm and cancel buttons, the
      period picker and the settings rows are where to check.
- [ ] **2.5.4 Motion Actuation (A).** N/A — no motion or shake features.

## 3. Understandable

- [ ] **3.1.1 Language of Page (A).** The app exposes its UI language through the
      per-app locale. **Confirm VoiceOver speaks in the selected language**, and
      pay attention to the chart labels named under 1.1.1: a hard-coded English
      string inside a German UI fails here even when everything around it passes.
- [ ] **3.2.1 On Focus (A).** Focusing a control causes no context change.
- [ ] **3.2.2 On Input (A).** Changing a toggle, a stepper or a picker causes no
      surprising navigation. The language picker restarts the UI by design;
      record it as intended and user-initiated.
- [ ] **3.2.6 Consistent Help (A, new in 2.2).** The overflow menu's help entry is
      in the same place on every screen. Confirm, including the calendar, whose
      toolbar was brought into line with the others.
- [ ] **3.3.1 Error Identification (A).** Input errors are described in text.
      Trigger each validation path in the drink editor — a blank name, an
      out-of-range percentage — and confirm a text message, spoken by VoiceOver
      rather than only shown.
- [ ] **3.3.2 Labels or Instructions (A).** Every input in the entry sheet, the
      drink editor, the settings steppers and the export range sheet has a visible
      label.

## 4. Robust

- [ ] **4.1.2 Name, Role, Value (A).** Every UI component exposes name, role and
      state.
  - The calendar day cells and the heat-map cells: confirm the combined label does
    not read the day number twice — once from the inner `Text` and once from the
    assembled description.
  - The settings toggles announce their on/off state; the steppers announce their
    current value and not only their title.
  - The `LabeledContent` pairs on Today (today's total or, while a streak runs,
    the current abstinence; the monthly average; the BAC readout) are meant to
    announce caption and value together. Confirm they do, and confirm the BAC
    readout carries its unit and, if it has one, its warning state — which is
    otherwise carried by colour alone. The abstinence row replaces the gram total
    in place, so check that the swap is announced as a changed value and not as a
    silently different row.
  - The month trend arrow beside the average is an SF Symbol with no label of its
    own. Decide whether the direction it shows reaches VoiceOver at all.
  - (Note: **4.1.1 Parsing was removed in WCAG 2.2** — do not test it.)

## 5. Explicitly N/A for this app (record, do not claim)

1.2.1–1.2.3 (audio/video), 1.4.2 (audio control), 2.1.4 (character shortcuts),
2.2.1–2.2.2 (timing and moving content), 2.3.1 (three flashes), 2.5.4 (motion), and
the web-scoped 2.4.1. For each: reason = "native offline app, feature not present".

## 6. Open questions carried into this pass

1. **Reading order on Today** — does focus follow the visual order, or jump into
   the toolbar and back (1.3.2)?
2. **The traffic-light dot** — status or "image" (1.1.1)?
3. **The three limit bars** — which limit and how full, or a label and a value
   arriving as two unrelated elements with the bar contributing nothing (1.1.1,
   4.1.2)?
4. **The BAC readout** — spoken with its unit and its warning state (4.1.2)?
5. **The chart labels** — English literals inside a localised UI (1.1.1, 3.1.1)?

## 7. Sign-off

- Evaluator (author): ____________________  Date: __________
- Device / iOS version / VoiceOver settings: ____________________
- Result: [ ] All in-scope Level-A SC Pass  → self-assessed Level A conformance
- Outstanding fails (link follow-ups): ____________________

State the claim honestly, e.g.: *"Self-assessed conformant to WCAG 2.2 Level A as
of <date>, evaluated on <device> with VoiceOver; no independent audit; no W3C
conformance logo used."* A claim made for the app covers both platforms unless it
says otherwise, so an iOS result that differs from the Android one has to be
stated as such.
