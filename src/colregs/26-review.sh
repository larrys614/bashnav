# ---------------------------------------------------------------------
#  Review: the claims a test cannot check, put to a person one at a
#  time.  Entirely local.  Nothing here opens a socket; submitting
#  means the program prints a link and YOU open it, so there is no
#  credential in this file to leak and no service for anyone to run.
# ---------------------------------------------------------------------
rv_file() { echo "$COLREGS_HOME/review.tsv"; }
rv_save() {   # key state note
  mkdir -p "$COLREGS_HOME"
  n=$(printf '%s' "$3" | tr '\t\n' '  ')
  printf '%s\t%s\t%s\n' "$1" "$2" "$n" >> "$(rv_file)"
}
rv_ask_note() {   # $1 = the question to ask
  printf "  %s (one line, return to skip): " "$1"
  IFS= read -r RVNOTE || RVNOTE=""
}
#  THE VERDICT IS SAVED BEFORE THE NOTE IS ASKED FOR, and this is not a
#  tidiness point.  Larry marked three claims in the mot section -- two
#  wrong, one with a comment -- and none of the three was in review.tsv
#  afterwards.  The file's last write was hours earlier, at the end of
#  the encounter section.
#
#  The sequence that loses them:
#
#    1  he presses f.  The verdict is now known.
#    2  rv_ask_note prints its prompt and `read` BLOCKS.
#    3  he reaches for the mouse to copy the screen into a chat, and
#       presses ctrl-c to get his shell back.
#    4  SIGINT's default disposition kills the script while read is
#       blocked, so rv_save on the same line never runs.
#
#  Reproduced with a fifo held open so `read` genuinely blocks: the mark
#  is gone.  The note is optional and the verdict is not, so the verdict
#  is written the instant the key is pressed.  If a note follows, a
#  SECOND row is appended for the same key, and every reader of this file
#  -- rv_load, rv_list, rv_next -- takes the last row for a key, so the
#  later row supersedes the earlier one.
#
#  The cost is a duplicate line per annotated claim.  The alternative is
#  losing a reviewer's judgement because he wanted to copy the screen.
rv_one() {   # $1 = key ; returns 1 to stop
  eng -v cmd=rvshow -v key="$1" || return 1
  printf "  %s  [r] right   [f] wrong, say why   [c] right, but a comment\n" "$1"
  printf "  [return] skip   [q] stop : "
  IFS= read -r v || return 1
  RVSTEP=answered
  case "$v" in
    r|R) rv_save "$1" ok "" ;;
    f|F) rv_save "$1" flag ""
         rv_ask_note "What is wrong with it?"
         [ -n "$RVNOTE" ] && rv_save "$1" flag "$RVNOTE" ;;
    c|C) rv_save "$1" ok ""
         rv_ask_note "What is the comment?"
         [ -n "$RVNOTE" ] && rv_save "$1" ok "$RVNOTE" ;;
    q|Q|x|X) return 1 ;;
    *) RVSTEP=skipped ;;
  esac
  return 0
}
rv_run() {   # $1 = section, or empty for "carry on from where I left off"
  RVSKIP=""
  if [ -n "$1" ]; then
    #  NOT  while read k ... done < keyfile :  that redirects the loop
    #  body's stdin to the key file, so every prompt inside rv_one reads
    #  a KEY instead of the answer the person typed, and the whole
    #  section scrolls past unanswered. The keys are plain tokens, so
    #  word-splitting a single variable is safe and leaves stdin alone.
    rvkeys=$(eng -v cmd=rvkeys -v which="$1")
    for k in $rvkeys; do
      rv_one "$k" || break
    done
  else
    #  rv_next returns the first claim with no row in the file, and
    #  [return] deliberately writes no row -- so skipping re-offered the
    #  SAME claim, for ever.  The keys skipped in this run are carried
    #  along and stepped over; nothing is written for them, so a later
    #  run offers them again, which is what skipping means.
    while :; do
      k=$(eng -v cmd=rvnext -v rfile="$(rv_file)" -v skips="$RVSKIP")
      [ -z "$k" ] && { echo; echo "  Every claim has been looked at.  Thank you."; echo; break; }
      rv_one "$k" || break
      [ "$RVSTEP" = skipped ] && RVSKIP="$RVSKIP $k"
    done
  fi
}
rv_submit() {
  RV=$(rv_file)
  if [ ! -s "$RV" ]; then echo; echo "  Nothing reviewed yet."; echo; return; fi
  printf '%s\n' \
    '' \
    '  SENDING IT BACK' \
    '  ---------------------------------------------------------------' \
    '  This builds a report and prints a link that opens a GitHub issue' \
    '  with the report already in it.  The program does not send it -' \
    '  you do, by opening the link.  Nothing leaves this machine until' \
    '  you press return in your browser.' \
    '' \
    '  GitHub signs the issue with your account, so it is not anonymous' \
    '  and there is no email for anybody to collect.' \
    ''
  printf "  A name to put on it (return to leave it off): "; IFS= read -r who
  cr=""
  if [ -n "$who" ]; then
    printf "  Credit you in CONTRIBUTORS if a correction lands? [y/N] "
    IFS= read -r c
    case "$c" in y|Y) cr=yes ;; *) cr=no ;; esac
  fi
  dr=""
  if [ "$stry" -gt 0 ] 2>/dev/null; then
    printf "  Include your drill record (%s of %s)? [y/N] " "$sok" "$stry"
    IFS= read -r c
    case "$c" in y|Y) dr="$sok of $stry" ;; esac
  fi
  B="$COLREGS_HOME/review-report.md"
  eng -v cmd=rvreport -v rfile="$RV" -v rvver="$COLREGS_VERSION" \
      -v rvwho="$who" -v rvcredit="$cr" -v rvdrill="$dr" > "$B"
  U=$(eng -v cmd=rvurl -v rfile="$RV" -v rbody="$B" -v rvrepo="$GH_USER")
  n=$(printf '%s' "$U" | wc -c | tr -d ' ')
  echo
  if [ "$n" -lt 7000 ]; then
    echo "  Open this, check it reads the way you meant, and submit:"
    echo
    echo "$U"
    echo
    echo "  If that link says the page could not be found, the repository"
    echo "  is not published yet - nothing you did is wrong, and nothing"
    echo "  has been lost. The report is a file on this machine either"
    echo "  way, and you can send it whenever the repository is up."
  else
    #  Too long for a URL. Say so plainly rather than silently truncating
    #  somebody's careful work.
    echo "  Your review is too long to fit in a link ($n characters)."
    echo "  It is written out here instead:"
    echo
    echo "    $B"
    echo
    echo "  Open a new issue and paste or attach that file:"
    echo
    echo "    https://github.com/${GH_USER}/bashnav/issues/new"
  fi
  echo
  echo "  The report is also saved at $B"
  echo
}
review_menu() {
  while :; do
    printf '%s\n' \
      '' \
      '  REVIEW -- help make it right' \
      '' \
      '  The test suite proves the program works. It cannot prove that what' \
      '  it says about the rules is true. That needs somebody with the' \
      '  Convention open, going through the claims one at a time.' \
      '' \
      '    1  Carry on from where I left off' \
      '    2  Encounter verdicts        who gives way, and what to do' \
      '    3  Give-way calls from her lights' \
      '    4  The light tables' \
      '    5  Rules lesson answers      6  Sound signals      7  Day shapes' \
      '    8  What I have answered so far' \
      '    9  Send it back' \
      '' \
      '    x  back'
    printf "  > "; IFS= read -r c || return 0
    case "$c" in
      1) rv_run "" ;;
      2) rv_run enc ;;  3) rv_run mot ;;  4) rv_run lig ;;
      5) rv_run les ;;  6) rv_run snd ;;  7) rv_run shp ;;
      8) eng -v cmd=rvlist -v rfile="$(rv_file)" ;;
      9) rv_submit ;;
      x|X|q|Q|"") return 0 ;;
      *) echo "  ?" ;;
    esac
  done
}
