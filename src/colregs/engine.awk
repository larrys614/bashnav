# =====================================================================
#  colregs -- the engine
#  Lights, shapes, encounters, sound signals and the rules themselves,
#  drawn in characters.  Pure POSIX awk.
# =====================================================================

function d2r(x){ return x*0.0174532925199432958 }
function sind(x){ return sin(x*0.0174532925199432958) }
function cosd(x){ return cos(x*0.0174532925199432958) }
function fabs(x){ return (x<0)?-x:x }
function nrm360(x){ x=x-360*int(x/360); if(x<0) x+=360; return x }
function nrm180(x){ x=nrm360(x); if(x>180) x-=360; return x }

# ---- colour ----------------------------------------------------------
#  day   : white on black, lights in their true colours
#  night : everything red, because dark adaptation is worth more than
#          a pretty screen.  Every light also carries its letter, so the
#          pattern is still unambiguous with no colour at all.
function col_init(   e){
  if(COL_READY) return
  e=sprintf("%c",27)
  if(cmode=="night"){
    C_BASE=e "[40m" e "[31m"; C_ACC=e "[1;31m"; C_DIM=e "[2;31m"
    K_W=e "[1;31m"; K_R=e "[1;31m"; K_G=e "[1;31m"; K_Y=e "[1;31m"
  } else if(cmode=="day"){
    C_BASE=e "[40m" e "[37m"; C_ACC=e "[1;32m"; C_DIM=e "[90m"
    K_W=e "[1;97m"; K_R=e "[1;91m"; K_G=e "[1;92m"; K_Y=e "[1;93m"
  } else {
    C_BASE=""; C_ACC=""; C_DIM=""; K_W=""; K_R=""; K_G=""; K_Y=""
  }
  C_RST=C_BASE
  if(cmode=="night"){ C_PANEL=e "[40m" e "[31m"; C_EOL=e "[K" C_BASE }
  else if(cmode=="day"){ C_PANEL=e "[40m" e "[37m"; C_EOL=e "[K" C_BASE }
  else { C_PANEL=""; C_EOL="" }
  COL_READY=1
  return 0
}
function cw(s,c){ col_init(); if(c=="") return s; return c s C_RST }
function cwd(s){ col_init(); return cw(s,C_DIM) }
function kcol(c){ col_init()
  if(c=="R") return K_R; if(c=="G") return K_G; if(c=="Y") return K_Y; return K_W }

# ---- canvas ----------------------------------------------------------
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

function gclear(w,h,   r,c){ col_init(); PW=w; PH=h
  for(r=0;r<h;r++) for(c=0;c<w;c++){ G[r,c]=" "; GC[r,c]="" } }
function gput(r,c,ch){ r=int(r+0.5); c=int(c+0.5)
  if(r>=0&&r<PH&&c>=0&&c<PW){ G[r,c]=ch; GC[r,c]="" } }
function gputc(r,c,ch,col){ r=int(r+0.5); c=int(c+0.5)
  if(r>=0&&r<PH&&c>=0&&c<PW){ G[r,c]=ch; GC[r,c]=col } }
function gputw(r,c,ch){ r=int(r+0.5); c=int(c+0.5)
  if(r>=0&&r<PH&&c>=0&&c<PW&&G[r,c]==" "){ G[r,c]=ch; GC[r,c]="" } }
function gputwc(r,c,ch,col){ r=int(r+0.5); c=int(c+0.5)
  if(r>=0&&r<PH&&c>=0&&c<PW&&G[r,c]==" "){ G[r,c]=ch; GC[r,c]=col } }
function gputs(r,c,s,   i){ for(i=1;i<=length(s);i++) gput(r,c+i-1,substr(s,i,1)) }
function gputsc(r,c,s,col,   i){ for(i=1;i<=length(s);i++) gputc(r,c+i-1,substr(s,i,1),col) }
#  The drawing is always painted as its own black panel with light text,
#  whatever the terminal profile is set to - otherwise white artwork on a
#  white Terminal background is invisible.  Only the lamps carry colour.
function gshow(   r,c,line,cur,last,cc,r0){
  r0=0
  if(!G_NOCROP)
  for(r=0;r<PH;r++){ last=-1
    for(c=0;c<PW;c++) if(G[r,c]!=" ") last=c
    if(last>=0){ r0=r; break }
  }
  for(r=r0;r<PH;r++){
    last=-1
    for(c=0;c<PW;c++) if(G[r,c]!=" ") last=c
    line=""; cur=""
    for(c=0;c<=last;c++){
      cc=GC[r,c]
      if(cc!=cur){ line=line (cc==""? C_PANEL : cc); cur=cc }
      line=line G[r,c]
    }
    print "  " C_PANEL line C_EOL
  }
  return 0
}
function hr(){ print "  ----------------------------------------------------------------------" }
function tp(s){ print "  " s }
function tb(){ print "" }

# =====================================================================
#  Lights.  Each light is  x,y,h,arc,colour
#    x   fore-and-aft position, +0.5 bow to -0.5 stern
#    y   athwartships, + to starboard
#    h   height above the waterline, 0 to 1
#    arc M masthead 225 deg | S starboard 112.5 | P port 112.5
#        T sternlight 135  | A all round        | Y towing (as stern)
#    colour W R G Y
#  Visibility is decided by the arc and the bearing of the observer from
#  the vessel, so the same table draws the vessel from any angle.
# =====================================================================
function lights_init(   i,n,a){
  if(LT_READY) return
  MF = "0.15,0,0.72,M,W"                    # masthead, forward
  MA = "-0.10,0,0.92,M,W"                   # masthead, aft and higher
  SG = "0.06,0.11,0.42,S,G"                 # starboard sidelight
  SR = "0.06,-0.11,0.42,P,R"                # port sidelight
  ST = "-0.46,0,0.36,T,W"                   # sternlight
  TY = "-0.46,0,0.50,T,Y"                   # towing light, yellow
  LT_READY=1
  return 0
}
function ar(x,y,h,c){ return sprintf("%.3f,%.3f,%.3f,A,%s,",x,y,h,c) }
#  Same, but out on a yard: the drawing joins these to their partner with
#  a spar, so three greens read as one on the mast and two on the yard
#  rather than as three greens scattered across the sky.
function yd(x,y,h,c){ return sprintf("%.3f,%.3f,%.3f,A,%s,yard",x,y,h,c) }

# vessel table: key | short name | rule | lights (semicolon list) | note
function ves_init(   i,n,a){
  if(VES_READY) return
  lights_init()
  VT[1]  = "power50|Power-driven vessel under 50 m, under way|Rule 23|" MF ";" SG ";" SR ";" ST "|One masthead light, sidelights, sternlight."
  VT[2]  = "power50p|Power-driven vessel of 50 m or more, under way|Rule 23|" MF ";" MA ";" SG ";" SR ";" ST "|Two masthead lights, the after one higher."
  VT[3]  = "sail|Sailing vessel under way|Rule 25|" SG ";" SR ";" ST "|Sidelights and a sternlight. No masthead light - that is the whole point."
  VT[4]  = "sailrg|Sailing vessel, optional all-round pair|Rule 25|" SG ";" SR ";" ST ";" ar(0.15,0,0.80,"R") ";" ar(0.15,0,0.70,"G") "|Red over green at the masthead, with normal sidelights and sternlight."
  VT[5]  = "anchor|Vessel at anchor, under 50 m|Rule 30|" ar(0.35,0,0.70,"W") "|A single all-round white light where it can best be seen."
  VT[6]  = "anchor50|Vessel at anchor, 50 m or more|Rule 30|" ar(0.38,0,0.80,"W") ";" ar(-0.35,0,0.55,"W") "|Two all-round whites, forward one higher, and the decks lit."
  VT[7]  = "aground|Vessel aground|Rule 30|" ar(0.35,0,0.72,"W") ";" ar(0.10,0,0.88,"R") ";" ar(0.10,0,0.78,"R") "|Anchor light or lights, plus two all-round reds in a vertical line."
  VT[8]  = "nuc|Not under command, making no way|Rule 27|" ar(0.10,0,0.88,"R") ";" ar(0.10,0,0.78,"R") "|Two all-round reds. Nothing else if she is not moving through the water."
  VT[9]  = "nucway|Not under command, making way|Rule 27|" ar(0.10,0,0.88,"R") ";" ar(0.10,0,0.78,"R") ";" SG ";" SR ";" ST "|Two all-round reds, and because she is making way, sidelights and sternlight too."
  VT[10] = "ram|Restricted in her ability to manoeuvre|Rule 27|" ar(0.10,0,0.99,"R") ";" ar(0.10,0,0.89,"W") ";" ar(0.10,0,0.79,"R") ";" MF ";" SG ";" SR ";" ST "|Red, white, red in a vertical line. Making way, so the ordinary lights as well.|the lower two of her three lights are red over white, which on its own is a vessel fishing. The third light, red on top, is what makes her restricted in her ability to manoeuvre."
  VT[11] = "draught|Constrained by her draught|Rule 28|" ar(0.10,0,0.99,"R") ";" ar(0.10,0,0.89,"R") ";" ar(0.10,0,0.79,"R") ";" MF ";" SG ";" SR ";" ST "|Three all-round reds in a vertical line, over the ordinary power-driven lights."
  VT[12] = "trawl|Vessel trawling|Rule 26|" ar(0.15,0,0.88,"G") ";" ar(0.15,0,0.76,"W") ";" SG ";" SR ";" ST "|Green over white. Green for a trawl dragged along the bottom.|green over white is trawling; red over white is fishing other than trawling. Green for the gear dragged along the ground."
  VT[13] = "fishing|Fishing, other than trawling|Rule 26|" ar(0.15,0,0.88,"R") ";" ar(0.15,0,0.76,"W") ";" SG ";" SR ";" ST "|Red over white. The old rhyme: red over white, fishing at night.|red over white is fishing other than trawling; green over white is a trawler. Both keep gear streamed a long way from the vessel."
  VT[14] = "pilot|Pilot vessel on duty|Rule 29|" ar(0.15,0,0.88,"W") ";" ar(0.15,0,0.76,"R") ";" SG ";" SR ";" ST "|White over red: pilot ahead. Sidelights and sternlight when under way.|white over red is the pilot; red over white is fishing. They are the same two colours the other way up, and it is the commonest mistake made at night."
  VT[15] = "tow200|Towing, tow under 200 m|Rule 24|" MF ";" "0.15,0,0.84,M,W" ";" SG ";" SR ";" ST ";" TY "|Two masthead lights in a vertical line, and a yellow towing light above the sternlight."
  VT[16] = "tow200p|Towing, tow over 200 m|Rule 24|" MF ";" "0.15,0,0.84,M,W" ";" "0.15,0,0.96,M,W" ";" SG ";" SR ";" ST ";" TY "|Three masthead lights in a vertical line - the tow is longer than 200 m."
  VT[17] = "towed|Vessel being towed|Rule 24|" SG ";" SR ";" ST "|Sidelights and a sternlight, and nothing else. She looks like a sailing vessel until you see what is ahead of her."
  #  Rule 27(f): one green at or near the foremast head and one at each
  #  end of the FORE YARD - all three on the same mast. They used to be
  #  given different fore-and-aft positions, which threw the two yard
  #  lights off to one side and made them impossible to account for.
  VT[18] = "mineclear|Mine clearance vessel|Rule 27|" MF ";" SG ";" SR ";" ST ";" ar(0.15,0,0.98,"G") ";" yd(0.15,0.15,0.82,"G") ";" yd(0.15,-0.15,0.82,"G") "|Three all-round greens: one at the foremast head and one at each end of the fore yard. Keep 1000 m clear.|The top green sits over the masthead white, and green over white on its own is a trawler. The two greens out on the yard are what tell you it is not."
  VT[19] = "hover|Air-cushion vessel in non-displacement mode|Rule 23|" MF ";" SG ";" SR ";" ST ";" ar(0.15,0,0.60,"Y") "|The ordinary power-driven lights plus an all-round flashing yellow."
  VT[20] = "sail7|Sailing vessel under 7 m, or a vessel under oars|Rule 25|" ar(0.0,0,0.35,"W") "|If she carries nothing else she must show a torch or lantern in time to prevent collision."
  NVES=20
  VES_READY=1
  return 0
}
function ves_find(key,   i,a){
  ves_init()
  for(i=1;i<=NVES;i++){ split(VT[i],a,"|"); if(a[1]==key) return i }
  return 0
}
# is a light with this arc visible from bearing th (0 = dead ahead of her)?

# ---------------------------------------------------------------------
#  The second question a lookout asks: which way is she going?
#  It follows from which lights you can see, not from what she is.
# ---------------------------------------------------------------------
function motion_of(idx,th,   a,n,L,i,f,g,r,w,m,key){
  ves_init()
  split(VT[idx],a,"|"); key=a[1]; n=split(a[4],L,";")
  g=0;r=0;w=0;m=0
  for(i=1;i<=n;i++){
    split(L[i],f,",")
    if(!arc_vis(f[4],th)) continue
    if(f[4]=="S") g=1
    else if(f[4]=="P") r=1
    else if(f[4]=="T") w=1
    else if(f[4]=="M") m=1
  }
  MO_G=g; MO_R=r; MO_W=w; MO_M=m
  if(key=="anchor"||key=="anchor50"||key=="aground"||key=="sail7") return 5
  if(key=="nuc") return 5
  if(g&&r) return 1
  if(g) return 2
  if(r) return 3
  if(w) return 4
  return 5
}
function motion_text(k){
  if(k==1) return "End on, or nearly: she is coming straight at you."
  if(k==2) return "Crossing from your left to your right."
  if(k==3) return "Crossing from your right to your left."
  if(k==4) return "Going away from you - you are overtaking her."
  return "She is not under way, or not making way through the water."
}
function motion_why(k,idx,   a){
  split(VT[idx],a,"|")
  if(k==1) return "Both sidelights at once means you are within a degree or two of her bow, and she of yours. Her red appears on your right and her green on your left, because she is facing you. Rule 14: neither of you stands on - each alters to starboard and you pass port to port."
  if(k==2) return "Her green sidelight is her starboard side, so you are standing in her starboard sector and she is heading from your left to your right. Which also tells you who gives way: she has YOU on her starboard side, so under Rule 15 she is the one who must keep out of the way. You stand on and hold your course - while watching her like a hawk."
  if(k==3) return "Her red sidelight is her port side, so you are in her port sector and she is heading from your right to your left. In a crossing situation that puts her on your own starboard side, which makes you the give-way vessel: alter to starboard and pass under her stern. If to starboard red appear, it is your duty to keep clear."
  if(k==4) return "A sternlight and no sidelight means you are more than 22.5 degrees abaft her beam. You are overtaking her, and you keep out of her way until you are finally past and clear."
  return "No sidelights and no sternlight: she is not making way through the water. Anchored, aground, or stopped."
}

