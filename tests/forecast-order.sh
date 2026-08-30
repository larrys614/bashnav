#!/bin/sh
#  NEVER TELL BEFORE YOU ASK.
#
#  The house rule, from the colregs lights quiz that printed the aspect
#  and then asked for it. Here it means: nothing of the app's forecast
#  may appear on screen before the user's own is written down. Print the
#  machine's guess first and the person has not forecast anything - they
#  have read an answer and agreed with it.
#
#  Testable, because it is an ordering property of the transcript.
set -e
cd "$(dirname "$0")/.."
AW=${1:-awk}; SH=${2:-sh}
d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
export DECKLOG_HOME="$d"; export WEATHER_HOME="$d"
export DECKLOG_AWK="$AW"; export WEATHER_AWK="$AW"
$SH ./bin/weather version >/dev/null 2>&1
cat > "$d/log" <<'LOG'
2026-08-30T06:00Z|nav|lat=41 14.0N|wdir=210|wspd=14|sea=3|~
2026-08-30T06:00Z|wx|mslp=1016.4|~
2026-08-30T12:00Z|nav|lat=41 20.0N|wdir=170|wspd=22|sea=4|~
2026-08-30T12:00Z|wx|mslp=1010.1|~
LOG
printf '12\n200\n25\n1005\n5\n' | $SH ./bin/weather forecast > "$d/out" 2>&1 || true
bad=0
#  the app's own forecast is the "rules" line; the user's last prompt is
#  the sea-state menu. The rules line must come after it.
p=$($AW '/YOUR forecast/{print NR; exit}' "$d/out")
q=$($AW '/^  rules /{print NR; exit}'      "$d/out")
u=$($AW '/^  user  /{print NR; exit}'      "$d/out")
[ -n "$p" ] || { echo "  FAIL the user was never asked for a forecast"; bad=1; }
[ -n "$q" ] || { echo "  FAIL the app never offered one of its own"; bad=1; }
if [ -n "$p" ] && [ -n "$q" ] && [ "$q" -lt "$p" ]; then
  echo "  FAIL the app showed its forecast at line $q, before asking at line $p"; bad=1
fi
#  and the user's record must be in the log before the rules record
o=$($AW -F'|' '/\|fc\|/{ for(i=3;i<=NF;i++) if($i ~ /^by=/) printf "%s ", substr($i,4) }' "$d/log")
case "$o" in
  "user rules persist "*|"user rules persist") ;;
  *) echo "  FAIL the forecasts were written in the order [$o]; the user's must be first"; bad=1 ;;
esac
[ "$bad" = 0 ] && echo "ORDER OK (asked at line $p, answered at line $q)"
exit $bad
