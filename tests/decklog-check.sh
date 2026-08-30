#!/bin/sh
#  deck-log's properties.  The log is append-only, so these guard the
#  things that cannot be fixed later.
set -e
cd "$(dirname "$0")/.."
AW=${1:-awk}; SH=${2:-sh}
d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
export DECKLOG_HOME="$d"; export DECKLOG_AWK="$AW"
DL="$SH ./bin/deck-log"
ENGINE_F=""
bad=0
say(){ echo "  FAIL $1"; bad=1; }

#  registry: a plate containing '=' must survive, because a real one does
$DL version >/dev/null 2>&1
ENGINE_F=$(ls "$d"/decklog-*.awk 2>/dev/null | head -1)
[ -n "$ENGINE_F" ] || { echo "  FAIL the engine was never extracted"; exit 1; }
printf 'e\ny\neng.main\nYanmar\n4JH4-TE\nE12345\n4JH4-TE S/N E12345 E/G 3TNV88=B\nq\n' | $DL >/dev/null 2>&1
printf 'e\ny\ngen\nOnan\nMDKBH\nG999\nplate|with a pipe\nq\n' | $DL >/dev/null 2>&1
grep -q 'plate=4JH4-TE S/N E12345 E/G 3TNV88%3DB' "$d/boat" || say "an '=' in a plate was not encoded"
grep -q 'plate=plate%7Cwith a pipe' "$d/boat" || say "a '|' in a plate was not encoded"
o=$($DL equip | grep -c '3TNV88=B') ; [ "$o" = 1 ] || say "the plate did not decode back"

#  two engines, the same part fitted to each
printf 'n\nimpeller\nmain impeller\nJabsco 17937\neng.main\n2\nbox 3\n2\nq\n' | $DL >/dev/null 2>&1
printf 'n\ngimpeller\ngen impeller\nJabsco 22405\ngen\n1\nbox 4\n1\nq\n'      | $DL >/dev/null 2>&1

#  use one from the main engine
printf '1\nimpeller\n1\n1\n1234.5\nn\n' | $DL job >/dev/null 2>&1
hold(){ $AW -f "$ENGINE_F" -v cmd=holdraw -v LOG="$d/log" -v BOAT="$d/boat" -v cmode=plain </dev/null \
        | $AW -F'|' -v p="$1" '$1==p{print $2}'; }
h=$(hold impeller)
[ "$h" = 1 ] || say "after using 1 of 2, the holding is [$h] and should be 1"
g=$(hold gimpeller)
[ "$g" = 1 ] || say "the generator's holding is [$g]; a different part must not be touched"

#  THE test for how stock is keyed: fit the MAIN engine's impeller to
#  the generator in an emergency - which is exactly when a boat does
#  that - and the main engine's holding must still go down, because the
#  spare came out of the same locker.
printf '2\nemergency, used the main impeller\n1\n1\n40\nn\n' | $DL job >/dev/null 2>&1
h=$(hold impeller)
[ "$h" = 0 ] || say "a spare cannibalised for another machine did not come off its holding (got [$h])"

#  a stocktake SETS the holding, and the derived number follows the log
printf '7\n\n' | $DL stocktake >/dev/null 2>&1
h=$(hold impeller)
[ "$h" = 7 ] || say "after a stocktake of 7 the derived holding is [$h]"
g=$(hold gimpeller)
[ "$g" = 1 ] || say "a skipped item in a stocktake changed to [$g]; it should stay 1"

#  and now nothing is short, so the shopping list must be empty of it
o=$($DL shopping | grep -c 'main impeller' || true)
[ "$o" = 0 ] || say "an item at 7 of a minimum 2 is still on the shopping list"

#  use six, and it comes back
printf '1\nimpeller\n1\n6\n1240\nn\n' | $DL job >/dev/null 2>&1
h=$(hold impeller)
[ "$h" = 1 ] || say "after using 6 of 7 the holding is [$h]"
o=$($DL shopping | grep -c 'main impeller' || true)
[ "$o" = 1 ] || say "an item 1 short of its minimum is not on the shopping list"

#  the log is append-only: every earlier line survives every later write
cp "$d/log" "$d/before"
printf '1\noil and filter\n\n1300\nn\n' | $DL job >/dev/null 2>&1
n=$(wc -l < "$d/before")
head -n "$n" "$d/log" > "$d/after"
cmp -s "$d/before" "$d/after" || say "an earlier log line changed when a new entry was written"

#  every record the app writes must parse with the record reader
o=$($AW -f src/decklog/log.awk -f tests/dl-parse.awk -v F="$d/log")
case "$o" in
  *" 0 bad") ;;
  *) say "the app wrote a record its own reader rejects: $o" ;;
esac

[ "$bad" = 0 ] && echo "DECKLOG OK"
exit $bad
