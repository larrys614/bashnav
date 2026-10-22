#  EVERY ENCOUNTER'S VESSEL KEY MUST NAME A VESSEL THAT EXISTS.
#
#  Field 11 of an encounter row is a key into the same twenty-two the
#  lights drill renders, so the scenario can draw her instead of
#  describing her. A key with a typo in it is invisible in every other
#  check: ves_find returns 0, draw_lights declines, and the scenario
#  prints perfectly with no picture -- which is also exactly what the
#  three scenarios that are MEANT to have no picture look like. So the
#  only way a wrong key shows up is by asking whether it resolves.
#
#  It also pins the count. Larry asked for a picture on all of them and
#  ruled that the seaplane keeps none; the two fog signals cannot be
#  seen at all. That is three, and three is what this expects -- a key
#  silently dropped from a row would otherwise just look like a fourth.
BEGIN{
  enc_init(); ves_init()
  nbad=0; nkey=0; nnone=0
  for(i=1;i in EC;i++){
    n=split(EC[i],a,"|")
    if(n<11){ printf "FAIL  encounter %d has only %d fields\n", i, n; nbad++; continue }
    if(a[11]==""){
      nnone++
      #  and it must be one of the two reasons, not an omission
      if(a[2] !~ /blast|fog signal/ && a[2] !~ /seaplane/){
        printf "FAIL  encounter %d has no vessel and is neither a fog signal nor a seaplane: %s\n", i, a[2]
        nbad++
      }
      continue
    }
    nkey++
    if(ves_find(a[11])==0){
      printf "FAIL  encounter %d names vessel \"%s\", which is not in the table\n", i, a[11]
      nbad++
    }
  }
  if(nnone!=3){ printf "FAIL  %d encounters have no vessel, expected 3\n", nnone; nbad++ }
  if(nbad){ printf "  %d bad\n", nbad; exit 1 }
  printf "  ok  all %d encounter vessel keys resolve, and the 3 without one say why\n", nkey
}
