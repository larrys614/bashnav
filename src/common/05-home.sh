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
    if mkdir -p "$bn_h_dir" 2>/dev/null && : > "$bn_h_dir/.wtest" 2>/dev/null
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
