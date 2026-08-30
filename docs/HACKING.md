# Hacking

Every rule here exists because something shipped broken. None of it is
stylistic. Read it before you write awk for this project.

---

## Portability

### Test under two awks or you have tested nothing

`gawk` accepts several things `mawk` refuses **at parse time**, so a gawk-only
run does not tell you the file is valid awk. `run-tests.sh` defaults to every
shell and every awk installed on the machine, and CI names `dash`/`bash` ×
`mawk`/`gawk` explicitly so the intent survives a change to that default.

This mattered: three separate mawk parse failures were found by CI and not
locally, because the runner used to default to one shell and one awk.

### Never name a variable after an awk built-in

A tide-rate variable called `RS` set awk's **record separator**. The next
`getline` read the entire station file as one record. The symptom was a tide
prediction that quietly used no data at all.

Banned: `RS RT NR NF FS OFS ORS RSTART RLENGTH SUBSEP FILENAME FNR CONVFMT
OFMT ENVIRON ARGC ARGV FIELDWIDTHS IGNORECASE`.

`tests/awkvars-check.awk` enforces this across `src/`, `docs/` and `tests/`.

> I introduced `RT` — a gawk built-in — **into the lint written to catch
> exactly this class of bug**, in `docs/ansi2svg.awk`. It is now `RTX`. The
> lint covers `docs/` and `tests/` for that reason.

### Never let a function parameter shadow a function name

    function ek_across(sp, co, brg)     # WRONG if brg() is a function

Illegal in POSIX awk. gawk tolerates it; **mawk refuses to parse the file**,
so the tool dies at startup with a syntax error and no other clue.

Worse: **mawk resolves called functions at parse time, gawk only at call
time.** So an awk file that calls a function defined in a *different* `-f`
file will load under gawk and fail to parse under mawk. `src/colregs/engine.awk`
can no longer be loaded on its own for this reason — it needs `contacts.awk`
and `review.awk` alongside it. Test invocations must pass all three.

`tests/fnparam-check.awk` enforces the shadowing rule.

### No newline after the `:` of a ternary

    x = (a > b) ? one :
        two                    # gawk sometimes; mawk never

Break the line before the `?` or use an `if`. `rv_colour()` and `rv_arc()` in
`review.awk` are written as plain `if`s for exactly this reason.

### `$HOME` is not writable on iOS

    : "${CELNAV_HOME:=$HOME/.celnav}"          # WRONG on the target platform

a-Shell's README: *"In iOS, you cannot write in the `~` directory, only in
`~/Documents/`, `~/Library/` and `~/tmp`."* `$HOME` there is the app's data
container, `/private/var/mobile/Containers/Data/Application/<uuid>`, and `mkdir`
in it is refused.

**All five tools defaulted to `$HOME/.<tool>`, so not one of them would start on
an iPad** — the only platform this project has ever been for. Each printed
`cannot create /private/var/mobile/Containers/…` and stopped. It survived a full
test matrix, CI, a published release and five tools because *every machine the
suite runs on has a writable `$HOME`*.

`src/common/05-home.sh` now picks the first of `$HOME`, `$HOME/Documents`,
`$HOME/Library` it can create **and write a file in**. Proving it by writing,
rather than sniffing the platform, is the point: there is no `uname` that
distinguishes a-Shell from any other iOS shell, and the next constrained
platform will not announce itself either.

> Larry reported *"a could not create container error"*, then the path. That was
> our own message read off the screen — `cannot create /private/var/mobile/
> Containers/Data/Application/<uuid>/.celnav` — and the word he picked out of it
> was in the path, not the verb. **Third time on this project that his report
> was an accurate description and I read it as a diagnosis.** Reproducing it
> took one command: a `$HOME` with the write bit off.

### POSIX sh, not bash

No arrays, no `[[ ]]`, no `local`, no `$'...'`, no `${var,,}`, no `function`
keyword. It must run under `dash` and under a-Shell.

### `-f file` and an inline program do not mix — and it fails silently

    awk -f lib.awk 'BEGIN{ print "hi" }'        # prints NOTHING, exits 0

Once you use `-f`, **all** program text must come through `-f`. The inline
`'BEGIN{...}'` is taken as a **filename**, awk looks for a file called
`BEGIN{ print "hi" }`, does not find it, has no main rule to run, and exits
successfully having done nothing at all.

No error, no warning, exit status 0.

This is not a curiosity. A truncation test written this way reported success
across eighty-six offsets while executing no test code whatsoever, and the real
bug it was meant to find — a half-written record parsing as a whole one — sat
there undetected until the harness was fixed.

