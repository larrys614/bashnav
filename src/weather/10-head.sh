#!/bin/sh
# =====================================================================
#  weather -- read your own barometer.
#  Part of Bash Navigation Software.  Pure POSIX sh + awk, no network.
#
#  It reasons over the observations in the deck log and it TEACHES the
#  physics underneath, which is why it is its own tool and not part of
#  deck-log.  A log records what happened on this boat; a teacher is a
#  different animal, and trying to be both is how the teaching material
#  got left out of the first attempt.
#
#  IT CANNOT FORECAST, and says so.  No model, no GRIB, no chart it did
#  not get from you.  What it works from is the one category of weather
#  data that is never wrong - what you measured yourself - and the only
#  one still available when the antenna comes down.
# =====================================================================
WEATHER_VERSION=1.0

#  the log belongs to deck-log; weather only ever READS it
: "${DECKLOG_HOME:=$HOME/.bashnav}"
LOG="$DECKLOG_HOME/log"
: "${WEATHER_HOME:=$DECKLOG_HOME}"
CONF="$WEATHER_HOME/weather.conf"
PROG="$WEATHER_HOME/weather.progress"
ENGINE="$WEATHER_HOME/weather-$WEATHER_VERSION.awk"

cmode=day
#  [ -t 1 ] at the top level, never inside cmode_now: in a command
#  substitution stdout is a pipe and every terminal is told it is plain.
ISTTY=0; [ -t 1 ] && ISTTY=1
lessons=""; lon=""

awk_has_math() {
  $1 'BEGIN{ x=atan2(1,1)+sqrt(2.0)+sin(1)+cos(1); if(x>0) exit 0; exit 1 }' </dev/null >/dev/null 2>&1
}
pick_awk() {
  if [ -n "$WEATHER_AWK" ]; then AWK="$WEATHER_AWK"; return 0; fi
  for a in awk gawk mawk nawk original-awk "busybox awk"; do
    if awk_has_math "$a"; then AWK="$a"; return 0; fi
  done
  AWK=awk; echo "weather: no usable awk found." >&2; return 1
}
load_conf() {
  [ -f "$CONF" ] || return 0
  while IFS='=' read -r k v; do
    case "$k" in cmode) cmode="$v" ;; lon) lon="$v" ;; esac
  done < "$CONF"
}
save_conf() { mkdir -p "$WEATHER_HOME"; { echo "cmode=$cmode"; echo "lon=$lon"; } > "$CONF"; }
load_prog() {
  [ -f "$PROG" ] || return 0
  while IFS='=' read -r k v; do case "$k" in lessons) lessons="$v" ;; esac; done < "$PROG"
}
save_prog() { mkdir -p "$WEATHER_HOME"; echo "lessons=$lessons" > "$PROG"; }
mark_done() {
  case ",$lessons," in *,"$1",*) return 0 ;; esac
  if [ -z "$lessons" ]; then lessons="$1"; else lessons="$lessons,$1"; fi
  save_prog
}
paint() {
  [ "$cmode" = plain ] && return 0
  [ "$ISTTY" = 1 ] || return 0
  case "$cmode" in
    night) printf '\033[40m\033[31m\033[2J\033[H' ;;
    day)   printf '\033[40m\033[37m\033[2J\033[H' ;;
  esac
}
unpaint() { [ "$cmode" = plain ] || { [ "$ISTTY" = 1 ] && printf '\033[0m\n'; }; }
cmode_now() { if [ "$ISTTY" = 1 ]; then echo "$cmode"; else echo plain; fi; }
eng() {
  $AWK -f "$ENGINE" -v cmode="$(cmode_now)" -v LOG="$LOG" -v lon="$lon" \
       -v now="$(date -u '+%Y-%m-%dT%H:%MZ')" "$@" </dev/null
}
