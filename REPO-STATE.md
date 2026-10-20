# Repository state

Last updated 2026-10-20. Published at
**https://github.com/larrys614/bashnav**.

New here? Start with [`CLAUDE.md`](CLAUDE.md), then
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md),
[`docs/HACKING.md`](docs/HACKING.md) and
[`docs/TESTING.md`](docs/TESTING.md).

---

## Versions

| tool | version | size | what it is |
|---|---|---|---|
| `bin/celnav` | 1.6 | 153 KB | celestial navigation: almanac, sight reduction, plotting, fix, and a teaching track |
| `bin/colregs` | 1.15 | 175 KB | rules of the road: lights, shapes, sounds, encounters, collision-avoidance scenarios, contact management, and an interactive review |
| `bin/tides` | 1.1 | 2.9 MB | harmonic tide prediction, 8,334 stations worldwide |
| `bin/deck-log` | 1.1 | 42 KB | the boat's records &mdash; deck, engine, provisions &mdash; append-only in UTC, spares derived by replaying the log |
| `bin/weather` | 1.0 | 67 KB | reasons over the log's observations and shows its working; ten lessons; forecast scoring |
| `bin/bashnav` | 1.0 | 3.4 KB | the launcher: a menu in front of the other five, and one home-screen icon on an iPad |

Licence **Apache 2.0** (`LICENSE`, canonical text). `NOTICE` carries the
copyright plus the data terms: NOAA harmonics public domain, TICON-4 harmonics
CC BY 4.0. **The CC BY obligation travels with the data** regardless of the
code licence.

---

## Decisions taken, and why

**Apache 2.0, not MIT.** Commercial use is welcome; the patent grant and the
explicit warranty disclaimer are what a navigation tool needs.

**One repository, site included.** One thing to maintain, one URL.

**The site is generated from real output.** `docs/make-site.sh` runs the tools
and drops their actual output into the page, so the site cannot drift from
what the programs do. Same for the README pictures, via `docs/ansi2svg.awk`.

**Contributors opt in, name only.** `CONTRIBUTORS.md`. The review session
never asks for an email address, and there is a test that it does not.

**The COLREGs content is a training aid and says so** — in `colregs about`, in
`SAFETY.md`, and on the site. Where the program and the Convention differ, the
Convention governs.

**Pick a station, not a place.** A tide cannot be computed from a position.

**No tidal current data.** *Decided 2026-08-29.* NOAA publishes 4,430
current-prediction stations with harmonic constants and the same
reference/subordinate structure the heights use — but **US waters only**.
TICON, which gives the height data worldwide coverage, is heights. Larry's
call: US-only coverage makes it a no. Worldwide is the point of carrying the
tool at all.

---

## The browser build: all six tools

*Closed 20 Oct 2026.* `docs/web/` now carries the launcher and all six tools.
a-Shell proved a dead end for colour and for running a script by path, so the
iPad gets the browser build and the shell suite is for Mac and Linux.

| | |
|---|---|
| `docs/web/celnav/` | camera sight: an altitude from a photograph |
| `docs/web/colregs/` | lights, shapes, sounds, the rules |
| `docs/web/tides/` | harmonic prediction, all 8,334 stations |
| `docs/web/deck-log/` | the boat's records, append-only in IndexedDB |
| `docs/web/weather/` | read your own barometer |
| `docs/web/drill/` | a study machine, shipped with no material in it |

### Replacing a pack with a file of the same name

*Fixed 20 Oct 2026, and it is the fault that caused the other three.*

A file input fires `change` only when the selection **changes**, and a file
counts as the same selection if it has the same **name**. The input's value
was never cleared, so after loading `procedures.drillpack.json` once,
picking another file of that name did nothing at all: no error, no note,
the old pack simply stayed. From the outside the app appeared to offer no
way to replace a pack.

Every pack a builder produces tends to have the same filename, so this hit
on the second pack and every pack after it. Five bug reports in one morning
were questions that had already been removed, read out of a pack that could
not be replaced.

`f-pack.value` is now cleared after every attempt, so the next selection is
always a change. Replace also prints which pack is loaded now, so replacing
it is a deliberate act with a checkable result. The harness covers it, and
the check was confirmed to fail with the one line reverted.

The lesson is the one the service worker already taught in this same tool:
**a fix that cannot be identified from the outside is not delivered.** Three
things now carry a readable identity -- the app (`build N`, matched to
`drill-vN`), the pack (`built` and `id`, on the home screen), and the file
(`procedures-<id>.drillpack.json`, from the builder).

### The home screen says which pack is loaded

*Added 20 Oct 2026.* Loading a pack replaces the one in the browser's
storage, and nothing on screen said which one was being drilled. A rebuilt
pack therefore looked identical to the one it replaced, and a question
reported as fixed came round again from the old pack -- four times in one
morning, each time read as the fix not having worked.

