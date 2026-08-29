#  Checks for the contacts section, driven by -v what=...
#  Loaded after engine.awk and contacts.awk.
BEGIN{
  if(what=="mark"){
    n=0
    for(s=1;s<=60;s++){ if(!ct_gen(s)) continue; n++
      ct_trackm(s, ct_ans1(), ct_ans2(), ct_ans3()) }
    printf "SEEDS %d\n", n
  }
  else if(what=="markwrong"){
    for(s=1;s<=20;s++){ if(!ct_gen(s)) continue
      ct_trackm(s, (ct_ans1()=="a")?"b":"a",
                   (ct_ans2()=="a")?"b":"a",
                   (ct_ans3()=="a")?"b":"a") }
  }
  else if(what=="drift"){
    #  The claim the whole section rests on: a bearing drawing away from
    #  your bow can never cross ahead of you.
    bad=0; n=0
    for(s=1;s<=400;s++){
      if(!ct_gen(s)) continue
      n++
      rb = sgn180(CG_TB - CG_OC)
      toward = ((rb<0 && CG_DRIFT=="right") || (rb>0 && CG_DRIFT=="left"))
      if(CG_DRIFT=="steady"){ if(CG_AHEAD>=0) bad++; continue }
      if(toward  && CG_AHEAD!=1) bad++
      if(!toward && CG_AHEAD!=0) bad++ }
    printf "%d %d\n", n, bad
  }
  else if(what=="ekelund"){
    n=0; worst=0
    for(s=1;s<=300;s++){
      if(!ek_gen(s)) continue
      n++
      e = 1909.86*(EK_A2-EK_A1)/(EK_R1-EK_R2); if(e<0) e=-e
      d = (e-EK_R)/EK_R; if(d<0) d=-d
      if(d>worst) worst=d }
    printf "%d %.4f\n", n, worst
  }
  else if(what=="relbrg"){
    #  Red/Green must agree with the words, and both must agree with the
    #  side she is actually on. One vocabulary, no drift between them.
    bad=0
    for(r=-179;r<=180;r++){
      rg = red_green(r); ph = rel_phrase(r,"your")
      #  The number is precise and the words are deliberately coarse:
      #  "Red 3" and "right ahead" are the same bearing, said to
      #  different tolerances. So only require a side word when the
      #  phrase names a side at all - but when it does, it must be right.
      if(r<-0.5 && r>-179.5 && rg !~ /^Red /)   bad++
      if(r> 0.5 && r< 179.5 && rg !~ /^Green /) bad++
      if(ph ~ /port/      && r>=0) bad++
      if(ph ~ /starboard/ && r<=0) bad++
      n = rg; sub(/^(Red|Green) /,"",n)
      if(rg ~ /^(Red|Green) /){ d=(r<0)?-r:r; if(n+0 != int(d+0.5)) bad++ }
    }
    #  and the classic points must land on the classic words
    if(rel_phrase(45,"your")  != "broad on your starboard bow")     bad++
    if(rel_phrase(-45,"your") != "broad on your port bow")          bad++
    if(rel_phrase(90,"your")  != "on your starboard beam")          bad++
    if(rel_phrase(135,"your") != "broad on your starboard quarter") bad++
    if(rel_phrase(0,"your")   != "right ahead")                     bad++
    if(rel_phrase(180,"your") != "right astern")                    bad++
    if(red_green(-20) != "Red 20")   bad++
    if(red_green(30)  != "Green 30") bad++
    printf "%d\n", bad
  }
  exit 0
}
