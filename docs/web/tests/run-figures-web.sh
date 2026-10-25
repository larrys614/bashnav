#!/bin/sh
# Verify the site's pictures are still what the browser apps draw.
#
#   sh docs/web/tests/run-figures-web.sh
#
# The pictures on the front page are the apps' OWN SVG, captured out of
# the running page by docs/web/gen/make-app-figures.sh. Like everything
# else here it needs node, python3 and a headless Chromium, so it is not
# part of tests/run-tests.sh - that suite checks the committed files and
# asserts Rule 27(f) in the day-shape figure, with no browser.
#
# This is the regenerate-and-compare half: capture again and diff against
# what is committed, so a change to any app's drawing shows up as a
# changed picture rather than as a page that has quietly stopped matching
# the app it is advertising.
set -e
ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
cd "$ROOT"

if ! node -e 'require("playwright")' >/dev/null 2>&1; then
  echo "SKIPPED -- the figure capture needs playwright:  npm i -D playwright"
  exit 0
fi
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "SKIPPED -- comparing the figures needs a git checkout"
  exit 0
fi

sh docs/web/gen/make-app-figures.sh

if git diff --quiet -- docs/img/app; then
  echo
  echo "FIGURES: every picture is what the apps draw"
else
  echo
  echo "  these pictures are no longer what the apps draw:"
  #  SAY HOW BIG THE CHANGE IS, because a screenshot diff has two very
  #  different meanings and `git diff --name-only` cannot tell them apart.
  #  A changed screen moves a picture by kilobytes. A re-render of the
  #  same screen can move it by a few dozen bytes: the launcher came back
  #  69 pixels different out of 773,140, maximum channel delta 71, which
  #  is font antialiasing and nothing else - it went away on the next
  #  three captures and was visually identical under a crop. Both read as
  #  "no longer what the apps draw" without these two numbers.
  git diff --name-only -- docs/img/app | while read -r f; do
    new=$(wc -c < "$f" | tr -d ' ')
    old=$(git show "HEAD:$f" 2>/dev/null | wc -c | tr -d ' ')
    [ -n "$old" ] && [ "$old" != 0 ] || old='-'
    printf '    %-34s committed %8s bytes, now %8s\n' "$f" "$old" "$new"
  done
  echo "  (if the change is intended, commit them; if not, the app changed"
  echo "   under you and the page is advertising something else. A difference"
  echo "   of a few dozen bytes in a .png is antialiasing - look at the two"
  echo "   pictures before believing the app changed.)"
  exit 1
fi
