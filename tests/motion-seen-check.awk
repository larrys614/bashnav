#  THE WORDS MUST MATCH THE DISPLAY.
#
#  Larry, three claims in a row:
#
#      "you say she shows two masthead lights but you only display one"
#      "here again, the description does not match the lights displayed"
#      "the wording shoud match the display......thats all you get at sea"
#
#  The give-way explanation opens by saying what she shows, and the
#  screen beside it draws her lights as seen from one bearing.  The
#  sentence used to be built from the vessel table's caption -- every
#  light she CARRIES -- while the drawing shows only the lights whose
#  ARCS bear on you.  So a 50 m vessel seen from 135 was described as
#  showing two masthead lights and drawn showing one sternlight, and the
#  reader had no way to tell which of the two was lying.
#
#  Nothing in the suite could catch that, because nothing compared the
#  SENTENCE with the ARCS.  Each was self-consistent on its own.
#
#  This is that comparison, over every vessel at every degree.  For each
#  role it asserts both directions: a light in arc must be named, and a
#  light out of arc must not be.  Both halves matter -- naming a light
#  you cannot see is what Larry found, and silently dropping one you can
#  see would be the same fault wearing the other hat.
function has(s,w){ return index(s,w)>0 }
BEGIN{
  ves_init()
  bad=0; checked=0
  for(v=1;v<=NVES;v++){
    split(VT[v],a,"|"); n=split(a[4],L,";")
    for(th=0;th<360;th++){
      mh=0; sg=0; sp=0; stn=0; yel=0; arn=0; arw=""
      for(i=1;i<=n;i++){
        split(L[i],f,",")
        if(!arc_vis(f[4],th)) continue
        if(f[4]=="M") mh++
        else if(f[4]=="S") sg=1
        else if(f[4]=="P") sp=1
        else if(f[4]=="T") stn=1
        else if(f[4]=="Y") yel=1
        else if(f[4]=="A"){ arn++
          c=(f[5]=="W"?"white":(f[5]=="G"?"green":(f[5]=="R"?"red":"yellow")))
          if(!has(arw,c)) arw=arw c "," }
      }
      s=seen_sig(v,th); checked++

      #  masthead lights: named if and only if one bears
      if(mh>0 && !has(s,"masthead")){
        printf "FAIL  %s at %03d: %d masthead light(s) bear and none is named\n  %s\n", a[1],th,mh,s; bad++ }
      if(mh==0 && has(s,"masthead")){
        printf "FAIL  %s at %03d: no masthead light bears, but one is named\n  %s\n", a[1],th,s; bad++ }

      #  sidelights, which is where naming what she carries goes wrong
      #  fastest: "both sidelights" from a bearing where one is cut off.
      want = (sg&&sp) ? "both sidelights" : (sg ? "her green sidelight" : (sp ? "her red sidelight" : ""))
      if(want!="" && !has(s,want)){
        printf "FAIL  %s at %03d: expected \"%s\"\n  %s\n", a[1],th,want,s; bad++ }
      if(want=="" && has(s,"sidelight")){
        printf "FAIL  %s at %03d: no sidelight bears, but one is named\n  %s\n", a[1],th,s; bad++ }
      if(!sg && has(s,"green sidelight")){
        printf "FAIL  %s at %03d: her green is cut off and named\n  %s\n", a[1],th,s; bad++ }
      if(!sp && has(s,"red sidelight")){
        printf "FAIL  %s at %03d: her red is cut off and named\n  %s\n", a[1],th,s; bad++ }
      if((!sg||!sp) && has(s,"both sidelights")){
        printf "FAIL  %s at %03d: only one sidelight bears, both are named\n  %s\n", a[1],th,s; bad++ }

      #  the sternlight -- false from ahead on most captions
      if(stn && !has(s,"her sternlight")){
        printf "FAIL  %s at %03d: her sternlight bears and is not named\n  %s\n", a[1],th,s; bad++ }
      if(!stn && has(s,"sternlight")){
        printf "FAIL  %s at %03d: her sternlight is cut off and named\n  %s\n", a[1],th,s; bad++ }

      if(yel && !has(s,"yellow towing")){
        printf "FAIL  %s at %03d: her towing light bears and is not named\n  %s\n", a[1],th,s; bad++ }

      #  every all-round colour that bears must appear by name
      nc=split(arw,CL,",")
      for(i=1;i<=nc;i++){
        if(CL[i]=="") continue
        if(!has(s,CL[i])){
          printf "FAIL  %s at %03d: an all-round %s bears and is not named\n  %s\n", a[1],th,CL[i],s; bad++ }
      }
      if(arn==0 && has(s,"all-round")){
        printf "FAIL  %s at %03d: no all-round light bears, one is named\n  %s\n", a[1],th,s; bad++ }
    }
  }
  if(bad){ printf "  %d bad of %d\n", bad, checked; exit 1 }
  printf "  ok  every light named is a light that bears, and every light that bears is named (%d views)\n", checked
}
