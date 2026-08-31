# Libellus Potionis&mdash;User’s Guide

Libellus Potionis is a diary for logging your own drinking. You log what you
drink; the app works out how much pure alcohol that was and whether “la
petite sœur” is still within the limits you set yourself. This guide walks
you through the app step by step: how it is laid out, how to set it up, how
to log a drink, then looking back and taking stock, and finally backups.

## What the app does, and what it doesn’t

Libellus Potionis keeps record. It doesn’t judge and it doesn’t nag. The
figures it shows are your own entries, converted to grams of pure alcohol. If
you log every drink, you can look back at your own drinking while
sober&mdash;which is where the app earns its keep.

Libellus Potionis is free software under the GNU General Public License,
which means its source code is public and any claim about how it handles your
data can be checked by anyone at any time. Privacy is a defining trait of
Libellus Potionis: it asks for no sensitive permission at all, no camera, no
microphone, no location, no file access, not even network access. Everything
you enter stays in the app’s private storage on your device, protected by the
device’s own encryption. You can lock access to the app in the settings using
Face ID; that is the
only permission the app ever requests.

What Libellus Potionis is _not:_ the app is neither a measuring instrument
nor a medical device. The blood alcohol figure is an estimate from a
statistical model (see “How the figures are worked out”). Nothing the app
says can tell you whether you are fit to drive, and nothing it says is a
diagnosis. What Libellus Potionis can do is give you a picture of your own
drinking over weeks and months, and, if you want, print that picture as a
two-page PDF on a sheet of paper you can take to a counseling appointment.

Libellus Potionis needs iOS 17 or later, which covers iPhones from roughly
2018 onwards. It is tested regularly on an iPhone 16e and an iPhone SE 3rd
generation, both on iOS 26.

## How the app is laid out

Libellus Potionis has four screens. You move between them with the bar along
the bottom of the display, which is present on all four:

- _Today_: how the current day stands, and what was logged on it,
- _Calendar_: looking back over single days, months and years, and
  correcting their entries where needed,
- _Statistics_: statistical evaluations over weeks, months and years,
- _Drinks_: the catalog of drinks you can log.

Top right on all four screens sits the same menu button
“(&middot;&middot;&middot;)”. It opens a menu holding _Settings, Help_ (this
guide) and the _About_ page, with information on the app, its versions
and its licenses. If your device can authenticate you, _Lock app_ stands
there as well, and locks the app there and then.

_Settings, Help_ and _About_ open as sheets of their own,
which you close at the top right.

## Setting up

Straight after installing, the app has no entries yet but is ready to use: a
predefined catalog of drinks common around the world lets you log that first
beer right away. Three things are still worth setting first. All three live
under _Settings_; the remaining settings are covered further down.

### Your limits

The _Limits_ section holds the values that apply to you, and all three
apply at once:

- _Daily Limit in Grams_: the daily limit of pure alcohol in grams,
- _7-Day Limit in Grams_: the weekly limit of pure alcohol in grams,
  counted over a rolling window of seven days,
- _Max. Drinking Days/7 Days_: the weekly limit of drinking days, counted over a
  rolling seven-day window as well.

The third value caps not the amount but the frequency. Set it to four
drinking days, drink on three of the six days before, and the _Today_
screen shows you that the first drink would use up the fourth drinking day,
while a second drink the same day would not use an additional one.

