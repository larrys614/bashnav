
#  ask_menu <key> <fieldname>   - a coded field: one keypress, no return
ask_menu() {
  eng -v cmd=menu -v what="$1"
  while :; do
    printf "  > "; IFS= read -r a || { fld "$2" "-"; return 0; }
    [ -z "$a" ] && { fld "$2" "-"; return 0; }
    if eng -v cmd=menuok -v what="$1" -v ans="$a" >/dev/null 2>&1; then
      fld "$2" "$a"; return 0
    fi
    echo "  ?"
  done
}

#  ask_num <fieldname> <prompt> [last]
#
#  A MEASUREMENT GETS NO DEFAULT.  The pressure at 1800 is not the 1500
#  reading unless changed - it is a new reading or it is nothing.  `last`
#  is shown for orientation only; return declines and records "-".
ask_num() {
  k=$1; prompt=$2; last=$3
  while :; do
    if [ -n "$last" ]; then printf "  %-34s %s\n" "$prompt" "$(printf '\033[90mlast: %s\033[0m' "$last" 2>/dev/null || echo "last: $last")"
    else printf "  %s\n" "$prompt"; fi
    printf "  > "; IFS= read -r a || { fld "$k" "-"; return 0; }
    case "$a" in
      "")  fld "$k" "-"; return 0 ;;
      "/") fld "$k" "/"; return 0 ;;
    esac
    if msg=$(eng -v cmd=check -v what="$k" -v ans="$a"); then
      fld "$k" "$a"; return 0
    fi
    #  a question, not a rejection: an instrument reading wrongly is
    #  itself worth logging
    printf "  %s\n" "$msg"
    printf "  is that really what you read? [y] yes, log it  [n] type it again  > "
    IFS= read -r y || return 0
    case "$y" in y|Y) fld "$k" "$a"; return 0 ;; esac
  done
}

#  ask_state <fieldname> <prompt> [carried]
#
#  STATE CARRIES FORWARD, because it genuinely persists: at 1800 the
#  course really is what it was at 1500 unless somebody changed it.
#  Return ACCEPTS the carried value here - the opposite of ask_num, and
#  the screen makes clear which you are looking at.
ask_state() {
  k=$1; prompt=$2; carried=$3
  if [ -n "$carried" ]; then printf "  %-34s [%s] " "$prompt" "$carried"
  else printf "  %-34s " "$prompt"; fi
  IFS= read -r a || { fld "$k" "${carried:--}"; return 0; }
  [ -z "$a" ] && a="$carried"
  [ -z "$a" ] && a="-"
  fld "$k" "$a"
}
ask_text() {
  printf "  %s " "$2"; IFS= read -r a || a=""
  [ -z "$a" ] && a="-"
  fld "$1" "$a"
}

last_of() { eng -v cmd=recent -v n=40 2>/dev/null | $AWK -v k="$1" '$0 ~ k {print}' | tail -1; }

# ---------------------------------------------------------------------
#  The three-hourly entry.
# ---------------------------------------------------------------------
do_entry() {
  load_conf
  echo
  echo "  ==============================================================="
  printf "   %s   %s\n" "$(utcstamp)" "deck log entry"
  echo "  ==============================================================="
  echo
  fld_start
  ask_state lat "latitude  (e.g. 41 14.0N)"  "$LAST_LAT"
  ask_state lon "longitude (e.g. 072 05.0W)" "$LAST_LON"
  ask_state crs "course steered, true"       "$LAST_CRS"
  ask_state sog "speed over ground, knots"   "$LAST_SOG"
  echo
  printf "  %s\n" "TRUE wind - not apparent. Apparent changes on every tack."
  ask_num wdir "wind direction, degrees true" ""
  ask_num wspd "wind speed, knots" ""
  ask_menu sea sea
  ask_text note "anything worth recording:"
  fld who "${who:--}"
  fld_commit nav || return 1
  echo
  echo "  logged."
  echo
  printf "  weather observation as well? [Y/n] "; IFS= read -r a || a=n
  case "$a" in n|N) ;; *) do_wx ;; esac
  return 0
}

