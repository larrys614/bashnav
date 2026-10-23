#  One captured CONTACTS lesson -> one JS object.
#
#  Same job as dumplesson.awk and the same two structural chores -- drop
#  the heading and its underline, strip the two-space screen indent --
#  with one difference that is the whole reason this file exists.
#
#  TWO OF THESE LESSONS CARRY A RELATIVE-MOTION PLOT AND ONE A COMPASS
#  ROSE, and the shell draws them on a 67 x 19 character grid. A picture
#  of a terminal is the wrong thing to put in a browser: it cannot follow
#  dark mode, it cannot reflow on a phone, and at that size the marks are
#  single characters. So the browser is handed the PARAMETERS and draws
#  SVG -- which means the parameters have to cross, and they live in the
#  awk source as arguments to ct_plot().
#
#  Typing them into the JS by hand is the obvious way and it is wrong: it
#  is a second source of truth that nothing checks, and the first draft of
#  this file was exactly that. Instead ct_plot() and ct_rose() print
#  "@@FIG ..." under -v FIGDUMP=1 and say what they were about to draw.
#  This splits the body on those lines. The numbers are the awk's own.
#
#  So a body is a LIST OF BLOCKS: {"t":"p","s":...} for prose,
#  {"t":"fig","kind":...} plus its parameters for a figure, in the order
#  the lesson prints them.
function jq(s){
  gsub(/\\/,"\\\\",s); gsub(/"/,"\\\"",s); gsub(/\t/," ",s)
  gsub(/\n/,"\\n",s)                       # see the note in dumplesson.awk
  return s
}
function flush_p(   t){                    # the prose gathered so far
  t = buf
  gsub(/^\n+/,"",t); gsub(/\n+$/,"",t)     # the blank lines the screen adds
  buf = ""
  if(t=="") return 0
  printf "%s\n    {\n     \"t\": \"p\",\n     \"s\": \"%s\"\n    }", (nb++ ? "," : ""), jq(t)
  return 0
}
BEGIN{ buf=""; nb=0; title=""; got=0; rule=0
       printf "  {\n" }
{
  line = $0
  sub(/[ \t]+$/,"",line)
  #  THE HEADING IS FOUND, NOT COUNTED. dumplesson.awk takes it off line 2
  #  and the underline off line 3, which is right for thead() today; this
  #  matches the heading itself, so a blank line gained or lost at the top
  #  cannot shift the title into the body or leave the underline in it.
  #  The first version of this file counted, guessed wrong by one, and put
  #  a row of dashes into the browser with an empty title above it.
  if(!got && line ~ /^  *C[0-9]+  /){
    t=line; sub(/^  *C[0-9]+  */,"",t); title=t; got=1; rule=1
    printf "   \"id\": \"%s\",\n   \"title\": \"%s\",\n   \"blocks\": [", jq(id), jq(title)
    next }
  if(rule){ rule=0; next }                 # the underline under the heading
  if(!got) next                            # the blank line thead() leads with
  if(line ~ /^@@FIG /){
    flush_p()
    #  the marker's own words, so a new figure kind needs nothing here
    n = split(line, a, " ")
    printf "%s\n    {\n     \"t\": \"fig\",\n     \"kind\": \"%s\"", (nb++ ? "," : ""), jq(a[2])
    for(i=3;i<=n;i++){
      if(split(a[i], kv, "=") == 2) printf ",\n     \"%s\": %s", jq(kv[1]), kv[2]+0 }
    printf "\n    }"
    next
  }
  sub(/^  /,"",line)                       # the screen indent
  buf = buf (buf=="" ? "" : "\n") line
}
END{ flush_p(); printf "\n   ]\n  }" }
