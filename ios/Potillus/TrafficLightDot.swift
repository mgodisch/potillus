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

import PotillusKit
import SwiftUI

// =============================================================================
// TrafficLightDot – "how many more of this drink fit?" as a 12-pt dot
// =============================================================================
//
// The SwiftUI counterpart of Android's TrafficLightDot. Same three states and
// the same two styles.
//
// COLOUR (always): the dot uses the SAME palette as the Today screen's limit
//   bars (`Emphasis.tint`) — the app tint for green, orange for one-left, red
//   for none-left — so a green dot and a calm bar read as the same "you're fine".
//
// SYMBOLS (opt-in, Settings → Appearance → alternative status symbols): the dot
//   adds a glyph that encodes the state by SHAPE as well as hue, for red–green
//   colour-vision deficiency (WCAG 1.4.1): a cross for red, an up-arrow for
//   green, a "1" for yellow. The specular highlight of the plain style is dropped
//   so it does not compete with the glyph.
//
// ACCESSIBILITY (either style): the dot is one element carrying a localised
//   description of the capacity state, so VoiceOver speaks what sighted users
//   read from the colour or glyph — the glyph itself is decorative.
// =============================================================================

struct TrafficLightDot: View {

    /// The pre-computed status for this drink's serving.
    let light: TrafficLight

    /// When `true`, overlay the colour-blind glyph (flat style); when `false`,
    /// draw the plain coloured sphere. Threaded from `alternativeStatusSymbols`.
    var useSymbols = false

    @Environment(\.appLocale) private var locale

    private static let size: CGFloat = 12

    private var color: Color {
        switch light {
        // A traffic light's calm state is GREEN, not the app's blue accent. iOS
        // mapped `.green` to `.accentColor` (blue), so the "servings remain" dot
        // read as blue while Android drew it green (successColor). The three
        // states now match Android's TrafficLightDot: green / amber / red.
        case .green: return .green
        case .yellow: return .orange
        case .red: return .red
        }
    }

    /// The colour-blind glyph, or `nil` for yellow (drawn as a "1" text instead,
    /// since there is no single-digit SF Symbol that reads as a bare numeral).
    private var symbol: String? {
        switch light {
        case .red: return "xmark"
        case .green: return "arrow.up"
        case .yellow: return nil
        }
    }

    private var statusDescription: String {
        switch light {
        case .green: return Loc.string("Within your limits", locale: locale)
        case .yellow: return Loc.string("Almost at your limit", locale: locale)
        case .red: return Loc.string("Limit reached", locale: locale)
        }
    }

    var body: some View {
        ZStack {
            Circle().fill(color)

            if useSymbols {
                glyph
            } else {
                // Specular highlight: a small, semi-transparent white circle set
                // to the upper-left fakes a convex ball lit from ten o'clock —
                // radius 35 % and offset 28 % per axis, matching the Android dot.
                Circle()
                    .fill(Color.white.opacity(0.52))
                    .frame(width: Self.size * 0.35, height: Self.size * 0.35)
                    .offset(x: -Self.size * 0.14, y: -Self.size * 0.14)
            }
        }
        .frame(width: Self.size, height: Self.size)
        .accessibilityElement()
        .accessibilityLabel(statusDescription)
    }

    @ViewBuilder
    private var glyph: some View {
        // White reads on all three tints; the glyph is decorative (the dot's
        // accessibility label already carries the meaning).
        if let symbol {
            Image(systemName: symbol)
                .font(.system(size: Self.size * 0.66, weight: .bold))
                .foregroundStyle(.white)
        } else {
            Text(verbatim: "1")
                .font(.system(size: Self.size * 0.66, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}
