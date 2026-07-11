fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Android

### android screenshots

```sh
[bundle exec] fastlane android screenshots
```

Capture the in-app Play-Store screenshots (all store locales) via screengrab.

Prefer `make screenshots-android`, which also cleans the status bar (Demo Mode)

and renders the PDF report pages as screenshots 07/08.

### android testing

```sh
[bundle exec] fastlane android testing
```

Upload the SIGNED release App Bundle to the closed-testing ALPHA track

and OVERWRITE the store listing + release notes on Google Play (titles,

short/full descriptions, feature graphics, screenshots and changelogs

from fastlane/metadata/android/). Build the bundle first with

`make -C android bundle` (or `make release-android`); the Makefile `push-playstore`

target guards that prerequisite -- this lane does NOT build it.

Options (all optional):

  track:<name>   Play track (default: alpha). For production use the

                 dedicated `production` lane below.

  status:<name>  release status draft|completed|halted|inProgress

                 (default: completed -- testing tracks expect completed).

Example:  bundle exec fastlane testing track:beta status:draft

### android production

```sh
[bundle exec] fastlane android production
```

Upload the SIGNED release App Bundle to the PRODUCTION track and OVERWRITE

the store listing + release notes on Google Play. Same build prerequisite

as `testing` (this lane does NOT build the AAB). Staged as a DRAFT by

default: the release waits in the Play Console for you to review and

publish manually, rather than going live automatically. NOTE: a new

personal developer account cannot publish to production until the

closed-testing gate is cleared (12 testers / 14 days -- docs/PLAY_STORE.md §5).

Options (all optional):

  track:<name>   Play track (default: production).

  status:<name>  release status draft|completed|halted|inProgress

                 (default: draft -- stage for manual review/publish).

Example:  bundle exec fastlane production status:completed

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
