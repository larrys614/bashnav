#  One step of the annotated walkthrough -> one JS object.
#
#  Same job as dumptlesson.awk, with one difference that is the whole
#  reason the walkthrough was worth porting at all: ITS FIGURES CAN BE
#  REAL DRAWINGS. Three of the ten steps draw - the navigational triangle
#  at step 6, one LOP at step 9, three LOPs and the fix at step 10 - and
#  the browser already has the code for all three. The triangle is the
#  sandbox's, and the plotting sheet is the sight screen's.
#
#  So a figure here is not a named gap. gshow() prints "@@FIG grid W H"
#  under -v FIGDUMP=1 as before, and plot_sheet() now prints its own data
#  with it: "@@PLOT n fixN fixE haveFix" and one "@@LOP i zn p label" per
#  line. That is turned into a block carrying the actual azimuths and
#  intercepts, so the page draws the sheet rather than describing a hole
#  where one should be.
#
#  The caption lines the shell prints under a plot - "AP = +  LOP =
#  lettered line  1 row = 5 nm" and the note about a near-vertical line
#  stepping a column - are about the CHARACTER GRID and mean nothing in a
#  browser that draws real lines. They are dropped, and the drawing
#  carries its own legend instead.
function jq(s){ return js_dq(s) }
function flush_p(   t){
  t = buf
  gsub(/^\n+/,"",t); gsub(/\n+$/,"",t)
  buf = ""
  if(t=="") return 0
  printf "%s\n    {\n     \"t\": \"p\",\n     \"s\": \"%s\"\n    }", (nb++ ? "," : ""), jq(t)
  return 0
}
BEGIN{ buf=""; nb=0; title=""; got=0; rule=0; nlop=0; figttl=""; skipcap=0 }
{
  line = $0
  sub(/[ \t]+$/,"",line)

  #  the step header, then the rule under it, then the title
  if(!got && line ~ /^  WALKTHROUGH  step /){ rule=1; next }
  if(rule){ rule=0; next }
  if(!got){
    if(line == "") next
    t=line; sub(/^  */,"",t); title=t; got=1
    printf "  {\n   \"step\": %d,\n   \"title\": \"%s\",\n   \"blocks\": [", step+0, jq(title)
    next
  }

  #  the two caption lines under a plot describe the character grid
  if(skipcap){
    if(line ~ /^  AP = / || line ~ /near-vertical LOP/ || line ~ /^  wide, so one degree/) next
    skipcap=0
  }

  if(line ~ /^@@PLOT /){
    flush_p()
    split(line, a, " ")
    printf "%s\n    {\n     \"t\": \"plot\",\n     \"title\": \"%s\",\n     \"fixN\": %s,\n     \"fixE\": %s,\n     \"fix\": %s,\n     \"lops\": [",
           (nb++ ? "," : ""), jq(figttl), a[3], a[4], (a[5]+0 ? "true" : "false")
    nlop=0
    next
  }
  if(line ~ /^@@LOP /){
    split(line, a, " ")
    printf "%s{ \"zn\": %s, \"p\": %s, \"label\": \"%s\" }", (nlop++ ? ", " : ""), a[3], a[4], jq(a[5])
    next
  }
  if(line ~ /^@@FIG /){
    if(nlop){ printf "]\n    }"; nlop=0; skipcap=1; figttl=""; next }
    #  a grid figure with no plot data behind it: step 6's triangle, which
    #  the page draws from the walkthrough's own sight
    flush_p()
    split(line, a, " ")
    printf "%s\n    {\n     \"t\": \"fig\",\n     \"kind\": \"%s\",\n     \"title\": \"%s\"\n    }",
           (nb++ ? "," : ""), jq(a[2]), jq(figttl)
    figttl=""
    next
  }

  #  A FIGURE'S TITLE IS PRINTED BEFORE IT, as its own all-capitals line,
  #  and it belongs to the figure rather than to the prose above it.
  if(line ~ /^  [A-Z][A-Z ,:-]+$/ && length(line) < 50){ flush_p(); figttl=line; sub(/^  */,"",figttl); next }

  sub(/^  /,"",line)
  buf = buf (buf=="" ? "" : "\n") line
}
END{
  if(nlop) printf "]\n    }"
  flush_p()
  printf "\n   ]\n  }"
}