function light_sig(idx,th,   a,n,L,i,f,cnt,j,t1,t2,sig){
  ves_init()
  split(VT[idx],a,"|"); n=split(a[4],L,";")
  cnt=0
  for(i=1;i<=n;i++){
    split(L[i],f,",")
    if(!arc_vis(f[4],th)) continue
    cnt++; SGH[cnt]=f[3]+0
    #  what you can actually judge: the colour, and how far the light sits
    #  left or right of the others.  Absolute height is not something you can
    #  measure at night, so it is deliberately left out.
    SGC[cnt]=f[5] sprintf("%d", int(((f[1]+0)*sind(th) - (f[2]+0)*cosd(th))/0.06 + 100))
  }
  for(i=2;i<=cnt;i++){ t1=SGH[i]; t2=SGC[i]; j=i-1
    while(j>=1 && SGH[j]<t1){ SGH[j+1]=SGH[j]; SGC[j+1]=SGC[j]; j-- }
    SGH[j+1]=t1; SGC[j+1]=t2 }
  sig=""
  for(i=1;i<=cnt;i++) sig=sig SGC[i] ","
  return sig
}
function arc_vis(arc,th){
  th=nrm180(th)
  if(arc=="A") return 1
  if(arc=="M") return (fabs(th)<=112.5)
  #  Sidelights meet at the bow, but Annex I allows the cut-off to fall up
  #  to 3 degrees outside the prescribed sector, and in practice there is a
  #  small arc right ahead where both are seen. Without that overlap the
  #  picture claims you are dead ahead of her while showing one sidelight.
  if(arc=="S") return (th>=-2.5 && th<=112.5)
  if(arc=="P") return (th<=2.5  && th>=-112.5)
  if(arc=="T" || arc=="Y") return (fabs(th)>=112.5)
  return 0
}

# ---- draw one vessel's lights as seen from bearing th ----------------
function draw_lights(key,th,   i,idx,a,n,L,j,f,w,h,sea,us,vs,cx,u,v,hw,c,col,maxv,cnt,r0,ylo,yhi,yv){
  idx=ves_find(key); if(idx==0){ print "  unknown vessel: " key; return 1 }
  split(VT[idx],a,"|")
  V_NAME=a[2]; V_RULE=a[3]; V_NOTE=a[5]; V_TRAP=a[6]; V_IDX=idx; V_TH=th
  n=split(a[4],L,";")
  w=67; h=17; sea=h-3; cx=int(w/2); us=(w-8)/1.5; vs=sea-1
  gclear(w,h)
  G_NOCROP=1
  gputsc(0,0,"masthead height",C_DIM)
  gputsc(sea-1,0,"deck",C_DIM)
  for(i=0;i<w;i++) gputw(sea+1,i,"~")
  hw = (1.00*fabs(sind(th)) + 0.22*fabs(cosd(th)))/2.0
  for(i=-hw;i<=hw;i+=0.01) gputw(sea, cx+i*us, "=")
  gputw(sea, cx-hw*us, "\\"); gputw(sea, cx+hw*us, "/")
  # a faint line under each light, so the vertical grouping is plain
  cnt=0
  for(i=1;i<=n;i++){
    split(L[i],f,",")
    if(!arc_vis(f[4],th)) continue
    u = (f[1]+0)*sind(th) - (f[2]+0)*cosd(th)
    for(v=0;v<=(f[3]+0);v+=0.02) gputwc(sea-v*vs, cx+u*us, ":", C_DIM)
  }
  #  the yard the outboard lights are hung from, drawn before the lights
  #  so the lights sit on top of it
  ylo=99; yhi=-99; yv=-1
  for(i=1;i<=n;i++){
    split(L[i],f,",")
    if(f[6]!="yard" || !arc_vis(f[4],th)) continue
    u = (f[1]+0)*sind(th) - (f[2]+0)*cosd(th)
    if(u<ylo) ylo=u
    if(u>yhi) yhi=u
    yv = f[3]+0
  }
  if(yv>=0 && yhi>ylo)
    for(u=ylo;u<=yhi;u+=0.01) gputwc(sea-yv*vs, cx+u*us, "-", C_DIM)
  for(i=1;i<=n;i++){
    split(L[i],f,",")
    if(!arc_vis(f[4],th)) continue
    u = (f[1]+0)*sind(th) - (f[2]+0)*cosd(th)
    v = f[3]+0
    c = f[5]
    gputc(sea - v*vs, cx + u*us, c, kcol(c))
    cnt++
  }
  V_SEEN=cnt
  return 0
}
# ---- the relative-bearing vocabulary --------------------------------
#  One set of words, used for where SHE is from you and for where YOU
#  are from her, so the same phrase always means the same angle.
#  The boundaries are conventional, not legal: they are centred on the
#  old points of the compass - broad on the bow is four points, 45
#  degrees; broad on the quarter is four points from astern, 135.
function rel_phrase(rel,poss,ahead,   t,s){
  if(ahead=="") ahead=5
  t=nrm180(rel); s=(t<0)?"port":"starboard"; t=fabs(t)
  if(t<=ahead)  return "right ahead"
  if(t>=180-ahead) return "right astern"
  if(t<35)  return "fine on " poss " " s " bow"
  if(t<65)  return "broad on " poss " " s " bow"
  if(t<115) return "on " poss " " s " beam"
  if(t<145) return "broad on " poss " " s " quarter"
  return "fine on " poss " " s " quarter"
}
#  Red for port, green for starboard - the sidelights, which is the whole
#  reason the convention is remembered. Nought to 180 each side.
function red_green(rel,   t){
  t=nrm180(rel)
  if(fabs(t)<=0.5)      return "right ahead"
  if(fabs(t)>=179.5)    return "right astern"
  if(t<0) return sprintf("Red %d", int(-t+0.5))
  return sprintf("Green %d", int(t+0.5))
}
#  Four ways of saying the same angle. The style is a setting because
#  which one is right depends entirely on who is listening.
function rel_style(rel,   t,d,s){
  t=nrm180(rel)
  if(rstyle=="words") return rel_phrase(rel,"the")
  if(rstyle=="rel360") return sprintf("%03d relative", nrm360(rel))
  if(rstyle=="none")  return ""
  if(fabs(t)<=0.5)   return "right ahead"
  if(fabs(t)>=179.5) return "right astern"
  d = int(fabs(t)+0.5); s = (t<0) ? "port" : "starboard"
  if(rstyle=="usn") return sprintf("%s %d", (t<0)?"Port":"Starboard", d)
  return sprintf("%s %d", (t<0)?"Red":"Green", d)      # rn, the default
}
#  The other way of saying it, for the line that follows the report when
#  he still cannot find her. Never the same form twice.
function rel_other(rel){
  if(rstyle=="words") return red_green(rel)
  return rel_phrase(rel,"your")
}
function aspect_words(th,   t,p){
  t=nrm180(th); p=rel_phrase(th,"her",2.5)
  if(p=="right ahead")  return "You are right ahead of her: you are looking at her bow."
  if(p=="right astern") return "You are right astern of her: you are looking at her stern."
  if(index(p,"beam")>0) return "You are " p ": you see her whole " ((t<0)?"port":"starboard") " side."
  return "You are " p "."
}
function show_lights(key,th){
  if(draw_lights(key,th)) return 1
  print ""
  printf "  %s\n", cw("WHAT DO YOU SEE?",C_ACC)
  hr()
  gshow()
  hr()
  #  Browsing tells you the aspect.  The quiz must not: Q2 is asking
  #  you to work the aspect out from the lights themselves.
  if(!Q_NOASPECT) printf "  %s\n", aspect_words(th)
  printf "  Letters are the colours: %s white  %s red  %s green  %s yellow\n",
     cw("W",K_W), cw("R",K_R), cw("G",K_G), cw("Y",K_Y)
  #  Left-and-right is where a light sits along her hull, seen from close
  #  to, and it reads backwards to a seaman's eye: a sidelight looks as
  #  though it ought to be forward, toward the bow, and it is drawn aft
  #  of the masts.  That is not the drawing being wrong.  Annex I 3(b)
  #  says the sidelights "shall not be placed in front of the forward
  #  masthead lights", so aft of the masts is where they belong - and at
  #  a bow aspect you are looking across her beam more than along her
  #  length, which swings her starboard light further to your left
  #  still.  It is the same geometry as bow-on, where her green is on
  #  your left and her red on your right; it just fades out as she comes
  #  beam-on.  None of it survives to any real range: a 5 m offset at
  #  2 miles is a fifteenth of a degree.  Height and colour are what you
  #  actually get.  This question has been asked twice; hence the note.
  printf "  %s\n", cwd("Sideways spacing is where the lights sit along her hull, close to.")
  printf "  %s\n", cwd("Annex I keeps sidelights abaft the forward masthead light, so a")
  printf "  %s\n", cwd("sidelight falls toward her stern here, never toward her bow. And")
  printf "  %s\n", cwd("at a bow aspect you see across her beam more than along her length,")
  printf "  %s\n", cwd("so her green swings left - as it does bow-on. Not a heading cue:")
  printf "  %s\n", cwd("at any real range every one of them is in line.")
  print ""
  return 0
}
function reveal_lights(){
  printf "  %s\n", cw(V_NAME,C_ACC)
  printf "  %s.  %s\n", V_RULE, V_NOTE
  if(V_TRAP!="") printf "  %s %s\n", cw("Watch out:",C_ACC), V_TRAP
  if(V_IDX>0){
    print ""
    printf "  %s\n", cw(motion_text(motion_of(V_IDX,V_TH)),C_ACC)
    printf "  %s\n", motion_why(motion_of(V_IDX,V_TH),V_IDX)
  }
  print ""
  return 0
}

# =====================================================================
#  Day shapes.  Black shapes on a mast: what the lights become by day.
# =====================================================================
function shp_init(){
  if(SHP_READY) return
  # key | name | rule | glyph stack, top first, separated by ; | note
  SH[1] = "anchor|Vessel at anchor|Rule 30|ball|One black ball, forward, where it can best be seen."
  SH[2] = "aground|Vessel aground|Rule 30|ball;ball;ball|Three balls in a vertical line."
  SH[3] = "nuc|Not under command|Rule 27|ball;ball|Two balls in a vertical line."
  SH[4] = "ram|Restricted in her ability to manoeuvre|Rule 27|ball;diamond;ball|Ball, diamond, ball. The diamond in the middle is the one to remember."
  SH[5] = "draught|Constrained by her draught|Rule 28|cyl|A black cylinder."
  SH[6] = "motorsail|Sailing vessel also under power|Rule 25|conedn|A cone, point down, forward. She is a power-driven vessel now, whatever her sails are doing."
  SH[7] = "fishing|Vessel fishing|Rule 26|hourglass|Two cones with their points together. Under 20 m may show a basket instead."
  SH[8] = "tow200p|Towing, tow over 200 m|Rule 24|diamond|A diamond, shown by the towing vessel and by the tow."
  SH[9] = "mineclear|Mine clearance|Rule 27|ball;ballpair|Three balls: one at the foremast head and one at each end of the fore yard."
  SH[10]= "divers|Vessel with divers down|Rule 27|flagA|A rigid replica of flag A, at least 1 m high. She is restricted in her ability to manoeuvre."
  NSHP=10
  SHP_READY=1
  return 0
}
function glyph_rows(g,n){
  if(g=="ball"){      GLY[1]="(O)"; return 1 }
  if(g=="diamond"){   GLY[1]="/|\\"; GLY[2]="\\|/"; return 2 }
  if(g=="cyl"){       GLY[1]="[#]"; GLY[2]="[#]"; return 2 }
  if(g=="conedn"){    GLY[1]="\\|/"; GLY[2]=" V "; return 2 }
  if(g=="coneup"){    GLY[1]=" A "; GLY[2]="/|\\"; return 2 }
  if(g=="hourglass"){ GLY[1]="\\|/"; GLY[2]=" X "; GLY[3]="/|\\"; return 3 }
  if(g=="flagA"){     GLY[1]="+---\\"; GLY[2]="|   >"; GLY[3]="+---/"; return 3 }
  if(g=="ballpair"){  GLY[1]="(O)---+---(O)"; return 1 }
  GLY[1]="???"; return 1
}
function shp_find(key,   i,a){ shp_init()
  for(i=1;i<=NSHP;i++){ split(SH[i],a,"|"); if(a[1]==key) return i }
  return 0 }
