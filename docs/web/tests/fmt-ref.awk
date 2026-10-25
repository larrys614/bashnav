#  Values and awk's own %.*f of them, for docs/web/tests/fmt-check.js.
#
#  THE INTERESTING VALUES ARE THE ODD QUARTERS.  A tie at one decimal
#  needs the value to be an odd multiple of 1/4 - any other x.x5 is not
#  exactly representable in binary and both languages already agree which
#  side of the tie it falls on.  So they are generated deliberately rather
#  than hoped for: a random sweep of a few thousand doubles contains none.
BEGIN{
  srand(7)
  #  odd quarters, both signs, across the range these programs print
  for(i=-400;i<=400;i++){
    v = i + 0.25; printf "%.17g\t1\t%.1f\n", v, v
    v = i + 0.75; printf "%.17g\t1\t%.1f\n", v, v
  }
  #  odd eighths, which are the ties at two decimals
  for(i=-60;i<=60;i++){
    v = i + 0.125; printf "%.17g\t2\t%.2f\n", v, v
    v = i + 0.375; printf "%.17g\t2\t%.2f\n", v, v
    v = i + 0.625; printf "%.17g\t2\t%.2f\n", v, v
    v = i + 0.875; printf "%.17g\t2\t%.2f\n", v, v
  }
  #  the near-ties, which are where a "fix" for the above goes wrong by
  #  multiplying before testing: 2.45 is 2.4500000000000001776 and rounds
  #  UP in both languages, and a formatter that computed 2.45*10 == 24.5
  #  and then rounded to even would print 2.4
  for(i=0;i<=99;i++){
    v = i/100.0 + 0.005; printf "%.17g\t1\t%.1f\n", v, v
    v = i/10.0 + 0.05;   printf "%.17g\t1\t%.1f\n", v, v
  }
  #  and a plain sweep, because the ordinary case has to keep working
  for(i=0;i<1200;i++){
    v = (rand()-0.5)*720; printf "%.17g\t1\t%.1f\n", v, v
  }
  #  the two star magnitudes that are exact quarters, by name
  printf "1.25\t1\t%.1f\n", 1.25
  printf "2.75\t1\t%.1f\n", 2.75
}
