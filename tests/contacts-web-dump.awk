#  The awk side of the contacts port diff. Same shape as
#  colregs-web-dump.awk: print every function's answer over its whole
#  useful input range, so the JS can be compared line for line rather
#  than read.
BEGIN{
  for(i=-360;i<=720;i+=7) printf "nrm360\t%d\t%.9f\n", i, nrm360(i)
  for(i=-360;i<=720;i+=7) printf "sgn180\t%d\t%.9f\n", i, sgn180(i)
  for(y=-5;y<=5;y++) for(x=-5;x<=5;x++){
    if(x==0&&y==0) continue
    printf "rbrg\t%d\t%d\t%.9f\n", x, y, rbrg(x,y) }
  printf "ktym\t%.9f\n", ktym()
  #  the generator, which is the real test: a Park-Miller sequence that
  #  disagrees by one step diverges completely and visibly
  for(s=1;s<=40;s++){
    xsrand(s)
    for(i=0;i<6;i++) printf "xrand\t%d\t%d\t%.12f\n", s, i, xrand()
  }
  for(v=1;v<=2000000;v*=7) printf "ctyd\t%d\t%s\n", v, ct_yd(v)
  for(sp=4;sp<=20;sp+=4) for(co=0;co<360;co+=30) for(bg=0;bg<360;bg+=45)
    printf "ekacross\t%d\t%d\t%d\t%.9f\n", sp, co, bg, ek_across(sp,co,bg)
  for(s=1;s<=60;s++){
    if(ek_gen(s))
      printf "ekgen\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%.6f\t%.6f\t%.1f\t%.1f\t%.6f\t%d\n",
        s, EK_R, EK_TB, EK_CC, EK_CS, EK_C1, EK_S1, EK_C2, EK_A1, EK_A2,
        EK_R1, EK_R2, EK_EST, EK_BAND
    else printf "ekgen\t%d\tnone\n", s
  }
  for(s=1;s<=60;s++){
    if(ct_gen(s))
      printf "ctgen\t%d\t%d\t%d\t%.6f\t%d\t%d\t%d\t%.6f\t%.6f\t%.6f\t%.6f\t%.6f\t%.6f\t%s\t%d\t%d\n",
        s, CG_OC, CG_OS, CG_TB, CG_R0, CG_CC, CG_CS,
        CG_PX, CG_PY, CG_VX, CG_VY, CG_TC, CG_CPA, CG_DRIFT, CG_BAND, CG_AHEAD
    else printf "ctgen\t%d\tnone\n", s
  }
  #  the observations and the CPA, for the seeds that generated
  for(s=1;s<=20;s++){
    if(!ct_gen(s)) continue
    for(i=0;i<5;i++)
      printf "ctobs\t%d\t%d\t%.6f\t%.6f\n", s, i, ct_brg(i), ct_rng(i)
  }
}
