# =====================================================================
#  celnav teaching module
#  Loaded alongside engine.awk.  Everything here is drawing and text;
#  all the astronomy comes from the engine, so a lesson and the working
#  tool can never disagree.
# =====================================================================

# ---------------------------------------------------------------------
#  Orthographic globe.  Sets up a view centred on (lat0,lon0) and draws
#  points, small circles and graticule on the shared canvas.
# ---------------------------------------------------------------------
function gl_init(w,h,lat0,lon0,   i){
  GL_W=w; GL_H=h; GL_CX=int(w/2); GL_CY=int(h/2)
  GL_RX=GL_CX-1; GL_RY=GL_CY-1
  GL_LAT0=lat0; GL_LON0=lon0
  gclear(w,h)
  return 0
}
# project: sets GL_R (row), GL_C (col), GL_VIS (1 if on the near side)
function gl_proj(lat,lon,   x,y,z,dl){
  dl=lon-GL_LON0
  x = cosd(lat)*sind(dl)
  y = cosd(GL_LAT0)*sind(lat) - sind(GL_LAT0)*cosd(lat)*cosd(dl)
  z = sind(GL_LAT0)*sind(lat) + cosd(GL_LAT0)*cosd(lat)*cosd(dl)
  GL_VIS = (z >= -0.02)
  GL_C = GL_CX + x*GL_RX
  GL_R = GL_CY - y*GL_RY
  return GL_VIS
}
function gl_limb(   t){
  for(t=0;t<360;t+=0.45) gput(GL_CY-GL_RY*cosd(t), GL_CX+GL_RX*sind(t), ".")
  return 0
}
function gl_graticule(full,   la,lo){
  for(lo=-180;lo<180;lo+=1.5){ if(gl_proj(0,lo)) gputw(GL_R,GL_C,"-") }
  if(full){
    for(la=-60;la<=60;la+=30){ if(la==0) continue
      for(lo=-180;lo<180;lo+=3){ if(gl_proj(la,lo)) gputw(GL_R,GL_C,"'") } }
    for(lo=-180;lo<180;lo+=45)
      for(la=-84;la<=84;la+=3){ if(gl_proj(la,lo)) gputw(GL_R,GL_C,"'") }
  }
  return 0
}
# a small circle of angular radius rad (degrees) about (clat,clon)
function gl_circle(clat,clon,rad,ch,   b,la,lo){
  for(b=0;b<360;b+=0.5){
    la = asind(sind(clat)*cosd(rad) + cosd(clat)*sind(rad)*cosd(b))
    lo = clon + atan2d(sind(b)*sind(rad)*cosd(clat), cosd(rad)-sind(clat)*sind(la))
    if(gl_proj(la,lo)) gput(GL_R,GL_C,ch)
  }
  return 0
}
function gl_mark(lat,lon,ch){
  if(gl_proj(lat,lon)) gput(GL_R,GL_C,ch)
  return 0
}
function gl_label(lat,lon,s,dc,dr){
  if(gl_proj(lat,lon)) gputs(GL_R+dr, GL_C+dc, s)
  return 0
}

# point at angular distance d on bearing b from (lat,lon) -> DP_LAT, DP_LON
function dest(lat,lon,b,d){
  DP_LAT = asind(sind(lat)*cosd(d) + cosd(lat)*sind(d)*cosd(b))
  DP_LON = lon + atan2d(sind(b)*sind(d)*cosd(lat), cosd(d)-sind(lat)*sind(DP_LAT))
  return DP_LAT
}
function angdist(la1,lo1,la2,lo2){
  return acosd(sind(la1)*sind(la2)+cosd(la1)*cosd(la2)*cosd(lo2-lo1))
}

# ---------------------------------------------------------------------
#  The navigational triangle drawn on the observer's sky
#  (zenith at the centre, horizon at the rim, north up)
# ---------------------------------------------------------------------
function sky_pt(alt,az){
  SP_R = TR_CY - TR_RY*((90-alt)/90)*cosd(az)
  SP_C = TR_CX + TR_RX*((90-alt)/90)*sind(az)
  return 0
}
function tri_arc(a1,z1,a2,z2,ch,   x1,y1,zz1,x2,y2,zz2,om,t,s1,s2,x,y,z,al,az,i){
  x1=cosd(a1)*cosd(z1); y1=cosd(a1)*sind(z1); zz1=sind(a1)
  x2=cosd(a2)*cosd(z2); y2=cosd(a2)*sind(z2); zz2=sind(a2)
  om=acosd(x1*x2+y1*y2+zz1*zz2)
  if(om<0.01) return 0
  for(i=0;i<=200;i++){
    t=i/200.0
    s1=sind((1-t)*om)/sind(om); s2=sind(t*om)/sind(om)
    x=s1*x1+s2*x2; y=s1*y1+s2*y2; z=s1*zz1+s2*zz2
    al=asind(z); az=nrm360(atan2d(y,x))
    if(al< -1) continue
    sky_pt(al,az); gputw(SP_R,SP_C,ch)
  }
  return 0
}
function tri_diagram(lat,dec,lha,   w,h,t,paz,palt,zn,hc){
  w=61; h=25; TR_CX=int(w/2); TR_CY=int(h/2); TR_RX=TR_CX-1; TR_RY=TR_CY-1
  gclear(w,h)
  for(t=0;t<360;t+=0.6){
    gputw(TR_CY-TR_RY*cosd(t), TR_CX+TR_RX*sind(t), ".")
  }
  reduce_sight(lat,lha*0,0,0)     # keep the engine happy about globals
  hc = asind(sind(lat)*sind(dec)+cosd(lat)*cosd(dec)*cosd(lha))
  zn = nrm360(atan2d(-cosd(dec)*sind(lha), cosd(lat)*sind(dec)-sind(lat)*cosd(dec)*cosd(lha)))
  palt = (lat>=0? lat : -lat)
  paz  = (lat>=0? 0 : 180)
  tri_arc(90,0,palt,paz,"'")          # zenith to pole  (co-latitude)
  tri_arc(90,0,hc,zn,"`")             # zenith to body  (zenith distance)
  tri_arc(palt,paz,hc,zn,"+")         # pole to body    (polar distance)
  sky_pt(90,0);   gput(SP_R,SP_C,"Z")
  sky_pt(palt,paz); gput(SP_R,SP_C,"P"); gputs(SP_R-1,SP_C-1,(lat>=0?"N":"S"))
  sky_pt(hc,zn);  gput(SP_R,SP_C,"*")
  gputs(0,TR_CX-1,"N"); gputs(h-1,TR_CX-1,"S")
  gputs(TR_CY,0,"W");   gputs(TR_CY,w-1,"E")
  TRI_HC=hc; TRI_ZN=zn
  return 0
}

function arc_mid(a1,z1,a2,z2,   x1,y1,zz1,x2,y2,zz2,x,y,z,n){
  x1=cosd(a1)*cosd(z1); y1=cosd(a1)*sind(z1); zz1=sind(a1)
  x2=cosd(a2)*cosd(z2); y2=cosd(a2)*sind(z2); zz2=sind(a2)
  x=(x1+x2)/2; y=(y1+y2)/2; z=(zz1+zz2)/2
  n=sqrt(x*x+y*y+z*z); if(n<1e-9) return 0
  AM_ALT=asind(z/n); AM_AZ=nrm360(atan2d(y,x))
  return 0
}
function tri_label(alt,az,s,dc,dr){
  sky_pt(alt,az); gputs(SP_R+dr, SP_C+dc, s)
  return 0
}

# ---------------------------------------------------------------------
#  How big is each sextant correction?  A bar chart in arcminutes.
# ---------------------------------------------------------------------
function bar(n,   i,s){ s=""; for(i=0;i<n;i++) s=s "="; return s }
function corr_bars(hs,ie,heye,temp,press,limb,   ho,sc,i){
  ho = corrections(hs,ie,heye,temp,press,limb)
  sc = 0.55                                   # characters per arcminute
  printf "    %-22s %11s\n", "Hs  sextant reading", fmt_dm(hs,2)
  printf "    %-22s %+8.1f'  %s\n", "index error", -ie, bar(int(fabs(ie)*sc+0.5))
  printf "    %-22s %+8.1f'  %s\n", "dip (height of eye)", -C_DIP, bar(int(C_DIP*sc+0.5))
  printf "    %-22s %11s\n", "Ha  apparent altitude", fmt_dm(C_HA,2)
  printf "    %-22s %+8.1f'  %s\n", "refraction", -C_REF, bar(int(C_REF*sc+0.5))
  if(C_PAR>0.02) printf "    %-22s %+8.1f'  %s\n", "parallax", C_PAR, bar(int(C_PAR*sc+0.5))
  if(C_LIMB!=0)  printf "    %-22s %+8.1f'  %s\n", "semi-diameter", C_LIMB, bar(int(fabs(C_LIMB)*sc+0.5))
  printf "    %-22s %11s\n", "Ho  observed altitude", fmt_dm(ho,2)
  return ho
}

# ---------------------------------------------------------------------
#  Why a straight line will do: the circle of position, zoomed in
# ---------------------------------------------------------------------
function lop_zoom(zd,nmwide,   w,h,cx,cy,i,x,R,y,row,sag,vex,maxsag){
  w=67; h=13; cx=int(w/2); cy=h-3
  gclear(w,h)
  R = zd*60.0                                   # radius of the circle, nm
  maxsag = R - sqrt(R*R - (nmwide/2)*(nmwide/2))
  vex = (h-6)/maxsag                            # rows per nm, exaggerated
  for(i=0;i<w;i++){
    x = (i-cx)*(nmwide/w)
    y = R - sqrt(R*R - x*x)
    row = cy - y*vex
    gputw(cy,i,"-")
    gput(row,i,"o")
  }
  gput(cy,cx,"+")
  gputs(cy+1,cx-3,"AP")
  gputs(0,1,sprintf("the circle of position has a radius of %.0f nm", R))
  gputs(1,1,sprintf("across %.0f nm it falls only %.2f nm away from the straight line", nmwide, maxsag))
  gputs(2,1,sprintf("(drawn here with the vertical stretched about %.0f times, or you", vex*(nmwide/w)))
  gputs(3,1,"would not see the curve at all)")
  gputs(h-1,1,"o = the true circle of position    - = the straight LOP we draw")
  return maxsag
}
# ---------------------------------------------------------------------
#  Running fix: one LOP advanced along the course to meet a second
# ---------------------------------------------------------------------
function runfix_fig(zn1,p1,zn2,p2,crs,dist,   w,h,cx,cy,xs,ys,i,t,m,rn,re,p1a,dn,de,mx,sc){
  w=71; h=23; cx=int(w/2); cy=int(h/2)
  rn=dist*cosd(crs); re=dist*sind(crs)
  p1a = p1 + rn*cosd(zn1) + re*sind(zn1)
  mx=fabs(p1); if(fabs(p1a)>mx)mx=fabs(p1a); if(fabs(p2)>mx)mx=fabs(p2); if(dist>mx)mx=dist
  ys = nicestep(mx*1.35/(h/2-1)); xs = ys/2.0
  gclear(w,h)
  lop_line(cx,cy,xs,ys,zn1,p1,".",w,h)
  lop_line(cx,cy,xs,ys,zn1,p1a,"=",w,h)
  lop_line(cx,cy,xs,ys,zn2,p2,"|",w,h)
  m=fabs(rn/ys); if(fabs(re/xs)>m) m=fabs(re/xs)
  for(t=0;t<=m;t+=0.4) gput(cy-(rn/ys)*t/m, cx+(re/xs)*t/m, ">")
  gput(cy,cx,"+")
  dn=(p1a*sind(zn2)-p2*sind(zn1))/sind(zn2-zn1)
  de=(p2*cosd(zn1)-p1a*cosd(zn2))/sind(zn2-zn1)
  gput(cy-dn/ys, cx+de/xs, "@")
  gputs(0,1,sprintf("1 row = %g nm", ys))
  return 0
}
function lop_line(cx,cy,xs,ys,zn,p,ch,w,h,   fr,fc,dr,dc,m,t){
  fr = cy - (p*cosd(zn))/ys
  fc = cx + (p*sind(zn))/xs
  dr = -(cosd(zn+90))/ys
  dc =  (sind(zn+90))/xs
  m  = fabs(dr); if(fabs(dc)>m) m=fabs(dc)
  dr=dr/m; dc=dc/m
  for(t=-(w+h); t<=(w+h); t+=0.5){
    if(fr+dr*t<0||fr+dr*t>=h||fc+dc*t<0||fc+dc*t>=w) continue
    gput(fr+dr*t, fc+dc*t, ch)
  }
  return 0
}

# =====================================================================
#  Lesson text helpers
# =====================================================================
# ---- a reproducible pseudo-random generator -------------------------
#  awk's own srand()/rand() is not reproducible across implementations:
#  mawk re-seeds from the clock even when handed an explicit seed, which
#  would make a drill and its marking disagree.  MINSTD is exact in
#  double precision and gives the same stream everywhere.
function xsrand(s,   i){
  RS_ = int(s) % 2147483647
  if(RS_ <= 0) RS_ += 2147483646
  for(i=0;i<8;i++) RS_ = (16807*RS_) % 2147483647
  return 0
}
function xrand(){ RS_ = (16807*RS_) % 2147483647; return RS_/2147483647.0 }

function tp(s){ print "  " s }
function tb(){ print "" }
function thead(id,title,   i,u){
  print ""
  printf "  %s  %s\n", id, title
  u=""; for(i=0;i<length(title)+6;i++) u=u "-"
  print "  " u
}
function tnote(s){ print "  " s }

# =====================================================================
#  Module F -- Foundations
# =====================================================================
function les_F1(){
  thead("F1","What a sight actually measures")
  tb()
  tp("A sextant measures one thing: the angle between a body in the sky and")
  tp("your horizon. Nothing else. It does not know where you are, and it does")
  tp("not care.")
  tb()
  tp("  1. You bring the body down to the horizon in the mirrors and read the")
  tp("     angle off the arc. That reading is Hs, the sextant altitude.")
  tp("  2. Straight overhead is 90 degrees. The horizon is 0. So an altitude of")
  tp("     40 degrees means the body stands 40 degrees up from the sea.")
  tp("  3. The useful quantity is the other half of that: 90 minus the altitude,")
  tp("     called the zenith distance. It is how far the body is from being")
  tp("     directly overhead.")
  tb()
  tp("That last number is the whole trick, and the next two lessons are about")
  tp("why. Hold on to it: zenith distance = 90 - altitude.")
  tb()
  tp("     zenith (straight up)")
  tp("         |")
  tp("         |      90 - Hs = zenith distance")
  tp("         |   .-'")
  tp("         | .'        * the body")
  tp("         |'      .-'")
  tp("         |   .-'   Hs = the angle you measure")
  tp("      you o------------------------------  your horizon")
  tb()
}
function les_F2(){
  thead("F2","The geographical position")
  tb()
  tp("At any instant, every body in the sky is directly overhead somewhere on")
  tp("the earth. That spot is its geographical position, or GP.")
  tb()
  tp("  1. The GP has a latitude and a longitude, like any other place.")
  tp("  2. Its latitude is the body's declination - how far north or south of")
  tp("     the celestial equator the body lies.")
  tp("  3. Its longitude comes from the body's Greenwich Hour Angle, GHA -")
  tp("     how far west of Greenwich it has swung.")
  tp("  4. The GP moves, and quickly: the earth turns 15 degrees of longitude")
  tp("     an hour, so a body's GP travels about 900 nautical miles westward")
  tp("     every hour at the equator.")
  tb()
  tp("The almanac exists to answer one question: at this instant of Universal")
  tp("Time, where is this body's GP? Declination gives the latitude, GHA gives")
  tp("the longitude. That is all an almanac is for.")
  tb()
  tp("Nothing here depends on where you are. The GP is the same for every")
  tp("observer on earth at that instant, which is exactly what makes it useful.")
  tb()
}
function les_F3(){
  thead("F3","Your altitude puts you on a circle")
  tb()
  tp("Now put the two ideas together.")
  tb()
  tp("  1. If a body were exactly overhead, its altitude would be 90 degrees")
  tp("     and you would be standing on its GP.")
  tp("  2. Measure an altitude of 50 degrees instead, and your zenith distance")
  tp("     is 40 degrees. You are 40 degrees away from the GP.")
  tp("  3. One degree on the earth is 60 nautical miles, so you are 2400 miles")
  tp("     from the GP - but the sextant says nothing about which direction.")
  tp("  4. Every point 2400 miles from the GP is a candidate. Those points form")
  tp("     a circle drawn on the earth, centred on the GP.")
  tb()
  tp("That circle is your circle of position. One sight, one circle. You are")
  tp("somewhere on it.")
  tb()
}
function les_F4(){
  thead("F4","Two circles give a fix")
  tb()
  tp("One circle is not a position. Two are.")
  tb()
  tp("  1. Take a second sight of a different body. It gives a second circle,")
  tp("     centred on that body's GP.")
  tp("  2. Two circles on a sphere cross in two places, and you are at one of")
  tp("     them.")
  tp("  3. The two crossings are usually hundreds or thousands of miles apart,")
  tp("     so your dead reckoning tells you at a glance which one is yours.")
  tp("  4. A third sight is the check. If all three circles pass through the")
  tp("     same small area, the round was a good one. If they enclose a large")
  tp("     triangle, one of the sights is wrong.")
  tb()
  tp("That is celestial navigation entire. Everything after this lesson is")
  tp("about doing it accurately and quickly, on a small chart table, without")
  tp("drawing circles thousands of miles across.")
  tb()
}
function les_F5(){
  thead("F5","Why we never draw the circles")
  tb()
  tp("A circle of position is typically two or three thousand miles across.")
  tp("You cannot draw one on a chart. You do not need to.")
  tb()
  tp("  1. You already know roughly where you are - your dead reckoning.")
  tp("  2. Near your DR, a stretch of that vast circle is almost perfectly")
  tp("     straight. Over 60 miles it departs from a straight line by a")
  tp("     fraction of a mile.")
  tp("  3. So instead of the circle, we draw a short straight line: the line")
  tp("     of position, or LOP.")
  tp("  4. To place it we need two things - how far the circle passes from")
  tp("     the DR, and in what direction. Those are the intercept and the")
  tp("     azimuth, and computing them is what sight reduction does.")
  tb()
  tp("The picture below is the circle from lesson F3, zoomed in to a 60-mile")
  tp("stretch, with the vertical stretched so that you can see the curve at all.")
  tb()
}