The home screen now shows the pack's `built` date and a short content
digest, `id`, which the builder sets. The date alone is not enough:
rebuilding twice in a morning is the normal case while the questions are
being worked on.

Two test assertions were wrong and were corrected with it. The reveal check
asked whether the FIRST question's answer was on screen while the practice
loop had moved on to another, and both it and the leak check searched
`innerHTML` for raw answer text, which an answer containing `&` or `<` can
never match -- so a leak could have been reported as absent.

### Ordering questions: put these in order, one does not belong

*Added 20 Oct 2026.* A four-option question can test which step **belongs**.
It cannot test that you know the **order** without naming a position, and
"what is number four" asks about the layout of the page rather than the
procedure -- nobody in the water recalls item four, they recall what to do
once their head is out of the water.

So a question may instead carry `seq`, the steps in their correct order, and
`extra`, at least one step from a different procedure. The app offers them
scrambled; you tap them into order and leave the intruder alone. Marked all
or nothing: partial credit would make a near miss on a sequence look like
competence, and on a MOB chain a near miss is a different outcome.

Refused at load, because none of these can be seen while drilling: fewer
than three steps, the same step listed twice, no intruder at all, or an
intruder that is also one of the real steps -- which would mark you wrong
for leaving out a step that genuinely belongs.

`CACHE` is `drill-v3` and `BUILD` is `3`; the harness still asserts they
agree. The harness also learned to drive an ordering question, which it
needed: the drive loops click `.choice`, an ordering question has none, and
without that the suite would have stopped covering the graded test the
moment a pack contained one -- silently, because the loop would simply find
nothing to click.

### A drill question may carry its own wrong options

*Added 20 Oct 2026.* `drill` builds a test's four options from the other
answers in the same section, preferring ones of the same `kind`. That holds
while the answers are mutually exclusive and fails when they are not: *which
of these is on the hoist preparation checklist?* can draw three more items
off the same checklist, and offer four right answers against one mark.

A question may now carry `ch` -- exactly three wrong options -- and when it
does the app uses those and its own answer, and nothing from the pool.
Two rules are enforced when a pack loads, because neither failure is visible
while drilling: a wrong option equal to the answer is a question with two
right options, and a repeated wrong option is three options wearing four
labels.

**`sw.js` had to change with it, and that is the part worth remembering.**
The worker is cache-first, so an installed copy keeps serving the `drill.js`
it cached, and a browser only reinstalls a worker when `sw.js` itself
changes. A fix shipped without touching `sw.js` reaches nobody who has
already used the tool, and to them it looks as though the fix did not work.
`CACHE` is now `drill-v2`, `BUILD` is `2`, and `run-drill-web.sh` asserts
the two agree -- so bumping the cache is checked rather than remembered.

The app still ships with no material in it. What uses `ch` is the pack,
which is built outside this repository and stays on Larry's own machines.

### Where the site lives, and why `docs/web/`

*Moved 20 Oct 2026.* GitHub Pages is set to **`main` → `/docs`**, which makes
`docs/` the root of the website and everything above it unpublished. The browser
build used to sit at `web/` in the repository root, so Pages never served it:
the three links to it from `docs/index.html` were 404s, and so was every tool.

Moving it to `docs/web/` fixes that without changing a single URL, because
`docs/` *is* the site root — the tools are still at
`https://larrys614.github.io/bashnav/web/<tool>/`. That matters more than it
sounds: the origin and path are what a service worker caches under, what
IndexedDB keys on, and what an Add-to-Home-Screen icon points at. A layout that
changed the URL would have orphaned every installed icon and every stored log.

What it impacts, and what had to change with it:

- The harnesses in `docs/web/tests/` walk up to the repository root to reach
  `src/`, so each gained a level: `../..` became `../../..`. The tides harness
  caught this itself by failing to find `stations.dat`.
- `docs/web/tides/gen/mkindex.py` and the three `gen/make-*-web.sh` scripts
  write into the build, so their output paths gained the `docs/` prefix.
- `docs/.nojekyll` stops Pages running Jekyll over 112 static files that need
  no rendering. Before the move, Jekyll was building the landing page out of
  `README.md` and serving it under its default theme — which is why the
  published front page was a plain white Markdown render rather than the
  designed site in `docs/index.html`.
- `CLAUDE.md`'s staging example is now `git add docs/ src/`, since `web/` is no
  longer a top-level directory.

The deliberate consequence: a file is published only if it is under `docs/`.
`src/`, `bin/`, `tests/` and `release/` are not served, and moving something
into `docs/` is now an explicit act rather than a side effect.

`deck-log` and `weather` **share one log**: both are served from this origin,
and IndexedDB is per-origin rather than per-path, so they genuinely share one
store. A service worker's *scope* is per-path, though, which is why
`weather/log.js` and `weather/store.js` are byte-identical copies rather than
loaded from `../deck-log/` — out of scope they would not be cached and the tool
would not work offline, which is the entire point.

