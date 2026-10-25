#  Reference values for the celnav browser build, emitted by the awk
#  engine itself at full double precision.
#
#  WHAT THIS EXISTS TO CATCH.  plot.js shipped using solve_fix()'s FIRST
#  PASS as the fix.  solve_fix() linearises the sight reduction about the
#  position it is handed, so from a live DR the first pass is right to a
#  few hundredths of a mile and from a DR five degrees away it is 43 nm
#  out.  Every per-sight number - Ho, Hc, Zn, the intercept - was correct
#  the whole time, so nothing looked wrong on screen, and the one number
#  a navigator actually plots was the one that was wrong.  Only a fix
#  compared against the shell over a spread of DRs finds that.
#
#  So this does not check the pieces.  It generates whole cases, runs the
#  shell's own cmd_reduce() path over them - solve_fix(), converge_fix(),
#  the residual pass - and emits every number at %.17g.
#
#  THE CASES ARE GENERATED, NOT TYPED.  A seeded LCG picks a true
#  position, a time, and two to five bodies; the sights are then made by
#  INVERTING corrections(), so each Hs is a reading that a sextant would
#  actually have produced at that position, with noise added.  The DR is
#  offset from the truth by anything from a mile to several hundred,
#  which is the axis the bug lived on.
#
#  Loaded second: engine.awk's BEGIN dispatches on cmd= and would exit
#  before this ran, so the harness passes no cmd.
#
#  Output goes to stdout, one tab-separated row per line:
#     CASE id drlat drlon speed course fixjd nsights
#     SGT  id i utc body jd hs ie he tm pr limb
#     LOP  id i ho hc zn intercept aplat aplon lha gha dec run
#     FIX  id ok lat lon fix_n fix_e shift rms
#     NRM  id a b c det
#     RES  id i residual
BEGIN{
  if(NCASE=="") NCASE=400
  if(SEED=="")  SEED=20261025
  srnd(SEED)
  np = split("sun,moon,venus,mars,jupiter,saturn", PLANET, ",")
  #  SCN mode: emit ONE scenario as a sight file in the shell's own
  #  format, for the page stage to type into the form and for the shell
  #  to reduce.  Same inv_corr(), so the readings are readings and not
  #  numbers somebody liked the look of.
  if(SCN!=""){ scenario(); exit }
  for(cid=1; cid<=NCASE; cid++) gencase(cid)
}

#  -v SCN="Sun,Moon" -v TLAT=35 -v TLON=-40 -v UTC0="2026-08-29 14:00:00"
#  Conditions arrive as SHEYE/SIE/STEMP/SPRESS, not HEYE/IE/TM/PR: engine.awk
#  already has arrays called TM and IE, and mawk will not take a scalar
#  reference to a name it has seen subscripted - it stops with "illegal
#  reference to array TM" and names a line in THIS file, which is a
#  confusing way to find out.
#  PADFIX=1 drags the first sight's minutes to 9.96, which is the only
#  window where a zero-pad taken from the value instead of the rounded
#  string goes wrong.  celnav-ui.js refuses to pass a scenario without
#  one, so every scenario carries one.
function scenario(   n,i,b,utc,jd,hc,hs,limb,he,ie,tm,pr,emitted){
  n = split(SCN, SB, ",")
  he = (SHEYE!="" ? SHEYE+0 : 2.5); ie = (SIE!="" ? SIE+0 : 0)
  tm = (STEMP!="" ? STEMP+0 : 10);  pr = (SPRESS!="" ? SPRESS+0 : 1010)
  emitted = 0
  for(i=1;i<=n;i++){
    b = SB[i]
    utc = utc_plus(UTC0, (i-1)*4)
    jd  = parse_utc(utc)
    if(body_at(b,jd)=="ERR"){ printf "#  %s: unknown body\n", b; continue }
    reduce_sight(TLAT+0, TLON+0, B_GHA, B_DEC)
    hc = R_HC
    if(hc<6 || hc>84){ printf "#  %s at %s: Hc %.1f, not a sight\n", b, utc, hc; continue }
    limb = (B_SD>0 ? "L" : "C")
    hs = inv_corr(hc, ie,he,tm,pr,limb)
    if(hs=="ERR"){ printf "#  %s: no Hs inverts to Hc %.4f\n", b, hc; continue }
    emitted++
    if(emitted==1 && PADFIX!="") hs = int(hs) + 9.96/60.0
    #  TWO decimals of minutes, not fmt_dm's one.  The pad sight is 9.96',
    #  and fmt_dm would write it "10.0'" - at which point the file no
    #  longer says what it was built to say, and celnav-ui.js cannot tell
    #  that the scenario reaches the window.  It has to be readable from
    #  the file, not passed beside it.
    printf "%s|%s|%s|%s|%g|%g|%g|%g\n", utc, b, limb, min2(hs), ie, he, tm, pr
  }
}
#  degrees and minutes to two decimals, carrying at 59.995
function min2(x,   d,m){
  d = int(x); m = (x-d)*60.0
  if(m >= 59.995){ m = 0; d = d+1 }
  return sprintf("%d %05.2f'", d, m)
}
#  add whole minutes to a "YYYY-MM-DD HH:MM:SS", through the julian date so
#  the hour and the day carry themselves
function utc_plus(u,mins,   jd){
  jd = parse_utc(u) + mins/1440.0
  jd2cal(jd)
  return sprintf("%04d-%02d-%02d %s", CAL_Y, CAL_M, CAL_D, fmt_hms(CAL_FRAC*24))
}

