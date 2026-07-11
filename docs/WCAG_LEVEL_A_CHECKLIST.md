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

# Libellus Potionis — WCAG 2.2 Level A self-assessment protocol

Purpose: a guided, repeatable manual evaluation you (the author) run on-device to
establish WCAG 2.2 **Level A** for the app. This is a **self-assessment**; record
it as such (not an independent audit). A Level-A *conformance claim* requires that
**every** in-scope Level-A success criterion (SC) passes **and** a thorough human
evaluation — which is what this protocol is. Automated checks alone are not
sufficient (per W3C).

Scope note: Potillus is a native, offline Android app with no media, no timers,
no hyperlinks, and no login. Several Level-A SC are therefore **N/A** and marked
below; do not claim them, just record them as not applicable with the reason.

---

## 0. Setup (do once)

- [ ] Build a **release-style debug** build and install on a physical phone.
- [ ] Enable **TalkBack** (Settings → Accessibility → TalkBack). Learn the swipe
      gestures: right = next element, left = previous, double-tap = activate.
- [ ] Enable **Switch Access** OR pair a Bluetooth keyboard (for the keyboard SC).
- [ ] Set **Font size** and **Display size** to the largest step.
- [ ] Prepare data: at least one drink, several logged entries across multiple
      days including **one day over the daily limit and one under**, so the
      calendar/heat-map status cues have something to show.
- [ ] Test in **both light and dark theme**, and in **at least one RTL locale**
      (e.g. switch app language to a RTL language if available) plus German/English.

Record for each SC: **Pass / Fail / N/A** + a note. Screens to cover: Today,
Drinks, Calendar (month grid), Calendar (year heat-map), Statistics (charts),
Settings, the add/edit-entry dialog, the date/time pickers, the document/help
viewer, the PDF export flow.

---

## 1. Perceivable

- [ ] **1.1.1 Non-text Content (A).** Every informative non-text element has a
      text alternative.
  - Traffic-light capacity dot → TalkBack announces the capacity state
    (implemented: `contentDescription` on `TrafficLightDot`).
  - Statistics charts (bar/value/donut) → each announces a summary (implemented).
  - Drink-category icons, star/favourite, delete/edit icons → each has a
    description. *Verify none announce as "unlabelled".*
  - Purely decorative graphics announce nothing.
- [ ] **1.3.1 Info and Relationships (A).** Structure is programmatically
      determinable.
  - **Verify:** section headings on Settings/Statistics are exposed as *headings*
    to TalkBack (swipe by heading). If they read as plain text, add
    `Modifier.semantics { heading() }` to the header `Text`s. *(Likely a gap —
    check first.)*
  - Form fields in dialogs are associated with their labels.
- [ ] **1.3.2 Meaningful Sequence (A).** TalkBack reading order matches the
      visual order on every screen.
- [ ] **1.3.3 Sensory Characteristics (A).** No instruction relies on shape/
      position/colour alone ("tap the green dot"). Scan all in-app help text.
- [ ] **1.4.1 Use of Color (A).** Colour is never the *only* visual means of
      conveying information.
  - Traffic-light dot: shape glyph now shown **by default** (cross / 1 / arrow) →
    Pass, provided the setting is left on.
  - **Verify / OPEN:** the **calendar month-grid** day dot shows over- vs
    under-limit by **colour only** (red vs primary-blue). Decide: is red-vs-blue
    sufficiently distinguishable for your palette (different hue *and* lightness →
    usually OK), or add a non-colour cue (e.g. a ring/outline on over-limit days)?
    Same question for the **year heat-map** cells. Record the decision and, if
    needed, file a follow-up.
  - Progress bars / over-limit chart bars also encode via length/position, not
    colour alone → Pass, but confirm.
- [ ] **1.4.2 Audio Control (A).** N/A — no auto-playing audio.

## 2. Operable

- [ ] **2.1.1 Keyboard (A).** With a Bluetooth keyboard / Switch Access, every
      control is reachable and operable, including the **custom clickable
      calendar cells** (month grid + year heat-map). They now declare
      `role = Role.Button`; confirm they are focusable and activatable.
- [ ] **2.1.2 No Keyboard Trap (A).** Focus can always move away from any control
      (dialogs, pickers).
