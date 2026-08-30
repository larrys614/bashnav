# =====================================================================
#  weather -- reasoning over a 500 mb chart the user is holding.
#
#  The app cannot fetch a chart and never will.  But a 500 mb chart
#  arrives by HF RADIOFAX, on an SSB receiver, at sea, with no
#  connectivity at all - which is exactly the situation the rest of
#  bashnav is built for.  So this is the reasoning layer over a fax:
#  read three numbers off it and the rules do the rest, showing every
#  step.
#
#  Rules from Sienkiewicz & Chesneau, Mariner's Guide to the
#  500-Millibar Chart, NOAA - public domain.  See docs/SOURCES.md.
# =====================================================================
function ch_say(s){ printf "  %s\n", s; return 0 }
function ch_why(s){ printf "  %s\n", cwd("   " s); return 0 }

#  brg    bearing FROM you TO the nearest point of the 564 line
#  dist   its distance in nm
#  orient the line's own orientation, as a bearing (either end)
#  w500   the 500 mb wind speed there, knots
#  north  1 northern hemisphere, 0 southern
function ch_report(brg, dist, orient, w500, north,   pole, side, mn, mx, smn, smx){
  print ""
  printf "  %s\n", cw("FROM THE 500 MILLIBAR CHART", C_ACC)
  hr()
  pole = north ? "north" : "south"

  if(dist=="" || brg==""){
    ch_say("Give me where the 564 line runs and I will walk the rules.")
    print ""
    return 0
  }
  ch_say(sprintf("The 5640 m contour is %g nm away, bearing %03d, lying %03d/%03d.",
         dist+0, brg+0, orient+0, (orient+180)%360))
  print ""

  # ---- 1. the storm track -------------------------------------------
  ch_say(cw("The surface storm track", C_ACC) sprintf(" runs parallel to that line, %s of it,", pole))
  ch_say("between 300 and 600 nm away from it.")
  ch_why("so the depressions are travelling along " sprintf("%03d/%03d", orient+0, (orient+180)%360) ", not toward you")

  # ---- 2. the gale boundary, which is the one that matters ----------
  print ""
  ch_say(cw("All the gale force winds are on the " pole " side of the 564 line.", C_WARN))
  if(ch_poleward(brg, north)){
    ch_say(cw("You are on the equatorward side of it. That is the right side.", C_OK))
    ch_why("stay there and you stay out of the gales - that is the routing rule,")
    ch_why("and it is why the standard book on this is called Heavy Weather Avoidance")
  } else {
    ch_say(cw("The line is equatorward of you, so you are on the gale side of it.", C_WARN))
    ch_why("getting equatorward of the 564 line is the single most useful thing")
    ch_why("you can do about the weather from here")
  }

  # ---- 3 and 4. speed and strength, if the wind was read ------------
  if(w500!=""){
    print ""
    mn = (w500+0)/3.0; mx = (w500+0)/2.0
    ch_say(sprintf("At %g knots aloft, systems below move at %.0f to %.0f knots.",
           w500+0, mn, mx))
    ch_why("a surface low or front travels at a third to a half of the 500 mb wind")
    if(dist+0 > 0){
      ch_say(sprintf("So a system 300 nm off would be on you in %.0f to %.0f hours.",
             300.0/mx, 300.0/mn))
    }
    print ""
    ch_say(sprintf("Behind it, in the cold air, expect about %.0f knots on deck.", (w500+0)/2.0))
    ch_why("surface wind in the west-to-southwest quadrant is about half the 500 mb")
    ch_why("wind - which is the number that decides what sail you are carrying")
  }
  hr()
  printf "  %s\n", cwd("Rules from Sienkiewicz and Chesneau, Mariner's Guide to the")
  printf "  %s\n", cwd("500-Millibar Chart, NOAA. They are rules of thumb: good ones,")
  printf "  %s\n", cwd("and still rules of thumb.")
  print ""
  return 0
}
#  Is the 564 line on my POLEWARD side?  If it bears north of me in the
#  northern hemisphere, I am equatorward of it, which is where I want
#  to be.
function ch_poleward(brg, north,   b){
  b = brg+0
  while(b<0) b+=360
  while(b>=360) b-=360
  if(north) return (b < 90 || b > 270)     # the line lies to my north
  return (b > 90 && b < 270)               # southern: to my south
}
