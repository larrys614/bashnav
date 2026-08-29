import sys
sys.path.insert(0,'/home/claude/celnav/doc')
from figgen import make, ACCENT, ACC2
def at(lines,row,sub,span=None):
    c=lines[row].index(sub); return (row,c,span or len(sub))

# ---- FIG 5: the learn menu + syllabus -------------------------------
tm=[l.rstrip() for l in open('/tmp/fig_train2.txt')]
i=next(k for k,l in enumerate(tm) if l.startswith('  ==='))
j=next(k for k,l in enumerate(tm) if 'back to the navigation menu' in l)
menu=tm[i:j+1]+["  > 1"]
k=next(k for k,l in enumerate(tm) if 'LEARN -- the syllabus' in l)
e=next(x for x,l in enumerate(tm) if x>k and 'lessons done' in l)
syl=[l.rstrip() for l in tm[k:e+1]]
labs=[
 dict(side="R", y=1.0, at=at(menu,1,"lessons 4 of 20   drills 14/18"),
      text="Kept between sessions: how many\nlessons you have finished and how\nthe drills have gone."),
 dict(side="L", y=3.2, at=[at(menu,3,"1  Lessons"),at(menu,4,"2  Walkthrough")],
      text="The teaching track: twenty lessons\nfrom first principles, and one real\nsight explained line by line."),
 dict(side="L", y=6.4, at=[at(menu,5,"3  Drills"),at(menu,6,"4  Sandbox")], color=ACC2,
      text="The practice track: problems built\nfrom the real almanac and marked,\nand a what-if mode."),
]
make("fig/train", menu, labs)

labs=[
 dict(side="L", y=6.0, at=[at(syl,4,"[x]"),at(syl,5,"[x]"),at(syl,6,"[x]")],
      text="Lessons you have\nfinished."),
 dict(side="R", y=3.0, at=at(syl,3,"FOUNDATIONS"),
      text="Four modules, five lessons each:\nfoundations, time and the almanac,\nthe sextant, then reduction and the fix."),
 dict(side="R", y=22.0, at=at(syl,31,"F1, R3"), color=ACC2,
      text="Jump to any lesson by code, or\npress n for the next unfinished one."),
]
labs.append(dict(side="L", y=16.0, at=at(syl,24,"REDUCTION AND THE FIX"), color=ACC2,
      text="Each lesson ends with a question.\nAnswer it correctly and the lesson\nis ticked off."))
make("fig/syllabus", syl, labs)

# ---- FIG 7: the navigational triangle -------------------------------
tri=[l.rstrip() for l in open('/tmp/fig_tri.txt') if l.strip()!='']
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
dr=[l.rstrip() for l in open('/tmp/fig_drill.txt') if l.strip()!='']
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
