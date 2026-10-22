
# ---- command implementations ---------------------------------------
do_fix() {
  if [ ! -s "$SIGHTS" ]; then echo; echo "  No sights in the log.  Enter one first."; echo; return; fi
  ft="$fixtime"
  [ -n "$1" ] && ft="$1"
  engine -v cmd=reduce -v sfile="$SIGHTS" -v drlat="$drlat" -v drlon="$drlon" \
         -v course="$course" -v speed="$speed" -v fixtime="$ft"
}
do_plan() {
  u="$1"; [ -z "$u" ] && u=$(utcnow)
  engine -v cmd=plan -v utc="$u" -v drlat="$drlat" -v drlon="$drlon"
}
do_almanac() {
  u="$1"; [ -z "$u" ] && u=$(utcnow)
  b="$2"; [ -z "$b" ] && b="sun,moon,venus,mars,jupiter,saturn"
  engine -v cmd=almanac -v utc="$u" -v bodies="$b"
}
do_noon() {
  u="$1"; [ -z "$u" ] && u=$(utctoday)
  engine -v cmd=noon -v utc="$u" -v drlat="$drlat" -v drlon="$drlon" \
         -v hs="$2" -v limb="$3" -v ie="$ie" -v heye="$heye" \
         -v temp="$temp" -v press="$press"
}
noon_mode() {
  ask "Date, YYYY-MM-DD (blank = today)" ""; nd="$ANS"
  [ -z "$nd" ] && nd=$(utctoday)
  do_noon "$nd" "" ""
  ask "Hs at the maximum (blank = just the prediction)" ""; nh="$ANS"
  if [ -n "$nh" ]; then
    ask "Limb, L or U" "L"; nl="$ANS"
    do_noon "$nd" "$nh" "$nl"
  fi
  pause
}
do_polaris() {
  u="$1"; [ -z "$u" ] && u=$(utcnow)
  engine -v cmd=polaris -v utc="$u" -v drlon="$drlon" \
         -v hs="$2" -v ie="$ie" -v heye="$heye" -v temp="$temp" -v press="$press"
}
polaris_mode() {
  ask "UT, YYYY-MM-DD HH:MM:SS (blank = now)" ""; pu="$ANS"
  [ -z "$pu" ] && pu=$(utcnow)
  do_polaris "$pu" ""
  ask "Hs of Polaris (blank = just the correction)" ""; ph="$ANS"
  [ -n "$ph" ] && do_polaris "$pu" "$ph"
  pause
}
do_compass() {
  engine -v cmd=compass -v utc="$1" -v drlat="$drlat" -v drlon="$drlon" \
         -v body="$2" -v cbrg="$3" -v variation="$4"
}
do_devcard() {
  engine -v cmd=devcard -v utc="$1" -v drlat="$drlat" -v drlon="$drlon" \
         -v body="$2" -v variation="$3" -v swing="$4"
}
devcard_mode() {
  #  A SWING IS TAKEN ONE HEADING AT A TIME, so it is collected one
  #  heading at a time.  Each observation keeps its own time: a swing
  #  takes twenty minutes and the sun moves about five degrees of azimuth
  #  in that time, which would otherwise land in the card looking exactly
  #  like deviation.
  ask "Date of the swing, UT" "$(utctoday)"; dcd="$ANS"
  ask "Body" "sun"; dcb="$ANS"
  ask "Variation from the chart (E +, W -)" ""; dcv="$ANS"
  echo "  Enter each observation. A blank ship's head ends the swing."
  dcs=""
  while : ; do
    ask "Ship's head (blank = done)" ""; dch="$ANS"
    [ -z "$dch" ] && break
    ask "  Time UT (hh:mm:ss)" ""; dct="$ANS"
    ask "  Compass bearing of $dcb" ""; dcr="$ANS"
    if [ -z "$dct" ] || [ -z "$dcr" ]; then
      echo "  skipped -- that heading needs a time and a bearing"
      continue
    fi
    dcs="${dcs}${dcs:+; }${dch},${dct},${dcr}"
  done
  if [ -n "$dcs" ]; then do_devcard "$dcd 00:00:00" "$dcb" "$dcv" "$dcs"
  else echo "  nothing swung"; fi
  pause
}
do_stars() { engine -v cmd=stars -v utc="$1"; }
do_selftest() { engine -v cmd=selftest; }

