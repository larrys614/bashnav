#!/bin/sh
#  The site's pictures are the browser apps' own drawings now, captured by
#  docs/web/gen/make-app-figures.sh into docs/img/app/. This checks the
#  committed files, with no browser, so it runs on the boat.
#
#  Three things:
#
#  1. Every img/app/*.svg the page references is there, is a plain SVG
#     with a size GitHub Pages and an <img> can both use, and carries no
#     script. An SVG with a <script> in it does not render on GitHub and
#     is a hole besides.
#
#  2. Nothing is generated and then never shown. Two ansi pictures -
#     colregs-contacts and colregs-mineclear - were built on every site
#     rebuild for weeks and referenced by nothing, which is how a figure
#     quietly stops being looked at.
#
#  3. THE CONVENTION, in the one figure that states it. The day-shape
#     drawing of a mine clearance vessel must show THREE balls: one at
#     the foremast head and one at each end of the fore yard, Rule 27(f),
#     with the mast between the yard pair. The browser drew FOUR - it had
#     turned the shell glyph's "+", which marks where the yard crosses
#     the mast, into a shape - and four balls is not an arrangement the
#     Convention has. run-tests.sh already checks exactly this property
#     for her LIGHTS, at sixteen angles; nothing checked her shapes.
set -e
cd "$(dirname "$0")/.."
AW=${1:-awk}
bad=0

refs=$($AW '{ while(match($0, /img\/app\/[A-Za-z0-9._-]+\.(svg|png)/)) {
                print substr($0, RSTART, RLENGTH); $0 = substr($0, RSTART+RLENGTH) } }' \
       docs/index.html | sort -u)
if [ -z "$refs" ]; then
  echo "  the site references no app figures at all"
  echo "APPFIG 1"
  exit 1
fi

for r in $refs; do
  f="docs/$r"
  if [ ! -s "$f" ]; then
    echo "  $r is referenced by the site and is not there"; bad=$((bad+1)); continue
  fi
  case "$r" in
  *.svg)
    #  a standalone SVG an <img> can render: namespaced, with a viewBox and
    #  a pixel size, and carrying no script - GitHub Pages will serve one
    #  with a script in it and the browser will not draw it
    grep -q '<svg' "$f" || { echo "  $f has no <svg> element"; bad=$((bad+1)); }
    grep -q 'xmlns="http://www.w3.org/2000/svg"' "$f" \
      || { echo "  $f has no xmlns, so an <img> will not render it"; bad=$((bad+1)); }
    grep -q 'viewBox="' "$f" || { echo "  $f has no viewBox"; bad=$((bad+1)); }
    grep -q 'width="[0-9]' "$f" \
      || { echo "  $f has no pixel width, so it has no intrinsic size in an <img>"; bad=$((bad+1)); }
    grep -q '<script' "$f" && { echo "  $f contains a script"; bad=$((bad+1)); }
    ;;
  *.png)
    #  THE SCREENSHOTS. Four of the six apps draw nothing - tides,
    #  deck-log, weather and drill are tables, logs, forms and prose - so
    #  their figures are pictures of the real screen. These are the only
    #  binary files in the repository and the only ones that cannot be
    #  diffed, so what can be checked is that the file is a PNG, is not
    #  truncated, and is not so small that the screen did not render.
    head -c 8 "$f" | od -An -tx1 2>/dev/null | tr -d ' \n' | grep -qi '^89504e470d0a1a0a' \
      || { echo "  $f does not start with the PNG signature"; bad=$((bad+1)); }
    sz=$(wc -c < "$f")
    [ "$sz" -lt 8000 ] && { echo "  $f is only $sz bytes - the screen probably did not render"; bad=$((bad+1)); }
    [ "$sz" -gt 600000 ] && { echo "  $f is $sz bytes, which is too much of the repository for one picture"; bad=$((bad+1)); }
    ;;
  esac
done

#  generated and never shown
for f in docs/img/app/*.svg docs/img/app/*.png; do
  [ -e "$f" ] || continue
  n=$(basename "$f")
  case "$refs" in *"img/app/$n"*) ;; *) echo "  docs/img/app/$n is generated and referenced by nothing"; bad=$((bad+1)) ;; esac
done

#  ---- Rule 27(f), in the figure ------------------------------------
f=docs/img/app/colregs-shapes.svg
if [ -s "$f" ]; then
  r=$($AW '
    { line = $0
      while(match(line, /<circle[^>]*>/)) {
        c = substr(line, RSTART, RLENGTH)
        line = substr(line, RSTART + RLENGTH)
        x = ""; y = ""
        if(match(c, /cx="[0-9.]+"/)) { x = substr(c, RSTART+4, RLENGTH-5) }
        if(match(c, /cy="[0-9.]+"/)) { y = substr(c, RSTART+4, RLENGTH-5) }
        if(x != "" && y != "") { n++; CX[n] = x + 0; CY[n] = y + 0 }
      }
    }
    END{
      if(n != 3){ printf "balls %d\n", n; exit }
      #  the two lowest-down (largest cy) are the yard pair; the odd one
      #  out is the masthead ball and must sit above them, between them
      lo = 1; for(i = 2; i <= n; i++) if(CY[i] < CY[lo]) lo = i
      top = lo; a = 0; b = 0
      for(i = 1; i <= n; i++) if(i != top){ if(!a) a = i; else b = i }
      if(CY[a] != CY[b]){ print "yard not level"; exit }
      l = (CX[a] < CX[b] ? CX[a] : CX[b]); rr = (CX[a] < CX[b] ? CX[b] : CX[a])
      if(CY[top] >= CY[a]){ print "masthead ball not above the yard"; exit }
      if(CX[top] <= l || CX[top] >= rr){ print "masthead ball not between the yard pair"; exit }
      print "ok"
    }' "$f")
  case "$r" in
    ok) ;;
    *) echo "  mine clearance day shapes: $r -- Rule 27(f) is three balls, one at the"
       echo "    foremast head and one at each end of the fore yard"
       bad=$((bad+1)) ;;
  esac
fi

printf 'APPFIG %d\n' "$bad"
[ "$bad" = 0 ]
