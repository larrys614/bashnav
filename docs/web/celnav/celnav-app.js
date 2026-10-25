/*  celnav's shell: the router, and the teaching track.

    This page WAS camera sight and nothing else. The shell tool has
    always been one celnav containing both the sights and the thirty-
    three lessons, and colregs keeps its lessons inside the tool, so the
    browser now matches: camera sight is a section rather than the whole
    of it. That costs one tap to the thing Larry uses most, which is why
    it was his call and not mine.

    camui.js is untouched. It drives the camera flow by element id and
    knows nothing about any of this; its panels simply live inside
    #v-camera now. Anything this file needs from it, it asks for by id.

    THE LESSONS ARE GENERATED, not typed: see
    docs/web/celnav/gen/make-celnav-web.sh. The prose is teach.awk's own
    output, the modules come from syl_init(), and the answers come from
    cmd=t_qmeta because ques() only sets them on the branch that does not
    print.

    THE FIGURES ARE GAPS, for now. Ten of the lessons draw on a 67 x 25
    character grid -- the globe with its graticule and circles of
    position, the celestial triangle, the LOP zoom -- and a picture of a
    terminal is the wrong thing in a browser 380px wide. Pass two draws
    them as SVG. Until then each one is a NAMED gap, so a lesson with a
    hole in it says so rather than quietly reading as though nothing is
    missing.  */
'use strict';

(function () {

function $(id) { return document.getElementById(id); }
function mk(tag, cls, text) {
  var e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text !== undefined) e.textContent = text;
  return e;
}
function remember(k, v) { try { localStorage.setItem('celnav-' + k, v); } catch (e) {} }
function recall(k, d) {
  try { var v = localStorage.getItem('celnav-' + k); return v === null ? d : v; }
  catch (e) { return d; }
}

/* ---------------------------------------------------------------------
   PROSE FROM A TERMINAL, the same three shapes colregs settled on.

   teach.awk wraps at about 70 columns and those breaks are real newline
   characters. Honoured in a narrow box they break a second time, so a
   line becomes one full line and a stub. The breaks are dropped and the
   browser wraps -- except where the line breaks ARE the layout, which is
   decided per paragraph:

     pre    a column gutter (two or more spaces that do not follow
            sentence punctuation) or a hanging indent deeper than a
            list's. The correction bars, the deviation card, the
            interpolation tables and the almanac extracts all land here,
            which is why those figures needed no marker: they print as
            rows of text and holding them is the right answer.
     list   a numbered or lettered item, its lines joined and the marker
            given a hanging indent.
     flow   everything else.

   Conservative on purpose: a table flowed into a paragraph is
   unreadable, a paragraph left hard-wrapped is merely ugly.
   --------------------------------------------------------------------- */
/*  A COLUMN GUTTER, AND THE DISTINCTION IS THE WIDTH. Two spaces after
    a full stop is sentence spacing; three or more inside a line is a
    column, whatever precedes them. The first version excluded a colon
    from the two-space case and applied that exclusion to any width,
    which held nothing it should not -- until celnav's Polaris lesson,
    where "at upper transit, above the pole:   latitude = Ho - p" is a
    label and a formula in two columns, and the colon is exactly what a
    label ends with. Measured across all three apps, splitting the cases
    by width moves that one paragraph and nothing else.  */
var PR_GUTTER = /\S {3,}\S|[^.!?: ] {2}\S/;
var PR_MARKER = /^( *)(\d+\.|\([a-z]\)|[a-z]\))\s+\S/;
var PR_DEEP = 6;