# ---- interactive: enter a sight ------------------------------------
ask() {  # ask "prompt" "default" -> sets ANS
  if [ -n "$2" ]; then printf "  %s [%s]: " "$1" "$2"; else printf "  %s: " "$1"; fi
  IFS= read -r ANS
  [ -z "$ANS" ] && ANS="$2"
}
enter_sight() {
  echo
  echo "  ---- new sight ----------------------------------------------"
  ask "UT date (YYYY-MM-DD)" "$(utctoday)"; sd="$ANS"
  ask "UT time (HHMMSS or HH:MM:SS)" ""; st=$(fixtimefmt "$ANS")
  [ -z "$st" ] && { echo "  no time given - sight discarded"; return; }
  ask "Body (name, star number, or ? for list)" "Sun"; sb="$ANS"
  if [ "$sb" = "?" ]; then do_stars; ask "Body" "Sun"; sb="$ANS"; fi
  case "$(echo "$sb" | tr 'A-Z' 'a-z')" in
    sun|moon) ask "Limb (L lower / U upper)" "L"; sl=$(echo "$ANS"|tr 'a-z' 'A-Z') ;;
    *) sl="C" ;;
  esac
  ask "Hs sextant altitude (DD MM.M)" ""; sh="$ANS"
  [ -z "$sh" ] && { echo "  no altitude given - sight discarded"; return; }
  ask "Index error, arcmin (+ = on the arc)" "$ie"; si="$ANS"
  ask "Height of eye, metres" "$heye"; se="$ANS"
  ask "Label (optional)" ""; sx="$ANS"
  add_sight "$sd $st" "$sb" "$sl" "$sh" "$si" "$se" "$temp" "$press" "$sx"
  echo "  sight recorded."
  engine -v cmd=almanac -v utc="$sd $st" -v bodies="$sb"
}
set_dr() {
  echo
  ask "DR latitude  (e.g. 35 10.4 N)" "$drlat"; drlat="$ANS"
  ask "DR longitude (e.g. 040 20.1 W)" "$drlon"; drlon="$ANS"
  ask "Course made good, degrees true" "$course"; course="$ANS"
  ask "Speed over ground, knots" "$speed"; speed="$ANS"
  save_conf
  echo "  DR set."
}
set_opts() {
  echo
  ask "Height of eye, metres" "$heye"; heye="$ANS"
  ask "Standard index error, arcmin" "$ie"; ie="$ANS"
  ask "Air temperature, deg C" "$temp"; temp="$ANS"
  ask "Pressure, millibars" "$press"; press="$ANS"
  save_conf
  echo "  settings saved."
}
log_menu() {
  while :; do
    echo; list_sights; echo
    echo "  d N = delete sight N     c = clear all     x = back"
    printf "  > "; IFS= read -r a
    case "$a" in
      d\ *) del_sight "${a#d }" ;;
      c) : > "$SIGHTS"; echo "  log cleared" ;;
      x|"") return ;;
    esac
  done
}
help_text() {
  printf '%s\n' \
    '' \
    '  CELNAV -- offline celestial navigation' \
    '' \
    '  Everything is computed from first principles: the almanac is built in,' \
    '  so there is nothing to download and nothing expires.' \
    '' \
    '  THE WORKING CYCLE' \
    '    1. Set your DR position, course and speed (menu 6).' \
    '    2. Before twilight, run sight planning (menu 3) to see which bodies' \
    '       are up, how high, and which three give the best cut.' \
    '    3. Shoot your sights and enter each one (menu 1) with the UT time to' \
    '       the second.  Time matters more than anything: 4 seconds of error' \
    '       is about 1 mile of longitude.' \
    '    4. Reduce and plot (menu 2).  You get the full working for each' \
    '       sight, the least-squares fix, the residuals, and the plot.' \
    '    5. Clear the log (menu 7) before the next round of sights.' \
    '' \
    '  ANGLE FORMATS' \
    '    Latitude    35 10.4 N   or  -35.1733' \
    '    Longitude   040 20.1 W  or  040:20.1W' \
    '    Altitude    32 14.6     (degrees and decimal minutes)' \
    '' \
    '  ON THE RUN' \
    '    Set course and speed and every LOP is advanced to the fix time for' \
    '    you, so a sun-run-sun or a spread of sights over an hour still gives' \
    '    one fix.  The fix time defaults to the last sight in the log.' \
    '' \
    '  COMMAND LINE (for scripting or a quick answer)' \
    '' \
    '    Working' \
    '      celnav plan  [ "YYYY-MM-DD HH:MM:SS" ]   twilight, what is up, best three' \
    '      celnav alm   [ "UT" ] [ body,body,... ]  GHA, Dec, SD, HP' \
    '      celnav sight "UT" body limb Hs [ie] [heye]    record one sight' \
    '      celnav fix   [ "UT of fix" ]             reduce the log and plot' \
    '      celnav noon  [ "YYYY-MM-DD" ] [ Hs ] [ limb ]  latitude at LAN' \
    '      celnav polaris [ "UT" ] [ Hs ]           latitude from Polaris' \
    '      celnav compass "UT" body <bearing> [variation]' \
    '      celnav devcard "DATE" body <variation> "hdg,time,brg; ..."' \
    '      celnav table <lat> <dec> [LHA]           a Pub. 249 page, generated' \
    '      celnav current "DRlat" "DRlon" "FIXlat" "FIXlon" <hours>' \
    '                                               set and drift' \
    '      celnav ep "lat" "lon" <crs> <spd> <hrs> [set] [drift]' \
    '                                               the DR run, and the EP' \
    '                                               a swing, as a deviation card' \
    '      celnav stars [ "UT" ]                    the 57 stars plus Polaris' \
    '      celnav dr <lat> <lon> [course] [speed]   set the DR' \
    '      celnav log | clear                       list or empty the sight log' \
    '' \
    '    Learning' \
    '      celnav learn                             the training menu' \
    '      celnav lesson <code>                     one lesson, e.g. R3' \
    '      celnav walk                              a real sight, step by step' \
    '      celnav drill [corr|alm|red|int|full|fix] one marked drill' \
    '      celnav sandbox                           the what-if triangle' \
    '      celnav syllabus                          the lesson list and progress' \
    '' \
    '    Setup and checking' \
    '      celnav doctor                            check awk, clock, data folder' \
    '      celnav test                              the self test on its own' \
    '      celnav day | night | plain               colour mode' \
    '      celnav where | version | reinstall | help' \
    ''
}
banner() {
  echo
  echo "  ==============================================================="
  echo "   CELNAV $CELNAV_VERSION   celestial navigation, no internet needed"
  echo "  ==============================================================="
  printf "   DR %s  %s      course %03.0f T   speed %s kn\n" "$drlat" "$drlon" "$course" "$speed"
  printf "   eye %s m   index error %s'   %s C  %s mb   sights logged: %s   [%s]\n" \
         "$heye" "$ie" "$temp" "$press" "$(nsights)" "$cmode"
  echo "  ---------------------------------------------------------------"
}
menu() {
  while :; do
    banner
    printf '%s\n' \
      '    1  Enter a sight              5  Compass check' \
      '    2  Reduce sights -> FIX       6  Set DR, course and speed' \
      '    3  Sight planning / stars     7  Sight log' \
      '    4  Almanac for a time         8  Sextant and weather settings' \
      '' \
      '    n  Noon sight                 latitude from the sun at its highest' \
      '    p  Polaris                    latitude from one star, any time of night' \
      '' \
      '    9  LEARN AND PRACTISE  -- lessons, drills, walkthrough, sandbox' \
      '' \
      '    s  Star list   t  Self test   d  Check setup   c  Colour' \
      '    a  About      h  Help       q  Quit'
    printf "  > "
    IFS= read -r c || exit 0
    case "$c" in
      1) enter_sight ;;
      2) printf "  Fix time (blank = time of last sight): "; IFS= read -r ft
         if [ -n "$ft" ]; then
           case "$ft" in *-*) ;; *) ft="$(utctoday) $(fixtimefmt "$ft")" ;; esac
         fi
         do_fix "$ft" ;;
      3) printf "  UT for planning (blank = now): "; IFS= read -r u
         if [ -n "$u" ]; then case "$u" in *-*) ;; *) u="$(utctoday) $(fixtimefmt "$u")" ;; esac; fi
         do_plan "$u" ;;
      4) printf "  UT (blank = now): "; IFS= read -r u
         if [ -n "$u" ]; then case "$u" in *-*) ;; *) u="$(utctoday) $(fixtimefmt "$u")" ;; esac; fi
         printf "  Bodies (blank = sun,moon,planets): "; IFS= read -r b
         do_almanac "$u" "$b" ;;
      5) printf "  1 single check, 2 swing the ship for a deviation card [1]: "
         IFS= read -r m
         if [ "$m" = "2" ]; then devcard_mode
         else
           printf "  UT (blank = now): "; IFS= read -r u; [ -z "$u" ] && u=$(utcnow)
           case "$u" in *-*) ;; *) u="$(utctoday) $(fixtimefmt "$u")" ;; esac
           printf "  Body: "; IFS= read -r b
           printf "  Compass bearing observed: "; IFS= read -r cb
           printf "  Variation from chart (E +, W -): "; IFS= read -r vr
           do_compass "$u" "$b" "$cb" "$vr"
         fi ;;
      6) set_dr ;;
      7) log_menu ;;
      8) set_opts ;;
      9) train_menu ;;
      n|N) noon_mode ;;
      p|P) polaris_mode ;;
      s|S) do_stars ;;
      t|T) do_selftest ;;
      d|D) doctor ;;
      c|C) printf "  day, night or plain? [%s] " "$cmode"; IFS= read -r v
           [ -n "$v" ] && set_colour "$v" ;;
      a|A) about_menu ;;
      h|H|\?) help_text ;;
      q|Q) unpaint; exit 0 ;;
      "") ;;
      *) echo "  ?" ;;
    esac
  done
}


