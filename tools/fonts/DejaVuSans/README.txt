DejaVu Sans (feature-graphic badge text)
========================================

WHAT GOES HERE
  The static DejaVu Sans (Book/Regular) font, used to render the small
  "GET IT ON" line of the feature-graphic badge (fdroid/get-it-on-*.svg):

    DejaVuSans.ttf        the Book/Regular weight (400)
    LICENSE               the DejaVu Fonts license

  This directory is scanned by the feature-graphic renderer's pinned fontconfig
  (tools/fonts/ is scanned recursively), so DejaVuSans.ttf is picked up
  automatically once present. DejaVu Sans is already a static font, so — unlike
  Rokkitt — no instancing step is needed.

SOURCE (download and extract these two files into this directory)
  Official DejaVu Fonts release 2.37:

    https://github.com/dejavu-fonts/dejavu-fonts/releases/download/version_2_37/dejavu-fonts-ttf-2.37.zip

  From the zip, copy:
    dejavu-fonts-ttf-2.37/ttf/DejaVuSans.ttf  ->  DejaVuSans.ttf
    dejavu-fonts-ttf-2.37/LICENSE             ->  LICENSE

  The DejaVu Fonts license is a permissive, free font license (derived from the
  Bitstream Vera and Arev font licenses). See docs/NOTICES.md.
