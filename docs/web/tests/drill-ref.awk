#  The drill generator's own state, for a sweep of seeds.
#
#  A SEED IS THE PROBLEM'S NAME. "drill red 4821" has to be the same sight
#  in the shell and in the browser, or the two are not the same study
#  machine - a navigator working a drill on an iPad and checking it at a
#  terminal would get two different right answers. So the generator is
#  part of the specification, down to the pseudo-random sequence, and this
#  dumps every value it produces so docs/web/tests/drill-check.js can hold
#  the port to it.
#
#  Seeds that fail are dumped too, as a GENFAIL line: eighty tries without
#  a body between 12 and 72 degrees is a real outcome for an unlucky seed,
#  and a port that quietly produced a problem there would disagree about
#  which seeds are usable.
#
#    awk -v N=400 -f engine.awk -f teach.awk -f drill-ref.awk
BEGIN{
  star_init()
  n = (N+0 ? N+0 : 200)
  for(sd=1; sd<=n; sd++){
    if(drill_gen("full", sd)){
      printf "GEN\t%d\t%.17g\t%.17g\t%.17g\t%.17g\t%d\t%d\t%s\t%s\t%s\t%.17g\t%.17g\t%.17g\t%.17g\t%.17g\t%.17g\t%.17g\t%.17g\t%.17g\n",
        sd, D_LAT, D_LON, D_IE, D_HE, D_T, D_P, D_BODY, D_NAME, D_LIMB,
        D_JD, D_GHA, D_DEC, D_SD, D_HP, D_HC, D_ZN, D_OFF, D_HS
      printf "GENU\t%d\t%s\n", sd, D_UTC
    } else {
      printf "GENFAIL\t%d\n", sd
    }
    fix_gen(sd)
    printf "FIXG\t%d\t%.17g\t%.17g\t%.17g\t%.17g\t%.17g\t%.17g\n",
      sd, D_LAT, D_LON, FX_LAT, FX_LON, SOL_N, SOL_E
    for(i=1;i<=3;i++)
      printf "FIXL\t%d\t%d\t%.17g\t%.17g\t%s\n", sd, i, FX_Z[i], FX_P[i], FX_N[i]
  }
}
