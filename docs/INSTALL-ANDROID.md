<!-- vim: set et ts=4:
=============================================================================
Libellus Potionis - Privacy-Friendly Alcohol Tracker
Copyright (c) 2026 Martin A. Godisch <martin@godisch.de>
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

# Building the Android debug APK from a blank Debian install

This guide takes a **fresh Debian GNU/Linux stable** system with nothing but a
shell and builds the **debug APK** of Libellus Potionis. It is written to be
followed top to bottom by someone who has never built an Android app before;
each step says not just *what* to type but *why* it is needed.

**Scope.** This document stops at a working, installable debug APK. Signing a
release build and publishing to F-Droid or the Play Store are **out of scope**
on purpose.

**What you will have at the end.** A file at

    android/app/build/outputs/apk/debug/app-debug.apk

that you can install on any Android 11 (API 30) or newer device or emulator.

**Relation to `make help`.** This guide is the extended companion to the
Makefile's `make help`: it walks the build-path targets (`make -C android
debug-apk`, `make install-debug`) in order, with the *why* behind each. `make
help`, run from the repository root, is the one-line index of every target
(build, checks, store assets, release, publishing); the release and publishing
groups are deliberately out of scope here.

---

## 1. Why these tools, and nothing else

An Android build has three moving parts, and it helps to know which one each
tool belongs to before installing anything.

| Tool | Version | Why it is needed | Installed how |
|------|---------|------------------|---------------|
| **JDK** | **21** (LTS) | Gradle and the Kotlin/Java compiler run on the JVM. The build pins Java 21 (`JAVA_VERSION := 21` in `android/Makefile`; `sourceCompatibility`/`targetCompatibility = VERSION_21` in `app/build.gradle.kts`). | `apt` |
| **Android SDK** | platform-tools, build-tools, `platforms;android-36` | The compiled bytecode is linked against a platform (`compileSdk = 36`) and packaged with `build-tools`; `platform-tools` provides `adb`. | `sdkmanager` (manual) |
| **Gradle** | **9.6.1** | The build system. You do **not** install it: the repository ships a *Gradle wrapper* (`./gradlew`) that downloads exactly the pinned version on first use. | automatic |
| **Android Gradle Plugin / Kotlin** | AGP **9.2.0**, Kotlin **2.4.0** | The plugins that turn Kotlin into an APK. Declared in `android/gradle/libs.versions.toml`; Gradle fetches them from Maven Central on the first build. | automatic |
| **git, unzip, curl** | any | Clone the source; unpack the SDK command-line tools; download them. | `apt` |
| **python3, make, bash** | any | The `make` targets regenerate a couple of bundled text files (the in-app copyright notice and the localized user guides) with small Python helpers before compiling. | `apt` |

Two things are deliberately **not** on the list:

- **No NDK.** The app is pure Kotlin/Java. You may see a one-line
  `stripDebugDebugSymbols` warning about missing native tooling during a
  release build; it is harmless and never appears for a debug build.
- **No manual Gradle, AGP, or Kotlin install.** Pinning them in the repository
  and letting the wrapper and Maven fetch them is what makes the build
  reproducible: everyone compiles with the same versions regardless of what is
  installed system-wide.

`minSdk = 30` (Android 11) is the oldest device the APK will run on;
`targetSdk = 36` (Android 16) is the behaviour level it is optimised for.

---

## 2. Install the system packages

Everything except the Android SDK comes from Debian's own repositories, so a
single `apt` line covers it. `sudo` is only needed here.

    sudo apt update
    sudo apt install --no-install-recommends \
        openjdk-21-jdk git unzip curl python3 make ca-certificates

Confirm the JDK is exactly version 21 — the build refuses any other major
version:

    java -version
    # openjdk version "21.0.x" ...

If your Debian release does not carry `openjdk-21-jdk`, install a standalone
Temurin/Adoptium **21** JDK instead and make sure it is the `java` on your
`PATH`; the build only checks that the major version is 21, not its vendor.

---

## 3. Install the Android SDK command-line tools

The SDK is not in Debian; you fetch Google's **"Command line tools only"**
package and let its `sdkmanager` pull the rest. Install it under a
user-owned directory so no step needs root.

The build looks for the SDK at `~/android-sdk` by default
(`ANDROID_HOME ?= $(HOME)/android-sdk` in `android/Makefile`), and it expects
`sdkmanager` at the exact path `cmdline-tools/latest/bin/sdkmanager`. That
`latest/` level matters — `sdkmanager` refuses to run if the tools sit one
directory too high.

    # 1. Create the SDK root and unpack the command-line tools into it.
    export ANDROID_HOME="$HOME/android-sdk"
    mkdir -p "$ANDROID_HOME/cmdline-tools"

    # Download "Command line tools only" (Linux) from
    #   https://developer.android.com/studio#command-line-tools-only
    # then unzip it. The archive unpacks to a folder named "cmdline-tools";
    # it must be renamed to "latest":
    unzip -q commandlinetools-linux-*_latest.zip -d "$ANDROID_HOME/cmdline-tools"
    mv "$ANDROID_HOME/cmdline-tools/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"

    # 2. Put sdkmanager (and later adb) on PATH.
    export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

Now install the exact components the build requires and accept the licenses.
Together with the cmdline-tools installed above, the three below are the four
component families `android/Makefile` verifies before it will build:

    sdkmanager "platform-tools" \
               "platforms;android-36" \
               "build-tools;36.0.0"

    # If "build-tools;36.0.0" is rejected, list what is available and install
    # the highest version offered:
    #   sdkmanager --list | grep build-tools
    sdkmanager --licenses     # answer "y" to each prompt

Make the two environment variables permanent so future shells find the SDK —
add these to `~/.profile` (or `~/.bashrc`):

    export ANDROID_HOME="$HOME/android-sdk"
    export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

> **Alternative:** if you keep the SDK somewhere else, you do not need the
> `ANDROID_HOME` export at all — you can pass the path to every build with
> `make ANDROID_HOME=/path/to/android-sdk ...`.

---

## 4. Get the source

    git clone <repository-url> potillus
    cd potillus

The repository holds both platforms side by side (`android/` and `ios/`); the
Android build lives under `android/`.

---

## 5. Build the debug APK

The project is driven by `make`. On Debian the system `make` **is** GNU Make,
so plain `make` works (only macOS needs a separate `gmake`).

    cd android
    make -C android debug-apk

`make -C android debug-apk` does three things in order, and understanding them turns a failed
build into an obvious fix:

1. **Prerequisite check** (`prereq`): it verifies `java -version` is 21 and
   that the four SDK component directories from step 3 exist, then regenerates
   two bundled text files with `python3` (the in-app copyright notice from the
   repository's `COPYING.md`/`LICENSE*.md`, and the localized user guides).
2. **Gradle wrapper bootstrap:** the first `./gradlew` invocation downloads
   Gradle **9.6.1** into `~/.gradle`. This needs network access and happens
   only once.
3. **`./gradlew assembleDebug`:** Gradle downloads AGP 9.2.0, Kotlin 2.4.0 and
   the app's dependencies from Maven Central (again, first time only), then
   compiles and packages the APK.

When it finishes you have:

    android/app/build/outputs/apk/debug/app-debug.apk

> **Just want the raw Gradle command?** Once steps 2–3 are done you can skip
> the Makefile and run `./gradlew assembleDebug` directly from `android/`. The
> `make` path exists so the SDK-component check and the generated text files
> are never forgotten; the underlying build is the same.

The first build is slow because of the one-time downloads; later builds reuse
the Gradle daemon and caches. If Gradle runs out of memory on a small machine,
raise its heap: `make -C android debug-apk GRADLE_OPTS="-Xmx4g"`.

---

## 6. (Optional) Run it

You do not need a device to have built the APK, but to *see* the app you need
one of the following.

**On a physical phone** (Developer options → USB debugging enabled):

    adb install -r android/app/build/outputs/apk/debug/app-debug.apk
    # (from the repo root, `make install-debug` instead copies that APK to
    #  ../downloads/ for manual sideloading -- it does NOT install to a device)

**On an emulator**, create one from the SDK you already have:

    sdkmanager "emulator" "system-images;android-36;google_apis;x86_64"
    avdmanager create avd -n potillus -k "system-images;android-36;google_apis;x86_64"
    emulator -avd potillus &
    adb install -r android/app/build/outputs/apk/debug/app-debug.apk

---

## 7. Troubleshooting

- **`java -version` is not 21 / `prereq` fails on the java check.** Debian can
  have several JDKs installed at once. Point the default at 21 with
  `sudo update-alternatives --config java`.
- **"No rule to make target `.../platforms/android-36`".** A required SDK
  component is missing — re-run the `sdkmanager` line in step 3 and confirm
  `$ANDROID_HOME` points where you installed it (or pass
  `make ANDROID_HOME=...`).
- **License / "not accepted" errors from Gradle.** Run
  `sdkmanager --licenses` and accept them all.
- **`sdkmanager: command not found`.** The `cmdline-tools/latest/bin`
  directory is not on `PATH`, or the tools were unpacked one level too high
  (they must be at `cmdline-tools/latest/`, not `cmdline-tools/`).
- **First build fails with network/timeout errors.** The initial build must be
  online to fetch Gradle, AGP, Kotlin and the dependencies; run it once with a
  connection, after which builds work offline.
