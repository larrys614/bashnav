#!/bin/sh
# Verify the browser celnav build against the awk engine.
#
# This is NOT part of tests/run-tests.sh.  That suite is POSIX sh and awk
# only, so it runs on the boat; this one needs node, python3 and a
# headless Chromium, so it runs on a development machine before a push.
#
#   sh docs/web/tests/run-celnav-web.sh            400 cases
#   sh docs/web/tests/run-celnav-web.sh --full     3000 cases
#
# WHY THIS EXISTS.  The browser's sight reduction had been diffed piece by
# piece and every piece agreed: body_at(), corrections() and
# reduce_sight() match the awk to nine decimals.  Two faults shipped
# anyway, and neither was in a piece:
#
#   plot.js used solve_fix()'s FIRST PASS as the fix.  solve_fix()
#   linearises the reduction about the position it is handed, so the
#   answer was right to 0.02 nm from a live DR and 43 nm out from a DR
#   five degrees away.  Every per-sight number on screen was correct,
#   which is why nothing looked wrong.
#
#   engine.js set the planets' horizontal parallax to zero, with a comment
#   claiming the awk multiplied it by zero.  The awk does not.  0.08' on a
#   Venus sight at 14 degrees, and more when she is close.
#
# What each stage proves:
#
#   1  the engine     the whole reduction and the converged fix, against
#                     the awk's own numbers at full precision, over
#                     generated cases - every awk on the machine, because
#                     a cross-implementation diff that picks one awk
#                     proves nothing
#   2  the page       what the page SHOWS, against the awk tool's own
#                     printed working.  A module diff cannot see a wiring
#                     or formatting fault, and the fix read "35 010.0' N"
#                     while every number behind it was right
set -e
ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
cd "$ROOT"
WORK=${TMPDIR:-/tmp}/celnav-web-tests.$$
mkdir -p "$WORK"
trap 'rm -rf "$WORK"; [ -n "$SRV" ] && kill $SRV 2>/dev/null || true' EXIT

PORT=${PORT:-8731}
NCASE=400
[ "$1" = "--full" ] && NCASE=3000

AWKS=
for a in mawk gawk awk busybox; do
  [ "$a" = busybox ] && continue
  command -v "$a" >/dev/null 2>&1 && AWKS="$AWKS $a"
done
[ -n "$AWKS" ] || { echo "no awk found"; exit 2; }
echo "cases: $NCASE   awks:$AWKS"

echo
echo "1. the engine and the fix, against the awk"
for a in $AWKS; do
  printf '   %s\n' "$a"
  $a -v NCASE="$NCASE" -f src/celnav/engine.awk -f docs/web/tests/celnav-ref.awk \
     </dev/null > "$WORK/ref.$a.tsv"
  node docs/web/tests/celnav-diff.js "$WORK/ref.$a.tsv"
done

echo
echo "1b. printf's %.1f against JavaScript's"
#  C rounds a tie to the even last digit and toFixed() rounds it up, so
#  Deneb's magnitude of exactly 1.25 printed 1.2 in the shell and 1.3 on
#  the page. No browser needed: the page's own f(v, dec) is read out of
#  celnav-app.js and evaluated.
for a in $AWKS; do
  printf '   %s\n' "$a"
  $a -f docs/web/tests/fmt-ref.awk </dev/null > "$WORK/fmt.tsv"
  node docs/web/tests/fmt-check.js "$WORK/fmt.tsv"
done

#  Stage 2 drives a headless Chromium.  Playwright is not something to make
#  anyone install to reduce a sight, so if it is absent the stage is
#  SKIPPED and said to be skipped - not silently passed.  Stage 1 is the
#  one that proves the navigation.
if node -e 'require("playwright")' >/dev/null 2>&1; then
  echo
  echo "2. the page, against the awk tool's own working"
  python3 docs/web/tests/serve.py "$PORT" "$ROOT/docs/web" >/dev/null 2>&1 &
  SRV=$!
  sleep 1
  AWK1=$(echo $AWKS | cut -d' ' -f1)

  #  Each scenario is BUILT by the engine - the sights are inverted out of
  #  corrections() at a known position, not numbers anybody typed - and
  #  each carries one sight whose minutes land in [9.95, 10), the single
  #  window where a zero-pad taken from the value goes wrong.  celnav-ui.js
  #  refuses to pass a scenario without one.
  #
  #    name | bodies | true lat,lon | UT | DR lat | DR lon | speed | course
  cat > "$WORK/scn" <<'SCN'
