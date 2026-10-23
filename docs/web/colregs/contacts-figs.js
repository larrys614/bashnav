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

/* =====================================================================
   THE RELATIVE-MOTION PLOT

   Own ship at the centre, head up, and the contact where she is
   RELATIVE to own ship. In relative motion she travels in a straight
   line, so the figure is: her marks, the line through them, and which
   side of the centre it passes.
   ===================================================================== */
function plot(b) {
  var px = b.px, py = b.py, vx = b.vx, vy = b.vy;
  var nobs = b.nobs, dt = b.dt, showcpa = b.cpa;

  /*  the CPA, from the shared arithmetic rather than again here  */
  var C = root.CONTACTS.ct_cpa(px, py, vx, vy);
  var tc = C.tcpa, cpx = C.cpx, cpy = C.cpy;

  /*  the shell's scale: the furthest thing drawn, plus 8 per cent  */
  var mx = 0, i, t, x, y;
  for (i = 0; i < nobs; i++) {
    t = i * dt;
    x = Math.abs(px + vx * t); y = Math.abs(py + vy * t);
    if (x > mx) mx = x;
    if (y > mx) mx = y;
  }
  if (showcpa) {
    if (Math.abs(cpx) > mx) mx = Math.abs(cpx);
    if (Math.abs(cpy) > mx) mx = Math.abs(cpy);
  }
  if (mx <= 0) mx = 1;
  mx = mx * 1.08;

  var W = 440, H = 440, cx = W / 2, cy = H / 2, pad = 34;
  var s = svg(W, H);
  var sc = (Math.min(W, H) / 2 - pad) / mx;
  var X = function (v) { return cx + v * sc; };
  var Y = function (v) { return cy - v * sc; };

  s.setAttribute('aria-label',
    'Relative plot: ' + nobs + ' marks ' + dt + ' minutes apart, closing to ' +
    root.CONTACTS.ct_yd(C.cpa) + ' yards ' + (C.ahead ? 'ahead' : 'astern'));

  /*  range rings, so "how far does she pass" is readable and not only
      "which side". The shell has none and cannot.  */
  var step = 1000;
  while (mx / step > 4) step += (step < 5000) ? 1000 : 5000;
  for (var r = step; r <= mx; r += step) {
    el('circle', { cx: cx, cy: cy, r: r * sc, 'class': 'ct-ring' }, s);
  }

  /*  own ship's course line: the line she must cross to get from one
      side of you to the other  */
  el('line', { x1: cx, y1: pad * 0.4, x2: cx, y2: H - pad * 0.4,
               'class': 'ct-ring' }, s);

  /*  her track, from the first mark to the last, or on to the CPA  */
  var tend = (showcpa && tc > (nobs - 1) * dt) ? tc : (nobs - 1) * dt;
  if (tend > 0) {
    el('line', { x1: X(px), y1: Y(py),
                 x2: X(px + vx * tend), y2: Y(py + vy * tend),
                 'class': 'ct-track' }, s);
  }

  /*  the CPA. The MARK goes at the point, because the lesson's legend
      says "* = CPA" and the picture answers to the legend. The DISTANCE
      goes in the corner, not beside the mark: these lessons are chosen
      for near-misses, so the CPA sits almost on top of own ship, and a
      floating label there lands on the Y and on the last mark at once.
      Rendered, that was three overlapping strings in the middle.  */
  if (showcpa) {
    el('line', { x1: cx, y1: cy, x2: X(cpx), y2: Y(cpy),
                 'class': 'ct-cpa-line' }, s);
    el('path', {
      d: 'M' + (X(cpx) - 6) + ' ' + Y(cpy) + ' h12 M' + X(cpx) + ' ' +
         (Y(cpy) - 6) + ' v12',
      'class': 'ct-cpa'
    }, s);
  }

  /*  own ship: head up, at the centre  */
  el('path', {
    d: 'M' + cx + ' ' + (cy - 13) + ' L' + (cx + 7) + ' ' + (cy + 6) +
       ' L' + cx + ' ' + (cy + 2) + ' L' + (cx - 7) + ' ' + (cy + 6) + ' Z',
    'class': 'ct-own'
  }, s);
  txt(s, cx, cy + 22, 'Y', 'ct-own-lab', 'middle');

  /*  her marks, last so a mark you took is never hidden  */
  for (i = 0; i < nobs; i++) {
    t = i * dt;
    x = X(px + vx * t); y = Y(py + vy * t);
    el('circle', { cx: x, cy: y, r: 3.5, 'class': 'ct-mark' }, s);
    txt(s, x + 7, y + 4, String(i + 1), 'ct-num');
  }

  /*  the shell's scale label, its arithmetic unchanged  */
  txt(s, 8, 18, (Math.trunc(mx * 2 / 100 + 0.5) * 100) + ' yd across', 'ct-lab');

  /*  and the CPA in words, where there is room for it. Which SIDE she
      passes is only worth saying when the miss is big enough for the
      side to mean anything; at a hundred yards it is not a pass.  */
  if (showcpa) {
    txt(s, 8, H - 10,
        'CPA ' + root.CONTACTS.ct_yd(C.cpa) + ' yd' +
        ((C.cpa >= 200) ? (C.ahead ? ', passing ahead' : ', passing astern') : ''),
        'ct-own-lab');
  }
  return s;
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