- [ ] **2.1.4 Character Key Shortcuts (A).** N/A — no single-character shortcuts.
- [ ] **2.4.1 Bypass Blocks (A).** Web-scoped; for a native app treat as N/A
      (no repeated blocks of navigation to bypass).
- [ ] **2.4.2 Page Titled (A).** Each screen has a clear title (top app bar).
- [ ] **2.4.3 Focus Order (A).** TalkBack/keyboard focus order is logical on
      every screen and dialog.
- [ ] **2.4.4 Link Purpose (In Context) (A).** N/A / minimal — no hyperlinks
      except any in the help text; if present, their purpose is clear from text.
- [ ] **2.5.1 Pointer Gestures (A).** No functionality needs multipoint or
      path-based gestures (all taps). Pass.
- [ ] **2.5.2 Pointer Cancellation (A).** Actions fire on up-event; a press can
      be aborted by dragging off. (Compose default.) Confirm no down-event action.
- [ ] **2.5.3 Label in Name (A).** For every control with a visible text label,
      the accessible name **contains** that visible text. **Verify** on buttons
      like "Change", chips, and dialog confirm/cancel.
- [ ] **2.5.4 Motion Actuation (A).** N/A — no motion/shake features.

## 3. Understandable

- [ ] **3.1.1 Language of Page (A).** The app exposes its UI language; the
      per-app locale is set. Confirm TalkBack speaks in the selected language.
- [ ] **3.2.1 On Focus (A).** Focusing a control causes no unexpected context
      change.
- [ ] **3.2.2 On Input (A).** Changing a setting/toggle causes no surprising
      context change (e.g. no unexpected navigation).
- [ ] **3.2.6 Consistent Help (A, new in 2.2).** Help access (the help/guide
      entry) is in a consistent location across screens. Confirm.
- [ ] **3.3.1 Error Identification (A).** Input errors (e.g. invalid grams,
      blank drink name) are described in text, not colour alone. Trigger each
      validation path and confirm a text message.
- [ ] **3.3.2 Labels or Instructions (A).** Every input in the add/edit dialog,
      limit dialogs, weight dialog, pickers has a visible label/instruction.

## 4. Robust

- [ ] **4.1.2 Name, Role, Value (A).** Every UI component exposes name, role and
      state to assistive tech.
  - Custom clickable calendar cells now expose `role = Role.Button`; month cells
    also expose a "date, grams, status" name (implemented). **Verify** the
    announcement on-device — check the month cell does not read the day number
    *and* the description redundantly ("14, 14 March … button"); if it does,
    silence the inner day-number `Text` with `clearAndSetSemantics {}` or move
    the description onto the click node.
  - Switch/toggle rows announce their **on/off state**. Confirm for the new
    "Alternative Status Symbols" switch and the others.
  - (Note: **4.1.1 Parsing was removed in WCAG 2.2** — do not test it.)

---

## 5. Explicitly N/A for this app (record, do not claim)

1.2.1–1.2.3 (audio/video), 1.4.2 (audio control), 2.1.4 (char shortcuts),
2.2.1–2.2.2 (timing/moving — no timeouts or auto-updating content), 2.3.1 (three
flashes — no flashing), 2.5.4 (motion), and web-scoped items (2.4.1 bypass
blocks). For each: reason = "native offline app, feature not present".

---

## 6. Open items already known (decide during this pass)

1. **Calendar 1.4.1 (colour-only status):** month-grid dot and year heat-map cell
   convey over/under-limit by colour. Screen-reader users are covered (both now
   have text descriptions), but *sighted colour-blind* users rely on the palette
   being distinguishable. Decision needed: accept red-vs-blue as distinguishable,
   or add a non-colour visual cue (outline/shape) on over-limit days.
2. **4.1.2 month-cell announcement redundancy** (see above) — verify and, if
   needed, a one-line `clearAndSetSemantics` fix.
3. **1.3.1 headings** — verify section headers expose the `heading()` role;
   likely a small addition if not.

---

## 7. Sign-off

- Evaluator (author): ____________________  Date: __________
- Device / Android version / TalkBack version: ____________________
- Result: [ ] All in-scope Level-A SC Pass  → self-assessed Level A conformance
- Outstanding fails (link follow-ups): ____________________

State the claim honestly, e.g.: *"Self-assessed conformant to WCAG 2.2 Level A
as of <date>, evaluated on <device> with TalkBack; no independent audit; no W3C
conformance logo used."*
