Rokkitt (variable font source)
===============================

WHAT GOES HERE
  The UPSTREAM variable font, checked in as the reproducible source for the
  static Rokkitt Bold used in the "F-Droid" wordmark of the feature-graphic
  badge (fdroid/get-it-on-*.svg):

    Rokkitt[wght].ttf     the variable font (wght axis)
    OFL.txt               the SIL Open Font License 1.1 it ships under

  This directory is deliberately OUTSIDE the pinned font dir (tools/
  fonts/) so the variable font never competes with the generated static instance
  during rendering (the renderer's fontconfig scans tools/fonts/ only).

SOURCE (download these two files into this directory)
  Rokkitt is by Vernon Adams, published under the SIL Open Font License 1.1 via
  the Google Fonts project (upstream: github.com/googlefonts/RokkittFont):

    https://raw.githubusercontent.com/google/fonts/main/ofl/rokkitt/Rokkitt%5Bwght%5D.ttf
    https://raw.githubusercontent.com/google/fonts/main/ofl/rokkitt/OFL.txt

  Save the first as  Rokkitt[wght].ttf  (keep the literal name) and the second
  as  OFL.txt  in this directory.

GENERATING THE STATIC BOLD (run once, then commit the result)
  From the android/ directory:

    make rokkitt-bold

  This instances weight 700 into  ../fonts/Rokkitt/Rokkitt-Bold.ttf  (using
  fontTools.varLib.instancer) and copies OFL.txt alongside it. Commit the
  generated Rokkitt-Bold.ttf so everyone renders the feature graphic
  byte-identically without needing fonttools installed.
