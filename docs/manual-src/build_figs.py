import sys, re
sys.path.insert(0,'/home/claude/celnav/doc')
from figgen import make, ACCENT, ACC2

def grab(path, start, end=None, n=None):
    L=[l.rstrip('\n') for l in open(path)]
    i=next(k for k,l in enumerate(L) if start in l)
    if n: return L[i:i+n]
    j=next(k for k,l in enumerate(L) if k>i and end in l)
    return L[i:j+1]

def at(lines, row, sub, span=None):
    c=lines[row].index(sub)
    return (row, c, span or len(sub))

# ---------------------------------------------------------------- FIG 1 menu
m=[l.rstrip('\n') for l in open('/tmp/fig_menu.txt')]
m=[l for l in m if l.strip()!='' or True][1:14]
m=[l for l in m]
# trim to the banner block
i=next(k for k,l in enumerate(m) if l.startswith('  ==='))
menu=m[i:i+13]
menu=[l.rstrip() for l in menu]
while menu and menu[-1].strip() in ('','>'): menu=menu[:-1]
menu.append('  > 2')
for k,l in enumerate(menu): print(k, repr(l))

labs=[
 dict(side="L", y=1.0, at=at(menu,3,"DR 35 00 N  040 00 W"),
      text="The position the sights\nare reduced from."),
 dict(side="L", y=4.4, at=at(menu,4,"eye 2.5 m   index error 0.0'"), color=ACC2,
      text="The sextant and weather\nfigures now in force."),
 dict(side="L", y=7.6, at=[at(menu,6,"1  Enter a sight"),at(menu,7,"2  Reduce sights -> FIX")],
      text="The working cycle: enter each\nsight as you take it, then\nreduce the whole round at once."),
 dict(side="L", y=11.0, at=at(menu,8,"3  Sight planning / stars"),
      text="Run before twilight - what is\nup, how high, and the best\nthree to shoot."),
 dict(side="R", y=1.0, at=at(menu,3,"course 000 T   speed 0 kn"),
      text="Course made good and speed.\nWith these set, every line of\nposition is advanced to the\nfix time for you."),
 dict(side="R", y=4.6, at=at(menu,4,"sights logged: 3"), color=ACC2,
      text="Sights waiting to be reduced."),
 dict(side="R", y=7.6, at=at(menu,9,"8  Sextant and weather settings"), color=ACC2,
      text="Sets the two figures\nhighlighted above."),
 dict(side="B", x=len(menu[11])*0.63, at=at(menu,11,"d  Check setup"), color=ACC2,
      text="Checks your awk, your clock and the data folder,\nthen runs the built-in self test."),
 dict(side="B", x=4.0, at=(12,2,3),
      text="Type a number\nand press return."),
]
W,H = make("fig/menu", menu, labs)
print("menu", W, H)

# ---------------------------------------------------------------- FIG 2 plot
L=[l.rstrip('\n') for l in open('/tmp/fig_fix.txt')]
i=next(k for k,l in enumerate(L) if 'INTERCEPT PLOT' in l)
j=next(k for k,l in enumerate(L) if k>i and '1 column' in l)
plot=[l.rstrip() for l in L[i:j+1]]
plot=[l for l in plot]

labs2=[
 dict(side="L", y=5.0, at=(5,2,4),
      text="Line of position 'a', from the\nsight of Dubhe. Every LOP is\ndrawn at right angles to that\nbody's azimuth."),
 dict(side="L", y=11.5, at=[at(plot,12,"@")], color=ACC2,
      text="The fix - where the three\nlines of position meet."),
 dict(side="L", y=17.5, at=[at(plot,12,"b"),at(plot,14,"c"),at(plot,14,"a")],
      text="Foot of each intercept. The\nletter matches the sight in\nthe table underneath."),
 dict(side="R", y=3.0, at=at(plot,1,"N"),
      text="North is up, east is right,\njust like a plotting sheet."),
 dict(side="R", y=9.0, at=[(8,31,1)],
      text="LOP 'c', from Markab. Markab\nbore 269 degrees, almost due\nwest, so its line of position\nruns nearly north and south."),
 dict(side="R", y=15.5, at=[(18,22,2)],
      text="LOP 'b', from Bellatrix."),
 dict(side="B", x=30.0, at=at(plot,14,"+"), color=ACC2,
      text="The AP: your DR position, at the centre.\nThe dotted cross through it is the\nnorth-south and east-west grid."),
 dict(side="B", x=62.0, at=at(plot,28,"1 row = 5 nm, 1 column = 2.5 nm"),
      text="The scale, chosen automatically to fit\nthe largest intercept on the sheet."),
]
make("fig/plot", plot, labs2)
print("plot done")

