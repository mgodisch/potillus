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

Prefer `make screenshots`, which also cleans the status bar (Demo Mode)

and renders the PDF report pages as screenshots 07/08.

### android deploy

```sh
[bundle exec] fastlane android deploy
```

Upload the SIGNED release App Bundle and the store metadata to Google Play.

Build the bundle first with `make bundle` (needs a configured signing key,

see android/keystore.properties.example). Options (all optional):

  track:<name>   Play track to publish to (default: internal). Publishing to

                 production requires passing track:production explicitly.

  status:<name>  release status: draft|completed|halted|inProgress (default: draft)

Example:  bundle exec fastlane deploy track:internal status:completed

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
