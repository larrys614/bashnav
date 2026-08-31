#!/bin/sh
#  NO HEREDOC MAY FEED A COMMAND THAT PRINTS OR IS READ BACK.
#
#  a-Shell -- the iPad terminal this whole project exists for -- does not
#  deliver a heredoc to the command reading it.  Larry's test, on the
#  device:
#
#      cat <<'M'
#      hello
#      M
#
#  hangs.  cat sits on the terminal instead, and every Return the user
#  presses comes back as a blank line.  There is no Ctrl and no Esc on
#  the iPad's on-screen keyboard, so the only way out is to abandon the
#  window.
#
#  Every menu, help screen and About page in every tool was built with
#  "cat <<'M'".  bashnav was the exception -- its menu is printf -- and
#  bashnav was the only tool that worked on the iPad.  Three for three:
#  weather hung, celnav hung, bashnav ran.
#
#  So: display text is printf, never a heredoc.  A heredoc that WRITES A
#  FILE ("cat > \"\$ENGINE\" <<'TAG'") is left alone; that form is how
#  every tool carries its awk engine and it does work there.
set -e
cd "$(dirname "$0")/.."
bad=0

#  cat reading a heredoc with no file redirect on the same line, and the
#  command-substitution form, which hangs the same way.
for f in src/*/*.sh build.sh tests/*.sh; do
  [ -f "$f" ] || continue
  #  this file quotes the very patterns it looks for
  case "$f" in */heredoc-check.sh) continue ;; esac
  awk -v F="$f" '
    /<</ && /cat/ {
      line = $0
      sub(/#.*/, "", line)                    # ignore comments
      if(line !~ /cat/) next
      if(line ~ /cat[^<]*>[^&]/) next         # cat > file <<TAG  : writes a file, fine
      if(line ~ /cat[^<]*>&2[[:space:]]*<</){ printf "  %s:%d  cat >&2 <<  -- use printf ... >&2\n", F, FNR; bad++; next }
      if(line ~ /cat[[:space:]]*<</)         { printf "  %s:%d  cat <<  -- use printf\n", F, FNR; bad++; next }
      if(line ~ /\$\([[:space:]]*cat[[:space:]]*<</){ printf "  %s:%d  $(cat <<  -- use printf\n", F, FNR; bad++ }
    }
    END{ exit (bad>0) }
  ' "$f" || bad=1
done

#  And the built tools themselves, up to the payload marker.  bin/ is
#  generated, so this is belt and braces on build.sh -- but bin/ is what
#  actually ships, and it is what runs on the iPad.
for f in bin/*; do
  [ -f "$f" ] || continue
  awk -v F="$f" '
    /^exit 0$/ { exit }                       # payloads start here
    /<</ && /cat/ {
      line = $0; sub(/#.*/, "", line)
      if(line ~ /cat[[:space:]]*<</ || line ~ /cat[^<]*>&2[[:space:]]*<</){
        printf "  %s:%d  a built tool prints through a heredoc\n", F, FNR; bad++ }
    }
    END{ exit (bad>0) }
  ' "$f" || bad=1
done

[ "$bad" = 0 ] && echo "HEREDOC OK"
exit $bad
