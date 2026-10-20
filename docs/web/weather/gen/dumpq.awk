#  Pull the question line out of a lesson as printed in plain mode.
#  Nested quoting in the shell is how a generator becomes unreadable, so
#  this lives in its own file rather than inline.
function jq(s){ gsub(/\\/,"\\\\",s); gsub(/'/,"\\'",s); return s }
/^  Question: / { sub(/^  Question: /, ""); q = $0 }
END{ printf "q: '%s'", jq(q) }
