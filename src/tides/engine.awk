# =====================================================================
#  tides -- harmonic tide prediction
#  Part of Bash Navigation Software.  Pure POSIX awk, no network.
#
#  A tide is not computable from a position.  It depends on the shape of
#  the coast, the depth and the resonance of the basin, so every place
#  needs harmonic constants measured there.  This program does the
#  synthesis; the constants come from the station file beside it.
#
#  The constituent definitions and the nodal machinery follow Foreman,
#  as carried by UTide - see src/tides/gen/make_tables.py.
# =====================================================================

function d2r(x){ return x*0.0174532925199432958 }
function sind(x){ return sin(x*0.0174532925199432958) }
function cosd(x){ return cos(x*0.0174532925199432958) }
function atan2d(y,x){ return 57.2957795130823209*atan2(y,x) }
function fabs(x){ return (x<0)?-x:x }
function ffloor(x,   n){ n=int(x); return (x<n)?n-1:n }
function frac1(x){ return x - ffloor(x) }
function nrm360(x){ x=x-360*int(x/360); if(x<0) x+=360; return x }

# ---- Julian Date from a UT calendar date ----------------------------
function jdate(y,m,d,   a,b){
  if(m<=2){ y=y-1; m=m+12 }
  a=int(y/100); b=2-a+int(a/4)
  return int(365.25*(y+4716))+int(30.6001*(m+1))+d+b-1524.5
}
function jd2cal(jd,   z,f,a,al,b,c,dd,e){
  jd=jd+0.5; z=int(jd); f=jd-z
  if(z<2299161){ a=z } else { al=int((z-1867216.25)/36524.25); a=z+1+al-int(al/4) }
  b=a+1524; c=int((b-122.1)/365.25); dd=int(365.25*c); e=int((b-dd)/30.6001)
  CAL_D=b-dd-int(30.6001*e)+f
  CAL_M=(e<14)?e-1:e-13
  CAL_Y=(CAL_M>2)?c-4716:c-4715
  CAL_FRAC=CAL_D-int(CAL_D); CAL_D=int(CAL_D)
  return CAL_Y
}
function dow(jd,   n){ n=int(jd+1.5)%7; return substr("SunMonTueWedThuFriSat",n*3+1,3) }

# ---- the astronomical variables, in cycles --------------------------
#  s  mean longitude of the moon        p   lunar perigee
#  h  mean longitude of the sun         np  NEGATIVE of the ascending node
#  tau lunar time                       pp  solar perigee
function tide_astron(jd,   d,D,i,day){
  d = jd - 2415020.0                       # days from 1899-12-31 12:00 UT
  D = d/10000.0
  AS_S  = frac1((270.434164  + 13.1763965*d   - 0.000085*D*D    + 0.000000039*D*D*D)/360.0)
  AS_H  = frac1((279.696678  +  0.9856473354*d+ 0.00002267*D*D                      )/360.0)
  AS_P  = frac1((334.329556  +  0.1114040803*d- 0.0007739*D*D   - 0.00000026*D*D*D  )/360.0)
  AS_NP = frac1((-259.183275 +  0.0529539222*d- 0.0001557*D*D   - 0.00000005*D*D*D  )/360.0)
  AS_PP = frac1((281.220844  +  0.0000470684*d+ 0.0000339*D*D   + 0.00000007*D*D*D  )/360.0)
  day   = frac1(jd + 0.5)                  # fraction of the day since midnight
  AS_TAU= day + AS_H - AS_S
  return 0
}

