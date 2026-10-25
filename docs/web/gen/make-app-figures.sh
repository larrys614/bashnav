#!/bin/sh
# Capture the site's pictures from the browser apps themselves.
#
#   sh docs/web/gen/make-app-figures.sh
#
# The site showed thirteen ansi2svg renderings - the TERMINAL's characters
# drawn as SVG. That was right while the shell build was the product; the
# page leads with the browser apps now, so the pictures are the apps' own
# drawings, lifted out of the running page.
#
# This needs node, python3 and a headless Chromium, like everything under
# docs/web/tests/, so it is NOT part of tests/run-tests.sh and is run on a
# development machine before a push. The suite checks the committed files
# are valid and referenced; docs/web/tests/run-figures-web.sh regenerates
# them and diffs.
#
# The terminal plates are NOT retired: each figure keeps its collapsed
# "the same thing, as your terminal prints it" block, which is the shell
# build's real output and says so.
set -e
ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
cd "$ROOT"
PORT=${PORT:-8731}

if ! node -e 'require("playwright")' >/dev/null 2>&1; then
  echo "SKIPPED -- capturing the app figures needs playwright:  npm i -D playwright"
  exit 0
fi

python3 docs/web/tests/serve.py "$PORT" "$ROOT/docs/web" >/dev/null 2>&1 &
SRV=$!
trap 'kill $SRV 2>/dev/null || true' EXIT
sleep 1

PORT="$PORT" node docs/web/gen/app-figures.js

#  A recapture that differs only by font antialiasing is not a change, and
#  leaving it in the working tree makes tests/plates-check.sh red on
#  pictures that are correct. See figures-putback.sh for the numbers.
sh docs/web/gen/figures-putback.sh
