# Sources

Where the content in these tools comes from, and how each kind of source is
used. Cited so a later session can check the claims rather than trust them.

---

## The rule

**Facts and methods are free; expression is not.** Everything here is written
from the rules, the physics and standard practice, in our own words. No text,
diagram or table is reproduced from a copyrighted source, and no training
organisation's course material, assessment or procedure is used.

Standard sailing vocabulary is a case in point. The parts of a sail have been
called this for centuries, "ready about" and "lee ho" are older than anyone now
sailing, and a bow spring holds a boat the same way in every marina in the
world. None of it belongs to anybody.

---

## Lift, trim and balance

The physics is the part most often taught wrongly, so it is the part checked
hardest.

- **NASA Glenn Research Center**, *Incorrect Lift Theory* (Beginner's Guide to
  Aeronautics). Why equal-transit / longer-path is wrong, and the measurement
  that kills it — the computed lift does not match the measured lift.
  <https://www.grc.nasa.gov/WWW/K-12/VirtualAero/BottleRocket/airplane/wrong1.html>
- **McLean, D.** (2018) "Aerodynamic Lift, Part 1: The Science", *The Physics
  Teacher* **56**(8), 516–520.
- **McLean, D.** (2018) "Aerodynamic Lift, Part 2: A Comprehensive Physical
  Explanation", *The Physics Teacher* **56**(8), 521–524.
  <https://doi.org/10.1119/1.5064559> — that pressure and velocity stand in a
  reciprocal cause-and-effect relationship, and neither is prior. This is the
  source for the app refusing to pick a side between "Newton" and "Bernoulli".
- **Babinsky, H.** (2003) "How do wings work?", *Physics Education* **38**(6),
  497–503. <https://doi.org/10.1088/0031-9120/38/6/001> — where streamlines
  curve there is a pressure gradient across them, low pressure on the inside of
  the curve. The part that works without an equation.
- **Gentry, A.** (1971) "The Aerodynamics of Sail Interaction", 3rd AIAA
  Symposium on the Aero/Hydronautics of Sailing, Redondo Beach, California —
  the slot between headsail and main, and why it is not a venturi.

**Do not link gentrysailing.com.** The domain has lapsed and now redirects to a
gambling site. Cite Gentry from the symposium proceedings or a library copy.

### Book-length, for when a claim needs more than a paper

- **Marchaj, C. A.** (2002) *Sail Performance: Techniques to Maximize Sail Power*
- **Fossati, F.** (2009) *Aero-hydrodynamics and the Performance of Sailing Yachts*
- **Larsson, L. & Eliasson, R. E.** (2007) *Principles of Yacht Design* — the
  standard treatment of centre of effort, centre of lateral resistance and lead
- **Garrett, R.** (1996) *The Symmetry of Sailing: The Physics of Sailing for Yachtsmen*

---

## What each kind of source is good for

**Public-domain government data** — NOAA and the like. The only class we can use
*directly*, and `tides` does: its harmonic constants are NOAA (public domain)
and TICON-4 (CC BY 4.0). NOAA is also the right source for marine weather and
the structure of the wind over the sea — **the wind gradient is the entire
reason twist exists**, and it is a measured, published atmospheric boundary
layer rather than an assertion.

**Sailmakers' technical libraries** — North Sails, Quantum and the like.
Excellent on *practice*: nobody knows better what good trim looks like or how a
shape changes with halyard, sheet and car. But they are commercial copyrighted
publications, so read for facts and write our own words; and their *physics*
varies in quality, with some still telling the equal-transit story. Take trim
from them and mechanism from the academic sources, never the reverse.

**The aeronautical and yacht-research literature** — the AIAA sailing symposia,
the yacht research units, the experimental-fluids journals. Paywalled and
pitched high, but this is the layer that settles arguments.

**Wikipedia** — a decent map of the territory and a good reading list. A place
to find sources, never a source.

---

## COLREGS

`colregs` is written from the Convention itself. The COLREGs as published by
the IMO are what govern; where the program and the Convention differ, **the
Convention is right and the program is wrong**. Annex I light positioning is
checked mechanically in `tests/annex1-check.awk`, including Annex I 3(b) — that
sidelights sit at or abaft the forward masthead light, never in front of it.

## Tides

Validated against **NOAA's own published tide tables**, not against another
implementation of the same theory. See `docs/TESTING.md` for why that
distinction found three real bugs that a library-to-library comparison would
have passed.
