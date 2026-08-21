# Libellus Potionis - User's Guide

Libellus Potionis is a diary for your own drinking. You log what you drink;
the app works out how much pure alcohol that was and how close it brings you
to the limits you set yourself.

This guide walks through the app, step by step: how it is laid out, how to
set it up, how to log a drink, how to look back and take stock, and how to
keep your data safe. The headings are there for looking things up later.

## What the app does, and what it doesn't

Libellus Potionis keeps record. It doesn't judge and it doesn't nag. The
figures it shows are your own entries, converted to grams of pure alcohol. If
you log every drink, you will be able to look back at your drinking habits
while sober -- which is where the app earns its keep.

Libellus Potionis is free software under the GNU General Public License,
version 3.0 or later. Its source code is public, so anyone anywhere can check
what it does with your data. Libellus Potionis takes privacy very seriously,
it asks for no sensitive permission at all: no camera, no microphone, no
location, no file access, not even network access. Everything you enter stays
in the app's private storage on your device, protected by the device's own
encryption. You can lock access to the app using Face ID in the settings; that is the
only permission the app ever requests.

What Libellus Potionis is _not:_ The app is neither a measuring instrument
nor a medical device. The blood alcohol figure is an estimate from a
statistical model (see "How the figures are worked out"). Nothing the app
says can tell you whether you are fit to drive, and nothing it says is a
diagnosis. What Libellus Potionis can do is show you a picture of your
drinking habits over weeks and months, and, if you want, print that picture
as a two-page PDF you can take to a counseling appointment.

Libellus Potionis needs iOS 17 or later, which covers iPhones from roughly
2018 onwards. It is tested regularly on an iPhone 16e and an iPhone SE 3rd
generation, both on iOS 26.

## How the app is laid out

There are four screens. You move between them with the bar along the bottom
of the display, which is present on all four:

- **Today** -- where you start: how the day stands, and what you logged
  today,
- **Calendar** -- looking back over days, months and years, and
  correcting them if need be,
- **Statistics** -- statistical numbers for a period you choose,
- **Drinks** -- the catalog you log your drinks from.

Top right on all four screens sits the same menu button. It opens Menu,
which holds "Settings", Help (this guide) and About, where you
find the version, the license and the third-party components in use. If your
device has a screen lock set up, Lock app is there too, and locks the app
at once.

Settings, Help and About open as sheets of their own, which you
close at the top right.

## Setting up

Straight after installing, the app has no entries yet but is ready to use: it
ships with a catalog of drinks common around the world, so you can log that
first beer right away. Three things are worth setting first, though. All
three live under "Settings"; the remaining settings are covered further
down.

### Your limits

The Limits section holds three values, and all three apply at once:

- **Daily Limit in Grams** -- grams of pure alcohol per day,
- **7-Day Limit in Grams** -- grams of pure alcohol over a rolling window of
  seven days,
- **Max. Drinking Days/7 Days** -- how many days you drink on, again over a
  rolling seven-day window.

The third is the one people skip past, and often the most telling: it caps
how often you drink, not how much. Set it to four, drink on three of the past
six days, and the Today screen will tell you that your next drink uses up
the fourth drinking day, while a second drink the same day costs you nothing
further.