function proseKind(lines) {
  var i, ind = [], mn, mx;
  for (i = 0; i < lines.length; i++) if (PR_GUTTER.test(lines[i])) return 'pre';
  for (i = 0; i < lines.length; i++) ind.push(lines[i].match(/^ */)[0].length);
  mn = Math.min.apply(null, ind); mx = Math.max.apply(null, ind);
  if (mx - mn >= PR_DEEP) return 'pre';
  for (i = 0; i < lines.length; i++) if (PR_MARKER.test(lines[i])) return 'list';
  return 'flow';
}
function proseJoin(lines) {
  var i, out = '';
  for (i = 0; i < lines.length; i++) {
    out += (out === '' ? '' : ' ') + lines[i].replace(/^ +/, '').replace(/ +$/, '');
  }
  return out;
}
function renderProse(text, box) {
  String(text).split(/\n[ \t]*\n/).forEach(function (par) {
    var lines = par.split('\n').filter(function (l) { return l.replace(/\s/g, '') !== ''; });
    if (!lines.length) return;
    var kind = proseKind(lines), e, i;

    if (kind === 'pre') {
      e = mk('pre', 'lp-pre');
      e.textContent = par.replace(/^\n+/, '').replace(/\s+$/, '');
      box.appendChild(e);
      return;
    }
    if (kind === 'flow') {
      box.appendChild(mk('p', 'lp', proseJoin(lines)));
      return;
    }
    var items = [], cur = null;
    for (i = 0; i < lines.length; i++) {
      if (PR_MARKER.test(lines[i])) { cur = [lines[i]]; items.push(cur); }
      else if (cur) cur.push(lines[i]);
      else { cur = [lines[i]]; items.push(cur); }
    }
    items.forEach(function (it) { box.appendChild(mk('div', 'lp-item', proseJoin(it))); });
  });
  return box;
}
function proseBox(box, text) {
  var d = mk('div', 'prose');
  renderProse(text, d);
  box.appendChild(d);
  return d;
}

/* =====================================================================
   THE SYLLABUS
   ===================================================================== */
function doneList() {
  var raw = recall('lessons', '');
  return raw ? raw.split(',') : [];
}
function markDone(id) {
  var d = doneList();
  if (d.indexOf(id) < 0) { d.push(id); remember('lessons', d.join(',')); }
}
function lessonById(id) {
  var L = window.CELNAV_LESSONS, i;
  for (i = 0; i < L.length; i++) if (L[i].id === id) return L[i];
  return null;
}
function syllabus() {
  var box = $('syl-index');
  box.textContent = '';
  var done = doneList(), seen = {}, wrap = null;

  window.CELNAV_SYLLABUS.forEach(function (e) {
    if (!seen[e.module]) {
      seen[e.module] = 1;
      box.appendChild(mk('h3', null, e.module));
      wrap = mk('div', 'ridx');
      box.appendChild(wrap);
    }
    var b = mk('button'); b.type = 'button';
    var isDone = done.indexOf(e.id) >= 0;
    var m = mk('span', isDone ? 'done' : 'todo', isDone ? '[x]' : '[ ]');
    var t = mk('span', null, e.id + '  ' + e.title);
    b.appendChild(m); b.appendChild(t);
    b.addEventListener('click', function () { openLesson(e.id); });
    wrap.appendChild(b);
  });

  box.appendChild(mk('p', 'note',
    done.length + ' of ' + window.CELNAV_SYLLABUS.length + ' done.'));
  $('les').hidden = true;
  box.hidden = false;
}

/*  what each lesson's missing figure is, so a gap says what belongs in
    it rather than that something is absent. Second pass replaces these
    with the drawings; tests/celnav-lessons-check.js makes sure every
    lesson that has a gap has a line here.  */
var FIG_NAMES = {
  P2: 'the three positions, plotted together',
  F3: 'the circle of position, drawn on the globe',
  F4: 'two circles crossing, drawn on the globe',
  F5: 'the line of position, zoomed until the circle looks straight',
  T4: 'LHA as the angle at the pole, looking down on it',
  R1: 'the celestial triangle on the sky dome',
  R4: 'the intercept and the line of position, plotted',
  R5: 'a running fix, advanced for the run between sights',
  C1: 'the cut between two bodies, and the band of altitudes'
};

/*  "Q. stem?  a) one  b) two  c) three" -> the stem, and the options
    with their text. Null when it does not read that way, so the caller
    can fall back rather than show something wrong.  */
function splitQuestion(q) {
  var t = String(q).replace(/^Q\.\s*/, '');
  var i = t.search(/(^|\n)\s*a\)/);
  if (i < 0) return null;
  var stem = t.slice(0, i).replace(/\s+$/, '');
  var parts = t.slice(i).split(/\s(?=[a-d]\))/);
  var opts = [], k, s;
  for (k = 0; k < parts.length; k++) {
    s = parts[k].replace(/^\s+/, '').replace(/\s+$/, '');
    if (!/^[a-d]\)/.test(s)) continue;
    opts.push({ ltr: s.charAt(0), text: s.slice(2).replace(/^\s+/, '').replace(/\s+/g, ' ') });
  }
  if (!stem || opts.length < 2) return null;
  for (k = 0; k < opts.length; k++) if (!opts[k].text) return null;
  return { stem: stem, opts: opts };
}

