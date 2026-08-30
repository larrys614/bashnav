#  Properties of the record layer.  These are the tests that protect an
#  append-only file: everything else in the tool can be rewritten, but a
#  record already on somebody's iPad cannot.
function chk(what, got, want){
  T++
  if(got==want) return 0
  BAD++; printf "  FAIL %s: got [%s] want [%s]\n", what, got, want
  return 1
}
BEGIN{
  # ---- encoding round trip, including everything that can hurt ------
  split("", k); split("", v)
  k[1]="note";  v[1]="belt squeals|check at 1300hrs"
  k[2]="plate"; v[2]="E/G 3TNV88=B"
  k[3]="pct";   v[3]="100% done"
  k[4]="empty"; v[4]=""
  k[5]="zero";  v[5]="0"
  k[6]="neg";   v[6]="-4.5"
  k[7]="both";  v[7]="a|b=c%d"
  rec = lg_make("2026-08-30T18:00Z","eng",k,v,7)
  chk("record has no raw pipe in a value", (rec ~ /squeals\|check/), 0)
  chk("record ends with the completeness marker", (rec ~ /\|~$/), 1)
  chk("record parses", lg_parse(rec), 1)
  for(i=1;i<=7;i++) chk("roundtrip " k[i], LG[k[i]], v[i])
  chk("timestamp", LG_TS, "2026-08-30T18:00Z")
  chk("type", LG_TYPE, "eng")

  #  a value of "0" must be distinguishable from a declined field and
  #  from an absent one - the three states the whole design rests on
  chk("zero is a reading", LG["zero"], "0")
  chk("declined is not zero", ("declined" in LG), 0)

  # ---- malformed records are rejected, never fatal -----------------
  chk("empty line",        lg_parse(""), 0)
  chk("no type",           lg_parse("2026-08-30T18:00Z"), 0)
  chk("bad timestamp",     lg_parse("30-08-2026|eng|a=1|~"), 0)
  chk("short timestamp",   lg_parse("2026-08-30T18:00|eng|a=1|~"), 0)
  chk("bad type",          lg_parse("2026-08-30T18:00Z|ENGINE|a=1|~"), 0)
  chk("field without =",   lg_parse("2026-08-30T18:00Z|eng|justtext|~"), 0)
  chk("empty key",         lg_parse("2026-08-30T18:00Z|eng|=1|~"), 0)
  chk("upper-case key",    lg_parse("2026-08-30T18:00Z|eng|Key=1|~"), 0)
  chk("a record with no fields is legal", lg_parse("2026-08-30T18:00Z|eng|~"), 1)
  #  the bug the truncation test found: a half-written line is
  #  structurally perfect and must still be rejected
  chk("truncated mid-value",  lg_parse("2026-08-30T18:00Z|eng|job=impeller|qty=1|note=las"), 0)
  chk("truncated at a field boundary", lg_parse("2026-08-30T18:00Z|eng|job=impeller|qty=1"), 0)
  chk("truncated right after the type", lg_parse("2026-08-30T18:00Z|eng"), 0)
  chk("a forged terminator inside a value cannot happen",
      lg_parse("2026-08-30T18:00Z|eng|note=" lg_enc("a|~")), 0)

  # ---- a truncated tail must not take the good records with it -----
  #  Written for the iPad: a-Shell is suspended or killed mid-write and
  #  the last line is half there.  Every earlier record must survive.
  if(TRUNC!=""){
    n = lg_read(TRUNC, "")
    chk("good records recovered from a truncated log", LG_GOOD, WANTGOOD+0)
    chk("the damaged tail is reported, not swallowed", (LG_BAD>0), WANTBAD+0)
  }
  printf "LOGRESULT %d %d\n", T, BAD+0
}