function draw_shapes(key,   idx,a,n,st,i,j,rows,w,h,sea,cx,r,g,OCC){
  G_NOCROP=0
  idx=shp_find(key); if(idx==0){ print "  unknown shape: " key; return 1 }
  split(SH[idx],a,"|")
  S_NAME=a[2]; S_RULE=a[3]; S_NOTE=a[5]
  n=split(a[4],st,";")
  w=61; h=18; sea=h-3; cx=int(w/2)
  gclear(w,h)
  for(i=0;i<w;i++) gputwc(sea+1,i,"~",C_DIM)
  for(i=-6;i<=6;i++) gputw(sea,cx+i,"=")
  gputw(sea,cx-7,"\\"); gputw(sea,cx+7,"/")
  r=sea-1
  for(i=0;i<h;i++) OCC[i]=0
  for(i=n;i>=1;i--){
    rows=glyph_rows(st[i])
    for(j=rows;j>=1;j--){ gputsc(r, cx-int(length(GLY[j])/2), GLY[j], C_ACC); OCC[r]=1; r-- }
    r--
  }
  for(i=r+1;i<sea;i++) if(!OCC[i]) gputwc(i,cx,"|",C_DIM)
  return 0
}
function show_shapes(key){
  if(draw_shapes(key)) return 1
  print ""
  printf "  %s\n", cw("WHAT IS SHE SHOWING?",C_ACC)
  hr(); gshow(); hr()
  print ""
  return 0
}
function reveal_shapes(){
  printf "  %s\n", cw(S_NAME,C_ACC)
  printf "  %s.  %s\n", S_RULE, S_NOTE
  print ""
  return 0
}

# =====================================================================
#  Encounters.  A plan view, head up, you in the middle.
# =====================================================================
function arrowchar(hdg,   h){
  h=nrm360(hdg)
  if(h<22.5||h>=337.5) return "^"
  if(h<67.5)  return "/"
  if(h<112.5) return ">"
  if(h<157.5) return "\\"
  if(h<202.5) return "v"
  if(h<247.5) return "/"
  if(h<292.5) return "<"
  return "\\"
}
function draw_plan(bg,rng,thdg,tlab,   w,h,cx,cy,rx,ry,t,r,tr,tc,i,dr,dc,m,ch){
  w=63; h=25; cx=int(w/2); cy=int(h/2); rx=cx-2; ry=cy-1
  gclear(w,h)
  for(t=0;t<360;t+=1.0){
    gputwc(cy-ry*cosd(t), cx+rx*sind(t), ".", C_DIM)
    gputwc(cy-ry*0.5*cosd(t), cx+rx*0.5*sind(t), ".", C_DIM)
  }
  for(t=0;t<360;t+=30) gputwc(cy-ry*1.0*cosd(t), cx+rx*1.0*sind(t), "+", C_DIM)
  # you, head up
  gputc(cy-1,cx,"^",C_ACC); gputc(cy,cx,"|",C_ACC)
  gputsc(cy+1,cx-1,"YOU",C_ACC)
  # the other vessel
  tr = cy - ry*rng*cosd(bg)
  tc = cx + rx*rng*sind(bg)
  ch = arrowchar(thdg)
  dr = -cosd(thdg); dc = sind(thdg)
  m = fabs(dr); if(fabs(dc)>m) m=fabs(dc)
  dr=dr/m; dc=dc/m
  for(i=1;i<=4;i++) gputw(tr - dr*i, tc - dc*i, ":")
  gput(tr,tc,ch)
  gputs(tr + (tr<cy?-1:1), tc+2, tlab)
  gputsc(0,cx-6,"HEAD  UP",C_DIM)
  return 0
}
function enc_init(){
  if(ENC_READY) return
  # own | target label | brglo | brghi | target heading | answer | options | why | rule
  EC[1]="You are a power-driven vessel under way.|a power-driven vessel, both her sidelights and two masthead lights in line|352|8|180|d|"\
"Stand on: keep your course and speed.;Give way: alter to port and pass down her starboard side.;Sound one short blast and hold on.;Alter course to starboard, and expect her to do the same.|"\
"Head-on, or nearly so, between two power-driven vessels. Neither is the stand-on vessel: each alters to starboard so that they pass port to port. Seeing both her sidelights is the classic sign.|Rule 14"
  EC[2]="You are a power-driven vessel under way.|a power-driven vessel showing her red sidelight|030|100|290|b|"\
"Stand on: she must keep clear of you.;Give way: alter to starboard and pass under her stern.;Give way: alter to port to cut across ahead of her.;Slow down and let her decide.|"\
"She is crossing from your starboard side, so you are the give-way vessel. Rule 15 says keep out of her way and, if the circumstances admit, avoid crossing ahead of her - so you alter to starboard and go under her stern.|Rule 15"
  EC[3]="You are a power-driven vessel under way.|a power-driven vessel showing her green sidelight|260|330|070|a|"\
"Stand on: keep your course and speed, and watch her.;Give way: alter to starboard.;Give way: alter to port.;Stop your engines at once.|"\
"She is crossing from your port side, so she must keep out of your way and you are the stand-on vessel. Keep your course and speed - but Rule 17 also allows you to act as soon as it is clear she is not, and requires you to act when collision cannot be avoided by her action alone.|Rule 17"
  EC[4]="You are a power-driven vessel making 18 knots.|a power-driven vessel dead ahead making 8 knots, showing only her sternlight|350|010|000|b|"\
"Stand on: you are the faster vessel.;Give way: you are overtaking, so keep clear until you are finally past and clear.;Sound two short blasts and pass down her port side.;Alter to starboard only if she alters first.|"\
"You are coming up on her from more than 22.5 degrees abaft her beam - you can see only her sternlight, which is the test. Any subsequent alteration of bearing does not make you a crossing vessel: you remain the give-way vessel until finally past and clear.|Rule 13"
  EC[5]="You are a power-driven vessel making 8 knots.|a large power-driven vessel coming up astern, fine on your port quarter|170|200|000|a|"\
"Stand on: keep your course and speed.;Give way: alter to starboard.;Give way: slow down and let her pass.;Alter to port to open the distance.|"\
"She is overtaking you, so she must keep out of your way. You are the stand-on vessel and should hold your course and speed so that she can plan around you.|Rule 13"
  EC[6]="You are a power-driven vessel under way.|a sailing vessel under sail alone, on your starboard bow|020|080|300|b|"\
"Stand on: she is smaller than you.;Give way: keep out of her way.;Give way only if she is on your starboard side.;Sound five short blasts.|"\
"A power-driven vessel under way keeps out of the way of a sailing vessel. Which side she is on does not come into it, and neither does her size.|Rule 18"
  EC[7]="You are a sailing vessel under sail alone.|a power-driven vessel on your port bow|300|350|080|a|"\
"Stand on: she must keep out of your way.;Give way: alter to starboard.;Give way: tack away.;Bear away and pass under her stern.|"\
"She is a power-driven vessel and you are under sail, so she keeps clear. Stand on - but keep watching, and be ready to act under Rule 17 if she does nothing.|Rule 18"
  EC[8]="You are a power-driven vessel under way.|a vessel showing red over white all-round lights, with sidelights|300|060|150|b|"\
"Stand on: she is fishing and must keep clear.;Give way: keep well out of her way.;Give way only if she is on your starboard side.;Pass close ahead to give her room astern.|"\
"Red over white means a vessel engaged in fishing other than trawling. A power-driven vessel keeps out of the way of a vessel engaged in fishing, and you should also expect gear to be streamed a long way astern of her.|Rule 18"
  EC[9]="You are a power-driven vessel under way.|a vessel showing red, white, red in a vertical line|280|080|170|b|"\
"Stand on: she is the give-way vessel.;Give way: keep well out of her way.;Sound one short blast and alter to starboard.;Stand on but sound five short blasts.|"\
"Red over white over red: restricted in her ability to manoeuvre. She may be dredging, laying cable or transferring stores, and she cannot get out of your way. Everything keeps clear of her except a vessel not under command.|Rule 18"
  EC[10]="You are a power-driven vessel in a deep-water channel.|a vessel showing three all-round red lights in a vertical line|300|060|170|b|"\
"Stand on: a constrained vessel has no special status.;Give way: avoid impeding her safe passage.;Overtake her quickly on her starboard side.;Anchor until she has passed.|"\
"Three all-round reds means a vessel constrained by her draught. She is not technically a stand-on vessel under Rule 18, but every vessel must avoid impeding her safe passage, and she may have very little water under her.|Rule 18(d)"
  EC[11]="You are a sailing vessel on the port tack.|a sailing vessel on the starboard tack, on your starboard bow|020|070|300|b|"\
"Stand on: you were there first.;Give way: keep out of her way.;Give way only if she is to windward.;Tack immediately.|"\
"When two sailing vessels have the wind on different sides, the one with the wind on the port side keeps out of the way of the other. You are on port tack, so you give way.|Rule 12"
  EC[12]="You are a sailing vessel to windward.|a sailing vessel to leeward, both of you on the same tack|100|150|020|b|"\
"Stand on: windward has right of way.;Give way: the windward vessel keeps clear of the leeward vessel.;Give way only in a narrow channel.;Both alter to starboard.|"\
"With the wind on the same side, the vessel to windward keeps out of the way of the vessel to leeward. Windward gives way - the opposite of what many people first guess.|Rule 12"
  EC[13]="You are a power-driven vessel under way.|a vessel showing two all-round red lights and no sidelights|280|080|000|b|"\
"Stand on: she is not moving.;Give way: keep well out of her way - she is not under command.;Sound five short blasts and hold on.;Pass close ahead - she cannot move.|"\
"Two all-round reds and nothing else: not under command, and making no way through the water. She cannot manoeuvre at all. Everything keeps out of her way.|Rule 18"
  EC[14]="You are a power-driven vessel under way in fog, hearing but not seeing her.|a fog signal of one prolonged blast followed by two short, forward of your beam|300|060|170|b|"\
"Stand on: the signal tells you she will keep clear.;Reduce to bare steerage way - she may be a vessel restricted in her ability to manoeuvre, fishing, towing or under sail.;Alter boldly to port.;Sound five short blasts and continue.|"\
"One prolonged and two short is the signal for a vessel not under command, restricted in her ability to manoeuvre, constrained by her draught, sailing, fishing, or towing. In restricted visibility there is no stand-on vessel: Rule 19 requires you to reduce to the minimum at which you can be kept on course, and if necessary take all way off.|Rule 19"
  EC[15]="You are a yacht of 11 m, under power, crossing a narrow buoyed channel.|a laden bulk carrier coming down the channel, which she cannot leave|020|090|300|b|"\
"Stand on: you are crossing and she is on your starboard side, so Rule 15 applies.;Keep clear early: do not impede a vessel that can only navigate within the channel.;Cross ahead quickly to get out of her way.;Anchor in the channel until she has passed.|"\
"Rule 9(b): a vessel of less than 20 metres or a sailing vessel shall not impede the passage of a vessel which can safely navigate only within a narrow channel. Shall not impede is stronger than give way - keep clear early enough that the question never arises.|Rule 9"
  EC[16]="You are a 12 m yacht under sail, crossing a traffic separation scheme.|a container ship following the lane, fine on your starboard bow|030|080|300|b|"\
"Stand on: you are under sail, so power keeps clear of you.;Keep clear: a sailing vessel shall not impede a power-driven vessel following a lane, and cross on a heading at right angles to the flow.;Motor along the lane until there is a gap.;Cross at a shallow angle to spend less time in the lane.|"\
"Rule 10(j): a vessel under 20 metres or a sailing vessel shall not impede the safe passage of a power-driven vessel following a traffic lane. And Rule 10(c) says cross on a heading as nearly as practicable at right angles to the flow - heading, not ground track, because a beam-on aspect is what makes you visible and predictable.|Rule 10"
  EC[17]="You are a coaster overtaking a slower vessel in a narrow channel.|the vessel ahead, whose agreement you need before you pass|350|010|000|c|"\
"Alter to starboard and pass, sounding one short blast.;Pass on whichever side has more water, without signalling.;Sound two prolonged and one short - I intend to overtake you on your starboard side - and wait for her answer.;Call her on VHF and pass when she does not object.|"\
"Rule 9(e) with Rule 34(c): in a narrow channel, overtaking needs the other vessel indicating agreement. You signal two prolonged and one short for her starboard side, two prolonged and two short for her port side, and she answers prolonged, short, prolonged, short if she agrees.|Rule 9(e)"
  EC[18]="You are a power-driven vessel in thick fog, hearing but not seeing her.|two prolonged blasts, about two seconds apart, from fine on the port bow|300|010|000|b|"\
"Stand on: two prolonged means she is stopped, so she is no danger.;Reduce to the least speed at which you can be kept on course, and be ready to take all way off.;Alter boldly to port and pass down her starboard side.;Sound five short blasts and hold your speed.|"\
"Two prolonged blasts is a power-driven vessel under way but stopped and making no way. In restricted visibility there is no stand-on vessel: Rule 19(e) requires you to reduce to bare steerage way on hearing a fog signal apparently forward of the beam, and if necessary take all your way off.|Rule 19"
  EC[19]="You are a yacht under sail alone.|a vessel showing two all-round red lights and nothing else|280|080|000|b|"\
"Stand on: you are under sail, so everything keeps clear of you.;Keep well out of her way: she is not under command and cannot manoeuvre at all.;Pass close under her stern to see what is wrong.;Sound five short blasts.|"\
"Being under sail does not put you at the top of the order. Rule 18(b): a sailing vessel keeps out of the way of a vessel not under command, of one restricted in her ability to manoeuvre, and of one engaged in fishing.|Rule 18(b)"
  EC[20]="You are a sailing vessel, and the vessel to windward is on the same tack.|another sailing vessel to windward, converging|020|080|300|a|"\
"Stand on: the windward vessel keeps clear of the leeward vessel.;Give way: you are the leeward vessel and must bear away.;Give way: tack immediately.;Both alter to starboard.|"\
"Rule 12(a)(ii): when two sailing vessels have the wind on the same side, the vessel which is to windward keeps out of the way of the vessel to leeward. You are to leeward, so you stand on.|Rule 12"
  EC[21]="You are a power-driven vessel in a deep-water route.|a loaded tanker showing three all-round red lights in a vertical line|300|060|170|b|"\
"Stand on: she has no special status under Rule 18.;Avoid impeding her safe passage - she may have very little water under her keel.;Overtake her briskly on her starboard side.;Cross close ahead of her to clear the route.|"\
"Three all-round reds means constrained by her draught. Rule 18(d) says every vessel shall, if the circumstances of the case admit, avoid impeding her safe passage, and she must navigate with particular caution.|Rule 18(d)"
  EC[22]="You are a power-driven vessel under way.|a seaplane on the water, ahead and to starboard|020|070|280|a|"\
"Stand on: a seaplane on the water keeps well clear of all vessels.;Give way: an aircraft has right of way.;Give way: alter to starboard and pass astern of her.;Stop your engines.|"\
"Rule 18(e): a seaplane on the water shall, in general, keep well clear of all vessels and avoid impeding their navigation. In a risk-of-collision situation she then complies with the rules of this part like any other vessel.|Rule 18(e)"
  EC[23]="You are a power-driven vessel under way.|a vessel showing three all-round green lights, one at the masthead and one at each yardarm|300|060|170|c|"\
"Stand on: green lights mean she is under way and keeping clear.;Give way: alter to starboard and pass a cable astern of her.;Keep at least 1000 metres clear of her: she is engaged in mine clearance.;Sound one short blast and pass close ahead.|"\
"Rule 27(f): three all-round greens marks a vessel engaged in mine clearance operations. Other vessels shall keep at least 1000 metres clear of her - much further than ordinary avoiding action.|Rule 27(f)"
  EC[24]="You are a power-driven vessel closing the coast at night.|two all-round red lights in a line, with a white light below and forward, and no sidelights|300|060|000|b|"\
"Stand on: she is showing red over red, so she is not under command and under way.;Keep clear: anchor lights with two all-round reds means she is aground, so there is shoal water where she sits.;Close her to offer assistance without altering course.;Sound one prolonged blast and hold on.|"\
"Rule 30(d): a vessel aground shows the anchor lights plus two all-round reds in a vertical line. The important part is not only that she cannot move - it is that you now know exactly where the shoal is.|Rule 30(d)"
  EC[25]="You are entering a busy anchorage after dark.|a single all-round white light, low down, not moving, fine on the starboard bow|350|030|000|b|"\
"Stand on: a single white light is a sternlight, so she is going away from you.;Treat her as a vessel at anchor and pass well clear: she is not under way and cannot get out of your way.;Assume it is a small boat under oars and hold your course.;Sound two short blasts and pass down her port side.|"\
"One all-round white is a vessel of under 50 metres at anchor. A single white light is genuinely ambiguous at first sight - it may be a sternlight, an anchor light or a small craft - so the answer is to keep watching the bearing and pass well clear until you know which.|Rule 30"
  EC[26]="You are a power-driven vessel approaching a pilot station.|a pilot vessel showing white over red, with sidelights and a sternlight, crossing from your port side|280|340|070|a|"\
"Stand on: she is crossing from your port side, and being a pilot vessel gives her no special status.;Give way: pilot vessels always have right of way.;Give way: sound one short blast and alter to starboard.;Stop and let her cross.|"\
"White over red - pilot ahead. Rule 29 says what a pilot vessel shows, not that she is privileged. Unless she is also restricted in her ability to manoeuvre, the ordinary steering rules apply, and here she is on your port side crossing.|Rule 29"
  EC[27]="You are a yacht under sail alone, overhauling a fishing boat that is under way and making 5 knots.|the vessel ahead, showing only her sternlight|350|010|000|b|"\
"Stand on: you are under sail, so she keeps clear of you.;Give way: you are overtaking, and Rule 13 overrides the order of Rule 18.;Give way only if she starts fishing.;Sound one short blast and pass to starboard.|"\
"Rule 13 applies notwithstanding anything contained in Rules 4 to 18 - so an overtaking vessel keeps clear whatever the two vessels are. Sailing does not help you here, and you only see her sternlight, which is the test for overtaking.|Rule 13"
  EC[28]="You are a power-driven vessel crossing ahead of a tug and her tow at night.|three masthead lights in a vertical line, sidelights and a yellow light above her sternlight|020|080|300|c|"\
"Stand on: the tug is restricted and will keep clear of you.;Give way: alter to port and pass between the tug and her tow.;Give way: alter to starboard and pass well astern of the whole tow - it is more than 200 metres long.;Cross close ahead of the tug to stay clear of the tow.|"\
"Three masthead lights in a vertical line means the tow exceeds 200 metres. The tow itself may show only sidelights and a sternlight and is easy to miss, and the towline between them is not lit at all. Never pass between a tug and her tow.|Rule 24"
  NENC=28
  ENC_READY=1
  return 0
}
function enc_pick(i,   a){
  enc_init(); split(EC[i],a,"|")
  ENC_ANS=a[6]; ENC_WHY=a[8]; ENC_RULE=a[9]
  return 0
}
function enc_show(i,seed,   a,o,bg,rng,thdg,n){
  enc_init()
  split(EC[i],a,"|")
  xsrand(seed+0); xrand()
  bg = a[3]+0; n = a[4]+0
  if(n < bg) n += 360
  bg = nrm360(bg + xrand()*(n-bg))
  rng = 0.55 + xrand()*0.35
  thdg = nrm360(a[5]+0 + (xrand()*30-15))
  draw_plan(bg,rng,thdg,"HER")
  print ""
  printf "  %s\n", cw("WHAT DO YOU DO?",C_ACC)
  hr()
  gshow()
  hr()
  printf "  %s\n", a[1]
  printf "  You see %s, bearing %03d relative, heading as drawn.\n", a[2], bg
  hr()
  n=split(a[7],o,";")
  printf "   a) %s\n   b) %s\n   c) %s\n   d) %s\n", o[1],o[2],o[3],o[4]
  print ""
  ENC_ANS=a[6]; ENC_WHY=a[8]; ENC_RULE=a[9]
  return 0
}
function enc_reveal(){
  printf "  %s -- %s\n", cw(toupper(ENC_ANS) " is right",C_ACC), ENC_RULE
  printf "  %s\n", ENC_WHY
  print ""
  return 0
}