function openLesson(id) {
  var L = lessonById(id);
  if (!L) return;
  $('syl-index').hidden = true;
  $('les').hidden = false;
  $('les-title').textContent = L.id + '  ' + L.title;

  var body = $('les-body');
  body.textContent = '';
  L.blocks.forEach(function (b) {
    if (b.t === 'p') { proseBox(body, b.s); return; }
    /*  a named gap. It is deliberately plain and deliberately obvious:
        a lesson missing its figure should look unfinished, because it
        is.  */
    var g = mk('div', 'fig-gap');
    g.appendChild(mk('span', 'fig-gap-tag', 'figure to come'));
    g.appendChild(mk('span', null, FIG_NAMES[L.id] || ('a ' + b.kind + ' figure')));
    body.appendChild(g);
  });

  /*  the question, marked in place  */
  var chk = $('les-check');
  chk.hidden = false;
  var qbox = $('les-q');
  qbox.textContent = '';

  var opts = $('les-opts');
  opts.textContent = '';
  $('les-answer').hidden = true;

  /*  THE OPTIONS GO ON THE BUTTONS. In the shell they are part of the
      question's own text -- "a) 30 miles   b) 300 miles   c) 1800
      miles", set in columns on one line -- and shown that way the line
      is held as a table, scrolls sideways on a phone, and takes the
      question stem with it: rendered, "A sight gives a zenith distance
      of 30 degrees" was clipped mid-sentence and the options were off
      the edge with only bare letters to press.

      So the stem is flowed and the options are split onto the buttons.
      That means parsing prose the awk never promised to shape, which is
      a thing to be careful with rather than a thing to avoid: all 33
      split cleanly, the check proves each one has a stem, two or more
      options, text on every one and the answer among them, and if a
      question ever arrives in a shape this cannot read it falls back to
      showing the question whole with lettered buttons.  */
  var parsed = splitQuestion(L.question);
  renderProse(parsed ? parsed.stem : L.question.replace(/^Q\.\s*/, ''), qbox);
  var letters = parsed
    ? parsed.opts.map(function (o) { return o.ltr; })
    : (L.question.match(/\b([a-d])\)/g) || []).map(function (x) { return x.charAt(0); });

  var answered = false, btns = [];
  letters.forEach(function (ltr, oi) {
    var b = mk('button', 'opt'); b.type = 'button';
    b.appendChild(mk('span', 'ltr', ltr + ')'));
    if (parsed) b.appendChild(mk('span', 'otext', parsed.opts[oi].text));
    b.addEventListener('click', function () {
      if (answered) return;
      answered = true;
      for (var k = 0; k < btns.length; k++) {
        btns[k].disabled = true;
        if (letters[k] === L.answer) btns[k].dataset.state = 'right';
        else if (letters[k] === ltr) btns[k].dataset.state = 'wrong';
      }
      $('les-verdict').textContent = (ltr === L.answer)
        ? 'Correct.' : 'Not quite — the answer is ' + L.answer.toUpperCase() + '.';
      $('les-why').textContent = L.why;
      $('les-answer').hidden = false;
      markDone(L.id);
    });
    btns.push(b);
    opts.appendChild(b);
  });

  window.scrollTo(0, 0);
}

/* =====================================================================
   SIGHT REDUCTION

   The tool's first purpose, and the browser had no way in: an altitude
   could only arrive from a photograph. Every piece of the arithmetic was
   already here and already diffed against the awk -- corrections(),
   reduce_sight(), solve_fix(), fix_geometry() -- and CELPLOT already
   kept the sight list, solved the fix and drew the sheet for the camera
   flow. So this is the way in and nothing else: a sight from a metal
   sextant, a plastic one or the camera becomes the same record,
   { body, jd, hs, ie, he, tm, pr, limb, utc }, and goes through the same
   solver.
   ===================================================================== */
/*  THE ENGINE IS NOT GLOBAL. camui.js builds its own with
    extendCelnav(makeCelnav(window.CELNAV_TABLES)) inside its IIFE, so
    there is no window.CN to borrow -- I assumed there was, and the first
    version of this reached for one and got undefined. One instance is
    built here the same way. They do not interfere: the engine's E.*
    fields are scratch, read immediately after the call that sets them.  */
var CN_ONE = null;
function CNe() {
  if (!CN_ONE && typeof makeCelnav === 'function')
    CN_ONE = (typeof extendCelnav === 'function')
      ? extendCelnav(makeCelnav(window.CELNAV_TABLES))
      : makeCelnav(window.CELNAV_TABLES);
  return CN_ONE;
}
var SVGNS = 'http://www.w3.org/2000/svg';

