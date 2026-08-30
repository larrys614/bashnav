#!/bin/sh
#  Build the single-file iPad installer from bin/.
#
#  The tools are carried as quoted heredocs, the same trick each tool
#  uses for its own awk engine.  Quoted, so nothing inside is expanded;
#  and every marker is checked against every payload first, because a
#  delimiter that appears in the data ends the heredoc early and the
#  result is a script that is silently half a tool.
set -e
cd "$(dirname "$0")/.."
OUT=${1:-release/bashnav-ipad.sh}
REL=$(cat release/VERSION)
TOOLS="celnav colregs tides deck-log weather bashnav"

./build.sh >/dev/null

for t in $TOOLS; do
  [ -f "bin/$t" ] || { echo "make-ipad: bin/$t is missing" >&2; exit 1; }
  fn=$(printf '%s' "$t" | tr -d '-')
  m="__BN_PAYLOAD_${fn}__"
  if grep -q "$m" "bin/$t"; then
    echo "make-ipad: the marker $m appears inside bin/$t" >&2; exit 1
  fi
done

mkdir -p "$(dirname "$OUT")"
{
  sed "s/__RELEASE__/$REL/" src/release/install-head.sh
  for t in $TOOLS; do
    fn=$(printf '%s' "$t" | tr -d '-')
    echo "extract_$fn() {"
    echo "  cat > \"\$DEST/$t\" <<'__BN_PAYLOAD_${fn}__'"
    cat "bin/$t"
    echo "__BN_PAYLOAD_${fn}__"
    echo "}"
  done
  cat src/release/install-tail.sh
} > "$OUT"

#  Stamp the file's own length into it.  The placeholder is exactly ten
#  __BYTES__ placeholder is nine characters and the number is zero
#  padded to nine, so the file
#  does not change size when the number goes in -- which is the only
#  reason the number can be right.
n=$(wc -c < "$OUT" | tr -d ' ')
pad=$(printf '%09d' "$n")   # __BYTES__ is nine characters wide
sed "s/^BASHNAV_BYTES=__BYTES__$/BASHNAV_BYTES=$pad/" "$OUT" > "$OUT.tmp"
mv "$OUT.tmp" "$OUT"
m=$(wc -c < "$OUT" | tr -d ' ')
[ "$m" = "$n" ] || { echo "make-ipad: stamping changed the size ($n -> $m)" >&2; exit 1; }
grep -q "^BASHNAV_BYTES=$pad\$" "$OUT" || { echo "make-ipad: the byte count was not stamped" >&2; exit 1; }
chmod +x "$OUT"

sh -n "$OUT" || { echo "make-ipad: the installer does not parse" >&2; exit 1; }
ls -l "$OUT"
