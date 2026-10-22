#  One captured colregs lesson -> one JS object.
#
#  The lesson is printed, not stored: les() calls thead/tp/tb, so the only
#  way to get it is to run it and read what comes out. In cmode=plain
#  there are no escapes to convert -- unlike the weather lessons, these
#  carry no inline emphasis -- so the work is structural: drop the two
#  header lines, strip the two-space screen indent, and split the body
#  from the question at the "Q." line.
#
#  -v id=, -v ans=, -v why= come from the driver, the last two out of
#  cmd=lessonmeta rather than out of prose.
function jq(s){
  gsub(/\\/,"\\\\",s); gsub(/"/,"\\\"",s); gsub(/\t/," ",s)
  #  A LESSON BODY IS MOSTLY NEWLINES, and a real newline inside a JSON
  #  string is an invalid control character, not a line break. The table
  #  dumper escapes them; this one did not, and the whole file failed to
  #  parse at the first lesson.
  gsub(/\n/,"\\n",s)
  return s
}
BEGIN{ body=""; ques=""; inq=0; nl=0; title="" }
{
  line = $0
  sub(/[ \t]+$/,"",line)
  nl++
  #  line 2 is "  L1  Rule 5 - Look-out", line 3 its underline
  if(nl==2){ t=line; sub(/^  *[A-Z][0-9]+  */,"",t); title=t; next }
  if(nl==3) next                       # the rule under the heading
  sub(/^  /,"",line)                   # the screen indent
  if(line ~ /^Q\. /) inq=1
  if(inq){ ques = ques (ques==""?"":"\n") line }
  else   { body = body (body==""?"":"\n") line }
}
END{
  #  trim the blank lines the screen layout adds at either end
  gsub(/^\n+/,"",body); gsub(/\n+$/,"",body)
  gsub(/^\n+/,"",ques); gsub(/\n+$/,"",ques)
  printf "  {\n   \"id\": \"%s\",\n   \"title\": \"%s\",\n   \"body\": \"%s\",\n",
         jq(id), jq(title), jq(body)
  printf "   \"question\": \"%s\",\n   \"answer\": \"%s\",\n   \"why\": \"%s\"\n  }",
         jq(ques), jq(ans), jq(why)
}
