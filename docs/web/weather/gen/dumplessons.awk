#  Convert one captured lesson (cmode=day, so the colour is in the text)
#  into a JS object.  The emphasis is the author's own: lph wraps a
#  heading in C_ACC, lpd an aside in C_DIM, and inside a line cw() marks
#  the words that matter.  Converting the escapes rather than stripping
#  them is what keeps the web lesson the same lesson.
#
#  cmode=day codes:  1;32 accent   90 aside   1;91 warn   1;92 ok
#                    40m 37m      the reset
#  js_dq/js_sq live in docs/web/gen/jsonesc.awk, loaded with -f before
#  this file. The doubling must not happen in gsub's replacement string;
#  see the long note there.
function jq(s){ return js_sq(s) }
BEGIN{ E=sprintf("%c",27); first=1 }
{
  line = $0
  #  A FIGURE IS A PLACE, NOT A PICTURE. gshow() prints "@@FIG grid W H"
  #  under -v FIGDUMP=1 instead of the character grid, which is how the
  #  shell says "the demonstration goes here" without deciding how it is
  #  drawn. The terminal draws it in characters; the browser renders the
  #  interactive version. Both builds are then the same lesson with the
  #  same demonstration in the same place, rather than one of them having
  #  a feature the other has never heard of.
  if(line ~ /^@@FIG /){
    split(line, fa, " ")
    printf "    { s: 'demo', kind: '%s', w: %d, h: %d },\n", jq(fa[2]), fa[3]+0, fa[4]+0
    next
  }
  #  the horizontal rule is structure, not content
  if(line ~ /^  -+$/){ printf "    { s: 'rule' },\n"; next }
  if(line ~ /^[ \t]*$/){ printf "    { s: 'gap' },\n"; next }

  #  split the line into styled spans
  out = ""; style = "plain"; buf = ""
  n = length(line)
  i = 1
  while(i <= n){
    if(substr(line,i,1) == E){
      #  read the escape sequence
      j = i+1
      if(substr(line,j,1) == "["){
        k = j+1
        while(k <= n && substr(line,k,1) !~ /[a-zA-Z]/) k++
        code = substr(line, j+1, k-j-1)
        #  flush what we have under the current style
        if(buf != ""){ out = out sp(style, buf); buf = "" }
        if(code == "1;32") style = "acc"
        else if(code == "90") style = "dim"
        else if(code == "1;91") style = "warn"
        else if(code == "1;92") style = "ok"
        else if(code == "40" || code == "37" || code == "0") style = "plain"
        i = k+1
        continue
      }
    }
    buf = buf substr(line,i,1)
    i++
  }
  if(buf != "") out = out sp(style, buf)
  printf "    { s: 'line', p: [%s] },\n", out
}
function sp(st, t,   q){
  q = jq(t)
  if(SEEN) return ", { t: '" q "', s: '" st "' }"
  SEEN=1
  return "{ t: '" q "', s: '" st "' }"
}
