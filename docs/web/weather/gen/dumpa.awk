#  The answer, which cmd=lessonq prints on its own.
#  js_dq/js_sq live in docs/web/gen/jsonesc.awk, loaded with -f before
#  this file. The doubling must not happen in gsub's replacement string;
#  see the long note there.
function jq(s){ return js_sq(s) }
{ a = a $0 }
#  The record is NOT closed here. A lesson may carry a second tier after
#  the answer, so the generator closes it once it knows whether there is
#  one. Closing it here and again there produced "} },".
END{ printf ", a: '%s',\n", jq(a) }
