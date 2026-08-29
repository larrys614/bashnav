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
#  NOT named RS, RH and so on: RS is awk's record separator, and setting
#  it to 0.0366 makes the next getline read a whole file as one record.
#  Nothing warns you; the file simply appears to be one line long.
function tide_rates(jd,   d,D){
  d = jd - 2415020.0; D = d/10000.0
  R_S  = (13.1763965    - 2*0.000085*D/10000    + 3*0.000000039*D*D/10000)/360.0
  R_H  = ( 0.9856473354 + 2*0.00002267*D/10000                            )/360.0
  R_P  = ( 0.1114040803 - 2*0.0007739*D/10000   - 3*0.00000026*D*D/10000  )/360.0
  R_NP = ( 0.0529539222 - 2*0.0001557*D/10000   - 3*0.00000005*D*D/10000  )/360.0
  R_PP = ( 0.0000470684 + 2*0.0000339*D/10000   + 3*0.00000007*D*D/10000  )/360.0
  R_TAU= 1.0 + R_H - R_S
  return 0
}
# ---- prepare a station for a day: nodal factors and speeds ---------
#  F and U change over months, not hours, so they are computed once at the
#  middle of the interval and held.  V is linear in time and stepped.
function tide_prep(jd0,lat,   i,j,k,pass,left,w,ok){
  tide_fuv(jd0,lat)
  tide_rates(jd0)
  #  Constituents with Doodson numbers of their own.
  for(i=1;i<=TT_N;i++){
    CWOK[i]=0
    if(!CDOK[i]) continue
    CW_[i] = CD1[i]*R_TAU + CD2[i]*R_S + CD3[i]*R_H + CD4[i]*R_P + CD5[i]*R_NP + CD6[i]*R_PP
    CWOK[i]=1
  }
  #  A shallow-water constituent is a PRODUCT of others and has no
  #  Doodson numbers of its own, so its speed is the same weighted sum
  #  of its parents' speeds that its phase is of theirs. Leaving it at
  #  zero turns an overtide into a constant offset that drifts with the
  #  date - which is exactly what it did, to five centimetres.
  for(pass=0; pass<6; pass++){
    left=0
    for(i=1;i<=TT_N;i++){
      if(CWOK[i] || CHN[i]<=0) continue
      w=0; ok=1
      for(k=CH0[i]; k<CH0[i]+CHN[i]; k++){
        j=HIN[k]
        if(!CWOK[j]){ ok=0; break }
        w += HCO[k]*CW_[j]
      }
      if(ok){ CW_[i]=w; CWOK[i]=1 } else left++
    }
    if(left==0) break
  }
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

# =====================================================================
#  The station file.
#
#    R|id|name|region|country|lat|lon|tzmin|z0mm|datum|lostmm|i:amp:ph,...
#    S|id|name|region|country|lat|lon|tzmin|refid|htype|hhi|hlo|thi|tlo
#
#  Reference stations carry harmonic constants measured there.
#  Subordinate stations carry offsets from a reference station: a time
#  offset in minutes for high and for low water, and either a ratio or a
#  fixed correction on the height.  That is how a real tide table is
#  built, and it is why "nearest station" is a question about a HARBOUR
#  and not about a position.
# =====================================================================
function st_reset(   i){
  ST_N=0; ST_Z0=0; ST_ID=""; ST_NAME=""; ST_REGION=""; ST_COUNTRY=""
  ST_LAT=0; ST_LON=0; ST_TZ=0; ST_DATUM=""; ST_KIND=""
  SB_REF=""; SB_TYPE=""; SB_HHI=1; SB_HLO=1; SB_THI=0; SB_TLO=0
  return 0
}
#  Take one R line and load the constants. Amplitudes are in millimetres
#  and phases in tenths of a degree in the file, to keep it small.
function st_take_ref(line,   f,n,cs,nc,i,t,nt){
  n=split(line,f,"|")
  if(n<12) return 0
  ST_KIND="R"
  ST_ID=f[2]; ST_NAME=f[3]; ST_REGION=f[4]; ST_COUNTRY=f[5]
  ST_LAT=f[6]+0; ST_LON=f[7]+0; ST_TZ=f[8]+0
  ST_Z0=(f[9]+0)/1000.0; ST_DATUM=f[10]
  ST_LOST=(f[11]+0)/1000.0
  nc=split(f[12],cs,",")
  ST_N=0
  for(i=1;i<=nc;i++){
    nt=split(cs[i],t,":")
    if(nt<3) continue
    ST_N++
    ST_C[ST_N]=t[1]+0            # index into the constituent table
    ST_A[ST_N]=(t[2]+0)/1000.0   # metres
    ST_P[ST_N]=(t[3]+0)/10.0     # degrees
  }
  return ST_N
}
function st_take_sub(line,   f,n){
  n=split(line,f,"|")
  if(n<14) return 0
  ST_KIND="S"
  ST_ID=f[2]; ST_NAME=f[3]; ST_REGION=f[4]; ST_COUNTRY=f[5]
  ST_LAT=f[6]+0; ST_LON=f[7]+0; ST_TZ=f[8]+0
  SB_REF=f[9]; SB_TYPE=f[10]
  SB_HHI=f[11]+0; SB_HLO=f[12]+0
  SB_THI=f[13]+0; SB_TLO=f[14]+0
  return 1
}
#  Find one station by exact id. Returns 1 if found.
function st_load(file,id,   line,f,got){
  st_reset(); got=0
  while((getline line < file) > 0){
    if(substr(line,1,1)=="#") continue
    split(line,f,"|")
    if(f[2]!=id) continue
    if(f[1]=="R") got=(st_take_ref(line)>0)
    else if(f[1]=="S") got=st_take_sub(line)
    break
  }
  close(file)
  return got
}
# ---- great-circle distance, nautical miles --------------------------
function st_dist(la1,lo1,la2,lo2,   dla,dlo,a,c){
  dla=d2r(la2-la1); dlo=d2r(lo2-lo1)
  a = sin(dla/2)*sin(dla/2) + cosd(la1)*cosd(la2)*sin(dlo/2)*sin(dlo/2)
  if(a<0) a=0
  if(a>1) a=1
  c = 2*atan2(sqrt(a), sqrt(1-a))
  return c*3437.74677    # radians to nautical miles
}
function st_bearing(la1,lo1,la2,lo2,   y,x){
  y = sind(lo2-lo1)*cosd(la2)
  x = cosd(la1)*sind(la2) - sind(la1)*cosd(la2)*cosd(lo2-lo1)
  return nrm360(atan2d(y,x))
}
#  Insert into a fixed-size "best so far" list kept sorted ascending.
function st_keep(k,d,id,nm,rg,cy,la,lo,kind,   i,j){
  if(SR_N>=k && d>=SR_D[SR_N]) return 0
  i = (SR_N<k) ? ++SR_N : SR_N
  while(i>1 && SR_D[i-1]>d){
    SR_D[i]=SR_D[i-1]; SR_ID[i]=SR_ID[i-1]; SR_NM[i]=SR_NM[i-1]
    SR_RG[i]=SR_RG[i-1]; SR_CY[i]=SR_CY[i-1]
    SR_LA[i]=SR_LA[i-1]; SR_LO[i]=SR_LO[i-1]; SR_KD[i]=SR_KD[i-1]
    i--
  }
  SR_D[i]=d; SR_ID[i]=id; SR_NM[i]=nm; SR_RG[i]=rg; SR_CY[i]=cy
  SR_LA[i]=la; SR_LO[i]=lo; SR_KD[i]=kind
  return 1
}
#  Nearest k stations to a position, by great-circle distance.
function st_near(file,lat,lon,k,   line,f,d,n){
  SR_N=0
  while((getline line < file) > 0){
    if(substr(line,1,1)=="#") continue
    n=split(line,f,"|")
    if(n<8) continue
    d = st_dist(lat,lon,f[6]+0,f[7]+0)
    st_keep(k,d,f[2],f[3],f[4],f[5],f[6]+0,f[7]+0,f[1])
  }
  close(file)
  return SR_N
}
#  Search by name, case-insensitively, on any part of the name, the
#  region or the country. Results in file order, capped.
function st_search(file,q,k,   line,f,n,hay,cnt){
  SR_N=0; cnt=0
  q=tolower(q)
  while((getline line < file) > 0){
    if(substr(line,1,1)=="#") continue
    n=split(line,f,"|")
    if(n<8) continue
    hay = tolower(f[3] " " f[4] " " f[5])
    if(index(hay,q)==0) continue
    cnt++
    if(SR_N<k){
      SR_N++
      SR_D[SR_N]=0; SR_ID[SR_N]=f[2]; SR_NM[SR_N]=f[3]; SR_RG[SR_N]=f[4]
      SR_CY[SR_N]=f[5]; SR_LA[SR_N]=f[6]+0; SR_LO[SR_N]=f[7]+0; SR_KD[SR_N]=f[1]
    }
  }
  close(file)
  SR_TOTAL=cnt
  return SR_N
}

# =====================================================================
#  High and low water.
#
#  Scan on a five-minute grid for a sign change in the slope, then fit a
#  parabola through the three points and evaluate the curve at its
#  vertex.  A semi-diurnal tide turns over slowly, so five minutes is
#  ample to bracket a turn and the parabola places it to well under a
#  minute.
# =====================================================================
function tide_hilo(jdA,jdB,   step,t,h0,h1,h2,den,dl,tv,hv){
  HL_N=0
  step = 5.0/1440.0
  h0 = tide_h(jdA-step)
  h1 = tide_h(jdA)
  for(t=jdA; t<=jdB; t+=step){
    h2 = tide_h(t+step)
    if((h1>h0 && h1>=h2) || (h1<h0 && h1<=h2)){
      den = h0 - 2*h1 + h2
      dl  = (den!=0) ? 0.5*(h0-h2)/den : 0
      if(dl>1) dl=1
      if(dl<-1) dl=-1
      tv = t + dl*step
      hv = tide_h(tv)              # the curve itself, not the parabola
      HL_N++
      HL_T[HL_N]=tv; HL_H[HL_N]=hv; HL_K[HL_N]=(h1>h0)?"H":"L"
    }
    h0=h1; h1=h2
  }
  return HL_N
}

# =====================================================================
#  Opening a station.
#
#  A reference station predicts directly.  A subordinate station has no
#  constants of its own: it is a set of corrections to a reference
#  station's high and low waters, which is exactly how a paper tide
#  table works.  So for a subordinate the times and heights of the
#  turns are corrected, and the curve between them is interpolated -
#  there is no honest way to synthesise a continuous curve from offsets.
# =====================================================================
function tide_open(file,id,jdmid,   ok){
  TD_ERR=""
  if(!st_load(file,id)){ TD_ERR="no station with that id"; return 0 }
  TD_KIND=ST_KIND
  TD_ID=ST_ID; TD_NAME=ST_NAME; TD_REGION=ST_REGION; TD_COUNTRY=ST_COUNTRY
  TD_LAT=ST_LAT; TD_LON=ST_LON; TD_TZ=ST_TZ
  if(ST_KIND=="R"){
    TD_DATUM=ST_DATUM; TD_REF=""; TD_REFNAME=""
    tide_prep(jdmid, ST_LAT)
    tide_station_prep()
    return 1
  }
  #  subordinate: keep its own identity, borrow the reference's physics
  TD_REF=SB_REF; TD_TYPE=SB_TYPE
  TD_HHI=SB_HHI; TD_HLO=SB_HLO; TD_THI=SB_THI; TD_TLO=SB_TLO
  if(!st_load(file,SB_REF)){ TD_ERR="its reference station is missing"; return 0 }
  if(ST_KIND!="R"){ TD_ERR="its reference station is not a reference station"; return 0 }
  TD_REFNAME=ST_NAME; TD_DATUM=ST_DATUM
  tide_prep(jdmid, ST_LAT)
  tide_station_prep()
  return 1
}
#  High and low water at the station, whichever kind it is.
function tide_table(jdA,jdB,   i,n,t,h,k,pad){
  if(TD_KIND=="R") return tide_hilo(jdA,jdB)
  #  Work the reference over a wider window, because a time offset can
  #  carry a turn into or out of the day being asked for.
  pad = 0.35
  n = tide_hilo(jdA-pad, jdB+pad)
  TB_N=0
  for(i=1;i<=n;i++){
    k = HL_K[i]
    t = HL_T[i] + ((k=="H") ? TD_THI : TD_TLO)/1440.0
    if(TD_TYPE=="ratio") h = HL_H[i] * ((k=="H") ? TD_HHI : TD_HLO)
    else                 h = HL_H[i] + ((k=="H") ? TD_HHI : TD_HLO)
    if(t<jdA || t>jdB) continue
    TB_N++; TB_T[TB_N]=t; TB_H[TB_N]=h; TB_K[TB_N]=k
  }
  #  hand it back in the same arrays the caller reads
  HL_N=TB_N
  for(i=1;i<=TB_N;i++){ HL_T[i]=TB_T[i]; HL_H[i]=TB_H[i]; HL_K[i]=TB_K[i] }
  return HL_N
}
#  The curve. At a reference station this is the real synthesis; at a
#  subordinate it is a cosine drawn between corrected turning points,
#  which is what a tide table's curve has always been.
function tide_curve_prep(jdA,jdB,   i,n,pad,t,h,k){
  if(TD_KIND=="R"){ CV_OK=1; return 1 }
  pad=0.6
  n = tide_hilo(jdA-pad, jdB+pad)
  CVN=0
  for(i=1;i<=n;i++){
    k = HL_K[i]
    t = HL_T[i] + ((k=="H") ? TD_THI : TD_TLO)/1440.0
    if(TD_TYPE=="ratio") h = HL_H[i] * ((k=="H") ? TD_HHI : TD_HLO)
    else                 h = HL_H[i] + ((k=="H") ? TD_HHI : TD_HLO)
    CVN++; CVT[CVN]=t; CVH[CVN]=h
  }
  CV_OK=(CVN>=2)
  return CV_OK
}
function tide_height(jd,   i,a,b,x){
  if(TD_KIND=="R") return tide_h(jd)
  if(!CV_OK) return 0
  if(jd<=CVT[1]) return CVH[1]
  if(jd>=CVT[CVN]) return CVH[CVN]
  for(i=1;i<CVN;i++) if(jd>=CVT[i] && jd<=CVT[i+1]) break
  a=CVH[i]; b=CVH[i+1]
  x=(jd-CVT[i])/(CVT[i+1]-CVT[i])
  #  half a cosine: the right height and a flat top at each turn
  return (a+b)/2 + (a-b)/2*cos(3.14159265358979*x)
}
