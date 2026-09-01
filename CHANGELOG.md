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

Add new entries on top!

HEADING CONVENTION: directly below each "## vX.Y.Z" header, write a one-line
summary formatted as a git commit subject — imperative mood, capitalized, no
trailing period, at most 50 characters. Leave a blank line, then the detailed
notes. This makes the entry's first line directly reusable as the subject of
the release commit/tag (git's recommended ≤50-char subject limit).

RELEASE REMINDER: on every version bump, also add a localized store note
fastlane/metadata/android/<locale>/changelogs/<versionCode>.txt for EVERY
locale, keeping the set identical across locales. release-check.sh §1 enforces
both that the current versionCode's note exists in each locale and that all
locales carry the same set of changelog files.

ANCHOR: android/version-anchor baselines v1.0.0 at versionCode 97, so the
one-increment-per-release arithmetic in release-check.sh §1 counts the entries
below from this file alone. The 0.x series it counted before ended with v0.85.0
at versionCode 96, which is why the count starts over here while the
versionCode carries on.

=============================================================================
-->

# Libellus Potionis – Changelog

This file records the releases from v1.0.0 on.

---

## v1.0.0

Release the first production version

### Changed

- The changelog was reset to v1.0.0, the version anchor was updated
  accordingly.
- The bundled fastlane was updated to 2.238.0.
