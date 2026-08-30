# =====================================================================
#  weather -- the lessons.
#
#  THE ORGANISING RULE, and it is the reason this file is not longer:
#
#     Every piece of physics has to earn its place by changing what the
#     app says or what you would do.  Otherwise it is a lecture with a
#     barometer attached.
#
#  Ordered from what you can see today outward to why the planet works
#  this way.  Each lesson ends with a question, as in colregs.
#  Sources are in docs/SOURCES.md; nothing here is copied from anywhere.
# =====================================================================

function les_init(){
  if(LES_READY) return
  LS_N=0
  les("fluid",    "Air is a fluid, and moist air is lighter")
  les("data",     "The three kinds of weather data, and which one you have")
  les("tide",     "The atmospheric tide: why the glass falls every afternoon")
  les("coriolis", "Coriolis, which is not a force")
  les("gradient", "Gradient wind, surface wind, and friction")
  les("lapse",    "Lapse rates, stability, and where the cloud base is")
  les("cells",    "The heat engine, and the three cells")
  les("h500",     "The 500 millibar chart and the 564 line")
  les("cyclone",  "How a tropical cyclone is made, and how to keep away")
  les("seasons",  "The tilt, the seasons, and an honest boundary")
  LES_READY=1
  return 0
}
function les(k,t){ LS_N++; LS_K[LS_N]=k; LS_T[LS_N]=t; return 0 }

function lp(s){ printf "  %s\n", s; return 0 }
function lpd(s){ printf "  %s\n", cwd(s); return 0 }
function lph(s){ print ""; printf "  %s\n", cw(s,C_ACC); hr(); return 0 }