**So: probe code goes in a file and is passed with `-f`.** And any harness whose
probe can produce no output must fail loudly on an empty result rather than
skipping it.

### Do not seed `rand()` and expect it to be reproducible

**mawk re-seeds `srand()` from the clock even when handed an explicit seed.**
Both engines used seeded `rand()` so a drill could be regenerated for marking;
under mawk the marking would occasionally score a correct answer as wrong.

Both now use an internal MINSTD generator, `xsrand()`/`xrand()`. The test that
found it — "every drill and quiz marks its own correct answer as correct" — is
the most valuable test in the suite.

---

## Shell traps

### Test for a tty at the top level, never inside a substitution

    # WRONG
    cmode_now() { [ -t 1 ] && echo "$cmode" || echo plain; }

    # RIGHT — in 10-head.sh, at the top level
    ISTTY=0; [ -t 1 ] && ISTTY=1
    cmode_now() { if [ "$ISTTY" = 1 ]; then echo "$cmode"; else echo plain; fi; }

Inside `$( )` stdout **is a pipe**, so `[ -t 1 ]` is always false and every
terminal was told it was plain. Colour never worked for anybody, on any
terminal, for weeks. Larry asked "should I be seeing the light in color?" and
the honest answer was no, nobody ever had.

### `while read … done < file` redirects the whole loop body

    # WRONG — every prompt inside rv_one reads a KEY, not the user's answer
    while read k; do rv_one "$k"; done < keyfile

    # RIGHT
    rvkeys=$(eng -v cmd=rvkeys)
    for k in $rvkeys; do rv_one "$k" || break; done

The review section picker appeared to ignore every keystroke. It was consuming
the key file instead.

### A write probe must sit inside `( )`

    mkdir -p "$d" 2>/dev/null && : > "$d/.wtest" 2>/dev/null      # WRONG

Two separate faults in one line, both invisible until the directory exists and
cannot be written:

1. **The error still reaches the terminal.** Redirections are applied left to
   right, so the failing `> "$d/.wtest"` reports *before* the `2>/dev/null` that
   was meant to silence it. The user sees `cannot create /…/.wtest`.
2. **Under `dash` the shell exits.** `:` is a POSIX **special built-in**, and a
   redirection error on a special built-in terminates a non-interactive shell.
   Not the function — the whole script.

    mkdir -p "$d" 2>/dev/null && ( : > "$d/.wtest" ) 2>/dev/null   # RIGHT

The iPad installer died exactly there the first time it met a read-only `$HOME`:
printed a raw shell error and stopped after "checking they run". `bash` survived
it and only leaked the message, which is how a thing like this reaches a user —
it works on the machine you wrote it on.

`tests/ipad-install-check.sh` probes this directly, at the shell level, as well
as through the installer.

### Declining is not failing

`tides near` used to exit non-zero when the user pressed return instead of
picking a station. Under `set -e` in the test suite that killed the run. The
`do_near`/`do_find` helpers now `return 0` either way, with a comment saying
why, so nobody "tidies" it back.

---

## The bug ledger

Kept because the *pattern* recurs, not for nostalgia.

### Data and correctness

**Shallow-water constituents had speed zero.** M4 came out at 0.000000
cycles/day, so every overtide became a DC offset that drifted with the date. A
shallow-water constituent is a *product* of others and has no Doodson numbers
of its own: its speed is the same weighted sum of its parents' speeds that its
phase is of theirs. Fixed with a six-pass resolution loop in `tide_prep()`.

**SA phase out by 283°.** Foreman lists Sa as `(0 0 1 0 0 -1)`; NOAA
references it to `h` alone. Found by predicting the same station six months
apart and watching the error swing.

**A 10 mm amplitude floor cost a factor of four in timing.** It looked
harmless. Worst error against NOAA's published tables went from 5.9 minutes to
26.9. `FLOOR` is now 0.0005 m and the extra megabyte is worth it.

**Mine clearance lights drawn on two masts.** Larry could not account for a
green light in the picture, which is how it was found. All three all-round
greens belong on one mast.

**Encounters 13 and 14 showed five options with the right answer cut in
half** — a semicolon inside option (b), and the option list is
semicolon-separated. Found from a screen Larry pasted. `tests/fields-check.awk`
now checks that no table field contains its own separator.

### Validate against the published answer, not another implementation

