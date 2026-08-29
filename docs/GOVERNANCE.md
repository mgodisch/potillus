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

# Project Governance

This document describes how Libellus Potionis is governed: how decisions are
made and who holds which role.

## Governance model

Libellus Potionis uses a **single-maintainer** (benevolent-dictator) governance
model. **Martin A. Godisch** (`android@godisch.de`) created the project,
maintains it, and makes every final decision: scope and direction, design and
architecture, which contributions are accepted, and when and what is released.
The model may move toward a shared one if further long-term maintainers join;
such a change is recorded here.

## How decisions are made

- **Proposals and discussion** happen in the open, in the
  [GitLab issue tracker](https://gitlab.com/godisch/potillus/-/issues) and in
  merge requests. Anyone may open an issue, comment, or propose a change.
- **Decisions** are made by the maintainer. For contributions, the acceptance
  criteria and review process are documented in
  [CONTRIBUTING.md](../CONTRIBUTING.md) (Section 2, "Submitting changes"): the
  maintainer reviews every merge request and is the sole merger.
- **Disputes** are resolved by the maintainer. As with any free-software
  project, anyone who disagrees with the project's direction is free to fork it
  under its GPL-3.0-or-later license.

## Key roles

At present the project has a single role:

- **Maintainer / project lead** — Martin A. Godisch (`android@godisch.de`).
  Holds all responsibilities: triaging and answering issues, reviewing and
  merging contributions, handling security reports (see [SECURITY.md](../SECURITY.md)),
  maintaining translations and documentation, and preparing and signing
  releases.

Contributors take on no formal ongoing role beyond the individual changes they
submit.

## Repository access and account security

Anyone granted write (push) access to the canonical repository — currently only
the maintainer — MUST have two-factor authentication (2FA) enabled on their
GitLab account, using a cryptographic method (a TOTP authenticator app or a
hardware security key), not SMS. The forge offers no per-project 2FA enforcement
setting on the plan the project uses, so this is a documented project policy:
write access will not be granted to, or retained by, an account without such
2FA. This protects the integrity of the central repository against account
takeover.

Escalated permissions — write and merge access, release secrets or credentials —
are granted only after the maintainer has reviewed the individual, weighing their
track record under the merge-request process, a justifiable lineage of identity,
and the 2FA requirement above. They are granted at the lowest level the person's
role needs, escalated as further need is shown, and revoked when the need ends.
Until such a grant, every contribution arrives as a merge request that only the
maintainer merges.

## Continuity

The project has one maintainer, and this section says plainly what that means
for anyone depending on it.

**There is no designated successor today.** Should the maintainer become
unavailable, no one else currently holds the rights to publish an update to
Google Play or the App Store, and no one else can answer a security report at
the address in [SECURITY.md](../SECURITY.md). A user should assume that in that
event the published apps stop receiving updates.

**What does not stop.** The licence is GPL-3.0-or-later, so anyone may fork the
project and publish their own build under their own signing identity. The public
repository carries the history, the documentation, the release tooling and the
test vectors, and the GitHub mirror is a second copy of it. The F-Droid channel
re-signs from source, so it needs no hand-over of the maintainer's private key.
The app stores data only on the device in a documented, versioned backup format,
so a user's data outlives the project.

**When a successor would be named.** The maintainer will designate a
co-maintainer or successor once a contributor has established a track record
under the review process described above and is willing to take the role on.
Naming someone who has not is worse than naming no one: it would satisfy a
checklist while leaving the actual obligations — security response, store
accounts, signing identity — with a person who has not agreed to carry them.
Should that change, this section and the "Key roles" list above are updated
together, and the change is announced in the CHANGELOG.

**Reporting a maintainer who has gone silent.** If the maintainer does not
respond within the period stated in [SECURITY.md](../SECURITY.md) and no
successor is listed here, treat the project as unmaintained and fork it. The
license grants that right precisely so that no permission is needed for it.
