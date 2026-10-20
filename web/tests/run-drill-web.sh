#!/bin/sh
# Verify the drill app.
#
#   sh web/tests/run-drill-web.sh              against a synthetic pack
#   sh web/tests/run-drill-web.sh <pack.json>  against a real one
#
# The harness builds its own synthetic pack, so this test carries no
# material of anybody's -- which matters, because it lives in a public
# repository and the whole point of the app is that the material does
# not.
set -e
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"
trap '[ -n "$SRV" ] && kill $SRV 2>/dev/null || true' EXIT

if ! node -e 'require("playwright")' >/dev/null 2>&1; then
  echo "SKIPPED -- the drill suite is entirely a browser test and needs playwright:"
  echo "          npm i -D playwright"
  exit 0
fi

python3 web/tests/serve.py 8091 "$ROOT/web" >/dev/null 2>&1 &
SRV=$!
sleep 1
node web/tests/drill-ui.js "$@"
echo
echo "DRILL WEB: all checks passed"
