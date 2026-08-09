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

# Libellus Potionis — WCAG 2.2 Level AAA self-assessment protocol (Android)

Purpose: a guided, repeatable manual evaluation for the Level AAA success criteria
(SC) that apply to the Android app. This is a **self-assessment**, not an
independent audit, and it sits on top of
[WCAG_LEVEL_A_ANDROID.md](WCAG_LEVEL_A_ANDROID.md) and
[WCAG_LEVEL_AA_ANDROID.md](WCAG_LEVEL_AA_ANDROID.md): an AAA claim needs every
in-scope SC of all three levels.

Read the W3C's own caveat before spending a session here. The guidelines state
that AAA conformance is not recommended as a general policy for entire sites,
because some content cannot satisfy all of it. The reason to walk this protocol is
therefore to learn which individual AAA criteria the app already reaches — several
do — rather than to reach the level.

Only the SC that this app can actually fail or pass are listed below. The rest are
collected in section 4 with the reason they do not apply, which is what a
conformance record needs from them.

## 0. Setup

As for Level AA, plus: a contrast meter (7 : 1 is the threshold here, not 4.5 : 1),
and Settings → Accessibility → **Remove animations** switched on for one pass.

## 1. Perceivable

- [ ] **1.3.6 Identify Purpose (AAA).** Asks that icons and regions carry a
      programmatically determinable purpose beyond their label. Android exposes no
      general vocabulary for this the way ARIA does on the web; record what the
      platform offers (role, state, content description) and whether anything more
      is available for the bottom bar and the toolbar actions.
- [ ] **1.4.6 Contrast (Enhanced) (AAA).** Expected to fail, and the numbers are
      already on record in `ui/theme/Color.kt`: `successColor` measures 4.50 : 1 in
      the light theme, `warningColor` 3.35 : 1, `dangerTextColor` 3.49 : 1 in the
      dark theme, and `SchieferOnSurfaceVariant` 5.21 : 1 on the cards. The 7 : 1
      threshold is out of reach for the status palette without giving up the hues
      that make the states distinguishable. Re-measure body text separately — it
      may well clear 7 : 1 where the signal colours do not, and that is worth
      recording as a partial result.
- [ ] **1.4.8 Visual Presentation (AAA).** Five sub-requirements: user-selectable
      foreground and background, no more than 80 characters per line, no
      justification, 1.5 line spacing within paragraphs, and 200 % resize without
      horizontal scrolling. The prose screens are where this is decidable — the
      user's guide and the licence viewer. Check line length and spacing there;
      the app offers themes rather than free colour choice, which is a partial
      answer to the first point and should be recorded as such.
