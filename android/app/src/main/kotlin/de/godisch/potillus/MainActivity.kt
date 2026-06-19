/* vim: set et ts=4:
 * =============================================================================
 * Libellus Potionis -- Privacy-Friendly Alcohol Tracker
 * Copyright (c) 2026 Martin A. Godisch <android@godisch.de>
 * =============================================================================
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 3 of the License, or (at your option) any later
 * version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 * =============================================================================
 */
package de.godisch.potillus

// =============================================================================
// MainActivity.kt – Single Activity; biometric gate; ViewModel factory
// =============================================================================
//
// SINGLE-ACTIVITY PATTERN:
//   The entire app lives in one Activity. Screens are Compose composables
//   managed by the Navigation component, NOT separate Activities or Fragments.
//   This avoids the overhead of activity transitions and simplifies state sharing.
//
// STARTUP SEQUENCE:
//   1. onCreate() reads the biometric preference from DataStore (one-shot collect).
//   2. If biometric is enabled AND the device supports it:
//      a. Set UiGate to BIOMETRIC (blank screen – no UI shown yet).
//      b. Show the BiometricPrompt.
//      c. On success: set UiGate to READY.
//      d. On error/cancel: finish() the Activity.
//   3. If biometric is disabled: set UiGate to READY immediately.
//   4. setContent observes UiGate; only renders MainContent when READY.
//      LOADING: shows a centered CircularProgressIndicator.
//      BIOMETRIC: shows a blank surface (no data visible behind the prompt).
//      READY: renders the full AppNavigation.
//
// RE-AUTHENTICATION AFTER BACKGROUNDING:
//   When biometric lock is enabled the app should not display data if the
//   user returns after a period of inactivity. Two sub-problems are solved:
//
//   a) Double-prompt on rotation:
//      `_uiGate` resets to LOADING on every Activity recreation. Without a
//      guard, `onCreate` would call showBiometricPrompt() again on rotation,
//      producing two overlapping system dialogs. The companion-object flag
//      `isAuthenticatedThisSession` persists across recreations (it is tied
//      to the class, not the instance) and prevents the second prompt.
//
//   b) Re-auth after inactivity:
//      `onStop` records `backgroundedAt` (unless it is a config change – that
//      would incorrectly count a rotation as an inactivity period). `onStart`
//      checks the elapsed time; if it exceeds REAUTH_THRESHOLD_MS the flag is
//      cleared and the prompt is shown again.
//
// VIEWMODEL FACTORY (MainContent):
//   Jetpack's ViewModelProvider needs a Factory to create ViewModels that have
//   constructor parameters (repositories, preferences). The anonymous Factory
//   object maps each ViewModel class to its constructor. This is the manual
//   alternative to Hilt/Koin dependency injection.
//
// "by lazy" AND "by remember":
//   - `remember { factory }` keeps the Factory instance across recompositions
//     so it is not recreated on every render.
//   - `viewModel<T>(factory = factory)` retrieves or creates the ViewModel from
//     the ViewModelStore (which survives configuration changes).
// =============================================================================

import android.os.Bundle
import android.os.SystemClock
import android.util.Log
import android.view.WindowManager
import androidx.activity.compose.setContent
import androidx.appcompat.app.AppCompatActivity
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.*
import androidx.biometric.BiometricPrompt
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.core.content.ContextCompat
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.lifecycleScope
import androidx.lifecycle.repeatOnLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import de.godisch.potillus.ui.nav.AppNavigation
import de.godisch.potillus.ui.screen.*
import de.godisch.potillus.ui.theme.PotillusTheme
import de.godisch.potillus.BuildConfig
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import androidx.core.view.WindowCompat

class MainActivity : AppCompatActivity() {

