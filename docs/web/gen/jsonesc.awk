#  Escaping text for a generated JavaScript or JSON file, portably.
#
#  Loaded with -f before any of the dumpers under docs/web/*/gen/, and by
#  tests/review-pack.awk.  Every one of them used to carry its own copy of
#
#      gsub(/\\/,"\\\\",s); gsub(/"/,"\\\"",s); gsub(/\n/,"\\n",s)
#
#  and all nine were wrong in the same way: THE DOUBLING HAPPENS IN GSUB'S
#  REPLACEMENT STRING, which is where awk builds stop agreeing.  POSIX
#  defines only '&' and '\&' there; a backslash before anything else is
#  left to the implementation, and they differ.  Given one backslash:
#
#      mawk 1.3.4 20240123, gawk, one-true-awk   ->  \\   correct
#      mawk 1.3.4 20200120                       ->  \    one short
#
#  That older mawk was Debian and Ubuntu's for years, so on a perfectly
#  ordinary machine every generator wrote a silently wrong file: a lesson
#  showing a shell line continuation lost its backslash and rendered a
#  literal \n with no line break.  Worse than wrong output, the failure
#  has a trap in it - the suite then reports "lessons.js is not what
#  teach.awk prints, run the generator", and doing what it says commits
#  the broken version.
#
#  SPLIT IS NOT THE WAY OUT EITHER, which cost a round to find out.
#  split(s, p, "\\") looks like it avoids the replacement rules, and it
#  does, but one-true-awk compiles a single-character separator as a
#  REGEX, and a lone backslash as a regex is a dangling escape: it split
#  on newlines too, and turned every line break into a pair of
#  backslashes.
#
#  So js_sub() uses index() and substr() and nothing else.  index() is a
#  plain string search with no regex anywhere, substr() a plain cut, and
#  the replacement is built by concatenating string LITERALS, whose
#  escapes the lexer resolves - which is well defined everywhere.  Checked
#  identical under mawk 1.3.4 20200120, mawk 1.3.4 20240123, gawk 5.1,
#  gawk 5.2 and one-true-awk; tests/jsonesc-check.awk holds it there.
function js_sub(s, from, to,   out,p){
  out = ""
  while((p = index(s, from)) > 0){
    out = out substr(s, 1, p - 1) to
    s = substr(s, p + length(from))
  }
  return out s
}

#  For a "double-quoted" JSON string holding a lesson body: a real newline
#  inside a JSON string is an invalid control character rather than a line
#  break, so it becomes \n, and tabs become spaces because the pages set
#  their own columns.
function js_dq(s){
  s = js_sub(s, "\\", "\\" "\\")
  s = js_sub(s, "\"", "\\" "\"")
  s = js_sub(s, "\t", " ")
  s = js_sub(s, "\n", "\\" "n")
  return s
}

#  The same, but with newlines flattened to spaces - for one-line prose
#  where the line breaks carry nothing.
function js_dq_flat(s){
  s = js_sub(s, "\\", "\\" "\\")
  s = js_sub(s, "\"", "\\" "\"")
  s = js_sub(s, "\n", " ")
  return s
}

#  The same, leaving newlines alone - for a caller that assembles its own
#  lines and appends the \n itself.
function js_dq_raw(s){
  s = js_sub(s, "\\", "\\" "\\")
  s = js_sub(s, "\"", "\\" "\"")
  return s
}

#  For a 'single-quoted' JavaScript string.
function js_sq(s){
  s = js_sub(s, "\\", "\\" "\\")
  s = js_sub(s, "'", "\\" "'")
  return s
}
