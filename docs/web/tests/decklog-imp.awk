#  Dump implausible() over the numeric range, so the JS port is held to
#  the awk's exact answers and its exact wording.
#  Loaded FIRST, because screens.awk carries the tool's own dispatch in a
#  BEGIN block that exits before a later file's BEGIN would ever run.
#  Output goes to a named file for the same reason.
BEGIN{
  nk = split("mslp wspd wdir airt seat dewp sog crs other", K, " ")
  for(a=1;a<=nk;a++){
    for(i=-400;i<=1400;i++){
      v = i
      printf "I\t%s\t%s\t%s\n", K[a], v, implausible(K[a], v) > OUTF
    }
    #  fractional values, and the four states
    for(i=0;i<40;i++){
      v = sprintf("%.1f", -100 + i*57.3)
      printf "I\t%s\t%s\t%s\n", K[a], v, implausible(K[a], v) > OUTF
    }
    printf "I\t%s\t%s\t%s\n", K[a], "-", implausible(K[a], "-") > OUTF
    printf "I\t%s\t%s\t%s\n", K[a], "/", implausible(K[a], "/") > OUTF
    printf "I\t%s\t%s\t%s\n", K[a], "",  implausible(K[a], "") > OUTF
  }
}