    /**
     * Controls which UI layer is rendered before the app is ready.
     *
     * This enum drives a gate mechanism rather than just a boolean so that
     * future states (e.g. PIN entry) can be added without changing the `when`
     * structure in `setContent`.
     *
     * - [LOADING]   → blank screen with spinner while settings are read
     *                 asynchronously from DataStore (typically < 100 ms).
     * - [BIOMETRIC] → blank screen while the biometric/device-credential prompt
     *                 is displayed (no app data visible behind the system UI).
     * - [READY]     → the main navigation UI is fully rendered.
     */
    private enum class UiGate { LOADING, BIOMETRIC, READY }

    private val _uiGate = MutableStateFlow(UiGate.LOADING)
    private val uiGate: StateFlow<UiGate> = _uiGate

    /**
     * Set to `true` once the user has authenticated in this process session.
     * Lives in the companion object so it survives Activity recreation on
     * configuration changes (e.g. screen rotation). Reset to `false` by the
     * re-auth logic in [onStart] after a sufficiently long background period.
     *
     * WHY @Volatile?
     *   All reads and writes in the current implementation happen on the main
     *   thread (in [onCreate], [onStart], and the BiometricPrompt callback which
     *   uses [ContextCompat.getMainExecutor]).  There is therefore no actual data
     *   race today.
     *
     *   @Volatile is added as a teaching aid and a defensive measure: it instructs
     *   the JVM to always read the field from main memory rather than from a
     *   CPU-register or thread-local cache, and to flush writes immediately.  Any
     *   future code path that touches this flag from a background thread (e.g. a
     *   deep-link handler or a WorkManager task) will be safe without requiring a
     *   separate code review.  The cost is negligible (a single memory barrier on
     *   every read/write).
     *
     *   Without @Volatile, a developer unfamiliar with this file might copy the
     *   companion-object `var` pattern into a multi-threaded context and introduce
     *   a visibility bug that is very hard to reproduce.
     */
    companion object {
        @Volatile
        private var isAuthenticatedThisSession = false

        /**
         * Monotonic timestamp (from [SystemClock.elapsedRealtime]) recorded in
         * [onStop] when the app is backgrounded; `0` means "not backgrounded /
         * already consumed". elapsedRealtime (not wall clock) is used because it
         * keeps counting during deep sleep and is immune to clock adjustments, so
         * the inactivity threshold holds across an overnight lock.
         *
         * CRITICAL — this lives in the companion object (process-global), NOT as an
         * Activity instance field. Android frequently destroys the Activity while
         * keeping the process cached for hours. With a per-instance timestamp, a
         * recreated Activity would start with `backgroundedAt == 0` while the static
         * [isAuthenticatedThisSession] was still `true`, so [onCreate] re-revealed
         * the app WITHOUT a prompt no matter how long it had been backgrounded.
         * Keeping the timestamp process-global lets the staleness check in
         * [onCreate] and [onStart] work even across Activity recreation.
         */
        @Volatile
        private var backgroundedAt = 0L

        /**
         * Minimum background duration after which re-authentication is required.
         * 30 seconds is a common default for health and finance apps; long enough
         * to survive a brief pocket-lock but short enough to deter casual snooping.
         */
        private const val REAUTH_THRESHOLD_MS = 30_000L

        private const val TAG = "MainActivity"
    }

    /**
     * Whether the biometric app lock is currently enabled.
     *
     * Seeded from the initial DataStore read in [onCreate] and then kept in sync
     * with the live preference by a [repeatOnLifecycle] collector (also in
     * [onCreate]). [onStart] reads this synchronously to decide whether to trigger
     * inactivity re-auth without an async read (which would be too slow before the
     * first frame). Keeping it reactive — rather than a one-shot cache — means a
     * lock the user switches ON during the same session arms the re-auth path
     * immediately, not only after the next cold start.
     */
    private var biometricEnabled = false