do_wx() {
  echo
  printf "  %s\n" "  ---- weather ----"
  fld_start
  ask_num mslp "sea level pressure, hPa" "$LAST_MSLP"
  ask_menu ptend ptend
  ask_num pchg "pressure change over 3 h, hPa (+/-)" ""
  ask_num airt "air temperature, C" ""
  ask_num dewp "dew point, C  (or wet bulb)" ""
  ask_num seat "sea temperature, C" ""
  ask_menu cloud cloud
  ask_menu cl cl
  ask_menu cm cm
  ask_menu ch ch
  ask_menu vis vis
  echo
  printf "  %s\n" "  swell - separate from the wind sea. Period is the important one."
  ask_num swdir "swell from, degrees true" ""
  ask_num swper "swell period, seconds" ""
  ask_num swht  "swell height, metres" ""
  fld who "${who:--}"
  fld_commit wx || return 1
  echo; echo "  weather logged."; echo
}

# ---------------------------------------------------------------------
#  Engine
# ---------------------------------------------------------------------
CHECKLIST="oil_filter:oil and filter;fuel_pri:primary fuel filter;fuel_sec:secondary fuel filter;fuel_leaks:fuel system, leaks and damage;hoses:hoses and fittings;air:air filter;strainer:sea water strainer;impeller:water pump impeller;cooling:cooling system, leaks;coolant:antifreeze level and strength;hx:heat exchanger and coolers;anodes:sacrificial anodes;trans:transmission fluid;cables:throttle and shift cables;belts:belt tension and wear;batt:battery condition and connections;mounts:engine and motor mounts;sump:sump and oil pad"

pick_equip() {
  list=$(eng -v cmd=equiplist)
  [ -z "$list" ] && { echo "  no equipment in the registry yet - deck-log equip add"; return 1; }
  echo
  i=1; for e in $list; do echo "    $i  $e"; i=$((i+1)); done
  printf "  > "; IFS= read -r n || return 1
  case "$n" in *[!0-9]*|"") return 1 ;; esac
  EQ=$(printf '%s\n' $list | $AWK -v n="$n" 'NR==n{print}')
  [ -n "$EQ" ] || return 1
  return 0
}

do_inspect() {
  pick_equip || return 1
  echo
  echo "  $EQ - inspection.   o = ok   a = needs attention   - = not checked   / = could not reach"
  echo
  IFS=';'
  for item in $CHECKLIST; do
    key=${item%%:*}; label=${item#*:}
    printf "  %-38s " "$label"
    IFS= read -r s </dev/tty 2>/dev/null || s="-"
    case "$s" in o|O) s=o ;; a|A) s=a ;; /) s=/ ;; *) s=- ;; esac
    note=""
    if [ "$s" = a ]; then printf "    what is wrong? "; IFS= read -r note </dev/tty 2>/dev/null || note=""; fi
    fld_start
    fld eq "$EQ"; fld insp "$key"; fld state "$s"; fld note "${note:--}"; fld who "${who:--}"
    fld_commit eng || true
    IFS=';'
  done
  unset IFS
  echo
  echo "  inspection logged."
  eng -v cmd=defects
}

do_job() {
  pick_equip || return 1
  echo
  printf "  what was done? (e.g. oil and filter, impeller) "; IFS= read -r job || return 1
  [ -z "$job" ] && return 0
  parts=$(eng -v cmd=partlist)
  part=""; qty=""
  if [ -n "$parts" ]; then
    echo
    echo "  part used?"
    i=1; for p in $parts; do echo "    $i  $p"; i=$((i+1)); done
    echo  "    return  none"
    printf "  > "; IFS= read -r n || n=""
    case "$n" in
      ''|*[!0-9]*) ;;
      *) part=$(printf '%s\n' $parts | $AWK -v n="$n" 'NR==n{print}')
         [ -n "$part" ] && { printf "  how many? [1] "; IFS= read -r qty; [ -z "$qty" ] && qty=1; } ;;
    esac
  fi
  printf "  engine hours now? "; IFS= read -r hrs || hrs=""
  printf "  does this close an open item? [y/N] "; IFS= read -r c || c=n
  closes=""
  case "$c" in
    y|Y) eng -v cmd=defects
         printf "  paste the date-time of the item it closes (YYYY-MM-DDTHH:MMZ): "
         IFS= read -r closes || closes="" ;;
  esac
  fld_start
  fld eq "$EQ"; fld job "$job"
  [ -n "$part" ] && { fld part "$part"; fld qty "${qty:-1}"; fld fits "$EQ"; }
  fld hrs "${hrs:--}"; fld who "${who:--}"
  [ -n "$closes" ] && fld closes "$closes"
  fld_commit eng || return 1
  echo
  echo "  logged."
  #  the one line that matters, said while they are still standing there
  if [ -n "$part" ]; then eng -v cmd=holdings | grep -A2 -i "$part" | head -4; fi
  echo
}

