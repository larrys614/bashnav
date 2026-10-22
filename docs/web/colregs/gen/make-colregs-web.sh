#!/bin/sh
# Regenerate docs/web/colregs/data.js from src/colregs/engine.awk.
#
# THE README PROMISED THIS AND IT WAS NOT HERE. data.js says "regenerate
# with work/dump.awk and work/mkdata.py" and there is no work/ in the
# repository -- deck-log, weather and tides all carry their gen/ and
# colregs' was lost. So the one thing the file claims, that the web build
# and the shell build cannot drift, was not true: on 22 October 2026 the
# shell gained a wind field and a vessel-kind field on the encounters and
# the browser could not see either of them, and there was no path to bring
# them across but typing.
#
# The tables are CODE, not data: ves_init() and the rest build their rows
# at run time from ar() calls and shared constants, so this runs the
# initialisers and prints what they actually built. The lessons are
# printed by les(), so they are captured from a real run.
#
# Run from anywhere:  sh docs/web/colregs/gen/make-colregs-web.sh
set -e
ROOT=$(cd "$(dirname "$0")/../../../.." && pwd)
SRC="$ROOT/src/colregs"
GEN="$ROOT/docs/web/colregs/gen"
OUT="$ROOT/docs/web/colregs/data.js"

AWK=awk
for a in mawk gawk awk; do command -v "$a" >/dev/null 2>&1 && { AWK=$a; break; }; done

#  THE TOOL LOADS ALL THREE, SO MUST THIS. engine.awk calls into
#  contacts.awk and review.awk, and mawk refuses a call to a function it
#  cannot see -- which is the right behaviour and the reason the tests
#  carry the same note.
ENG="-f $SRC/engine.awk -f $SRC/contacts.awk -f $SRC/review.awk"

VER=$(sed -n 's/^COLREGS_VERSION=//p' "$SRC/10-head.sh" | head -1)
[ -n "$VER" ] || { echo "make-colregs-web: cannot read COLREGS_VERSION" >&2; exit 1; }

{
  echo "// colregs data -- generated from bin/colregs v$VER by running the awk"
  echo "// engine's own table initialisers and dumping what they built.  Do not"
  echo "// hand-edit: regenerate with docs/web/colregs/gen/make-colregs-web.sh so"
  echo "// the two cannot drift."
  echo "window.COLREGS_DATA = {"
  printf ' "version": "%s",\n' "$VER"
  $AWK $ENG -f "$GEN/dumptables.awk" </dev/null
  echo ' "lessons": ['
  n=0
  for L in L1 L2 L3 L4 L5 L6 L7 L8 L9 L10 L11 L12 L13 L14 L15; do
    n=$((n+1))
    meta=$($AWK $ENG -v cmode=plain -v cmd=lessonmeta -v les_id="$L" </dev/null)
    ans=${meta%%	*}
    why=${meta#*	}
    $AWK $ENG -v cmode=plain -v cmd=lesson -v les_id="$L" </dev/null \
      | $AWK -f "$GEN/dumplesson.awk" -v id="$L" -v ans="$ans" -v why="$why"
    [ "$n" -lt 15 ] && echo "," || echo ""
  done
  echo ' ]'
  echo "};"
} > "$OUT.new"

mv "$OUT.new" "$OUT"
echo "make-colregs-web: wrote $OUT"