function sightFields() {
  var C = CNe();
  var d = $('s-date').value.trim(), t = $('s-time').value.trim();
  if (!d || !t) return { err: 'Give the UT date and time — the clock is what rules.' };
  var utc = d + ' ' + t;
  if (!/^\d{4}-\d{2}-\d{2}[ T]\d{1,2}:\d{2}/.test(utc))
    return { err: 'UT as 2026-08-29 and 07:30:00.' };
  var body = $('s-body').value.trim();
  if (!body) return { err: 'Which body? A name, or a star number.' };
  var hs = C.parse_ang($('s-hs').value);
  if (hs === 'ERR' || isNaN(hs)) return { err: 'Hs as degrees and minutes, like 19 32.1.' };
  var num = function (id, dflt) {
    var v = parseFloat($(id).value);
    return isNaN(v) ? dflt : v;
  };
  return { body: body, jd: C.parse_utc(utc), hs: hs,
           ie: num('s-ie', 0), he: num('s-he', 0),
           tm: num('s-tm', 10), pr: num('s-pr', 1010),
           limb: $('s-limb').value, utc: utc };
}
function sightAP() {
  var C = CNe();
  var la = C.parse_ang($('s-alat').value), lo = C.parse_ang($('s-alon').value);
  if (la === 'ERR' || lo === 'ERR' || isNaN(la) || isNaN(lo)) return null;
  return { lat: la, lon: lo };
}
/*  an angle as degrees and minutes. Altitudes get no hemisphere; a
    latitude or longitude gets one, and a longitude gets three digits.  */
/*  Degrees and minutes, split out so the two carries happen in the one
    place.  BOTH were wrong here.  The zero-pad was decided from m before
    toFixed(1) rounded it, so 9.956' asked for a pad and then printed
    "10.0" - the fix read 35 010.0' N.  And minutes rounding up to 60.0
    never carried into the degrees, so 29 59.97' printed as 29 60.0'.
    fmt_dm() in engine.awk carries at 59.95; this does the same.  */
function dmparts(v) {
  var neg = v < 0; v = Math.abs(v);
  var d = Math.floor(v), m = (v - d) * 60;
  if (m >= 59.95) { m = 0; d = d + 1; }
  var ms = m.toFixed(1);
  while (ms.length < 4) ms = '0' + ms;   /* awk's %04.1f: pad the ROUNDED
                                            string, never the value */
  return { neg: neg, d: d, m: ms };
}
function dm(v) {
  var p = dmparts(v);
  return (p.neg ? '-' : '') + p.d + '\u00b0 ' + p.m + "'";
}
function ddm(v, lat) {
  var h = (v < 0) ? (lat ? 'S' : 'W') : (lat ? 'N' : 'E');
  var p = dmparts(v);
  return ('00' + p.d).slice(lat ? -2 : -3) + '\u00b0 ' + p.m + "' " + h;
}
function mins(v) { return (v >= 0 ? '+' : '\u2212') + Math.abs(v).toFixed(1) + "'"; }

/*  THE CORRECTION CHAIN, SHOWN RATHER THAN SUMMED, in the order and with
    the parts the shell's own working shows -- Hs, IE, dip, Ha, refraction,
    semi-diameter, parallax, Ho -- because lesson S5 is about the size of
    each part and a single corrected number teaches nothing.

    Read out of the engine's E.* fields, not from a return value:
    corrections() returns Ho alone and stashes the parts, exactly as the
    awk does with its globals. And body_at() takes the NAME first and must
    run before corrections(), which reads the horizontal parallax and
    semi-diameter it sets. I had all three of those wrong by assuming, and
    the screen threw on every sight.  */
function showCorrections(sg) {
  var C = CNe(), box = $('s-corr');
  box.textContent = '';
  var gha = C.body_at(sg.body, sg.jd);
  if (gha === 'ERR') {
    box.appendChild(mk('p', 'note',
      'I do not know that body. A name, or a star number \u2014 the list is on the field.'));
    return null;
  }
  var ho = C.corrections(sg.hs, sg.ie, sg.he, sg.tm, sg.pr, sg.limb), E = C.E;
  var rows = [
    ['Hs', dm(sg.hs)],
    ['index error', mins(-sg.ie)],
    ['dip', mins(-E.C_DIP)],
    ['Ha', dm(E.C_HA)],
    ['refraction', mins(-E.C_REF)],
    ['semi-diameter', E.C_LIMB ? mins(E.C_LIMB) : '\u2014'],
    ['parallax', E.C_PAR ? mins(E.C_PAR) : '\u2014'],
    ['Ho', dm(ho)],
    ['GHA', ddm(E.B_GHA, false)],
    ['Dec', ddm(E.B_DEC, true)]
  ];
  var t = mk('table', 'kv');
  rows.forEach(function (r) {
    var tr = mk('tr');
    tr.appendChild(mk('th', null, r[0]));
    tr.appendChild(mk('td', 'num', r[1]));
    t.appendChild(tr);
  });
  box.appendChild(t);
  return ho;
}

