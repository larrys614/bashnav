# =====================================================================
#  colregs -- review.  The claims a test cannot check, put to a person
#  one at a time, with the picture in front of them.
#
#  Nothing here touches the network.  The session is local, the answers
#  are a file in your own home directory, and submitting is a URL the
#  program prints for you to open - so there is no credential in this
#  code to leak and no server for anybody to run.
# =====================================================================

#  Every reviewable claim, in a fixed order, as  key | section | title
function rv_build(   i,j,n,a,L,f,t,m,k,cnt,tmp,x){
  if(RV_READY) return RV_N
  ves_init(); shp_init(); enc_init(); snd_init()
  RV_N=0
  #  encounters first: they say what to DO, so a wrong one is the
  #  most dangerous thing in the program
  for(i=1;i<=NENC;i++){
    split(EC[i],a,"|")
    RV_N++; RV_K[RV_N]=sprintf("enc-%d",i-1); RV_S[RV_N]="enc"
    RV_T[RV_N]=substr(a[2],1,58); RV_I[RV_N]=i
  }
  #  the distinct give-way calls the lights quiz can make
  cnt=0
  for(i=1;i<=NVES;i++){
    split(VT[i],a,"|")
    for(t=0;t<360;t+=45){
      m=motion_of(i,t)
      k = a[2] "\t" motion_text(m) "\t" motion_why(m,i)
      if(k in RVSEEN) continue
      RVSEEN[k]=1; cnt++; MOK[cnt]=k
    }
  }
  #  sorted, so the order does not depend on the order vessels happen
  #  to be listed in
  for(i=2;i<=cnt;i++){ x=MOK[i]; j=i-1
    while(j>=1 && MOK[j]>x){ MOK[j+1]=MOK[j]; j-- }
    MOK[j+1]=x }
  for(i=1;i<=cnt;i++){
    split(MOK[i],a,"\t")
    RV_N++; RV_K[RV_N]=sprintf("mot-%d",i-1); RV_S[RV_N]="mot"
    RV_T[RV_N]=substr(a[1] " -- " a[2],1,58); RV_M[RV_N]=MOK[i]
  }
  for(i=1;i<=NVES;i++){
    split(VT[i],a,"|")
    RV_N++; RV_K[RV_N]=sprintf("lig-%d",i-1); RV_S[RV_N]="lig"
    RV_T[RV_N]=substr(a[2],1,58); RV_I[RV_N]=i
  }
  j=0
  for(i=1;i<=15;i++){
    Q_A=""; les_q("L" i,0)
    if(Q_A=="") continue
    RV_N++; RV_K[RV_N]=sprintf("les-%d",j); RV_S[RV_N]="les"
    RV_T[RV_N]="Lesson L" i; RV_I[RV_N]=i; j++
  }
  for(i=1;i<=NSND;i++){
    split(SD[i],a,"|")
    RV_N++; RV_K[RV_N]=sprintf("snd-%d",i-1); RV_S[RV_N]="snd"
    RV_T[RV_N]=substr(a[3],1,58); RV_I[RV_N]=i
  }
  for(i=1;i<=NSHP;i++){
    split(SH[i],a,"|")
    RV_N++; RV_K[RV_N]=sprintf("shp-%d",i-1); RV_S[RV_N]="shp"
    RV_T[RV_N]=substr(a[2],1,58); RV_I[RV_N]=i
  }
  RV_READY=1
  return RV_N
}
function rv_secname(s){
  if(s=="enc") return "Encounter verdicts - who gives way, and what to do"
  if(s=="mot") return "Give-way calls from her lights"
  if(s=="lig") return "The light tables"
  if(s=="les") return "Rules lesson answers"
  if(s=="snd") return "Sound signals"
  if(s=="shp") return "Day shapes"
  return s
}
function rv_secrule(s){
  if(s=="enc") return "Rules 8 to 19"
  if(s=="mot") return "Rules 12 to 18"
  if(s=="lig") return "Rules 20 to 31 and Annex I"
  if(s=="les") return "the Convention itself"
  if(s=="snd") return "Rules 34 and 35, Annex III"
  if(s=="shp") return "Rules 24 to 30"
  return ""
}
function rv_find(key,   i){ rv_build()
  for(i=1;i<=RV_N;i++) if(RV_K[i]==key) return i
  return 0 }

#  Written as plain ifs rather than nested ternaries split over lines:
#  awk permits a newline after a comma or an operator, but not after the
#  ':' of a conditional. gawk accepts it anyway, mawk does not, and the
#  file then fails to parse at all.
function rv_colour(c){
  if(c=="W") return "white"
  if(c=="R") return "red"
  if(c=="G") return "green"
  if(c=="Y") return "yellow"
  return c
}
function rv_arc(a){
  if(a=="A") return "all-round 360"
  if(a=="M") return "masthead 225"
  if(a=="S") return "starboard side 112.5"
  if(a=="P") return "port side 112.5"
  if(a=="T") return "stern 135"
  if(a=="Y") return "towing 135"
  return a
}

