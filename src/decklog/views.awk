# =====================================================================
#  deck-log -- registry, derived views, and the entry helpers.
#
#  THE THREE LAYERS, and it matters that they stay separate:
#
#    registry   facts about the boat.  Equipment, parts, minimums,
#               stowage.  Changes rarely.  Lives in BOAT.
#    log        events.  What happened.  Append only.  Lives in LOG.
#    views      holdings, open defects, what is due, the shopping list.
#               COMPUTED, NEVER STORED.
#
#  So there is no stored inventory.  The catalogue is registry; the
#  count is derived by replaying the log.  A stored count is the obvious
#  design and it is the one that goes wrong: it drifts from the log, and
#  then you have two numbers and no way to know which one lied.
# =====================================================================

function col_init(   e){
  if(COL_READY) return
  e=sprintf("%c",27)
  if(cmode=="night"){ C_BASE=e "[40m" e "[31m"; C_ACC=e "[1;31m"; C_DIM=e "[2;31m"
                      C_WARN=e "[1;31m" }
  else if(cmode=="day"){ C_BASE=e "[40m" e "[37m"; C_ACC=e "[1;32m"; C_DIM=e "[90m"
                         C_WARN=e "[1;91m" }
  else { C_BASE=""; C_ACC=""; C_DIM=""; C_WARN="" }
  C_RST=C_BASE; COL_READY=1
  return 0
}
function cw(s,c){ col_init(); if(c=="") return s; return c s C_RST }
function cwd(s){ col_init(); return cw(s,C_DIM) }
function hr(){ print "  ----------------------------------------------------------------------" }

# ---------------------------------------------------------------------
#  The registry.  Same encoding as the log so there is one escaping
#  rule in the tool, not two.
#
#      eq|id=eng.main|make=Yanmar|model=4JH4-TE|serial=E12345|...|~
#      pt|id=impeller|number=Jabsco 17937-0001|fits=eng.main|min=2|...|~
# ---------------------------------------------------------------------
function bt_read(file,   line, id){
  EQ_N=0; PT_N=0
  while((getline line < file) > 0){
    if(line=="" || substr(line,1,1)=="#") continue
    if(!lg_parse("2000-01-01T00:00Z|" line)) continue
    id = LG["id"]
    if(id=="") continue
    if(LG_TYPE=="eq"){
      EQ_N++; EQ_ID[EQ_N]=id
      EQ_MAKE[EQ_N]=LG["make"]; EQ_MODEL[EQ_N]=LG["model"]
      EQ_SER[EQ_N]=LG["serial"]; EQ_NAME[EQ_N]=LG["name"]
      EQ_PLATE[EQ_N]=LG["plate"]; EQ_IDX[id]=EQ_N
    } else if(LG_TYPE=="pt"){
      PT_N++; PT_ID[PT_N]=id
      PT_NUM[PT_N]=LG["number"]; PT_FITS[PT_N]=LG["fits"]
      PT_MIN[PT_N]=LG["min"]+0; PT_STOW[PT_N]=LG["stow"]
      PT_NAME[PT_N]=LG["name"]; PT_IDX[id]=PT_N
    }
  }
  close(file)
  return EQ_N + PT_N
}
function bt_make(type, k, v, n,   rec){
  #  the registry line is a record without a timestamp
  rec = lg_make("2000-01-01T00:00Z", type, k, v, n)
  sub(/^[^|]*\|/, "", rec)
  return rec
}

# ---------------------------------------------------------------------
#  Inventory, derived.
#
#  Replay the log: a stocktake SETS the holding, a use subtracts, a
#  restock adds.  `fits` is honoured, so a part consumed against the
#  main engine does not move the generator's holding of the same part.
# ---------------------------------------------------------------------
#  KEYED BY PART ALONE, and that is a correction.
#
#  The first version keyed the holding by part AND by the equipment the
#  job recorded, which looks careful and is wrong.  A spare belongs to
#  the locker, not to a machine.  The moment somebody cannibalises the
#  main engine's impeller for the generator in an emergency - which is
#  exactly when a boat does that - the job records fits=gen, a second
#  bucket appears from nowhere, the main engine's holding never goes
#  down, and the shopping list quietly stops asking for the part you
#  just used.
#
#  So: `fits` in the REGISTRY says what a part is for, and `eq`/`fits`
#  on a JOB says where it went - useful history, both of them.  Neither
#  divides the stock.  Two engines needing different impellers are two
#  parts with two ids, which is what they are in the locker.
function inv_build(logfile,   i, part, q){
  for(part in HOLD) delete HOLD[part]
  lg_read(logfile, "")
  for(i=1; i<=LG_N; i++){
    if(!lg_at(i)) continue
    part = LG["part"]
    if(part=="") continue
    q = LG["qty"]
    if(LG_TYPE=="inv" && LG["action"]=="stocktake"){ HOLD[part] = LG["count"]+0; continue }
    if(LG_TYPE=="inv" && LG["action"]=="restock"){   HOLD[part] += q+0; continue }
    if(LG_TYPE=="eng" || LG_TYPE=="pro"){
      if(q!="") HOLD[part] -= q+0
    }
  }
  return 0
}
function inv_hold(part, fits){
  if(part in HOLD) return HOLD[part]
  return 0
}

# ---------------------------------------------------------------------
#  Open defects.  An inspection that finds something opens an item; it
#  stays open until a job records closes=<timestamp>.  This is the piece
#  the log alone does not give you: a finding is not an event that is
#  over when it is written.
# ---------------------------------------------------------------------
function def_build(logfile,   i, ts, c){
  DEF_N=0
  for(i in CLOSED) delete CLOSED[i]
  lg_read(logfile, "")
  for(i=1; i<=LG_N; i++){
    if(!lg_at(i)) continue
    c = LG["closes"]
    if(c!="") CLOSED[c]=LG_TS
  }
  for(i=1; i<=LG_N; i++){
    if(!lg_at(i)) continue
    if(LG["state"]!="a") continue
    ts = LG_TS
    if(ts in CLOSED) continue
    DEF_N++
    DEF_TS[DEF_N]=ts; DEF_EQ[DEF_N]=LG["eq"]
    DEF_ITEM[DEF_N]=LG["insp"]; DEF_NOTE[DEF_N]=LG["note"]
  }
  return DEF_N
}
