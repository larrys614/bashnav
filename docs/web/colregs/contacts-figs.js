/*  The contacts figures, drawn as SVG.

    The shell draws these on a 67 x 19 character grid, which is the only
    thing it can do and is wrong for a browser: a character grid cannot
    follow the night palette, it cannot reflow on a phone, and at that
    size a mark is one character and the CPA is an asterisk.

    So the browser is handed the parameters ct_plot() and ct_rose() were
    called with -- see docs/web/colregs/gen/dumpclesson.awk -- and draws
    the same figure properly. Same elements, same meaning, same words in
    the legend the lesson prints underneath:

        "Y = you, head up.  1 to 5 = her, three minutes apart.  * = CPA"

    That legend is prose carried from the awk, so it is not ours to
    change; the picture has to answer to it. Own ship at the centre, head
    up; her marks numbered from one; the CPA marked. The scale label is
    the shell's own arithmetic, kept so the two pictures are the same
    size in yards and not only the same shape.

    THE PLOT HAS RANGE SCALES, because a plot you cannot change the scale
    of answers one question and C1 asks a different one. Its contact
    passes 148 yards astern on a picture 28,100 yards across -- half a
    pixel, and on the shell's 67-column grid the asterisk sat on top of
    own ship's Y, so "which side of you it passes" had nothing to point
    at. The scales are the standard radar set and the rings are a
    radar's, so the habit the figure teaches is the one you use on the
    bridge: open wide to see her coming, change down as she closes, and
    read the CPA off the rings on a short scale. Marks outside the
    selected scale fall off the edge, as they do on a radar.

    NOT ONE COLOUR IS NAMED IN THIS FILE. The rest of the app reads the
    custom properties with cssvar() at draw time, which bakes the palette
    into the element, so setMode() has to redraw every view that is
    showing -- "anything already drawn was drawn in the old palette" --
    from a list in the wiring that each new view has to remember to join.
    Drawn first with cssvar(), these figures came out blue and green on
    the red night palette, which is the one thing you must not hand
    somebody on a bridge at night.

    Here the elements carry classes and colregs.css carries the colours,
    so the figure follows the toggle with no redraw and nothing to join.  */
