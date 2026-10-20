#  Forbid POSIX interval expressions -- {n}, {n,}, {n,m} -- in awk
#  regular expressions.
#
#  mawk 1.3.3 does not implement them.  It reads {0,4} as four literal
#  characters, so a pattern that is correct POSIX ERE silently matches
#  nothing.  deck-log shipped with /^[a-z][a-z0-9]{0,4}$/ guarding the
#  record type and was therefore COMPLETELY DEAD under that mawk: it
#  rejected every record, refused to write an entry, and read an
#  existing log as empty.  gawk implements intervals, so a gawk run
#  proves nothing about this -- which is why it reached a release.
#
#  Write the repetition out instead:
#      [a-z]([a-z0-9]([a-z0-9]([a-z0-9][a-z0-9]?)?)?)?
#
#  Run over every .awk file in src/.  A { inside a bracket expression is
#  a literal and is fine, so those are stepped over rather than flagged.
{
  line = $0
  sub(/#.*$/, "", line)             # a comment cannot contain a live regex
  n = length(line)
  inre = 0; inbr = 0; prev = ""
  for(i = 1; i <= n; i++){
    c = substr(line, i, 1)
    if(c == "\\"){ i++; continue }
    if(inre){
      if(inbr){ if(c == "]") inbr = 0; continue }
      if(c == "["){ inbr = 1; continue }
      if(c == "/"){ inre = 0; continue }
      if(c == "{"){
        #  {digits} or {digits,} or {digits,digits}
        rest = substr(line, i)
        if(rest ~ /^\{[0-9]+(,[0-9]*)?\}/){
          printf "%s:%d: interval expression in a regex: %s\n", FILENAME, FNR, $0
          BAD++
        }
      }
      continue
    }
    #  A / starts a regex only where a value is expected, which after an
    #  operator, a comma, an open bracket or ~ it is.
    if(c == "/" && (prev == "" || prev == "~" || prev == "(" || prev == "," ||
                    prev == "=" || prev == "!" || prev == "&" || prev == "|")) inre = 1
    if(c != " " && c != "\t") prev = c
  }
}
END{
  if(BAD){ printf "%d interval expression(s) found\n", BAD; exit 1 }
  exit 0
}