# =====================================================================
#  Module T -- Time and the almanac
# =====================================================================
function les_T1(){
  thead("T1","Universal Time, and why the clock rules")
  tb()
  tp("Everything in celestial navigation is referred to Universal Time, which")
  tp("for our purposes is the same as GMT. Not ship's time, not local time.")
  tb()
  tp("  1. The earth turns 360 degrees in 24 hours: 15 degrees an hour,")
  tp("     15 minutes of arc a minute, 15 seconds of arc a second.")
  tp("  2. At the equator one minute of arc of longitude is one nautical mile.")
  tp("     So one second of clock error is a quarter of a mile of longitude.")
  tp("  3. Four seconds is a mile. Forty seconds is ten miles.")
  tp("  4. A clock error moves your longitude and leaves your latitude alone,")
  tp("     which is a useful thing to recognise: if a fix is wrong east-west")
  tp("     but right north-south, suspect the time before anything else.")
  tb()
  tp("The practical rules that follow from this:")
  tb()
  tp("  - Set your watch against a known source and write down the error and")
  tp("    the date you checked it.")
  tp("  - Note the time of a sight to the second, at the instant the body")
  tp("    touches the horizon.")
  tp("  - If you are shooting alone, call the time out loud as you take it, or")
  tp("    take the sight and then read the watch - never the other way round.")
  tb()
}
function les_T2(){
  thead("T2","GHA and declination")
  tb()
  tp("These two numbers are the GP, and the almanac's whole job is to produce")
  tp("them for a given instant.")
  tb()
  tp("  1. Declination is the latitude of the GP. North is positive, south")
  tp("     negative. The sun's declination swings between about 23.4 degrees")
  tp("     north in June and 23.4 south in December, and it is what gives us")
  tp("     seasons.")
  tp("  2. Greenwich Hour Angle is the longitude of the GP, measured westward")
  tp("     from Greenwich, and always written 0 to 360 degrees rather than")
  tp("     east and west.")
  tp("  3. To convert: a GHA of 45 degrees is longitude 45 degrees west. A GHA")
  tp("     of 300 degrees is longitude 60 degrees east, because 360 - 300 = 60.")
  tp("  4. GHA increases by about 15 degrees an hour for every body, because it")
  tp("     is really a measure of the earth's rotation.")
  tb()
  tp("In CELNAV, 'celnav alm' prints GHA and declination for any body at any")
  tp("time. You can check it against a printed Nautical Almanac page and the")
  tp("figures will agree to a fraction of a minute of arc.")
  tb()
}
function les_T3(){
  thead("T3","Aries and SHA: why the stars are different")
  tb()
  tp("The sun, moon and planets each get their own GHA in the almanac. The")
  tp("stars are handled differently, and for a good reason.")
  tb()
  tp("  1. The stars are so far away that they do not move relative to one")
  tp("     another in any human timescale. The whole star sphere turns as one")
  tp("     rigid thing.")
  tp("  2. So the almanac gives the hour angle of one imaginary point, the")
  tp("     First Point of Aries, and then each star's fixed offset from it.")
  tp("  3. That offset is the Sidereal Hour Angle, SHA, measured westward from")
  tp("     Aries. Sirius has an SHA of about 259 degrees and will still have")
  tp("     it in twenty years.")
  tp("  4. So: GHA of a star = GHA Aries + SHA, subtracting 360 if needed.")
  tb()
  tp("One consequence worth knowing: the star sphere gains about four minutes")
  tp("a day on the sun. A star that crosses your meridian at 2000 tonight will")
  tp("do it at 1956 tomorrow, and two hours earlier in a month.")
  tb()
}
function les_T4(){
  thead("T4","LHA: the angle at the pole")
  tb()
  tp("GHA is measured from Greenwich. What matters to you is the angle measured")
  tp("from your own meridian, and that is the Local Hour Angle.")
  tb()
  tp("  1. LHA = GHA + your longitude, counting east longitude as positive and")
  tp("     west as negative, then brought back into the range 0 to 360.")
  tp("  2. LHA 0 means the body is exactly on your meridian - due north or due")
  tp("     south of you, and at its highest for the day. That is the noon sight.")
  tp("  3. LHA 90 means the body is a quarter of the way round the sky to the")
  tp("     west of you; LHA 270 means a quarter of the way to the east.")
  tp("  4. LHA is the angle at the pole in the navigational triangle, which is")
  tp("     the shape the whole reduction is built on. You meet it again in R1.")
  tb()
  tp("Worked example. GHA of the sun is 283 degrees 42 minutes; you are in")
  tp("longitude 40 degrees west. LHA = 283 42 - 40 00 = 243 42. The sun is")
  tp("243 degrees west of you round the sky - which is another way of saying")
  tp("116 degrees to the east of you, and therefore still in the morning sky.")
  tb()
}
function les_T5(){
  thead("T5","Using the almanac in CELNAV")
  tb()
  tp("CELNAV computes the almanac rather than tabulating it, so there is no")
  tp("year to run out and no page to turn.")
  tb()
  tp("  1. 'celnav alm \"2026-08-29 07:30:00\" sun,moon,venus' prints GHA,")
  tp("     declination, semi-diameter and horizontal parallax for those bodies.")
  tp("  2. Add a star by name - 'celnav alm \"...\" Dubhe' - and it also prints")
  tp("     the SHA, so you can cross-check against a printed almanac.")
  tp("  3. 'celnav stars' lists all 57 navigational stars plus Polaris with")
  tp("     their SHA and declination for the date.")
  tp("  4. GHA Aries is printed at the top of every almanac page, so you can")
  tp("     verify the star relation from T3 by hand.")
  tb()
  tp("A good habit while you are learning: work a sight from a paper almanac,")
  tp("then run the same time and body through CELNAV. Where the two disagree")
  tp("by more than a couple of tenths of a minute, one of you has made a")
  tp("mistake - and finding out which is the most useful hour you can spend.")
  tb()
}

# =====================================================================
#  Module S -- The sextant and its corrections
# =====================================================================
function les_S1(){
  thead("S1","Taking a sight")
  tb()
  tp("The instrument work is most of the accuracy. The arithmetic that follows")
  tp("is exact; your sight is not.")
  tb()
  tp("  1. Pre-set roughly. For a star, set the sextant to the altitude you")
  tp("     expect - CELNAV's planning list gives it - and the star will be near")
  tp("     the horizon in the mirror when you look along the bearing.")
  tp("  2. Bring the body down to the horizon, then rock the sextant gently")
  tp("     side to side. The body swings in an arc; the lowest point of that")
  tp("     arc is true vertical. Touch it to the horizon there.")
  tp("  3. Sun: bring the lower limb - the bottom edge - to sit on the horizon.")
  tp("     Use the shades. Never look at the sun without them.")
  tp("  4. Note the time at the instant of contact, then read the arc.")
  tb()
  tp("Three practical points that matter more than they sound:")
  tb()
  tp("  - Take three or four sights of the same body in quick succession and")
  tp("    keep them all. Their scatter tells you what your sights are worth.")
  tp("  - Shoot from as high as you can safely stand, and know that height.")
  tp("  - In a seaway, wait for the top of the roll so that you see a true")
  tp("    horizon rather than the back of a wave.")
  tb()
}
function les_S2(){
  thead("S2","Index error and dip")
  tb()
  tp("Two corrections come off before anything else. Both are about you and")
  tp("your instrument, not about the sky.")
  tb()
  tp("  INDEX ERROR is the sextant reading when it should read zero.")
  tp("  1. Set the sextant to zero and look at the horizon. If the two images")
  tp("     do not line up, the difference is the index error.")
  tp("  2. If the reading is on the arc - a positive reading - the error is")
  tp("     subtracted. Off the arc, it is added. Check it every day; it moves.")
  tb()
  tp("  DIP is because you are not at sea level.")
  tp("  3. From a height, the visible horizon is slightly below true")
  tp("     horizontal, so every altitude you measure is slightly too big.")
  tp("  4. Dip in minutes of arc is about 1.76 times the square root of your")
  tp("     height of eye in metres. From 3 metres that is 3.0 minutes - three")
  tp("     miles of error if you forget it.")
  tb()
  tp("Take both off Hs and you have Ha, the apparent altitude.")
  tb()
}
function les_S3(){
  thead("S3","Refraction")
  tb()
  tp("The atmosphere bends light downwards as it comes in, so every body")
  tp("appears higher than it really is. Refraction is always subtracted.")
  tb()
  tp("  1. It depends almost entirely on altitude. At 45 degrees it is one")
  tp("     minute of arc. At 20 degrees, about 2.6. At 10 degrees, 5.3. At the")
  tp("     horizon it reaches about 34 minutes - more than the sun's diameter.")
  tp("  2. That is why the setting sun you can see is already, geometrically,")
  tp("     below the horizon.")
  tp("  3. Temperature and pressure change it by a few per cent. CELNAV asks")
  tp("     for both; they matter for low sights and are almost irrelevant")
  tp("     above 25 degrees.")
  tp("  4. Below about 15 degrees, refraction depends on the real temperature")
  tp("     profile between you and the horizon, which no formula knows. That is")
  tp("     the reason low sights are less trustworthy, not the sextant.")
  tb()
  tp("Practical rule: prefer bodies between 15 and 70 degrees. Above 70 the")
  tp("azimuth changes quickly with position; below 15 the refraction is a guess.")
  tb()
}
function les_S4(){
  thead("S4","Semi-diameter and parallax")
  tb()
  tp("Two more corrections, needed only for the sun and moon.")
  tb()
  tp("  SEMI-DIAMETER, because the sun and moon are discs, not points.")
  tp("  1. You measured an edge; you want the centre. The sun's semi-diameter")
  tp("     is about 16 minutes, the moon's about 15 to 16.")
  tp("  2. Lower limb: add it. Upper limb: subtract it. Stars and planets are")
  tp("     points, so there is nothing to do.")
  tb()
  tp("  PARALLAX, because you are on the surface of the earth, not at its")
  tp("  centre, and the almanac gives positions as seen from the centre.")
  tp("  3. For the sun this is at most 0.15 minutes - one sixth of a mile, and")
  tp("     usually ignorable but free to include.")
  tp("  4. For the moon it is enormous: up to about 61 minutes, a full degree.")
  tp("     A moon sight worked without parallax is 60 miles wrong. It is")
  tp("     largest when the moon is on the horizon and zero when overhead,")
  tp("     which is why the correction carries a cosine of the altitude.")
  tb()
}
function les_S5(){
  thead("S5","The whole chain, and the size of each part")
  tb()
  tp("In order, always: Hs, then index error and dip to get Ha, then refraction,")
  tp("parallax and semi-diameter to get Ho. Ho is what a perfect observer at the")
  tp("centre of the earth would have measured, and it is the number the")
  tp("reduction uses.")
  tb()
  tp("Below is a real sun sight with every correction drawn to scale, so you")
  tp("can see which ones actually matter.")
  tb()
}
# =====================================================================
#  Module R -- Reduction, the fix, and errors
# =====================================================================
function les_R1(){
  thead("R1","The assumed position and the navigational triangle")
  tb()
  tp("You cannot compute your position directly. You compute what a sight")
  tp("would have looked like from a position you assume, and then compare.")
  tb()
  tp("  1. Take an assumed position - in CELNAV, your DR itself.")
  tp("  2. Draw three points on the sky as seen from there: your zenith Z")
  tp("     straight overhead, the elevated pole P, and the body itself.")
  tp("  3. Those three points make a spherical triangle, and every quantity in")
  tp("     sight reduction is one of its parts:")
  tb()
  tp("       side Z to P    = 90 - your latitude          (co-latitude)")
  tp("       side P to body = 90 - the declination        (polar distance)")
  tp("       side Z to body = 90 - the altitude           (zenith distance)")
  tp("       angle at P     = LHA")
  tp("       angle at Z     = the azimuth of the body")
  tb()
  tp("  4. You know the first two sides and the angle between them, so the")
  tp("     triangle is fully determined. Solving it gives the third side and")
  tp("     the angle at Z - which is to say, the altitude and bearing the body")
  tp("     would have had from your assumed position.")
  tb()
}
function les_R2(){
  thead("R2","Hc and Zn")
  tb()
  tp("Solving that triangle gives two numbers, and CELNAV prints both.")
  tb()
  tp("  1. Hc, the computed altitude:")
  tb()
  tp("         sin Hc = sin(lat) sin(dec) + cos(lat) cos(dec) cos(LHA)")
  tb()
  tp("  2. Zn, the true bearing of the body from the assumed position, taken")
  tp("     from the same triangle and given as 000 to 360 degrees true.")
  tp("  3. Hc is what you would have measured if you really had been at the")
  tp("     assumed position. Ho is what you did measure. They differ because")
  tp("     you are not there.")
  tp("  4. Zn is the direction of the body's GP from you - which is also the")
  tp("     direction in which the circle of position runs away from you, and")
  tp("     therefore the direction along which the whole comparison is made.")
  tb()
  tp("Two lines of trigonometry replace a book of tables. The tables were only")
  tp("ever a way of doing this arithmetic without a calculator.")
  tb()
}
function les_R3(){
  thead("R3","The intercept: toward or away")
  tb()
  tp("Here is where the sight finally tells you something about your position.")
  tb()
  tp("  1. The intercept is simply Ho minus Hc, in minutes of arc - which are")
  tp("     nautical miles.")
  tp("  2. A bigger altitude means you are closer to the GP. So if Ho is")
  tp("     greater than Hc, you are nearer the body than the assumed position")
  tp("     was: the intercept is TOWARD, in the direction Zn.")
  tp("  3. If Ho is less than Hc, you are further away: AWAY, in the opposite")
  tp("     direction.")
  tp("  4. The old mnemonic is 'computed greater, away' - if Hc is the greater")
  tp("     of the two, plot away from the body.")
  tb()
  tp("Example. Ho is 19 degrees 24.8 minutes, Hc is 19 degrees 23.3 minutes.")
  tp("The difference is 1.5 minutes, so 1.5 miles, and Ho is the larger:")
  tp("1.5 miles TOWARD the body along its azimuth.")
  tb()
}
function les_R4(){
  thead("R4","Plotting the line of position")
  tb()
  tp("Three steps, and they are the same whether you use paper or the screen.")
  tb()
  tp("  1. Mark the assumed position.")
  tp("  2. Draw the azimuth line from it, in the direction Zn.")
  tp("  3. Measure the intercept along that line - toward the body or away from")
  tp("     it - and mark the point. That point is on your circle of position.")
  tp("  4. Through that point draw a line at right angles to the azimuth. That")
  tp("     is the line of position. You are somewhere on it.")
  tb()
  tp("Why at right angles: the azimuth points at the GP, and the circle of")
  tp("position is centred on the GP, so the circle - and the straight line we")
  tp("use in its place - must cross the azimuth square on.")
  tb()
  tp("On CELNAV's plot the assumed position is the + at the centre, the dotted")
  tp("line is the azimuth, the letter marks the end of the intercept, and the")
  tp("lettered line through it is the LOP.")
  tb()
}
function les_R5(){
  thead("R5","Crossing, running, and knowing when to doubt it")
  tb()
  tp("  CROSSING. Two LOPs from bodies well apart in azimuth cross at your")
  tp("  position. Three give you a check: a small triangle means good sights,")
  tp("  a large one means at least one is wrong.")
  tb()
  tp("  RUNNING. Sights taken minutes or hours apart were taken from different")
  tp("  places, because the boat moved. Each earlier LOP is advanced along the")
  tp("  course made good by the distance run, and the fix is taken from the")
  tp("  advanced lines. Set course and speed and CELNAV does this for you; the")
  tp("  classic case is the sun line in the morning advanced to noon.")
  tb()
  tp("  DOUBTING. Two things tell you how much to trust a fix:")
  tp("  1. The residuals - how far each LOP misses the final answer. This is")
  tp("     your observing error, and under a mile is good work from a small")
  tp("     boat.")
  tp("  2. The geometry - how far one minute of sight error moves the fix.")
  tp("     Bodies bunched in one quarter of the sky give a long thin error")
  tp("     ellipse and a confident-looking fix that is badly wrong along one")
  tp("     axis. CELNAV prints this in miles and warns you when the cut is weak.")
  tb()
  tp("  Bodies about 120 degrees apart in azimuth give the tightest fix, which")
  tp("  is why the planning list suggests three with the widest spread.")
  tb()
}

