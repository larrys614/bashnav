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
  "you=2.0 rules=13.6 persist=14.0 n=3") ;;
  *) say "scores are [$r], hand-worked answer is you=2.0 rules=13.6 persist=14.0 n=3" ;;
esac

# ---------------------------------------------------------------------
#  THE TOOL'S OWN RECORD, not a hand-built one.
#
#  The log above is written by this test, with by=you -- and the tool
#  wrote by=user, which THE SCORE SHEET DOES NOT REPORT. So every check
#  above passed while the one column the whole learning loop exists for
#  was silently missing from the report, and "You are beating the rule
#  set" could never fire.
#
#  A test that writes its own fixture cannot catch a disagreement between
#  the writer and the reader. So: drive the tool, log the observation its
#  forecast was made for, and read the tool's own score sheet.
# ---------------------------------------------------------------------
H="$d/home"; mkdir -p "$H"
cat > "$H/log" <<'LOG2'
2026-08-30T06:00Z|nav|lat=41 14.0N|lon=-72.0|crs=096|sog=8.5|wdir=210|wspd=14|sea=3|~
2026-08-30T06:00Z|wx|mslp=1016.4|~
2026-08-30T12:00Z|nav|lat=41 20.0N|lon=-72.0|crs=096|sog=8.1|wdir=170|wspd=22|sea=4|~
2026-08-30T12:00Z|wx|mslp=1010.1|~
LOG2
printf '12\n150\n30\n1002\n5\n' \
  | DECKLOG_HOME="$H" WEATHER_HOME="$H" WEATHER_AWK="$AW" \
    sh ./bin/weather forecast >/dev/null 2>&1 || true

grep -q '|fc|' "$H/log" || say "the tool wrote no forecast record at all"

#  under a name the report actually uses
wrote=$($AW -F'|' '/\|fc\|/{ for(i=3;i<=NF;i++) if($i ~ /^by=/) { sub(/^by=/,"",$i); print $i } }' \
        "$H/log" | sort -u | tr '\n' ' ')
case " $wrote " in
  *" you "*) ;;
  *) say "the tool records the user's forecast as [$wrote]; the score sheet reports you, rules and persist" ;;
esac

#  the forecast is for a time 12 hours from now, so log the observation
#  it was made for -- otherwise there is nothing to verify against and
#  the report is correctly empty.
valid=$($AW -F'|' '/\|fc\|/{ for(i=3;i<=NF;i++) if($i ~ /^for=/) { sub(/^for=/,"",$i); print $i; exit } }' "$H/log")
if [ -n "$valid" ]; then
  printf '%s|nav|lat=42 00.0N|lon=-72.0|wdir=150|wspd=32|sea=5|~\n' "$valid" >> "$H/log"
  printf '%s|wx|mslp=1003.0|~\n' "$valid" >> "$H/log"
else
  say "the tool's forecast record carries no valid time"
fi

sheet=$(DECKLOG_HOME="$H" WEATHER_HOME="$H" WEATHER_AWK="$AW" sh ./bin/weather score 2>/dev/null)
case "$sheet" in
  *"you "*) ;;
  *) say "the tool's own score sheet does not show the user's column" ;;
esac
case "$sheet" in
  *"rules "*) ;;
  *) say "the tool's own score sheet does not show the rules' column" ;;
esac
case "$sheet" in
  *"persist "*) ;;
  *) say "the tool's own score sheet does not show persistence" ;;
esac

[ "$bad" = 0 ] && echo "SCORE E2E OK"
exit $bad