For a sense of what numbers are reasonable, look at what national health
bodies recommend. They differ widely from country to country;
[Wikipedia](https://en.wikipedia.org/wiki/Alcohol_consumption_recommendations#Recommended_alcohol_intake_limitations_by_country)
collects them.

### Your body weight

The Personal Data section holds a single value, Body Weight, and it
is optional. Until you set one, all you see is the button that adds
it; after that you can step it up or down, and a second button removes it
again. The app works perfectly well without it. The only thing you
lose is the blood alcohol estimate on the Today screen, which cannot be
worked out without a weight. "How the figures are worked out" explains where
it comes from.

### When your day begins

Statistics holds New Day Starts At, set to four in the morning. This
decides which day a drink belongs to: have a glass at one in the morning and
it lands on the evening before, where it belongs. The setting applies
throughout the app, in the calendar as much as in the statistics and in
exports.

The Statistics From row sits in the same place. It is the floor under
every calculation: anything logged before that date is left out of the
figures. That is what lets you draw a line on the first of January for a new
year's resolution without throwing away what came before. A fresh install
sets it to the day you installed the app, which is usually right, and has one
consequence that catches people out when they restore an older backup: the
old entries are all there, and none of them count toward anything. The
Include all history button lifts the floor again, and only appears while a
floor is set.

## What the Today screen shows

Above the day's list is a summary that refreshes after every entry, and as
the day wears on. From the top:

**Two large figures**, one above the other. First you see either
Current Abstinence, the number of days you have gone without, or
Today's Total, the pure alcohol you have logged today in grams.
Below, under "Ø", is your
average for the month so far in grams per day. That monthly figure is the
only thing on this screen that looks beyond today. A green or red trend arrow
beside it compares the month with the one before; with no previous month to
compare, no arrow.

**Three bars** follow: today against your daily limit, the past seven days
against your seven-day limit, and the drinking days in those seven days
against your limit for those. Each shows the figure and the bar.

**The blood alcohol estimate** appears only if you have entered a body
weight, and only while the model still puts alcohol in your blood. It is an
estimate, and it cannot tell you whether you are fit to drive.

Below all of this is the list of what you have logged today.

## Logging a drink

There is more than one place to log from. The Today screen is the
obvious one; Calendar and Drinks offer their own routes. On
Today, the plus button sits at the
top right and opens the entry
sheet.

### The entry sheet

At the top is the Drink row, where you pick from the catalog; with only
one drink defined, its name simply stands there with nothing to pick. Three
fields follow:

- **Amount** - how much you drank, in milliliters, from 1 to 5,000.
  It starts at the drink's usual serving.
- **Time** - set to now, and adjustable if you are catching up on
  something.
- **Note** - anything you want to remember: the occasion, the company.

Strength belongs to the drink and cannot be overridden here. If the same kind
of drink is markedly stronger one evening, give it its own entry in the
catalog.

As soon as the volume is in range, the sheet tells you, in the
Alcohol Content row, how many grams of pure alcohol that comes
to. This is the figure Libellus Potionis works with. Milliliters never enter
the arithmetic.

Beside it sits a colored dot telling you how many more of the drink you have
picked would fit inside your three limits today: green if at least two more
would, yellow if exactly one would, red if the next one breaks a limit. All
three limits are checked - daily, seven-day, and drinking days. A screen
reader announces Within your limits, Almost at your limit or
Limit reached. If red and green are hard for you to tell apart,
turn on Alternative Status Symbols under Appearance in "Settings", and
the dot carries a shape as well as a color.

Close the sheet with either of the two buttons at the top. Once you
have typed something, swiping down no longer dismisses it, so half an entry
cannot vanish by accident.

### Quick buttons for your regulars

Mark a drink as a favorite in the catalog and it appears on the Today
screen as Quick Selection Favorites: a row of buttons above the day's list. One tap
logs the drink at its usual serving, with no sheet in between. For the beer
after work that is always the same beer, this is the short way.

### Fixing or removing an entry

Tap an entry in the day's list and it opens as Edit Entry, with the same
fields and the same bounds as when you logged it. To
remove it, swipe the row left, or turn on edit mode at the top right and tap
the row's red badge. Either way you reach Delete and the same
question, because an entry deleted by mistake is gone for good.

## The drinks catalog

The Drinks screen manages the drinks you log from. The app ships with a
selection of common ones, and you are free to change them, add to them, and
delete them.

Each row shows the name, a category symbol, the serving, the strength, and
the grams of pure alcohol those come to, with the favorite star and the
status dot for that serving ahead of
them. The
star toggles the favorite, which is what puts a drink in the quick buttons
on the Today screen.

Tapping a row opens the entry sheet for that
drink, which is the second way to log, alongside the plus button on
Today. Editing and deleting belong to edit mode, which you turn on at the
top right: there the same tap opens the drink's editor, and the row's red
badge leads to the delete prompt. A left swipe offers both actions as well,
in edit mode and outside it.

### Adding or changing a drink

The plus button opens Add Drink; a tap in edit mode opens Edit Drink. Both
ask the same four things:

- **Name** - whatever you like, up to 100 characters.
- **Amount** - the usual serving, which the entry sheet starts from.
  From 1 to 5,000 milliliters.
- **Alcohol (%)** - the usual strength, from 0 to 100 percent.
- **Category** - one of six: Beer, Wine / Sparkling Wine,
  Spirits, Long Drink / Mix, Liqueur or
  Other. The category changes no arithmetic; it groups the
  breakdown on the Statistics screen.

### Why some drinks refuse to be deleted

A drink that entries already point at cannot be removed, and the app tells
you how many are hanging off it. Delete it and those entries would lose what
they refer to, leaving gaps in every figure the app shows you.

## Looking back: the calendar

The Calendar screen shows what happened. The switch between its two views
is at the top left.

Every time you come to the calendar it is back on the current month, however
far you had paged away last time. There is a reason: the plus button logs to
the selected day, and a selection left over from browsing March would quietly
book your next drink three months into the past.

### The month view

The month view is the ordinary grid of a month, and the view you start in.
The month is named above the grid, with an arrow either side for paging.

Days with entries carry a dot: blue for a drinking day inside your limits,
red for one that broke a limit. Days with nothing logged carry none.

Tap a day to select it and its entries appear below, where you can edit and
delete them exactly as on Today. The plus button at the
top right, which only appears
once a day is selected, logs to that day. This is how you catch up on what
you did not record at the time.

### The year view

The year view lays out the twelve months of a year as a grid of small
squares, one per day. The year is shown above the grid, with an arrow either
side for moving between years. The legend below names the three states:
no entry, under limit,
over limit. Today has a ring around it.

Tap a month to drop into the month view for it. The individual squares are
not tappable. Switching selects no day; pick one in the month view you land
in.

Two stretches stay blank on purpose: everything after today, and everything
before your Statistics From date. The app has nothing to say about
either, and a
grey square there would read as a day without alcohol.
Include all history in the settings brings the older entries back if you
want them.

## Taking stock: the statistics

The Statistics screen does the arithmetic. You choose the length of the
period at the top - Week, Month or Year - and everything below
follows that choice. Every calculation ignores entries from before your
Statistics From date. If there is nothing in the period you picked,
the sections stay
where they are and show zeroes.

### Moving back through time

Below the period buttons, the stretch you are looking at is spelled out as
exact dates. The current month ends today rather than at month's end, and if
you have set a Statistics From date, the stretch begins there. So what
stands there is precisely what the figures below cover.

An arrow sits either side of it. The left one steps a period back, the right
one back toward the present. The arrows are the only way; there is no swipe
across the screen.

Two things bound the paging: forwards you cannot go past the current period,
and backwards you stop at your Statistics From date, or at your oldest
entry if you have not set one. Come to the screen afresh and it is back on
the present period.

Everything here follows the period you chose, figures and charts alike.
Trend vs. Previous Period always compares with the period of the same length directly
before it, so March against February.

### The figures

- **Total in Period** - grams of pure alcohol in the period.
- **Average per Day** - the average across every calendar day.
- **Average per Drinking Day** - the average across drinking days only. The gap
  between this and the one above is worth reading: a wide gap means you drink
  rarely and heavily when you do.
- **Days Over Daily Limit** - days on which you passed your daily limit.
- **Days Over 7-Day Limit** - drinking days where that day and the six
  before it added up to more than your seven-day limit.
- **Days Over Drinking Days Limit** - drinking days that sat above your
  drinking-day limit within their seven-day window: the fifth drinking day in
  seven, say, when you allow yourself four.
- **Abstinent Days** - days in the period with nothing logged.

Three more figures follow under Abstinence & Trend: **Current Abstinence**
counts the days since your last drink, **Longest Abstinence** the longest
stretch without alcohol in the period, and **Trend vs. Previous Period** points the
way the comparison with the previous period runs.

### The charts

A bar chart traces consumption across the period. Three readings of your
pattern follow it:

**Time of Day** splits the day into eight three-hour slots and
gives the average grams per day for each. This is where you see whether your
drinking sits in the evening or runs through the day. The section appears
only if you drank at all in the period.

**Weekday** gives the same average per day of the week.

**Categories** shows as a ring how your drinking splits
across the six categories.

Pull the screen down to reload the figures.

## Getting your data out

The Export section of the Statistics screen offers two formats.

**Export CSV** writes a table with one row per entry, ready for a
spreadsheet such as [LibreOffice](https://www.libreoffice.org/) Calc. Numbers
are written machine-readably with a decimal point, whatever language the app
is in.

**Export PDF report** produces a two-page report: the headline figures, a month
by month table, the long-term trend, your pattern by category, time of day
and day of the week, and a closing section on risky drinking and abstinence.
It is meant to be readable across a table in a counseling session.

Both formats ask for a period first. What they offer is everything the app
evaluates: from your Statistics From date through to today, or, with no
such date set, from the start of the period you are looking at.
Pick a different stretch in the dialog if you want one.

The PDF covers exactly the period you pick, not merely the days inside it
that you logged something on. Export July having drunk on eleven days and you
get a report over thirty-one days, with twenty abstinent days and a daily
average divided by thirty-one. The month table lists every month the period
touches, including one with nothing logged in it at all. This is what makes
the report agree with the Statistics screen. If the period you pick ends
today, the report ends yesterday for as long as today is still dry: an
unfinished day would drag the average down and count as abstinent before it
has had its chance.

The system file picker opens afterwards, and you
choose where the file goes: into Files, into cloud storage, or straight into
another app.

## Further settings

### Keeping your data safe

**Nothing you record leaves this device on its own.**
Libellus Potionis keeps its data out of every device
backup, iCloud and computer backups alike; the Include in device backup switch under
Security reverses that (see "Access and visibility"). While it is off,
changing phones, factory-resetting or reinstalling leaves a backup you made
yourself as the only thing that carries your data across.

A backup is a single JSON file. The Include settings switch
decides whether your settings go into it. It is on again every time you open
the settings; the app does not remember how you left it. Turn it off and the
backup carries only the drinks catalog and the entries, and importing it
leaves the settings on the receiving device alone.

Moving your data to a new device:

1. On the old device, choose "Settings" -> Backup ->
   Export. Keep the file somewhere safe, a
   [Signal](https://signal.org/) note to yourself for instance.
2. Install Libellus Potionis on the new device.
3. There, choose "Settings" -> Backup -> Import
   and restore.

The app asks how you want the import to go. Replace throws away
what is on the device: the drinks catalog, the entries, and the settings if
the backup carries any. Merge leaves your drink definitions and
entries where they are and fills in what is missing. Entries you already have
are not duplicated, and your current settings are not overwritten.

### Access and visibility

The Security section holds
three switches.

**Biometric Lock** asks for Face ID, Touch ID or
your passcode whenever you open the app. Turning the lock on or off
requires that same authentication. It applies again when you leave the app
and come back, though not if you come back within thirty seconds. The menu at
the top right also carries Lock app, which locks the app there and then.

**Show in app switcher** is off to begin with. While screenshots are
off, the app's window stays covered in the app
switcher. Someone who picks up your unlocked phone and thumbs through
the open apps sees nothing there.
A screenshot itself is beyond the app's reach: iOS offers no way to
prevent one, and this switch does not change that.

**Include in device backup** is off to begin with as well. While it is off,
the app's data stays out of every device backup, iCloud and computer backups
alike. Turn it on and your data survives restoring a device from its backup -
and also sits wherever that backup sits.

### Appearance and language

The Appearance section offers three things.

**Color Scheme**: System, or Light or Dark
regardless of what the system does.

**Language**: the app's language, again independent of the system.
(System) hands it back to the system.

**Alternative Status Symbols** gives the status dots a shape as well as a color,
so the three states stay apart when red, yellow and green do not.

## How the figures are worked out

### From milliliters to grams

Every entry is converted to grams of pure alcohol as it is saved:

**grams = milliliters × strength × 0.789**

0.789 is the density of ethanol in grams per milliliter. Half a liter of beer
at 5 % therefore comes to 500 ml × 0.05 × 0.789 g/ml, or about 19.7 g. Every
limit, every figure and every export works from that number and never from
milliliters. It is the only thing that makes a glass of wine and a shot of
spirits comparable at all.

### The blood alcohol estimate

Given a body weight, Libellus Potionis estimates blood alcohol concentration
with the
[Widmark formula](https://en.wikipedia.org/wiki/Blood_alcohol_content):

**BAC [per mille] = A / (P × r) − β × t**

A is the pure alcohol in grams, P your body weight in kilograms, r the
distribution coefficient, β the elimination rate of about 0.15 per mille an
hour, and t the hours since your first drink. The app shows the result in
per mille, as the screen does.

The app does not ask your sex, and so errs on the cautious side: r is fixed
at 0.6, the lower of the two classical coefficients. A smaller r spreads the
same alcohol through a smaller volume and so returns the higher of the two
figures. The estimate is meant to run high rather than low. The elimination
rate, by contrast, is an average; individually it runs somewhere between 0.10
and 0.20 per mille per hour, and if you clear alcohol slowly you are above
the figure on screen.

What comes out is a model, not a measurement. It replaces no breathalyser,
and it cannot tell you whether you are fit to drive.

### The logical day

A drink belongs to the day that began at New Day Starts At, not to the day on
the clock. With the default of four in the morning, a glass at half past one
still counts toward the day before. The rule holds throughout the app, and
across clock changes.

### The rolling week

Your seven-day limit and your drinking days do not follow the calendar week.
They cover today and the six days behind it, so the window moves along with
you. A heavy Saturday stays in view until it is six days old, and drops out
on the Saturday after.