# ---------------------------------------------------------------------
#  Looking down on the north pole: GHA, longitude and LHA
# ---------------------------------------------------------------------
function lha_diagram(gha,lon,   w,h,cx,cy,rx,ry,t,lha,lw,r,rr,cc){
  w=61; h=23; cx=int(w/2); cy=int(h/2); rx=cx-7; ry=cy-2
  gclear(w,h)
  lw  = nrm360(-lon)
  lha = nrm360(gha + lon)
  for(t=0;t<=gha;t+=0.8)  gputw(cy-ry*0.55*cosd(t), cx+rx*0.55*sind(t), "-")
  for(t=0;t<=lha;t+=0.8)  gputw(cy-ry*0.80*cosd(lw+t), cx+rx*0.80*sind(lw+t), "=")
  for(t=0;t<360;t+=0.5) gput(cy-ry*cosd(t), cx+rx*sind(t), ".")
  for(r=0.10;r<=1.0;r+=0.025){
    gput(cy-ry*r,                    cx,                    "|")
    gput(cy-ry*r*cosd(lw),  cx+rx*r*sind(lw),  "o")
    gput(cy-ry*r*cosd(gha), cx+rx*r*sind(gha), "*")
  }
  gput(cy,cx,"N")
  gputs(cy-ry-1, cx-4, "Greenwich")
  rr=cy-(ry+1.6)*cosd(lw);  cc=cx+(rx+2)*sind(lw);  gputs(rr, cc-(lw>180?5:0), "you")
  rr=cy-(ry+1.6)*cosd(gha); cc=cx+(rx+2)*sind(gha); gputs(rr, cc-(gha>180?3:0), "GP")
  return 0
}
# ---------------------------------------------------------------------
#  Diagrams belonging to particular lessons
# ---------------------------------------------------------------------
# =====================================================================
#  Module C -- Choosing and checking
# =====================================================================
function les_C1(){
  thead("C1","Choosing your bodies: the cut matters more than the sights")
  tb()
  tp("A fix is only as good as the angles between its lines. Three careful")
  tp("sights of three bodies in the same quarter of the sky make a worse")
  tp("fix than three rough sights spread right round you.")
  tb()
  tp("  1. A line of position runs square across the azimuth of its body.")
  tp("     Two lines crossing at a right angle pin a position in both")
  tp("     directions at once.")
  tp("  2. Two lines crossing at fifteen degrees pin it in one direction")
  tp("     and leave it almost free in the other. One minute of sextant")
  tp("     error slides the crossing four miles along that weak axis.")
  tp("  3. So the number to weigh before you shoot is the azimuth spread,")
  tp("     not the magnitude. Want bodies 90 to 120 degrees apart, and")
  tp("     three of them rather than two.")
  tb()
  tp("Then the altitude. A body wants to stand between about 15 and 65")
  tp("degrees up.")
  tb()
  tp("  4. Below 15 degrees the light has come a long way through the")
  tp("     lowest air, and refraction there depends on the real air and")
  tp("     sea temperatures, which you do not know. The correction stops")
  tp("     being arithmetic and becomes a guess.")
  tp("  5. Above about 65 the azimuth swings quickly - the body is on its")
  tp("     way to your zenith, where it has no azimuth at all - so a few")
  tp("     seconds of timing error moves the line. The circle of position")
  tp("     is tightly curved up there as well, and we draw it straight.")
  tb()
  tp("And the window. A star needs a horizon to measure against and a sky")
  tp("dark enough to show it. You get both only between civil and nautical")
  tp("twilight, which is around twenty minutes, twice a day.")
  tb()
  tp("CELNAV does this arithmetic for you before you pick up the sextant.")
  tb()
  tp("  celnav plan        the twilight times, every body that is up with")
  tp("                     its altitude, azimuth and magnitude, the ones")
  tp("                     too low or too high marked as such, the best")
  tp("                     three by azimuth spread, and a chart of the sky")
  tp("                     with that set numbered on it")
  tb()
  tp("And afterwards it tells you what the cut was worth. 'celnav fix'")
  tp("reports the geometry in miles: what one minute of sight error does")
  tp("to the answer, and along which bearing. When it says WEAK CUT, that")
  tp("is not a style note - it is the error ellipse, computed from your")
  tp("own azimuths. Believe it.")
  tb()
  tp("The order of work is plan, then shoot. Not shoot, then hope.")
  tb()
}
function les_C2(){
  thead("C2","Checking the compass against the sky")
  tb()
  tp("Every other compass reference can be wrong. A charted bearing")
  tp("assumes you already know where you are. A transit needs two marks in")
  tp("sight. Another vessel's heading is her business. The azimuth of a")
  tp("star is none of those things: it comes from the almanac and the")
  tp("clock, and it is right.")
  tb()
  tp("Three quantities, and it matters which is which:")
  tb()
  tp("  1. Variation is the earth's. It is printed on the chart for your")
  tp("     area and year, and it changes slowly with place and time. It is")
  tp("     the same for every compass aboard.")
  tp("  2. Deviation is the ship's. It is the iron in her, and it changes")
  tp("     with her heading, because the iron turns when she turns.")
  tp("  3. Compass error is the two together: the whole difference between")
  tp("     what the card reads and true. A sky check measures the error.")
  tp("     Take the charted variation off it and what remains is the")
  tp("     deviation of that compass on that heading.")
  tb()
  tp("The method:")
  tb()
  tp("  4. Note the time to the second and read the bearing of the body")
  tp("     over the compass.")
  tp("  5. Give CELNAV the instant, the body, the bearing you read and the")
  tp("     chart variation, west negative:")
  tb()
  tp("       celnav compass \"2026-10-21 19:00:00\" Saturn 88 -14")
  tb()
  tp("  6. It computes the true azimuth for that instant, subtracts to get")
  tp("     the error, and names the deviation that is left.")
  tb()
  tp("Choose a low body, under about 20 degrees. High up the azimuth")
  tp("changes fast, so a few seconds of clock error moves it; and a")
  tp("bearing taken steeply over a compass card is hard to take honestly.")
  tp("A body sitting on the horizon at rising or setting is the classical")
  tp("choice, and its azimuth measured off true east or west has its own")
  tp("name: the amplitude.")
  tb()
  tp("One honest limit. A check on one heading gives you the deviation on")
  tp("that heading and no other. Deviation is a curve around the card, and")
  tp("to know the whole of it you swing the ship and check on several")
  tp("headings in turn.")
  tb()
  tp("That is what devcard does. Turn the ship onto each heading, take a")
  tp("bearing of the body, and note the TIME of each one separately:")
  tb()
  tp("  celnav devcard \"2026-10-22\" sun -2 \\")
  tp("     \"000,10:00:00,147.0; 045,10:05:00,146.9; 090,10:10:00,148.4\"")
  tb()
  tp("Each bearing keeps its own time because a swing takes twenty minutes")
  tp("and the sun moves about five degrees of azimuth in that time. Share")
  tp("one time across the whole swing and that nine degrees of the sun's")
  tp("own motion lands in the card, looking exactly like deviation.")
  tb()
  tp("It prints the card above, computed from your own swing, and says")
  tp("which parts of the compass you did not cover.")
  tb()
}
# ---------------------------------------------------------------------
#  Three LOPs, drawn twice: the same sights with a good and a bad cut
# ---------------------------------------------------------------------
function cut_cross(cx,cy,xs,ys,za,pa,zb,pb,   dn,de){
  dn = (pa*sind(zb)-pb*sind(za))/sind(zb-za)
  de = (pb*cosd(za)-pa*cosd(zb))/sind(zb-za)
  CX_N=dn; CX_E=de
  gput(cy-dn/ys, cx+de/xs, "o")
  return 0
}
function cut_fig(z1,z2,z3,p1,p2,p3,title,   w,h,cx,cy,xs,ys,n1,e1,n2,e2,n3,e3,d,m){
  w=67; h=15; cx=int(w/2); cy=int(h/2)
  ys=1.5; xs=ys/2.0
  tb(); tp(title); tb()
  gclear(w,h)
  lop_line(cx,cy,xs,ys,z1,p1,"1",w,h)
  lop_line(cx,cy,xs,ys,z2,p2,"2",w,h)
  lop_line(cx,cy,xs,ys,z3,p3,"3",w,h)
  cut_cross(cx,cy,xs,ys,z1,p1,z2,p2); n1=CX_N; e1=CX_E
  cut_cross(cx,cy,xs,ys,z2,p2,z3,p3); n2=CX_N; e2=CX_E
  cut_cross(cx,cy,xs,ys,z1,p1,z3,p3); n3=CX_N; e3=CX_E
  gput(cy,cx,"+")
  gshow()
  m=0
  d=sqrt((n1-n2)^2+(e1-e2)^2); if(d>m) m=d
  d=sqrt((n2-n3)^2+(e2-e3)^2); if(d>m) m=d
  d=sqrt((n1-n3)^2+(e1-e3)^2); if(d>m) m=d
  tp("1 2 3 = the lines of position   o = where a pair crosses   + = the AP")
  printf "  one row = %g nm.  The cocked hat is %.1f nm across.\n", ys, m
  return 0
}
# ---------------------------------------------------------------------
#  Deviation is a curve round the card, not one number
# ---------------------------------------------------------------------
function dev_card(   i,hd,d,b,s,k){
  tp("     ship's head    deviation      west  <  |  >  east")
  tp("     ------------   ---------")
  for(i=0;i<8;i++){
    hd = i*45
    d  = 4.5*sind(hd+30)
    s  = int(fabs(d)*2+0.5)
    b  = ""
    if(d<0){ for(k=0;k<12-s;k++) b=b " "; for(k=0;k<s;k++) b=b "#"; b=b "|" }
    else   { for(k=0;k<12;k++)   b=b " "; b=b "|"; for(k=0;k<s;k++) b=b "#" }
    printf "      %03d  T        %4.1f %s   %s\n", hd, fabs(d), (d<-0.05?"W":(d>0.05?"E":" ")), b
  }
  return 0
}
# =====================================================================
#  Module P -- Before the sights
#  Larry's instruction: "a preliminary module -- if you understand, skip;
#  else take it."  The gate is in the shell and asks these three lessons'
#  own check questions, so what the gate tests and what the module teaches
#  cannot drift apart.
# =====================================================================
function les_P1(){
  thead("P1","Dead reckoning: course, speed and time")
  tb()
  tp("Everything else in this program needs a position to start from. A")
  tp("sight is reduced from an assumed position; a running fix is advanced")
  tp("along a course and a speed; even deciding which of two circle")
  tp("crossings is you needs a rough idea of where you are.")
  tb()
  tp("Dead reckoning is that idea, and it is the only position you can")
  tp("always have. No sky, no satellites, no landmarks: just what you")
  tp("steered, how fast, and for how long.")
  tb()
  tp("It is arithmetic and makes no claim to be true. That is not a")
  tp("weakness as long as you remember it.")
  tb()
  tp("THE METHOD")
  tb()
  tp("  1. Distance run = speed x time. Nothing subtle.")
  tp("  2. Resolve it onto north and east:")
  tb()
  tp("       northing = distance x cos(course)")
  tp("       departure = distance x sin(course)")
  tb()
  tp("  3. Northing IS difference of latitude: one minute of latitude is")
  tp("     one nautical mile, everywhere on earth. That is what a mile is.")
  tb()
  tp("  4. Departure is NOT difference of longitude. The meridians close")
  tp("     together toward the poles, so a mile of easting is worth more")
  tp("     than a minute of longitude:")
  tb()
  tp("       difference of longitude = departure / cos(latitude)")
  tb()
  tp("At 50 degrees north, cos 50 is 0.64 - so a mile east is 1.56")
  tp("minutes of longitude. At 70 north it is nearly three. Forget this")
  tp("and your DR walks east or west of the truth, and the error grows")
  tp("with latitude, which is exactly where the weather is worst.")
  return 0
}
function dr_fig(   crs,spd,h,d,dn,de,dlo,la){
  crs=50; spd=6.5; h=1.5; la=50.15
  d=spd*h; dn=d*cosd(crs); de=d*sind(crs); dlo=de/cosd(la)
  tp("A worked run, computed by this lesson as you read it:")
  tb()
  printf "      course %03d T    speed %.1f kn    time %.0f min\n", crs, spd, h*60
  tb()
  #  The sketch is written as fixed strings with the numbers appended, so
  #  the arithmetic cannot pull the drawing out of true.
  tp("                   N")
  tp("                   |")
  tp("                   |      /")
  printf "            northing |    /   distance %.2f nm\n", d
  printf "            %5.2f    |  /\n", dn
  printf "                     |/ %d deg\n", crs
  tp("                   +------------ E")
  printf "                     departure %.2f nm\n", de
  tb()
  printf "      difference of latitude    %6.2f'  = %.2f nm\n", dn, dn
  printf "      departure                 %6.2f nm\n", de
  printf "      cos(latitude %.0f)            %6.3f\n", la, cosd(la)
  printf "      difference of longitude   %6.2f'\n", dlo
  tb()
  tp("Note the last three lines. The departure and the difference of")
  tp("longitude are different numbers for the same movement east.")
  return 0
}
function les_P2(){
  thead("P2","Three kinds of position, and which to believe")
  tb()
  tp("A chart can carry three marks that all claim to be where you are.")
  tp("They are not the same claim.")
  tb()
  tp("  DR   DEAD RECKONING. Course, speed and time from the last known")
  tp("       position. No observation in it at all. It is where you would")
  tp("       be if the water had stood still and the helm had been")
  tp("       perfect.")
  tb()
  tp("  EP   ESTIMATED POSITION. The DR with what you know about the")
  tp("       water put back in - set, drift, leeway. Better than the DR,")
  tp("       and still an assumption rather than an observation.")
  tb()
  tp("  FIX  Two or more lines of position, each from something outside")
  tp("       the ship. The only one of the three with an observation in")
  tp("       it.")
  tb()
  tp("The order of confidence never changes: fix, then EP, then DR. A")
  tp("navigator who cannot say which of the three a mark is has lost the")
  tp("only thing that matters about it.")
  tb()
  tp("WHY THIS MODULE COMES BEFORE THE SIGHTS")
  tb()
  tp("A celestial fix is not independent of your DR. Three places it")
  tp("leans on it:")
  tb()
  tp("  1. The assumed position comes from the DR. Put it far from the")
  tp("     truth and the intercept gets long, and a long intercept is")
  tp("     where the straight-line approximation starts to cost you.")
  tp("  2. A running fix advances the earlier line of position along your")
  tp("     course and speed. A log reading 5 per cent high puts that error")
  tp("     straight into the fix - and it will look like a good fix.")
  tp("  3. With one body you have a line, not a position. Which point on")
  tp("     that line you are is a DR question.")
  tb()
  tp("So the fix is only ever as good as the reckoning you ran it from.")
  tp("That is the honest version of \"celestial navigation\": it is")
  tp("reckoning, corrected by observation, not observation alone.")
  return 0
}
function pos3_fig(   w,h,cx,cy,xs,ys,de,sn){
  #  Scaled so the longest label still fits inside the grid: the DR sits
  #  24 miles east of the start, so at one column to the mile the mark
  #  lands at column 30 of 63 and its label has room to the right of it.
  w=63; h=13; cx=5; cy=4
  ys=1.0; xs=1.0
  de=24; sn=-4
  tb(); tp("ONE SHIP, THREE MARKS, FOUR HOURS APART"); tb()
  gclear(w,h)
  gput(cy,cx,"o");               gputs(cy,cx+2,"0400 fix")
  gput(cy,cx+de/xs,"x");         gputs(cy,cx+de/xs+2,"0800 DR")
  gput(cy-sn/ys,cx+de/xs,"e");   gputs(cy-sn/ys,cx+de/xs+2,"0800 EP")
  gput(cy-sn/ys-1,cx+de/xs-3,"O")
  gputs(cy-sn/ys-1,cx+de/xs-12,"0800 fix")
  gshow()
  tp("o = where you were   x = DR   e = EP   O = where you actually are")
  printf "  one row and one column = %g nm.\n", ys
  tb()
  tp("The DR ran 24 miles east on course and log alone. The EP allowed")
  tp("four miles of south-going set. The fix landed near the EP and not")
  tp("on it, which is the normal case - and the reason the next set and")
  tp("drift is worked from the fix and never from the estimate.")
  return 0
}
function les_P3(){
  thead("P3","Set and drift: what the sea did while you were not looking")
  tb()
  tp("You have a DR for 0800 and a star fix for 0800, and they are not in")
  tp("the same place. The difference has a name and a use.")
  tb()
  tp("  SET    the direction the water is setting TOWARD, in degrees true")
  tp("  DRIFT  its rate, in knots")
  tb()
  tp("Take the bearing and distance from the DR to the fix. The bearing")
  tp("is the set. The distance divided by the hours since the last fix is")
  tp("the drift. That is the whole calculation.")
  tb()
  tp("TWO THINGS TO BE HONEST ABOUT")
  tb()
  tp("  1. It is a remainder, not a measurement. Nothing in it was")
  tp("     observed. It is everything your reckoning failed to account")
  tp("     for, and the current is only one item on that list: leeway, a")
  tp("     log reading high or low, steering that averaged a few degrees")
  tp("     off the ordered course, and the error of the fix itself are all")
  tp("     inside the same number.")
  tp("  2. Direction is the commonest mistake. The set is FROM the DR")
  tp("     TOWARD the fix. If your reckoning put you west of where you")
  tp("     really were, the water has been setting you east - toward the")
  tp("     fix, not away from it. The reciprocal is a plausible, wrong,")
  tp("     and completely silent error.")
  tb()
  tp("IN CELNAV")
  tb()
  tp("  celnav current   given the DR, the fix and the hours, the set and")
  tp("                   the drift")
  tp("  celnav ep        given a position, a course, a speed and a time,")
  tp("                   the DR - and with a set and drift, the EP")
  tb()
  tp("Carry a set and drift forward as the best estimate you have, and")
  tp("expect the next fix to revise it. A tidal stream turns; an ocean")
  tp("current does not, much. Which you are in decides how much faith the")
  tp("number deserves tomorrow.")
  return 0
}
function curr_fig(   la1,lo1,la2,lo2,h){
  #  Only three things go into a set and drift: the DR, the fix, and the
  #  hours.  The earlier fix the DR was run from does not enter the
  #  calculation at all, so it is not printed -- an earlier draft of this
  #  figure showed it, with the same position as the DR, which is not how
  #  a four-hour run works.
  la1=50.0; lo1=-5.0
  la2=50+2.83/60; lo2=-5+4.40/60
  h=4
  tp("Worked as you read it, by the same code the command uses:")
  tb()
  printf "      0800 DR               %s  %s\n", fmt_lat(la1), fmt_lon(lo1)
  printf "      0800 star fix         %s  %s\n", fmt_lat(la2), fmt_lon(lo2)
  printf "      hours since the DR    %.0f\n", h
  ll_dist_brg(la1,lo1,la2,lo2)
  tb()
  printf "      the fix lies          %.1f nm  %03d T  from the DR\n", LD_NM, LD_BRG+0.5
  printf "      SET                   %03d T\n", LD_BRG+0.5
  printf "      DRIFT                 %.2f kn\n", LD_NM/h
  tb()
  tp("Reverse the two positions and the set comes out 225 T instead of")
  tp("045 T - the same magnitude, the opposite conclusion, and nothing on")
  tp("the page to tell you which one you did.")
  return 0
}
# =====================================================================
#  Module L -- Latitude the direct way
# =====================================================================
function les_L1(){
  thead("L1","The noon sight: latitude without a reduction")
  tb()
  tp("Everything in modules R and S was about a sight taken at any old")
  tp("moment, from a position you only guessed. There is one moment in the")
  tp("day when none of that is needed.")
  tb()
  tp("At local apparent noon the sun crosses your meridian. Its LHA is")
  tp("zero. Look at what that does to the navigational triangle:")
  tb()
  tp("  1. The angle at the pole IS the LHA, and it has gone to zero. A")
  tp("     triangle with no angle at one corner is not a triangle: the")
  tp("     three points lie on one great circle, your own meridian.")
  tp("  2. So the azimuth has no east-west component at all. The sun bears")
  tp("     due south of you, or due north, and nothing in between.")
  tp("  3. A line of position runs square across the azimuth. Square across")
  tp("     due south is due east and west - a parallel of latitude.")
  tb()
  tp("That is why this sight needs no assumed position and no intercept.")
  tp("You are not comparing what you measured with what you would have")
  tp("measured from somewhere else. You are measuring your latitude.")
  tb()
  tp("The whole method:")
  tb()
  tp("     zenith distance  =  90 - Ho")
  tp("     latitude         =  declination  +/-  zenith distance")
  tb()
  tp("and the sign is only which side of you the sun stood: PLUS the")
  tp("zenith distance if it bore south of you, MINUS if it bore north.")
  tb()
  tp("Three things to know about the moment itself.")
  tb()
  tp("  4. It is not noon by your watch, and it is not noon by local mean")
  tp("     time either. Two corrections stand between: your longitude")
  tp("     (four minutes of time per degree) and the equation of time,")
  tp("     which runs from about 14 minutes behind the clock in February")
  tp("     to 16 minutes ahead of it in November.")
  tp("  5. You do not need to know it in advance. The altitude is at a")
  tp("     maximum, so it is momentarily standing still - it changes as")
  tp("     the SQUARE of the time either side. Follow the sun up, catch")
  tp("     the highest reading it gives you, and watch it start to fall.")
  tp("     The reading is what you want; the clock is not the point.")
  tp("  6. That is the opposite of every other sight you have taken. Four")
  tp("     seconds of clock error moves a star sight a mile. Here it moves")
  tp("     almost nothing, which is why this sight was the backbone of")
  tp("     navigation for two centuries.")
  tb()
  tp("And the honest limit. One sight, one line, and that line is a")
  tp("parallel of latitude: it is true on its own and needs no crossing,")
  tp("but it tells you NOTHING about your longitude. For that you need a")
  tp("second body, or a second sight after a run, or the old trick of")
  tp("equal altitudes either side of noon.")
  tb()
  tp("  celnav noon                      the moment, and what to expect")
  tp("  celnav noon \"2026-10-21\" <Hs>    the latitude from your reading")
  tb()
}
# ---------------------------------------------------------------------
#  The meridian, and a real local apparent noon computed on the spot
# ---------------------------------------------------------------------
function noon_fig(   jd,d,mer,lat,lon,ut){
  tp("          Z    your zenith - and its height above the equator")
  tp("          |    IS your latitude, which is what you want")
  tp("          |")
  tp("          |    90 - Ho, the zenith distance: how far the sun")
  tp("          |    stands from straight overhead")
  tp("          |")
  tp("          *    the sun, on your meridian, bearing due south")
  tp("          |")
  tp("          |    its declination, straight out of the almanac")
  tp("   - - - -+- - - -   the celestial equator")
  tb()
  tp("Read it off the diagram: from the equator up to your zenith is your")
  tp("latitude, and that same span is the declination plus the zenith")
  tp("distance. There is nothing else in it.")
  tb()
  #  Computed here rather than written down, so the lesson cannot drift
  #  away from what the program would actually tell you.
  lat=50.15; lon=-5.0667
  jd=lan_jd(lon, jdate(2026,10,21))
  body_at("Sun", jd); d=B_DEC
  jd2cal(jd); ut=CAL_FRAC*24.0
  mer=90.0-fabs(lat-d)
  tp("A worked one. Falmouth, 50 09'N 005 04'W, on 21 October 2026:")
  tb()
  printf "    the sun crosses your meridian at   %s UT\n", fmt_hms(ut)
  printf "    its declination then is            %s S\n", fmt_dm(fabs(d))
  printf "    so expect a meridian altitude of   %.1f degrees, bearing south\n", mer
  printf "    measure that, and 90 - Ho = %s of zenith distance,\n", fmt_dm(90.0-mer)
  printf "    which minus %s of southerly declination puts you\n", fmt_dm(fabs(d))
  printf "    back on %s.\n", fmt_dm(lat)
  tb()
}
function les_L2(){
  thead("L2","Polaris: latitude from one star, all night long")
  tb()
  tp("The noon sight gives you latitude at one moment of the day. There is")
  tp("another that gives it to you any time the horizon is visible, and it")
  tp("needs even less arithmetic.")
  tb()
  tp("The pole of the sky has no star on it. But one lies close: Polaris,")
  tp("a little over half a degree off. Here is why that matters.")
  tb()
  tp("  1. The altitude of the celestial pole above your horizon IS your")
  tp("     latitude. Exactly, always, by the geometry of the thing - stand")
  tp("     on the equator and the pole is on your horizon; stand at the")
  tp("     pole and it is overhead.")
  tp("  2. So if Polaris sat ON the pole, you would measure your latitude")
  tp("     directly off the sextant, with nothing to correct and no")
  tp("     almanac to open.")
  tp("  3. It does not. It circles the pole once a day at that half a")
  tp("     degree and a bit, so it stands sometimes above the pole and")
  tp("     sometimes below it and mostly to one side.")
  tb()
  tp("The whole correction is therefore one question: where on that little")
  tp("circle is Polaris right now? And its LHA answers it.")
  tb()
  tp("     at upper transit, above the pole:   latitude = Ho - p")
  tp("     at lower transit, below the pole:   latitude = Ho + p")
  tp("     anywhere between:                   latitude = Ho - p cos LHA")
  tb()
  tp("where p is the polar distance, 90 minus the declination.")
  tb()
  tp("  4. The almanac prints this as Ho - 1 degree + a0 + a1 + a2. Do not")
  tp("     let the three columns suggest three ideas: they are one")
  tp("     correction, written as a series. a0 carries almost all of it")
  tp("     and depends on the LHA of Aries; a1 is a small term in your")
  tp("     latitude and a2 a smaller one in the month. The constant degree")
  tp("     is subtracted only so that all three columns can be printed as")
  tp("     positive numbers.")
  tp("  5. CELNAV does not need the series. It has Polaris's own GHA and")
  tp("     declination, so it solves the triangle the star is standing in")
  tp("     and gets the answer in closed form. Ask it for a sight and it")
  tp("     prints both: the first-order correction above, and the exact")
  tp("     one, so you can see the size of what a1 and a2 are for.")
  tb()
  tp("Two honest limits, and the first is not small.")
  tb()
  tp("  6. There is no Polaris in the southern hemisphere. Nothing bright")
  tp("     sits near the south pole - Sigma Octantis is a degree off and")
  tp("     barely visible - so this method simply does not exist below the")
  tp("     equator, and a noon sight does the work instead.")
  tp("  7. It is one line, a parallel of latitude, and tells you nothing")
  tp("     about your longitude. What it does give you is time: Polaris")
  tp("     is up all night, so you are not waiting for a particular")
  tp("     moment the way you are at noon.")
  tb()
  tp("And a long slow caveat worth knowing: Polaris has not always been")
  tp("the pole star and will not stay one. The earth's axis precesses, so")
  tp("the pole is drifting through the sky - Polaris is closing on it now,")
  tp("will be at its nearest around 2100, and in two thousand years will")
  tp("be nowhere near it. That is why the star catalogue in this program")
  tp("carries proper motion and precession rather than fixed positions.")
  tb()
  tp("  celnav polaris                   the correction right now")
  tp("  celnav polaris \"UT\" <Hs>         the latitude from your reading")
  tb()
}
# ---------------------------------------------------------------------
#  Polaris on its circle, and the projection that is the correction
# ---------------------------------------------------------------------
function pol_fig(   jd,lha,p,lat,ho){
  tp("            Polaris goes round the pole once a day:")
  tb()
  tp("                      upper transit")
  tp("                           *   latitude = Ho - p")
  tp("                        .     .")
  tp("                      .         .")
  tp("              *       .    + P   .       *")
  tp("          latitude    .         .     latitude")
  tp("          = Ho        .         .     = Ho")
  tp("                        .     .")
  tp("                           *   latitude = Ho + p")
  tp("                      lower transit")
  tb()
  tp("  P = the celestial pole, whose altitude is your latitude.")
  tp("  p = Polaris's distance from it, about 37' at present.")
  tb()
  tp("Out at the sides, Polaris is level with the pole and its altitude IS")
  tp("your latitude. Above and below, it is wrong by the whole of p. In")
  tp("between, by the part of p that lies along your meridian, which is")
  tp("p cos LHA - and that is the correction, all of it.")
  tb()
  #  Computed when the lesson runs, like L1's, so it cannot drift from
  #  what the program would actually say.
  jd=jdate(2026,10,22)+20.0/24.0
  body_at("Polaris", jd)
  lha=nrm360(B_GHA-5.0667)
  p=(90.0-B_DEC)*60.0
  tp("Tonight, for instance, from 005 04'W at 20:00 UT:")
  tb()
  printf "    Polaris GHA %s, so its LHA is %s\n", fmt_dm(B_GHA,3), fmt_dm(lha,3)
  printf "    its polar distance is %.1f'\n", p
  printf "    so the correction to Ho is %+.1f'\n", -p*cosd(lha)
  tb()
}
# =====================================================================
#  Module B -- The other bodies
# =====================================================================
function les_B1(){
  thead("B1","The moon: where the corrections stop being bookkeeping")
  tb()
  tp("Module S walked the correction chain on a sun sight, and every term")
  tp("in it was small: a couple of minutes of dip, two of refraction,")
  tp("sixteen of semi-diameter, and a parallax of a sixth of a minute you")
  tp("could have ignored and never noticed.")
  tb()
  tp("The moon is the body that makes the chain matter.")
  tb()
  tp("  1. PARALLAX. The corrections you apply are all about turning what")
  tp("     YOU saw into what an observer at the centre of the earth would")
  tp("     have seen, because that is where the almanac stands. For the")
  tp("     sun, 93 million miles away, the earth's radius is nothing. The")
  tp("     moon is a quarter of a million miles away, so the earth's")
  tp("     radius is a real fraction of that, and the correction reaches")
  tp("     about 61 minutes - a whole degree, sixty miles of position.")
  tp("     It is not a refinement. It is the biggest number in the sum.")
  tp("  2. SEMI-DIAMETER, and it GROWS as the moon rises. You measure to")
  tp("     a limb, so you add or subtract the moon's half-width - but when")
  tp("     the moon is overhead you are one earth radius nearer to it than")
  tp("     when it is on your horizon, so it looks very slightly bigger.")
  tp("     That is augmentation, and it is about 0.3' at the zenith.")
  tp("     CELNAV applies it; most tables fold it into the main")
  tp("     correction.")
  tp("  3. WHICH LIMB. Half the month the lower limb is the lit one and")
  tp("     half the month it is not, so a moon sight is the one sight")
  tp("     where you routinely shoot the upper limb - and the")
  tp("     semi-diameter changes sign when you do. Get that wrong and you")
  tp("     are out by twice the semi-diameter, about half a degree, thirty")
  tp("     miles.")
  tb()
  tp("Then the thing that catches people out, which is not a correction at")
  tp("all:")
  tb()
  tp("  4. The moon moves about its own diameter in an hour. Half a degree")
  tp("     an hour is half a minute of arc a minute of time, so four")
  tp("     seconds of clock error is a tenth of a mile and a minute of it")
  tp("     is half a mile. Every sight wants the time to the second; this")
  tp("     one punishes you for less.")
  tb()
  tp("And the reason to bother with all of it:")
  tb()
  tp("  5. The moon is the only body besides the sun that is regularly up")
  tp("     in DAYLIGHT. A sun line crossed with a moon line is the one")
  tp("     two-body fix available at midday, when there is no twilight to")
  tp("     wait for and a running fix would mean two hours of hoping your")
  tp("     course and speed were honest. 'celnav plan' lists the moon")
  tp("     with its phase, and will say so when it is up with the sun.")
  tb()
}
# ---------------------------------------------------------------------
#  The same chain, twice: a sun sight and a moon sight, to scale
# ---------------------------------------------------------------------
function moon_fig(   jd,hs,hm){
  jd=jdate(2026,10,22)+21.0/24.0
  tp("A sun sight first - the same one module S5 works through:")
  tb()
  B_NAME="Sun"; B_SD=15.9; B_HP=0.15
  corr_bars(34.2,1.5,4.0,15,1013,"L")
  tb()
  tp("And a moon sight at the same height of eye, with the moon's own")
  tp("figures for tonight out of the almanac:")
  tb()
  body_at("Moon", jd)
  printf "    (semi-diameter %.1f', horizontal parallax %.1f')\n", B_SD, B_HP
  tb()
  corr_bars(34.2,1.5,4.0,15,1013,"L")
  tb()
  tp("Same sextant reading, same horizon, same air. The sun's corrections")
  tp("very nearly cancel; the moon's do not come close. Read the bars")
  tp("rather than the numbers: that one long row is why a moon sight")
  tp("reduced with the sun's habits is wrong by tens of miles.")
  tb()
}
function les_B2(){
  thead("B2","The planets: a point of light that moves")
  tb()
  tp("After the moon, the planets are a relief. There are four a navigator")
  tp("uses - Venus, Mars, Jupiter, Saturn - and in the sextant they behave")
  tp("almost exactly like stars.")
  tb()
  tp("  1. NO SEMI-DIAMETER. A planet shows a disc only in a telescope; in")
  tp("     a sextant it is a point, so you bring the point itself to the")
  tp("     horizon and there is no limb to choose and no half-width to add.")
  tp("     That alone removes the two corrections that cause most mistakes")
  tp("     on the sun and the moon.")
  tp("  2. ALMOST NO PARALLAX - but not quite none, and this program used")
  tp("     to call it none. Venus comes within 0.27 of the earth's own")
  tp("     distance from the sun, and at that range its parallax reaches")
  tp("     0.5 minutes of arc near the horizon: half a mile. Mars reaches")
  tp("     0.2'. Jupiter and Saturn, four and eight times further out,")
  tp("     give three hundredths of a minute and can be forgotten. The")
  tp("     almanac prints an extra correction for Venus and Mars for")
  tp("     exactly this reason; CELNAV computes it for all four.")
  tb()
  tp("What a planet does have, and a star does not, is motion of its own.")
  tp("That is where the almanac's two odd little columns come from:")
  tb()
  tp("  3. The almanac tabulates GHA and declination for each whole hour,")
  tp("     and you interpolate for the minutes and seconds. For a star")
  tp("     that works perfectly, because a star's GHA advances at the same")
  tp("     rate every hour for ever - the rate the earth turns.")
  tp("  4. A planet is also moving around the sun while you watch, so its")
  tp("     GHA does NOT advance at quite that rate, and the rate itself")
  tp("     changes through the year. The 'v' correction is the difference,")
  tp("     and 'd' is the same idea for the declination.")
  tp("  5. So v and d are not physics. They are the repair work that")
  tp("     tabulating by the hour makes necessary. CELNAV has no need of")
  tp("     either: it computes the position for the second you ask about,")
  tp("     from the orbit, so there is nothing to interpolate and nothing")
  tp("     to correct for having interpolated.")
  tb()
  tp("And the practical reason to care about any of this:")
  tb()
  tp("  6. The planets are BRIGHT. Venus at magnitude -4 and Jupiter at")
  tp("     -2 are far brighter than any star, so they show while the")
  tp("     horizon is still crisp - before the stars come out in the")
  tp("     evening and after they have faded in the morning. That widens")
  tp("     the twilight window at both ends, which is the scarcest thing")
  tp("     in celestial navigation.")
  tp("  7. Venus can be found in broad daylight if you know where to")
  tp("     look, which is the one thing 'celnav plan' is for: it lists")
  tp("     every planet that is up with its altitude, azimuth and")
  tp("     magnitude, so you can point the sextant at empty-looking sky")
  tp("     and find it there.")
  tb()
}
# ---------------------------------------------------------------------
#  A planet and a star, the same reading, side by side
# ---------------------------------------------------------------------
function planet_fig(   jd){
  jd=jdate(2026,10,22)+20.0/24.0
  tp("Vega, at a sextant reading of 20 degrees:")
  tb()
  body_at("Vega", jd)
  corr_bars(20.0,1.5,4.0,15,1013,"C")
  tb()
  tp("And Venus, same reading, same horizon:")
  tb()
  body_at("Venus", jd)
  printf "    (a point source, so no semi-diameter; horizontal parallax %.2f')\n", B_HP
  tb()
  corr_bars(20.0,1.5,4.0,15,1013,"C")
  tb()
  tp("One row of difference, and it is a small one - which is the point.")
  tp("A planet is a star you can shoot earlier in the evening. The work")
  tp("that makes planets awkward is all in the almanac, and none of it is")
  tp("in the sextant.")
  tb()
}
function les_fig(id,   la,lo,zd,b){
  if(id=="F3"){
    gl_init(67,25, 25, -30); gl_graticule(0); gl_limb()
    gl_circle(20,-35,40,"o"); gl_mark(20,-35,"*"); gl_label(20,-35,"GP",2,0)
    dest(20,-35,335,40); gl_mark(DP_LAT,DP_LON,"@"); gl_label(DP_LAT,DP_LON,"you",-4,0)
    dest(20,-35,60,40);  gl_mark(DP_LAT,DP_LON,"@")
    dest(20,-35,150,40); gl_mark(DP_LAT,DP_LON,"@")
    gl_mark(90,0,"N")
    gshow()
    tb(); tp("Altitude 50 degrees, so the zenith distance is 40 degrees, so you are")
    tp("2400 miles from the GP. Every @ satisfies the sight equally well.")
  } else if(id=="F4"){
    gl_init(67,25, 25, -25); gl_graticule(0); gl_limb()
    gl_circle(20,-35,40,"o"); gl_mark(20,-35,"*"); gl_label(20,-35,"1",2,0)
    gl_circle(45,-5,32,"x");  gl_mark(45,-5,"*");  gl_label(45,-5,"2",2,0)
    gl_mark(90,0,"N")
    gshow()
    tb(); tp("Two bodies, two circles, and they cross in two places. Your dead")
    tp("reckoning tells you which crossing is yours - they are a long way apart.")
  } else if(id=="F5"){
    lop_zoom(40,60); gshow()
  } else if(id=="T4"){
    lha_diagram(283.7,-40); gshow()
    tb()
    tp("  |  the Greenwich meridian      o  yours      *  the body's meridian")
    tp("  ---  GHA, measured west from Greenwich")
    tp("  ===  LHA, measured west from your own meridian")
    tp("  Looking down on the north pole. West is clockwise.")
    tb()
    tp("GHA 283 42', longitude 040 00'W, so LHA = 283 42 - 40 00 = 243 42'.")
  } else if(id=="S5"){
    B_NAME="Sun"; B_SD=15.9; B_HP=0.15
    tp("A sun sight: Hs 34 12.0', lower limb, index error 1.5' on the arc,")
    tp("height of eye 4 m, 15 C, 1013 mb.")
    tb()
    corr_bars(34.2,1.5,4.0,15,1013,"L")
    tb()
    tp("Semi-diameter and dip dominate; refraction is small at this altitude;")
    tp("the sun's parallax is almost nothing. For the moon the picture is")
    tp("entirely different - parallax alone can be a whole degree.")
  } else if(id=="R1"){
    tri_diagram(35,20,310)
    arc_mid(90,0,TRI_HC,TRI_ZN); tri_label(AM_ALT,AM_AZ,"90-Hc",-2,1)
    arc_mid(90,0,35,0);          tri_label(AM_ALT,AM_AZ,"90-L",1,0)
    arc_mid(35,0,TRI_HC,TRI_ZN); tri_label(AM_ALT,AM_AZ,"90-d",1,-1)
    gshow()
    tb(); tp("Latitude 35 N, declination 20 N, LHA 310. Z is your zenith at the")
    tp("centre, P the pole, * the body. The rim is your horizon.")
    printf "  Solving it gives Hc %.1f degrees and Zn %.0f degrees true.\n", TRI_HC, TRI_ZN
  } else if(id=="R4"){
    LZN[1]=27; LP[1]=1.5; LLBL[1]="a"
    LZN[2]=128; LP[2]=-19.0; LLBL[2]="b"
    plot_sheet(2,0,0,0,"ONE SIGHT PLOTTED, AND A SECOND CROSSING IT")
  } else if(id=="R5"){
    runfix_fig(110,-22,240,5,245,20); gshow()
    tb()
    tp("  .  the LOP from the first sight, where it fell at the time")
    tp("  =  the same LOP advanced along the run")
    tp("  |  the LOP from the second sight     >  the run     @  the fix")
  } else if(id=="C1"){
    cut_fig(30,150,270,1.2,-0.9,0.6,"THE SAME THREE SIGHTS, SPREAD 120 DEGREES APART")
    tb()
    tp("Each line is one minute of arc off the true position. They close")
    tp("into a cocked hat about a mile across, and the fix is inside it.")
    tb()
    cut_fig(40,55,70,1.2,-0.9,0.6,"AND THE SAME THREE SIGHTS BUNCHED IN ONE QUADRANT")
    tb()
    tp("Identical sights, identical errors, azimuths fifteen degrees")
    tp("apart. The crossings have slid miles out along the one weak")
    tp("direction. No amount of care with the sextant would have helped:")
    tp("the geometry did this, and only a fourth body elsewhere in the sky")
    tp("can undo it.")
  } else if(id=="L1"){
    noon_fig()
  } else if(id=="L2"){
    pol_fig()
  } else if(id=="B1"){
    moon_fig()
  } else if(id=="B2"){
    planet_fig()
  } else if(id=="H1"){
    tab_fig()
  } else if(id=="H3"){
    interp_fig()
  } else if(id=="P1"){
    dr_fig()
  } else if(id=="P2"){
    pos3_fig()
  } else if(id=="P3"){
    curr_fig()
  } else if(id=="C2"){
    tp("A compass swung on eight headings - the same compass, the same")
    tp("ship, the same iron, eight different answers:")
    tb()
    dev_card()
    tb()
    tp("One sky check gives you one row of that table. It is the row you")
    tp("are steering on, which is the row that matters now, but it is not")
    tp("the whole character of the compass. Swing her to learn that.")
  }
  return 0
}