three stars, DR on the fix|Dubhe,Bellatrix,Markab|35,-40|2026-08-29 07:30:00|35 00 N|040 00 W|0|0
three stars, DR five degrees out|Dubhe,Bellatrix,Markab|35,-40|2026-08-29 07:30:00|30 00 N|048 00 W|0|0
sun and planets by day, with a run|Sun,Venus,Jupiter|35,-40|2026-08-29 14:00:00|34 50 N|039 40 W|8|75
moon and three stars at night|Moon,Altair,Vega,Deneb|35,-40|2026-08-29 02:00:00|35 12 N|040 10 W|0|0
southern ocean, four stars|Canopus,Achernar,Rigil Kentaurus,Acrux|-48,147|2026-06-14 11:00:00|47 40 S|147 20 E|6|250
SCN

  while IFS='|' read -r name bodies pos utc dlat dlon spd crs; do
    [ -n "$name" ] || continue
    printf '   %s\n' "$name"
    tlat=${pos%,*}; tlon=${pos#*,}
    $AWK1 -v SCN="$bodies" -v TLAT="$tlat" -v TLON="$tlon" -v UTC0="$utc" -v PADFIX=1 \
          -f src/celnav/engine.awk -f docs/web/tests/celnav-ref.awk \
          </dev/null > "$WORK/sights.txt"
    $AWK1 -v sfile="$WORK/sights.txt" -v drlat="$dlat" -v drlon="$dlon" \
          -v speed="$spd" -v course="$crs" -v cmd=reduce \
          -f src/celnav/engine.awk </dev/null > "$WORK/shell.txt"
    PORT="$PORT" node docs/web/tests/celnav-ui.js \
         "$WORK/sights.txt" "$WORK/shell.txt" "$dlat" "$dlon" "$spd" "$crs"
  done < "$WORK/scn"

  echo
  echo "3. the almanac and the star list, against what the shell prints"
  #  The two screens whose faults are not arithmetic: the star list opened
  #  at Ankaa because the awk indexes its star arrays from 1 and the port
  #  from 0, and a GHA rendered with the latitude formatter acquires a
  #  hemisphere it cannot have. Both are invisible to a module diff and
  #  obvious in the rendered table.
  $AWK1 -v CELNAV_HOME="$WORK/ch" -f src/celnav/engine.awk \
        -v cmd=almanac -v utc="2026-08-29 07:34:00" \
        -v bodies="sun,moon,venus,mars,jupiter,saturn" </dev/null > "$WORK/almanac.txt"
  $AWK1 -f src/celnav/engine.awk -v cmd=stars </dev/null > "$WORK/stars.txt"
  PORT="$PORT" node docs/web/tests/celnav-tables.js \
       "$WORK/almanac.txt" "$WORK/stars.txt" "2026-08-29 07:34:00" "2026-01-01"

  echo
  echo "4. the noon sight and Polaris, against what the shell prints"
  #  The two latitudes that need no fix. Their arithmetic - lan_jd() and
  #  pol_lat() - is already held to the awk at full precision in stage 1;
  #  what this adds is what the PAGE does with it, which is where this
  #  repository's shipped faults have actually lived.
  #
  #  Worth knowing, because it decides which stage you trust for what:
  #  cutting lan_jd's five iterations down to one leaves the rendered
  #  "Sun on your meridian at 16:46:29 UT" unchanged to the second, and
  #  stage 1 catches it at 3e-5 of a day on every case. The page check
  #  cannot see it, and is not meant to.
  NLAT="41 49.0 N"; NLON="071 24.0 W"; NDATE=2026-08-29
  $AWK1 -f src/celnav/engine.awk -v cmd=noon -v drlat="$NLAT" -v drlon="$NLON" \
        -v utc="$NDATE" </dev/null > "$WORK/noon-plan.txt"
  $AWK1 -f src/celnav/engine.awk -v cmd=noon -v drlat="$NLAT" -v drlon="$NLON" \
        -v utc="$NDATE" -v hs="60 03.2" -v ie=1.5 -v heye=2 </dev/null > "$WORK/noon-work.txt"
  $AWK1 -f src/celnav/engine.awk -v cmd=polaris -v drlon="$NLON" \
        -v utc="$NDATE 23:12:00" </dev/null > "$WORK/pol-plan.txt"
  $AWK1 -f src/celnav/engine.awk -v cmd=polaris -v drlon="$NLON" \
        -v utc="$NDATE 23:12:00" -v hs="42 18.4" -v heye=2 </dev/null > "$WORK/pol-work.txt"
  PORT="$PORT" node docs/web/tests/celnav-latitude.js \
       "$WORK/noon-plan.txt" "$WORK/noon-work.txt" "$WORK/pol-plan.txt" "$WORK/pol-work.txt"

  echo
  echo "5. sight planning and the compass check, against what the shell prints"
  #  plan_sky() is one function shared by the shell and the browser, and
  #  stage 1 holds its SELECTION to the awk's by name. What this adds is
  #  the screen around it - the twilight table, which is six find_cross()
  #  calls and two different clocks, and the compass check, which has no
  #  engine function at all: three subtractions and a sign.
  PLLAT="41 49.0 N"; PLLON="071 24.0 W"; PLDATE=2026-08-29
  $AWK1 -f src/celnav/engine.awk -v cmd=plan -v drlat="$PLLAT" -v drlon="$PLLON" \
        -v utc="$PLDATE 23:30:00" </dev/null > "$WORK/plan.txt"
  $AWK1 -f src/celnav/engine.awk -v cmd=compass -v drlat="$PLLAT" -v drlon="$PLLON" \
        -v utc="$PLDATE 10:15:00" -v body=Sun </dev/null > "$WORK/compass-plain.txt"
  $AWK1 -f src/celnav/engine.awk -v cmd=compass -v drlat="$PLLAT" -v drlon="$PLLON" \
        -v utc="$PLDATE 10:15:00" -v body=Sun -v cbrg=118.5 -v variation=-14.0 \
        </dev/null > "$WORK/compass.txt"
  PORT="$PORT" node docs/web/tests/celnav-plan.js \
       "$WORK/plan.txt" "$WORK/compass.txt" "$WORK/compass-plain.txt"

  echo
  echo "CELNAV WEB: all stages passed"
else
  echo
  echo "2. SKIPPED -- the browser stage needs playwright:  npm i -D playwright"
  echo
  echo "CELNAV WEB: the engine passed; the page was not checked"
fi
