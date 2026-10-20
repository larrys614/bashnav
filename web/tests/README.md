# web/tests — verifying the browser builds

`tests/run-tests.sh` in the repository root is POSIX `sh` and POSIX `awk`
and nothing else, so it runs on the boat. These do not: they need `node`,
`python3` and a headless Chromium, so they run on a development machine
before a push and are deliberately kept out of that suite.

    sh web/tests/run-tides-web.sh            a quick pass, 9 stations
    sh web/tests/run-tides-web.sh --full     615 stations x 4 dates

## The method

Nothing here checks the browser build against a number somebody typed in.
Every reference value is **emitted by running the awk engine**, and the
harness loads the **shipped** files under `web/tides/`, so a stale copy
cannot pass.

| | |
|---|---|
| `tides-ref.awk`  | dumps the awk engine's own values at full double precision |
| `tides-diff.js`  | the same quantities out of the JS engine, compared |
| `tides-ui.js`    | drives the page and checks what it *shows* against `tides today` |
| `tides-moon.js`  | re-draws the moon path into a canvas and counts the lit pixels |
| `serve.py`       | a static server that honours `Range`, which Python's own does not |

## Why the page is tested and not only the engine

The engine diff passed, over nine hundred thousand values, while the page
was visibly wrong: it predicted the **UT** day and then labelled it in the
station's time, so at Newport the previous evening's low water sat at the
top of the table and the whole curve was shifted fifteen columns. A tide
day is the station's own standard day — `jdA = jd0 - tz/1440` — and both
sides of a module diff happily used UT midnight.

A module diff proves the physics. Only driving the page proves the wiring.

## Tolerances

Set by what each quantity *means*, not by what the port happens to
achieve: a millisecond on a tide time, a nanometre on a tide height. awk
uses the platform's libm for `sin`, `cos`, `atan2`, `exp` and `log` and V8
uses its own, so the last bit or two differ and bit-equality is the wrong
test. In practice heights agree to about a femtometre and the turning
times are exact.

An earlier run reported two failures at exactly half the dump's own print
quantum — 43 ms is half of `%.12e` on a Julian Date of 2.46 million. The
fix was to dump full double precision, not to loosen the tolerance.
