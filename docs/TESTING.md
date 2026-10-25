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
| `jsonesc-check.awk` | the generators' JS/JSON escaper, held to a literal answer per awk &mdash; one mawk build emitted one backslash where the rest emit two |
| `svg-check.awk` | an SVG that is not an exact character grid |
| `readme-check.awk` | unclosed fences, unbalanced `<details>`, `<img>` inside a fence or pointing at nothing |
| `plates-check.sh` | every plate and picture the site shows, against what the program produces &mdash; per awk, so awk-dependent site output fails |
| `count-check.awk` | counts quoted in prose against what the program actually has |
| `toolrow-check.awk` | a tool in `bin/` with no table row or no section, and any README link &mdash; anchor, published app or file &mdash; that leads nowhere |
| `install-check.awk` | an install section that has fallen behind what exists |
| `ipad-install-check.sh` | the iPad installer must install, prove the tools run, set the PATH, and survive being run twice &mdash; plus the write-probe regression at shell level |
| `ashell-check.sh` | constructs a-Shell cannot run: a heredoc feeding a command that prints, and a compound command redirected to a file |
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

### Three of these changed shape when the README did

The browser-first README broke four checks, and the useful part was telling
apart the ones that encoded the old *shape* from the ones that were protecting
*content the rewrite had dropped*. Only three were shape.

1. **`toolrow-check.awk`** assumed rows of the form `| **[name](#name)** |` and
   headings at exactly `## name`. The new README has two tables — the browser
   apps linking to the published builds, the six shell scripts linking to their
   own `###` sections. Worse, its anchor was extracted with
   `sub(/^[^(]*\(#/)`, which on a row whose link is a URL with no `#` in it did
   nothing at all, so it reported *"the row for celnav links to
   #celnav](https://..."*. It now checks the property instead: every tool has a
   row and a heading, every `#anchor` lands on a heading, every link to
   `…/bashnav/web/<name>/` lands on a build that is in `docs/web/`, and every
   relative link lands on a file in the repository.

2. **`readme-check.awk`** was given `-v WANT=6`. A number typed in two places
   is the trap that left three site plates silently empty when `make-site.sh`
   named engine versions by hand, and the rewrite took the README from six
   pictures to two, so it went red for something that was not a fault. It now
   counts every `<img>` in the file, fenced or not, and requires that all of
   them render — which is precisely the bug it exists for, since a fence
   swallowing a picture leaves the tag in the raw count and out of the rendered
   one. What that no longer guards is a picture deleted outright; deleting one
   is an edit rather than a fault, and the typed number had started costing
   more than it saved.

3. **`plates-check.sh`** diffed two ASCII blocks pasted into the README. Those
   blocks are gone — the README shows the SVGs `make-site.sh` renders from the
   same output. The property is unchanged, the target moved: it now rebuilds
   the whole site with a given awk and diffs `docs/plates/` and `docs/img/`
   against what is committed, covering all eight plates and fifteen pictures.

The two that were *not* shape — the launcher's menu block and the install
section's "no app to install" and `~/Documents` — went back into the README,
because an iPad reader still needs all three and the launcher menu still
drifts. `launcher-check.sh` matches the `bashnav` heading at any depth now, so
it does not have to move again the next time the README is reorganised.

### What running the site build per awk found immediately

`plates-check.sh` builds the site with each awk in the matrix, so **site output
that depends on which awk produced it is a failure**. On the first run it found
one: `encounter.txt` and `scenario.txt` were generated from the colregs engine
alone, with `contacts` assigned to a shell variable and never used. gawk and
one-true-awk resolve a function at the call and never reach `rv_keys()`, which
lives in `review.awk`; mawk resolves at parse time and refuses the file
outright. And the awk sat at the **head of a pipeline**, where `set -e` cannot
see it — a pipeline's status is the last command's, `sed` succeeds on empty
input, and the script wrote a zero-byte plate and carried on. Rebuilding the
site on a machine whose `awk` is mawk blanked two front-page plates silently.

`make-site.sh` now checks its text plates for emptiness the way it already
checked its pictures, which is what should have caught it. It also no longer
exits 1 on success: the last statement in the script was
`grep -c '{{' docs/index.html >/dev/null && { … }`, and `grep -c` returns 1
when the count is zero, so under `set -e` a clean build always reported
failure. Nothing was reading that status, which is the only reason it survived.

And an **unfilled `{{PLACEHOLDER}}`** now fails the build rather than printing
`warning:` and carrying on. It is the same class of fault as a blank plate —
visible on the front page, and arriving the same way, a template name changed in
one place and not the other — so it had no business being the one that only
warned. `plates-check.sh` inherits it: a site that will not build under an awk
is reported as a failure under that awk.

> Running a build under every awk costs a second a time. Both of these had been
> in the repository for weeks, and neither was findable any other way.

### What regenerate-and-compare cannot see

Six generated browser files are regenerated during the suite and diffed against
what is committed, which is the check that catches a change to the shell that
has not reached the browser. It has a blind spot, and it is not obvious: **the
generator is compared with itself**, on whichever awk is running. If the
generator is wrong on that awk, the check reports the *committed* file as stale
and advises regenerating it — and following that advice commits the wrong file.

That is exactly what nine generators were doing. All of them escaped their
output with `gsub(/\\/,"\\\\",s)`, which does the doubling inside gsub's
replacement string, where POSIX leaves backslashes to the implementation. On
mawk 1.3.4 20200120 — Debian's and Ubuntu's for years — one backslash came out
where two were needed, so a celnav lesson showing a shell line continuation
rendered a literal `\n` with no line break.

`tests/jsonesc-check.awk` closes it by holding the escaper to a **literal
answer** under every awk instead of to its own output. Its expectations are
written in a safe alphabet — `<BS>`, `<DQ>`, `<SQ>`, `<NL>`, `<TAB>` — because a
check for escaping that spells its own expectations with backslashes is resting
on the thing it is testing. Verified red on the broken build (3 of 8 cases) and
green on the fix.

The same sweep found two more gaps of the ordinary kind: `weather`'s and
`deck-log`'s generators had no regenerate-and-compare at all, and
`docs/web/weather/lessons.js` had gone stale — the committed file was missing a
passage of the Coriolis lesson that `src/weather` prints. Both are compared now.

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

### The exception: a port, where the awk *is* the published answer

`docs/web/tests/` compares the browser builds against the awk engines, which is
a comparison against another implementation and would be worthless for the
physics — so it is never used for the physics. It is used for *sameness*: the
awk tool is the thing that was validated against NOAA and against the
Convention, the browser is a port of it, and the only question is whether the
port says the same thing.

That question is answered on **whole cases**, not on functions. celnav's
browser fix was 43 nm wrong from a stale DR while every function in it agreed
with the awk to nine decimals, because what it got wrong was the loop that
drives them. `docs/web/tests/celnav-ref.awk` therefore generates a position, a
time, two to five bodies and a DR up to several hundred miles off, inverts each
`Hs` out of `corrections()` so the sights are readings rather than inventions,
and runs the shell's own `cmd_reduce()` path over them — 21,468 comparisons per
400 cases, under every awk on the machine.

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
