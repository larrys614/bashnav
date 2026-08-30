# Changelog

## Documentation - so this can be picked up cold

Four documents so a later session, or anybody else, can understand what is
here without reading eight thousand lines of awk:

- `CLAUDE.md` - the orientation file. What this is, the five rules that break
  things silently, and where to look next.
- `docs/ARCHITECTURE.md` - why one tool is one file, how the engines are
  packed as heredocs and extracted on first run, the strict shell/awk split
  and the `cmd=` engine interface, the tide data pipeline and its licensing.
- `docs/HACKING.md` - the portability traps, each tied to the bug that taught
  it: awk built-in variable names, parameter/function shadowing, mawk
  resolving functions at parse time, the tty test inside a command
  substitution, `while read ... done < file` eating the loop body's stdin.
  Plus the full bug ledger.
- `docs/TESTING.md` - what the suite checks and why each check exists, why
  validation is against NOAA's published tables rather than another
  implementation, and the two things that still need a human eye.

`REPO-STATE.md` rewritten - it still said MIT and "nothing is published yet".

Also: the README described "the two questions a tide table is actually for -
is there enough water, and does the mast clear the bridge." That was a tidy
pair rather than an honest ranking. Enough water is the real question;
clearance is narrow. Corrected, and a paragraph added saying plainly that a
tide height is not a tidal stream - the rise and fall is the vertical, set and
drift is the horizontal, and nothing in this tool predicts a current.

## README - the lights picture was never rendering

