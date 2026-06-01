<!-- vim: set et ts=4:
=============================================================================
Libellus Potionis "Potillus" -- Privacy-Friendly Alcohol Tracker
Copyright (c) 2026 Martin A. Godisch <android@godisch.de>
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

=============================================================================
-->

# Libellus Potionis (Potillus) – Changelog

<!-- Add new entries on top! -->

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
- Not built or tested in this environment (no Android SDK). Run `make test` and
  `make test-device` before tagging.
