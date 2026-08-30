# Testing

    ./tests/run-tests.sh                                       # every shell x every awk found
    SHELLS="dash bash" AWKS="mawk gawk" ./tests/run-tests.sh    # named explicitly
    ./tests/golden.sh                                          # has any screen changed?
    ./tests/golden.sh --update                                 # accept the change

`run-tests.sh` rebuilds `bin/` from `src/` before it runs. **A file you edit
in `bin/` to probe a test will be silently overwritten** — that has cost real
time; edit `src/`.

---

## The rule

**A test you have never watched fail is not a test.**

And a lint that scans for a fact cannot see a *contradiction*. `install-check`
asks whether the README mentions each tool and says the right things about an
iPad. For weeks the README carried **two** `## Install` sections — the current
one and a stale one still saying "Both tools" — and the check passed the whole
time, because everything it looks for was present in the newer one. It was
found by reading, not by running.

Break the code deliberately, watch the check go red, restore, watch it go
green. My own harnesses have been wrong four separate times, and two checks
have passed while the behaviour they claimed to test was switched off. Both
were caught only by probing.

---

## Property tests — the ones that earn their keep

These check a property rather than an output, so they keep working when the
content changes.

| Check | Why it exists |
|---|---|
| **every drill and quiz marks its own correct answer as correct** | caught mawk re-seeding `srand()` from an explicit seed, which made marking intermittently wrong |
| **scenario replays terminate** | a replay loop that never converges hangs the tool with no error |
| **drift toward the bow always crosses ahead** (400 geometries) | verifies Larry's remembered Navy bearing-drift rule numerically before it was written down as a lesson. The full sweep was 700,000 geometries, zero exceptions |
| **Ekelund recovers the true range** (300 leg pairs) | the formula was derived and verified rather than quoted |
| **Red/Green and the words agree at every degree, both sides** | five reporting styles must describe the same angle consistently |
| **light tables satisfy Annex I where it is checkable** | `tests/annex1-check.awk`; light heights and arcs against the Annex |
| **tides match NOAA's published tables** | see below — the single most important check in the repo |
| **the About numbers match the program** | the About text quotes counts of vessel types, encounters and lessons; they drifted |

## Lints — each one is a bug that shipped

| File | Catches |
|---|---|
| `awkvars-check.awk` | a variable named after an awk built-in (`RS` broke tide loading) |
| `fnparam-check.awk` | a function parameter shadowing a function name (mawk will not parse it) |
| `fields-check.awk` | a table field containing its own separator (a `;` in an option cut an answer in half) |
| `svg-check.awk` | an SVG that is not an exact character grid |
| `readme-check.awk` | unclosed fences, unbalanced `<details>`, `<img>` inside a fence or pointing at nothing |
| `count-check.awk` | counts quoted in prose against what the program actually has |
| `toolrow-check.awk` | a tool in `bin/` with no row in the README's table, or no section, or a row whose anchor leads nowhere |
| `install-check.awk` | an install section that has fallen behind what exists |
| `ipad-install-check.sh` | the iPad installer must install, prove the tools run, set the PATH, and survive being run twice &mdash; plus the write-probe regression at shell level |
| `ios-home.sh` | every tool must start when `$HOME` cannot be written &mdash; the iOS condition, which no tool survived until 2026-08-30 |
| `launcher-check.sh` | the launcher must offer and find every tool, fail out loud, pass arguments through — and its menu in the README is diffed against the menu it prints |
| `review-check.awk` | review keys unique and well formed; every claim renders |
| `contacts-check.awk` | the contacts lessons and the tracking exercise |
| **no network, ever** | `curl wget nc telnet ftp`, and `getline < "http…"` |

The network lint matches a **command at a command position**, not a substring:
`nc` lives inside "since" and "encounter", and a lint that cries wolf gets
switched off, which is worse than no lint. A URL printed for a person to
*read* is fine — the licence text and the review link are both just words on a
screen. What is banned is fetching one.

---

## Validation: against the published answer, never against another implementation

`tests/tides-check.awk` + `tests/tides-noaa.dat` compare high and low water
against **NOAA's own published tide tables** — the numbers a mariner would
actually read — at six stations spanning small and large ranges and mixed and
diurnal regimes.

    24 turns.  mean |dt| 2.4 min, worst 5.9.  mean |dh| 1.0 cm, worst 2.0.

Three real bugs were found this way: shallow-water constituents with zero
speed, the SA phase reference, and the amplitude floor. **Every one of them
would have passed a comparison against another harmonic library**, because
both implementations would have been wrong in the same way.

The fixture is committed, so the check runs offline like everything else.

> Once I fabricated a station's fixture values by eye instead of fetching
> them, and spent an afternoon chasing a 38-minute error that did not exist.
> **Invented reference data in a validation test is worse than no test.** If
> you cannot fetch the reference, do not write the check.

---

## Golden files

`tests/golden/` holds 27,245 lines of expected screen output across 13 files —
lights from every angle, every encounter, every lesson, the scenarios, the
tracking plots, the tide tables and curves, the station searches.

    ./tests/golden.sh              # compare
    ./tests/golden.sh --update     # rewrite, then READ THE DIFF before committing

This is a change detector, not a correctness check. It answers "did anything a
user sees change, and did I mean it?" CI runs the comparison, so an unintended
change to a screen fails the build instead of being noticed months later.

---

## Test the platform, not a convenient stand-in

Every check in this suite ran green while **not one of the six tools could start
on an iPad**, because each kept its data in `$HOME/.<tool>` and iOS refuses
writes to `$HOME`. The suite runs on machines with a writable `$HOME`, so it
shared the assumption the code was making, and a test that shares an assumption
with the code cannot test it.

`tests/ios-home.sh` takes the assumption away two ways: a `$HOME` whose dotfolder
cannot be created (portable, runs as any user, root included), and a `$HOME` with
the write bit off, which is the real condition. The second needs a uid that
`chmod` applies to, so under root it uses `setpriv`; where it cannot run it says
**SKIP** out loud rather than passing quietly.

## Shell-only checks run once per shell

The installer, the launcher and the `$HOME` checks exercise `sh`, not `awk`, so
running them for every shell × awk pair repeated identical work twelve times and
made the suite slow enough to skip. They now run when `$AW` is the first awk in
the list. The guard is written as `if [ "$AW" != "$FIRSTAWK" ]; then :` rather
than `&&`-ed onto the check, because `if [ … ] && o=$(check)` sends every
skipped pass down the `else` branch and reports a **failure** — which is worse
than the slowness it was meant to fix.

## What still needs a human

Two things the suite cannot judge, and where feedback is genuinely wanted:

1. **Whether the COLREGs content is correct and not misleading.** The suite
   checks that a light table satisfies Annex I and that a quiz marks itself
   correctly. It cannot check that the *rule cited* is the right rule, or that
   an explanation is sound. That is why `colregs review` exists: 153 claims,
   each reviewable by a person, submitted through a GitHub issue link.

2. **Whether a drawing reads correctly to a seaman's eye.** Larry found the
   mine-clearance light arrangement, the towing light geometry and the quiz
   that told you the answer before asking. None of those were test failures.
   All three were somebody who knew what a ship looks like at night, looking.
