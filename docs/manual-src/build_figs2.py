#  Figures are drawn from the panel fixtures in cap/ - one file per figure,
#  holding the exact screen text that picture shows.  For a while the figures
#  could not be redrawn at all, because the captures they came from lived in
#  /tmp and were never committed; extract_panel.py recovered them from the
#  figures' own SVGs.  Two of them track the app rather than a saved session
#  and are rebuilt by capture.sh.
import io, os, sys
#  this file's own directory, so figgen is importable however the script is
#  invoked -- python3 -I drops the working directory, which is what the old
#  hard-coded path here was standing in for.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from figgen import make, ACCENT, ACC2

HERE = os.path.dirname(os.path.abspath(__file__))

#  CAPIN points the fixtures somewhere else, so a rebuilt set can be run
#  through the generators and compared before it replaces the committed
#  one -- the same role FIGOUT plays for the output.
CAPIN = os.environ.get("CAPIN") or os.path.join(HERE, "cap")

def cap(name):
    p = os.path.join(CAPIN, name + ".txt")
    if not os.path.exists(p):
        raise SystemExit("missing fixture %s - run extract_panel.py" % p)
    return [l.rstrip("\n").rstrip() for l in io.open(p, encoding="utf-8")]

def at(lines, row, sub, span=None):
    c = lines[row].index(sub)
    return (row, c, span or len(sub))

def _only(lines, sub):
    hit = [k for k, l in enumerate(lines) if sub in l]
    if len(hit) != 1:
        raise SystemExit("anchor %r matched %d lines, expected 1" % (sub, len(hit)))
    return hit[0]

def fat(lines, sub, span=None):
    #  Anchor on a unique string wherever it has moved to, so adding a
    #  lesson does not silently point a callout at the wrong line.
    return at(lines, _only(lines, sub), sub, span)

def to_end(lines, sub):
    #  Anchor from a string to the end of its line - for figures that show
    #  a count or a progress figure that is expected to change.
    r = _only(lines, sub); c = lines[r].index(sub)
    return (r, c, len(lines[r]) - c)

# ---- FIG 5: the learn menu + syllabus -------------------------------
#  These two track the APP, not a saved session, so capture.sh rebuilds
#  their fixtures from the built program.  Their callouts are anchored by
#  search rather than by row, because adding a lesson moves every row
#  below it and a row-anchored callout would then point at the wrong line
#  while still rendering perfectly.
menu = cap("train")
syl  = cap("syllabus")
labs=[
 dict(side="R", y=1.0, at=to_end(menu,"lessons "),
      text="Kept between sessions: how many\nlessons you have finished and how\nthe drills have gone."),
 dict(side="L", y=3.2, at=[fat(menu,"1  Lessons"),fat(menu,"2  Walkthrough")],
      text="The teaching track: lessons from\nfirst principles, and one real sight\nexplained line by line."),
 dict(side="L", y=6.4, at=[fat(menu,"3  Drills"),fat(menu,"4  Sandbox")], color=ACC2,
      text="The practice track: problems built\nfrom the real almanac and marked,\nand a what-if mode."),
]
make("fig/train", menu, labs)

labs=[
 dict(side="L", y=6.0, at=[at(syl,4,"[x]"),at(syl,5,"[x]"),at(syl,6,"[x]")],
      text="Lessons you have\nfinished."),
 dict(side="R", y=3.0, at=fat(syl,"FOUNDATIONS"),
      text="Five modules: foundations, time and the\nalmanac, the sextant, reduction and the\nfix, then choosing bodies and checking\nthe compass against them."),
 dict(side="R", y=22.0, at=fat(syl,"F1, R3"), color=ACC2,
      text="Jump to any lesson by code, or\npress n for the next unfinished one."),
]
labs.append(dict(side="L", y=16.0, at=fat(syl,"REDUCTION AND THE FIX"), color=ACC2,
      text="Each lesson ends with a question.\nAnswer it correctly and the lesson\nis ticked off."))
make("fig/syllabus", syl, labs)

# ---- FIG 7: the navigational triangle -------------------------------
tri = cap("triangle")
labs=[
 dict(side="L", y=2.0, at=at(tri,2,"N"),
      text="The rim is your horizon,\nnorth at the top."),
 dict(side="L", y=8.0, at=[at(tri,14,"Z")],
      text="Z - your zenith, the point\nstraight above your head."),
 dict(side="L", y=14.0, at=[at(tri,11,"90-L")], color=ACC2,
      text="Side Z to P: 90 minus your\nlatitude, the co-latitude."),
 dict(side="R", y=2.0, at=[at(tri,7,"P")],
      text="P - the elevated pole. Its height\nabove the horizon is your latitude."),
 dict(side="R", y=7.5, at=[at(tri,15,"*"),at(tri,10,"90-d")],
      text="The body, and the side to it from\nthe pole: 90 minus the declination."),
 dict(side="R", y=13.5, at=[at(tri,15,"90-Hc")],
      text="Side Z to the body: 90 minus the\naltitude - the zenith distance you\nare solving for."),
 dict(side="B", x=34.0, at=[at(tri,29,"computed altitude Hc 43.71      azimuth Zn 95.3 T")], color=ACC2,
      text="You know two sides and the angle between them at P - that angle is LHA.\nSolving the triangle gives the third side (so Hc) and the angle at Z (so Zn).\nIn the sandbox you change one number and watch the whole shape move."),
]
make("fig/triangle", tri, labs)

# ---- FIG 8: a drill, marked ------------------------------------------
dr = cap("drill")
labs=[
 dict(side="L", y=2.5, at=[at(dr,2,"11 36.0'S   011 48.0'W"),at(dr,3,"314 51.8'"),at(dr,4,"N05 59.2'")],
      text="Real figures, generated from the\nbuilt-in almanac - a different\nproblem every time."),
 dict(side="L", y=8.0, at=[at(dr,7,"CORRECT"),at(dr,8,"CORRECT")], color=ACC2,
      text="Your answers, marked to a\ntolerance of 0.3' and half\na degree."),
 dict(side="R", y=11.0, at=[at(dr,10,"LHA = GHA + longitude")],
      text="Right or wrong, it then shows the\nwhole working, so a mistake tells\nyou where you went astray."),
]
make("fig/drill", dr, labs)
print("figs 5-8 done")
