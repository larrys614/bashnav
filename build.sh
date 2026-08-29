#!/bin/sh
# Build the single-file tools from src/ into bin/.
set -e
cd "$(dirname "$0")"
mkdir -p bin

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

build_celnav
build_colregs
ls -l bin/