(function (root) {
'use strict';

var NS = 'http://www.w3.org/2000/svg';
function svg(w, h) {
  var s = document.createElementNS(NS, 'svg');
  s.setAttribute('viewBox', '0 0 ' + w + ' ' + h);
  s.setAttribute('role', 'img');
  s.setAttribute('class', 'ct-fig');
  return s;
}
function el(tag, a, p) {
  var e = document.createElementNS(NS, tag), k;
  for (k in a) if (a.hasOwnProperty(k)) e.setAttribute(k, a[k]);
  if (p) p.appendChild(e);
  return e;
}
function txt(p, x, y, s, cls, anchor) {
  var t = el('text', { x: x, y: y, 'class': cls }, p);
  if (anchor) t.setAttribute('text-anchor', anchor);
  t.textContent = s;
  return t;
}
function sind(x) { return Math.sin(x * Math.PI / 180); }
function cosd(x) { return Math.cos(x * Math.PI / 180); }

/*  The standard radar range scales, and the ring interval each one is
    normally drawn with. Two thousand yards to the mile, which is what
    the whole module uses -- see the head of contacts.js and the units
    note in C6.  */
var YD_NM = 2000;
var SCALES = [
  { nm: 0.25, ring: 0.05 },
  { nm: 0.5,  ring: 0.1  },
  { nm: 0.75, ring: 0.25 },
  { nm: 1.5,  ring: 0.25 },
  { nm: 3,    ring: 0.5  },
  { nm: 6,    ring: 1    },
  { nm: 12,   ring: 2    },
  { nm: 24,   ring: 4    }
];
/*  the scale you would be on: the smallest that holds her, by RANGE and
    not by either coordinate, because that is what "on the 12-mile
    scale" means  */
function fitScale(b) {
  var far = 0, i, t, x, y, r;
  for (i = 0; i < b.nobs; i++) {
    t = i * b.dt;
    x = b.px + b.vx * t; y = b.py + b.vy * t;
    r = Math.sqrt(x * x + y * y);
    if (r > far) far = r;
  }
  for (i = 0; i < SCALES.length; i++) if (SCALES[i].nm * YD_NM >= far) return i;
  return SCALES.length - 1;
}
/*  0.25, not .25: the leading zero is how a range scale is written on a
    radar and on a chart, and a bare point is a decimal you can miss  */
function nmStr(v) { return String(v); }

/* =====================================================================
   THE RELATIVE-MOTION PLOT

   Own ship at the centre, head up, and the contact where she is
   RELATIVE to own ship. In relative motion she travels in a straight
   line, so the figure is: her marks, the line through them, and which
   side of the centre it passes.
   ===================================================================== */
function plotAt(b, si) {
  var px = b.px, py = b.py, vx = b.vx, vy = b.vy;
  var nobs = b.nobs, dt = b.dt, showcpa = b.cpa;

  /*  the CPA, from the shared arithmetic rather than again here  */
  var C = root.CONTACTS.ct_cpa(px, py, vx, vy);
  var tc = C.tcpa, cpx = C.cpx, cpy = C.cpy;

  /*  the selected range scale, in yards to the edge of the display  */
  var S = SCALES[si], mx = S.nm * YD_NM;

  var W = 440, H = 460, cx = W / 2, cy = 228, pad = 30;
  var s = svg(W, H);
  var rpx = Math.min(W / 2, cy) - pad;          // the display's radius
  var sc = rpx / mx;
  var X = function (v) { return cx + v * sc; };
  var Y = function (v) { return cy - v * sc; };
  var i, t, x, y, r;

  s.setAttribute('aria-label',
    'Relative plot on the ' + nmStr(S.nm) + ' mile scale: ' + nobs + ' marks ' +
    dt + ' minutes apart, closing to ' + root.CONTACTS.ct_yd(C.cpa) +
    ' yards ' + (C.ahead ? 'ahead' : 'astern'));

  /*  everything inside the display is clipped to it, so her track runs
      off the edge instead of across the labels, exactly as a contact
      beyond the range scale does on a radar  */
  var cid = 'ctclip' + (CLIP_N++);
  var cp = el('clipPath', { id: cid }, s);
  el('circle', { cx: cx, cy: cy, r: rpx }, cp);
  var face = el('g', { 'clip-path': 'url(#' + cid + ')' }, s);

  /*  the range rings at this scale's interval, and the edge  */
  for (r = S.ring * YD_NM; r < mx - 1; r += S.ring * YD_NM) {
    el('circle', { cx: cx, cy: cy, r: r * sc, 'class': 'ct-ring' }, face);
  }
  el('circle', { cx: cx, cy: cy, r: rpx, 'class': 'ct-edge' }, s);

  /*  own ship's course line: the line she must cross to get from one
      side of you to the other  */
  el('line', { x1: cx, y1: cy - rpx, x2: cx, y2: cy + rpx,
               'class': 'ct-ring' }, face);

  /*  her track, from the first mark to the last, or on to the CPA  */
  var tend = (showcpa && tc > (nobs - 1) * dt) ? tc : (nobs - 1) * dt;
  if (tend > 0) {
    el('line', { x1: X(px), y1: Y(py),
                 x2: X(px + vx * tend), y2: Y(py + vy * tend),
                 'class': 'ct-track' }, face);
  }

  /*  the CPA. The MARK goes at the point, because the lesson's legend
      says "* = CPA" and the picture answers to the legend. The DISTANCE
      goes in the corner, not beside the mark: these lessons are chosen
      for near-misses, so the CPA sits almost on top of own ship, and a
      floating label there lands on the Y and on the last mark at once.
      Rendered, that was three overlapping strings in the middle.  */
  if (showcpa) {
    el('line', { x1: cx, y1: cy, x2: X(cpx), y2: Y(cpy),
                 'class': 'ct-cpa-line' }, face);
    el('path', {
      d: 'M' + (X(cpx) - 6) + ' ' + Y(cpy) + ' h12 M' + X(cpx) + ' ' +
         (Y(cpy) - 6) + ' v12',
      'class': 'ct-cpa'
    }, face);
  }

  /*  own ship: head up, at the centre  */
  el('path', {
    d: 'M' + cx + ' ' + (cy - 13) + ' L' + (cx + 7) + ' ' + (cy + 6) +
       ' L' + cx + ' ' + (cy + 2) + ' L' + (cx - 7) + ' ' + (cy + 6) + ' Z',
    'class': 'ct-own'
  }, face);
  /*  the legend under the lesson says "Y = you", so the Y is not
      optional: it was lost once when own ship moved into the clipped
      group and the figure stopped answering its own caption  */
  txt(face, cx, cy + 22, 'Y', 'ct-own-lab', 'middle');

  /*  her marks, last so a mark you took is never hidden. A mark beyond
      the scale is NOT drawn at the edge -- it is not there, and drawing
      it would be the one lie a radar does not tell.  */
  var off = 0;
  for (i = 0; i < nobs; i++) {
    t = i * dt;
    x = px + vx * t; y = py + vy * t;
    if (Math.sqrt(x * x + y * y) > mx) { off++; continue; }
    el('circle', { cx: X(x), cy: Y(y), r: 3.5, 'class': 'ct-mark' }, face);
    txt(face, X(x) + 7, Y(y) + 4, String(i + 1), 'ct-num');
  }

  /*  the scale, read the way a radar states it  */
  txt(s, 8, 18, nmStr(S.nm) + ' nm', 'ct-own-lab');
  txt(s, 8, 34, 'rings ' + (S.ring < 1 ? (S.ring * YD_NM) + ' yd'
                                       : nmStr(S.ring) + ' nm'), 'ct-lab');
  if (off) {
    txt(s, W - 8, 18, off + (off === 1 ? ' mark' : ' marks') + ' beyond',
        'ct-lab', 'end');
  }

  /*  the CPA in words, where there is room for it. Which SIDE she passes
      is only worth saying when the miss is big enough for the side to
      mean anything; at a hundred yards it is not a pass.  */
  if (showcpa) {
    txt(s, 8, H - 10,
        'CPA ' + root.CONTACTS.ct_yd(C.cpa) + ' yd' +
        ((C.cpa >= 200) ? (C.ahead ? ', passing ahead' : ', passing astern') : ''),
        'ct-own-lab');
  }
  return s;
}

/*  the figure plus its range control: a container, because the control
    is what makes the figure answer C1's question and the two belong to
    each other  */
var CLIP_N = 0;
function plot(b) {
  var box = document.createElement('div');
  box.className = 'ct-wrap';
  var row = document.createElement('div');
  row.className = 'ct-rng';
  /*  no visible "RANGE nm" caption: eight scales and a caption do not
      fit across a phone and the 24 dropped to a row of its own. The
      figure states the scale it is on, so the caption was saying it
      twice; the row keeps its name for anyone not looking at it.  */
  row.setAttribute('role', 'group');
  row.setAttribute('aria-label', 'Range scale, nautical miles');
  var si = fitScale(b), btns = [], cur = null;

  function redraw(n) {
    si = n;
    var next = plotAt(b, si);
    if (cur) box.replaceChild(next, cur); else box.appendChild(next);
    cur = next;
    for (var j = 0; j < btns.length; j++) {
      if (j === si) btns[j].setAttribute('data-on', '1');
      else btns[j].removeAttribute('data-on');
      btns[j].setAttribute('aria-pressed', j === si ? 'true' : 'false');
    }
  }

  SCALES.forEach(function (S, j) {
    var btn = document.createElement('button');
    btn.type = 'button';
    btn.textContent = nmStr(S.nm);
    btn.setAttribute('aria-label', nmStr(S.nm) + ' mile range scale');
    btn.addEventListener('click', function () { redraw(j); });
    btns.push(btn);
    row.appendChild(btn);
  });
  box.appendChild(row);
  redraw(si);
  return box;
}

/* =====================================================================
   THE COMPASS ROSE

   Relative bearings, which is what you give a man who has to find her
   with his eyes. Red to port, green to starboard, nought to 180 each
   side, and the colours are the sidelights -- which is the whole reason
   the convention sticks.

   On the night palette every lamp colour is the same red, deliberately:
   the app's rule is that the LETTER disambiguates. Here it is the word,
   which is already in the label and is the reason the convention is
   spoken rather than signalled.
   ===================================================================== */
function rose() {
  var W = 440, H = 400, cx = W / 2, cy = H / 2;
  var rx = 128, s = svg(W, H);
  s.setAttribute('aria-label',
    'Relative bearings: Red to port and Green to starboard, nought right ' +
    'ahead to 180 right astern');

  el('circle', { cx: cx, cy: cy, r: rx, 'class': 'ct-ring' }, s);

  /*  the spokes, each in the colour of the side it is on, because that
      is the thing the lesson is about  */
  var marks = [45, 90, 135], i, k, th, cls;
  for (i = 0; i < marks.length; i++) {
    for (k = -1; k <= 1; k += 2) {
      th = marks[i] * k;
      cls = (k < 0) ? 'ct-port' : 'ct-stbd';
      el('line', {
        x1: cx + rx * 0.17 * sind(th), y1: cy - rx * 0.17 * cosd(th),
        x2: cx + rx * sind(th), y2: cy - rx * cosd(th),
        'class': cls + ' ct-spoke'
      }, s);
      txt(s, cx + (rx + 12) * sind(th), cy - (rx + 12) * cosd(th) + 4,
          ((k < 0) ? 'Red ' : 'Green ') + marks[i],
          cls, (k < 0) ? 'end' : 'start');
    }
  }

  /*  own ship's head, and the two ends of the scale  */
  el('line', { x1: cx, y1: cy - rx, x2: cx, y2: cy + rx, 'class': 'ct-ring' }, s);
  el('path', {
    d: 'M' + cx + ' ' + (cy - 15) + ' L' + (cx + 8) + ' ' + (cy + 7) +
       ' L' + cx + ' ' + (cy + 2) + ' L' + (cx - 8) + ' ' + (cy + 7) + ' Z',
    'class': 'ct-own'
  }, s);
  txt(s, cx, cy + 26, 'Y', 'ct-own-lab', 'middle');
  txt(s, cx, cy - rx - 18, '000 RIGHT AHEAD', 'ct-own-lab', 'middle');
  txt(s, cx, cy + rx + 26, '180 RIGHT ASTERN', 'ct-own-lab', 'middle');
  return s;
}

root.CONTACTS_FIGS = { plot: plot, rose: rose };

})(typeof window !== 'undefined' ? window : this);