# =====================================================================
#  Module H -- The tables
#  Larry's spec: "teach via HO 249 is an option to select and will work
#  the user step by step through -- but will also in parallel calc w/o
#  the books, and compare the input result from the user to the internal."
# =====================================================================
function les_H1(){
  thead("H1","What a sight reduction table actually is")
  tb()
  tp("Pub. 249 is four volumes of numbers and no explanation, which makes")
  tp("it look like special knowledge. It is not. Every entry in it is the")
  tp("same spherical triangle this program solves, worked out in advance")
  tp("for whole degrees and printed.")
  tb()
  tp("  sin Hc = sin L sin d + cos L cos d cos LHA")
  tb()
  tp("That is the whole of it. Give that formula a latitude, a")
  tp("declination and an LHA and it returns an altitude. Pub. 249 is that")
  tp("formula evaluated for every whole-degree combination a navigator")
  tp("might need, by someone else, before you sailed.")
  tb()
  tp("WHICH IS WHY THIS PROGRAM DOES NOT SHIP THE TABLES. It generates")
  tp("them. Restrict the arguments to whole degrees and the engine IS the")
  tp("table, so the tutor can print the exact page your sight needs")
  tp("instead of the handful of pages an extract would carry.")
  tb()
  tp("THE PRICE OF PRECOMPUTING, which is the thing to understand:")
  tb()
  tp("  1. The table only holds WHOLE degrees. So the assumed position")
  tp("     is not your DR -- it is the whole degree of latitude nearest")
  tp("     it, and whatever longitude makes the LHA come out whole.")
  tp("  2. Declination will not be a whole degree. That is what the d")
  tp("     column is for: how much Hc changes per degree of declination,")
  tp("     so you can interpolate the minutes yourself.")
  tp("  3. The azimuth is printed as an ANGLE from the elevated pole, 0")
  tp("     to 180, not as a true bearing. A rule at the foot of the page")
  tp("     converts it, and which rule depends on your hemisphere and")
  tp("     whether the LHA is more or less than 180.")
  tb()
  tp("None of those three is difficulty. They are the bookkeeping, and the")
  tp("bookkeeping is the whole reason a fix can come out of a book and a")
  tp("pencil with no battery anywhere in it.")
  return 0
}
function tab_fig(   la,de,lh,i){
  la=50; de=-11; lh=329
  tp("A page, generated by this lesson as you read it:")
  tb()
  printf "      LAT %dN   DEC %dS   CONTRARY NAME\n", la, -de
  tb()
  printf "        %5s %11s %8s %6s\n", "LHA", "Hc", "d", "Z"
  for(i=lh-2;i<=lh+2;i++){
    tab_entry(la,de,i)
    printf "        %5d  %4d %04.1f' %+8.1f %6.0f\n",
           i, int(TB_HC), (TB_HC-int(TB_HC))*60, TB_D, TB_Z
  }
  tb()
  tp("Nothing was looked up. Those twenty numbers came out of the same")
  tp("line of trigonometry at the top of this lesson, which is all the")
  tp("book ever contained.")
  return 0
}
function les_H2(){
  thead("H2","Volume 1: the seven selected stars")
  tb()
  tp("Volume 1 is the odd one out and the one worth knowing about.")
  tb()
  tp("It is entered with two arguments only - LHA Aries and your latitude")
  tp("- and it gives you Hc and Zn DIRECTLY, for seven stars chosen for")
  tp("that moment. No declination argument, no interpolation, no azimuth")
  tp("rule. Read seven lines, shoot them, plot them.")
  tb()
  tp("That is possible because the stars do not move relative to Aries")
  tp("within the life of an edition, so their declinations can be built")
  tp("into the table instead of being an argument to it.")
  tb()
  tp("THE SELECTION IS ITSELF AN ALGORITHM. The seven are chosen bright,")
  tp("spread in azimuth, and in the honest altitude band - which is")
  tp("exactly what C1 said makes a good set, and exactly what celnav plan")
  tp("does when it picks the best three by azimuth spread.")
  tb()
  tp("So the app and the book are solving the same problem. They will")
  tp("sometimes disagree, and the disagreement is informative rather than")
  tp("a fault: Volume 1 was computed for a whole degree of latitude and a")
  tp("whole degree of LHA Aries, for an edition that has an epoch, and it")
  tp("does not know what the weather is doing to your horizon tonight.")
  tb()
  tp("Volume 1 also carries the one thing this program cannot: it works")
  tp("with no power at all, in a wet cockpit, by torchlight.")
  return 0
}
function les_H3(){
  thead("H3","Volumes 2 and 3, and the interpolation")
  tb()
  tp("Volumes 2 and 3 are the general case: any body, any declination")
  tp("between 0 and 29 degrees, which covers the sun, the moon, the four")
  tp("planets and the stars near the equator.")
  tb()
  tp("Three columns per entry, and each one has a job:")
  tb()
  tp("  Hc   the computed altitude at the WHOLE degree of declination")
  tp("  d    how much Hc changes per whole degree of declination, signed")
  tp("  Z    the azimuth angle from the elevated pole, 0 to 180")
  tb()
  tp("THE INTERPOLATION IS ONE MULTIPLICATION:")
  tb()
  tp("       Hc = Hc(table) + d x (minutes of declination / 60)")
  tb()
  tp("and the sign of d does the thinking for you, as long as you let it.")
  tp("A negative d means the altitude FALLS as the declination increases,")
  tp("so the correction is subtracted. Applying it the wrong way is the")
  tp("commonest error in the method and it is worth twice the correction,")
  tp("because you move the wrong way by the amount you should have moved")
  tp("the right way.")
  tb()
  tp("THE OTHER TWO MISTAKES, both of which the tutor will name for you:")
  tb()
  tp("  * an LHA one degree out. Silent, plausible, and worth about the")
  tp("    difference between two rows - twenty minutes of arc at a")
  tp("    workaday altitude, so twenty miles.")
  tp("  * reading Zn where the page prints Z. The two agree in one")
  tp("    quadrant and differ by a reflection everywhere else, which is")
  tp("    the worst kind of error: right often enough to feel safe.")
  tb()
  tp("Work a sight both ways - tables mode in this app does it with you,")
  tp("and shows you the exact answer alongside - until the three are")
  tp("habits rather than things to remember.")
  return 0
}
function interp_fig(   la,de,lh,dm,hc,ex){
  la=50; de=-11; lh=329; dm=7.5
  tab_entry(la,de,lh)
  hc = TB_HC + TB_D*(dm/60)/60
  ex = reduce_sight(la,0,lh,de-dm/60)
  tp("The interpolation, worked as you read it:")
  tb()
  printf "      from the page, LHA %d      Hc %s   d %+.1f\n",
         lh, fmt_dm(TB_HC,2), TB_D
  printf "      declination                 %d %04.1f'S\n", -de, dm
  printf "      correction  %+.1f x %.1f/60    %+.1f'\n", TB_D, dm, TB_D*(dm/60)
  printf "      interpolated Hc             %s\n", fmt_dm(hc,2)
  tb()
  printf "      and solved exactly          %s\n", fmt_dm(ex,2)
  printf "      the table costs you         %.1f'\n", fabs(hc-ex)*60
  tb()
  #  The figure computes the cost, so the sentence under it must not
  #  assert a different number: at these arguments it comes out at zero
  #  to the tenth the tables are worked to, and saying "a tenth of a
  #  minute" underneath a printed 0.0' is the kind of drift this project
  #  keeps catching in its own prose.
  tp("Which is to say: the table has cost you nothing you could plot,")
  tp("from arguments of whole degrees. That is what the d column buys,")
  tp("and it is why the method survived two hundred years of use at sea.")
  return 0
}
function les_H4(){
  thead("H4","When the tables beat the calculator, and when they do not")
  tb()
  tp("An honest comparison, because the answer is not that one is better.")
  tb()
  tp("WHAT THE TABLES HAVE")
  tb()
  tp("  They need no power. That is the whole argument and it is enough.")
  tp("  A book in a dry bag works after the batteries are flat, after the")
  tp("  lightning strike, and after the water got into the nav station.")
  tp("  They are also checkable: every number in them is public and the")
  tp("  same for everyone, so an error in your working is findable by")
  tp("  someone else looking at the same page.")
  tb()
  tp("WHAT THEY COST")
  tb()
  tp("  Whole-degree arguments, so an assumed position that is not where")
  tp("  you are and an intercept that has to be plotted. Interpolation by")
  tp("  hand, with three known ways to get it wrong. Volumes that have an")
  tp("  epoch and go slowly out of date. And time: a tabular reduction is")
  tp("  minutes of careful arithmetic where this program takes none.")
  tb()
  tp("WHAT THIS PROGRAM HAS")
  tb()
  tp("  The exact triangle for the second you asked about, from the DR")
  tp("  you actually have, with no interpolation and no assumed position.")
  tp("  And a battery, which is the whole of the case against it.")
  tb()
  tp("THE SENSIBLE POSITION")
  tb()
  tp("Be fluent in both. Work sights by the tables often enough that the")
  tp("method is yours, and use the program when it is there - then the")
  tp("day the power goes you are not learning the method, you are using")
  tp("it. That is the same argument the About page makes about celestial")
  tp("navigation against satellites, one level down.")
  tb()
  tp("And one practical note: check the program against the tables, not")
  tp("the other way round. If they disagree by more than a minute or two,")
  tp("the arguments are wrong somewhere, and the tutor in tables mode")
  tp("exists to tell you which one.")
  return 0
}
# =====================================================================
#  Check questions
# =====================================================================
function ques(id,show){
  if(id=="F1"){ if(show){ tp("Q. You measure an altitude of 62 degrees. What is the zenith distance?")
      tp("     a) 62 degrees      b) 28 degrees      c) 152 degrees") }
    else { Q_ANS="b"; Q_WHY="90 - 62 = 28 degrees, which is 1680 miles from the GP." } }
  else if(id=="F2"){ if(show){ tp("Q. What does a body's declination tell you?")
      tp("     a) the latitude of its GP   b) the longitude of its GP   c) its altitude") }
    else { Q_ANS="a"; Q_WHY="Declination is the latitude of the GP; GHA gives the longitude." } }
  else if(id=="F3"){ if(show){ tp("Q. A sight gives a zenith distance of 30 degrees. How far are you from the GP?")
      tp("     a) 30 miles        b) 300 miles       c) 1800 miles") }
    else { Q_ANS="c"; Q_WHY="30 degrees times 60 miles per degree = 1800 nautical miles." } }
  else if(id=="F4"){ if(show){ tp("Q. Two circles of position cross in two places. What decides which one is you?")
      tp("     a) the brighter body   b) your dead reckoning   c) the higher altitude") }
    else { Q_ANS="b"; Q_WHY="The crossings are usually hundreds of miles apart, so a rough DR settles it." } }
  else if(id=="F5"){ if(show){ tp("Q. Why can a line of position be drawn straight?")
      tp("     a) the circle really is straight   b) over a few tens of miles the")
      tp("        curvature is a fraction of a mile   c) because the earth is flat locally") }
    else { Q_ANS="b"; Q_WHY="Across 60 miles a typical circle departs from the chord by about 0.2 miles." } }
  else if(id=="T1"){ if(show){ tp("Q. Your watch is 20 seconds fast and you do not allow for it. How wrong is the fix?")
      tp("     a) 5 miles of longitude   b) 20 miles of longitude   c) 5 miles of latitude") }
    else { Q_ANS="a"; Q_WHY="Four seconds is one mile, so 20 seconds is five - and it is longitude, not latitude." } }
  else if(id=="T2"){ if(show){ tp("Q. A body has GHA 300 degrees. What longitude is its GP in?")
      tp("     a) 300 degrees west   b) 60 degrees east   c) 60 degrees west") }
    else { Q_ANS="b"; Q_WHY="GHA is measured west, so 300 west is the same place as 60 east." } }
  else if(id=="T3"){ if(show){ tp("Q. How do you get the GHA of a star?")
      tp("     a) it is tabulated for each star   b) GHA Aries plus the star's SHA")
      tp("     c) GHA of the sun plus the star's SHA") }
    else { Q_ANS="b"; Q_WHY="One hour angle for the whole star sphere, plus each star's fixed offset." } }
  else if(id=="T4"){ if(show){ tp("Q. GHA is 210 degrees and you are in longitude 30 degrees east. What is LHA?")
      tp("     a) 180 degrees     b) 240 degrees     c) 330 degrees") }
    else { Q_ANS="b"; Q_WHY="LHA = GHA + longitude east = 210 + 30 = 240 degrees." } }
  else if(id=="T5"){ if(show){ tp("Q. Why does CELNAV never need an almanac update?")
      tp("     a) it stores fifty years of tables   b) it computes the positions")
      tp("     c) it downloads them when it can") }
    else { Q_ANS="b"; Q_WHY="Positions come from orbital theory in the script, so nothing expires." } }
  else if(id=="S1"){ if(show){ tp("Q. Why do you rock the sextant while taking a sight?")
      tp("     a) to steady your hand   b) to find true vertical - the lowest point of the swing")
      tp("     c) to clear the mirrors") }
    else { Q_ANS="b"; Q_WHY="A sextant not held vertical always reads too high. The bottom of the arc is vertical." } }
  else if(id=="S2"){ if(show){ tp("Q. Your height of eye is 9 metres. Roughly what is the dip?")
      tp("     a) 1.8 minutes     b) 5.3 minutes     c) 9 minutes") }
    else { Q_ANS="b"; Q_WHY="1.76 times the square root of 9 = 1.76 x 3 = 5.3 minutes, always subtracted." } }
  else if(id=="S3"){ if(show){ tp("Q. Which sight is least affected by uncertainty in refraction?")
      tp("     a) a body at 8 degrees   b) a body at 25 degrees   c) a body at 60 degrees") }
    else { Q_ANS="c"; Q_WHY="Refraction shrinks fast with altitude - about 0.6 minutes at 60 degrees." } }
  else if(id=="S4"){ if(show){ tp("Q. You take an upper-limb sight of the sun. What do you do with semi-diameter?")
      tp("     a) add about 16 minutes   b) subtract about 16 minutes   c) ignore it") }
    else { Q_ANS="b"; Q_WHY="Upper limb subtract, lower limb add - you are correcting to the centre." } }
  else if(id=="S5"){ if(show){ tp("Q. Which correction is by far the largest for a low moon sight?")
      tp("     a) refraction      b) parallax        c) dip") }
    else { Q_ANS="b"; Q_WHY="The moon's parallax reaches about 61 minutes - over a degree, or 60 miles." } }
  else if(id=="R1"){ if(show){ tp("Q. In the navigational triangle, what is the side from the pole to the body?")
      tp("     a) 90 minus latitude   b) 90 minus declination   c) 90 minus altitude") }
    else { Q_ANS="b"; Q_WHY="Polar distance: 90 minus the declination. The angle at the pole is LHA." } }
  else if(id=="R2"){ if(show){ tp("Q. What is Hc?")
      tp("     a) the altitude you measured   b) the altitude you would have measured")
      tp("        from the assumed position   c) the corrected sextant reading") }
    else { Q_ANS="b"; Q_WHY="Hc comes entirely from the assumed position and the almanac - your sextant plays no part in it." } }
  else if(id=="R3"){ if(show){ tp("Q. Ho is 40 12.0' and Hc is 40 19.0'. What do you plot?")
      tp("     a) 7 miles toward the body   b) 7 miles away from the body")
      tp("     c) 31 miles toward the body") }
    else { Q_ANS="b"; Q_WHY="Hc is the greater, so away: computed greater, away. The difference is 7.0 minutes = 7 miles." } }
  else if(id=="R4"){ if(show){ tp("Q. Which way does the line of position run?")
      tp("     a) along the azimuth   b) at right angles to the azimuth   c) east and west") }
    else { Q_ANS="b"; Q_WHY="The circle is centred on the GP, so it crosses the azimuth square on." } }
  else if(id=="R5"){ if(show){ tp("Q. Three stars all bore between 040 and 070 degrees. What is wrong with the fix?")
      tp("     a) nothing, three sights is three sights   b) the LOPs are nearly parallel,")
      tp("        so the position is poorly fixed along one axis   c) the stars are too bright") }
    else { Q_ANS="b"; Q_WHY="A narrow spread gives a long thin error ellipse. CELNAV reports this in miles." } }
  else if(id=="B2"){ if(show){ tp("Q. The almanac prints a “v” correction for the planets and none for the")
      tp("   stars. What is it for?")
      tp("     a) the planet's semi-diameter   b) the planet's own motion, which")
      tp("        makes its GHA advance at a slightly different rate each hour")
      tp("     c) its parallax") }
    else { Q_ANS="b"; Q_WHY="A star's GHA advances at the rate the earth turns, every hour, for ever. A planet is moving in its own orbit as well, so the hourly rate differs and changes through the year. v is the repair that tabulating by the hour makes necessary - CELNAV computes the position for the second and needs neither v nor d." } }
  else if(id=="B1"){ if(show){ tp("Q. You shoot the moon's UPPER limb but reduce it as a lower-limb sight.")
      tp("   Its semi-diameter is 16'. How far out is your altitude?")
      tp("     a) 16' too high   b) 32' too high   c) 16' too low") }
    else { Q_ANS="b"; Q_WHY="The semi-diameter changes SIGN with the limb, so getting it wrong moves the answer by twice it: 32 minutes of arc, which is 32 miles of position." } }
  else if(id=="L2"){ if(show){ tp("Q. You take Polaris at its lower transit - directly below the pole -")
      tp("   and its polar distance is 37.5'. How does your latitude compare with")
      tp("   the altitude you measured?")
      tp("     a) 37.5' greater than Ho   b) 37.5' less than Ho   c) the same") }
    else { Q_ANS="a"; Q_WHY="Below the pole, the pole stands higher than the star - and the pole's altitude is your latitude. So latitude is Ho plus the polar distance. Above the pole it is Ho minus it." } }
  else if(id=="L1"){ if(show){ tp("Q. At local apparent noon your zenith distance is 60 57.0', the sun's")
      tp("   declination is 10 48.1' S, and the sun bore due south of you. Where are you?")
      tp("     a) 50 08.9' N      b) 71 45.1' N      c) 50 08.9' S") }
    else { Q_ANS="a"; Q_WHY="Latitude is the declination plus the zenith distance, and the declination is southerly: 60 57.0 - 10 48.1 = 50 08.9 N. Adding the two instead gives (b), which is the commonest mistake of all." } }
  else if(id=="C1"){ if(show){ tp("Q. A star stands 8 degrees above the horizon and is beautifully placed")
      tp("   for the cut. Why is it still a poor sight?")
      tp("     a) it is too dim that low   b) refraction down there depends on")
      tp("        air and sea temperatures you do not know   c) its azimuth")
      tp("        changes too fast to time") }
    else { Q_ANS="b"; Q_WHY="Below about 15 degrees the refraction correction stops being arithmetic and becomes a guess. Fast azimuth change is the trouble at the other end of the scale, up near the zenith." } }
  else if(id=="H1"){ if(show){ tp("Q. Why does a sight reduction table use an assumed position rather than")
      tp("   your DR?")
      tp("     a) because the DR is not accurate enough to reduce from")
      tp("     b) because the table only holds whole degrees, and the AP is")
      tp("        where the whole degrees are")
      tp("     c) because the intercept has to be short") }
    else { Q_ANS="b"; Q_WHY="The AP is a bookkeeping choice, not a judgement about your DR: whole-degree latitude and a longitude that makes the LHA whole, because those are the only rows the book has." } }
  else if(id=="H2"){ if(show){ tp("Q. What makes Volume 1 different from Volumes 2 and 3?")
      tp("     a) it is more accurate")
      tp("     b) it gives Hc and Zn directly for seven chosen stars, with no")
      tp("        declination argument and no interpolation")
      tp("     c) it covers declinations above 29 degrees") }
    else { Q_ANS="b"; Q_WHY="The stars' declinations are built into the table instead of being an argument to it, which is why two arguments are enough and nothing needs interpolating." } }
  else if(id=="H3"){ if(show){ tp("Q. The page gives Hc 23 14.8' and d -56.0. Your declination is 11 07.5'S.")
      tp("   What is the interpolated Hc?")
      tp("     a) 23 07.8'      b) 23 21.8'      c) 22 18.8'") }
    else { Q_ANS="a"; Q_WHY="-56.0 x 7.5/60 = -7.0', so 23 14.8' - 7.0' = 23 07.8'. B added it instead of subtracting, which is worth twice the correction. C used the next whole degree of declination." } }
  else if(id=="H4"){ if(show){ tp("Q. What is the one argument for the tables that the calculator cannot")
      tp("   answer?")
      tp("     a) they are more accurate")
      tp("     b) they need no power")
      tp("     c) they are faster") }
    else { Q_ANS="b"; Q_WHY="They are less accurate and much slower. They work when nothing else does, which is the only argument that matters and is sufficient on its own." } }
  else if(id=="P1"){ if(show){ tp("Q. You steer 050 T at 6.5 knots for 90 minutes. How far north and how")
      tp("   far east are you?")
      tp("     a) 6.3 nm north and 7.5 nm east")
      tp("     b) 9.8 nm north and 9.8 nm east")
      tp("     c) 7.5 nm north and 6.3 nm east") }
    else { Q_ANS="a"; Q_WHY="9.75 nm run; northing is distance x cos 50 = 6.3, departure is x sin 50 = 7.5. C has the sine and cosine swapped, which is the mistake to know about." } }
  else if(id=="P2"){ if(show){ tp("Q. Which of the three would you bet the ship on, and why?")
      tp("     a) the DR, because it is arithmetic and cannot be wrong")
      tp("     b) the fix, because it is the only one with an observation in it")
      tp("     c) the EP, because it allows for the current") }
    else { Q_ANS="b"; Q_WHY="The DR's arithmetic being right is not the question - it is right about an assumption. The EP adds a better assumption. Only the fix looked outside the ship." } }
  else if(id=="P3"){ if(show){ tp("Q. Your 0800 DR and your 0800 star fix are 4 miles apart, the fix to the")
      tp("   north-east. The last fix was at 0400. What is the set and drift?")
      tp("     a) set 045 T, drift 1.0 kn")
      tp("     b) set 225 T, drift 1.0 kn")
      tp("     c) set 045 T, drift 4.0 kn") }
    else { Q_ANS="a"; Q_WHY="Set is FROM the DR TOWARD the fix, so 045. Drift is 4 miles over 4 hours = 1 knot. B is the reciprocal and C forgot the hours." } }
  else if(id=="C2"){ if(show){ tp("Q. A star azimuth check gives a compass error of 6 degrees east, and the")
      tp("   chart shows variation 10 degrees west. What is the deviation?")
      tp("     a) 4 degrees east   b) 16 degrees east   c) 16 degrees west") }
    else { Q_ANS="b"; Q_WHY="Error is variation and deviation together. 6 east with 10 west of variation leaves 16 east of deviation - the ship is pulling the card hard the other way." } }
  else { Q_ANS=""; Q_WHY="" }
  return 0
}

