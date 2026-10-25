#  Pull the question line out of a lesson as printed in plain mode.
#  Nested quoting in the shell is how a generator becomes unreadable, so
#  this lives in its own file rather than inline.
#  js_dq/js_sq live in docs/web/gen/jsonesc.awk, loaded with -f before
#  this file. The doubling must not happen in gsub's replacement string;
#  see the long note there.
function jq(s){ return js_sq(s) }
/^  Question: / { sub(/^  Question: /, ""); q = $0 }
END{ printf "q: '%s'", jq(q) }
