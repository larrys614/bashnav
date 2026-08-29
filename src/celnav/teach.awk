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
  }
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
  else { Q_ANS=""; Q_WHY="" }
  return 0
}

# =====================================================================
#  Syllabus and lesson dispatch
# =====================================================================
function syl_init(){
  if(SYL_READY) return
  SYL = "F1|Foundations|What a sight actually measures;" \
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
        "R5|Reduction and the fix|Crossing, running, and knowing when to doubt it"
  NSYL=split(SYL,SYLROW,";")
  SYL_READY=1
  return 0
}
function lesson(id){
  if(id=="F1")les_F1(); else if(id=="F2")les_F2(); else if(id=="F3")les_F3()
  else if(id=="F4")les_F4(); else if(id=="F5")les_F5()
  else if(id=="T1")les_T1(); else if(id=="T2")les_T2(); else if(id=="T3")les_T3()
  else if(id=="T4")les_T4(); else if(id=="T5")les_T5()
  else if(id=="S1")les_S1(); else if(id=="S2")les_S2(); else if(id=="S3")les_S3()
  else if(id=="S4")les_S4(); else if(id=="S5")les_S5()
  else if(id=="R1")les_R1(); else if(id=="R2")les_R2(); else if(id=="R3")les_R3()
  else if(id=="R4")les_R4(); else if(id=="R5")les_R5()
  else { print "  no such lesson: " id; return 1 }
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
  if(cmd=="t_syllabus")       cmd_t_syllabus()
  else if(cmd=="t_lesson")    cmd_t_lesson()
  else if(cmd=="t_check")     cmd_t_check()
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