# =====================================================================
#  Syllabus and lesson dispatch
# =====================================================================
function syl_init(){
  if(SYL_READY) return
  SYL = "P1|Before the sights|Dead reckoning: course, speed and time;" \
        "P2|Before the sights|Three kinds of position, and which to believe;" \
        "P3|Before the sights|Set and drift: what the sea did while you were not looking;" \
        "F1|Foundations|What a sight actually measures;" \
        "F2|Foundations|The geographical position;" \
        "F3|Foundations|Your altitude puts you on a circle;" \
        "F4|Foundations|Two circles give a fix;" \
        "F5|Foundations|Why we never draw the circles;" \
        "T1|Time and the almanac|Universal Time, and why the clock rules;" \
        "T2|Time and the almanac|GHA and declination;" \
        "T3|Time and the almanac|Aries and SHA: why the stars are different;" \
        "T4|Time and the almanac|LHA: the angle at the pole;" \
        "T5|Time and the almanac|Using the almanac in CELNAV;" \
        "S1|Sextant and corrections|Taking a sight;" \
        "S2|Sextant and corrections|Index error and dip;" \
        "S3|Sextant and corrections|Refraction;" \
        "S4|Sextant and corrections|Semi-diameter and parallax;" \
        "S5|Sextant and corrections|The whole chain, and the size of each part;" \
        "R1|Reduction and the fix|The assumed position and the triangle;" \
        "R2|Reduction and the fix|Hc and Zn;" \
        "R3|Reduction and the fix|The intercept: toward or away;" \
        "R4|Reduction and the fix|Plotting the line of position;" \
        "R5|Reduction and the fix|Crossing, running, and knowing when to doubt it;" \
        "L1|Latitude the direct way|The noon sight: latitude without a reduction;" \
        "L2|Latitude the direct way|Polaris: latitude from one star, all night long;" \
        "B1|The other bodies|The moon: where the corrections stop being bookkeeping;" \
        "B2|The other bodies|The planets: a point of light that moves;" \
        "C1|Choosing and checking|Choosing your bodies: the cut and the band;" \
        "C2|Choosing and checking|Checking the compass against the sky;" \
        "H1|The tables|What a sight reduction table actually is;" \
        "H2|The tables|Volume 1: the seven selected stars;" \
        "H3|The tables|Volumes 2 and 3, and the interpolation;" \
        "H4|The tables|When the tables beat the calculator, and when they do not"
  NSYL=split(SYL,SYLROW,";")
  SYL_READY=1
  return 0
}
function lesson(id){
  if(id=="P1")les_P1(); else if(id=="P2")les_P2(); else if(id=="P3")les_P3()
  else if(id=="F1")les_F1(); else if(id=="F2")les_F2(); else if(id=="F3")les_F3()
  else if(id=="F4")les_F4(); else if(id=="F5")les_F5()
  else if(id=="T1")les_T1(); else if(id=="T2")les_T2(); else if(id=="T3")les_T3()
  else if(id=="T4")les_T4(); else if(id=="T5")les_T5()
  else if(id=="S1")les_S1(); else if(id=="S2")les_S2(); else if(id=="S3")les_S3()
  else if(id=="S4")les_S4(); else if(id=="S5")les_S5()
  else if(id=="R1")les_R1(); else if(id=="R2")les_R2(); else if(id=="R3")les_R3()
  else if(id=="R4")les_R4(); else if(id=="R5")les_R5()
  else if(id=="L1")les_L1(); else if(id=="L2")les_L2()
  else if(id=="B1")les_B1(); else if(id=="B2")les_B2()
  else if(id=="C1")les_C1(); else if(id=="C2")les_C2()
  else if(id=="H1")les_H1(); else if(id=="H2")les_H2()
  else if(id=="H3")les_H3(); else if(id=="H4")les_H4()
  else { print "  no such lesson: " id; return 1 }
  return 0
}
function cmd_t_codes(   i,a,out){
  syl_init()
  out=""
  for(i=1;i<=NSYL;i++){ split(SYLROW[i],a,"|"); out = out (i>1?" ":"") a[1] }
  print out
  return 0
}
function cmd_t_syllabus(   i,a,mod,pm,mark,n,d){
  syl_init()
  print ""
  print "  LEARN -- the syllabus"
  hr()
  mod=""
  n=0
  for(i=1;i<=NSYL;i++){
    split(SYLROW[i],a,"|")
    if(a[2]!=mod){ mod=a[2]; printf "\n  %s\n", toupper(mod) }
    mark = (index("," done ",", "," a[1] ",")>0) ? "x" : " "
    if(mark=="x") n++
    printf "   [%s]  %-4s %s\n", mark, a[1], a[3]
  }
  hr()
  printf "  %d of %d lessons done.  Type a lesson code (F1, R3 ...) to open it.\n", n, NSYL
  print ""
  return 0
}
function cmd_t_lesson(){
  if(lesson(les)){ print ""; exit 2 }
  les_fig(les)
  tb(); hr()
  ques(les,1)
  tb()
  return 0
}
#  THE GATE ASKS THE MODULE'S OWN QUESTIONS.  A separate set would be a
#  second thing to keep in step with the first, and the whole point of the
#  gate is that it tests exactly what the module teaches.
function cmd_t_ques(){
  tb()
  ques(les,1)
  tb()
  return 0
}
#  THE QUESTION'S ANSWER AND REASON, for the web generator.
#
#  ques() holds both, but only sets them on the branch that does NOT
#  print -- so the shell gets them by asking the question again with
#  show=0. The browser needs them as data, and digging them out by
#  running cmd=t_check with a deliberately wrong answer and scraping the
#  verdict would be a second way of reading one fact. Same seam colregs
#  has as cmd=lessonmeta.
function cmd_t_qmeta(){
  ques(les,0)
  printf "%s\t%s\n", Q_ANS, Q_WHY
  return 0
}
#  THE SYLLABUS AS DATA, so the browser's module headings and their order
#  come from syl_init() rather than from being typed again.
function cmd_t_syldump(   i,a){
  syl_init()
  for(i=1;i<=NSYL;i++){ split(SYLROW[i],a,"|"); printf "%s\t%s\t%s\n", a[1], a[2], a[3] }
  return 0
}
function cmd_t_check(){
  ques(les,0)
  tb()
  if(tolower(ans)==Q_ANS){ print "  Correct.  " Q_WHY; print ""; exit 0 }
  printf "  Not quite - the answer is %s.  %s\n", toupper(Q_ANS), Q_WHY
  print ""
  exit 1
}