# ---------------------------------------------------------------------
#  Registry
# ---------------------------------------------------------------------
add_equip() {
  echo
  printf "  short id (e.g. eng.main, gen, watermaker): "; IFS= read -r id || return 1
  [ -z "$id" ] && return 0
  printf "  make: ";   IFS= read -r make
  printf "  model: ";  IFS= read -r model
  printf "  serial: "; IFS= read -r ser
  echo "  now the WHOLE plate, verbatim - every number on it, including"
  echo "  the ones neither of us understands. It is the one the chandler"
  echo "  asks for that a tidy form leaves out."
  printf "  plate: "; IFS= read -r plate
  fld_start
  fld id "$id"; fld make "$make"; fld model "$model"; fld serial "$ser"; fld plate "$plate"
  mkdir -p "$DECKLOG_HOME"
  line=$(eng -v cmd=mkeq -v type=eq -v fields="$FIELDS"); rm -f "$FIELDS"; FIELDS=""
  [ -n "$line" ] && printf '%s\n' "$line" >> "$BOAT"
  echo "  added."
}
add_part() {
  echo
  printf "  short id (e.g. impeller): "; IFS= read -r id || return 1
  [ -z "$id" ] && return 0
  printf "  name: ";                       IFS= read -r name
  printf "  manufacturer's number: ";      IFS= read -r num
  printf "  fits which equipment id: ";    IFS= read -r fits
  printf "  minimum to carry: ";           IFS= read -r min
  printf "  stowed where: ";               IFS= read -r stow
  printf "  how many aboard right now: ";  IFS= read -r have
  fld_start
  fld id "$id"; fld name "$name"; fld number "$num"; fld fits "$fits"
  fld min "${min:-1}"; fld stow "$stow"
  mkdir -p "$DECKLOG_HOME"
  line=$(eng -v cmd=mkeq -v type=pt -v fields="$FIELDS"); rm -f "$FIELDS"; FIELDS=""
  [ -n "$line" ] && printf '%s\n' "$line" >> "$BOAT"
  #  the opening holding is a STOCKTAKE EVENT in the log, not a number
  #  in the registry - so the count is always derived and can never
  #  disagree with the log
  if [ -n "$have" ]; then
    fld_start
    fld part "$id"; fld fits "$fits"; fld count "$have"; fld action stocktake
    fld_commit inv || true
  fi
  echo "  added."
}
do_stocktake() {
  parts=$(eng -v cmd=partlist)
  [ -z "$parts" ] && { echo "  no parts in the registry yet"; return 0; }
  echo
  echo "  count the locker. Return to skip an item."
  for p in $parts; do
    printf "  %-24s " "$p"; IFS= read -r c || c=""
    [ -z "$c" ] && continue
    case "$c" in *[!0-9]*) continue ;; esac
    fld_start; fld part "$p"; fld count "$c"; fld action stocktake; fld who "${who:--}"
    fld_commit inv || true
  done
  echo "  counted."
}

do_provision() {
  echo
  printf "  item (water, fuel, gas, food): "; IFS= read -r item || return 1
  [ -z "$item" ] && return 0
  printf "  used or remaining? [u/r] "; IFS= read -r ur
  printf "  how much: "; IFS= read -r amt
  printf "  units (l, kg, %%): "; IFS= read -r u
  fld_start
  fld item "$item"; fld who "${who:--}"
  case "$ur" in r|R) fld remain "$amt" ;; *) fld used "$amt" ;; esac
  fld unit "${u:--}"
  fld_commit pro || return 1
  echo "  logged."
}

do_correct() {
  eng -v cmd=recent -v n=10
  echo
  echo "  A log is never edited. A correction is a NEW entry that points"
  echo "  at the old one, and both stay visible for ever - the electronic"
  echo "  version of lining through and initialling."
  printf "  date-time of the entry to correct (YYYY-MM-DDTHH:MMZ): "; IFS= read -r ref || return 1
  [ -z "$ref" ] && return 0
  printf "  which field: "; IFS= read -r k
  printf "  correct value: "; IFS= read -r v
  printf "  why: "; IFS= read -r why
  fld_start
  fld ref "$ref"; fld field "$k"; fld value "$v"; fld why "${why:--}"; fld who "${who:--}"
  fld_commit cor || return 1
  echo "  correction logged. The original entry is untouched."
}

