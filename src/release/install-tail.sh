
for t in $TOOLS; do
  step "$t"
  fn=$(printf '%s' "$t" | tr -d '-')       # deck-log -> extract_decklog
  "extract_$fn" || die "could not write $DEST/$t"
  chmod +x "$DEST/$t" 2>/dev/null || die "could not make $DEST/$t executable"
  fine
done
say ""

# ---------------------------------------------------------------------
#  3. Prove they run, here, now.
#
#  An installer that reports success without executing anything is how
#  you find out on watch that it did not work.
# ---------------------------------------------------------------------
step "checking they run"
for t in celnav colregs tides deck-log weather; do
  v=$("$DEST/$t" version 2>&1) || die "$t would not run: $v"
  case "$v" in "$t "*) ;; *) die "$t answered '$v', which is not a version" ;; esac
done
fine

# ---------------------------------------------------------------------
#  4. The environment.
#
#  a-Shell runs ~/Documents/.profile when it opens a window, so this is
#  what makes plain "weather" work instead of "./weather".
#
#  The *_HOME variables are belt and braces: every tool already probes
#  for a writable folder by itself.  Setting them makes the answer
#  explicit and stops it moving if the files ever do.
# ---------------------------------------------------------------------
DATA="$DEST"
writable "$HOME" && DATA="$HOME"

BLOCK=$(cat <<BLK
# >>> bashnav >>>  managed block, safe to delete, rewritten on reinstall
export PATH="$DEST:\$PATH"
export CELNAV_HOME="$DATA/.celnav"
export COLREGS_HOME="$DATA/.colregs"
export TIDES_HOME="$DATA/.tides"
export DECKLOG_HOME="$DATA/.bashnav"
export WEATHER_HOME="$DATA/.bashnav"
# <<< bashnav <<<
BLK
)

PROF="$DEST/.profile"
step "environment in .profile"
if [ -f "$PROF" ]; then
  [ -f "$PROF.bashnav-backup" ] || cp "$PROF" "$PROF.bashnav-backup" 2>/dev/null
  #  Replace our block rather than appending a second one.  awk, not
  #  sed -i: a-Shell's sed may not have -i and this has to work there.
  awk '/^# >>> bashnav >>>/{skip=1} !skip{print} /^# <<< bashnav <<</{skip=0}' \
      "$PROF" > "$PROF.new" 2>/dev/null || die "could not rewrite $PROF"
  mv "$PROF.new" "$PROF" || die "could not replace $PROF"
fi
printf '%s\n' "$BLOCK" >> "$PROF" || die "could not write $PROF"
fine

step "loading it into this window"
# shellcheck disable=SC1090
. "$PROF" >/dev/null 2>&1 || true
case ":${PATH}:" in *":$DEST:"*) fine ;; *) printf 'not this window -- open a new one\n' ;; esac
say ""

# ---------------------------------------------------------------------
#  5. Home-screen icons.
#
#  A script cannot make one.  On iOS only the Shortcuts app can add to
#  the home screen, and only when a person does it.  What this can do
#  is put the command on the clipboard and open Shortcuts at the right
#  place, so it is a paste rather than typing on glass in a seaway.
# ---------------------------------------------------------------------
say "  -------------------------------------------------------------------"
say "  ICONS ON THE HOME SCREEN"
say ""
say "  No script can create one -- on iOS only you can, in Shortcuts."
say "  Five taps each, and this is the recipe:"
say ""
say "    1. Shortcuts app -> + -> search a-Shell -> Execute Command"
say "    2. Command:  cd $DEST; ./bashnav"
say "    3. Open the action's options and set it to run IN APP."
say "       NOT In Extension. The extension has no terminal, so a menu"
say "       has nothing to draw on and cannot read a keystroke."
say "    4. Name it, then Share -> Add to Home Screen, and pick an icon."
say ""
say "  One icon for the menu, or one each -- change the command to"
say "  ./bashnav weather, ./bashnav tides, and so on."
say ""
if command -v pbcopy >/dev/null 2>&1; then
  printf 'cd %s; ./bashnav' "$DEST" | pbcopy 2>/dev/null &&
    say "  The command for step 2 is on your clipboard. Paste it."
  say ""
fi
say "  When you are ready:   open shortcuts://"
say "  -------------------------------------------------------------------"
say ""
say "  Installed. In a new window, type:"
say ""
say "     bashnav          the menu"
say "     weather          or any tool by name"
say "     celnav doctor    checks your awk, your clock, your folders"
say ""
exit 0
