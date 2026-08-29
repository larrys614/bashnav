#!/bin/sh
#  Golden-file regression for colregs and celnav.
#
#  The other suite checks that the machinery works. This one checks that
#  the OUTPUT has not changed: every deterministic screen the tools can
#  produce is captured as text and committed. A change to the code that
#  alters what a user sees then shows up as a readable diff, and has to
#  be looked at and accepted on purpose rather than slipping through.
#
#    tests/golden.sh            compare against the committed files
#    tests/golden.sh --update   rewrite them (read the diff first)
#
#  It cannot tell you whether the output is CORRECT - only whether it is
#  the same as it was. Correctness of the rules themselves is a job for
#  a human with a copy of the Convention; see tests/REVIEW.md.
set -e
cd "$(dirname "$0")/.."
AW=${GOLDEN_AWK:-awk}
G=tests/golden
E="-f src/colregs/engine.awk -f src/colregs/contacts.awk"
CE="-f src/celnav/engine.awk"
CT="-f src/celnav/engine.awk -f src/celnav/teach.awk"
mode=compare
[ "$1" = "--update" ] && mode=update
out=$(mktemp -d); trap 'rm -rf "$out"' EXIT

emit() {   # emit <name> ; program output on stdin
  cat > "$out/$1"
}

# ---- colregs: every vessel, from every 30 degrees ---------------------
{
  for k in power50 power50p sail sailrg anchor anchor50 aground nuc nucway \
           ram draught trawl fishing pilot tow200 tow200p towed mineclear \
           hover sail7; do
    b=0
    while [ "$b" -lt 360 ]; do
      echo "=== light $k $b ==="
      $AW $E -v cmode=plain -v cmd=light -v key="$k" -v th="$b" -v reveal=1 </dev/null
      b=$((b+30))
    done
  done
} | emit lights.txt

{
  for k in anchor aground nuc ram draught motorsail fishing tow200p mineclear divers; do
    echo "=== shape $k ==="
    $AW $E -v cmode=plain -v cmd=shape -v key="$k" -v reveal=1 </dev/null
  done
} | emit shapes.txt

{
  for c in reflights refshapes sndtable colours cref; do
    echo "=== $c ==="
    $AW $E -v cmode=plain -v cmd="$c" </dev/null
  done
} | emit reference.txt

{
  for l in L1 L2 L3 L4 L5 L6 L7 L8 L9 L10 L11 L12 L13 L14 L15; do
    echo "=== lesson $l ==="
    $AW $E -v cmode=plain -v cmd=lesson -v les_id="$l" </dev/null
    for a in a b c d; do
      $AW $E -v cmode=plain -v cmd=check -v les_id="$l" -v ans="$a" </dev/null || true
    done
  done
} | emit lessons-rules.txt

{
  for l in C1 C2 C3 C4 C5 C6 C7; do
    echo "=== lesson $l ==="
    $AW $E -v cmode=plain -v cmd=clesson -v les_id="$l" </dev/null
  done
} | emit lessons-contacts.txt

#  Every encounter, with every answer marked, so a changed verdict shows
{
  n=1
  while [ "$n" -le 28 ]; do
    echo "=== encounter $n ==="
    $AW $E -v cmode=plain -v cmd=enc -v seed=1 -v which="$n" </dev/null
    for a in a b c d; do
      $AW $E -v cmode=plain -v cmd=encm -v seed=1 -v which="$n" -v ans="$a" </dev/null || true
    done
    n=$((n+1))
  done
} | emit encounters.txt

{
  s=1
  while [ "$s" -le 40 ]; do
    echo "=== qlight $s ==="
    $AW $E -v cmode=plain -v cmd=qlight -v seed="$s" </dev/null
    for a in a b c d; do
      $AW $E -v cmode=plain -v cmd=qlightm -v seed="$s" -v ans="$a" -v ans2="$a" </dev/null || true
    done
    s=$((s+1))
  done
} | emit quiz-lights.txt

{
  for q in qshape qsound; do
    s=1
    while [ "$s" -le 30 ]; do
      echo "=== $q $s ==="
      $AW $E -v cmode=plain -v cmd="$q" -v seed="$s" </dev/null
      for a in a b c d; do
        $AW $E -v cmode=plain -v cmd="${q}m" -v seed="$s" -v ans="$a" </dev/null || true
      done
      s=$((s+1))
    done
  done
} | emit quiz-shapes-sound.txt

{
  s=1
  while [ "$s" -le 20 ]; do
    echo "=== scenario $s ==="
    $AW $E -v cmode=plain -v cmd=scen -v seed="$s" </dev/null
    for a in a b c d; do
      $AW $E -v cmode=plain -v cmd=scenm -v seed="$s" -v a1="$a" -v a2="$a" -v a3="$a" </dev/null || true
    done
    $AW $E -v cmode=plain -v cmd=scenout -v seed="$s" -v ans=a </dev/null || true
    s=$((s+1))
  done
} | emit scenarios.txt