- [ ] **1.4.9 Images of Text (No Exception) (AAA).** No text is drawn as an image
      anywhere, including the charts, whose axis labels are real text. Expected to
      pass; confirm the PDF report and the launcher icon are out of scope (a logo
      is the criterion's own exception).

## 2. Operable

- [ ] **2.1.3 Keyboard (No Exception) (AAA).** Everything Level A's 2.1.1 covers,
      with no exception for path-dependent input. Since the app has no
      path-dependent input at all, this reduces to the same walkthrough. Do it with
      a hardware keyboard and confirm the statistics screen's swipe has a keyboard
      route through its arrow buttons.
- [ ] **2.2.5 Re-authenticating (AAA).** When the app lock re-locks and the user
      authenticates again, no data may be lost. Enter a half-finished entry, let
      the lock engage, unlock, and confirm the sheet and its content survive.
- [ ] **2.2.6 Timeouts (AAA).** Asks that users be warned about a data-loss
      timeout. The app lock's inactivity timeout is the only timeout in the app.
      Decide whether it can lose data at all — see the check above — and record
      that rather than a bare pass.
- [ ] **2.3.3 Animation from Interactions (AAA).** Motion animation triggered by
      interaction can be disabled. Run one pass with the system's animation
      removal on and confirm the screen transitions, the chart draw and the
      calendar's month change respect it.
- [ ] **2.4.8 Location (AAA).** The user can tell where they are within the app.
      The bottom bar marks the current screen and each screen carries a title;
      confirm the calendar's month/year mode and the statistics period are equally
      legible as "where am I".
- [ ] **2.4.10 Section Headings (AAA).** Content is organised by headings. This
      shares its fate with 1.3.1 at Level A: the section headers on Settings and
      Statistics are `Text`, not headings with the `heading()` role, and a grep of
      the Compose sources finds no `heading()` anywhere. Both criteria are settled
      by the same small addition.
- [ ] **2.4.12 Focus Not Obscured (Enhanced) (AAA).** Stricter than AA's 2.4.11:
      **no** part of the focused control may be hidden, not merely some of it.
      Re-run the keyboard pass with that reading, watching the bottom bar and the
      snackbar.
- [ ] **2.4.13 Focus Appearance (AAA).** The focus indicator needs an area of at
      least the size of a 2 px perimeter and a contrast ratio of at least 3 : 1
      against the unfocused state. The two custom rings from AA's 2.4.7 are what
      to measure here; the AA criterion asks only that focus be visible, this one
      asks how visible.
- [ ] **2.5.5 Target Size (Enhanced) (AAA).** 44 by 44 px. Standard `IconButton`s
      are 48 dp and clear it. The year heat-map's 10 dp cells do not, and the
      Spacing exception that carries them at AA does not exist at this level, so
      this is a fail unless the year view is excluded from the claim. Record it as
      a fail rather than reopening the AA decision.
- [ ] **2.5.6 Concurrent Input Mechanisms (AAA).** Switching between touch and a
      keyboard mid-session must not be blocked. Nothing in the app restricts input
      modality; confirm by pairing a keyboard and alternating.

## 3. Understandable

- [ ] **3.1.3 Unusual Words (AAA)**, **3.1.4 Abbreviations (AAA).** The UI carries
      at least "BAC" and the unit "g", and the user's guide explains the Widmark
      formula. Check that every abbreviation shown in the UI is expanded somewhere
      reachable from it, and that the guide's glossary covers the terms the screens
      use.
- [ ] **3.1.5 Reading Level (AAA).** Asks for text readable at lower secondary
      level, or a supplementary version. This applies to the user's guide and the
      privacy policy. Note the translation situation when recording: English and
      German are hand-authored, the other locales are machine-generated, so a
      reading-level judgement made on English does not carry to them.
- [ ] **3.2.5 Change on Request (AAA).** No context change happens without the
      user asking for it. Confirm the language switch, which restarts the UI, is
      the only one and is user-initiated.
- [ ] **3.3.5 Help (AAA).** Context-sensitive help is available. The overflow
      menu's help entry opens the user's guide as a whole; the criterion asks for
      help related to the function at hand. Decide whether the guide counts here
      or whether per-screen entry points would be needed, and record the reading.
- [ ] **3.3.6 Error Prevention (All) (AAA).** AA's 3.3.4 applies only to legal,
      financial and data-deleting actions; this extends it to every submission.
      Walk the drink editor and the entry sheet and confirm each is reversible,
      checked, or confirmed.
- [ ] **3.3.9 Accessible Authentication (Enhanced) (AAA).** The app lock uses
      biometrics or the device credential. The enhanced criterion removes the
      object-recognition exception the AA version allows but keeps the alternative
      route: the device credential is that route. Record which mechanisms the lock
      actually offers on the test device.

## 4. Not applicable to this app (record, do not claim)

- **1.2.6 Sign Language, 1.2.7 Extended Audio Description, 1.2.8 Media
  Alternative, 1.2.9 Audio-only (Live), 1.4.7 Low or No Background Audio.** The
  app plays and displays no media.
- **2.2.3 No Timing.** No part of the app depends on timing. The app lock's
  inactivity timeout is a security mechanism, which the criterion's own essential
  exception covers; it is examined under 2.2.6 instead.
- **2.2.4 Interruptions.** Nothing interrupts the user: no notifications, no
  network, no background updates to the displayed data.
- **2.3.2 Three Flashes.** Nothing flashes.
- **2.4.9 Link Purpose (Link Only).** Web-scoped. The only hyperlinks are in the
  documentation screens, where their surrounding text is present by construction.
- **3.1.6 Pronunciation.** No content whose meaning depends on pronunciation.

For each: reason = "native offline app, feature not present", except where a more
specific reason is given above.

## 5. Sign-off

- Evaluator (author): ____________________  Date: __________
- Device / Android version / TalkBack version: ____________________
- Result per SC, not per level: AAA is walked to find out which criteria are
  reached, and 2.5.5 is expected to fail by the same decision that carries 2.5.8
  at AA.
- Outstanding fails: ____________________
