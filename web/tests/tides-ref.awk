#  Reference dump: the awk engine's own numbers, for the JS port to be
#  diffed against.  One value per line, so that there is no printf
#  argument-count to get wrong -- the surplus-argument trap has cost this
#  project two debugging rounds already, and CONVFMT silently rounds a
#  number that lands on %s to six significant figures.
BEGIN{
  #  The id list is read from a file, not from -v: mawk mangles a -v
  #  assignment a few kilobytes long and then reports a syntax error in
  #  an unrelated source file, which is a confusing way to lose an hour.
  nid = 0
  while((getline line < IDFILE) > 0) if(line!="") ids[++nid] = line
  close(IDFILE)
  nda = split(DATES, das, ",")
  for(a=1;a<=nid;a++){
    for(b=1;b<=nda;b++){
      split(das[b], ymd, "-")
      jd0  = jdate(ymd[1]+0, ymd[2]+0, ymd[3]+0)   # 00:00 UT that day
      jdmid = jd0 + 0.5
      if(!tide_open(FILE, ids[a], jdmid)){
        printf "ERR\t%s\t%s\t%s\n", ids[a], das[b], TD_ERR
        continue
      }
      key = ids[a] "\t" das[b]
      printf "ST\t%s\t%s\t%s\n", key, TD_KIND, TD_DATUM
      printf "LAT\t%s\t%.17e\n", key, TD_LAT
      printf "N\t%s\t%d\n", key, ST_N
      #  the per-constituent machinery, for the constituents this station uses
      for(i=1;i<=ST_N;i++){
        c = ST_C[i]
        printf "C\t%s\t%d\t%d\n", key, i, c
        printf "CF\t%s\t%d\t%.17e\n", key, i, CF_[c]
        printf "CU\t%s\t%d\t%.17e\n", key, i, CU_[c]
        printf "CV\t%s\t%d\t%.17e\n", key, i, CV_[c]
        printf "CW\t%s\t%d\t%.17e\n", key, i, CW_[c]
        printf "AMP\t%s\t%d\t%.17e\n", key, i, ST_F[i]
        printf "PHA\t%s\t%d\t%.17e\n", key, i, ST_P[i]
      }
      #  the curve, every 13 minutes across the day: a step that is not a
      #  divisor of anything, so it cannot accidentally sample only the
      #  points where two different wrong answers agree
      tide_curve_prep(jd0, jd0+1)
      for(k=0;k<=110;k++){
        t = jd0 + k*13.0/1440.0
        printf "H\t%s\t%d\t%.17e\n", key, k, tide_height(t)
      }
      #  the sun and moon panel
      moon_phase(jdmid)
      printf "MPE\t%s\t%.17e\n", key, MP_ELONG
      printf "MPA\t%s\t%.17e\n", key, MP_AGE
      printf "MPI\t%s\t%.17e\n", key, MP_ILLUM
      printf "MPN\t%s\t%s\n",    key, MP_NAME
      printf "MPT\t%s\t%s\n",    key, MP_TIDE
      rise_set(jd0, TD_LAT, TD_LON, "sun", -0.833)
      printf "SR\t%s\t%.17e\n", key, (RS_RISE=="") ? -1 : RS_RISE-jd0
      printf "SS\t%s\t%.17e\n", key, (RS_SET =="") ? -1 : RS_SET -jd0
      rise_set(jd0, TD_LAT, TD_LON, "moon", -0.833)
      printf "MR\t%s\t%.17e\n", key, (RS_RISE=="") ? -1 : RS_RISE-jd0
      printf "MS\t%s\t%.17e\n", key, (RS_SET =="") ? -1 : RS_SET -jd0
      rise_set(jd0, TD_LAT, TD_LON, "sun", -6)
      printf "CT\t%s\t%.17e\n", key, (RS_RISE=="") ? -1 : RS_RISE-jd0
      #  and the altitudes themselves, every 97 minutes
      for(k=0;k<=14;k++){
        t = jd0 + k*97.0/1440.0
        printf "ALS\t%s\t%d\t%.17e\n", key, k, alt_of("sun",  t, TD_LAT, TD_LON)
        printf "ALM\t%s\t%d\t%.17e\n", key, k, alt_of("moon", t, TD_LAT, TD_LON)
      }
      #  and the turns
      n = tide_table(jd0, jd0+1)
      printf "HLN\t%s\t%d\n", key, n
      for(i=1;i<=n;i++){
        printf "HLT\t%s\t%d\t%.17e\n", key, i, HL_T[i]-jd0
        printf "HLH\t%s\t%d\t%.17e\n", key, i, HL_H[i]
        printf "HLK\t%s\t%d\t%s\n",    key, i, HL_K[i]
      }
    }
  }
}
