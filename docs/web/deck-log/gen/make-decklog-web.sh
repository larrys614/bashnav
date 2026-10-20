#!/bin/sh
# Regenerate docs/web/deck-log/menus.js from src/decklog/.
#
# The VOS menus and the eighteen-point engine checklist are DUMPED from
# the tool's own tables, never retyped. An earlier draft of views.js
# carried a checklist I had written from memory of the specification --
# eighteen plausible items that were not the eighteen items the tool
# actually uses. It would have looked right on screen for years.
#
# Run from the repository root:  sh docs/web/deck-log/gen/make-decklog-web.sh
set -e
ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
SRC="$ROOT/src/decklog"
#  The engine is assembled exactly as build.sh assembles it, from
#  src/common/log.awk and src/common/colour.awk plus the decklog files.
#  Note that src/decklog/log.awk is a byte-identical DUPLICATE of
#  src/common/log.awk that the build does not use.
OUT="$ROOT/web/deck-log/menus.js"

AWK=awk
for a in mawk gawk awk; do command -v "$a" >/dev/null 2>&1 && { AWK=$a; break; }; done

#  The dumper goes FIRST so its BEGIN block runs before screens.awk's own
#  dispatch, and it writes to a named file so that dispatch cannot print
#  over the top of it.
"$AWK" -v OUTF="$OUT" \
   -f "$ROOT/web/deck-log/gen/dumpmenus.awk" \
   -f "$ROOT/src/common/log.awk" -f "$ROOT/src/common/colour.awk" \
   -f "$SRC/views.awk" -f "$SRC/screens.awk" \
   </dev/null >/dev/null 2>&1 || true
[ -s "$OUT" ] || { echo "make-decklog-web: the menu dump is empty" >&2; exit 1; }

#  The checklist is a shell variable in 30-ui.sh, so it is lifted from
#  there by the same rule: extracted, not retyped.
CL=$(sed -n 's/^CHECKLIST="\(.*\)"$/\1/p' "$SRC/30-ui.sh")
[ -n "$CL" ] || { echo "make-decklog-web: CHECKLIST not found in 30-ui.sh" >&2; exit 1; }
printf 'var CHECKLIST = [' >> "$OUT"
printf '%s' "$CL" | tr ';' '\n' | $AWK -F: '
  { printf "%s[%c%s%c, %c%s%c]", (NR>1 ? ", " : ""), 39, $1, 39, 39, $2, 39 }
' >> "$OUT"
printf '];\n' >> "$OUT"
printf "if (typeof module !== 'undefined') module.exports = { MENUS: MENUS, MENU_ORDER: MENU_ORDER, CHECKLIST: CHECKLIST };\n" >> "$OUT"

echo "menus.js  $(wc -c < "$OUT" | tr -d ' ') bytes"
"$AWK" 'BEGIN{}' </dev/null
node -e '
var m = require(process.argv[1]);
console.log("  menus     " + m.MENU_ORDER.length + "  (" + m.MENU_ORDER.join(", ") + ")");
console.log("  checklist " + m.CHECKLIST.length + " items");
' "$OUT"
