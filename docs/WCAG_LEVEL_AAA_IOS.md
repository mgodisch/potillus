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

# Libellus Potionis — WCAG 2.2 Level AAA self-assessment protocol (iOS)

Purpose: a guided, repeatable manual evaluation for the Level AAA success criteria
(SC) that apply to the iOS app. This is a **self-assessment**, not an independent
audit, and it sits on [WCAG_LEVEL_A_IOS.md](WCAG_LEVEL_A_IOS.md) and
[WCAG_LEVEL_AA_IOS.md](WCAG_LEVEL_AA_IOS.md).

The W3C states that AAA conformance is not recommended as a general policy for
entire sites, because some content cannot satisfy all of it. Walk this protocol to
learn which individual AAA criteria the app reaches, not to reach the level.

Only the SC this app can pass or fail are listed. The rest are collected in
section 4 with the reason they do not apply.

## 0. Setup

As for Level AA, plus **Reduce Motion** switched on for one pass, and the contrast
meter set to the 7 : 1 threshold.

## 1. Perceivable

- [ ] **1.3.6 Identify Purpose (AAA).** iOS exposes accessibility traits and, for
      text input, `textContentType`. Record what the app declares beyond a label —
      the tab bar's items, the toolbar actions, the text fields in the drink
      editor — and whether more is available.
- [ ] **1.4.6 Contrast (Enhanced) (AAA).** Depends entirely on the AA measurement
      that has not been made yet. Once the values from
      [WCAG_LEVEL_AA_IOS.md](WCAG_LEVEL_AA_IOS.md) exist, re-read them against
      7 : 1. Expect the system `.secondary` captions and the orange warning state
      to fall short; expect the primary label colour on the standard background to
      clear it.
- [ ] **1.4.8 Visual Presentation (AAA).** Decidable on the prose screens: the
      user's guide, the privacy policy and the licence viewer. Check line length,
      spacing and the absence of justification; the app offers appearance
      following the system rather than free colour choice, which is a partial
      answer to be recorded as such.
- [ ] **1.4.9 Images of Text (No Exception) (AAA).** No text is drawn as an image,
      the Swift Charts axes included. Expected to pass; the app icon is the
      criterion's own logo exception.

## 2. Operable

- [ ] **2.1.3 Keyboard (No Exception) (AAA).** With Full Keyboard Access, every
      function must be operable, including the year heat-map's per-month
      accessibility action and the statistics swipe, whose keyboard route is its
      arrow buttons.
- [ ] **2.2.5 Re-authenticating (AAA).** Begin an entry, let the app lock engage,
      unlock, and confirm nothing typed was lost.
- [ ] **2.2.6 Timeouts (AAA).** The app lock's inactivity timeout is the only
      timeout. Establish whether it can lose data, and record that rather than a
      bare pass.
- [ ] **2.3.3 Animation from Interactions (AAA).** Run one pass with Reduce Motion
      on and confirm the sheet presentations, the tab transitions and the chart
      draw respect it.
- [ ] **2.4.8 Location (AAA).** The tab bar marks the current screen and each
      screen carries a navigation title. Confirm the calendar's month-versus-year
      mode and the statistics period are equally legible as "where am I".
- [ ] **2.4.10 Section Headings (AAA).** Shares its fate with 1.3.1 at Level A: it
      turns on whether the section headers are exposed with the header trait.
      SwiftUI's `Form` section headers do this by default; the hand-built card
      headers are what to check.
- [ ] **2.4.12 Focus Not Obscured (Enhanced) (AAA).** Stricter than AA's 2.4.11 —
      **no** part of the focused control may be hidden. Re-run the keyboard pass
      with that reading, watching the tab bar and the sheet detents.
- [ ] **2.4.13 Focus Appearance (AAA).** Measure the focus indicator's area and its
      contrast against the unfocused state, particularly over the calendar's
      filled day cells where the background varies.
- [ ] **2.5.5 Target Size (Enhanced) (AAA).** 44 by 44 px, which is also Apple's
      own Human Interface guidance, so the standard controls should clear it. The
      year heat-map's day cells will not, and the Spacing exception that may carry
      them at AA does not exist here. Record the fail rather than reopening the AA
      decision.
- [ ] **2.5.6 Concurrent Input Mechanisms (AAA).** Alternate between touch and a
      paired keyboard mid-session and confirm neither is locked out.

## 3. Understandable

- [ ] **3.1.3 Unusual Words (AAA)**, **3.1.4 Abbreviations (AAA).** The UI carries
      at least "BAC" and the unit "g". Confirm each is expanded somewhere reachable
      from the screen that shows it.
- [ ] **3.1.5 Reading Level (AAA).** Applies to the user's guide and the privacy
      policy. Record that English and German are hand-authored while the other
      locales are machine-generated, so a judgement made on English does not carry
      to them.
- [ ] **3.2.5 Change on Request (AAA).** No context change happens unrequested.
      The language picker restarts the UI; confirm it is the only one and that it
      is user-initiated.
- [ ] **3.3.5 Help (AAA).** The overflow menu's help entry opens the user's guide
      as a whole, while the criterion asks for help related to the function at
      hand. Decide whether that counts and record the reading — the same decision
      the Android protocol faces, and the two should not diverge.
- [ ] **3.3.6 Error Prevention (All) (AAA).** Extends AA's 3.3.4 to every
      submission. Walk the entry sheet, the drink editor and the export range
      sheet.
- [ ] **3.3.9 Accessible Authentication (Enhanced) (AAA).** The app lock uses Face
      ID or Touch ID with the device passcode as the alternative route. Record which
      the test device actually offers.

## 4. Not applicable to this app (record, do not claim)

- **1.2.6 Sign Language, 1.2.7 Extended Audio Description, 1.2.8 Media
  Alternative, 1.2.9 Audio-only (Live), 1.4.7 Low or No Background Audio.** No
  media.
- **2.2.3 No Timing.** Nothing depends on timing; the app lock's timeout is a
  security mechanism under the criterion's essential exception and is examined
  under 2.2.6.
- **2.2.4 Interruptions.** Nothing interrupts the user: no notifications, no
  network, no background updates to the displayed data.
- **2.3.2 Three Flashes.** Nothing flashes.
- **2.4.9 Link Purpose (Link Only).** Web-scoped; the few links live in the
  documentation screens with their context present.
- **3.1.6 Pronunciation.** No content whose meaning depends on pronunciation.

## 5. Sign-off

- Evaluator (author): ____________________  Date: __________
- Device / iOS version / VoiceOver settings: ____________________
- Result per SC, not per level.
- Outstanding fails: ____________________