    /**
     * Sets up window security, edge-to-edge rendering, the biometric gate and
     * the Compose content tree.
     *
     * Order matters: [WindowManager.LayoutParams.FLAG_SECURE] is applied before
     * [setContent] so the very first rendered frame is already excluded from
     * screenshots and the Recents thumbnail. The biometric decision is
     * made asynchronously from DataStore; until it resolves, the gate stays in
     * [UiGate.LOADING] and only a spinner is shown.
     *
     * @param savedInstanceState Standard Android saved-state bundle (unused here;
     *                           all UI state is held in ViewModels / DataStore).
     */
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Prevent the app's content from appearing in screenshots,
        // screen recordings, and the Android Recents (app-switcher) thumbnail.
        //
        // This app stores health-sensitive data (alcohol consumption diary). Without
        // FLAG_SECURE a quick press of the Recents button exposes the last visible
        // screen to anyone who glances at the device. Screen-sharing tools (Scrcpy,
        // Google Meet screen share) also capture the window unless this flag is set.
        //
        // FLAG_SECURE must be applied BEFORE setContent() to take effect on the very
        // first frame. Applying it later leaves a single un-secured frame visible in
        // Recents during cold start.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )

        // Opt into edge-to-edge rendering (mandatory on Android 15+ / API 35+).
        // The window extends behind system bars; composables use Modifier.imePadding()
        // and Modifier.navigationBarsPadding() to handle their own insets.
        // This replaces the deprecated android:windowSoftInputMode="adjustResize"
        // attribute which was removed from AndroidManifest.xml.
        WindowCompat.setDecorFitsSystemWindows(window, false)

        val app = application as PotillusApp

        lifecycleScope.launch {
            biometricEnabled = app.appPreferences.settingsFlow.first().biometricEnabled

            // Require authentication when the lock is on AND either we have never
            // authenticated in this process OR the app has been backgrounded longer
            // than the inactivity threshold. The staleness term is what closes the
            // warm-start hole: a recreated Activity whose process kept the static
            // isAuthenticatedThisSession == true must still re-prompt once enough
            // time has passed (backgroundedAt is process-global — see its KDoc).
            if (biometricEnabled && isBiometricAvailable() &&
                (!isAuthenticatedThisSession || isReauthDueToInactivity())) {
                isAuthenticatedThisSession = false
                backgroundedAt = 0L
                _uiGate.value = UiGate.BIOMETRIC
                showBiometricPrompt(app)
            } else {
                // Lock off / unavailable, or already authenticated and still fresh.
                // Consume any pending background timestamp so a later configuration
                // change (which skips onStop) cannot read it as stale and re-prompt.
                backgroundedAt = 0L
                _uiGate.value = UiGate.READY
            }
        }

        // Keep [biometricEnabled] in sync with the live preference for as long as
        // the Activity is at least STARTED. Without this, the flag would only ever
        // reflect the single value read above in onCreate, so a lock the user
        // switches ON during the same session would not arm the onStart inactivity
        // re-auth until the next cold start. repeatOnLifecycle cancels the
        // collection when the Activity stops and restarts it on the next start, so
        // it never collects while the app is in the background.
        lifecycleScope.launch {
            repeatOnLifecycle(Lifecycle.State.STARTED) {
                app.appPreferences.settingsFlow.collect {
                    biometricEnabled = it.biometricEnabled
                }
            }
        }