# =====================================================================
#  Training mode
# =====================================================================
pause() { printf "  -- press return --"; IFS= read -r _junk; }

do_lesson() {
  teach -v cmd=t_lesson -v les="$1" || return 1
  printf "  Your answer (a/b/c, or return to skip): "; IFS= read -r av
  [ -z "$av" ] && return 0
  if teach -v cmd=t_check -v les="$1" -v ans="$av"; then mark_done "$1"; fi
}
learn_menu() {
  while :; do
    teach -v cmd=t_syllabus -v done="$lessons"
    printf "  Lesson code, n for the next one you have not done, or x to go back: "
    IFS= read -r a
    case "$a" in
      x|X|"") return ;;
      n|N)  nx=""
            for L in $(teach -v cmd=t_codes); do
              case ",$lessons," in *,"$L",*) ;; *) nx="$L"; break ;; esac
            done
            if [ -z "$nx" ]; then echo "  Every lesson done. Try the drills."; else do_lesson "$nx"; fi ;;
      *)    do_lesson "$(echo "$a" | tr 'a-z' 'A-Z')" ;;
    esac
  done
}
walk_mode() {
  s=1
  while [ "$s" -le 10 ]; do
    teach -v cmd=t_walk -v step="$s"
    printf "  return = next, b = back, x = leave: "; IFS= read -r a
    case "$a" in x|X) return ;; b|B) [ "$s" -gt 1 ] && s=$((s-1)) ;; *) s=$((s+1)) ;; esac
  done
  echo "  That is the whole method. The drills will let you do it yourself."
}
drill_one() {
  k="$1"; sd=$(newseed)
  teach -v cmd=t_drill -v kind="$k" -v seed="$sd" || return 1
  case "$k" in
    corr) printf "  Ho = "; IFS= read -r x1; x2="" ;;
    alm)  printf "  GHA = "; IFS= read -r x1; printf "  Dec (e.g. N21 14.3) = "; IFS= read -r x2 ;;
    red)  printf "  Hc = ";  IFS= read -r x1; printf "  Zn (degrees) = "; IFS= read -r x2 ;;
    int)  printf "  Intercept, + toward / - away, in nm = "; IFS= read -r x1; x2="" ;;
    full) printf "  Intercept, + toward / - away, nm = "; IFS= read -r x1; printf "  Zn (degrees) = "; IFS= read -r x2 ;;
    fix)  printf "  Fix latitude  = "; IFS= read -r x1; printf "  Fix longitude = "; IFS= read -r x2 ;;
  esac
  [ -z "$x1" ] && { echo "  skipped."; return 0; }
  dtry=$((dtry+1))
  if teach -v cmd=t_mark -v kind="$k" -v seed="$sd" -v a1="$x1" -v a2="$x2"; then dok=$((dok+1)); fi
  save_prog
}
drill_menu() {
  while :; do
    echo
    echo "  DRILLS                                     score so far: $dok of $dtry"
    echo "  ---------------------------------------------------------------"
    echo "   1  Sextant corrections      Hs to Ho"
    echo "   2  The almanac              time and body to GHA and Dec"
    echo "   3  Sight reduction          AP, GHA, Dec to Hc and Zn"
    echo "   4  The intercept            Ho and Hc to miles, toward or away"
    echo "   5  A complete sight         everything, end to end"
    echo "   6  A three-star fix         three LOPs to a position"
    echo "   m  Mixed - one of each, at random        r  reset the score"
    echo "   x  back"
    printf "  > "; IFS= read -r a
    case "$a" in
      1) drill_one corr ;; 2) drill_one alm ;; 3) drill_one red ;;
      4) drill_one int ;;  5) drill_one full ;; 6) drill_one fix ;;
      m|M) for k in corr alm red int full fix; do drill_one "$k"; done ;;
      r|R) dok=0; dtry=0; save_prog; echo "  score reset" ;;
      x|X|"") return ;;
    esac
  done
}
sandbox_mode() {
  sl=35; sd=20; sh=310
  while :; do
    teach -v cmd=t_sandbox -v slat="$sl" -v sdec="$sd" -v slha="$sh"
    echo "   l = latitude    d = declination    h = LHA    x = leave"
    printf "  change what? "; IFS= read -r a
    case "$a" in
      l|L) printf "  latitude (-90 to 90, north +): "; IFS= read -r v; [ -n "$v" ] && sl="$v" ;;
      d|D) printf "  declination (-90 to 90): "; IFS= read -r v; [ -n "$v" ] && sd="$v" ;;
      h|H) printf "  LHA (0 to 360): "; IFS= read -r v; [ -n "$v" ] && sh="$v" ;;
      x|X|"") return ;;
    esac
  done
}
#  THE PRELIMINARY MODULE AND ITS GATE.
#  Larry's instruction: "a preliminary module -- if you understand, skip;
#  else take it."  So the gate asks three questions first, and it asks
#  the module's OWN check questions rather than a separate set: what the
#  gate tests and what the module teaches then cannot drift apart.
#
#  Two of three offers the skip and names what was missed. Fewer opens
#  the module. Either way P1, P2 and P3 stay reachable by code from the
#  lesson list, because a gate that LOCKS a lesson is worse than no gate.
#  TABLES MODE.  Larry's spec, verbatim: "teach via HO 249 is an option
#  to select and will work the user step by step through -- but will also
#  in parallel calc w/o the books, and compare the input result from the
#  user to the internal."
#
#  So the engine reduces the same sight exactly while the reader works it
#  by the page, and the comparison at the end attributes the difference
#  rather than only reporting it: table rounding, the interpolation
#  applied backwards, a declination one degree off, an LHA one degree
#  off, or Zn read where the page prints Z.  Each has a size of its own.
tables_mode() {
  echo
  echo "  ==============================================================="
  echo "   PUB. 249 -- work a sight by the tables, with the answer beside it"
  echo "  ==============================================================="
  echo "  The pages are generated, not shipped: every entry is this app's"
  echo "  own triangle solved for whole degrees. Nothing is looked up."
  ask "UT of the sight (YYYY-MM-DD hh:mm:ss)" "$(utctoday) 10:00:00"; tm_u="$ANS"
  ask "Body" "sun"; tm_b="$ANS"
  ask "Hs (blank = just the arguments and the page)" ""; tm_hs="$ANS"
  tm_limb=L
  case "$tm_b" in sun|Sun|SUN|moon|Moon|MOON)
    ask "Limb, L or U" "L"; tm_limb="$ANS" ;; esac
  engine -v cmd=tabargs -v utc="$tm_u" -v body="$tm_b" \
         -v drlat="$drlat" -v drlon="$drlon" -v hs="$tm_hs" -v limb="$tm_limb" \
         -v ie="$ie" -v heye="$heye" -v temp="$temp" -v press="$press"
  pause
  engine -v cmd=tabpage -v utc="$tm_u" -v body="$tm_b" \
         -v drlat="$drlat" -v drlon="$drlon"
  echo "  Read Hc, d and Z off the row marked, interpolate Hc for the"
  echo "  minutes of declination, and enter what you get."
  ask "Your interpolated Hc (e.g. 23 07.8)" ""; tm_hc="$ANS"
  ask "Your Z, the angle off the page (blank to skip)" ""; tm_z="$ANS"
  if [ -n "$tm_hc" ] || [ -n "$tm_z" ]; then
    engine -v cmd=tabcheck -v utc="$tm_u" -v body="$tm_b" \
           -v drlat="$drlat" -v drlon="$drlon" -v hs="$tm_hs" -v limb="$tm_limb" \
           -v ie="$ie" -v heye="$heye" -v temp="$temp" -v press="$press" \
           -v uhc="$tm_hc" -v uz="$tm_z"
  fi
  pause
}
prelim_gate() {
  echo
  echo "  ==============================================================="
  echo "   BEFORE THE SIGHTS -- three questions first"
  echo "  ==============================================================="
  echo "  Everything in this program starts from a reckoned position. If"
  echo "  you already work in DR, EP and set and drift, these three will"
  echo "  take a minute and you can skip the module."
  pg_right=0; pg_missed=""
  for pg_q in P1 P3 P2; do
    teach -v cmd=t_ques -v les="$pg_q"
    printf "  Your answer (a/b/c): "; IFS= read -r pg_a
    if [ -n "$pg_a" ] && teach -v cmd=t_check -v les="$pg_q" -v ans="$pg_a"; then
      pg_right=$((pg_right+1))
    else
      pg_missed="${pg_missed}${pg_missed:+ }$pg_q"
    fi
  done
  echo "  ---------------------------------------------------------------"
  echo "  $pg_right of 3."
  if [ "$pg_right" -ge 2 ]; then
    if [ -n "$pg_missed" ]; then
      echo "  That is enough to skip the module. The one you missed is in $pg_missed,"
      echo "  which is worth ten minutes even so."
    else
      echo "  All three. Nothing in this module will be new to you."
    fi
    printf "  Take it anyway? (y/N): "; IFS= read -r pg_t
    case "$pg_t" in y|Y) ;; *) return 0 ;; esac
  else
    echo "  Worth taking. These three things are assumed by every lesson"
    echo "  after them, and a celestial fix is only as good as the"
    echo "  reckoning it was run from."
  fi
  for pg_q in P1 P2 P3; do do_lesson "$pg_q"; done
  echo "  That is the preliminary module. The sights start at F1."
  pause
}
train_menu() {
  while :; do
    load_prog
    ndone=$(printf '%s' "$lessons" | tr ',' '\n' | grep -c '[A-Z]')
    [ -n "$ndone" ] || ndone=0
    nles=$(teach -v cmd=t_codes | wc -w | tr -d ' ')
    echo
    echo "  ==============================================================="
    echo "   LEARN AND PRACTISE          lessons $ndone of $nles   drills $dok/$dtry"
    echo "  ==============================================================="
    echo "   1  Lessons              $nles of them, from first principles"
    echo "   2  Walkthrough          one real sight, explained line by line"
    echo "   3  Drills               problems with answers, marked"
    echo "   4  Sandbox              change one thing, watch the triangle move"
    echo
    echo "   p  Before the sights     DR, EP, set and drift -- skip it if you know it"
    echo "   t  Tables (Pub. 249)     work a sight by the book, answer alongside"
    echo
    echo "   x  back to the navigation menu"
    printf "  > "; IFS= read -r a
    case "$a" in
      1) learn_menu ;; 2) walk_mode ;; 3) drill_menu ;; 4) sandbox_mode ;;
      p|P) prelim_gate ;;
      t|T) tables_mode ;;
      x|X|"") return ;;
    esac
  done
}
set_colour() {
  case "$1" in
    day|night|plain) cmode="$1"; save_conf; paint
       echo "  colour mode: $cmode" ;;
    *) echo "  usage: day | night | plain" ;;
  esac
}

