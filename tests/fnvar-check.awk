#  A function name used as an ORDINARY VARIABLE anywhere in the same
#  program.  fnparam-check catches a function name used as a PARAMETER;
#  this is the other half, and it bit within an hour of the lint being
#  written: teach.awk defined p() while screens.awk used p as a local
#  in mkrec, and the tool died at startup with a message about a space
#  before a bracket that tells you nothing.
#
#  Read every -f file given, collect the function names, then look for
#  any of them on the left of an assignment.
FNR==1 { FILES[++NFILE]=FILENAME }
/^[ \t]*function[ \t]+[A-Za-z_][A-Za-z0-9_]*[ \t]*\(/ {
  s=$0; sub(/^[ \t]*function[ \t]+/,"",s); sub(/[ \t]*\(.*/,"",s)
  FN[s]=FILENAME
  next
}
{ LINE[++NL]=$0; WHERE[NL]=FILENAME; LNO[NL]=FNR }
END{
  for(i=1;i<=NL;i++){
    s=LINE[i]
    sub(/#.*/,"",s)
    #  name = something, or name++ / name-- / name +=
    while(match(s, /[A-Za-z_][A-Za-z0-9_]*[ \t]*(\+\+|--|[-+*\/]?=[^=])/)){
      t=substr(s,RSTART,RLENGTH)
      sub(/[ \t]*(\+\+|--|[-+*\/]?=).*/,"",t)
      if(t in FN){
        printf "  %s:%d assigns to %s, which is a function defined in %s\n",
               WHERE[i], LNO[i], t, FN[t]
        bad++
      }
      s = substr(s, RSTART+RLENGTH)
    }
  }
  printf "FNVAR %d\n", bad+0
}
