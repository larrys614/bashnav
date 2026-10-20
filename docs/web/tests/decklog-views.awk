#  Generate a log with awk's own writer, derive the views with awk's own
#  code, and dump both so the JS port can be held to them.  The log is
#  generated rather than typed so the sequences are ones nobody thought
#  to test: a use before any stocktake, a restock of a part never seen,
#  a stocktake that corrects drift downwards, a defect closed by a job
#  logged earlier in the file than the finding.
function rnd(n){ return int(rand()*n) }
BEGIN{
  srand(SEED+0)
  PARTS = "impeller oilfilter belt anode fuelsec oil"
  NP = split(PARTS, P, " ")
  EQS = "eng.main gen.onan wm.spectra"
  NE = split(EQS, E, " ")
  ITEMS = "belts anodes hx impeller strainer mounts"
  NI = split(ITEMS, IT, " ")

  n = 0
  for(d=1; d<=DAYS+0; d++){
    for(h=0; h<24; h+=3){
      #  28-day months and 12 of them, so the dates stay valid however
      #  many days are asked for.  An earlier version let the month run
      #  past 12 and produced "2026-447-01T00:00Z", which is 18
      #  characters and which BOTH readers correctly rejected -- so the
      #  diff still passed while three quarters of the corpus was being
      #  thrown away by both sides.
      yy = 2026 + int((d-1)/336)
      mo = 1 + int(((d-1)%336)/28)
      dd = 1 + ((d-1)%28)
      ts = sprintf("%04d-%02d-%02dT%02d:00Z", yy, mo, dd, h)
      roll = rnd(100)
      if(roll < 18){
        #  a stocktake
        k[1]="part"; v[1]=P[rnd(NP)+1]
        k[2]="count"; v[2]=rnd(6)
        k[3]="action"; v[3]="stocktake"
        print lg_make(ts,"inv",k,v,3) > LOGFILE
        n++
      } else if(roll < 30){
        k[1]="part"; v[1]=P[rnd(NP)+1]
        k[2]="qty"; v[2]=1+rnd(3)
        k[3]="action"; v[3]="restock"
        print lg_make(ts,"inv",k,v,3) > LOGFILE
        n++
      } else if(roll < 52){
        #  a job: consumes a part, and sometimes closes a defect
        k[1]="job";  v[1]=IT[rnd(NI)+1]
        k[2]="part"; v[2]=P[rnd(NP)+1]
        k[3]="qty";  v[3]=1+rnd(2)
        k[4]="hrs";  v[4]=sprintf("%.1f", 1000+d*3.5+h/3)
        k[5]="eq";   v[5]=E[rnd(NE)+1]
        nf=5
        if(OPEN_N>0 && rnd(100)<35){
          j = rnd(OPEN_N)+1
          k[6]="closes"; v[6]=OPEN[j]; nf=6
          #  mark it closed in our own bookkeeping too
          OPEN[j]=OPEN[OPEN_N]; OPEN_N--
        }
        print lg_make(ts,"eng",k,v,nf) > LOGFILE
        n++
      } else if(roll < 68){
        #  an inspection item, sometimes a finding
        k[1]="insp"; v[1]=IT[rnd(NI)+1]
        st = rnd(100)
        k[2]="state"; v[2]= (st<55) ? "o" : (st<80) ? "a" : (st<90) ? "-" : "/"
        k[3]="eq";   v[3]=E[rnd(NE)+1]
        k[4]="note"; v[4]= (v[2]=="a") ? "glazed, slight squeal|at start" : ""
        print lg_make(ts,"eng",k,v,4) > LOGFILE
        if(v[2]=="a"){ OPEN_N++; OPEN[OPEN_N]=ts }
        n++
      } else if(roll < 80){
        #  provisions consume too
        k[1]="part"; v[1]=P[rnd(NP)+1]
        k[2]="qty";  v[2]=1+rnd(2)
        print lg_make(ts,"pro",k,v,2) > LOGFILE
        n++
      } else if(roll < 92){
        #  a core entry, which must not touch any holding
        k[1]="lat"; v[1]=sprintf("%.3f", 41+rnd(100)/100)
        k[2]="lon"; v[2]=sprintf("%.3f", -72-rnd(100)/100)
        k[3]="crs"; v[3]=sprintf("%03d", rnd(360))
        k[4]="sog"; v[4]=sprintf("%.1f", rnd(90)/10)
        print lg_make(ts,"nav",k,v,4) > LOGFILE
        n++
      } else {
        #  and a record of a type this version does not know, which a
        #  reader must step over without complaint
        k[1]="zz"; v[1]="future"
        k[2]="part"; v[2]=P[rnd(NP)+1]
        print lg_make(ts,"xyz",k,v,2) > LOGFILE
        n++
      }
    }
  }
  close(LOGFILE)
  printf "RECORDS\t%d\n", n

  inv_build(LOGFILE)
  for(p in HOLD) printf "HOLD\t%s\t%d\n", p, HOLD[p]

  m = def_build(LOGFILE)
  printf "DEFN\t%d\n", m
  for(i=1;i<=m;i++) printf "DEF\t%d\t%s\t%s\t%s\n", i, DEF_TS[i], DEF_EQ[i], DEF_ITEM[i]
}
