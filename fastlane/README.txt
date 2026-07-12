Fastlane store metadata
=======================

This tree holds the store-listing metadata for Libellus Potionis. It follows
the layout that both `fastlane supply` (Google Play) and F-Droid read from a
`fastlane/metadata/android/<locale>/` directory:

    metadata/android/
        en-US/                       English (United States) listing
            title.txt                app title          (max 30 characters)
            short_description.txt     short description  (max 80 characters)
            full_description.txt      full description   (max 4000 characters)
            changelogs/
                <versionCode>.txt     release note for that versionCode
                                      (max 500 characters — F-Droid's limit)
            images/                   store graphics (see images/PLACEHOLDERS.txt)
                phoneScreenshots/
        de-DE/                        German (Germany) listing — same structure

Conventions used here
---------------------
* Locale folders use Play's BCP-47 style codes (en-US, de-DE). F-Droid accepts
  these as well, so a single tree serves both stores.
* Release notes are named after the integer `versionCode` from
  app/build.gradle.kts (versionCode <N> -> changelogs/<N>.txt). This coupling is
  verified on every build by tools/release-check.sh (section 1), which runs as
  part of the Makefile `prereq` target: add a note for each locale whenever you
  bump the versionCode, or the build fails.
* Titles and descriptions intentionally do NOT contain the version number, so
  they need no edit on every release.
* Text files are UTF-8 and end with a trailing newline; trailing whitespace is
  insignificant. The character limits above are the store maxima — staying well
  under them is safest.

Adding a new language
---------------------
Create metadata/android/<locale>/ with title.txt, short_description.txt,
full_description.txt and changelogs/<versionCode>.txt. Provide images/ only if
you have localized graphics; otherwise the en-US images are used as the default.
