#  Emit a corpus of awkward log records from the awk engine, for the JS
#  port to be checked against in both directions.
#
#  Values travel to the harness as HEX, not as text.  Transporting them
#  in any encoding would mean the test shares a mechanism with the thing
#  it is testing, and a bug in the escaping would cancel out and pass.
#  Hex cannot collide with | = % or a newline.
function hexinit(   i){ for(i=1;i<=255;i++) ORD[sprintf("%c",i)]=i }
function hex(s,   i,o){ o=""; for(i=1;i<=length(s);i++) o = o sprintf("%02x", ORD[substr(s,i,1)]); return o }

BEGIN{
  hexinit()
  #  The values that break a naive parser, plus the ones that look
  #  harmless and are not.
  V[1]  = "plain text"
  V[2]  = "belt squeals, replaced 30 Aug|check again at 1300hrs"
  V[3]  = "4JH4-TE  S/N E12345  E/G 3TNV88=B"
  V[4]  = "100% done"
  V[5]  = "%7C"                      # a literal that must not decode to |
  V[6]  = "%25"                      # and the escape for % itself
  V[7]  = "a|b=c%d"
  V[8]  = ""                         # empty, which is not the same as absent
  V[9]  = "0"                        # zero is a reading
  V[10] = "-"                        # asked, not taken
  V[11] = "/"                        # asked, not observable
  V[12] = "  leading and trailing  "
  V[13] = "-3.5"
  V[14] = "000"                      # a wind direction of north
  V[15] = "||||"
  V[16] = "===="
  V[17] = "%%%%"
  V[18] = "%7C%3D%0A%25"             # every escape, literal
  V[19] = "line one\nline two"       # a newline inside a value
  V[20] = "tab\there"
  NV = 20

  K[1]="note"; K[2]="plate"; K[3]="why"; K[4]="part"; K[5]="v0"
  K[6]="k_1"; K[7]="mslp"; NK=7

  for(i=1;i<=NV;i++){
    #  one record per value, with the value in several different field
    #  positions, because a tail-position bug and a middle-position bug
    #  are different bugs
    kk[1]="a";  vv[1]="before"
    kk[2]=K[((i-1)%NK)+1]; vv[2]=V[i]
    kk[3]="z";  vv[3]="after"
    rec = lg_make("2026-08-30T18:00Z", "eng", kk, vv, 3)
    printf "CASE\t%d\t%s\t%s\t%s\n", i, kk[2], hex(V[i]), hex(rec)
    #  and the same value alone, in the last field position
    k2[1]=kk[2]; v2[1]=V[i]
    rec = lg_make("2026-08-30T18:00Z", "wx", k2, v2, 1)
    printf "TAIL\t%d\t%s\t%s\t%s\n", i, kk[2], hex(V[i]), hex(rec)
  }

  #  what the awk parser accepts and rejects, so the JS can be held to
  #  the same answers rather than to my memory of them
  BAD[1]  = "not a record"
  BAD[2]  = "2026-08-30T18:00Z|eng"
  BAD[3]  = "2026-08-30T18:00Z|eng|job=x"                    # no terminator
  BAD[4]  = "2026-08-30T18:00|eng|job=x|~"                   # no Z
  BAD[5]  = "2026-13-30T18:00Z|eng|job=x|~"                  # month 13: accepted by shape
  BAD[6]  = "2026-08-30T18:00Z|ENG|job=x|~"                  # uppercase type
  BAD[7]  = "2026-08-30T18:00Z|toolongtype|job=x|~"
  BAD[8]  = "2026-08-30T18:00Z|eng|JOB=x|~"                  # uppercase key
  BAD[9]  = "2026-08-30T18:00Z|eng|=x|~"                     # empty key
  BAD[10] = "2026-08-30T18:00Z|eng|job|~"                    # no =
  BAD[11] = "2026-08-30T18:00Z|eng|job=x|~|extra"
  BAD[12] = "2026-08-30T18:00Z|eng|~"                        # no fields, still valid
  BAD[13] = "#a comment"
  BAD[14] = ""
  BAD[15] = "2026-08-30T18:00Z|e|job=x|~"                    # one-char type
  BAD[16] = "2026-08-30T18:00Z|eng|job=x|job=y|~"            # duplicate key
  NB = 16
  for(i=1;i<=NB;i++){
    ok = lg_parse(BAD[i])
    printf "JUDGE\t%d\t%d\t%s\t%s\n", i, ok, hex(BAD[i]), (ok ? "" : LG_ERR)
  }

  #  truncation at every byte offset of a good record
  good = "2026-08-30T18:00Z|eng|job=impeller|part=jabsco|qty=1|hrs=1234.5|~"
  for(i=1;i<=length(good);i++){
    t = substr(good,1,i)
    ok = lg_parse(t)
    printf "TRUNC\t%d\t%d\n", i, ok
  }
}
