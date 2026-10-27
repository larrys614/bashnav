#  A GIVE-WAY CALL MUST ANSWER WHAT SHE IS, NOT ONLY WHERE SHE IS.
#
#  Larry, reviewing mot-4 -- a vessel constrained by her draught,
#  crossing from his left to his right, where the program said she must
#  keep out of the way and "You stand on and hold your course":
#
#      "IF she is constrained by her draft, the sidelights dont matter,
#      you give way"
#
#  motion_why() was handed the vessel and never looked at it. Measured
#  across every claim the drill can make, 42 of 73 were about a vessel
#  with a standing under Rule 18 and none mentioned it; nine told the
#  reader to stand on against a vessel he must keep clear of.
#
#  Two things are asserted here, over every vessel and every aspect:
#
#    1. no explanation tells you to stand on against a vessel Rule 18
#       ranks above you, and
#    2. every such explanation names her status, so the reader is told
#       WHY rather than left to infer it from an action.
#
#  Rule 13 is the deliberate exception to nothing: an overtaking vessel
#  keeps clear whatever the other one is, so the overtaking branch is
#  allowed to give the plain answer -- and it still has to name her.
BEGIN{
  ves_init()
  bad = 0; checked = 0; named = 0
  for(v=1;v<=NVES;v++){
    split(VT[v],a,"|")
    st = r18_of(a[1])
    if(st=="") continue
    for(th=0;th<360;th+=15){
      m = motion_of(v,th)
      if(m==5) continue
      w = motion_why(m,v,th)
      checked++
      if(w ~ /You stand on and hold your course/){
        printf "FAIL  %s (%s) at %03d: told to stand on\n", a[1], st, th
        bad++
      }
      #  her status has to be named in words
      if(w ~ /NOT UNDER COMMAND|RESTRICTED IN HER ABILITY|ENGAGED IN FISHING|UNDER SAIL|CONSTRAINED BY HER DRAUGHT|WIG CRAFT|BEING TOWED|under tow|constrained by her draught/)
        named++
      else {
        printf "FAIL  %s (%s) at %03d: her standing is never named\n", a[1], st, th
        bad++
      }
    }
  }
  if(bad){ printf "  %d bad of %d\n", bad, checked; exit 1 }
  printf "  ok  %d give-way calls about a Rule 18 vessel all name her standing, none says stand on\n", checked
}