# ---- show one claim, in full ----------------------------------------
function rv_show(key,   i,s,a,n,O,j,idx,parts){
  i=rv_find(key); if(i==0){ print "  no such item: " key; return 1 }
  s=RV_S[i]
  print ""
  printf "  %s\n", cw(sprintf("%s   %s", RV_K[i], rv_secname(s)),C_ACC)
  printf "  %s\n", cwd("check against " rv_secrule(s))
  hr()
  if(s=="enc"){
    idx=RV_I[i]; split(EC[idx],a,"|")
    printf "  You are %s\n", tolower(substr(a[1],9))
    printf "  You see %s.\n", a[2]
    print ""
    n=split(a[7],O,";")
    for(j=1;j<=n;j++) printf "     %s) %s\n", substr("abcd",j,1), O[j]
    print ""
    printf "  %s   %s\n", cw("The program says " toupper(a[6]),C_ACC), a[9]
    printf "  %s\n", a[8]
  }
  else if(s=="mot"){
    split(RV_M[i],a,"\t")
    printf "  Vessel   %s\n", a[1]
    printf "  %s   %s\n", cw("The program says",C_ACC), a[2]
    print ""
    printf "  %s\n", a[3]
  }
  else if(s=="lig"){
    idx=RV_I[i]; split(VT[idx],a,"|")
    G_NOCROP=1
    draw_lights(a[1], 305); gshow()
    printf "  %s\n", cwd("drawn from 305 - use 'colregs light " a[1] " <brg>' for any angle")
    print ""
    printf "  %s   %s.  %s\n", cw(a[2],C_ACC), a[3], a[5]
    if(a[6]!="") printf "  %s %s\n", cw("Watch out:",C_ACC), a[6]
    print ""
    n=split(a[4],O,";")
    for(j=1;j<=n;j++){
      split(O[j],parts,",")
      printf "     %-6s %-22s height %.2f   %+.2f along   %+.2f across\n",
        rv_colour(parts[5]), rv_arc(parts[4]),
        parts[3]+0, parts[1]+0, parts[2]+0
    }
  }
  else if(s=="les"){
    idx=RV_I[i]
    les_q("L" idx,1)
    Q_A=""; les_q("L" idx,0)
    print ""
    printf "  %s   %s\n", cw("The program says " toupper(Q_A),C_ACC), Q_W
    printf "  %s\n", cwd("the lesson body itself is 'colregs lesson L" idx "'")
  }
  else if(s=="snd"){
    idx=RV_I[i]; split(SD[idx],a,"|")
    printf "  %s\n", cw(a[2],C_ACC)
    printf "  %s   %s\n", a[3], a[4]
    print ""
    printf "  %s\n", a[5]
  }
  else if(s=="shp"){
    idx=RV_I[i]; split(SH[idx],a,"|")
    draw_shapes(a[1]); gshow()
    print ""
    printf "  %s   %s\n", cw(a[2],C_ACC), a[3]
    printf "  %s\n", a[5]
  }
  hr()
  return 0
}
# ---- the list, with what has been answered so far -------------------
function rv_list(rfile,   i,line,f,n,done,fl,s,lastsec){
  rv_build()
  while((getline line < rfile) > 0){
    n=split(line,f,"\t"); if(n<2) continue
    ST_[f[1]]=f[2]; if(n>=3) NT_[f[1]]=f[3]
  }
  close(rfile)
  print ""
  printf "  %s\n", cw("REVIEW -- the claims no test can check",C_ACC)
  hr()
  done=0; fl=0
  for(i=1;i<=RV_N;i++){
    if(RV_S[i]!=lastsec){
      lastsec=RV_S[i]
      printf "\n  %s   %s\n", cw(rv_secname(lastsec),C_ACC), cwd(rv_secrule(lastsec))
    }
    s = (RV_K[i] in ST_) ? ST_[RV_K[i]] : ""
    if(s=="ok") done++
    if(s=="flag"){ done++; fl++ }
    printf "   [%s] %-8s %s\n",
      (s=="ok"?"x":(s=="flag"?cw("!",C_ACC):" ")), RV_K[i], RV_T[i]
  }
  hr()
  printf "  %d of %d looked at, %s flagged.\n", done, RV_N, (fl?cw(fl "",C_ACC):"0")
  print ""
  return 0
}
function rv_next(rfile,   i,line,f,n){
  rv_build()
  while((getline line < rfile) > 0){
    n=split(line,f,"\t"); if(n<2) continue
    ST_[f[1]]=f[2]
  }
  close(rfile)
  for(i=1;i<=RV_N;i++) if(!(RV_K[i] in ST_)){ print RV_K[i]; return 0 }
  print ""
  return 0
}

function rv_keys(sec,   i){
  rv_build()
  for(i=1;i<=RV_N;i++) if(sec=="" || RV_S[i]==sec) print RV_K[i]
  return 0
}