#  ---- a reproducible LCG.  awk's rand() differs between awks, and a
#  harness whose cases depend on which awk ran it is not a harness.
function srnd(s){ RSEED = s % 2147483647; if(RSEED<=0) RSEED += 2147483646 }
function rnd(){ RSEED = (RSEED * 16807) % 2147483647; return RSEED / 2147483647 }
function rrange(lo,hi){ return lo + rnd()*(hi-lo) }
function rint(lo,hi){ return lo + int(rnd()*(hi-lo+1)) }

#  ---- Hs from Ho.  corrections() goes one way only, so this walks back:
#  the correction chain is smooth and nearly linear in Hs, so adding the
#  shortfall converges in a handful of passes.  Returns 'ERR' if it does
#  not, rather than emitting a sight that is not a sight.
function inv_corr(target,ie,he,tm,pr,limb,   hs,i,d){
  hs = target
  for(i=0;i<60;i++){
    d = target - corrections(hs,ie,he,tm,pr,limb)
    hs = hs + d
    if(fabs(d) < 1e-13) return hs
  }
  return "ERR"
}

function gencase(cid,   tlat,tlon,y,mo,da,hh,mi,se,utc,jd,i,nb,b,hc,hs,ie,he,tm,pr,limb,
                        ns,dN,dE,alat,alon,res,rms,want,tries,sp,co,used){
  tlat = rrange(-70,70); tlon = rrange(-180,180)
  y  = rint(2024,2028); mo = rint(1,12); da = rint(1,28)
  hh = rint(0,23); mi = rint(0,59); se = rint(0,59)
  he = rrange(1,30); ie = rrange(-3,3)
  tm = rrange(-20,40); pr = rrange(960,1050)
  #  a run, for a third of the cases: the LOPs then have to be advanced
  sp = (rnd()<0.33 ? rrange(2,14) : 0); co = rrange(0,360)

  want = rint(2,5); ns = 0; tries = 0
  split("", used)
  while(ns<want && tries<40){
    tries++
    if(rnd()<0.30) b = PLANET[rint(1,np)]
    else           b = "" rint(1,57)
    #  one sight per body: a round of the same star four minutes apart is
    #  a real thing to shoot, but it makes the cut parallel and every case
    #  would end up testing the no-fix branch instead of the fix.
    if(b in used) continue
    used[b] = 1
    #  spread the sights over a window, so the run matters
    utc = sprintf("%04d-%02d-%02d %02d:%02d:%02d", y,mo,da,hh,(mi+ns*4)%60,se)
    jd  = parse_utc(utc)
    if(body_at(b,jd)=="ERR") continue
    reduce_sight(tlat,tlon,B_GHA,B_DEC)
    hc = R_HC
    if(hc<6 || hc>84) continue                 # not a sight anybody shoots
    limb = (B_SD>0 ? (rnd()<0.5?"L":"U") : "C")
    hs = inv_corr(hc + rrange(-0.8,0.8)/60.0, ie,he,tm,pr,limb)
    if(hs=="ERR" || hs<0 || hs>90) continue
    ns++
    S_UTC[ns]=utc; S_BODY[ns]=b; S_LIMB[ns]=limb; S_HS[ns]=hs
    S_IE[ns]=ie; S_HE[ns]=he; S_TM[ns]=tm; S_PR[ns]=pr; S_JD[ns]=jd
  }
  if(ns<2) return

  #  the DR: anything from on top of the fix to several hundred miles off
  alat = tlat + rrange(-1,1)*(rnd()<0.5 ? 0.05 : 6)
  alon = tlon + rrange(-1,1)*(rnd()<0.5 ? 0.05 : 8)
  if(alat>89) alat=89; if(alat<-89) alat=-89

  speed = sp; course = co                      # solve_fix reads these globals
  FIXJD = S_JD[ns]

  printf "CASE\t%d\t%.17g\t%.17g\t%.17g\t%.17g\t%.17g\t%d\n", cid,alat,alon,sp,co,FIXJD,ns
  for(i=1;i<=ns;i++)
    printf "SGT\t%d\t%d\t%s\t%s\t%.17g\t%.17g\t%.17g\t%.17g\t%.17g\t%.17g\t%s\n",
      cid,i,S_UTC[i],S_BODY[i],S_JD[i],S_HS[i],S_IE[i],S_HE[i],S_TM[i],S_PR[i],S_LIMB[i]

  solve_fix(ns,alat,alon,1)                    # the printed working, from the DR
  dN=SOL_N; dE=SOL_E
  for(i=1;i<=ns;i++)
    printf "LOP\t%d\t%d\t%.17g\t%.17g\t%.17g\t%.17g\t%.17g\t%.17g\t%.17g\t%.17g\t%.17g\t%.17g\n",
      cid,i,S_HO[i],S_HC[i],S_ZN[i],S_INT[i],AP_LAT[i],AP_LON[i],S_LHA[i],S_GHA[i],S_DEC[i],S_RUN[i]

  if(!SOL_OK){ printf "FIX\t%d\t0\t0\t0\t0\t0\t0\t0\n", cid; return }

  converge_fix(ns,alat,alon,dN,dE)             # the SHELL's convergence, not a copy
  solve_fix(ns,FIXLAT,FIXLON,0)                # residuals belong at the fix
  printf "NRM\t%d\t%.17g\t%.17g\t%.17g\t%.17g\n", cid,NM_A,NM_B,NM_C,NM_DET
  rms=0
  for(i=1;i<=ns;i++){
    res = PP[i] - (SOL_N*cosd(ZN[i]) + SOL_E*sind(ZN[i]))
    printf "RES\t%d\t%d\t%.17g\n", cid,i,res
    rms += res*res
  }
  printf "FIX\t%d\t1\t%.17g\t%.17g\t%.17g\t%.17g\t%.17g\t%.17g\n",
    cid,FIXLAT,FIXLON,FIX_N,FIX_E,FIX_SHIFT,sqrt(rms/ns)

  #  ---- the two engine functions the noon and Polaris screens rest on.
  #  lan_jd() iterates FIVE times - not to a tolerance - so a port that
  #  stops when it thinks it has converged agrees only by luck; and
  #  pol_lat() is the closed form the almanac's a0/a1/a2 columns
  #  approximate. Both emitted per case so they are covered over the same
  #  spread of positions and dates as everything else.
  printf "LAN\t%d\t%.17g\n", cid, lan_jd(alon, int(FIXJD+0.5)-0.5)
  printf "POL\t%d\t%.17g\t%.17g\t%.17g\n", cid,
    pol_lat(48.2, 89.37, nrm360(343.0 + alon)),
    pol_lat(fabs(alat), 89.37, nrm360(S_JD[1]*13.0 + alon)),
    pol_lat(fabs(alat)/2 + 10, 89.0, nrm360(alon*3))
}
