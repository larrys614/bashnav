#  A SCENARIO STATES ONE BEARING, AND THE STEM OWNS IT.
#
#  Larry, reviewing enc-15: "She could not be fine on your bow if she is
#  following the lane and you are close enough to be considered crossing,
#  unless she is nearly dead ahead of you.  She might be broad on bow, or
#  forward of your beam I would think."
#
#  He was reading one stem.  Ten of the twenty-eight target descriptions
#  stated a bearing of their own, and the stem then appended a second one
#  drawn at random from the scenario's bearing range -- so the reader was
#  given two bearings for one contact, and in seven of the ten they could
#  contradict each other outright:
#
#      5   the text said fine on your port QUARTER,   the stem could say starboard
#      16  the text said fine on your starboard BOW,  the stem could say beam
#      18  the text said fine on the PORT bow,        the stem could say starboard
#      25  the text said fine on the STARBOARD bow,   the stem could say port
#      6, 11, 22                                      bow against beam
#
#  The bearing was removed from all ten. The stem is the single source,
#  which is also the design the reveal depends on: the arc asks and the
#  number confirms, and a second bearing in the question breaks both
#  halves of that.
#
#  A position that is a SITUATION rather than a bearing stays: "coming up
#  astern" is the overtaking case and is true across that scenario's whole
#  range, and "not moving" and "low down" describe the vessel, not where
#  she is.
BEGIN{
  enc_init()
  bad = 0
  for(i=1;i<=NENC;i++){
    split(EC[i],a,"|")
    t = a[2]
    if(t ~ /dead ahead/ || t ~ /right ahead/ || t ~ /fine on/ || t ~ /broad on/ ||
       t ~ /abaft/ || t ~ /forward of your beam/ || t ~ /ahead and to/ ||
       t ~ /on your (port|starboard) (bow|quarter|beam|side)/ || t ~ /astern of/){
      printf "FAIL  scenario %d states its own bearing: %s\n", i, t
      bad++
    }
  }
  if(bad){ printf "  %d bad\n", bad; exit 1 }
  printf "  ok  no scenario states a bearing its stem will state again (%d checked)\n", NENC
}
