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

=============================================================================
-->

# Security Policy

Libellus Potionis is a privacy-focused application, and security reports are
taken seriously. This document describes how to report a vulnerability and what
to expect in return.

## Reporting a vulnerability

Please report suspected security vulnerabilities **privately**. Do **not** open
a public issue for a security problem — a public issue would disclose the
vulnerability before a fix is available.

Send your report by e-mail to **android@godisch.de**.

Because a report may contain sensitive details, please **encrypt it with PGP**
using the maintainer's public key:

- Fingerprint: `1842 323B 4FCF 9B90 995F  A17F A350 B991 F05A 4857`

The maintainer is a Debian Developer, so the key is distributed through the
official Debian keyserver and can be fetched from there:

```sh
gpg --keyserver hkps://keyring.debian.org:443 \
    --recv-keys 1842323B4FCF9B90995FA17FA350B991F05A4857
```

The same key is also part of the `debian-keyring` package. Before trusting the
key, verify that the fingerprint printed by `gpg --fingerprint` matches the one
above.

If you are unable to use PGP, still write to android@godisch.de; the maintainer
will arrange a secure channel before you share any sensitive details.

## What to include

To help triage and reproduce the issue, please include where possible:

- a description of the vulnerability and its potential impact;
- the app version (shown in the app, or the `versionName`) and the Android
  version and device model;
- step-by-step instructions or a proof of concept to reproduce it;
- any relevant logs, stack traces, or screenshots.

## What to expect

- **Acknowledgement:** the maintainer will acknowledge your report within
  **14 days** of receipt.
- **Assessment:** after acknowledgement you will receive confirmation of whether
  the report is accepted as a vulnerability and an estimate of the time to a
  fix.
- **Disclosure:** please practice coordinated disclosure — give the maintainer a
  reasonable opportunity to release a fix before disclosing the issue publicly.
  Unless you prefer to remain anonymous, your contribution will be credited in
  the release notes once a fix is published.

## Scope

This policy covers the Libellus Potionis application code in this repository.
Vulnerabilities in third-party dependencies should be reported to their
respective projects; if a dependency issue affects Libellus Potionis, you are
welcome to notify the maintainer as well so the dependency can be updated.
