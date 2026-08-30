# =====================================================================
#  Colour, shared.
#
#  day    light text on a black panel
#  night  deep red on black, no green at all, because rebuilding dark
#         adaptation takes twenty minutes and a bright screen costs
#         every one of them
#  plain  no escape sequences whatsoever - chosen automatically when
#         stdout is not a terminal, so redirected output is clean text
#
#  The panel is painted rather than only setting a foreground colour:
#  a user on a light terminal profile otherwise gets white on white.
# =====================================================================
function col_init(   e){
  if(COL_READY) return
  e=sprintf("%c",27)
  if(cmode=="night"){
    C_BASE=e "[40m" e "[31m"; C_ACC=e "[1;31m"; C_DIM=e "[2;31m"
    C_WARN=e "[1;31m"; C_NO=e "[1;31m"; C_OK=e "[1;31m"
  } else if(cmode=="day"){
    C_BASE=e "[40m" e "[37m"; C_ACC=e "[1;32m"; C_DIM=e "[90m"
    C_WARN=e "[1;91m"; C_NO=e "[1;91m"; C_OK=e "[1;92m"
  } else {
    C_BASE=""; C_ACC=""; C_DIM=""; C_WARN=""; C_NO=""; C_OK=""
  }
  C_RST=C_BASE; COL_READY=1
  return 0
}
function cw(s,c){ col_init(); if(c=="") return s; return c s C_RST }
function cwd(s){ col_init(); return cw(s,C_DIM) }
function hr(){ print "  ----------------------------------------------------------------------" }
