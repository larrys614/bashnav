# deck-log — the browser build

The boat's records: the deck log, weather, engine and provisions, in one
tool, prompting every three hours. It shares **one log** with the POSIX
`awk` build in `src/decklog/` — the same file, byte for byte, not two
formats that look alike.

    index.html        the four sections, the log, the boat, backup
    log.js            the record layer: encode, decode, build, parse
    store.js          IndexedDB, export, import and merge
    views.js          registry, holdings, open defects, shopping list
    menus.js          the VOS coded menus and the engine checklist (generated)
    decklog.js        the app
    gen/              the generator
    ../tests/         the verification

## The record layer is the one irreversible decision

    YYYY-MM-DDThh:mmZ|type|key=value|key=value|...|~

**The trailing `~` is a completeness marker**, and it is the reason the
format survives an interrupted write. Kill the app mid-write and the
half-line left behind is *structurally perfect*: right timestamp, right
type, every field a well-formed `key=value`. Nothing distinguishes it
from a finished record, so a reader accepts it and you silently lose
whatever never reached storage — an engine entry with the part but not
the hours, and no sign anything is missing. In an append-only log that
is permanent, and it is exactly the failure that would matter in an
inquiry. A truncation cannot forge the marker, because `|` is
percent-encoded inside values and so `|~` appears nowhere else.

**Values are percent-encoded** for four characters only — `%`, `|`, `=`
and newline — so ordinary text stays literal and the log is still
readable by eye and by `grep`. That matters for a file somebody may have
to interpret after an incident with no software to hand.

**A reader ignores keys it does not understand.** Adding a field to the
engine section must never break the weather reader. Everything else
about the shape follows from wanting that property.

## Four states, not two

| in the record | means |
|---|---|
| `mslp=1013.2` | observed, and here it is |
| `cld=0` | observed, and the answer was none. **Zero is a reading.** |
| `mslp=-` | asked, and **not taken** |
| `cld=/` | asked, and **not observable** — dark, fog, obscured |
| *key absent* | never asked: the section was declined, or this version had no such field |

`-` and `/` are on screen for every observed field, the same size as
everything else. A form that punishes blanks gets invented numbers:
somebody who did not read the barometer writes something plausible
rather than leave a gap that looks like negligence. A declined section
is **one record**, not fifteen empty fields.

## State is carried forward. A measurement never is.

At 1800 the course really is what it was at 1500 unless somebody changed
it, so position, course and speed are shown **in the box**, marked
*carried forward*, and committing accepts them. The pressure at 1800 is
*not* the 1500 reading unless changed — it is a new reading or it is
nothing — so the box is **empty** and the last reading sits beside the
label, greyed, as information and not as an offer. Had carry-forward
applied to everything, the log would have grown a column of barometer
readings nobody took: worse than a gap, because it looks like data.

## Plausibility is a question, not a rejection

    1132.0 hPa is outside anything recorded on earth
    — logged as typed unless you change it.

An instrument reading wrongly is itself worth logging, so "no, that is
what I read" has to be accepted, and here it is accepted by simply
leaving the value alone.

## Where it lives, and why export is the backup

The log is in IndexedDB, **one row per record, keyed by insertion
order**. Not one big string: appending must not rewrite what is already
written, and a store that rewrites its whole contents on every append is
one interrupted transaction away from losing a passage. The append-only
promise is kept by the storage, not only by the code above it.

That storage is reliable on a real origin — which is why these tools are
hosted rather than opened out of Files — but it is **per-device,
invisible, and the user can erase it** by clearing website data. So
export is not a convenience feature, it is *the backup*, and the app
treats it that way: it asks for persistent storage, says plainly whether
the browser granted it, and nags honestly when records have gone
unexported.

Export is the log itself, byte for byte. Plain text, no JSON, no
wrapper. The format was chosen so somebody could read it with no
software to hand after an incident; wrapping it on the way out would
throw that away at exactly the moment it matters.

## Import never replaces. It merges.

Replacing a log with an imported one is the most destructive thing this
app could offer and it is one mis-tap from losing a passage, so there is
no replace. The preview runs before anything is written, and a damaged
file is **rejected whole** — half an imported log is worse than none,
because you cannot tell afterwards which half you got.

The merge is a union, deduplicated on byte-identical lines, ordered by
UTC timestamp and then by the whole line. Sorting happens **on the way
out**, so storage stays strictly append-only while the exported file is
a pure function of the set of records held. That buys the two properties
which are the whole safety argument, and both are tested over generated
log pairs:

- **commutative** — merging A into B gives a byte-identical file to merging B into A
- **idempotent** — merging the same file twice changes nothing

A genuine conflict is the same timestamp *and* the same type with
different content: two people logged that slot and they disagree.
**Both are kept.** Picking one would be deleting a record, which is the
operation this format forbids, and the convention is already clear — you
do not erase a log, you line through and annotate. The merge is itself
an event, so a log that has been merged says so and says what came in.

## No stored inventory, and no invented catalogue

Holdings, open defects and the shopping list are **computed by replaying
the log** and never stored. A stored count is the obvious design and it
is the one that goes wrong: it drifts from the log, and then you have
two numbers and no way to know which lied.

Holdings are keyed by **part alone**. Keying them by part *and* by the
equipment a job recorded looks careful and is wrong: a spare belongs to
the locker, not to a machine. The moment somebody cannibalises the main
engine's impeller for the generator — which is exactly when a boat does
that — a second bucket would appear from nowhere, the main engine's
holding would never go down, and the shopping list would quietly stop
asking for the part just used.

There is **no default parts catalogue**. An earlier draft shipped one,
written from the specification's prose; the awk tool has no such list
and starts the registry empty, so shipping one here would have been the
web build inventing data about somebody else's boat and then disagreeing
with the terminal build about what was in the locker. The eighteen-item
engine checklist *is* real and is dumped from the tool's own
`CHECKLIST`. Intervals come from the owner's engine manual, never from
us: the items are universal, the hours are not.

## Told at the moment of use

    Engine logged.  ** That was your last one. **
    Holding 0, minimum 2 — 2 short. On the shopping list for the next port.
    Stowed: port bilge, box 3.

This has to arrive while the person is still standing there thinking
about it. Knowing you are out *before* you close the engine cover, while
you might still improvise, ration or nurse it, is worth more than any
report generated later — which is why the redraw happens before this
message and not after. The other way round, it was wiped a moment after
it appeared.

## Who may write to it

The log records what happened on this boat, and nothing else may write
to it. A real sight and a real fix, an observed tide height, a contact
plotted for a real CPA, anything entered at the nav desk — yes. Every
drill, quiz, scenario and sandbox sight — never. A log containing
invented vessels from a training scenario is not untidy, it is
dangerous, and no amount of "well, we would know which were real"
survives a year and a change of crew.

## Regenerating and verifying

    sh web/deck-log/gen/make-decklog-web.sh
    sh web/tests/run-decklog-web.sh

`menus.js` is **dumped from the tool's own tables**: the VOS 0–9 codes
are the standard, so a menu here is the standard and not a coarsening of
it, and not one character of them is retyped.

The verification runs the record layer in **both directions** — awk
writes and JS reads, JS writes and awk reads, byte for byte, including a
note containing `|` and `=` and a newline, and truncation at every byte
offset. Then the derived views over generated logs including one of
100,000 records, the plausibility limits *and their wording* over the
whole numeric range, the merge properties, and finally a real entry made
through the page, exported, and read back by the awk tool.

**A working record, not a substitute for the ship's official log** where
one is required. Where this and your own records differ, your own
records are right.
