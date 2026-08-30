#  Date arithmetic written from memory is a reliable way to be
#  confidently wrong: the first version of sc_validtime returned the
#  year 4600 for a date in 2026, and it looked fine until printed.
#  So: round-trip every day for forty years.
BEGIN{
  bad=0; n=0
  jd0 = sc_jdn(2000,1,1); jd1 = sc_jdn(2040,1,1)
  for(jd=jd0; jd<=jd1; jd++){
    sc_civil(jd)
    if(sc_jdn(SC_Y, SC_M, SC_D) != jd){
      if(bad<3) printf "  FAIL jd %d -> %04d-%02d-%02d -> %d\n", jd, SC_Y, SC_M, SC_D, sc_jdn(SC_Y,SC_M,SC_D)
      bad++
    }
    if(SC_M<1 || SC_M>12 || SC_D<1 || SC_D>31 || SC_Y<1999 || SC_Y>2041) bad++
    n++
  }
  printf "  %d days round-tripped\n", n
  #  and the valid time must land on a synoptic hour, always
  split("2026-08-30T18:00Z 2026-12-31T23:00Z 2028-02-28T22:00Z 2026-01-01T00:00Z", T, " ")
  for(i=1;i<=4;i++) for(h=1;h<=48;h++){
    v = sc_validtime(T[i], h)
    hh = substr(v,12,2)+0
    if(hh%3 != 0){ if(bad<6) printf "  FAIL %s +%dh -> %s, not a synoptic hour\n", T[i], h, v; bad++ }
    if(v !~ /^20[0-9][0-9]-[0-1][0-9]-[0-3][0-9]T[0-2][0-9]:00Z$/){
      if(bad<6) printf "  FAIL %s +%dh -> %s, not a valid timestamp\n", T[i], h, v; bad++ }
    if(wx_mins(v) <= wx_mins(T[i])){ if(bad<6) printf "  FAIL %s +%dh -> %s is not in the future\n", T[i], h, v; bad++ }
  }
  printf "DATERESULT %d\n", bad
}
