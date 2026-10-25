#  docs/web/gen/jsonesc.awk must give the SAME answer on every awk.
#
#  Nine generators used to escape their own text with
#  gsub(/\\/,"\\\\",s), which does the doubling inside gsub's REPLACEMENT
#  string - the one place POSIX leaves backslashes to the implementation.
#  mawk 1.3.4 20200120, which Debian and Ubuntu shipped for years, emits
#  one backslash where every other build emits two, so on an ordinary
#  machine every generated file came out silently wrong. Nothing in the
#  suite could see it, because the suite compares a generated file against
#  what the generator just produced on the SAME awk.
#
#  This holds the escaper to a literal answer instead, so an awk that
#  disagrees fails here by name rather than by writing a bad file.
#
#  THE EXPECTED VALUES ARE WRITTEN IN A SAFE ALPHABET. A check for
#  escaping that spells its own expectations with backslashes is resting
#  on the thing it is testing; vis() rewrites the result into <BS>, <DQ>,
#  <SQ>, <NL> and <TAB>, so every expectation below is plain ASCII.
function vis(s,   i,c,r){
  r = ""
  for(i = 1; i <= length(s); i++){
    c = substr(s, i, 1)
    if(c == "\\")      r = r "<BS>"
    else if(c == "\"") r = r "<DQ>"
    else if(c == "'")  r = r "<SQ>"
    else if(c == "\n") r = r "<NL>"
    else if(c == "\t") r = r "<TAB>"
    else               r = r c
  }
  return r
}
function want(tag, got, expect){
  nchk++
  if(vis(got) != expect){
    printf "  %s disagrees\n    expected  %s\n    got       %s\n", tag, expect, vis(got)
    bad++
  }
}
BEGIN{
  #  one of everything that has to be escaped, in one string
  s = "a" "\\" "b" "\"" "c" "'" "d" "\t" "e" "\n" "f"
  want("js_dq",      js_dq(s),      "a<BS><BS>b<BS><DQ>c<SQ>d e<BS>nf")
  want("js_sq",      js_sq(s),      "a<BS><BS>b<DQ>c<BS><SQ>d<TAB>e<NL>f")
  want("js_dq_flat", js_dq_flat(s), "a<BS><BS>b<BS><DQ>c<SQ>d<TAB>e f")
  want("js_dq_raw",  js_dq_raw(s),  "a<BS><BS>b<BS><DQ>c<SQ>d<TAB>e<NL>f")

  #  and the two shapes that actually bit. A shell line continuation at
  #  the end of a line is the one in celnav lesson S8: the backslash must
  #  survive doubling AND be followed by an escaped newline, which is
  #  three backslashes in a row in the output and was two.
  want("continuation", js_dq("sun -2 " "\\" "\n" "   x"),
       "sun -2 <BS><BS><BS>n   x")
  want("adjacent",     js_dq("a" "\\" "\\" "b"), "a<BS><BS><BS><BS>b")

  #  nothing to escape must come back untouched, and the empty string
  #  must not become something
  want("plain", js_dq("plain words"), "plain words")
  want("empty", js_dq(""), "")

  printf "JSONESC %d of %d\n", bad+0, nchk+0
}