# ---------------------------------------------------------------- FIG 3 sky
i=next(k for k,l in enumerate(L) if 'SKY VIEW' in l)
j=next(k for k,l in enumerate(L) if k>i and 'inner rings' in l)
sky=[l.rstrip() for l in L[i:j+1]]

labs3=[
 dict(side="L", y=4.6, at=at(sky,2,"*****************"),
      text="The horizon. A body drawn\non this rim is just rising\nor just setting."),
 dict(side="L", y=10.0, at=[at(sky,7,"....")], color=ACC2,
      text="Altitude rings at 60 and\n30 degrees. Sights between\nthese two rings are the\nones worth taking."),
 dict(side="L", y=16.0, at=at(sky,13,"c"),
      text="Markab, low in the west.\nThe letters match the\nsights in the reduction."),
 dict(side="R", y=3.5, at=at(sky,5,"a"),
      text="Dubhe, high in the north."),
 dict(side="R", y=10.0, at=[at(sky,13,"+"),at(sky,12,"zenith")],
      text="The centre is straight\noverhead - the zenith."),
 dict(side="R", y=16.5, at=at(sky,16,"b"),
      text="Bellatrix, in the south-east.\nThese three are spread widely\nround the compass, which is\nwhat makes the cut a good one."),
 dict(side="L", y=0.6, at=at(sky,1,"N"),
      text="North at the top, east to the right.\nYou are looking straight up at the\nsky, not down at a chart."),
 dict(side="B", x=28.0, at=at(sky,26,"inner rings = 60 and 30 degrees altitude"), color=ACC2,
      text="The rim and the rings are the altitude scale: rim = 0 degrees,\ncentre = 90. A body halfway out stands about 45 degrees up."),
]
make("fig/sky", sky, labs3)
print("sky done")

# ------------------------------------------------------------ FIG 4 working
i=next(k for k,l in enumerate(L) if 'Sight a: Dubhe' in l)
wk=[l.rstrip() for l in L[i:i+7]]

labs4=[
 dict(side="L", y=1.0, at=at(wk,1,"Hs     19 32.1'"),
      text="Hs - what you read\noff the sextant."),
 dict(side="L", y=4.0, at=[at(wk,2,"IE         -1.5'"),at(wk,3,"Dip        -3.0'"),at(wk,4,"Ha     19 27.6'")],
      text="Index error and dip come\noff first. Ha is the\napparent altitude."),
 dict(side="L", y=7.6, at=[at(wk,5,"Ref        -2.8'"),at(wk,6,"Ho     19 24.8'")], color=ACC2,
      text="Refraction comes off next.\nHo is the true observed\naltitude - what a perfect\nobserver would have measured."),
 dict(side="R", y=0.2, at=[at(wk,1,"GHA   283 41.6'"),at(wk,2,"Dec   N61 36.5'")],
      text="The built-in almanac: where\nDubhe was over the earth at\nthat instant."),
 dict(side="R", y=4.4, at=[at(wk,2,"LHA 243 41.6'"),at(wk,3,"Hc     19 23.3'"),at(wk,4,"Zn    026 51.9'")],
      text="The navigational triangle,\nsolved at the assumed position:\nHc is the altitude you would\nhave measured from there, Zn\nthe true bearing of the body."),
 dict(side="R", y=9.2, at=at(wk,6,"Intercept    1.5 nm TOWARD"), color=ACC2,
      text="Ho minus Hc, in minutes of arc,\nwhich is miles: you are 1.5 miles\nnearer to Dubhe than the assumed\nposition was."),
 dict(side="T", x=62.0, at=at(wk,1,"assumed pos 35 00.0'N 040 00.0'W"),
      text="The DR, run back along your course and speed\nto the time of this sight."),
]
make("fig/working", wk, labs4)
print("working done")