function sightList() {
  var box = $('s-list');
  box.textContent = '';
  var all = window.CELPLOT.all();
  if (!all.length) {
    box.appendChild(mk('p', 'note', 'None yet. Two of different bodies give a fix.'));
    return;
  }
  var P = sightAP();
  var sol = P ? window.CELPLOT.solve(CNe(), P.lat, P.lon,
                                     parseFloat($('s-spd').value) || 0,
                                     parseFloat($('s-crs').value) || 0) : null;
  var t = mk('table', 'ct-tab');
  var hr = mk('tr');
  ['body', 'UT', 'Hs', 'Hc', 'Zn', 'intercept', ''].forEach(function (h) {
    hr.appendChild(mk('th', null, h));
  });
  t.appendChild(hr);
  all.forEach(function (s, i) {
    var lop = (sol && sol.lops && sol.lops[i]) ? sol.lops[i] : null;
    var tr = mk('tr');
    [s.body,
     (s.utc || '').replace(/^\d{4}-\d{2}-\d{2}[ T]/, ''),
     dm(s.hs),
     lop ? dm(lop.hc) : '\u2014',
     lop ? ('00' + Math.round(lop.zn)).slice(-3) : '\u2014',
     lop ? (Math.abs(lop.intercept).toFixed(1) + ' nm ' +
            (lop.intercept >= 0 ? 'TOWARD' : 'AWAY')) : '\u2014'
    ].forEach(function (v, k) {
      var td = mk('td', (k >= 2) ? 'num' : null, v);
      tr.appendChild(td);
    });
    var td = mk('td');
    var x = mk('button', 'linkish', 'remove');
    x.type = 'button';
    x.addEventListener('click', function () {
      window.CELPLOT.remove(i); sightRefresh();
    });
    td.appendChild(x);
    tr.appendChild(td);
    t.appendChild(tr);
  });
  box.appendChild(t);
}

function sightFix() {
  var box = $('s-fix');
  box.textContent = '';
  var P = sightAP();
  if (!P) {
    box.appendChild(mk('p', 'note',
      'Give an assumed position above — the reduction is measured from it.'));
    $('s-sheet').textContent = '';
    return;
  }
  var all = window.CELPLOT.all();
  var sol = window.CELPLOT.solve(CNe(), P.lat, P.lon,
                                 parseFloat($('s-spd').value) || 0,
                                 parseFloat($('s-crs').value) || 0);
  if (!sol) {
    box.appendChild(mk('p', 'note', 'No sights kept yet.'));
    $('s-sheet').textContent = '';
    return;
  }
  if (!sol.ok || all.length < 2) {
    box.appendChild(mk('p', 'note', all.length === 1
      ? 'One sight is one line of position, not a fix. One more of a different body.'
      : 'Those sights do not cross usefully — bodies too close in azimuth.'));
  } else {
    var t = mk('table', 'kv');
    [['FIX', ddm(sol.lat, true) + '   ' + ddm(sol.lon, false)],
     ['from the AP', Math.abs(sol.N).toFixed(1) + ' nm ' + (sol.N >= 0 ? 'N' : 'S') + ', ' +
                     Math.abs(sol.E).toFixed(1) + ' nm ' + (sol.E >= 0 ? 'E' : 'W')]
    ].concat(sol.geom ? [['error ellipse',
       sol.geom.major.toFixed(1) + ' x ' + sol.geom.minor.toFixed(1) + ' nm']] : [])
     .forEach(function (r) {
      var tr = mk('tr');
      tr.appendChild(mk('th', null, r[0]));
      tr.appendChild(mk('td', 'num', r[1]));
      t.appendChild(tr);
    });
    box.appendChild(t);
  }
  /*  draw(svgNS, host, sol, opts) -- the solution, not the position: I
      guessed the signature first and it took the engine as its first
      argument, which is camui's call to solve(), not to draw().  */
  window.CELPLOT.draw(SVGNS, $('s-sheet'), sol, {
    /*  the sheet takes its colours from the page, so it follows the night
        palette rather than being drawn in whatever it was built with  */
    css: function (n) {
      return getComputedStyle(document.documentElement).getPropertyValue(n).trim() || '#6fb3d9';
    }
  });
}

