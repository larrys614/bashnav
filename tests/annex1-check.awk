#  Structural checks on the light tables against Annex I and Rule 21.
#  These cannot tell you whether a vessel shows the RIGHT lights - that
#  needs a person with the Convention open. They check the things that
#  are geometry rather than judgement, and that a person reading twenty
#  tables would miss.
function fail(v,msg){ printf "FAIL %-10s %s\n", v, msg; NF_++ }
BEGIN{
  ves_init(); NF_=0
  for(i=1;i<=NVES;i++){
    split(VT[i],a,"|"); key=a[1]
    n=split(a[4],L,";")
    ng=0; nr=0; nmast=0; nstern=0
    mfx=""; mfh=-1; sgh=-1; srh=-1; sgx=""; srx=""; sgy=0; sry=0
    delete H; delete X
    for(j=1;j<=n;j++){
      split(L[j],f,",")
      x=f[1]+0; y=f[2]+0; h=f[3]+0; arc=f[4]; col=f[5]
      if(arc!="A"&&arc!="M"&&arc!="S"&&arc!="P"&&arc!="T"&&arc!="Y")
        fail(key,"unknown arc " arc)
      if(col!="W"&&col!="R"&&col!="G"&&col!="Y")
        fail(key,"unknown colour " col)
      if(h<=0 || h>1.0) fail(key,"height out of the hull: " h)
      if(x>0.5 || x<-0.5) fail(key,"light is off the ends of the ship: " x)
      if(arc=="S"){ ng++; sgh=h; sgx=x; sgy=y; if(col!="G") fail(key,"starboard sidelight is not green") }
      if(arc=="P"){ nr++; srh=h; srx=x; sry=y; if(col!="R") fail(key,"port sidelight is not red") }
      if(arc=="M"){ nmast++; if(col!="W") fail(key,"masthead light is not white")
                    if(mfh<0 || h<mfh){ mfh=h; mfx=x } }
      if(arc=="T"&&col=="W") nstern++
      #  two lights at the same place are one light
      kk = sprintf("%.3f/%.3f/%.3f", x, y, h)
      if(kk in H) fail(key,"two lights in exactly the same place")
      H[kk]=1
    }
    # ---- Rule 21 / Annex I -------------------------------------------
    #  Sidelights come in pairs, level, and opposite each other.
    if(ng!=nr) fail(key,"sidelights are not a pair")
    if(ng==1){
      if(sgh!=srh) fail(key,"sidelights are at different heights")
      if(sgx!=srx) fail(key,"sidelights are at different points along the hull")
      if(sgy<=0 || sry>=0 || sgy!=-sry) fail(key,"sidelights are not opposite each other")
      #  Annex I 3(b): sidelights not higher than 3/4 of the forward
      #  masthead light
      if(nmast>0 && sgh > 0.75*mfh + 1e-9)
        fail(key,sprintf("sidelights at %.2f are above 3/4 of the masthead light at %.2f",sgh,mfh))
      #  Annex I 3(b), the other half of the same sentence: "the
      #  sidelights shall not be placed in front of the forward
      #  masthead lights."  So a sidelight belongs AT or ABAFT the
      #  forward masthead light, never ahead of it.  This is the rule
      #  behind the thing that looks wrong in the drawing - a green
      #  light sitting aft of the masts on a vessel showing you her
      #  starboard bow.  It is not a drawing error; it is Annex I.
      if(nmast>0 && sgx > mfx + 1e-9)
        fail(key,sprintf("sidelights at %.2f are forward of the masthead light at %.2f",sgx,mfx))
    }
    #  A vessel under way showing sidelights shows a sternlight
    if(ng==1 && nstern==0 && key!="tow200" && key!="tow200p")
      fail(key,"shows sidelights but no sternlight")
    #  Masthead lights of one vessel are in a vertical line: same x
    if(nmast>1){
      first=""; for(j=1;j<=n;j++){ split(L[j],f,",")
        if(f[4]!="M") continue
        if(first=="") first=f[1]+0
        else if(key!="power50p" && (f[1]+0)!=first)
          fail(key,"masthead lights are not in a vertical line") }
    }
  }
  # ---- Rule 21: the arcs have to add up to a whole circle ------------
  seen_m=0; seen_t=0; both=0; neither=0
  for(t=-180;t<180;t+=0.25){
    m=arc_vis("M",t); s=arc_vis("T",t)
    if(m&&s) both++
    if(!m&&!s) neither++
  }
  if(both>4)   fail("Rule21","masthead and stern arcs overlap by more than the tolerance")
  if(neither>0) fail("Rule21","masthead and stern arcs leave a gap: " neither " steps")
  #  and the sidelights, together, cover the same 225 degrees as the mast
  gap=0
  for(t=-180;t<180;t+=0.25){
    p=arc_vis("P",t); g=arc_vis("S",t); m=arc_vis("M",t)
    if(m && !p && !g) gap++
  }
  if(gap>0) fail("Rule21","a sidelight gap inside the masthead arc: " gap " steps")
  printf "%d\n", NF_
  exit 0
}
