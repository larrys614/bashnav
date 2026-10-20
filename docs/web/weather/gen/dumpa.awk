#  The answer, which cmd=lessonq prints on its own.
function jq(s){ gsub(/\\/,"\\\\",s); gsub(/'/,"\\'",s); return s }
{ a = a $0 }
#  The record is NOT closed here. A lesson may carry a second tier after
#  the answer, so the generator closes it once it knows whether there is
#  one. Closing it here and again there produced "} },".
END{ printf ", a: '%s',\n", jq(a) }
