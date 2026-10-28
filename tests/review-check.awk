#  Every reviewable claim must render, and the report must carry the
#  program's own words for anything flagged - otherwise an issue arrives
#  saying "lig-7 is wrong" with nothing to act on.
BEGIN{
  n=rv_build()
  if(what=="count"){ print n; exit 0 }
  if(what=="show"){
    bad=0
    for(i=1;i<=n;i++){
      OUT=""
      if(rv_show(RV_K[i])!=0){ printf "RVSHOW %s failed\n", RV_K[i]; bad++ }
      c=rv_claim(i)
      if(c=="" || length(c)<12){ printf "RVCLAIM %s is thin: '%s'\n", RV_K[i], c; bad++ }
    }
    printf "BAD %d\n", bad; exit 0
  }
  if(what=="keys"){
    #  keys must be unique and stable in shape
    bad=0
    for(i=1;i<=n;i++){
      if(RV_K[i] in SEEN){ printf "duplicate key %s\n", RV_K[i]; bad++ }
      SEEN[RV_K[i]]=1
      #  enc and les stay numbered -- their tables are indexed, not
      #  sorted, so those keys have never moved. The rest name what they
      #  are about, so that adding a vessel cannot shift a reviewer's
      #  saved verdict onto a claim he never read.
      if(RV_K[i] ~ /^(enc|les)-/){
        if(RV_K[i] !~ /^(enc|les)-[0-9]+$/){ printf "odd key %s\n", RV_K[i]; bad++ }
      } else if(RV_K[i] ~ /^mot-/){
        if(RV_K[i] !~ /^mot-[a-z0-9]+-[0-9][0-9][0-9]$/){ printf "odd key %s\n", RV_K[i]; bad++ }
      } else if(RV_K[i] !~ /^(lig|snd|shp)-[a-z0-9]+$/){
        printf "odd key %s\n", RV_K[i]; bad++ }
    }
    printf "BAD %d\n", bad; exit 0
  }
  exit 0
}
