#  AN ASPECT YOU CANNOT READ MUST NOT BE STATED AS ONE.
#
#  The lights reference, the scenario view and the quiz reveal all end
#  with a line saying where you are standing relative to her. That line
#  came from the TRUE bearing, so it was stated with equal confidence for
#  a vessel showing one all-round white light, from which no side, end or
#  quarter can be read at all. In the reference it is at worst incomplete
#  -- you typed the bearing. In the quiz reveal it is the ANSWER.
#
#  Checked here over every vessel at every degree, in both directions:
#
#    1  where no directional light bears, no definite aspect is claimed;
#    2  where one does, the full aspect is still given -- working the
#       aspect out from her sidelights is the whole skill being drilled,
#       and a check that only tested the first half could be satisfied by
#       saying nothing anywhere.
BEGIN{
  ves_init()
  bad=0; checked=0; mute=0
  for(v=1;v<=NVES;v++){
    split(VT[v],a,"|"); n=split(a[4],L,";")
    for(th=0;th<360;th++){
      dir=0
      for(i=1;i<=n;i++){
        split(L[i],f,",")
        if(arc_vis(f[4],th) && f[4]!="A") dir=1
      }
      s = aspect_line(v,th); checked++
      definite = (s ~ /on her (port|starboard) beam|right ahead of her|right astern of her|broad on her|fine on her/)
      if(!dir){
        mute++
        if(definite){
          printf "FAIL  %s at %03d claims an aspect from all-round lights alone\n  %s\n", a[1],th,s; bad++ }
        #  and it must still say something: silence is not an answer
        if(length(s) < 20){
          printf "FAIL  %s at %03d says nothing about aspect: '%s'\n", a[1],th,s; bad++ }
      } else {
        if(!definite){
          printf "FAIL  %s at %03d has a directional light bearing and gives no aspect\n  %s\n", a[1],th,s; bad++ }
        if(s != aspect_words(th)){
          printf "FAIL  %s at %03d disagrees with aspect_words\n  %s\n  %s\n", a[1],th,s,aspect_words(th); bad++ }
      }
    }
  }
  if(bad){ printf "  %d bad of %d\n", bad, checked; exit 1 }
  printf "  ok  no aspect is claimed from all-round lights alone (%d of %d views), and every other view still gives one\n", mute, checked
}
