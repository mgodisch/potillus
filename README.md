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

# Libellus Potionis "Potillus" -- Privacy-Friendly Alcohol Tracker

**v0.61.1**

Libellus Potionis is your digital probation officer for alcohol consumption.
Libellus Potionis is a privacy-friendly, free, open-source, and ad-free app. It
requires no access to your smartphone's camera, microphone, location, or
similar features—not even network access.

You can predefine drinks and log them either while drinking or retroactively
with a corrected time. You define three limits that always apply together: a
daily limit and a weekly limit (both in grams of pure alcohol) and a maximum
number of drinking days per week. Using a traffic light system, Libellus
Potionis helps you drink up to your limit without exceeding it. If you enter
your weight, Libellus Potionis estimates your current blood alcohol
concentration (BAC).

Upon request, Libellus Potionis generates a report for your addiction
counselor, providing a statistical analysis of your drinking habits, clearly
presented on two PDF pages. If the built-in statistics are not sufficient, you
can export your data as a CSV dataset for further processing in tools like
LibreOffice Calc.

## User's Guide

See the [USERSGUIDE.md \[en\]](USERSGUIDE.md), [\[de\]](USERSGUIDE-de.md) for
how to use Libellus Potionis.

## Supported Android versions

Libellus Potionis runs on **Android 11 (API 30) and newer** (`minSdk = 30`,
`targetSdk = 36`). API 30 is a deliberate floor: it is the lowest level at which
the app can save CSV/PDF/backup files to the public Downloads folder via
`MediaStore` *without* requesting any storage permission, which keeps the app's
minimal-permission promise intact. On Android 11–12 the per-app language picker
in the system Settings is unavailable (it is an API 33+ feature), but the in-app
language selector works on every supported version.

## Changes

Changes are documented in [CHANGELOG.md](CHANGELOG.md).

Libellus Potionis was developed for Android 15, runs on Android 11 and newer,
and is tested with the Fairphone 4 and Google Pixel 10 Pro running GrapheneOS.
The source code can be found at the
[canonical repository at codeberg.org](https://codeberg.org/godisch/potillus/).

## License

Libellus Potionis "Potillus" -- Privacy-Friendly Alcohol Tracker
Copyright (c) 2026 Martin A. Godisch <android@godisch.de>

This program is free software: you can redistribute it and/or modify it under
the terms of the [GNU General Public License](LICENSE.md) as published by the
Free Software Foundation, either version 3 of the License, or (at your option)
any later version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
details.

You should have received a copy of the GNU General Public License along with
this program.  If not, see <https://www.gnu.org/licenses/>.
