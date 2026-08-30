# Repository state

Last updated 2026-08-30. Published at
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

1. **`docs/index.html` still describes two tools.** The site predates `tides`,
   `deck-log`, `weather` and `bashnav`. `docs/make-site.sh` already builds
   `docs/img/tides-day.svg` and `docs/img/tides-find.svg` and nothing uses
   them. The README covers all six fully; the site is the stale surface.
2. **Five orphaned SVGs on GitHub** from before a rename — `contacts.svg`,
   `lights.svg`, `lights-mineclear.svg`, `plot.svg`, `sky.svg`. Identical blob
   SHAs to their new names, nothing references them. Extracting a tarball adds
   files but never removes them, so they must be deleted on Larry's side.
3. **A Shortcuts recipe for iPad GPS → `tides near`**, so a position can be
   handed to the tool without typing it. The Shortcuts groundwork is now in the
   README — a-Shell's **Execute Command** action, set to run **In App** — and
   this one differs only in passing an argument the Shortcut computes. *Not
   tested on hardware.* Larry has the iPad; the recipe is written from a-Shell's
   own documentation and needs one run to confirm.
4. **The Clipper training app.** Larry has emailed Clipper for permission to
   build an interactive trainer from their course PDFs. Nothing is to be built
   from those materials without written permission — their text is
   copyrighted. Facts and methods are not, and can be taught freely in our own
   words.
5. **Tag a release** and attach `release/bashnav-ipad.sh` and the six binaries,
   so people who only want the tools do not have to clone 2.9 MB of station
   data through git. The README's iPad instructions already point at
   `releases/latest/download/bashnav-ipad.sh`, so this is now load bearing.
6. **`seamanship` is held**, on the local `seamanship-hold` tag and not in this
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