{
  for st in rn usn rel360 words none; do
    s=1
    while [ "$s" -le 12 ]; do
      echo "=== track $st $s ==="
      $AW $E -v cmode=plain -v rstyle="$st" -v cmd=track -v seed="$s" </dev/null
      $AW $E -v cmode=plain -v rstyle="$st" -v cmd=trackm -v seed="$s" \
            -v a1=a -v a2=a -v a3=a </dev/null || true
      s=$((s+1))
    done
  done
} | emit track.txt

{
  s=1
  while [ "$s" -le 30 ]; do
    echo "=== ekelund $s ==="
    $AW $E -v cmode=plain -v cmd=ek -v seed="$s" </dev/null
    $AW $E -v cmode=plain -v cmd=ekm -v seed="$s" -v ans=a </dev/null || true
    s=$((s+1))
  done
} | emit ekelund.txt

# ---- celnav: the numbers, which are the part that must not drift ------
{
  for d in "2026-01-01 00:00:00" "2026-06-21 12:00:00" "2027-03-15 18:30:00" \
           "2030-09-09 06:00:00" "2045-12-25 03:00:00"; do
    echo "=== almanac $d ==="
    $AW $CE -v cmode=plain -v cmd=almanac -v utc="$d" \
       -v bodies="sun,moon,venus,mars,jupiter,saturn,polaris,Sirius,Vega" </dev/null
  done
  echo "=== star list ==="
  $AW $CE -v cmode=plain -v cmd=stars -v utc="2026-06-21 12:00:00" </dev/null
  #  Worked fixes. These use the same three star sights as the known-fix
  #  assertion in run-tests.sh, which resolve to a real position close to
  #  the DR - so what is captured here is a sensible fix and not an
  #  arithmetic exercise on invented altitudes.
  sf=$(mktemp)
  printf '%s\n' \
    "2026-08-29 07:30:00|Dubhe|C|19 32.1|1.5|3.0|10|1010|" \
    "2026-08-29 07:34:00|Bellatrix|C|49 37.2|1.5|3.0|10|1010|" \
    "2026-08-29 07:38:00|Markab|C|29 01.3|1.5|3.0|10|1010|" > "$sf"
  echo "=== fix, three stars ==="
  $AW $CE -v cmode=plain -v cmd=reduce -v sfile="$sf" \
     -v drlat="35 00 N" -v drlon="040 00 W" -v course=0 -v speed=0 </dev/null
  echo "=== fix, same three on the run ==="
  $AW $CE -v cmode=plain -v cmd=reduce -v sfile="$sf" \
     -v drlat="35 00 N" -v drlon="040 00 W" -v course=250 -v speed=8 </dev/null
  #  one sight deliberately five miles out, to capture what the residuals
  #  and the ellipse say about a blunder
  printf '%s\n' \
    "2026-08-29 07:30:00|Dubhe|C|19 32.1|1.5|3.0|10|1010|" \
    "2026-08-29 07:34:00|Bellatrix|C|49 37.2|1.5|3.0|10|1010|" \
    "2026-08-29 07:38:00|Markab|C|29 06.3|1.5|3.0|10|1010|five miles out" > "$sf"
  echo "=== fix, with a blunder in it ==="
  $AW $CE -v cmode=plain -v cmd=reduce -v sfile="$sf" \
     -v drlat="35 00 N" -v drlon="040 00 W" -v course=0 -v speed=0 </dev/null
  #  two bodies close in azimuth, to capture the weak-cut warning
  printf '%s\n' \
    "2026-08-29 07:30:00|Dubhe|C|19 32.1|1.5|3.0|10|1010|" \
    "2026-08-29 07:34:00|Merak|C|22 10.0|1.5|3.0|10|1010|" > "$sf"
  echo "=== fix, weak cut ==="
  $AW $CE -v cmode=plain -v cmd=reduce -v sfile="$sf" \
     -v drlat="35 00 N" -v drlon="040 00 W" -v course=0 -v speed=0 </dev/null
  rm -f "$sf"
  echo "=== planning, twilight and the best three ==="
  $AW $CE -v cmode=plain -v cmd=plan -v utc="2026-06-21 21:00:00" \
     -v drlat="50 09.0 N" -v drlon="005 04.0 W" </dev/null
} | emit celnav-almanac.txt

# ---- compare or update ------------------------------------------------
mkdir -p "$G"
fail=0
for f in "$out"/*; do
  n=$(basename "$f")
  if [ "$mode" = update ]; then
    cp "$f" "$G/$n"
    printf "  updated  %-26s %6d lines\n" "$n" "$(wc -l < "$f")"
  elif [ ! -f "$G/$n" ]; then
    echo "  MISSING  $n  (run tests/golden.sh --update)"; fail=$((fail+1))
  elif cmp -s "$f" "$G/$n"; then
    printf "  same     %-26s %6d lines\n" "$n" "$(wc -l < "$f")"
  else
    printf "  CHANGED  %-26s\n" "$n"
    diff -u "$G/$n" "$f" | head -40 || true
    fail=$((fail+1))
  fi
done
echo
if [ "$mode" = update ]; then echo "golden files rewritten - read the diff before committing"; exit 0; fi
if [ "$fail" -eq 0 ]; then echo "GOLDEN: no output changed"; exit 0; fi
echo "GOLDEN: $fail file(s) changed"
echo "If the change is intended, run tests/golden.sh --update and commit the diff."
exit 1
