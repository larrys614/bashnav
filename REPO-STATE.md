# Bash Navigation Software — repository state

Built 2026-08-29. Ready to push; nothing is published yet.

## What is in it

    bin/celnav          celnav 1.1   cksum 4175943417 142889
    bin/colregs         colregs 1.1  cksum 2128191058 95824
    src/celnav/         10-head.sh, engine.awk, teach.awk, 30-ui.sh
    src/colregs/        10-head.sh, engine.awk, 30-ui.sh
    build.sh            joins src/ into the two single files in bin/
    tests/run-tests.sh  the whole suite; SHELLS and AWKS widen the matrix
    docs/index.html     the project site (GitHub Pages serves /docs)
    docs/site-template.html + docs/make-site.sh + docs/plates/
                        the site is rebuilt from the tools' real output
    docs/manual-src/    manual and quick-reference sources, mkpdf.sh, figures
    docs/*.pdf          the built manual (11 pp) and card (4 pp)
    .github/workflows/  CI: the matrix, busybox awk, shellcheck, and a check
                        that bin/ is not stale
    README, LICENSE (MIT), CONTRIBUTING, SAFETY, CHANGELOG, PUBLISHING

## Decisions taken

**MIT licence**, as chosen: shortest, best understood, and the least friction
for a safety tool meant to be used widely, including inside commercial software.
It carries the warranty and liability disclaimer that a navigation tool needs.

**One repository, site included.** `bashnav` holds both tools and publishes the
site from `docs/`. One thing to maintain, one URL to give people.

**The site is generated from real output.** `docs/make-site.sh` runs the tools
and drops their actual output into the page, so what the site shows can never
drift from what the programs do. The lights plate is post-processed so the
R, G, W and Y letters appear in their real colours.

## colregs 1.1 — what it covers

- **Lights** — twenty vessel types. Each light is a record of fore-and-aft
  position, athwartships position, height and arc of visibility, so any vessel
  is rendered from any bearing and the arcs decide what is visible. Seen from
  astern, masthead lights correctly disappear.
- **Day shapes** — ten, drawn as glyphs on a mast.
- **Encounters** — twenty-eight scenarios on a head-up plan view, each with four
  options and the rule that governs it: crossing, head-on and overtaking, narrow
  channels (Rule 9), traffic separation schemes (Rule 10), restricted visibility
  (Rule 19), tows, mine clearance, seaplanes, pilot vessels, and vessels aground
  or at anchor.
- **Collision avoidance** — a developing situation rather than a snapshot. The
  generator picks a desired CPA and time to it, then solves backwards for the
  target's course and speed, so every scenario has a known exact answer. Three
  observations six minutes apart carry realistic bearing scatter. The user
  answers three questions (is there risk, how close, what do you do); the
  solution shows the CPA, the time to it, and the target's true course and speed
  from the vector triangle. Then a frame-by-frame true-motion replay runs under
  *the action the user chose*, and reports the CPA that action actually
  produced against the CPA of holding on.
- **Sound signals** — fifteen, drawn as timelines, split into Rule 34 (in sight
  of one another) and Rule 35 (restricted visibility).
- **Fifteen lessons** on Rules 5, 6, 7, 8, 9, 10, 12, 13, 14, 15/16, 17, 18, 19,
  the lights and shapes rules, and the sound rules. Each ends with a question.

The COLREGs content is a training aid and says so, in `colregs about`, in
SAFETY.md and on the site. Where it and the Convention differ, the Convention
governs.

## Two bugs the tests and a user caught

**The artwork was invisible on a light terminal.** Both tools set a white
foreground without painting a background, so on Apple Terminal's default light
profile the ASCII was white on white and only the coloured lamps showed. Every
drawing now paints itself as its own black panel with light text, edge to edge
(erase-to-end-of-line), independent of the user's terminal profile.

## A bug the tests caught

`mawk` re-seeds `srand()` from the clock even when handed an explicit seed. Both
engines used seeded `rand()` so a drill could be regenerated for marking; under
mawk the marking would occasionally score a correct answer as wrong. Both now use
an internal MINSTD generator (`xsrand`/`xrand`), and the suite checks that every
drill and quiz marks its own correct answer as correct — which is the test that
found it.

## Also fixed

- `celnav help` never listed the commands added in 1.1 (`doctor`, `learn`,
  `walk`, `drill`, `sandbox`, `night`, `version`). It now lists all of them,
  grouped into Working, Learning and Setup.
- An unknown command used to say "try celnav help". Both tools now print the
  actual list of commands, so a typo answers itself.
- The install instructions said `apk add gawk` without saying that apk is
  Alpine's and exists only inside iSH. macOS, Linux and the BSDs need nothing
  installed, and the docs and the doctor message now say so.
- `tests/run-tests.sh` had a `set -e` hazard: a command substitution capturing a
  deliberately-failing run silently ended the suite early. Fixed, and the suite
  now runs to the end under dash and bash with mawk and gawk.

## Still to do

1. Larry's GitHub username goes into `README.md` and the site; both carry the
   placeholder `larrys614`. `PUBLISHING.md` step 2 is the one command.
2. Push, and turn on Pages (Settings → Pages → main → /docs).
3. Optional: tag v1.1 and attach `bin/celnav` and `bin/colregs` to a release, so
   people who only want the tools do not have to clone.