# ---- the report ------------------------------------------------------
function rv_load(rfile,   line,f,n){
  while((getline line < rfile) > 0){
    n=split(line,f,"\t"); if(n<2) continue
    ST_[f[1]]=f[2]; NT_[f[1]] = (n>=3) ? f[3] : ""
  }
  close(rfile)
  return 0
}
#  What the program claims for one item, in one line, so an issue can be
#  acted on without anybody having to go and look it up.
function rv_claim(i,   s,a,idx){
  s=RV_S[i]; idx=RV_I[i]
  if(s=="enc"){ split(EC[idx],a,"|")
    return "\"" a[2] "\" -- program says " toupper(a[6]) " (" a[9] ")" }
  if(s=="mot"){ split(RV_M[i],a,"\t")
    return a[1] " -- program says: " a[2] }
  if(s=="lig"){ split(VT[idx],a,"|")
    return a[2] " (" a[3] ") -- " a[5] }
  if(s=="les"){ Q_A=""; les_q("L" idx,0)
    return "Lesson L" idx " -- program says " toupper(Q_A) }
  if(s=="snd"){ split(SD[idx],a,"|")
    return a[2] " = " a[3] " (" a[4] ")" }
  if(s=="shp"){ split(SH[idx],a,"|")
    return a[2] " (" a[3] ") -- " a[4] }
  return RV_T[i]
}
function rv_report(rfile,   i,nf,nn,nok,body,lastsec){
  rv_build(); rv_load(rfile)
  nf=0; nn=0; nok=0
  for(i=1;i<=RV_N;i++){
    if(!(RV_K[i] in ST_)) continue
    if(ST_[RV_K[i]]=="flag") nf++
    else { nok++; if(NT_[RV_K[i]]!="") nn++ }
  }
  print "### colregs review"
  print ""
  printf "colregs %s. %d of %d claims looked at: %d flagged as wrong or misleading, %d marked correct.\n",
     rvver, nf+nok, RV_N, nf, nok
  if(rvwho!="") printf "\nReviewer: %s\n", rvwho
  if(rvdrill!="") printf "\nDrill record: %s\n", rvdrill
  if(rvcredit=="yes" && rvwho!="") print "\nHappy to be credited."
  else if(rvcredit=="no") print "\nPlease do not credit me."
  if(nf>0){
    print ""
    print "### Flagged"
    print ""
    for(i=1;i<=RV_N;i++){
      if(!(RV_K[i] in ST_) || ST_[RV_K[i]]!="flag") continue
      printf "- **%s** %s  \n", RV_K[i], rv_claim(i)
      if(NT_[RV_K[i]]!="") printf "  > %s\n", NT_[RV_K[i]]
      else print "  > (no note given)"
    }
  }
  if(nn>0){
    print ""
    print "### Notes on claims marked correct"
    print ""
    for(i=1;i<=RV_N;i++){
      if(!(RV_K[i] in ST_) || ST_[RV_K[i]]=="flag" || NT_[RV_K[i]]=="") continue
      printf "- **%s** %s  \n", RV_K[i], rv_claim(i)
      printf "  > %s\n", NT_[RV_K[i]]
    }
  }
  if(nf==0 && nn==0){
    print ""
    printf "Nothing flagged. %d claims checked and found correct.\n", nok
  }
  print ""
  print "---"
  print "Sent from `colregs review`. The tool never touched the network -"
  print "this issue was opened by hand from a link it printed."
  return 0
}
# ---- percent-encoding, for the issue link ---------------------------
function rv_hexinit(   i){
  if(HEXR) return
  for(i=0;i<256;i++) ORD_[sprintf("%c",i)]=i
  HEXR=1
}
function rv_enc(s,   i,c,o,n){
  rv_hexinit()
  o=""
  for(i=1;i<=length(s);i++){
    c=substr(s,i,1)
    if(c ~ /[A-Za-z0-9._~-]/) o=o c
    else { n=ORD_[c]; if(n=="") n=63; o=o sprintf("%%%02X", n) }
  }
  return o
}
function rv_url(rfile,   line,body,t,i,nf){
  rv_build(); rv_load(rfile)
  nf=0
  for(i=1;i<=RV_N;i++) if((RV_K[i] in ST_) && ST_[RV_K[i]]=="flag") nf++
  body=""
  while((getline line < rbody) > 0) body = body line "\n"
  close(rbody)
  t = sprintf("colregs review: %d flagged", nf)
  #  No labels= parameter. A label that does not exist in the repository
  #  is one more thing that has to have been set up correctly before a
  #  stranger's careful review will go anywhere, and the title already
  #  says what this is. Maintainers can label it themselves.
  printf "https://github.com/%s/bashnav/issues/new?title=%s&body=%s\n",
     (rvrepo!=""?rvrepo:"larrys614"), rv_enc(t), rv_enc(body)
  return 0
}
