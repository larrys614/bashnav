#  Separator-collision check.  Every one of these tables is packed into a
#  delimited string, so a delimiter appearing INSIDE a field splits it
#  silently: the field is truncated, a nonsense one appears after it, and
#  the last one falls off the end.  That is how encounters 13 and 14 came
#  to show five options with the right answer cut in half - found by a
#  reader, not by any test, because every letter still marked correctly.
BEGIN{
  bad=0
  enc_init()
  for(i=1;i<=NENC;i++){
    split(EC[i],a,"|"); n=split(a[7],O,";")
    if(n!=4){ printf "ENC %d has %d options (want 4): %s\n", i, n, substr(a[2],1,55); bad++ }
    if(a[6] !~ /^[abcd]$/){ printf "ENC %d answer is '%s'\n", i, a[6]; bad++ }
  }
  shp_init()
  for(i=1;i<=NSHP;i++){
    split(SH[i],a,"|"); n=split(a[4],G,";")
    if(n<1||n>3){ printf "SHAPE %d has %d glyphs\n", i, n; bad++ }
  }
  ves_init()
  for(i=1;i<=NVES;i++){
    split(VT[i],a,"|"); n=split(a[4],L,";")
    for(j=1;j<=n;j++){
      m=split(L[j],f,",")
      if(m<5||m>6){ printf "VESSEL %s light %d has %d fields\n", a[1], j, m; bad++ }
    }
  }
  snd_init()
  for(i=1;i<=NSND;i++){
    n=split(SD[i],a,"|")
    if(n!=5){ printf "SOUND %d has %d fields\n", i, n; bad++ }
  }
  #  and the lights quiz options, built the same way at run time
  for(s=1;s<=200;s++){
    qpick_lights(s)
    for(j=1;j<=4;j++){
      split(VT[OPT[j]],a,"|")
      if(a[2]==""){ printf "QLIGHT seed %d option %d is empty\n", s, j; bad++ }
    }
  }
  printf "%d\n", bad
  exit 0
}
