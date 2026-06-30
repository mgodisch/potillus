Inter (static instances) — bundled build asset, NOT shipped in the APK.

Used only by android/tools/render-feature-graphic.py to render the Play-Store
feature graphic deterministically (pinned font, so rsvg-convert output does not
depend on whatever fonts happen to be installed on the build host).

Files:
  Inter-Regular.ttf   weight 400
  Inter-SemiBold.ttf  weight 600
  Inter-Bold.ttf      weight 700

These are static instances (opsz=14) extracted from the upstream Inter variable
font with fontTools' instancer. Family name is "Inter" with the usWeightClass set
per file, so fontconfig selects the right file from font-weight alone.

Upstream: https://github.com/rsms/inter  (also mirrored at google/fonts/ofl/inter)
License:  SIL Open Font License 1.1 — see OFL.txt. The OFL is a permissive,
          free/libre licence; bundling these files alongside this GPL-3.0 project
          as build tooling is compatible (fonts are not linked into the program).
