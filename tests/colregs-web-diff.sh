#!/bin/sh
# Diff the web colregs against the shell colregs, function by function.
#
# The web README says the geometry is "ported function-for-function, with
# the same names, so the awk and the JS can be read side by side", and
# that they are "also diffed: both implementations are run over all 361
# integer bearings and the output compared."
#
# THAT CHECK WAS NOT IN THE REPOSITORY. Nothing ran it, and the first time
# it was run -- 22 October 2026 -- it found aspect_words had its own arc
# boundaries in the JS (8, 75, 105, 172) where the awk delegates to
# rel_phrase with ahead=2.5. The two told the reader different things
# about the same geometry, on 580 of the 361 aspects, for as long as the
# web build has existed.
#
# So this is the check the README describes, written down. It compares
# every function the two share, over its whole input range, as strings:
#
#   rel_phrase   360 bearings x 2 possessives
#   aspect_words 361 aspects
#   arc_vis      6 arc types x 361 bearings
#
# Run from the repository root:  sh tests/colregs-web-diff.sh
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

if ! command -v node >/dev/null 2>&1; then
  echo "SKIPPED -- the cross-implementation diff needs node"
  exit 0
fi

AWK=awk
for a in mawk gawk awk; do command -v "$a" >/dev/null 2>&1 && { AWK=$a; break; }; done
TMP=${TMPDIR:-/tmp}/colregs-diff.$$
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

$AWK -f src/colregs/engine.awk -f src/colregs/contacts.awk -f src/colregs/review.awk \
     -f tests/colregs-web-dump.awk </dev/null > "$TMP/awk.out"
node tests/colregs-web-dump.js docs/web/colregs/colregs.js > "$TMP/js.out"

a=$(wc -l < "$TMP/awk.out" | tr -d ' ')
b=$(wc -l < "$TMP/js.out" | tr -d ' ')
if [ "$a" != "$b" ]; then
  echo "FAIL -- the two dumps are different lengths: awk $a, js $b"
  exit 1
fi
if diff "$TMP/awk.out" "$TMP/js.out" > "$TMP/d" 2>&1; then
  echo "  ok    the web and shell implementations agree ($a comparisons)"
  exit 0
fi
echo "FAIL -- the web and shell implementations disagree:"
head -10 "$TMP/d"
echo "        $(grep -c '^[<>]' "$TMP/d") differing lines"
exit 1
