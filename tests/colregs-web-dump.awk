BEGIN{
  for(b=0;b<360;b++)  printf "relp\t%d\t%s\n", b, rel_phrase(b,"your")
  for(b=0;b<360;b++)  printf "relpthe\t%d\t%s\n", b, rel_phrase(b,"the")
  for(t=-180;t<=180;t++) printf "aspect\t%d\t%s\n", t, aspect_words(t)
  for(t=-180;t<=180;t++) printf "ltarc\t%d\t%s\n", t, lt_arc(t)
  ves_init()
  for(v=1;v<=NVES;v++){
    split(VT[v],K,"|")
    for(t=-180;t<=180;t++) printf "ltnote\t%s\t%d\t%s\n", K[1], t, lt_note(K[1],t)
  }
  n=split("M S P T Y A",A," ")
  for(i=1;i<=n;i++) for(t=-180;t<=180;t++)
    printf "arc\t%s\t%d\t%d\n", A[i], t, (arc_vis(A[i],t)?1:0)
}