### How the browser builds are verified

`tests/run-tests.sh` stays POSIX `sh` and `awk` so it runs on the boat. The
browser suites need `node`, `python3` and a headless Chromium, so they live in
`docs/web/tests/` and are run before a push:

    sh docs/web/tests/run-tides-web.sh [--full]
    sh docs/web/tests/run-decklog-web.sh
    sh docs/web/tests/run-weather-web.sh

Nothing in them is checked against a number somebody typed. Every reference
value is **emitted by running the awk engine**, and the harnesses load the
**shipped** files under `docs/web/`, so a stale copy cannot pass. The browser
stages skip themselves with a message when playwright is absent rather than
failing.

**A module diff proves the physics; only driving the page proves the wiring.**
The tides engine agreed with the awk over 955,255 values while the page was
visibly wrong — it predicted the UT day and labelled it in the station's time,
so at Newport the previous evening's low water sat at the top of the table.
Both sides of a module diff happily used UT midnight.

### Three faults in the shipped tools, found by those diffs

1. **`deck-log` was completely dead under mawk 1.3.3.** See the loose end
   below; this is the serious one.
2. **`weather` never scored the user.** `do_forecast` wrote `by=user` while
   the score sheet's three names are `you rules persist`, so the one column
   the learning loop exists for was accumulated and never printed.
3. **`colregs`' `about` still said twenty vessels** after the WIG craft and
   the submarine took the tables to 22, and the give-way calls to 73. That one
   `run-tests.sh` was already reporting.

### And two in the harnesses, the same mistake twice

A generated corpus can throw itself away and still pass, because both readers
reject the same bad input. The 100,000-record deck-log run reported *22,176
good, 77,824 bad* and passed; the valid-time check reported 276 round-trip
failures, which is exactly the number of impossible dates in 2000–2040.
**Check the counts, not only the agreement.**

---

## Next: set and drift

*Agreed 2026-08-29. Designed, not built.* Lives **in `tides`**.

Larry's framing, and he is right about the priority: the daily navigational
problem underway is not clearance under a bridge, it is what the water is
doing to you and what to steer to allow for it. The README claimed "the two
questions a tide table is actually for — is there enough water, and does the
mast clear the bridge". That was a tidy pair rather than an honest ranking,
and it has been corrected.

**The module needs no flow data at all**, which is why the decision above
costs nothing. Both halves are vector geometry:

1. **Measuring set and drift.** Run a DR from a known fix; take a second fix.
   The vector from DR to fix, over the elapsed time, is set and drift. This is
   the honest number, because it contains *everything* that moved you — tidal
   stream, wind-driven current, leeway, log error, helmsman's bias — not just
   the part a table predicted.

2. **Using it — the current triangle.** Intended track and boat speed through
   the water on one side, set and drift on another; course to steer and speed
   over ground fall out. And the reverse, from what was observed.

It is the same triangle Larry solved by hand in the fire control tracking
party — own ship's vector, the relative vector, the target's vector. In
collision work you solve for the target's motion; in current sailing you solve
for the water's. `src/colregs/contacts.awk` already has that machinery and it
should be lifted, not rewritten.

**The one honest link to the tide data**, and worth building because it works
worldwide with the constants already present: tidal stream atlases are indexed
by **hours from high water at a standard port** ("HW Dover −3"). `tides`
already knows HW time everywhere it has a station, so it can say *which page
of the atlas you are on*. That is a real, useful connection between the height
data and the stream — as opposed to computing a stream from a height curve,
which is not possible. In a standing-wave basin the stream runs hardest at
half-tide and goes slack at HW and LW; in a progressive wave the flood peaks
*at* HW; which one you are in depends on the shape of the coast.

---

## The platform bug, 2026-08-30

**None of the tools could start on an iPad**, from the first release until this
morning. iOS refuses writes in `$HOME`; every tool kept its data there. Found by
Larry the first time he tried to run them on the boat, not by the suite. Fixed
(`src/common/05-home.sh`) and covered (`tests/ios-home.sh`). Full account in
`CHANGELOG.md` and `docs/HACKING.md`.

The lesson worth carrying: **the suite ran on machines that shared the code's
assumption.** Everything else this project targets — a-Shell's awk, a small
screen, no network — is modelled somewhere in the tests. A writable `$HOME` was
not, because it never looked like a platform question.

## The iPad release

`release/make-ipad.sh` builds **`release/bashnav-ipad.sh`**, one self-extracting
installer carrying all six tools.

**It is generated *and committed*, like `bin/`.** It was gitignored for a day, on
the reasoning that a release asset should not be a tracked file. That reasoning
assumed somebody would be cutting GitHub releases by hand, and the README's
`curl` line pointed at a `releases/latest/download/` URL that did not exist.
Larry's call: track it. The install line now points at the file in the repo and
works the moment a change is pushed, with no release step at all.