An unclosed ```` ```sh ```` fence in "Colour and night vision" swallowed the
whole block that follows it: the `<img>` for `colregs-lights.svg`, the
`<details>` around the copyable text, and the plain-text version of the
picture itself. GitHub printed the img tag as source and rendered no image at
all - and a missing picture and a colourless one look identical from the
outside, which is how it was reported and why it took three rounds to find.
The picture itself was correct the whole time.

Fixed, and `tests/readme-check.awk` now runs in the suite: fences must close,
`<details>` must balance, every `<img>` must sit outside every fence and point
at a file that exists, and all four pictures must be present. All three
failure modes were watched fail before the check was trusted.

## tides 1.1 - 2026-08-29

Finding a station without knowing its name.

Typing a station's exact name was hopeless, and that put the whole tool
behind a wall: the database calls a place `NEW LONDON  State Pier`, or
`Chappaquoit Point  West Falmouth Harbor`, and nobody guesses that.

- **Every word has to appear, in any order, anywhere inside a word.**
  `lon new` finds New London just as well as `new london` does, and both
  find it whatever the database calls it.
- **Regular expressions**, used automatically the moment the text
  contains any of `^ $ . [ ] | ( ) * + ? { } \` - `^st mary`, `bay$`,
  `falmouth|mystic`, `port.*bay`, `^boston$`. The pattern is matched
  against the name, the state and the country *separately*, so anchors
  anchor to the name rather than to the three fields run together.
- **A malformed pattern is caught before it is used.** awk cannot catch a
  bad regular expression - it aborts the run - so the pattern is checked
  first and anything that fails the check is searched as plain text.
  Refusing to answer is worse than answering the obvious way.
- **The list is ranked**, so a place whose name *is* what you typed is not
  buried under thirty places that merely contain it.
- **Searching from the menu keeps asking** until you choose something or
  give up. A first guess is usually wrong, and walking back out to the
  menu to try again is what makes people stop looking.
- The list drops the station id, which can run to seventy characters, and
  shows the rest of the name, the state and which dataset it came from -
  which is where the disambiguation actually lives.
- The number you pick now comes from a machine-readable list the engine
  writes during the same run that drew the screen, rather than from
  scraping the drawing. A station called "Pier 39" would have broken that.

## tides 1.0 - 2026-08-29

The third tool. Harmonic tide prediction with no network and no
subscription: 8,334 stations, 6,090 with their own harmonic constants and
2,244 that offset from a neighbour, which is exactly how a printed tide
table is built.

    tides near 41.2333 -72.0833     the stations nearest a position
    tides find "new lon"            or by name
    tides use noaa/8461490          choose one
    tides today                     the table, the curve, and now
    tides sky                       the same, with the moon and the sun

- **The day's table** in the station's own standard time, no summer time,
  exactly like a printed table - that is what the offsets in the data are
  referenced to.
- **The curve**, 24 hours across with the turns marked and now shown.
- **The moon and the sun**: rise, set, civil twilight, the phase drawn
  from its terminator, and whether this moon is springs or neaps.
- **Depth and clearance** - the two questions a tide table is actually
  for. Charted depth plus tide against your draught and the water you want
  under the keel, reported as the stretches of the day when there is
  enough; and a bridge's charted height minus the tide against your air
  draught.

Checked against NOAA's own published tables rather than against another
implementation of the same theory: 24 turns at six stations spanning small
and large ranges, mixed and diurnal regimes. Mean 2.4 minutes and 1.0 cm,
worst 5.9 minutes and 2.0 cm. The fixture is committed, so it runs offline.

Three bugs found by that comparison, all invisible to a test that only
checked the code against itself: a rate variable named RS (awk's record
separator, which made the next getline swallow the whole station file),
shallow-water constituents left with a speed of zero (every overtide
became a DC offset that drifted with the date), and SA carrying Foreman's
Doodson numbers while the constants are referenced to h alone - a phase
thrown by 283 degrees, worth 8 cm in August and -6 cm in February.


## celnav 1.6 - 2026-08-29

Added
- The plot legend now says why a near-vertical line of position steps a
  column part way down, and how far off vertical that is in miles. It
  looks like a drawing fault and is not: a cell is half as wide as it is
  tall, so a line within a couple of degrees of vertical must either step
  once or be drawn wrong - and one degree over the height of the sheet is
  a real distance, not a rounding error. Reported by a reader who counted
  the columns.

## colregs 1.15 - 2026-08-29

Fixed
- **Picking a section in `colregs review` ignored everything you typed.**
  The loop read the key list with `while read ... done < keyfile`, which
  redirects the loop body's stdin to that file - so every prompt inside it
  read the next KEY as if it were the answer, and the whole section
  scrolled past unanswered. "Carry on from where I left off" was fine;
  choosing Encounter verdicts, or any other section, was not. Now tested
  by driving the session the way a person does, which is the only way this
  class of bug is ever visible.
- The issue link no longer asks for a `review` label. A label that does not
  exist in the repository is one more thing that has to be set up
  correctly before a stranger's careful review will go anywhere, and the
  title already says what it is.
- If the link cannot be found, the tool now says why: the repository is not
  published yet, nothing was lost, and the report is a file on your own
  machine that can be sent whenever it is up.

## colregs 1.14 - 2026-08-29

Added
- **`colregs review`** - the claims no test can check, put to a person one
  at a time, with the drawing in front of them. All 153 of them: the 28
  encounter verdicts first because they say what to DO, then the 65
  distinct give-way calls, the 20 light tables, the lesson answers, the
  sound signals and the day shapes. Each says what the program claims and
  which rules to check it against. Mark it right, mark it wrong and say
  why, or skip. Progress is a file in your own home directory and the
  session resumes where you left it.
- **Sending it back, without a network.** `review` then builds a report and
  prints a link that opens a GitHub issue with the findings already in it.
  The program does not send anything: you open the link, and GitHub signs
  the issue with your own account. So there is no credential in this
  open-source code to leak, no server for anyone to run, and no email
  address collected by anybody - the identity comes free from GitHub. A
  review too long for a URL is written to a file instead, with the same
  instructions, rather than being silently truncated.
- Your drill record can be attached to the report as signal for triage. It
  is not a gate: a reviewer who disagrees with the program is the one most
  worth hearing from, and a score threshold would select precisely for
  people who agree with it.
- `CONTRIBUTORS.md`, opt-in and name only.
- **A test that neither tool can reach the network** - no curl, wget, nc,
  /dev/tcp, no URL read with getline, nothing piped to a fetcher. The
  founding promise of both tools is now enforced by the build rather than
  by good intentions. Verified to bite by injecting each in turn.
- A test that the review session never prompts for an email address.
- Tests that all 153 claims render, that their keys are unique and well
  formed, and that a flagged item survives the round trip into the issue
  link and back out byte for byte - a review is somebody's careful work.

## colregs 1.13 - 2026-08-29

Fixed
- **Encounters 13 and 14 showed five options, with the right answer cut in
  half.** The options are separated by semicolons, and both of those
  encounters had a semicolon inside option b. So b was truncated to "Give
  way: keep well out of her way", a nonsense option c appeared reading "she
  is not under command.", and the real fourth option - "Pass close ahead -
  she cannot move." - fell off the end and was never shown at all. The
  correct answer is b in both, so a reader was being shown a mutilated
  version of the right answer next to a fragment of it.

  Found by a reader looking at the review sheet, exactly as the about
  section says these things get found. Every drill test passed throughout,
  because marking works on the letter and the letter was still b.

Added
- A separator-collision test over every packed table in the program:
  encounters (four options and a single-letter answer), day shapes, the
  twenty light tables, sound signals, and two hundred generated lights
  questions. A delimiter inside a field is silent by nature - the field
  truncates, a nonsense one appears after it, and the last falls off the
  end - so it needed a test of its own rather than an eye.

## celnav 1.5 / colregs 1.12 - 2026-08-29

Added
- **A third suite: golden files.** `tests/golden.sh` captures every screen
  the tools produce deterministically - about 26,000 lines - and commits
  them. Any change to what a user sees now appears as a readable diff that
  has to be accepted on purpose rather than noticed later. It runs in CI.
- **Annex I structural checks on the light tables.** Sidelights paired,
  level, opposite each other and no higher than three quarters of the
  masthead light; arcs summing to a full circle with no gap; no two lights
  in the same place. Each check was verified to bite by breaking that rule
  in turn.
- **`about` section 3: what is tested, and what is not.** Both tools now
  list what the suites cover and then say plainly what no test can reach:
  that a test can check the quiz marks answer C as correct but not that C
  is right; that it can check a light table is geometrically consistent but
  not that a mine clearance vessel shows those lights.
- **The feedback screen now ranks where feedback is worth most**, by how
  much damage a wrong claim would do - give-way verdicts first, because a
  wrong light table makes you misname a ship and a wrong verdict makes you
  turn the wrong way. Same list on the site.
- `tests/review-pack.awk` dumps every claim a machine cannot check,
  generated from the same tables the code runs on. `tests/REVIEW.md` is the
  plan for reviewing them.
- A test that the numbers the about section quotes still match the program,
  so the documentation cannot quietly start lying about itself.

Fixed
- `docs/make-site.sh` named engine versions by hand, so three plates on the
  site had been silently failing to render since the last version bump. It
  now takes the version from the tools.

## celnav 1.4 / colregs 1.11 - 2026-08-29

Added
- **`colregs style`** - a setting for how a relative bearing is spoken,
  because the right answer depends on who is listening. Five choices, each
  described on the selection screen before you pick: Red and Green (Royal
  Navy and British), Port and starboard (United States and merchant),
  relative full circle ("340 relative"), words only ("fine on the port
  bow"), or true bearing alone. It changes the report and the relative
  column on the tracking plot. The true bearing is always given as well,
  because that is what goes on the chart.
  Reachable as `colregs style`, `s` from the contacts menu, or `s` from
  the main menu. It persists between runs.
- The reveal's follow-up line now always gives the OTHER form - if the
  style is words, it offers Red/Green, and the other way round.
- The About section now names the boats: USS Alaska (SSBN-732), USS
  Lafayette (SSBN-616), USS Gato (SSN-615) and USS Greenling (SSN-614),
  1984 to 1990.

Changed
- `YOUR-GITHUB-USERNAME` is now `larrys614` throughout - the README, the
  site, and the feedback screen inside both tools. Nothing is left blocking
  a first push.

## colregs 1.10 - 2026-08-29

Added
- **Relative bearings, throughout.** A true bearing is for the plot; a
  relative bearing is for the eye. The report now carries both, the
  tracking exercise shows a relative column beside the true one, and the
  reveal ends with the plain-words version for anyone who still cannot
  find her.
- **C7, relative bearings** - Red and Green (and why the colours are the
  sidelights), port and starboard, the American full-circle relative
  bearing, and the words that need no number: right ahead, fine on the bow,
  broad on the bow (four points, 45), on the beam, broad on the quarter,
  fine on the quarter, right astern. With a rose drawn from the same
  definitions the code uses, so the picture cannot disagree with the words.
- C7 also carries the trap: **a relative bearing moves when YOU turn.**
  Alter twenty degrees and every contact draws twenty degrees the other way
  with nothing having happened in the water. So bearing drift is measured in
  true bearings, or on a steady course, and never across a turn - which
  everything in C2 and C3 quietly assumed and never said.
- C4 now includes the relative bearing in the anatomy of the report, and
  notes that this half of it goes stale the moment you alter course.

Changed
- One relative-bearing vocabulary now serves the whole tool. The lights
  reveal ("you are broad on her port bow") and the contacts report come
  from the same function, so the same phrase always means the same angle.
  A test walks every degree of the circle and checks that Red/Green, the
  words and the side all agree.

## celnav 1.3 / colregs 1.9 - 2026-08-29

Changed
- **Licence: MIT to Apache 2.0.** Same freedoms - use it, sell it, fork it
  closed - with three things MIT does not give: an explicit patent grant
  from every contributor, a requirement that modified versions say they
  were modified, and protection of the author's name from being used to
  endorse a fork. A NOTICE file now carries the copyright and the
  third-party attributions that travel with the tide data (NOAA public
  domain; TICON-4 under CC BY 4.0, whose terms this licence does not
  change).

Added
- **`about` in both tools**, in five parts: why it exists and who wanted it,
  how it was written and what went wrong while it was, where the numbers
  come from, how to send feedback, and the licence and warranty. Reachable
  as `celnav about` / `colregs about`, or `a` from either menu.
- The "how it was written" section names the three bugs that testing and
  users found and that reading the code did not, because that is the honest
  argument for sending feedback.
- Tests that the about section has all five parts in both tools, and that
  the licence the programs claim is the licence actually in LICENSE and
  NOTICE - with no MIT left anywhere in the built files.

## colregs 1.8 - 2026-08-29

Added
- **`colregs contacts`** - managing contacts by bearing drift, the way a
  tracking party does it. Six lessons and two exercises.
  - C1 relative motion: she travels in a straight line relative to you, so
    the bearing sweeps one way and can never reverse.
  - C2 the rule itself: a bearing drawing AWAY from your bow passes astern,
    a bearing drawing TOWARD it crosses ahead. Not a rule of thumb - a
    consequence of the straight line, checked against 700,000 random
    geometries with no exceptions, and against every contact the exercise
    generates on every test run.
  - C3 constant bearing, decreasing range, and the half of Rule 7 that kills
    people: 7(d)(ii), risk despite good drift - a very large vessel whose
    bow is nearer than the bridge you plotted, a tow, close range.
  - C4 the report: designation, bearing, drift, range, CPA and time, why
    bearing comes before drift, and why "steady" must be said out loud.
  - C5 the arithmetic - three-minute rule, six-minute rule, time to CPA, and
    one degree at one mile is 35 yards.
  - C6 Ekelund: range from the change in bearing rate across a leg change.
    R(kyd) = 1.91 x change in speed across the line of sight / change in
    bearing rate. Derived, and verified to floating point over 59,000
    geometries.
- `colregs track` - the tracking watch. Five marks three minutes apart, and
  you call the drift, where she goes, and her CPA before the plot does. The
  reveal draws the relative-motion plot and gives you the report you would
  have made.
- `colregs ekelund` - two legs, two bearing rates, how far off is she.
- `colregs card` - the whole section on one screen.

## colregs 1.6 - 2026-08-29

Fixed
- **The mine clearance vessel's three greens were on two different masts.**
  Rule 27(f) puts one green at or near the foremast head and one at each end
  of the fore yard - all on the same mast. The two yard lights had been given
  a fore-and-aft position half a hull-length forward of the masthead one, so
  at an oblique aspect they swung off to one side of the mast where nothing
  could account for them. All three now share a mast.

Added
- Lights hung on a yard are drawn joined by the yard, so three greens read as
  one on the mast and two out on the yard rather than as three scattered
  lights. Seen from dead abeam the yard is end-on and no spar is drawn,
  because the two lights really are in line.
- A "Watch out" line on the vessels whose lights contain another vessel's
  whole signal as a sub-pattern: the mine clearance vessel's top green over
  the masthead white looks like a trawler; the lower two of a restricted
  vessel's red-white-red are a fishing vessel; white over red and red over
  white are the pilot and the fisherman the other way up.

## celnav 1.2 / colregs 1.5 - 2026-08-29

Fixed
- **Colour never appeared on any terminal.** Both tools asked "am I writing
  to a terminal?" inside a command substitution, where stdout is a pipe by
  definition. The answer was always no, so every session ran in plain mode
  and the coloured lights, the highlighted AP and night mode were all dead
  code on a real terminal. The test suite only checked the other half - that
  output is clean when piped - which passed for the wrong reason. Both halves
  are now tested, on a real pty.
- Panel lines now return to the tool's own base colour at the end of the
  line instead of resetting to the terminal's profile, so text after a
  drawing is not handed back to a light background mid-screen.
- The lights quiz no longer prints the aspect ("You are fine on her port
  bow") above a question that asks you to work the aspect out. It is given
  in the answer instead, where it belongs.


## Unreleased

## colregs 1.4 — 2026-08-29
- **The lights quiz now asks two questions**, as a lookout does: what is she,
  and which way is she going. The second is answered from the lights alone —
  her green means you are in her starboard sector and she is crossing left to
  right; her red means right to left; both sidelights means end on; a
  sternlight alone means you are overtaking her; nothing but all-round lights
  means she is not making way.
- The answer also draws out who gives way, because the sidelight tells you
  that too: **see her green and you are the stand-on vessel; see her red and
  you give way.** Suggested by a user, who put it better than the rule book.
- `colregs light <key> <bearing>` says which way she is going as well.

## colregs 1.3 — 2026-08-29
- **Sidelights now overlap slightly right ahead.** The arcs were modelled as
  meeting at exactly 000, so at four degrees off her bow the picture showed one
  sidelight while the caption said you were dead ahead of her. Annex I allows
  the cut-off to fall up to three degrees outside the prescribed sector, and in
  practice there is a small arc right ahead where both sidelights are seen. The
  model now reflects that, and the aspect wording matches what is drawn.
  Reported by a user.

## colregs 1.2 — 2026-08-29
- **The lights picture no longer crops.** It was trimming blank rows off the
  top, which threw away the one thing that distinguishes a sternlight from a
  masthead light from an anchor light: how high it is. A power-driven vessel
  seen from dead astern showed her sternlight at the top of the frame, reading
  as a masthead light. The frame is now fixed, with masthead height and deck
  marked. Found by a user, which is the only way this kind of bug gets found.
- **Look-alike vessels are never offered as alternatives to each other.** Some
  views are genuinely ambiguous — a sailing vessel and a vessel under tow show
  the same lights from every angle, and from dead astern a sternlight, an
  anchor light and a small craft's torch are the same single white light. The
  quiz now computes what is actually visible from that bearing and excludes any
  vessel that would look identical, so every question has one right answer.
- When the view *is* ambiguous, the answer says so and names the vessels it
  could equally have been. That is a real lesson about looking at lights, not a
  fault to be hidden.
- `colregs sigcheck` verifies over 600 generated questions that no question
  offers two equally correct answers. It runs in CI.

## colregs 1.1 — 2026-08-29
- **Collision avoidance**: a developing situation rather than a snapshot. Three
  timed observations of bearing and range, with the scatter a hand bearing
  compass actually gives you; you decide whether risk exists, how close she will
  come, and what to do. Then the worked solution — CPA, time to CPA, and her true
  course and speed from the vector triangle — and a frame-by-frame replay of both
  tracks under the action you chose, with the CPA it actually produced.
- Snapshot encounters extended from 14 to 28: narrow channels, traffic
  separation schemes, overtaking signals, restricted visibility, aground and
  anchored vessels, mine clearance, seaplanes, pilot vessels and long tows.
- The drawing now paints itself as a black panel with light text, edge to edge,
  so it is legible whatever the terminal's own profile is. Previously a white
  foreground was set without a background, which made the artwork invisible on a
  light Terminal profile — only the coloured lamps showed.
- `colregs colours` prints a swatch so you can confirm your terminal.
- An unknown command now lists the commands that do exist instead of saying
  "try colregs help".

## celnav 1.1 — 2026-08-29
- Training mode: twenty lessons, an annotated walkthrough of a real sight, six
  kinds of marked drill, and a what-if sandbox for the navigational triangle.
- Colour, with three modes: day, night (deep red, to protect dark adaptation)
  and plain. Chosen automatically as plain when output is not a terminal.
- Replaced awk's `srand()`/`rand()` with an internal MINSTD generator. mawk
  re-seeds from the clock even when given an explicit seed, which would have
  made a drill and its marking disagree.
- The plot paints itself as its own black panel with light text, so it is
  legible whatever the terminal's own profile is. A white foreground had been
  set without a background, which made the artwork invisible on a light
  Terminal profile.
- `celnav help` lists every command, grouped into Working, Learning and Setup;
  it had been omitting everything added in 1.1. An unknown command now prints
  the list of commands that do exist.

## celnav 1.0 — 2026-08-29
- First release. Sight reduction with the full working shown, iterated
  least-squares fix, running fix, sight planning with twilight times, compass
  check, ASCII sky view and intercept plot, and an offline self test.
- Almanac computed from orbital theory: Sun, Moon, four planets, 57 navigational
  stars and Polaris. Measured against an independent ephemeris over 1990–2076.

## colregs 1.0 — 2026-08-29
- First release. Lights drawn from any angle from a physical model of each
  light's arc; day shapes; encounter scenarios with the rule that governs them;
  sound signals; and fifteen lessons on the rules themselves.
