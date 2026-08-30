#  Every built tool must appear in the README's table of tools AND have
#  its own "## <tool>" section.  deck-log shipped with a section and no
#  row, and nothing noticed - the kind of gap that is invisible to the
#  person who wrote it and obvious to the first person who reads it.
#
#  And every ROW must point at a heading that exists, whether or not it
#  is a binary: the weather section is part of deck-log and has no file
#  of its own, but a dead link in the first table anybody reads is still
#  a dead link.
FNR==NR {
  readme = readme $0 "\n"
  if($0 ~ /^\| \*\*\[/){
    s = $0
    sub(/^\| \*\*\[/, "", s)
    name = substr(s, 1, index(s, "]")-1)
    sub(/^[^(]*\(#/, "", s)
    anchor = substr(s, 1, index(s, ")")-1)
    ROW[++NROW] = name SUBSEP anchor
  }
  next
}
{ t=$0
  if(index(readme, "[" t "](#" t ")")==0){ printf "  %s has no row in the table of tools\n", t; bad++ }
  if(index(readme, "\n## " t "\n")==0){    printf "  %s has no ## section\n", t; bad++ }
}
END{
  for(i=1;i<=NROW;i++){
    split(ROW[i], p, SUBSEP)
    if(index(readme, "\n## " p[2] "\n")==0){
      printf "  the row for %s links to #%s, and there is no such section\n", p[1], p[2]
      bad++
    }
  }
  printf "TOOLROW %d\n", bad+0
}
