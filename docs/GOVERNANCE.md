<!-- vim: set et ts=4:
=============================================================================
Libellus Potionis - Privacy-Friendly Alcohol Tracker
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
model. The project was created and is maintained by one person, **Martin A.
Godisch** (`android@godisch.de`), who is the project owner and lead and makes
all final decisions about the project — including its scope and direction, the
software's design and architecture, which contributions are accepted, and when
and what is released.

This centralized model is deliberate and appropriate for a small, single-author
teaching project. It may evolve toward a shared model if the project grows and
additional long-term maintainers join; any such change will be recorded here.

## How decisions are made

- **Proposals and discussion** happen in the open, in the
  [Codeberg issue tracker](https://codeberg.org/godisch/potillus/issues) and in
  pull requests. Anyone may open an issue, comment, or propose a change.
- **Decisions** are made by the maintainer. For contributions, the acceptance
  criteria and review process are documented in
  [CONTRIBUTING.md](../CONTRIBUTING.md) (Section 2, "Submitting changes"): the
  maintainer reviews every pull request and is the sole merger.
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

Because the project currently has one maintainer, that person holds every role.
Detailed responsibilities are listed under "Key roles" above; contributors take
on no formal ongoing role beyond the individual contributions they submit.

## Repository access and account security

Anyone granted write (push) access to the canonical repository — currently only
the maintainer — MUST have two-factor authentication (2FA) enabled on their
Codeberg account, using a cryptographic method (a TOTP authenticator app or a
hardware security key), not SMS. The forge offers no per-project 2FA enforcement
setting, so this is a documented project policy: write access will not be granted
to, or retained by, an account without such 2FA. This protects the integrity of
the central repository against account takeover.

Escalated permissions to sensitive resources — write/merge access to the
canonical repository, and access to release secrets or credentials — are granted
only after the maintainer has reviewed and approved the individual. Review
considers the contributor's track record in the project (contributions accepted
through the normal pull-request review process), a justifiable lineage of
identity, and the 2FA requirement above. Permissions are granted at the lowest
level needed for the person's role and escalated only as further need is
demonstrated, and revoked when no longer needed. Until such a grant, all
contributions are submitted as pull requests and merged only by the maintainer,
so no contributor holds escalated permissions without this review.
