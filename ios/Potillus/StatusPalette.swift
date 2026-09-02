// vim: set et ts=4:
// =============================================================================
// Libellus Potionis - Privacy-Friendly Alcohol Tracker
// Copyright (c) 2026 Martin A. Godisch <martin@godisch.de>
// =============================================================================
//
// This program is free software: you can redistribute it and/or modify it under
// the terms of the GNU General Public License as published by the Free Software
// Foundation, either version 3 of the License, or (at your option) any later
// version.
//
// This program is distributed in the hope that it will be useful, but WITHOUT
// ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
// FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
// details.
//
// You should have received a copy of the GNU General Public License along with
// this program.  If not, see <https://www.gnu.org/licenses/>.
//
// In addition, as permitted by section 7 of the GNU General Public License,
// this program may carry additional permissions; any such permissions that
// apply to it are stated in the accompanying COPYING.md file.
//
// =============================================================================
import SwiftUI
import UIKit

// =============================================================================
// StatusPalette – the measured status colours, shared with Android
// =============================================================================
//
// Until the v0.86.0 review this port coloured "within limits", "approaching" and
// "over" with Apple's system green, orange and red. In dark mode those clear
// every WCAG threshold; in light mode they do not: system green (#34C759) and
// orange (#FF9500) sit at about 2.2 : 1 on a white card, below the 3 : 1 a
// non-text indicator needs and far below the 4.5 : 1 small text needs, and the
// green was used as TEXT — the abstinent-day count, the days-under-limit
// figures, the trend arrow. Android measured its palette in
// `ui/theme/Color.kt`; these are the same six values, so the two apps read
// alike and the measurements below hold on both.
//
// MEASURED (WCAG 2.2 contrast, sRGB) against the iOS backgrounds each colour
// meets — white / the grouped card (#F2F2F7) in light mode, black / the card
// (#1C1C1E) in dark mode:
//
//   success     light #2E7D32  5.13 / 4.59     dark #4CAF50  7.56 / 6.12
//   warning     light #A67C00  3.82 / 3.42     dark #E8A020  9.48 / 7.68
//   danger      light #960018  9.09 / 8.15     dark #DD2C2C  4.47 / 3.62
//   dangerText  light #960018  9.09 / 8.15     dark #DF3A3A  4.80 / 3.89
//   error       light #B3261E  (Material's error role, 5.5+ on both)
//               dark  #CF6679  (5.3+ on both)
//
// Green and red clear 4.5 : 1 for text in light mode; warning clears 3 : 1 for
// the dot and the bar it paints and is never used for text. In dark mode the
// danger red stops short of 4.5 : 1 by design — Android's Color.kt explains
// why a red light enough for 4.5 : 1 reads as pink — which is why over-limit
// TEXT uses `dangerText`, a step lighter, and dots and bars use `danger`.
//
// WHAT IS LOST. Apple's system colours respond to "Increase Contrast"; these
// fixed values do not. The trade was made knowingly: the system colours failed
// the ordinary reader in light mode, and a measured palette that holds on both
// platforms was judged worth more than a switch few users know exists.
//
// CALM IS NOT HERE. The calm state of a bar is the app tint (`.accentColor`),
// as Android's primary; only a traffic light's calm is green, and that one
// reads `success`.
// =============================================================================

extension Color {
    /// Within limits, streaks, dry days.
    static let statusSuccess = Color(light: 0x2E7D32, dark: 0x4CAF50)
    /// Approaching the limit: the amber dot and bar. Never text.
    static let statusWarning = Color(light: 0xA67C00, dark: 0xE8A020)
    /// Over the limit: dots, bars, lines.
    static let statusDanger = Color(light: 0x960018, dark: 0xDD2C2C)
    /// Over the limit, as TEXT and trend glyphs.
    static let statusDangerText = Color(light: 0x960018, dark: 0xDF3A3A)
    /// A failed input or operation — Material's error role, not a status.
    static let statusError = Color(light: 0xB3261E, dark: 0xCF6679)

    /// The empty year-cell fill: a lightness step of about 10 L* above the card
    /// in both modes, the difference Android's Color.kt found readable on a
    /// device where a contrast ratio was the wrong instrument (1.29 : 1 light,
    /// 1.36 : 1 dark). Until v0.86.0 the dark value sat 3.4 L* above the card and
    /// read as nothing.
    static let yearCellEmpty = Color(light: 0xDDE3F0, dark: 0x303032)

    /// One colour per appearance, resolved by UIKit's trait collection.
    private init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((value >> 16) & 0xFF) / 255.0,
                green: CGFloat((value >> 8) & 0xFF) / 255.0,
                blue: CGFloat(value & 0xFF) / 255.0,
                alpha: 1.0
            )
        })
    }
}
