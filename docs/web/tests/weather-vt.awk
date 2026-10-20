#  Only REAL dates.  An earlier version looped d=1..31 in every month
#  and reported 276 round-trip failures -- which is exactly the number of
#  impossible dates in 2000..2040 (31 February and the 31st of the
#  thirty-day months). sc_jdn of 31 February is a perfectly good day
#  number and sc_civil correctly maps it back to 3 March, so the
#  "failure" was the generator's.
function mdays(y,mo){
  if(mo==2) return ((y%4==0 && y%100!=0) || y%400==0) ? 29 : 28
  if(mo==4 || mo==6 || mo==9 || mo==11) return 30
  return 31
}
BEGIN{
  for(y=2000;y<=2040;y++) for(mo=1;mo<=12;mo++) for(d=1;d<=mdays(y,mo);d++){
    jd = sc_jdn(y,mo,d); sc_civil(jd)
    if(SC_Y!=y || SC_M!=mo || SC_D!=d){ printf "RT\t%04d-%02d-%02d\t%04d-%02d-%02d\n", y,mo,d,SC_Y,SC_M,SC_D > OUTF; bad++ }
    for(hh=0;hh<24;hh+=1) for(ha=6;ha<=24;ha+=6)
      printf "VT\t%04d-%02d-%02dT%02d:00Z\t%d\t%s\n", y,mo,d,hh,ha, sc_validtime(sprintf("%04d-%02d-%02dT%02d:00Z",y,mo,d,hh), ha) > OUTF
  }
  printf "RTBAD\t%d\n", bad+0 > OUTF
}
