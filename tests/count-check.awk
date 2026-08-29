#  The counts the about section quotes, computed from the code itself.
BEGIN{
  ves_init(); enc_init()
  if(what=="vessels")    { print NVES; exit 0 }
  if(what=="encounters") { print NENC; exit 0 }
  if(what=="motion"){
    n=0
    for(i=1;i<=NVES;i++){ split(VT[i],a,"|")
      for(t=0;t<360;t+=45){
        m=motion_of(i,t)
        k = a[2] "|" motion_text(m) "|" motion_why(m,i)
        if(!(k in S)){ S[k]=1; n++ } } }
    print n; exit 0 }
  print "?"; exit 1
}