# =====================================================================
#  Sound signals.  A script cannot make a noise, so it draws one.
#    #      one short blast, about a second
#    ####   one prolonged blast, four to six seconds
#    * *    distinct strokes on the bell
#    *****  the bell rung rapidly
# =====================================================================
function snd_init(){
  if(SND_READY) return
  # key | pattern | meaning | rule | when
  SD[1] ="stbd|#|I am altering my course to starboard|Rule 34(a)|In sight of one another, power-driven, when manoeuvring as authorised or required by these rules."
  SD[2] ="port|# #|I am altering my course to port|Rule 34(a)|In sight of one another, power-driven."
  SD[3] ="astern|# # #|I am operating astern propulsion|Rule 34(a)|Note that this says what the engines are doing, not that the vessel is moving astern."
  SD[4] ="doubt|# # # # #|I do not understand your intentions, or I doubt you are taking sufficient action|Rule 34(d)|Five or more short and rapid blasts. Use it early and use it loudly; it is the only signal that says something is wrong."
  SD[5] ="ovtstbd|#### #### #|I intend to overtake you on your starboard side|Rule 34(c)|In a narrow channel or fairway, where overtaking needs the other vessel's cooperation."
  SD[6] ="ovtport|#### #### # #|I intend to overtake you on your port side|Rule 34(c)|In a narrow channel or fairway."
  SD[7] ="agree|#### # #### #|I agree: go ahead and overtake|Rule 34(c)|The vessel about to be overtaken answers prolonged, short, prolonged, short."
  SD[8] ="bend|####|I am approaching a bend where other vessels may be hidden|Rule 34(e)|Answered by any vessel within hearing round the bend with the same signal."
  SD[9] ="fogpower|####|Power-driven vessel making way through the water|Rule 35(a)|At intervals of not more than two minutes."
  SD[10]="fogstop|#### ####|Power-driven vessel under way but stopped and making no way|Rule 35(b)|Two prolonged blasts, about two seconds apart, every two minutes."
  SD[11]="fogram|#### # #|Not under command, restricted in ability to manoeuvre, constrained by draught, sailing, fishing, or towing|Rule 35(c)|One prolonged and two short, every two minutes. Six different vessels share this signal, so it tells you to be careful rather than exactly what she is."
  SD[12]="fogtowed|#### # # #|A vessel being towed, and manned|Rule 35(e)|One prolonged and three short, sounded immediately after the towing vessel's signal."
  SD[13]="foganchor|*****|At anchor|Rule 35(g)|The bell rung rapidly for about five seconds, every minute. A vessel of 100 m or more also sounds a gong aft, and any vessel may add one short, one prolonged and one short to warn an approaching vessel."
  SD[14]="fogaground|* * * ***** * * *|Aground|Rule 35(h)|Three distinct strokes, the rapid ringing, then three distinct strokes again."
  SD[15]="pilot|# # # #|Pilot vessel on duty - identity signal|Rule 35(k)|Four short blasts, in addition to whatever signal her situation requires."
  NSND=15
  SND_READY=1
  return 0
}
function snd_draw(pat,   n,a,i,j,line,ruler,t){
  line=""; ruler=""
  n=split(pat,a," ")
  for(i=1;i<=n;i++){
    if(i>1){ line=line "   "; ruler=ruler "   " }
    line=line a[i]
    for(j=1;j<=length(a[i]);j++) ruler=ruler "-"
  }
  print ""
  printf "        %s\n", cw(line,C_ACC)
  printf "        %s\n", cw(ruler,C_DIM)
  printf "        %s\n", cw("time ->",C_DIM)
  print ""
  return 0
}
function snd_find(key,   i,a){ snd_init()
  for(i=1;i<=NSND;i++){ split(SD[i],a,"|"); if(a[1]==key) return i }
  return 0 }
function snd_show(i,   a){
  snd_init(); split(SD[i],a,"|")
  print ""
  printf "  %s\n", cw("WHAT IS SHE SAYING?",C_ACC)
  hr()
  snd_draw(a[2])
  hr()
  print "  #  short blast, about one second      ####  prolonged, four to six seconds"
  print "  *  a stroke on the bell               ***** the bell rung rapidly"
  print ""
  SND_MEAN=a[3]; SND_RULE=a[4]; SND_WHEN=a[5]
  return 0
}
function snd_reveal(){
  printf "  %s\n", cw(SND_MEAN,C_ACC)
  printf "  %s.  %s\n", SND_RULE, SND_WHEN
  print ""
  return 0
}
function snd_table(   i,a){
  snd_init()
  print ""
  printf "  %s\n", cw("SOUND SIGNALS",C_ACC)
  hr()
  print "  In sight of one another (Rule 34)"
  for(i=1;i<=8;i++){ split(SD[i],a,"|")
    printf "    %-18s %s\n", a[2], a[3] }
  print ""
  print "  In or near an area of restricted visibility (Rule 35)"
  for(i=9;i<=15;i++){ split(SD[i],a,"|")
    printf "    %-18s %s\n", a[2], a[3] }
  hr()
  print "  #  short blast (one second)     ####  prolonged blast (four to six seconds)"
  print "  *  stroke on the bell           ***** bell rung rapidly for five seconds"
  print ""
  return 0
}

