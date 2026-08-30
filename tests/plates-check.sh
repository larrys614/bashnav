#!/bin/sh
#  The README pastes real program output into fenced blocks.  Those are
#  hand-copied, so they drift: the colregs plate sat there for weeks
#  showing "You are on her starboard bow" after the program had started
#  saying "broad on her starboard bow", and missing the note explaining
#  why a sidelight is drawn aft of the masts - which is the one thing a
#  reader looking at that picture actually needs.
#
#  This regenerates each plate and diffs it against what the README
#  claims.  It does not rewrite the README; a plate that has changed is
#  a change somebody should look at.
set -e
cd "$(dirname "$0")/.."
AW=${1:-awk}
CR="-f src/colregs/engine.awk -f src/colregs/contacts.awk -f src/colregs/review.awk"
bad=0
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

#  plate <n> <last-line-pattern> <awk args...>   nth "WHAT DO YOU SEE?" block
plate() {
  n=$1; last=$2; shift 2
  $AW $CR -v cmode=plain "$@" </dev/null | sed -n "/WHAT DO YOU SEE/,/$last/p" > "$tmp/want"
  #  Match ANY line opening or closing a fence, not just a bare one.
  #  A "```sh" opener does not match /^```$/ while its closer does, so a
  #  bare-fence pattern goes out of phase after the first shell block and
  #  every plate after it is read from the wrong place.
  $AW -v n="$n" '
    /^```/ { inb = !inb; if(!inb) blk=0; next }
    inb && /WHAT DO YOU SEE/ && !blk { seen++; blk=1 }
    inb && blk && seen==n { print }
  ' README.md > "$tmp/got"
  [ -s "$tmp/got" ] || { echo "  plate $n: not found in README.md"; bad=1; return; }
  if ! diff -u "$tmp/want" "$tmp/got" > "$tmp/d"; then
    echo "  plate $n has drifted from the program:"
    sed -n '3,12p' "$tmp/d" | sed 's/^/    /'
    bad=1
  fi
}

plate 1 yellow    -v cmd=light -v key=mineclear -v th=310
plate 2 "in line" -v cmd=light -v key=ram -v th=40

[ "$bad" = 0 ] && echo "PLATES OK"
exit $bad
