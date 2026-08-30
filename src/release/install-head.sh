#!/bin/sh
# =====================================================================
#  bashnav for iPad -- one file, one command, nothing to unpack.
#
#  WHY ONE FILE AND NOT A TARBALL PLUS A SCRIPT.
#  a-Shell does not guarantee tar, and it definitely does not ship
#  unzip -- that needs "pkg install zip", which needs the network,
#  which is the one thing this suite is built never to need.  An
#  installer whose first act is to require a tool the platform may not
#  have is an installer that fails on the boat.  So the tools travel
#  inside this script as quoted heredocs, exactly the way each tool
#  already carries its own awk engine.  sh is the only dependency, and
#  you have it or you could not be reading this.
#
#      chmod +x bashnav-ipad.sh
#      ./bashnav-ipad.sh
#
#  It is safe to run twice.  Nothing is deleted, and the block it adds
#  to .profile is replaced rather than appended a second time.
# =====================================================================
set -u
BASHNAV_RELEASE=__RELEASE__
#  Nine digits, filled in by release/make-ipad.sh after the file is
#  assembled.  The placeholder __BYTES__ is nine characters and the
#  number is zero padded to nine, so substituting it does not change the
#  file's length -- which is the only reason the number can be true.
BASHNAV_BYTES=__BYTES__
TOOLS="celnav colregs tides deck-log weather bashnav"

say()  { printf '%s\n' "$*"; }
step() { printf '  %-46s' "$*"; }
fine() { printf 'ok\n'; }
die()  { printf '\n  STOPPED: %s\n\n' "$*" >&2; exit 1; }

case "${1:-}" in
  -h|--help|help)
    say ""
    say "  bashnav-ipad.sh            install into ~/Documents"
    say "  BASHNAV_DEST=<dir> ...     install somewhere else"
    say "  bashnav-ipad.sh --list     what is inside, without installing"
    say ""
    exit 0 ;;
  --list) say ""; say "  bashnav release $BASHNAV_RELEASE"; for t in $TOOLS; do say "    $t"; done; say ""; exit 0 ;;
esac

say ""
say "  ==================================================================="
say "   BASH NAVIGATION SOFTWARE -- release $BASHNAV_RELEASE"
say "  ==================================================================="
say ""

# ---------------------------------------------------------------------
#  0. Am I all here?
#
#  This file is 3.4 MB fetched over whatever link a boat has.  A short
#  download leaves a script that still runs: sh treats end-of-file as
#  the end of an unterminated heredoc, so the last tool is written out
#  half-finished and no error is raised.  That is the same shape as the
#  truncated log record in docs/HACKING.md -- a fragment that is
#  structurally perfect and simply wrong.
#
#  So the file carries its own length and checks it before doing
#  anything.  Skipped when there is no file to measure, which is what
#  piping the script into sh looks like.
# ---------------------------------------------------------------------
if [ -f "$0" ]; then
  have=$(wc -c < "$0" 2>/dev/null | tr -d ' ')
  want=$(printf '%s' "$BASHNAV_BYTES" | sed 's/^0*//')
  if [ -n "$have" ] && [ -n "$want" ] && [ "$have" != "$want" ]; then
    say "  This file is $have bytes and should be $want."
    say ""
    if [ "$have" -lt "$want" ] 2>/dev/null; then
      say "  The download stopped early. Nothing has been installed."
      say "  Fetch it again -- a short copy would install half a tool"
      say "  and say nothing about it."
    else
      say "  It is LONGER than expected, which usually means the transfer"
      say "  changed the line endings. Fetch it again as a binary file."
    fi
    say ""
    exit 1
  fi
fi

# ---------------------------------------------------------------------
#  1. Where the tools go.
#
#  iOS lets an app write in Documents, Library and tmp and nowhere
#  else -- $HOME itself is refused.  So ~/Documents is not a
#  preference here, it is the only answer on an iPad.  We prove it by
#  writing a file rather than by guessing from the platform.
# ---------------------------------------------------------------------
#  ( ) around the probe is load bearing: a failing redirection reports
#  before the 2>/dev/null can silence it, and ":" is a special built-in,
#  so under dash the redirection error EXITS the script.  This installer
#  died exactly there the first time it met a read-only $HOME.
writable() {
  mkdir -p "$1" 2>/dev/null || return 1
  ( : > "$1/.wtest" ) 2>/dev/null || return 1
  rm -f "$1/.wtest"
  return 0
}

DEST="${BASHNAV_DEST:-}"
if [ -n "$DEST" ]; then
  writable "$DEST" || die "$DEST is not writable."
else
  for d in "$HOME/Documents" "$HOME/bin" "$HOME" .; do
    if writable "$d"; then DEST="$d"; break; fi
  done
  [ -n "$DEST" ] || die "found nowhere writable. Set BASHNAV_DEST and try again."
fi
say "  Installing into $DEST"
say ""

# ---------------------------------------------------------------------
#  2. The tools themselves.
# ---------------------------------------------------------------------
