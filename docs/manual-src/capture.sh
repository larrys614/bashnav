#!/bin/sh
#  Rebuild the figure fixtures that track the APP.
#
#  Figures are drawn from the panel fixtures in cap/, one per figure.  Six
#  of them are frozen: they show one saved working session -- a Dubhe
#  sight taken at 2026-08-29 07:30 UT from 35 00.0'N 040 00.0'W, the fix
#  it belongs to, the triangle and a marked drill -- and nothing in the
#  app changes them.  Those six were recovered from the figures' own SVGs
#  by extract_panel.py, after the original /tmp captures were lost.
#
#  Two are different.  The training menu and the syllabus show the state
#  of the teaching module, so they go stale every time a lesson is added:
#  the menu prints how many lessons there are and the syllabus lists all
#  of them by module.  This script rebuilds those two from the built
#  program, so redrawing them is a command rather than an afternoon of
#  remembering how the originals were made.
#
#    sh capture.sh            rebuild cap/train.txt and cap/syllabus.txt
#    sh capture.sh <dir>      write them to <dir> instead, to compare first
#
#  Redrawing the figures is then: sh capture.sh && python3 build_figs2.py
#  -- and build_figs2.py needs cairosvg for the PNG the PDFs embed, which
#  figgen skips with a warning when it is not installed.
set -e
cd "$(dirname "$0")"
OUT=${1:-cap}
ROOT=$(cd ../.. && pwd)
APP="$ROOT/bin/celnav"
[ -x "$APP" ] || { echo "capture: $APP is not built -- run ./build.sh" >&2; exit 1; }
[ -d "$OUT" ] || mkdir -p "$OUT"

#  A SCRATCH HOME.  Capturing must not touch the reader's own progress --
#  and must not read it either, or the fixture would differ from one
#  machine to the next and the figure would change for no reason.
H=$(mktemp -d)
trap 'rm -rf "$H" 2>/dev/null || true' EXIT
CELNAV_HOME="$H" "$APP" reinstall >/dev/null 2>&1

#  The state the callouts describe in words: four lessons finished, and
#  fourteen of eighteen drills right.  These numbers and the label text in
#  build_figs2.py have to agree, so change them together.
printf 'lessons=F1,F2,F3,F4\ndok=14\ndtry=18\n' > "$H/progress"

#  Not a terminal, so the app emits no colour of its own accord; the menu
#  is reached with "learn" and left with x, which is also how the figure
#  shows it -- the trailing "> 1" is the keystroke the callout points at.
CELNAV_HOME="$H" sh -c "printf 'x\n' | \"$APP\" learn" > "$H/train.raw" 2>&1
CELNAV_HOME="$H" "$APP" syllabus > "$H/syl.raw" 2>&1

awk '/^  ===/ {on=1} on {print} /back to the navigation menu/ {exit}' \
    "$H/train.raw" > "$OUT/train.txt"
printf '  > 1\n' >> "$OUT/train.txt"

awk '/LEARN -- the syllabus/ {on=1} on {print} /lessons done/ {exit}' \
    "$H/syl.raw" > "$OUT/syllabus.txt"

for f in train syllabus; do
  n=$(wc -l < "$OUT/$f.txt" | tr -d ' ')
  [ "$n" -gt 3 ] || { echo "capture: $OUT/$f.txt came out $n lines -- the app's output shape changed" >&2; exit 1; }
  printf 'capture: %-22s %3s lines\n' "$OUT/$f.txt" "$n"
done
