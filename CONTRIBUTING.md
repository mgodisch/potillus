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

# Contributing to Libellus Potionis

Libellus Potionis is a personal Android alcohol tracker and a **teaching
project**. The goal of every change is to keep the code readable, well-tested,
and well-documented for developers learning Android development.

---

## Table of Contents

1. [Project philosophy](#1-project-philosophy)
2. [Submitting changes](#2-submitting-changes)
3. [Architecture rules](#3-architecture-rules)
4. [Coding conventions](#4-coding-conventions)
5. [Testing strategy](#5-testing-strategy)
6. [Translation workflow](#6-translation-workflow)
7. [Versioning & release checklist](#7-versioning--release-checklist)
8. [Data persistence — schema freeze rules](#8-data-persistence--schema-freeze-rules)

---

## 1. Project philosophy

| Principle | Rationale |
|---|---|
| **Privacy first** | No network permission, no analytics, no crash reporting. All data stays on-device. |
| **No DI framework** | Hilt and Koin add compile-time complexity. Manual DI via `PotillusApp` lazy singletons is sufficient for a single-module, single-user app. |
| **Minimal dependencies** | Every library must justify its presence. Prefer AndroidX stable releases over alpha/beta. |
| **Documented code** | Comments explain *why*, not *what*. Every public function has a KDoc. |
| **English everywhere** | All source code, KDoc, test comments, build files, and documentation are in English. String resources (UI strings) are the only exception – they must be in the target language of each locale. |

---

## 2. Submitting changes

Libellus Potionis is a personal project maintained by a single author. Feedback
is always welcome; external code contributions are considered on a case-by-case
basis. The steps below describe how a change moves from idea to merge. All
participation in the project is expected to follow our
[Code of Conduct](CODE_OF_CONDUCT.md).

1. **Open an issue first.** Before writing code, describe the bug or proposed
   enhancement in the [Codeberg issue
   tracker](https://codeberg.org/godisch/potillus/issues). This lets the
   maintainer confirm the change fits the project's scope and privacy-first
   philosophy (Section 1) before anyone invests effort. Small, obvious fixes
   (typos, an off-by-one in a comment) may skip this step.
2. **Submit the change as a pull request** against the `main` branch of the
   [canonical repository](https://codeberg.org/godisch/potillus). If you cannot
   use Codeberg, a plain patch or `git format-patch` series sent to
   [android@godisch.de](mailto:android@godisch.de) is accepted as an
   alternative.
3. **Meet the acceptance requirements.** Every change must follow the
   conventions in the rest of this document: the architecture rules
   (Section 3), coding and KDoc conventions (Section 4), the testing strategy
   (Section 5), and — for any user-facing string — the translation workflow
   (Section 6). In particular, per the mandatory test policy in Section 5, major
   new functionality MUST include automated tests covering it in the same change.
   `./gradlew test` must pass and `tools/release-check.sh` must stay green.
4. **Review and merge.** The maintainer reviews every pull request and is the
   sole merger. Expect review comments; a change is merged only once it builds,
   its tests pass, and it upholds the documented conventions. There is no
   separate CI service — the maintainer runs the build and the release gate
   locally as part of the review. The project's decision-making model and roles
   are described in [GOVERNANCE.md](docs/GOVERNANCE.md).

### Good first issues

New or casual contributors are welcome to start with small, self-contained tasks
that need no deep familiarity with the codebase. Issues suitable for a first
contribution are marked in the [issue
tracker](https://codeberg.org/godisch/potillus/issues) with the `good first
issue` label; filter by that label to find current ones. Small tasks that fit
this project especially well include:

- **Translation review.** English and German are hand-authored; the other
  locales are machine-generated (see Section 6). Reviewing and correcting the
  strings for a language you speak natively is a valuable, self-contained
  contribution.
- **Documentation.** Clarifying or correcting the README, this guide, or the
  in-app user guide.
- **Test cases.** Adding tests for existing behaviour that is not yet covered.

If you spot a small improvement that is not yet tracked, feel free to open an
issue describing it.

### Developer Certificate of Origin (DCO)

All contributions to this project are made under the
[Developer Certificate of Origin (DCO)](https://developercertificate.org/), a
lightweight statement that you wrote the contribution yourself or otherwise have
the right to submit it under the project's license (GPL-3.0-or-later).

To certify this, sign off on every commit by adding a `Signed-off-by` line that
matches the author identity of the commit:

```
Signed-off-by: Your Name <your.email@example.org>
```

Git adds this line automatically when you commit with the `-s` (`--signoff`)
flag:

```sh
git commit -s -m "Your commit message"
```

To avoid having to remember `-s`, add a repository alias — note that
`format.signOff` affects only `git format-patch` / `git send-email`, not
`git commit`, so it does **not** sign off ordinary commits:

```sh
git config alias.cs 'commit -s'    # then commit with: git cs -m "…"
```

Alternatively, append the trailer automatically with a `prepare-commit-msg`
hook (idempotent — it never adds a duplicate line):

```sh
cat > .git/hooks/prepare-commit-msg <<'EOF'
#!/bin/sh
git interpret-trailers --if-exists doNothing \
    --trailer "Signed-off-by: $(git config user.name) <$(git config user.email)>" \
    --in-place "$1"
EOF
chmod +x .git/hooks/prepare-commit-msg
```

Sign-off is a plain text line certifying agreement with the DCO; it is **not** a
cryptographic signature and requires no key — only that your Git `user.name` and
`user.email` are configured. Pull requests whose commits are not signed off may
be asked to add the sign-off before they are merged.

### Commit signing and merge workflow

Beyond the DCO sign-off (a plain-text line), the repository requires every commit
to carry a **cryptographic signature**. Branch protection on Codeberg rejects
pushes that contain unsigned or unverifiable commits on every branch except
`main`; `main` itself is merged **fast-forward-only**, so the already-signed
commits flow onto it unchanged (rather than the forge creating an unsigned merge
commit). Enable signing locally and register the matching **public** key with
your Codeberg account, so the forge can verify the signature:

```sh
git config commit.gpgSign true
git config user.signingKey <your-key-id>
```

For SSH signing instead of GPG, set `git config gpg.format ssh` and point
`user.signingKey` at your public-key file. If the public key is not on your
Codeberg account, the commit counts as *unverifiable* and the push is rejected.

Because merges are fast-forward-only, the branch must sit directly on top of the
current `main`. Rebase before opening or updating a pull request; with
`commit.gpgSign` set, the rebased commits are re-signed automatically:

```sh
git fetch origin
git rebase origin/main          # to squash: git rebase -i --gpg-sign origin/main
git push --force-with-lease
```

### Code review requirements

Every change is reviewed before it is merged. Because the project currently has a
single maintainer, the maintainer is the reviewer and the sole merger; external
contributions are reviewed as pull requests (or emailed patch series). Until a
continuous-integration service is in place, the reviewer runs the full build, the
test suite, and the release gate locally as part of each review.

A change is reviewed against this checklist — the same requirements a contributor
is expected to have met (Section 2, step 3):

- **Scope and philosophy.** The change fits the project's purpose and
  privacy-first design, and adds no network access, accounts, tracking, or new
  permissions (Section 1).
- **Architecture.** It respects the architecture rules (Section 3).
- **Code quality.** It follows the coding and KDoc conventions (Section 4) and
  introduces no new compiler or lint warnings (the build treats warnings as
  errors).
- **Tests.** New major functionality is covered by automated tests in the same
  change (the mandatory test policy, Section 5), and existing tests still pass.
- **Localization.** Any new or changed user-facing string is complete across all
  locales per the translation workflow (Section 6), so `LocaleSyncTest` passes.
- **Licensing.** New source files carry the standard copyright-and-licence header,
  and the change respects third-party licences (see COPYING.md).
- **Provenance.** All commits are signed off under the DCO (see above).
- **Data safety.** Any change touching persistence honours the schema-freeze
  rules (Section 8).

To be accepted (merged), a change MUST build cleanly, MUST have `./gradlew test`
passing and `tools/release-check.sh` green, MUST uphold every item above, and
MUST be judged a worthwhile improvement free of known defects that would argue
against its inclusion. Changes that do not yet meet these requirements receive
review comments and are merged only once resolved.

---

## 3. Architecture rules

```
data/          ← Room entities, DAOs, DataStore preferences, repositories
data/security/ ← Android Keystore-backed secret store for the encrypted prefs
domain/        ← Pure Kotlin: models, AlcoholCalculator, DayResolver, and other
                 framework-free logic (ChartBucketing, LocaleDetector, Trend)
l10n/          ← Locale registry (SupportedLocales), locale detection, and
                 date/number formatting helpers
ui/            ← Compose screens, ViewModels, navigation, theme, components
util/          ← Export helpers (CSV, PDF, JSON backup) and the GPL notice
```

- **No Android imports in `domain/`.**  
  `AlcoholCalculator` and `DayResolver` must compile without the Android SDK.
  This keeps them unit-testable on the JVM without an emulator.
- **No Room imports above `data/`.**  
  ViewModels and screens never import `@Entity`, `@Dao`, or `@Query`.
  Repositories expose domain models only.
- **No `Context` in ViewModels except `SettingsViewModel`.**  
  `SettingsViewModel` extends `AndroidViewModel` specifically to call
  `Application.getString()` for localised status messages. All other ViewModels
  must remain context-free.

---

## 4. Coding conventions

- **Kotlin style guide:** follow the [official Kotlin coding conventions](https://kotlinlang.org/docs/coding-conventions.html).
- **Automatic enforcement:** the Kotlin style is enforced automatically by
  [ktlint](https://pinterest.github.io/ktlint/). Before submitting, run
  `./gradlew ktlintFormat` to auto-format your changes and `./gradlew ktlintCheck`
  to verify; `ktlintCheck` also runs as part of the standard `check` task. Style
  settings live in the repository-root `.editorconfig`.
- **KDoc:** all public classes, functions, and properties must have a KDoc comment.
  Use `@param`, `@return`, and `@throws` where relevant.
- **Constants:** domain constants (limit values, Widmark coefficients) belong in
  `AlcoholCalculator` as `const val` with units in the name or KDoc (e.g. `BINGE_THRESHOLD = 60.0` g).
- **Default values:** default values in `AppSettings` and `AppPreferences` must match.
  When adding a new preference key, add the default in both places at the same time.
- **Enum persistence:** enums stored in Room or DataStore must be stored by their
  `.name` string (not ordinal). Always deserialise with
  `runCatching { Foo.valueOf(name) }.getOrDefault(Foo.DEFAULT)` for forward compatibility.
- **Accessibility labels:** every INTERACTIVE control needs an accessible name.
  In practice, an `Icon` inside an `IconButton` (or any tappable icon-only
  surface) must set a localized `contentDescription = stringResource(...)`;
  only purely decorative icons that sit next to their own visible text label may
  use `contentDescription = null`. `tools/release-check.sh` §13 enforces this for
  `IconButton` icons and fails the build on a regression. This is a labelling
  invariant only — the project does not claim a WCAG conformance level (see
  `docs/ROADMAP.md` → Accessibility for the honest status and the open Level AA
  gaps).

---

## 5. Testing strategy

The project ships two test source sets. Unit tests run on the JVM without an
emulator; instrumented tests run on a device or emulator.

| Layer | Kind | Where |
|---|---|---|
| Domain logic (`AlcoholCalculator`, `DayResolver`, `ChartBucketing`, `Trend`, `LocaleDetector`) | Unit, pure Kotlin | `app/src/test/` |
| Data layer (repositories, `EntityMapping`, `AppPreferences` I/O, `KeystoreSecretStore`) | Unit, with in-memory fakes (`test/.../fake/`) | `app/src/test/` |
| ViewModels | Unit, with fake repositories/prefs | `app/src/test/` |
| l10n & util (number/date formatting, CSV/PDF/backup, templating) | Unit | `app/src/test/` |
| Locale sync & completeness (`LocaleSyncTest`) | Unit | `app/src/test/` |
| Room migrations (`MigrationTest`) | Instrumented (`Room.testing`) | `app/src/androidTest/` |
| Compose UI components (`EntryListItemUiTest`, `LimitBarUiTest`) | Instrumented UI | `app/src/androidTest/` |
| Locale formatting on real Android | Instrumented | `app/src/androidTest/` |
| Screenshot capture (fastlane/screengrab) | Instrumented | `app/src/androidTest/screenshot/` |

Run the unit tests with `./gradlew :app:test` and the instrumented tests with
`./gradlew :app:connectedAndroidTest` (device/emulator required).

**Test policy (mandatory).** As major new functionality is added to the
software, automated tests covering that functionality MUST be added to the
project's automated test suite as part of the same change. A change that
introduces significant new behavior without accompanying tests will not be
merged.

**Rules for tests:**
- The domain layer is the coverage floor: every public function in
  `AlcoholCalculator` and `DayResolver` must have unit tests, and new domain
  logic ships with its own tests.
- Test names use backtick strings describing the scenario, e.g.  
  `` `trafficLight RED when no serving fits` ``.
- Test comments and `assertTrue` messages must be in **English**.
- Cover all boundary conditions: zero inputs, negative inputs, exactly-at-limit,
  exactly-one-over-limit, future dates.

**Coverage (Kover):**
The project measures test coverage with Kover. Generate a report with:

```
./gradlew :app:koverHtmlReport   # HTML report under app/build/reports/kover
./gradlew :app:koverXmlReport    # machine-readable XML
./gradlew :app:koverLog          # prints total coverage to the console
```

Coverage is measured over the unit-testable code — the `domain`, `l10n`, and
repository layers, the pure `util` helpers, and the screen ViewModels. Code that
requires the Android runtime is excluded, because it is exercised by the
instrumented tests in `src/androidTest` rather than by JVM unit tests: the
Compose UI (`ui.theme`, `ui.component`, `ui.nav`, and all `@Composable`
functions), the app entry points and manual DI factory (`MainActivity`,
`PotillusApp`, `AppViewModelFactory`), the Room database/DAO layer
(`data.db.dao`, `AppDatabase`, generated `*_Impl`), the DataStore preferences
(`data.prefs`), the Keystore access (`data.security`), the Room-transaction
repository (`BackupRepository`, which uses `db.withTransaction`), the PDF/WebView
renderers (`PdfReportBuilder`, `WebViewPdfPrinter`), and generated code (`R`,
`BuildConfig`, Compose `ComposableSingletons`). Individual Android-I/O methods
inside otherwise-testable classes (the MediaStore export/import in `BackupManager`
and `CsvExporter`, and the ViewModel export/import actions) are marked with the
`@AndroidIoBound` annotation and excluded via `annotatedBy(...)`, so the reported
figure reflects the JVM-unit-testable code. The plain `@Entity` data classes stay in scope. The
targets are statement coverage >= 80% (silver) and >= 90% (gold), plus branch
coverage >= 80% (gold); build-breaking enforcement is added once those targets
are reached.

---

## 6. Translation workflow

Libellus Potionis is fully localized. String resources live in
`app/src/main/res/values-<qualifier>/strings.xml`, where `<qualifier>` is the
Android resource qualifier (e.g. `values-fr/`, `values-pt-rBR/`,
`values-zh-rCN/`). The base (English) strings live in `res/values/` — there is
**no** `values-en/` directory; Android falls back to `res/values/` for English.

**Single source of truth.** The authoritative list of supported languages is
[`SupportedLocales`](app/src/main/kotlin/de/godisch/potillus/l10n/SupportedLocales.kt)
(`SupportedLocales.ALL`). It is consumed by the in-app language selector
(`LanguageDropdown` in `SettingsScreen`) and by
`PotillusApp.applyLanguageOnFirstLaunch()`, which derives its candidate set from
`SupportedLocales.TAGS` (never hard-coded). `res/xml/locale_config.xml` (the
system per-app language picker) must mirror this list exactly. `LocaleSyncTest`
enforces that `SupportedLocales.ALL`, `locale_config.xml`, and the set of
`values-<qualifier>/` directories all agree, and that every `strings.xml` is
complete.

**Translation quality.** Only **English** (`res/values/`) and **German**
(`res/values-de/`) are written and maintained by the author. **All other
locales are machine-generated** and shipped as-is without native-speaker review.
They are therefore likely to contain awkward or incorrect phrasing.
Native-speaker corrections are very much appreciated — please open an issue or a
pull request (see Section 2) with the language and the improved string(s).

**Rules:**
1. Add every new string key to **all** locale files at the same time (the base
   `res/values/strings.xml` plus every `values-<qualifier>/`). `LocaleSyncTest`
   fails the build on any missing key.
2. The base English text in `res/values/strings.xml` is the reference for
   meaning; `res/values-de/strings.xml` is the hand-authored German reference.
   When in doubt, English takes precedence.
3. Do not use string formatting characters (`%1$s`, `%2$d`) unless the
   corresponding Java format call exists in the Kotlin source.

**Adding a new locale:**
1. Create `app/src/main/res/values-<qualifier>/strings.xml` with every key
   translated (copy `res/values/` or `res/values-de/` as the starting point).
2. Register the locale in `SupportedLocales.ALL` as a `Locale(tag, autonym)`
   entry, where `tag` is a plain BCP-47 tag with **no** `r` region prefix
   (`"pt-BR"`, `"zh-CN"`) and `autonym` is the language name in its own script.
   Keep the list sorted alphabetically by autonym.
3. Add `<locale android:name="<tag>"/>` to `res/xml/locale_config.xml`.
4. Run `./gradlew :app:test` (`LocaleSyncTest`) to confirm all three artefacts
   are in sync and the new `strings.xml` is complete.

---

## 7. Versioning & release checklist

**Versioning.** The version string is three-part `MAJOR.MINOR.PATCH`. Routine
changes (fixes, small improvements) bump the PATCH component; larger feature sets
bump MINOR. `versionCode` in `build.gradle.kts` increases by at least 1 every
release. `versionName`, the top `CHANGELOG.md` entry, the `README.md` title and
the `proguard-rules.pro` header must always carry the same string — `release-check.sh`
§1 enforces this.

**Changelog.** `CHANGELOG.md` is forward-only: it begins at the published baseline
and records what changes from there. It is deliberately *not* the home of design
rationale — the reasons behind a decision live in the KDoc/comments beside the code
they explain, so the source stays self-explanatory without the changelog.

Before tagging a new version:

- [ ] `README.md` header updated to the new version number.
- [ ] `app/build.gradle.kts` `versionName` and `versionCode` updated.
- [ ] `CHANGELOG.md` entry written in English.
- [ ] All new public functions have KDoc.
- [ ] All new string keys present in every locale file (enforced by LocaleSyncTest).
- [ ] `locale_config.xml` and `SettingsScreen.kt` language list in sync.
- [ ] Unit tests pass: `./gradlew test`.
- [ ] No new German (or other non-English) comments in source files.
- [ ] `proguard-rules.pro` reviewed if new reflection-based code was added.
- [ ] Room schema version bumped and `MIGRATION_X_Y` added if the database schema changed.
- [ ] New `app/schemas/<version>.json` committed (generated by `./gradlew build`).
- [ ] Dependencies checked for known vulnerabilities with `osv-scanner` against
      the generated CycloneDX SBOM (see SECURITY.md, "Dependency monitoring").
- [ ] Create the release tag as a **GPG-signed** annotated tag with
      `git tag -s vX.Y.Z -m "vX.Y.Z"`, signed with the maintainer's key, and push
      it. Tags are verifiable with `git tag -v vX.Y.Z` (see SECURITY.md,
      "Verifying releases").
- [ ] Publish the release on Codeberg from the signed tag and attach the CycloneDX
      SBOM (`android/app/build/outputs/sbom/libellus-potionis-sbom.json`, built by
      `make release`/`make bundle`) as a release asset, so every released version is
      accompanied by its software bill of materials.

To avoid forgetting the signature, configure Git to sign annotated tags
automatically in this repository (this requires `user.signingkey` to be set):

```sh
git config tag.gpgSign true
```

Note this applies to annotated tags (`git tag -a`/`-m`/`-s`); a lightweight
`git tag vX.Y.Z` creates no tag object and is not signed, so always create the
release tag as an annotated tag.

### Updating the Gradle version

The Gradle distribution is pinned by checksum in
`android/gradle/wrapper/gradle-wrapper.properties` (`distributionSha256Sum`), so
Gradle verifies every download against a known-good hash. This is supply-chain
hardening and also underpins OSPS Baseline `OSPS-QA-05.02` (the committed
`gradle-wrapper.jar` stays a stock, verifiable wrapper). The pin is
version-specific, so when bumping Gradle, regenerate the wrapper rather than
editing the version by hand — this refreshes both the URL and the checksum:

```sh
./gradlew wrapper --gradle-version <X.Y.Z> \
    --gradle-distribution-sha256-sum <sha256-of-gradle-X.Y.Z-bin.zip>
```

The official `-bin.zip` checksum is published at
<https://gradle.org/release-checksums/>.

---

## 8. Data persistence — schema freeze rules

The three persistence surfaces are considered **frozen**: their
on-disk/on-wire format is stable, and any change must be backward-compatible or
ship explicit migration code. The goal is that a user who installs the app never
loses their configured drinks, logged entries, or settings across an update.

**Compatibility guarantee (since the first F-Droid release, v0.77.4).** From
that release onward the database and the JSON backup format are guaranteed
backward-compatible: any later app version can open a database and import a
backup produced by v0.77.4 or newer. Concretely, Room migrations are
forward-only and never destructive (`fallbackToDestructiveMigration` is banned,
see §8.1), and the backup importer keeps reading every `BACKUP_VERSION` from
that baseline up to the current one (older/newer field handling in §8.3). The
rules in §8.1–§8.4 are how this guarantee is upheld in practice; do not weaken
them without treating it as a breaking change to that promise.

The three surfaces and their rules:

### 8.1 Room database (`drinks`, `entries`)

- **Never** edit a committed schema JSON in `app/schemas/`. Those files are the
  historical record migrations are validated against.
- To change the schema: bump `@Database(version = N)` in `AppDatabase`, add a
  `val MIGRATION_(N-1)_N = object : Migration(N-1, N) { … }`, and register it via
  `Room.databaseBuilder().addMigrations(...)`.
- Build once so Room exports `app/schemas/.../N.json`, and **commit** it.
- Add a `migrate(N-1)To(N)_…()` case to `MigrationTest` (androidTest) following
  the existing pattern. `runMigrationsAndValidate` will fail the build if the
  migration does not reproduce the committed schema.
- **Never** add `fallbackToDestructiveMigration()` — it silently wipes user data.
- The denormalised columns on `entries` (drinkName/volumeMl/alcoholPercent/
  gramsAlcohol) are intentional: historical records must not change when a drink
  definition is later edited. Do not "normalise them away".

### 8.2 Preferences (encrypted DataStore, `AppPreferences`)

- **Never rename** an existing key string (e.g. `"theme_mode"`) and **never
  change its value type** (e.g. int → string) after release — either silently
  loses the stored value. Pick a new key instead and migrate if needed.
- Adding a **new** key is safe and needs no migration: the read mapping uses
  `prefs[KEY] ?: default`, so an absent key falls back to its default.
- Enum-valued keys are parsed with `runCatching { valueOf(...) }.getOrDefault(...)`.
  Keep that pattern: it means renaming/removing an enum constant degrades to the
  default instead of crashing. Avoid renaming persisted enum constants regardless.

### 8.3 Backup / restore (JSON, `BackupManager`)

- The JSON root carries a `"version"` integer (`BACKUP_VERSION`). Bump it only
  for **additive** changes, and keep reading older files: required fields use
  `getXxx`, optional/newer fields use `optXxx(key, default)`.
- The importer already rejects files newer than it understands
  (`ImportError.VersionTooHigh`). Preserve that guard.
- The exported field names mirror the entity columns; if you rename a column,
  keep reading the old JSON field name for backward compatibility.

### 8.4 Identifiers that must never change

- `applicationId` / `namespace` (`de.godisch.potillus`).
- Database file name (`potillus.db`).
- DataStore file name and its Keystore alias (`potillus_prefs_key`).