doctor() {
  echo
  echo "  CELNAV environment check"
  echo "  ---------------------------------------------------------------"
  printf "  shell            : %s\n" "${0##*/} (running under $(ps -p $$ -o comm= 2>/dev/null || echo sh))"
  printf "  awk in use       : %s\n" "$AWK"
  if awk_has_math "$AWK"; then echo "  awk maths        : OK (sin/cos/atan2/sqrt/log/exp present)"
  else echo "  awk maths        : MISSING -- install gawk (see message above)"; fi
  printf "  data directory   : %s" "$CELNAV_HOME"
  #  subshell: see src/common/05-home.sh for why this is not optional
  if mkdir -p "$CELNAV_HOME" 2>/dev/null && ( : > "$CELNAV_HOME/.wtest" ) 2>/dev/null; then
     rm -f "$CELNAV_HOME/.wtest"; echo "  (writable)"
  else echo "  (NOT WRITABLE)"; fi
  printf "  engine file      : %s" "$ENGINE"
  [ -f "$ENGINE" ] && echo "  (installed)" || echo "  (not yet written)"
  printf "  UTC clock        : %s\n" "$(utcnow)"
  echo "  ---------------------------------------------------------------"
  echo "  Set your watch against a known time source before you shoot."
  echo "  4 seconds of clock error is about 1 mile of longitude."
  echo
  do_selftest
}

