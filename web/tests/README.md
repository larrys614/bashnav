# web/tests — verifying the browser builds

`tests/run-tests.sh` in the repository root is POSIX `sh` and POSIX `awk`
and nothing else, so it runs on the boat. These do not: they need `node`,
`python3` and a headless Chromium, so they run on a development machine
before a push and are deliberately kept out of that suite.

    sh web/tests/run-tides-web.sh            a quick pass, 9 stations
    sh web/tests/run-tides-web.sh --full     615 stations x 4 dates
    sh web/tests/run-decklog-web.sh          the record layer and the page

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


---

# deck-log

The log is append-only and **shared** with the awk build: the same file,
byte for byte, not two formats that look alike. A record one tool writes
that the other cannot read is permanent damage, discovered months later
by something trying to read it. So the record layer is checked in both
directions before anything else.

| | |
|---|---|
| `decklog-rt.awk` / `.js` | awk writes, JS reads; JS writes, awk reads; byte for byte |
| `decklog-views.awk` / `.js` | holdings and open defects over generated logs, up to 100,000 records |
| `decklog-imp.awk` | the plausibility limits *and their wording*, over the whole numeric range |
| `decklog-merge.js` | commutative, idempotent, lossless, conflicts kept |
| `decklog-ui.js` | a real entry made through the page, exported, read back by the awk tool |

## The corpus travels as hex

`decklog-rt.awk` emits its awkward values, and the records built from
them, as **hex**. Carrying them in any text encoding would mean the test
sharing a mechanism with the thing it is testing, and a bug in the
escaping would cancel out and pass. It is not hypothetical: an earlier
version used a tab-separated dump, and the one case whose value is a
literal tab split the record in half — the harness sharing a delimiter
with its own payload, which is the same class of bug the log format
exists to prevent.

## Two faults these found

**The confirmation was wiped by the redraw.** `commitSection` set the
message and then called `drawSection()`, which overwrote it with its own
"already logged" note — so the one message this tool most needs to
deliver, that you have just used your last impeller and are short of
your minimum, was destroyed on the way to the screen.

**The parts catalogue was invented.** An earlier `views.js` shipped
twelve plausible spares and an eighteen-item checklist written from the
specification's prose rather than from the tool. The checklist was not
the tool's checklist and the catalogue did not exist in the tool at all.
Both now come from `gen/make-decklog-web.sh`, which dumps them.

## A generated corpus can throw itself away

The 100,000-record run first reported `22176 good, 77824 bad` and still
*passed*, because both readers correctly rejected the same malformed
timestamps: the generator's month field ran past 12 after day 336 and
produced `2026-447-01T00:00Z`. A diff between two readers cannot notice
that three quarters of its corpus is being discarded by both of them.
Check the counts, not only the agreement.