function lesson_body(k){
  # ------------------------------------------------------------------
  if(k=="fluid"){
    lph("AIR IS A FLUID, AND MOIST AIR IS LIGHTER")
    lp("Air is a fluid. At the speeds anything on a boat moves it barely")
    lp("compresses, so it behaves very much like water - and the weather is")
    lp("fluid dynamics happening to a very large, very thin bath.")
    print ""
    lp(cw("And here is the counterintuitive one:",C_ACC))
    print ""
    lp("  " cw("Warm MOIST air is LIGHTER than warm DRY air.",C_ACC))
    print ""
    lp("Humid air feels heavy. It is not. At the same temperature and pressure")
    lp("a given volume holds a fixed NUMBER of molecules - so water vapour does")
    lp("not add molecules to the box, it " cw("replaces",C_ACC) " them:")
    print ""
    lp("       H2O  18      pushing out      N2  28")
    lp("                                     O2  32")
    print ""
    lp("Every water molecule that goes in evicts something heavier. Same count,")
    lp("less mass, lower density.")
    print ""
    lp(cw("This is the engine of everything else.",C_ACC) " Warm moist air is buoyant")
    lp("twice over - once for being warm, once for being wet - which is why the")
    lp("tropics convect so violently, and why a thunderstorm is a heat engine")
    lp("rather than a wind event.")
    print ""
    return 1
  }
  # ------------------------------------------------------------------
  if(k=="data"){
    lph("THE THREE KINDS OF WEATHER DATA")
    lp("Most sailors never learn this, and it decides how much to believe.")
    print ""
    lp(cw("OBSERVATION",C_ACC) "   an instrument reading of what is happening now.")
    lp("               Not a forecast - but it is " cw("true",C_ACC) ".")
    print ""
    lp(cw("ANALYSIS",C_ACC) "      a chart drawn from observations and then edited and")
    lp("               verified " cw("by a human forecaster",C_ACC) ". A surface analysis,")
    lp("               most national weather service products. The best")
    lp("               available picture of NOW.")
    print ""
    lp(cw("MODEL OUTPUT",C_ACC) "  a computer's projection. What sailors call a GRIB.")
    lp("               " cw("Nobody has looked at it.",C_NO))
    print ""
    lp("The trap is the third. A GRIB arrives in colour, at high resolution, out")
    lp("to seven days, looking authoritative - and it is a machine's")
    lp("extrapolation with no human in the loop. Sailors treat it as gospel.")
    lp("The rule: check you are looking at an analysis, not a model run.")
    print ""
    lp(cw("And it places this tool honestly.",C_ACC) " It works entirely in the first")
    lp("column. Every number in it is something you measured. It cannot")
    lp("forecast - but what it reasons FROM is the one category that is never")
    lp("wrong, and the only one still there when the antenna comes down.")
    print ""
    return 1
  }
  # ------------------------------------------------------------------
  if(k=="tide"){
    lph("THE ATMOSPHERIC TIDE")
    lp("The sun heats the air, the earth turns under it, and a pressure wave")
    lp("travels westward with the sun. It is on your barometer, every day.")
    print ""
    lp("The odd part: the dominant component is " cw("SEMIdiurnal - twice a day",C_ACC) ",")
    lp("not once. Why once-a-day heating produces a twice-a-day pressure signal")
    lp("is a genuine puzzle in meteorology.")
    print ""
    lp("  amplitude in the tropics     about 1.4 hPa")
    lp("  maxima                       about 1000 and 2200 local")
    lp("  minima                       about 0400 and " cw("1600",C_ACC) " local")
    lp("  and it falls off steeply    ~1.2 hPa at the equator, ~0.2 at 45 deg")
    print ""
    lp(cw("Which is a trap worth knowing about.",C_WARN) " In the tropics the glass")
    lp("falls two to three millibars between mid-morning and mid-afternoon")
    lp(cw("every single day, in perfect weather.",C_ACC) " A sailor who does not know")
    lp("that reads a routine afternoon fall as a system approaching.")
    print ""
    lpd("This app corrects for it before saying anything about tendency, and")
    lpd("tells you how much of the change was the tide. Give it your longitude")
    lpd("- it needs local solar time to know where in the cycle you are.")
    print ""
    return 1
  }
  # ------------------------------------------------------------------
  if(k=="coriolis"){
    lph("CORIOLIS, WHICH IS NOT A FORCE")
    lp("The earth turns underneath you. Describe anything's motion relative to")
    lp("the ground and it appears to curve. The \"force\" is the bookkeeping")
    lp("entry for having chosen a rotating frame - nothing is pushing.")
    print ""
    lp("Its size goes as " cw("sin(latitude)",C_ACC) ":")
    print ""
    lp("  at the poles     full strength")
    lp("  at 45 degrees    about 0.7 of it")
    lp("  " cw("at the equator   ZERO",C_ACC))
    print ""
    lp(cw("Two things it buys you.",C_ACC))
    print ""
    lp("First: " cw("no tropical cyclone forms within about 5 degrees of the",C_ACC))
    lp(cw("equator",C_ACC) ", because there is nothing there to spin it up. All that heat")
    lp("and moisture and no rotation.")
    print ""
    lp("Second: it is half of Buys Ballot, which is the most useful rule this")
    lp("app has. Stand with your back to the wind and the low is on your left")
    lp("in the northern hemisphere - and on your right in the southern, because")
    lp("the sense of the rotation reverses.")
    print ""
    return 1
  }
  # ------------------------------------------------------------------
  if(k=="gradient"){
    lph("GRADIENT WIND, SURFACE WIND, AND FRICTION")
    lp("Well above the sea the wind balances the pressure gradient against")
    lp("Coriolis and runs " cw("along",C_ACC) " the isobars. That is the gradient wind, and")
    lp("it is what a weather chart draws.")
    print ""
    lp("Down where you are, friction slows the air. Slower air feels less")
    lp("Coriolis. So pressure wins a little, and the surface wind blows")
    lp(cw("across",C_ACC) " the isobars, toward the low:")
    print ""
    lp("  over water   backed 10-20 degrees, and about 2/3 of gradient speed")
    lp("  over land    backed 30-40 degrees, and slower still")
    lp("  " cw("southern hemisphere: veered, not backed",C_ACC))
    print ""
    lp(cw("This is the chart-to-deck translation",C_ACC) " - what the isobars mean for")
    lp("what you will actually get on the wind instrument.")
    print ""
    lp("And the same boundary layer does something else you already know about.")
    lp("Friction slows the lowest air, so wind speed climbs with height, and")
    lp("the apparent wind aloft is stronger and further aft than at the boom.")
    lp("That is why a sail is " cw("twisted",C_ACC) ". One piece of physics, two apps.")
    print ""
    return 1
  }
  # ------------------------------------------------------------------
  if(k=="lapse"){
    lph("LAPSE RATES, STABILITY, AND THE CLOUD BASE")
    lp("Air cools as it rises, because it expands. How fast is the whole game.")
    print ""
    lp("  " cw("dry adiabatic",C_ACC) "     about 3.0 C per 1000 ft   an unsaturated parcel")
    lp("  " cw("saturated",C_ACC) "         about 1.5 C per 1000 ft   condensing gives heat back")
    lp("  " cw("environmental",C_ACC) "     whatever the air actually does - measured")
    print ""
    lp("Compare the environmental rate with the adiabatic and you have")
    lp(cw("stability",C_ACC) ". If the surrounding air cools FASTER with height than the")
    lp("parcel does, the parcel stays warmer than its surroundings, keeps")
    lp("rising, and you get towering cloud. That is instability, and it is why")
    lp("a saturated parcel can keep going where a dry one would have stopped.")
    print ""
    lp(cw("THE CLOUD BASE",C_ACC) " falls straight out of it, and the arithmetic is")
    lp("something you can do on deck:")
    print ""
    lp("  a rising parcel cools at         3.0 C / 1000 ft")
    lp("  its dew point falls at           0.5 C / 1000 ft")
    lp("  " cw("so the spread closes at          2.5 C / 1000 ft",C_ACC))
    print ""
    lp("  " cw("height (ft) = (air temp - dew point, in C) x 400",C_ACC))
    print ""
    lp("400, not 333. " cw("It is not the lapse rate, it is the DIFFERENCE",C_WARN) " between")
    lp("two of them. Divide by the lapse rate alone and you put the base a")
    lp("fifth too low. And it is " cw("air",C_ACC) " temperature, not sea temperature - the")
    lp("sea is a fair proxy offshore and badly wrong near a front.")
    print ""
    lp("A field of cumulus with flat bases all at one height IS that level made")
    lp("visible. Above it, the " cw("trade inversion",C_ACC) " caps the marine layer, and the")
    lp("flat tops are you looking at the underside of the lid.")
    print ""
    return 1
  }
  # ------------------------------------------------------------------
  if(k=="cells"){
    lph("THE HEAT ENGINE, AND THE THREE CELLS")
    lp("The tropics take in more energy from the sun than they radiate away.")
    lp("The poles do the reverse. The atmosphere and the ocean exist, as far as")
    lp("weather is concerned, to move the difference poleward.")
    print ""
    lp("Most of the atmosphere's share travels as " cw("latent heat",C_ACC) " - water")
    lp("evaporated in the tropics and released as rain somewhere else. The")
    lp("water cycle is not a side effect of the weather. It is the working")
    lp("fluid.")
    print ""
    lp("  " cw("Hadley",C_ACC) "    rises at the equator, descends near 30 degrees")
    lp("  " cw("Ferrel",C_ACC) "    30 to 60, and the one you probably sail in")
    lp("  " cw("Polar",C_ACC) "     60 to the pole")
    print ""
    lp("The air descending at 30 degrees has already rained out everything it")
    lp("had, so it arrives warm and dry. That gives you the subtropical highs,")
    lp("the horse latitudes, the trade winds on their equatorward side - and")
    lp("most of the world's deserts sit at that latitude for this reason.")
    print ""
    lp(cw("And it closes the loop with the last lesson:",C_ACC) " that same descending")
    lp("warm air is the inversion capping the marine layer. The lid over your")
    lp("flat-topped cumulus is the far end of a circulation that started as")
    lp("thunderstorms on the equator.")
    print ""
    return 1
  }
  # ------------------------------------------------------------------
  if(k=="h500"){
    lph("THE 500 MILLIBAR CHART, AND THE 564 LINE")
    lp("A 500 mb chart is a " cw("topographic map of a pressure surface",C_ACC) ": the")
    lp("contours are the HEIGHT at which the pressure is 500 millibars, drawn")
    lp("in decametres. So \"564\" means the 5,640 metre contour. Low heights are")
    lp("cold air, high heights are warm.")
    print ""
    lp("It is around 18,000 feet, with about half the atmosphere's mass above")
    lp("and half below - which is why its flow is a fair proxy for where a")
    lp("whole system gets carried. The " cw("steering level",C_ACC) ".")
    print ""
    lp(cw("Five rules a mariner can use from one chart:",C_ACC))
    print ""
    lp("  " cw("1.",C_ACC) " The surface storm track lies " cw("300 to 600 nm poleward",C_ACC) " of the")
    lp("     5640 m contour, and runs " cw("parallel",C_ACC) " to it.")
    print ""
    lp("  " cw("2.",C_ACC) " " cw("All the gale force winds are poleward of the 564 line.",C_WARN))
    lp("     Stay on its equatorward side and you stay out of the gales. This")
    lp("     is the routing rule, and it is why the standard book on the")
    lp("     subject is called Heavy Weather Avoidance.")
    print ""
    lp("  " cw("3.",C_ACC) " Surface lows and fronts move at " cw("a third to a half",C_ACC) " of the")
    lp("     500 mb wind speed above them.")
    print ""
    lp("  " cw("4.",C_ACC) " Surface wind behind the system, in the cold air to the west")
    lp("     and southwest, is about " cw("half",C_ACC) " the 500 mb wind speed.")
    print ""
    lp("  " cw("5.",C_ACC) " Tighter contours mean stronger wind - the upper-air version of")
    lp("     close isobars. And the " cw("588",C_ACC) " contour marks the subtropical ridge,")
    lp("     which is what steers tropical systems.")
    print ""
    lp(cw("You do not need the internet for this.",C_ACC) " A 500 mb chart comes in by HF")
    lp("radiofax, on an SSB receiver, at sea, with no connectivity at all. Read")
    lp("three numbers off it and " cw("weather chart",C_ACC) " will walk the rules with you.")
    print ""
    lpd("From the Mariner's Guide to the 500-Millibar Chart, by Joe Sienkiewicz")
    lpd("of NOAA's Ocean Prediction Center and Lee Chesneau - US Navy, then OPC,")
    lpd("who spent his retirement teaching this to sailors. See docs/SOURCES.md.")
    print ""
    return 1
  }
  # ------------------------------------------------------------------
  if(k=="cyclone"){
    lph("HOW A TROPICAL CYCLONE IS MADE, AND HOW TO KEEP AWAY")
    lp("This is the payoff for the other lessons: it needs all of them.")
    print ""
    lp("  " cw("warm deep water",C_ACC) "    about 26.5 C, and 50 m deep, or the storm")
    lp("                     stirs up cold water and kills itself")
    lp("  " cw("enough Coriolis",C_ACC) "    so not within ~5 degrees of the equator")
    lp("  " cw("a moist unstable column",C_ACC) "  moist air is buoyant twice over")
    lp("  " cw("weak wind shear",C_ACC) "    or the tower is torn apart before it organises")
    lp("  " cw("something to start it",C_ACC) "  a wave, a trough, an old front")
    print ""
    lp("Take any one away and you get a lot of rain and no cyclone. Which is")
    lp("useful: it tells you which conditions to worry about.")
    print ""
    lp(cw("AND AVOIDANCE IS A PROBLEM YOU ALREADY KNOW.",C_ACC))
    print ""
    lp("A storm centre has a position, a course and a speed. So do you. You")
    lp("want the largest possible closest point of approach. " cw("That is exactly",C_ACC))
    lp(cw("the relative-motion problem from colregs",C_ACC) " - the same vector triangle,")
    lp("the same bearing drift, the same answer. The dangerous semicircle is")
    lp("just the half where the storm's own motion adds to its wind.")
    print ""
    lpd("Which is why the tools in this suite keep turning out to be the same")
    lpd("few ideas wearing different hats.")
    print ""
    return 1
  }
  # ------------------------------------------------------------------
  if(k=="seasons"){
    lph("THE TILT, THE SEASONS, AND AN HONEST BOUNDARY")
    lp("The earth's axis leans " cw("23.5 degrees",C_ACC) " and keeps pointing the same way")
    lp("as it goes round. So each hemisphere leans toward the sun for half the")
    lp("year. That is the whole of the seasons - not distance from the sun,")
    lp("which barely varies and is at its smallest in northern winter.")
    print ""
    lp("What it buys you at sea: the whole belt of weather migrates north and")
    lp("south with it. The equatorial convergence, the subtropical ridge, the")
    lp("storm tracks. " cw("A cyclone season is a season because the tilt makes it",C_ACC))
    lp(cw("one",C_ACC) " - warm water and a ridge in the right place at the same time.")
    print ""
    lp(cw("Now the honest part.",C_ACC))
    print ""
    lp("The axis also wobbles, a full circle every 26,000 years, and the orbit")
    lp("stretches and relaxes on cycles of 100,000. Those are real and they")
    lp("drive ice ages.")
    print ""
    lp("They are " cw("climate, not weather",C_ACC) ", and " cw("nothing on your passage depends",C_ACC))
    lp(cw("on them.",C_ACC) " They are in this lesson because they are interesting and")
    lp("because you asked, and they are labelled so you know which is which.")
    print ""
    lpd("Every other lesson here earns its place by changing what you would do.")
    lpd("This half of this one does not, and pretending otherwise would be the")
    lpd("beginning of a tool full of things that sound like knowledge.")
    print ""
    return 1
  }
  return 0
}
function lesson_q(k){
  if(k=="fluid")    return "It is 30 C and very humid. Is that air heavier or lighter than 30 C and dry?|Lighter. Water molecules at 18 replace nitrogen at 28 and oxygen at 32, and a given volume holds a fixed number of molecules. Warm and wet is buoyant twice over, which is what builds thunderstorms."
  if(k=="data")     return "A seven-day GRIB and a 24-hour surface analysis disagree. Which do you believe?|The analysis. A human forecaster has looked at it and corrected it. The GRIB is a machine's extrapolation that nobody has seen, and the further out it runs the less it is worth."
  if(k=="tide")     return "You are at 12N. The glass has fallen 2 hPa between 1000 and 1600. Worry?|Probably not - that is very close to the daily atmospheric tide, which is about 1.4 hPa of semidiurnal swing in the tropics with a minimum near 1600. Correct for it before reading anything into it. At 50N the same fall would mean much more."
  if(k=="coriolis") return "Why does no hurricane ever form on the equator?|Coriolis goes as sin(latitude) and is zero there. All the heat and moisture in the world, and nothing to start it rotating. About 5 degrees is the practical minimum."
  if(k=="gradient") return "The chart shows a 30 knot gradient wind. What do you expect on deck, offshore, in the northern hemisphere?|Around 20 knots - roughly two thirds - and backed 10 to 20 degrees from the isobar direction, because friction slows the surface air, which weakens Coriolis, so pressure gradient wins a little and the wind blows across the isobars toward the low."
  if(k=="lapse")    return "Air 18 C, dew point 12 C. How high is the cloud base?|About 2,400 ft: a spread of 6 C, and the spread closes at 2.5 C per 1000 ft, so 6 x 400. Not 6 x 333 - the divisor is the DIFFERENCE between the parcel's lapse rate and the dew point's, not the lapse rate itself."
  if(k=="cells")    return "Why are so many of the world's deserts near 30 degrees latitude?|That is where the Hadley cell descends. The air rose at the equator, rained out everything it had, and comes back down warm and dry. The subtropical highs, the horse latitudes and the deserts are all the same descending branch."
  if(k=="h500")     return "The 564 line runs east-west 200 nm north of you. Where is the storm track, and are you in the gales?|The track is 300 to 600 nm poleward of the 564 line and parallel to it, so well north of you. And all the gale force winds are poleward of that line - so at 200 nm south of it you are on the right side of it. That is the routing rule."
  if(k=="cyclone")  return "Sea surface 27 C, moist unstable air, a nice tropical wave - and 40 knots of shear aloft. Cyclone?|No. Shear tears the tower apart before it can organise. Four of the five ingredients is not a storm, which is exactly why knowing the list is useful."
  if(k=="seasons")  return "Northern winter is when the earth is CLOSEST to the sun. So why is it cold?|Because the seasons are the 23.5 degree tilt, not the distance. The northern hemisphere is leaning away, so the sun is low, the days are short, and the same energy is spread over more ground. The distance varies by about 3 percent and is swamped by it."
  return ""
}
