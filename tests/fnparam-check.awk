#  A function name cannot also be used as a variable or a parameter.
#  gawk lets it pass; mawk refuses to parse the file at all, so this is
#  invisible until the matrix runs - and the matrix is not what you run
#  while you are writing. Hence a lint.
#
#  Pass 1 collects every function name across all the files given; pass 2
#  checks every parameter list against it. Run over one tool's files at a
#  time, since the files are loaded together at run time.
{ L[++NL_]=$0; F_[NL_]=FILENAME; N_[NL_]=FNR }
END{
  for(i=1;i<=NL_;i++){
    if(match(L[i], /^[ \t]*function[ \t]+[A-Za-z_][A-Za-z_0-9]*/)){
      s=substr(L[i], RSTART, RLENGTH)
      sub(/^[ \t]*function[ \t]+/,"",s)
      FN[s]=1
    }
  }
  bad=0
  for(i=1;i<=NL_;i++){
    line=L[i]
    if(!match(line, /^[ \t]*function[ \t]+[A-Za-z_][A-Za-z_0-9]*[ \t]*\(/)) continue
    p = substr(line, RSTART+RLENGTH)
    #  the parameter list runs to the closing paren
    q = index(p, ")")
    if(q>0) p = substr(p,1,q-1)
    gsub(/[ \t]/,"",p)
    n = split(p, A, ",")
    for(j=1;j<=n;j++){
      if(A[j]=="") continue
      if(A[j] in FN){
        printf "%s:%d: parameter '%s' is also a function name\n", F_[i], N_[i], A[j]
        bad++
      }
    }
  }
  printf "BAD %d\n", bad
}