# ---- Foreman's nodal factors and the astronomical argument ----------
#  F  amplitude factor, U phase correction, V equilibrium argument
#  All phases are in cycles.
function tide_fuv(jd,lat,   i,k,s0,sn,rr,uu,re,im,slat,n,j,i0,c,resolved,pass){
  tide_tables_init()
  tide_astron(jd)
  slat = sind(lat)
  if(fabs(lat)<5) slat = (lat<0?-1:1)*sind(5)
  for(i=1;i<=TT_N;i++){
    if(CHN[i]>0) continue                                # shallow: later
    re=1; im=0
    s0=CS0[i]; sn=CSN[i]
    for(k=s0; k<s0+sn; k++){
      if(k<1) continue
      rr = SAMP[k]
      if(SLAT[k]==1) rr = rr*0.36309*(1.0-5.0*slat*slat)/slat
      else if(SLAT[k]==2) rr = rr*2.59808*slat
      uu = SD1[k]*AS_P + SD2[k]*AS_NP + SD3[k]*AS_PP + SPH[k]
      uu = uu - int(uu)
      re += rr*cos(6.283185307179586*uu)
      im += rr*sin(6.283185307179586*uu)
    }
    CF_[i] = sqrt(re*re+im*im)
    CU_[i] = atan2(im,re)/6.283185307179586
    CV_[i] = CD1[i]*AS_TAU + CD2[i]*AS_S + CD3[i]*AS_H + CD4[i]*AS_P \
           + CD5[i]*AS_NP + CD6[i]*AS_PP + CSEMI[i]
    CV_[i] = CV_[i] - int(CV_[i])
    CDONE[i]=1
  }
  # shallow-water constituents are products and sums of the others
  for(pass=0; pass<6; pass++){
    for(i=1;i<=TT_N;i++){
      if(CHN[i]==0 || CDONE[i]) continue
      i0=CH0[i]; resolved=1
      for(k=i0; k<i0+CHN[i]; k++) if(HIN[k]<1 || !CDONE[HIN[k]]) resolved=0
      if(!resolved) continue
      CF_[i]=1; CU_[i]=0; CV_[i]=0
      for(k=i0; k<i0+CHN[i]; k++){
        j=HIN[k]; c=HCO[k]
        CF_[i] = CF_[i] * exp(fabs(c)*log(CF_[j]))
        CU_[i] = CU_[i] + c*CU_[j]
        CV_[i] = CV_[i] + c*CV_[j]
      }
      CDONE[i]=1
    }
  }
  for(i=1;i<=TT_N;i++) CDONE[i]=0
  return 0
}

# ---- rates of the astronomical variables, cycles per day -----------
function tide_rates(jd,   d,D){
  d = jd - 2415020.0; D = d/10000.0
  RS  = (13.1763965    - 2*0.000085*D/10000    + 3*0.000000039*D*D/10000)/360.0
  RH  = ( 0.9856473354 + 2*0.00002267*D/10000                            )/360.0
  RP  = ( 0.1114040803 - 2*0.0007739*D/10000   - 3*0.00000026*D*D/10000  )/360.0
  RNP = ( 0.0529539222 - 2*0.0001557*D/10000   - 3*0.00000005*D*D/10000  )/360.0
  RPP = ( 0.0000470684 + 2*0.0000339*D/10000   + 3*0.00000007*D*D/10000  )/360.0
  RTAU= 1.0 + RH - RS
  return 0
}
# ---- prepare a station for a day: nodal factors and speeds ---------
#  F and U change over months, not hours, so they are computed once at the
#  middle of the interval and held.  V is linear in time and stepped.
function tide_prep(jd0,lat,   i){
  tide_fuv(jd0,lat)
  tide_rates(jd0)
  for(i=1;i<=TT_N;i++)
    CW_[i] = CD1[i]*RTAU + CD2[i]*RS + CD3[i]*RH + CD4[i]*RP + CD5[i]*RNP + CD6[i]*RPP
  TP_JD0 = jd0
  return 0
}
# ---- the height at a time, metres above the station's datum --------
function tide_h(jd,   i,ph,s){
  s = ST_Z0
  for(i=1;i<=ST_N;i++){
    ph = 360.0*(CV_[ST_C[i]] + CU_[ST_C[i]] + CW_[ST_C[i]]*(jd-TP_JD0)) - ST_P[i]
    s += ST_F[i]*cosd(ph)
  }
  return s
}
# load the amplitudes and phases for the station, with the nodal factor
function tide_station_prep(   i){
  for(i=1;i<=ST_N;i++) ST_F[i] = ST_A[i]*CF_[ST_C[i]]
  return 0
}
