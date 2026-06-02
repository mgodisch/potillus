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

<!-- GENERATED FILE -- do not edit. Source: docs/guide/usersguide.en.md.in (run `make guides`). -->

# Libellus Potionis "Potillus" -- User's Guide

Welcome to Libellus Potionis, the personal logger for your alcohol consumption!
This page describes the features and functions of the app.

## Highlights

Libellus Potionis is open source. The source code can be viewed and verified by
anyone. Libellus Potionis is privacy-friendly. It requires no
permissions—neither for the camera or microphone, nor for GPS or network
access. Libellus Potionis is secure: All data is stored in encrypted form, and
access to the app can be restricted using a fingerprint. Libellus Potionis
supports you in pacing yourself up to your limit by letting you know at any
time whether "la petite sœur" is still within your budget. Libellus Potionis
supports you during addiction counseling by providing a comprehensive, two-page
PDF report of your drinking habits upon request. Libellus Potionis is free of
charge and ad-free.

Libellus Potionis requires Android 15 or higher. It is continuously used by the
author on a Google Pixel 10 Pro running GrapheneOS and is additionally tested
on a Fairphone 4.

## Screen "Today"

On this screen, you will find a list of the alcoholic beverages you enjoyed
today. If you made a mistake when logging a drink, you can edit or delete
entries here. Use the plus button to add more beverages.

Above the beverage list, you will find an overview of the current day with the
following information: the amount of alcohol already consumed today (in grams),
the amount of alcohol already consumed today in relation to your daily and
weekly limits (in grams and as a bar chart), and the number of days with
alcohol consumption so far this week in relation to your limit (as a number and
as a bar chart).

## Screen "Calendar"

On this screen, you will find the calendar. Days on which alcohol was consumed
are marked with a blue dot (non-critical amount) or a red dot (exceeding the
limit). Selecting a day displays the corresponding beverages, which can then be
corrected or deleted if necessary. It is also possible to add consumed
beverages retroactively.

## Screen "Statistics"

This screen shows statistical evaluations of your alcohol consumption,
filterable by week, month, or year. A CSV export is available to process the
data further in a spreadsheet application. In addition, a PDF export is
provided, which formats the drinking habits in a layout suitable for addiction
counseling.

## Screen "Drinks"

This screen contains the list of beverages. The app comes pre-configured with a
set of internationally common beverages. All of these can be modified or
deleted. You can define a new beverage using the plus icon. Tapping a beverage
opens a dialog to log it as consumed.

## Screen "Settings"

The settings menu can be accessed via the menu icon (☰) in the top right corner.
Libellus Potionis provides the following configuration options:

### Personal data

In this category, you can record your body weight to approximate your blood
alcohol concentration using the Widmark formula.

### Limits

In this category, you can enter the limits that apply to your alcohol
consumption. The required fields are: maximum daily limit in grams of pure
alcohol, maximum weekly limit, and maximum drinking days per week. All limits
apply concurrently. Accordingly, three progress bars are visible on the
"Today" screen. If you are unsure what to configure here, you can look for
inspiration from recommendations in various countries on Wikipedia.

### Statistics

The statistical settings allow you to define the time at which a new day begins
(so that, for example, a drink at 1:00 AM still counts toward the previous
day), the day on which the week should start, and—for New Year's
resolutions—the date from which the data evaluation should begin.

### Backup

All data can be exported as JSON and imported again.

### Appearance

In this category, you can activate the biometric lock for the app. Furthermore,
you can set the color theme and the language independently of the system
settings.