# =====================================================================
#  Drills -- problems generated from the real almanac, with marking
# =====================================================================
function drill_body(k,   n,a){
  n=split("sun,moon,venus,mars,jupiter,saturn,Sirius,Vega,Dubhe,Arcturus,Capella,Antares,Rigel,Spica,Altair,Polaris",a,",")
  return a[1+int(k*n)]
}
function drill_gen(kind,seed,   i,tries,ok,y,mo,d,hh,b){
  xsrand(seed+0)
  for(i=0;i<3;i++) xrand()
  D_LAT = int((xrand()*110-55)*10)/10.0
  D_LON = int((xrand()*360-180)*10)/10.0
  D_IE  = int((xrand()*6-3)*10)/10.0
  D_HE  = int((2+xrand()*10)*10)/10.0
  D_T   = int(xrand()*30-5)
  D_P   = 990+int(xrand()*40)
  ok=0
  for(tries=0;tries<80 && !ok;tries++){
    y=2026+int(xrand()*7); mo=1+int(xrand()*12); d=1+int(xrand()*28)
    hh=xrand()*24
    D_JD = jdate(y,mo,d) + hh/24.0
    D_BODY = drill_body(xrand())
    if(body_at(D_BODY,D_JD)=="ERR") continue
    reduce_sight(D_LAT,D_LON,B_GHA,B_DEC)
    if(R_HC<12 || R_HC>72) continue
    ok=1
  }
  if(!ok) return 0
  jd2cal(D_JD)
  D_UTC = sprintf("%04d-%02d-%02d %s", CAL_Y,CAL_M,CAL_D, fmt_hms(CAL_FRAC*24))
  D_JD  = parse_utc(D_UTC)
  body_at(D_BODY,D_JD)
  D_GHA=B_GHA; D_DEC=B_DEC; D_SD=B_SD; D_HP=B_HP; D_NAME=B_NAME
  D_LIMB = (D_NAME=="Sun"||D_NAME=="Moon") ? ((xrand()<0.7)?"L":"U") : "C"
  reduce_sight(D_LAT,D_LON,D_GHA,D_DEC)
  D_HC=R_HC; D_ZN=R_ZN; D_LHA=R_LHA
  # build a plausible Hs by working backwards from an Ho a few miles off Hc
  D_OFF = int((xrand()*24-12)*10)/10.0            # intercept, nm
  D_HO  = D_HC + D_OFF/60.0
  D_HS  = invert_corr(D_HO)
  return 1
}
function invert_corr(ho,   ha,i,refr,par,sd,lim,f){
  f=(D_P/1010.0)*(283.0/(273.0+D_T))
  ha=ho
  for(i=0;i<12;i++){
    refr=f/tand(ha+7.31/(ha+4.4)); par=D_HP*cosd(ha); sd=D_SD
    if(D_NAME=="Moon" && sd>0) sd=sd*(1.0+sind(ha)*D_HP/3437.75)
    lim=(D_LIMB=="L"? sd : (D_LIMB=="U"? -sd : 0))
    ha = ho - (par-refr+lim)/60.0
  }
  return ha + D_IE/60.0 + 1.7594*sqrt(D_HE)/60.0
}
function drill_show(kind,   i,zn,p){
  print ""
  if(kind=="corr"){
    print "  DRILL -- sextant corrections"
    hr()
    printf "  Body            %s%s\n", D_NAME, (D_LIMB=="L"?", lower limb":(D_LIMB=="U"?", upper limb":"  (a point source)"))
    printf "  Sextant reading Hs  %s\n", fmt_dm(D_HS,2)
    printf "  Index error         %+.1f'  (positive = on the arc)\n", D_IE
    printf "  Height of eye       %.1f m\n", D_HE
    printf "  Air temperature     %d C        Pressure %d mb\n", D_T, D_P
    if(D_SD>0) printf "  Semi-diameter       %.1f'      Horizontal parallax %.1f'\n", D_SD, D_HP
    hr()
    print "  Work out Ho, the observed altitude."
  } else if(kind=="alm"){
    print "  DRILL -- the almanac"
    hr()
    printf "  Body   %s\n", D_NAME
    printf "  Time   %s UT\n", D_UTC
    hr()
    print "  Look up (or work out) the GHA and declination."
  } else if(kind=="red"){
    print "  DRILL -- sight reduction"
    hr()
    printf "  Assumed position    %s   %s\n", fmt_lat(D_LAT), fmt_lon(D_LON)
    printf "  GHA of the body     %s\n", fmt_dm(D_GHA,3)
    printf "  Declination         %s%s\n", (D_DEC<0?"S":"N"), fmt_dm(fabs(D_DEC),2)
    hr()
    print "  Work out LHA, then Hc and Zn."
  } else if(kind=="int"){
    print "  DRILL -- the intercept"
    hr()
    printf "  Observed altitude Ho   %s\n", fmt_dm(D_HO,2)
    printf "  Computed altitude Hc   %s\n", fmt_dm(D_HC,2)
    printf "  Azimuth Zn             %03d T\n", D_ZN+0.5
    hr()
    print "  How far, and which way do you plot it?"
  } else if(kind=="full"){
    print "  DRILL -- a complete sight"
    hr()
    printf "  %s%s, at %s UT\n", D_NAME, (D_LIMB=="L"?", lower limb":(D_LIMB=="U"?", upper limb":"")), D_UTC
    printf "  Sextant reading Hs  %s      index error %+.1f'\n", fmt_dm(D_HS,2), D_IE
    printf "  Height of eye %.1f m         %d C, %d mb\n", D_HE, D_T, D_P
    printf "  DR position   %s   %s\n", fmt_lat(D_LAT), fmt_lon(D_LON)
    hr()
    print "  Work it through to the intercept and the azimuth."
  } else if(kind=="fix"){
    print "  DRILL -- a three-star fix"
    hr()
    printf "  DR position   %s   %s\n", fmt_lat(D_LAT), fmt_lon(D_LON)
    print ""
    print "     sight      Zn        intercept"
    for(i=1;i<=3;i++)
      printf "     %-10s %03d T   %6.1f nm %s\n", FX_N[i], FX_Z[i]+0.5, fabs(FX_P[i]), (FX_P[i]>=0?"toward":"away")
    hr()
    print "  Plot them and give the fix."
  } else {
    print "  No such drill: " kind
    print "  Try one of: corr  alm  red  int  full  fix"
    print ""
    exit 2
  }
  print ""
  return 0
}
function fix_gen(seed,   i,base,sp,dn,de,cl){
  xsrand(seed+0); for(i=0;i<5;i++) xrand()
  D_LAT = int((xrand()*100-50)*10)/10.0
  D_LON = int((xrand()*360-180)*10)/10.0
  base  = xrand()*360
  sp    = 90+xrand()*60
  dn    = int((xrand()*30-15)*10)/10.0
  de    = int((xrand()*30-15)*10)/10.0
  for(i=1;i<=3;i++){
    FX_Z[i] = nrm360(base+(i-1)*sp+xrand()*10-5)
    FX_P[i] = int((dn*cosd(FX_Z[i])+de*sind(FX_Z[i]))*10)/10.0
    FX_N[i] = drill_body(xrand()*0.4+0.4)
  }
  # least squares back out of the rounded intercepts
  solve3(dn,de)
  cl=cosd(D_LAT); if(fabs(cl)<0.02) cl=0.02
  FX_LAT = D_LAT + SOL_N/60.0
  FX_LON = D_LON + SOL_E/(60.0*cl)
  return 0
}
function solve3(dn,de,   i,A,B,C,D,E2,det){
  A=0;B=0;C=0;D=0;E2=0
  for(i=1;i<=3;i++){
    A+=cosd(FX_Z[i])^2; B+=cosd(FX_Z[i])*sind(FX_Z[i]); C+=sind(FX_Z[i])^2
    D+=FX_P[i]*cosd(FX_Z[i]); E2+=FX_P[i]*sind(FX_Z[i])
  }
  det=A*C-B*B
  SOL_N=(D*C-E2*B)/det; SOL_E=(A*E2-B*D)/det
  return 0
}