# ---- entry point ----------------------------------------------------
pick_awk
install_engine
load_conf
load_prog
case "$1" in
  ""|menu) paint; menu ;;
  learn)   paint; train_menu ;;
  lesson)  shift; do_lesson "$(echo "${1:-F1}" | tr 'a-z' 'A-Z')" ;;
  walk)    paint; walk_mode ;;
  drill)   shift; if [ -n "$1" ]; then drill_one "$1"; else paint; drill_menu; fi ;;
  sandbox) paint; sandbox_mode ;;
  syllabus) teach -v cmd=t_syllabus -v done="$lessons" ;;
  day|night|plain) set_colour "$1" ;;
  plan)    shift; do_plan "$1" ;;
  alm|almanac) shift; do_almanac "$1" "$2" ;;
  sight)   shift
           [ $# -lt 4 ] && { echo "usage: celnav sight \"UT\" body limb Hs [ie] [heye]"; exit 2; }
           add_sight "$1" "$2" "$3" "$4" "${5:-$ie}" "${6:-$heye}" "$temp" "$press" ""
           echo "sight recorded (${1})" ;;
  fix)     shift; do_fix "$1" ;;
  noon)    shift; do_noon "$1" "$2" "$3" ;;
  polaris) shift; do_polaris "$1" "$2" ;;
  compass) shift; do_compass "$1" "$2" "$3" "$4" ;;
  table)   shift
           [ $# -lt 2 ] && { echo 'usage: celnav table <lat> <dec> [LHA]   (whole degrees)'; exit 2; }
           engine -v cmd=table -v tlat="$1" -v tdec="$2" -v tlha="$3" ;;
  current) shift
           [ $# -lt 5 ] && { echo 'usage: celnav current "DRlat" "DRlon" "FIXlat" "FIXlon" <hours>'; exit 2; }
           engine -v cmd=current -v drlat="$1" -v drlon="$2" \
                  -v fixlat="$3" -v fixlon="$4" -v hours="$5" ;;
  ep)      shift
           [ $# -lt 4 ] && { echo 'usage: celnav ep "lat" "lon" <course> <speed> <hours> [set] [drift]'; exit 2; }
           engine -v cmd=ep -v drlat="$1" -v drlon="$2" -v course="$3" \
                  -v speed="$4" -v hours="$5" -v cset="$6" -v cdrift="$7" ;;
  devcard) shift
           [ $# -lt 4 ] && { echo 'usage: celnav devcard "YYYY-MM-DD" body <variation> "hdg,hh:mm:ss,brg; ..."'; exit 2; }
           do_devcard "$1 00:00:00" "$2" "$3" "$4" ;;
  stars)   shift; do_stars "$1" ;;
  dr)      shift; drlat="$1"; drlon="$2"; [ -n "$3" ] && course="$3"; [ -n "$4" ] && speed="$4"
           save_conf; echo "DR set: $drlat $drlon  course $course  speed $speed" ;;
  log)     list_sights ;;
  clear)   : > "$SIGHTS"; echo "sight log cleared" ;;
  test|selftest) do_selftest ;;
  doctor|check) doctor ;;
  about)   paint; about_menu ;;
  reinstall) install_engine force; echo "engine rewritten: $ENGINE" ;;
  where)   echo "engine:  $ENGINE"; echo "sights:  $SIGHTS"; echo "config:  $CONF" ;;
  help|-h|--help) help_text ;;
  version|--version) echo "celnav $CELNAV_VERSION" ;;
  *) echo "celnav: there is no command '$1'."
     echo
     echo "  Working    plan  alm  sight  fix  compass  devcard  current  ep  table  stars  dr  log  clear"
     echo "  Learning   learn  lesson  walk  drill  sandbox  syllabus"
     echo "  Setup      day  night  plain  about  doctor  where  version"
     echo "  Setup      doctor  test  day  night  plain  where  version  reinstall"
     echo
     echo "  'celnav help' explains each of them."
     exit 2 ;;
esac
