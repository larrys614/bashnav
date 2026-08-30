#  The install section must name every tool in bin/, and must tell an
#  iPad user the three things they actually need.
#
#  It said "both tools" long after there were four, and it told an iPad
#  user to git clone without saying how to get a shell in the first
#  place - which sent Larry to a search engine that answered about
#  Android APK files, because nothing in the instructions said these are
#  scripts rather than an app.
#
#  A stale install section is the first thing a new person hits and the
#  last thing the person who wrote it ever reads.
FNR==NR { readme = readme $0 "\n"; next }
{
  t = $0
  hit = 0
  if(index(readme, "bin/" t) > 0) hit = 1
  if(index(readme, " " t " ") > 0) hit = 1
  if(index(readme, "/" t) > 0) hit = 1
  if(!hit){ printf "  the install instructions never mention %s\n", t; bad++ }
}
END{
  if(index(readme, "a-Shell") == 0){
    print "  the install section does not name a shell for iOS"; bad++ }
  if(index(readme, "no app to install") == 0){
    print "  the install section does not say these are scripts, not an app"; bad++ }
  if(index(readme, "~/Documents") == 0){
    print "  the install section does not say where iOS lets you write"; bad++ }
  printf "INSTALL %d\n", bad+0
}
