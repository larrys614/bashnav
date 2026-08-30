#!/bin/sh
# Bash Navigation Software -- the whole test suite.
# Runs under any POSIX shell. Set SHELLS and AWKS to widen the matrix.
set -e
cd "$(dirname "$0")/.."
#  Default to every shell and awk installed on this machine, not just
#  "sh" and "awk". A portability suite that only runs one combination by
#  default is a portability suite that finds nothing: two syntax errors
#  mawk rejects and gawk accepts sat in this repository until CI ran.
if [ -z "${SHELLS:-}" ]; then
  SHELLS=""
  for _s in sh dash bash ksh; do command -v "$_s" >/dev/null 2>&1 && SHELLS="$SHELLS $_s"; done
  [ -n "$SHELLS" ] || SHELLS=sh
fi
if [ -z "${AWKS:-}" ]; then
  AWKS=""
  for _a in awk gawk mawk; do command -v "$_a" >/dev/null 2>&1 && AWKS="$AWKS $_a"; done
  [ -n "$AWKS" ] || AWKS=awk
fi
fail=0
tmp=${TMPDIR:-/tmp}/bashnav-test.$$
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

say()  { printf '%s\n' "$*"; }
ok()   { printf '  ok    %s\n' "$*"; }
bad()  { printf '  FAIL  %s\n' "$*"; fail=$((fail+1)); }
check(){ if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (got '$3', want '$2')"; fi; }

./build.sh >/dev/null

say ""
say "syntax"
for f in bin/celnav bin/colregs; do
  if sh -n "$f" 2>/dev/null; then ok "$f parses"; else bad "$f parses"; fi
done

for SH in $SHELLS; do
 for AW in $AWKS; do
  say ""
  say "matrix: $SH + $AW"
  CH="$tmp/celnav-$SH-$AW"; CR="$tmp/colregs-$SH-$AW"
  #  The three files colregs loads together. mawk resolves called
  #  functions at parse time, so the engine alone no longer loads.
  CSRC="-f src/colregs/engine.awk -f src/colregs/contacts.awk -f src/colregs/review.awk"
  rm -rf "$CH" "$CR"

  # ---- celnav ------------------------------------------------------
  out=$(CELNAV_HOME="$CH" CELNAV_AWK="$AW" $SH ./bin/celnav test 2>&1 || true)
  case "$out" in *"ALL TESTS PASSED"*) ok "celnav self test" ;;
                 *) bad "celnav self test"; echo "$out" | tail -3 ;; esac

  CELNAV_HOME="$CH" CELNAV_AWK="$AW" $SH ./bin/celnav dr "35 00 N" "040 00 W" 0 0 >/dev/null
  CELNAV_HOME="$CH" CELNAV_AWK="$AW" $SH ./bin/celnav sight "2026-08-29 07:30:00" Dubhe     C "19 32.1" 1.5 3.0 >/dev/null
  CELNAV_HOME="$CH" CELNAV_AWK="$AW" $SH ./bin/celnav sight "2026-08-29 07:34:00" Bellatrix C "49 37.2" 1.5 3.0 >/dev/null
  CELNAV_HOME="$CH" CELNAV_AWK="$AW" $SH ./bin/celnav sight "2026-08-29 07:38:00" Markab    C "29 01.3" 1.5 3.0 >/dev/null
  fix=$(CELNAV_HOME="$CH" CELNAV_AWK="$AW" $SH ./bin/celnav fix | grep '  FIX' | sed 's/  */ /g')
  check "celnav known fix" " FIX 35 09.9'N 040 20.0'W" "$fix"

  n=$(CELNAV_HOME="$CH" CELNAV_AWK="$AW" $SH ./bin/celnav syllabus | grep -c '\[ \]')
  check "celnav 20 lessons listed" "20" "$n"
  for L in F1 F5 T3 S5 R1 R5; do
    n=$(printf '\n' | CELNAV_HOME="$CH" CELNAV_AWK="$AW" $SH ./bin/celnav lesson $L 2>&1 | grep -c '^  Q\.')
    [ "$n" = 1 ] || bad "celnav lesson $L has no question"
  done
  ok "celnav lessons render"
  for k in corr alm red int full fix; do
    o=$(CELNAV_HOME="$CH" CELNAV_AWK="$AW" $SH ./bin/celnav drill "$k" </dev/null 2>&1 | grep -c 'DRILL')
    [ "$o" -ge 1 ] || bad "celnav drill $k"
  done
  ok "celnav drills generate"
  # a drill and its marking must agree - this is what a non-reproducible
  # random generator would silently break
  # take the versions from the tools themselves, so a version bump never
  # silently breaks the suite
  CV=$(CELNAV_HOME="$CH" CELNAV_AWK="$AW" $SH ./bin/celnav version | awk '{print $2}')
  EN="$CH/engine-$CV.awk"; TE="$CH/teach-$CV.awk"
  for sd in 3 21 400 7777; do
    line=$($AW -f "$EN" -f "$TE" -v cmd=t_mark -v kind=red -v seed="$sd" -v a1=0 -v a2=0 </dev/null | grep '^  Hc = ')
    hc=$(echo "$line" | sed 's/^  Hc = //; s/  *Zn = .*//')
    zn=$(echo "$line" | sed 's/.*Zn = //; s/ T$//')
    if $AW -f "$EN" -f "$TE" -v cmd=t_mark -v kind=red -v seed="$sd" -v a1="$hc" -v a2="$zn" </dev/null >/dev/null 2>&1
    then :; else bad "celnav reduction drill seed $sd self-mark"; fi
    ho=$($AW -f "$EN" -f "$TE" -v cmd=t_mark -v kind=corr -v seed="$sd" -v a1=0 </dev/null | grep 'Correct Ho' | sed 's/.*is //; s/\.$//')
    if $AW -f "$EN" -f "$TE" -v cmd=t_mark -v kind=corr -v seed="$sd" -v a1="$ho" </dev/null >/dev/null 2>&1
    then :; else bad "celnav corrections drill seed $sd self-mark"; fi
  done
  ok "celnav drills mark their own answers correctly"

  # ---- colregs -----------------------------------------------------
  n=$(COLREGS_HOME="$CR" COLREGS_AWK="$AW" $SH ./bin/colregs reflights | grep -c '^  [a-z]')
  [ "$n" -ge 20 ] || bad "colregs lights reference short ($n)"
  ok "colregs lights reference"
  n=$(COLREGS_HOME="$CR" COLREGS_AWK="$AW" $SH ./bin/colregs refshapes | grep -c 'Rule')
  [ "$n" -ge 10 ] || bad "colregs shapes reference short ($n)"
  ok "colregs shapes reference"
  for th in -180 -90 -30 0 30 90 170; do
    o=$(COLREGS_HOME="$CR" COLREGS_AWK="$AW" $SH ./bin/colregs light power50p "$th" | grep -c 'WHAT DO YOU SEE')
    [ "$o" = 1 ] || bad "colregs light at bearing $th"
  done
  ok "colregs lights draw from every angle"
  n=$(COLREGS_HOME="$CR" COLREGS_AWK="$AW" $SH ./bin/colregs syllabus 2>/dev/null | grep -c '\[ \]' || true)
  o=$(printf '\n' | COLREGS_HOME="$CR" COLREGS_AWK="$AW" $SH ./bin/colregs lesson L9 2>&1 | grep -c '^  Q\.')
  check "colregs lesson L9 has a question" "1" "$o"

  RV=$(COLREGS_HOME="$CR" COLREGS_AWK="$AW" $SH ./bin/colregs version | awk '{print $2}')
  #  The tool always loads all three of its awk files together, so the
  #  tests must too. mawk resolves every called function at PARSE time,
  #  so engine.awk on its own does not even load under it once the
  #  engine dispatches into contacts.awk and review.awk. gawk only
  #  complains when such a function is actually called, which is why
  #  this passed locally and failed in CI.
  CE="$CR/engine-$RV.awk -f $CR/contacts-$RV.awk -f $CR/review-$RV.awk"
  # the lights quiz asks two questions and both must mark correctly
  for sd in 3 17 91 404 7; do
    r=$($AW -f $CE -v cmd=qlightm -v seed="$sd" -v ans=z -v ans2=z -v cmode=plain </dev/null || true)
    w1=$(echo "$r" | grep '^  Q1 ' | grep -o '[A-D] is right' | cut -c1 | tr 'A-D' 'a-d')
    w2=$(echo "$r" | grep '^  Q2 ' | grep -o '[A-D] is right' | cut -c1 | tr 'A-D' 'a-d')
    if $AW -f $CE -v cmd=qlightm -v seed="$sd" -v ans="$w1" -v ans2="$w2" -v cmode=plain </dev/null >/dev/null 2>&1
    then :; else bad "colregs lights quiz seed $sd self-mark (q1=$w1 q2=$w2)"; fi
  done
  ok "lights quiz marks both of its answers correctly"

  # every quiz must mark its own correct answer as correct
  for q in qshape qsound; do
    for sd in 3 17 91 404; do
      want=$($AW -f $CE -v cmd="${q}m" -v seed="$sd" -v ans=z </dev/null 2>&1 \
             | grep -o '^  [A-D] is right' | cut -c3 | tr 'A-D' 'a-d' || true)
      if $AW -f $CE -v cmd="${q}m" -v seed="$sd" -v ans="$want" </dev/null >/dev/null 2>&1
      then :; else bad "colregs $q seed $sd self-mark"; fi
    done
  done
  ok "colregs quizzes mark their own answers correctly"
  # a lights picture must have exactly one right answer among the four offered:
  # two vessels that look identical from that angle must never both appear
  if $AW -f $CE -v cmd=sigcheck </dev/null | grep -q "single right answer"
  then ok "lights questions have a single right answer"
  else bad "lights questions offer look-alike vessels"
       $AW -f $CE -v cmd=sigcheck </dev/null | head -4; fi
  for sd in 5 55 555; do
    want=$($AW -f $CE -v cmd=encm -v seed="$sd" -v ans=z </dev/null 2>&1 \
           | grep -o '^  [A-D] is right' | cut -c3 | tr 'A-D' 'a-d' || true)
    if $AW -f $CE -v cmd=encm -v seed="$sd" -v ans="$want" </dev/null >/dev/null 2>&1
    then :; else bad "colregs encounter seed $sd self-mark"; fi
  done
  ok "colregs encounters mark their own answers correctly"

  # ---- collision-avoidance scenarios -------------------------------
  for sd in 2 9 44 101 3030; do
    o=$($AW -f $CE -v cmd=scen -v seed="$sd" -v cmode=plain </dev/null | grep -c "COLLISION AVOIDANCE")
    [ "$o" = 1 ] || bad "scenario seed $sd did not generate"
  done
  ok "scenarios generate"
  # and each must mark its own three correct answers as correct
  for sd in 2 9 44 101 3030; do
    r=$($AW -f $CE -v cmd=scenm -v seed="$sd" -v a1=z -v a2=z -v a3=z -v cmode=plain </dev/null || true)
    k1=$(echo "$r" | grep '^  Q1' | sed 's/.*the answer is //' | tr 'A-Z' 'a-z')
    k2=$(echo "$r" | grep '^  Q2' | sed 's/.*the answer is //' | tr 'A-Z' 'a-z')
    k3=$(echo "$r" | grep '^  Q3' | sed 's/.*the answer is //' | tr 'A-Z' 'a-z')
    if $AW -f $CE -v cmd=scenm -v seed="$sd" -v a1="$k1" -v a2="$k2" -v a3="$k3" -v cmode=plain </dev/null >/dev/null 2>&1
    then :; else bad "scenario seed $sd self-mark (a1=$k1 a2=$k2 a3=$k3)"; fi
  done
  ok "scenarios mark their own answers correctly"
  # the replay must end by itself rather than run for ever
  for sd in 2 44; do
    ended=0
    for tm in 12 24 36 48 60 72 84 96; do
      $AW -f $CE -v cmd=scenframe -v seed="$sd" -v ans=a -v tmin="$tm" -v cmode=plain </dev/null >/dev/null 2>&1 || rc=$?
      rc=${rc:-0}
      if [ "$rc" -eq 3 ]; then ended=1; break; fi
      rc=0
    done
    [ "$ended" = 1 ] || bad "scenario seed $sd replay never reached its end"
  done
  ok "scenario replays terminate"
  n=$(COLREGS_HOME="$CR" COLREGS_AWK="$AW" $SH ./bin/colregs colours | grep -c "COLOUR CHECK")
  check "colregs colour check runs" "1" "$n"

  # ---- no stray escape sequences when output is not a terminal -----
  e=$(COLREGS_HOME="$CR" COLREGS_AWK="$AW" $SH ./bin/colregs light ram 40 | cat -v | grep -c '\^\[' || true)
  check "colregs is clean when piped" "0" "$e"
  e=$(CELNAV_HOME="$CH" CELNAV_AWK="$AW" $SH ./bin/celnav syllabus | cat -v | grep -c '\^\[' || true)
  check "celnav is clean when piped" "0" "$e"

  # ---- and colour when it IS a terminal ----------------------------
  #  The mirror of the test above, and the one that matters: colregs
  #  once decided "am I on a terminal?" inside a command substitution,
  #  where stdout is a pipe by definition, so the answer was always no
  #  and no terminal ever got colour.  Both halves have to be tested.
  if command -v script >/dev/null 2>&1 && script -qec true /dev/null >/dev/null 2>&1; then
    e=$(COLREGS_HOME="$CR" COLREGS_AWK="$AW" script -qec "$SH ./bin/colregs light ram 40" /dev/null 2>/dev/null | cat -v | grep -c '\^\[' || true)
    [ "$e" -gt 0 ] && ok "colregs has colour on a terminal" || bad "colregs has no colour on a terminal"
    e=$(CELNAV_HOME="$CH" CELNAV_AWK="$AW" script -qec "$SH ./bin/celnav plan '2026-08-29 20:00'" /dev/null 2>/dev/null | cat -v | grep -c '\^\[' || true)
    [ "$e" -gt 0 ] && ok "celnav has colour on a terminal" || bad "celnav has no colour on a terminal"
  else
    ok "colour-on-a-terminal test skipped (no usable script(1))"
  fi
  #  A grep is not a substitute for the run above, but it holds on the
  #  platforms where script(1) is missing or takes different arguments.
  for f in ./bin/colregs ./bin/celnav; do
    if grep -q 'cmode_now() {.*\[ -t 1 \]' "$f"; then
      bad "$f tests -t 1 inside cmode_now, which runs in a substitution"
    fi
  done
  ok "tty is detected at the top level, not inside a substitution"

  # ---- lights on a yard are drawn on the same mast as their partner
  #  The three greens of a mine clearance vessel once had different
  #  fore-and-aft positions, which threw the two yard lights off to one
  #  side of the mast, where nothing could account for them. The test:
  #  the masthead green must sit BETWEEN the two yard greens, at every
  #  angle from which all three are seen.
  bad_a=""
  for a in 0 30 60 90 120 150 180 210 240 270 300 330 45 135 225 315; do
    r=$($AW $CSRC -v cmd=light -v key=mineclear -v th=$a -v cmode=plain </dev/null \
        | $AW '
          /G[-:]+G/ { yl=index($0,"G"); yr=length($0); while(substr($0,yr,1)!="G") yr--; got=1 }
          !yard && /^ *G *$/ { mast=index($0,"G") }
          END{ if(!got){ print "noyard"; exit }
               if(mast<=yl || mast>=yr) print "off"; else print "ok" }')
    #  Seen from dead abeam the yard is end-on: the two lights really are
    #  in line, one behind the other, so there is no spar to draw.
    case "$a" in 90|270) [ "$r" = noyard ] || bad_a="$bad_a $a(yard-edge-on:$r)" ;;
                 *)      [ "$r" = ok ]     || bad_a="$bad_a $a($r)" ;;
    esac
  done
  [ -z "$bad_a" ] && ok "mine clearance greens hang on one yard, mast between them" \
                  || bad "mine clearance greens off their mast at:$bad_a"

  # ---- about, and the licence it claims ----------------------------
  for t in celnav colregs; do
    a=$(COLREGS_HOME="$CR" CELNAV_HOME="$CH" COLREGS_AWK="$AW" CELNAV_AWK="$AW" \
        printf '1\n2\n3\n4\n5\n6\nx\n' | $SH ./bin/$t about 2>/dev/null)
    for want in "WHY THIS EXISTS" "HOW IT WAS WRITTEN" "WHAT IS TESTED" \
                "NOW THE HONEST PART" "SOURCES" "FEEDBACK" \
                "WHERE IT IS WORTH MOST" \
                "Apache License, Version 2.0" "NO WARRANTY" \
                "SSN-614" "github.com/larrys614"; do
      case "$a" in *"$want"*) ;; *) bad "$t about is missing: $want" ;; esac
    done
  done
  ok "both tools have an about section with all six parts"

  #  The about text quotes numbers about the program. If the program
  #  changes and the text does not, the documentation starts lying -
  #  which is exactly the failure this section exists to prevent.
  a=$(COLREGS_HOME="$CR" COLREGS_AWK="$AW" printf '3\n5\nx\n' \
      | $SH ./bin/colregs about 2>/dev/null)
  nv=$($AW $CSRC -v cmode=plain -f tests/count-check.awk \
       -v what=vessels </dev/null)
  ne=$($AW $CSRC -v cmode=plain -f tests/count-check.awk \
       -v what=encounters </dev/null)
  nm=$($AW $CSRC -v cmode=plain -f tests/count-check.awk -v what=motion </dev/null)
  [ "$nv" = 20 ] || bad "about says twenty vessels; there are $nv"
  [ "$ne" = 28 ] || bad "about says twenty-eight encounters; there are $ne"
  [ "$nm" = 65 ] || bad "about says sixty-five give-way calls; there are $nm"
  case "$a" in *"Twenty vessels"*) ;; *) bad "about no longer says how many vessels" ;; esac
  case "$a" in *"twenty-eight encounters"*) ;; *) bad "about no longer says how many encounters" ;; esac
  case "$a" in *"sixty-five distinct give-way calls"*) ;; *) bad "about no longer says how many give-way calls" ;; esac
  gl=$(cat tests/golden/*.txt 2>/dev/null | wc -l)
  if [ "$gl" -lt 20000 ] || [ "$gl" -gt 34000 ]; then
    bad "about says about twenty-six thousand golden lines; there are $gl"
  fi
  ok "the numbers the about section quotes match the program ($nv/$ne/$nm/$gl)"
  #  the licence the program claims must be the licence in the file
  grep -q "Apache License" LICENSE || bad "LICENSE is not the Apache licence"
  grep -q "Copyright 2026 M. Larry Sherman" NOTICE || bad "NOTICE has no copyright line"
  grep -q "CC BY 4.0" NOTICE || bad "NOTICE does not carry the CC BY attribution"
  for t in bin/celnav bin/colregs; do
    grep -q "Apache License, Version 2.0" "$t" || bad "$t does not name its licence"
    grep -q "MIT" "$t" && bad "$t still mentions MIT"
  done
  ok "the licence the tools claim is the licence in LICENSE and NOTICE"

  # ---- the README's pictures ---------------------------------------
  #  The coloured art is generated from the tools' real output. If an
  #  image goes missing, or make-site.sh stops producing one, the front
  #  page silently shows a broken image to everybody who arrives.
  rm_bad=0
  for f in $(sed -n 's/.*src="\(docs\/img\/[^"]*\)".*/\1/p' README.md); do
    [ -s "$f" ] || { bad "README references $f, which is missing or empty"; rm_bad=1; }
  done
  for f in docs/img/*.svg; do
    [ -s "$f" ] || continue
    head -1 "$f" | grep -q "<svg" || { bad "$f is not an SVG"; rm_bad=1; }
    grep -q "<script" "$f" && { bad "$f contains a script; GitHub will not render it"; rm_bad=1; }
  done
  #  and the pictures must be an exact character grid. Three separate
  #  bugs sheared it - xml:space stripped, glyphs advancing by the font's
  #  width, XML collapsing spaces - all with the same symptom and none
  #  visible without rendering the file and looking at it.
  for f in docs/img/*.svg; do
    [ -s "$f" ] || continue
    r=$($AW -f tests/svg-check.awk -v pad=14 -v fw=8.0 < "$f" | tail -1)
    case "$r" in *"BAD 0") ;; *) bad "$f is not an exact grid: $r"; rm_bad=1 ;; esac
  done
  #  a round trip through known input, so the arithmetic itself is checked
  #  and not just the files that happen to be committed
  r=$(printf 'A%29sB\n' "" | $AW -f docs/ansi2svg.awk -v title=t \
      | $AW -f tests/svg-check.awk -v pad=14 -v fw=8.0 | tail -1)
  case "$r" in "TEXTS 2 BAD 0") ;; *) bad "ansi2svg does not place a known grid correctly: $r"; rm_bad=1 ;; esac
  [ "$rm_bad" = 0 ] && ok "every picture the README shows exists, is a plain SVG, and is an exact grid"

  #  ---- the README's own markup -------------------------------------
  #  A picture can be perfect and still never reach anybody.  An
  #  unclosed ```sh fence once swallowed the lights plate whole: the
  #  <img> tag sat inside the code block, GitHub printed it as text,
  #  and no image rendered at all.  From the outside that is
  #  indistinguishable from a picture with no colour in it, which is
  #  exactly how it was reported and why it took so long to find.
  r=$($AW -f tests/readme-check.awk -v WANT=4 README.md)
  case "$r" in
    *"READMERESULT 0 "*) ok "the README's fences close and all four pictures render" ;;
    *) printf '%s\n' "$r" | grep -v READMERESULT
       bad "the README's markup is broken - see the lines above" ;;
  esac

  # ---- a function name used as a variable ---------------------------
  #  awk will not let a function's name be used as a variable or a
  #  parameter. gawk lets it pass; mawk refuses to parse the file, but
  #  only when the function was defined BEFORE the use - so the same
  #  code can work in one file and break when another is loaded after
  #  it. Check each tool's files as they are actually loaded together.
  fp=0
  for grp in "src/colregs/engine.awk src/colregs/contacts.awk src/colregs/review.awk" \
             "src/celnav/engine.awk src/celnav/teach.awk" \
             "src/tides/tables.awk src/tides/engine.awk"; do
    r=$($AW -f tests/fnparam-check.awk $grp)
    n=$(echo "$r" | tail -1 | $AW '{print $2}')
    if [ "$n" != 0 ]; then bad "$n parameters shadow a function name"; echo "$r" | grep -v '^BAD' | head -4; fp=1; fi
  done
  [ "$fp" = 0 ] && ok "no parameter shadows a function name"

  # ---- awk's own built-in variables --------------------------------
  #  A global called RS is the record separator. Setting it to a number
  #  makes the next getline read a whole file as a single record, with no
  #  error anywhere - which is exactly what a rate variable named RS did
  #  in the tide engine, and it took a while to see.
  #  every awk source in the repository, not just the tools': the SVG
  #  generator used RT, which is gawk's record terminator, and the lint
  #  did not cover that file or that name.
  r=$($AW -f tests/awkvars-check.awk src/celnav/engine.awk src/celnav/teach.awk \
        src/colregs/engine.awk src/colregs/contacts.awk src/colregs/review.awk \
        src/tides/engine.awk src/tides/tables.awk docs/ansi2svg.awk \
        tests/contacts-check.awk tests/review-check.awk tests/tides-check.awk \
        tests/annex1-check.awk tests/fields-check.awk tests/count-check.awk)
  n=$(echo "$r" | tail -1 | $AW '{print $2}')
  if [ "$n" = 0 ]; then ok "no code assigns to one of awk's built-in variables"
  else bad "$n assignments to awk built-ins"; echo "$r" | grep -v "^BAD" | head -5; fi

  # ---- the tides tool ----------------------------------------------
  TH="$tmp/tides-$SH-$AW"; rm -rf "$TH"
  o=$(TIDES_HOME="$TH" TIDES_AWK="$AW" $SH ./bin/tides version 2>/dev/null)
  case "$o" in tides\ *) ok "tides reports its version" ;; *) bad "tides version: $o" ;; esac
  TIDES_HOME="$TH" TIDES_AWK="$AW" $SH ./bin/tides use noaa/8461490 >/dev/null 2>&1
  o=$(TIDES_HOME="$TH" TIDES_AWK="$AW" $SH ./bin/tides today 2026-08-30 2>&1)
  n=$(echo "$o" | grep -c -E '^  (HIGH|low) ' || true)
  check "tides prints four turns for the day" "4" "$n"
  case "$o" in *"NEW LONDON"*) ;; *) bad "tides does not name the station" ;; esac
  case "$o" in *"heights above MLLW"*) ;; *) bad "tides does not name the datum" ;; esac
  #  a secondary port must work too, and say what it is
  TIDES_HOME="$TH" TIDES_AWK="$AW" $SH ./bin/tides use noaa/8510884 >/dev/null 2>&1
  o=$(TIDES_HOME="$TH" TIDES_AWK="$AW" $SH ./bin/tides today 2026-08-30 2>&1)
  case "$o" in *"secondary port"*) ;; *) bad "a subordinate station is not marked as one" ;; esac
  n=$(echo "$o" | grep -c -E '^  (HIGH|low) ' || true)
  [ "$n" -ge 3 ] || bad "a secondary port gave $n turns"
  #  station search, by name and by position
  o=$(TIDES_HOME="$TH" TIDES_AWK="$AW" $SH ./bin/tides near 41.2333 -72.0833 5 </dev/null 2>&1)
  case "$o" in *"Little Gull"*) ;; *) bad "nearest-station search missed Little Gull Island" ;; esac
  case "$o" in *"straight line"*) ;; *) bad "the nearest-station warning is missing" ;; esac
  o=$(TIDES_HOME="$TH" TIDES_AWK="$AW" $SH ./bin/tides find "new london" </dev/null 2>&1)
  case "$o" in *"NEW LONDON"*) ;; *) bad "name search missed New London" ;; esac
  ok "tides finds stations by name and by position"

  #  ---- the loose name search -------------------------------------
  #  Nobody types a station's exact name, so every one of these has to
  #  land on New London: words in the wrong order, a fragment of a
  #  word, and a regular expression.
  for _q in "new london" "lon new" "new lon" "NEW LONDON" "^new london" "london|zzzz"; do
    o=$(TIDES_HOME="$TH" TIDES_AWK="$AW" $SH ./bin/tides find "$_q" </dev/null 2>&1)
    case "$o" in *"NEW LONDON"*) ;; *) bad "search '$_q' missed New London" ;; esac
  done
  ok "the name search takes words in any order, fragments and regexes"

  #  Anchors have to anchor to the NAME.  If the regex is run against
  #  the name, the state and the country run together, ^ and $ - the
  #  whole reason to reach for a regex - stop meaning anything, and
  #  "bay$" silently matches nothing at all.
  o=$(TIDES_HOME="$TH" TIDES_AWK="$AW" $SH ./bin/tides find 'bay$' </dev/null 2>&1)
  case "$o" in *"Bay "*|*"Bay  "*) ok "\$ anchors to the end of the station's name" ;;
    *) bad "'bay\$' found no station whose name ends in Bay" ;; esac
  o=$(TIDES_HOME="$TH" TIDES_AWK="$AW" $SH ./bin/tides find '^boston$' </dev/null 2>&1 \
      | $AW '/^ +[0-9]+  +[A-Za-z]/{n++} END{print n+0}')
  check "^boston\$ matches only the stations actually called Boston" "2" "$o"

  #  A word that is genuinely absent must find nothing, or the search
  #  is matching everything and the list means nothing.
  o=$(TIDES_HOME="$TH" TIDES_AWK="$AW" $SH ./bin/tides find "new zzzqqq" </dev/null 2>&1)
  case "$o" in *"Nothing matched"*) ok "an impossible search says so" ;;
    *) bad "'new zzzqqq' matched something" ;; esac

  #  A malformed regex must NOT abort the run: awk cannot catch a bad
  #  pattern, so a bad one has to be spotted before it is used.
  for _q in "((" "*bad" "a[" "b\\" "|x" "a{"; do
    o=$(TIDES_HOME="$TH" TIDES_AWK="$AW" $SH ./bin/tides find "$_q" </dev/null 2>&1)
    case "$o" in *"MATCHING"*) ;; *) bad "a malformed pattern '$_q' killed the search" ;; esac
  done
  ok "a malformed regular expression falls back to plain text"

  #  Exactness has to outrank containment, or a place whose name IS what
  #  you typed sits below the ones that merely contain it.  "falmouth"
  #  is the discriminating case: alphabetically "Chappaquoit Point  West
  #  Falmouth Harbor" comes first, and by rank "Falmouth Foreside" does.
  o=$(TIDES_HOME="$TH" TIDES_AWK="$AW" $SH ./bin/tides find "falmouth" </dev/null 2>&1 \
      | $AW '/^ +1  +[A-Za-z]/{print; exit}')
  case "$o" in *"Falmouth Foreside"*) ok "the closest name to what was typed comes first" ;;
    *) bad "search ranking put this first instead: $o" ;; esac

  #  Picking by number must use the engine's own list, and the picked
  #  station must be the one on that line of the drawing.
  o=$(printf '5\nnew lon\n3\nq\n' | TIDES_HOME="$TH" TIDES_AWK="$AW" $SH ./bin/tides 2>&1)
  case "$o" in *"station: NEW LONDON"*) ok "a station can be picked by number from a search" ;;
    *) bad "picking 3 from the 'new lon' list did not select NEW LONDON" ;; esac

  #  A search that finds nothing must not throw you back to the menu.
  o=$(printf '5\nzzzqqq\nnew lon\n3\nq\n' | TIDES_HOME="$TH" TIDES_AWK="$AW" $SH ./bin/tides 2>&1)
  case "$o" in *"station: NEW LONDON"*) ok "a fruitless search can be retried in place" ;;
    *) bad "the search loop did not offer a second try" ;; esac
  #  the curve and the sky panel must render
  TIDES_HOME="$TH" TIDES_AWK="$AW" $SH ./bin/tides use noaa/8461490 >/dev/null 2>&1
  o=$(TIDES_HOME="$TH" TIDES_AWK="$AW" $SH ./bin/tides sky 2026-08-30 2>&1)
  case "$o" in *"SUN AND MOON"*) ;; *) bad "the sun and moon panel is missing" ;; esac
  case "$o" in *"lit,"*) ;; *) bad "the moon phase is missing" ;; esac
  n=$(echo "$o" | grep -c '#' || true)
  [ "$n" -ge 5 ] || bad "the moon disc did not draw"
  ok "tides draws the curve, the moon and the sun"
  #  the depth helper must answer the two questions it exists for
  o=$(printf '4\n2.0\n1.6\n0.5\n\nq\n' | TIDES_HOME="$TH" TIDES_AWK="$AW" $SH ./bin/tides 2>&1 || true)
  case "$o" in *"enough water"*) ;; *) bad "the depth helper gave no window" ;; esac
  case "$o" in *"under the surface now"*) ;; *) bad "the depth helper did not add the tide to the charted depth" ;; esac
  ok "the depth helper works out when there is water"

  #  and it must be clean when piped, like the others
  e=$(TIDES_HOME="$TH" TIDES_AWK="$AW" $SH ./bin/tides today 2026-08-30 | cat -v | grep -c '\^\[' || true)
  check "tides is clean when piped" "0" "$e"

  # ---- tides against NOAA's own published predictions ---------------
  r=$($AW -f src/tides/tables.awk -f src/tides/engine.awk -f tests/tides-check.awk \
        -v SF=src/tides/stations.dat -v REF=tests/tides-noaa.dat </dev/null | grep '^RESULT')
  set -- $r
  tn=$2; tt=$3; th=$4; tm=$5
  [ "$tm" = 0 ] || bad "$tm predicted turns could not be matched to NOAA's"
  [ "$tn" -ge 24 ] || bad "only $tn turns compared against NOAA"
  if $AW -v t="$tt" 'BEGIN{exit !(t<12)}' </dev/null; then :; else bad "worst high/low water time error $tt min"; fi
  if $AW -v h="$th" 'BEGIN{exit !(h<0.06)}' </dev/null; then :; else bad "worst high/low water height error $th m"; fi
  ok "tides match NOAA's published tables ($tn turns, worst $tt min and $th m)"

  # ---- no network, ever --------------------------------------------
  #  The founding promise of both tools, and the reason the review
  #  session prints a link instead of posting one. A test, not a habit.
  #  Match a command at a command position, not a substring: "nc" lives
  #  inside "since" and "encounter", and a lint that cries wolf gets
  #  switched off, which is worse than no lint at all.
  #
  #  A URL printed for a person to READ is fine - the licence text and
  #  the review link are both just words on a screen. What is banned is
  #  fetching one, so these look for the fetch, never for the string.
  P_CMD='(^|[;&|(`$[:space:]])(curl|wget|ncat|netcat|telnet|ftp)([[:space:]]|$)'
  P_NC='(^|[;&|(`[:space:]])nc[[:space:]]+-'
  P_GET='getline[^;]*<[[:space:]]*.?(http|ftp)'
  P_PIPE='[|][[:space:]]*.[^"]*(curl|wget)'
  net=0
  for t in bin/celnav bin/colregs; do
    grep -qE "$P_CMD"  "$t" && { bad "$t invokes a network command"; net=1; }
    grep -qE "$P_NC"   "$t" && { bad "$t invokes nc"; net=1; }
    grep -qE "$P_GET"  "$t" && { bad "$t reads a URL with getline"; net=1; }
    grep -qE "$P_PIPE" "$t" && { bad "$t pipes to curl or wget"; net=1; }
    for lit in "/dev/tcp" "/dev/udp"; do
      grep -qF -- "$lit" "$t" && { bad "$t opens $lit"; net=1; }
    done
  done
  [ "$net" = 0 ] && ok "neither tool can reach the network"

  #  The review session must never PROMPT for an email address. Saying
  #  in prose that it collects none is fine and is not what this checks.
  if grep -nE "e-?mail" bin/colregs | grep -qE "read |printf.*: \"" ; then
    bad "colregs appears to prompt for an email address"
  else
    ok "the review session never asks for an email address"
  fi

  # ---- the review session ------------------------------------------
  RVK="-f src/colregs/engine.awk -f src/colregs/contacts.awk -f src/colregs/review.awk -f tests/review-check.awk"
  n=$($AW $RVK -v cmode=plain -v what=count </dev/null)
  [ "$n" -ge 150 ] || bad "only $n reviewable claims; expected all 153"
  r=$($AW $RVK -v cmode=plain -v what=keys </dev/null | tail -1)
  check "review keys are unique and well formed" "BAD 0" "$r"
  r=$($AW $RVK -v cmode=plain -v what=show </dev/null | tail -1)
  check "every reviewable claim renders and carries its own words" "BAD 0" "$r"
  ok "$n claims are offered for review"

  #  Drive the interactive session the way a person does. The section
  #  path once redirected the loop's stdin to the key file, so every
  #  prompt read a KEY instead of the answer typed at it and a whole
  #  section scrolled past unanswered - invisible to any test that only
  #  called the engine directly.
  RVH="$tmp/rvhome-$SH-$AW"; rm -rf "$RVH"; mkdir -p "$RVH"
  printf '2\nf\nthe note\nr\nc\na comment\nq\nx\n' \
    | COLREGS_HOME="$RVH" COLREGS_AWK="$AW" $SH ./bin/colregs review >/dev/null 2>&1 || true
  if [ -s "$RVH/review.tsv" ]; then
    got=$(cat "$RVH/review.tsv")
    case "$got" in *"enc-0	flag	the note"*) ;; *) bad "review did not record the flag and its note" ;; esac
    case "$got" in *"enc-1	ok"*) ;; *) bad "review did not record a plain correct" ;; esac
    case "$got" in *"enc-2	ok	a comment"*) ;; *) bad "review did not record a comment on a correct item" ;; esac
    n=$(wc -l < "$RVH/review.tsv" | tr -d ' ')
    [ "$n" = 3 ] || bad "review recorded $n answers from three keypresses"
    ok "the review session records what a person actually types"
  else
    bad "the review session recorded nothing at all"
  fi
  #  and resuming picks up where it stopped rather than starting again
  nx=$(COLREGS_HOME="$RVH" COLREGS_AWK="$AW" $SH ./bin/colregs review </dev/null 2>/dev/null | head -0
       $AW -f src/colregs/engine.awk -f src/colregs/contacts.awk -f src/colregs/review.awk \
           -v cmode=plain -v cmd=rvnext -v rfile="$RVH/review.tsv" </dev/null)
  check "review resumes at the next unanswered claim" "enc-3" "$nx"

  #  A flagged item must survive the round trip into the issue link and
  #  back out again, byte for byte - a review is somebody's careful work.
  RVT="$tmp/rv.tsv"
  printf 'enc-12\tflag\tthe semicolon splits option b\nlig-3\tok\t\n' > "$RVT"
  RVB="$tmp/rv.body"
  $AW -f src/colregs/engine.awk -f src/colregs/contacts.awk -f src/colregs/review.awk \
      -v cmode=plain -v cmd=rvreport -v rfile="$RVT" -v rvver=test </dev/null > "$RVB"
  grep -q "enc-12" "$RVB" || bad "the report does not name the flagged item"
  grep -q "the semicolon splits option b" "$RVB" || bad "the report drops the reviewer's note"
  grep -q "program says" "$RVB" || bad "the report does not carry what the program claims"
  U=$($AW -f src/colregs/engine.awk -f src/colregs/contacts.awk -f src/colregs/review.awk \
      -v cmode=plain -v cmd=rvurl -v rfile="$RVT" -v rbody="$RVB" </dev/null)
  case "$U" in https://github.com/*/bashnav/issues/new*) ;;
               *) bad "the review link is not a github issue url" ;; esac
  case "$U" in *" "*) bad "the review link contains a raw space" ;; esac
  #  decode it back and compare with the file it was built from
  echo "$U" | sed 's/.*&body=//' | $AW '
    BEGIN{ for(i=0;i<256;i++) o[sprintf("%c",i)]=i
           for(i=0;i<256;i++) h[sprintf("%02X",i)]=sprintf("%c",i) }
    { r=""
      for(i=1;i<=length($0);i++){ c=substr($0,i,1)
        if(c=="%"){ r=r h[substr($0,i+1,2)]; i+=2 } else r=r c }
      printf "%s", r }' > "$tmp/rv.back"
  if cmp -s "$RVB" "$tmp/rv.back"; then ok "a review round-trips through the issue link unchanged"
  else bad "the review link does not decode back to the report"; fi

  # ---- separator collisions ----------------------------------------
  #  Every table is a delimited string; a delimiter inside a field splits
  #  it silently. Encounters 13 and 14 shipped with five options and the
  #  right answer cut in half because of exactly this.
  r=$($AW $CSRC -v cmode=plain -f tests/fields-check.awk </dev/null)
  n=$(echo "$r" | tail -1)
  if [ "$n" = 0 ]; then ok "no table field is split by its own separator"
  else bad "$n split fields"; echo "$r" | grep -v '^[0-9]*$' | head -6; fi

  # ---- the light tables against Annex I ----------------------------
  #  Not whether a vessel shows the right lights - that needs a person
  #  with the Convention. Only the parts that are geometry: pairs, arcs,
  #  heights and the circle adding up.
  r=$($AW $CSRC -f tests/annex1-check.awk -v cmode=plain </dev/null)
  n=$(echo "$r" | tail -1)
  if [ "$n" = 0 ]; then ok "light tables satisfy Annex I where it is checkable"
  else bad "$n Annex I violations"; echo "$r" | grep '^FAIL' | head -8; fi

  # ---- the reporting style -----------------------------------------
  CT="$CSRC"      # the tool loads all three; so must every test
  #  Every style must produce a report, and each must be its own words.
  prev=""
  for st in rn usn rel360 words none; do
    r=$($AW $CT -v cmode=plain -v rstyle=$st -v cmd=cref </dev/null | grep "Master 2")
    case "$st" in
      rn)     case "$r" in *"Red 20"*) ;; *) bad "style rn does not say Red 20" ;; esac ;;
      usn)    case "$r" in *"Port 20"*) ;; *) bad "style usn does not say Port 20" ;; esac ;;
      rel360) case "$r" in *"340 relative"*) ;; *) bad "style rel360 is wrong" ;; esac ;;
      words)  case "$r" in *"fine on the port bow"*) ;; *) bad "style words is wrong" ;; esac ;;
      none)   case "$r" in *Red*|*Port*|*relative*|*bow*) bad "style none still gives a relative bearing" ;; esac ;;
    esac
    [ "$r" = "$prev" ] && bad "style $st is identical to the one before it"
    prev="$r"
  done
  ok "all five reporting styles say the same angle their own way"
  #  and the setting must survive being written and read back
  CS=$(mktemp -d)
  COLREGS_HOME="$CS" COLREGS_AWK="$AW" $SH ./bin/colregs style usn >/dev/null 2>&1
  r=$(COLREGS_HOME="$CS" COLREGS_AWK="$AW" $SH ./bin/colregs card 2>/dev/null | grep -c "Port 20" || true)
  check "the reporting style persists between runs" "1" "$r"
  r=$(COLREGS_HOME="$CS" COLREGS_AWK="$AW" $SH ./bin/colregs day >/dev/null 2>&1
      COLREGS_HOME="$CS" COLREGS_AWK="$AW" $SH ./bin/colregs card 2>/dev/null | grep -c "Port 20" || true)
  check "changing the colour mode does not lose the reporting style" "1" "$r"
  rm -rf "$CS"

  # ---- contacts ----------------------------------------------------
  CTC="$CT -f tests/contacts-check.awk"
  for L in C1 C2 C3 C4 C5 C6 C7; do
    n=$($AW $CT -v cmode=plain -v cmd=clesson -v les_id=$L </dev/null | wc -l)
    [ "$n" -gt 12 ] || bad "contacts lesson $L is thin or empty"
  done
  ok "seven contacts lessons render"
  nb=$($AW $CTC -v cmode=plain -v what=relbrg </dev/null)
  check "Red/Green and the words agree, on both sides, at every degree" "0" "$nb"
  n=$($AW $CT -v cmode=plain -v cmd=clesson -v les_id=C7 </dev/null | grep -c "never across a turn" || true)
  check "C7 warns that drift cannot be read across a turn" "1" "$n"
  n=$($AW $CT -v cmode=plain -v cmd=cref </dev/null | grep -c "passes ASTERN" || true)
  check "the contacts card renders" "1" "$n"

  out=$($AW $CTC -v cmode=plain -v what=mark </dev/null)
  ns=$(echo "$out" | sed -n 's/^SEEDS //p')
  n3=$(echo "$out" | grep -c "3 of 3" || true)
  check "the tracking exercise marks its own answers correctly" "$ns" "$n3"
  n0=$($AW $CTC -v cmode=plain -v what=markwrong </dev/null | grep -c "3 of 3" || true)
  check "the tracking exercise fails a wrong answer" "0" "$n0"

  #  The claim the section rests on: drift away from your bow can never
  #  cross ahead. If that is ever false, the lessons are teaching a lie.
  out=$($AW $CTC -v cmode=plain -v what=drift </dev/null)
  nn=${out%% *}; nb=${out##* }
  check "drift toward the bow always crosses ahead ($nn geometries)" "0" "$nb"

  out=$($AW $CTC -v cmode=plain -v what=ekelund </dev/null)
  nn=${out%% *}; nw=${out##* }
  if $AW -v w="$nw" 'BEGIN{exit !(w<0.07)}' </dev/null; then
    ok "Ekelund recovers the true range ($nn leg pairs, worst $nw)"
  else bad "Ekelund error $nw is too large"; fi

  # ---- the quiz must not give away what it is asking --------------
  e=$($AW $CSRC -v cmd=qlight -v seed=4242 -v cmode=plain </dev/null | grep -c 'You are ' || true)
  check "lights quiz does not tell you the aspect" "0" "$e"
  e=$($AW $CSRC -v cmd=light -v key=sail -v th=300 -v cmode=plain </dev/null | grep -c 'You are ' || true)
  check "the lights reference still tells you the aspect" "1" "$e"
 done
done

say ""
if [ "$fail" -eq 0 ]; then say "ALL TESTS PASSED"; exit 0; fi
say "$fail FAILURE(S)"
exit 1
