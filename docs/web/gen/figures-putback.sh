#!/bin/sh
# Put back a recaptured picture that differs only by antialiasing.
#
#   sh docs/web/gen/figures-putback.sh
#
# A SCREENSHOT IS NOT BYTE-STABLE. Two consecutive captures of the celnav
# noon screen came back 97 pixels different out of 1,083,600, maximum
# channel delta 6 - font antialiasing, invisible under a crop, and gone
# again on the next run. So make-app-figures.sh leaves the working tree
# dirty every time it runs, which trips tests/plates-check.sh - a POSIX
# check with no browser that only asks whether docs/img is clean - and
# makes the whole suite red on pictures that are correct.
#
# This is called at the end of the capture, so the capture never leaves
# sub-threshold noise behind. Decoding a PNG needs an image library, and
# the one thing we can be sure of here is the headless Chromium the
# capture has just driven, so the browser does the decoding.
#
# An SVG is the app's own drawing serialised and IS byte-stable: any
# difference in one is a real difference and is left alone.
set -e
cd "$(dirname "$0")/../../.."

NOISE_PX=${NOISE_PX:-400}      # out of a million-odd: 0.04 per cent
NOISE_DELTA=${NOISE_DELTA:-24} # one channel, out of 255

git rev-parse --git-dir >/dev/null 2>&1 || exit 0
node -e 'require("playwright")' >/dev/null 2>&1 || exit 0

for f in $(git diff --name-only -- docs/img/app); do
  case "$f" in *.png) ;; *) continue ;; esac
  git show "HEAD:$f" > "$f.committed.png" 2>/dev/null || continue
  d=$(node docs/web/tests/figures-diff.js "$f.committed.png" "$f" 2>/dev/null || echo 'differ 0 0 999')
  set -- $d
  if [ "$1" = differ ] && [ "$2" -le "$NOISE_PX" ] && [ "$4" -le "$NOISE_DELTA" ]; then
    cp "$f.committed.png" "$f"
    printf '  %-34s %s of %s pixels differ, max %s - antialiasing, put back\n' "$f" "$2" "$3" "$4"
  fi
  rm -f "$f.committed.png"
done