# ---- marking ---------------------------------------------------------
function near(a,b,tol){ return (fabs(a-b)<=tol) }
function verdict(ok){ return ok ? cw("CORRECT",C_ACC) : "not right" }
function drill_mark(kind,   ho,got,ok,n,g1,g2,g3,i,dn,de,cl,la,lo,d){
  ok=1
  print ""
  if(kind=="corr"){
    ho = corrections(D_HS,D_IE,D_HE,D_T,D_P,D_LIMB)
    g1 = parse_ang(a1)
    ok = near(g1,ho,0.3/60.0)
    printf "  Your Ho   %s        %s\n", fmt_dm(g1,2), verdict(ok)
    hr()
    B_NAME=D_NAME; B_SD=D_SD; B_HP=D_HP
    corr_bars(D_HS,D_IE,D_HE,D_T,D_P,D_LIMB)
    hr()
    printf "  Correct Ho is %s.\n", fmt_dm(ho,2)
  } else if(kind=="alm"){
    g1 = parse_ang(a1); g2 = parse_ang(a2)
    n  = near(nrm180(g1-D_GHA),0,1.0/60.0); i = near(g2,D_DEC,0.5/60.0)
    ok = (n && i)
    printf "  Your GHA  %-14s %s\n", fmt_dm(g1,3), verdict(n)
    printf "  Your Dec  %-14s %s\n", (g2<0?"S":"N") fmt_dm(fabs(g2),2), verdict(i)
    hr()
    printf "  %s at %s UT:\n", D_NAME, D_UTC
    printf "     GHA %s      Dec %s%s\n", fmt_dm(D_GHA,3), (D_DEC<0?"S":"N"), fmt_dm(fabs(D_DEC),2)
    if(D_SD>0) printf "     SD  %.1f'          HP  %.1f'\n", D_SD, D_HP
  } else if(kind=="red"){
    g1 = parse_ang(a1); g2 = parse_ang(a2)
    n = near(g1,D_HC,0.3/60.0); i = near(nrm180(g2-D_ZN),0,0.6)
    ok = (n && i)
    printf "  Your Hc   %-14s %s\n", fmt_dm(g1,2), verdict(n)
    printf "  Your Zn   %-14s %s\n", sprintf("%.1f T",g2), verdict(i)
    hr()
    printf "  LHA = GHA + longitude = %s + (%s) = %s\n", fmt_dm(D_GHA,3), fmt_lon(D_LON), fmt_dm(D_LHA,3)
    printf "  sin Hc = sin(%.4f) sin(%.4f) + cos(%.4f) cos(%.4f) cos(%.4f)\n", D_LAT,D_DEC,D_LAT,D_DEC,D_LHA
    printf "  Hc = %s          Zn = %.1f T\n", fmt_dm(D_HC,2), D_ZN
  } else if(kind=="int"){
    g1 = a1+0
    n = near(fabs(g1),fabs(D_OFF),0.5)
    i = ((g1>=0) == (D_OFF>=0))
    ok = (n && i)
    printf "  Your intercept  %.1f nm %s     %s\n", fabs(g1), (g1>=0?"toward":"away"), verdict(ok)
    hr()
    printf "  Ho - Hc = %s - %s = %.1f' = %.1f nm %s\n", fmt_dm(D_HO,2), fmt_dm(D_HC,2),
           fabs(D_OFF), fabs(D_OFF), (D_OFF>=0?"TOWARD":"AWAY")
    print  "  Ho the greater means you are nearer the body: plot toward it."
  } else if(kind=="full"){
    ho = corrections(D_HS,D_IE,D_HE,D_T,D_P,D_LIMB)
    g1 = a1+0; g2 = parse_ang(a2)
    n = near(fabs(g1),fabs(D_OFF),0.8) && ((g1>=0)==(D_OFF>=0))
    i = near(nrm180(g2-D_ZN),0,1.0)
    ok = (n && i)
    printf "  Your intercept  %-16s %s\n", sprintf("%.1f nm %s",fabs(g1),(g1>=0?"toward":"away")), verdict(n)
    printf "  Your azimuth    %-16s %s\n", sprintf("%.1f T",g2), verdict(i)
    hr()
    printf "  Hs  %s\n", fmt_dm(D_HS,2)
    B_NAME=D_NAME; B_SD=D_SD; B_HP=D_HP
    corr_bars(D_HS,D_IE,D_HE,D_T,D_P,D_LIMB)
    printf "  GHA %s   Dec %s%s   LHA %s\n", fmt_dm(D_GHA,3), (D_DEC<0?"S":"N"), fmt_dm(fabs(D_DEC),2), fmt_dm(D_LHA,3)
    printf "  Hc  %s   Zn %.1f T\n", fmt_dm(D_HC,2), D_ZN
    printf "  Intercept = Ho - Hc = %.1f nm %s\n", fabs(D_OFF), (D_OFF>=0?"TOWARD":"AWAY")
    LZN[1]=D_ZN; LP[1]=D_OFF; LLBL[1]="a"
    plot_sheet(1,0,0,0,"YOUR LINE OF POSITION")
  } else if(kind=="fix"){
    la = parse_ang(a1); lo = parse_ang(a2)
    d  = sqrt(((la-FX_LAT)*60)^2 + (nrm180(lo-FX_LON)*60*cosd(FX_LAT))^2)
    ok = (d <= 2.0)
    printf "  Your fix   %s  %s      out by %.1f nm   %s\n", fmt_lat(la), fmt_lon(lo), d, verdict(ok)
    hr()
    printf "  Fix   %s   %s\n", fmt_lat(FX_LAT), fmt_lon(FX_LON)
    printf "  which is %.1f nm %s and %.1f nm %s of the DR.\n",
       fabs(SOL_N),(SOL_N>=0?"N":"S"), fabs(SOL_E),(SOL_E>=0?"E":"W")
    for(i=1;i<=3;i++){ LZN[i]=FX_Z[i]; LP[i]=FX_P[i]; LLBL[i]=substr("abc",i,1) }
    plot_sheet(3,SOL_N,SOL_E,1,"THE PLOT")
  }
  print ""
  exit (ok?0:1)
}

