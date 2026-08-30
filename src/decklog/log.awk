# =====================================================================
#  deck-log -- the record layer.
#
#  This file is the one irreversible decision in the whole tool.  The log
#  is append-only, so every record written today has to still parse in
#  five years, in a version nobody has written yet.  Adding a key later
#  is free - a reader ignores keys it does not know.  Changing the SHAPE
#  is not, ever.
#
#  Format, one record per line:
#
#      YYYY-MM-DDThh:mmZ|type|key=value|key=value|...|~
#
#  THE TRAILING ~ IS A COMPLETENESS MARKER, and it is there because of a
#  bug this format had before the truncation test found it.
#
#  Kill the app mid-write and the half-line left on disk is STRUCTURALLY
#  PERFECT: right timestamp, right type, every field a well-formed
#  key=value.  Nothing distinguishes it from a finished record, so a
#  reader accepts it and you silently lose the fields that never made it
#  to disk - an engine entry with the part but not the hours, and no
#  indication anything is missing.  In an append-only log that is
#  permanent, and it is exactly the failure that would matter in an
#  inquiry.
#
#  So a record is complete only if its last field is a bare ~.  A
#  truncation cannot forge one: | is percent-encoded inside values, so
#  the sequence |~ appears nowhere else.  One character of noise, and
#  ANY reader in any language in any decade can tell a whole record from
#  half of one without knowing anything about our software.
#
#  - the timestamp is UTC.  Always.  Display in whatever the user likes.
#  - `type` is three characters or fewer: nav wx eng pro inv cel tid con
#    cor chart.  A reader that does not know a type skips the record.
#  - keys are [a-z0-9_] only, so they never need encoding
#  - VALUES ARE PERCENT-ENCODED for the four characters that can hurt.
#
#  POSIX awk only.  See docs/HACKING.md.
# =====================================================================

# ---------------------------------------------------------------------
#  Encoding.
#
#  Free text goes in this log - a note typed at 0400, the verbatim text
#  off an engine plate - and it will contain the delimiters:
#
#      note=belt squeals, replaced 30 Aug|check again at 1300hrs
#      plate=4JH4-TE  S/N E12345  E/G 3TNV88=B
#
#  Unescaped, those still LOOK like records.  They just have the wrong
#  number of fields and the tail is gone, and in an append-only log that
#  damage is permanent and silent.
#
#  Only four characters are encoded, so ordinary text stays literal and
#  the log is still readable by eye and by grep - which matters for a
#  file somebody may have to interpret after an incident with no
#  software to hand.
# ---------------------------------------------------------------------
function lg_enc(s){
  gsub(/%/,  "%25", s)      # first, or it would double-encode the rest
  gsub(/\|/, "%7C", s)
  gsub(/=/,  "%3D", s)
  gsub(/\n/, "%0A", s)
  return s
}
function lg_dec(s){
  #  %25 last, for the same reason in reverse
  gsub(/%0A/, "\n", s)
  gsub(/%3D/, "=",  s)
  gsub(/%7C/, "|",  s)
  gsub(/%25/, "%",  s)
  return s
}

# ---------------------------------------------------------------------
#  Building a record.
#
#  Callers hand over parallel arrays of keys and values rather than a
#  formatted string, so there is exactly one place that knows the
#  delimiters and exactly one place that encodes.
# ---------------------------------------------------------------------
function lg_make(ts, type, k, v, n,   i, out){
  out = ts "|" type
  for(i=1; i<=n; i++){
    if(k[i]=="") continue
    out = out "|" k[i] "=" lg_enc(v[i])
  }
  return out "|~"                     # the completeness marker
}

# ---------------------------------------------------------------------
#  Parsing.
#
#  Fills LG[key] with decoded values, sets LG_TS and LG_TYPE, and
#  returns 1 for a good record.  Returns 0 and sets LG_ERR otherwise -
#  it never aborts, because a damaged tail must not take the whole log
#  with it.
# ---------------------------------------------------------------------
function lg_parse(line,   n, f, i, p, key, val){
  for(key in LG) delete LG[key]
  LG_TS=""; LG_TYPE=""; LG_ERR=""; LG_NF=0
  if(line=="" || substr(line,1,1)=="#"){ LG_ERR="blank or comment"; return 0 }
  n = split(line, f, "|")
  if(n < 3){ LG_ERR="too few fields"; return 0 }
  if(!lg_ts_ok(f[1])){ LG_ERR="bad timestamp: " f[1]; return 0 }
  if(f[2] !~ /^[a-z][a-z0-9]{0,4}$/){ LG_ERR="bad type: " f[2]; return 0 }
  #  The record must be COMPLETE.  Without this a half-written line
  #  parses cleanly and quietly loses whatever never reached the disk.
  if(f[n] != "~"){ LG_ERR="incomplete record (no terminator)"; return 0 }
  LG_TS = f[1]; LG_TYPE = f[2]
  for(i=3; i<n; i++){
    p = index(f[i], "=")
    if(p < 2){ LG_ERR="field " i " is not key=value: " f[i]; return 0 }
    key = substr(f[i], 1, p-1)
    val = substr(f[i], p+1)
    if(key !~ /^[a-z0-9_]+$/){ LG_ERR="bad key: " key; return 0 }
    LG[key] = lg_dec(val)
    LG_NF++
  }
  return 1
}

#  A timestamp this reader will accept for ever: YYYY-MM-DDThh:mmZ
function lg_ts_ok(s){
  if(length(s)!=17) return 0
  return (s ~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]Z$/)
}

# ---------------------------------------------------------------------
#  Reading a whole log.
#
#  A record that will not parse is COUNTED and SKIPPED, never fatal.
#  The app is suspended by iOS, the battery dies, a-Shell is killed
#  mid-write - a half-written last line must not make the log
#  unreadable, and it must not silently swallow the good records above
#  it either.  So: LG_GOOD and LG_BAD, and the caller decides what to
#  say about it.
# ---------------------------------------------------------------------
function lg_read(file, want,   line, i){
  LG_N=0; LG_GOOD=0; LG_BAD=0; LG_BADLINE=""
  while((getline line < file) > 0){
    if(line=="" || substr(line,1,1)=="#") continue
    if(!lg_parse(line)){
      LG_BAD++
      if(LG_BADLINE=="") LG_BADLINE = line
      continue
    }
    LG_GOOD++
    if(want!="" && LG_TYPE!=want) continue
    LG_N++
    LR_TS[LG_N]   = LG_TS
    LR_TYPE[LG_N] = LG_TYPE
    LR_LINE[LG_N] = line
  }
  close(file)
  return LG_N
}

#  Re-parse the nth record kept by lg_read, so LG[] refers to it.
function lg_at(i){
  if(i<1 || i>LG_N) return 0
  return lg_parse(LR_LINE[i])
}
