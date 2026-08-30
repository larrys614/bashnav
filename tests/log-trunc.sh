#!/bin/sh
#  The iPad test.  a-Shell is suspended, the battery dies, or the app is
#  killed mid-write, and the last line is half on disk.  Every record
#  before it must still come back, and the damaged tail must be reported
#  rather than silently swallowed.
#
#  Truncate a good log at EVERY byte offset inside its final record.
set -e
cd "$(dirname "$0")/.."
AW=${1:-awk}
d=$(mktemp -d); trap 'rm -rf "$d"' EXIT
cat > "$d/log" <<'LOG'
2026-08-30T12:00Z|nav|lat=41.233|lon=-72.083|crs=096|sog=8.5|~
2026-08-30T15:00Z|wx|mslp=1013.2|ptend=3|note=squall to the west|~
2026-08-30T18:00Z|eng|job=impeller|part=impeller-jabsco|qty=1|note=last one|hrs=1234.5|~
LOG
#  NOTE: the probe goes in a file and is passed with -f.  Mixing -f with
#  an inline 'BEGIN{...}' makes the inline text a FILENAME, so awk looks
#  for a file called "BEGIN{...}", finds nothing, and exits 0 having run
#  nothing at all.  Silently.  That bug made an earlier version of this
#  script report success while testing precisely nothing.
cat > "$d/probe.awk" <<'PROBE'
BEGIN{ n=lg_read(F,""); nf=0; if(n>0 && lg_at(n)) nf=LG_NF
       printf "%d %d %d\n", LG_GOOD, LG_BAD, nf }
PROBE
full=$(wc -c < "$d/log"); lastn=$(tail -1 "$d/log" | wc -c)
head=$(( full - lastn ))
fail=0; n=0; whole=0; i=1
while [ "$i" -lt "$lastn" ]; do
  dd if="$d/log" of="$d/cut" bs=1 count=$(( head + i )) 2>/dev/null
  r=$($AW -f src/common/log.awk -f "$d/probe.awk" -v F="$d/cut" </dev/null)
  #  an empty answer means the probe never ran - fail loudly, do not skip
  case "$r" in
    [0-9]*" "[0-9]*" "[0-9]*) ;;
    *) echo "  FAIL at +$i: the probe produced no output ([$r])"; fail=1; i=$(( i + 1 )); continue ;;
  esac
  set -f; set -- $r; set +f
  g=$1; nf=$3
  #  The property that matters is NOT "the last record is always
  #  rejected" - once the terminator has been written the record really
  #  is complete, and only the newline is missing.  It is:
  #
  #      no truncation ever yields a record that parses as good while
  #      missing fields.
  #
  #  So: either the partial record was refused (2 good), or it was
  #  accepted and it is whole (3 good, and all 5 of its fields present).
  if [ "$g" -eq 2 ]; then
    :
  elif [ "$g" -eq 3 ] && [ "$nf" -eq 5 ]; then
    whole=$(( whole + 1 ))
  else
    echo "  FAIL truncated at +$i: $g good records, last has $nf fields (wanted 2, or 3 with 5)"
    fail=1
  fi
  n=$(( n + 1 )); i=$(( i + 1 ))
done
[ "$n" -gt 0 ] || { echo "  FAIL: no offsets were actually tested"; fail=1; }
[ "$fail" = 0 ] && echo "TRUNC OK ($n offsets: partial refused at $(( n - whole )), complete-but-unterminated accepted whole at $whole)"
exit $fail
