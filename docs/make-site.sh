#!/bin/sh
# Rebuild docs/index.html from the template, filling every plate with the
# tools' real output. Run it after changing anything that shows on the site.
set -e
cd "$(dirname "$0")/.."
GH=${GH_USER:-larrys614}

./build.sh >/dev/null

tmp=${TMPDIR:-/tmp}/bashnav-site.$$
mkdir -p "$tmp/plates"
trap 'rm -rf "$tmp"' EXIT

CH="$tmp/celnav"; CR="$tmp/colregs"
export CELNAV_HOME="$CH" COLREGS_HOME="$CR"

./bin/celnav dr "35 00 N" "040 00 W" 0 0 >/dev/null
./bin/celnav sight "2026-08-29 07:30:00" Dubhe     C "19 32.1" 1.5 3.0 >/dev/null
./bin/celnav sight "2026-08-29 07:34:00" Bellatrix C "49 37.2" 1.5 3.0 >/dev/null
./bin/celnav sight "2026-08-29 07:38:00" Markab    C "29 01.3" 1.5 3.0 >/dev/null
./bin/celnav fix > "$tmp/fix.txt"

sed -n '/INTERCEPT PLOT/,/1 column/p' "$tmp/fix.txt" | sed 's/^  //' > docs/plates/plot.txt
sed -n '/SKY VIEW/,/inner rings/p'    "$tmp/fix.txt" | sed 's/^  //' > docs/plates/sky.txt
sed -n '/Sight a:/,/Intercept/p'      "$tmp/fix.txt" | sed 's/^  //' > docs/plates/working.txt

#  Take the engine paths from the tools themselves rather than naming a
#  version here - a hard-coded one silently stops matching on the next
#  release, and the plate it feeds goes blank without anything failing.
CV=$(./bin/celnav version | awk '{print $2}')
RV=$(./bin/colregs version | awk '{print $2}')
awk -f "$CH/engine-$CV.awk" -f "$CH/teach-$CV.awk" \
    -v cmd=t_sandbox -v slat=35 -v sdec=20 -v slha=310 </dev/null \
  | sed -n '/SANDBOX/,/Zn/p' | sed 's/^  //' > docs/plates/triangle.txt

./bin/colregs light ram 40 | sed -n '/WHAT DO YOU SEE/,/yellow/p' | sed 's/^  //' > docs/plates/lights.txt
CE="$CR/engine-$RV.awk"
CC="$CR/contacts-$RV.awk"
awk -f "$CE" -v cmd=enc -v seed=21 -v which=2 </dev/null \
  | sed -n '/WHAT DO YOU DO/,/^   d)/p' | sed 's/^  //' > docs/plates/encounter.txt
awk -f "$CE" -v cmd=scen -v seed=42 </dev/null \
  | sed -n '/COLLISION AVOIDANCE/,/^  Q1/p' | sed 's/^  //' > docs/plates/scenario.txt
{ ./bin/colregs refsound | sed -n '/In sight of one another/,/bend/p' | sed 's/^  //' | head -9
  echo
  ./bin/colregs refsound | sed -n '/restricted visibility/,/Aground/p' | sed 's/^  //' | head -8
} > docs/plates/sound.txt