help_text() {
  printf '%s\n' \
    '' \
    '  DECK-LOG -- the boat'\''s records: deck, engine, provisions' \
    '' \
    '  deck-log                 the menu' \
    '  deck-log entry           a deck log entry (the three-hourly one)' \
    '  deck-log wx              a weather observation on its own' \
    '  deck-log log [n]         the last n entries' \
    '  deck-log inspect         run the engine checklist' \
    '  deck-log job             record work done, and the part it used' \
    '  deck-log open            what is outstanding' \
    '  deck-log spares          what is aboard' \
    '  deck-log shopping        the list for the next port' \
    '  deck-log equip | part    the registry' \
    '  deck-log stocktake       count the locker' \
    '  deck-log correct         correct an earlier entry, properly' \
    '  deck-log day|night|plain colour mode' \
    '  deck-log about | version' \
    '' \
    '  The weather reasoning lives in its own tool: try "weather".' \
    '' \
    '  Every timestamp is UTC. The log is append only: nothing is ever' \
    '  edited or deleted, and a correction is a new entry that references' \
    '  the old one. Both stay visible for ever.' \
    ''
}

menu() {
  while :; do
    load_conf
    last=$(eng -v cmd=since)
    echo
    echo "  ==============================================================="
    echo "   DECK-LOG $DECKLOG_VERSION                             $(utcstamp)"
    echo "  ==============================================================="
    if [ -n "$last" ]; then echo "   last entry: $last"; else echo "   nothing logged yet"; fi
    printf '%s\n' \
      '' \
      '    1  Log an entry            5  Spares aboard' \
      '    2  Weather only            6  Shopping list' \
      '    3  Engine inspection       7  The log' \
      '    4  Work done               8  What is outstanding' \
      '' \
      '    p  Provisions   s  Stocktake   e  Equipment   n  New part' \
      '    x  Correct an entry' \
      '' \
      '    c  Colour   a  About   h  Help   q  Quit'
    printf "  > "; IFS= read -r c || exit 0
    case "$c" in
      1) do_entry ;;      2) do_wx ;;
      3) do_inspect ;;    4) do_job ;;
      5) eng -v cmd=holdings ;;
      6) printf "  which port (return for none): "; IFS= read -r p
         eng -v cmd=shopping -v port="$p" ;;
      7) eng -v cmd=recent -v n=20 ;;
      8) eng -v cmd=defects ;;
      p|P) do_provision ;;  s|S) do_stocktake ;;
      e|E) eng -v cmd=equip; printf "  add one? [y/N] "; IFS= read -r y
           case "$y" in y|Y) add_equip ;; esac ;;
      n|N) add_part ;;
      x|X) do_correct ;;
      c|C) printf "  day, night or plain? [%s] " "$cmode"; IFS= read -r v
           case "$v" in day|night|plain) cmode="$v"; save_conf; paint ;; esac ;;
      a|A) about_text ;;
      h|H|\?) help_text ;;
      q|Q) unpaint; exit 0 ;;
      "") ;;
      *) echo "  ?" ;;
    esac
  done
}

pick_awk || true
load_conf
install_engine
case "${1:-}" in
  "")         paint; menu ;;
  entry)      do_entry ;;
  wx)         do_wx ;;
  log)        shift; eng -v cmd=recent -v n="${1:-20}" ;;
  inspect)    do_inspect ;;
  job)        do_job ;;
  open)       eng -v cmd=defects ;;
  spares)     eng -v cmd=holdings ;;
  shopping)   shift; eng -v cmd=shopping -v port="${1:-}" ;;
  equip)      eng -v cmd=equip ;;
  part)       add_part ;;
  stocktake)  do_stocktake ;;
  correct)    do_correct ;;
  day|night|plain) cmode="$1"; save_conf; echo "  colour: $cmode" ;;
  about)      about_text ;;
  help|-h|--help) help_text ;;
  version)    echo "deck-log $DECKLOG_VERSION" ;;
  *) echo "  deck-log: no such command: $1"; help_text; exit 2 ;;
esac
