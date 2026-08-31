# ---------------------------------------------------------------------
#  Where a tool keeps its engine, its config and your log.
#
#  ON iOS YOU CANNOT WRITE IN $HOME.  a-Shell's own README: "In iOS, you
#  cannot write in the ~ directory, only in ~/Documents/, ~/Library/ and
#  ~/tmp."  $HOME there is the app's data container --
#  /private/var/mobile/Containers/Data/Application/<uuid> -- and mkdir
#  in it is refused.
#
#  Every tool in this suite defaulted to $HOME/.<tool>, so not one of
#  them would start on an iPad: the platform the whole project exists
#  for.  It printed "cannot create /private/var/mobile/Containers/..."
#  and stopped.  Nobody noticed because every machine the tests run on
#  has a writable $HOME.
#
#  So: use the first place we can actually create AND write in.  $HOME
#  is tried first, so nothing changes on macOS, Linux, the BSDs or
#  Termux.  ~/Documents is what a-Shell gives you.
# ---------------------------------------------------------------------
bn_home() {                       # bn_home <dotfolder>  ->  prints path
  for bn_h_base in "$HOME" "$HOME/Documents" "$HOME/Library"; do
    [ -n "$bn_h_base" ] || continue
    bn_h_dir="$bn_h_base/$1"
    #  The write probe MUST sit inside its own subshell.  Twice over:
    #  a failing redirection is set up before the 2>/dev/null that was
    #  meant to silence it, so the error reaches the terminal anyway;
    #  and ":" is a POSIX *special* built-in, so under dash a
    #  redirection error on it makes the whole shell EXIT.  The tool
    #  would print "cannot create ..." and vanish.  ( ) contains both.
    if mkdir -p "$bn_h_dir" 2>/dev/null && ( : > "$bn_h_dir/.wtest" ) 2>/dev/null
    then
      rm -f "$bn_h_dir/.wtest"
      printf '%s\n' "$bn_h_dir"
      return 0
    fi
  done
  #  Nothing was writable.  Name the path the user expects, so the
  #  caller's own error message is one they can act on, and fail there.
  printf '%s\n' "$HOME/$1"
  return 1
}

# ---------------------------------------------------------------------
#  Unpacking the awk engines.
#
#  These used to be written with a heredoc:
#
#      cat > "$ENGINE" <<'__ENGINE__'
#      ...the whole engine...
#      __ENGINE__
#
#  a-Shell -- the iPad terminal this project exists for -- DOES NOT
#  DELIVER A HEREDOC.  Larry ran the three-line test on the device:
#
#      cat <<'M'          hangs, and every Return comes back blank,
#      hello              because cat falls through to the terminal
#      M
#
#  With the output redirected to a file, cat instead sees end of input
#  straight away and writes NOTHING.  So every engine on that iPad was
#  ZERO BYTES -- confirmed: wc -c ~/Documents/.celnav/*.awk = 0.  The
#  tools could never have computed anything; the menus simply hung
#  first, so that is where it was noticed.
#
#  So the payloads now live at the END of each tool, after "exit 0"
#  where the shell never reads them, between markers, and awk lifts
#  them out.  No heredoc, and awk is already a hard requirement.
#
#  And the result is CHECKED FOR SIZE.  A zero-byte engine must be a
#  loud failure at install time, not a strange awk error hours later.
# ---------------------------------------------------------------------
bn_self() {
  #  The path to this script.  $0 is it in every normal case; when the
  #  script was found on PATH by name, ask the shell where it is.
  if [ -f "$0" ]; then printf '%s\n' "$0"; return 0; fi
  bn_s_p=$(command -v "$0" 2>/dev/null)
  if [ -n "$bn_s_p" ] && [ -f "$bn_s_p" ]; then printf '%s\n' "$bn_s_p"; return 0; fi
  return 1
}
#  bn_unpack <TAG> <destination>
bn_unpack() {
  bn_u_self=$(bn_self) || {
    echo "${BN_TOOL:-bashnav}: cannot find my own file to unpack from" >&2; return 1; }
  [ -n "${AWK:-}" ] || {
    echo "${BN_TOOL:-bashnav}: no awk was chosen before unpacking" >&2; return 1; }
  [ -r "$bn_u_self" ] || {
    echo "${BN_TOOL:-bashnav}: cannot read $bn_u_self" >&2; return 1; }
  #  </dev/null is the house rule and it is not decoration: awk with no
  #  readable file argument reads STDIN and sits there forever.  On a
  #  terminal that is a hang with no message; on an iPad, where there is
  #  no Ctrl and no Esc, it ends the session.  See docs/ARCHITECTURE.md.
  $AWK -v s="#__BN_START_$1__" -v e="#__BN_END_$1__" '
    $0==e { f=0 } f { print } $0==s { f=1 }' "$bn_u_self" > "$2" 2>/dev/null </dev/null || {
    echo "${BN_TOOL:-bashnav}: could not write $2" >&2; return 1; }
  if [ ! -s "$2" ]; then
    echo "${BN_TOOL:-bashnav}: unpacked $1 and got an empty file." >&2
    echo "  Looked in: $bn_u_self" >&2
    echo "  The file is probably truncated, or awk ($AWK) cannot read it." >&2
    rm -f "$2"
    return 1
  fi
  return 0
}
