# COPYRIGHT

## Libellus Potionis - Privacy-Friendly Alcohol Tracker

Copyright &copy; 2026 Martin A. Godisch
<[android@godisch.de](mailto:android@godisch.de)>

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY
WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.  See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with
this program.  If not, see
<[https://www.gnu.org/licenses/](https://www.gnu.org/licenses/)>.

## Third-Party Assets

### GPLv3 logo

The Play-Store feature graphic embeds the GPLv3 "Free as in Freedom" logo
(`fastlane/gpl-v3-logo.svg`, recoloured white where it appears in the graphic),
used to advertise that this program is licensed under version 3 of the GNU
General Public License.  The official GPL, AGPL and
LGPL logos and their variants are the work of José Obed and are in the public
domain.  See
<[https://www.gnu.org/graphics/license-logos](https://www.gnu.org/graphics/license-logos)>
for the originals and terms.

### "Get it on F-Droid" badges

The `fdroid/get-it-on-<lang>.svg` files are the official "Get it on F-Droid"
download badges (one per store-listing language — e.g. `get-it-on-en.svg`,
`get-it-on-de.svg`, `get-it-on-pt-br.svg`, `get-it-on-zh-cn.svg`), used to link
to this app's listing in the F-Droid catalogue.  They all come from the same
source, the F-Droid artwork project
(<[https://gitlab.com/fdroid/artwork](https://gitlab.com/fdroid/artwork)>, also
mirrored at
<[https://github.com/f-droid/artwork](https://github.com/f-droid/artwork)>), and
are licensed under the Creative Commons Attribution-ShareAlike 3.0 Unported
license (CC BY-SA 3.0); see
<[https://creativecommons.org/licenses/by-sa/3.0/](https://creativecommons.org/licenses/by-sa/3.0/)>
for the terms.  (F-Droid licenses the badge-generation scripts separately under
GPL-3.0-or-later; only the badge artwork is bundled here.)  These files are
repository and store-listing assets and are **not** distributed inside the
application package.

### Inter font (build tooling only)

`tools/fonts/Inter/` bundles static instances of the Inter typeface,
used solely by `tools/render-feature-graphic.py` to render the feature
graphic deterministically (so the result does not depend on the fonts installed
on the build host).  Inter is licensed under the SIL Open Font License 1.1 (see
the accompanying `OFL.txt`).  These files are build-time tooling and are **not**
distributed inside the application package.

### Noto Sans CJK (feature-graphic CJK text)

`tools/fonts/NotoSansCJK/NotoSansCJK-Regular.ttc` supplies the Japanese, Korean
and Simplified/Traditional Chinese glyphs for the `ja`, `ko`, `zh-CN` and `zh-TW`
feature-graphic copy (Inter has no CJK glyphs), and — through fontconfig's
per-glyph fallback — the CJK text in the localized "Get it on F-Droid" badges.
It is the Regular-weight OpenType Collection from the Noto CJK project
(<[https://github.com/notofonts/noto-cjk](https://github.com/notofonts/noto-cjk)>,
`Sans/OTC/NotoSansCJK-Regular.ttc`) and is licensed under the SIL Open Font
License 1.1 (see the accompanying `LICENSE`; the source and version are recorded
in `README.txt`).  Like the other bundled faces, this file is build-time tooling
for `render-feature-graphic.py` and is **not** distributed inside the application
package.

### DejaVu Sans (feature-graphic badge text)

`tools/fonts/DejaVuSans/DejaVuSans.ttf` renders the small "GET IT ON"
line of the "Get it on F-Droid" badge embedded in the feature graphic.  DejaVu
Sans is published under the DejaVu Fonts license — a permissive free font license
derived from the Bitstream Vera and Arev font licenses (see the accompanying
`LICENSE`).  Like Inter, this file is build-time tooling for
`render-feature-graphic.py` and is **not** distributed inside the application
package.  See `tools/fonts/DejaVuSans/README.txt` for the exact source.

### Rokkitt (feature-graphic badge text)

The "F-Droid" wordmark of that badge is set in Rokkitt Bold.  Rokkitt is the work
of Vernon Adams and is licensed under the SIL Open Font License 1.1.  The upstream
*variable* font is checked in at
`tools/fonts-src/Rokkitt/Rokkitt[wght].ttf` (with its `OFL.txt`); the
static `tools/fonts/Rokkitt/Rokkitt-Bold.ttf` the renderer actually uses
is instanced from it reproducibly via `make rokkitt-bold` (see
`tools/fonts-src/Rokkitt/README.txt`).  Like the fonts above, these are
build-time tooling for `render-feature-graphic.py` and are **not** distributed
inside the application package.
