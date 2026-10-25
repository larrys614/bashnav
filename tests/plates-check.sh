#!/bin/sh
#  Every plate and picture the site shows must be what the program
#  actually produces, under the awk it is given.
#
#  WHY THIS WAS REWRITTEN.  It used to regenerate two plates and diff
#  them against ASCII blocks pasted by hand into the README - because
#  that is where they were, and because a hand-copied block drifts: the
#  colregs plate sat there for weeks saying "You are on her starboard
#  bow" after the program had started saying "broad on her starboard
#  bow", and without the note explaining why a sidelight is drawn aft of
#  the masts, which is the one thing a reader of that picture needs.
#
#  The README no longer pastes program output; it shows the SVGs that
#  docs/make-site.sh renders from the same output. So the property has
#  not changed - sample output must match the program - but the thing it
#  is checked against has. This now rebuilds the whole site with the
#  given awk and diffs docs/plates/ and docs/img/ against what is
#  committed. That covers all eight plates and all fifteen pictures
#  rather than the two the README happened to paste.
#
#  AND IT MAKES AWK-DEPENDENT SITE OUTPUT A FAILURE.  Running it per awk
#  found exactly that, on the first try: encounter.txt and scenario.txt
#  were generated from the colregs engine alone, which gawk and
#  one-true-awk accept and mawk refuses outright, and the awk sat at the
#  head of a pipeline where `set -e` could not see it fail. On a machine
#  whose awk is mawk, rebuilding the site blanked two front-page plates
#  and said nothing.
#
#  Like tests/ipad-install-check.sh, this compares against the COMMITTED
#  file rather than against what it just produced, because a harness that
#  tests its own output tests nothing. It therefore leaves a regenerated
#  site in the working tree, which is the same deal that check makes.
set -e
cd "$(dirname "$0")/.."
AW=${1:-awk}

if ! o=$(AWK="$AW" sh docs/make-site.sh 2>&1); then
  echo "  the site does not build under $AW:"
  printf '%s\n' "$o" | sed 's/^/    /' | head -12
  exit 1
fi

#  an empty or near-empty artefact is the failure make-site.sh is most
#  likely to have, and it now fails the build itself - but say so here
#  too, because this check runs under awks the author may never have
#  built the site with
printf '%s\n' "$o" | grep -q 'EMPTY ' && {
  printf '%s\n' "$o" | grep 'EMPTY ' | sed 's/^/    /'
  exit 1
}

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "PLATES SKIP"
  exit 0
fi

if git diff --quiet -- docs/plates docs/img; then
  echo "PLATES OK"
  exit 0
fi

echo "  built with $AW, these site artefacts are not what is committed:"
git diff --name-only -- docs/plates docs/img | sed 's/^/    /'
echo "  (regenerate with sh docs/make-site.sh and commit them, or find out why"
echo "   the program's output changed)"
exit 1
