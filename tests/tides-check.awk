#  Compare the program's high and low water against NOAA's own published
#  predictions. Not against another implementation of the same theory -
#  against the numbers a mariner would actually read.
function hm2day(s,   a){ split(s,a,":"); return (a[1]+a[2]/60.0)/24.0 }
BEGIN{
  FS="|"
  worstT=0; worstH=0; nT=0; sT=0; sH=0; n=0; miss=0
  while((getline line < REF) > 0){
    if(substr(line,1,1)=="#" || line=="") continue
    nf=split(line,f,"|")
    if(nf<3) continue
    split(f[2],d,"-")
    jd0 = jdate(d[1]+0, d[2]+0, d[3]+0)
    if(!tide_open(SF, f[1], jd0+0.5)){ printf "  %s: %s\n", f[1], TD_ERR; miss++; continue }
    m = tide_table(jd0, jd0+1)
    ne = split(f[3], E, " ")
    printf "  %-28s %s\n", substr(TD_NAME,1,28), f[2]
    for(i=1;i<=ne;i++){
      split(E[i], g, ",")
      want_t = jd0 + hm2day(g[1]); want_h = g[2]+0; want_k = g[3]
      #  match on kind and nearest time
      best=0; bd=9
      for(j=1;j<=m;j++){
        if(HL_K[j]!=want_k) continue
        dd = HL_T[j]-want_t; if(dd<0) dd=-dd
        if(dd<bd){ bd=dd; best=j }
      }
      if(best==0){ printf "    %s %s  NOT FOUND\n", want_k, g[1]; miss++; continue }
      dt = (HL_T[best]-want_t)*1440.0
      dh = HL_H[best]-want_h
      adt=(dt<0)?-dt:dt; adh=(dh<0)?-dh:dh
      if(adt>worstT) worstT=adt
      if(adh>worstH) worstH=adh
      sT+=adt; sH+=adh; n++
      printf "    %s  NOAA %s %6.3f    mine %6.3f   %+5.1f min  %+.3f m\n",
        want_k, g[1], want_h, HL_H[best], dt, dh
    }
  }
  close(REF)
  printf "\n  %d turns compared.  mean |dt| %.1f min, worst %.1f.  mean |dh| %.3f m, worst %.3f.  missing %d\n",
     n, sT/n, worstT, sH/n, worstH, miss
  printf "RESULT %d %.1f %.3f %d\n", n, worstT, worstH, miss
}
