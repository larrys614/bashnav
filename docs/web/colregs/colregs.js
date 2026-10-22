/* =====================================================================
   colregs -- the web build.

   Geometry is ported function-for-function from the awk engine, with the
   same names, so the two can be read side by side and cannot quietly
   drift:  arc_vis, nrm180, the u/v projection and the hull half-width
   are all the originals.  What changes is only the output device: a
   terminal could draw a lamp as a letter on a character grid, a browser
   can draw it as a lamp.
   ===================================================================== */
(function () {
'use strict';

/*  THE BUILD, MATCHED TO THE SERVICE WORKER'S CACHE.  The worker is
    cache-first, so an installed copy keeps serving the files it already
    has: shipping a change without moving the cache ships nothing to
    anyone who has opened the page before, and to them it looks like the
    change did not work. Larry shift-reloaded this app several times
    against a cache that was never going to give it up -- CACHE had sat
    at colregs-v1 since the app was written. tests/run-tests.sh now
    refuses a build and a cache that disagree, which is the same check
    the drill app got for the same reason.  */
var BUILD = 2;

var D = window.COLREGS_DATA;
var $ = function (id) { return document.getElementById(id); };

/* ---------- storage: optional, never load-bearing ------------------- */
function remember(k, v) { try { localStorage.setItem('colregs.' + k, v); } catch (e) {} }
function recall(k, dflt) {
  try { var v = localStorage.getItem('colregs.' + k); return v === null ? dflt : v; }
  catch (e) { return dflt; }
}

/* ---------- trig, as the engine has it ------------------------------ */
function d2r(x) { return x * Math.PI / 180; }
function sind(x) { return Math.sin(d2r(x)); }
function cosd(x) { return Math.cos(d2r(x)); }
function fabs(x) { return x < 0 ? -x : x; }
function nrm360(x) { x = x - 360 * Math.floor(x / 360); return x < 0 ? x + 360 : x; }
function nrm180(x) { x = nrm360(x); return x > 180 ? x - 360 : x; }

/* Is a light with this arc visible from bearing th, 0 being dead ahead
   of her?  Masthead 225 deg, sidelights 112.5 each, stern 135. */
function arc_vis(arc, th) {
  th = nrm180(th);
  if (arc === 'A') return true;
  if (arc === 'M') return fabs(th) <= 112.5;
  /* Sidelights meet at the bow, but Annex I allows the cut-off to fall up
     to 3 degrees outside the prescribed sector, and in practice there is a
     small arc right ahead where both are seen.  Without that overlap the
     picture claims you are dead ahead of her while showing one sidelight.
     The 2.5 is the engine's, and it is deliberate - do not tighten it. */
  if (arc === 'S') return th >= -2.5 && th <= 112.5;
  if (arc === 'P') return th <= 2.5 && th >= -112.5;
  if (arc === 'T' || arc === 'Y') return fabs(th) >= 112.5;
  return false;
}

/*  Ported function-for-function from the awk engine's rel_phrase, same
    name, same arcs, same wording -- a lookout reports the arc, not the
    angle.  tests/colregs-web-diff.sh runs both over all 360 bearings and
    requires the strings to be identical, because "ported" is a claim and
    a diff is a fact.  */
function rel_phrase(rel, poss, ahead) {
  if (ahead === undefined || ahead === '') ahead = 5;
  var t = nrm180(rel), s = t < 0 ? 'port' : 'starboard';
  t = fabs(t);
  if (t <= ahead) return 'right ahead';
  if (t >= 180 - ahead) return 'right astern';
  if (t < 35) return 'fine on ' + poss + ' ' + s + ' bow';
  if (t < 65) return 'broad on ' + poss + ' ' + s + ' bow';
  if (t < 115) return 'on ' + poss + ' ' + s + ' beam';
  if (t < 145) return 'broad on ' + poss + ' ' + s + ' quarter';
  return 'fine on ' + poss + ' ' + s + ' quarter';
}

/*  PORTED, THIS TIME.  This had its own arc boundaries -- 8, 75, 105,
    172 -- where the awk delegates to rel_phrase with ahead=2.5, so the
    two implementations disagreed on 580 of the 361 aspects and said
    different things to the reader about the same geometry. The README
    claimed they could not drift; nothing checked it. Now
    tests/colregs-web-diff.sh does, and this is the awk's version
    line-for-line.  */
function aspect_words(th) {
  var t = nrm180(th), p = rel_phrase(th, 'her', 2.5);
  if (p === 'right ahead') return 'You are right ahead of her: you are looking at her bow.';
  if (p === 'right astern') return 'You are right astern of her: you are looking at her stern.';
  if (p.indexOf('beam') >= 0)
    return 'You are ' + p + ': you see her whole ' + (t < 0 ? 'port' : 'starboard') + ' side.';
  return 'You are ' + p + '.';
}

/* ---------- svg helpers --------------------------------------------- */
var NS = 'http://www.w3.org/2000/svg';
function svg(w, h) {
  var s = document.createElementNS(NS, 'svg');
  s.setAttribute('viewBox', '0 0 ' + w + ' ' + h);
  s.setAttribute('role', 'img');
  return s;
}
function el(tag, attrs, parent) {
  var e = document.createElementNS(NS, tag);
  for (var k in attrs) if (attrs.hasOwnProperty(k)) e.setAttribute(k, attrs[k]);
  if (parent) parent.appendChild(e);
  return e;
}
function cssvar(name) {
  return getComputedStyle(document.documentElement).getPropertyValue(name).trim();
}
function lampColour(c) {
  return cssvar(c === 'R' ? '--lamp-r' : c === 'G' ? '--lamp-g' :
                c === 'Y' ? '--lamp-y' : '--lamp-w');
}

/* =====================================================================
   LIGHTS
   ===================================================================== */
var lightIdx = 0, lightBrg = 40;


/* =====================================================================
   FLASHING LIGHTS

   Annex I defines a flashing light as one flashing "at regular intervals
   at a frequency of 120 flashes or more per minute" - so 2 Hz is the
   defined minimum, and that is what is rendered here.  The rate is part
   of the identification, not decoration: a steady yellow all-round light
   and a flashing one are different vessels.

   The engine's light records carry no flash flag - the fact lives in the
   prose note - so the mapping is here, explicitly, one entry, with its
   citation.  It is NOT inferred from the note text: string-matching prose
   to decide what a light does is how a wrong light gets drawn.  If a
   flashing light is added to the engine's table, add it here too.

   Only one vessel in this data set has one.  (Rule 23(c)'s WIG craft, with
   its high-intensity all-round flashing red, is not in the table at all.)
   ===================================================================== */
var FLASHING = {
  /* vessel key : which lamps flash, by colour and arc, and with what rhythm.
     'flash' is Annex I's 120-a-minute.  'group3' is the submarine's, which is
     a different rhythm and therefore a different recognition. */
  hover:     [{ col: 'Y', arc: 'A', pat: 'flash',  mark: 'fl' }],
  /* Rule 23(b) - all-round flashing yellow */
  wig:       [{ col: 'R', arc: 'A', pat: 'flash',  mark: 'fl' }],
  /* Rule 23(c) - high intensity all-round flashing red, and only while
     taking off, landing or in flight near the surface */
  submarine: [{ col: 'Y', arc: 'A', pat: 'group3', mark: 'fl(3)' }]
  /* 32 CFR 707.7, a US Navy special rule and NOT a Convention light: "one
     flash per second for three seconds followed by a three second
     off-period".  Three quick flashes then dark is the whole point - a
     steady 2 Hz flash would be a different vessel. */
};
function lampFlash(vesselKey, L) {
  var f = FLASHING[vesselKey];
  if (!f) return null;
  for (var i = 0; i < f.length; i++)
    if (f[i].col === L.col && f[i].arc === L.arc) return f[i];
  return null;
}

/* Working lights, and why they are worth drawing.

   Rule 20(b): during the hours of darkness no other lights may be shown
   except those that cannot be mistaken for the prescribed lights and do not
   impair their visibility or distinctive character.  Rule 30(c): a vessel at
   anchor MAY light her decks, and one of 100 m or more MUST.

   So this is not decoration.  The lesson is what deck lights do to the
   lights you are trying to read - which is why a trawler working with her
   decks lit is hard to identify, and why the rule is written the way it is.
   The nav lamps keep their true colours and letters; what changes is the
   contrast they have to compete against. */
var DECK_ON = false;

function drawDeck(el, s, cx, seaY, W, deckCol) {
  /* the lit deck: a warm pool over the hull, brightest amidships */
  var grad = el('linearGradient', { id: 'deckglow', x1: 0, y1: 0, x2: 0, y2: 1 }, s);
  el('stop', { offset: '0%',   'stop-color': deckCol, 'stop-opacity': 0.00 }, grad);
  el('stop', { offset: '55%',  'stop-color': deckCol, 'stop-opacity': 0.34 }, grad);
  el('stop', { offset: '100%', 'stop-color': deckCol, 'stop-opacity': 0.10 }, grad);
  el('ellipse', { cx: cx, cy: seaY - 14, rx: 176, ry: 66, fill: 'url(#deckglow)' }, s);
  /* the lamps themselves, strung along the deck */
  for (var i = -2; i <= 2; i++) {
    var x = cx + i * 54;
    el('circle', { cx: x, cy: seaY - 22, r: 9, fill: deckCol, opacity: 0.16 }, s);
    el('circle', { cx: x, cy: seaY - 22, r: 3, fill: deckCol, opacity: 0.95 }, s);
  }
}

function drawLights(vessel, th) {
  var W = 600, H = 340, seaY = 252, cx = W / 2;
  var uScale = 420, vScale = 196;
  var stage = $('light-stage');
  stage.textContent = '';
  var s = svg(W, H);
  s.setAttribute('aria-label', 'A vessel seen from bearing ' + Math.round(th));

  /* sea */
  el('rect', { x: 0, y: seaY, width: W, height: H - seaY, fill: cssvar('--sea'), opacity: 0.55 }, s);
  el('line', { x1: 0, y1: seaY, x2: W, y2: seaY, stroke: cssvar('--line'), 'stroke-width': 1 }, s);

  /* hull: she looks long on the beam and narrow bow-on, which is the
     same half-width formula the terminal version uses */
  var hw = (1.00 * fabs(sind(th)) + 0.22 * fabs(cosd(th))) / 2.0;
  var half = hw * uScale;
  if (half < 26) half = 26;
  el('path', {
    d: 'M' + (cx - half) + ' ' + (seaY - 16) +
       ' L' + (cx + half) + ' ' + (seaY - 16) +
       ' L' + (cx + half * 0.82) + ' ' + seaY +
       ' L' + (cx - half * 0.82) + ' ' + seaY + ' Z',
    fill: cssvar('--hull')
  }, s);

  var visible = vessel.lights.filter(function (L) { return arc_vis(L.arc, th); });

  /* a dropline under each lamp, so the vertical grouping is plain */
  visible.forEach(function (L) {
    var u = L.x * sind(th) - L.y * cosd(th);
    var x = cx + u * uScale;
    el('line', {
      x1: x, y1: seaY - 16, x2: x, y2: seaY - 16 - L.h * vScale,
      stroke: cssvar('--mast'), 'stroke-width': 2
    }, s);
  });

  if (DECK_ON) drawDeck(el, s, cx, seaY, W, cssvar('--deck'));

  /* the lamps */
  visible.forEach(function (L) {
    var u = L.x * sind(th) - L.y * cosd(th);
    var x = cx + u * uScale, y = seaY - 16 - L.h * vScale;
    var col = lampColour(L.col);
    var fl = lampFlash(vessel.key, L);
    /* Both circles go in a GROUP and the group is what animates.  Animating
       the circles directly would have the CSS opacity override the halo's
       own opacity="0.18" presentation attribute and destroy the glow. */
    var host = fl ? el('g', { 'class': 'lamp-' + fl.pat }, s) : s;
    el('circle', { cx: x, cy: y, r: 16, fill: col, opacity: 0.18 }, host);
    el('circle', { cx: x, cy: y, r: 7.5, fill: col }, host);
    var t = el('text', {
      x: x + 13, y: y + 5, fill: col,
      'font-family': 'ui-monospace, Menlo, monospace',
      'font-size': 15, 'font-weight': 700
    }, s);
    /* The letter carries the pattern, same discipline as the colours: a
       flashing lamp reads as flashing with no colour AND with no motion,
       which is what somebody gets who has reduced motion switched on. */
    t.textContent = fl ? L.col + ' ' + fl.mark : L.col;
  });

  if (!visible.length) {
    var n = el('text', {
      x: cx, y: seaY - 80, fill: cssvar('--dim'), 'text-anchor': 'middle',
      'font-size': 15
    }, s);
    n.textContent = 'No lights visible from this bearing.';
  }

  if (DECK_ON) {
    /* The point of the exercise.  Working lights do not change a navigation
       light; they change what it has to be seen against.  A warm wash over
       the whole scene costs the lamps their contrast, which is exactly the
       impairment Rule 20(b) is about - and exactly why she is hard to read. */
    el('rect', { x: 0, y: 0, width: W, height: H,
                 fill: cssvar('--deck'), opacity: 0.085 }, s);
  }
  stage.appendChild(s);
  $('light-aspect').textContent = aspect_words(th);
}

function lightsShow(i, th) {
  lightIdx = i; lightBrg = th;
  $('brg').value = Math.round(th);
  $('brg-out').textContent = (nrm360(th) < 100 ? ('00' + Math.round(nrm360(th))).slice(-3)
                                               : String(Math.round(nrm360(th))));
  drawLights(D.vessels[i], th);
  $('light-answer').hidden = true;
  drill('light', D.vessels, i, sigVessel, function (v) { return v.name; },
        lightsReveal, 'Show me what she is');
}
function lightsNext() {
  lightsShow(Math.floor(Math.random() * D.vessels.length),
             Math.floor(Math.random() * 360) - 180);
}
function lightsReveal() {
  var v = D.vessels[lightIdx];
  $('light-name').textContent = v.name;
  $('light-rule').textContent = v.rule + '.';
  $('light-note').textContent = v.note;
  $('light-answer').hidden = false;
}

/* =====================================================================
   DAY SHAPES
   ===================================================================== */
var shapeIdx = 0;

/* The glyph vocabulary, as real shapes rather than character art. */
function glyph(kind, cx, y, scale, s, c, bg) {
  var r = 22 * scale, h = 0;
  if (kind === 'ball') {
    el('circle', { cx: cx, cy: y - r, r: r, fill: c }, s); h = r * 2;
  } else if (kind === 'diamond') {
    var d = 26 * scale;
    el('path', { d: 'M' + cx + ' ' + (y - d * 2) + ' L' + (cx + d) + ' ' + (y - d) +
                    ' L' + cx + ' ' + y + ' L' + (cx - d) + ' ' + (y - d) + ' Z', fill: c }, s);
    h = d * 2;
  } else if (kind === 'cyl') {
    var w = 20 * scale, hh = 44 * scale;
    el('rect', { x: cx - w, y: y - hh, width: w * 2, height: hh, rx: 3, fill: c }, s);
    h = hh;
  } else if (kind === 'conedn') {
    var w2 = 24 * scale, hh2 = 42 * scale;
    el('path', { d: 'M' + (cx - w2) + ' ' + (y - hh2) + ' L' + (cx + w2) + ' ' + (y - hh2) +
                    ' L' + cx + ' ' + y + ' Z', fill: c }, s);
    h = hh2;
  } else if (kind === 'coneup') {
    var w3 = 24 * scale, hh3 = 42 * scale;
    el('path', { d: 'M' + cx + ' ' + (y - hh3) + ' L' + (cx + w3) + ' ' + y +
                    ' L' + (cx - w3) + ' ' + y + ' Z', fill: c }, s);
    h = hh3;
  } else if (kind === 'hourglass') {
    var w4 = 24 * scale, hh4 = 80 * scale;
    el('path', { d: 'M' + (cx - w4) + ' ' + (y - hh4) + ' L' + (cx + w4) + ' ' + (y - hh4) +
                    ' L' + cx + ' ' + (y - hh4 / 2) + ' Z', fill: c }, s);
    el('path', { d: 'M' + cx + ' ' + (y - hh4 / 2) + ' L' + (cx + w4) + ' ' + y +
                    ' L' + (cx - w4) + ' ' + y + ' Z', fill: c }, s);
    h = hh4;
  } else if (kind === 'flagA') {
    var fw = 64 * scale, fh = 44 * scale;
    el('path', { d: 'M' + (cx - fw / 2) + ' ' + (y - fh) + ' h' + (fw * 0.55) +
                    ' l' + (fw * 0.45) + ' ' + (fh / 2) + ' l' + (-fw * 0.45) + ' ' + (fh / 2) +
                    ' h' + (-fw * 0.55) + ' Z', fill: c }, s);
    el('rect', { x: cx - fw / 2, y: y - fh, width: fw * 0.3, height: fh, fill: bg }, s);
    h = fh;
  } else if (kind === 'ballpair') {
    var sp = 70 * scale, rr = 20 * scale;
    el('line', { x1: cx - sp, y1: y - rr, x2: cx + sp, y2: y - rr,
                 stroke: c, 'stroke-width': 4 }, s);
    el('circle', { cx: cx - sp, cy: y - rr, r: rr, fill: c }, s);
    el('circle', { cx: cx + sp, cy: y - rr, r: rr, fill: c }, s);
    el('circle', { cx: cx, cy: y - rr, r: rr, fill: c }, s);
    h = rr * 2;
  }
  return h;
}

/* Day shapes are BLACK, and they are seen against the sky in daylight.
   Drawing them white on a night sky would be backwards, so in dark mode
   this one view gets a daylight ground and black shapes.
   In NIGHT mode it stays red on black: if someone is dark-adapted, a
   bright panel costs them twenty minutes, and that outranks fidelity. */
function drawShapes(sh) {
  var W = 600, H = 360, seaY = 300, cx = W / 2;
  var night = document.documentElement.getAttribute('data-mode') === 'night';
  var sky   = night ? '#000000' : '#c3ced8';
  var ink   = night ? cssvar('--lamp-r') : '#0d1117';
  var sea   = night ? cssvar('--sea')    : '#73838f';
  var hull  = night ? cssvar('--hull')   : '#2b343c';

  var stage = $('shape-stage');
  stage.textContent = '';
  var s = svg(W, H);
  el('rect', { x: 0, y: 0, width: W, height: H, fill: sky }, s);
  el('rect', { x: 0, y: seaY, width: W, height: H - seaY, fill: sea }, s);
  el('line', { x1: 0, y1: seaY, x2: W, y2: seaY, stroke: ink, opacity: 0.35 }, s);
  el('path', { d: 'M' + (cx - 120) + ' ' + (seaY - 16) + ' L' + (cx + 120) + ' ' + (seaY - 16) +
                  ' L' + (cx + 96) + ' ' + seaY + ' L' + (cx - 96) + ' ' + seaY + ' Z',
               fill: hull }, s);
  var top = seaY - 16;
  el('line', { x1: cx, y1: top, x2: cx, y2: 30, stroke: ink, 'stroke-width': 3, opacity: 0.8 }, s);
  var y = top - 10;
  for (var i = sh.stack.length - 1; i >= 0; i--) {
    var used = glyph(sh.stack[i], cx, y, 1, s, ink, sky);
    y -= used + 16;
  }
  stage.appendChild(s);
}
function shapesShow(i) {
  shapeIdx = i; drawShapes(D.shapes[i]); $('shape-answer').hidden = true;
  drill('shape', D.shapes, i, sigShape, function (s) { return s.name; },
        shapesReveal, 'Show me what she is');
}
function shapesNext() { shapesShow(Math.floor(Math.random() * D.shapes.length)); }
function shapesReveal() {
  var sh = D.shapes[shapeIdx];
  $('shape-name').textContent = sh.name;
  $('shape-rule').textContent = sh.rule + '.';
  $('shape-note').textContent = sh.note;
  $('shape-answer').hidden = false;
}

/* =====================================================================
   SOUND SIGNALS -- the thing a terminal could only draw
   ===================================================================== */
var ac = null, playing = null;

function audio() {
  if (!ac) {
    var C = window.AudioContext || window.webkitAudioContext;
    if (!C) return null;
    ac = new C();
  }
  if (ac.state === 'suspended') ac.resume();
  return ac;
}

/* A ship's whistle is low and loud.  Two detuned saws a fifth apart
   through a lowpass gets close enough to be recognisable. */
function blast(t0, dur) {
  var a = audio(); if (!a) return;
  var g = a.createGain(), f = a.createBiquadFilter();
  f.type = 'lowpass'; f.frequency.value = 900;
  g.gain.setValueAtTime(0, t0);
  g.gain.linearRampToValueAtTime(0.28, t0 + 0.04);
  g.gain.setValueAtTime(0.28, t0 + dur - 0.12);
  g.gain.linearRampToValueAtTime(0, t0 + dur);
  f.connect(g); g.connect(a.destination);
  [112, 168].forEach(function (hz, i) {
    var o = a.createOscillator();
    o.type = 'sawtooth';
    o.frequency.value = hz * (i ? 1.004 : 1);
    o.connect(f); o.start(t0); o.stop(t0 + dur + 0.02);
  });
}

/* A bell is inharmonic and decays fast. */
function bell(t0) {
  var a = audio(); if (!a) return;
  var g = a.createGain();
  g.gain.setValueAtTime(0.0001, t0);
  g.gain.exponentialRampToValueAtTime(0.3, t0 + 0.006);
  g.gain.exponentialRampToValueAtTime(0.0001, t0 + 1.1);
  g.connect(a.destination);
  [1, 2.76, 5.4, 8.9].forEach(function (m, i) {
    var o = a.createOscillator();
    o.type = 'sine'; o.frequency.value = 620 * m;
    var og = a.createGain(); og.gain.value = 1 / (i + 1.4);
    o.connect(og); og.connect(g);
    o.start(t0); o.stop(t0 + 1.2);
  });
}

/* Groups are separated by spaces.  Within a group, one '#' is a short
   blast and four is a prolonged one; one '*' is a stroke on the bell and
   five is the bell rung rapidly.  Durations are the real ones, because a
   prolonged blast is supposed to feel long. */
function soundPattern(pat) {
  var a = audio(); if (!a) return 0;
  var t = a.currentTime + 0.08;
  pat.trim().split(/\s+/).forEach(function (grp) {
    if (grp[0] === '#') {
      if (grp.length >= 4) { blast(t, 4.5); t += 4.5 + 1.0; }
      else { for (var i = 0; i < grp.length; i++) { blast(t, 1.0); t += 1.0 + 0.6; } t += 0.4; }
    } else if (grp[0] === '*') {
      if (grp.length >= 5) { for (var j = 0; j < 34; j++) { bell(t); t += 0.145; } t += 0.8; }
      else { for (var k = 0; k < grp.length; k++) { bell(t); t += 0.95; } t += 0.5; }
    }
  });
  return t - a.currentTime;
}

var soundIdx = 0;
function drawSound(sd) {
  var stage = $('sound-stage');
  stage.textContent = '';
  var groups = sd.pattern.trim().split(/\s+/);
  var W = 600, H = 120, pad = 20, y = 54;
  var s = svg(W, H);
  var unit = 0;
  groups.forEach(function (g) { unit += g[0] === '#' ? (g.length >= 4 ? 4.5 : g.length * 1.6) : g.length * 0.9; });
  var span = W - pad * 2, x = pad;
  var px = span / Math.max(unit, 1);
  groups.forEach(function (g) {
    if (g[0] === '#') {
      if (g.length >= 4) {
        el('rect', { x: x, y: y - 16, width: 4.5 * px, height: 32, rx: 4, fill: cssvar('--accent') }, s);
        x += 4.5 * px;
      } else {
        for (var i = 0; i < g.length; i++) {
          el('rect', { x: x, y: y - 16, width: 1.0 * px, height: 32, rx: 4, fill: cssvar('--accent') }, s);
          x += 1.6 * px;
        }
      }
    } else {
      for (var j = 0; j < g.length; j++) {
        el('circle', { cx: x + 0.4 * px, cy: y, r: Math.min(10, 0.35 * px), fill: cssvar('--accent') }, s);
        x += 0.9 * px;
      }
    }
    x += 0.5 * px;
  });
  el('line', { x1: pad, y1: y + 30, x2: W - pad, y2: y + 30, stroke: cssvar('--line') }, s);
  var lab = el('text', { x: pad, y: y + 50, fill: cssvar('--dim'), 'font-size': 13 }, s);
  lab.textContent = 'time →';
  var p = el('text', {
    x: W - pad, y: y + 50, fill: cssvar('--dim'), 'text-anchor': 'end',
    'font-family': 'ui-monospace, Menlo, monospace', 'font-size': 14
  }, s);
  p.textContent = sd.pattern;
  stage.appendChild(s);
}
function soundsShow(i) {
  soundIdx = i; drawSound(D.sounds[i]); $('sound-answer').hidden = true;
  drill('sound', D.sounds, i, sigSound, function (s) { return s.meaning; },
        soundsReveal, 'Tell me what she is saying');
}
function soundsNext() { soundsShow(Math.floor(Math.random() * D.sounds.length)); }
function soundsReveal() {
  var sd = D.sounds[soundIdx];
  $('sound-meaning').textContent = sd.meaning;
  $('sound-rule').textContent = sd.rule + '.';
  $('sound-when').textContent = sd.when;
  $('sound-answer').hidden = false;
}

/* =====================================================================
   THE DRILL  --  five candidates and a way out

   This replaced a single "Show me what she is" button.  Recognising the
   right answer once you are shown it is not the skill being trained;
   producing it is.  So every question now offers five candidates, one of
   them correct, and a sixth row that gives up and tells you.

   The four wrong answers are chosen to be CONFUSABLE with the right one
   rather than drawn at random.  Each candidate is scored on how much of
   its signature it shares with the answer -- lamp colours for lights,
   the glyph stack for day shapes, the blast pattern for sounds -- and
   the closest four are used.  A trawler against a vessel not under
   command teaches you something.  A trawler against a seaplane does not.

   A wrong tap marks that row and leaves the rest live, so a miss costs
   you another look at the picture instead of ending the question.
   ===================================================================== */

var LTRS = 'abcdef';

/* Multiset overlap: how many elements the two signatures share, counting
   repeats.  Three balls and two balls share two, not one. */
function sigOverlap(a, b) {
  var pool = b.slice(), n = 0;
  for (var i = 0; i < a.length; i++) {
    var k = pool.indexOf(a[i]);
    if (k >= 0) { pool.splice(k, 1); n++; }
  }
  return n;
}

function sigVessel(v) {
  var s = [];
  for (var i = 0; i < v.lights.length; i++) s.push(v.lights[i].col);
  return s.sort();
}
function sigShape(sh) { return sh.stack.slice().sort(); }

/* '#' is a short blast, '####' a prolonged one, '*' the bell.  What makes
   two signals confusable is the sequence of blast KINDS, not the string. */
function sigSound(sd) {
  return sd.pattern.split(' ').map(function (t) {
    if (t.charAt(0) === '*') return t.length > 1 ? 'bells' : 'bell';
    return t.length > 1 ? 'prolonged' : 'short';
  }).sort();
}

function nearest(list, idx, sigOf, n) {
  var mine = sigOf(list[idx]), scored = [];
  for (var i = 0; i < list.length; i++) {
    if (i === idx) continue;
    var s = sigOf(list[i]);
    scored.push({
      i: i,
      /* shared elements first, then the same number of them, then a
         little noise so the same question is not always the same five */
      s: sigOverlap(s, mine) + (s.length === mine.length ? 0.5 : 0) + Math.random() * 0.4
    });
  }
  scored.sort(function (a, b) { return b.s - a.s; });
  return scored.slice(0, n).map(function (o) { return o.i; });
}

function shuffled(a) {
  for (var i = a.length - 1; i > 0; i--) {
    var k = Math.floor(Math.random() * (i + 1)), t = a[i]; a[i] = a[k]; a[k] = t;
  }
  return a;
}

/* One row. */
function optRow(ltr, text, cls) {
  var b = document.createElement('button');
  b.className = 'opt' + (cls ? ' ' + cls : ''); b.type = 'button';
  var sp = document.createElement('span'); sp.className = 'ltr'; sp.textContent = ltr + ')';
  var tx = document.createElement('span'); tx.textContent = text;
  b.appendChild(sp); b.appendChild(tx);
  return b;
}

/* Build the six rows for one view.  nameOf turns a record into its label;
   reveal opens that view's answer panel; tell is the sixth row's wording. */
function drill(pfx, list, idx, sigOf, nameOf, reveal, tell) {
  var box = $(pfx + '-opts'), verdict = $(pfx + '-verdict');
  box.textContent = '';
  verdict.hidden = true; verdict.textContent = ''; verdict.dataset.state = '';

  var picks = shuffled(nearest(list, idx, sigOf, 4).concat([idx]));
  var done = false;

  function settle(right) {
    done = true;
    for (var i = 0; i < box.children.length; i++) box.children[i].disabled = true;
    reveal();
    verdict.dataset.state = right ? 'right' : '';
    verdict.textContent = right ? 'Right.' : 'The answer, then.';
    verdict.hidden = false;
  }

  picks.forEach(function (p, n) {
    var row = optRow(LTRS[n], nameOf(list[p]));
    row.addEventListener('click', function () {
      if (done || row.disabled) return;
      if (p === idx) {
        row.dataset.state = 'right';
        settle(true);
      } else {
        row.dataset.state = 'wrong';
        row.disabled = true;
        verdict.dataset.state = 'wrong';
        verdict.textContent = 'Not her. Look again.';
        verdict.hidden = false;
      }
    });
    box.appendChild(row);
  });

  var out = optRow(LTRS[5], tell, 'tell');
  out.addEventListener('click', function () {
    if (done) return;
    for (var i = 0; i < box.children.length; i++) {
      if (picks[i] === idx) box.children[i].dataset.state = 'right';
    }
    settle(false);
  });
  box.appendChild(out);
}

/* =====================================================================
   ENCOUNTERS
   ===================================================================== */
var encIdx = 0, encAnswered = false, encBrg = 0, encThdg = 0;

function arrowPath(cx, cy, hdg, len) {
  var dx = sind(hdg), dy = -cosd(hdg);
  var tipx = cx + dx * len, tipy = cy + dy * len;
  var bx = cx - dx * len * 0.5, by = cy - dy * len * 0.5;
  var px = -dy, py = dx;
  return 'M' + tipx + ' ' + tipy +
         ' L' + (bx + px * len * 0.4) + ' ' + (by + py * len * 0.4) +
         ' L' + (bx - px * len * 0.4) + ' ' + (by - py * len * 0.4) + ' Z';
}

function drawEncounter(e, brg, rng, thdg) {
  var W = 600, H = 420, cx = W / 2, cy = H / 2, R = Math.min(cx, cy) - 26;
  var stage = $('enc-stage');
  stage.textContent = '';
  var s = svg(W, H);
  [1, 0.66, 0.33].forEach(function (f) {
    el('circle', { cx: cx, cy: cy, r: R * f, fill: 'none',
                   stroke: cssvar('--line'), 'stroke-dasharray': '2 5' }, s);
  });
  for (var a = 0; a < 360; a += 30) {
    el('line', { x1: cx + sind(a) * R * 0.95, y1: cy - cosd(a) * R * 0.95,
                 x2: cx + sind(a) * R, y2: cy - cosd(a) * R,
                 stroke: cssvar('--line') }, s);
  }
  var hu = el('text', { x: cx, y: 18, fill: cssvar('--dim'), 'text-anchor': 'middle',
                        'font-size': 12, 'letter-spacing': '0.2em' }, s);
  hu.textContent = 'HEAD UP';

  /* you, at the centre, heading up the page */
  el('path', { d: arrowPath(cx, cy, 0, 16), fill: cssvar('--accent') }, s);
  var yl = el('text', { x: cx, y: cy + 30, fill: cssvar('--accent'), 'text-anchor': 'middle',
                        'font-size': 12, 'font-weight': 700 }, s);
  yl.textContent = 'YOU';

  /* her */
  var tx = cx + sind(brg) * R * rng, ty = cy - cosd(brg) * R * rng;
  var dx = sind(thdg), dy = -cosd(thdg);
  el('line', { x1: tx - dx * 46, y1: ty - dy * 46, x2: tx, y2: ty,
               stroke: cssvar('--dim'), 'stroke-dasharray': '3 4' }, s);
  el('path', { d: arrowPath(tx, ty, thdg, 15), fill: cssvar('--text') }, s);
  var hl = el('text', { x: tx + 14, y: ty - 10, fill: cssvar('--text'), 'font-size': 12,
                        'font-weight': 700 }, s);
  hl.textContent = 'HER';

  /*  THE WIND, where the scenario has one.  Rule 12 is decided by which
      side the wind is on, so a sailing scenario that names windward and
      leeward has to draw it -- the shell build gained this on 22 October
      and the browser could not see it, because the field had never been
      dumped into data.js.  Drawn from the upwind edge pointing downwind,
      the way a wind arrow is read on a chart.  */
  if (e.wind !== undefined) {
    var wx = cx + sind(e.wind) * R * 0.92, wy = cy - cosd(e.wind) * R * 0.92;
    var dwn = nrm360(e.wind + 180);
    var ex = wx + sind(dwn) * 54, ey = wy - cosd(dwn) * 54;
    el('line', { x1: wx, y1: wy, x2: ex, y2: ey, stroke: cssvar('--dim'),
                 'stroke-width': 2, 'stroke-dasharray': '6 4' }, s);
    el('path', { d: arrowPath(ex, ey, dwn, 13), fill: cssvar('--dim') }, s);
    var wl = el('text', { x: wx - sind(dwn) * 16, y: wy + cosd(dwn) * 16 + 4,
                          fill: cssvar('--dim'), 'text-anchor': 'middle',
                          'font-size': 12, 'letter-spacing': '0.15em' }, s);
    wl.textContent = 'WIND';
  }
  stage.appendChild(s);
}

function encShow(i) {
  encIdx = i; encAnswered = false;
  var e = D.encounters[i];
  var lo = e.brglo, hi = e.brghi; if (hi < lo) hi += 360;
  var brg = nrm360(lo + Math.random() * (hi - lo));
  var rng = 0.55 + Math.random() * 0.35;
  var thdg = nrm360(e.thdg + (Math.random() * 30 - 15));
  drawEncounter(e, brg, rng, thdg);
  $('enc-own').textContent = e.own;
  $('enc-target').textContent = 'You see ' + e.target + ', ' +
    rel_phrase(brg, 'your') + ', heading as drawn.' +
    (e.wind === undefined ? '' :
      ' The wind is from ' + ('00' + nrm360(e.wind)).slice(-3) +
      ' relative, as drawn.');
  encBrg = brg; encThdg = thdg;
  var box = $('enc-opts');
  box.textContent = '';
  e.options.forEach(function (text, n) {
    var ltr = 'abcd'[n];
    var b = document.createElement('button');
    b.className = 'opt'; b.type = 'button';
    var sp = document.createElement('span'); sp.className = 'ltr'; sp.textContent = ltr + ')';
    var tx = document.createElement('span'); tx.textContent = text;
    b.appendChild(sp); b.appendChild(tx);
    b.addEventListener('click', function () { encAnswer(ltr); });
    box.appendChild(b);
  });
  $('enc-answer').hidden = true;
}
/*  WHAT YOU WOULD ACTUALLY SEE, for the scenarios described by type
    rather than by their lights.  The arcs come from the same rule as the
    shell's lt_arc: the viewer's bearing from the subject, relative to the
    subject's bow.  Sixteen of the twenty-eight scenarios describe her
    lights in the question itself, and those carry no `kind`, so nothing
    is said about them here either.  */
function lt_arc_web(rel) {
  var r = nrm360(rel);
  if (r <= 1.5 || r >= 358.5) return 'both';
  if (r < 112.5) return 'green';
  if (r > 247.5) return 'red';
  return 'stern';
}
function lt_phrase_web(e, brg) {
  var relher = nrm360(brg + 180 - encThdg);
  var arc = lt_arc_web(relher);
  if (arc === 'both') return 'both her sidelights, bow-on';
  if (arc === 'stern') return 'her white sternlight and no colour at all';
  var side = arc === 'green' ? 'green starboard' : 'red port';
  return 'her ' + side + ' light' +
         (e.kind === 'sail' ? ' and no masthead light, because she is under sail'
                            : ' and her masthead light');
}

function encAnswer(ltr) {
  if (encAnswered) return;
  encAnswered = true;
  var e = D.encounters[encIdx];
  var kids = $('enc-opts').children;
  for (var i = 0; i < kids.length; i++) {
    var l = 'abcd'[i];
    kids[i].disabled = true;
    if (l === e.answer) kids[i].dataset.state = 'right';
    else if (l === ltr) kids[i].dataset.state = 'wrong';
  }
  $('enc-verdict').textContent = (ltr === e.answer ? 'Right' : 'Not right') +
    ' — the answer is ' + e.answer.toUpperCase() + '.';
  $('enc-rule').textContent = e.rule + '.';
  /*  The exact bearing, now that it can give nothing away -- it is the
      check against your own reading of the plan, which is where a number
      belongs. Same split as the shell build: the arc asks, the number
      confirms.  */
  $('enc-why').textContent = e.why + '  (she bore ' +
    ('00' + Math.round(nrm360(encBrg))).slice(-3) + ' relative.)' +
    (e.kind === undefined ? '' :
      '  She is ' + (e.kind === 'sail' ? 'under sail' : 'power-driven') +
      ', so you would see ' + lt_phrase_web(e, encBrg) + '.');
  $('enc-answer').hidden = false;
}
function encNext() { encShow(Math.floor(Math.random() * D.encounters.length)); }

/* =====================================================================
   THE RULES
   ===================================================================== */
function doneSet() {
  var raw = recall('lessons', '');
  return raw ? raw.split(',') : [];
}
function markDone(id) {
  var d = doneSet();
  if (d.indexOf(id) < 0) { d.push(id); remember('lessons', d.join(',')); }
}
function rulesIndex() {
  var box = $('rules-index');
  box.textContent = '';
  var done = doneSet();
  var wrap = document.createElement('div');
  wrap.className = 'ridx';
  D.lessons.forEach(function (L, i) {
    var b = document.createElement('button');
    b.type = 'button';
    var m = document.createElement('span');
    var isDone = done.indexOf(L.id) >= 0;
    m.className = isDone ? 'done' : 'todo';
    m.textContent = isDone ? '[x]' : '[ ]';
    var t = document.createElement('span');
    t.textContent = L.id + '  ' + L.title;
    b.appendChild(m); b.appendChild(t);
    b.addEventListener('click', function () { openLesson(i); });
    wrap.appendChild(b);
  });
  box.appendChild(wrap);
  var p = document.createElement('p');
  p.className = 'note';
  p.textContent = done.length + ' of ' + D.lessons.length + ' done.';
  box.appendChild(p);
  $('lesson').hidden = true;
  box.hidden = false;
}
function openLesson(i) {
  var L = D.lessons[i];
  $('rules-index').hidden = true;
  $('lesson').hidden = false;
  $('lesson-title').textContent = L.id + '  ' + L.title;
  $('lesson-body').textContent = L.body;
  $('lesson-q').textContent = L.question;
  var box = $('lesson-opts');
  box.textContent = '';
  var answered = false;
  ['a', 'b', 'c'].forEach(function (ltr) {
    var b = document.createElement('button');
    b.className = 'opt'; b.type = 'button';
    var sp = document.createElement('span'); sp.className = 'ltr'; sp.textContent = ltr + ')';
    b.appendChild(sp);
    b.addEventListener('click', function () {
      if (answered) return;
      answered = true;
      var kids = box.children;
      for (var k = 0; k < kids.length; k++) {
        var kl = ['a', 'b', 'c'][k];
        kids[k].disabled = true;
        if (kl === L.answer) kids[k].dataset.state = 'right';
        else if (kl === ltr) kids[k].dataset.state = 'wrong';
      }
      $('lesson-verdict').textContent = (ltr === L.answer ? 'Correct.' : 'Not quite — the answer is ' +
        L.answer.toUpperCase() + '.');
      $('lesson-why').textContent = L.why;
      $('lesson-answer').hidden = false;
      if (ltr === L.answer) markDone(L.id);
    });
    box.appendChild(b);
  });
  $('lesson-answer').hidden = true;
}

/* =====================================================================
   ROUTER
   ===================================================================== */
var views = {
  home:       { el: 'v-home',       title: 'COLREGS' },
  lights:     { el: 'v-lights',     title: 'Lights' },
  shapes:     { el: 'v-shapes',     title: 'Day shapes' },
  sounds:     { el: 'v-sounds',     title: 'Sound signals' },
  encounters: { el: 'v-encounters', title: 'Encounters' },
  rules:      { el: 'v-rules',      title: 'The rules' }
};
function go(name) {
  for (var k in views) if (views.hasOwnProperty(k)) $(views[k].el).hidden = (k !== name);
  $('title').textContent = views[name].title;
  $('back').hidden = (name === 'home');
  window.scrollTo(0, 0);
  if (name === 'lights' && !$('light-stage').firstChild) lightsNext();
  if (name === 'shapes' && !$('shape-stage').firstChild) shapesNext();
  if (name === 'sounds' && !$('sound-stage').firstChild) soundsNext();
  if (name === 'encounters') { if (!$('enc-stage').firstChild) encNext(); }
  if (name === 'rules') rulesIndex();
}

/* =====================================================================
   WIRING
   ===================================================================== */
function setMode(m) {
  document.documentElement.setAttribute('data-mode', m);
  $('mode').textContent = m === 'night' ? 'DARK' : 'NIGHT';
  var meta = document.querySelector('meta[name="theme-color"]');
  if (meta) meta.setAttribute('content', m === 'night' ? '#060101' : '#07090b');
  remember('mode', m);
  /* anything already drawn was drawn in the old palette */
  if (!$('v-lights').hidden) drawLights(D.vessels[lightIdx], lightBrg);
  if (!$('v-shapes').hidden) drawShapes(D.shapes[shapeIdx]);
  if (!$('v-sounds').hidden) drawSound(D.sounds[soundIdx]);
}

document.addEventListener('DOMContentLoaded', function () {
  setMode(recall('mode', 'dark'));
  $('mode').addEventListener('click', function () {
    setMode(document.documentElement.getAttribute('data-mode') === 'night' ? 'dark' : 'night');
  });
  $('back').addEventListener('click', function () {
    if (!$('lesson').hidden) { rulesIndex(); return; }
    go('home');
  });
  Array.prototype.forEach.call(document.querySelectorAll('[data-go]'), function (b) {
    b.addEventListener('click', function () { go(b.dataset.go); });
  });

  $('brg').addEventListener('input', function () {
    lightBrg = parseFloat($('brg').value);
    $('brg-out').textContent = ('00' + Math.round(nrm360(lightBrg))).slice(-3);
    drawLights(D.vessels[lightIdx], lightBrg);
  });
  $('deck').addEventListener('click', function () {
    DECK_ON = !DECK_ON;
    var b = $('deck');
    b.setAttribute('aria-pressed', DECK_ON ? 'true' : 'false');
    b.textContent = DECK_ON ? 'Deck lights ON' : 'Deck lights off';
    $('decknote').hidden = !DECK_ON;
    drawLights(D.vessels[lightIdx], lightBrg);
  });
  $('light-next').addEventListener('click', lightsNext);
  $('shape-next').addEventListener('click', shapesNext);
  $('sound-next').addEventListener('click', soundsNext);
  $('sound-play').addEventListener('click', function () {
    var secs = soundPattern(D.sounds[soundIdx].pattern);
    var b = $('sound-play');
    b.disabled = true;
    var was = b.textContent;
    b.textContent = '■  Sounding…';
    setTimeout(function () { b.disabled = false; b.textContent = was; }, Math.ceil(secs * 1000));
  });
  $('enc-next').addEventListener('click', encNext);

  /* reference lists */
  var ll = $('light-list');
  D.vessels.forEach(function (v) {
    var d = document.createElement('div'); d.className = 'row';
    var b = document.createElement('b'); b.textContent = v.name;
    var s = document.createElement('span'); s.textContent = v.rule + '. ' + v.note;
    d.appendChild(b); d.appendChild(s); ll.appendChild(d);
  });
  var sl = $('shape-list');
  D.shapes.forEach(function (v) {
    var d = document.createElement('div'); d.className = 'row';
    var b = document.createElement('b'); b.textContent = v.name;
    var s = document.createElement('span'); s.textContent = v.rule + '. ' + v.note;
    d.appendChild(b); d.appendChild(s); sl.appendChild(d);
  });
  var dl = $('sound-list');
  D.sounds.forEach(function (v) {
    var d = document.createElement('div'); d.className = 'row';
    var p = document.createElement('b'); p.className = 'pat'; p.textContent = v.pattern;
    var b = document.createElement('b'); b.textContent = v.meaning;
    var s = document.createElement('span'); s.textContent = v.rule + '. ' + v.when;
    d.appendChild(p); d.appendChild(b); d.appendChild(s); dl.appendChild(d);
  });

  go('home');

  /* offline */
  var note = $('offline-note');
  if ('serviceWorker' in navigator && location.protocol !== 'file:') {
    navigator.serviceWorker.register('sw.js').then(function () {
      note.textContent = 'Cached for offline use. Add to your home screen and it works with no signal.';
    }).catch(function () {
      note.textContent = 'Offline cache unavailable — the page still works while it is open.';
    });
  } else {
    note.textContent = 'Opened as a local file, so there is no offline cache to install — ' +
                       'everything is already in the file.';
  }
});

/*  A SEAM FOR THE DIFF, not an API.  The page never sees this: `module`
    is undefined in a browser.  tests/colregs-web-diff.sh loads this file
    in node and runs these against the awk originals over their whole
    input range, which is how "ported function-for-function" stops being
    a claim in a README and becomes a check that fails.  */
if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    nrm180: nrm180, nrm360: nrm360, fabs: fabs,
    arc_vis: arc_vis, rel_phrase: rel_phrase,
    aspect_words: aspect_words, lt_arc_web: lt_arc_web
  };
}

})();
