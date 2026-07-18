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

# Libellus Potionis – Changelog

<!-- Add new entries on top! -->
<!-- HEADING CONVENTION: directly below each "## vX.Y.Z" header, write a one-line
     summary formatted as a git commit subject — imperative mood, capitalized, no
     trailing period, at most 50 characters. Leave a blank line, then the detailed
     notes. This makes the entry's first line directly reusable as the subject of
     the release commit/tag (git's recommended ≤50-char subject limit). -->
<!-- RELEASE REMINDER: on every version bump, also add a localized store note
     fastlane/metadata/android/<locale>/changelogs/<versionCode>.txt for
     EVERY locale, keeping the set identical across locales. release-check.sh §1
     enforces both that the current versionCode's note exists in each locale and
     that all locales carry the same set of changelog files. -->

---

## v0.84.0

Move iOS entry delete and edit to edit mode

This version does two things. Its headline is an iOS interaction rework — the
per-row trash and pencil icons on the Today, Drinks and Calendar screens give way
to the native edit-mode-and-tap model Apple's own list apps use — and it also
absorbs the store-path corrections that had been drafted for 0.83.1. **0.83.1 is
cancelled and was never published**; its `versionCode` 95 was never shipped, so
0.84.0 inherits it. The human version therefore steps 0.83.0 → 0.84.0 (a minor
bump), while `versionCode` is 95 — the 94 → 95 step the 0.83.1 cycle made, now
carried by 0.84.0 — and everything that cycle had prepared is folded in below.

### iOS: delete and edit move to the native edit-mode model

The three iOS screens that list rows — Today's entries, the Drinks catalogue and
the Calendar's selected-day entries — each carried a small red trash icon (and,
on the entry rows, an edit pencil) stamped onto every row. That is Android's row
idiom, imported verbatim. Apple's guidance keeps a row's destructive action in an
*edit mode* or a detail view rather than on the face of every row, and reserves a
row's less-frequent actions for a long-press context menu; the
[Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
put it plainly for gestures — offer a visible way to perform an action, but let
edit mode or a context menu carry it, not a permanent per-row button. This change
adopts that model:

- **Delete is now the toolbar `EditButton` plus swipe, on all three screens.**
  `EditButton` toggles the list's edit mode, where each row shows the standard red
  delete badge; a trailing swipe reaches the same place. Both routes are wired
  through a single `.onDelete`, and the button appears only when the list actually
  has something to act on. The per-row trash icon is gone from every screen.
- **Delete is always confirmed now — the parity defect this uncovered.** Android
  removes a Today or Calendar entry only through an `AlertDialog` (`delete_confirm`);
  iOS had been deleting those entries the instant the gesture fired, with no
  confirmation at all — while, inconsistently, it *did* confirm deleting a *drink*
  (a definition rebuilt in seconds) but not a *consumption entry* (a fact the user
  cannot reconstruct). Both entry screens now route their delete through the same
  confirmation the Drinks screen already used (`Really delete “%@”?`, a red
  `Delete`, a `Cancel`), so no entry is ever removed by a single stray gesture.
- **Editing moves off the row.** On Today and Calendar, whose rows had no other
  tap action, the whole row is now the edit affordance — tapping it opens the same
  sheet the pencil used to, and because the row is a `Button`, SwiftUI suppresses
  that tap while the list is in edit mode, so a delete-tap never also opens the
  editor. On Drinks the row tap is already spoken for (it *logs* the drink, the
  many-times-a-day action), so editing and deleting a drink move to the **trailing
  swipe** — the native place for a row's secondary actions when its tap is taken,
  Mail being the model: tap opens, swipe acts. The swipe carries a blue **Edit**
  (labelled with the bare verb, not "Edit <name>", and drawn with the system
  compose glyph `square.and.pencil`) and a red **Delete** (the `trash` glyph on
  red, exactly as Mail and Reminders draw a swipe delete). The `EditButton` edit
  mode still shows the system delete badge — the round red "no-entry" control — so
  deletion keeps a visible, swipe-free path as well. The row's raw tap-to-log is
  gated on the edit-mode state so it stands down while the list is being edited.
- **The Calendar screen was rebuilt from a `ScrollView` onto a `List`.** Swipe,
  the edit-mode badge and `EditButton` live only in a `List`'s `ForEach`, and the
  calendar had none — its selected-day swipe-to-delete simply did not exist. The
  month header, weekday row and day grid now ride in a separator-hidden, inset-
  zeroed section so they keep their edge-to-edge look, and the selected day's
  entries are a second section that carries `.onDelete`. This closes the gap where
  the calendar was the one entry list a user could not swipe.

This adds exactly one user-facing string — the bare verb **`Edit`** for the
Drinks swipe, whose per-locale values are the verb stems already present in the
existing `Edit %@` key (English "Edit", German "Bearbeiten", and so on for all 21
locales), so it introduces no new wording, only a shorter form of words the
catalogue already carried. Everything else the change shows — `Delete`, `Cancel`,
`Really delete “%@”?` — already existed in every locale. Android has no bare-verb
`edit` string (only `edit_drink`/`edit_entry`), so the new key has no Android
counterpart to drift from and the locale-parity gate stays green.

Fixed in passing, a rendering slip the rework sat next to: **the Today row's time
ignored the in-app locale.** Its detail line hard-coded `HH:mm` while the
calendar's identical-looking row used a locale-aware
`setLocalizedDateFormatFromTemplate("Hm")`, so the very same entry read `18:30` on
Today but `6:30 PM` on the calendar for a 12-hour locale — two rows that claimed
to show the same fields while disagreeing on one. Today now shares the calendar's
formatter setup, and the calendar's own stale `HH:mm` docstring (its code was
already correct) was corrected to match.

Also silenced a build warning the Swift 6 compiler raised on the test suite:
`PreferencesStoreTests.testClearingTheFloorSurvivesTheNextLaunch` wrote `await
makeSeedingStore(...)` on a line that only *constructs* the store — the sibling
call sites `await` the store's `load()`, which is `async`, but this one has no
`.load()`, so the `await` covered nothing and drew "no 'async' operations occur
within 'await' expression". The stray `await` is removed; the `load()` on the next
line keeps its own.

And stopped the build from rewriting the String Catalog. With Xcode's default
"Use Compiler to Extract Swift Strings" (`SWIFT_EMIT_LOC_STRINGS`) on, a build that
found anything to update rewrote `ios/Potillus/Localizable.xcstrings` — re-extracting
the direct `String(localized: "…")` plurals and reformatting every line (Xcode
writes `"key" : value`; the committed file is stored `"key": value`) — which left a
spurious one-file change that intermittently blocked `git pull` with "commit your
changes or stash them". The setting is now pinned to `NO` in `ios/project.yml`: the
catalog is the committed, manually-maintained source of truth (its parity is guarded
by `check-l10n-parity.py`, not by Xcode's extractor), and it is still compiled into
the bundle, so only the write-back is suppressed — the runtime is unchanged.
`make ios-project` must be re-run once so the generated project picks the setting up.

And made the code-signing Team ID survive project regeneration. `ios/project.yml`
pinned `DEVELOPMENT_TEAM: ""`, and because `xcodegen` rewrites the entire
`.xcodeproj` on every `make ios-project`, any team chosen by hand in Xcode's
Signing & Capabilities editor was wiped on the next generate — Xcode then demanded
a team again on the next device run. The value is now read from the
`DEVELOPMENT_TEAM` environment variable (`"${DEVELOPMENT_TEAM}"`, which XcodeGen
expands at generate time), so a per-machine `export DEVELOPMENT_TEAM=…` in the
login shell is baked in on every regeneration without an account-specific value
entering the tree. Unset, it expands to empty — the previous behaviour, so clones
and CI are unaffected. It reuses the same variable `make release-ios` already
honours, so one export serves both development and release signing.

Updated the English App Store release notes to describe the new edit/delete
interaction. The pending `en-US/release_notes.txt` still said an entry "can be
edited or deleted from the row itself" — the 0.83.0 row buttons — which the
edit-mode/swipe rework above supersedes. It now describes tapping to edit and
swiping to delete on Today and Calendar, the swipe Edit/Delete on the drink list,
and the toolbar Edit button. The other locales' release notes are deliberately not
touched yet (they still trail at 0.83.0 and are pulled through at release time).

### Folded in from the cancelled 0.83.1: store upload path fixes

The rest of this entry is the 0.83.1 work, unchanged in substance and now shipping
as part of 0.84.0. It exists because publishing v0.83.0 for real found path
defects that no gate could have caught: they live in the seam between this
repository's layout and what fastlane assumes about it, and only speak when a
store is actually on the other end. v0.83.0 was tagged and its bundle is in the
Play alpha track, so its entry below is closed; the corrections belong here.

The store notes are still English-only: `changelogs/95.txt` exists for `en-US`
(now describing 0.84.0), and the remaining 20 locales — plus the iOS
`release_notes.txt`, which are not versionCode-keyed and still describe the 0.83.0
changes the App Store has yet to receive — follow at release time, once this cycle
has taken its final shape.

- **The Play preflight looked for the key one directory too deep.** `push-playstore`
  passed `fastlane/play-store-credentials.json` — repo-root-relative, and correct
  as such — into a `( cd fastlane && bundle exec fastlane run ... )` subshell,
  which resolved it against `fastlane/` and asked for
  `<root>/fastlane/fastlane/play-store-credentials.json`. The upload never
  started. What makes this worth more than a one-character fix is the rule it
  exposed, which the comment above the target had stated too broadly: a fastlane
  LANE is chdir'd back to the project root, so `aab:`/`ipa:` may be
  root-relative — that half was right, and the same run proved it by uploading
  `releases/…_94.aab` — but a `fastlane run` ONE-OFF gets no such chdir and
  resolves against the shell's cwd. The Makefile has exactly one `fastlane run`,
  and it now receives an absolute path: a new `PLAY_JSON_KEY` resolves the
  Appfile's own default (or `SUPPLY_JSON_KEY`, relative or not) through make's
  `$(abspath)`, at parse time, from the repository root. `$(abspath)` and not
  `realpath`, which macOS does not ship without coreutils. The Appfile's relative
  default stays exactly as it is: it is read by lanes, which run from the root,
  where it is right.
- **deliver was never told where the iOS listing lives.** `upload_to_app_store`
  aborted with "Unsupported directory name(s) for screenshots/metadata in
  './fastlane/screenshots': ios". The cause was a claim in the Fastfile —
  "Metadata + screenshots come from fastlane/metadata/ios/ (the default path once
  platform is ios)" — that is simply untrue: deliver's defaults are
  `./fastlane/metadata` and `./fastlane/screenshots` and do not consult `platform`
  at all. Pointed there, it read this repository's platform-qualified `android`
  and `ios` directories as LOCALE names and rejected them. The listing is
  platform-qualified on purpose — `fastlane/metadata/ios` beside
  `fastlane/metadata/android`, which supply and F-Droid share; `Snapfile`'s
  `output_directory` writes the screenshots to `fastlane/screenshots/ios`;
  `check-ios-metadata.py` reads `fastlane/metadata/ios` — so the tree is right and
  the configuration was missing. `metadata_path` and `screenshots_path` are now
  passed explicitly, and the comment that asserted the opposite is gone. Note that
  the screenshots error hid an identical one behind it: `metadata` would have
  failed next, for the same reason.

- **Three iOS store locales were named in the wrong namespace.** With the paths
  fixed, deliver got far enough to reject the next thing: "Unsupported directory
  name(s) ... : es, fr, nl". App Store Connect takes `es-ES`/`es-MX`,
  `fr-FR`/`fr-CA` and `nl-NL`; bare `es`, `fr` and `nl` are not on its list. They
  are, however, perfectly good Xcode language tags — which is exactly how they
  got there, and why they read as correct: `ios/Potillus/Localizable.xcstrings`
  still calls those languages `es`, `fr` and `nl`, and rightly so. The store
  directories are a different namespace that merely resembles it. All three are
  renamed, in `fastlane/metadata/ios/` and `fastlane/screenshots/ios/` alike, to
  the names the Android side has always used: `es-ES`, `fr-FR`, `nl-NL`.
  `es-MX`/`fr-CA` would have been a reach decision rather than a correction, and
  the app's own translations are the generic variants. Nothing else needed
  touching: `Snapfile` derives its `languages` from the metadata directory names
  and `IOS_SCREENSHOT_LOCALES` derives from the same glob, so both follow;
  `check-l10n-parity.py`'s language list is catalogue tags, not store locales,
  and stays as it is.
- **...and the gate that should have said so, said nothing.** `check-ios-metadata.py`
  enforced lengths, file-set parity and non-empty essentials, but had no opinion
  about locale NAMES — the one property deliver checks first and this repository
  had wrong. It now carries App Store Connect's accepted list and rejects
  anything outside it, naming the valid locales that share the bad name's
  language subtag ("did you mean es-ES or es-MX?") without choosing between them.
  The list deliberately omits deliver's `appleTV`/`iMessage`/`default`
  pseudo-locales: this app ships none, and admitting them would let a typo pass
  as intent. Checking the metadata names covers the screenshot names too, since
  the Snapfile generates the latter from the former.

- **The report screenshots were A4 where the App Store wanted a phone.** Past
  the locale names, deliver rejected 42 files at once: shots 07..08 are the
  app's PDF report rasterized by pdftoppm, so at the project's 200 dpi they are
  1654x2339 — an A4 page, aspect 0.71, beside six simulator shots at the iPhone's
  own 1206x2622, aspect 0.46. That the six passed unremarked is what identifies
  the rule: Play's requirement is a RANGE (320..3840 per side, at most 2:1) that
  an A4 page satisfies comfortably, and the App Store's is an ENUMERATED set of
  real device resolutions that it does not. The pages had been that shape since
  they were first rendered; only Play had ever seen them.
  - `screenshots-ios` gained two steps. Step 4 runs the new
    `tools/letterbox-ios-report.py`, which scales each page to the canvas WIDTH
    — the one scale that keeps A4's proportions — and centres it on the app's
    identity colour `#1A1E2B`, the `ic_launcher_background` of
    `values/colors.xml` and the `ICON_BG` of `render-feature-graphic.py`. A
    neutral grey would have read as a letterbox bar, i.e. as something missing;
    the white page on the app's own dark navy reads as a document on a surface,
    and holds its edge against the store's chrome in either appearance. The tool
    takes the canvas size from the locale's own shot 01 rather than a constant:
    that cannot drift when `IOS_SIM_DEVICE` changes, and cannot be wrong, since
    01 came out of a simulator at a real device's real resolution. It is
    idempotent, so a second run over a finished tree changes nothing.
  - Step 5 is the gate that should have existed: `tools/check-ios-screenshots.py`,
    the counterpart to `validate-screenshots.py`, which says in its own first
    line that it is the *Google Play* gate and reads only the Android tree. The
    new one deliberately does NOT carry Apple's size table. That table is
    Apple's, it moves with each device generation, and a stale copy here would
    fail on its own schedule. It checks UNIFORMITY instead — every shot in a
    locale agrees with the others, every locale agrees with the rest — which
    needs no table and catches the entire defect, because 01..06 are a valid
    size by construction and the A4 pages were the things disagreeing with them.
    Its limit is stated in its own docstring rather than hidden: a wrong
    `IOS_SIM_DEVICE` would be uniformly wrong and pass.
  - This is the fourth defect of one family in this cycle, and the family is now
    named: every one of them lived where this repository's shape meets what
    fastlane and the stores assume about it, every one was invisible to a gate
    written for the Android half, and every one waited for a real upload to
    speak. The iOS side now has the three gates the Android side always had.

- **The App Store reviewer contact was a placeholder, and is now a secret.** The
  fifth and last defect of the family, and the one the family had been building
  towards: `review_information/` was excluded from `check-ios-metadata.py` as
  "not a locale", so it was checked by nothing whatsoever, and reached its first
  real upload still holding the PLACEHOLDER text it shipped with. Apple rejected
  two of the four fields — the email had no `@`, the phone no leading `+` and 51
  bytes where 20 are allowed — and, having no format rule for names, would have
  passed "PLACEHOLDER: reviewer contact first name" straight to the review team.
  The failure is what prevented the embarrassment.
  - The four fields are now git-ignored and set up once per machine from
    `*.txt.example` templates, the same shape `ios/signing.properties` already
    has. Apple asks for a person reachable by phone; a public repository should
    not answer that. The maintainer's name and address are in every file header
    already, so the phone number is the one genuinely new exposure — but the four
    are one contact, and splitting them would only invite the next person to
    commit the rest. `notes.txt` and the two empty demo-credential files stay
    committed: they state that the app has no login, which is a fact about the
    app, not about a person.
  - `check-ios-metadata.py` gained the section that was missing. It checks the
    two fields Apple checks — email shape, and the phone's leading `+` and
    20-BYTE limit, measured after encoding, because Apple said bytes — and the
    two it does not, which is where it earns its keep. Absence is not failure:
    the files are git-ignored, so a fresh clone legitimately has none and is told
    so rather than failed. A HALF-filled contact is failure, since no clone
    arrives at one by itself.
  - And `push-appstore` now runs the gates. `make ios` had always run
    `check-ios-metadata`; the upload path never did. That is the whole lesson of
    this cycle in one line: four attempts, each rejected by a store for something
    a gate could have said in a second, on a repository that already owned the
    gate. It now requires the four contact files outright and runs both iOS
    checks before a byte goes over the wire.

- **The rating answers are now written down, because nothing else writes them
  down.** Every other part of both listings lives here and has a gate: texts,
  screenshots, categories, the copyright line. The two age-rating questionnaires
  do not — they are filled in by hand, in two consoles, and until now the answers
  and the reasoning existed nowhere. `docs/STORE_RATINGS.md` is that record, and
  its subject is not the numbers (both consoles show those) but the fact that
  **the two stores ask different questions and the answers are not
  transferable**:
  - Apple asks about CONTENT on a frequency axis — "Infrequent: Users will
    rarely encounter this content" vs "Frequent: Users will regularly encounter
    this content". For an app whose Drinks screen ships a catalogue of alcoholic
    beverages, whose BAC estimate ticks every minute and whose statistics count
    binge days, "rarely" is not an interpretation but a false statement.
    `Frequent` → **18+**.
  - Google asks about PURPOSE, and its section heading gives it away —
    "Bewerbung oder Verkauf von Produkten oder Aktivitäten mit
    Altersbeschränkung": is promoting or selling the app's *focus*? It advertises
    nothing and sells nothing. `No` → **IARC generic 3+**.
  - Same app, same facts, both true, and the outcomes as far apart as the scales
    reach. 18+ beside 3+ is not an error waiting to be reconciled, and the file
    says so in as many words — because the next person to see them side by side
    will want to "fix" one, and that is the only way this can go wrong.
  - What neither console has a field for is what the app IS: a harm-reduction
    tool, full of references to the thing it exists to reduce. Apple sees the
    references and not the point; Google sees no commerce and not the references.
    The single place in either process where the purpose can be stated is the
    reviewer note, so `review_information/notes.txt` now states it — that the app
    depicts and encourages no drinking, marks every excess red, counts abstinent
    days, and answers the questionnaire on frequency because that is what it asks.
  - Also recorded: the target audience (16–17 **and** 18+) is a product decision,
    independent of both questionnaires — wanting 16-year-olds as users does not
    make the app's alcohol references rarer. And a consequence worth knowing:
    Play's "restrict access for minors", which actually removes an app from
    search and download rather than merely labelling it, requires 18+ to be the
    ONLY selected group, so selecting 16–17 puts it deliberately out of reach.

- **`check-ios-screenshots` became a target, which it should have been at birth.**
  It was added earlier this cycle and then invoked only by `python3` from
  `screenshots-ios` and `push-appstore` — no make target, absent from `.PHONY`,
  absent from `check-ios-static`, unlike `check-ios-metadata`, which has had all
  of those for a release. The gap mattered: the shots it guards are COMMITTED, so
  they can be wrong in a tree nobody is capturing or uploading from, and a gate
  that only runs at the two ends of the pipeline would never say so. It now sits
  beside its sibling in `check-ios-static`, which is the list a Mac-free release
  path runs.

- Also fixed in passing: `PRIVACY.md` still sent the reader to
  `docs/PLAY_STORE.md` for "the two supported ways to turn this file into a
  public URL". That document was deleted in v0.79.0, and v0.81.0's cleanup of the
  references to it caught `fastlane/Fastfile` and `fastlane/README.md` but missed
  this one — so the pointer had outlived its target by four releases, and the
  hosting question it deferred was answered nowhere at all. It is answered now,
  from the tree rather than from a memory: every locale's `privacy_url.txt`
  points at `PRIVACY.md` in the canonical repository, so the served policy and
  the committed one are the same file and cannot drift.

---

## v0.83.0

Fix iOS presets, cold-start lock and freezes

This opens the 0.83.0 cycle with the version bump — `versionCode` 93 → 94 and
the human version 0.82.0 → 0.83.0 — to take the iOS app to the public App Store
listing via the `ios testing` lane. The App Store export-compliance declaration is
already in place (`ITSAppUsesNonExemptEncryption` = NO in `ios/project.yml`), so no
change is needed there. The iOS app icon introduced in 0.82.0 is also enlarged —
less padding, so the glass matches its on-device Android appearance (Android's
adaptive-icon mask crops more of the border) — regenerated crisply at 1024×1024
from the vector master at `ios/icon/appicon.svg`. The cycle then folds in the
fixes from the eleventh, twelfth and thirteenth QA reviews — the first three to
review Android, iOS and the cross-platform seam between them as one subject, the
twelfth being the first to review a 0.83.0 that had already been reviewed once,
and the thirteenth finding no defect in either app: everything it changed is a
statement the repository makes about itself. The final,
localised release notes are now in place: the English Android note and the
English iOS note are translated into all 20 further store languages (the two
stores' notes still need not match, and do not).

- **Localised store release notes for both stores.** The English Android note
  `fastlane/metadata/android/en-US/changelogs/94.txt` and the English iOS note
  `fastlane/metadata/ios/en-US/release_notes.txt` are translated into the 20
  further store languages each store lists (Android: `cs-CZ` … `zh-TW`; iOS:
  `cs` … `zh-Hant`). Terminology is taken from the in-app strings — screen and
  option names such as Today, Statistics, Calendar, Drinks, Settings, About,
  "(System)", "Replace", the abstinent-days and daily-limit wording — as found
  in `android/app/src/main/res/values-*/strings.xml` and
  `ios/Potillus/Localizable.xcstrings`, so a store note never names a screen
  differently from the app itself; quotation-mark style follows each locale's
  existing `full_description.txt`, and the iOS wording avoids addressing the
  reader directly. Google Play's 500-character limit is counted the way
  `release-check.sh` §10 counts it (Unicode code points including the trailing
  newline); the longest notes come in at 498 (`es-ES`) and 494 (`de-DE`), the
  es-ES and fr-FR drafts having been tightened to fit. The App Store notes stay
  far below the 4000-character limit (longest: `fr` at 1923). Adding the 20 iOS
  files also turns `check-ios-metadata.py` green again: its file-set-parity
  rule had been failing since the en-US `release_notes.txt` arrived alone.
  Also fixed in passing: the RELEASE REMINDER comment at the top of this file
  still pointed at `android/fastlane/metadata/android/…`, the tree's location
  before the v0.73.2 move of fastlane to the repository root.

- **`clean` and `distclean` became four honest targets.** Both delegated to
  `android/` and nothing else, so on a tree with two platforms their names
  promised twice what they delivered: every iOS artifact — the xcarchive, the
  exported `.ipa`, the generated Xcode project, `Version.xcconfig`, the copied
  license, the rendered guides, SwiftPM's caches — survived a `make distclean`
  untouched. They are replaced by `clean-android`, `distclean-android`,
  `clean-ios` and `distclean-ios`, following the `-android`/`-ios` convention the
  rest of the file already uses for `release-*` and `screenshots-*`. There is no
  plain `clean`/`distclean` any more: a name that covers one of two platforms is
  worse than no name.
  - The clean/distclean split is the one `android/Makefile` already drew, now
    stated once for both platforms: `clean` is build output (regenerated by the
    next build), `distclean` additionally removes the generated sources a build
    needs before it can start. `distclean-ios` therefore depends on `clean-ios`,
    as Android's `distclean` depends on its `clean`; the inventory it clears is
    `ios/.gitignore`, and each line names the target that regenerates it.
  - None of the four touches `releases/`. Those are staged artifacts that
    push-appstore/push-playstore verify and upload, and that release-ios refuses
    to overwrite; clearing them is a decision, not housekeeping.
  - The `rm -f *.patch *.log *.orig` the old targets carried is gone rather than
    duplicated into both halves: it is not an artifact of either platform's
    build, and `git clean -n` answers that question more honestly than a glob.
  - Also fixed: the `.PHONY` list was missing `push-appstore` and
    `push-appstore-preflight` — an oversight from when they were added earlier
    this cycle. And the cascade-stamp comment still said `make clean`.

- **`make push-appstore` — the iOS app now publishes through the same door as the
  Android one.** `push-playstore` guards the Play upload four ways before fastlane
  sees it; the App Store path had no counterpart at all, so the documented route
  was a bare `fastlane ios testing`, bypassing every one of them. It now mirrors
  push-playstore where the platforms agree and diverges only where they genuinely
  differ.
  - Same guards: the staged artifact must exist (the target never builds), and the
    release tag `vX.Y.Z` must exist locally AND on the push remote.
  - Instead of a signing-key fingerprint pin, two checks that fit what an iOS
    signature actually is. The `.ipa`'s own `Info.plist` must agree with the tree
    — `CFBundleIdentifier` = the applicationId, `CFBundleVersion` = the
    versionCode, `CFBundleShortVersionString` = the CHANGELOG's top version — which
    catches the everyday mistake the Android side cannot: pushing a stale `.ipa`
    left in `releases/`. It is a real cross-check, not a tautology, because those
    values reach the `.ipa` through `gen-ios-version.py` → `Version.xcconfig` →
    Xcode, not from this Makefile. And the signature must verify and carry OUR
    `TeamIdentifier`. A certificate-digest pin was considered and rejected: Apple
    issues that certificate, it rotates yearly, and under this project's automatic
    signing Xcode mints it at export time — pinning it would schedule an annual
    false failure while proving less than the Team ID does. `SECURITY.md`'s
    fingerprint is the Android key and stays that.
  - `SUBMIT=1` switches from the `ios testing` lane to `ios production`, i.e. adds
    the review submission. The default does not submit, mirroring how
    push-playstore's production counterpart stages a draft rather than publishing.
  - New `preflight` lane + `make push-appstore-preflight`: the App Store Connect
    counterpart of push-playstore's `validate_play_store_json_key` pre-flight. It
    authenticates and makes one read-only `app_store_build_number` query, so a bad
    key or an unreachable app record fails before anything is uploaded. It could
    not follow the Android shape of a `fastlane run` one-off from the Makefile:
    the iOS credential is a HASH, and fastlane's CLI takes only primitive types.
    Hence a lane. It doubles as the closest thing this platform has to
    `VALIDATE_ONLY=1` — deliver has no validate-only mode.
  - The pre-flight is a PREREQUISITE, not a `$(MAKE)` call inside the recipe, and
    that is load-bearing: under `.ONESHELL` the recipe is one script, so a
    `$(MAKE)` anywhere in it makes the whole script a line containing `$(MAKE)` —
    which make runs even under `-n`. `make -n push-appstore` would have published.
  - `docs/RELEASE-IOS.md` routed the reader to the bare fastlane call and did not
    say that `ios testing` overwrites the live listing; it now names the target,
    the guards, the `SUBMIT=1` switch and what App Store Connect still curates by
    hand. The `help` block gained both targets, and `release-ios` now prints the
    App Store destination next to the TestFlight one it already printed.

- **The fastlane files now describe the fastlane files.** Reviewing the upload
  path for the notes above surfaced three comments that had fallen behind the
  code they introduce — the same class of finding as the thirteenth round's, in
  the one corner that round did not read.
  - `Fastfile`'s head comment opened with "Currently this defines a single lane,
    `screenshots`" and pointed at `android/Makefile` for the target that invokes
    it. There are now seven lanes across two platforms, and both screenshot
    targets live in the top-level `Makefile`. The head comment now names the two
    platform blocks and their lanes, states the property they share (no lane
    builds anything) and hands off to the per-lane `desc` text rather than
    restating it.
  - `Appfile`'s head comment called itself "shared identity for fastlane's
    Google Play actions … consumed by the `testing` lane". It carries the iOS
    `app_identifier` as well, and the Play values are read by `production` no
    less than by `testing`. The head now says both, and the bottom-of-file iOS
    comment it grew a companion to is left as it stands: that one was right.
  - `Fastfile`'s `upload_appstore` claimed "Never overwrite the (manually
    curated) age rating or pricing" above `force: true` and
    `precheck_include_in_app_purchases: false`. Neither option does that:
    `force` skips deliver's HTML-preview confirmation prompt, and the precheck
    switch turns off an in-app-purchase scan for an app that has none. Each
    option now carries a comment stating what it actually does; the claim, which
    described no code, is gone.

- **The repository's claims about itself now match the repository (thirteenth QA
  round).** The thirteenth round found no defect in either app — the gates were
  green, `swift test` ran 408 green, Kover stood at 96.9% line coverage, and the
  deep passes over crypto, the app-lock boundary, the tickers, the backup caps
  and the shared vectors turned up nothing to fix. What it found was five places
  where the tree says something about itself that is no longer true. That is the
  characteristic yield of a thirteenth pass, and it is the class this cycle has
  been working through since the twelfth round's `copyright.md` nachlass.
  - `SettingsModel`'s header still held the block "TWO SETTINGS THIS SCREEN DOES
    NOT SHOW", promising that `biometricEnabled` and `allowScreenshots` would
    appear "when LocalAuthentication and the screenshot suppression land". They
    landed — in this cycle. The rule the block was built on is too good to lose
    and is now stated as the one that was MET: a switch that flips a flag nothing
    reads is worse than a missing switch, which is why `SettingsScreen` shows the
    app-lock switch only where `BiometricAuthenticator.canEvaluate()` is true and
    puts a line of explanation where the switch would be when it is not.
  - COPYING.md described the fonts in the sample report PDFs as Roboto "in every
    file, plus Noto Sans CJK" in the four CJK ones. Measured with `pdffonts`, and
    again independently against the raw PDF streams: the seventeen Latin-, Greek-
    and Cyrillic-script files embed only Roboto; the `ja`, `ko`, `zh-CN` and
    `zh-TW` files embed only Noto Sans CJK — the WebView picks one family per
    document, it does not mix them. Nothing was unattributed; the claim was too
    WIDE, not too narrow, which is the rarer way for an inventory that promises
    completeness to be wrong.
  - The best-practices self-assessment still answered as an Android-only project
    in six places. `copyright_per_file` and `license_per_file` enumerate the file
    classes carrying the header and omitted Swift — while all 112 Swift files
    carry it and `check-headers.py` has been enforcing `.swift` all along, so the
    evidence was weaker than the truth. `OSPS-QA-06.02` named only the JVM suites,
    `OSPS-BR-05.01`/`OSPS-QA-02.01` only the Gradle catalogue and not
    `Package.resolved`, `OSPS-DO-07.01` called the project "a standard Android
    Gradle project". Every criterion was and stays Met; only the justifications
    grew the second platform. No status changed, and the `.jsonc` view follows.
  - CONTRIBUTING.md said "The `Makefile` is not needed for iOS work at all" —
    contradicted by `docs/INSTALL-IOS.md`, the document that sentence points at
    ("The build is driven by the repository's `Makefile`"), by `make ios` itself,
    and by CONTRIBUTING.md four lines earlier, which tells the reader to run
    `make check-swift-tests`. It is a survivor from before `make ios` existed, and
    following it walks a contributor straight past `check-ios-static` and its
    eleven checks.
  - `docs/INSTALL-IOS.md` called `gmake ios-version-check` "the release gate". It
    is not a gate: no target depends on it, and none should — `ios-project`
    regenerates `Version.xcconfig` before XcodeGen reads it, so in the make path
    the check is structurally redundant, and wiring it into `check-ios-static`
    would only add a gate that skips in every tree where the gitignored file is
    absent. The Makefile's own wording had it right ("suitable for a release
    gate"); the doc now says the same, and says where the check still earns its
    keep — by hand, after a version bump, if you drive `xcodebuild` directly.
- **The German-comment gate reads the tooling too (thirteenth QA round).**
  `release-check.sh` §7 quotes CONTRIBUTING's "all source code … build files" and
  scanned Kotlin, three named build scripts and Swift — not the 5,700 lines of
  Python and shell under `tools/`, which the convention has always covered and no
  gate ever read. This is the same widening the round before made for
  `build.gradle.kts`, and this time it is prevention rather than repair: probed
  first, `tools/` was already clean. The gate was then probed the other way —
  German planted in a `.py` and in a `.sh`, each made it fire, each removal made
  it silent — because a gate nobody has watched fire is not evidence. It skips
  gracefully when `tools/` is absent, like the iOS branch beside it.
- **Fixed: a fresh clone could not build, and a source tarball broke on its
  second try (twelfth QA round).** Three findings with one root: a gate that
  meets a BUILD PRODUCT and does not know what it is looking at.
  - `make ios` failed on the FIRST run in any fresh tree — clone or tarball,
    git or no git. `check-ios-guides` sits in `check-ios-static`, which runs
    BEFORE the `ios-project` target that renders the guides, and
    `render-guide-ios.py --check` counted a guide that had never been rendered
    as "stale". It has drifted from nothing: absent is the normal state of a
    fresh clone (git tracks no file under `Resources/`, so the directory does
    not exist) and of the Linux release path, where `make ios` never runs. Both
    checkers now tell missing from stale — Android's `render-guide.py` had the
    identical bug, hidden only because `make android` happens to run
    `check-guides` after the build; standalone it failed the same way. Its
    "Run `make guides` and commit the result" also lost the "and commit": the
    guides have been gitignored for a long time.
  - `check-headers` failed in a source tarball once anything had been built,
    and `make fix-headers` would have written this project's section 7 pointer
    INTO the verbatim GPLv3 text. Outside a git checkout the tool walks the
    tree instead of asking `git ls-files`, and 0.83.0's four generated license
    copies and 21 iOS guides were not in the walk's skip sets — only the
    now-deleted `copyright.md` was. `SKIP_DIRS` gained `raw` and `Resources`,
    which is how the same file already handles `fonts`, `fonts-src` and
    `metadata`; both directories hold build products exclusively (zero tracked
    files, measured), and no others by those names exist. `license_gpl2.md`
    had escaped by luck: the GPLv2 appendix writes "free software; you can
    redistribute" with a semicolon, so the anchor missed.
  - `tools/render-copyright.py` is gone. It existed to CONCATENATE COPYING.md
    and the license texts into the single `copyright.md` this cycle deleted;
    with one input per output it had one job left that `cp` cannot do — create
    the output directory — and two it did not need to do: normalise the
    trailing newline and pin LF. Every input already ends in exactly one LF and
    holds no CR, so its output and `cp`'s were byte-identical (measured). The
    Makefile rules are `mkdir -p` plus `cp`; Gradle's three `Exec` tasks are
    `Copy` tasks; `check-guides` compares the copy against its source directly.
    The `mkdir -p` is the load-bearing part: git cannot track an empty
    directory, so `res/raw/` and `ios/Potillus/Resources/` do not exist after a
    clone and a bare `cp` fails with "No such file or directory".
  `MarkdownText`'s thematic-break branch outlived its stated reason twice over
  and now has a durable one: the guides under `docs/guide/*.md.in` are
  hand-written Markdown, and a `---` is ordinary Markdown their author may reach
  for. A renderer that handles a construct only while some document happens to
  contain one is a trap for whoever writes the next document.
- **The third-party inventory is complete on both sides (twelfth QA round).**
  Checked against the actual `releaseRuntimeClasspath` rather than the build
  script: 156 artifacts, and every one of them falls into a copyright-holder
  family COPYING.md already names — so nothing the APK/AAB ships was
  unattributed. The list that was short is the one that promises "for
  completeness": the build- and test-time dependencies. `androidx.compose.ui:ui-tooling`
  was missing (it is `debugImplementation`, and its presence on the release
  classpath was tested, not assumed — absent, unlike its sibling
  `ui-tooling-preview`, which is a real release dependency and was already
  listed). So were the iOS side's tools, while the Gradle plugins were all
  there: XcodeGen, SwiftLint and fastlane now have their own subsection under the
  iOS heading, all MIT, with the note that the `tools.fastlane:screengrab` Gradle
  artifact is a different, Apache-2.0 thing. And "APK/ABB" was a slip for AAB —
  the Android App Bundle — three times over.
- **The Drinks tab's traffic-light dots follow the clock (twelfth QA round).**
  Every figure behind a dot is scoped to TODAY — today's grams, and the seven-day
  window ending today — and nothing fires on the passage of time. So a Drinks tab
  left open across the day-change boundary kept colouring its dots against
  YESTERDAY's consumption, and an app foregrounded onto that tab after a night in
  a pocket did the same. The dot exists to inform the tap that has not happened
  yet; it corrected itself on the next log, which is to say after the decision it
  is there to inform. `DrinkCapacityModel` is the FOURTH iOS model whose state is
  a function of "now", and the eleventh round — which gave Today, Statistics and
  Calendar their tickers — did not find it. It has one now: day-keyed like
  StatsModel's and CalendarModel's, so the two queries rerun only when the
  logical day actually moved, plus a reload on the scene turning active, because
  `onAppear` does not fire on foregrounding. Android never had the gap: its
  DrinksScreen builds the same `DrinkCapacity` from `TodayViewModel`'s state,
  which has been ticking since its own review rounds. Four new tests, in a new
  `DrinkCapacityModelTests` — the existing suite drove the VALUE type and never
  the model, which is exactly how the missing ticker stayed green. One rolls the
  day over by advancing the clock alone. (Those four tests were written against
  an assumed drink row and died on the FOREIGN KEY before they reached the
  ticker; they log a real drink now.)
- **The iOS statistics chart says what its numbers mean (twelfth QA round).**
  Android has drawn a dashed red daily-limit line across that chart since it
  existed, and reddened the bars above it; iOS drew every bar in the accent
  colour and no line at all — the screen showed the figures without the one mark
  that says whether they are good or bad, directly above a card counting days
  over that same limit. It was not an idiom difference: `StatsState.limitInfo`
  was already computed and stored, and NOTHING read it, which is the shape of a
  feature that was ported half way. The app's own PDF report draws the line. The
  chart now draws it too — `RuleMark` at the limit, dashed, and
  `AlcoholCalculator.isOverLimit` (not a bare `>`: the totals are summed from a
  0.1 g grid, and the shared 1e-6 epsilon is what makes the bar redden on exactly
  the days the count above it counts). Suppressed in the YEAR view, where the
  buckets are monthly averages and a DAILY limit is not their reference —
  Android's `showLimitLine = !isYear`, restated. `Color.red`, not Android's
  hand-tuned hex: this screen already reads the system semantic colours. The
  chart moved into an extension, because it pushed the view past SwiftLint's
  `type_body_length`.
- **Fixed: a restored iPhone silently hid its own history (twelfth QA round).**
  The first-launch seed that gives a new installation a statistics floor was
  triggered by `readFromDisk()` returning nil — which means absent, unreadable,
  wrong key, OR tampered — while its own documentation said, correctly, that only
  the FILE'S ABSENCE is an honest signal for "this user has never been asked".
  The gap is reachable: the preferences key is `ThisDeviceOnly`, so restoring a
  device backup onto a new phone brings `prefs.bin` back without the key that
  opens it. A user who had opted their log into the device backup then got their
  whole restored history floored at the RESTORE date — every statistic silently
  starting today, with nothing on screen to say why. `load()` now probes
  `fileExists` before reading, which is the signal the documentation always
  claimed and the same one `AppDatabase.openOrCreate` uses for the preset drinks.
  A file that exists has been written by this app; whatever went wrong with it,
  its owner HAS been asked, so the defaults — no floor, the whole history — are
  the honest answer, and the real settings come back through the JSON backup,
  which is the supported path. Two tests pin it, including that an unreadable
  file is not rewritten: the seed persists what it seeds, so seeding there would
  have destroyed the very bytes a future key recovery would need.
- **iOS accessibility labels are enforced, not remembered (twelfth QA round).**
  `release-check.sh` §13 has failed the Android build for an interactive
  `IconButton` whose icon carries `contentDescription = null` since its own
  review rounds. The iOS side had no counterpart — the convention held because
  somebody remembered it. All eleven icon-only buttons were in fact labelled;
  nothing was watching, and a rule enforced on one platform and remembered on the
  other is how two platforms drift. `tools/check-ios-a11y.py` is that
  counterpart: brace-aware like the Android scanner, it isolates each `Button`
  with its argument list, its closures and its trailing modifier chain (where the
  label almost always sits) and reports one only when the label is an `Image`,
  carries no `Text` or `Label`, and no `.accessibilityLabel` is attached. It
  skips gracefully when `ios/Potillus/` is absent, and is wired into
  `make check-ios-static`. Probed before being believed: a violation planted in
  two different files and two different `Button` shapes made it fire, and its
  removal made it silent again. Decorative images outside a Button are
  deliberately not checked — they are furniture, not controls, and Android's gate
  draws the same line.
- **Documentation and gate corrections (twelfth QA round).** Removing the
  combined `res/raw/copyright.md` earlier in this cycle left references to it
  behind in five places, each now describing a file that no longer exists:
  `DocumentViewerScreen.swift`'s header still called the screen the viewer of
  COPYING.md-plus-the-GPL (Android's KDoc for the same role had been brought up to
  date; the iOS twin had not), `PdfReportBuilder` pointed at a Makefile note that
  had moved, `MarkdownText`'s thematic-break branch justified itself by that
  document's three concatenated parts, and `release-check.sh` twice listed it
  among "excluded" verbatim texts — which the markdown check does not exclude so
  much as never name, since it runs over an explicit file list. The break branch
  STAYS: no document the app now bundles contains a rule, but
  `render-copyright.py` keeps its concatenation ability and still joins with
  exactly that separator, so the day a build passes it two inputs again the seam
  must not surface as three hyphens. `.gitignore` said the iOS licence copy is
  generated from COPYING.md; the Makefile says `LICENSE.md`. `render-copyright.py`'s
  docstring made its "single source of truth" point twice.
  `check-ui-string-parity` scanned `AboutScreen.swift`, which is fixed English by
  design, and so reported its "Open-source components" heading as an iOS label
  drifting from an Android string — an invitation to map a legal heading onto a
  translation, which is the exact outcome that screen exists to prevent; it now
  mirrors `check-l10n.py`'s `UNLOCALISED_VIEWS`, and the other five advisory
  findings are untouched. One "licence" survived this cycle's spelling sweep, in
  an `AboutScreen.swift` comment. And two claims in the best-practices
  self-assessment had gone stale: `OSPS-LE-03.02` still offered
  `res/raw/copyright.md` "shown in-app" as its evidence — the criterion is still
  met, but by three bundled verbatim licences and an About screen that states the
  GPL notice and the App Store Distribution Exception in full — and the
  internationalization answer counted 22 locales where the app ships 21 (20
  translations plus the English base), the figure `release-check.sh` §4 and
  `check-ios-metadata` both use.
- **The English store notes say what this release actually became.** They were
  last written when 0.83.0 was half its present size, and four user-visible things
  had landed since without reaching them: the iOS calendar could not add an entry
  at all, today's entries could not be edited, statistics counted the days before
  the app was installed, and the Statistics screen was reordered and given its
  donut. Nothing in the notes had become untrue — they were simply short. The
  App Store note has room and takes all four. The Play note had 62 characters
  spare, which was not enough for the one thing it lacked, so a clause that
  restated its own first half ("so the catalogue afterwards matches the backup
  exactly") gave way to the Statistics and Calendar cards finally matching the rest
  of the app.
  The other twenty locales are untouched and drift further: they still carry the
  older, bulleted draft this release opened with. That was a deliberate call when
  the notes were first revised and it stands, but the gap is now four items wide.
- **The About screen's paragraphs now read as paragraphs.** Android's license
  cards laid their prose out with `Arrangement.Top`, so consecutive paragraphs
  butted together with NO gap — tighter than the leading inside a paragraph, which
  made four paragraphs look like one block that occasionally started a new line.
  A paragraph break has to be wider than a line break to be one; the cards now
  space their children by 8dp, the step StatsScreen's metric cards already use.
  iOS had the opposite fault: every paragraph is a List row, and a List rules a
  line between rows, so the GPL notice arrived chopped into four by three
  horizontal rules. The paragraphs hide their bottom separator; the fourth keeps
  its, because that rule belongs there — it separates the notice from the link to
  its full text. Android grows the same rule inside each card, above each link,
  and loses the one that sat above "Open-source components", where the heading
  and the cards already do the separating. The card gap is 12dp, matching the gap
  the enclosing Column puts between the cards, so the rhythm does not change when
  the eye crosses a card edge; it applies to every child alike, so the rule above
  each link is held off the last paragraph by the same amount, and
  "Open-source components" gets 12dp more above it than the Column gives every
  child alike — a heading needs more air above than below to belong to what
  follows.
  On iOS the four paragraphs are now ONE row rather than four. They had been four,
  which is why a List ruled a line between every sentence of the notice; hiding
  each separator fixed the look but left the structure lying, and a row's own
  vertical insets held the paragraphs about 26pt apart — wider than the blank line
  they stood in for, and not reachable from the call site. One row with an explicit
  `VStack(spacing: 10)` says what this is, a single legal text, and sets the gap
  exactly: wider than the leading inside a paragraph, narrower than a blank line.
  The rule above the link is then the List's own, drawn between that row and the
  link's, which is where it belongs. The paragraphs were `.footnote` while the
  "Version" row above them is `.body`, so the screen shrank below its own first
  line; they are `.callout` now, one step down from the label they sit under
  rather than two. GRDB's MIT text joins them and loses its `.secondary` grey:
  small and grey reads as a disclaimer to skip, and that text is the permission
  notice the licence obliges us to put in front of a reader.
- **"licence" is now "license" everywhere, and the About screen groups each
  license in a card.** The tree had been spelling it both ways — 159 occurrences
  of the British form across 40 files, sitting next to the American form the GPL,
  the Apache licence and every bundled text use themselves. The licenses win:
  `LICENSE_OUTPUTS`, `generateLicenseDocuments`, `Screen.LicenseGpl3` and the
  rest follow. Left alone on purpose: this changelog, which is a record of what
  was written when, and `tools/fonts/Inter/README.txt`, which is someone else's
  document.
  The About screen's prose was `bodySmall` while the license viewers it links to
  render at `bodyMedium`, so tapping a link appeared to change the typeface;
  both are `bodyMedium` now. The links name the document — "GNU General Public
  License v3", "Apache License 2.0", "GNU General Public License v2" — and the
  window titles are short ("GPL 3.0", "GPL 2.0", "Apache License 2.0"), because a
  top bar truncates and the link already said the long name. Each license now
  sits in its own [SectionCard], which does the grouping the horizontal rules
  were going to do. "The libraries below are compiled into this application" is
  gone from both platforms: the cards say it.
- **Fixed: the Statistics and Calendar cards did not match the rest of the app.**
  Nine cards — seven in StatsScreen, two in CalendarScreen — were written as a
  bare `Card(modifier = ...)` with no `colors` argument, so they took Material
  3's default container colour instead of the `surface` that Settings, Drinks and
  the entry list use. It looked like a design decision and was a forgotten
  argument. All nine are [SectionCard] now and inherit the right colour by
  construction; CalendarScreen's two keep their denser 12dp inset and
  StatsScreen's metric cards their 8dp row spacing, both passed explicitly rather
  than re-implemented. TodayScreen's daily summary and CalendarScreen's
  selected-day panels are untouched: `primaryContainer` there is deliberate.
- **`SectionCard`: one card, instead of five screens guessing.** The app's
  neutral grouping card — surface-coloured, 1dp lift, 16dp padding — existed
  three times written out by hand (SettingsScreen's private `SettingsCard`,
  DrinksScreen, `EntryListItem`). It is now a shared component in
  `ui/component/Components.kt`. TodayScreen's daily summary and CalendarScreen's
  selected-day panels keep `primaryContainer`: those are meant to stand out, and
  stay accents.
- **The iOS calendar can log a drink onto the day you picked.** Android has had a
  "+" there since the screen existed; iOS had no way to add an entry at all, only
  to edit one that was already there. The button was the small part. Underneath it,
  a calendar entry needs two facts that Android has always kept apart and iOS could
  not express: the TIMESTAMP is the moment of typing, the LOGICAL DATE is the day
  being recorded, and on a calendar those genuinely differ.
  `EntryLogger.makeEntry` derived the logical date from the timestamp
  unconditionally, so an entry booked onto the 12th would have landed on today —
  silently, and not noticed until the month was reopened. It now takes an optional
  `logicalDate`; nil keeps the derivation, which is what the Today and Drinks
  screens want and what every existing caller gets, so nothing else changes.
  `CalendarModel` gained `addEntry`, which hands it the selected day, and the drink
  catalogue it needs for the sheet — loaded and observed, so a drink added on the
  Drinks screen is there without leaving the calendar. This is Android's
  `CalendarViewModel.addEntry` → `addFromDrinkWithDate` line, restated in Swift:
  its `updateEntry` documents that calendar entries "are deliberately assigned to a
  specific date that may differ from the wall-clock date of the timestamp", and
  now iOS can say that too. The day-change boundary is not applied — a calendar
  square is not subject to a 4 a.m. rollover — and the timestamp comes from the
  sheet, defaulting to now, as Android's dialog offers it.
  The "+" sits at `.primaryAction` and only appears once a day is selected, as
  Android's floating action button does: without a selection there is no day to
  book onto. The sheet omits the capacity dot, because every figure feeding it —
  today's grams, this week's total, this week's drinking days — is about TODAY, and
  this entry is not; a dot answering the wrong day's question is worse than none.
  "Add Entry" is Android's own string, with its twenty translations carried over
  verbatim rather than written afresh.
- **Today's entries can be edited, the Categories card stays for an empty period,
  and the MIT chapter reads like the GPL one.** Three places where iOS had quietly
  settled for less than the screen beside it.
  A Today row was a name and a gram figure with a swipe to delete and no way to
  edit at all — while the calendar's row, showing the same entry, had the time, the
  volume, the strength, the note, a pencil and a bin. Android draws both screens
  with the same `EntryListItem` and always has. Today's row is now the calendar's
  row: today's mistyped entry is the likeliest thing anyone wants to correct, and
  it was the one entry they could not. The swipe stays beside the buttons — it is
  the gesture an iOS reader reaches for unprompted, and dropping it to match a
  screen that never had it would be parity bought with a habit.
  The Categories card vanished for a period with no drinks in it, because the
  section was guarded on the breakdown being non-empty. An empty ring says "you
  drank nothing"; a missing section says "this app has no such feature", and a
  reader cannot tell that from a bug. It is unconditional now, like the time-of-day
  and weekday sections. Android hides its card here; that divergence is deliberate.
  The About screen's MIT chapter kept its separator — that rule marks where our
  words stop and GRDB's begin — but the licence below it was one `Text`, and a
  blank line inside a `Text` is a whole line high. The notice therefore sat visibly
  looser than the prose above it: the same screen telling the same kind of thing in
  two rhythms. It is rendered from its paragraphs now, spaced by the 10pt used
  everywhere else. The text itself is untouched — `grdbLicenseParagraphs` is
  `grdbLicense` cut at its blank lines, and a test pins that rejoining the pieces
  reproduces the constant character for character. What is reproduced has to be the
  license, not a rendering of it.
- **iOS Statistics leads with its chart, and its categories are a donut.** The
  consumption chart had sat fourth, behind two blocks of numbers; it is the answer
  the screen is opened for, so it now comes first, right under the period picker,
  exactly as on Android — where a comment in this file had claimed the key-metrics
  card was "Android's first card", which it never was. That comment had dressed a
  divergence up as parity.
  The categories arrived as a list of rows while Android drew a donut. They are a
  donut now, with the two-column legend Android puts under its ring: the legend
  carries the grams and the percentage the rows used to, so nothing is lost by the
  list going. The six slice colours are NOT restated here — `CategoryPalette` asks
  PotillusKit's `ReportPalette.color(forCategory:)`, the same function the PDF
  report asks and the same one the shared `test-vectors/report-chart.json` pins for
  both platforms, so the ring, the report and Android cannot drift. That palette's
  docstring has always claimed it "matches the on-screen palette"; until now iOS
  had no on-screen palette to match. The hex-to-`Color` step lives in the app
  target because PotillusKit imports no SwiftUI anywhere — being UI-free is what
  lets it be tested without a host app.
- **Fixed: a fresh iOS install counted the days before it existed as abstinent.**
  Install on the 16th, open Statistics, and the month view congratulated the user
  for fifteen dry days and drew fifteen green ticks for the 1st to the 15th —
  days the app had not been installed for. The arithmetic was never wrong; a
  default was missing. Android's `AppPreferences` falls back to the package's
  `firstInstallTime` when no start date was ever stored, "so statistics start at
  the install date until the user picks another"; the Swift port copied the
  `statsFromDate` setting and the whole apparatus that honours it —
  `StatsWindows.applyingFloor`, the streak filter, the baseline clipping — but
  not that fallback, so the floor stayed empty and every period ran from its own
  start. A brand-new installation now seeds the floor with the install date.
  IT IS WRITTEN DOWN, not recomputed: iOS has no `firstInstallTime` to derive it
  from forever, so "today" is only correct on the day it is first asked. And it
  is triggered by the ABSENCE OF THE PREFERENCES FILE, not by the floor being
  empty — empty is a meaningful user choice, `SettingsModel.clearStatsFromDate()`
  writes it to mean "cover my whole history", and seeding on empty would undo
  that at every launch. Android tells the two apart because its DataStore
  distinguishes a missing key from a key holding ""; iOS now uses the same signal
  `AppDatabase.openOrCreate` uses for the preset drinks. As there, an
  installation that already has a `prefs.bin` is deliberately left alone and
  keeps no floor until a date is picked in Settings. Only `makeDefault()` seeds;
  tests, previews and screenshot runs build the store directly and keep their
  pristine defaults. Android is unchanged: its three-state logic already does all
  of this, and giving it the same mechanism would have put the distinction that
  makes clearing work at risk for no visible gain. `AppSettings.statsFromDate`'s
  documentation claimed empty meant "from the first entry" — it never did, which
  is precisely the behaviour the bug imitated; it means no lower bound at all.
- **The About screen states the licence instead of pointing at it, and each app
  now bundles only the licences it actually owes.** The screen is rebuilt on both
  platforms into the same two chapters with the same wording: "Licence", holding
  the GPL notice every source file carries — as prose, not monospaced — and
  "Open-source components", listing at COPYING.md's level of detail only what the
  package REDISTRIBUTES. Each verbatim text is one tap away in its own window.
  Android links to the GPL-3.0, the Apache-2.0 (required by §4(a) for the
  AndroidX/Kotlin/Okio/Guava/JSpecify runtime compiled into the APK) and the new
  GPL-2.0 (for `desugar_jdk_libs`, whose OpenJDK Classpath Exception is stated on
  the screen because it is NOT part of the GPL-2.0 text); iOS links to the
  GPL-3.0 and keeps GRDB's MIT text inline, nine sentences being too short to
  deserve a window. `LICENSE.GPL-2.0.md` is new — the repository shipped no
  GPL-2.0 text at all, so desugar's licence had nowhere to point — and joins
  `check-headers`' `EXCLUDED_PATHS`, since a verbatim licence must not carry our
  own header.
  THE FOURTH PARAGRAPH IS NOT THE FILE HEADER. The headers end with a POINTER —
  "any such permissions … are stated in the accompanying COPYING.md file" — which
  worked only while the app bundled COPYING.md inside the combined copyright
  document. It no longer does, so the sentence would send a reader to a file that
  is not on their phone; the App Store Distribution Exception now stands there in
  full, stated where it is read, which is what section 7 asks for.
  ONE DOCUMENT PER LICENCE, NOT ONE COMBINED. `raw/copyright.md` and its iOS twin
  are gone. Both were built from COPYING.md, so the APK carried GRDB's MIT notice
  for a library it does not ship and the iOS app carried the Apache text for
  libraries it does not have; `render-copyright.py` keeps its concatenation
  ability but the build now passes it one input per output, which makes it a
  verbatim copy with LF endings pinned — still the single generator the Makefile,
  its `check-guides` verification and the Gradle tasks share. The in-app
  copyright document is not shown at all any more; COPYING.md stays the
  exhaustive inventory and travels with the source, which is where the store
  listing's assets belong: the feature graphic RASTERISES its fonts into a PNG,
  so no font file is ever redistributed.
  THE WHOLE SCREEN IS ENGLISH. It was half-and-half before — iOS localised
  "Licence" and "Open-source components" while Android hard-coded the same words
  and documented why, so the two platforms answered one question two ways. A
  translated licence is not the licence, and a screen that switches language
  halfway down is worse than one that does not switch at all. The overflow-menu
  entry stays localised ("Über"), because that label is navigation and a user has
  to recognise it; the screen's own title is "About", the first line of an
  English document. `AboutScreen.swift` joins `Localization.swift` in
  `check-l10n`'s new `UNLOCALISED_VIEWS`, and `check-l10n-parity` skips it too.
  Five orphaned catalogue keys and Android's now-unused `copyright` string (21
  locales) are gone. Android's `DocumentViewerScreen` takes `title: String`
  instead of `@StringRes titleRes: Int` — the signature iOS already had — because
  the guide passes a localized lookup while the licence viewers pass fixed
  English literals naming legal documents.
- **Fixed: the Android About screen declared its package twice, and `SectionCard`
  defaulted its modifier wrongly.** Two slips while those files were written in
  this same release, each caught by the first real Android build: the duplicate
  `package` by the Kotlin compiler, and `modifier: Modifier =
  Modifier.fillMaxWidth()` by Compose's ModifierParameter lint rule, which
  requires the default to be plain `Modifier` — the width now chains onto the
  caller's modifier at the point of use, as `DrinkCategoryIcon` already did, and
  as the file's five other modifier parameters were already declared. Neither was
  caught by the release gates, because none of them parses Kotlin or runs lint.
  SwiftLint caught three more of the same kind on the other platform: two
  three-character-minimum identifiers, a file left without its trailing newline by
  the edit that split it into an extension, and a closure whose parameters had been
  wrapped onto the next line to fit — the wrap being unnecessary once the loop
  stopped enumerating for an index nothing used. `check-swift-length`
  mirrors SwiftLint's structural rules and nothing else, by design — it says so
  itself — so `identifier_name` and `trailing_newline` were never its to catch.
  And one member of `CalendarState` was documented, commented and used, but never
  declared: the edit meant to add it silently matched nothing, and every gate
  passed on a file that could not compile. The Swift compiler was the first thing
  in the chain able to notice, and it found three more of the same shape in
  CalendarModelTests, all from one careless edit: a multi-line function signature
  cut after two lines, a `@discardableResult` separated from the function it
  qualified, and the orphan then carried forward into the repair. The file was
  rebuilt from its last good state instead, and diffed against it: every one of the
  22 existing tests word for word unchanged, the fixtures untouched but for the one
  argument that had to be added.
- **The overflow menu ends with About, and Help and About share their glyphs
  across platforms.** The menu now reads Settings, Help, "Lock app", About on
  both platforms: About is looked up once, not daily, so it yields the prime
  positions to the three entries that do real work, and it stays last whether or
  not the conditional "Lock app" entry is present. The two glyphs that had
  drifted are aligned on the metaphors iOS already used — a question mark in a
  circle for Help, an "i" in a circle for About. Android had been drawing a
  MEDICAL CROSS (`Icons.Filled.LocalHospital`) for Help: in an app about
  drinking, a red-cross shape reads as "medical help", not "user guide". The
  glyph had inherited that slot when the open book moved from Help to About in
  the Copyright→About rename; both are now gone, and with them two imports. The
  FILL stays platform-specific on purpose — Android's other menu entries are
  filled glyphs, so an outlined circle between them would read as a different
  weight class, while on iOS the outlined SF Symbols are what sits naturally
  beside `gearshape` and `lock`. Note `Icons.AutoMirrored.Filled.Help`, not
  `Icons.Filled.Help`: the latter carries a `@Deprecated` with
  `ReplaceWith("Icons.AutoMirrored.Filled.Help")` in the pinned
  material-icons-extended 1.7.8, since a question mark mirrors in right-to-left
  layouts, and would therefore fail the build. `Icons.Filled.Info` has no
  auto-mirrored variant and comes from material-icons-core. The menu's callback
  is renamed `onOpenCopyright` → `onOpenAbout`, which it has actually invoked
  since the About screen landed; the stale name and its KDoc ("opens the
  Copyright viewer", "three entries: Settings, Help and Copyright" — there are
  four) are corrected, and the rename runs through `AppNav` and the four main
  screens. The `AboutScreen` → copyright-document wiring keeps the old name,
  because that one does open the document.
- **A fresh install now fills the iOS drink catalogue.** The Swift port carried
  Room's schema across but not Room's `onCreate` callback, so on iOS — and only
  on iOS — the drinks list came up EMPTY after a first install or a storage
  reset: nothing to log until the user defined a drink by hand or imported a
  backup. `AppDatabase.openOrCreate` is the missing counterpart to Android's
  `PrepopulateCallback`. It probes for the database file BEFORE opening it and,
  when the file is absent, inserts the same fifteen presets Android's
  `PRESET_DRINKS` carries — verified name by name, with the same volumes,
  strengths and categories, stored as the `DrinkCategory` raw strings the rest of
  the port uses. The seed deliberately does NOT live in the GRDB migrator, which
  `AppDatabase(inMemory:)` shares with every test and the screenshot run; seeding
  there would push fifteen rows into every fixture and make "a fresh database is
  empty" false across the suite. Android draws the same line, attaching its
  callback in the production builder rather than in the schema, so its own test
  databases come up empty too. An emptied catalogue on an EXISTING database is
  left alone: that is a state the user chose — a REPLACE import, or deleting the
  lot — and a re-seed would undo it at the next launch, which is why the probe
  asks whether the FILE exists rather than whether the catalogue is empty.
  Existing installations therefore keep their empty catalogue; the seed is a
  first-creation event, exactly as on Android. Five new `AppDatabaseSeedTests`
  pin the contract against a REAL FILE, because the path that was broken is file
  creation itself — the whole existing suite builds its own fixtures on
  `AppDatabase(inMemory:)` and so expected an empty fresh database by
  construction, which is why nothing was red. They assert the fifteen rows and
  their values, that a reopen adds nothing, that a deliberately emptied catalogue
  stays empty, and that an in-memory database still comes up empty. The preset
  catalogue is still not pinned in `test-vectors/`, which is what let the port
  lose the seed unnoticed; the gap is recorded in the new tests' header.
- **A REPLACE import now truly replaces the drink catalogue on both platforms.**
  After a fresh install or a storage reset the app seeds the full built-in preset
  set (on iOS, only since the fix above); choosing "Replace" when importing a
  backup then left those presets in
  place, so they lingered ALONGSIDE the backup's drinks instead of being replaced
  — a preset the backup did not contain stayed visible. REPLACE now wipes the
  WHOLE drink catalogue (presets included) before re-inserting the backup, so the
  catalogue afterwards is exactly the backup's drink list: a drink is present if
  and only if the backup defines it, and presets the backup carries are recreated
  verbatim (they are exported with their `isPreset` flag). The log is cleared
  first, so no entry references a drink when the wipe runs and the entries→drinks
  foreign key cannot trip. On Android the wipe moved from
  `DrinkDao.deleteUserCreatedDrinks` (`isPreset = 0`) to a new
  `DrinkDao.deleteAllDrinks`; on iOS the REPLACE branch in `BackupImporter` drops
  the `isPreset == false` filter. The narrower "keep the presets" helper is
  retained on both platforms for callers that want to clear only the user's own
  drinks. Pinned by an updated iOS importer test and a new Android instrumented
  test that both assert the catalogue equals the backup exactly; the stale
  "presets survive a REPLACE" notes in the DAO / repository / screenshot-test
  comments were corrected to match.
- **The iOS app lock now engages on a cold start (eleventh QA round).** The
  launch prompt was fired from a bare `.task { lock.onLaunch() }`, which ran
  while `isEnabled` still held its `false` default — the stored setting arrives
  asynchronously from the encrypted preferences, and arming it later
  deliberately does not lock. Net effect: after every process death the diary
  opened WITHOUT a prompt, and the lock only re-engaged after the next
  30-second background trip. The model-level test armed the flag by hand
  before calling `onLaunch` and so never saw the shell's ordering race.
  `StartupState.make(arming:)` now loads the settings BEFORE returning
  `.ready` and completes the new `AppLockModel.armAndLaunch(enabled:reason:)`
  — which takes the freshly loaded setting as a parameter, so the race cannot
  be written — strictly before any content view exists; while the prompt is up
  the cover overlays a plain progress spinner. Two kit tests pin the contract.
- **The iOS screens now follow the clock (eleventh QA round).** Nothing on iOS
  re-derived "now": the models reloaded on database and settings events only,
  so the advertised live BAC estimate froze at its last-loaded value, and
  Today, Statistics and Calendar kept yesterday's logical day across the
  day-change time for as long as the screen stayed open. Android has run a
  60-second ticker for both jobs since its own review rounds
  (`TodayViewModel.TICK_INTERVAL_MS`); the three iOS models now do too —
  unconditional on Today (the BAC needs every minute), day-keyed on Statistics
  and Calendar (a reload only when the logical day moved, so the queries do
  not rerun for nothing) — and the three screens additionally reload on the
  scene turning active, because `onAppear` does not fire on foregrounding and
  the ticker only bounds staleness to a minute. The tick interval is
  injectable; a new test rolls the day over by advancing the clock alone.
- **iOS backup and import failures speak the app's language (eleventh QA
  round).** The failure alerts showed `String(describing: error)` — raw
  English, or a raw Swift error dump — in all twenty non-English languages,
  while Android has long mapped every import failure onto localized
  resources. A `describeBackupFailure` mapping now mirrors Android's
  `import_error_*` strings: the four actionable failures (empty file, broken
  JSON, newer format, oversized file) get their own sentence, everything
  structural folds into "Read error: %@" with the typed detail — Android's own
  shape. Six catalogue keys were added with all twenty translations copied
  from Android's resources (specifiers converted `%1$d`→`lld`, `%1$s`→`%@`);
  the three keys whose English matches Android verbatim are enforced
  word-for-word by `check-l10n-parity` from now on.
- **The iOS in-app guide and licence render as paragraphs (eleventh QA
  round).** The document viewer turned every hard-wrapped SOURCE LINE into its
  own block, so the guide showed ragged shreds of sentences with a gap after
  each, and a wrapped list item broke apart mid-entry. The small Markdown pass
  now joins consecutive non-blank lines into one paragraph (blank line =
  separator, Markdown's own rule), a list item starts its own block and keeps
  its wrapped continuation lines, and headings/rules flush as before. Pinned
  by a new smoke-test file; the Help and Copyright screens visibly change
  (for the better) in every language.
- **The Face ID permission dialog is localized (eleventh QA round).**
  `NSFaceIDUsageDescription` existed only as the English value in
  `project.yml`, so the system dialog shown when the lock is first armed was
  English in all twenty-one languages. A new `InfoPlist.xcstrings` carries the
  sentence in every app language (best-effort translations awaiting native
  review, like the rest); the `project.yml` value remains as the English
  fallback and its comment says so.
- **The app-lock threshold is now vector-pinned on BOTH platforms (eleventh QA
  round).** `test-vectors/app-lock.json` was one-sided — only the Swift suite
  loaded it — and behind that blind spot Android's strict `>` diverged from
  the `>=` boundary the vectors pin ("exactly at the threshold: prompt").
  The arithmetic is extracted from `MainActivity` into `domain/AppLock.kt`
  (testable on the JVM, `>=` like iOS; a background gap of exactly 30 seconds
  now prompts on Android too — a one-millisecond behavioural change), a new
  `AppLockVectorTest.kt` loads the shared file, and the vector's `_comment` no
  longer claims "identical arithmetic" conditionally nor names the retired
  `systemUptime` clock.
- **The App Store metadata gains the gate the Play metadata has (eleventh QA
  round).** `release-check.sh` §10 enforces Google Play's limits; the files
  under `fastlane/metadata/ios/` had no counterpart, so the upload-time length
  failures the Android side fixed in 0.82.0 were one careless edit away from
  repeating. A new `tools/check-ios-metadata.py` enforces App Store Connect's
  store-listing limits (name/subtitle 30, keywords 100, promotional text 170,
  description and release notes 4000), locale file-set parity, and non-empty
  name/description; it skips gracefully when the directory is absent and is
  wired into `make check-ios-static`.
- **English-only comments now hold in the build files too (eleventh QA
  round).** CONTRIBUTING's "English everywhere" covers build files, but the
  German-comment gate scanned only `*.kt` — and the German prose it exists for
  sat in `build.gradle.kts` and `settings.gradle.kts`. Those comments are
  translated, and release-check §7 now also scans the three Gradle build
  scripts (named explicitly, so it cannot descend into `.gradle/` caches) and
  the Swift sources when `ios/` is present, each grep guarded against the
  found-nothing exit code so the gate cannot die under `set -e`.
- **Hardening and repository hygiene (eleventh QA round).** The report's
  `WKWebView` now disables content JavaScript explicitly — the template ships
  no scripts and every value is HTML-escaped, but WebKit's default is ON,
  unlike the Android WebView default the report keeps there; one line makes
  the platforms' stance identical. `KeychainKeyProvider` tolerates the
  first-launch creation race (`errSecDuplicateItem` now reads the winning key
  back instead of failing the launch). And `.gitignore` finally contains the
  two entries the documentation already promised: `ios/Version.xcconfig`
  (whose generator documents itself as "therefore git-ignored") and
  `ios/Potillus.xcodeproj` ("not committed", per INSTALL-IOS.md).
- **Documentation corrections (eleventh QA round).** `test-vectors/README.md`
  now inventories all twelve vector files (app-lock, report-chart,
  report-data, report-format and template-render were missing from its
  "Files" list). `COPYING.md` no longer claims BOTH apps reproduce the GRDB
  licence text in their about screen — only iOS ships GRDB and does so
  (test-pinned); Android carries no MIT obligation. `docs/INSTALL-IOS.md` no
  longer derives the version from a "shared `VERSION` file" that never
  existed (the sources are `CHANGELOG.md` and the Android `versionCode`, as
  its own next paragraph says). And `ios/.swiftlint.yml` no longer cites two
  scripts that are not in the tree (`build-report-labels.py`,
  `check-report-labels.py`) nor contradicts the report-label catalogue's own
  "hand-maintained" header; the real guard is `check-l10n-parity.py` CHECK 3.
- **The best-practices badge answers are browsable and complete.** A new
  `make bestpractices-jsonc` writes `.bestpractices.jsonc`, a generated view of
  `.bestpractices.json` in which every criterion is preceded by a comment
  naming the bestpractices.dev level it lives at — `passing`/`silver`/`gold`
  for the OpenSSF Best Practices Badge (metal) series, `level 1`/`2`/`3` for
  the OSPS Baseline — so a reader knows which page to open to find the
  official text. The levels come from a committed, provenance-documented map
  (`tools/bestpractices-levels.json`) regenerated from the two upstream
  machine-readable sources, and `.json` stays canonical (comment-free,
  tool-readable) while the `.jsonc` is the annotated sibling. The download
  target (`make bestpractices-json`) now mirrors the FULL upstream criteria
  set through `tools/filter-bestpractices.py` (upstream wins; retired criteria
  are dropped, so the file follows the current definitions), and two gates
  keep it honest: `check-bestpractices-levels.py` fails if a criterion has no
  mapped level, and release-check §15 fails while any criterion is unanswered
  — status not in Met/Unmet/N/A, or an empty justification — exempting the few
  criteria the badge form gives no rationale field.
- **The iOS screens are brought into visual and verbal parity with Android.**
  A pass over every screen so someone who switches platforms finds the same
  layout, labels and colours. Today gains the headline pair (today's total and
  the monthly average with its trend arrow) above thicker limit bars, and its
  entries header and empty state match Android's wording. The calendar day view
  gains the daily-limit bar, richer entry rows (time · ml · % · g · note), an
  edit pencil and a red delete, and a tap on the selected day no longer
  deselects it. The drinks rows show the grams-per-serving Android shows. The
  statistics screen is rebuilt into Android's two-card structure — key metrics
  (totals, averages, the three days-over-limit counts in red/green, abstinent
  days) then abstinence and trend — with the dry-day check-marks drawn on the
  consumption chart. Settings adopts Android's section order (Personal · Limits
  · Statistics · Backup · Security · Appearance), folds the day-change time into
  Statistics, and — a fix — makes the statistics-start date always editable
  again (it previously became read-only once "all history" was chosen). Across
  all these screens the iOS labels now use Android's exact wording so the two
  platforms share translations, verified by a new advisory tool,
  `make check-ui-string-parity`, that reports iOS labels drifting from their
  Android counterpart (the key-based l10n gate cannot see differently-worded
  equivalents). Two genuine bugs found on the way are fixed: the traffic-light
  "green" dot rendered in the app's blue accent instead of green, and the
  German (and other) empty-state translations were silently dropped because the
  catalogue key had been stored with an escaped rather than a real newline.
  Platform-idiomatic differences are deliberately kept — the overflow menu and
  the add button stay in their iOS positions, and the app-lock hint keeps its
  Face ID / Touch ID wording rather than Android's fingerprint phrasing.
- **A "(System)" language option is offered on both platforms.** The data model
  already treated an empty language tag as "follow the device language" — and
  that is the default — but neither picker let a user choose it, so once a fixed
  language had been selected there was no way back to following the system. Both
  platforms now list "(System)" as the first language entry, mapping to the
  empty tag. On Android the `LanguageDropdown` prepends the entry and a new
  `language_system` string is added to every locale; selecting it calls
  `setApplicationLocales` with an empty locale list, which restores system
  following. On iOS the `Picker` prepends a `"(System)"` entry tagged with the
  empty string, which `Loc.locale(for:)` already resolves to `.current`, so the
  interface follows the device language live. Choosing a fixed language still
  works exactly as before on both.
- **"About" replaces "Copyright" in the overflow menu on both platforms.** The
  menu entry now opens an About screen — app name, version, the app's own GPL
  notice, and its direct dependencies grouped by licence — with a link on to the
  full copyright-and-licence document. On iOS the About screen moves out of
  Settings (where it used to live) into the overflow menu, matching Android's
  placement; on Android an equivalent About screen is added and the overflow's
  former "Copyright" entry becomes "About". The licence sentences on the screen
  are English-only, like the COPYING.md they derive from — licence text is a
  legal artifact that translation would distort — while the structural labels a
  user navigates by are localised. COPYING.md now reproduces the full GRDB MIT
  licence text, so the bundled copyright document (built from COPYING.md on both
  platforms) carries the notice regardless of which app is installed; only iOS
  actually ships GRDB and additionally reproduces the licence inline in its
  About screen, still pinned by the `testGrdbLicence*` tests.
- **The iOS build now produces a CycloneDX SBOM too, and the Android one is
  renamed for symmetry.** Android's SBOM comes from the first-party CycloneDX
  Gradle plugin; Swift Package Manager has no first-party equivalent, and the
  third-party tools would each add a build-time toolchain the project avoids for
  reproducibility. Since GRDB is the app's one direct dependency, pinned exactly
  in `Package.resolved`, a small generator (`tools/gen-ios-sbom.py`) emits the
  same CycloneDX 1.6 JSON format, with the application as the metadata component
  and GRDB as a library component carrying a `pkg:swift` purl, its commit and its
  MIT licence. It runs through the same `tools/sbom-normalize.py` as the Android
  SBOM (timestamp pinned from `SOURCE_DATE_EPOCH` or dropped), so the file is
  byte-reproducible. A `make ios-sbom` target builds it and `make release-ios`
  stages it beside the `.ipa` as `<id>_<code>_ios_sbom.json`; the Android staged
  SBOM is renamed from `_sbom.json` to `_android_sbom.json` so the two platforms'
  inventories sit side by side, and `push-codeberg` attaches the iOS SBOM as a
  release asset when it has been staged. COPYING.md, SECURITY.md (osv-scanner)
  and the best-practices SBOM justification are updated to describe both.
- **Store screenshots and report PDFs are never auto-captured, and builds fail
  fast when they are missing.** The device screenshots (01..06) and the per-locale
  report PDFs need a physical device or simulator to produce, so the build must
  never reach for one on its own. The previous behaviour — a missing screenshot
  would silently trigger a full `make screenshots-android` capture mid-build — is
  removed: those artifacts now have hard-fail sentinels that assert presence and,
  when a file is absent, stop with an actionable message naming the capture
  command (`make screenshots-android` / `make screenshots-ios` / `make
  report-pdfs`). The derived artifacts stay dependency-driven: the feature
  graphics and the rasterised report pages (07/08) are still regenerated on
  demand from their inputs, but fail cleanly when the underlying device artifact
  is missing rather than capturing it. Finally, `make android`, `make ios`,
  `make release-android` and `make release-ios` each gate up front on the full
  per-locale set of required device artifacts, so a build that would ship
  incomplete store assets stops immediately instead of part-way through.
- **Store release notes are written for this version in every language.** The
  placeholder "what's new" text is replaced with real notes in all 21 store
  locales on each platform — the Play changelog (`changelogs/94.txt`, kept within
  the 500-character store limit) and the App Store `release_notes.txt`. Each
  platform's notes describe only that platform's own changes.
- **The two unmet SHOULD badge criteria now carry real rationales.** The badge
  permits a SHOULD criterion to stay unmet as long as the reasoning is
  documented, and a review of every unmet answer found exactly two in that
  category: `crypto_algorithm_agility` and `bus_factor`. Both justifications
  read as deferred promises rather than reasoning, and the crypto one promised a
  remediation — a versioned blob format — that would not have satisfied the
  criterion anyway, since the criterion asks for multiple algorithms rather than
  a migration marker. Both are rewritten to say why the criterion is not met and
  what mitigates it: for the cipher, that the sole sealed artifact is the
  preferences blob, that Android's key is generated inside the Keystore and a
  second algorithm would risk moving it out, that users of a diary do not select
  ciphers, and that the cross-platform blob framing makes the change risky for no
  gain; for the bus factor, that a single-maintainer project is forkable Free
  Software, that F-Droid re-signs from source, and that governance and the
  contribution process are documented. Both statuses remain `Unmet`. The roadmap
  entry is corrected to match.

---

## v0.82.0

Add the native Swift/SwiftUI iOS port

This release makes Libellus Potionis multi-platform. A native Swift/SwiftUI port
of the app now lives in the same repository under `ios/`, feature-complete for
daily use and pinned to the Android app's behaviour by a shared set of golden
test vectors. The two apps share one human-readable version and the JSON backup
interchange format — not a live sync and not a common binary. The Android
Play-publishing tooling that 0.82.0 began with is hardened as well, below.

The iOS port, section by section:

- **Shared core, ported not shared.** The health-relevant domain logic —
  `AlcoholCalculator`, `DayResolver`, `ChartBucketing` and `Trend` — is
  re-implemented in Swift rather than shipped as a Kotlin Multiplatform binary. A
  language-neutral golden-vector suite in `test-vectors/`, loaded by both the JVM
  and the Swift test targets, keeps the two implementations from drifting: neither
  platform can change a formula without either updating a reviewable shared vector
  or turning its own suite red. The tricky cases are covered — `isOverLimit`'s
  floating-point tolerance, and the timezone- and DST-safe calendar arithmetic
  behind the logical day, the rolling seven-day window and the chart buckets.
- **Data layer on GRDB.** The SQLite schema, the record types, the repositories
  behind protocol seams, the JSON backup (v3) reader/writer, the CSV export and an
  encrypted preferences store are all in place; GRDB is the iOS counterpart to
  Android's Room. The database files are not interchangeable between platforms —
  the supported bridge is the JSON backup, and the iOS suite proves it by parsing
  and importing a real Android-written backup (15 drinks, 85 entries) with no
  orphaned rows.
- **Every screen in SwiftUI.** Today, Calendar, Statistics, Drinks, Add-drink,
  Settings and the document viewer are built to feature parity, reactive to
  database changes, with a startup-failure path, an app lock via
  `LocalAuthentication` (and an app-switcher privacy cover), and the two-page PDF
  report rendered by WebKit from the same HTML template Android uses, in the UI
  language.
- **Twenty languages.** Every screen, the PDF-report labels, the CSV export
  headers and the plurals are localised across the twenty UI languages as String
  Catalogs with English as the source. A parity check
  (`tools/check-l10n-parity.py`) verifies the iOS translations against Android's
  resources, and a System-language user gets the report in the device language
  rather than English.
- **Release plumbing and screenshots.** The iOS build derives `MARKETING_VERSION`
  from this changelog's top entry and its build number from Android's
  `versionCode`, so the two stores' counters stay in step. fastlane iOS lanes and
  App Store metadata for 21 locales are in place, and `make screenshots-ios`
  captures the store screenshots fully non-interactively — pinning the simulator
  clock, driving the UI-test target through the screens in light and dark mode,
  and rasterizing the rendered report pages — mirroring the Android flow.
- **iOS build-and-release tooling.** A `make release-ios` target now archives the
  app WITHOUT code signing and signs only at the App-Store export (automatic
  cloud signing via `-allowProvisioningUpdates`, which mints the distribution
  certificate and App-Store profile without a registered device; the export
  authenticates with the App Store Connect API key from the
  `APP_STORE_CONNECT_API_KEY_*` environment, or a signed-in Xcode account, so it
  runs head-less), then stages the
  `.ipa` into
  `releases/` under the same `<applicationId>_<versionCode>` name as the Android
  AAB — the iOS counterpart of `make release-android`, with the same fail-fast
  guard against overwriting a staged release (it needs a Mac, the one release
  target that is not host-free). The signing Team ID is resolved like the Android
  keystore — the `DEVELOPMENT_TEAM` environment variable wins, else a git-ignored
  `ios/signing.properties` (committed template `ios/signing.properties.example`) —
  and injected as an xcodebuild build setting plus the `teamID` of a generated
  ExportOptions.plist. A new fastlane `ios alpha` lane uploads the staged `.ipa` to
  TestFlight for internal testing (`upload_to_testflight`, no listing metadata);
  the existing `ios testing`/`production` lanes now take the staged `.ipa` as
  `ipa:`, mirroring the Android `aab:` option. `docs/RELEASE-IOS.md` documents the
  flow. Editorial fix noticed on the way: the Fastfile comments pointed at a
  `make -C ios archive` target that never existed — corrected to `make release-ios`.
- **GPLv3 on the App Store.** Apple's store terms are reconciled with the GPL by
  an additional permission under GPL section 7 — an App-Store distribution
  exception whose wording is adapted from the Feeel project — carried in every
  file header and stated in `COPYING.md`; GPLv3-or-later and full copyleft remain
  intact. The port's only third-party dependency is GRDB.swift (MIT, no transitive
  dependencies, no network), which satisfies the project's dependency policy.
- **Container-runnable guards.** The repository's static checks — GPL headers,
  Swift symbols and test presence, l10n and l10n-parity, Makefile hygiene — run
  without a Mac; compiling Swift remains the one step that needs one.

The Android Play-publishing tooling is hardened as well:

- `push-playstore` runs a real PRE-FLIGHT auth check before uploading. It calls
  fastlane's `validate_play_store_json_key` and requires its success line, so a
  service account that is not (yet) invited to the Play Console — the actual
  cause of the "caller does not have permission" failure that first surfaced only
  after all 21 locales of metadata had been sent — now fails immediately with an
  actionable message. That fastlane action logs a success line but does NOT raise
  on failure, so the guard checks for the success line explicitly rather than
  trusting the exit code.
- The store-metadata length check (`tools/release-check.sh` section 10) had three
  bugs that let an over-long note reach Google. It counted the text WITHOUT the
  trailing newline, but Google counts with it — a 500-visible-character el-GR note
  plus "\n" was rejected as 501 > 500. It never checked `title.txt` (limit 30) at
  all. And, most seriously, its unguarded `output=$(...)` assignment aborted the
  whole gate under `set -e` the moment it actually found a violation, so a genuine
  catch killed the run instead of reporting it. All three are fixed: counting now
  includes the trailing newline (matching supply's verbatim `File.read` and
  Google's server-side count), the title limit is enforced, and the checker runs
  under an `if` guard like its siblings. The enforced limits — title 30, short
  description 80, full description 4000, release notes 500 — are Google Play's
  documented store-listing limits.
- The fixed check caught a latent fr-FR short-description overflow (81 > 80 with
  the trailing newline) that had not yet been uploaded; it is trimmed by its one
  trailing newline, with no change to the visible text (the same one-character
  trim already applied to the el-GR note in 0.81.0).
- The two publishing recipes were de-noised. The long rationale comments that
  `.ONESHELL` echoed on every run are moved into non-recipe header comments above
  each target (which make never echoes), leaving only short per-step markers in
  the recipe. The executed commands and status lines are unchanged; only what the
  terminal prints changed.

The iOS branch's first quality-assurance round hardens it against untrusted input
and corrects documentation that the port had outgrown:

- **Backup import is validated like Android's.** The iOS reader accepted a
  backup's drink and entry numbers on trust — only their presence was checked, not
  their range — while Android's `BackupManager` has long rejected physically
  impossible values. The GRDB schema constrains only nullability, so an
  out-of-range value (a negative volume, a non-finite alcohol percentage, a
  February 30th that a lenient formatter would silently clamp) would have entered
  the database and corrupted every BAC and statistics figure that touched it. The
  reader now enforces the same bounds as Android's Guard 2/3/4 — `volumeMl` in
  1…10 000, `alcoholPercent` a finite 0…100, `gramsAlcohol` a finite non-negative,
  `timestampMillis` positive, and a `logicalDate` that survives a parse→format
  round-trip — throwing a typed `valueOutOfRange` the UI can localise.
- **Backup files are size-capped.** The import read the whole chosen file into
  memory with no ceiling; Android caps it at 10 MiB with a fast advertised-size
  check plus a bounded read for the case where the size is misreported. iOS now
  does the same through `BackupReader.readData`, refusing an oversized file before
  it can exhaust memory, and `parse` keeps a backstop for any caller that hands
  over bytes directly.
- **Stale reader documentation corrected.** The backup reader still described a
  time when iOS "has no preferences store yet" and therefore never applied a
  restored settings block. That store now exists and the importer does apply
  settings (sanitised); the scope notes and a test comment are updated to match
  the shipped behaviour.
- **CSV export headers follow the UI language.** The export shipped its eight
  column captions in English regardless of the chosen language, while Android
  localises them from string resources — so a German user got an English-headed
  file. The captions now live in `CsvHeaderLabels`, copied verbatim from Android's
  `csv_col_*` strings for all twenty languages, and the exporter resolves them
  from the in-app language exactly as the PDF report already did. English remains
  the source and the "System" fallback. (The reader doc that claimed iOS had "no
  string catalogue" was itself stale and is corrected.)
- **The merge-import plural no longer warns.** The "N imported, M skipped."
  string carried a single plural variation over a message with two numbers, which
  made Xcode emit "cannot reliably infer argument number" in every one of the
  twenty-one localisations and risked pluralising on the wrong count. It is
  restructured to an explicit substitution that pluralises on the imported count —
  matching Android's `import_success_merge`, which keys its plural on the same
  argument — with the skipped count rendered as a plain number.
- **The Linux release path now verifies iOS too.** `release-check.sh` is the
  Android gate and knows nothing about Swift, and `make ios` cannot run on Linux
  because it ends in `swift test` and `xcodebuild` — so a green release check left
  the iOS static invariants unchecked on a Linux CI. A new `make check-ios-static`
  groups the Mac-free iOS gates (Swift symbols and tests, headers, l10n, l10n
  parity, report paper) so CI can run it alongside `release-check.sh`; `make ios`
  now reuses it for its own static phase.
- **CSV header parity is now enforced, not just intended.** A new
  `check-l10n-parity.py` check compares the localized `CsvHeaderLabels` captions,
  in column order, against Android's `csv_col_*` strings for English and every
  language, so the two platforms' export headers cannot drift.
- **Calendar month-navigation is labelled for VoiceOver.** The previous/next
  chevrons were icon-only buttons with no accessibility label, so VoiceOver
  announced the raw SF Symbol. They now carry localized "Previous month" / "Next
  month" labels, copied from Android's `cd_prev_month` / `cd_next_month`, matching
  the labelled controls beside them.
- **Twenty hardcoded English strings across the screens are now localized, and
  the linter that should have caught them is fixed.** `check-l10n` scanned line by
  line, so it was blind to any localizable literal whose call spanned two lines,
  and it did not look at alert or dialog titles or at the accessibility strings a
  screen reader speaks. Under that blind spot sat raw English in every screen:
  eight `.alert` / `.confirmationDialog` titles ("Export failed", "Backup failed",
  "Something went wrong", …), the drink-row VoiceOver hint, the calendar day-cell
  VoiceOver label, three export error messages, and a set of `Toggle` / `DatePicker`
  labels written across two lines ("App lock", "Show in app switcher", "From",
  "To", …). All are now routed through `Loc.string`: the labels reuse catalogue
  keys that already carried all twenty translations, while the titles, hints and
  error messages are added as English source strings for the translation pipeline
  to pick up. `check-l10n` now scans the whole file (so a title on the line after
  `.alert(` is caught) and covers alert/dialog titles and `accessibilityLabel` /
  `Hint` / `Value`, so this class of miss cannot recur.
- **The backup tests are split so the strict SwiftLint build passes.** The
  import-guard tests added earlier this round pushed `BackupTests` past
  SwiftLint's `type_body_length` limit, which `--strict` (the project's `make
  ios` gate) turns into a build error. The value-range and size-cap tests now
  live in a dedicated `BackupValidationTests`, leaving `BackupTests` with the
  format-compatibility suite; both classes are well within the limit and every
  test is preserved.
- **The twelve new iOS strings are now translated into every language.** The
  alert titles, accessibility strings and export error messages added earlier
  this round shipped as English source keys; they are now filled in for all
  twenty non-English locales. As with the rest of the app's non-English/German
  text (see CONTRIBUTING §6), these are best-effort machine-quality translations
  awaiting native-speaker review, not hand-authored prose.
- **The drinks list matches Android's row.** Two differences from Android are
  corrected. The padlock that iOS drew beside preset drinks is gone — Android
  shows no such marker, and the icon read as "locked/disabled" rather than
  "built-in". And a delete affordance is now visible in the row: a red trash
  button beside the edit pencil, so a drink can be removed without discovering
  the swipe gesture. Both the button and the swipe now open the same
  confirmation dialog ("Really delete …?", with a red Delete and a Cancel),
  mirroring Android's, so a removal is always a deliberate two-step action.
- **Every screen now carries the shared overflow menu.** Android puts one menu
  in the top bar of all four main screens; iOS previously had only a lone gear on
  Today, leaving Settings unreachable from Calendar, Statistics and Drinks. A
  single `AppOverflowMenu` modifier now adds a native navigation-bar menu to each
  screen with the same entries Android offers: Settings, Copyright, and — while
  the app lock is enabled — Lock app, which locks on the spot via the lock's new
  `lockNow()`. (Android also offers a manual lock whenever the device can
  authenticate; iOS ties the entry to the lock being enabled, which is what its
  authenticate/retry path requires and what keeps a manual lock from ever
  stranding the user.) The Help entry follows once the user guide is bundled.
- **The CSV header table builds under SwiftLint `--strict`.** `CsvHeaderLabels`
  had grown a twenty-one-branch `switch` (one `case` per language) whose
  cyclomatic complexity and per-line length both tripped the strict lint that
  `make ios` runs, failing the build before any test ran. The captions now live
  in a keyed `[String: [String]]` table with a flat lookup — complexity one, no
  over-long lines — with every caption preserved byte-for-byte. The
  `check-l10n-parity` CHECK 5 parser reads the table rows instead of the former
  `case` arms, and still enforces column-by-column identity with Android (a
  deliberately corrupted caption is still caught).
- **The overflow menu's Help now opens an in-app user guide.** Android's Help
  shows a per-language user guide generated from templates; iOS had no counterpart
  and the menu's Help entry was deferred. It now exists. An iOS-specific guide
  template (`ios/docs/guide/usersguide.md.in`) is adapted from Android's in the
  few spots that differ — iOS 17 system requirements, Face ID / Touch ID rather
  than a fingerprint, the App Switcher rather than the recent-apps overview, and
  the menu in the top-left — while the rest, describing features that behave
  identically, is shared. A new `tools/render-guide-ios.py` resolves the
  `{{token}}` labels against the String Catalogue (so the guide always names the
  labels the app shows, e.g. "App lock", not Android's "Biometric Lock") and
  writes a gitignored `usersguide_<tag>.md` per language, exactly as
  `copyright.md` is generated. The `make ios` static gate gains `check-ios-guides`
  to catch a stale guide. Help opens the guide for the app's language with an
  English fallback. Only the English guide shipped at first; the guide now exists
  in all of the app's languages. The twenty translations are adapted from
  Android's per-language guides, with the four platform-specific passages — Face
  ID / Touch ID rather than a fingerprint, the App Switcher rather than the
  recent-apps overview (and the note that iOS cannot block screenshots), the iOS
  system requirements, and the top-left menu — rewritten for iOS. They are
  best-effort and await native review, exactly like the string translations.
- **The app lock is harder to switch off, and no longer fooled by a sleeping
  device.** Two fixes brought over from the Android lock review. First, the
  App-lock switch now requires Face ID / Touch ID (or the passcode) BOTH to turn
  the lock on and to turn it off, and a cancelled prompt leaves the setting where
  it was — previously the switch wrote the preference directly, so anyone holding
  the unlocked phone could simply disable the lock. This matches Android's
  `authenticateForToggle`. Second, the 30-second re-auth window is now measured
  with `ContinuousClock`, which keeps counting while the device sleeps, instead of
  `ProcessInfo.systemUptime`, which stops; a phone left locked in a pocket past the
  window now correctly re-prompts on return, matching Android's `elapsedRealtime`.
- **The capacity traffic-light dots are now shown on iOS.** Android marks each
  drink with a green/yellow/red dot — how many more servings fit before a limit
  is crossed — in the drinks list and next to the grams preview in the log dialog.
  On iOS the calculation (`AlcoholCalculator.trafficLight`) and its shared test
  vectors were already there, but no view drew the dot, and the Settings toggle
  for colour-blind status symbols therefore did nothing. The dot now appears in
  the drinks list (between the star and the name) and beside the grams preview in
  the log sheet, on both the Drinks and Today screens. A small `DrinkCapacityModel`
  publishes the day's budget snapshot and refreshes when an entry is logged or a
  limit changes; the dot reuses the limit bars' colours so bar and dot agree, adds
  the colour-blind glyphs (cross / arrow / "1") when the symbols toggle is on —
  which now has an effect — and carries a localised VoiceOver label. Three
  capacity-status labels were added in all languages, from Android.
- **The unlock prompt is now localized.** The running lock's prompt showed a
  hard-coded English string, while the rest of the app — including the toggle
  prompt added alongside the lock hardening — speaks the in-app language. The
  reason is now set from the language setting each time it changes (the same place
  the gate is armed), reusing the "Please authenticate" string, which is exactly
  what Android shows for every biometric prompt.
- **Manual "Lock app" no longer requires auto-lock to be on.** The overflow menu's
  lock entry, and `lockNow()`, were tied to the automatic lock being enabled, so a
  user who had not switched on auto-lock could not blank the screen on demand —
  unlike Android, which offers it whenever the device can authenticate. The entry
  now appears, and locks, whenever a biometric or device passcode is available;
  the unlock path (`retry`, and the reprompt on returning while locked) no longer
  depends on the auto-lock setting, so a manual lock can always be cleared and
  never strands the user. It stays hidden when the device has no authenticator.
- **Folded `ios/README.md` into the root `README.md`.** The iOS developer notes
  (package layout, the XcodeGen build, `swift test` and the smoke-test bundle,
  the generated `Version.xcconfig`, and the GRDB dependency) now live in a
  "Building the iOS app" section under Technical Aspects, so there is a single
  README. Two stale lines were dropped in the move: the domain layer no longer
  "will live" in the package (it does), and the closing "this is a scaffold …
  domain logic is not ported yet" no longer held. The two pointers to the old
  file (`tools/gen-ios-version.py`, `CONTRIBUTING.md`) were repointed.
- **Extended the assurance case to cover the iOS port.** `docs/ASSURANCE_CASE.md`
  argued security for the Android app alone. Every claim that rests on a platform
  facility now names the Android and iOS mechanism side by side: the Keychain
  (`WhenUnlockedThisDeviceOnly`) AES-256-GCM preferences sealing via CryptoKit
  next to the Android Keystore, database backup exclusion next to
  `allowBackup="false"`, GRDB parameterized queries and migrations next to Room's,
  Swift/ARC memory safety next to Kotlin/ART, and the shared validators and CSV
  neutralization. The screen boundary is stated honestly: iOS has no `FLAG_SECURE`
  equivalent, so active screen capture is added as an explicit iOS residual risk,
  with the app-switcher cover addressing only the passive preview. The review
  record now notes that the iOS security-relevant areas are argued here and
  exercised by the package tests and gates, with a dedicated on-device iOS review
  pass to be recorded when performed. Claims were checked against the iOS sources
  (`SecretKeyProviding`, `PreferencesStore`, `BackupExclusion`, `CsvExporter`,
  `AppDatabase`) rather than asserted.
- **Recorded the deferred iOS parity items on the roadmap.** The parity sweep left
  two conscious iOS omissions for a decision. The calendar year view was already
  tracked under "Two deferred iOS parity items" in `docs/ROADMAP.md`, so it needed
  nothing. The accessibility side was not: an iOS/VoiceOver counterpart to the
  Android/TalkBack self-assessment (`docs/WCAG_LEVEL_A_CHECKLIST.md`) is now added
  as future work under Accessibility, noting that the port already labels its
  controls for VoiceOver but has no recorded structured pass, and that the
  Compose-specific Level-AA gaps do not transfer to the separate iOS views. A
  stale "native Android app" aside in the same section was corrected to "native
  mobile app."
- **Moved the install guides and the Code of Conduct under `docs/`.**
  `INSTALL-ANDROID.md`, `INSTALL-IOS.md`, and `CODE_OF_CONDUCT.md` now live in
  `docs/` alongside the other project documents, leaving the repository root less
  cluttered. The README links all three (the Code of Conduct newly, from
  "Feedback & Contributing"; the install guides repointed), and every other
  pointer was updated to the new paths: `CONTRIBUTING.md` and `COPYING.md`, the
  `code_of_conduct_justification` in `.bestpractices.json` (location text and
  Codeberg URL), and `tools/check-headers.py`, whose licence-header exclusion is
  matched on the repository-relative path and would otherwise have demanded a GPL
  header on the CC-BY-licensed Code of Conduct. Historical changelog entries that
  named the old paths were left as written. The forge recognizes a Code of
  Conduct under `docs/`, so its badge status is unaffected.
- **Fixed a SwiftLint `type_body_length` failure in `StatsScreen`.** The view's
  body had grown to 251 lines, one over the configured 250-line limit, breaking
  the `check-swiftlint` gate on macOS. Five presentation helpers (`weekdaySymbol`,
  `name`, and the `grams`/`count`/`days` formatters) were moved verbatim into a
  same-file `extension StatsScreen`, which SwiftLint does not count toward the
  type body while Swift still shares the type's `private` scope, so the view code
  reaches them unchanged. Body length drops to about 233. An orphaned `// ── CSV`
  section marker left over from an earlier edit was removed in passing.
- **On-screen numbers now follow the in-app language (iOS).** Grams, the BAC
  estimate, percentages, and the body weight were formatted with POSIX
  `String(format:)`, so they always showed a dot — a German or French user saw
  "20.0 g" and "0.50 ‰" instead of "20,0 g" and "0,50 ‰", out of step with the
  rest of the localized UI. This mirrors an Android fix (numbers had followed the
  system rather than the in-app locale). A new
  `Loc.number(_:fractionDigits:locale:signed:)` — the `NumberFormatter` the display
  code had long noted was pending — formats every on-screen figure in the chosen
  locale, applied across Today, Statistics, Calendar, Drinks, the entry sheet, and
  Settings (including the trend's leading sign and a VoiceOver grams label).
  Exports are untouched: CSV and the PDF report keep their fixed POSIX format by
  design. To keep the Settings and Statistics view bodies within SwiftLint's
  `type_body_length`, the Settings rows format through a small `measure` helper in
  the existing extension.
- **Fixed a strict-concurrency build error in `DrinkCapacityModel`.** Its `deinit`
  cancelled the observation tasks by reaching into the `@MainActor`-isolated
  `observations` array, which a nonisolated `deinit` may not touch — the iOS build
  failed to compile with "main actor-isolated property 'observations' can not be
  referenced from a nonisolated context". The `deinit` was removed: the tasks
  already capture `self` weakly, so they cannot keep the model alive, and the view
  calls `stop()` on disappearance. This is exactly the no-`deinit` pattern the
  other models (Today, Calendar, Statistics, Drinks) already follow and document.
- **Fixed two `check-l10n` failures introduced by the number localization.**
  Routing on-screen numbers through `Loc.number` moved two literals into a form the
  localization scanner rejected. The BAC readout's `"\(…) ‰"` tripped because the
  permille sign was missing from the scanner's neutral-unit list — a genuine
  oversight, since `‰` is as language-neutral as `%`, so it was added there rather
  than pointlessly routing a non-translatable symbol through `Loc.string`. The
  drink editor's live grams label nested `calculateGrams(…)` inside the number
  interpolation, and the scanner's single-level parenthesis strip could not see
  through two levels; the value is now computed in a small `grams` helper so the
  interpolation is single-level and the `Text` holds no literal at all. Both were
  format-only; no user-visible behaviour changed.
- **Fixed a build break in the Statistics trend readout.** Localizing the trend
  percentage had wrapped its `Loc.number` call across several lines *inside* a
  string interpolation, which Swift does not allow — a single-line string literal
  cannot contain a newline in its `\(…)`, so the compiler saw an unterminated
  literal. The value now goes through a small `trend` formatting helper beside the
  existing `grams` one, keeping the interpolation on one line and the call site
  short. No behaviour changed.
- **Moved the iOS build how-to out of the README into `docs/INSTALL-IOS.md`.**
  The README's "Building the iOS app" section was a full build walkthrough that
  belonged with the from-scratch install guide, not in the project overview. Its
  unique material — the `ios/` source layout, the app's smoke-test bundle, the
  `Version.xcconfig` confirmation and "never set it in `project.yml`" rule, and
  the GRDB `Package.resolved`/`COPYING.md`/App-Store note — was folded into
  `docs/INSTALL-IOS.md`, and the section was removed from the README. The README
  now links both install guides in a single short paragraph. The stale pointer in
  `CONTRIBUTING.md` was repointed at the install guide. Concrete dependency
  versions were also dropped from the README's build-infrastructure section so it
  no longer drifts on every dependency bump; the Gradle build files remain the
  single source of truth for exact versions.
- **Fixed a cross-file access error that broke the Statistics export build.**
  An earlier round localized the export failure messages in
  `StatsScreenExport.swift` — an `extension StatsScreen` that lives in its own
  file — to `Loc.string(…, locale: locale)`. But `locale` was declared `private`
  on `StatsScreen`, and Swift's `private` is file-scoped: a same-type extension in
  another file cannot see it, so the four `locale` references failed to compile.
  The neighbouring `model` and export state are already `internal` for exactly
  this reason (with a comment saying so); `locale` now joins them. The error only
  surfaced now because earlier builds aborted before reaching this file. No
  behaviour changed.

- **The Today card now shows the month's average, matching Android.** Android's
  Today screen carries a per-day average for the current month ("Ø <month>:
  <x> g/day") with an up/down arrow against the pre-month baseline, and a date
  range on the seven-day figure; iOS had deferred all four until localisation
  existed. `TodayModel` now computes `monthlyAvgPerDay` and `monthTrend` in the
  kit — a faithful port of `TodayViewModel`, including the `statsFromDate` floor
  that clips a mid-month start (the v0.81.0 fix) and the baseline that divides the
  whole earlier period by its own day count. The two locale-dependent labels stay
  in the view: the standalone month name and the `weekStart–today` range are
  formatted from the state in the in-app locale, so the kit holds no
  `DateFormatter` locale choice. The `g/day` unit and the `Ø %@` caption reuse
  Android's own translations (`grams_per_day`, `avg_of_month`) in every language.
  Three `TodayModelTests` cover the divisor, the trend against a previous month,
  and the mid-month floor.

- **Kept the Today tests within SwiftLint's class-length budget.** The three new
  `TodayModelTests` pushed the class body past the 250-line `type_body_length`
  limit. The fixtures (`entry`, `waitUntil`, `logDay`) now live in an
  `extension TodayModelTests`, which SwiftLint does not count against the class:
  the test methods stay in the class so XCTest still discovers them, and a test
  class earns its length from tests, not fixtures.

- **A container guard now catches SwiftLint's length limits.** SwiftLint is a
  macOS binary, so the Linux `check-ios-static` gate could not run it, and its
  length rules — the ones that fail a build without a compile error — surfaced
  only on the Mac, one round-trip late (the two fixes above were both such
  overruns). `tools/check-swift-length.py` reproduces those counts in Python:
  `type_body_length` (250, SwiftLint's default — the config does not override
  it), `file_length` (500) and `line_length` (120), reading the limits and the
  included/excluded roots from `ios/.swiftlint.yml` so the two cannot drift. It is
  an early warning beside `check-swiftlint`, never a replacement — the Mac's
  `--strict` pass stays authoritative for every rule — and it is calibrated to
  agree with SwiftLint on the whole committed tree, so it never fails a build
  SwiftLint would pass. `function_body_length` and the non-length rules remain
  SwiftLint's alone.

- **Silenced a strict-concurrency warning at the app entry point.**
  `PotillusApp.continuousUptime()` — the sleep-inclusive monotonic clock AppLock's
  re-auth window is measured against — was main-actor-isolated by inference, since
  `PotillusApp` is an `App` and therefore `@MainActor`. But `AppLockModel` stores
  the `uptime` closure as `@Sendable` and calls it off the main actor, so the call
  sat in a nonisolated context and Swift's concurrency checking flagged it. The
  reading depends on nothing actor-isolated — a `ContinuousClock` and an immutable
  `Sendable` epoch — so the method is now `nonisolated`, matching the existing
  `StatsModel.dayCount` pattern. Behaviour is unchanged; the warning is gone.

- **The iOS app now has an app icon.** The port shipped without one: there was no
  asset catalog in `ios/`, so the build set no `CFBundleIconName` and bundled no
  icon, and App Store upload validation rejected it (missing 120×120 icon and the
  `CFBundleIconName` key, error 90713/90022). An `AppIcon` asset catalog is added
  at `ios/Potillus/Assets.xcassets` with a single 1024×1024 marketing icon (Xcode's
  actool derives the smaller sizes), and `project.yml` names it via
  `ASSETCATALOG_COMPILER_APPICON_NAME` so actool writes the key and emits the icon.
  The artwork is the Android launcher's — the white glass-and-straw on the
  `#1A1E2B` background — vectorised from the 512×512 Play-Store icon to a crisp,
  opaque 1024×1024; the vector master is kept at `ios/icon/appicon.svg`.

---

## v0.81.0

Add accessible capacity symbols and chart labels

This release improves accessibility for colour-vision deficiency and for
screen-reader users, addressing the roadmap's Level-A chart gap and the
"Use of Color" concern on the traffic-light indicator. It additionally folds
in the fixes from the seventh full QA review of the whole tree; those include
user-visible corrections — the statistics trend baseline, the Today card's
monthly average and the PDF report's abstinence figures now honour the
"Statistics From" date and the chosen export range, and the date picker for
that setting no longer blocks the local today on timezones east of UTC — each
listed individually below.

- Drink validation: one rule set instead of two. The rules for a drink
  definition lived in both `DrinksViewModel` and `AddEditDrinkDialog`, and the two
  disagreed. The dialog capped the serving size at 5000 ml while the ViewModel
  accepted up to 10 000, so no user could ever create the larger drink the domain
  allowed; and the dialog never checked the name's length, so a name beyond 100
  characters left the Save button enabled and the write was then silently dropped
  — a button that lied about what it would do. Both now consult
  `AlcoholCalculator`'s neighbour `DrinkValidator`, which fixes the serving size
  at 1…5000 ml, the alcohol content at a finite 0…100 %, and the name at 1…100
  characters measured after trimming. A too-long name marks the name field in
  error and disables Save, matching how the volume and alcohol fields already
  behave. `updateDrink` is now validated as well; it previously trusted its
  caller, which happened to be the dialog.

- Drink-days bar: fix the colour at exactly the allowance. The bar turned red
  only once the drink-day count strictly exceeded the maximum, so a user who had
  already spent every permitted drink day but had not yet drunk today saw an
  amber bar next to a red traffic-light dot — the two indicators answered the
  same question, "may I drink now?", differently. A drink day, once spent, stays
  spent for the whole day: at 5 / 5 with today already a drink day the bar is
  amber, because another drink adds no further drink day; at 5 / 5 with today
  still dry it is now red, because the first drink would spend a day that is no
  longer available. Both displays now share one predicate,
  `AlcoholCalculator.drinkDayLimitReached`, extracted from the traffic light's
  own gate, and a test walks the whole grid to keep them in step. The gram bars
  are unaffected: reaching a gram limit leaves no room for the next drink, so
  they stay red at 100 %.

- Alternative status symbols (opt-in). A switch under Settings → Appearance
  makes the traffic-light capacity dot draw a distinct glyph inside its coloured
  circle in addition to the colour: a cross when the limit is reached, a "1"
  when one serving remains, and an up-arrow when there is room for more. This
  adds a shape cue on top of hue, so the three states can be told apart without
  relying on the red/yellow/green colours alone — an aid for red–green
  colour-vision deficiency (WCAG 1.4.1 "Use of Color") when enabled. It is off
  by default; the plain coloured sphere is shown until the user turns it on. The
  flag is `alternativeStatusSymbols` in `AppSettings`, threaded from the setting
  through `TodayScreen`, `DrinksScreen` and the log dialog into `TrafficLightDot`.
- Screen-reader description for the capacity dot. `TrafficLightDot` now carries
  a localized `contentDescription` announcing the capacity state regardless of
  the symbol setting, so TalkBack conveys what sighted users read from the
  colour/glyph. It uses `clearAndSetSemantics` so the dot reads as a single node
  rather than leaking a raw glyph.
- Chart text alternatives (WCAG 1.1.1, Level A). The three statistics charts —
  `AlcoholBarChart`, `ValueBarChart` and `CategoryDonutChart` — are drawn on a
  bare `Canvas` and were previously invisible to a screen reader. Each now
  exposes a summarising `contentDescription` via `semantics`; the generic
  `ValueBarChart` takes an optional caller-supplied label, which `StatsScreen`
  fills from the existing "time of day" and "weekday" section headings.
- Custom clickable surfaces get a button role (WCAG 4.1.2 Name, Role, Value).
  The calendar month-grid day cells and the year heat-map day cells are plain
  `clickable` `Box`es; they now declare `role = Role.Button` so assistive tech
  announces them as actionable. The month cells additionally gain a "date,
  grams, status" `contentDescription` (reusing the year heat-map's caption
  strings, so no new locale keys), exposing the over/under-limit state that was
  previously conveyed only by the dot's colour.
- Backups. The new preference is written into JSON backups within backup
  format 3 as an optional field, so no format bump is needed: an older
  format-3 backup that lacks the key restores with the setting defaulting to
  off, and a REPLACE (full) restore applies it while a MERGE keeps the local
  value — matching how the other settings behave.
- Localization. Eight new string keys (three capacity-state descriptions, the
  toggle title and summary, and three chart descriptions) were added to all 21
  locale files, keeping every locale complete for `LocaleSyncTest`.
- Tests. `SettingsViewModelTest` covers the new setter and its round-trip
  through restore; `BackupManagerTest` covers the settings round-trip with the
  new field and the tolerant default when a format-3 backup omits the key.
- Docs. Added `docs/WCAG_LEVEL_A_CHECKLIST.md`, a manual WCAG 2.2 Level A
  self-assessment protocol tailored to the app (per-criterion pass/fail, a
  per-screen TalkBack walkthrough and a sign-off template) to guide the
  on-device evaluation these accessibility changes prepare for.
- Build & release tooling (Makefile / fastlane). Two new fastlane lanes in
  `fastlane/Fastfile` upload the signed AAB together with the full store
  metadata to Google Play: `testing` targets the closed-testing alpha track
  (status completed) and `production` targets the production track staged as a
  draft for manual review; both share a `private_lane :upload_release` helper
  and neither builds the bundle. The root Makefile gained matching upload-only
  targets `push-playstore` (drives the `testing` lane) and `push-codeberg`
  (creates a Codeberg/Forgejo release for the already-pushed tag over the REST
  API and attaches the release APK + SBOM). Both fail fast when a prerequisite
  is missing and read their secrets from git-ignored files
  (`fastlane/play-store-credentials.json`, `fastlane/codeberg-credentials.txt`).
- Device-free default build. The on-device instrumentation tests were split out
  of the default `debug` target into a separate `device-tests` target, so the
  everyday build (release gate, lint, JVM unit tests, guide/copyright sync,
  debug APK) no longer needs a device; `release` now refreshes the screenshots
  and feature graphics and then builds the signed APK, AAB and SBOM in one step.
- Makefile hygiene. Recipes now echo the commands they run (secrets stay in
  shell variables, so no token value is printed); tool-presence checks were
  reduced to plain `command -v` guards that fail fast under the Makefiles'
  strict shell flags; a redundant `-` ignore-errors prefix was dropped from the
  Demo-Mode tear-down, where the per-command `|| true` already makes each step
  best-effort; and the in-Makefile target overviews / `help` texts were
  brought back in sync with the current target set.
- Statistics trend vs. "Statistics From" (seventh QA round): the trend arrow
  and percentage on the Statistics screen compared the current period against
  a previous-period baseline that ignored the configured statistics start
  date. With a floor inside or after the previous window, the baseline summed
  entries the setting promises are "ignored in all statistics"
  (`stats_from_desc`). The baseline query and its per-day divisor are now
  clipped to the same floor as the current period; a window entirely before
  the floor yields no baseline and the trend reads FLAT, exactly like the
  no-history case. Pinned by a new `StatsViewModelTest` regression test.
- Today card monthly average vs. mid-month "Statistics From" (seventh QA
  round): a statistics start date INSIDE the running month was ignored by the
  Today card — its monthly average kept anchoring at the 1st of the month, so
  excluded entries and days entered sum and divisor, disagreeing with the
  Statistics screen's correctly clipped MONTH view. The card's month anchor is
  now clamped to the floor; sum, filter and divisor cover the identical span.
  Pinned by a new `TodayViewModelTest` regression test.
- PDF report abstinence figures for historical export ranges (seventh QA
  round): a report over a range that ended in the past anchored its "current"
  and "longest abstinence" at the REAL today, counting every day from the last
  in-range drink until now as abstinent — including post-period days on which
  the user did drink. The streaks now anchor at the period end (range end + 1
  day) for historical ranges and keep the real-today anchor when the range
  ends today, preserving the Statistics-screen parity for the default export.
  `StatsViewModel.exportPdf` threads the chosen range end through
  `PdfReportBuilder.buildHtml` into `PdfReportData.from`; two new
  `PdfReportDataTest` cases pin both anchors.
- "Statistics From" date picker timezone bound (seventh QA round): the picker
  capped selectable days at the UTC calendar day, so east of UTC the user's
  local today was unselectable for up to the zone offset after midnight, and
  west of UTC the local tomorrow was briefly selectable. The bound now derives
  from the local calendar day (read through `DayResolver.clock()`, matching
  the export range dialog and the screenshot-pinning convention).
- Backup restore validates the language tag (seventh QA round): a restored
  `language` value is now matched case-insensitively against
  `SupportedLocales` and canonicalised; unknown tags degrade to the
  follow-system sentinel instead of being persisted and applied verbatim from
  a hand-edited file. Covered by new `BackupManagerTest` cases.
- Feature-graphic renderer refuses to run with missing bundled fonts (seventh
  QA round): fontconfig silently substitutes a missing family, so an absent
  face under `tools/fonts/` (e.g. the statically instanced Rokkitt Bold, see
  `make rokkitt-bold` and COPYING.md) would have set the F-Droid badge text in
  the wrong typeface without any warning. `tools/render-feature-graphic.py`
  now checks the exact bundled font files up front and fails loudly with the
  recovery command.
- Documentation corrections (seventh QA round): the Keystore KDoc no longer
  claims StrongBox backing (`KeystoreSecretStore` / `AppPreferences` — the key
  is TEE-backed; StrongBox would require `setIsStrongBoxBacked(true)`, which
  is deliberately not requested); the `DrinkDaysBar` KDoc now describes the
  trailing 7-day window instead of the pre-v0.62.0 "Mon–Sun week"; the
  unreachable `application/pdf` chooser branch in `SettingsScreen`'s share
  effect (dead since CSV/PDF export moved to Statistics and the PDF path
  stopped producing a file) was removed; and COPYING.md's build-time tooling
  list gained the KSP, Kover and ktlint Gradle plugins alongside the already
  listed CycloneDX plugin.
- Screenshot pipeline captures at an exact 2:1 instead of cropping (seventh QA
  round, follow-up): `make screenshots` now overrides the capture device's
  display to 1428x2856 @ 640 dpi (`SCREENSHOT_SIZE` / `SCREENSHOT_DENSITY`, an
  exact 2:1 at ~357 dp usable width), so Google Play's max-2:1 rule is met by
  construction and the store shots show the full, uncropped app. The former
  `screenshots-crop` step and `tools/crop-screenshots.py` are removed with it,
  and any device geometry is now acceptable. Two robustness fixes on top of that
  change: the sticky `wm size` / `wm density` overrides are reset in
  `screenshots-demo-off`, so the EXIT trap restores the device even after a
  Ctrl-C or a failed capture (previously a phone stayed scaled indefinitely);
  and the `require-pillow` pre-flight — dropped with the crop step — is
  reinstated for `feature-graphics`, because `tools/render-feature-graphic.py`
  still imports PIL for the phone mockup and would otherwise fail with a bare
  ImportError. All 21 locales' in-app screenshots 01..06 are recaptured at the
  new geometry; store assets only, no app behaviour change.
- Screenshot capture waited on the wrong signals (eighth QA round): the store
  assets disagreed across languages although every locale renders the same
  `fastlane/demo-backup.json` — e.g. `01_today.png` showed a monthly average of
  0.0 g/day in 14 of 21 locales and the correct 8.0 g/day in the other 7. The
  captures waited for STATIC elements (a nav label, or the mere disappearance of
  an empty-state label), which are laid out in the very first frame; every screen
  ViewModel, however, publishes its state through `stateIn(..., <UiState>())`,
  whose all-empty SEED is shown until the backing Room Flow emits. Whether a run
  caught the seed frame was pure timing luck, and the luck differed per locale
  because the capture language switch recreates the Activity — and its
  ViewModels — only in locales other than the device language. Two further
  symptoms had the same root: `02_calendar.png` was captured without day markers
  and without the day-detail card in 6 locales, and `04_drinks.png` showed the
  empty "no drinks" screen in 7 (its wait for the DISAPPEARANCE of that label was
  satisfied vacuously while the page had not composed yet, so its timeout never
  fired). `ScreenshotTest` now routes every capture through one helper that
  enforces a two-stage readiness contract: the screen must expose a POSITIVE,
  data-derived marker that cannot exist in the seed state (the month name in the
  Today caption, the Calendar's day-detail label, the fixture's period total on
  Statistics, a drink row's edit icon), and that marker must then be visible in
  the device's own accessibility tree with the device idle. The second stage also
  fixes `06_settings.png`, which showed the Drinks screen in 9 locales: the
  previous wait proved only that the Settings destination had COMPOSED, while
  screengrab grabs the compositor's surface, which was still drawing the
  predecessor. Both stages now fail loudly instead of silently saving a wrong
  asset. Every expected string is resolved through the same sources production
  uses (localized context, `FULL_STANDALONE` month names on the detected app
  language tag, `Double.fmt1`), so the markers cannot drift from the rendered UI
  in any of the 21 languages. Test-only change; no production code is touched.
  The committed PNGs have since been recaptured with the fixed suite (verified
  in the tenth QA round: all 21 locales show the fixture data, none the seed
  state), so the store assets in the tree are the correct ones.
- Two-text rows no longer break in verbose languages (eighth QA round): on the
  Today card the drink-days label and its week range shared a `SpaceBetween` row
  in which BOTH texts were measured at their intrinsic width. A long localized
  label ("3 / 5 дней с алкоголем (последние 7 дней)", "0 / 5 μέρες κατανάλωσης
  (τελευταίες 7 ημέρες)") then claimed the whole row and the week range was
  squeezed into the remainder, where it wrapped mid-token into a ragged second
  line touching the label. The fix applies the rule `StatRow` has followed since
  v0.78.0 — weight the FLEXIBLE text, pin the FIXED one to one unbroken line — to
  `DrinkDaysBar`, `LimitBar` and the Today card's caption and headline rows. In
  the affected languages the left label now wraps to a second line instead of
  displacing the range, so those rows are one line taller; no text is truncated.
  The same measurement trap was closed at three further sites found by sweeping
  every two-child `Row` in the UI: the Settings rows for body weight, daily
  limit, 7-day limit, max drink days, day-change time and statistics-start date
  put their label ahead of a fixed-size edit button without a weight (the sibling
  switch rows already had one), and the calendar's month header sat between two
  icon buttons unweighted — a long month name could have pushed the "next month"
  arrow off the row; it is now weighted, centred and ellipsized. Layout only, no
  behavioural or data change.

- Publishing tooling verifies the signer key (ninth QA round, release-tooling
  focus). `make push-playstore` and `make push-codeberg` previously checked only
  that a release artifact existed, not that it was signed — and for the AAB the
  unsigned and signed outputs share the name `app-release.aab`, so an unsigned
  bundle would have been uploaded and rejected by Play only after the full
  metadata round-trip. Both targets now prove the signature and pin the signer
  before doing anything: `push-playstore` runs `jarsigner -verify` on the bundle
  (reading its "jar verified." verdict, because the exit code alone passes an
  unsigned archive) and `keytool -printcert` to read the signer certificate;
  `push-codeberg` requires the signed `app-release.apk` name and runs
  `apksigner verify` / `--print-certs`. Both compare the certificate SHA-256
  against the fingerprint published in SECURITY.md, so an artifact signed with
  the wrong key is refused. The signing tools run non-interactively and are found
  on `PATH`, else from `JAVA_HOME` / `ANDROID_HOME`.
- `push-codeberg` verifies the tag is pushed, not merely created locally.
  Codeberg's release API resolves the release against a server-side tag, so a
  purely local tag made the create call fail late; the target now checks the tag
  on the same remote `make push` uses (the branch upstream, else `origin`) and
  fails fast with an actionable message.
- `push-playstore` gains a Play-side dry run and the same tag guard. A new
  `VALIDATE_ONLY=1` switch threads fastlane supply's `validate_only` through the
  `testing` / `production` lanes, so `make push-playstore VALIDATE_ONLY=1`
  validates the upload (credentials, AAB, metadata) against the Play API without
  changing anything on Google Play. And, mirroring `push-codeberg`, the target now
  requires the release tag `vX.Y.Z` to exist locally and on the push remote before
  uploading -- Play has no notion of git tags, so this is a release-hygiene gate
  that keeps every published build tied to a recorded, pushed tag.
- `make release` no longer captures screenshots, and is now device-free. It
  previously ran `make screenshots` first, forcing a connected device/emulator
  just to build the signed APK/AAB/SBOM. Screenshots and feature graphics are
  store assets needed only at publish time, so capturing them is now decoupled:
  run `make screenshots` (or `make store-assets` for the whole set) on demand,
  exactly as the report pages 07/08 already worked. Building the release
  artifacts needs no device.
- Release-tooling hygiene. The redundant early `command -v bundle` in
  `push-playstore` was dropped (the `bundle check` guard already covers it), and
  a stale reference to a non-existent `docs/PLAY_STORE.md` was removed from
  `fastlane/Fastfile` and `fastlane/README.md`. Tool availability is checked with
  plain `command -v` calls, documented in a comment above each, so the recipes
  show exactly what they run. Relatedly, the device pre-flight checks in
  `screenshots`, `report-pdfs`, `test-device` and `install-debug` no longer fail
  silently: the `adb devices` probe is traced with a scoped `set -x` so the literal
  command shows up next to the failure (`.ONESHELL` echoes the whole recipe once,
  up front and far from where it runs), and in `screenshots` / `report-pdfs` it now
  runs BEFORE the Gradle build so a not-running emulator fails fast instead of
  after a full build. The `java` target likewise prints `java -version` before its
  version test, so a wrong JDK is visible instead of a bare `Error 1`.
- Docs. SECURITY.md now states key custody per channel accurately: the maintainer
  holds the app-signing key for the Codeberg / F-Droid APK, and — under Google
  Play App Signing — the upload key for Play, while Google holds Play's own
  app-signing key. The certificate-fingerprint verification note clarifies that
  the published fingerprint identifies the F-Droid / Codeberg APK signer and that
  a Play-delivered APK carries Google's re-signing key. `release-check.sh` gained
  a section (14 / 14) that fails the build unless SECURITY.md carries exactly one
  canonical signing-key fingerprint, since the publishing targets read the pin
  from there. Tooling and documentation only; no app-visible behaviour changed,
  so no versionCode bump and no store-note changes.
- Release-tooling correctness (eighth QA pass). The remote-detection line shared by
  `push-playstore` and `push-codeberg` could abort the whole recipe instead of
  falling back to `origin`. Under the Makefile's `.SHELLFLAGS := -eu -o pipefail`, a
  checkout with no configured upstream makes `git rev-parse @{u}` exit non-zero;
  pipefail propagates that through the pipe and `set -e` then kills the recipe ON THE
  ASSIGNMENT, before the `${remote:-origin}` fallback on the same line can run. A
  `|| true` inside the command substitution now swallows the failure so the fallback
  supplies `origin` as designed; the happy path (upstream configured) is unchanged.
  Both publishing targets were still untested, so this latent abort had not surfaced.
- Docs. A stale `deploy`-lane reference in SECURITY.md (the Play-credentials bullet)
  was corrected to the current `testing` / `production` Play-upload lanes, and the
  illustrative versionCode in `fastlane/README.txt` — long outdated at 66 — was
  replaced with a drift-free `<N>` placeholder so the example needs no edit on
  future releases. Tooling and documentation only; still no app-visible
  behaviour change, so no versionCode bump and no store-note changes.

- Favourite toggle no longer re-validates untouched fields (tenth QA round).
  `DrinksViewModel.updateDrink` gained full `DrinkValidator` checks earlier in
  this release, and the Drinks screen's favourite star ran through it — so a
  drink imported from a backup with a serving size outside the editor's
  1…5000 ml (the reader deliberately accepts up to 10 000 and promises such a
  drink "stays usable"; see the BackupManager import comment) could no longer
  be favourited: the star tap failed with a volume validation error for a field
  the user never touched. The star now goes through a dedicated
  `DrinksViewModel.setFavorite`, which writes only the flipped flag and leaves
  the stored, already-accepted values byte-identical; genuine edits keep the
  full validation. The regression was introduced within this unreleased version
  and never shipped, so no store-note change is needed. Two new
  `DrinksViewModelTest` cases pin the contrast (star works on an out-of-range
  import, a real edit of it is still rejected).
- Publishing-tooling verification and hardening (tenth QA round). `release`,
  `push-playstore` and `push-codeberg` were exercised end to end in a stubbed
  environment — signed dummy artifacts, a local git remote with a pushed tag,
  real jarsigner/keytool/apksigner, every guard triggered individually — and
  the lane options and path resolution were verified against the pinned
  fastlane 2.237.0 sources. Findings fixed on top: the signing-key pin read
  from SECURITY.md is now lowercase-normalized in the Makefile AND
  release-check §14 fails on a non-lowercase fingerprint, so a reformatted pin
  is caught at build time (as that section promises) instead of making both
  push targets refuse correctly signed artifacts at push time; the
  unpushed-tag guard in both targets now fails with a named-tag message
  instead of a bare git exit code; `push-codeberg` is safe to re-run after a
  partial failure — it reuses an existing release for the tag and skips
  already-attached assets instead of tripping Forgejo's duplicate-release
  409 — and no longer places the access token on any curl command line (it
  goes into a mode-0600 temp header file passed with `-H @file` and removed
  by an EXIT trap, keeping it out of `/proc/<pid>/cmdline`).
- The `deploy` target in android/Makefile was removed (tenth QA round): it
  duplicated the root `push-playstore` while bypassing every safeguard that
  target adds — the jarsigner verification, the signer-fingerprint pin and the
  pushed-tag guards — and it rebuilt the bundle on the way, against the
  publishing targets' upload-only doctrine. Upload with `make push-playstore`
  (dry run: `VALIDATE_ONLY=1`); a breadcrumb comment marks the old spot.
- Makefile hygiene (tenth QA round): `prereq`'s `$(GUIDE_OUTPUTS)` prerequisite
  silently expanded to nothing — the rule precedes `-include guides.d` and make
  expands prerequisite lists the moment it reads a rule, so the variable was
  still empty there. The guide outputs are now attached on a second dependency
  line placed after the include (make merges prerequisite lists; verified with
  `make -p`). No build was ever wrong: Gradle's own `generateUserGuides` task
  had masked the gap, which is exactly why it stayed unnoticed.
- Docs (tenth QA round): CONTRIBUTING's release checklist now publishes via
  `make push-codeberg` (signer pin, APK + SBOM release assets, re-runnable) and
  `make push-playstore` (with the `VALIDATE_ONLY=1` dry run) instead of
  describing a manual Codeberg upload that attached only the SBOM; and the
  eighth-round screenshot note above was corrected — the committed PNGs are
  the post-fix captures, not the old ones.

- Release artifacts are staged into a git-ignored `releases/` directory and the
  publishing targets upload from there (eleventh QA round, follow-up request).
  `make release` now copies the signed AAB, APK and SBOM into `releases/` under
  canonical, self-describing names — `de.godisch.potillus_<versionCode>.apk`,
  `_<versionCode>.aab`, `_<versionCode>_sbom.json` (e.g.
  `de.godisch.potillus_92.apk`) — with `cp --archive`, and refuses to start if a
  file for this versionCode is already staged (so a published set is never
  silently overwritten). `push-playstore` and `push-codeberg` now upload EXACTLY
  those staged files (fastlane's `aab:` option receives the staged path; the
  lane threads it through), run their signature/signer checks against the staged
  bytes, and use the canonical names as the Codeberg asset names. Neither push
  target builds or stages any more: each fails fast if the staged file is absent
  and does not trigger `make release`. After each Codeberg upload the published
  asset is re-downloaded from its release URL and its sha256 is compared with the
  staged file (one 2-second retry to absorb asset-endpoint lag), so a corrupted
  upload is caught. `.gitignore` gains `/releases`; the release checklist in
  CONTRIBUTING documents the staging step and the new asset names. Tooling and
  documentation only; no app-visible change, so no versionCode bump.

---

## v0.80.0

Include user settings in JSON backups

The JSON backup now carries the user's settings, closing a data-loss gap:
until now a "restore" on a fresh install brought back drinks and entries but
silently reset every preference — including the body weight that feeds the
blood-alcohol calculation — because the settings live in a separate encrypted
DataStore that the backup never touched.

- Backup format bumped from 2 to 3. The export writes a new top-level
  `settings` object (theme, day-change time, daily/weekly limits, max drink
  days per week, statistics start date, biometric lock, screenshot permission,
  language and body weight). Older apps that only understand versions 1–2
  reject a v3 file via the existing "version too high" guard rather than
  dropping the settings unnoticed.
- Restore semantics: a REPLACE import (full restore) applies the backup's
  settings; a MERGE import keeps the local settings and only adds data, so it
  never surprises the user by overwriting their current configuration. A
  pre-v3 backup has no settings block and leaves the local settings untouched
  in both modes — its drink/entry history still restores exactly as before.
- On import the settings are validated defensively (enum fallback, range
  clamping identical to the preference setters, canonical-date check for the
  statistics start date), so a slightly corrupt or hand-edited backup can
  never abort the restore of the primary drink/entry payload. The
  `weightKg == 0` (not set) and `language == ""` (follow system) sentinels are
  preserved rather than turned into a bogus 1 kg weight or an empty explicit
  locale.
- Restoring a language also re-applies it to the framework per-app locale
  (AppCompatDelegate), matching what the in-app language picker does, so the
  restored language takes effect immediately instead of drifting out of sync
  with the stored preference.
- Dynamic-analysis assertions: added `assert()` invariants to the domain layer
  (`AlcoholCalculator`, `DayResolver`) — the non-negative grams / BAC / limit-
  fraction / serving-count / streak / effective-day-count postconditions and the
  countLimitViolations sliding-window invariant. They are checked under `-ea` in
  the unit-test suite (fault detection during testing) and are no-ops in release
  builds, addressing the gold `dynamic_analysis_enable_assertions` item.
- Tests: settings round-trip and pre-v3 tolerance in BackupManagerTest;
  REPLACE-applies / MERGE-keeps and the weight/language sentinel guards in
  SettingsViewModelTest.

---

## v0.79.0

Work toward OpenSSF gold badge criteria

Development toward the OpenSSF Best Practices gold level (project 13480),
plus the fixes from full QA reviews of the whole tree (the fourth, fifth and
sixth review rounds folded into this release; the fourth was the first covering
every source, resource, tooling and store-metadata file at once, the fifth a
follow-up full pass, the sixth a further full pass focused on accessibility and
data-compatibility documentation). The OpenSSF work is documentation and process
only; the QA fixes include user-visible corrections — Chinese language
detection, the report's longest-abstinence figure, month/date label
localization, the day rollover on the Today screen, the PDF report's CJK glyph
orthography for Japanese/Korean/Traditional-Chinese, and accessible names for
the calendar navigation arrows, the drink-category icon and the year heat-map's
day cells (screen-reader only) — each listed individually below.

- Accessibility — honest conformance documentation (sixth QA round): documented
  the app's accessibility state truthfully and added a regression guard, without
  claiming any WCAG level. `docs/ROADMAP.md` (Accessibility) now states plainly
  that NO WCAG 2.2 conformance level is claimed and NONE of the W3C conformance
  logos is used — because a logo is a formal claim that ALL criteria of a level
  are met under a thorough human evaluation (not done here; W3C is explicit that
  no tool check suffices), there are verified open Level AA items, and the logos
  are web-page scoped rather than native-app scoped — and it lists the measured
  gaps: non-text contrast 1.4.11 (empty heat-map cells 1.1–1.3∶1, today outline
  1.2–1.5∶1, below 3∶1), text contrast 1.4.3 (`onSurfaceVariant` 4.39∶1;
  warning-red as text 3.25–4.23∶1), target size 2.5.8 (10 dp cells), and the
  on-screen chart's missing text alternative 1.1.1 (Level A). README gains a
  factual Accessibility subsection (capabilities, no claim, pointer to the
  roadmap); CONTRIBUTING §4 documents the labelling rule; and
  `.bestpractices.json` (`accessibility_best_practices`) is corrected — the
  heat-map labels are no longer a to-do, the over-broad "adequate touch targets"
  wording is scoped to standard controls, and the entry now states no WCAG level
  is claimed. A new `tools/release-check.sh` §13 (ACCESSIBILITY LABELS) fails the
  build if any `Icon` inside an `IconButton` has `contentDescription = null`, so
  the labels added in this release cannot silently regress (sections renumbered
  "/ 12" → "/ 13"; the check skips gracefully without python3 and is a labelling
  invariant only, not a WCAG conformance test). DELIBERATELY NOT changed: the
  per-locale store `full_description` — a non-conformance is not marketing copy,
  so the accessibility status lives in the roadmap, not the store listing.
  Documentation and tooling only; no app-behaviour change.
- Accessibility — year heat-map day cells (sixth QA round, accessibility
  follow-up): the year calendar's day squares in `YearCalendarView` encoded the
  under- vs. over-limit state by cell COLOUR alone, with no per-cell screen-reader
  label — the last documented accessibility gap on docs/ROADMAP.md
  (`accessibility_best_practices`, WCAG 1.4.1). Each day that carries data now
  exposes a `contentDescription` built from a new `year_calendar_day_desc` string
  ("date, grams, status"), where the status reuses the existing under/over-limit
  legend captions and the date/number are formatted in the per-app locale; empty
  days stay inert and silent so a reader is not flooded with hundreds of "no
  entry" nodes. `year_calendar_day_desc` is a locale-neutral skeleton
  (`%1$s, %2$s g, %3$s`) whose words come from already-localized sub-strings, but
  it is still added to all 21 languages to satisfy `LocaleSyncTest` key parity.
  No on-screen change. NOTE on the colour channel: the under/over palette is blue
  (`primary`) vs. red (`dangerRed`), not a red/green pair, so it is already
  colour-blind distinguishable; an additional non-colour VISUAL indicator is left
  as an optional, low-priority roadmap nicety rather than forced onto the 10 dp
  cells. (docs/ROADMAP.md updated to record the item as screen-reader-done.)
- Accessibility — calendar navigation buttons (sixth QA round): the icon-only
  previous/next arrows for the month view and the year view in `CalendarScreen`
  set `contentDescription = null`, so a screen reader announced only "button",
  with no way to tell previous from next or month from year (WCAG 4.1.2,
  name-role-value). Every other actionable icon in the app already carries a
  localized `contentDescription`; these four were the only exceptions. Added
  four accessibility strings (`cd_prev_month`, `cd_next_month`, `cd_prev_year`,
  `cd_next_year`), translated into all 21 languages, and wired them onto the
  four arrow `Icon`s. Screen-reader only; nothing changes on screen.
- Accessibility — drink-category icon (sixth QA round): `DrinkCategoryIcon`
  used the raw enum constant (`category.name`, e.g. "BEER") as its
  `contentDescription`, which a screen reader read out verbatim and unlocalized.
  Switched it to the localized `DrinkCategory.displayLabel()` already defined in
  the same file, so the icon is voiced in the app's own language. No new strings;
  screen-reader only.
- Statistics export — clock consistency (sixth QA round): the CSV/PDF export
  date-range dialogs fell back to a bare `LocalDate.now()` while the stats flow
  had not yet emitted its `today`, bypassing `DayResolver.clock()` (the
  screenshot clock override) and the configured day-change boundary that every
  other date-relative surface honors. The fallback now reads
  `LocalDate.now(DayResolver.clock())`. It is only a transient placeholder for
  the picker's initial date and is replaced the moment the flow emits, so there
  is no user-visible change; the fix removes an inconsistency with the app-wide
  "derive today from DayResolver" rule.
- Documentation — data-compatibility guarantee (sixth QA round): CONTRIBUTING.md
  §8 now records that, since the first F-Droid release (v0.77.4), the Room
  database and the JSON backup format are guaranteed backward-compatible — Room
  migrations are forward-only and never destructive, and the backup importer
  keeps reading every `BACKUP_VERSION` from that baseline onward. Matching
  breadcrumbs were added to `AppDatabase` and `BackupManager`. While there, a
  stale cross-reference in `AppDatabase` was corrected: the migration workflow
  is documented in CONTRIBUTING.md §8.1, not the §7.1 the comment pointed at.
  Documentation only; no functional change.
- Roadmap — accessibility status (sixth QA round): docs/ROADMAP.md now notes
  that the two accessible-name gaps above are closed, leaving the accessible
  year heatmap (WCAG 1.4.1, color-only day cells) as the remaining documented
  accessibility item. Documentation only.
- Store release notes (sixth QA round): the per-locale versionCode-90 store
  changelogs are deliberately left unchanged. This round's only user-visible
  effect is screen-reader accessible names (nothing changes on screen), which
  the existing "Fixes from a full code review" framing already covers; and the
  English master already sits at 464/500 characters, so adding a sentence would
  breach the store's 500-character limit across locales. versionCode is
  unchanged (these fixes fold into the unreleased v0.79.0).
- PDF report — CJK glyph orthography: the report template's root element now
  carries a per-locale language hint (`<html lang="{{REPORT_LANG}}">`, filled
  by `PdfReportBuilder` from the per-app locale via `Locale.toLanguageTag()`).
  The report is rendered by a WebView (Blink), whose CJK font fallback selects
  the glyph ORTHOGRAPHY — Simplified vs Traditional Han, Japanese kanji, Korean
  hanja — from the document language. Han-unified code points are shared across
  zh/ja/ko but prefer region-specific glyph shapes, so without a `lang` hint
  Blink defaulted to Simplified-Chinese forms: Japanese, Korean and
  Traditional-Chinese reports rendered Chinese-style glyphs for those shared
  characters. Verified in the fifth QA round with `pdffonts` on the committed
  sample reports, which embedded `NotoSansCJKSC` (Simplified) even for `ja`,
  `ko` and `zh-TW`. `PdfReportBuilder` already formats every number/date/label
  with the same per-app locale, so only the glyph orthography was off; the fix
  makes it deterministic on every device. User-visible for Japanese, Korean and
  Traditional-Chinese report exports; Latin locales are unaffected. A new
  `PdfReportLangTest` pins both the template invariant and the substitution
  behaviour (the placeholder⇄builder sync is already enforced by
  `PdfTemplatePlaceholderTest`). NOTE: the pre-rendered sample PDFs under
  `fastlane/report-pdf/` are regenerated on a device by the `ReportExportTest`
  flow and are refreshed on the next screenshot/report run; they are repository
  assets and are not shipped inside the APK.
- `AndroidManifest.xml`: corrected the "HOW TO ADD A NEW LANGUAGE" checklist
  header, which said "all three steps are required" while the checklist lists
  four steps (Step 3 applies to RTL languages only). Comment only; no
  functional change. (Fifth QA round.)
- Build hygiene: investigated the Gradle 9.6.1 deprecation warning "Using a
  Project object as a dependency notation" seen during `:app` configuration.
  A `--warning-mode all --stacktrace` run attributes it to upstream plugins,
  not this project's build scripts: one occurrence originates in Kover
  (`PrepareKover.kt`) and two in the Android Gradle Plugin itself
  (`VariantDependenciesBuilder` while wiring test components). No project build
  script uses the deprecated notation, so there is nothing to fix in-repo;
  recorded here so the warning is not re-investigated and is tracked for the
  eventual Gradle 10 upgrade (to be resolved by future Kover/AGP releases). No
  change. (Fifth QA round.)
- `.bestpractices.json`: reworded the four justifications that quoted a
  concrete release ("currently 0.78.0" in `OSPS-BR-02.01`/`OSPS-BR-02.02`/
  `version_unique`, "e.g. v0.78.0" in `version_tags`) to be release-agnostic
  — the versionName/versionCode statements now point at their defining
  location (`android/app/build.gradle.kts`) and the tag statement describes
  the `v<versionName>` scheme. The self-assessment can no longer go stale on
  version bumps; the substance of the answers is unchanged. (Found by the
  claims-vs-tree consistency scan of the QA delta review; the file said
  0.78.0 while the tree was 0.79.0.)
- QA delta review (three verified findings against v0.79.0, independently
  reported by a skill-guided review run and confirmed at the source):
  - `KeystoreSecretStore.openWithKey` now throws `GeneralSecurityException`
    (instead of `require`'s `IllegalArgumentException`) for a blob too short to
    contain an IV. `open()`'s public contract promises GSE for ANY malformed
    blob and `AppPreferences` catches exactly that family to translate
    decryption failures into a DataStore `CorruptionException` — so a truncated
    (partially written) preferences file used to BYPASS the
    `ReplaceFileCorruptionHandler` and crash the read instead of self-healing.
    The unit test that had pinned the wrong exception type was corrected and a
    boundary-case test (exactly IV-sized blob → authentication failure, not
    length failure) added; both executed on the JVM.
  - `YearCalendarView` builds its month-abbreviation formatter with the per-app
    `formattingLocale()`; the pattern previously carried no locale, so the year
    calendar's month labels followed the SYSTEM language on every API level —
    against the project's own "never Locale.getDefault() for user-visible
    text" rule.
  - `formatStatsDate` (Settings/Stats date range) uses the locale's LONG date
    style instead of the hardcoded `"d. MMMM yyyy"` pattern: passing a locale
    to a hardcoded pattern localizes only the month NAME, while field order and
    punctuation stayed German for every language ("28. June 2026" instead of
    "June 28, 2026"). Minor visible change for German users: none (LONG for de
    is "28. Juni 2026").
- Per-file licensing: added the project's standard GPL copyright-and-licence
  header to the remaining hand-authored source files that lacked it — eight XML
  files (the manifest, the two adaptive-icon mipmaps, the colour and theme
  resources, `data_extraction_rules.xml`, and `locale_config.xml`) and four
  configuration files (`libs.versions.toml`, `gradle-daemon-jvm.properties`,
  `.editorconfig`, and `version-anchor`). Every hand-authored source file now
  carries both a copyright statement and a licence statement (gold criteria
  `copyright_per_file` and `license_per_file`). No functional change.
- Contributor onboarding: added a "Good first issues" subsection to
  CONTRIBUTING.md that identifies small, self-contained tasks for new or casual
  contributors (native-speaker translation review, documentation, and test
  cases) and points to the tracker's `good first issue` label (gold criterion
  `small_tasks`).
- Security policy: docs/GOVERNANCE.md now documents that any account with write
  access to the canonical repository must have cryptographic two-factor
  authentication (a TOTP app or a hardware key, not SMS) enabled, since the forge
  offers no per-project 2FA enforcement (gold criteria `require_2FA` and
  `secure_2FA`).
- Code review: added a "Code review requirements" subsection to CONTRIBUTING.md
  documenting how review is conducted (single reviewer and merger; the reviewer
  runs the build, tests, and release gate locally), an explicit checklist of what
  is checked, and the acceptance criteria for merging (gold criterion
  `code_review_standards`).
- Security review: `docs/ASSURANCE_CASE.md` now records a dated security review
  (2026) that takes into account the security requirements (SECURITY.md,
  "Security model") and the security boundary (threat model and trust
  boundaries), combining the assurance-case analysis with an Android-focused QA
  pass over the security-relevant code (gold criterion `security_review`).
- Test coverage: integrated Kover and expanded the JVM unit-test suite to measure
  statement and branch coverage over the unit-testable code (the Compose UI, the
  Android-runtime-bound layers — database, preferences, Keystore, PDF/WebView, and
  the MediaStore import/export marked `@AndroidIoBound` — the app entry points,
  and generated code are excluded and covered by instrumented tests instead).
  Statement coverage now reaches ~97% and branch coverage ~80%. A build-breaking
  floor (`koverVerify`: LINE >= 90, BRANCH >= 75 over that scope) is wired into the
  release gate (`tools/release-check.sh --coverage`, `make cover-check`) so
  coverage cannot silently regress. This meets silver `test_statement_coverage80`,
  gold `test_statement_coverage90`, and passing `test_most`; the gold
  `test_branch_coverage80` criterion (and the `dynamic_analysis` it unlocks)
  remains a priority-2 roadmap goal, as the last branches sit in
  Android-/Compose-adjacent code.
- Supply-chain hardening: pinned the Gradle distribution by checksum
  (`distributionSha256Sum` in `gradle-wrapper.properties`) so Gradle verifies every
  download against a known-good hash, and documented the wrapper-regeneration step
  that refreshes the pin on a Gradle bump (CONTRIBUTING.md §7). This keeps the
  committed `gradle-wrapper.jar` a stock, verifiable wrapper (OSPS Baseline
  `OSPS-QA-05.02`). No functional change.
- Documented the commit-signing and fast-forward-only merge workflow now enforced
  by branch protection — signed commits required on every branch except `main`,
  `main` merged fast-forward-only — in CONTRIBUTING.md §2, and noted commit-signature
  verification (`git log --show-signature`) in SECURITY.md. Also corrected the DCO
  auto-sign-off tip: `format.signOff` affects `git format-patch`/`git send-email`,
  not `git commit`, so it does not sign off ordinary commits; use a `commit -s`
  alias or a `prepare-commit-msg` hook instead. Documentation only; no functional
  change.
- Added `.bestpractices.json` (repository root) as a version-controlled snapshot
  of the project's OpenSSF badge answers — the metal series (passing, silver, gold)
  and OSPS Baseline Levels 1 and 2 — together with a manual
  `make bestpractices-json` target that refreshes it from bestpractices.dev's own
  JSON export. This is a one-way site -> repo mirror: the badge automation does not
  ingest a `.bestpractices.json` from a Codeberg repository, and the URL-based
  proposal path is impractical because the server rejects the long URLs. No
  credentials are used. Metadata/tooling only; no functional change.
- SECURITY.md: added a "Security advisories" section documenting that confirmed,
  fixed vulnerabilities are published through predictable public channels — the
  CHANGELOG release notes and the corresponding Codeberg release — stating the
  affected version(s), how a user can determine whether they are affected, and the
  remediation. Satisfies OSPS Baseline Level 2 `OSPS-VM-04.01`. Documentation only;
  no functional change.
- SECURITY.md: reworded the link to the assurance case to use human-readable link
  text (matching the rest of the docs), resolving a `tools/md-syntax.py` warning.
- SECURITY.md: added a "Secrets and credentials" section defining the project's
  policy for its secrets (release signing keystore, Google Play upload credentials,
  and the maintainer's OpenPGP key) — how they are stored (never committed;
  git-ignored with structure-only templates; environment-variable injection),
  accessed (held solely by the maintainer on trusted machines), and rotated.
  Satisfies OSPS Baseline Level 3 `OSPS-BR-07.02`. Documentation only; no functional
  change.
- SECURITY.md: added a "Support" section stating the project's support model — a
  single-maintainer rolling release in which only the latest version is supported,
  the scope (best-effort bug fixes and security updates shipped in new releases, no
  back-porting) and duration of support, and when a version stops receiving security
  updates. Satisfies OSPS Baseline Level 3 `OSPS-DO-04.01` and `OSPS-DO-05.01`.
  Documentation only; no functional change.
- docs/GOVERNANCE.md: extended "Repository access and account security" with a
  policy that code collaborators are reviewed and approved before being granted
  escalated permissions to sensitive resources (write/merge access, release
  secrets), with least-privilege grants and identity vetting. Satisfies OSPS
  Baseline Level 3 `OSPS-GV-04.01`. Documentation only; no functional change.
- Release process: every published Codeberg release is accompanied by the build's
  CycloneDX SBOM as a release asset. `android/Makefile` `release`/`bundle` (which
  already build the SBOM alongside the artifact) now also print its path, and
  CONTRIBUTING.md §7 adds attaching it as a release-checklist step. Every released
  version is thus delivered with its software bill of materials, satisfying OSPS
  Baseline Level 3 `OSPS-QA-02.02`. No change to the build artifacts themselves.
- docs/ROADMAP.md: added a "Working toward OpenSSF Baseline Level 3" section
  recording the remaining Level 3 gaps — the structural walls shared with the gold
  tier and a future VEX feed for `OSPS-VM-04.02` — and marked Level 3 as in
  progress. Documentation only; no functional change.
- SECURITY.md ("Dependency monitoring"): documented that every dependency must be
  under a license compatible with the project's GPL-3.0-or-later distribution and
  that incompatible-license findings are remediated before release, defining the
  project's SCA remediation threshold for both vulnerabilities and licenses (OSPS
  Baseline Level 3 `OSPS-VM-05.01`). docs/ROADMAP.md: recorded the future
  CI-based automated, blocking policy gates (`OSPS-VM-05.03`, strengthening
  `OSPS-VM-06.02`). Documentation only; no functional change.
- Screenshots: pin the capture date in-app so `make screenshots` no longer
  depends on the device date. Every date-relative surface derives "today" from
  `DayResolver.today()`, which read the raw device clock; the `screenshots`
  target tried to pin that clock via `adb shell date`, but that only works on an
  emulator or a rooted userdebug build and silently no-ops on a locked
  production phone — so captures used the REAL date instead of the intended
  perspective (2026-06-30, the last day of the demo period). Fix: `DayResolver`
  gains a test-only `clockOverride` (null in production, so shipped behaviour is
  unchanged); a new androidTest helper `ScreenshotClock` pins it to 2026-06-30,
  and both capture tests (`ScreenshotTest`, `ReportExportTest`) set it in
  `@Before` and clear it in `@After`. The perspective is now correct on ANY
  device. The Makefile's device-date pin is demoted to best-effort cosmetics
  (its former "will use the real date" WARNING was made accurate — screenshots
  are unaffected), and a cheap `screenshots` preflight now enforces that the
  Makefile `SCREENSHOT_DATE` and `ScreenshotClock.SCREENSHOT_DATE` agree and
  that the pinned day is not before the fixture's last logged day (2026-06-29,
  so 2026-06-30 is a deliberately dry "today"), preventing the sources from
  drifting apart unnoticed. Test-tooling only; no change to the shipped APK.
  - Follow-up: the in-app pin initially covered only `DayResolver.today()`, but a
    few date-relative surfaces read the wall clock directly and so still showed
    the real date — most visibly the Calendar header/grid (seeded from
    `YearMonth.now()`), which displayed the real month while the day cells showed
    the pinned day, plus the PDF report's "export date" (`LocalDate.now()`).
    `DayResolver` now exposes the effective clock via `clock()` (the pinned test
    clock when set, else the real system clock), and these call sites read
    `YearMonth.now(DayResolver.clock())` / `LocalDate.now(DayResolver.clock())`.
    Production behaviour is unchanged (the clock is the real system clock when
    unpinned). The add-drink dialog's default time-of-day and a non-visible
    export-range fallback were deliberately left as-is (time-of-day, governed by
    Demo Mode; not the date perspective).
- Enforce the ktlint Kotlin-style gate tree-wide and wire it into the default
  build. `./gradlew ktlintFormat` reformatted the whole codebase to the pinned
  ktlint ruleset (long-whitespace, trailing commas, argument wrapping, newline and
  indentation rules). The non-auto-correctable findings were resolved WITHOUT
  churning idiomatic code, via `.editorconfig`: Jetpack Compose `@Composable`
  functions are exempted from the lowercase function-naming rule (PascalCase is the
  Compose convention), and `no-wildcard-imports` (Compose imports whole packages)
  and `backing-property-naming` (the ViewModels expose state through a combined
  `uiState`, so their private `_x` MutableStateFlows have no public `x`) are
  disabled; the intentional package-overview file `ui/screen/ViewModels.kt` is
  exempted from `no-empty-file`. Genuine code fixes: `app/build.gradle.kts` script
  imports made contiguous and comment-free so ktlint can order them; an inline
  value-parameter comment in `DrinkEntity` moved above the parameter; the singleton
  holder `AppDatabase.INSTANCE` renamed to `instance`. Finally `android/Makefile`'s
  `lint` target — on the default `debug` path via `test` — now runs
  `./gradlew ktlintCheck lintDebug`, so a style regression breaks the everyday
  build instead of surfacing only at release time. Style/build-tooling only; no
  functional change to the app.
- Update fastlane v2.236.1 to v2.237.0.
- QA: the PDF report's "longest abstinence" now includes the ongoing dry
  streak, exactly like the Statistics screen. The report called the legacy
  no-`today` overload of `DayResolver.computeLongestAbstinence`, which ignores
  the tail gap after the last drink — so a report could show a *current*
  abstinence larger than the *longest* one (impossible by definition) whenever
  the ongoing run was the user's best. `PdfReportDataTest` pins the tail
  inclusion and the `longest >= current` invariant with a pinned clock.
- QA: first-launch language detection now understands script subtags. Modern
  Android reports Chinese as `zh-Hant-TW` / `zh-Hans-CN`, which the full-tag /
  base-language matcher could not map to the shipped `zh-TW` / `zh-CN` — so
  Chinese users were silently forced to English, persistently (the detected
  tag overrides Android's own resource fallback). `LocaleDetector.detect` now
  matches language+region with the script dropped, disambiguates the remaining
  `zh` variants by script/region (`Hant`/TW/HK/MO → `zh-TW`, otherwise
  `zh-CN`), and folds the Norwegian macrolanguage alias `no` onto `nb`; seven
  new unit tests cover the added steps.
- QA: the Today screen now rolls over to the new logical day while it stays
  open. "Today" was computed once per settings emission, so with the app open
  across the configured day-change time (04:00 by default — late evenings are
  the point of that setting) every date-scoped query stayed pinned to the
  previous day and a drink logged after the boundary was invisible. The
  minute ticker now re-derives the day *outside* the `flatMapLatest` (behind
  `distinctUntilChanged`, so DB queries restart only at the boundary), and the
  Statistics period bounds and the Calendar's today marker follow the same
  pattern. A new `TodayViewModelTest` drives a pinned mutable clock across the
  boundary on virtual time to pin the rollover.
- QA: totals that are exactly AT a limit no longer count as exceeded. Gram
  amounts are stored on a 0.1 g grid, but day/window totals are binary-double
  sums (the 7-day window even incrementally maintained), so an
  exactly-at-limit total could drift to e.g. 100.000000000000014 and a strict
  `>` flagged an exceedance the user cannot see — against the app's "displayed
  number == compared number" principle. The new
  `AlcoholCalculator.isOverLimit` (epsilon 1e-6, three orders below the data
  grid) is now the single definition of "over the limit", used by the
  violation counters, the report's over-limit months / binge days / peak-KPI
  warnings / chart bars, and the on-screen limit bar, calendar and chart
  markers. A regression test replays a provably drifting sequence.
- QA: month+year labels (Calendar header, the PDF's monthly table and chart)
  are now built from the CLDR skeletons `yMMMM`/`yMMM` via the new
  `monthYearFormatter` (l10n/LocaleSupport.kt) instead of a literal
  `"MMMM yyyy"` — which showed the wrong field order for Chinese, Japanese
  and Korean ("6月 2026" instead of "2026年6月") and the wrong grammatical
  form for the inflected languages (genitive "czerwca 2026" instead of the
  standalone "czerwiec 2026"). The year view's bare month abbreviations
  switched from `MMM` to the standalone `LLL` for the same reason. Asserted
  on-device by three new `LocaleFormattingInstrumentedTest` cases.
- QA: Swedish compact day+month labels (Today's week range, chart ticks) now
  render day-first ("28/6") as Swedish convention demands. Deriving the label
  from the SHORT date pattern kept sv's ISO-like year-first order, yielding
  "6-28" — and the test suite even pinned that wrong order as expected. The
  derivation now aligns the day/month order with the locale's MEDIUM pattern
  (quoted-literal-safe); a new property test asserts that alignment for every
  shipped locale, so future locales cannot re-enter through the same gap.
- QA: backup import now validates referential integrity at parse time
  (`BackupManager` Guard 5): every entry must reference a drink contained in
  the backup. Previously a dangling `drinkId` (hand-edited or truncated file)
  reached the repository, where the REPLACE path's remap fallback kept the raw
  id — silently attaching the entry to the wrong drink when the number
  happened to match a local preset, or aborting the whole transaction with
  only a generic error otherwise. The repository's fallback is replaced by a
  strict lookup that names the dangling id; two new parser tests cover the
  reject and accept paths.
- QA: store-locale directories renamed to Google Play's store-listing codes.
  The `deploy` lane pushes `fastlane/metadata/android/` to Play, which accepts
  only its fixed language list — 14 of the 21 directories carried bare codes
  Play rejects (`cs`→`cs-CZ`, `da`→`da-DK`, `el`→`el-GR`, `es`→`es-ES`,
  `fr`→`fr-FR`, `it`→`it-IT`, `ja`→`ja-JP`, `ko`→`ko-KR`, `nb`→`no-NO`,
  `nl`→`nl-NL`, `pl`→`pl-PL`, `pt`→`pt-PT`, `ru`→`ru-RU`, `sv`→`sv-SE`);
  F-Droid reads region-qualified codes fine, so nothing is lost there. The
  per-locale sample report PDFs and `screenshots.html` were renamed/retargeted
  along, `render-feature-graphic.py` now keys its CJK font fallback by
  language/region instead of the literal directory name, the capture suites
  resolve their resources via the detected APP language rather than the raw
  store code — `no-NO` vs `nb` is the one pair Android's resource matcher
  does not bridge, which made the screenshot run wait for an English label
  the Norwegian UI never shows and the Norwegian sample report silently
  render in English — and `release-check.sh` §4 gained Check D: every metadata directory must be a
  valid Play code AND map 1:1 (full tag first, then language subtag, `no`→`nb`)
  onto `SupportedLocales.ALL`. The app's resource qualifiers and the
  `docs/guide` templates keep their own — platform-fixed — naming; the
  "add a new language" checklists now document all three ecosystems.
- QA: hygiene — the stale build-script comment claiming the Kover verify
  thresholds are "deliberately NOT enabled yet" (they are enabled and gate
  releases) rewritten; `setDayChangeTime` clamps hour/minute like every other
  preferences setter (belt-and-suspenders, per the class contract); the
  committed `fastlane/report.xml` run artifact removed and gitignored; the
  "170 string keys" counts in two localization checklists made count-free
  (`LocaleSyncTest` owns the number — it is 169 today).
- Rewrote the versionCode-90 user release notes in all 21 store languages:
  they now describe this release's user-visible QA fixes alongside the
  OpenSSF process work (the previous note predated the QA round and claimed
  "no functional changes").
- Build tooling: the store-image pipeline now auto-generates and cascades.
  Missing device screenshots (01..06) are captured automatically the first
  time a feature graphic needs one — a single guarded `make screenshots`
  run (device required), triggered ONLY by genuine absence, never by mere
  staleness (which stays manual, as before). The eight shots are split by
  producer: `make screenshots` now captures only the in-app shots 01..06 and
  then refreshes the feature graphics; `make report-pdfs` owns the report
  pages 07..08 (it now rasterizes them from the freshly exported PDFs) and
  likewise refreshes the graphics — so renewing either half always renews the
  graphics that depend on it. A new `make store-assets` target rebuilds the
  whole set in one go, and a once-per-run stamp guarantees the feature
  graphics render exactly once even when both producers run together (it also
  removes the former double build in `make release`). `validate-screenshots.py`
  gained `--in-app`/`--report` modes so each producer validates only its own
  half. screengrab's own `clear_previous_screenshots` is disabled and replaced
  by a targeted delete of exactly 01..06 in the `screenshots` recipe: screengrab
  globs and deletes ALL `*.png` in each `phoneScreenshots/` directory, so with
  the report pages no longer regenerated by `make screenshots` it would have
  wiped the committed 07/08 without rebuilding them — the recipe now clears only
  the six in-app shots it recaptures and never touches the report pages.
- Deleted `docs/PLAY_STORE.md`.

---

## v0.78.0

Complete L10N for F-Droid; overhaul build tools

Google Play onboarding, an F-Droid badge in the feature graphic, a relocation of
the build tooling, and a handful of user-facing fixes. Beyond those the release
makes no user-facing behavioural change; the rest is documentation, store
assets, build/release tooling and internal QA hardening (see "Licensing, QA
review & hardening" and "Second QA pass" below).

User-facing:
- CSV/PDF export: when the chosen date range contains no entries, show a short,
  self-dismissing Toast ("No entries available.") instead of doing nothing
  visible. Previously this was only a faint inline notice inside the scrollable
  statistics list, so it was easily missed. A successful export is still
  signalled only by the share sheet (CSV) or the system print dialog (PDF).
- In-app language on Android 11–12L (API 30–32): CSV column headers, the whole
  PDF report (labels, date and number formats) and import/export status
  messages now follow the language selected IN THE APP. They previously fell
  back to the SYSTEM language on those API levels, because AppCompat's per-app
  locale back-port localizes only Activity contexts, not the Application
  context the exporters were handed (fixed via `perAppLocalizedContext()`, see
  the second QA pass below). Android 13+ was never affected.
- Locale-correct compact date labels: the Today screen's weekly range and the
  PDF report chart's x-axis ticks now use the LOCALE's day/month order and
  separator ("6/28" for en-US/ja/zh, "6. 28." for ko, "6-28" for sv) instead of
  the hard-coded European "d.M." for every language. For unaffected locales the
  only visible change is the dropped trailing dot ("28.6–4.7" instead of
  "28.6.–4.7.").
- CSV/JSON export reports FAILURE when the file cannot be written: if MediaStore
  hands back no output stream, the app previously claimed success while leaving
  an EMPTY file in Downloads — a silent data-loss trap for a health backup. The
  orphaned file is now removed and the error message shown.
- Statistics chart: the current day no longer shows a green "abstinent" tick
  before it is over. The tick promises a completed, alcohol-free period, but an
  in-progress day is in superposition — it may still become a drink day until the
  configured day-change time. The chart now leaves the current day/period as an
  empty slot until it resolves: a drink is logged (a bar appears) or the period
  closes dry (the tick appears). The rule is enforced in the single shared series
  builder (`ChartBucketing.bucketize`), so the on-screen chart and the PDF report
  cannot drift apart; the PDF, whose range ends at the last recorded day, was not
  visibly affected but now shares the same guarantee. WEEK/MONTH (daily bars) and
  YEAR (monthly bars) are all covered.
- French localization polish (cosmetic, fr only): the bottom-navigation
  "Statistics" tab used the full screen title "Statistiques", which wrapped onto
  two lines in the narrow tab. It now uses a dedicated short tab label ("Stats");
  the screen title and the Settings section header keep the full "Statistiques".
  A new `nav_statistics` string backs the tab in every locale (most repeat their
  full word; only French shortens it). Also, the Statistics row label "Moyenne
  par jour de consommation" was long enough to squeeze its value into a vertical,
  character-by-character stack; it is shortened to "Moy. par jour de conso.",
  matching the wording the PDF report already uses. Regenerated screenshots and
  feature graphics.
- Statistics rows are now hardened against that value-stacking regardless of
  language: the label takes the flexible width (and wraps if long) while the
  value is pinned to a single line. Previously a translation long enough to fill
  the row could squeeze any statistic's value into a vertical, per-character
  stack; this is now structurally impossible in every locale, whatever the label
  length. The French shortening above is the cosmetic nicety on top of this
  general safety net.

New documentation:
- `PRIVACY.md`: the privacy policy required by the Play "App content" section,
  linked from `README.md`. It states the app's actual behaviour — no data
  collection, no network access, on-device storage protected at rest by device
  encryption and the sandbox, and an optional biometric lock handled by Android —
  using the corrected data-at-rest wording (no database-level-encryption
  over-claim; the JSON backup is described plainly).
- `docs/PLAY_STORE.md`: a repeatable runbook for publishing to Google Play
  alongside F-Droid with a single signing identity (own app signing key via PEPK;
  a separate upload key), package-name registration, Play App Signing enrolment,
  the App-content declarations, the closed-testing gate, and versionCode
  discipline.

Store descriptions (all locales):
- Reflow every `full_description.txt` so each paragraph and list item is a single
  line, letting F-Droid and Google Play wrap the text themselves. This fixes the
  mid-sentence hard breaks that F-Droid rendered from the source's fixed-width
  (~80-column) wrapping. List markers are now the Unicode bullet "•", which
  displays as a real bullet on both stores; the previous Markdown `*` showed
  literally on Google Play, which renders no Markdown. Blank lines between
  sections are preserved. Line joining is CJK-aware — Chinese/Japanese fragments
  are rejoined without a space, space-using scripts (including Korean) with one —
  so no spurious spaces are introduced into CJK text. Wording is unchanged; every
  locale stays within the 4000-character store limit.

Feature graphic (`tools/render-feature-graphic.py`):
- Embed the per-locale "Get it on F-Droid" badge (`fdroid/get-it-on-de.svg` and
  `fdroid/get-it-on-en.svg`, both new in this release) in the bottom-LEFT corner
  and the GPLv3 logo in the bottom-RIGHT, with mirrored 48 px margins, a shared
  baseline and a shared visible height. The bottom-right logo is drawn after the
  report "paper" so it sits in front of the tilted PDF screenshot.
- Factored SVG parsing into `_svg_box_and_inner`; added a colour-preserving
  `_badge_nested` (F-Droid brand colours are kept, unlike the recoloured logo)
  and `_svg_ink_bbox`. The badge canvas carries a ~43 px transparent margin, so
  the badge is cropped to its ink box before scaling — otherwise its visible
  height would not match the logo. The shared mark size is kept reduced
  (`logo_w` 96).
- Also render a 4x high-resolution companion (`featureGraphic-4K.png`,
  4096x2000) next to each 1024x500 store graphic, for press/web/print; fastlane
  supply does not upload it, and the `README.md` header embeds this high-res
  version. (Named `featureGraphic-4K.png`; an earlier draft in this cycle called
  it `featureGraphic-hq.png` — the renderer, the `README.md` embed and the two
  committed companion PNGs were renamed to match.)

Feature-graphic localisation:
- Add per-locale marketing copy
  (`fastlane/metadata/android/<locale>/feature-graphic.txt`) for all 19 further
  store locales (cs, da, el, es, fr, it, ja, ko, nb, nl, pl, pt, pt-BR, ro, ru,
  sv, uk, zh-CN, zh-TW), so the deterministic renderer now produces a localized
  feature graphic for every one of the 21 store locales.
- CJK support: bundle Noto Sans CJK Regular (OFL 1.1) under
  `tools/fonts/NotoSansCJK/` — Inter has no CJK/Hangul glyphs — and make the
  renderer CJK-aware. `_char_width` now gives Han/kana/Hangul/fullwidth code
  points a full-em advance, `_wrap` allows a line break between CJK characters
  (they carry no spaces, so a CJK tagline was previously one unbreakable,
  oversized line), and `_build_svg` appends the region-appropriate Noto family
  (SC/TC/JP/KR) after Inter in the text `font-family` for `ja`/`ko`/`zh-CN`/
  `zh-TW`. The CJK glyphs in those locales' F-Droid badges resolve via
  fontconfig's per-glyph fallback to the same bundled font. Latin/Greek/Cyrillic
  locales are unaffected (font-family stays `Inter`).
- Quality pass on the supplied copy: fixed a German phrase that had leaked into
  the Dutch tagline ("ohne kompromissen" → "zonder compromissen"); shortened two
  bullets that overflowed the fixed 150 px label column (nl "app-vergrendeling"
  → "app-slot"; ro reworded to a clean three-line form); and normalized the
  privacy bullet to a spaced "100 %" across the Latin locales, matching
  de-DE/en-US (CJK locales keep their locale-conventional spacing).
- Data-security bullet height fix (el, fr, pl, ru, uk): the feature boxes all
  share one height (the tallest bullet's line count), and in these five wordier
  languages the privacy bullet wrapped to FIVE lines, pushing the four-box stack
  to ~530 px — taller than the 500 px canvas, so it was clipped top and bottom.
  Trimmed each to four lines while keeping the concrete features ("app lock",
  "offline") intact: pl moves the "&" onto the offline line so the app-lock fits
  one line (no word dropped); fr drops the redundant "uniquement"; el/ru/uk drop
  the "100 %" emphasis (already echoed by their "full control" tagline). The
  four-line stack is ~442 px and sits within the canvas (verified against the
  renderer's own wrap and stack-height math).
- Follow-up harmonization: el/ru/uk had dropped the "100 %" prefix above (their
  app-lock term is inherently two lines, so "100 %" was the cheapest line to
  cut). Restored it uniformly by shortening the privacy word so "100 %" fits one
  line again while keeping the full app-lock term: el uses the noun "απόρρητο"
  (confidentiality); ru/uk use "приватно". All 21 privacy bullets now carry
  "100 %" and still render at four lines. NOTE: for ru/uk this shifts a noun to
  an adverb ("приватно" = "privately"), which is fine in marketing register but
  worth a native review; el stays a noun.
- ja/ko feature-graphic polish: the width-based CJK wrap split words mid-run and
  left tiny orphan tails on their own line (ja "プライバシー" → "…プライバシ"+"ー：",
  "レポート" → "…レポ"+"ート"; ko lone "：", "보고서" → "…보고"+"서"). Added explicit
  line breaks at word boundaries in the ja/ko copy (no renderer change) so each
  line ends on a natural boundary and "100 %" sits on its own line, matching the
  Latin locales. NOTE: the exact break points are a native-review detail.
- Each new file carries the same English format-header comment as de-DE/en-US
  (ignored by the renderer) so editors see the title/tagline/bullet contract.
- Add the localized "Get it on F-Droid" badges (`fdroid/get-it-on-<lang>.svg`)
  for every store language, and generalize `_badge_for_locale`: it now selects
  the badge whose tag matches the locale (region kept and lower-cased, e.g.
  `pt-BR` → `pt-br`), then falls back to the bare language and finally to the
  English badge, so locales without their own badge (nb, uk) still render one.
  de-DE/en-US keep resolving to the de/en badge, so the two already-published
  graphics are unchanged. `COPYING.md` now attributes the whole localized badge
  set (same F-Droid artwork source, CC BY-SA 3.0). The CJK badges (ja, ko,
  zh-CN, zh-TW) render correctly via the bundled Noto Sans CJK font (see the
  CJK note above).

Badge fonts (build tooling; not shipped in the app package):
- Bundle the two fonts the badge text needs under `tools/fonts/`: DejaVu Sans
  (DejaVu Fonts license) for "GET IT ON" and Rokkitt (SIL Open Font License 1.1)
  for the "F-Droid" wordmark; both are documented in `COPYING.md`. The static
  Rokkitt Bold is instanced from the checked-in upstream variable font via the
  new `make rokkitt-bold`; the variable source lives outside the pinned font dir
  (`tools/fonts-src/`) so it never competes with the static instance during the
  deterministic render.

Release-check tooling (`tools/release-check.sh`):
- Section 9 (markdown syntax) now also validates `PRIVACY.md`.
- Section 9 no longer swallows its own findings: the checker was invoked as a
  bare `output=$(md-syntax.py …)` assignment, and under the script's `set -e` a
  non-zero exit from that substitution aborted the whole run AT that line —
  before the captured `path:line: message` problems could be printed — so a
  markdown error surfaced only as a bare "Error 1" naming no file. The call is
  now `if`-guarded (a tested context, where `set -e` does not abort), so every
  offending FILE and LINE is printed; an unexpected crash of `md-syntax.py` also
  surfaces its stderr instead of failing silently.
- Section 1 (version consistency) no longer verifies the F-Droid reference
  recipe: the recipe cross-check and its path variable are removed, and the
  recipe (`fdroid/de.godisch.potillus.yml`) is kept only as a static,
  non-maintained backup (a banner in the file states this).

Screenshot pipeline (all store locales):
- `make screenshots` now captures every store locale, not just de-DE/en-US.
  `SCREENSHOT_LOCALES` (Makefile) and the screengrab `locales` (Screengrabfile)
  are both DERIVED from the metadata tree — every
  `fastlane/metadata/android/<locale>/` has a `changelogs/` sub-dir, so globbing
  those yields exactly the locale set and skips the non-locale `screenshots.html`.
  The two derivations match, so capture, cropping, validation and the feature
  graphic always cover the same set, and adding a locale directory extends the
  pipeline automatically. The screenshot instrumentation test already applies
  whatever locale screengrab passes, so no test change was needed.
- `screenshots-pdf` renders report pages 07/08 for every locale from a report PDF
  named EXACTLY for that store locale,
  `fastlane/report-pdf/potillus_report_<locale>.pdf` (`de-DE` uses
  `potillus_report_de-DE.pdf`, `zh-CN` uses `potillus_report_zh-CN.pdf`). There is
  deliberately NO base-language or English fallback: a `fr` graphic must use the
  `fr` report, and `zh-CN`/`zh-TW` (or `pt`/`pt-BR`) must not collapse onto a
  shared PDF -- so a missing per-locale PDF is a hard `make` error (run
  `make report-pdfs`, which exports each PDF under that exact name). The two
  committed reports were renamed from `potillus_report_de.pdf` /
  `potillus_report_en.pdf` to `potillus_report_de-DE.pdf` /
  `potillus_report_en-US.pdf` to match.
- The report pages and feature graphics are proper make FILE targets wired into
  a dependency graph, so `make screenshots-pdf` and `make feature-graphics`
  regenerate only the locales whose inputs actually changed. Each
  `featureGraphic.png` depends on its `feature-graphic.txt`, its `01_today.png`
  capture and its `07_report_page_1.png`; that report page in turn depends on the
  source report PDF, so dropping a newer PDF re-rasterizes the locale's report
  page AND re-renders its feature graphic on the next `make` -- with no separate
  `screenshots-pdf` step. A missing device screenshot now fails with an
  actionable message rather than make's terse "No rule to make target".
- The source report PDFs moved from `fastlane/` into `fastlane/report-pdf/` (the
  `REPORT_PDF_DIR` variable); `make report-pdfs` pulls exports straight there.
- Every feature graphic now tracks the WHOLE `tools/fonts/` tree, not only Inter
  and NotoSansCJK: the badges draw live text in DejaVuSans ("GET IT ON") and
  Rokkitt ("F-Droid"), so those font files are genuine inputs too. Changing any
  bundled font -- or generating the Rokkitt bold via `make rokkitt-bold` --
  rebuilds the affected graphics, closing a stale-asset gap in the earlier deps.
- `featureGraphic-4K.png`, the high-resolution companion the README embeds, is now
  a first-class output: it shares one grouped-target rule with `featureGraphic.png`
  (GNU Make 4.3+), so a single renderer call produces both and `make` tracks both.

Build dependencies -- localized user guides (android/):
- The generated guides (`res/raw*/usersguide.md`) are no longer rebuilt by a
  blanket phony `guides` target on every build. `render-guide.py --make-deps`
  emits, from its single language discovery, one
  `output: template strings.xml render-guide.py` rule per language into `guides.d`,
  which `android/Makefile` auto-regenerates and `-include`s. `prereq` now depends
  on the real `$(GUIDE_OUTPUTS)`, so `make` regenerates a guide only when its own
  template or `strings.xml` changed -- specific per-target prerequisites instead of
  one global catch-all. The shared recipe `touch`es its output because
  `render-guide.py` writes content-based and the file would otherwise look
  perpetually stale; `distclean` also removes `guides.d`.

Report export (semi-automatic, human-in-the-loop):
- New `make report-pdfs` drives the app's PDF report export once per locale so
  producing the 21 source PDFs no longer means 21 fully manual exports. For each
  locale an instrumented test (`ReportExportTest`) opens the system "Save as PDF"
  dialog and then BLOCKS until the app is foreground again; the operator taps
  Save (nothing else) and the run advances. Afterwards the saved files are pulled
  into `fastlane/report-pdf/`, where `screenshots-pdf` already resolves them.
- Why semi-automatic: the production export deliberately routes through the
  platform print dialog (see util/WebViewPdfPrinter), and both fully-silent export
  (needs a non-public print-framework API) and automating the localized dialog
  itself are fragile. So the automation only triggers the export and waits for the
  app to return to the foreground — it never has to read a localized button.
- The dialog's file name is pre-filled as `potillus_report_<locale>.pdf`: the test
  calls the print path directly with that job name. This lives ENTIRELY in the
  androidTest source set; production keeps its timestamped name (unchanged).
- `ReportExportTest` is inert in every other run: an Assume guard skips it unless
  invoked with `-e reportExport true`, so `make test` and `make screenshots` never
  open a dialog. It seeds the same `demo-backup.json` fixture and localizes the
  report via a Context configured for the requested `testLocale`, so the output
  matches the committed de/en reports.
- NOTE: this instrumented test + Makefile target could not be compiled or run in
  the authoring environment (no Android SDK/Gradle/device); it is written against
  the existing ScreenshotTest/screengrab patterns and is to be validated on-device.
- Install step hardened after a first on-device run: the APKs are now installed
  with `adb install -t` (the instrumentation APK is testOnly and is rejected
  without it), any previously installed copy is uninstalled first so a signature
  or downgrade mismatch cannot block the install, and adb's own failure message
  is printed instead of the bare, reason-less "Error 1" seen after "Performing
  Streamed Install". The unused `-g` (no dangerous runtime permissions) was
  dropped.

Root `Makefile` convenience targets and readability:
- Redesigned the everyday entry points into two convenience targets and made
  `debug` the default goal (`.DEFAULT_GOAL`). `make debug` runs the maximal LOCAL
  verification and then the debug APK: through `android/` it drives the
  `release-check` gate (via `prereq`), Android `lint`, the JVM `unit-test`s, the
  on-device instrumentation tests (`test-device`) and the `check-guides` doc-sync
  check, then refreshes any feature graphics already on disk. It is incremental (no
  `clean`) and needs a connected device, since the instrumentation tests do; it
  fails if any code or documentation check requires a correction. The former
  bespoke `default` target (clean + debug + test + copy-to-USB) is gone.
- `make release` refreshes the store assets and then builds the signed artifact:
  `screenshots` (recaptures every locale and rasterizes the report pages from the
  PDFs you exported), `feature-graphics` (rebuilds each locale's graphic whose
  inputs changed), and finally the `android` `release` target (signed release APK
  plus its CycloneDX SBOM). You still supply the per-locale report PDFs yourself.
- New `feature-graphics-existing` target refreshes ONLY the feature graphics that
  already exist on disk (a `$(wildcard)` over the metadata tree). `debug` uses it so
  a screenshot-less working copy never trips the `01_today.png` guard for the many
  locales whose device screenshots are not committed; `release` keeps using the full
  `feature-graphics`, since it captures screenshots for every locale first.
- Removed duplication: the per-tool preflight checks are now single `require-device`,
  `require-pdftoppm`, `require-rsvg`, `require-pillow` and `require-fonttools` helper
  macros (called with the target name as the message prefix), replacing the roughly
  six inline copies. The two report-page rules were folded into one parametrized
  canned recipe (`report_page_rule`; page 1 renders `07_report_page_1.png`, page 2
  renders `08_report_page_2.png`) and the feature-graphic rule into
  `feature_graphic_rule`, both instantiated per locale by `potillus_pipeline_rules`.
  Behaviour is unchanged, verified against the `make -p` database.
- Reorganized the file into labelled sections (configuration, convenience/install,
  screenshots, the report-page/feature-graphic pipeline, PDF export, fonts,
  packaging/deploy, housekeeping) with a targets-at-a-glance index at the top; the
  configuration variables are consolidated together and `screenshots-demo-off` now
  sits beside `screenshots`.

User's guide (all 21 locales):
- Document the app-visibility/lock features and the monthly-average badge. A new
  `### {{security}}` section (rendered from the `security` string) describes the
  `{{biometric_lock}}` and `{{allow_screenshots}}` toggles — the latter is off by
  default (`FLAG_SECURE`), so the window stays out of screenshots and the recent-
  apps overview. It is placed before `### {{appearance}}`, matching the Settings
  screen order (backup → security → appearance).
- The `### {{appearance}}` section is trimmed to what it still covers (color
  theme + language); its former biometric-lock sentence now lives under Security.
- The "{{today}}" screen gains a sentence for the new "Ø" badge (average grams of
  pure alcohol per day for the current month).
- Applied to the English source template and translated into all 20 other
  guide templates (`android/docs/guide/usersguide.<lang>.md.in`). UI labels stay
  as `{{token}}` references so they track `strings.xml`; only the connective
  prose is translated. All required string keys already exist in every locale, so
  `render-guide.py` regenerates all 21 guides cleanly (verified).

Build tooling relocation:
- Move the build/packaging tooling from `android/tools/` to a repo-root `tools/`
  directory (a sibling of `android/`, `fastlane/`, `fdroid/`, `docs/`), since
  these scripts serve the build/release process rather than the app. Re-anchor
  `release-check.sh` (it now cd's to the sibling `android/`),
  `render-feature-graphic.py` and `render-guide.py`, and update the invocations
  in `android/Makefile` and `app/build.gradle.kts` to `../tools/...`. Historical
  CHANGELOG entries are intentionally left referring to `android/tools/`.
- Move the `screenshots` and `feature-graphics` targets (with their screenshot
  helper targets and variables) from `android/Makefile` to the root `Makefile`,
  since they orchestrate repo-wide assets rather than the app build; the Gradle
  build stays in android/ via a new `screenshot-apks` target invoked with
  `$(MAKE) -C android`. `crop-screenshots.py` and `validate-screenshots.py` are
  made cwd-independent (`__file__`-anchored) so they run from the repository root.

Release packaging (`Makefile`):
- Exclude `keystore.properties` and `play-store-credentials.json` from the
  release tarball, and drop the `distclean` dependency of the `tgz` target.
- Derive the `tar` exclude list for the `tgz` target DYNAMICALLY from
  `.gitignore` instead of hard-coding a parallel copy, so the tarball can no
  longer ship files the repository ignores. `.gitignore` patterns are mapped to
  `tar` faithfully: comments/blank lines are dropped; a negation (`!`) aborts the
  build (tar cannot express an un-exclude); root-anchored patterns (those with a
  `/`) get the repo dir prepended and are matched `--anchored`, the rest
  `--no-anchored`; and `--no-wildcards-match-slash` keeps `*` inside one path
  segment (so `/*.pdf` excludes only root PDFs). `.git` is excluded explicitly
  since git does not list it.

Fastlane (`fastlane/Fastfile`):
- The `deploy` lane now defaults to the `internal` track instead of `production`;
  reaching production requires passing `track:production` explicitly. Removed a
  stale reference to a no-longer-existing `PLACEHOLDERS.txt`.

Licensing, QA review & hardening:
- `COPYING.md`: added a "Third-Party Software (bundled in the release APK)"
  section that records the copyright holders and licenses of the runtime
  libraries actually shipped in the APK — the Apache-2.0 AndroidX / Jetpack /
  Compose / Room / DataStore / biometric / tracing stack and the Kotlin +
  kotlinx runtime, plus `desugar_jdk_libs` under GPL-2.0-with-Classpath-Exception
  — and points to the CycloneDX SBOM as the authoritative machine-readable
  inventory. Build- and test-time-only dependencies are listed separately as
  non-redistributed. Previously only the build-time font/badge/logo assets were
  documented; the APK-embedded dependencies were covered by the SBOM alone.
  Documentation only — no code, resource or build change, so nothing user-facing
  or functional is affected.
- `WebViewPdfPrinter`: closed a latent Activity leak in the PDF-export path. The
  off-screen `WebView` was already created from the application context, but the
  `WebViewClient.onPageFinished` closure captured the Activity context strongly to
  reach the `PrintManager`; while the `WebView` was parked in the static `retained`
  field awaiting its page-finished callback, that chain pinned the whole Activity,
  and if the callback never fired (e.g. a load failure) the Activity leaked until
  the next export. The Activity context is now held through a `WeakReference` (the
  print dialog is Activity-scoped UI, so a collected Activity simply means there is
  nothing to print), and `retained` is released on every callback path. No change
  to the successful-export flow (the system print dialog still opens exactly as
  before); the fix only affects the error/never-fires path. The class KDoc and the
  `StaticFieldLeak` suppression rationale were updated to match.
- Backup MERGE: documented that merging also brings over the backup's drink
  catalogue — a custom drink whose name is not present locally is inserted even
  when it has no entries — and that this is intentional and idempotent (a later
  merge re-matches the drink by name). Clarifies the previously entries-only
  wording of the MERGE contract in `BackupManager`, `IBackupRepository` and
  `BackupRepository.buildIdMap`. Documentation only — the import behaviour is
  unchanged; REPLACE likewise restores the full catalogue.
- `DrinkDao.insert`: changed the conflict strategy from `REPLACE` to `ABORT`,
  mirroring `EntryDao.insert`, and corrected the KDoc. Every caller inserts with
  `id = 0` (new-drink add, backup remap, preset pre-population), so Room always
  auto-generates the primary key and no collision can occur — `ABORT` is thus
  behaviourally identical here while making any future explicit-id collision fail
  loudly instead of silently overwriting a row. The previous rationale ("re-insert
  presets without failing on the unique constraint") was inaccurate: the `drinks`
  table has no `UNIQUE` constraint on `name`, and backup de-duplication is done by
  name in `BackupRepository`. No schema/migration impact (the conflict strategy
  affects the generated INSERT statement, not the table definition).

Second QA pass (full-scope re-audit of v0.78.0; folded into this release):
- Per-app locale plumbing: new `Context.perAppLocalizedContext()`
  (`l10n/LocaleSupport.kt`) derives a context carrying the locale list stored
  via `AppCompatDelegate.getApplicationLocales()`. Used per call by the
  `StringProvider`s in `AppViewModelFactory`, by `SettingsViewModel`'s plural
  resolution, and by `StatsViewModel` before handing the context to
  `CsvExporter`/`PdfReportBuilder` — fixing the API 30–32 system-language
  fallback described under "User-facing". The `LocaleSupport.kt` documentation,
  which incorrectly claimed the Application context carries the per-app locale,
  was corrected. The transformation itself lives in an `internal`
  `localizedContextFor(locales)` behind the one-line public facade, and two
  instrumented regression tests (`LocaleFormattingInstrumentedTest`) cover its
  no-op (empty list) and locale-carrying paths with EXPLICIT locale lists —
  deliberately not arranged through `AppCompatDelegate.setApplicationLocales`,
  which on API 33+ reaches the framework `LocaleManager` only via ACTIVE
  AppCompatDelegate instances (verified in the AndroidX source) and is
  therefore a silent no-op in an activity-less instrumented test; an earlier
  test iteration failed on-device for exactly that reason. Production is
  unaffected by that gate: on API 33+ the framework already localizes every
  context, so the facade's empty-read fallback is already correct there.
- New `l10n/DatePatterns.kt` (`shortDayMonthPattern(locale)`): derives the
  compact day+month pattern from the locale's SHORT date pattern via pure
  java.time (JVM-testable, unlike `DateFormat.getBestDateTimePattern`);
  verified against all 21 shipped locales in the new `DatePatternsTest`. Used
  by `TodayViewModel` (weekly range label) and `PdfReportBuilder` (chart tick
  labels).
- `TodayViewModel.addEntry`/`updateEntry` read the settings snapshot from
  `prefs.settingsFlow.first()` instead of `uiState.value.settings`: before the
  first combine emission the hot StateFlow still holds the `AppSettings()`
  DEFAULTS (04:00 day change), so an entry added through that window could be
  filed under the wrong logical date. Matches `CalendarViewModel.addEntry`; the
  comment that argued the opposite was corrected.
- `WebViewPdfPrinter`: the off-screen WebView is now destroyed deterministically
  when the print job ends, via a delegating `PrintDocumentAdapter`
  (`DestroyOnFinishAdapter`) whose `onFinish()` — fired once per job, after
  printing/saving AND after cancellation — releases the native resources.
  Previously the WebView was merely dereferenced and lingered until GC.
- `AppDatabase.PrepopulateCallback` launches on an explicit `Dispatchers.IO`,
  honouring the documented `applicationScope` convention that every launch site
  states its dispatcher (it silently fell back to `Dispatchers.Default`).
- `StatsUiState` default `period` unified to `MONTH`, matching the ViewModel's
  actual initial state; the `stateIn` seed is now plain `StatsUiState()`. This
  also makes `StatsViewModelTest.awaitComputed()`'s documented seed-detection
  assumption (`state == StatsUiState()`) actually hold.
- Compose list hygiene: all `LazyColumn`/`LazyRow` `items()` over entries and
  drinks now pass the stable Room id as `key` (Today, Calendar ×2, Drinks,
  favourites quick-bar), so deletions/reorderings move keyed rows instead of
  rebinding every following position.
- Removed all guarded `!!` not-null assertions from UI code (drink editor save,
  export date-range confirm, import mode dialog) in favour of elvis-return /
  `?.let` guards — crash-free even if the guarding `enabled` conditions are
  ever refactored.
- Dead API removed: `AlcoholCalculator.soberByMillis` (never wired into any
  screen; its four unit tests removed with it) and the repository-level
  `getById` lookups (`IEntryRepository`/`IDrinkRepository`, implementations,
  fakes, `EntryDao.getById`). `DrinkDao.getById` is kept — its sole consumer is
  a white-box assertion in `BackupRepositoryInstrumentedTest` — with a KDoc
  note saying so. `LimitBar` now calls `AlcoholCalculator.limitPercent` instead
  of duplicating the fill-fraction division inline with a subtly different
  zero-limit guard; the domain function is the single source of truth.
- Licensing (COPYING.md): the Apache-2.0 runtime inventory now also names the
  copyright holders pulled in transitively — Square, Inc. (`okio`, via
  DataStore), The Guava Authors (`listenablefuture`, via concurrent-futures),
  The JSpecify Authors (`jspecify`) and `org.jetbrains:annotations` — and a new
  "Third-Party Assets" paragraph records the Roboto (Apache-2.0) and Noto Sans
  CJK (OFL-1.1) subsets embedded in the committed `fastlane/report-pdf/*.pdf`
  samples (verified with pdffonts).
- Licensing (Apache-2.0 §4(a)): the verbatim licence text is checked in as
  `LICENSE.Apache-2.0.md` and bundled into the in-app copyright document —
  `res/raw/copyright.md` is now the three-file concatenation COPYING.md +
  LICENSE.md + LICENSE.Apache-2.0.md (android/Makefile rule, `check-guides`
  comparison and the `generateCopyrightDocument` Gradle task updated in
  lock-step). The `packaging { excludes }` block gained a licence-compliance
  note explaining that the excluded META-INF/AL2.0 + LGPL2.1 entries are
  duplicated notice FILES from the kotlinx-coroutines artifacts, not code, and
  where the licence text is delivered instead.
- Licensing (Apache-2.0 §4(d)): `tools/release-check.sh` gained SECTION 12,
  "THIRD-PARTY NOTICE FILES" — an SBOM-gated scan that resolves every shipped
  component to its Gradle-cache artifact and WARNs on any `META-INF/NOTICE*`
  entry, automating the confirmation step COPYING.md previously prescribed as a
  manual release-process note. Without the SBOM or cache the check reports
  itself as skipped and passes, so the routine debug gate cannot false-fail.
- App Bundle language splits disabled (`bundle { language { enableSplit =
  false } }`): the in-app language switcher requires every locale's resources
  on the device, which Play's default per-language AAB splits would strip — a
  LATENT mismatch that existed ever since the switcher shipped. It surfaced as
  the lint error `AppBundleLocaleChanges` once `perAppLocalizedContext()`
  introduced a `Configuration.setLocales` call the detector recognises
  (`AppCompatDelegate` alone never triggered it); with `warningsAsErrors` that
  failed `lintDebug`/`make debug`. F-Droid APKs are unsplit and unaffected;
  the AAB now carries all 21 locales' string resources (negligible size).
- PDF report footer: the English licence/warranty line is documented as
  DELIBERATELY not localized (legal boilerplate is quoted, not paraphrased).
- Known upstream issue (documented, not fixable in-repo): the Gradle 9.6
  configuration-phase deprecation "Using a Project object as a dependency
  notation" originates in AGP 9.2's internal test-variant wiring — this build
  declares no `project(...)` dependency — and will disappear with a future AGP
  update; tracked at the `allWarningsAsErrors` note in `build.gradle.kts`.

Third QA pass (delta re-audit of v0.78.0; folded into this release):
- CSV export: `CsvExporter.escapeField` now forces RFC 4180 quoting on a field
  that embeds a lone carriage return, not only a line feed. RFC 4180 §2 mandates
  quoting for CR *or* LF; the previous guard tested only `\n`, so an old-Mac
  line ending (a bare `\r` with no accompanying `\n`) in the middle of a note
  could split the record. A leading `\r` was already neutralised as a
  formula-injection trigger; this closes the mid-field case. New unit cases in
  `CsvExporterTest` (`carriageReturn_forcesQuoting`) cover both positions.
- `TodayViewModel`: documentation only. Clarified that its Context-free
  `Locale.forLanguageTag(settings.language)` derivation and the Context-based
  `Context.formattingLocale()` used elsewhere are two views of the SAME per-app
  locale (the language tag and `AppCompatDelegate`'s application locales are
  always written together), so a future reader does not "reconcile" them by
  injecting a Context into this deliberately Context-free, JVM-testable
  ViewModel. A matching cross-reference was added to `LocaleSupport.kt`'s
  "HOW TO USE" note. No behavioural change.
- In-app document viewer (`MarkdownText`): render a Markdown thematic break
  (`---`, `***`, `___`) as a `HorizontalDivider` instead of the literal marker
  characters. The in-app licenses screen concatenates COPYING.md, the GPL text
  and the Apache-2.0 text separated by `---` (see `tools/render-copyright.py`),
  which previously showed as "---" between the sections. Detection is via the
  new `THEMATIC_BREAK_RE`, unit-tested in `MarkdownTextTest`.
- In-app document viewer: decode the `&mdash;` (—) and `&sect;` (§) HTML
  entities, which COPYING.md uses (e.g. "&sect;4(a)") and which previously
  rendered verbatim. Added to the existing `HTML_ENTITIES` table with matching
  `MarkdownTextTest` cases.
- `LICENSE.Apache-2.0.md`: dropped the leading `<!-- … -->` modeline/preamble
  header so the file is now the pure, verbatim upstream Apache-2.0 text. That
  header was concatenated into the in-app copyright document and rendered as a
  literal HTML comment after the second `---` seam. The licence body is
  unchanged (still byte-identical to the upstream original), so the &sect;4(a)
  "copy of the licence" obligation is still satisfied — more cleanly than before.
- Licensing (COPYING.md): the Apache-2.0 &sect;4(d) paragraph now points at the
  automated `release-check.sh` Section 12 NOTICE scan instead of describing the
  confirmation as a manual "the release process should confirm" step, which had
  become stale once that gate was added earlier in this release. Documentation
  only; the transitive runtime inventory was re-verified complete against the
  resolved `releaseRuntimeClasspath` (no missing copyright holder).


- `versionCode` 88 → 89 and `versionName` 0.77.4 → 0.78.0 in `build.gradle.kts`
  and the `README.md` title; localized store notes in `changelogs/89.txt` for all
  21 listing locales now describe the export fix above (all 21 locales are now
  localized; the previously English-only locales were translated).
  The F-Droid recipe is intentionally NOT updated — it is a static backup.

OpenSSF Best Practices (bestpractices.dev) passing- and silver-badge groundwork
(documentation only; no code or user-facing behaviour change):
- README: new "Feedback & Contributing" and "Security" sections. The former
  documents how to obtain the app, report bugs/enhancements (the Codeberg
  issue tracker, or android@godisch.de), and contribute (CONTRIBUTING.md);
  the latter points to the new SECURITY.md.
- CONTRIBUTING.md: new "Submitting changes" section describing the
  contribution process (open an issue first, submit a Codeberg pull request
  or an e-mailed patch, meet the acceptance requirements, pass maintainer
  review); later sections were renumbered and a stale table-of-contents
  anchor was fixed. Accuracy pass to match the code: the architecture map
  now lists the `l10n/` and `data/security/` packages; the `BINGE_THRESHOLD`
  example was corrected from `48.0` g to `60.0` g; the testing-strategy table
  was replaced with the real unit/instrumented test layout; and the
  translation workflow was rewritten around `l10n/SupportedLocales.kt` as the
  single source of truth, noting that only English and German are
  hand-authored while all other locales are machine-generated (native-speaker
  corrections welcome).
- SECURITY.md: new security policy publishing the private
  vulnerability-reporting process — PGP-encrypted e-mail to android@godisch.de,
  the maintainer's key fetched from the official Debian keyserver
  (keyring.debian.org), and a 14-day acknowledgement commitment.
- CONTRIBUTING.md: adopted the Developer Certificate of Origin (DCO) for
  contributions (silver criterion `dco`). Section 2 now requires every commit to
  be signed off (`git commit -s`, adding a `Signed-off-by` line) and links to
  developercertificate.org, clarifying that sign-off is a plain-text DCO
  agreement, not a cryptographic signature. It also notes the
  `git config format.signOff true` convenience setting.
- `docs/GOVERNANCE.md`: new document defining the project's governance model (silver
  criterion `governance`). It states the single-maintainer (benevolent-dictator)
  model, how decisions are made (open discussion on Codeberg, maintainer
  decides and is sole merger), and the key project roles; it is linked from
  CONTRIBUTING.md.
- `CODE_OF_CONDUCT.md`: adopted the Contributor Covenant v2.1 (silver criterion
  `code_of_conduct`), reproduced verbatim under CC BY 4.0 with the enforcement
  contact set to android@godisch.de; linked from CONTRIBUTING.md and recorded in
  COPYING.md's third-party inventory.
- `docs/ROADMAP.md`: new documented roadmap (silver criterion `documentation_roadmap`)
  describing the project's intended directions for roughly the next year and its
  explicit non-goals; the specific items are listed in the file. It also serves
  as the project's task list, tracking the open near-term items ordered by
  criticality. Linked from the README.
- SECURITY.md: added a "Security model" section documenting the software's
  security requirements (silver criterion `documentation_security`) — what users
  can expect (no network/data transmission, least privilege, on-device encrypted
  storage, optional biometric lock, no tracking) and cannot expect (no defence
  on a compromised device, biometric lock is only an access gate, exported files
  leave the app's control, BAC figures are informational).
- README: added a "Quick start" section (silver criterion
  `documentation_quick_start`) — a short numbered guide for new users to install
  the app and log their first drink, see their status, and optionally set limits
  or export data.
- Build: adopted ktlint for automatic Kotlin style enforcement (silver criterion
  `coding_standards_enforced`) via the org.jlleitschuh.gradle.ktlint plugin
  (14.2.0), a repository-root .editorconfig selecting the official Kotlin
  conventions, and a CONTRIBUTING.md §4 note. ktlintCheck runs under `check`
  and is build-time only (not on the release-assembly path), so the APK and
  reproducible builds are unaffected.
- SECURITY.md / CONTRIBUTING.md: documented a periodic dependency
  vulnerability-monitoring process (silver criterion `dependency_monitoring`) —
  external dependencies are scanned with osv-scanner against the CycloneDX SBOM
  before each release, with a matching item added to the §7 release checklist.
- CONTRIBUTING.md: added a formal, mandatory test policy to §5 (silver criterion
  `test_policy_mandated`) — as major new functionality is added, automated tests
  covering it MUST be added in the same change, or it will not be merged.
- CONTRIBUTING.md: made the add-tests policy explicit in the change-proposal
  instructions in §2 (silver criterion `tests_documented_added`), stating that
  major new functionality MUST include automated tests in the same change.
- SECURITY.md: added a "Verifying releases" section (silver criterion
  `signed_releases`) documenting that releases are signed with the maintainer's
  own reproducible-build signing key (private key never on distribution sites)
  and how users can verify a release — automatically via the F-Droid client, by
  comparing the APK signing certificate SHA-256 fingerprint with the published
  value, or by reproducing the build.
- CONTRIBUTING.md / SECURITY.md: adopted GPG-signed release tags (silver
  criterion `version_tags_signed`) — the §7 release checklist now creates a
  signed annotated tag (`git tag -s`) with the maintainer's key, and "Verifying
  releases" documents verification via `git tag -v`. It also notes the
  `git config tag.gpgSign true` convenience setting.
- `docs/ASSURANCE_CASE.md`: new security assurance case (silver criterion
  `assurance_case`) — states the threat model, identifies the trust boundaries,
  argues that secure design principles were applied, and maps common
  implementation weakness classes to the countermeasures in the app; linked from
  SECURITY.md.
- Build: the in-app copyright document (`res/raw/copyright.md`) now separates its
  three concatenated parts (COPYING.md, the GPL text, and the Apache-2.0 text)
  with Markdown horizontal rules, and normalizes the spacing between them, for
  clearer rendering in the in-app licenses view. The concatenation moved into a
  single shared generator, `tools/render-copyright.py`, which both the Makefile
  rule (and its `check-guides` verification) and the Gradle
  `generateCopyrightDocument` task now call, so the two build paths can no longer
  disagree about the generated bytes. Generated output only; no licensing content
  changes.
- README: added the OpenSSF Best Practices badge (project 13480) under the title
  (silver criterion `documentation_achievements`), so the project's badge status
  is shown on the repository front page and updates automatically as the level
  changes.

---

## v0.77.4

Drop in-APK SBOM for reproducible builds

Reproducible builds:
- The release APK no longer embeds the CycloneDX SBOM under `assets/sbom/`.
  F-Droid's from-source rebuild of 0.77.3 verified the signature but failed the
  byte-for-byte reproducibility comparison, and the *only* differences were in
  the packaged SBOM. Its CycloneDX metadata captures the build environment and
  therefore differs between the developer's machine and F-Droid's CI:
  `metadata.timestamp` (dropped locally when `SOURCE_DATE_EPOCH` is unset, but
  pinned to it in CI), an auto-injected `build-system` entry carrying the GitLab
  CI job URL, and the VCS URL recorded as `ssh://…` locally vs `https://…` in
  CI. None of these can be reconciled across environments, so the robust fix is
  to stop shipping the SBOM *inside* the APK.
- `build.gradle.kts`: removed section 5 (`GenerateSbomAsset` and its
  `androidComponents` asset wiring) together with the imports it alone used
  (`java.io.File`, `javax.inject.Inject`, `ExecOperations`). Section 4
  (`cyclonedxDirectBom`) is unchanged, so `make sbom` / `make release` still
  produce the standalone `build/outputs/sbom/libellus-potionis-sbom.json`, which
  can be published as a separate release asset alongside the APK.
- The in-APK SBOM was never read at runtime and is not checked by
  `release-check.sh`, so nothing else depends on it; the APK is otherwise
  byte-identical to 0.77.3.

Release-check tooling (`tools/release-check.sh`):
- New §11 (REPRODUCIBLE-BUILD HYGIENE) fails the release if `build.gradle.kts`
  reintroduces an in-APK SBOM task (`GenerateSbomAsset`), so this regression
  cannot silently return. Sections renumbered from "/ 10" to "/ 11".

F-Droid recipe:
- `AutoName: Libellus Potionis` added to the reference recipe so it stays in
  sync with the fdroiddata copy (where `fdroid checkupdates` populates it) and
  no longer disappears from the recipe diff.

Versioning:
- `versionCode` 87 → 88 and `versionName` 0.77.3 → 0.77.4 across
  `build.gradle.kts`, `README.md` and the F-Droid recipe; localized store notes
  added as `changelogs/88.txt` for all 21 locales. No user-facing or functional
  change — this is a build-reproducibility fix.

---

## v0.77.3

Refine translations and data-security wording

Localization QA:
- A localization quality-assurance pass reviewed the in-app UI strings and
  several user-guide translations for terminology, grammar and typography:
  - `res/values/strings.xml` (base/English): added a structured translator and
    reviewer context block plus a per-entry `<!-- … -->` note for every string —
    where it appears in the UI, what each `%1$s`/`{name}` placeholder means, and
    the typographic-quote convention. These comments are documentation-only and
    do not affect the build. Stray German-style quote escapes in a couple of
    English strings were normalized to standard curly quotes.
  - In-app UI strings across the base locale and all 21 translations
    (`res/values*/strings.xml`): terminology, grammar and quote-consistency
    fixes (e.g. aligning the PDF-report field labels).
  - 12 localized user-guide templates (cs, da, es, fr, it, nb, nl, pl, pt,
    pt-BR, ru, sv): wording and grammar refinements.
  - The Romanian store summary was shortened to 77 characters to meet the
    80-character store limit: "Jurnal de alcool axat pe confidențialitate:
    limite, alcoolemie, rapoarte PDF."
  - Build fix: the Ukrainian `import_merge` value ("Об'єднати") introduced by
    the pass had its apostrophe escaped (`\'`) so the Android resource compiler
    (aapt2) accepts the string.

Documentation accuracy (data-at-rest wording):
- After the earlier removal of SQLCipher, the Room database is no longer
  encrypted at the application level — it is protected at rest only by Android's
  file-based storage encryption and the per-app sandbox. A few texts still
  carried the old "everything is encrypted" claim and were corrected so the
  project no longer overstates its guarantees:
  - `README.md`: the "Privacy & Security Architecture" section no longer says
    security is enforced "through fully encrypted data storage via hardware-backed
    cryptography". It now states that data rests in the app's private, sandboxed
    storage, protected at rest by Android's device storage encryption, with an
    optional biometric fingerprint lock.
  - In-app User's Guide (`docs/guide/usersguide.md.in` and all 21 localized
    `usersguide.<locale>.md.in` templates): the clause "All data is stored in
    encrypted form" was replaced by an accurate wording ("your data stays in the
    app's private storage on your device, protected by your device's
    encryption"), translated per locale.
  - Fastlane full descriptions (all 21 locales): dropped the now-superfluous
    half-sentence stating the preferences are "additionally sealed with a
    hardware-backed Android Keystore key", leaving the accurate device-encryption
    + sandbox statement.
- No source-code comments needed changes: `AppPreferences.kt` still correctly
  documents the app-encrypted preferences DataStore (AES-256-GCM, Keystore-backed
  — unchanged and accurate), and `AppDatabase.kt` only references the *legacy*
  SQLCipher artefacts that `purgeLegacyEncryptedDatabase()` deletes.

Release-check tooling (`tools/release-check.sh`):
- §1 (VERSION CONSISTENCY) no longer cross-checks a version comment in
  `proguard-rules.pro`. That header line merely duplicated `versionName` for no
  functional benefit — R8 ignores `#` comments — yet had to be re-synced on
  every release. The `# Version:` line was removed from `proguard-rules.pro`,
  and the corresponding check (together with the file's pre-flight existence
  entry and the doc references) was dropped from the script, removing one manual
  sync point per release. The README title version stays enforced because it is
  user-facing.
- §2 (CHANGELOG ENTRY) now also verifies the entry's first line — reused verbatim
  as the git commit subject — is ≤ 50 characters (git's subject-length
  convention).
- New §10 (STORE METADATA LENGTH LIMITS) checks every locale's
  `short_description.txt` (≤ 80), `full_description.txt` (≤ 4000) and
  `changelogs/*.txt` (≤ 500), counted in CHARACTERS (not bytes) so Greek,
  Cyrillic and CJK are measured the way the stores do. Existing sections were
  renumbered from "/ 9" to "/ 10".

F-Droid reproducible build:
- The reference recipe (`fdroid/de.godisch.potillus.yml`) now declares `Binaries`
  (the Codeberg release-asset URL, `de.godisch.potillus_%c.apk`) and
  `AllowedAPKSigningKeys`, enabling F-Droid to verify its own from-source build
  against the developer-signed APK published on Codeberg. The published release
  asset must be named for its versionCode (`de.godisch.potillus_87.apk`).

Versioning:
- `versionCode` 86 → 87 and `versionName` 0.77.2 → 0.77.3 across
  `build.gradle.kts`, `README.md` and the F-Droid recipe;
  localized store notes added as `changelogs/87.txt` for all 21 locales (the
  listing-only locales drop the previous `86.txt`). Documentation and metadata
  only — the APK is functionally identical to 0.77.2.

---

## v0.77.2

Fix SBOM normalizer path in release build

Bug fix:
- The `generateSbomAsset` task resolved its `sbom-normalize.py` helper with
  `layout.projectDirectory.file("tools/sbom-normalize.py")`.
  `layout.projectDirectory` is the `:app` module directory (`android/app/`), so
  this pointed at a non-existent `android/app/tools/sbom-normalize.py`; the
  script actually lives at the Gradle root, `android/tools/sbom-normalize.py`.
  The path now resolves via `rootProject.file("tools/sbom-normalize.py")`,
  matching the idiom already used elsewhere in this file. The full release
  build, including SBOM generation, R8 and resource shrinking, now completes.

Versioning:
- `versionCode` 85 → 86 and `versionName` 0.77.1 → 0.77.2 across
  `build.gradle.kts`, `proguard-rules.pro`, `README.md` and the F-Droid recipe
  (`commit: v0.77.2`); localized store notes added as `changelogs/86.txt` for
  all 21 locales (the listing-only locales drop the previous `85.txt`). No
  functional change to the app.

---

## v0.77.1

Fix F-Droid release build signing config

Bug fix:
- The `release` build type looked up its signing config with
  `signingConfigs.getByName("release")`. Before building, F-Droid strips the
  whole `signingConfigs { … }` block out of `build.gradle.kts` (it signs APKs
  itself), after which the named config no longer exists and `getByName` aborts
  the build with "SigningConfig with name 'release' not found". As a result the
  F-Droid build of 0.77.0 failed at `assembleRelease`. The lookup now uses the
  nullable `findByName("release")` with a null-safe check, so when the block has
  been removed the release build simply stays unsigned and F-Droid signs it.
  Local behaviour is unchanged: with a keystore the build is signed, without one
  it stays unsigned, exactly as before.

Versioning:
- `versionCode` 84 → 85 and `versionName` 0.77.0 → 0.77.1 across
  `build.gradle.kts`, `proguard-rules.pro`, `README.md` and the F-Droid recipe
  (`commit: v0.77.1`); localized store notes added as `changelogs/85.txt` for
  all 21 locales (the listing-only locales drop the previous `84.txt`). No
  functional change to the app; this is the first version that builds on F-Droid.

---

## v0.77.0

Rework feature-graphic copy; drop fdroid README

Store assets:
- Reworked the feature-graphic bullet copy in both locales. The privacy bullet
  now spells out the concrete guarantees instead of a generic label — en-US
  "100 % Privacy: App Lock & Offline-only", de-DE "100 % Privacy: App-Sperre,
  kein Netzwerk" — the limits bullet is title-cased on en-US ("Set & Maintain
  Limits"), and the final bullet now also advertises "Open Source". Both
  `featureGraphic.png` were regenerated from the updated copy.
- `README.md` now shows the en-US feature graphic at the top.

Build wiring:
- `Makefile`: `make screenshots` now also runs `make feature-graphics`, so the
  store graphics are regenerated together with the screenshots instead of as a
  separate manual step.

F-Droid:
- Removed the maintainer reference-copy comment header from
  `fdroid/de.godisch.potillus.yml` (it is plain metadata now) and deleted
  `fdroid/README.md`; the recipe no longer references it, and `release-check.sh`
  still keeps the reference copy's version in sync with `build.gradle.kts`.

Versioning:
- `versionCode` 83 → 84 and `versionName` 0.76.0 → 0.77.0 across
  `build.gradle.kts`, `proguard-rules.pro`, `README.md` and the F-Droid recipe;
  localized store notes added as `changelogs/84.txt` for all 21 locales (the
  listing-only locales drop the previous `83.txt`). Store-asset/tooling change
  only — the APK is functionally identical to 0.76.0.

---

## v0.76.0

Add a deterministic feature-graphic generator

Replace the two AI-generated Play-Store feature graphics with a deterministic,
re-localizable generator. This is a store-listing change only: the APK is
functionally identical to v0.75.0, and the versionCode is bumped purely so the
refreshed listing ships under its own code (same approach as v0.74.0).

Feature-graphic generator:
- New `android/tools/render-feature-graphic.py` composes the 1024x500 graphic
  (the exact Google Play feature-graphic size; the previous AI images were
  1488x720) from inputs the project already controls, so the result is
  reproducible and trivially re-localizable: per-locale marketing copy, the REAL
  screenshots from `make screenshots` (`01_today` as the phone, `07_report_page_1`
  as the report page) and the app's launcher icon. It emits SVG and renders with
  `rsvg-convert`; the phone is built and perspective-warped with Pillow (turned
  slightly about its vertical axis, left edge receding) and given a perspective
  depth edge on its near side, since SVG's affine transforms cannot do perspective. The old
  images baked in AI-hallucinated text (e.g. a garbled report page); the embedded
  shots are now the genuine, localized captures.
- Determinism: text is rendered with a PINNED bundled font (see below), selected
  via a throwaway fontconfig that exposes only `android/tools/fonts/`, so output
  never depends on the fonts installed on the build host. Repeated renders are
  byte-identical.
- Runtime dependencies are deliberately small: the python3 standard library,
  `rsvg-convert` (Debian `librsvg2-bin`), Pillow (already a project prerequisite)
  and the bundled fonts. Marketing copy
  lives in `fastlane/metadata/android/<locale>/feature-graphic.txt`; tagline line
  breaks are computed by the tool, so editors change words, not layout.

Bundled font:
- `android/tools/fonts/Inter/` adds static Inter instances (Regular/SemiBold/Bold,
  SIL OFL 1.1) used ONLY by the generator. They are build tooling and are NOT
  shipped in the APK. Credited in `COPYING.md`.

GPLv3 logo:
- `fastlane/gpl-v3-logo.svg` adds the GPLv3 "Free as in Freedom" logo, embedded
  (recoloured white) as a small license badge in the bottom-left of the graphic. It
  is one of the
  official GNU license logos by José Obed and is in the public domain; sourced from
  <https://www.gnu.org/graphics/license-logos> and credited in `COPYING.md`.

Copy / design tweaks (both locales unless noted):
- de-DE now addresses the reader informally ("Dein …" rather than "Ihr …").
- "100 %" is written with a space (was "100%").
- The "limits" bullet icon is a bar chart beneath a DOWNWARD trend arrow (the goal
  of keeping limits is to bring consumption down).
- The free/ad-free bullet leads with "free" (de "Kostenlos & Werbefrei",
  en "Free & Ad-free").

Build wiring:
- `android/Makefile`: new `feature-graphics` target renders the graphic for the
  screenshot locales, with an `rsvg-convert` pre-flight check mirroring the
  pdftoppm / Pillow checks; added to `.PHONY` and `make help`. It reuses the
  captures from `make screenshots` and does not capture anything itself.

Versioning:
- `versionCode` 82 → 83 and `versionName` 0.75.0 → 0.76.0 across
  `build.gradle.kts`, `proguard-rules.pro`, `README.md` and the F-Droid recipe;
  localized store notes added as `changelogs/83.txt` for all 21 locales.

Also in this release (unrelated tooling fixes):
- `android/tools/validate-screenshots.py` still pointed at the pre-move metadata
  path (`fastlane/metadata/android`), so `make screenshots` failed its final
  Google Play validation step even though capture, crop and PDF rendering had all
  succeeded. It now uses `../fastlane/metadata/android`, matching
  `crop-screenshots.py`.
- `ScreenshotTest` read screengrab's locale from the `testlocale` instrumentation
  argument, but screengrab passes it as `testLocale` (camelCase). Argument keys
  are case-sensitive, so the lookup returned null and every locale run fell back
  to the device language — both stores' captures came out identical (the device
  language). It now reads `testLocale` (with a lowercase fallback), so each
  locale renders in its own language again. Test-only; not in the release APK.
- Follow-up to the above: on API 33+ the per-app locale
  (`AppCompatDelegate.setApplicationLocales`) is applied ASYNCHRONOUSLY, so seeding
  it before launching the Activity left the first captured frame in the device
  language and the English run timed out. The locale is now applied AFTER each
  Activity launch, with the Activity foregrounded (mirroring the in-app language
  picker, the one path that switches reliably on the capture device). Test-only.

---

## v0.75.0

Disable embedded Google dependency blob, ship SBOM inside the APK

Privacy / transparency:
- `android/app/build.gradle.kts` (`android { dependenciesInfo { } }`): disabled
  the dependency-metadata block that the Android Gradle Plugin embeds by default
  into the APK signing block (`includeInApk = false`) and the App Bundle
  (`includeInBundle = false`). That block is encrypted with a Google public key
  and readable only by Google Play; for an offline, network-free FOSS app it
  serves no purpose and is opaque to users. Dropping it also removes one
  non-transparent artefact from the output, which is friendlier to
  reproducible-build verification.

Reproducible builds / SBOM packaging:
- `android/app/build.gradle.kts` (new section 5: `GenerateSbomAsset` +
  `androidComponents`): the CycloneDX SBOM is now packaged INSIDE the release APK
  under `assets/sbom/libellus-potionis-sbom.json`, so the bill of materials ships
  with the artefact it describes. The standalone copy under `build/outputs/sbom/`
  (used by `make sbom`) is unchanged.
- The packaged copy is kept reproducible: the raw CycloneDX output carries a
  wall-clock `metadata.timestamp`, so a generated-assets task normalises it with
  the same `tools/sbom-normalize.py` used by `make sbom` (`SOURCE_DATE_EPOCH`-aware;
  strips the timestamp otherwise) BEFORE the asset merge. The task is wired via
  `addGeneratedSourceDirectory`, so it runs as part of `mergeReleaseAssets` with no
  manual task dependencies. `python3` is already a build prerequisite (see the
  `Makefile`), so no new toolchain requirement is introduced.

Store screenshots (`make screenshots`):
- Fixed four defects in the automated Play-Store screenshot capture
  (`android/app/src/androidTest/kotlin/de/godisch/potillus/screenshot/ScreenshotTest.kt`)
  plus two build-tooling diagnostics (`android/Makefile`). All app-facing fixes are
  test-only; no production code changed.
- `03_statistics` showed a single bar (the capture day) instead of the whole
  month: `AppSettings.statsFromDate` falls back to the APK install date when unset
  (`AppPreferences.installDate`); screengrab reinstalls the app per locale, so that
  default is the capture day, and `StatsViewModel` clamps the period start to it —
  collapsing the chart and the period totals to one day. The Calendar (which does
  not clamp) still showed the full month, which is why the two screens disagreed.
  `setUp()` now clears the floor (`setStatsFromDate("")`) so the statistics period
  spans the full demo history again.
- `04_drinks` was intermittently empty (blank in one locale run, populated in the
  other — the signature of a race). `DrinksViewModel.uiState` starts from an empty
  `DrinksUiState()` that is filled by a Room `Flow` via `stateIn(...)`; the bare
  `composeRule.waitForIdle()` returns before that first database emission arrives.
  A new `waitUntilDrinksLoaded()` gate waits until the empty-state label
  (`R.string.no_drinks`) has disappeared before capturing.
- The `en-US` screenshots rendered in German: the app drives its UI language via
  its own per-app locale (`AppCompatDelegate.setApplicationLocales`), so relying on
  screengrab's `LocaleTestRule` system-locale switch had no effect on the rendered
  language and both locale runs came out in the device language. `setUp()` now
  resolves the requested `testlocale` to a supported language tag (reusing the
  production `LocaleDetector.detect` against `SupportedLocales.TAGS`) and sets BOTH
  the `language` preference and the live per-app locale to it. This is the last
  setup step, so it reliably wins over the asynchronous first-launch language
  detection in `PotillusApp.applyLanguageOnFirstLaunch`.
- Duplicate preset drinks appeared on the Drinks screen: the preset prepopulation
  runs asynchronously (`AppDatabase.PrepopulateCallback` launches it on the
  application scope when the database is first created), and the screenshot run's
  first database access is the import itself, so seeding and import raced and both
  inserted the presets. `setUp()` now awaits the presets (by collecting the drinks
  `Flow` until they are present) before `importReplace`, so the import's name-based
  deduplication matches and reuses them. (This race is effectively unreachable
  through the normal UI, where an import happens seconds after first launch.)
- `android/Makefile` (`screenshots`): the device date pin (`adb shell date`)
  silently no-ops on non-rooted physical devices, leaving the date-relative screens
  (Today / Calendar / Statistics) on the real device date instead of
  `SCREENSHOT_DATE`. The recipe now reads the device date back and prints a
  non-fatal WARNING when it differs from `SCREENSHOT_DATE`, so the condition is no
  longer silent; run on an emulator or rooted device to pin the date.
- `android/Makefile` (`screenshots`): added a fast-failing pre-flight check for the
  bundled fastlane. The fastlane tree moved to the repository root, so a vendored
  bundle installed under the old `android/fastlane/.vendor` no longer applies; the
  capture step then failed late (after a full build and after toggling Demo Mode)
  with the cryptic `bundler: command not found: fastlane` (Error 127). The recipe
  now runs `bundle check` in `../fastlane` up front and, if the bundle is missing,
  aborts immediately with an actionable message (`cd fastlane && bundle install`),
  mirroring the existing Pillow / pdftoppm pre-flight checks.

Version:
- Bumped to `0.75.0` / versionCode `82` across `build.gradle.kts`,
  `proguard-rules.pro`, the `README.md` title and the F-Droid recipe
  (`fdroid/de.godisch.potillus.yml`: `Builds` seed entry and
  `CurrentVersion`/`CurrentVersionCode`); added the per-locale fastlane `82.txt`
  store-changelog notes.

---

## v0.74.0

Prepare F-Droid packaging, localize store listing

This is a packaging, tooling and store-metadata release. It contains **no
changes to the app's runtime behaviour**: no source file under `src/main/kotlin`
was touched, the database schema is unchanged, and the set of shipped UI string
resources is identical to v0.73.4. The version is bumped purely so the new store
listings ship under their own `versionCode`.

Packaging (F-Droid):
- `fdroid/de.godisch.potillus.yml`: the reference build recipe lagged the source
  tree (it still pinned `versionName 0.73.0` / `versionCode 76`). Its single
  `Builds:` block and the `CurrentVersion` / `CurrentVersionCode` fields are now
  synced to the current release (`0.74.0` / `81`, `commit: v0.74.0`). A new
  release-check invariant (see Tooling) keeps them in lock-step from now on, so
  this class of drift cannot silently reappear.
- `fdroid/README.md`: added a step-by-step **fdroiddata submission checklist**
  (fork, copy recipe, local `fdroid lint` / `fdroid build -l`, open the merge
  request, address CI) and recorded the project decision that the FIRST
  F-Droid-published version will be cut as `1.0.0`. The reference recipe
  deliberately tracks the latest real release until that `1.0.0` tag exists.

Changed (build configuration):
- `android/settings.gradle.kts`: removed the `foojay-resolver-convention`
  plugin. It can fetch a JDK over the network when a Java toolchain is requested
  that is not installed locally — undesirable in F-Droid's network-restricted
  build. The project declares no `toolchain {}` / `jvmToolchain(...)`, so the
  plugin was never actually triggered (Gradle uses the build environment's JDK
  21); removing it deletes a latent network path and a future foot-gun with no
  change to how any build resolves Java.
- `android/app/build.gradle.kts`: enabled `allWarningsAsErrors` in the Kotlin
  `compilerOptions` block. The sources are warning-free, so every future Kotlin
  compiler warning (unused import/symbol, deprecated API, always-true `is`
  check, …) now fails the build instead of accumulating silently. Scope is the
  Kotlin compiler only (all source sets and build types); it does not affect
  Gradle-level deprecation notices (see "Known upstream issue" below).
- `gradle/libs.versions.toml` + `android/app/build.gradle.kts` (`lint { }`):
  bumped `navigation-compose` 2.8.9 → 2.9.7 and re-enabled the three navigation
  lint checks that had been disabled as tooling-bug workarounds
  (`WrongStartDestinationType`, `ComposableDestinationInComposeScope`,
  `ComposableNavGraphInComposeScope`). navigation-compose 2.8.9 shipped lint
  detectors compiled against older Compose lint utilities, which under AGP 9.2 /
  `compose-bom` 2026.06.00 threw `NoClassDefFoundError`
  (`androidx/navigation/lint/UtilKt`, `androidx/compose/lint/PsiUtilsKt`) and
  aborted the whole lint task while analysing `AppNav.kt`. 2.9.7 ships detectors
  built against the current Compose lint API, so the checks run instead of
  crashing — making the previous `disable` workarounds unnecessary. `AppNav.kt`
  is a single flat `NavHost` with top-level type-safe `composable<…>`
  destinations and a `@Serializable` start destination, so the re-enabled checks
  report no findings, and the type-safe-route API is unchanged between 2.8 and
  2.9 (no source edits required).

Store metadata (L10N):
- Added fastlane store listings (`title`, `short_description`, `full_description`
  and the `versionCode 81` changelog note) for the **19 app languages that had
  no store listing yet**: `cs`, `da`, `el`, `es`, `fr`, `it`, `ja`, `ko`, `nb`,
  `nl`, `pl`, `pt`, `pt-BR`, `ro`, `ru`, `sv`, `uk`, `zh-CN`, `zh-TW`. The store
  listing now covers all 21 shipped app languages (`en` and `de` already
  existed). Screenshots are intentionally NOT duplicated per locale — F-Droid
  falls back to the `en-US` images — so only text was added.
- Added the `versionCode 81` changelog note (`changelogs/81.txt`) to the
  existing `en-US` and `de-DE` listings as well, as required by the release
  gate.

Tooling (`android/tools/release-check.sh`):
- SECTION 1 now cross-checks the F-Droid reference recipe: the recipe's
  `CurrentVersion` / `CurrentVersionCode` and its latest `Builds:` block must
  equal the `build.gradle.kts` `versionName` / `versionCode` (which SECTION 1
  already ties to the top CHANGELOG entry). This is the enforcing half of the
  recipe-sync fix above.
- SECTION 1 fastlane **locale-parity** rule relaxed: full changelog *history*
  parity is now required only among the history-bearing locales (`en-US`,
  `de-DE`); every other listing locale must carry only the CURRENT
  `versionCode` note. Without this, adding 19 listing locales would have
  demanded ~320 back-dated changelog files for `versionCode`s those locales
  never shipped under. The current-version coverage check (every locale must
  have `<versionCode>.txt`) is unchanged.

Tests (warning cleanup, required by `allWarningsAsErrors` above):
- `AppViewModelFactoryTest`: removed five `assertTrue(vm is …)` assertions (and
  the now-unused `assertTrue` import). Each `vm` is already statically typed by
  its constructor's return type, so the runtime `is` check is always true and
  the Kotlin compiler flagged it as "Check for instance is always 'true'". The
  meaningful guarantee — that each ViewModel's constructor signature stays
  callable with the injected types — is enforced at compile time (the test would
  not compile otherwise) and the retained `assertNotNull(vm)` covers successful
  construction.
- `LocaleDetectorTest`: replaced the deprecated single-argument
  `java.util.Locale("…")` constructor (deprecated since JDK 19) with the
  equivalent `Locale.of("…")` at the three remaining call sites. Behaviour is
  identical; the file already used `Locale.of` / `Locale.forLanguageTag`
  elsewhere. (The many `Locale("xx", "Autonym")` calls in
  `l10n/SupportedLocales.kt` are unaffected: they construct the app's own
  `data class Locale(tag, autonym)`, not `java.util.Locale`.)

Localization (plurals) and re-enabled lint check:
- Converted `import_success_replace` ("%1$d entries imported.") and
  `import_success_merge` ("%1$d entries imported, %2$d skipped.") from flat
  `<string>`s into `<plurals>` across all 21 locales, and re-enabled the
  `PluralsCandidate` lint check that previously masked them (removed from the
  `lint { disable }` set). `SettingsViewModel` now resolves them via a new
  `quantityStr` helper (`resources.getQuantityString`, selecting on the imported
  count). Per-locale plural forms mirror the CLDR category set and morphology of
  each locale's existing `<plurals name="days">` (the flat translation becomes the
  high-count form; singular/few/many forms derived accordingly). The merge message
  is pluralized on the FIRST count only — the second number's word is invariant in
  the en/de sources (an invariant past participle), so a single `<plurals>` is
  correct there; in several locales (e.g. `cs`, `pl`, `ru`, `uk`) both clauses are
  impersonal and do not inflect, so their categories carry identical text.
- The remaining `%d`-bearing strings are NOT pluralizable nouns —
  `import_error_version_too_high` (a backup version number),
  `import_error_file_too_large` (`%d MB`, an invariant unit) and
  `pdf_kpi_over_drink_days` (`%d/7`, a ratio) — so each is annotated
  `tools:ignore="PluralsCandidate"` (with `xmlns:tools` added to the base
  `values/strings.xml`) rather than forced into a meaningless plural.

Known upstream issue (documented, not fixed here):
- The Android Gradle Plugin emits "Using a Project object as a dependency
  notation has been deprecated" during configuration. A deprecation trace places
  it inside AGP itself
  (`com.android.build.gradle.internal.dependency.VariantDependenciesBuilder`,
  reached from `VariantManager.createTestComponents`) while it wires the tested
  project as a dependency of the test variant — not in this project's build
  scripts, and not in any applied third-party plugin (CycloneDX 3.2.4, the
  latest, was ruled out). It is harmless on the current Gradle 9.6.1 and will
  only become an error on Gradle 10, so the fix must come from a future AGP
  release. `allWarningsAsErrors` does not promote it, as it is a Gradle
  configuration-phase notice rather than a Kotlin compiler warning.

---

## v0.73.4

Fix QA findings: locale-aware numbers, backup robustness, docs

Fixed:
- L10N: user-visible numbers (grams, BAC, percentages, gram limits) were
  formatted with `String.format` / `"%.1f".format`, which follow
  `Locale.getDefault()` (the system locale) instead of the per-app locale set
  via `AppCompatDelegate.setApplicationLocales`. On a device whose system
  language differed from the in-app language this printed a wrong decimal
  separator next to correctly localized month/weekday names (e.g. "Juni 2026"
  beside "19.6 g"). A new `l10n/NumberFormat.kt` adds locale-aware `fmt0` /
  `fmt1` / `fmt2` helpers, and every read-only display on the Today, Statistics,
  Calendar and Drinks screens, the shared chart and list components, and the PDF
  report now passes the per-app locale (`Context.formattingLocale()`). CSV
  export and the round-trip-parsed numeric input field keep `Locale.ROOT` on
  purpose (machine-readable / `String.toDouble()`-parseable); the latter also
  fixes a latent bug where the grams input dialog opened in an error state on a
  comma-decimal system locale (F-1).
- Backup: `BackupRepository.importMerge` now reads the existing drink
  name-to-id snapshot INSIDE its database transaction, mirroring
  `importReplace`, closing a read-outside-write (TOCTOU) gap (F-5).
- Backup: `buildIdMap` now indexes freshly inserted drinks by name within the
  same import, so a backup containing two identically named new drinks no longer
  creates duplicate drink rows (F-6).
- `StatsViewModel.uiState` now seeds its initial value with the actual default
  period (`MONTH`) instead of `WEEK`, so the period selector no longer flashes a
  one-frame `WEEK` selection before the first emission (F-7).

Changed:
- Removed the unused `IEntryRepository.isDuplicate` and its `EntryRepository` /
  `FakeEntryRepository` implementations: the only MERGE de-duplication path
  calls `entryDao.countByTimestampAndDrink` directly, so the method was dead
  code (F-2).

Docs:
- `AlcoholCalculator.roundTo2Decimals` KDoc corrected: it rounds the BAC value
  to two decimals, not gram values (which use `roundTo1Decimal`) (F-4).
- `EntryRepository.addFromDrink` KDoc no longer mentions the removed gender
  setting (F-3).

L10N (comprehensive translation QA against `en` + `de` as the authoritative
sources; key parity, apostrophe escaping, format placeholders, plural CLDR
categories, brand/URL invariants and newline parity all verified clean):
- `values-zh-rCN`: `drink_delete_blocked` started with a stray `%` and wrapped
  the drink name in ASCII straight quotes (`"…"`). Android treats `"` as a
  verbatim delimiter and strips it, so the user saw `%<name>有 …` with the
  quotes gone and a leftover percent sign. Replaced with the same
  `\u201c…\u201d` curly quotes the `en` source uses, dropping the stray `%`
  (L-1). The string is filled via `String.replace("{name}"/"{count}")`, not
  `String.format`, so there was never a crash — only wrong on-screen text.
- CSV header `csv_col_alcohol_pct` is now spelled out in every locale to match
  the `en`/`de` `Word_Word` style (e.g. `Alcohol_Percent` / `Alkohol_Prozent`)
  instead of a literal `%` (e.g. `Alcool_%` → `Alcool_pourcentage`,
  `酒精_%` → `酒精_百分比`). Purely a header-naming consistency change; the value
  carries no format arguments, so behaviour is unchanged.

Tests:
- Added `NumberFormatTest` (JVM) pinning the decimal separator to the passed
  locale (en-US "." vs de-DE ",").
- `LimitBarUiTest` now pins the Compose **Context configuration** locale to US
  (via a `createConfigurationContext` Context provided through `LocalContext`),
  not just `Locale.getDefault()`. Since `LimitBar` now formats grams for the
  per-app locale through `Context.formattingLocale()` — which is decoupled from
  the JVM default — the previous `Locale.setDefault(US)` alone no longer made the
  expected "20.0 g" deterministic on a comma-decimal device.

---

## v0.73.3

Fix QA findings: orphaned directory, German comments, docs, header style

Changed:
- `app/src/main/res/raw-la/` — removed the empty, orphaned directory left
  behind when Latin (`la`) was dropped from the supported-locale set in
  v0.63.0. The directory had no content and served no purpose, but its
  presence could mislead `render-guide.py` if it ever changed to scan
  output directories instead of template files (B-01).
- `AndroidManifest.xml` — translated the only remaining German inline comment
  (`<!-- CSV-Export in Downloads-Ordner … -->`) to English, consistent with
  CONTRIBUTING.md §3 and `release-check.sh` §7 (D-01).
- `ui/component/AppOverflowMenu.kt`, `ui/component/MarkdownText.kt` — unified
  the vim modeline and file-header comment style with the rest of the codebase:
  `// vim: set et ts=4 sw=4:` / `// =====` block replaced by the project-standard
  `/* vim: set et ts=4: */` / `/* * ===== */` block (D-04).
- `data/repository/EntryRepository.kt` — added the missing KDoc block to
  `mostRecentEntry()`, making it consistent with the other `override` functions
  in the same file that all carry explanatory KDoc (D-02).
- `gradle.properties` — added `org.gradle.warning.mode=all` so that the
  per-deprecation detail Gradle previously suppressed behind the summary line
  *"Deprecated Gradle features were used … use `--warning-mode all`"* is
  printed on every build run. The property is the canonical project-wide way
  to set the flag (rather than a per-invocation CLI argument) and ensures the
  warnings surface in CI, `make` runs, and Android Studio alike.
- `gradle.properties` — translated the three remaining German inline comments
  (`# AndroidX aktivieren …`, `# Gradle-Daemon und Parallelbuilds`,
  `# Kotlin-Code-Style`) to English, consistent with CONTRIBUTING.md §3 (D-01).
- `data/prefs/AppPreferences.kt` — made the encrypted DataStore flow resilient
  to a transient read `IOException`. `settingsFlow` previously mapped
  `dataStore.data` directly, so a plain `IOException` raised on
  the read path (which the `ReplaceFileCorruptionHandler` does NOT cover — it
  only handles `CorruptionException` from the serializer) would propagate to
  every collector, including the start-up reads in `MainActivity.onCreate` and
  `PotillusApp.onCreate`, and crash the app. It is now routed through a
  new, unit-tested `recoverIoAsEmpty(...)` helper that emits `emptyPreferences()`
  on an `IOException` (downstream `map` then falls back to the documented
  defaults) and rethrows any non-IO error. This is the Jetpack DataStore
  guidance and matches the app's existing "degrade, never crash" policy.
  Covered by the new `AppPreferencesIoSafetyTest` (R-01).
- `app/build.gradle.kts` — silenced the cosmetic `stripDebugDebugSymbols`
  build warning *"Unable to strip the following libraries, packaging them as
  they are: `libandroidx.graphics.path.so`, `libdatastore_shared_counter.so`"*.
  The app ships no native code of its own; these two transitive prebuilt `.so`
  files cannot be stripped when no NDK toolchain is present (as in the F-Droid
  build image) and are then packaged unstripped anyway, so the message is purely
  cosmetic — but it became visible on every build once
  `org.gradle.warning.mode=all` was enabled in v0.73.3. They are now listed under
  `packaging.jniLibs.keepDebugSymbols`, which removes them from the strip set so
  AGP no longer attempts (and fails) to strip them. The packaged output is
  unchanged. The two names are listed explicitly rather than a blanket `**/*.so`
  so a future unstrippable library re-surfaces the warning for a conscious
  decision (B-02).
- `util/GplNotice.kt` — converted the file header from the `//` line-comment
  form to the project-standard `/* … */` block header used by the other Kotlin
  files, completing the header-style unification this release already applied to
  `AppOverflowMenu.kt` and `MarkdownText.kt` (F2).
- `ui/component/MarkdownText.kt` — promoted the pure helpers `decodeHtmlEntities`
  and `parseOrderedList` (and the `ORDERED_ITEM_RE` pattern) from `private` to
  `internal` + `@VisibleForTesting`, so the renderer's parsing logic is unit
  testable on the JVM without a device. No behavioural change (F3).
- Documentation accuracy: corrected five stale comments left by the earlier
  C-01 refactor (which moved `toDomain`/`toEntity` to `EntityMapping.kt` as
  `internal`). `BackupRepository.kt` and `DrinkRepository.kt` no longer claim the
  mappers are file-private and re-declared per repository; `Models.kt`,
  `DrinkEntity.kt` and `EntryEntity.kt` now point readers to the `internal`
  extensions in `EntityMapping.kt` instead of the (no-longer-correct) repository
  classes. Comments only — no code or behaviour change (G1).

Added:
- `app/src/test/kotlin/.../data/repository/EntityMappingTest.kt` — JVM unit
  tests for the shared entity ↔ domain conversions: `toDomain`/`toEntity` round
  trips and the unknown-category → `OTHER` fallback, the only non-trivial logic
  in the otherwise pass-through repositories (F3).
- `app/src/test/kotlin/.../ui/component/MarkdownTextTest.kt` — JVM unit tests for
  the in-app Markdown renderer's pure helpers: HTML-entity decoding, the
  ordered-item match boundary (a wrapped decimal is not a new item), and
  continuation-line reflow (F3).

Removed:
- The annual info dialog (the one-shot dialog shown on December 27th) and every
  artefact that existed only to support it (F1). Removed: `PotillusApp`'s
  `infoDialog`/`_infoDialog` state, `dismissInfoDialog()` and
  `checkAnnualInfoDialog()` (plus the now-unused `MutableStateFlow`/`StateFlow`/
  `asStateFlow`/`LocalDate` imports); the `AlertDialog` block and its
  `AlertDialog`/`Text`/`TextButton`/`stringResource` imports in `MainActivity`;
  the `info_dialog_title` / `info_dialog_body` / `info_dialog_ok` strings in
  `values/strings.xml` and all 20 `values-*/strings.xml` (per-locale key count
  170, still in sync); the `infoDialogShownYear` / `setInfoDialogShownYear`
  members of `IAppPreferences`, `AppPreferences` (`KEY_INFO_YEAR`,
  `info_dialog_shown_year`) and `FakeAppPreferences`; and the now-obsolete
  suppression call and notes in `ScreenshotTest`. A leftover
  `info_dialog_shown_year` value in an existing DataStore file is simply ignored.
  The two "translate all N keys" comments (`AndroidManifest.xml`,
  `app/build.gradle.kts`) were updated 173 → 170.
- `ui/screen/Screens.kt` — deleted the content-free documentation placeholder.
  The `Screen` sealed interface and all navigation routes live in
  `ui/nav/AppNav.kt`, which is already self-documenting. The placeholder added
  no information and could confuse readers expecting a `Screens` class (D-03).

---

## v0.73.2

Move fastlane metadata to repo root for F-Droid

Changed (project layout):
- Moved the fastlane tree from `android/fastlane/` to the repository root
  (`fastlane/`, a sibling of `android/`) so F-Droid auto-discovers the store
  listing, per-version changelogs and screenshots from the source repo (F-Droid
  does not look inside the Gradle module tree). The directory move itself is a
  `git mv`; this entry accompanies the path updates that follow from it. fastlane
  re-anchors to the new parent (the repo root), so paths into the Gradle build
  outputs in `Fastfile`/`Screengrabfile` gain an `android/` prefix, while the
  metadata output stays under `fastlane/`. The `android/`-side references
  (`Makefile`, `app/build.gradle.kts`, `tools/release-check.sh`,
  `tools/crop-screenshots.py`, `libs.versions.toml`, the screenshot test and
  `.gitignore`) now point at `../fastlane/`. No functional change to the app.

---

## v0.73.1

Fix QA findings: locale, DRY mapping, docs, tests

Changed:
- `TodayViewModel`: replace `Locale.getDefault()` with a locale derived from
  `AppSettings.language` (BCP-47 tag) for the monthly-average label on the Today
  card. On devices where the system language differs from the in-app language the
  month name now matches the rest of the UI rather than the OS locale (A-01).
- `DrinkRepository`, `EntryRepository`, `BackupRepository`: the four entity ↔
  domain conversion helpers (`toDomain` / `toEntity`) are now defined once as
  `internal` extension functions in the new `EntityMapping.kt` file instead of
  being duplicated across three files (C-01 DRY fix). The behaviour is unchanged.
- `PotillusApp.applyLanguageOnFirstLaunch`: the pure locale-detection logic is
  delegated to the new `LocaleDetector.detect()` function so it is unit-testable
  without an Android runtime (T-03).
- `DrinksScreen`, `TodayScreen`, `StatsScreen`, `CalendarScreen`: added missing
  `@param` KDoc entries for `onOpenHelp`, `onOpenCopyright`, and `onLockApp` (D-02).
- `Screens.kt`: added the missing `package de.godisch.potillus.ui.screen` declaration;
  without it the file resided in the default package, inconsistent with every other
  source file in the project (D-01 / S-01).

Added:
- `EntityMapping.kt` (`data/repository`): single source of truth for the four
  entity ↔ domain conversion helpers, replacing the previously scattered private
  and class-private copies (C-01).
- `LocaleDetector.kt` (`domain`): pure, Android-free singleton that implements the
  three-step BCP-47 matching strategy (full tag → base language → "en") extracted
  from `PotillusApp` (T-03).
- `LocaleDetectorTest.kt`: 10 JVM unit tests for `LocaleDetector.detect` covering
  all three matching steps, region variants (zh-CN/zh-TW, pt-BR), unsupported
  locales, empty sets, and case-insensitivity (T-03).
- `AppViewModelFactoryTest.kt`: unit tests that verify each registered ViewModel
  can be constructed with its injected dependency types, and that the factory's
  `else` guard throws `IllegalArgumentException` for unregistered classes (T-02).

---

## v0.73.0

Remove SQLCipher; add signing and Play tooling

Added:
- Conditional release code-signing in `android/app/build.gradle.kts`. A new
  `signingConfigs { create("release") }` block reads the key material either from
  a git-ignored `android/keystore.properties` file or from environment variables
  (the latter take precedence, which is convenient for CI). The release build
  type applies the config ONLY when the material is present, so the default
  source build — and F-Droid, which signs the APK itself — keeps producing the
  unsigned `app-release-unsigned.apk` with no key configured.
- `android/keystore.properties.example`: a documented template listing the four
  keys (`storeFile`, `storePassword`, `keyAlias`, `keyPassword`) and their
  environment-variable equivalents (`POTILLUS_KEYSTORE_FILE` etc.). The real
  `keystore.properties` and the Play service-account JSON are now git-ignored.
- `make bundle` (`android/Makefile`): builds the Android App Bundle
  (`bundleRelease`) that Google Play requires for new apps, alongside the
  existing `make release` APK target; both also generate the SBOM.
- `make deploy` plus a fastlane `deploy` lane (`android/fastlane/Fastfile`) and
  `android/fastlane/Appfile`: upload the signed AAB and the existing store
  metadata to Google Play via `upload_to_play_store`. The Play track and release
  status are overridable (defaults: `production` / `draft`, i.e. staged for
  manual publish) and the service-account key path is read from the
  `SUPPLY_JSON_KEY` environment variable (falling back to
  `fastlane/play-store-credentials.json`).
- Per-locale Play/F-Droid release notes `…/changelogs/76.txt` (de-DE, en-US) for
  the new versionCode.

Changed:
- `make release` is now a phony target that always invokes `assembleRelease` and
  prints the produced artifact path, instead of hard-coding the
  `app-release-unsigned.apk` filename (which becomes `app-release.apk` once a
  signing key is configured).
- Bumped versionName 0.72.0 → 0.73.0 and versionCode 75 → 76, with the matching
  README, `proguard-rules.pro` and fastlane changelog updates that
  `tools/release-check.sh` couples to the version.

Removed:
- **SQLCipher** (`net.zetetic:sqlcipher-android`) and the explicit
  `androidx.sqlite` pin are gone, together with all passphrase machinery
  (`getOrCreatePassphrase` / `hasSealedPassphrase` / `canOpenSealedPassphrase`
  and the `KeystoreSecretStore`-sealed passphrase in `AppDatabase.kt`), the
  `-keep class net.sqlcipher.**` ProGuard rules, and the `SupportOpenHelperFactory`
  usage in `MigrationTest`. The database is now a plain Room/SQLite file, relying
  on Android's file-based storage encryption and the per-app sandbox at rest.
- The **device-transfer "Settings not restored?" warning** (its detection,
  `PotillusApp` state/flow, the `MainActivity` dialog, the
  `device_transfer_warning_title`/`_body` strings in all 21 locales, and the
  `PotillusAppHeuristicTest`). The warning existed only to diagnose a failed
  SQLCipher-passphrase migration, which can no longer occur.

Changed (data & security):
- `data_extraction_rules.xml` now **excludes** the database and the preferences
  DataStore from both cloud-backup and device-transfer (and no longer references
  the obsolete passphrase file). With `allowBackup="false"` these rules stay
  inert, but they now state the intent plainly: personal data never leaves the
  device automatically. The **only** supported way to move data between devices
  is the user-initiated JSON backup (Settings → Backup → Export / Import).
- The user's guide **Backup** section was rewritten to explain, emphatically,
  why export/import is the sole transfer path and how to perform it, and was
  translated into all 21 supported languages.

Security:
- **Clean break, no data migration.** A plaintext SQLite engine cannot open the
  former SQLCipher file, so on the first launch after upgrading, `AppDatabase`
  runs a one-shot `purgeLegacyEncryptedDatabase()`: keyed on the legacy
  passphrase SharedPreferences marker, it deletes the old encrypted database, the
  passphrase file, and the now-unused Keystore key, then lets Room create a fresh,
  empty database. The routine is idempotent and a no-op on clean installs. Users
  upgrading from an encrypted build must re-import their JSON backup.

Fixed:
- The release `signingConfigs` block in `android/app/build.gradle.kts` failed to
  compile, breaking every Gradle task at configuration time (`Unresolved reference
  'util'`). Inside that block the bare identifier `java` resolves to Gradle's
  Java-plugin extension accessor, so the fully-qualified `java.util.Properties()`
  was misparsed. Added an explicit `import java.util.Properties` and now reference
  it as `Properties()`.
- Lint (run with `warningsAsErrors = true`) aborted the build on the legacy-database
  cleanup in `AppDatabase.kt`: `legacyPrefs.edit().clear().commit()` tripped both
  `ApplySharedPref` (prefer `apply()` over `commit()`) and `UseKtx` (prefer the
  `SharedPreferences.edit` KTX extension). The call was redundant — the following
  `deleteSharedPreferences()` already removes the file and its in-memory state — so
  the line was dropped entirely.
- The in-app guide viewer (`MarkdownText`) now renders `**bold**` inline spans.
  The rewritten Backup section uses bold for emphasis; previously the renderer
  handled only headings, paragraphs and `[text](url)` links, so the `**` markers
  would have appeared literally. Bold is now parsed alongside links in
  `renderInline` via a combined regex and a `FontWeight.Bold` span.
- The guide viewer now also renders ordered lists (`1.`, `2.`, …) as separate,
  hanging-indented items instead of collapsing them into a single paragraph, so
  the rewritten Backup section's device-transfer steps display as a proper
  numbered list with inline bold preserved per item.
- Migrated the screenshot test off the deprecated `createEmptyComposeRule` (the
  Compose UI-test rule) to its `…junit4.v2` replacement. The v2 rule uses a
  StandardTestDispatcher; the test is unaffected because it already synchronizes
  explicitly via `waitUntil`/`waitForIdle` and drives a real Activity rather than
  relying on immediate composition.
- Worked around a crash in the bundled navigation lint detector
  (`WrongStartDestinationType` / `BaseWrongStartDestinationTypeDetector`), which
  throws `NoClassDefFoundError: androidx/navigation/lint/UtilKt` under the lint
  shipped with AGP 9.2 and aborts `lintAnalyzeDebug` (the project runs lint with
  `abortOnError`/`warningsAsErrors`). The check is disabled in the `lint {}` block
  with a documented rationale; it is a tooling bug, not a finding in the app's
  navigation graph. The crash only surfaced once a source change invalidated the
  previously cached lint result.
- Migrated the three build-script tasks (`copyDemoBackupFixture`,
  `generateUserGuides`, `generateCopyrightDocument`) off the `val name by
  tasks.registering { }` Kotlin-DSL property-delegate syntax, which Gradle 9.6
  deprecated (scheduled for removal in Gradle 10), to the equivalent
  `tasks.register<Type>("name") { }` form. Task names and wiring are unchanged.
  (One remaining Gradle 10 deprecation — "Using a Project object as a dependency
  notation" — originates inside the Android Gradle Plugin, not this build script,
  and will clear with a future AGP release.)

Cleanup:
- Removed 13 unused imports across the UI and test sources, and corrected two
  stale KDoc/comment references in `AppPreferences.kt` that still mentioned the
  former SQLCipher "DB passphrase key alias" (which no longer exists). The
  preferences DataStore key is now the only persistent Keystore key the app uses.

Changed (build and distribution):
- **Guide and copyright resources are now generated by Gradle.** Two tasks
  (`generateUserGuides`, `generateCopyrightDocument`) render
  `res/raw[-xx]/usersguide.md` and `res/raw/copyright.md` and are wired into
  `preBuild`, so a bare `./gradlew assembleRelease` (a fresh clone, CI, or an
  F-Droid build that does not go through `make`) no longer fails on the missing,
  git-ignored `R.raw.*` backing files — previously only the Makefile produced them.
- **Added the F-Droid build recipe** at `fdroid/de.godisch.potillus.yml` (a
  reference copy of the fdroiddata metadata) with `fdroid/README.md`. Because the
  generation is wired into Gradle, the recipe is a plain `gradle: [yes]` build;
  the release stays unsigned when no keystore is configured, so F-Droid signs it.
  Auto-updates track v-prefixed semver tags.

Changed (store metadata):
- Corrected the store texts that the SQLCipher removal had made inaccurate. The
  long description no longer claims data is "stored fully encrypted using
  hardware-backed cryptography" (true only of the former SQLCipher layer); it now
  describes the actual model — on-device private storage under Android's storage
  encryption and the app sandbox, with the preferences additionally sealed by a
  hardware-backed Keystore key. The versionCode 76 store note
  (`changelogs/76.txt`, de + en), previously "developer tooling only", now states
  the real user-facing change and warns that data from earlier versions is not
  migrated automatically.

Changed (dependencies):
- Bumped the Jetpack Compose BOM from 2026.04.01 to 2026.06.00 (core Compose
  modules 1.11.0 → 1.11.3, bug-fix only). The Compose compiler stays paired with
  the Kotlin plugin, and the v2 UI-test rule adopted earlier is unaffected.
- Bumped the Gradle wrapper from 9.4.1 to 9.6.1 (`gradle-wrapper.properties`).
  9.6.1 is a patch release of the 9.6 line and stays well within AGP 9.2's Gradle
  requirement. Only `distributionUrl` is changed; the bundled wrapper JAR boots
  any 9.x distribution, so it needs no regeneration.
- Bumped Kotlin from 2.3.21 to 2.4.0. Because AGP 9's built-in Kotlin is pinned on
  the buildscript classpath, this touches two coupled spots that must stay in
  sync: the `kotlin` catalog key and the hard-coded `kotlin-gradle-plugin`
  classpath literal in the root `build.gradle.kts`. The Compose compiler and the
  serialization compiler plugin follow the `kotlin` key automatically. KSP is
  moved 2.3.7 → 2.3.9 (the release the Kotlin 2.4.0 notes pair with). The
  kotlinx-serialization runtime stays at 1.11.0; it must satisfy the
  forward-compatibility rule under the 2.4.0 compiler — if a build reports a
  serialization version mismatch, that runtime needs bumping too.

Note:
- The Google Play *feature graphic* (1024×500 px) is a design asset and cannot
  be generated here; the placeholder description in
  `android/fastlane/metadata/android/en-US/images/PLACEHOLDERS.txt` still
  applies. The F-Droid build-recipe metadata (for the fdroiddata repository) is
  intentionally NOT included yet — it needs the agreed tag/versioning convention.
  (With SQLCipher removed, the build no longer ships any prebuilt native binary,
  so the earlier prebuilt-binary concern no longer applies.)

---

## v0.72.0

Automate Play-Store screenshots via screengrab

Added:
- Fully automated Play-Store screenshot pipeline, runnable as `make screenshots`
  (root) which delegates to `make -C android screenshots`. It captures the six
  in-app phone screenshots in both store locales (`de-DE`, `en-US`) via Fastlane
  `screengrab` plus an Espresso/Compose UI test, then renders the two pages of
  the localized PDF report as screenshots 7 and 8, placing all eight assets per
  locale straight into `fastlane/metadata/android/<locale>/images/phoneScreenshots/`.
- `app/src/androidTest/.../screenshot/ScreenshotTest.kt`: the capture suite. It
  seeds the database from the canonical demo fixture (`fastlane/demo-backup.json`,
  copied into the androidTest assets at build time by the new
  `copyDemoBackupFixture` Gradle task), fixes the theme per phase (screenshots
  1–3 in light mode, 4–6 in dark mode), and navigates Today → Calendar →
  Statistics → Drinks → Add-drink dialog → Settings. It selects navigation
  targets by their localized label text plus a click action (the production UI
  has no test tags) so it works unchanged in both locales.
- `app/src/androidTest/.../screenshot/ScreenshotOnly.kt`: a runtime annotation
  tagging the suite so it can be excluded from an ordinary device-test run via
  the documented switch `make test-device EXCLUDE_SCREENSHOTS=1`
  (`-PexcludeScreenshotTests`). By default the suite still runs as part of
  `connectedDebugAndroidTest`, so a broken capture flow is caught by the normal
  gate.
- `tools/validate-screenshots.py`: a pure-stdlib gate that fails the run unless
  every captured asset meets Google Play's phone-screenshot requirements (PNG,
  each side 320–3840 px, aspect ratio ≤ 2:1, exactly eight per locale).
- Fastlane Ruby configuration: `fastlane/Fastfile` (lane `screenshots`),
  `fastlane/Screengrabfile` (locales, packages, output dir), `fastlane/Gemfile`
  (declares the fastlane gem) and the resolved `fastlane/Gemfile.lock` that pins
  the exact gem versions for the mandatory `bundle exec` run.

Changed:
- Status-bar hygiene during capture uses the Android Demo Mode API, driven from
  the `screenshots` Makefile target via adb: clock 10:00, 100 % battery, full
  Wi-Fi and no notifications. A bash `EXIT` trap guarantees Demo Mode is disabled
  again afterwards (`screenshots-demo-off`), even if the run fails. The device
  date is pinned to 2026-06-30 so the date-relative Today screen shows the demo
  period (best-effort; needs an emulator/rooted build).
- `app/build.gradle.kts` / `gradle/libs.versions.toml`: added the
  `tools.fastlane:screengrab` and `androidx.test.uiautomator` androidTest
  dependencies. The UiAutomator full-screen capture strategy is required so the
  cleaned Demo-Mode status bar is part of the saved image. `FLAG_SECURE` is cleared
  for the run by enabling the existing `allowScreenshots` preference from the
  test — no production code change.
- Screenshot filenames are stable across runs: screengrab's timestamp suffix is
  disabled (`use_timestamp_suffix(false)`), so capture overwrites
  `01_today.png` … `06_settings.png` in place instead of emitting a new
  timestamped file every run. The committed store screenshots can therefore be
  re-generated and checked in without churn or duplicates.
- The six in-app screenshots are bottom-cropped to at most a 2:1 aspect ratio
  (`tools/crop-screenshots.py`, Make step `screenshots-crop`). This removes the
  Android navigation bar at the bottom and satisfies Google Play's max-2:1 rule
  even when captured on a tall phone/emulator (e.g. 19.5:9). The PDF report pages
  (07/08) keep their A4 ratio and are never cropped.

Release process:
- versionName 0.71.1 → 0.72.0, versionCode 74 → 75 (anchor v0.70.0 = 72 plus
  three releases since). README title and `proguard-rules.pro` header updated to
  v0.72.0.
- Added fastlane store notes `changelogs/75.txt` in both locales (covers 0.72.0).

---

## v0.71.1

Fix Today-screen trend-arrow baseline

Fixed:
- Today screen, second row: the month-trend arrow (↑/↓) next to the per-day
  average was rendered in `titleMedium` while the adjacent "g/day" label uses
  `bodyMedium`. Because `Alignment.Bottom` aligns text bounding boxes rather
  than baselines, the larger style left the arrow sitting off the "g/day"
  baseline. The arrow now uses `bodyMedium` (bold), so it shares the label's
  baseline and size.

Release process:
- New rule, enforced by `release-check.sh` (SECTION 1): every `## vX.Y.Z`
  heading added to this changelog must be accompanied by exactly one increment
  of `versionCode`. The check derives the expected `versionCode` from a fixed
  reference point in `android/version-anchor` (anchored at v0.70.0 = 72) plus
  the number of changelog entries above it. versionName 0.71.0 → 0.71.1,
  versionCode 72 → 74 (0.71.0 = 73, 0.71.1 = 74).
- Added fastlane store notes for the new versionCodes in both locales:
  `changelogs/73.txt` (covers 0.71.0) and `changelogs/74.txt` (covers 0.71.1).

---

## v0.71.0

Reorder PDF KPIs; show longest abstinence streak

Changed:
- PDF report, KPI section: reordered tiles so that `abstinent days` and
  `longest abstinence phase` appear together in the first row, followed by
  `drinking days` and `total alcohol`. The consumption-peak and average/median
  rows are regrouped accordingly. (Patch `reorder.diff`.)

Added:
- PDF report, KPI section: the previously empty tile next to `abstinent days`
  now shows the longest continuous abstinence streak (in days) within the
  report period, using the already-computed `PdfReportData.longestAbstinence`
  field and the existing `pdf_meta_longest_abstinence` string resource
  (available in all 21 locales).
- PDF report, KPI section: `max per day` and `max per 7 days` tiles are now
  highlighted in red (warn flag) when their value exceeds the corresponding
  configured limit (`LimitInfo.limitGrams` and `LimitInfo.weeklyLimitGrams`
  respectively), consistent with the existing colouring of the
  `days > g/day` and `days > g/7 days` violation tiles.
- Statistics screen: initial period on first app start changed from `WEEK` to
  `MONTH` (`StatsViewModel._period` default).
- Document viewer: HTML character entities (`&copy;`, `&amp;`, `&lt;`,
  `&gt;`, `&quot;`, `&apos;`, `&nbsp;`, `&reg;`, `&trade;`) are now decoded
  to their Unicode equivalents before rendering, so e.g. `&copy;` in
  `LICENSE.md` appears as `©` instead of literal markup
  (`MarkdownText.decodeHtmlEntities`).
- Settings screen, Appearance section: new "Allow Screenshots" toggle.
  When off (default) `FLAG_SECURE` blocks screenshots and screen recordings
  to protect health-sensitive data. When on, the flag is cleared reactively
  via the `settingsFlow` collector in `MainActivity` without requiring a
  restart (`AppSettings.allowScreenshots`, `KEY_ALLOW_SCREENSHOTS`,
  `IAppPreferences.setAllowScreenshots`, `SettingsViewModel.setAllowScreenshots`).
  String resources added in all 21 locales.
- Today screen, second row: the left column now shows today's own total in
  grams (e.g. `0.0 g`) styled like the right column's headline figure, instead
  of the static word "Alcohol". The month-trend arrow (↑/↓) on the right is now
  rendered in bold.
- Settings screen: the access-lock and screenshot toggles moved out of the
  "Appearance" section into a new "Security" section placed above it, so
  "Appearance" now precedes the colour-scheme (theme) and language controls
  only. New `security` string resource added in all 21 locales.
- PDF report, page 1 long-term trend chart: corrected the section heading unit
  from "Ø Grams/Month" to "Ø Grams/Day" in all 21 locales — the bars (and the
  dashed reference line) have always been per-day averages against the daily
  limit, independent of the span-derived bucket width. Each bar now also carries
  its per-day average on top (one decimal, blank for abstinent buckets),
  matching the page-2 hour/weekday charts (`BAR_VALUE`).

---

## v0.70.0

Add monthly trend arrow; fair per-day trend

Added:
- Today screen, monthly trend arrow. Next to the month's per-day average a small
  arrow now shows how it compares with the baseline period — the per-day average
  over the whole time from the configured statistics start date up to the day
  before this month: a green ↓ when this month is averaging fewer grams of
  alcohol per day than that baseline, a red ↑ when it is more, and nothing (no
  arrow, no extra space) when the two are equal at 0.1 g precision or there is no
  baseline yet (statistics started this month). Backed by a new shared domain
  type Trend (Trend.of(currentAvg, prevAvg)) and a monthTrend field on
  TodayUiState; the baseline is read by widening the monthly daily-summary query
  to start at the statistics start date.
- Release gate now checks Markdown syntax. A new check (`release-check.sh`
  section 9, backed by `tools/md-syntax.py`, standard library only) verifies that
  `CHANGELOG.md`, `README.md`, `CONTRIBUTING.md` and the per-language guides
  rendered from `*.md.in` are well formed: inline-code backticks and `*` emphasis
  balanced, and code-looking tokens (`snake_case`, glob `*`) wrapped in backticks
  so a stray marker cannot turn into accidental emphasis in the in-app renderer.
  `CHANGELOG.md` headings must additionally read `## vMAJOR.MINOR.PATCH` in
  descending order. The verbatim GPL texts (`LICENSE.md`, `COPYING.md`,
  `copyright.md`) are excluded.

Changed:
- Statistics trend is now computed on a per-day-AVERAGE basis instead of period
  totals, and its arrow uses the same shared Trend rule as the Today card. This
  makes an in-progress period compare fairly with the previous one: the current
  period is divided by its effective days (today counts only once it is a drink
  day) and the previous, complete period by its full day count. As a result a
  part-month no longer looks artificially lower than a full previous month, and
  the two screens always agree. The "trend vs. previous" percentage is now the
  change in the per-day averages; equal-at-0.1 g shows "–" (no arrow). The 7-day
  view is unaffected in practice (two equal-length windows).

Fixed:
- PDF report, page-1 trend chart: the x-axis labels are now drawn in a separate
  row BELOW the baseline, matching the page-2 hour/weekday charts (previously they
  sat above the axis, inside the plot area). The trend chart was switched to the
  same .barchart layout (a .bars plot area plus a .axis label row), so a label is
  never overlapped by its bar and both pages are laid out consistently.
- English PDF report capitalization. Report labels now use sentence case
  (lowercase except the first word and proper nouns) instead of Title Case —
  e.g. "Total alcohol", "Ø per day", "Longest abstinence phase", "Binge days",
  "Drinking days" — and units after a slash are lowercase ("g/day", "g/7 days",
  "Ø g/day", "… days/month"). Document title and section headings keep their
  Title-Case / all-caps styling. Only the report-only (`pdf_*`) English strings
  were touched; localized values are unchanged (e.g. German "g/Tag" stays
  capitalized, since "Tag" is a noun).
- Day counts are now correctly pluralized. The abstinence values in the PDF
  report (e.g. "Longest abstinence: 1 day", "Current: 0 days") and the streak
  values on the Statistics screen previously always used the plural form ("1
  Days"). They now use a shared `days` plural resource with the correct forms for
  every locale (including the multi-form Slavic plurals: cs/pl/ru/uk and ro).
  The now-unused `pdf_days_suffix` and `days_count` strings were removed.
- CHANGELOG escaping. Several code identifiers in recent entries were written
  without backticks; their `_` and `*` characters could render as unintended
  emphasis in a Markdown viewer. They are now wrapped in backticks (along with a
  stray `2.2.*` version glob), matching the file's convention. The new section-9
  check above guards against regressions.

Release housekeeping:
- versionName 0.69.0 → 0.70.0 (minor bump), versionCode 71 → 72.
- Synced proguard-rules.pro and the README title line; added Fastlane store
  notes 72.txt for de-DE and en-US.

---

## v0.69.0

Label chart bars; add monthly per-day average

Added:
- Statistics chart, per-bar value labels. On the two sparse axes each bar is now
  annotated with its grams of alcohol per day, commercially rounded to a whole
  number and printed without a unit to stay compact: the 7-day view labels each
  daily bar with that day's grams, and the year view labels each monthly bar
  with the month's grams averaged over its calendar days. The dense ~30-bar
  month view is left unlabelled to avoid clutter.
- Today screen, monthly per-day average. The summary card's right-hand column
  now shows the current month's average grams per day: a caption "Ø <month>"
  (the full localized month name) above the figure "<x> g/day". The left column
  keeps the "Today's Total" caption but no longer repeats today's gram figure —
  that number already appears on the daily-limit bar just below, so the card
  shows only the label "Alcohol" there. The per-day average uses the same rule
  as the chart and the statistics summary (see Fixed). Backed by new
  monthlyAvgPerDay and currentMonthLabel fields on TodayUiState.
- New/renamed string resources, translated into all 20 locales: `avg_of_month`
  ("Ø %1$s" format), `alcohol` and `grams_per_day`; the now-unused `grams_alcohol` was
  removed.

Changed:
- Statistics chart, year view: the dashed daily-limit line and the over-limit
  red colouring are no longer drawn, because a month's per-day average is not
  compared against a daily limit. Bar heights remain the per-day average (the
  same scale as the 7-day and month views), so a bar's height matches its label.
  The 7-day and month views keep the daily-limit line unchanged.

Fixed:
- Per-day averages now agree across the app. The Today card's monthly average,
  the Statistics summary's "average per day" and the year-view chart bar for the
  current month previously used different denominators (the chart and Today
  counted the in-progress day; the summary did not), so the same month could
  read as e.g. 18.8 vs 19.6. They now share one rule, centralised in
  DayResolver.effectivePeriodDays: the current day counts only once a drink has
  been logged on it (otherwise the unfinished day is left out of the average).
  bucketize gained an optional inProgressDay parameter for this; the PDF export
  passes none and is unchanged.

Release housekeeping:
- versionName 0.68.2 → 0.69.0 (minor bump), versionCode 70 → 71.
- Synced proguard-rules.pro and the README title line; added Fastlane store
  notes 71.txt for de-DE and en-US.

---

## v0.68.2

Rename app, fix year chart, add SBOM tooling

Fixed:
- Statistics screen, YEAR view: the consumption chart aggregated by ISO week
  (~52 bars) while labelling each weekly bar with its month name, so a single
  month could appear as several identically-named bars (e.g. three "Jun" bars
  for entries spread across June). The on-screen YEAR view now aggregates by
  calendar month (≤ 12 bars, exactly one bar per month). Implemented by
  selecting `ChartGranularity.MONTHLY` instead of `WEEKLY` for the YEAR period
  in StatsViewModel; the existing month-name axis label is the natural label for
  a monthly bucket. The PDF export is deliberately unchanged — it derives its
  granularity from the chosen span via `ChartBucketing.granularityForSpan()`, so
  a one-year report still shows ~52 weekly bars.

Changed:
- The user-visible application name is now simply "Libellus Potionis"; the
  informal "Potillus" nickname has been dropped. This affects the `app_name`
  string in the base locale and every translated `values-<code>/strings.xml`,
  the README/CONTRIBUTING/COPYING/CHANGELOG titles, all source- and build-file
  header comments, `GplNotice.HEADER_LINES` (the header reproduced in exported
  reports and JSON backups), the rendered User's Guide titles, and the Fastlane
  store descriptions (de-DE, en-US).
- Technical identifiers are intentionally left unchanged: the application id and
  Kotlin package (`de.godisch.potillus`), the canonical repository URL
  (`codeberg.org/godisch/potillus`) and the source tarball name stay "potillus",
  so the update channel, signing identity and existing installations are
  unaffected.

Added:
- Standardized SBOM generation. The CycloneDX Gradle plugin (org.cyclonedx.bom
  3.2.4, the Gradle-9-compatible line) is wired into the build to emit a
  CycloneDX 1.6 JSON Software Bill of Materials for the release runtime
  classpath, i.e. exactly the third-party components packaged in app-release.
  No SBOM file is committed to source; the SBOM is generated on demand via the
  new `make sbom` target and is also produced as part of `make release`,
  landing next to the APK at app/build/outputs/sbom/. The plugin is build-time
  only, so the APK and versionCode are unchanged.
  - Android scoping: generation is pinned to the resolved `releaseRuntimeClasspath`
    configuration, which avoids the well-known "cannot choose between the
    following variants of project :app" resolution error.
  - Reproducible builds: the random serial number is disabled
    (`includeBomSerialNumber = false`) and the volatile `metadata.timestamp` is
    normalized by the new tools/sbom-normalize.py post-step (honoring
    SOURCE\_DATE\_EPOCH when set, otherwise dropping the timestamp), so the SBOM
    is byte-stable across identical builds. python3 was already a build
    prerequisite, so no new tooling dependency is introduced.

Release housekeeping:
- versionName 0.68.1 → 0.68.2, versionCode 69 → 70.
- Kept the version string in `proguard-rules.pro` and the README title line in
  sync (release-check.sh §1).
- Added Fastlane store notes `70.txt` for de-DE and en-US (release-check.sh §1
  requires the changelog-file set to be identical across all locales).

---

## v0.68.1

Fix lock bypass on warm start; add manual lock

Fixed (security):
- The biometric app lock could be bypassed after a "warm start". When Android
  destroyed the Activity but kept the process cached (common after the phone has
  been locked or used for other things for hours), reopening the app sometimes
  revealed it WITHOUT a prompt. Cause: the inactivity timestamp `backgroundedAt`
  was a per-Activity-instance field (reset to 0 on the recreated Activity), while
  `isAuthenticatedThisSession` is process-global (still true) — so onCreate's gate,
  which only checked the boolean, skipped the prompt, and onStart saw `backgroundedAt
  == 0` and also skipped. `backgroundedAt` is now process-global (companion object)
  and the staleness check runs in onCreate as well as onStart, so re-authentication
  is required once the threshold has elapsed regardless of whether the Activity was
  recreated. The timestamp is consumed on a valid foreground return, so a later
  configuration change (which skips onStop) cannot re-prompt spuriously.
  Reproducible deterministically with Developer Options → "Don't keep activities".

Added:
- "Lock app" entry in the shared overflow menu, for locking the app on demand. It
  clears the authenticated state and shows the prompt immediately. Variant A: it
  works regardless of the auto-lock setting, as long as a biometric or device
  credential is available; the entry is hidden when no authenticator is enrolled,
  so it can never strand the user. MainActivity exposes `lockNow()`, threaded
  through AppNavigation to the four main screens' `AppOverflowMenu`. New string
  `lock_app` added to all 21 locales (per-locale key count 172 → 173).

---

## v0.68.0

Add biometric toggle auth; fix bugs and lint

Quality-assurance release plus one small feature: two functional bugfixes, a
security-feature responsiveness fix, biometric authorisation for the lock toggle,
resource-handling hardening, additional tests, and documentation corrections. No
schema change, no UI redesign.

Added:
- Toggling the biometric app lock now requires biometric (or device-credential)
  authorisation in BOTH directions: enabling AND disabling the lock prompts, and
  the switch only changes when authentication succeeds. Cancelling leaves the
  setting unchanged (the switch is bound to the stored value and snaps back).
  MainActivity exposes a dedicated `authenticateForToggle()` that — unlike the
  app-start gate — never finishes the Activity on cancel; the capability is threaded
  through AppNavigation to the Settings switch. It reuses the existing biometric
  prompt strings, so no new translations are needed. If no authenticator is
  enrolled, the toggle is left unchanged (the lock could not be satisfied anyway).

Fixed (functional):
- CSV export now formats the grams column with a locale-independent dot decimal
  separator (Locale.ROOT). Previously the default-locale formatter produced a
  comma on comma-decimal locales (e.g. de, fr, es), and that unquoted comma split
  the grams value across two columns, misaligning every following column in the
  exported file. The localised column headers are now also escaped, so a comma in
  a translated caption can no longer add a stray column.
- Importing a JSON backup now runs the file read and JSON parse on Dispatchers.IO
  instead of the main thread, removing an ANR risk on large backups. This matches
  the export path, which already moved its I/O off the main thread.

Fixed (security / behaviour):
- The biometric app lock now reflects the live preference: enabling it during a
  running session arms the inactivity re-authentication immediately, rather than
  only after the next cold start. MainActivity keeps its cached flag in sync via a
  repeatOnLifecycle collector.

Hardened:
- WebViewPdfPrinter now creates its off-screen WebView from the application
  context (not the Activity context) and abandons any still-pending previous
  WebView before starting a new print job, preventing an Activity context leak if
  the page-finished callback never fires.
- DocumentViewerScreen reads its bundled raw resource on Dispatchers.IO via
  produceState instead of synchronously during composition, keeping all disk I/O
  off the UI thread.

Tests:
- Added ChartBucketingTest (JVM) for gap filling, per-day averaging, period
  clamping and calendar-month snapping.
- Added CsvExporterBuildTest (JVM, run under Locale.GERMANY) covering the new
  Locale.ROOT grams formatting, the eight-column invariant and header escaping.
  CsvExporter's CSV assembly was extracted into an internal, Context-free
  buildCsv() to make this testable without an Android Context.
- Added LimitBarUiTest (instrumented Compose UI) and LocaleFormattingInstrumented-
  Test (instrumented) for Context.formattingLocale().

Fixed (lint / backup-rule correctness):
- `res/xml/data_extraction_rules.xml` used `domain="datastore"`, which is not a
  valid data-extraction domain. Android Lint rejected it as a `FullBackupContent`
  error (build-blocking once Lint runs), and the rule would have silently matched
  nothing if `android:allowBackup` were ever turned on, defeating the intended
  exclusion of the encrypted preferences file from cloud backup and its inclusion
  in a device transfer. Both rules now use `domain="file"` with the real on-disk
  path `datastore/potillus_settings.preferences_pb` (the `file` domain is rooted
  at `getFilesDir()`, where DataStore stores its file). No runtime behaviour
  changes while `allowBackup` stays `false`.

Lint cleanup (warnings driven to zero):
- Fixed in the sources: launcher/limit/chart composables now declare `modifier`
  as the first optional parameter (ModifierParameter); DocumentViewerScreen reads
  the user guide via `LocalResources.current` so a configuration change
  re-invalidates it (LocalContextResourcesRead); the passphrase write uses the KTX
  `SharedPreferences.edit(commit = true) { … }` form, keeping the deliberate
  synchronous commit (UseKtx, ApplySharedPref); the adaptive-icon XMLs moved from
  `mipmap-anydpi-v26` to `mipmap-anydpi` since minSdk 30 makes the `-v26` qualifier
  redundant (ObsoleteSdkInt), and the legacy pre-API-26 density launcher bitmaps
  (`mipmap-*dpi/ic_launcher*.png`) were deleted — at minSdk 30 the adaptive icon is
  always used, so they were dead fallbacks whose continued presence alongside the
  unqualified `mipmap-anydpi` XML triggered an IconXmlAndPng error; the
  `localeConfig` attribute is annotated
  `tools:targetApi="33"` and the backup-rules advisory is suppressed with
  `tools:ignore="DataExtractionRules"` (allowBackup is off, so a legacy
  full-backup-content file would be dead config); the WebViewPdfPrinter singleton
  carries a documented `@SuppressLint("StaticFieldLeak")` on its object declaration
  (it holds only the application context and is cleared after use — see its KDoc); and
  five genuinely unused strings (`stats_from_section`, `bac_section`, `bac_desc`,
  `biometric`, `pdf_months_truncated`) were removed from all 21 locales
  (UnusedResources), lowering the per-locale key count from 177 to 172.
- Opted out by explicit policy in a documented `lint { }` block (NOT a baseline):
  the dependency/AGP/Gradle/targetSdk version-update nags (GradleDependency,
  NewerVersionAvailable, AndroidGradlePluginVersion, OldTargetApi), the launcher-
  icon design hints (IconLauncherShape, IconDuplicates), and PluralsCandidate.
  Each carries a rationale in build.gradle.kts; dependency upgrades and a proper
  plural conversion across 21 locales are tracked as separate, tested changes.
- Made the lint check a strict gate: `lint { warningsAsErrors = true }` (with the
  default `abortOnError = true`) so `./gradlew lintDebug` now fails on warnings,
  not just errors. The disabled checks above never report, so only genuinely new
  warnings can break the build.

Documentation:
- Corrected the stale "181 string keys" comment to 177 in AndroidManifest.xml and
  app/build.gradle.kts (LocaleSyncTest remains the authoritative source).
- Corrected the "minSdk 35" remark in the AndroidManifest biometric comment to the
  actual minSdk 30.
- Translated the remaining German inline comments in AndroidManifest.xml and
  app/build.gradle.kts to English, matching the project's English-documentation
  convention.

---

## v0.67.2

Bugfix: locale-sensitive text (month names, weekday names, long dates) now follows
the in-app language instead of the system language. Previously, with the app set
to English, the PDF report still printed German month names next to its English
"Export Date" and "Period" labels.

### Fixed

- **PDF report dates follow the in-app language.** `PdfReportBuilder` formatted
  dates and month labels with `Locale.getDefault()`, which reflects the *system*
  locale and is unaffected by the in-app language picker
  (`AppCompatDelegate.setApplicationLocales` only re-configures the Context, not
  the JVM default). Labels (drawn from string resources via the Context) were
  therefore localized while the adjacent month names were not. The two
  locale-sensitive formatters are now built per report from the Context's locale,
  and the weekday/month axis labels use the same locale. The formatters were also
  `object`-level `val`s frozen at class-load time, so this additionally removes a
  stale-locale hazard.
- **Calendar and statistics screens follow the in-app language.** The same
  `Locale.getDefault()` mismatch was present on screen: `CalendarScreen` (long
  dates, the "MMMM yyyy" month header and weekday header), `StatsScreen` (the
  week/year chart axis and the weekday-chart labels) and `SettingsScreen` (the
  statistics from/to date). All now format with the per-app locale, taken from the
  Compose `LocalContext`.

### Added

- **`Context.formattingLocale()` helper** (`l10n/LocaleSupport.kt`) — a single,
  documented source for "the locale to format user-visible values in", resolved
  from the Context configuration so it always agrees with the localized string
  resources. All formatting code now goes through it instead of
  `Locale.getDefault()`.

### Changed

- **Version bump** to `0.67.2` / `versionCode 67` across `build.gradle.kts`,
  `README.md` and `proguard-rules.pro`, with matching localized store changelog
  notes (`fastlane/.../changelogs/67.txt`) for de-DE and en-US.

---

## v0.67.1

Bugfix: the in-app Markdown viewer (Copyright and Help) now resolves HTML/Markdown
character entities such as `&copy;`, which were previously shown verbatim.

### Fixed

- **`MarkdownText` resolves character entities.** The viewer now decodes
  HTML/Markdown character entities — named (`&copy;` → `©`, `&amp;`, `&mdash;`,
  …) and numeric (`&#169;`, `&#xA9;`) — in headings and visible text, never in
  URLs. Unknown names and out-of-range numeric values are left verbatim. Stray
  ampersands without a trailing `;` (e.g. "AT&T") are untouched.

### Changed

- **Fastlane changelog sync check.** `release-check.sh` §1 now additionally
  verifies LOCALE PARITY: all `fastlane/metadata/android/<locale>/changelogs/`
  directories must carry the same set of `<versionCode>.txt` notes, so a release
  note added to one language but forgotten in another is caught before release
  (previously only the current versionCode's presence per locale was checked). A
  maintainer reminder was added at the top of this CHANGELOG.
- **Version bump** to `0.67.1` / `versionCode 66` across `build.gradle.kts`,
  `proguard-rules.pro`, the `README.md` title and this CHANGELOG, with new
  fastlane `changelogs/66.txt` notes for `en-US` and `de-DE`.

---

## v0.67.0

Renamed the overflow-menu **License** entry to **Copyright** and broadened the
document it shows: the viewer now displays the project's `COPYING.md` notice and
the full `LICENSE.md` GPL text, joined at build time and separated by a single
blank line, still untranslated. Added a README section describing the project's
textbook-grade source documentation, introduced a fastlane store-metadata tree
for Google Play and F-Droid (English and German), and hardened the build: the
release gate now runs on every build and its fastlane release notes are tied to
the `versionCode`.

### Added

- **Fastlane store metadata.** New `android/fastlane/metadata/android/` tree with
  `en-US` and `de-DE` listings, each providing `title.txt` (≤30 chars),
  `short_description.txt` (≤80), `full_description.txt` (≤4000) and a
  `changelogs/<versionCode>.txt` release note (≤500, F-Droid's limit). Texts are
  derived from `README.md`; titles and descriptions deliberately omit the version
  to avoid churn. An `images/` folder per locale carries the launcher icon and
  documented placeholders for the feature graphic and screenshots (the binary
  assets must be supplied before publishing). Layout follows the conventions both
  `fastlane supply` and F-Droid consume.
- **README documentation section.** New *Source Code Documentation* subsection
  under *Technical Aspects*, explaining the literate, KDoc-everywhere style, how
  `release-check.sh` enforces it, and the benefits for newcomers, reviewers and
  long-term maintenance.

### Changed

- **"License" → "Copyright" in the overflow menu.** The string key `license` was
  renamed to `copyright` in all 21 locales with the (intentionally untranslated)
  value `Copyright`. The navigation route `Screen.License`, the callback
  `onOpenLicense`, and the raw resource `R.raw.license` were renamed to
  `Screen.Copyright`, `onOpenCopyright` and `R.raw.copyright` so no identifier
  still calls the feature "license". KDoc/comments in `AppNav.kt`,
  `AppOverflowMenu.kt` and `DocumentViewerScreen.kt` were updated to describe the
  combined document accurately (and to correct a stale note that claimed the text
  was rendered as plain, non-Markdown monospace).
- **Build-time copyright document.** The Makefile rule that copied
  `../LICENSE.md` to `raw/license.md` now concatenates `../COPYING.md`, a blank
  line, and `../LICENSE.md` into `raw/copyright.md`. `check-guides`, `.gitignore`,
  `distclean` and the `prereq` prerequisite list were updated accordingly.
- **`MarkdownText` h1 top spacing.** Level-1 (`#`) headings gained a top inset
  (20.dp, larger than the `##` heading's 16.dp). Previously an h1 had no top
  inset, so the `# GNU GENERAL PUBLIC LICENSE` heading at the COPYING/LICENSE
  seam sat closer to the text above it than the `## Preamble` heading below —
  now its gap is at least as large.
- **`release-check.sh` moved to `android/tools/`** and re-anchored to `android/`
  (one line: `cd "$SCRIPT_DIR/.."`); all other relative paths are unchanged. A
  new Makefile `release-check` target runs it, and it was added to `prereq`, so
  the full read-only release gate now runs on **every** build and aborts on any
  hard failure.
- **`release-check.sh --Werror`.** New switch that treats warnings as errors
  (non-zero exit on any warning). The Makefile `release-check` target passes it,
  so warnings can no longer slip silently into a build. Without the flag warnings
  remain advisory (exit 0); an invalid option exits 2; `--help` is supported.
- **Sharper §5 documentation heuristic.** The KDoc look-behind now skips
  multi-line annotation arguments (e.g. `@Query("""…""")`) so KDoc placed above
  the annotation is found, and it excludes local (nested) functions the same way
  it already excludes private ones. This removes two false positives
  (`EntryDao.getDailySummaries`, `PdfReportBuilder`'s local `svg`) so the gate is
  clean under `--Werror`.
- **Version coupling for fastlane.** `release-check.sh` §1 verifies that every
  fastlane locale directory ships a `changelogs/<versionCode>.txt` note matching
  the current `versionCode`, alongside the existing version-string consistency
  check across `build.gradle.kts`, the CHANGELOG, `README.md` and
  `proguard-rules.pro`.
- **Removed the Makefile `version-check` target.** Its checks are fully covered
  by `release-check.sh` §1, which already runs in `prereq`; keeping a separate
  Make target would only duplicate that logic. The target and its entry in
  `prereq`/`.PHONY` were dropped, and the documentation that pointed at it now
  points at the script.
- **Version bump** to `0.67.0` / `versionCode 65` across `build.gradle.kts`,
  `proguard-rules.pro`, the `README.md` title and this CHANGELOG.

---

## v0.66.0

PDF-report improvements: the time-of-day chart now labels every hour beneath the
axis, the weekday profile is shown as a bar chart, the category breakdown is a
half-width table paired with a colour-matched donut, and two peak-consumption KPIs
(max per day, max per 7 days) were added. Follow-up changes: a donut rendering fix,
average-grams bar labels, red limit lines, an eight-bucket on-screen time-of-day
chart, an annual info dialog, and integer-only body weight.

### Added

- **Annual info dialog.** A once-per-year dialog ("Do you like this App?") shown
  only when the app is opened on December 27th (device-local date); if that day is
  missed it is not caught up later. `PotillusApp` decides this once per process
  start (`checkAnnualInfoDialog()`) and `MainActivity` renders it over the content,
  mirroring the existing device-transfer dialog. The "last shown year" is persisted
  through `IAppPreferences.infoDialogShownYear` (new DataStore key
  `info_dialog_shown_year`; `FakeAppPreferences` updated). New strings
  `info_dialog_title` / `info_dialog_body` (placeholder) / `info_dialog_ok` in all
  21 locales, with title and OK localised per language.
- **Bar value labels.** PDF time-of-day bars and the on-screen `ValueBarChart`
  (time-of-day + weekday) now print the average grams above each bar
  (`ValueBarChart` gains a `showValues` flag; bars reserve headroom so labels are
  not clipped).
- **Peak-consumption KPIs.** `util/PdfReportData.kt` gains `maxPerDay` (heaviest
  single calendar day) and `maxPer7Days` (heaviest *rolling* 7-consecutive-day
  window; the whole-period total when the period is shorter than 7 days).
  `util/PdfReportBuilder.kt` shows them as two new KPI tiles. New strings
  `pdf_kpi_max_day`, `pdf_kpi_max_7days` translated into **all 21 locales**.
- **Category donut in the PDF.** Beside the (now half-width) category table the
  report draws an SVG donut matching the on-screen chart, using the same per-category
  colours (`util/PdfReportBuilder.kt` `categoryColor()`, mirroring
  `ui/component/categoryColors`). The ring is built with the stroke-dasharray
  technique (`PIE_SLICES` block: `PIE_FILL`, `PIE_DASH`, `PIE_GAP`, `PIE_OFFSET`) so
  it needs no raster image and survives SimpleTemplate's HTML-escaping. Each table
  row gets a matching colour swatch (`C_COLOR`) as an inline legend.

### Fixed

- **Donut rendered every slice as a full ring.** The SVG dash values were formatted
  with the default locale, so on a comma-decimal device `stroke-dasharray="40,00
  60,00"` was parsed by SVG as four numbers (`40 0 60 0`) — a zero gap that paints
  the whole circle. The pie geometry is now formatted with `Locale.ROOT`
  (`util/PdfReportBuilder.kt`).

### Changed

- **On-screen time-of-day chart → eight 3-hour buckets.** The Statistics screen now
  shows eight buckets (0–3, 3–6 … 21–24), each the **average grams per day** in the
  period (`StatsViewModel`: `hourBucketAverages` replaces the 24 hourly sums in
  `StatsUiState`; the divisor is the same `effectivePeriodDays` used for the per-day
  rate). The PDF time-of-day chart keeps all 24 hourly bars, each labelled with its
  average grams per day.
- **Limit lines are now red dashed** (were amber/orange) in both the PDF
  (`.chart .limit` → `#c83232`) and the app (`AlcoholBarChart` limit line →
  `dangerRedColor()`), matching the over-limit cue colour.
- **Body weight is integer-only.** Settings accepts whole numbers only
  (`GramsInputDialog(allowDecimal = false)`) and displays an integer; the PDF shows
  the weight as an integer (`roundToInt()`).
- **Time-of-day chart: all hours labelled, below the axis.**
  `assets/report_template.html` + `util/PdfReportBuilder.kt`: the chart is split into
  a bars row (`HBARS`) and a separate axis row (`HLABELS`) rendered *beneath* the
  baseline, and every hour 0..23 is labelled (previously only every third hour, and
  the labels sat inside the plot area where tall bars overlapped them). New CSS
  `.barchart` family; the obsolete `.chart.hours` variant was removed.
- **Weekday profile is now a bar chart.** Replaces the former one-row table with a
  bar chart analogous to the hour chart: bars (`WDBARS`) with the average value
  printed above each bar and the weekday names on the axis row (`WDLABELS`). Bar
  heights leave 15 % headroom so the value label above the tallest bar still fits.
- **Category breakdown layout.** The table is now half width (`.cat-row` /
  `.cat-table`, ~48 %) with the donut occupying the right half.

### Tests

- `test/.../util/PdfReportDataTest.kt`: added a test for `maxPerDay` / `maxPer7Days`.
- `PdfTemplatePlaceholderTest` continues to guard the template ⇄ builder placeholder
  contract; it automatically covers the new `HBARS`/`HLABELS`/`WDBARS`/`WDLABELS`/
  `PIE_SLICES`/`C_COLOR`/`H_VALUE` placeholders and the removal of the old
  `HOURS`/`WEEKDAY_*` blocks.

---

## v0.65.0

Feature release. Adds two new charts to the Statistics screen, reworks the PDF
report's time-of-day section into a 24-hour chart, adds median KPIs alongside the
existing means, fixes the per-day average of partial (started) months, shows the
running Android version in the PDF footer, makes the light-mode "caution" colour
clearly yellow, and adds a build-time guard that every PDF template placeholder is
initialised. The PDF layout/design in `assets/report_template.html` was also
updated (visual styling), independently of the structural edits listed here.

### Added

- **`ui/component/ChartComponents.kt` – `ValueBarChart`.** A small, reusable
  vertical bar chart (no time axis, no limit line, no abstinence ticks) used by the
  Statistics screen for the new hour-of-day and weekday charts. A bar of value ≤ 0
  is drawn as an empty slot, which is how "no data for this slot" is shown.
- **Statistics screen: hour-of-day and weekday charts.** Above the category donut
  the screen now shows, in order, a **24-hour** chart (grams per clock hour) and a
  **weekday** chart (average grams per weekday, rotated to the locale's first
  weekday). Each card is hidden when it has no data.
  - `ui/screen/StatsViewModel.kt`: `StatsUiState` gains `hourlyGrams` (24 buckets),
    `weekdayOrder` (ISO 1..7, rotated) and `weekdayAverages` (null = weekday never a
    drink day); all computed in the existing `combine`.
  - `ui/screen/StatsScreen.kt`: renders the two new cards; weekday labels use the
    locale's short `DayOfWeek` names.
- **PDF report: median KPIs.** Beside the mean tiles the report now prints
  **Median per Day**, **Median per Drinking Day**, **Ø Drinking Days/Month** and
  **Median Drinking Days/Month**. Medians are robust to the occasional very heavy
  day that can inflate a plain average.
  - `util/PdfReportData.kt`: adds `medianPerDay`, `medianPerDrinkDay`,
    `avgDrinkDaysPerMonth`, `medianDrinkDaysPerMonth`, plus a private `median()`
    helper (even count → mean of the two central values).
  - `util/PdfReportBuilder.kt`: emits the four extra KPI tiles.
  - `res/values*/strings.xml`: new keys `pdf_kpi_median_day`,
    `pdf_kpi_median_drink_day`, `pdf_kpi_avg_drink_days_month`,
    `pdf_kpi_median_drink_days_month` – translated into **all 21 locales**.
- **PDF report: 24-hour time-of-day chart.** The former "Ø first/last drink" and
  "share before/after 17:00" figures are replaced by a 24-bar chart of **grams of
  pure alcohol per clock hour** (0..23), mirroring the on-screen chart.
  - `util/PdfReportData.kt`: adds `hourlyGrams: List<Double>` (24 buckets).
  - `util/PdfReportBuilder.kt`: fills the new `HOURS` repeat block (height = grams
    relative to the busiest hour; axis thinned to every third hour plus hour 23).
  - `assets/report_template.html`: new `.chart.hours` CSS variant and `HOURS`
    repeat block; the old before/after meta table is removed.
  - `res/values*/strings.xml`: new screen titles `stats_time_of_day`,
    `stats_weekday` – translated into **all 21 locales**.
- **`test/.../util/PdfTemplatePlaceholderTest.kt` (new).** A pure-JVM guard that
  reads `report_template.html` and `PdfReportBuilder.kt` as source, then fails the
  build if any `{{PLACEHOLDER}}` used in the template is never initialised in the
  builder (which would otherwise print as a raw `{{…}}` in the PDF). Comments are
  stripped before scanning, and a second test asserts a few structural placeholders
  are seen so a broken scan cannot pass vacuously.

### Changed

- **Light-mode "caution" colour is now clearly yellow.** `ui/theme/Color.kt`: the
  light-theme `warningColor()` changed from amber-700 `#B45309` to gold `#A67C00`.
  The previous amber still read as orange-red on the small dot (its red channel
  dominated its green), sitting too close to the danger red. `#A67C00` shifts the
  hue towards gold while staying compliant: **3.35:1** vs the light background
  (≥ 3:1 required for a non-text indicator; 3.82:1 vs a white card) and **2.38:1**
  vs the danger red `#960018`. Dark mode (`#E8A020`) is unchanged.
- **PDF footer 2 carries the running Android version.** `util/PdfReportBuilder.kt`:
  the line now reads *"… on Android &lt;release&gt;, …"* using
  `Build.VERSION.RELEASE` (falling back to the numeric API level when blank),
  replacing the static *"for Android"*.
- **`assets/report_template.html` – heavier documentation (teaching detail).**
  Added a top-of-body **placeholder & block inventory** and richer per-section
  comments. (Separately, the file's visual design was updated manually by the
  author; see the note at the top of this entry.)

### Fixed

- **Partial-month g/day no longer diluted by not-yet-recorded days.**
  `util/PdfReportData.kt`: the monthly **Ø g/day** now divides each month's grams by
  the number of that month's calendar days that actually fall inside the report
  period `[firstDate, lastDate]` (via `ChronoUnit.DAYS.between(…)`), not by the full
  calendar-month length. Previously a started first/last month counted its
  remaining, unrecorded days as abstinent and deflated the figure.

### Localisation

- **`res/values*/strings.xml`**: removed the four now-unused keys
  `pdf_meta_first_drink`, `pdf_meta_last_drink`, `pdf_meta_before_18`,
  `pdf_meta_after_18`; added the six new keys above, translated into every locale.
  Net change is uniform across all 21 files (`168 → 172` strings), so
  `LocaleSyncTest` stays green.

### Tests

- `test/.../util/PdfReportDataTest.kt`: removed the obsolete *"time-of-day
  percentages are complementary"* test (the fields no longer exist); added tests
  for the 24-bucket hourly histogram (sums to the total), the new medians/means,
  and the partial-month g/day fix.
- Added `PdfTemplatePlaceholderTest` (see *Added*).
- `test/.../ui/screen/StatsViewModelTest.kt`: hardened the three data-bearing tests
  (`single over-limit day`, `drink today extends the effective period`,
  `categoryBreakdown sums grams`) against two pre-existing, time/scheduling-dependent
  fragilities (no production behaviour changed):
  - They dated their entry with `LocalDate.now()` (the real calendar date) while the
    ViewModel derives its period from the LOGICAL day (shifted by `dayChangeHour`,
    `4` in these tests). Run between midnight and 04:00 the entry fell one calendar
    day outside the period, so the computed state had no data and the assertions saw
    zeros. They now date the entry with `DayResolver.today(4, 0)`, matching the
    period — which was the tests' own documented intent ("use today's date as the
    logical date").
  - They assumed the first Turbine emission is already the computed state rather than
    the `stateIn(WhileSubscribed)` seed. A small `awaitComputed()` helper now skips
    any leading seed emission.

---

## v0.64.0

Feature release. Reworks the consumption chart (Statistics screen **and** PDF
report) into a real, gap-free time axis that also shows abstinent days,
overhauls the PDF footers, and fixes a colour bug that made the traffic-light
"caution" state look like "danger" in light mode.

### Added

- **`domain/ChartBucketing.kt`** – a small, Android-free helper shared by the
  Statistics screen and the PDF export. It expands the sparse per-day summaries
  (which only contain days *with* entries) into a continuous, gap-free series of
  buckets covering every day in the period, so abstinent days become explicit
  zero buckets on a proper time axis. A bucket may be a day, a week or a month;
  its value is the **mean grams of pure alcohol per calendar day** inside the
  bucket. Using a per-day average (rather than a per-bucket total) keeps the
  dashed **daily-limit** reference line directly comparable across all
  granularities. The object is pure `java.time` + plain data, hence JVM
  unit-testable.

### Changed

- **Statistics chart now uses a real time axis incl. abstinent days.** WEEK and
  MONTH render one bar per day; YEAR aggregates into weekly buckets (≈ 52 bars)
  spanning `max(1 Jan, statsFrom) … today`. Days/weeks with zero consumption are
  no longer omitted: they are drawn as a small **green tick** at the baseline, so
  "recorded, nothing consumed" is visually distinct from a tiny bar. Axis labels
  are **thinned** for dense charts (≤ 12 buckets → one aligned label per bar;
  more → a handful of evenly spaced labels for context).
  - `ui/component/ChartComponents.kt`: `AlcoholBarChart` now takes a
    `List<ChartBucket>` and a `(ChartBucket) -> String` label function instead of
    a `List<DaySummary>`; renders the abstinence tick and the thinned labels.
  - `ui/screen/StatsViewModel.kt`: builds the bucket series (`chartBuckets`,
    `chartGranularity`) in the same `combine` that produces the rest of the UI
    state. The legacy `dataPoints` field is retained unchanged.
  - `ui/screen/StatsScreen.kt`: feeds `chartBuckets` to the chart and formats the
    label per period (weekday / day-of-month / month name).
- **PDF report: the monthly-average trend chart is replaced by the same
  time-axis chart and is now shown unconditionally** (previously hidden when
  there were fewer than two months of data). The export picks a granularity from
  the recorded span (`≤ 35 days` daily, `≤ 366 days` weekly, else monthly).
  Abstinent buckets are drawn as a green tick, matching the on-screen chart.
  - `util/PdfReportData.kt`: adds `chartBuckets` + `chartGranularity` (the
    existing `months` list is kept for the monthly *table*).
  - `util/PdfReportBuilder.kt`: emits the bucket bars with per-bucket tick
    visibility and thinned labels.
  - `assets/report_template.html`: adds the green-tick markup/CSS to the chart.
- **PDF footers overhauled.**
  - **Footer 1** (medical disclaimer) is now translated and present in **all 21
    locales** (`pdf_footer1`), with new wording: *"Estimates – not a medical
    diagnosis. Not for fitness-to-drive assessment or diagnostic purposes."*
  - **Footer 2** is **English-only and never translated**: it is built in code
    (no longer a string resource) and reads *"Created with Libellus Potionis
    v&lt;version&gt;, free software under the GNU GPL v3, WITHOUT ANY WARRANTY."*
    The version is **shortened** to `MAJOR.MINOR.PATCH` via
    `BuildConfig.VERSION_NAME.substringBefore("-")`, so the debug build's
    `-debug` suffix is stripped from the printed line.
  - The separate **running GPL footer was removed**; its GPL / no-warranty notice
    is folded into Footer 2.
  - Both footers are now **pinned to the bottom of their page** (page 1 / page 2)
    regardless of how much content precedes them, via per-page flex `.sheet`
    wrappers in the template.
- **Traffic-light "caution" colour fixed in light mode.** `ui/theme/Color.kt`:
  the light-theme `warningColor()` changed from amber-800 `#92400E` to amber-700
  `#B45309`. On a 12 dp dot the very dark amber-800 was almost indistinguishable
  from the danger red `#960018` (same red channel, little green), so the YELLOW
  state read as RED in light mode. amber-700 keeps a clearly amber hue and still
  clears the ≥ 3:1 contrast a non-text indicator needs (4.40:1 on the light
  background). Dark mode was already fine and is unchanged.
- **`res/values*/strings.xml`**: `pdf_footer1` updated/translated in all locales;
  `pdf_footer2` removed from all locales (key count drops uniformly 171 → 170, so
  `LocaleSyncTest` stays green).

### Assumptions

- **Per-day average.** Weekly/monthly bars show the bucket's mean grams per day
  (not the bucket total), so the daily-limit line stays meaningful at every
  granularity. A daily bar therefore equals that day's own total, unchanged.
- **Abstinent = zero in the period, including today.** The current (in-progress)
  day's empty bucket is also shown as a green tick.
- **Footer pinning is best-effort and tuned for A4** (`.sheet { min-height:
  267mm }` = A4 height minus the existing 14/16 mm `@page` margins). On US Letter
  the printable height differs; per-page footer placement should be verified by
  exporting a PDF and the `min-height` adjusted if needed.

### Known follow-ups

- The 19 non-German/English `pdf_footer1` translations are **best-effort and
  should be reviewed by native speakers** before release (consistent with the
  project's translation-quality policy).
- The PDF chart heading string `pdf_section_trend` ("…avg g/month") was left
  untouched to avoid a 21-locale translation churn; its unit wording is now
  slightly imprecise for daily/weekly charts and is a candidate for a future
  copy pass.

---

## v0.63.1

Bug-fix release. Resolves a runtime crash when switching between the bottom-bar
main screens, and hardens the app against a whole class of `java.time`
availability problems by enabling **core library desugaring**.

### Rationale

The app crashed with `java.lang.NoSuchMethodError: No virtual method
datesUntil(...)` shortly after a non-Today main screen was shown. The trigger is
`java.time.LocalDate.datesUntil(...)`, a Java 9 API used by `StatsViewModel`,
`DayResolver` and `PdfReportData`.

On Android, `java.time` is provided by the *updatable* ART mainline module
(`/apex/com.android.art/.../core-oj.jar`). `datesUntil()` was backported into a
later ART revision, so at one and the same API level a device whose module has
been updated (e.g. via Google Play system updates) exposes the method, while an
older emulator system image does not. This is exactly why the crash reproduced
on an API 30 emulator yet not on physical API 29/30 devices: identical API
level, different ART module version. Relying on the platform's `java.time` for
Java 9+ methods is therefore fragile across runtimes.

Core library desugaring removes this dependency on the device's module version:
D8/R8 rewrites the affected `java.*` calls to resolve against the bundled
`desugar_jdk_libs` implementation, which is shipped inside the APK and available
uniformly down to `minSdk`. This fixes the crashing call site **and** every
other `datesUntil()` (and future Java 9+ `java.time`) usage at once, with no
changes to the Kotlin sources.

### Fixed

- **App no longer crashes when switching main screens.** Enabling core library
  desugaring makes `LocalDate.datesUntil(...)` resolve on all supported
  runtimes, eliminating the `NoSuchMethodError` raised from
  `StatsViewModel.uiState` (and latent in `DayResolver` and `PdfReportData`).

### Changed

- **`app/build.gradle.kts`**: set `isCoreLibraryDesugaringEnabled = true` in
  `compileOptions` and added the `coreLibraryDesugaring(libs.desugar.jdk.libs)`
  dependency.
- **`gradle/libs.versions.toml`**: added the `desugar-jdk-libs` version
  (`2.1.5`, 2.x requires AGP 7.4.0+ — satisfied by AGP 9.2.0) and the matching
  `com.android.tools:desugar_jdk_libs` library coordinate.
- **Version bump to 0.63.1**: `versionName` (`app/build.gradle.kts`) and the
  version strings in the README title and the `proguard-rules.pro` header
  brought in sync with this CHANGELOG (enforced by the `version-check` build
  step); `versionCode` advanced `60 → 61` for the published APK.

### Notes

- Side effects of desugaring are limited to a small APK-size increase (only the
  used classes survive R8 shrinking in release builds) and an additional L8 dex
  step at build time. The supported device range is **unchanged**: desugaring
  does not raise `minSdk` (it works down to API 21, well below the project's
  `minSdk = 30`).

---

## v0.63.0

Localisation-scope release. Reduces the shipped languages to the set whose
translations can be quality-assured against the German/English originals for
**both** the UI strings and the in-app user guide, and adds a build-time guard
that keeps the two language sets identical from now on.

### Rationale

Previously the app shipped 51 translated locales, but only a subset could be
reviewed to a level the project is willing to vouch for across *both* surfaces
(strings and the long-form guide). Shipping a translation that cannot be
quality-assured is worse than not shipping it. This release keeps only the
languages that clear that bar for both surfaces, and writes the missing guides
for the kept languages so that every shipped language now has a guide.

### Changed

- **Supported languages reduced to 21** (20 locales + the English base):
  `cs da de el en es fr it ja ko nb nl pl pt pt-BR ro ru sv uk zh-CN zh-TW`.
- **Seven new user-guide translations** authored from the German source
  (`usersguide.de.md.in`), token placeholders preserved:
  `el ja ko ro uk zh-CN zh-TW`. Every kept language now ships a guide.
- `locale_config.xml` and `SupportedLocales.kt` trimmed to the kept set. The
  English base stays listed as `en` (no `values-en/`; it resolves to the base
  `values/`), which remains best practice for the per-app language picker.

### Removed

- **31 languages** dropped from `values-XX/`, `locale_config.xml` and
  `SupportedLocales.kt` (including Latin, whose guide template and rendered
  guide were removed too):
  `ar bg bn cy et fi fo ga ha he hi hr hu id is la lb lt lv mr ms mt sk sl sw ta te th tr vi yo`.

### Added

- **Build-time language-parity guard.** The guide-template language set and the
  string-resource language set must now be identical (both counting the base as
  English). Enforced on two layers: `render-guide.py` aborts the build (write
  and `--check` modes) with a precise diff, and a new `LocaleSyncTest` case does
  the same on the Gradle/CI path.

### Release bookkeeping

- `versionName` → `0.63.0`, `versionCode` → `60`; README title and
  `proguard-rules.pro` header updated to match (release-check.sh §1 /
  `make version-check`).

---

## v0.62.1

Maintenance release. Small UI consistency fixes, a clearer PDF export file name,
a menu-icon refresh, and refreshed German localisation.

### Fixed

- **PDF export file name now carries the `.pdf` extension.** The system "Save as
  PDF" dialog derives its default file name from the print-job name, which
  previously lacked an extension (e.g. `potillus_report_20260603_1430`).
  `PdfReportBuilder.jobName()` now appends `.pdf`, so the dialog pre-fills a
  complete file name.

### Changed

- **Unified the "danger" red across the Statistics screen.** The over-limit
  chart bars and the over-limit statistics (e.g. *Days over daily limit*,
  *over weekly limit*, *over drink-day limit*) and the rising-trend percentage
  now use `dangerRedColor()` — the same saturated red already used by the delete
  trash icons, traffic-light bullets and calendar over-limit dots — instead of
  the softer Material `error` colour. Export-error text still uses `errorColor()`,
  as it denotes a genuine error state rather than a statistic.
- **Overflow-menu icons refreshed.** The *License* entry now uses the open-book
  glyph (`MenuBook`), and the *Help* entry uses a medical-cross glyph
  (`LocalHospital`). The cross inherits the menu's content colour (it is not
  drawn red), so it blends with the active theme.
- **German localisation updated.** The German user's guide and
  `values-de/strings.xml` were revised (provided by the maintainer).

### Release bookkeeping

- `versionName` bumped to `0.62.1`, `versionCode` to `59`; README title and
  `proguard-rules.pro` header updated to match (release-check.sh §1).

---

## v0.62.0

Feature release. Replaces the fixed, configurable calendar week with a gliding
**7-day window** throughout the app, and removes the *"Week starts on …"* setting.

### Rationale

The weekly gram limit and the maximum-drink-days limit were previously evaluated
per calendar week, resetting on a user-chosen weekday. A fixed reset is easy to
game (heavy drinking split across the Sunday/Monday boundary landed in two
separate buckets) and does not reflect continuous health risk. A trailing 7-day
window — every day judged against itself plus the previous six days — never
resets, is stricter, and matches how low-risk-drinking guidance is generally
framed. Removing the setting also simplifies the Settings screen.

### Changed

- **All consumption metrics now use a trailing 7-day window** (today + the
  previous six calendar days), evaluated continuously:
  - *Today screen* — the "this week" gram total, drink-day count and the range
    label now cover the last seven days instead of the current calendar week.
  - *Statistics screen* — the **WEEK** period is now the rolling last-7-days
    window (its previous period, used for the trend %, is the seven days before
    that); MONTH and YEAR are unchanged. The period chip is relabelled **"7 days"**.
  - *Limits* — the traffic light and the "days over limit" statistics/PDF figures
    use the rolling window. `AlcoholCalculator.countLimitViolations` was rewritten
    from a per-calendar-week grouping into an O(n) two-pointer sliding window and
    no longer takes a `weekStartDay` parameter.
- **Calendar grid and PDF weekday profile** keep a fixed first weekday for *layout
  only*; it now follows the **device locale** (via the new
  `DayResolver.firstDayOfWeekIso()`) instead of the removed setting.
- User-facing strings reworded from "week" to "7 days" in the English base, German
  and — best-effort — all other bundled locales:
  `weekly_limit_grams`, `drink_days_setting`, `drink_days_label`,
  `limit_caption_week`, `days_over_weekly_limit`, `pdf_unit_g_per_week`,
  `pdf_kpi_over_weekly`, and the stats period label `week`.

### Removed

- The **"Week starts on <weekday>"** setting and its entire plumbing:
  `AppSettings.weekStartDay`, `IAppPreferences.setWeekStartDay`,
  `AppPreferences` key `week_start_day` (its stored value is now ignored — no
  migration needed; no DB schema change), `SettingsViewModel.setWeekStartDay`,
  and the Settings UI control.
- The obsolete `week_starts_on` string was deleted from the base locale **and all
  51 translations** so the `LocaleSyncTest` key-count/key-set checks stay green.

### Fixed

- Nothing was found broken during the accompanying review pass; see *Notes* for a
  pre-existing observation that was left as-is to keep this change focused.

### Tests

- `AlcoholCalculatorTest`: the `countLimitViolations` suite was rewritten for the
  rolling window, adding cases for window-boundary inclusivity (a 6-day gap shares
  a window, a 7-day gap does not), no gram carry-over beyond the window, and the
  drink-day count not resetting across a weekday boundary. Expected values were
  cross-checked against an independent reference implementation.
- `PdfReportDataTest`: the weekday-order test is now locale-deterministic (asserts
  against `DayResolver.firstDayOfWeekIso()` instead of a hard-coded Monday), so it
  passes regardless of the JVM default locale on the build machine.

### Notes / follow-ups

- **Translations:** the reworded limit strings were translated (best-effort) for
  every bundled locale, preserving each language's existing terminology and only
  swapping the period token to "7 days". Placeholders (`%1$s`) and locale key sets
  are unchanged, so the format-arg and `LocaleSyncTest` checks stay green. Two areas
  intentionally keep their English fallback for now, by agreement: the in-app
  user's guide (`usersguide*.md`) and the "crypto key unavailable" startup message.
- **Build not run in this environment.** The change was made and statically
  reviewed without executing the Android/Gradle toolchain (unavailable in the
  authoring sandbox). Please run `./gradlew testDebugUnitTest lint` before release.
- **Pre-existing observation (not changed):** `TodayViewModel` and `StatsViewModel`
  each retain a `java.time.LocalDate` import that already appeared unused before
  this change. Left untouched to avoid widening the diff; safe to drop later.

---

## v0.61.3

Bug-fix release. Fixes the PDF export (broken on every device since v0.61.0), the
limit progress bars turning red one step too early, a self-terminating comment in
the report template, and two build-tooling paths missed when the code base moved
into `android/`.

### Fixed

- **PDF export failed on every device** ("Export fehlgeschlagen"). The placeholder
  regex in `SimpleTemplate` left its closing braces unescaped (`\{\{(\w+)}}`). The
  desktop JVM regex engine — which local unit tests and `make test` run against —
  accepts a bare `}`, but the stricter ICU engine on Android devices
  (`com.android.icu.util.regex`) rejects it with `PatternSyntaxException`. That
  threw inside `SimpleTemplate`'s static initialiser, failed every
  `PdfReportBuilder.buildHtml` call, and the exception was swallowed by
  `runCatching`, surfacing only as a brief "export failed" banner. All braces are
  now escaped (`\{\{(\w+)\}\}`), which is valid under both engines.
- **Progress bars turned red when a limit was exactly *reached*** rather than
  exceeded. `LimitBar` (daily and weekly gram limits) and `DrinkDaysBar` coloured
  the bar red at `fraction >= 1.0`. Red now means *strictly over* the limit
  (`totalGrams > limitGrams` / `drinkDays > maxDrinkDays`), matching
  `AlcoholCalculator.countLimitViolations` and the calendar/chart over-limit
  markers. Reaching the limit exactly stays amber.
- **Self-terminating comment in `report_template.html`.** The documentation block
  at the top contained a literal `repeat:NAME` / `end:NAME` example written with
  real HTML-comment delimiters, whose first close sequence ended the doc comment
  early and leaked explanatory prose into the rendered page. The example is now
  described without literal delimiters. (This was previously masked by the PDF
  export crashing before it could render.)

### Fixed (build tooling, after the move into `android/`)

- `release-check.sh` looked for `CHANGELOG.md` / `README.md` in its own directory
  (`android/`), but they live at the repository root; it now reads `../CHANGELOG.md`
  and `../README.md`, matching the `version-check` Make target.
- The root `Makefile` `install` target referenced the pre-move APK path
  `potillus/app/build/...`; corrected to `android/app/build/...`.

### Added

- `SimpleTemplateInstrumentedTest` (androidTest) exercises `SimpleTemplate.render`
  on-device, so the JVM-vs-ICU regex divergence that caused the PDF crash is caught
  by `make test`'s `test-device` phase in future — the JVM unit test cannot detect
  it.

### Notes

- Root cause of the PDF regression was confirmed from an on-device logcat stack
  trace (`PatternSyntaxException` in `SimpleTemplate.<clinit>`); the pure pipeline
  (`PdfReportData`, template fill) was never at fault.
- The WebView + system-print path itself still warrants the usual on-device check
  now that the report can be generated again: trigger the PDF export, confirm the
  system print dialog opens, A4 pagination looks right, and "Save as PDF" works.

---

## v0.61.2

- Moved Android code base into subdirectory android/.

## v0.61.1

Bug-fix release: corrected off-by-one errors in the abstinence and average
calculations so that the **abstinent-days KPI**, the **average per day**, and the
**current / longest abstinence streaks** all agree and follow a single, consistent
rule for how the in-progress current day is treated:

- A day counts as a **drink day** the moment its first drink is logged. At that
  point today joins the observable period (with the amount consumed so far), so
  the period is one day longer than the completed days.
- A day counts as an **abstinent day** only once it has *finished* alcohol-free,
  i.e. it has reached the next day-change time without any consumption.
- While today has no drink yet it is undetermined (it may still become either a
  drink or an abstinent day) and stays out of the period entirely until it finishes.

Formally the period length is `effectivePeriodDays = completedDays + (today is a
drink day ? 1 : 0)`, and every rate / count is derived from it.

### Fixed

- **Current / longest abstinence over-counted by one day.** `DayResolver`'s
  tail-gap calculation (last drink day → today) counted the span *including* the
  last drink day. Since the last drink day is itself a drink day (and today is
  still in progress), both endpoints must be excluded; the gap now subtracts the
  drink day (`− 1`, floored at 0), matching the inter-drink-gap convention that
  already did this. Example: last drink two days ago, none since → current
  abstinence is now `1` (the single completed dry day), previously `2`.
- **Abstinent-days KPI and average-per-day were inconsistent with the
  drink-today case.** The Statistics view divided by / subtracted from a period
  that excluded the in-progress day, while `totalGrams` and `drinkDays` already
  *included* a drink logged today. Both are now derived from one explicit
  `effectivePeriodDays = completedDays + (today is a drink day ? 1 : 0)`:
  - `avgPerDay = totalGrams / effectivePeriodDays` — previously divided by the
    completed days only, so logging a drink today divided today's grams over a
    period that did not include today, overstating the daily average (and showing
    `0` when the period was just today). Now today extends the period exactly when
    it is a drink day.
  - `abstinentDays = effectivePeriodDays − drinkDays` (= completed dry days) — the
    in-progress day is never counted as abstinent. Per-drink-day averaging still
    includes today, as intended.

### Changed (documentation / tests)

- Clarified the `DayResolver` KDoc for both abstinence functions to state
  explicitly that the last drink day and the in-progress current day are both
  excluded, and rewrote the `StatsViewModel` comment around the previously
  misleading `coerceAtLeast(0)` note to document the single `effectivePeriodDays`
  model from which the average and the abstinent-day count are derived.
- Updated four `DayResolverTest` expectations to the completed-day semantics
  (last-drink-3-days-ago 3→2, drank-yesterday 1→0, statsFrom-ignored 3→2,
  tail-gap-included 9→8) and added regression tests for the reported scenario
  (drink on T−2, today T → current and longest tail = 1) plus a `StatsViewModelTest`
  case asserting that a drink logged today extends the period for `avgPerDay`.

### Notes

- Behaviour intentionally differs from a naive "days since last drink": the day
  immediately after a drink day shows `0` and becomes `1` only once the following
  day has also finished dry. This is the rule that makes the KPI and the streaks
  consistent.
- A drink logged before the day-change time on the "statistics start" date falls
  on the previous logical day and is correctly excluded from the period — this was
  already handled by the logical-date model and needed no change.

---

## v0.61.0

Reworked the PDF report so its **layout can be edited by hand** without touching
report code. The report is now authored as an HTML/CSS template under
`app/src/main/assets/`; computed numbers and localised labels are injected into
it at runtime, and the result is turned into a PDF through the **Android system
print dialog**. No third-party PDF library and no extra permission were added,
preserving the app's no-network, minimal-permission design.

### Changed (PDF export architecture)

- **Hand-editable template.** `app/src/main/assets/report_template.html` defines
  the two-page A4 report's structure and styling (fonts, colours, spacing, column
  widths, section order, page breaks). It uses `{{PLACEHOLDER}}` tokens and
  `<!-- repeat:NAME -->…<!-- end:NAME -->` row blocks; the contract is documented
  in the file header. Editing it requires only a rebuild, not code changes.
- **System print dialog instead of silent file write.** The PDF is produced by
  loading the report HTML into an off-screen `WebView` and calling
  `PrintManager.print(...)` (`WebViewPdfPrinter`). The user picks *Save as PDF*
  (or a printer) and the destination in the system UI.
- **Behaviour preserved.** All figures are computed by the new pure
  `PdfReportData` layer, which reuses `AlcoholCalculator` and `DayResolver`, so
  the PDF and the on-screen statistics still agree exactly.

### Added

- `util/PdfReportData.kt` – Context-free computation of every report figure
  (KPIs, monthly aggregates, category shares, time-of-day, weekday profile,
  streaks). Unit-tested on the JVM (`PdfReportDataTest`).
- `util/SimpleTemplate.kt` – a tiny, dependency-free HTML templating engine
  (scalar placeholders + repeat blocks, with HTML escaping). Unit-tested
  (`SimpleTemplateTest`).
- `util/PdfReportBuilder.kt` – resolves localised labels, formats numbers and
  fills the template; replaces the old canvas-drawing `PdfExporter`.
- `util/WebViewPdfPrinter.kt` – renders the report HTML via the system print
  dialog.

### Removed

- `util/PdfExporter.kt` – the previous `android.graphics.Canvas`/`PdfDocument`
  exporter that hard-coded the layout in Kotlin and drew each element by pixel
  coordinate.

### UX / behavioural notes

- The PDF export no longer writes a file straight to *Downloads* and no longer
  opens a share sheet; saving/sharing happen inside the system print dialog. CSV
  export is unchanged (still writes to Downloads and offers a share sheet).
- Long monthly tables are no longer truncated to a fixed row budget: the HTML
  report paginates automatically across pages. The `pdf_months_truncated` string
  is consequently no longer referenced (left in place; harmless).
- Per-page footers use the running GPL notice (fixed at the page foot) plus a
  trailing per-page disclaimer; this is a minor cosmetic change from the old
  absolute pixel placement and can be restyled in the template.

### Fixed / cleanup

- Removed the now-unreachable PDF branch from the Statistics share effect (PDF no
  longer flows through `shareTarget`).
- Updated stale KDoc in `ExportResult.kt` and `GplNotice.kt` that referenced the
  deleted `PdfExporter`.

### Known limitation (needs on-device QA)

- The `WebView` + `PrintManager` path is runtime-only and **cannot be exercised
  in unit tests or in this build environment**; it requires verification on a
  physical device / emulator (report renders, A4 pagination, "Save as PDF"). The
  pure pieces (`PdfReportData`, `SimpleTemplate`) are covered by JVM unit tests.

### Observation (not changed)

- `SettingsScreen` still contains a dead `application/pdf` branch in its share
  effect; Settings only exports JSON backups, so it never fires. Left untouched
  to keep this change scoped to the Statistics PDF export.

---

## v0.60.1

Lowered the minimum supported Android version from 15 to 11 to make the app
installable on a much larger share of devices, with no functional code changes —
every version-sensitive API the app uses is already available at the new floor.

### Changed (minimum supported Android version)

- **`minSdk` lowered from 35 (Android 15) to 30 (Android 11)** in
  `app/build.gradle.kts`. This roughly doubles the reachable worldwide install
  base (≈41% → ≈87%, per apilevels.com / Statcounter, April 2026 data) while
  `targetSdk` stays at 36. The previous floor was a policy choice (GrapheneOS
  Pixel devices), not a technical requirement: the codebase contains no
  `Build.VERSION.SDK_INT`, `@RequiresApi`, or `@TargetApi` usage, and every
  version-sensitive API it relies on is available at API 30 or lower
  (MediaStore Downloads + `RELATIVE_PATH` — API 29; Android Keystore AES-256-GCM
  — API 23; `androidx.biometric` — API 23; `WindowCompat` edge-to-edge insets —
  all levels; `AppCompatDelegate` locale switching — back-ported). API 30 is a
  *principled* floor rather than the lowest possible one: API 29 is the level at
  which the exporters can write to the public Downloads folder via `MediaStore`
  **without** any storage permission, so going lower would force a storage
  permission and break the app's minimal-permission design.
- **Bumped `versionCode` 53 → 54 and `versionName` 0.60.0 → 0.60.1**, kept in
  lock-step with the `proguard-rules.pro` header and the `README.md` title
  (enforced by `release-check.sh §1` / the `version-check` Make target).

### Changed (documentation)

- **Rewrote the `minSdk` rationale comment in `app/build.gradle.kts`** to a
  teaching-grade explanation: it now enumerates each version-sensitive API with
  its availability level, explains why no `SDK_INT` branches are needed, and
  documents the two graceful-degradation cases on API 30–32 (see below).
- **Added a "Supported Android versions" section to `README.md`** stating the
  Android 11+ requirement and the reason API 30 is the floor.
- **Added an API-level note in `AndroidManifest.xml`** explaining that
  `android:dataExtractionRules` is honoured only on API 31+ and is silently
  ignored on API 30, which is harmless because `android:allowBackup="false"`
  disables backup on every supported version.

### Notes (graceful degradation on API 30–32, no code change required)

- The **system per-app language picker** (`android:localeConfig`) is an API 33+
  feature. On Android 11–12 it is absent, but the in-app language selector in
  `SettingsScreen` (via `AppCompatDelegate`) works on every supported version.
- **Cloud/device-transfer backup** is disabled on all versions
  (`allowBackup="false"`), so the API-31+ `dataExtractionRules` being ignored on
  API 30 has no security or privacy impact.

### Follow-up (recommended before release)

- Run the unit **and** instrumented test suites (`MigrationTest`,
  `BackupRepositoryInstrumentedTest`, `EntryListItemUiTest`) on emulators for API
  30, 31/32, 33, and 34, plus a manual smoke test of CSV/PDF/backup export,
  biometric unlock, database encryption, and runtime language switching. This QA
  pass — not code changes — is the main remaining effort of the version drop.

---

## v0.60.0

A round of fixes and refinements: localized the device-transfer warning, a daily
limit rounding fix, build-tooling and in-app guide-viewer improvements, and
overflow-menu icons.

### Changed (version metadata)

- **Corrected the version strings, which had drifted.** `versionName` was still
  `0.58.0` (a leftover) and is set to `0.60.0`; `versionCode` is bumped 51 → 53;
  the `app/proguard-rules.pro` header is synced from `v0.56.0` to `v0.60.0`. These
  must stay in lock-step with the top CHANGELOG entry (enforced by
  `release-check.sh §1`).
- **Added the app version to `README.md`** (`v0.60.0` under the title), which had
  carried no version string at all.
- **New `version-check` target in the `Makefile`, wired into `prereq`.** It reads
  the version from the top-most `## vX.Y.Z` CHANGELOG entry and fails the build if
  `build.gradle.kts` (versionName), the `proguard-rules.pro` header, or the
  `README.md` title disagree — so version drift is caught on every local build,
  not just at the release gate.

### Changed (in-app guide viewer)

- **Paragraphs in the Markdown guide viewer now have a clear blank-line gap.**
  `MarkdownText` separated paragraphs with only 8.dp, which read as cramped; the
  inter-paragraph spacing is now 12.dp, matching the blank lines that separate
  paragraphs in the guide source.

### Changed (overflow menu)

- **Leading icons added to the overflow menu items:** a gear before Settings
  (`Icons.Filled.Settings`), a book before Help (`Icons.AutoMirrored.Filled.MenuBook`)
  and a gavel before License (`Icons.Filled.Gavel`). The icons are decorative
  (`contentDescription = null`) since each sits next to its text label. All three
  come from the already-included `material-icons-extended`.

### Fixed (invisible daily-limit exceedance from rounding)

- **Alcohol grams are now computed at 0.1 g precision instead of 0.01 g.**
  `AlcoholCalculator.calculateGrams` rounded to two decimals, so e.g. 188 ml at
  13.5 % stored 20.02 g. The UI displays one decimal ("20.0 g"), but the daily
  limit and binge checks compared the stored 20.02 g, so a 20 g limit showed as
  exceeded while the screen still read "20.0 g" — an exceedance the user could not
  see. `calculateGrams` now rounds to 0.1 g (new `roundTo1Decimal`), so the
  displayed value and every comparison use the same number. BAC keeps its 0.01 ‰
  precision (`roundTo2Decimals` is unchanged for `calculateBAC`).
- **No data migration.** Only newly logged entries are stored at 0.1 g; existing
  entries are left as-is (to be adjusted manually via a backup edit if desired),
  per request — no migration code was added.
- Unit tests in `AlcoholCalculatorTest` updated to the 0.1 g precision, including
  a regression test for the 188 ml / 13.5 % → 20.0 g case.

### Changed (guide build tooling)

- **`tools/render-guide.py` now discovers languages automatically** from the
  `docs/guide/usersguide*.md.in` templates instead of a hard-coded list, so
  adding a language (e.g. the new Latin guide) needs no script edit. The English
  default template is now the code-less `docs/guide/usersguide.md.in` (renamed
  from `usersguide.en.md.in`), mapping to the unqualified `values`/`raw`; a tag
  maps to `values-<q>`/`raw-<q>` with the Android region form (`pt-BR` →
  `pt-rBR`).
- **Outputs are regenerated on a timestamp basis:** an in-app `usersguide.md` is
  rewritten only when its template **or** the matching `strings.xml` is newer
  than the existing file. `--check` still compares content (for CI).
- Dropped the dead code for the former root-level `USERSGUIDE.md` /
  `USERSGUIDE-de.md` copies (those outputs were already removed) and updated the
  `Makefile` `guides` comment accordingly.

### Changed (localized device-transfer warning)

- **Translated the device-transfer warning** (`device_transfer_warning_title` /
  `device_transfer_warning_body`), which had been English in every locale, into
  the major languages: de, fr, es, it, nl, pt, pt-BR, ru, pl, sv, da, nb, cs, fi,
  el, tr, uk, hu, ro, sk, ja, ko, zh-rCN, zh-rTW, ar, id (26 locales). The
  remaining locales keep the English text for now. The wording uses the app's
  neutral/impersonal register (no informal/formal pronoun, matching the existing
  strings), and the "Settings → …" breadcrumb uses each locale's actual
  `settings` label so it matches what the app shows.

---

## v0.59.0

Toolchain modernisation for 2026, delivered as a sequence of incremental,
build-on-each-other steps under one version:

  - **Part 1:** raise the Kotlin compiler, KSP, the Compose BOM
    and the Kotlin-coupled test libraries, and adapt the instrumented UI tests
    to the Compose v2 testing APIs. The build system (AGP 8.13.2, Gradle
    8.14.5) is deliberately left untouched.
  - **Part 2:** Gradle 8.14.5 → 9.4.1 + AGP 8.13.2 → 9.2.0
    together (lock-step major upgrade), removing the now-redundant
    `kotlin-android` plugin and adopting AGP 9 built-in Kotlin, with the Kotlin
    compiler version pinned to 2.3.21 via a buildscript override; plus the AGP 9
    `srcDirs` → `directories` source-set fix.
  - **SQLCipher migration (this change):** move off the deprecated, EOL
    `android-database-sqlcipher` to the maintained `sqlcipher-android` for
    16 KB page-size compliance.
  - **Part 3 — hygiene (this change):** consolidate the inline-pinned
    dependency versions into the version catalog and drop the obsolete
    `suppressUnsupportedCompileSdk` flag. (Enabling the Gradle configuration
    cache is kept as a separate, optional follow-up.)
  - **Dependency freshening:** raise the explicitly-versioned
    AndroidX core libraries (core-ktx, activity-compose, lifecycle) to current
    stable. (navigation-compose stays at 2.8.9 — androidx.navigation 2.9 is still
    in alpha, so 2.8.9 is the current stable.)
  - **SQLCipher / SQLite / Room currency (this change):** raise the database
    stack to the current coordinated set — sqlcipher-android 4.15.0,
    androidx.sqlite 2.6.2 and Room 2.8.4 — and drop the merged room-ktx artifact.

### Changed

- **Kotlin 2.0.21 → 2.3.21.** Current patch of the Kotlin 2.3 line. Because the
  Compose compiler plugin and the serialization plugin are versioned via the
  same catalog key, this also moves the Compose compiler to 2.3.21, which is the
  compiler that pairs with the Compose 1.11 runtime (see below).
- **KSP 2.0.21-1.0.28 → 2.3.7.** Adopts KSP's new, Kotlin-decoupled version
  scheme (since KSP 2.3.0 a single release supports Kotlin `2.2.*` and newer), so
  the version no longer mirrors the compiler version.
- **Compose BOM 2025.05.01 → 2026.04.01.** Pins the core Compose modules to
  1.11.0.

### Fixed

- **Serialization runtime incompatible with the new compiler.**
  `kotlinx-serialization-core` was pinned to 1.7.3 (built against Kotlin 2.0).
  Kotlin's forward-compatibility rule (a runtime built with 2.Y supports 2.(Y+1)
  but not 2.(Y+2)) makes 1.7.3 invalid under the 2.3.21 compiler. Bumped to
  1.11.0 (built against Kotlin 2.2.x).
- **Coroutines test runtime incompatible with the new compiler.**
  `kotlinx-coroutines-test` 1.9.0 (Kotlin 2.0) falls under the same rule; bumped
  to 1.11.0. Dispatcher semantics are unchanged, so the JVM unit tests behave
  identically.
- **`kotlin-test` version drift.** The literal `2.0.21` test dependency was
  updated to `2.3.21` to match the compiler and avoid a metadata mismatch.
- **Build script: removed `kotlinOptions` String setter.** The Kotlin 2.3
  Gradle plugin turns `android { kotlinOptions { jvmTarget = "21" } }` from a
  deprecation warning into a hard script-compilation error. Migrated to the
  type-safe `compilerOptions` DSL in a new top-level `kotlin { }` block
  (`jvmTarget.set(JvmTarget.JVM_21)`), with the matching
  `org.jetbrains.kotlin.gradle.dsl.JvmTarget` import. This DSL migration was
  originally earmarked for part 3 but is mandatory here because the 2.3 compiler
  makes the old form non-compiling.
- **Instrumented UI tests under the Compose v2 testing APIs.** BOM 2026.04.01
  enables the v2 testing APIs by default, switching the Compose test
  dispatcher from `UnconfinedTestDispatcher` (eager) to `StandardTestDispatcher`
  (queued). In `EntryListItemUiTest`, the two click tests asserted on a plain
  counter immediately after `performClick()`; that read could now race the
  queued click. The assertions are wrapped in `composeTestRule.runOnIdle { }`,
  which drains the queue before reading. Node-based assertions
  (`assertIsDisplayed()`) were left unchanged because finders synchronise
  implicitly.
- **Stale documentation.** The `libs.versions.toml` comment claiming KSP must
  use the `<kotlin-version>-<ksp-patch>` format and "must exactly match the
  Kotlin version" was corrected to describe the decoupled scheme.

### Notes

- Building part 1 on AGP 8.13.2 emits a deprecation warning about the
  `org.jetbrains.kotlin.android` plugin: from Kotlin 2.3.0 onward the plugin is
  redundant on AGP versions that ship built-in Kotlin. This is expected and is
  resolved in part 2; it is a warning, not an error, on AGP 8.x.
- Room (2.7.1) and SQLite (2.4.0) are unchanged and run on KSP 2.3.7. A full
  compile + `connectedDebugAndroidTest` on the target toolchain is the
  authoritative verification step for this part.

### Changed (part 2 — build system)

- **Gradle 8.14.5 → 9.4.1.** Mandatory lock-step partner for AGP 9: moving from
  AGP 8.x to 9.x requires a Gradle 8.x → 9.x major upgrade that cannot be
  bypassed. 9.4.1 is the version Google's current AGP setup guide recommends.
- **AGP 8.13.2 → 9.2.0.** Major upgrade. JDK 17+ (we use 21) and compileSdk up
  to API 36.1 (we use 36) are satisfied.
- **Adopted AGP 9 built-in Kotlin; removed the `kotlin-android` plugin.** AGP 9
  compiles Kotlin itself, so `org.jetbrains.kotlin.android` is no longer applied
  (app and root) nor declared in the version catalog. Keeping it under AGP 9
  would be a hard error (duplicate `kotlin` extension), not just a warning —
  this resolves the deprecation warning noted for part 1.
- **Pinned the built-in Kotlin compiler to 2.3.21 via a buildscript override.**
  AGP 9 bundles KGP 2.2.10 as a floor. To keep the 2.3.21 compiler established
  in part 1 (the Compose/serialization plugins and test libraries are aligned to
  it), the root `build.gradle.kts` adds the officially documented override
  `buildscript { dependencies { classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.3.21") } }`.
  The Compose, serialization and KSP plugins continue to be applied via the
  version catalog and are unchanged.
- **Fixed AGP 9 source-set deprecation.** The first green AGP 9 build emitted
  `'fun srcDirs(...)' is deprecated. Use 'directories' mutable set instead`.
  The androidTest schema-assets line was migrated from
  `assets.srcDirs(files("$projectDir/schemas"))` to
  `assets.directories += "$projectDir/schemas"`. Same resolved location, AGP 9
  DSL. (The build also logs an informational note that `libsqlcipher.so` and two
  other prebuilt native libraries cannot be stripped of debug symbols; that is
  expected and requires no change.)

### Notes (part 2)

- The buildscript Kotlin pin is a hard-coded literal because a Gradle
  `buildscript` block cannot read the version catalog. It must be kept in sync
  with `kotlin` in `libs.versions.toml` on every future Kotlin bump; both spots
  carry a comment to that effect.
- KGP 2.3.21 is officially fully tested with Gradle only up to 9.3.0, so on
  9.4.1 benign Kotlin deprecation warnings are possible. Dropping the wrapper to
  9.3.0 would avoid them if AGP 9.2 accepts it; 9.4.1 was chosen to match
  Google's recommendation.
- KSP (2.3.7) is applied via the plugins block as before. Because 2.3.7 is above
  AGP's built-in KSP floor it is not force-upgraded; if a build ever reports a
  KGP/KSP mismatch, add the commented KSP `classpath(...)` line provided in the
  root `build.gradle.kts`.
- `android.builtInKotlin=false` is deliberately NOT set: built-in Kotlin is
  adopted, not opted out of (the opt-out is removed in AGP 10, mid-2026).
- No use of the removed AGP 9 variant APIs (`applicationVariants`, etc.) was
  found, so no DSL changes were required to configure under AGP 9. As always, a
  full compile + `connectedDebugAndroidTest` on the target toolchain is the
  authoritative verification step.

### Changed (SQLCipher migration — 16 KB page-size compliance)

- **`net.zetetic:android-database-sqlcipher:4.5.4` → `net.zetetic:sqlcipher-android:4.10.0`.**
  The old artifact was deprecated in 2022 and reached end-of-life in 2023; its
  native libraries are not built for 16 KB memory pages. Android 15+ devices can
  run with 16 KB pages and Google Play requires 16 KB support for apps targeting
  Android 15+, so the unaligned `libsqlcipher.so` (flagged by the strip step in
  the build log) is a real runtime/release risk. The maintained replacement
  `sqlcipher-android` ships 16 KB-aligned libraries (since 4.6.1).
- **`AppDatabase.kt` adapted to the new API.** The package moved from
  `net.sqlcipher.database` to `net.zetetic.database.sqlcipher`, and the Room
  integration class changed from `SupportFactory` to `SupportOpenHelperFactory`
  (same constructor: a passphrase `ByteArray`, zeroed immediately after). The
  new library also requires the native library to be loaded explicitly, so
  `System.loadLibrary("sqlcipher")` is called once before the factory is built.
  No schema, passphrase, or Keystore logic changed, so existing encrypted
  databases open unchanged.
- **Instrumented test (`MigrationTest.kt`) migrated too.** It also used the old
  `net.sqlcipher.database.SupportFactory`. Switched to `SupportOpenHelperFactory`
  with `System.loadLibrary("sqlcipher")` in the companion `init`. IMPORTANT
  semantic change: the old `SupportFactory(passphrase, hook, clearPassphrase)`
  third argument was `clearPassphrase` (the test passed `false` to keep the
  passphrase reusable across multiple opens); the new
  `SupportOpenHelperFactory(passphrase, hook, enableWriteAheadLogging)` third
  argument is unrelated (WAL). The new library has no passphrase-clearing toggle
  and does not zero the passphrase, so the single-argument constructor is now
  used and is safe across the test's repeated opens.

### Notes (SQLCipher migration)

- `androidx.sqlite` is deliberately left at 2.4.0 to keep this step a focused
  artifact swap. Newer `sqlcipher-android` releases (4.15.0) are paired with
  `androidx.sqlite` 2.6.2; raising both together is deferred to the optional
  dependency-freshening step. If the build reports a `SupportSQLiteOpenHelper`
  API mismatch, bump `sqlite` alongside.
- If Gradle fails to resolve the native AAR, append `@aar` to the `sqlcipher`
  library coordinate (a comment in `libs.versions.toml` notes this).
- Verification is necessarily on-device: a `connectedDebugAndroidTest` run
  (which exercises the encrypted Room database and the migration test) confirms
  the native library loads and decryption still works.

### Changed (part 3 — hygiene)

- **Consolidated inline-pinned dependency versions into the version catalog.**
  Eight dependencies were previously declared as string literals in
  `app/build.gradle.kts` (`androidx.tracing`, `junit`, `kotlin-test`,
  `kotlinx-coroutines-test`, `turbine`, `org.json`, `androidx.test:runner`,
  `espresso-core`). They now live in `gradle/libs.versions.toml` and are
  referenced via `libs.*` accessors. Resolved versions are unchanged, so this is
  behaviour-neutral; the per-dependency rationale comments stay at the usage
  site. `kotlin-test` now references the `kotlin` version (`version.ref`), so it
  can no longer drift from the compiler version.
- **Removed the obsolete `android.suppressUnsupportedCompileSdk=36` flag.** It
  silenced an "untested compileSdk" warning that no longer applies: AGP 9.2
  officially supports compileSdk up to API 36.1, and the project uses 36.

### Notes (part 3)

- This step touches only `gradle.properties`, the version catalog and dependency
  declarations; no source code changes. It is behaviour-neutral and should not
  alter the build graph beyond removing the (now unnecessary) warning
  suppression.
- The Gradle configuration cache (suggested by the build output) is intentionally
  not enabled here. It can surface incompatibilities (e.g. with the buildscript
  Kotlin override, KSP, or Room) and is best introduced as its own isolated,
  separately-tested change.

### Changed (dependency freshening — AndroidX core)

- **core-ktx 1.13.1 → 1.18.0**, **activity-compose 1.9.0 → 1.12.3**,
  **lifecycle 2.8.2 → 2.10.0** (current stable as of mid-2026). These were a year
  or more behind the SDK-36 / Kotlin-2.3 / Compose-1.11 baseline. Verified against
  the official AndroidX release notes; pre-release versions were deliberately
  avoided (core 1.19, lifecycle 2.11 are still rc/beta).
- **navigation-compose kept at 2.8.9.** androidx.navigation 2.9.x is still in
  alpha, so 2.8.9 is the current stable — no bump warranted. (Not to be confused
  with the JetBrains `org.jetbrains.androidx.navigation` 2.9.x KMP fork, which is
  a different artifact.)

### Notes (dependency freshening)

- This is a pure version bump in the catalog; no source changes. Still, it crosses
  real minor versions (notably lifecycle 2.9's Kotlin-Multiplatform repackaging),
  so it must be built and instrument-tested. The APIs this app uses
  (`collectAsStateWithLifecycle`, `viewModel()`, `setContent`) are unchanged.
- activity-compose and lifecycle were bumped together on purpose: activity 1.12
  depends transitively on a recent lifecycle, so pinning lifecycle to 2.10.0 keeps
  the catalog's declared version aligned with what actually resolves.
- Other explicitly-versioned libraries were left as-is: appcompat 1.7.0 and
  biometric 1.1.0 are the current stables; Room 2.7.1, DataStore 1.1.1 and the
  SQLCipher/SQLite pair are working and were out of scope here. Raising the
  SQLCipher/SQLite pair to the very latest (`sqlcipher-android` 4.15.0 +
  `androidx.sqlite` 2.6.2) remains available as a separate, coordinated change.

### Changed (SQLCipher / SQLite / Room currency)

- **sqlcipher-android 4.10.0 → 4.15.0**, **androidx.sqlite 2.4.0 → 2.6.2**,
  **Room 2.7.1 → 2.8.4** — bumped together as one coordinated set. 2.6.2 is the
  androidx.sqlite version Google documents for Room 2.8.4 and Zetetic documents
  for sqlcipher-android 4.15.0, so the three move in lockstep to avoid a
  Room ↔ androidx.sqlite binary-compatibility skew.
- **Removed the `room-ktx` dependency and catalog entry.** As of Room 2.8 the
  room-ktx APIs (coroutine/Flow support, suspend DAOs) are merged into
  room-runtime and the standalone artifact is empty. No code change is needed —
  the same APIs now resolve from room-runtime.
- **Corrected a stale comment** in `app/build.gradle.kts` that still referred to
  the old `SupportFactory` and an `@aar` classifier; it now describes
  `SupportOpenHelperFactory` and the explicit `System.loadLibrary` step.

### Notes (SQLCipher / SQLite / Room currency)

- Room 2.8.x is the final Room 2.x line (maintenance mode); Room 3.0 is a
  separate package (`androidx.room3`) and is deliberately not adopted. 2.8.x
  retains the SupportSQLite APIs, so the SQLCipher `SupportOpenHelperFactory`
  integration in `AppDatabase` and `MigrationTest` works unchanged.
- This crosses a Room minor version and the androidx.sqlite 2.5→2.6 line, so it
  must be built and instrument-tested. The migration test (which opens the
  encrypted DB through SQLCipher and validates the Room schema migration) is the
  key check. No schema, DAO, entity, passphrase or Keystore code changed.
- Verified against the official Room and sqlcipher-android documentation; no
  pre-release versions were used.

### Changed (Compose v2 test rule)

- **`EntryListItemUiTest` now uses the v2 `createAndroidComposeRule`.** Since
  Compose 1.11 (Compose BOM 2026.04.01, adopted in part 1) the v1 test
  environment factories are deprecated in favour of the
  `androidx.compose.ui.test.junit4.v2` package. Only the import changed: the v2
  factories are the sole part of the testing surface that moved, while the
  finders, actions, `setContent` and `runOnIdle` stay on their existing APIs. The
  v2 environment runs composition on a StandardTestDispatcher; the
  recomposition-dependent assertions were already wrapped in `runOnIdle {}` in
  part 1, so no test logic needed to change.

### Fixed (false "Settings not restored?" on first install)

- **The device-transfer warning no longer fires on a genuine first install.**
  Previously the warning was driven by a heuristic — install younger than 15
  minutes AND `language` empty AND `weightKg == 0.0` — and a fresh install
  satisfies all three, so every first launch showed "Settings not restored?".
  The check now uses an authoritative signal instead: a sealed passphrase
  envelope is *present* in storage (restored from an Android backup) but cannot
  be *decrypted* with this device's Keystore key — the actual signature of a
  transfer where the hardware-bound key did not migrate. A first install has no
  envelope at all, so the warning stays silent.
- **Implementation.** `AppDatabase` gains two read-only probes,
  `hasSealedPassphrase()` and `canOpenSealedPassphrase()` (the latter attempts
  `KeystoreSecretStore.open` and returns false on `GeneralSecurityException` /
  malformed blob, zeroing the plaintext). `PotillusApp.checkForDeviceTransferFailure()`
  consumes them; the pure decision `shouldWarnDeviceTransfer(present, decryptable)`
  is `present && !decryptable`. The install-recency window (`INSTALL_RECENCY_MS`)
  and the settings-based heuristic are removed, and `onCreate` no longer needs the
  pre-write settings snapshot for this check.
- **Tests.** `PotillusAppHeuristicTest` was rewritten to lock in the new truth
  table (present+undecryptable → warn; absent → silent; present+decryptable →
  silent). It remains a pure JVM test.
- **Display language unchanged but worth noting:** the dialog is shown via
  `stringResource`, i.e. resolved against the system/configuration locale. That is
  the correct behaviour here, because in the failure scenario the user's stored
  language preference lives in the encrypted store that cannot be read. The
  message strings are currently English in every locale (translation is tracked
  separately).

### Added

- **`docs/guide/usersguide.la.md.in` — a Latin translation of the user guide.**
  The build-time renderer (`tools/render-guide.py`) now emits the Latin guide to
  `res/raw-la/usersguide.md` (with `values-la` for the on-screen labels), so the
  app shows it for users whose per-app language is Latin.

---

## v0.58.0

Added a localized, build-time-templated in-app user guide system and an
in-app viewer for it; replaced the per-screen settings gear with a single
overflow (burger) menu that also opens the guide and the license; embedded a
GPLv3 notice in the JSON and PDF exports; and fixed a text bug in the English
source guide.

### Added

- **In-app user guides under `res/raw`.** The user guide now ships as a raw
  resource (`R.raw.usersguide`) so it can be displayed inside the app later. As
  with `strings.xml`, the file is locale-qualified: the English guide lives in
  `res/raw/usersguide.md` (the resource default) and each translated guide in
  `res/raw-<locale>/usersguide.md`. Because the app sets a per-app locale via
  `AppCompatDelegate.setApplicationLocales`, Android resolves the matching
  `raw-xx` directory automatically — exactly the mechanism already used for
  strings.
- **Single-source guide templates** in `docs/guide/usersguide.<lang>.md.in`.
  Every on-screen name (screen titles, settings-section headers) is written as a
  `{{key}}` token instead of a hard-coded word, so a guide can never drift away
  from the label the app actually shows.
- **Build-time renderer `tools/render-guide.py`.** It resolves each `{{key}}`
  against the *matching* locale's `strings.xml`, undoes Android's string
  escaping (e.g. French `Aujourd\'hui` → `Aujourd'hui`), and fails loudly on an
  unknown key. It writes the in-app `res/raw[-xx]/usersguide.md` copies (license
  header stripped for clean on-device rendering) and regenerates the
  repository-facing `USERSGUIDE.md` / `USERSGUIDE-de.md` (header kept, plus a
  "generated — do not edit" banner). Writes are content-diffed (no needless
  touches) and a `--check` mode lets CI verify the committed guides are in sync.
- **Curated 14-language core set** with real translations: English (base), plus
  German, French, Spanish, Italian, Dutch, Portuguese, Brazilian Portuguese,
  Russian, Polish, Swedish, Danish, Norwegian Bokmål and Czech. Every other
  supported language deliberately has no `raw-xx`, so the app falls back to the
  English guide via normal resource resolution rather than showing
  machine-quality text.
- **Makefile integration.** A new `guides` target regenerates the guides and is
  now a prerequisite of every build, so the shipped guides are always in sync;
  `check-guides` runs the renderer in verification mode for CI. Help text and
  `.PHONY` updated accordingly.
- **Overflow menu (`AppOverflowMenu`).** The four main screens previously each
  carried an identical settings gear in their top bar. They now share one
  composable that shows a burger icon (`Icons.Default.Menu`) opening a dropdown
  with three entries: **Settings**, **Help** and **License**. The menu holds no
  navigation logic of its own — it invokes callbacks supplied by
  `AppNavigation` — so the four screens stay free of navigation dependencies.
- **In-app guide & license viewer (`DocumentViewerScreen`).** A single,
  reusable read-only screen backs both new menu entries. *Help* renders the
  locale-resolved `R.raw.usersguide` as Markdown; *License* shows
  `R.raw.license` as plain monospaced text. Both are pushed on top of Home with
  an Up arrow, mirroring Settings, and are wired as two new type-safe routes
  (`Screen.Help`, `Screen.License`).
- **Minimal Markdown renderer (`MarkdownText`).** A small, dependency-free
  composable renders exactly the Markdown subset the guides use (ATX headings,
  reflowed paragraphs, `[text](url)` links). Adding no third-party library keeps
  the app dependency-light, in line with its privacy-minimal design; the
  unsupported-syntax boundary is documented in the file.
- **Bundled license (`res/raw/license.md`).** A verbatim copy of the
  project-root `LICENSE.md`, produced by a `cp` step in the Makefile's `guides`
  target. It is intentionally **not** translated or locale-qualified, so
  `R.raw.license` always resolves to the original (English) GPLv3 text;
  `check-guides` now also fails if the copy drifts from the root file.
- **GPLv3 notice in exports (`GplNotice`).** Exports now carry the project's
  GPLv3 header as a non-evaluated notice. The **JSON backup** gains a top-level
  `_comment` array (JSON has no comment syntax, and the importer already ignores
  unknown keys, so this round-trips safely). The **PDF report** gains a small
  one-line notice in the footer of every page (`FOOTER_RESERVE` raised from 30
  to 42 pt to make room). The **CSV export deliberately carries no notice**, as
  CSV has no portable comment convention and a leading line would surface as a
  spurious data row in spreadsheet importers.
- **Three new UI strings** (`menu`, `help`, `license`) added across all 52
  locales (the base plus 51 translations), so per-locale `strings.xml` parity is
  preserved (now 172 strings each, up from 169).

### Changed

- **Settings is now reached via the overflow menu**, not a dedicated gear icon.
  The gear `IconButton` was removed from all four main screens; `StatsScreen`'s
  now-unused icon imports were dropped.
- **Guide wording updated to match the new menu.** Every guide template's
  "gear/cog icon" phrasing was replaced with "menu icon (☰)" and the guides
  regenerated, so the shipped text describes the actual UI.

- **English source guide had stray heading echoes.** Several paragraphs ended
  with a duplicated fragment of the following heading (e.g. "… functions of the
  app. Highlights", "… on a Fairphone 4. \"Today\" Screen", "… the Widmark
  formula. Limits"). These were removed while templating; the German guide was
  already clean.

### Notes

- The in-app Markdown *viewer* deferred when the guide files were first added
  is now implemented (see `DocumentViewerScreen` / `MarkdownText` above), so the
  guide is readable directly inside the app rather than only via
  `resources.openRawResource`.
- This version *does* change `strings.xml`: three UI strings were added to every
  locale, raising the `LocaleSyncTest`-checked parity from 169 to 172 strings.
  `res/raw` (the guide and license copies) remains outside that test.
- The GPLv3 notice embedded in exports is kept in English on purpose — it is a
  legal notice rather than UI chrome, so it lives in code (`GplNotice`), not in
  the translatable `strings.xml`.

---

## v0.57.0

Replaced the gender + guideline-mode limit system with three always-active,
user-defined limits.

### Changed

- **Limits are now three independent values that always apply together:** a
  daily limit (g), a weekly limit (g) and a maximum number of drink days per
  week. Defaults are 20 g / 100 g / 5 days. The previous WHO / DHS / custom
  *limit mode* selector and the separate daily-vs-weekly *gram mode* toggle have
  been removed; all three limits are always evaluated at once.
- **Biological sex is no longer stored or used.** The Widmark BAC estimate now
  uses a fixed, conservative distribution coefficient r = 0.6 (the smaller of
  the two classic coefficients), which yields the higher — i.e. worst-case —
  blood-alcohol estimate. Body weight is still used.
- **Binge threshold** is now the sex-independent constant 48 g
  (`AlcoholCalculator.BINGE_THRESHOLD`), replacing the former per-sex values.
- **Today screen** now shows three progress bars (daily grams, weekly grams,
  drink days) instead of one gram bar plus the drink-days bar.
- **Traffic-light capacity dots** consider all three limits. Free servings are
  the minimum of the daily and weekly gram headroom; the drink-day limit acts as
  a gate that forces red once the week's drink-day budget is used up. The gate
  fires both when today is not yet a drink day and the week already holds the
  maximum number of drink days, and when today *is* a drink day but the maximum
  had already been reached on earlier days.
- **Statistics screen** replaces the single "days over limit" row with three
  rows: days over the daily limit, days over the weekly limit, and days over the
  drink-day limit (see the new `AlcoholCalculator.countLimitViolations`).
- **PDF report** drops the "Sex" metadata row and the guideline-mode line; the
  limit line now reads "X g/day · Y g/week · N drink days/wk", the KPI grid shows
  the three violation counts plus the (fixed-threshold) binge count, and the
  monthly table's over-limit column and the trend sparkline reference line now
  use the daily limit.
- **Settings screen** "Personal data" now contains only body weight; the new
  "Limits" section offers three numeric inputs (daily / weekly / drink days).

### Added

- `AlcoholCalculator.countLimitViolations(...)` — shared, unit-tested helper that
  counts the three violation kinds over a list of day summaries, grouping weeks
  by the configured week-start day. Used by both the Statistics screen and the
  PDF export so they always report identical figures.
- `LimitViolations` domain model holding the three counts.
- New, fully translated string resources across all 51 locales:
  `limits`, `daily_limit_grams`, `limit_caption_day`, `limit_caption_week`,
  `days_over_daily_limit`, `days_over_weekly_limit`, `days_over_drink_day_limit`,
  `pdf_unit_g_per_week`, `pdf_meta_drink_days_suffix`, `pdf_kpi_over_daily`,
  `pdf_kpi_over_weekly`, `pdf_kpi_over_drink_days`, `pdf_col_over_daily`.

### Removed

- Domain enums `Gender` and `LimitMode`; `AppSettings.gender`,
  `AppSettings.limitMode`, `AppSettings.weeklyGramMode`; the WHO/DHS limit
  constants and per-sex binge/Widmark constants; the `LimitMode` label
  extensions; the `DrinkCapacity.weeklyGramMode` field and its `effective*`
  helpers; and the now-orphaned `unit_g_per_day` plus all WHO/DHS/gender/
  weekly-mode string resources (24 keys).
- The corresponding `IAppPreferences` setters (`setGender`, `setLimitMode`,
  `setCustomLimit`, `setCustomMaxDrinkDays`, `setWeeklyGramMode`) were replaced
  by `setDailyLimit`, `setWeeklyLimit` and `setMaxDrinkDaysPerWeek`. The DataStore
  keys for the daily limit and drink-day count are reused under their historical
  names so existing values survive; obsolete keys are ignored.

### Documentation

- Updated `README.md`, `CONTRIBUTING.md` and the in-code KDoc to reflect the new
  model. The user guides already described the three-limit design.

### Notes / known issues

- A static **dead-code review** found two pre-existing functions in
  `AlcoholCalculator` that are referenced only by tests and never in production:
  `soberByMillis` and `limitPercent`. They predate this change and were left in
  place (public, tested domain API); removal is recommended if they are not
  intended for upcoming features. (`MILLIS_PER_HOUR`, by contrast, is live.) A
  handful of string resources (`bac_section`, `bac_desc`, `biometric`,
  `stats_from_section`) also appear unused; these are pre-existing and were not
  touched.
- The domain layer (`Models.kt`, `AlcoholCalculator.kt`) was compiled and its
  unit tests (39 cases, including the new BAC, limit, traffic-light and
  violation-counting tests) were executed and pass. The Android/Compose layers
  could not be compiled in this environment (no Android SDK); they were reviewed
  statically for signature and resource consistency.
- The new locale strings were translated on a best-effort basis for the less
  common languages; native review is recommended.

---

## v0.56.0

First sanitized, public baseline.

This is the starting point of the public, forward-only changelog. The internal
development history that preceded it has been removed — it is not part of the
published source — and the knowledge it carried, in particular the *reasons*
behind design decisions, now lives in the source code itself, in the KDoc and
comments next to the code each decision affects.

What was done to produce this baseline:

- **Source documentation sanitized.** All references to concrete past app
  versions and to internal review issue codes were removed from comments, KDoc,
  file headers, the README, CONTRIBUTING, the build script, the ProGuard rules,
  the localization resources and `release-check.sh`. Functional version tokens
  are intentionally kept because they are data contracts, not release history:
  the Room schema version (`@Database(version = 2)`, `MIGRATION_1_2`, the
  committed `app/schemas/*.json`) and the backup-format version
  (`BACKUP_VERSION`).
- **Design rationale folded into the code.** Explanations that previously lived
  only in the changelog (or were referenced indirectly through an issue code)
  were rewritten in present tense as self-contained rationale at the relevant
  code site, so the code explains itself without this file.
- **Three-part versioning.** The version string is now `MAJOR.MINOR.PATCH`,
  starting at `0.56.0` (`versionCode` 49). Going forward, routine changes bump
  PATCH and larger feature sets bump MINOR; `versionName`, this changelog's top
  entry, the README title and the ProGuard header stay in lock-step (CONTRIBUTING
  §6).

### Notes

- No application behaviour changed in this baseline: the edits are limited to
  documentation/comments, the version strings, and the version-format check.
