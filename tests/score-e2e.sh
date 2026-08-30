#!/bin/sh
#  End to end: forecasts written, the observation they were for logged,
#  and all three scored.  Uses a log built by hand so the numbers are
#  known and the arithmetic can be checked by eye.
set -e
cd "$(dirname "$0")/.."
AW=${1:-awk}
d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
bad=0; say(){ echo "  FAIL $1"; bad=1; }
cat > "$d/log" <<'LOG'
2026-08-30T06:00Z|nav|lat=41 14.0N|crs=096|sog=8.5|wdir=210|wspd=14|sea=3|~
2026-08-30T06:00Z|wx|mslp=1016.4|airt=18.0|dewp=14.0|seat=17.5|~
2026-08-30T12:00Z|nav|lat=41 20.0N|crs=096|sog=8.1|wdir=170|wspd=22|sea=4|~
2026-08-30T12:00Z|wx|mslp=1010.1|airt=17.2|dewp=16.8|seat=16.9|~
2026-08-30T12:00Z|fc|for=2026-08-31T00:00Z|by=you|wdir=150|wspd=30|mslp=1002|~
2026-08-30T12:00Z|fc|for=2026-08-31T00:00Z|by=rules|wdir=114|wspd=48|mslp=1001|~
2026-08-30T12:00Z|fc|for=2026-08-31T00:00Z|by=persist|wdir=170|wspd=22|mslp=1010|~
2026-08-31T00:00Z|nav|lat=42 00.0N|crs=096|sog=7.0|wdir=150|wspd=32|sea=5|~
2026-08-31T00:00Z|wx|mslp=1003.0|airt=16.0|dewp=15.0|seat=16.0|~
LOG
cat > "$d/p.awk" <<'PROBE'
BEGIN{ sc_verify(LOG)
  printf "you=%.1f rules=%.1f persist=%.1f n=%d\n", TOT["you"], TOT["rules"], TOT["persist"], VN }
PROBE
r=$($AW -f src/common/log.awk -f src/common/colour.awk -f src/weather/wx.awk \
      -f src/weather/score.awk -f "$d/p.awk" -v LOG="$d/log" </dev/null)
#  worked by hand against the 00Z observation: wdir 150, wspd 32, mslp 1003.0
#    you     |150-150|*0.1 + |30-32|*0.5 + |1002-1003|*1.0 = 0 + 1.0 + 1.0 = 2.0
#    rules   |114-150|*0.1 + |48-32|*0.5 + |1001-1003|*1.0 = 3.6 + 8.0 + 2.0 = 13.6
#    persist |170-150|*0.1 + |22-32|*0.5 + |1010-1003|*1.0 = 2.0 + 5.0 + 7.0 = 14.0
case "$r" in
  "you=2.0 rules=13.6 persist=14.0 n=3") echo "SCORE E2E OK" ;;
  *) say "scores are [$r], hand-worked answer is you=2.0 rules=13.6 persist=14.0 n=3" ;;
esac
exit $bad
