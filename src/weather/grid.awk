# =====================================================================
#  weather -- the character grid, for the one figure this tool draws.
#
#  WHY THIS IS A FOURTH COPY, and what the alternative is.
#
#  celnav, colregs and tides each carry their own grid. The SETTERS are
#  the same in all three; `gshow` is not, and that is the point: celnav's
#  carries the FIGDUMP path the web generator needs, colregs' paints its
#  own panel so the artwork is legible whatever the terminal profile is,
#  and tides' calls col_init() itself. Extracting the lot would mean
#  rewriting `gshow` in three working tools to serve a figure in a fourth,
#  which is a large blast radius for a small gain.
#
#  So this is celnav's grid, FIGDUMP path included, copied rather than
#  shared. The honest version of that trade: if a fifth tool ever needs
#  one, extract the setters into src/common/ and leave each tool its own
#  `gshow` - the setters are nine lines and genuinely identical, and the
#  divergence is all in the painting.
#
#  Drawing conventions, so this reads the same as the other three:
#    row 0 is the TOP, column 0 is the left
#    gput overwrites, gputw writes only into blank space
#    the c-suffixed forms take a colour; the others inherit the panel's
# =====================================================================
#  THE PANEL COLOURS ARE DEFINED HERE, not in src/common/colour.awk.
#  That file is shared with another tool and gives C_BASE and C_RST; it
#  has no panel concept. celnav's own col_init() adds C_PANEL and C_EOL,
#  and gshow() below needs them -- copied without this, every name would
#  be the empty string and the figure would print with no panel at all.
#  On a light terminal profile that is white artwork on white, which is
#  the exact failure docs/HACKING.md records for the colregs lights.
function gcol_init(   e){
  if(GCOL_READY) return
  col_init()
  e=sprintf("%c",27)
  if(cmode=="night"){ C_PANEL = e "[40m" e "[31m"; C_EOL = e "[K" C_BASE }
  else if(cmode=="day"){ C_PANEL = e "[40m" e "[37m"; C_EOL = e "[K" C_BASE }
  else { C_PANEL=""; C_EOL="" }
  GCOL_READY=1
  return 0
}
function gclear(w,h,   r,c){ gcol_init(); PW=w; PH=h
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
#  The plot is painted as its own panel, so it is legible whatever the
#  terminal's own background happens to be.
function gshow(   r,c,line,cur,last,cc){
  #  THE WEB GENERATOR WANTS A GAP, NOT A PICTURE OF A TERMINAL. These
  #  figures are drawn on a character grid -- the globe with its
  #  graticule and circles of position, the celestial triangle, the LOP
  #  zoom -- and 25 rows of 67 characters is a picture of a terminal,
  #  not a figure, in a browser 380px wide. Under -v FIGDUMP=1 the grid
  #  is replaced by a marker the dumper turns into a named gap, and the
  #  prose around it still prints. Set by the generator alone; the tool
  #  never sets it. Same move as ct_plot() in colregs.
  #
  #  The grid is still cleared, so a figure built and skipped cannot
  #  leave its marks inside the next one.
  if(FIGDUMP){ print "@@FIG grid " PW " " PH; gclear(PW,PH); return 0 }
  for(r=0;r<PH;r++){
    last=-1
    for(c=0;c<PW;c++) if(G[r,c]!=" ") last=c
    line=""; cur=""
    for(c=0;c<=last;c++){
      cc=GC[r,c]
      if(cc!=cur){ line = line (cc==""? C_PANEL : cc); cur=cc }
      line = line G[r,c]
    }
    print "  " C_PANEL line C_EOL
  }
  return 0
}

# ---------------------------------------------------------------------
#  THE TWO SHELLS, DRAWN.  Coriolis's demonstration, as a picture.
#
#  WHY THIS FRAME AND NOT THE OTHER ONE.  The lesson tells the story in
#  the inertial frame, where nothing curves and nothing pushes, and that
#  is the honest account.  It does not DRAW: at true proportions a
#  shell's path in that frame is a straight radial line and the ground
#  turns under it by an invisible amount -- which is exactly why the real
#  deflection is a couple of hundred metres and not ninety miles.  Drawn
#  at a scale
#  where the rotation shows, the "straight line" wraps most of the way
#  round the pole and stops looking like gunnery at all.
#
#  So this is the GUNNER'S frame, which is what a range table's diagram
#  shows: the line of fire, the track, and where the shell actually
#  lands.  Two panels side by side, because the point of the figure is
#  the punchline -- fired north it lands east, fired south it lands west,
#  and both of those are to the RIGHT of the line of fire.  One panel
#  cannot show that; two show it without a word.
#
#  WHAT IS COMPUTED AND WHAT IS SCALED.  The cross-track deflection goes
#  as the SQUARE of the time of flight -- the rotating frame's
#  acceleration 2*Omega x v is constant along the track, so the offset is
#  a parabola -- and the curve drawn here is that parabola, computed, not
#  a hand-drawn arc.  Its SIZE is scaled to the width of the panel and
#  the caption says so, with the real figure beside it.  A figure that
#  silently exaggerated would be teaching the wrong magnitude, which in
#  gunnery is the whole game.
# ---------------------------------------------------------------------
function gun_track(x0,ytop,ybot,dirn,sign,   i,n,t,dx,row,col){
  #  dirn  -1 fires up the page (north), +1 fires down it (south)
  #  sign  +1 deflects to page-right, -1 to page-left
  n = ybot - ytop
  for(i=0;i<=n;i++){
    t   = i/n                       # fraction of the flight
    dx  = sign * GUN_DEF * t * t    # the parabola: offset goes as t^2
    row = (dirn<0 ? ybot - i : ytop + i)
    col = x0 + dx
    gputc(row, col, (i==n ? "*" : "."), (i==n ? C_ACC : C_DIM))
  }
  return 0
}
function gun_panel(x0,ylo,yhi,dirn,sign,fired,   r,yimp,c){
  #  the line of fire: straight, the way the gun was laid
  for(r=ylo;r<=yhi;r++) gputw(r, x0, "|")
  yimp = (dirn<0 ? ylo : yhi)          # the row the shell arrives on
  gun_track(x0, ylo, yhi, dirn, sign)
  #  THE GAP IS THE WHOLE POINT, so it is drawn and not left to be
  #  inferred from two marks at different columns: this is the quantity a
  #  range table carries a column for.
  for(c=1;c<GUN_DEF;c++) gputwc(yimp, x0 + sign*c, "-", C_DIM)
  gputc(yimp, x0, "+", C_DIM)                    # aim: a still earth
  gputc(yimp, x0 + sign*GUN_DEF, "*", C_ACC)     # fall: the real one
  gputsc(yimp + (dirn<0 ? -1 : 1), x0-1, "aim", C_DIM)
  #  the gun at the breech end, and which way it was laid
  gputsc((dirn<0 ? yhi+1 : ylo-1), x0-1, "GUN", C_DIM)
  gputsc((dirn<0 ? ylo-2 : yhi+2), x0-int(length(fired)/2), fired, C_ACC)
  return 0
}
function gun_figure(   w,h,xl,xr,ylo,yhi){
  #  THIRTY-FOUR COLUMNS, NOT SIXTY-NINE. Drawn two panels wide at a
  #  comfortable 69 it was legible on a laptop and useless on the device
  #  this tool is for: at 390 px the whole FIRED SOUTH panel sat off the
  #  right-hand edge, so the one thing the figure exists to show -- east
  #  one way, west the other, both to the right -- was the part you could
  #  not see. A phone fits about 34 monospace columns, which is narrower
  #  than weather's own tables, so this now fits where they do not.
  w=34; h=21
  gclear(w,h)
  GUN_DEF = 6                       # columns of deflection at impact
  xl = 8; xr = 25; ylo = 3; yhi = 15

  gun_panel(xl, ylo, yhi, -1, +1, "FIRED NORTH")
  gun_panel(xr, ylo, yhi, +1, -1, "FIRED SOUTH")

  #  where each one falls, named OUTBOARD of the fall and on the row it
  #  falls on - away from the aim, so the word lands in empty space
  #  instead of across the line of fire.
  gputsc(ylo, xl + GUN_DEF + 2, "EAST", C_ACC)
  gputsc(yhi, xr - GUN_DEF - 6, "WEST", C_ACC)

  #  and the sentence the picture exists to make obvious, wrapped to fit.
  #  The latitude is named HERE rather than in the lesson's heading,
  #  because the browser's version of this demonstration has a slider and
  #  a heading naming one latitude would be false there the moment it moved.
  gputsc(yhi+3, 0, "both are to the RIGHT of", C_ACC)
  gputsc(yhi+4, 0, "the line of fire", C_ACC)
  gputsc(yhi+5, 0, "drawn from 45 N", C_DIM)
  return 0
}