For a sense of what numbers are reasonable, look at what the health
authorities of various countries recommend. They differ widely, and
[Wikipedia](https://en.wikipedia.org/wiki/Alcohol_consumption_recommendations#Recommended_alcohol_intake_limitations_by_country)
collects them.

### Your body weight

The _Personal Data_ section holds the _Body Weight_, and it is
optional. Until a value is entered, all that stands there is the button that
adds it; after that you can step it up or down, and a second button removes
it again. The app works fully without a body weight, only the estimated blood
alcohol figure on the _Today_ screen is _not_ shown then, because the
basis for working it out is missing.

### When your day begins

_Statistics_ holds _New Day Starts At_, set to four in the morning. This
setting decides which day a drink counts towards: have a glass at one in the
morning and it lands on the evening before, where it belongs. The day
boundary applies throughout the app, in the calendar as much as in the
statistics and in exports.

The _Statistics From_ row sits in the same place. That date is the floor
under every evaluation: entries before it are ignored in every figure. It
lets you draw a clean line on the first of January for a new year’s
resolution without losing what you have logged so far. A fresh install sets
the date to the day of installation. That is usually right, but it can puzzle
you when a backup with older data is imported: the old entries are there, and
none of them count anywhere. The _Include all history_ button lifts the
floor again.

## The Today screen

Above the drinks list stands a summary that refreshes after every entry and
as time passes. From the top:

Two large figures stand one above the other: the length of the
current abstinence in days, or the pure alcohol logged today in grams,
below, as “Ø”, the
average for the current month in grams per day. A green or red trend arrow
beside it compares that figure with the month before.

Three quantity bars: the first shows today’s consumption against the daily
limit you configured, the second the sum of today and the past six days
against the seven-day limit you configured, the third the number of drinking
days among today and the past six days against the limit you configured. All
three show a figure and a bar.

The estimated blood alcohol figure appears only if a body weight is entered,
and only while the arithmetic still puts alcohol in your blood. It is an
estimate, and it cannot tell you whether you are fit to drive.

Below that stands the list of drinks logged for the current day.

## Logging a drink

There is more than one place to log a drink from. The _Today_ screen
offers the first, and the _Calendar_ and _Drinks_ screens offer
further ones. At the top right
of the _Today_ screen sits the plus button; it opens the entry sheet.

### The entry sheet

At the top stands the _Drink_ row with the choice from the catalog; with
only one drink defined, its name stands there with nothing to choose. Three
fields follow:

- the volume drunk, in milliliters. From 1 to 5,000 ml; it starts at the
  chosen drink’s usual serving.
- the time, set to now. Adjustable when you are logging something after the
  fact.
- an optional note, a free remark on the occasion or the company.

Strength belongs to the drink and cannot be entered differently here. If the
same kind of drink is markedly stronger one evening, give it its own entry in
the catalog.

As soon as the volume is in range, the grams of pure alcohol the entry comes
to stand below the fields, in the _Alcohol Content_ row.
This is the figure Libellus Potionis works with, not the milliliters.

Beside the alcohol content sits a colored status dot. It says how many
servings of the chosen drink can still be had the same day within the three
limits you defined: green while at least two more are possible, yellow while
exactly one still fits, red when the next one would break one or more of the
limits set. If red and green are hard for you to tell apart, turn on
_Alternative Status Symbols_ under _Appearance_ in _Settings_, and the
colored dot carries a matching shape as well.

Close the sheet with either of the two buttons at the top. Once you
have typed something, swiping down no longer dismisses it, so half an entry
cannot vanish by accident.

### Quick buttons for the drinks you log often

Drinks marked as favorites in the catalog appear on the _Today_ screen as
a row of buttons above the day’s list. One tap logs the drink at its usual
serving, with no sheet in between. For the beer after work that is always the
same beer, this is the shortest way.

### Fixing or removing an entry

Tap an entry in the day’s list and it opens as _Edit Entry_: the same
fields as when you logged it, and the same bounds. To
remove it, swipe the row left, or tap the row’s red badge in edit mode at the
top right. Either way you reach _Delete_ and the same question,
because an entry deleted by mistake cannot be brought back.

## The calendar

The _Calendar_ screen shows what has been. The switch between the month
view and the year heat map sits at the top
left.

### The month view

The month view shows an ordinary grid of a month and is the view you start
in. The month is named above the grid, with an arrow either side for paging.
Days with entries carry a dot: a blue one for a drinking day below the
limits, a red one for a drinking day that broke a limit. Days without an
entry carry no dot.

A tap selects the day and lists its entries below. There they can be edited
and deleted exactly as the current day can on the _Today_ screen, and the
plus button at the top right,
which appears only once a day is selected, logs to the selected day. This is
how you catch up on what you did not record while drinking.

### The year view

The year view can be selected using the button on the top
left. It shows the twelve months
of a year as a heat map, a grid of small squares, one per day. The year is
shown above the grid, with an arrow either side for moving between years. The
legend below names the three states: no entry,
under limit, over limit. Today carries a
ring. A tap on a month opens the month view for it.

## Taking stock: the statistics

The _Statistics_ screen analyzes. The length of the period is chosen at
the top: _Week_, _Month_ or _Year_. Everything below refers to
that choice. _Week_ always means a rolling seven-day window made up of
today and the six days before it. Every calculation ignores entries from
before the _Statistics From_ date in _Settings_. If there are no
entries in the chosen period, the sections stay where they are and show
zeroes.

### Moving back through time

Below the period buttons, the stretch on display is spelled out as an exact
range of dates. The current month ends today rather than at month’s end, and
if a _Statistics From_ is set, the range begins there. So what stands
there is precisely what the figures below cover. An arrow sits either side of
it. The left one steps a period back, the right one back toward the present.

Everything on this screen follows the chosen period, figures and charts
alike. _Trend vs. Previous Period_ always compares with the period of the same length
directly before it, so March against February.

### The figures

- _Total in Period_: grams of pure alcohol in the chosen period.
- _Average per Day_: the average across every calendar day.
- _Average per Drinking Day_: the average across drinking days. A large gap to
  the previous figure points to drinking that is rare but heavy.
- _Days Over Daily Limit_: the number of days on which the daily limit
  was passed.
- _Days Over 7-Day Limit_: the number of drinking days on which that day
  and the six before it added up to more than the seven-day limit.
- _Days Over Drinking Days Limit_: drinking days that sat above the
  drinking-day limit within their seven-day window, the fifth drinking day in
  seven, say, when only four are allowed.
- _Abstinent Days_: days in the period without entries.
- _Current Abstinence_: counts the days since the last drink.
- _Longest Abstinence_: the longest stretch without alcohol in the period.
- _Trend vs. Previous Period_: shows the trend against the period before.

### The charts

Four charts complement the figures, the first on the course, the others on
the pattern:

- The first bar chart traces consumption across the chosen period: the chosen
  seven-day window, the chosen month, or the average consumption per day for
  each month of the chosen year.
- _Time of Day_ splits the day into eight slots of three hours each
  and gives the average in grams per day for each of them. This is where you
  see whether the drinking sits in the evening or runs through the day. The
  section appears only if anything was drunk in the chosen period.
- _Weekday_ gives the average consumption per day of the week.
- _Categories_ shows as a ring how the drinking splits
  across the six drink categories.

## The drinks catalog

The _Drinks_ screen manages the drinks you choose from when logging. The
app ships with a selection of common ones; they can be changed, added to and
deleted.

Each row shows the name, a category symbol, the serving, the strength and the
grams of pure alcohol those come to, with the favorite star and the status
dot for that serving ahead of them. The star toggles the favorite: favorites appear in
the quick buttons on the _Today_ screen.

A tap on the row opens
the entry sheet for that drink; this is the third way to log, alongside the
plus buttons on the _Today_ and the _Calendar_ screens. Editing and
deleting belong to edit mode, which you turn on at the top right: there the
same tap opens the editor, and the row’s red badge leads to the delete
prompt. A left swipe offers both actions as well, in edit mode and outside
it.

### Adding or changing a drink

The plus button opens _Add Drink_, a tap in edit mode opens _Edit Drink_.
Both sheets ask the same:

- _Name_: whatever you like, up to 100 characters.
- _Amount_: the usual serving, which the entry sheet starts from. From
  1 to 5,000 milliliters.
- _Alcohol (%)_: the usual strength, from 0 to 100 percent.
- _Category_: one of six categories: Beer,
  Wine / Sparkling Wine, Spirits, Long Drink / Mix,
  Liqueur or Other. The category changes nothing in
  the arithmetic; it groups the breakdown on the _Statistics_ screen.

### Why some drinks refuse to be deleted

A drink cannot be deleted while entries in your log still refer to it; the
app then tells you how many do. The reason is that those entries would
otherwise lose what they refer to, leaving the statistics incomplete.

## Data export

### The PDF report

On the _Statistics_ screen, the _Export PDF report_ button produces a
two-page report as a _Portable Document Format (PDF)_ file: the headline
figures, a month by month table, the long-term trend, the pattern by
category, time of day and day of the week, and a section on risky drinking
and abstinence. The format suits a conversation with an addiction counselor.

The report covers exactly the period chosen: If you export July after
drinking on eleven days, you get a report over thirty-one days, with twenty
abstinent days and a daily average divided by thirty-one. The month table
lists every month of the period, including one without a single entry. This
is what makes the figures of the report agree with those of the
_Statistics_ screen. If the period chosen ends today, the report ends
yesterday for as long as nothing is logged today: an unfinished day would
drag the average down and count as abstinent before it is over.

For the PDF report, the system file picker
opens, where you decide where the file goes: into Files, into cloud storage,
or into another app.

### The CSV export

The _Export CSV_ button on the _Statistics_ screen writes a table
with one row per entry, ready for a spreadsheet such as [LibreOffice
Calc](https://www.libreoffice.org/). Numbers are written machine-readably
with a decimal point, whatever language the app is in.

For the CSV file, too, the system
file picker opens, where you decide where the file goes: into Files, into
cloud storage, or into another app.

### The JSON export &mdash; Backups

**Data you record does not leave this device without your explicit action.**
Libellus
Potionis keeps its data out of every device backup, iCloud and computer
backups alike; the _Include in device backup_ switch under _Settings_ reverses
that (see “Access and visibility”). While it is off, a backup you made
yourself is the only way to keep your data when you change devices, after a
factory reset or a reinstall.

A backup is a single JSON file. The _Include settings_ switch
decides whether the settings are written into it alongside the drinks catalog
and the entries. The option is on again every time the settings are opened.
This is how the data moves to a new device:

1. On the old device, choose _Settings_ → _Backup_ →
   _Export_. Keep the file somewhere safe, a
   [Signal](https://signal.org/) note to yourself for instance.
2. Install Libellus Potionis on the new device.
3. There, restore the data through _Settings_ → _Backup_ →
   _Import_.

On import the app asks how it should go about it. _Replace_ throws
away what is on the device: the drinks catalog, the entries, and the
settings, provided the backup carries any. _Merge_ deletes no
existing drink definitions and no entries, and adds what is missing. Entries
that already exist are not duplicated, and the current settings are not
overwritten.

## Further settings

### Access and visibility

The _Security_ section holds
three switches:

- _Biometric Lock_ asks, whenever the app is opened, for Face ID, Touch
  ID or the device passcode. Turning the lock on or off requires that
  same authentication. It applies again when you leave the app and come back,
  though not if you come back within thirty seconds. The menu at the top
  right also carries _Lock app_, which locks the app there and then.
- _Show in app switcher_ is off by default. While disabled, the content stays covered in the app
  switcher. Someone who picks up your unlocked device and thumbs
  through the open apps sees nothing there. Preventing a screenshot
  is beyond the reach of the iOS app; iOS offers no interface for doing
  so.
- _Include in device backup_ is off by default as well. While the switch is
off, the app’s data stays out of every device backup, iCloud and computer
backups alike. Turn it on and the data survives restoring a device from its
backup, but then it also sits wherever that backup sits.

### Appearance and language

The _Appearance_ section offers three things:

- _Color Scheme_: System, or Light or Dark
  regardless of the system setting.
- _Language_: the app’s language, again independent of the system.
  “(System)” follows the system language again.
- _Alternative Status Symbols_ gives the status dots a shape as well as a color.
  The three states stay apart that way when red, yellow and green are hard to
  tell apart.

## How the figures are worked out

### From milliliters to grams

Every entry is converted to grams of pure alcohol as it is saved:

**grams = milliliters × strength × 0.789**

0.789 is the density of ethanol in grams per milliliter. Half a liter of beer
at 5 % therefore comes to 500 ml × 0.05 × 0.789 g/ml, or about 19.7 g. Every
limit, every statistic and every export works with that number, never with
milliliters. It is the only thing that makes a beer and a glass of wine
comparable at all.

### The blood alcohol estimate

Given a body weight, Libellus Potionis estimates blood alcohol concentration
with the [Widmark
formula](https://en.wikipedia.org/wiki/Blood_alcohol_content):

**BAC [per mille] = A / (P × r) − β × t**

A is the pure alcohol in grams, P the body weight in kilograms, r the
distribution coefficient, β the elimination rate of about 0.15 per mille per
hour, and t the hours since the first drink.

The app does not record your sex and therefore works deliberately on the
cautious side: r is fixed at 0.6, the lower of the two classical
coefficients. A smaller r spreads the same alcohol through a smaller volume
and so returns the higher of the two figures: the estimate is meant to run
high rather than low. The elimination rate, by contrast, is an average;
individually it runs somewhere between 0.10 and 0.20 per mille per hour. If
you clear alcohol slowly, you are above the figure shown.

What comes out is a model, not a measurement. It replaces no breathalyser,
and it cannot tell you whether you are fit to drive.

### The logical day

A drink belongs to the day that began at _New Day Starts At_, not to the day
the clock shows. With the default of four in the morning, a glass at half
past one still counts toward the day before. The rule holds throughout the
app, and across clock changes.

### The rolling week

The seven-day limit and the drinking days do not refer to a calendar week but
to today and the six days before it. The window therefore moves along day by
day. A heavy Saturday stays in view until it is six days old, and drops out
on the Saturday after.
