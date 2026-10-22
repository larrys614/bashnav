#  THE DRAWN WIND HAS TO AGREE WITH THE WORDS, FOR EVERY SEED.
#
#  Larry, drilling scenario 12: "wind dir not shown".  Rule 12 is decided
#  by which side the wind is on, so a scenario that states windward and
#  leeward in words and draws neither leaves the reader unable to check
#  the premise.  The three sailing scenarios now carry the wind as a
#  tenth field and draw it.
#
#  But the contact's bearing and heading are RANDOMISED per seed, so one
#  wind direction has to hold across the whole range -- and a value that
#  looks right in the first case can contradict the words in the last.
#  This recomputes bearing and heading exactly as enc_show does, and
#  checks the claim the scenario makes about tack and about windward or
#  leeward, over every seed.
#
#  Run as:  awk -f src/colregs/engine.awk -f tests/colregs-wind.awk /dev/null
function tack(wrel){ return (nrm360(wrel)>180 ? "port" : "stbd") }
function within90(a,b){ return (fabs(nrm180(a-b)) < 90) }
BEGIN{
  enc_init()
  #  scenario | my tack | her tack | where she is
  CLAIM[11]="port|stbd|"
  CLAIM[12]="port|port|leeward"
  CLAIM[20]="stbd|stbd|windward"
  bad=0; n=0
  for(k in CLAIM){
    split(EC[k],a,"|")
    split(CLAIM[k],c,"|")
    if(a[10]==""){ printf "  FAIL scenario %d carries no wind field\n", k; bad++; continue }
    w=a[10]+0
    for(sd=1;sd<=300;sd++){
      xsrand(sd); xrand()
      bg=a[3]+0; hi=a[4]+0
      if(hi<bg) hi+=360
      bg=nrm360(bg + xrand()*(hi-bg))
      rng=0.55+xrand()*0.35
      thdg=nrm360(a[5]+0 + (xrand()*30-15))
      n++
      mine = tack(w)
      hers = tack(nrm360(w-thdg))
      if(mine!=c[1]){
        printf "  FAIL scenario %d seed %d: wind %03d puts ME on %s tack, text says %s\n",
               k, sd, w, mine, c[1]; bad++; break }
      if(hers!=c[2]){
        printf "  FAIL scenario %d seed %d: wind %03d and her heading %03d put HER on %s tack, text says %s\n",
               k, sd, w, thdg, hers, c[2]; bad++; break }
      if(c[3]=="leeward" && !within90(nrm360(w+180), bg)){
        printf "  FAIL scenario %d seed %d: she bears %03d, which is not downwind of a wind from %03d\n",
               k, sd, bg, w; bad++; break }
      if(c[3]=="windward" && !within90(w, bg)){
        printf "  FAIL scenario %d seed %d: she bears %03d, which is not upwind of a wind from %03d\n",
               k, sd, bg, w; bad++; break }
    }
  }
  if(bad==0) printf "  ok    the drawn wind agrees with the words (%d scenario-seeds)\n", n
  else       printf "  FAIL  %d sailing scenario(s) contradict their own wind\n", bad
  exit (bad==0?0:1)
}
