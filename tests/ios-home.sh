#!/bin/sh
#  THE BUG THIS EXISTS FOR
#
#  Every tool kept its engine, config and log in $HOME/.<tool>.  On iOS
#  that is refused: a-Shell's own README says "In iOS, you cannot write
#  in the ~ directory, only in ~/Documents/, ~/Library/ and ~/tmp",
#  because $HOME there is the app's data container.
#
#  So not one of the six would start on an iPad - the platform this
#  whole project exists for.  Larry got
#
#      celnav: cannot create /private/var/mobile/Containers/Data/...
#
#  and reported "a could not create container error", which is exactly
#  what that says if you are reading the path and not the verb.
#
#  Nothing caught it because every machine the suite runs on has a
#  writable $HOME.  This check takes that away.
set -e
cd "$(dirname "$0")/.."
SH=${1:-sh}
here=$(pwd)
d=$(mktemp -d); trap 'chmod -R u+w "$d" 2>/dev/null; rm -rf "$d"' EXIT
bad=0; say(){ echo "  FAIL $1"; bad=1; }

TOOLS="celnav colregs tides deck-log weather"

#  ---- 1. $HOME exists but its dotfolder cannot be made ---------------
#  Portable everywhere, root included: a FILE already sits where the
#  dotfolder would go, so mkdir is refused for a reason no uid can
#  override.  The fallback to ~/Documents must carry every tool.
h="$d/collide"; mkdir -p "$h/Documents"
for t in $TOOLS; do
  case "$t" in deck-log|weather) f=.bashnav ;; *) f=".$t" ;; esac
  : > "$h/$f" 2>/dev/null || true
done
for t in $TOOLS; do
  o=$(cd "$h/Documents" && HOME="$h" $SH "$here/bin/$t" version 2>&1) || true
  case "$o" in
    "$t "*) ;;
    *) say "$t did not start when \$HOME/.$t was unusable: [$o]" ;;
  esac
done
for f in .celnav .colregs .tides .bashnav; do
  [ -d "$h/Documents/$f" ] || say "$f did not fall back to ~/Documents"
done

#  ---- 2. and the real thing: $HOME itself is not writable ------------
#  This is the actual iOS condition.  It needs a uid that chmod applies
#  to, so it runs as an ordinary user, or via setpriv when the suite is
#  running as root.  It is never skipped silently.
h2="$d/readonly"; mkdir -p "$h2/Documents"
#  mktemp makes its directory 0700, so an unprivileged uid cannot even
#  walk into it.  Open the path, then close $HOME itself.
chmod 755 "$d"; chmod 777 "$h2/Documents"; chmod 555 "$h2"
run=""
if [ "$(id -u)" != 0 ]; then
  run="env"
elif command -v setpriv >/dev/null 2>&1; then
  run="setpriv --reuid=65534 --regid=65534 --clear-groups env"
fi
if [ -z "$run" ]; then
  echo "  SKIP  read-only \$HOME: running as root and setpriv is not here."
  echo "        chmod does not apply to root, so this cannot be modelled."
  echo "        Check 1 above still covers the fallback."
else
  chmod -R a+rX "$here/bin"
  for t in $TOOLS; do
    o=$(cd "$h2/Documents" && $run HOME="$h2" PATH=/usr/bin:/bin \
        $SH "$here/bin/$t" version 2>&1) || true
    case "$o" in
      "$t "*) ;;
      *) say "$t did not start with a read-only \$HOME: [$o]" ;;
    esac
  done
  #  and it must actually WORK there, not merely print its version:
  #  tides has to unpack 2.9 MB and then find a station in it.
  o=$(cd "$h2/Documents" && $run HOME="$h2" PATH=/usr/bin:/bin \
      $SH "$here/bin/tides" find falmouth 2>&1) || true
  case "$o" in *"Falmouth Heights"*) ;;
    *) say "tides could not unpack and search with a read-only \$HOME" ;; esac
  o=$(cd "$h2/Documents" && $run HOME="$h2" PATH=/usr/bin:/bin \
      $SH "$here/bin/celnav" doctor 2>&1) || true
  case "$o" in *"NOT WRITABLE"*) say "celnav doctor still reports its folder unwritable" ;; esac
  case "$o" in *"Documents/.celnav"*) ;;
    *) say "celnav doctor does not name the folder it actually used" ;; esac
fi

#  ---- 3. nothing changed where $HOME *is* writable --------------------
h3="$d/normal"; mkdir -p "$h3/Documents"
o=$(cd "$h3" && HOME="$h3" $SH "$here/bin/celnav" version 2>&1) || true
[ -d "$h3/.celnav" ] || say "on a normal machine the folder must stay in \$HOME"
[ -d "$h3/Documents/.celnav" ] && say "it should not have used ~/Documents when \$HOME was fine"

[ "$bad" = 0 ] && echo "IOS-HOME OK"
exit $bad
