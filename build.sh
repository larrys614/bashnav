#!/bin/sh
# Build the single-file tools from src/ into bin/.
set -e
cd "$(dirname "$0")"
mkdir -p bin

build_decklog() {
  out=bin/deck-log
  {
    cat src/decklog/10-head.sh
    echo ''
    echo '# ---- engine extraction (written once, then reused) -----------------'
    echo 'install_engine() {'
    echo '  if [ -f "$ENGINE" ]; then'
    echo '    [ "$1" = force ] || { [ -f "$0" ] && [ "$0" -nt "$ENGINE" ] 2>/dev/null; } || return 0'
    echo '  fi'
    echo '  mkdir -p "$DECKLOG_HOME" 2>/dev/null || {'
    echo '    echo "deck-log: cannot create $DECKLOG_HOME" >&2; exit 1; }'
    echo '  cat > "$ENGINE" <<'"'"'__DECKLOG_ENGINE__'"'"''
    cat src/common/log.awk
    cat src/common/colour.awk
    cat src/decklog/views.awk
    cat src/decklog/screens.awk
    echo '__DECKLOG_ENGINE__'
    echo '}'
    cat src/decklog/25-about.sh
    cat src/decklog/30-ui.sh
  } > "$out"
  chmod +x "$out"
}

build_weather() {
  out=bin/weather
  {
    cat src/weather/10-head.sh
    echo ''
    echo '# ---- engine extraction (written once, then reused) -----------------'
    echo 'install_engine() {'
    echo '  if [ -f "$ENGINE" ]; then'
    echo '    [ "$1" = force ] || { [ -f "$0" ] && [ "$0" -nt "$ENGINE" ] 2>/dev/null; } || return 0'
    echo '  fi'
    echo '  mkdir -p "$WEATHER_HOME" 2>/dev/null || {'
    echo '    echo "weather: cannot create $WEATHER_HOME" >&2; exit 1; }'
    echo '  cat > "$ENGINE" <<'"'"'__WEATHER_ENGINE__'"'"''
    cat src/common/log.awk
    cat src/common/colour.awk
    cat src/weather/wx.awk
    cat src/weather/score.awk
    cat src/weather/chart.awk
    cat src/weather/teach.awk
    cat src/weather/screens.awk
    echo '__WEATHER_ENGINE__'
    echo '}'
    cat src/weather/25-about.sh
    cat src/weather/30-ui.sh
  } > "$out"
  chmod +x "$out"
}

build_celnav() {
  out=bin/celnav
  {
    cat src/celnav/10-head.sh
    echo ''
    echo '# ---- engine extraction (written once, then reused) -----------------'
    echo 'install_engine() {'
    echo '  if [ -f "$ENGINE" ] && [ -f "$TEACH" ]; then'
    echo '    [ "$1" = force ] || { [ -f "$0" ] && [ "$0" -nt "$ENGINE" ] 2>/dev/null; } || return 0'
    echo '  fi'
    echo '  mkdir -p "$CELNAV_HOME" 2>/dev/null || {'
    echo '    echo "celnav: cannot create $CELNAV_HOME" >&2; exit 1; }'
    echo '  cat > "$ENGINE" <<'"'"'__CELNAV_ENGINE__'"'"''
    cat src/celnav/engine.awk
    echo '__CELNAV_ENGINE__'
    echo '  cat > "$TEACH" <<'"'"'__CELNAV_TEACH__'"'"''
    cat src/celnav/teach.awk
    echo '__CELNAV_TEACH__'
    echo '}'
    cat src/common/20-about.sh
    cat src/celnav/25-about.sh
    cat src/celnav/30-ui.sh
  } > "$out"
  chmod +x "$out"
}

build_colregs() {
  out=bin/colregs
  {
    cat src/colregs/10-head.sh
    echo ''
    echo '# ---- engine extraction (written once, then reused) -----------------'
    echo 'install_engine() {'
    echo '  if [ -f "$ENGINE" ] && [ -f "$CONTACTS" ] && [ -f "$REVIEW" ]; then'
    echo '    [ "$1" = force ] || { [ -f "$0" ] && [ "$0" -nt "$ENGINE" ] 2>/dev/null; } || return 0'
    echo '  fi'
    echo '  mkdir -p "$COLREGS_HOME" 2>/dev/null || {'
    echo '    echo "colregs: cannot create $COLREGS_HOME" >&2; exit 1; }'
    echo '  cat > "$ENGINE" <<'"'"'__COLREGS_ENGINE__'"'"''
    cat src/colregs/engine.awk
    echo '__COLREGS_ENGINE__'
    echo '  cat > "$CONTACTS" <<'"'"'__COLREGS_CONTACTS__'"'"''
    cat src/colregs/contacts.awk
    echo '__COLREGS_CONTACTS__'
    echo '  cat > "$REVIEW" <<'"'"'__COLREGS_REVIEW__'"'"''
    cat src/colregs/review.awk
    echo '__COLREGS_REVIEW__'
    echo '}'
    cat src/common/20-about.sh
    cat src/colregs/25-about.sh
    cat src/colregs/26-review.sh
    cat src/colregs/30-ui.sh
  } > "$out"
  chmod +x "$out"
}


build_tides() {
  out=bin/tides
  {
    cat src/tides/10-head.sh
    echo ''
    echo '# ---- data extraction (written once, then reused) -------------------'
    echo 'extract_data() {'
    echo '  cat > "$TABLES" <<'"'"'__TIDES_TABLES__'"'"''
    cat src/tides/tables.awk
    echo '__TIDES_TABLES__'
    echo '  cat > "$ENGINE" <<'"'"'__TIDES_ENGINE__'"'"''
    cat src/tides/engine.awk
    echo '__TIDES_ENGINE__'
    echo '  [ "$ISTTY" = 1 ] && printf "extracting the station data, once ... " >&2'
    echo '  cat > "$STATIONS" <<'"'"'__TIDES_STATIONS__'"'"''
    cat src/tides/stations.dat
    echo '__TIDES_STATIONS__'
    echo '  [ "$ISTTY" = 1 ] && echo "done" >&2'
    echo '  return 0'
    echo '}'
    cat src/tides/30-ui.sh
  } > "$out"
  chmod +x "$out"
}

build_celnav
build_colregs
build_tides
build_decklog
build_weather
ls -l bin/
