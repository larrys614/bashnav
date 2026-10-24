#  One captured celnav lesson -> one JS object.
#
#  Same job as colregs' dumpclesson.awk and the same structural chores:
#  drop the heading and the rule under it, strip the two-space screen
#  indent, and split the body at the figures. Two differences.
#
#  ONE, THESE LESSONS END IN A QUESTION. cmd=t_lesson prints the prose,
#  then the figure, then a rule, then "Q." and its options. The rule is
#  what separates them, so everything from it onward is the question and
#  everything before it is the body. The answer and the reason are not
#  in that output at all -- ques() only sets them on the branch that
#  does not print -- so they come from cmd=t_qmeta.
#
#  TWO, THE FIGURES ARE GAPS FOR NOW. Ten of the thirty-three lessons
#  draw on a 67 x 25 character grid: the globe with its graticule and
#  circles of position, the celestial triangle on the sky dome, the LOP
#  zoom. A picture of a terminal is the wrong thing in a browser 380px
#  wide, so gshow() prints "@@FIG grid W H" under -v FIGDUMP=1 and this
#  turns it into a block the page renders as a named gap. The figures
#  themselves are the second pass; the gap says which lesson's figure is
#  missing so nothing silently has a hole in it.
#
#  The OTHER figures -- the correction bars, the deviation card, the
#  interpolation tables -- print as rows of text rather than onto the
#  grid, so they arrive as prose and the page's hold rule keeps their
#  columns. That is the right answer for a table and needs nothing here.
function jq(s){
  gsub(/\\/,"\\\\",s); gsub(/"/,"\\\"",s); gsub(/\t/," ",s)
  gsub(/\n/,"\\n",s)
  return s
}
function flush_p(   t){
  t = buf
  gsub(/^\n+/,"",t); gsub(/\n+$/,"",t)
  buf = ""
  if(t=="") return 0
  printf "%s\n    {\n     \"t\": \"p\",\n     \"s\": \"%s\"\n    }", (nb++ ? "," : ""), jq(t)
  return 0
}
BEGIN{ buf=""; nb=0; title=""; got=0; rule=0; inq=0; qbuf=""; nfig=0 }
{
  line = $0
  sub(/[ \t]+$/,"",line)

  #  the heading is found, not counted -- see the note in dumpclesson.awk
  if(!got && line ~ /^  *[A-Z][0-9]  /){
    t=line; sub(/^  *[A-Z][0-9]  */,"",t); title=t; got=1; rule=1
    printf "  {\n   \"id\": \"%s\",\n   \"title\": \"%s\",\n   \"blocks\": [", jq(id), jq(title)
    next }
  if(rule){ rule=0; next }
  if(!got) next

  #  the rule before the question ends the body
  #  TEN LITERAL DASHES, NOT AN INTERVAL EXPRESSION. This was written
  #  /^ *-{20,} *$/ and mawk -- which the generator picks first -- does
  #  not implement {n,m}, so the rule never matched, the question stayed
  #  inside the prose and all thirty-three lessons came out with no
  #  question at all. CLAUDE.md's rule 1 and the suite's own
  #  interval-expression check, both of them mine, both ignored.
  if(!inq && line ~ /^ *----------/){ inq=1; next }
  if(inq){ qbuf = qbuf (qbuf=="" ? "" : "\n") line; next }

  if(line ~ /^@@FIG /){
    flush_p()
    n = split(line, a, " ")
    nfig++
    printf "%s\n    {\n     \"t\": \"fig\",\n     \"kind\": \"%s\",\n     \"w\": %d,\n     \"h\": %d,\n     \"n\": %d\n    }",
           (nb++ ? "," : ""), jq(a[2]), a[3]+0, a[4]+0, nfig
    next
  }
  sub(/^  /,"",line)
  buf = buf (buf=="" ? "" : "\n") line
}
END{
  flush_p()
  gsub(/^\n+/,"",qbuf); gsub(/\n+$/,"",qbuf)
  #  the question's own two-space indent comes off the same way
  nq = split(qbuf, QL, "\n")
  q = ""
  for(i=1;i<=nq;i++){ l=QL[i]; sub(/^  /,"",l); q = q (q=="" ? "" : "\n") l }
  printf "\n   ],\n   \"question\": \"%s\",\n   \"answer\": \"%s\",\n   \"why\": \"%s\"\n  }",
         jq(q), jq(ans), jq(why)
}
