#!/bin/sh
# =====================================================================
#  bashnav -- one icon, all the tools behind it.
#  Part of Bash Navigation Software.  Pure POSIX sh, no awk, no network.
#
#  On an iPad each tool can have its own home-screen icon through a
#  Shortcut, but that needs the Shortcuts action set to run IN APP and
#  not in the extension - the extension has no terminal, so an
#  interactive menu has nothing to talk to.
#
#  This is the version that always works: one icon, one tap, pick from
#  the list.  It is also the honest answer on a boat, where you are
#  cold and the screen is wet and finding the right icon among five is
#  worse than reading a list of five.
# =====================================================================
BASHNAV_VERSION=1.0

#  Look next to this script first, then on the PATH, then in the place
#  iOS actually lets an app write.  A launcher that cannot find the
#  tools is worse than no launcher.
here=$(dirname "$0")
find_tool() {
  for d in "$here" "$here/bin" "$HOME/Documents" "$HOME/bin" .; do
    [ -x "$d/$1" ] && { echo "$d/$1"; return 0; }
  done
  command -v "$1" 2>/dev/null && return 0
  return 1
}

TOOLS="celnav:Celestial navigation, sight reduction and the fix
colregs:Rules of the road, lights, and collision avoidance
tides:Tide prediction for 8,334 stations
deck-log:The boat's records: deck, engine, provisions
weather:Read your own barometer"

show() {
  echo
  echo "  ==============================================================="
  echo "   BASH NAVIGATION SOFTWARE $BASHNAV_VERSION"
  echo "  ==============================================================="
  echo
  i=1
  OLDIFS=$IFS; IFS='
'
  for line in $TOOLS; do
    name=${line%%:*}; desc=${line#*:}
    if p=$(find_tool "$name"); then
      printf "    %d  %-9s %s\n" "$i" "$name" "$desc"
    else
      printf "    %d  %-9s %s\n" "$i" "$name" "-- not found --"
    fi
    i=$((i+1))
  done
  IFS=$OLDIFS
  echo
  echo "    q  Quit"
  echo
}

pick() {
  n=$1
  i=1
  OLDIFS=$IFS; IFS='
'
  for line in $TOOLS; do
    name=${line%%:*}
    if [ "$i" = "$n" ]; then IFS=$OLDIFS; echo "$name"; return 0; fi
    i=$((i+1))
  done
  IFS=$OLDIFS
  return 1
}

#  a name straight off the command line: bashnav tides
if [ -n "${1:-}" ]; then
  case "$1" in
    -h|--help|help)
      echo
      echo "  bashnav            the menu"
      echo "  bashnav <tool>     run one directly"
      echo "  bashnav where      where each tool was found"
      echo
      exit 0 ;;
    version) echo "bashnav $BASHNAV_VERSION"; exit 0 ;;
    where)
      OLDIFS=$IFS; IFS='
'
      for line in $TOOLS; do
        name=${line%%:*}
        if p=$(find_tool "$name"); then printf "  %-9s %s\n" "$name" "$p"
        else printf "  %-9s not found\n" "$name"; fi
      done
      IFS=$OLDIFS
      exit 0 ;;
  esac
  if p=$(find_tool "$1"); then shift; exec "$p" "$@"; fi
  echo "  bashnav: cannot find $1"
  echo "  Put the tools beside this script, on your PATH, or in ~/Documents."
  exit 2
fi

while :; do
  show
  printf "  > "
  IFS= read -r c || exit 0
  case "$c" in
    q|Q) exit 0 ;;
    "") ;;
    *[!0-9]*) echo "  ?" ;;
    *) name=$(pick "$c") || { echo "  ?"; continue; }
       if p=$(find_tool "$name"); then "$p"
       else
         echo
         echo "  $name is not here yet."
         echo "  Put it beside this script, on your PATH, or in ~/Documents."
       fi ;;
  esac
done
