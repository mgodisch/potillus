/* vim: set et ts=4:
 * =============================================================================
 * Libellus Potionis - Privacy-Friendly Alcohol Tracker
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
 * In addition, as permitted by section 7 of the GNU General Public License,
 * this program may carry additional permissions; any such permissions that
 * apply to it are stated in the accompanying COPYING.md file.
 *
 * =============================================================================
 */
package de.godisch.potillus.screenshot

import de.godisch.potillus.domain.DayResolver
import java.time.Clock
import java.time.LocalDate
import java.time.ZoneId

// =============================================================================
// ScreenshotClock.kt — pins the app's logical "today" for the capture suite
// =============================================================================
//
// WHY THIS EXISTS
//   Every date-relative screen (Today / Calendar / Statistics and the PDF
//   report) derives its notion of "today" from DayResolver.today(), which in
//   production reads the real device clock. The Play-Store screenshots must
//   instead be captured from ONE fixed perspective — [SCREENSHOT_DATE], the last
//   day of the demo period (2026-06-30) — so the Calendar/Statistics windows
//   frame the whole demo history the same way on every run. That day is
//   deliberately one day AFTER the fixture's last logged drink (2026-06-29), so
//   the Today screen shows a clean, drink-free "today" over a full history.
//
//   The Makefile ALSO tries to pin that date by setting the device clock via
//   `adb shell date`, but that only works on an emulator or a rooted userdebug
//   build; on a locked production phone the command is silently rejected and
//   the app would fall back to the real date, capturing off-date screenshots.
//   Pinning DayResolver.clockOverride in-process removes that dependency: the
//   perspective is guaranteed by the app itself, on ANY device.
//
// SCOPE
//   This helper lives in the androidTest source set, so it can never affect a
//   shipped build. It only ever writes DayResolver.clockOverride, whose
//   production default (null) leaves the real clock in place.
// =============================================================================

/**
 * Pins and un-pins [DayResolver]'s logical "today" for the screenshot-capture
 * instrumented tests. See the file header for the rationale.
 */
internal object ScreenshotClock {

    /**
     * Canonical capture date in ISO-8601 (`YYYY-MM-DD`): the single perspective
     * every date-relative screen is rendered from.
     *
     * Two invariants tie it to the rest of the capture pipeline (both enforced by
     * the `screenshots` target's cheap preflight guard, before any expensive work):
     *  - it MUST equal the Makefile's `SCREENSHOT_DATE` variable, and
     *  - it MUST NOT fall before the last logged day in the demo fixture
     *    (`fastlane/demo-backup.json`), so no seeded entry lands on a day the
     *    pinned Today cannot show. It MAY be later on purpose: 2026-06-30 is a
     *    deliberately dry "today" one day after the last 2026-06-29 entry.
     */
    const val SCREENSHOT_DATE: String = "2026-06-30"

    /**
     * Local time-of-day (24 h) the pinned clock is fixed at. Noon is chosen so
     * the pinned instant sits comfortably after the default 04:00 day-change
     * boundary (see [de.godisch.potillus.domain.model.AppSettings.dayChangeHour]),
     * which makes the resolved logical date unambiguously [SCREENSHOT_DATE]
     * regardless of the device time zone.
     */
    private const val PIN_HOUR: Int = 12

    /**
     * Pins [DayResolver.today] to [SCREENSHOT_DATE] at [PIN_HOUR]:00 in the device
     * time zone. Call from a test's `@Before`, before the Activity is launched, so
     * the very first composed frame already reflects the pinned date.
     */
    fun pin() {
        val pinnedInstant = LocalDate.parse(SCREENSHOT_DATE)
            .atTime(PIN_HOUR, 0)
            .atZone(ZoneId.systemDefault())
            .toInstant()
        DayResolver.clockOverride = Clock.fixed(pinnedInstant, ZoneId.systemDefault())
    }

    /**
     * Clears the pin so it cannot leak into other instrumented tests that share
     * the same process. Call from a test's `@After`.
     */
    fun unpin() {
        DayResolver.clockOverride = null
    }
}