function sightRefresh() { sightList(); sightFix(); }

function sightInit() {
  /*  the body list the shell offers: the sun, moon, the four planets it
      carries and the 57 navigational stars, by name  */
  var C = CNe(), dl = $('s-bodies'), i;
  if (dl && !dl.firstChild) {
    ['Sun', 'Moon', 'Venus', 'Mars', 'Jupiter', 'Saturn'].forEach(function (n) {
      dl.appendChild(mk('option', null, n)).value = n;
    });
    if (C && C.stars && C.stars.SNAME)
      for (i = 0; i < C.stars.SNAME.length; i++)
        dl.appendChild(mk('option', null, C.stars.SNAME[i])).value = C.stars.SNAME[i];
  }
  /*  the UT date defaults to today, because the clock is what rules and a
      sight with yesterday's date is the commonest way to get a fix that
      is confidently hundreds of miles out  */
  if (!$('s-date').value) $('s-date').value = new Date().toISOString().slice(0, 10);
  sightRefresh();
}

/* =====================================================================
   ROUTER
   ===================================================================== */
var views = {
  home:   { el: 'v-home',   title: 'celnav' },
  camera: { el: 'v-camera', title: 'Camera sight' },
  sight:  { el: 'v-sight',  title: 'Sight reduction' },
  learn:  { el: 'v-learn',  title: 'Learn' }
};
function go(name) {
  for (var k in views) if (views.hasOwnProperty(k)) $(views[k].el).hidden = (k !== name);
  $('title').textContent = views[name].title;
  $('nav-back').hidden = (name === 'home');
  window.scrollTo(0, 0);
  if (name === 'learn') syllabus();
  if (name === 'sight') sightInit();
  remember('view', name);
}

document.addEventListener('DOMContentLoaded', function () {
  Array.prototype.forEach.call(document.querySelectorAll('[data-go]'), function (b) {
    b.addEventListener('click', function () { go(b.dataset.go); });
  });
  $('s-add').addEventListener('click', function () {
    var sg = sightFields();
    if (sg.err) { $('s-note').textContent = sg.err; $('s-corr').textContent = ''; return; }
    if (!showCorrections(sg)) { $('s-note').textContent = ''; return; }
    var n = window.CELPLOT.add(sg);
    $('s-note').textContent = n + ' sight' + (n === 1 ? '' : 's') + ' kept.' +
      (n < 2 ? ' One more of a different body gives a fix.' : '');
    $('s-hs').value = '';
    sightRefresh();
  });
  $('s-clear').addEventListener('click', function () {
    window.CELPLOT.clear(); $('s-corr').textContent = ''; $('s-note').textContent = '';
    sightRefresh();
  });
  ['s-alat', 's-alon', 's-crs', 's-spd'].forEach(function (id) {
    $(id).addEventListener('input', sightRefresh);
  });

  $('nav-back').addEventListener('click', function () {
    if (!$('les').hidden) { syllabus(); return; }
    go('home');
  });
  /*  camera sight was this whole page, so anyone who had it installed
      and open lands where they left off rather than on a new screen
      they did not ask for  */
  go(recall('view', 'home') === 'camera' ? 'camera' : 'home');

  var off = $('offline-note');
  if (off) {
    if (!('caches' in window)) { off.textContent = 'This browser will not cache for offline use.'; }
    else caches.keys().then(function (ks) {
      var k = ks.filter(function (x) { return x.indexOf('celnav-') === 0; })[0];
      return k ? caches.open(k).then(function (c) { return c.match('./'); }) : null;
    }).then(function (hit) {
      off.textContent = hit ? 'Cached. This runs with no network at all.'
                            : 'Not cached yet. Open it once more with a signal.';
    }).catch(function () { off.textContent = ''; });
  }
});

/*  The seam tests/celnav-lessons-check.js loads this through. `module`
    is undefined in a browser, so the page pays nothing; what it buys is
    that the reflow and the figure-gap names can be held to something
    outside one. Same seam colregs.js, contacts.js and weather.js carry.  */
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { renderProse: renderProse, proseKind: proseKind,
                     FIG_NAMES: FIG_NAMES, splitQuestion: splitQuestion };
}

})();
