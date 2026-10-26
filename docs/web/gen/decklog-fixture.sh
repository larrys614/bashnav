#!/bin/sh
#  One boat, used by two builds.
#
#      sh docs/web/gen/decklog-fixture.sh <dir>
#
#  Writes <dir>/boat and <dir>/log: a small cruising boat with two
#  machines, three parts, a stocktake, an open finding and one job that
#  consumed a spare.
#
#  WHY IT EXISTS. deck-log's two site pictures were photographs of an
#  EMPTY app - "No equipment yet", "No part has moved yet" - and the one
#  claim that makes the tool worth having is the one thing an empty
#  locker cannot show: the holding is DERIVED by replaying the log and is
#  never stored. A reader cannot see a count come down from a job that
#  used a part if no part was ever used.
#
#  WHY ONE FILE AND NOT TWO. The README prints shell output beside the
#  browser's picture of the same screen, and this project has already
#  been bitten once by a figure and its prose being two different runs:
#  the celnav plot sheet was captured with ie 0 and he 2.5 while the text
#  next to it quoted a run with 1.5 and 3.0, so the picture's intercepts
#  and the README's disagreed. The registry and the log are the SAME
#  format in both builds - that was a deliberate choice in views.awk and
#  views.js - so one fixture can feed the shell and the browser, and the
#  two cannot drift.
#
#  WHAT THE NUMBERS SAY, which is the point of choosing these ones:
#  the locker was counted at 2 impellers on 20 Aug, a job on 28 Aug used
#  one, so the derived holding is 1 against a minimum of 2 and the
#  shopping list asks for exactly one. Nothing stores "1". The strainer
#  finding of 26 Aug stays open because no job has recorded closing it.
set -e
[ -n "$1" ] || { echo "usage: $0 <dir>" >&2; exit 2; }
mkdir -p "$1"

cat > "$1/boat" <<'BOAT'
eq|id=eng.main|name=main engine|make=Yanmar|model=4JH4-TE|serial=E12345|plate=4JH4-TE S/N E12345|~
eq|id=gen|name=generator|make=Onan|model=MDKBH|serial=G90231|plate=MDKBH S/N G90231|~
pt|id=impeller|name=raw water impeller|number=Jabsco 17937-0001|fits=eng.main|min=2|stow=box 3, port locker|~
pt|id=fuelfilt|name=primary fuel filter|number=Racor 2010SM-10|fits=eng.main|min=2|stow=box 3, port locker|~
pt|id=gimpeller|name=generator impeller|number=Jabsco 22405-0001|fits=gen|min=1|stow=box 4|~
BOAT

#  The nav and wx lines are here for the ENTRY screen: position, course
#  and speed are state in deck-log, shown as they were last logged, and
#  a blank form cannot show that either.
cat > "$1/log" <<'LOG'
2026-08-20T14:00Z|inv|action=stocktake|part=impeller|count=2|who=LS|~
2026-08-20T14:00Z|inv|action=stocktake|part=fuelfilt|count=2|who=LS|~
2026-08-20T14:00Z|inv|action=stocktake|part=gimpeller|count=1|who=LS|~
2026-08-26T09:15Z|eng|eq=eng.main|insp=raw water strainer|state=a|note=weed in the basket, flow down|who=LS|~
2026-08-28T16:40Z|eng|eq=eng.main|job=changed the raw water impeller|part=impeller|qty=1|fits=eng.main|hours=1242.0|who=LS|~
2026-08-29T09:00Z|nav|lat=41 14.0N|lon=072 05.0W|crs=215|sog=6.4|wdir=210|wspd=14|sea=3|~
LOG
