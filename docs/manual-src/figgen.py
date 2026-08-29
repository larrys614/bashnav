# -*- coding: utf-8 -*-
"""Render celnav screen output as an annotated figure: a monospace panel with
callout labels outside it and arrows pointing at the thing each label names."""
import math, html, cairosvg

FS      = 13.0                 # panel monospace size
CW      = 0.60245 * FS         # DejaVu Sans Mono advance width
LH      = 1.26 * FS
LFS     = 11.0                 # label size
LLH     = 13.0
LCW     = 0.545 * LFS          # rough sans advance
PAD     = 12.0
ACCENT  = "#1f5673"
ACC2    = "#a2542a"
INK     = "#16222c"

def esc(s): return html.escape(s).replace(" ", " ")

def make(path, lines, labels, fs=FS, lfs=LFS, gap=21.0, panel_bg="#f7fafb"):
    cw, lh = 0.60245*fs, 1.26*fs
    lcw = 0.545*lfs
    ncols = max(len(l) for l in lines)
    nrows = len(lines)
    pw = ncols*cw + 2*PAD
    ph = nrows*lh + 2*PAD

    def lab_w(t): return max(len(x) for x in t.split("\n"))*lcw
    def lab_h(t): return len(t.split("\n"))*LLH

    lg = max([lab_w(l["text"]) for l in labels if l["side"]=="L"] or [0])
    rg = max([lab_w(l["text"]) for l in labels if l["side"]=="R"] or [0])
    tg = max([lab_h(l["text"]) for l in labels if l["side"]=="T"] or [0])
    bg = max([lab_h(l["text"]) for l in labels if l["side"]=="B"] or [0])
    lg += gap if lg else 0
    rg += gap if rg else 0
    tg += gap if tg else 0
    bg += gap if bg else 0

    # vertical overflow from side labels
    over_t = over_b = 0.0
    for l in labels:
        if l["side"] in ("L","R"):
            ly = PAD + l["y"]*lh
            h  = lab_h(l["text"])
            over_t = max(over_t, (h/2 + 6) - ly)
            over_b = max(over_b, (ly + h/2 + 6) - ph)
    tg += max(0.0, over_t)
    bg += max(0.0, over_b)
    px, py = lg, tg
    W, H = lg+pw+rg, tg+ph+bg
    o = []
    o.append(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W:.1f}" height="{H:.1f}" '
             f'viewBox="0 0 {W:.1f} {H:.1f}" font-family="DejaVu Sans, Helvetica, sans-serif">')
    o.append('<defs>'
             '<marker id="ah" markerWidth="8" markerHeight="8" refX="7" refY="3" orient="auto">'
             f'<path d="M0,0 L7,3 L0,6 z" fill="{ACCENT}"/></marker>'
             '<marker id="ah2" markerWidth="8" markerHeight="8" refX="7" refY="3" orient="auto">'
             f'<path d="M0,0 L7,3 L0,6 z" fill="{ACC2}"/></marker></defs>')
    o.append(f'<rect x="0" y="0" width="{W:.1f}" height="{H:.1f}" fill="#ffffff"/>')
    o.append(f'<rect x="{px:.1f}" y="{py:.1f}" width="{pw:.1f}" height="{ph:.1f}" rx="5" '
             f'fill="{panel_bg}" stroke="#bfcdd6" stroke-width="1"/>')

    def cell(r, c, span=1):
        x = px + PAD + c*cw
        y = py + PAD + r*lh
        return x-1.5, y+lh*0.11, span*cw+3, fs*1.14

    # highlight boxes first (under the text)
    for l in labels:
        for tgt in l["at"] if isinstance(l["at"], list) else [l["at"]]:
            r, c, sp = (tgt+(1,))[:3] if len(tgt)==2 else tgt
            x,y,w,h = cell(r,c,sp)
            col = l.get("color", ACCENT)
            o.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" rx="2.5" '
                     f'fill="{col}" fill-opacity="0.11" stroke="{col}" stroke-width="0.9"/>')

    # panel text
    o.append(f'<g font-family="DejaVu Sans Mono, monospace" font-size="{fs:.2f}" fill="{INK}" '
             f'xml:space="preserve">')
    for i, line in enumerate(lines):
        y = py + PAD + i*lh + fs*0.95
        o.append(f'<text x="{px+PAD:.1f}" y="{y:.1f}">{esc(line)}</text>')
    o.append('</g>')

    # labels + arrows
    for l in labels:
        t = l["text"].split("\n")
        col = l.get("color", ACCENT)
        side = l["side"]
        w = max(len(x) for x in t)*lcw
        h = len(t)*LLH
        if side == "L":
            ly = py + PAD + l["y"]*lh
            tx0 = px - gap*0.55
            ax, ay = tx0, ly
            o.append(f'<g font-size="{lfs:.1f}" fill="{col}" text-anchor="end">')
            for k, s in enumerate(t):
                o.append(f'<text x="{px-gap*0.62:.1f}" y="{ly - h/2 + (k+0.85)*LLH:.1f}">{html.escape(s)}</text>')
            o.append('</g>')
        elif side == "R":
            ly = py + PAD + l["y"]*lh
            ax, ay = px+pw+gap*0.55, ly
            o.append(f'<g font-size="{lfs:.1f}" fill="{col}">')
            for k, s in enumerate(t):
                o.append(f'<text x="{px+pw+gap*0.62:.1f}" y="{ly - h/2 + (k+0.85)*LLH:.1f}">{html.escape(s)}</text>')
            o.append('</g>')
        elif side == "T":
            lx = px + PAD + l["x"]*cw
            ax, ay = lx, py - gap*0.35
            o.append(f'<g font-size="{lfs:.1f}" fill="{col}" text-anchor="middle">')
            for k, s in enumerate(t):
                o.append(f'<text x="{lx:.1f}" y="{py - gap*0.5 - (len(t)-k-1)*LLH:.1f}">{html.escape(s)}</text>')
            o.append('</g>')
        else:  # B
            lx = px + PAD + l["x"]*cw
            ax, ay = lx, py+ph+gap*0.35
            o.append(f'<g font-size="{lfs:.1f}" fill="{col}" text-anchor="middle">')
            for k, s in enumerate(t):
                o.append(f'<text x="{lx:.1f}" y="{py+ph+gap*0.5+(k+0.8)*LLH:.1f}">{html.escape(s)}</text>')
            o.append('</g>')

        for tgt in (l["at"] if isinstance(l["at"], list) else [l["at"]]):
            r, c, sp = (tgt+(1,))[:3] if len(tgt)==2 else tgt
            x,y,bw,bh = cell(r,c,sp)
            cxs = {"L": x, "R": x+bw, "T": x+bw/2, "B": x+bw/2}
            cys = {"L": y+bh/2, "R": y+bh/2, "T": y, "B": y+bh}
            bx, by = cxs[side], cys[side]
            dx, dy = bx-ax, by-ay
            d = math.hypot(dx,dy) or 1
            ex, ey = bx-dx/d*4.5, by-dy/d*4.5
            mk = 'ah2' if col == ACC2 else 'ah'
            o.append(f'<path d="M{ax:.1f},{ay:.1f} L{ex:.1f},{ey:.1f}" stroke="{col}" '
                     f'stroke-width="1.15" fill="none" marker-end="url(#{mk})" opacity="0.9"/>')
    o.append('</svg>')
    svg = "\n".join(o)
    open(path+".svg","w").write(svg)
    cairosvg.svg2png(bytestring=svg.encode(), write_to=path+".png", scale=2.6)
    return W, H