# =====================================================================
#  The rules themselves.  Fifteen lessons, each with a check question.
# =====================================================================
function thead(id,title,   i,u){
  print ""
  printf "  %s\n", cw(sprintf("%s  %s",id,title),C_ACC)
  u=""; for(i=0;i<length(title)+6;i++) u=u "-"
  print "  " u
  print ""
}
function les(id){
  if(id=="L1"){ thead("L1","Rule 5 - Look-out")
    tp("Every vessel shall at all times maintain a proper look-out by sight and")
    tp("hearing as well as by all available means appropriate in the prevailing")
    tp("circumstances and conditions so as to make a full appraisal of the")
    tp("situation and of the risk of collision.")
    tb()
    tp("  1. It is the first substantive rule, and it is the one most often")
    tp("     broken. More collisions are put down to a failure of look-out than")
    tp("     to any other cause.")
    tp("  2. 'By sight and hearing' means a person, outside, looking and")
    tp("     listening - not only a radar screen.")
    tp("  3. 'All available means' does include radar, AIS and VHF, and if you")
    tp("     have them and do not use them properly, that is a breach too.")
    tp("  4. 'At all times' has no exceptions for singlehanders, for tiredness,")
    tp("     or for the middle of an ocean.")
    tb()
    tp("The look-out must be able to appraise the situation. Someone at the")
    tp("wheel who cannot see astern past the sprayhood is not, by themselves, a")
    tp("proper look-out.")
    tb() }
  else if(id=="L2"){ thead("L2","Rule 6 - Safe speed")
    tp("Every vessel shall at all times proceed at a safe speed so that she can")
    tp("take proper and effective action to avoid collision and be stopped")
    tp("within a distance appropriate to the prevailing circumstances.")
    tb()
    tp("  1. There is no number in this rule. Safe speed depends on visibility,")
    tp("     traffic density, manoeuvrability, background lights, the state of")
    tp("     wind, sea and current, the proximity of hazards and your draught.")
    tp("  2. If you are using radar there are further factors: its limitations,")
    tp("     the scale in use, sea and weather clutter, and the possibility that")
    tp("     small vessels and ice may not be detected at all.")
    tp("  3. 'Be stopped within a distance appropriate' is the practical test.")
    tp("     In thick fog with shipping about, that usually means slower than")
    tp("     feels comfortable.")
    tp("  4. A sailing vessel is not exempt. Reducing sail is reducing speed.")
    tb() }
  else if(id=="L3"){ thead("L3","Rule 7 - Risk of collision")
    tp("Every vessel shall use all available means appropriate to determine if")
    tp("risk of collision exists. If there is any doubt, such risk shall be")
    tp("deemed to exist.")
    tb()
    tp("  1. The test is compass bearing. If the compass bearing of an")
    tp("     approaching vessel does not appreciably change, risk of collision")
    tp("     exists.")
    tp("  2. It can exist even with an appreciable bearing change - with a very")
    tp("     large vessel, a tow, or anything at close range.")
    tp("  3. Radar must be used properly if fitted and working: long-range")
    tp("     scanning, and systematic observation of detected objects. A")
    tp("     glance at the screen is not plotting.")
    tp("  4. Assumptions shall not be made on the basis of scanty information,")
    tp("     especially scanty radar information. One AIS target is not a")
    tp("     picture of the traffic.")
    tb()
    tp("Take the bearing with a hand bearing compass over several minutes, or")
    tp("line her up against a stanchion and keep your head still. Steady")
    tp("bearing, decreasing range: you are going to hit her.")
    tb() }
  else if(id=="L4"){ thead("L4","Rule 8 - Action to avoid collision")
    tp("Any action shall be positive, made in ample time and with due regard to")
    tp("good seamanship.")
    tb()
    tp("  1. Alterations of course or speed shall be large enough to be readily")
    tp("     apparent to another vessel observing visually or by radar. A")
    tp("     succession of small alterations is exactly what the rule forbids.")
    tp("  2. If there is sea room, an alteration of course alone may be the most")
    tp("     effective action - provided it is made in good time, is substantial,")
    tp("     and does not result in another close-quarters situation.")
    tp("  3. Action to avoid collision shall result in passing at a safe")
    tp("     distance, and its effectiveness shall be carefully checked until")
    tp("     the other vessel is finally past and clear.")
    tp("  4. If necessary to avoid collision or allow more time to assess, slack")
    tp("     off, stop, or reverse. Taking all way off is always available to you.")
    tb()
    tp("A ten degree alteration at four miles is invisible on the other bridge.")
    tp("Thirty degrees, early, is a signal in itself.")
    tb() }
  else if(id=="L5"){ thead("L5","Rule 9 - Narrow channels")
    tp("A vessel proceeding along the course of a narrow channel or fairway")
    tp("shall keep as near to the outer limit which lies on her starboard side")
    tp("as is safe and practicable.")
    tb()
    tp("  1. Keep to the starboard side of the channel. That is the whole rule")
    tp("     in one line.")
    tp("  2. A vessel of less than 20 metres, or a sailing vessel, shall not")
    tp("     impede the passage of a vessel which can safely navigate only")
    tp("     within the channel. Nor shall a vessel engaged in fishing.")
    tp("  3. Do not cross a channel if it impedes a vessel that can only")
    tp("     navigate within it. If in doubt about her intentions, the doubt")
    tp("     signal - five or more short blasts - is available.")
    tp("  4. Overtaking in a narrow channel needs the other vessel's agreement,")
    tp("     signalled by sound: two prolonged and one short means you intend to")
    tp("     pass on her starboard side.")
    tb()
    tp("'Shall not impede' is not the same as give way. It means you must keep")
    tp("clear early enough that the question of who gives way never arises.")
    tb() }
  else if(id=="L6"){ thead("L6","Rule 10 - Traffic separation schemes")
    tp("A vessel using a traffic separation scheme shall proceed in the")
    tp("appropriate lane in the general direction of traffic flow, keep clear of")
    tp("the separation line or zone, and normally join or leave at the ends.")
    tb()
    tp("  1. If you must join at the side, do so at as small an angle to the")
    tp("     general direction of flow as practicable.")
    tp("  2. If you must cross, cross on a heading as nearly as practicable at")
    tp("     right angles to the direction of flow. Heading, not track - so you")
    tp("     do not crab across with the tide to make a right-angled ground")
    tp("     track. This was changed deliberately: a beam-on aspect is what makes")
    tp("     you visible and predictable.")
    tp("  3. A vessel under 20 metres, a sailing vessel, or a vessel fishing")
    tp("     shall not impede the safe passage of a power-driven vessel")
    tp("     following a lane.")
    tp("  4. Inshore traffic zones are not for through traffic, with limited")
    tp("     exceptions - vessels under 20 metres, sailing vessels, fishing")
    tp("     vessels, and vessels going to or from a place inside the zone.")
    tb() }
  else if(id=="L7"){ thead("L7","Rule 12 - Sailing vessels")
    tp("When two sailing vessels are approaching one another so as to involve")
    tp("risk of collision:")
    tb()
    tp("  1. When each has the wind on a different side, the vessel with the")
    tp("     wind on her port side shall keep out of the way of the other.")
    tp("     Port tack gives way to starboard tack.")
    tp("  2. When both have the wind on the same side, the vessel to windward")
    tp("     shall keep out of the way of the vessel to leeward. Windward gives")
    tp("     way - which surprises most people the first time.")
    tp("  3. If a vessel with the wind on the port side sees a vessel to")
    tp("     windward and cannot tell whether that vessel has the wind on the")
    tp("     port or the starboard side, she shall keep out of the way.")
    tp("  4. The windward side is the side opposite that on which the mainsail")
    tp("     is carried - or, for a square-rigged vessel, the largest fore-and-")
    tp("     aft sail.")
    tb()
    tp("Note that this rule applies between two sailing vessels only. Rule 18")
    tp("governs a sailing vessel meeting anything else.")
    tb() }
  else if(id=="L8"){ thead("L8","Rule 13 - Overtaking")
    tp("Any vessel overtaking any other shall keep out of the way of the vessel")
    tp("being overtaken. This rule overrides everything in the other steering")
    tp("rules - it applies notwithstanding anything in Rules 4 to 18.")
    tb()
    tp("  1. A vessel is overtaking when coming up on another from a direction")
    tp("     more than 22.5 degrees abaft her beam.")
    tp("  2. The practical test at night: if you can see only her sternlight,")
    tp("     and neither of her sidelights, you are overtaking.")
    tp("  3. When in any doubt whether you are overtaking, assume that you are")
    tp("     and act accordingly.")
    tp("  4. Any subsequent alteration of the bearing between the two shall not")
    tp("     make you a crossing vessel or relieve you of the duty to keep clear")
    tp("     until you are finally past and clear.")
    tb()
    tp("A sailing vessel overtaking a power-driven vessel keeps clear. This is")
    tp("the case that most often catches sailors out.")
    tb() }
  else if(id=="L9"){ thead("L9","Rule 14 - Head-on situation")
    tp("When two power-driven vessels are meeting on reciprocal or nearly")
    tp("reciprocal courses so as to involve risk of collision, each shall alter")
    tp("her course to starboard so that each shall pass on the port side of the")
    tp("other.")
    tb()
    tp("  1. Neither vessel is the stand-on vessel. Both act.")
    tp("  2. The situation shall be deemed to exist when a vessel sees the other")
    tp("     ahead or nearly ahead - by night, both sidelights, or the masthead")
    tp("     lights in a line or nearly in a line.")
    tp("  3. When in doubt whether such a situation exists, assume that it does")
    tp("     and act accordingly.")
    tp("  4. This rule is between power-driven vessels only.")
    tb()
    tp("Alter to starboard, early and boldly, and pass port to port: red to red.")
    tb() }
  else if(id=="L10"){ thead("L10","Rules 15 and 16 - Crossing, and the give-way vessel")
    tp("When two power-driven vessels are crossing so as to involve risk of")
    tp("collision, the vessel which has the other on her own starboard side")
    tp("shall keep out of the way and shall, if the circumstances of the case")
    tp("admit, avoid crossing ahead of the other vessel.")
    tb()
    tp("  1. Starboard side, so at night you see her red sidelight. Red means")
    tp("     stop: she is on your right and you give way.")
    tp("  2. Avoid crossing ahead. In practice, alter to starboard and pass")
    tp("     under her stern: it is the action that is unmistakable from her")
    tp("     bridge.")
    tp("  3. Rule 16 tells the give-way vessel to take early and substantial")
    tp("     action to keep well clear. Early and substantial.")
    tp("  4. This rule is between power-driven vessels. A crossing sailing")
    tp("     vessel is a Rule 18 problem.")
    tb() }
  else if(id=="L11"){ thead("L11","Rule 17 - Action by the stand-on vessel")
    tp("Where one vessel is to keep out of the way, the other shall keep her")
    tp("course and speed. But standing on is not a licence to do nothing.")
    tb()
    tp("  1. Normally: keep your course and speed, so that the give-way vessel")
    tp("     can work out a solution around you.")
    tp("  2. You MAY take action as soon as it becomes apparent to you that she")
    tp("     is not taking appropriate action. This is permission, not duty.")
    tp("  3. You SHALL take such action as will best aid to avoid collision when")
    tp("     you find yourself so close that collision cannot be avoided by the")
    tp("     give-way vessel's action alone. This is a duty.")
    tp("  4. If you are a power-driven vessel taking action in a crossing")
    tp("     situation, do not alter to port for a vessel on your own port side.")
    tb()
    tp("The give-way vessel's obligation does not go away because you have")
    tp("acted. Both of you remain bound to avoid collision.")
    tb() }
  else if(id=="L12"){ thead("L12","Rule 18 - Responsibilities between vessels")
    tp("Except where Rules 9, 10 and 13 otherwise require, the pecking order")
    tp("runs from the least manoeuvrable to the most:")
    tb()
    tp("     not under command")
    tp("     restricted in her ability to manoeuvre")
    tp("     engaged in fishing")
    tp("     sailing")
    tp("     power-driven")
    tb()
    tp("  1. Each keeps out of the way of everything above it in that list.")
    tp("  2. A vessel constrained by her draught sits slightly outside the list:")
    tp("     Rule 18(d) says every vessel shall avoid impeding her safe passage,")
    tp("     and she must navigate with particular caution.")
    tp("  3. A seaplane on the water keeps well clear of all vessels; a")
    tp("     wing-in-ground craft, when taking off, landing or in flight near")
    tp("     the surface, keeps well clear of all vessels.")
    tp("  4. The exceptions matter: in a narrow channel, in a traffic scheme,")
    tp("     and when overtaking, the ordinary order can be reversed.")
    tb()
    tp("Sailing vessels are third from the bottom, not at the top. A yacht keeps")
    tp("out of the way of a fishing vessel, and out of the way of anything not")
    tp("under command.")
    tb() }
  else if(id=="L13"){ thead("L13","Rule 19 - Restricted visibility")
    tp("This rule applies to vessels not in sight of one another when navigating")
    tp("in or near an area of restricted visibility. It is a different world")
    tp("from Rules 11 to 18.")
    tb()
    tp("  1. There is no stand-on vessel. Nobody has right of way. The give-way")
    tp("     and stand-on rules simply do not apply.")
    tp("  2. Every vessel shall proceed at a safe speed adapted to the")
    tp("     circumstances, with engines ready for immediate manoeuvre.")
    tp("  3. A vessel which detects by radar alone another vessel shall")
    tp("     determine if a close-quarters situation is developing, and if so")
    tp("     take avoiding action in ample time. If that action is an alteration")
    tp("     of course, avoid: an alteration to port for a vessel forward of the")
    tp("     beam other than for a vessel being overtaken, and an alteration")
    tp("     towards a vessel abeam or abaft the beam.")
    tp("  4. A vessel which hears apparently forward of her beam the fog signal")
    tp("     of another vessel, or which cannot avoid a close-quarters situation")
    tp("     with a vessel forward of her beam, shall reduce to the minimum at")
    tp("     which she can be kept on course - and if necessary take all her way")
    tp("     off, and in any event navigate with extreme caution until the")
    tp("     danger of collision is over.")
    tb() }
  else if(id=="L14"){ thead("L14","Rules 20 to 31 - Lights and shapes")
    tp("Lights are shown from sunset to sunrise, and in restricted visibility,")
    tp("and may be shown at any other time when it is considered necessary.")
    tp("Shapes are shown by day.")
    tb()
    tp("  1. The arcs are fixed and worth knowing by heart: masthead light 225")
    tp("     degrees, sidelights 112.5 each, sternlight 135. Sidelights plus")
    tp("     sternlight make the full circle.")
    tp("  2. What you see tells you her aspect. Both sidelights: she is nearly")
    tp("     bow-on. One sidelight and a masthead light: she is crossing. Only a")
    tp("     white light: she may be a sternlight, an anchor light, or a small")
    tp("     boat - keep watching until you know which.")
    tp("  3. All-round lights in a vertical line are the vessel telling you what")
    tp("     she is doing and what she cannot do. Red over white, fishing at")
    tp("     night. Red over red, the captain is dead - not under command.")
    tp("     Red, white, red - restricted in her ability to manoeuvre.")
    tp("  4. Day shapes carry the same meanings: a ball for anchored, three")
    tp("     balls aground, two balls not under command, ball-diamond-ball")
    tp("     restricted, a cone point down for a sailing vessel under power.")
    tb() }
  else { thead("L15","Rules 32 to 37 - Sound and light signals")
    tp("Sound signals fall into two groups, and the difference matters more")
    tp("than the signals themselves.")
    tb()
    tp("  1. Rule 34 signals are for vessels IN SIGHT of one another. They say")
    tp("     what you are doing right now: one short, I am altering to")
    tp("     starboard; two short, to port; three short, my engines are going")
    tp("     astern.")
    tp("  2. Rule 35 signals are for RESTRICTED VISIBILITY, when you cannot see")
    tp("     each other. They say what kind of vessel you are: one prolonged")
    tp("     for a power-driven vessel making way; one prolonged and two short")
    tp("     for anything from not-under-command to a sailing vessel.")
    tp("  3. Five or more short and rapid blasts is the doubt signal, and the")
    tp("     most under-used signal at sea. It means: I do not understand what")
    tp("     you are doing, or I do not think you are doing enough.")
    tp("  4. A prolonged blast is four to six seconds. A short blast is about")
    tp("     one second. Vessels of 100 metres or more carry a bell and a gong;")
    tp("     under 12 metres you need not carry the equipment, but you must make")
    tp("     some other efficient sound signal.")
    tb() }
  return 0
}
function les_q(id,show){
  if(id=="L1"){ if(show){ tp("Q. Which of these on its own satisfies Rule 5?")
      tp("     a) a radar with ARPA, watched from the chart table")
      tp("     b) AIS with a CPA alarm set    c) none of them") }
    else { Q_A="c"; Q_W="Rule 5 requires sight and hearing as well as all available means. Electronics supplement a look-out; they do not replace one." } }
  else if(id=="L2"){ if(show){ tp("Q. What speed does Rule 6 specify in fog?")
      tp("     a) six knots     b) half your normal speed     c) no number at all") }
    else { Q_A="c"; Q_W="Rule 6 gives factors, not numbers. The test is that you can stop within a distance appropriate to the circumstances." } }
  else if(id=="L3"){ if(show){ tp("Q. A ship's compass bearing is steady and the range is closing. What does Rule 7 say?")
      tp("     a) risk of collision exists    b) risk exists only inside two miles")
      tp("     c) no risk while she is more than 30 degrees off the bow") }
    else { Q_A="a"; Q_W="A steady compass bearing with decreasing range is the definition of risk of collision. And if in any doubt, risk shall be deemed to exist." } }
  else if(id=="L4"){ if(show){ tp("Q. Which action best meets Rule 8?")
      tp("     a) five degrees now, and five more if she does not respond")
      tp("     b) a single alteration of 30 degrees, made early")
      tp("     c) hold on until one mile, then alter hard") }
    else { Q_A="b"; Q_W="Action must be positive, made in ample time, and large enough to be readily apparent to the other vessel visually or by radar." } }
  else if(id=="L5"){ if(show){ tp("Q. In a narrow channel, which side do you keep to?")
      tp("     a) the port side     b) the starboard side     c) the deepest water") }
    else { Q_A="b"; Q_W="As near to the outer limit on your starboard side as is safe and practicable." } }
  else if(id=="L6"){ if(show){ tp("Q. Crossing a traffic separation scheme, what should be at right angles to the flow?")
      tp("     a) your heading     b) your ground track     c) your wake") }
    else { Q_A="a"; Q_W="Rule 10(c) says heading. Do not crab across with the tide to make the track square - a beam-on aspect is what makes you visible." } }
  else if(id=="L7"){ if(show){ tp("Q. Two sailing vessels, both with the wind on the starboard side. Who gives way?")
      tp("     a) the vessel to windward     b) the vessel to leeward     c) the overtaking vessel") }
    else { Q_A="a"; Q_W="Same tack: windward keeps out of the way of leeward." } }
  else if(id=="L8"){ if(show){ tp("Q. At night you can see another vessel's sternlight and neither sidelight. What are you?")
      tp("     a) crossing     b) overtaking     c) head-on") }
    else { Q_A="b"; Q_W="Sternlight only means you are more than 22.5 degrees abaft her beam: you are overtaking, and you keep clear until finally past and clear." } }
  else if(id=="L9"){ if(show){ tp("Q. Two power-driven vessels meeting head-on. Who is the stand-on vessel?")
      tp("     a) the larger     b) the one to starboard     c) neither") }
    else { Q_A="c"; Q_W="In a head-on situation there is no stand-on vessel. Each alters to starboard and they pass port to port." } }
  else if(id=="L10"){ if(show){ tp("Q. You are power-driven and see another power-driven vessel's red sidelight, crossing. What do you do?")
      tp("     a) stand on     b) give way, and avoid crossing ahead of her")
      tp("     c) give way by altering to port") }
    else { Q_A="b"; Q_W="Her red light means she is on your starboard side. You give way, and Rule 15 says avoid crossing ahead - so alter to starboard and pass under her stern." } }
  else if(id=="L11"){ if(show){ tp("Q. You are the stand-on vessel and she is doing nothing about it. What does Rule 17 allow?")
      tp("     a) nothing until collision is unavoidable    b) you may act as soon as it is")
      tp("        apparent she is not acting    c) you must alter to port") }
    else { Q_A="b"; Q_W="Rule 17(a)(ii) permits you to act as soon as it becomes apparent she is not taking appropriate action, and 17(b) requires you to act when collision cannot be avoided by her action alone." } }
  else if(id=="L12"){ if(show){ tp("Q. A yacht under sail meets a vessel engaged in fishing. Who keeps clear?")
      tp("     a) the fishing vessel     b) the yacht     c) neither, it is a crossing situation") }
    else { Q_A="b"; Q_W="Rule 18: a sailing vessel keeps out of the way of a vessel engaged in fishing, and of one restricted in her ability to manoeuvre, and of one not under command." } }
  else if(id=="L13"){ if(show){ tp("Q. In fog, you hear one prolonged and two short forward of the beam. Who is the stand-on vessel?")
      tp("     a) you     b) she is     c) neither - Rule 19 has no stand-on vessel") }
    else { Q_A="c"; Q_W="Rule 19 applies to vessels not in sight of one another, and it has no give-way and stand-on. Reduce to the minimum steerage way and, if necessary, take all way off." } }
  else if(id=="L14"){ if(show){ tp("Q. What arc does a masthead light cover?")
      tp("     a) 112.5 degrees     b) 225 degrees     c) 360 degrees") }
    else { Q_A="b"; Q_W="225 degrees, from right ahead to 22.5 degrees abaft the beam on each side. The sidelights cover 112.5 each and the sternlight the remaining 135." } }
  else { if(show){ tp("Q. What does one prolonged blast mean from a vessel you cannot see, in fog?")
      tp("     a) I am altering to starboard     b) a power-driven vessel making way")
      tp("     c) I am approaching a bend") }
    else { Q_A="b"; Q_W="In restricted visibility (Rule 35) one prolonged every two minutes is a power-driven vessel making way through the water. The same signal in sight of another vessel, at a bend, is Rule 34(e)." } }
  return 0
}
function syl_show(done,   i,a,n,ids,ttl,mark){
  n=split("L1|Rule 5 - Look-out;L2|Rule 6 - Safe speed;L3|Rule 7 - Risk of collision;" \
          "L4|Rule 8 - Action to avoid collision;L5|Rule 9 - Narrow channels;" \
          "L6|Rule 10 - Traffic separation schemes;L7|Rule 12 - Sailing vessels;" \
          "L8|Rule 13 - Overtaking;L9|Rule 14 - Head-on;" \
          "L10|Rules 15 and 16 - Crossing and the give-way vessel;" \
          "L11|Rule 17 - Action by the stand-on vessel;" \
          "L12|Rule 18 - Responsibilities between vessels;" \
          "L13|Rule 19 - Restricted visibility;L14|Rules 20-31 - Lights and shapes;" \
          "L15|Rules 32-37 - Sound signals", ids, ";")
  print ""
  printf "  %s\n", cw("THE RULES -- fifteen lessons",C_ACC)
  hr()
  ttl=0
  for(i=1;i<=n;i++){
    split(ids[i],a,"|")
    mark = (index("," done ",", "," a[1] ",")>0) ? "x" : " "
    if(mark=="x") ttl++
    printf "   [%s]  %-4s %s\n", mark, a[1], a[2]
  }
  hr()
  printf "  %d of %d done.  Type a code (L1 ... L15), or n for the next one.\n", ttl, n
  print ""
  return 0
}

