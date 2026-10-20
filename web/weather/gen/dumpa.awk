#  The answer, which cmd=lessonq prints on its own.
function jq(s){ gsub(/\\/,"\\\\",s); gsub(/'/,"\\'",s); return s }
{ a = a $0 }
END{ printf ", a: '%s' },\n", jq(a) }
