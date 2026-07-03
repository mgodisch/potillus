Noto Sans CJK -- bundled for tools/render-feature-graphic.py
============================================================

File:     NotoSansCJK-Regular.ttc  (OpenType Collection, Regular weight)
Families: Noto Sans CJK JP / KR / SC / TC / HK (+ the Mono variants in the
          same collection, unused here)
Source:   https://github.com/notofonts/noto-cjk
          Sans/OTC/NotoSansCJK-Regular.ttc  (release "Sans 2.004")
License:  SIL Open Font License 1.1 -- see the accompanying LICENSE file.

WHY IT IS HERE
  Inter (the graphic's Latin text font) has no CJK/Hangul glyphs. This
  collection supplies the Japanese, Korean and Simplified/Traditional Chinese
  glyphs for the ja, ko, zh-CN and zh-TW feature-graphic copy, and -- via
  fontconfig's per-glyph fallback -- for the CJK text in the localized
  "Get it on F-Droid" badges. render-feature-graphic.py pins fontconfig to
  tools/fonts/ (this directory is scanned recursively), so the same file is used
  on every host and the render stays deterministic. Regular weight is used for
  all CJK text; the Latin title/labels keep coming from Inter.

  Only the Regular OTC is bundled to keep the download small (~19 MB). If bolder
  CJK labels are ever wanted, add the matching -Medium/-Bold OTC here and extend
  the font-family logic in the script.