# =====================================================================
#  Quizzes: pick an item, three distractors, and shuffle
# =====================================================================
function pick_opts(nitems,correct,seed,   i,j,t,pool,np){
  xsrand(seed+0); xrand(); xrand()
  np=0
  for(i=1;i<=nitems;i++) if(i!=correct){ np++; pool[np]=i }
  for(i=np;i>1;i--){ j=1+int(xrand()*i); t=pool[i]; pool[i]=pool[j]; pool[j]=t }
  OPT[1]=correct; OPT[2]=pool[1]; OPT[3]=pool[2]; OPT[4]=pool[3]
  for(i=4;i>1;i--){ j=1+int(xrand()*i); t=OPT[i]; OPT[i]=OPT[j]; OPT[j]=t }
  for(i=1;i<=4;i++) if(OPT[i]==correct) OPT_ANS=substr("abcd",i,1)
  return 0
}
function qpick_lights(seed,   i,c,sig,np,j,t,pool){
  QZ_MOT=0
  ves_init(); xsrand(seed+0)
  for(i=0;i<3;i++) xrand()
  c = 1+int(xrand()*NVES)
  QZ_TH = int(xrand()*360)-180
  QZ_C = c
  sig = light_sig(c,QZ_TH)
  # everything that looks exactly the same from this angle
  QZ_SAME=""
  np=0
  for(i=1;i<=NVES;i++){
    if(i==c) continue
    if(light_sig(i,QZ_TH)==sig){ QZ_SAME = QZ_SAME (QZ_SAME==""?"":"; ") ves_name(i); continue }
    np++; pool[np]=i
  }
  for(i=np;i>1;i--){ j=1+int(xrand()*i); t=pool[i]; pool[i]=pool[j]; pool[j]=t }
  OPT[1]=c; OPT[2]=pool[1]; OPT[3]=pool[2]; OPT[4]=pool[3]
  for(i=4;i>1;i--){ j=1+int(xrand()*i); t=OPT[i]; OPT[i]=OPT[j]; OPT[j]=t }
  for(i=1;i<=4;i++) if(OPT[i]==c) QZ_ANS=substr("abcd",i,1)
  #  and the four possible answers to "which way is she going"
  QZ_MOT = motion_of(c,QZ_TH)
  np=0
  for(i=1;i<=5;i++) if(i!=QZ_MOT){ np++; pool[np]=i }
  for(i=np;i>1;i--){ j=1+int(xrand()*i); t=pool[i]; pool[i]=pool[j]; pool[j]=t }
  MOPT[1]=QZ_MOT; MOPT[2]=pool[1]; MOPT[3]=pool[2]; MOPT[4]=pool[3]
  for(i=4;i>1;i--){ j=1+int(xrand()*i); t=MOPT[i]; MOPT[i]=MOPT[j]; MOPT[j]=t }
  for(i=1;i<=4;i++) if(MOPT[i]==QZ_MOT) QZ_MANS=substr("abcd",i,1)
  return 0
}
function ves_name(i,   a){ split(VT[i],a,"|"); return a[2] }
function quiz_lights(seed,   i,a,j,t,pool,np,mc){
  qpick_lights(seed)
  split(VT[QZ_C],a,"|")
  Q_NOASPECT=1
  show_lights(a[1],QZ_TH)
  Q_NOASPECT=0
  printf "  %s\n", cw("Q1  What is she?",C_ACC)
  for(i=1;i<=4;i++){ split(VT[OPT[i]],a,"|"); printf "     %s) %s\n", substr("abcd",i,1), a[2] }
  print ""
  printf "  %s\n", cw("Q2  Which way is she going?",C_ACC)
  for(i=1;i<=4;i++) printf "     %s) %s\n", substr("abcd",i,1), motion_text(MOPT[i])
  print ""
  return 0
}
function quiz_lights_reveal(){
  split(VT[QZ_C],QA,"|")
  printf "  Q1  %s -- %s\n", cw(toupper(QZ_ANS) " is right",C_ACC), QA[2]
  printf "      %s.  %s\n", QA[3], QA[5]
  if(QA[6]!="") printf "      %s %s\n", cw("Watch out:",C_ACC), QA[6]
  print ""
  printf "  Q2  %s -- %s\n", cw(toupper(QZ_MANS) " is right",C_ACC), motion_text(QZ_MOT)
  printf "      %s\n", motion_why(QZ_MOT,QZ_C)
  printf "      %s\n", aspect_words(QZ_TH)
  if(QZ_SAME!=""){
    print ""
    printf "  %s\n", cw("But from this angle she is genuinely ambiguous.",C_ACC)
    printf "  These would look exactly the same to you: %s.\n", QZ_SAME
    print  "  That is a real limitation of a single look, not a fault in the"
    print  "  question - it is why you keep watching until the bearing, the"
    print  "  range or a change of aspect tells you which one she is. Those"
    print  "  were left out of the answers above so the question had one answer."
  }
  print ""
  return 0
}
function qpick_shapes(seed,   i,c){
  shp_init(); xsrand(seed+0)
  for(i=0;i<3;i++) xrand()
  c = 1+int(xrand()*NSHP)
  QZ_C=c; pick_opts(NSHP,c,seed+23); QZ_ANS=OPT_ANS
  return 0
}
function quiz_shapes(seed,   i,a){
  qpick_shapes(seed)
  split(SH[QZ_C],a,"|")
  show_shapes(a[1])
  for(i=1;i<=4;i++){ split(SH[OPT[i]],a,"|"); printf "   %s) %s\n", substr("abcd",i,1), a[2] }
  print ""
  return 0
}
function quiz_shapes_reveal(){
  split(SH[QZ_C],QA,"|")
  printf "  %s -- %s\n", cw(toupper(QZ_ANS) " is right",C_ACC), QA[2]
  printf "  %s.  %s\n", QA[3], QA[5]
  print ""
  return 0
}
function qpick_sound(seed,   i,c){
  snd_init(); xsrand(seed+0)
  for(i=0;i<3;i++) xrand()
  c = 1+int(xrand()*NSND)
  QZ_C=c; pick_opts(NSND,c,seed+37); QZ_ANS=OPT_ANS
  return 0
}
function quiz_sound(seed,   i,a){
  qpick_sound(seed)
  snd_show(QZ_C)
  for(i=1;i<=4;i++){ split(SD[OPT[i]],a,"|"); printf "   %s) %s\n", substr("abcd",i,1), a[3] }
  print ""
  return 0
}
function quiz_sound_reveal(){
  split(SD[QZ_C],QA,"|")
  printf "  %s -- %s\n", cw(toupper(QZ_ANS) " is right",C_ACC), QA[3]
  printf "  %s.  %s\n", QA[4], QA[5]
  print ""
  return 0
}
function colour_check(   e){
  col_init()
  print ""
  printf "  %s\n", cw("COLOUR CHECK",C_ACC)
  hr()
  printf "  mode        %s\n", (cmode==""?"plain":cmode)
  printf "  the lamps   %s  %s  %s  %s\n", cw("W white",K_W), cw("R red",K_R), cw("G green",K_G), cw("Y yellow",K_Y)
  printf "  the vessel  hull and sea in the panel text colour\n"
  printf "  %s\n", cw("  faint       masts and droplines, like this",C_DIM)
  hr()
  print "  If the four lamps above are not four different colours, your terminal"
  print "  is not showing them. Try 'colregs day' - and note that colour is turned"
  print "  off on purpose whenever output is piped to a file or another program."
  print ""
  return 0
}
function ref_lights(   i,a){
  ves_init()
  print ""
  printf "  %s\n", cw("LIGHTS -- the whole set",C_ACC)
  hr()
  for(i=1;i<=NVES;i++){ split(VT[i],a,"|")
    printf "  %-14s %s\n", a[1], a[2]
    printf "  %-14s %s  %s\n", "", a[3], a[5] }
  hr()
  print "  Show any one from any angle:  colregs light <key> <bearing>"
  print ""
  return 0
}
function ref_shapes(   i,a){
  shp_init()
  print ""
  printf "  %s\n", cw("DAY SHAPES",C_ACC)
  hr()
  for(i=1;i<=NSHP;i++){ split(SH[i],a,"|")
    printf "  %-12s %-42s %s\n", a[1], a[2], a[3] }
  hr()
  print "  Draw any one:  colregs shape <key>"
  print ""
  return 0
}

