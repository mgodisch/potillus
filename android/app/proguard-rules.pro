# vim: set et ts=4:
# =============================================================================
# Libellus Potionis - Privacy-Friendly Alcohol Tracker
# Copyright (c) 2026 Martin A. Godisch <android@godisch.de>
# =============================================================================
#
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
# details.
#
# You should have received a copy of the GNU General Public License along with
# this program.  If not, see <https://www.gnu.org/licenses/>.
#
# =============================================================================

# =============================================================================
# proguard-rules.pro – R8 / ProGuard rules for Libellus Potionis
# Version: v0.73.1  (keep in sync with build.gradle.kts versionName)
# =============================================================================
#
# R8 is Android's code shrinker/obfuscator (successor to ProGuard).
# It runs only in release builds (minifyEnabled = true in build.gradle.kts).
#
# Many libraries ship their own consumer ProGuard rules inside their AAR files,
# so explicit rules here are only needed when R8 cannot infer them automatically.
#
# WHAT IS SHRINKING?
#   R8 removes classes and methods that are never called from the entry points
#   it knows about (Activities, Services, BroadcastReceivers …).
#   -keep rules tell R8: "do not remove or rename this class/member."
#
# WHAT IS OBFUSCATION?
#   R8 renames classes and members to short names (a, b, c …) to reduce APK size.
#   This can break reflection-based code that looks up members by name at runtime.
# =============================================================================

# ── Room ─────────────────────────────────────────────────────────────────────
# Room 2.4+ ships its own consumer rules inside room-runtime.aar, so explicit
# -keep rules for @Entity and @Dao classes are generally not required anymore.
# However, the domain model classes (used in BackupManager via reflection-free
# Kotlin code) and the entity/DAO classes are kept here as a belt-and-suspenders
# measure in case R8's analysis misses any reflection path.
#
-keep class de.godisch.potillus.data.db.entity.** { *; }
-keep class de.godisch.potillus.data.db.dao.**    { *; }
-keep class de.godisch.potillus.domain.model.**   { *; }

# ── DataStore (Preferences) ───────────────────────────────────────────────────
# This app uses *Preferences* DataStore (datastore-preferences), NOT Proto
# DataStore. A protobuf GeneratedMessageLite keep rule applies only to Proto
# DataStore, which this app does not use, so none is needed here – avoiding it
# keeps unnecessary classes out of the build.
#
# Preferences DataStore ships its own consumer rules; no explicit rule is needed.

# ── Biometric ────────────────────────────────────────────────────────────────
# androidx.biometric ships its own consumer ProGuard rules inside biometric.aar.
# A blanket -keep class androidx.biometric.** rule is therefore redundant, but
# it is harmless to keep a targeted rule for the prompt:
-keep class androidx.biometric.BiometricPrompt { *; }
-keep class androidx.biometric.BiometricManager { *; }

# ── Kotlin Coroutines ─────────────────────────────────────────────────────────
# kotlinx.coroutines ships its own consumer rules since 1.4.0.
# The volatile-fields rule below is retained for safety on older shrinker
# versions; it prevents R8 from removing the @Volatile annotation that the
# double-checked locking in AppDatabase relies on at runtime.
-keepclassmembernames class kotlinx.** {
    volatile <fields>;
}

# ── Enum classes (runCatching { Foo.valueOf(name) }) ─────────────────────────
# The app deserialises enums from stored strings (DataStore, JSON backup) using
# Enum.valueOf(name). R8 must not rename or remove enum constants, or valueOf()
# will throw at runtime for any value stored before the rename.
-keepclassmembers enum de.godisch.potillus.** {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ── org.json (BackupManager) ──────────────────────────────────────────────────
# BackupManager uses android.org.json (bundled with the Android SDK).
# These classes are part of the platform and are never shrunk; no rule needed.

# ── Debug information ─────────────────────────────────────────────────────────
# Keep annotation metadata so that Room's KSP-generated code and Kotlin
# reflection work correctly at runtime.
-keepattributes *Annotation*
# Keep source file names and line numbers so that crash stack traces are readable
# even in release builds (the mapping file maps obfuscated names back anyway).
-keepattributes SourceFile,LineNumberTable

# ── Security Crypto (intentionally absent) ────────────────────────────────────
# androidx.security:security-crypto is intentionally not a dependency (Google
# deprecated it), so there is deliberately no `-keep class
# androidx.security.crypto.**` rule here — those classes are not on the
# classpath. Secret-at-rest protection uses the app's own
# de.godisch.potillus.data.security.KeystoreSecretStore (plain platform Keystore
# APIs), which needs no -keep rule because it is referenced directly, not via
# reflection.
