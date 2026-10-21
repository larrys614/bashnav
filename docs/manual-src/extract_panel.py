#  Recover a figure's panel text from the figure's own committed SVG.
#
#  Why this exists: the figures are drawn from captured program output, but
#  the captures themselves were never committed, so for a while the pictures
#  could not be redrawn at all.  figgen writes every panel line into the SVG
#  as a <text> element, so the capture is still in there - and it survives
#  because panel text is escaped with non-breaking spaces (figgen.esc) while
#  callout text keeps ordinary ones.  That one difference tells the two apart.
#
#  Run once to create cap/*.txt; after that the fixtures are the input and
#  this script is only provenance.  Captures that track the app rather than a
#  saved session - the training menu and the syllabus - are rebuilt instead by
#  capture.sh.
#
#    python3 extract_panel.py                 write cap/<name>.txt for each figure
#    python3 extract_panel.py --check         compare against the fixtures on disk
import html, io, os, re, sys

NB = " "
TEXT = re.compile(r'<text x="([0-9.]+)" y="[0-9.]+">(.*?)</text>', re.S)

def panel(svgpath):
    s = io.open(svgpath, encoding='utf-8').read()
    hits = TEXT.findall(s)
    if not hits:
        raise SystemExit("%s: no text elements" % svgpath)
    #  the panel's x is shared by every panel line; find it from the lines
    #  that carry non-breaking spaces, which only panel text does.
    xs = {}
    for x, body in hits:
        if NB in body:
            xs[x] = xs.get(x, 0) + 1
    if not xs:
        raise SystemExit("%s: found no panel text" % svgpath)
    px = max(xs, key=lambda k: xs[k])
    #  then take every element at that x, in document order, so blank
    #  panel lines come back too.
    out = []
    for x, body in hits:
        if x == px:
            out.append(html.unescape(body).replace(NB, " ").rstrip())
    return out

def main(argv):
    check = "--check" in argv
    here = os.path.dirname(os.path.abspath(__file__))
    figs = sorted(f[:-4] for f in os.listdir(os.path.join(here, "fig"))
                  if f.endswith(".svg"))
    if not figs:
        raise SystemExit("no fig/*.svg to read")
    os.path.isdir(os.path.join(here, "cap")) or os.mkdir(os.path.join(here, "cap"))
    bad = 0
    for name in figs:
        lines = panel(os.path.join(here, "fig", name + ".svg"))
        dest = os.path.join(here, "cap", name + ".txt")
        text = "\n".join(lines) + "\n"
        if check:
            have = io.open(dest, encoding='utf-8').read() if os.path.exists(dest) else None
            same = (have == text)
            bad += 0 if same else 1
            print("  %-10s %3d lines  %s" % (name, len(lines), "same" if same else "DIFFERS"))
        else:
            io.open(dest, 'w', encoding='utf-8').write(text)
            print("  %-10s %3d lines  written" % (name, len(lines)))
    if check and bad:
        raise SystemExit("%d fixture(s) differ from the committed figures" % bad)
    return 0

sys.exit(main(sys.argv[1:]))