        setContent {
            val gate by uiGate.collectAsStateWithLifecycle()

            when (gate) {
                UiGate.LOADING, UiGate.BIOMETRIC -> {
                    Surface(Modifier.fillMaxSize()) {
                        if (gate == UiGate.LOADING) {
                            Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                                CircularProgressIndicator()
                            }
                        }
                    }
                }
                UiGate.READY -> {
                    // Show a one-time, dismissible warning when a possible
                    // device-transfer Keystore migration failure is detected.
                    // The dialog appears on top of the normal app content so it is
                    // never blocking; the user can dismiss it and continue normally.
                    val showTransferWarning by app.deviceTransferWarning.collectAsStateWithLifecycle()
                    if (showTransferWarning) {
                        AlertDialog(
                            onDismissRequest = { app.dismissDeviceTransferWarning() },
                            title   = { Text(stringResource(R.string.device_transfer_warning_title)) },
                            text    = { Text(stringResource(R.string.device_transfer_warning_body)) },
                            confirmButton = {
                                TextButton(onClick = { app.dismissDeviceTransferWarning() }) {
                                    Text(stringResource(android.R.string.ok))
                                }
                            }
                        )
                    }
                    val showInfoDialog by app.infoDialog.collectAsStateWithLifecycle()
                    if (showInfoDialog) {
                        AlertDialog(
                            onDismissRequest = { app.dismissInfoDialog() },
                            title   = { Text(stringResource(R.string.info_dialog_title)) },
                            text    = { Text(stringResource(R.string.info_dialog_body)) },
                            confirmButton = {
                                TextButton(onClick = { app.dismissInfoDialog() }) {
                                    Text(stringResource(R.string.info_dialog_ok))
                                }
                            }
                        )
                    }
                    MainContent(
                        app,
                        onAuthenticate = { onResult -> authenticateForToggle(onResult) },
                        onLockApp = { lockNow() }
                    )
                }
            }
        }
    }

    /**
     * Returns `true` if the device can authenticate with a strong biometric
     * OR the device credential (PIN / pattern / password).
     *
     * Combining [BIOMETRIC_STRONG] with [DEVICE_CREDENTIAL] means users without
     * enrolled biometrics can still unlock the app with their device PIN, so the
     * lock never becomes a dead end on hardware lacking a fingerprint sensor.
     */
    private fun isBiometricAvailable(): Boolean {
        val mgr = BiometricManager.from(this)
        return mgr.canAuthenticate(BIOMETRIC_STRONG or DEVICE_CREDENTIAL) ==
               BiometricManager.BIOMETRIC_SUCCESS
    }

    /**
     * Shows the system [BiometricPrompt]; on success it lifts the gate to
     * [UiGate.READY], on error/cancel it finishes the Activity (no app data is
     * shown without authentication).
     *
     * @param app The [PotillusApp] singleton (passed through so the success path
     *            has access to shared state without re-reading the Application).
     */
    private fun showBiometricPrompt(app: PotillusApp) {
        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle(getString(R.string.biometric_title))
            .setSubtitle(getString(R.string.biometric_subtitle))
            .setAllowedAuthenticators(BIOMETRIC_STRONG or DEVICE_CREDENTIAL)
            .build()

        val prompt = BiometricPrompt(
            this,
            ContextCompat.getMainExecutor(this),
            object : BiometricPrompt.AuthenticationCallback() {
                /** Authentication succeeded → mark the session authenticated and reveal the UI. */
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    isAuthenticatedThisSession = true
                    _uiGate.value = UiGate.READY
                }
                /**
                 * A terminal authentication error or user cancellation occurred.
                 * In every case the Activity is finished so no data is shown. The
                 * detailed code reference below documents the common [errorCode]s.
                 */
                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    // Log the error code in debug builds so developers can
                    // distinguish between expected cancellations and hardware/lockout
                    // problems without attaching a debugger.
                    //
                    // Common codes:
                    //   BIOMETRIC_ERROR_USER_CANCELED (10) – user pressed Cancel → finish() is correct.
                    //   BIOMETRIC_ERROR_NEGATIVE_BUTTON (13) – user tapped the negative button.
                    //   BIOMETRIC_ERROR_LOCKOUT (7) – too many failed attempts, 30-second cool-down.
                    //   BIOMETRIC_ERROR_LOCKOUT_PERMANENT (9) – too many lockouts, requires PIN to unlock.
                    //   BIOMETRIC_ERROR_HW_UNAVAILABLE (1) – sensor temporarily busy.
                    //
                    // In all cases we finish() the Activity. A future improvement could
                    // show a brief Toast for lockout errors ("Too many attempts – try again later")
                    // before calling finish().
                    if (BuildConfig.DEBUG) {
                        Log.w(TAG, "Biometric auth error $errorCode: $errString")
                    }
                    finish()
                }
                /**
                 * A single attempt was not recognised (e.g. wrong fingerprint).
                 * This is NOT a terminal error — the system prompt stays open and
                 * the user can retry — so we intentionally do nothing here.
                 */
                override fun onAuthenticationFailed() { /* user can retry */ }
            }
        )
        prompt.authenticate(promptInfo)
    }

    /**
     * Runs a [BiometricPrompt] to authorise a sensitive in-app action — currently
     * toggling the biometric app lock on or off — and reports the outcome via
     * [onResult].
     *
     * WHY A SEPARATE METHOD FROM [showBiometricPrompt]?
     *   [showBiometricPrompt] gates app start: on cancel/error it finishes the
     *   Activity, because no data may be shown without authentication. A settings
     *   toggle is different — cancelling must simply leave the setting unchanged and
     *   keep the user in the app. This variant therefore NEVER finishes the
     *   Activity; it only reports the result.
     *
     * If neither a biometric nor a device credential is enrolled, authentication is
     * impossible, so [onResult] is invoked with `false` immediately and the caller
     * leaves the toggle unchanged. (Without an authenticator the lock could not be
     * satisfied at app start anyway, so refusing to arm it is the correct outcome.)
     *
     * A successful authentication also marks the session authenticated, mirroring
     * the unlock path, so the inactivity gate does not immediately re-prompt.
     *
     * @param onResult Invoked on the main thread with `true` on success, or `false`
     *                 on cancel / error / no authenticator available.
     */
    fun authenticateForToggle(onResult: (Boolean) -> Unit) {
        if (!isBiometricAvailable()) {
            onResult(false)
            return
        }

        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle(getString(R.string.biometric_title))
            .setSubtitle(getString(R.string.biometric_subtitle))
            .setAllowedAuthenticators(BIOMETRIC_STRONG or DEVICE_CREDENTIAL)
            .build()

        val prompt = BiometricPrompt(
            this,
            ContextCompat.getMainExecutor(this),
            object : BiometricPrompt.AuthenticationCallback() {
                /** Authorised → mark the session authenticated and report success. */
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    isAuthenticatedThisSession = true
                    onResult(true)
                }
                /** Terminal error or user cancellation → report failure, but stay in the app. */
                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    if (BuildConfig.DEBUG) Log.w(TAG, "Toggle auth error $errorCode: $errString")
                    onResult(false)
                }
                /** A single non-terminal mismatch; the prompt stays open for a retry. */
                override fun onAuthenticationFailed() { /* user can retry */ }
            }
        )
        prompt.authenticate(promptInfo)
    }

    // ── Inactivity re-authentication ─────────────────────────────────────────

    /**
     * True when the lock should re-engage because the app has been backgrounded
     * for longer than [REAUTH_THRESHOLD_MS]. Reads the process-global
     * [backgroundedAt]; `backgroundedAt == 0` (not backgrounded / already consumed)
     * is never stale.
     */
    private fun isReauthDueToInactivity(): Boolean =
        backgroundedAt > 0L &&
        SystemClock.elapsedRealtime() - backgroundedAt > REAUTH_THRESHOLD_MS

    /**
     * Manually locks the app — the overflow-menu "Lock app" action (Variant A).
     *
     * It clears the authenticated state and shows the prompt immediately,
     * INDEPENDENTLY of the auto-lock setting ([biometricEnabled]), because the user
     * has explicitly asked to lock. It only proceeds when an authenticator
     * (biometric or device credential) is available — otherwise locking would strand
     * the user with no way back in, so the call is a no-op (and the menu entry is
     * hidden in that case; see AppOverflowMenu). On a cancelled prompt the gate's
     * usual policy applies (the Activity finishes), consistent with start-up.
     */
    fun lockNow() {
        if (!isBiometricAvailable()) return
        isAuthenticatedThisSession = false
        backgroundedAt = 0L
        _uiGate.value = UiGate.BIOMETRIC
        showBiometricPrompt(application as PotillusApp)
    }

    /**
     * Records the time at which the Activity became invisible.
     *
     * [isChangingConfigurations] is `true` during a rotation or other config
     * change; in that case we skip the recording so that a configuration change
     * does not trigger re-auth when the Activity immediately restarts.
     */
    override fun onStop() {
        super.onStop()
        if (!isChangingConfigurations && isAuthenticatedThisSession) {
            backgroundedAt = SystemClock.elapsedRealtime()
        }
    }

    /**
     * Checks whether re-authentication is needed when the Activity becomes
     * visible again after a background period.
     *
     * Called before [onResume], so the gate is set before the first frame is
     * drawn – the user never sees app content before the prompt appears.
     *
     * Only acts once [biometricEnabled] is known (it is `false` on the very first
     * onStart of a freshly created Activity, before the onCreate coroutine has read
     * it; that path is handled by onCreate's staleness check instead). When the app
     * returns within the threshold, the pending [backgroundedAt] is consumed so a
     * subsequent configuration change — which skips onStop — cannot read it as
     * stale and re-prompt spuriously.
     */
    override fun onStart() {
        super.onStart()
        if (!biometricEnabled || backgroundedAt == 0L) return
        if (isReauthDueToInactivity()) {
            isAuthenticatedThisSession = false
            backgroundedAt = 0L
            if (isBiometricAvailable()) {
                _uiGate.value = UiGate.BIOMETRIC
                showBiometricPrompt(application as PotillusApp)
            }
        } else {
            backgroundedAt = 0L
        }
    }
}

