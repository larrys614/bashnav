#!/bin/sh
# Diff the browser contacts against the shell contacts, function by
# function -- the same check colregs-web-diff.sh runs, for the module
# that was until now shell-only.
#
# WHY A DIFF AND NOT A READING. The first version of the port was read
# twice and looked right. The diff failed on the second group of lines:
# ct_yd inserts thousands separators AND rounds to the nearest hundred
# yards, because a tracking party reports a range that way and the
# function is handed computed ranges -- ct_rng, the CPA, the Ekelund
# estimate -- not round numbers. The port had the commas and not the
# rounding, so every range in the browser would have read as a yard
# rather than a hundred.
#
# What it covers, over each function's whole useful range:
#
#   nrm360, sgn180   -360 to 720
#   rbrg             every integer component pair in a 11 x 11 box
#   xsrand / xrand   40 seeds x 6 draws -- a Park-Miller sequence that
#                    disagrees by one step diverges completely, so this
#                    is what makes the SEEDED exercises diffable at all
#   ct_yd            powers of seven, so the rounding is exercised
#   ek_across        5 speeds x 12 courses x 8 bearings
#   ek_gen           60 seeds, every field of the generated leg pair
#   ct_gen           60 seeds, every field of the generated contact
#   ct_brg, ct_rng   5 observations on each of 20 generated contacts
#
# Run from the repository root:  sh tests/contacts-web-diff.sh
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

if ! command -v node >/dev/null 2>&1; then
  echo "SKIPPED -- the cross-implementation diff needs node"
  exit 0
fi

AWK=awk
for a in mawk gawk awk; do command -v "$a" >/dev/null 2>&1 && { AWK=$a; break; }; done
TMP=${TMPDIR:-/tmp}/contacts-diff.$$
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

# all three, because mawk refuses a function it has not seen and the
# engine calls into review.awk. The same reason colregs-web-diff.sh
# loads all three, and the reason this is written mawk-first: a run
# under gawk hides it.
$AWK -f src/colregs/engine.awk -f src/colregs/contacts.awk -f src/colregs/review.awk \
     -f tests/contacts-web-dump.awk -v cmode=plain </dev/null > "$TMP/awk.out"
node tests/contacts-web-dump.js docs/web/colregs/contacts.js > "$TMP/js.out"

a=$(wc -l < "$TMP/awk.out" | tr -d ' ')
b=$(wc -l < "$TMP/js.out" | tr -d ' ')
if [ "$a" != "$b" ]; then
  echo "FAIL -- the two dumps are different lengths: awk $a, js $b"
  exit 1
fi
if diff "$TMP/awk.out" "$TMP/js.out" > "$TMP/d" 2>&1; then
  echo "  ok    the browser and shell contacts agree ($a comparisons)"
  exit 0
fi
echo "FAIL -- the browser and shell contacts disagree:"
head -10 "$TMP/d"
echo "        $(grep -c '^[<>]' "$TMP/d") differing lines"
exit 1