`tides` is checked against **NOAA's own published tide tables**, not against
another harmonic library. Checking theory against theory would have passed
cleanly with all three of the bugs above still in place. 24 turns at six
stations spanning small and large ranges and mixed and diurnal regimes; mean
2.4 min / 1.0 cm, worst 5.9 min / 2.0 cm; the fixture is committed so the
check needs no network.

> **I once fabricated Newport's fixture values by eye instead of fetching
> them**, which produced a phantom 38-minute error and sent me hunting a bug
> that did not exist. *Invented reference data in a validation test is worse
> than no test at all.* If you cannot fetch the reference, do not write the
> test.

### Rendering

**The README SVGs sheared, three times, three different causes.** GitHub's
sanitizer strips `xml:space`, so indentation collapsed. Then glyphs advanced by
the font's own width rather than the grid's. Then XML collapsed runs of
whitespace inside text content, so the x-coordinate list no longer matched the
characters. Final rule in `docs/ansi2svg.awk`: **no space character is ever
written into the SVG.** A gap is expressed by arithmetic — each whitespace-free
chunk gets its own explicit x position. `tests/svg-check.awk` verifies the grid.

**The lights picture was not colourless — it was not there.** Larry reported
"still no color in colregs" three times across two sessions. Each time I went
and checked the SVG, and each time the SVG was correct. The actual fault was an
unclosed ` ```sh ` fence in `README.md` that swallowed the `<img>` tag, the
`<details>` block and the plain-text copy of the picture. GitHub printed the img
tag as source and rendered nothing.

> **A missing picture and a colourless picture are indistinguishable from the
> outside.** His report was an accurate description of what he saw and I kept
> reading it as a diagnosis. What found it in one call was opening the live page
> and asking the DOM what it had:
>
>     Array.from(document.querySelectorAll('img')).map(i => i.src)
>
> Three came back; the README claims four. **When a user reports how something
> looks, verify what is actually being served before investigating what you
> think is being served.** Proving the file on disk was byte-identical to the
> one on GitHub felt like progress and was the wrong question.

`tests/readme-check.awk` now enforces the markup.

### My own test harnesses

**They were wrong four separate times** — an export selector that matched
nothing, a `bad++` outside its `if`, `nc` matching inside the word "since",
and the Apache licence URL flagged as a network endpoint. And once my probe of
the network lint was silently overwritten, because `run-tests.sh` rebuilds
`bin/` from `src/` before running.

> **A test you have never watched fail is not a test.** Break the code
> deliberately, watch the check go red, then restore. Every check added since
> this rule was written has been probed this way, and two of them — the search
> ranking test and an `<img>` counter — passed while the thing they claimed to
> test was disabled. The ranking test used Boston, where alphabetical order
> already gives the right answer; it uses Falmouth now, where it does not.

### Do not put working files in `/tmp` on iOS

`deck-log` and `weather` built each record in `${TMPDIR:-/tmp}`. iOS gives an app
`Documents`, `Library` and its own `tmp`, and **nothing promises a `/tmp` at
all**. Both now use the tool's own data folder, which was probed for writability
at startup and is therefore the one place known to work.

### Platform

**Nothing in the suite ran as an iPad runs it.** See the `$HOME` entry above:
five tools, none of which could start on the target device, and a green matrix
the whole time. A test environment that shares an assumption with the code
cannot test that assumption. `tests/ios-home.sh` removes this one — a `$HOME`
that cannot be written, which is the actual iOS condition — and it is the model
for any future one.

### Build and release

**`make-site.sh` named engine versions by hand**, so three site plates had been
silently empty since a version bump. Version numbers must be derived, never
typed twice.

**A stray 45-byte `bashnav.tar.gz` was committed by accident.** `*.tar.gz` is
in `.gitignore` now.

---

## Publishing notes

Larry pushes from a Mac using GitHub Desktop. Things that have gone wrong:

- The repo was first created as **`basinav`** (a typo). "Repository not found"
  was literally true and read like an auth failure for an hour.
- A PAT needs the **`workflow` scope** as well as `repo`, or any push touching
  `.github/workflows/` is rejected.
- git discards a valid token when the operation fails for an unrelated reason,
  so the next attempt looks like a credentials problem and is not.
- **Extracting a tarball over a folder adds files but never removes them.**
  Renamed files leave their old names behind — `docs/img/` on GitHub still
  carries five orphans from before a rename. Deletions have to be made
  explicitly on his side.
- macOS Archive Utility does not merge into an existing folder; it creates
  `bashnav 2`. Worth checking when a change seems not to have arrived.