#  A picture must have exactly one right answer among the four offered.
function sigcheck(   sd,i,sig,bad,n){
  bad=0; n=0
  for(sd=1; sd<=600; sd++){
    qpick_lights(sd)
    sig = light_sig(QZ_C,QZ_TH)
    for(i=1;i<=4;i++){
      if(OPT[i]==QZ_C) continue
      if(light_sig(OPT[i],QZ_TH)==sig){
        printf "  seed %d: %s and %s look identical at %d and are both offered\n",
               sd, ves_name(QZ_C), ves_name(OPT[i]), QZ_TH
        bad++
      }
    }
    if(OPT[index("abcd",QZ_ANS)]!=QZ_C){ printf "  seed %d: the marked answer is not the right option\n", sd; bad++ }
    n++
  }
  printf "  checked %d lights questions: %s\n", n, (bad==0 ? "every one has a single right answer" : bad " PROBLEM(S)")
  exit (bad==0?0:1)
}

BEGIN{
  col_init()
  q1=0; q2=0
  if(cmd=="sigcheck") sigcheck()
  else if(cmd=="light"){        show_lights(key, th+0); if(reveal=="1") reveal_lights() }
  else if(cmd=="shape"){   show_shapes(key); if(reveal=="1") reveal_shapes() }
  else if(cmd=="reflights") ref_lights()
  else if(cmd=="colours")   colour_check()
  else if(cmd=="refshapes") ref_shapes()
  else if(cmd=="sndtable")  snd_table()
  else if(cmd=="qlight"){  quiz_lights(seed+0) }
  else if(cmd=="qlightm"){ qpick_lights(seed+0)
                           q1 = (tolower(ans)==QZ_ANS); q2 = (tolower(ans2)==QZ_MANS)
                           if(!q1 || !q2) printf "  %s\n", cw("Not quite.",C_ACC)
                           quiz_lights_reveal(); exit ((q1&&q2)?0:1) }
  else if(cmd=="qshape"){  quiz_shapes(seed+0) }
  else if(cmd=="qshapem"){ qpick_shapes(seed+0)
                           if(tolower(ans)!=QZ_ANS) printf "  %s\n", cw("Not right.",C_ACC)
                           quiz_shapes_reveal(); exit (tolower(ans)==QZ_ANS?0:1) }
  else if(cmd=="qsound"){  quiz_sound(seed+0) }
  else if(cmd=="qsoundm"){ qpick_sound(seed+0)
                           if(tolower(ans)!=QZ_ANS) printf "  %s\n", cw("Not right.",C_ACC)
                           quiz_sound_reveal(); exit (tolower(ans)==QZ_ANS?0:1) }
  else if(cmd=="enc"){     enc_init(); xsrand(seed+0); xrand()
                           ENCN = (which!="" ? which+0 : 1+int(xrand()*NENC)); enc_show(ENCN,seed+0) }
  else if(cmd=="encm"){    enc_init(); xsrand(seed+0); xrand()
                           ENCN = (which!="" ? which+0 : 1+int(xrand()*NENC))
                           enc_pick(ENCN)
                           if(tolower(ans)!=ENC_ANS) printf "  %s\n", cw("Not right.",C_ACC)
                           enc_reveal(); exit (tolower(ans)==ENC_ANS?0:1) }
  else if(cmd=="lesson"){  les(les_id); les_q(les_id,1); print "" }
  else if(cmd=="check"){   les_q(les_id,0)
                           if(tolower(ans)==Q_A){ printf "\n  %s  %s\n\n", cw("Correct.",C_ACC), Q_W; exit 0 }
                           printf "\n  Not quite - the answer is %s.  %s\n\n", toupper(Q_A), Q_W; exit 1 }
  else if(cmd=="syllabus") syl_show(done)
  else if(cmd=="scen"){    if(!scen_gen(seed+0)){ print "  could not build a scenario"; exit 2 }
                           scen_show() }
  else if(cmd=="scenm"){   if(!scen_gen(seed+0)){ print "  could not build a scenario"; exit 2 }
                           scen_opts()
                           scen_mark(a1,a2,a3); exit (SCEN_OK?0:1) }
  else if(cmd=="scenframe"){ if(!scen_gen(seed+0)) exit 2
                           scen_opts()
                           SC_PICK = SO_[index("abcd",tolower(ans))>0 ? index("abcd",tolower(ans)) : 1]
                           cpa_under(SC_PICK)
                           plot_true((tmin+0)/60.0, SC_PICK)
                           printf "\n  %s\n", cw(sprintf("  t + %2d min   she bears %03d T, range %.2f nm%s",
                                    tmin+0, TP_B, TP_R,
                                    (fabs((tmin+0)-CPA_T)<3.5 ? "   <- closest approach" : "")), C_ACC)
                           gshow()
                           if((tmin+0) > CPA_T + 6) exit 3
                           exit 0 }
  else if(cmd=="scenout"){ if(!scen_gen(seed+0)) exit 2
                           scen_opts()
                           SC_PICK = SO_[index("abcd",tolower(ans))>0 ? index("abcd",tolower(ans)) : 1]
                           scen_outcome(SC_PICK) }
  #  contacts: these live in contacts.awk, which is always loaded with
  #  the engine, so the functions are here by the time we call them
  else if(cmd=="csyl")     ct_syl(done)
  else if(cmd=="clesson")  ct_lesson(les_id)
  else if(cmd=="cref")     ct_ref()
  else if(cmd=="track"){   if(ct_track(seed+0)) exit 2 }
  else if(cmd=="trackm")   exit ct_trackm(seed+0,a1,a2,a3)
  else if(cmd=="ek"){      if(ek_show(seed+0)) exit 2 }
  else if(cmd=="ekm")      exit ek_mark(seed+0,ans)
  #  review: the claims a test cannot check, put to a person
  else if(cmd=="rvlist")   rv_list(rfile)
  else if(cmd=="rvshow")   exit rv_show(key)
  else if(cmd=="rvnext")   rv_next(rfile)
  else if(cmd=="rvreport") rv_report(rfile)
  else if(cmd=="rvurl")    rv_url(rfile)
  else if(cmd=="rvcount"){ print rv_build() }
  else if(cmd=="rvkeys")   rv_keys(which)
  else if(cmd!=""){ print "colregs: unknown cmd " cmd; exit 2 }
}

# =====================================================================
#  Collision avoidance: the radar plot
#
#  A developing situation rather than a snapshot. Three timed
#  observations of bearing and range; you decide whether risk exists,
#  how close she will come, and what to do. Then you watch it run.
#
#  Everything is worked in nautical miles and hours, in a north-up
#  frame:  E is +x, N is +y, bearings are atan2(E,N).
# =====================================================================
function vE(c,s){ return s*sind(c) }
function vN(c,s){ return s*cosd(c) }
function brg(e,n){ return nrm360(atan2d(e,n)) }
function asind(x){ if(x>=1) return 90; if(x<=-1) return -90
  return atan2d(x,sqrt(1-x*x)) }
function atan2d(y,x){ return 57.2957795130823209*atan2(y,x) }
function acosd(x){ if(x>=1) return 0; if(x<=-1) return 180
  return atan2d(sqrt(1-x*x),x) }

function scen_class(k){
  # key | description | rel-bearing lo | hi | cpa band | target kind
  if(k==1) return "cross_stbd|crossing from starboard|20|95|near|power"
  if(k==2) return "cross_port|crossing from port|265|340|near|power"
  if(k==3) return "headon|meeting head-on|352|8|near|power"
  if(k==4) return "overtaking|you overtaking her|345|15|near|slow"
  if(k==5) return "overtaken|she overtaking you|160|200|near|fast"
  if(k==6) return "clear|passing clear|20|340|far|power"
  if(k==7) return "sail|a sailing vessel crossing|20|340|near|sail"
  if(k==8) return "fishing|a vessel engaged in fishing|300|60|near|fishing"
  if(k==9) return "ram|a vessel restricted in her ability to manoeuvre|300|60|near|ram"
  return "cross_stbd|crossing from starboard|20|95|near|power"
}
function scen_gen(seed,   i,a,k,lo,hi,rb,d,T,side,beta,alpha,thr,vr,p0e,p0n,vte,vtn,ok,band){
  xsrand(seed+0)
  for(i=0;i<4;i++) xrand()
  ok=0
  for(i=0;i<400 && !ok;i++){
    k = 1+int(xrand()*9)
    split(scen_class(k),a,"|")
    SC_KEY=a[1]; SC_DESC=a[2]; lo=a[3]+0; hi=a[4]+0; band=a[5]; SC_KIND=a[6]
    SC_CO = int(xrand()*360)
    SC_SO = 6 + int(xrand()*11)
    if(hi<lo) rb = nrm360(lo + xrand()*(hi+360-lo)); else rb = lo + xrand()*(hi-lo)
    SC_B0 = nrm360(SC_CO + rb)
    SC_R0 = 6 + xrand()*4
    if(band=="far"){ SC_CPA = 3.4 + xrand()*1.8; SC_BAND=4 }
    else {
      SC_BAND = 1 + int(xrand()*3)
      if(SC_BAND==1) SC_CPA = 0.15 + xrand()*0.3
      else if(SC_BAND==2) SC_CPA = 0.85 + xrand()*0.3
      else SC_CPA = 1.85 + xrand()*0.3
    }
    T = (16 + xrand()*22)/60.0                    # time to CPA, hours
    side = (xrand()<0.5) ? 1 : -1
    p0e = SC_R0*sind(SC_B0); p0n = SC_R0*cosd(SC_B0)
    beta = brg(-p0e,-p0n)                          # from her, towards us
    alpha = asind(SC_CPA/SC_R0)
    thr = nrm360(beta + side*alpha)                # relative-motion direction
    vr = sqrt(SC_R0*SC_R0 - SC_CPA*SC_CPA)/T
    vte = vr*sind(thr) + vE(SC_CO,SC_SO)
    vtn = vr*cosd(thr) + vN(SC_CO,SC_SO)
    SC_ST = sqrt(vte*vte+vtn*vtn)
    SC_CT = brg(vte,vtn)
    SC_TCPA = T*60.0
    if(SC_ST<3.5 || SC_ST>26) continue
    if(SC_KEY=="headon"   && fabs(nrm180(SC_CT-(SC_CO+180)))>25) continue
    if(SC_KEY=="overtaking" && (fabs(nrm180(SC_CT-SC_CO))>25 || SC_ST>SC_SO-2)) continue
    if(SC_KEY=="overtaken"  && (fabs(nrm180(SC_CT-SC_CO))>25 || SC_ST<SC_SO+3)) continue
    if(SC_KEY=="clear" && SC_CPA<3.0) continue
    ok=1
  }
  if(!ok) return 0
  SC_P0E=p0e; SC_P0N=p0n
  SC_VRE=vr*sind(thr); SC_VRN=vr*cosd(thr)
  # three observations, six minutes apart, with the scatter a hand bearing
  # compass actually gives you
  for(i=0;i<3;i++){
    T=i*0.1
    OB_E[i]=SC_P0E+SC_VRE*T; OB_N[i]=SC_P0N+SC_VRN*T
    OB_R[i]=sqrt(OB_E[i]^2+OB_N[i]^2)
    OB_B[i]=brg(OB_E[i],OB_N[i])
    OB_BN[i]=nrm360(OB_B[i] + (xrand()*3.0-1.5))     # bearing scatter
    OB_RN[i]=OB_R[i] + (xrand()*0.16-0.08)           # range scatter
    OB_T[i]=i*6
  }
  scen_answers()
  return 1
}
# what the rules make of it
function scen_answers(   rb,rbher){
  rb    = nrm180(SC_B0 - SC_CO)              # she bears this, from your bow
  rbher = nrm180(nrm360(SC_B0+180) - SC_CT)  # you bear this, from her bow
  SC_RB=rb
  if(SC_CPA >= 3.0){ SC_ACT="none"; SC_RULE="Rule 7"
    SC_WHY="The bearing is drawing steadily and she will pass three miles or more off. There is no risk of collision, so no action is called for - but keep taking the bearing, because that is the only thing that tells you it stays true." }
  else if(SC_KIND=="sail" || SC_KIND=="fishing" || SC_KIND=="ram"){
    SC_ACT="giveway"; SC_RULE="Rule 18"
    SC_WHY="You are a power-driven vessel and she is " ((SC_KIND=="sail")?"under sail":((SC_KIND=="fishing")?"engaged in fishing":"restricted in her ability to manoeuvre")) ". You keep out of her way, whichever side she is on." }
  else if(SC_KEY=="overtaking"){ SC_ACT="overtake"; SC_RULE="Rule 13"
    SC_WHY="You are coming up on her from more than 22.5 degrees abaft her beam, so you are overtaking. You keep out of her way, and you stay the give-way vessel until you are finally past and clear." }
  else if(SC_KEY=="overtaken"){ SC_ACT="standon"; SC_RULE="Rule 13"
    SC_WHY="She is overtaking you, so she must keep out of your way. Hold your course and speed so that she can plan around you - and watch her." }
  else if(SC_KEY=="headon"){ SC_ACT="headon"; SC_RULE="Rule 14"
    SC_WHY="Reciprocal courses, and closing. Neither of you is the stand-on vessel: each alters to starboard so that you pass port to port." }
  else if(rb>=0 && rb<112.5){ SC_ACT="giveway"; SC_RULE="Rule 15"
    SC_WHY="She is crossing from your starboard side, so you give way - and Rule 15 says avoid crossing ahead of her. A bold alteration to starboard takes you under her stern." }
  else { SC_ACT="standon"; SC_RULE="Rule 17"
    SC_WHY="She is crossing from your port side, so she keeps out of your way and you stand on. Hold your course and speed, but be ready to act the moment it is clear she is not." }
  return 0
}
function act_text(k){
  if(k=="none")     return "No risk of collision: hold your course and speed, and keep checking the bearing."
  if(k=="standon")  return "Stand on: hold your course and speed; she must keep out of your way."
  if(k=="giveway")  return "Give way: a bold alteration to starboard, passing under her stern."
  if(k=="headon")   return "Both alter to starboard, and pass port to port."
  if(k=="overtake") return "Give way: you are overtaking; keep well clear until finally past and clear."
  if(k=="slow")     return "Give way: take off speed and let her pass ahead."
  return "?"
}

