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

# Shared test vectors

Language-neutral golden input/output cases for the health-relevant domain logic,
loaded by **both** platforms so the Android (JVM) and iOS (Swift) implementations
can never silently diverge. See `docs/IOS_MIGRATION.md`, "Correctness parity".

Each file is a JSON document with a `cases` array; every case pairs an `input`
with its `expected` output. Adding or changing a case here is a deliberate,
reviewable change, and both test suites assert against these files.

The vectors are seeded from the existing Android domain tests as the logic is
ported. That is a hazard as well as a guarantee: a vector encodes *current*
behaviour, so if the Android code has a bug, the vector enshrines it. When
Android fixes a bug, regenerate the affected vectors and re-check the Swift port
— and add a regression vector for the fixed case.

## Files

- `alcohol-calculator.json` — the Widmark BAC estimate, gram conversion, limit
  fractions, the traffic-light capacity status, and the rolling seven-day
  violation counts. Harvested from `AlcoholCalculatorTest.kt`.
- `day-resolver.json` — the logical-day boundary, effective period length, and
  the abstinence streaks. Harvested from `DayResolverTest.kt`. The `resolve`
  cases carry an absolute `epochMillis` plus an IANA `zoneId`, and deliberately
  include DST transitions (the spring-forward gap and the fall-back repetition)
  and cross-timezone instants, because the same instant is a different logical
  day in different zones.

## Loading

The iOS suite reads these files directly from the repository root, locating it
from the compile-time path of its loader (`ios/PotillusKit/Tests/.../
TestVectors.swift`). SwiftPM can only bundle resources inside a target, so
`Bundle.module` cannot reach up here — deriving the path is the standard
technique for shared fixtures and stays confined to test code.

A missing or malformed vector file is a hard test failure on both platforms: a
silently skipped parity suite would defeat the purpose.
