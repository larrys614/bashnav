#  The scoring, which is the part that must be exactly right: it is
#  arithmetic, not meteorology, and there is no excuse for it being off.
function chk(what,got,want){ T++; if(got==want) return 0
  BAD++; printf "  FAIL %s: got [%s] want [%s]\n", what, got, want; return 1 }
BEGIN{
  # ---- error points, from the WxChallenge weights -------------------
  chk("4 knots of wind error is 2 points",   sc_pts("wspd", 20, 24), 2)
  chk("3 mb of pressure error is 3 points",  sc_pts("mslp", 1010, 1013), 3)
  chk("2 sea-state steps is 4 points",       sc_pts("sea", 3, 5), 4)
  chk("40 degrees of wind is 4 points",      sc_pts("wdir", 200, 240), 4)
  chk("a perfect forecast scores 0",         sc_pts("wspd", 20, 20), 0)
  chk("an absent field is not comparable",   sc_pts("wspd", -9999, 20), -1)

  #  DIRECTION IS SCORED ON THE CIRCLE.  350 against 010 is 20 degrees,
  #  not 340. Get this wrong and every forecast near north is scored as
  #  a catastrophe - which would sit there for a season looking like
  #  the forecaster being bad at north.
  chk("350 against 010 is 2 points",  sc_pts("wdir", 350, 10), 2)
  chk("010 against 350 is 2 points",  sc_pts("wdir", 10, 350), 2)
  chk("000 against 180 is 18 points", sc_pts("wdir", 0, 180), 18)
  bad=0
  for(a=0;a<360;a+=3) for(b=0;b<360;b+=3){
    p = sc_pts("wdir", a, b)
    if(p < 0 || p > 18.0001) bad++
    if(sc_pts("wdir",a,b) != sc_pts("wdir",b,a)) bad++   # symmetric
  }
  chk("wind-direction points are 0..18 and symmetric everywhere", bad, 0)

  # ---- sea state from wind, monotonic ------------------------------
  bad=0; last=-1
  for(w=0; w<=70; w++){ s=sc_sea(w); if(s<last) bad++; last=s
                        if(s<0 || s>9) bad++ }
  chk("sea state rises with wind and stays in 0..9", bad, 0)

  printf "SCORERESULT %d %d\n", T, BAD+0
}