# =====================================================================
#  The annotated live reduction -- one real sight, explained line by line
# =====================================================================
function W_setup(){
  W_UTC="2026-08-29 07:30:00"; W_BODY="Dubhe"; W_HS=parse_ang("19 32.1")
  W_IE=1.5; W_HE=3.0; W_T=18; W_P=1013
  W_LAT=parse_ang("35 00 N"); W_LON=parse_ang("040 00 W")
  W_JD=parse_utc(W_UTC)
  body_at(W_BODY,W_JD)
  W_GHA=B_GHA; W_DEC=B_DEC
  W_HO=corrections(W_HS,W_IE,W_HE,W_T,W_P,"C")
  W_HA=C_HA; W_DIP=C_DIP; W_REF=C_REF
  reduce_sight(W_LAT,W_LON,W_GHA,W_DEC)
  W_HC=R_HC; W_ZN=R_ZN; W_LHA=R_LHA
  W_INT=(W_HO-W_HC)*60.0
  return 0
}
function cmd_t_walk(   n){
  W_setup()
  n=step+0
  print ""
  printf "  WALKTHROUGH  step %d of 10\n", n
  hr()
  if(n==1){
    tp("The situation.")
    tb()
    tp("  Morning twilight in the North Atlantic. You believe you are near")
    printf "  %s  %s, and you have no way on.\n", fmt_lat(W_LAT), fmt_lon(W_LON)
    tb()
    tp("  You put the sextant on Dubhe, bring it to the horizon, and at")
    printf "  %s UT you read %s off the arc.\n", W_UTC, fmt_dm(W_HS,2)
    tb()
    tp("  Your index error is +1.5' on the arc and your eye is 3 m above the")
    tp("  water. It is 18 C and 1013 mb.")
    tb()
    tp("  That is everything the reduction will use. Nothing else is needed,")
    tp("  and nothing else is allowed to creep in.")
  } else if(n==2){
    tp("What we are trying to do.")
    tb()
    tp("  The sight puts you somewhere on a circle centred on Dubhe's")
    tp("  geographical position. We cannot draw a circle two thousand miles")
    tp("  across, so instead we ask a smaller question:")
    tb()
    tp("     if I really were at my DR, what altitude would Dubhe have had?")
    tb()
    tp("  Compare that with what you actually measured, and the difference")
    tp("  tells you how far your DR is from the circle - and the azimuth")
    tp("  tells you in which direction. That is the whole method.")
  } else if(n==3){
    tp("Step 1 - the almanac. Where is Dubhe's GP?")
    tb()
    printf "     GHA  %s        the longitude of the GP, measured west\n", fmt_dm(W_GHA,3)
    printf "     Dec  %s%s        the latitude of the GP\n", (W_DEC<0?"S":"N"), fmt_dm(fabs(W_DEC),2)
    tb()
    tp("  So at that instant Dubhe was directly overhead a point in the far")
    printf "  north, latitude %s, longitude %s.\n", fmt_dm(fabs(W_DEC),2) (W_DEC<0?"S":"N"),
           fmt_dm((W_GHA<180?W_GHA:360-W_GHA),3) (W_GHA<180?"W":"E")
    tb()
    tp("  Nothing about you enters here. Two navigators anywhere on earth")
    tp("  would use the same two numbers for this instant.")
  } else if(n==4){
    tp("Step 2 - LHA. Bring it round to your own meridian.")
    tb()
    printf "     LHA = GHA + longitude = %s + (%s)\n", fmt_dm(W_GHA,3), fmt_lon(W_LON)
    printf "         = %s\n", fmt_dm(W_LHA,3)
    tb()
    tp("  Longitude west counts as negative. LHA is measured westward from")
    tp("  you, so 243 degrees west is the same as 117 degrees to the east of")
    tp("  you - which fits: this is a morning sight and the star is in the")
    tp("  northern sky, well round to the east.")
  } else if(n==5){
    tp("Step 3 - correct the sextant reading.")
    tb()
    B_NAME="Star"; B_SD=0; B_HP=0
    corr_bars(W_HS,W_IE,W_HE,W_T,W_P,"C")
    tb()
    tp("  A star is a point of light, so there is no semi-diameter, and it is")
    tp("  far enough away that parallax does not arise. Only index error, dip")
    tp("  and refraction apply.")
    printf "  Ho = %s. That is the sight, cleaned up.\n", fmt_dm(W_HO,2)
  } else if(n==6){
    tp("Step 4 - the triangle. This is the geometry the arithmetic solves.")
    tri_diagram(W_LAT,W_DEC,W_LHA)
    arc_mid(90,0,TRI_HC,TRI_ZN); tri_label(AM_ALT,AM_AZ,"90-Hc",-2,1)
    arc_mid(90,0,W_LAT,0);       tri_label(AM_ALT,AM_AZ,"90-L",1,0)
    arc_mid(W_LAT,0,TRI_HC,TRI_ZN); tri_label(AM_ALT,AM_AZ,"90-d",1,-1)
    gshow()
    tb()
    tp("  Z is your zenith, P the north pole, * is Dubhe. You know the side")
    tp("  Z-P (90 minus your latitude), the side P-* (90 minus declination),")
    tp("  and the angle between them at P (that is LHA). Everything else")
    tp("  follows.")
  } else if(n==7){
    tp("Step 5 - solve it for Hc and Zn.")
    tb()
    printf "     sin Hc = sin(%.3f) sin(%.3f) + cos(%.3f) cos(%.3f) cos(%.3f)\n",
           W_LAT, W_DEC, W_LAT, W_DEC, W_LHA
    printf "     Hc = %s          Zn = %s\n", fmt_dm(W_HC,2), fmt_dm(W_ZN,3)
    tb()
    tp("  Hc is the altitude Dubhe would have had if you really were at your")
    tp("  DR. Zn is the bearing it would have had from there. Note that your")
    tp("  sextant has played no part at all in these two numbers.")
  } else if(n==8){
    tp("Step 6 - compare, and get the intercept.")
    tb()
    printf "     Ho (measured)  %s\n", fmt_dm(W_HO,2)
    printf "     Hc (computed)  %s\n", fmt_dm(W_HC,2)
    printf "     difference     %.1f minutes of arc = %.1f nautical miles\n", fabs(W_INT), fabs(W_INT)
    tb()
    printf "  Ho is the %s, so you are %s the star than the DR was:\n",
           (W_INT>=0?"greater":"smaller"), (W_INT>=0?"nearer to":"further from")
    printf "  %.1f miles %s, along Zn %s.\n", fabs(W_INT), (W_INT>=0?"TOWARD":"AWAY"), fmt_dm(W_ZN,3)
    tb()
    tp("  A bigger altitude means a smaller zenith distance, and a smaller")
    tp("  zenith distance means you are closer to the GP. That is the whole")
    tp("  reason the rule runs that way.")
  } else if(n==9){
    tp("Step 7 - plot it.")
    LZN[1]=W_ZN; LP[1]=W_INT; LLBL[1]="a"
    plot_sheet(1,0,0,0,"ONE SIGHT, PLOTTED")
    tb()
    tp("  From the AP, go along the azimuth by the intercept, and draw the")
    tp("  line of position square across it. You are somewhere on that line.")
    tp("  One sight can do no more than this - and it is already worth having,")
    tp("  because it is a hard constraint on where you can be.")
  } else if(n==10){
    tp("Step 8 - cross it with two more.")
    LZN[1]=W_ZN;  LP[1]=W_INT;  LLBL[1]="a"
    LZN[2]=128.3; LP[2]=-19.0;  LLBL[2]="b"
    LZN[3]=269.2; LP[3]=16.2;   LLBL[3]="c"
    plot_sheet(3,9.9,-16.4,1,"THREE SIGHTS: THE FIX")
    tb()
    tp("  Bellatrix and Markab were shot in the same few minutes. Three lines,")
    tp("  one crossing point, and the fix is about 10 miles north and 16 west")
    tp("  of where you thought you were.")
    tb()
    tp("  That is a complete reduction. Everything else CELNAV does - the")
    tp("  running fix, the geometry warning, the planning list - is built on")
    tp("  exactly these eight steps.")
  }
  print ""
  return 0
}

# =====================================================================
#  Sandbox: change one thing and watch the triangle move
# =====================================================================
function cmd_t_sandbox(   la,de,lh,hc,zn){
  la=slat+0; de=sdec+0; lh=nrm360(slha+0)
  tri_diagram(la,de,lh)
  arc_mid(90,0,TRI_HC,TRI_ZN); tri_label(AM_ALT,AM_AZ,"90-Hc",-2,1)
  arc_mid(90,0,(la>=0?la:-la),(la>=0?0:180)); tri_label(AM_ALT,AM_AZ,"90-L",1,0)
  arc_mid((la>=0?la:-la),(la>=0?0:180),TRI_HC,TRI_ZN); tri_label(AM_ALT,AM_AZ,"90-d",1,-1)
  print ""
  print "  SANDBOX -- the navigational triangle"
  hr()
  gshow()
  hr()
  printf "  latitude %7.1f    declination %7.1f    LHA %7.1f\n", la, de, lh
  printf "  %s\n", cw(sprintf("  computed altitude Hc %.2f      azimuth Zn %.1f T", TRI_HC, TRI_ZN), C_ACC)
  hr()
  if(TRI_HC<0) print "  The body is below the horizon from here - no sight is possible."
  else if(TRI_HC>80) print "  Very high: the azimuth swings fast, so a small position error moves Zn a lot."
  else if(TRI_HC<15) print "  Low: refraction is uncertain down here."
  if(fabs(nrm180(lh))<3) print "  LHA near zero: the body is on your meridian - this is the noon sight,"
  if(fabs(nrm180(lh))<3) print "  where altitude alone gives latitude and the azimuth is due north or south."
  print ""
  return 0
}

BEGIN{
  col_init()
  if(cmd=="t_codes")          cmd_t_codes()
  else if(cmd=="t_syllabus")  cmd_t_syllabus()
  else if(cmd=="t_lesson")    cmd_t_lesson()
  else if(cmd=="t_check")     cmd_t_check()
  else if(cmd=="t_qmeta")     cmd_t_qmeta()
  else if(cmd=="t_syldump")   cmd_t_syldump()
  else if(cmd=="t_ques")      cmd_t_ques()
  else if(cmd=="t_walk")      cmd_t_walk()
  else if(cmd=="t_sandbox")   cmd_t_sandbox()
  else if(cmd=="t_drill"){
    if(kind=="fix"){ fix_gen(seed) } else { if(!drill_gen(kind,seed)){ print "  could not build a problem"; exit 2 } }
    drill_show(kind)
  }
  else if(cmd=="t_mark"){
    if(kind=="fix"){ fix_gen(seed) } else { if(!drill_gen(kind,seed)){ print "  could not build a problem"; exit 2 } }
    drill_mark(kind)
  }
}
