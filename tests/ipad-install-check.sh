#!/bin/sh
#  The iPad installer.  It is the only thing between a working repo and
#  a working iPad, and it runs exactly once on a boat with no way to
#  debug it, so it is tested under the condition it will actually meet:
#  a $HOME that cannot be written.
#
#  It also carries a regression that cost a round:
#
#      mkdir -p "$d" 2>/dev/null && : > "$d/.wtest" 2>/dev/null
#
#  fails twice over when $d exists but is read-only.  The redirection is
#  set up BEFORE the 2>/dev/null meant to silence it, so the error
#  reaches the terminal; and ":" is a POSIX special built-in, so under
#  dash a redirection error on it EXITS the shell.  The installer printed
#  "cannot create /tmp/pad/.wtest" and stopped dead.  ( ) fixes both.
set -e
cd "$(dirname "$0")/.."
SH=${1:-sh}
here=$(pwd)
INST=release/bashnav-ipad.sh
[ -f "$INST" ] && [ "$INST" -nt bin/tides ] || sh release/make-ipad.sh >/dev/null

d=$(mktemp -d); trap 'chmod -R u+w "$d" 2>/dev/null; rm -rf "$d"' EXIT
bad=0; say(){ echo "  FAIL $1"; bad=1; }

#  ---- 1. it parses, and answers without installing anything ---------
$SH -n "$INST" 2>/dev/null || say "the installer does not parse under $SH"
o=$($SH "$INST" --list 2>&1)
for t in celnav colregs tides deck-log weather bashnav; do
  case "$o" in *"$t"*) ;; *) say "--list does not mention $t" ;; esac
done

#  ---- 2. install under the real iOS condition -----------------------
h="$d/pad"; mkdir -p "$h/Documents"
cp "$INST" "$h/Documents/"
chmod 755 "$d"; chmod 777 "$h/Documents"; chmod 555 "$h"
run=""
if [ "$(id -u)" != 0 ]; then run="env"
elif command -v setpriv >/dev/null 2>&1; then
  run="setpriv --reuid=65534 --regid=65534 --clear-groups env"
fi
if [ -z "$run" ]; then
  echo "  SKIP  read-only \$HOME: root, and no setpriv to drop to a real uid."
else
  chmod -R a+rX "$h/Documents"
  out=$(cd "$h/Documents" && $run HOME="$h" PATH=/usr/bin:/bin \
        $SH ./bashnav-ipad.sh 2>&1) || say "the installer exited non-zero"

  #  the regression itself: no raw shell error may reach the screen
  case "$out" in
    *"cannot create"*|*"Permission denied"*|*"No such file"*)
      say "the installer leaked a shell error to the terminal" ;;
  esac
  case "$out" in *"Installed."*) ;;
    *) say "the installer did not reach the end"; printf '%s\n' "$out" | tail -4 ;; esac

  for t in celnav colregs tides deck-log weather bashnav; do
    [ -x "$h/Documents/$t" ] || say "$t was not installed, or is not executable"
  done

  #  and they must RUN from there, found on the PATH the installer set,
  #  the way a new a-Shell window would find them
  o=$(cd "$h" && $run HOME="$h" PATH=/usr/bin:/bin $SH -c \
      '. "$HOME/Documents/.profile"; weather version; tides version' 2>&1) || true
  case "$o" in *"weather 1.0"*) ;; *) say "weather not on the PATH the installer set: [$o]" ;; esac

  #  ---- 3. run it twice: one block, and the user's own lines live ---
  echo 'export MY_OWN_THING=1' >> "$h/Documents/.profile"
  (cd "$h/Documents" && $run HOME="$h" PATH=/usr/bin:/bin $SH ./bashnav-ipad.sh >/dev/null 2>&1) || true
  n=$(grep -c '^# >>> bashnav >>>' "$h/Documents/.profile" || true)
  [ "$n" = 1 ] || say "reinstalling left $n managed blocks in .profile, want 1"
  grep -q 'MY_OWN_THING' "$h/Documents/.profile" || say "reinstalling ate the user's own .profile line"
  [ -f "$h/Documents/.profile.bashnav-backup" ] || say "no backup of the .profile it first found"
fi

#  ---- 3b. a short download must be refused, not half-installed -----
#  3.4 MB over a boat's link. sh treats end-of-file as the end of an
#  unterminated heredoc, so a truncated installer writes the last tool
#  out half-finished and raises nothing -- the same shape as the
#  truncated log record in docs/HACKING.md. The file carries its own
#  length; check that the length is true and that it is acted on.
stamp=$(sed -n 's/^BASHNAV_BYTES=//p' "$INST" | sed 's/^0*//')
real=$(wc -c < "$INST" | tr -d ' ')
[ "$stamp" = "$real" ] || say "the stamped length is $stamp, the file is $real"

t="$d/trunc"; mkdir -p "$t"
head -c 3000000 "$INST" > "$t/short.sh"
o=$(cd "$t" && HOME="$t" $SH ./short.sh 2>&1) && say "a truncated installer exited 0"
case "$o" in *"stopped early"*) ;; *) say "a truncated installer did not say so: [$o]" ;; esac
[ -e "$t/Documents" ] && say "a truncated installer wrote something anyway"

cp "$INST" "$t/long.sh"; printf '\n# extra\n' >> "$t/long.sh"
o=$(cd "$t" && HOME="$t" $SH ./long.sh 2>&1) && say "an over-long installer exited 0"
case "$o" in *"LONGER than expected"*) ;; *) say "an over-long installer did not say so" ;; esac

#  ---- 4. the write probe, on its own, at the shell level ------------
#  This is the check that would have caught it. A probe of a directory
#  that exists and cannot be written must be silent and must not kill
#  the script.
ro="$d/readonly"; mkdir -p "$ro"; chmod 555 "$ro"
if [ -n "$run" ]; then
  o=$($run HOME="$d" $SH -c 'p(){ mkdir -p "$1" 2>/dev/null && ( : > "$1/.wtest" ) 2>/dev/null; }
      if p "'"$ro"'"; then echo WRITABLE; else echo READONLY; fi; echo ALIVE' 2>&1)
  case "$o" in
    "READONLY
ALIVE") ;;
    *) say "the write probe is not silent-and-surviving: [$o]" ;;
  esac
fi

[ "$bad" = 0 ] && echo "IPAD-INSTALL OK"
exit $bad
