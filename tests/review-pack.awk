#  Dumps every factual claim that a machine cannot check, in a form a
#  person with the Convention open can tick or cross.  Generated from
#  the same tables the program runs on, so it cannot drift from the code.
function jesc(s){ gsub(/\\/,"\\\\",s); gsub(/"/,"\\\"",s); gsub(/\n/," ",s); return s }
BEGIN{
  ves_init(); shp_init(); enc_init(); snd_init()
  print "{"
  # ---- A: the light tables -----------------------------------------
  print "\"lights\":["
  for(i=1;i<=NVES;i++){
    split(VT[i],a,"|")
    n=split(a[4],L,";"); desc=""
    for(j=1;j<=n;j++){
      split(L[j],f,",")
      arc = (f[4]=="A")?"all-round 360":((f[4]=="M")?"masthead 225":((f[4]=="S")?"starboard side 112.5":\
            ((f[4]=="P")?"port side 112.5":((f[4]=="T")?"stern 135":"towing 135"))))
      col = (f[5]=="W")?"white":((f[5]=="R")?"red":((f[5]=="G")?"green":"yellow"))
      desc = desc sprintf("%s%s %s, height %.2f, %+.2f along the hull, %+.2f across",
             (j>1?" | ":""), col, arc, f[3]+0, f[1]+0, f[2]+0)
    }
    printf "%s{\"key\":\"%s\",\"name\":\"%s\",\"rule\":\"%s\",\"lights\":\"%s\",\"note\":\"%s\",\"trap\":\"%s\"}\n",
      (i>1?",":""), jesc(a[1]), jesc(a[2]), jesc(a[3]), jesc(desc), jesc(a[5]), jesc(a[6])
  }
  print "],"
  # ---- B: what each sidelight tells you to DO ------------------------
  print "\"motion\":["
  k=0
  for(i=1;i<=NVES;i++){
    split(VT[i],a,"|")
    for(t=0;t<360;t+=45){
      m = motion_of(i,t)
      printf "%s{\"name\":\"%s\",\"brg\":%d,\"call\":\"%s\",\"why\":\"%s\"}\n",
        (k>0?",":""), jesc(a[2]), t, jesc(motion_text(m)), jesc(motion_why(m,i))
      k++
    }
  }
  print "],"
  # ---- C: the encounters, and the verdict each one asserts ----------
  print "\"encounters\":["
  for(i=1;i<=NENC;i++){
    enc_pick(i); split(EC[i],a,"|")
    n=split(a[7],O,";")
    opts=""
    for(j=1;j<=n;j++) opts = opts sprintf("%s%s) %s", (j>1?"  ":""), substr("abcd",j,1), O[j])
    printf "%s{\"n\":%d,\"you\":\"%s\",\"see\":\"%s\",\"opts\":\"%s\",\"ans\":\"%s\",\"why\":\"%s\",\"rule\":\"%s\"}\n",
      (i>1?",":""), i, jesc(a[1]), jesc(a[2]), jesc(opts),
      jesc(toupper(ENC_ANS)), jesc(ENC_WHY), jesc(ENC_RULE)
  }
  print "],"
  # ---- D: day shapes -------------------------------------------------
  print "\"shapes\":["
  for(i=1;i<=NSHP;i++){
    split(SH[i],a,"|")
    printf "%s{\"name\":\"%s\",\"rule\":\"%s\",\"stack\":\"%s\",\"note\":\"%s\"}\n",
      (i>1?",":""), jesc(a[2]), jesc(a[3]), jesc(a[4]), jesc(a[5])
  }
  print "],"
  # ---- E: sound signals ----------------------------------------------
  print "\"sound\":["
  for(i=1;i<=NSND;i++){
    split(SD[i],a,"|")
    printf "%s{\"pattern\":\"%s\",\"means\":\"%s\",\"rule\":\"%s\",\"note\":\"%s\"}\n",
      (i>1?",":""), jesc(a[2]), jesc(a[3]), jesc(a[4]), jesc(a[5])
  }
  print "],"
  # ---- F: the question at the end of each rules lesson --------------
  print "\"lessons\":["
  k=0
  split("L1 L2 L3 L4 L5 L6 L7 L8 L9 L10 L11 L12 L13 L14 L15",LL," ")
  for(i=1;i<=15;i++){
    Q_A=""; Q_W=""; QT=""
    les_q(LL[i],0)
    if(Q_A=="") continue
    printf "%s{\"id\":\"%s\",\"ans\":\"%s\",\"why\":\"%s\"}\n",
      (k>0?",":""), LL[i], jesc(toupper(Q_A)), jesc(Q_W)
    k++
  }
  print "]}"
  exit 0
}
