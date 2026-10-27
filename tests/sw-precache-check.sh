#!/bin/sh
#  Does each web tool's service worker cache everything its page loads?
#
#  THE OFFLINE PROMISE IS THE PRODUCT. These tools exist to work on a
#  boat with no signal, and the worker is cache-first precisely so that
#  nothing is fetched at sea. A file the page loads and the worker does
#  not precache is fetched from the network on first use: fine at the
#  dock, and on passage it is a stylesheet that never arrives or a
#  script whose absence takes a section of the app with it.
#
#  Nothing checked this. It is being written on 23 October 2026 because
#  the contacts module adds three scripts to colregs' page at once and I
#  was about to rely on remembering to add them in two places; the same
#  gap is open on all six tools and on the launcher.
#
#  Two things are compared, per tool:
#    1. every local script and stylesheet the page references is in the
#       worker's FILES list;
#    2. every file the FILES list names exists on disk, so a rename
#       cannot leave the worker precaching a 404 -- addAll() rejects as
#       a unit, so ONE missing entry means the tool caches NOTHING and
#       is online-only everywhere.
set -e
cd "$(dirname "$0")/.."
rc=0

for sw in docs/web/sw.js docs/web/*/sw.js; do
  [ -f "$sw" ] || continue
  dir=$(dirname "$sw")
  page="$dir/index.html"
  [ -f "$page" ] || continue
  name=$(basename "$dir")
  [ "$name" = web ] && name=launcher

  #  the worker's list, one per line, './x' -> 'x'
  #
  #  NOT  sed -n 's|^\./||p' :  -n with p prints only the lines the
  #  substitution MATCHED, so every entry without a leading './' was
  #  dropped from the list entirely and then reported as not precached.
  #  Found the day weather's page started loading '../shared/demo.css',
  #  which the worker precached correctly and this check could not see.
  #
  #  And dropping the -n alone is not the fix either: that filter was
  #  doing double duty, stripping './' AND discarding the tokens around
  #  the array - const, FILES, =, [, ]; - which then arrived in the
  #  existence loop as files that are not there. So the quoted strings are
  #  taken deliberately instead of being whatever survives a tr.
  files=$(sed -n '/^const FILES/,/\];/p' "$sw" \
          | grep -o "'[^']*'" | tr -d "'" | sed 's|^\./||' | sed '/^$/d')

  #  what the page actually loads, local only: a CDN is not our problem
  #  and there are none, but a check that ignores the distinction would
  #  report one as missing the day somebody adds it
  refs=$(sed -n 's/.*<script[^>]*src="\([^"]*\)".*/\1/p;s/.*<link[^>]*href="\([^"]*\)".*/\1/p' "$page" \
         | grep -v '^http' | grep -v '^//' | sed 's|^\./||')

  for r in $refs; do
    case "$r" in *.webmanifest|*.svg|*.png|*.ico) ;; esac
    if ! printf '%s\n' "$files" | grep -qx "$r"; then
      echo "  FAIL  $name: index.html loads $r, sw.js does not precache it"
      rc=1
    fi
  done

  #  the offline fallback has to name something this worker precaches,
  #  or the one page a visitor sees with no signal is the browser's
  #  error page. They agree today on all seven; nothing said so.
  fb=$(grep -o "caches.match('[^']*')" "$sw" | tail -1 | sed "s|.*('\./\{0,1\}||;s|').*||")
  if [ -n "$fb" ] && ! printf '%s\n' "$files" | grep -qx "${fb:-/}"; then
    if [ "$fb" != "" ] && [ "$fb" != "/" ]; then
      echo "  FAIL  $name: the offline fallback serves $fb, which sw.js does not precache"
      rc=1
    fi
  fi

  for f in $files; do
    case "$f" in ''|./) continue ;; esac
    if [ ! -e "$dir/$f" ]; then
      echo "  FAIL  $name: sw.js precaches $f, which is not there (addAll fails as a unit:"
      echo "        one missing entry and the tool caches nothing at all)"
      rc=1
    fi
  done
done

[ "$rc" = 0 ] && echo "  ok    every web tool precaches everything its page loads, and nothing it has not got"
exit $rc