**The cost, stated so it stays a decision.** The installer is a copy of all six
binaries, so every change to any tool writes a fresh ~3.4 MB blob into git
history &mdash; on top of the 2.9 MB `bin/tides` already costs. If the repository
ever becomes unpleasant to clone, the fix is to go back to a release asset and
point the README at it; nothing else depends on the file being tracked.

CI checks it is not stale, the same way it checks `bin/` &mdash; regenerate, then
`git diff`. A stale installer would hand an iPad an older tool than the repo
claims, and nothing on the boat would say so.

## Loose ends

1. ~~**`docs/index.html` still describes two tools.**~~ **Closed 19 Oct 2026.**
   The site now covers all six tools and the browser build, shows the real
   output as pictures with the terminal text folded underneath each one, and
   `make-site.sh` fails the build if any picture comes out blank. Every SVG it
   generates is now used by something.
2. ~~**Five orphaned SVGs on GitHub** from before a rename.~~ **Closed 19 Oct
   2026** — `contacts.svg`, `lights.svg`, `lights-mineclear.svg`, `plot.svg`
   and `sky.svg` removed with `git rm`. They were byte-identical duplicates of
   the `colregs-*` and `celnav-*` names and nothing referenced them.
3. ~~**POSIX interval expressions in an awk regex.**~~ **Closed 20 Oct 2026**,
   and worth reading even though it is closed. `lg_parse` guarded the record
   type with `/^[a-z][a-z0-9]{0,4}$/`. That is correct POSIX ERE, and **mawk
   1.3.3 does not implement it** — it reads `{0,4}` as four literal
   characters, so `eng` did not match and *every record was rejected*.
   `deck-log` then refused to write an entry and read an existing log as
   empty: total failure, on the awk that `awk` is on Debian, Ubuntu and
   a-Shell, which is also the first name `pick_awk()` tries.

   The guard that refuses to write a record it cannot read back did its job —
   nothing was ever corrupted — but a sailor would have seen a tool that
   silently declines to keep the log. gawk implements intervals, which is why
   it reached a release.

   Written out instead, and proved equivalent over 137,257 generated strings:

       ^[a-z]([a-z0-9]([a-z0-9]([a-z0-9][a-z0-9]?)?)?)?$

   `tests/interval-check.awk` now forbids the construct in any awk source and
   is wired into `run-tests.sh`. It was checked against three bad forms *and*
   three innocent ones — a check that cannot fail is worth nothing.

4. **`src/decklog/log.awk` is a dead byte-identical duplicate** of
   `src/common/log.awk`. `build.sh` uses the one in `common/`; nothing uses
   the other. Both carry the interval fix, but the duplicate is a trap: a
   future edit to it would silently never reach the build. It should be
   deleted.

5. **A Shortcuts recipe for iPad GPS → `tides near`**, so a position can be
   handed to the tool without typing it. The Shortcuts groundwork is now in the
   README — a-Shell's **Execute Command** action, set to run **In App** — and
   this one differs only in passing an argument the Shortcut computes. *Not
   tested on hardware.* Larry has the iPad; the recipe is written from a-Shell's
   own documentation and needs one run to confirm.
6. **The Clipper training app.** Larry has emailed Clipper for permission to
   build an interactive trainer from their course PDFs. Nothing is to be built
   from those materials without written permission — their text is
   copyrighted. Facts and methods are not, and can be taught freely in our own
   words.
7. **Tag a release** and attach `release/bashnav-ipad.sh` and the six binaries,
   so people who only want the tools do not have to clone 2.9 MB of station
   data through git. The README's iPad instructions already point at
   `releases/latest/download/bashnav-ipad.sh`, so this is now load bearing.
8. **`seamanship` is held**, on the local `seamanship-hold` tag and not in this
   repository, pending Clipper's answer. Larry has a personal binary. See the
   note above: if Clipper objects even to the generic build, it stays on his
   iPad and never enters `bashnav`.

---

## Working agreement

Larry has the sea time and the ideas; Claude writes the code. He is a market
data systems engineer and scripts in Bash, Perl and Python, so the explanations
should be engineering-grade — but he does not guess at this codebase, and that
is what makes his reports worth so much.

He tests by using the tools the way a sailor would, and he has found things the
suite could not: the mine-clearance light arrangement, the towing light
geometry, a quiz that told you the answer before it asked, a picture that was
missing rather than colourless, and — on the first morning he tried them at sea
— that **not one of the tools would start on an iPad**.

He reports symptoms accurately and does not diagnose. Treating his report as a
diagnosis has now cost several rounds three separate times. Reproduce first;
each of the three took one command once somebody went and looked.
