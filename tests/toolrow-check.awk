#  Every built tool must appear in the README's table of tools AND have
#  its own "## <tool>" section.  deck-log shipped with a section and no
#  row, and nothing noticed - the kind of gap that is invisible to the
#  person who wrote it and obvious to the first person who reads it.
BEGIN{ for(i=1;i<ARGC;i++){} }
FNR==NR { readme = readme $0 "\n"; next }
{ t=$0
  if(index(readme, "[" t "](#" t ")")==0){ printf "  %s has no row in the table of tools\n", t; bad++ }
  if(index(readme, "\n## " t "\n")==0){    printf "  %s has no ## section\n", t; bad++ }
}
END{ printf "TOOLROW %d\n", bad+0 }
