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
#  THE FIRST RECORD IS THE USER'S, WHATEVER IT IS CALLED.  do_forecast
#  used to write by=user and now writes by=you.  The log is append-only,
#  so score.awk normalises on read and BOTH spellings have to keep
#  working for ever -- its own comment says so.  This test accepted only
#  "user", so it went red on the very commit that made the change, and
#  the message it printed blamed the ORDER, which was never wrong.  The
#  two properties are now checked and reported separately.
first=${o%% *}
rest=${o#* }
case "$first" in
  you|user) ;;
  *) echo "  FAIL the first forecast written was [$first]; the user's must be first"; bad=1 ;;
esac
case "$rest" in
  "rules persist"*) ;;
  *) echo "  FAIL after the user's came [$rest]; expected the rules then persistence"; bad=1 ;;
esac
[ "$bad" = 0 ] && echo "ORDER OK (asked at line $p, answered at line $q)"
exit $bad
