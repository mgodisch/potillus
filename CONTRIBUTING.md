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
2. [Architecture rules](#2-architecture-rules)
3. [Coding conventions](#3-coding-conventions)
4. [Testing strategy](#4-testing-strategy)
5. [Translation workflow](#5-translation-workflow)
6. [Release checklist](#6-release-checklist)
7. [Data persistence — schema freeze rules](#7-data-persistence--schema-freeze-rules)

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

## 2. Architecture rules

```
data/          ← Room entities, DAOs, DataStore preferences, repositories
domain/        ← Pure Kotlin: models, AlcoholCalculator, DayResolver
ui/            ← Compose screens, ViewModels, navigation
util/          ← Export helpers (CSV, PDF, JSON backup)
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

## 3. Coding conventions

- **Kotlin style guide:** follow the [official Kotlin coding conventions](https://kotlinlang.org/docs/coding-conventions.html).
- **KDoc:** all public classes, functions, and properties must have a KDoc comment.
  Use `@param`, `@return`, and `@throws` where relevant.
- **Constants:** domain constants (limit values, Widmark coefficients) belong in
  `AlcoholCalculator` as `const val` with units in the name or KDoc (e.g. `BINGE_THRESHOLD = 48.0` g).
- **Default values:** default values in `AppSettings` and `AppPreferences` must match.
  When adding a new preference key, add the default in both places at the same time.
- **Enum persistence:** enums stored in Room or DataStore must be stored by their
  `.name` string (not ordinal). Always deserialise with
  `runCatching { Foo.valueOf(name) }.getOrDefault(Foo.DEFAULT)` for forward compatibility.

---

## 4. Testing strategy

| Layer | Tool | Where |
|---|---|---|
| Domain logic | JUnit 4, pure Kotlin | `app/src/test/` |
| UI / ViewModel | (future: Compose testing) | — |
| Database | (future: Room in-memory tests) | — |

**Rules for unit tests:**
- Every public function in `AlcoholCalculator` and `DayResolver` must have test coverage.
- Test names use backtick strings describing the scenario, e.g.  
  `` `trafficLight RED when no serving fits` ``.
- Test comments and `assertTrue` messages must be in **English**.
- Cover all boundary conditions: zero inputs, negative inputs, exactly-at-limit,
  exactly-one-over-limit, future dates.

---

## 5. Translation workflow

Libellus Potionis supports locales. All string resources live in
`app/src/main/res/values-<code>/strings.xml`.

**Rules:**
1. Add every new string key to **all locale files** at the same time.
2. The English file (`values-en/strings.xml`) is the reference for meaning.
   When in doubt, the English text takes precedence.
3. Machine translation is acceptable as a first pass, but native-speaker review
   is required before any public release.
4. Do not use string formatting characters (`%1$s`, `%2$d`) unless the corresponding
   Java format call exists in the Kotlin source.
5. The `locale_config.xml` and the language list in `SettingsScreen.kt` must always
   be kept in sync with the set of `values-<code>/` folders.

**Adding a new locale:**
1. Create `app/src/main/res/values-<code>/strings.xml` with every string key translated.
2. Add `<locale android:name="<code>"/>` to `locale_config.xml`.
3. Add `"<code>" to "<Native name>"` to the `languages` list in `SettingsScreen.kt`.
4. Add `"<code>"` to the `supported` set in `PotillusApp.applyLanguageOnFirstLaunch()`.

---

## 6. Versioning & release checklist

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

---

## 7. Data persistence — schema freeze rules

The three persistence surfaces are considered **frozen**: their
on-disk/on-wire format is stable, and any change must be backward-compatible or
ship explicit migration code. The goal is that a user who installs the app never
loses their configured drinks, logged entries, or settings across an update.

The three surfaces and their rules:

### 7.1 Room database (`drinks`, `entries`)

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

### 7.2 Preferences (encrypted DataStore, `AppPreferences`)

- **Never rename** an existing key string (e.g. `"theme_mode"`) and **never
  change its value type** (e.g. int → string) after release — either silently
  loses the stored value. Pick a new key instead and migrate if needed.
- Adding a **new** key is safe and needs no migration: the read mapping uses
  `prefs[KEY] ?: default`, so an absent key falls back to its default.
- Enum-valued keys are parsed with `runCatching { valueOf(...) }.getOrDefault(...)`.
  Keep that pattern: it means renaming/removing an enum constant degrades to the
  default instead of crashing. Avoid renaming persisted enum constants regardless.

### 7.3 Backup / restore (JSON, `BackupManager`)

- The JSON root carries a `"version"` integer (`BACKUP_VERSION`). Bump it only
  for **additive** changes, and keep reading older files: required fields use
  `getXxx`, optional/newer fields use `optXxx(key, default)`.
- The importer already rejects files newer than it understands
  (`ImportError.VersionTooHigh`). Preserve that guard.
- The exported field names mirror the entity columns; if you rename a column,
  keep reading the old JSON field name for backward compatibility.

### 7.4 Identifiers that must never change

- `applicationId` / `namespace` (`de.godisch.potillus`).
- Database file name (`potillus.db`) and passphrase storage
  (`potillus_db_key` + Keystore alias `potillus_db_passphrase_key`).
- DataStore file name and its Keystore alias (`potillus_prefs_key`).