/**
 * Root composable shown once the [MainActivity.UiGate] is `READY`.
 *
 * Builds the single [AppViewModelFactory] (remembered so it survives
 * recomposition), wires every screen ViewModel through it, and wraps the
 * navigation graph in [PotillusTheme] using the user's selected theme mode.
 *
 * @param app The [PotillusApp] singleton that owns all shared dependencies.
 */
@Composable
private fun MainContent(
    app: PotillusApp,
    /**
     * Runs a biometric prompt to authorise a sensitive toggle and calls back with
     * the result. Supplied by [MainActivity] (which owns the [BiometricPrompt]) and
     * forwarded down to [SettingsScreen] for the biometric-lock switch.
     */
    onAuthenticate: (onResult: (Boolean) -> Unit) -> Unit,
    /**
     * Locks the app immediately (the overflow-menu "Lock app" action). Supplied by
     * [MainActivity.lockNow] and forwarded to the four main screens' overflow menu.
     */
    onLockApp: () -> Unit
) {
    // The ViewModelProvider.Factory is a named class (AppViewModelFactory)
    // rather than an anonymous object defined here. Benefits:
    //   - The dependency graph is centralised in AppViewModelFactory.kt and easy to find.
    //   - This composable stays focused on navigation layout, not on wiring dependencies.
    //   - remember { } still ensures the factory is created at most once per Activity
    //     lifecycle and is not re-instantiated on recomposition.
    val factory = remember { AppViewModelFactory(app) }

    val settingsVm      = viewModel<SettingsViewModel>(factory = factory)
    val settingsUiState by settingsVm.uiState.collectAsStateWithLifecycle()

    PotillusTheme(themeMode = settingsUiState.settings.themeMode) {
        AppNavigation(
            todayVm    = viewModel(factory = factory),
            calendarVm = viewModel(factory = factory),
            statsVm    = viewModel(factory = factory),
            drinksVm   = viewModel(factory = factory),
            settingsVm = settingsVm,
            onAuthenticate = onAuthenticate,
            onLockApp = onLockApp
        )
    }
}
