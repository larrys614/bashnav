#!/bin/sh
# Regenerate docs/web/celnav/lessons.js from src/celnav/teach.awk --
# the thirty-three lessons, the syllabus, and the ten-step annotated
# walkthrough.
#
# The lessons are PRINTED, not stored: les_F3() and the rest call
# thead/tp/tb, and the figures are drawn onto a character grid, so the
# only way to get a lesson is to run it and read what comes out. That is
# the same reason colregs carries a generator, and the same reason this
# one exists rather than the lessons being typed across: the contacts
# lessons were typed by hand first, came across verbatim, and still
# carried the row of dashes the terminal draws under a heading.
#
# The syllabus comes from syl_init() through cmd=t_syldump, so the module
# names and their order are the awk's. The answer and the reason come
# from cmd=t_qmeta, because ques() only sets them on the branch that does
# not print.
#
# Run from anywhere:  sh docs/web/celnav/gen/make-celnav-web.sh
set -e
ROOT=$(cd "$(dirname "$0")/../../../.." && pwd)
SRC="$ROOT/src/celnav"
GEN="$ROOT/docs/web/celnav/gen"
#  the shared JS/JSON escaper, loaded before every dumper. Each of these
#  files used to carry its own copy, and all of them were wrong the same
#  way - see the note at the top of it.
ESC="$ROOT/docs/web/gen/jsonesc.awk"
OUT="$ROOT/docs/web/celnav/lessons.js"

AWK=awk
for a in mawk gawk awk; do command -v "$a" >/dev/null 2>&1 && { AWK=$a; break; }; done

ENG="-f $SRC/engine.awk -f $SRC/teach.awk"

VER=$(sed -n 's/^CELNAV_VERSION=//p' "$SRC/10-head.sh" | head -1)
[ -n "$VER" ] || { echo "make-celnav-web: cannot read CELNAV_VERSION" >&2; exit 1; }

#  the lesson ids, in the syllabus's own order
IDS=$($AWK $ENG -v cmode=plain -v cmd=t_syldump </dev/null | cut -f1 | tr '\n' ' ')
[ -n "$IDS" ] || { echo "make-celnav-web: the syllabus dumped nothing" >&2; exit 1; }

{
  echo "// celnav's teaching track -- generated from bin/celnav v$VER by running"
  echo "// teach.awk's own lesson functions and dumping what they printed. The"
  echo "// modules and their order come from syl_init(); the answers come from"
  echo "// cmd=t_qmeta, because ques() only sets them on the branch that does not"
  echo "// print. Do not hand-edit: regenerate with"
  echo "// docs/web/celnav/gen/make-celnav-web.sh so the two cannot drift."
  echo "window.CELNAV_SYLLABUS = ["
  n=0
  tot=$(printf '%s\n' $IDS | wc -l | tr -d ' ')
  $AWK $ENG -v cmode=plain -v cmd=t_syldump </dev/null | while IFS='	' read -r id mod ttl; do
    n=$((n+1))
    printf ' { "id": "%s", "module": "%s", "title": "%s" }' "$id" "$mod" "$ttl"
    [ "$n" -lt "$tot" ] && echo "," || echo ""
  done
  echo "];"
  echo "window.CELNAV_LESSONS = ["
  n=0
  for L in $IDS; do
    n=$((n+1))
    meta=$($AWK $ENG -v cmode=plain -v cmd=t_qmeta -v les="$L" </dev/null)
    ans=${meta%%	*}
    why=${meta#*	}
    $AWK $ENG -v cmode=plain -v FIGDUMP=1 -v cmd=t_lesson -v les="$L" </dev/null \
      | $AWK -f "$ESC" -f "$GEN/dumptlesson.awk" -v id="$L" -v ans="$ans" -v why="$why"
    [ "$n" -lt "$tot" ] && echo "," || echo ""
  done
  echo "];"
  #  THE ANNOTATED WALKTHROUGH, ten steps, generated the same way and for
  #  the same reason. Three of them draw, and all three can be REAL
  #  drawings in a browser rather than named gaps: the triangle is the
  #  sandbox's code and the plotting sheet is the sight screen's. So
  #  plot_sheet() dumps its own lines under FIGDUMP and dumpwalk.awk
  #  carries the azimuths and intercepts through.
  echo ""
  $AWK $ENG -v cmode=plain -f "$GEN/dumpwalkcase.awk" </dev/null
  echo ""
  echo "window.CELNAV_WALK = ["
  n=0
  for W in 1 2 3 4 5 6 7 8 9 10; do
    n=$((n+1))
    $AWK $ENG -v cmode=plain -v FIGDUMP=1 -v cmd=t_walk -v step="$W" </dev/null \
      | $AWK -f "$ESC" -f "$GEN/dumpwalk.awk" -v step="$W"
    [ "$n" -lt 10 ] && echo "," || echo ""
  done
  echo "];"
} > "$OUT.new"

mv "$OUT.new" "$OUT"
echo "make-celnav-web: wrote $OUT"