# ---- the relative plot: you at the centre, north up -------------------
function plot_rel(solution,   w,h,cx,cy,i,sc,mx,e,n,t,r,c,tc,ce,cn,step){
  w=61; h=25; cx=int(w/2); cy=int(h/2)
  mx=SC_R0*1.15
  sc=(cy-1)/mx
  gclear(w,h)
  for(t=0;t<360;t+=0.7){
    gputwc(cy-(cy-1)*cosd(t), cx+(cx-1)*sind(t), ".", C_DIM)
    gputwc(cy-(cy-1)*0.5*cosd(t), cx+(cx-1)*0.5*sind(t), ".", C_DIM)
  }
  gputsc(0,cx-1,"N",C_DIM)
  gputsc(cy,0,"W",C_DIM); gputsc(cy,w-1,"E",C_DIM)
  gputsc(h-1,cx-1,"S",C_DIM)
  if(solution){
    step=0.04
    for(t=-0.02;t<=1.6;t+=step){
      e=SC_P0E+SC_VRE*(SC_TCPA/60.0)*t; n=SC_P0N+SC_VRN*(SC_TCPA/60.0)*t
      gputwc(cy-n*sc*(cy-1)/mx/sc*1, cx+e*sc*(cx-1)/mx/sc*1, "-", C_DIM)
    }
  }
  for(i=0;i<3;i++){
    r=cy-OB_N[i]*(cy-1)/mx; c=cx+OB_E[i]*(cx-1)/mx
    gputc(r,c,sprintf("%d",i+1),C_ACC)
  }
  if(solution){
    tc=SC_TCPA/60.0
    ce=SC_P0E+SC_VRE*tc; cn=SC_P0N+SC_VRN*tc
    gputc(cy-cn*(cy-1)/mx, cx+ce*(cx-1)/mx, "X", C_ACC)
    gputsc(cy-cn*(cy-1)/mx, cx+ce*(cx-1)/mx+2, "CPA", C_ACC)
  }
  gputc(cy,cx,"+",C_ACC)
  gputsc(cy+1,cx-1,"YOU",C_ACC)
  return 0
}
function scen_show(   i,o,n){
  print ""
  printf "  %s\n", cw("COLLISION AVOIDANCE -- a radar plot",C_ACC)
  hr()
  printf "  You are a power-driven vessel, steering %03d T at %d knots.\n", SC_CO, SC_SO
  printf "  Visibility is good and you have her in sight.\n"
  hr()
  print "  Three observations, six minutes apart:"
  print ""
  printf "      %-8s %-12s %s\n","time","bearing","range"
  for(i=0;i<3;i++)
    printf "      %-8s %03.0f T        %.1f nm\n", sprintf("%02d min",OB_T[i]), OB_BN[i], OB_RN[i]
  print ""
  if(SC_KIND=="sail")         print "  She is under sail alone."
  else if(SC_KIND=="fishing") print "  She shows red over white: she is engaged in fishing."
  else if(SC_KIND=="ram")     print "  She shows red over white over red: restricted in her ability to manoeuvre."
  else                        print "  She is a power-driven vessel."
  plot_rel(0)
  hr(); gshow(); hr()
  print "  The marks are where she was, relative to you, at each observation."
  print ""
  printf "  %s\n", cw("Q1  Is there a risk of collision?",C_ACC)
  print "     a) Yes - the bearing is steady and the range is closing"
  print "     b) No - the bearing is drawing and she will pass well clear"
  print "     c) Three observations are not enough to say"
  print ""
  printf "  %s\n", cw("Q2  How close will she come?",C_ACC)
  print "     a) under half a mile    b) about one mile"
  print "     c) about two miles      d) three miles or more"
  print ""
  printf "  %s\n", cw("Q3  What do you do?",C_ACC)
  scen_opts()
  for(i=1;i<=4;i++) printf "     %s) %s\n", substr("abcd",i,1), act_text(SO_[i])
  print ""
  return 0
}
function scen_opts(   i,j,t,pool,np,seedx){
  # four actions, always including the right one
  np=0
  split("none standon giveway headon overtake slow",pool," ")
  SO_N=0
  SO_[1]=SC_ACT
  j=1
  for(i=1;i<=6;i++){
    if(pool[i]==SC_ACT) continue
    if(pool[i]=="headon" && SC_ACT!="headon" && j>3) continue
    j++; if(j<=4) SO_[j]=pool[i]
  }
  # shuffle, reproducibly
  xsrand(SC_CO*1000+SC_SO*37+int(SC_CPA*100))
  for(i=4;i>1;i--){ j=1+int(xrand()*i); t=SO_[i]; SO_[i]=SO_[j]; SO_[j]=t }
  for(i=1;i<=4;i++) if(SO_[i]==SC_ACT) SC_A3=substr("abcd",i,1)
  SC_A1 = (SC_CPA<3.0) ? "a" : "b"
  SC_A2 = substr("abcd",SC_BAND,1)
  return 0
}

# ---- own position under a chosen action ------------------------------
#  The alteration is made at the third observation, twelve minutes in.
function act_course(k){ if(k=="giveway"||k=="headon") return nrm360(SC_CO+30)
                        if(k=="overtake") return nrm360(SC_CO+35); return SC_CO }
function act_speed(k){  if(k=="slow") return SC_SO*0.35; return SC_SO }
function ownE(t,k,   td){ td=0.2
  if(t<=td) return vE(SC_CO,SC_SO)*t
  return vE(SC_CO,SC_SO)*td + vE(act_course(k),act_speed(k))*(t-td) }
function ownN(t,k,   td){ td=0.2
  if(t<=td) return vN(SC_CO,SC_SO)*t
  return vN(SC_CO,SC_SO)*td + vN(act_course(k),act_speed(k))*(t-td) }
function tgtE(t){ return SC_P0E + vE(SC_CT,SC_ST)*t }
function tgtN(t){ return SC_P0N + vN(SC_CT,SC_ST)*t }
function rng_at(t,k,   de,dn){ de=tgtE(t)-ownE(t,k); dn=tgtN(t)-ownN(t,k)
  return sqrt(de*de+dn*dn) }
function cpa_under(k,   t,r,best,bt){ best=1e9
  for(t=0.2;t<=2.0;t+=0.002){ r=rng_at(t,k); if(r<best){ best=r; bt=t } }
  CPA_T=bt*60.0
  return best }

# ---- true-motion plot: the two tracks on the water -------------------
function plot_true(tnow,k,   w,h,i,t,mnE,mxE,mnN,mxN,sc,cx,cy,e,n,r,c,pad,de,dn){
  w=63; h=23
  mnE=0;mxE=0;mnN=0;mxN=0
  for(t=0;t<=tnow+0.001;t+=0.02){
    e=ownE(t,k); n=ownN(t,k)
    if(e<mnE)mnE=e; if(e>mxE)mxE=e; if(n<mnN)mnN=n; if(n>mxN)mxN=n
    e=tgtE(t); n=tgtN(t)
    if(e<mnE)mnE=e; if(e>mxE)mxE=e; if(n<mnN)mnN=n; if(n>mxN)mxN=n
  }
  pad=0.8
  mnE-=pad; mxE+=pad; mnN-=pad; mxN+=pad
  sc=(w-4)/(mxE-mnE); if((h-3)/((mxN-mnN)*0.5) < sc) sc=(h-3)/((mxN-mnN)*0.5)
  cx=(mnE+mxE)/2; cy=(mnN+mxN)/2
  gclear(w,h)
  for(t=0;t<=tnow+0.001;t+=0.01){
    gputwc(h/2-(ownN(t,k)-cy)*sc*0.5, w/2+(ownE(t,k)-cx)*sc, ".", C_DIM)
    gputwc(h/2-(tgtN(t)-cy)*sc*0.5,   w/2+(tgtE(t)-cx)*sc,   ",", C_DIM)
  }
  gputc(h/2-(ownN(tnow,k)-cy)*sc*0.5, w/2+(ownE(tnow,k)-cx)*sc, "A", C_ACC)
  gputc(h/2-(tgtN(tnow)-cy)*sc*0.5,   w/2+(tgtE(tnow)-cx)*sc,   "B", C_ACC)
  gputs(h/2-(ownN(tnow,k)-cy)*sc*0.5+1, w/2+(ownE(tnow,k)-cx)*sc-1, "you")
  gputsc(0,1,"north up, true motion    A you    B her",C_DIM)
  gputsc(h-1,1,sprintf("%.1f nm per column",1/sc),C_DIM)
  TP_R = rng_at(tnow,k)
  de=tgtE(tnow)-ownE(tnow,k); dn=tgtN(tnow)-ownN(tnow,k)
  TP_B = brg(de,dn)
  return 0
}
function scen_mark(a1,a2,a3,   ok,c1,c2,c3,cpa0,cpaN,i){
  print ""
  c1=(tolower(a1)==SC_A1); c2=(tolower(a2)==SC_A2); c3=(tolower(a3)==SC_A3)
  ok=(c1&&c2&&c3)
  printf "  Q1 risk      you said %s   %s\n", toupper(a1), (c1?cw("right",C_ACC):"the answer is " toupper(SC_A1))
  printf "  Q2 how close you said %s   %s\n", toupper(a2), (c2?cw("right",C_ACC):"the answer is " toupper(SC_A2))
  printf "  Q3 action    you said %s   %s\n", toupper(a3), (c3?cw("right",C_ACC):"the answer is " toupper(SC_A3))
  hr()
  printf "  Her true course and speed:   %03d T at %.1f knots\n", SC_CT, SC_ST
  printf "  Closest point of approach:   %.1f nm, in %.0f minutes\n", SC_CPA, SC_TCPA
  hr()
  print "  How the plot gives you that. The three marks lie on a straight line -"
  print "  her motion relative to you. Extend it: the nearest it passes to the"
  print "  centre is the CPA, and how long she takes to get there is the time to it."
  print ""
  print "  Her true course comes from the vector triangle:"
  printf "     your vector      %03d T  %4.1f kn  over 12 minutes\n", SC_CO, SC_SO
  printf "     relative vector  %03d T  %4.1f kn  (the line through the marks)\n",
         brg(SC_VRE,SC_VRN), sqrt(SC_VRE^2+SC_VRN^2)
  printf "     her true vector  %03d T  %4.1f kn  = yours plus the relative one\n", SC_CT, SC_ST
  plot_rel(1)
  hr(); gshow(); hr()
  printf "  %s -- %s\n", cw(act_text(SC_ACT),C_ACC), SC_RULE
  printf "  %s\n", SC_WHY
  print ""
  SCEN_OK = ok
  return 0
}
function scen_outcome(k,   c0,cn,t0,tn){
  c0=cpa_under("none"); t0=CPA_T
  cn=cpa_under(k);      tn=CPA_T
  printf "\n  You chose: %s\n", act_text(k)
  printf "  If you hold on:            %.2f nm at %.0f minutes\n", c0, t0
  printf "  With the action you chose: %.2f nm at %.0f minutes  %s\n", cn, tn,
     (cn>c0+0.15 ? cw("- opened up",C_ACC) : (cn<c0-0.05 ? cw("- CLOSER. That is the wrong way.",C_ACC) : "- barely changed"))
  print ""
  return 0
}