awk -v gh="$GH" '
function esc(s){ gsub(/&/,"\\&amp;",s); gsub(/</,"\\&lt;",s); gsub(/>/,"\\&gt;",s); return s }
function plate(f,   line,out){
  out=""
  while((getline line < f) > 0) out = out esc(line) "\n"
  close(f)
  sub(/\n$/,"",out)
  return out
}
# the lights plate, with the light letters in their real colours.  A line
# whose only letters are R G W or Y is part of the drawing, not the prose.
function platelights(f,   line,out,t){
  out=""
  while((getline line < f) > 0){
    t=line; gsub(/[RGWY]/,"",t)
    if(line ~ /[A-Za-z]/ && t !~ /[A-Za-z]/){
      line=esc(line)
      gsub(/R/,"<span class=\"r\">R</span>",line)
      gsub(/G/,"<span class=\"g\">G</span>",line)
      gsub(/W/,"<span class=\"w\">W</span>",line)
      gsub(/Y/,"<span class=\"y\">Y</span>",line)
      out = out line "\n"
    } else out = out esc(line) "\n"
  }
  close(f)
  sub(/\n$/,"",out)
  return out
}
{
  if($0 ~ /\{\{PLOT\}\}/)      { sub(/\{\{PLOT\}\}/,      plate("docs/plates/plot.txt")) }
  if($0 ~ /\{\{WORKING\}\}/)   { sub(/\{\{WORKING\}\}/,   plate("docs/plates/working.txt")) }
  if($0 ~ /\{\{TRIANGLE\}\}/)  { sub(/\{\{TRIANGLE\}\}/,  plate("docs/plates/triangle.txt")) }
  if($0 ~ /\{\{LIGHTS\}\}/)    { sub(/\{\{LIGHTS\}\}/,    platelights("docs/plates/lights.txt")) }
  if($0 ~ /\{\{SOUND\}\}/)     { sub(/\{\{SOUND\}\}/,     plate("docs/plates/sound.txt")) }
  if($0 ~ /\{\{ENCOUNTER\}\}/) { sub(/\{\{ENCOUNTER\}\}/, plate("docs/plates/encounter.txt")) }
  if($0 ~ /\{\{SCENARIO\}\}/)  { sub(/\{\{SCENARIO\}\}/,  plate("docs/plates/scenario.txt")) }
  gsub(/\{\{GH\}\}/, gh)
  print
}' docs/site-template.html > docs/index.html


# ---- coloured pictures for the README -------------------------------
#  GitHub will not render ANSI in a code block and strips inline styles
#  from a README, but it does render an SVG image. So the art on the
#  front page can be the program's real output in the program's real
#  colours, rather than a plain-text approximation of it.
mkdir -p docs/img
CENG="$CH/engine-$CV.awk"
REN="-f $CR/engine-$RV.awk -f $CR/contacts-$RV.awk -f $CR/review-$RV.awk"

awk -f "$CENG" -v cmode=day -v cmd=reduce -v sfile="$CH/sights.txt" \
    -v drlat="35 00 N" -v drlon="040 00 W" -v course=0 -v speed=0 </dev/null \
  | sed -n '/INTERCEPT PLOT/,/1 column/p' \
  | awk -f docs/ansi2svg.awk -v title="celnav: the intercept plot, three star sights and the fix" \
  > docs/img/plot.svg

awk -f "$CENG" -v cmode=day -v cmd=plan -v utc="2026-08-29 07:34:00" \
    -v drlat="35 00 N" -v drlon="040 00 W" </dev/null \
  | sed -n '/SKY VIEW/,/suggested set/p' \
  | awk -f docs/ansi2svg.awk -v title="celnav: the sky, with the best three bodies marked" \
  > docs/img/sky.svg

awk $REN -v cmode=day -v cmd=light -v key=ram -v th=40 </dev/null \
  | sed -n '/WHAT DO YOU SEE/,/yellow/p' \
  | awk -f docs/ansi2svg.awk -v title="colregs: a vessel restricted in her ability to manoeuvre, seen from 040" \
  > docs/img/lights.svg

awk $REN -v cmode=day -v cmd=light -v key=mineclear -v th=310 </dev/null \
  | sed -n '/WHAT DO YOU SEE/,/yellow/p' \
  | awk -f docs/ansi2svg.awk -v title="colregs: a mine clearance vessel, three green lights on one yard" \
  > docs/img/lights-mineclear.svg

awk $REN -v cmode=day -v cmd=trackm -v seed=7 -v a1=b -v a2=b -v a3=c </dev/null \
  | sed -n '/yd across/,/whole question/p' \
  | awk -f docs/ansi2svg.awk -v title="colregs: the relative-motion plot from the tracking watch" \
  > docs/img/contacts.svg

echo "docs/img: $(ls docs/img/*.svg | wc -l) coloured pictures"

echo "docs/index.html written ($(wc -l < docs/index.html) lines)"
grep -c '{{' docs/index.html >/dev/null && {
  n=$(grep -c '{{' docs/index.html || true)
  [ "$n" = 0 ] || echo "warning: $n unfilled placeholder(s) remain"
}
