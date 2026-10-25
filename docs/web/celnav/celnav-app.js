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
/*  A GHA HAS NO HEMISPHERE. ddm() appends N/S or E/W, which is right for a
    latitude or a longitude and wrong for an hour angle: Aries at 091 01.8'
    is not 091 01.8' east of anything. This is awk's fmt_dm(x, 3).  */
function dm3(v) {
  var p = dmparts(v);
  return ('00' + p.d).slice(-3) + '\u00b0 ' + p.m + "'";
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

/*  both screens default to now, for the same reason the sight screen does:
    the overwhelmingly common case is "what is it doing at this moment",
    and a blank date field asks a question the device can answer itself  */
function utcToday() { return new Date().toISOString().slice(0, 10); }
function utcClock() { return new Date().toISOString().slice(11, 19); }

function almanacInit() {
  if (!$('a-date').value) $('a-date').value = utcToday();
  if (!$('a-time').value) $('a-time').value = utcClock();
  almanacShow();
}
function starsInit() {
  if (!$('st-date').value) $('st-date').value = utcToday();
  starsShow();
}

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
/* =====================================================================
   THE ALMANAC, AND THE STAR LIST

   The two screens a paper almanac is carried for. Nothing here is looked
   up: body_at() computes GHA and declination for the instant from the
   same series the sight reduction uses, so there is no year to run out
   and no volume to leave ashore.

   Both follow cmd_almanac() and cmd_stars() in src/celnav/engine.awk
   field for field, because the shell is the reference implementation and
   docs/web/tests/run-celnav-web.sh diffs the two.
   ===================================================================== */

/*  Aries is always shown. Every star sight is worked from the Greenwich
    hour angle of the First Point of Aries plus the star's SHA, so an
    almanac page without it is of no use for the thing stars are for.  */
function almanacShow() {
  var C = CNe(), box = $('a-out'), note = $('a-note');
  box.textContent = ''; note.textContent = '';
  var d = $('a-date').value.trim(), t = $('a-time').value.trim();
  if (!d || !t) { note.textContent = 'Give the UT date and time \u2014 the clock is what rules.'; return; }
  var utc = d + ' ' + t;
  if (!/^\d{4}-\d{2}-\d{2}[ T]\d{1,2}:\d{2}/.test(utc)) {
    note.textContent = 'UT as 2026-08-29 and 07:34:00.'; return;
  }
  var jd = C.parse_utc(utc);
  var list = ($('a-bodies').value.trim() || 'sun,moon,venus,mars,jupiter,saturn')
               .split(',').map(function (x) { return x.trim(); }).filter(Boolean);

  var head = mk('p', 'note', 'JD ' + jd.toFixed(5) + '   \u0394T ' +
                C.deltaT(C.E.UT_Y).toFixed(1) + ' s');
  box.appendChild(head);

  var t2 = mk('table', 'ct-tab');
  var hr = mk('tr');
  ['body', 'GHA', 'Dec', 'SD', 'HP'].forEach(function (h) { hr.appendChild(mk('th', null, h)); });
  t2.appendChild(hr);

  var tr = mk('tr');
  tr.appendChild(mk('td', null, 'Aries'));
  tr.appendChild(mk('td', 'num', dm3(C.gast(jd))));
  tr.appendChild(mk('td', 'num', '\u2014'));
  tr.appendChild(mk('td', 'num', '\u2014'));
  tr.appendChild(mk('td', 'num', '\u2014'));
  t2.appendChild(tr);

  var unknown = [];
  list.forEach(function (b) {
    if (C.body_at(b, jd) === 'ERR') { unknown.push(b); return; }
    var E = C.E, r = mk('tr');
    r.appendChild(mk('td', null, E.B_NAME));
    r.appendChild(mk('td', 'num', dm3(E.B_GHA)));
    r.appendChild(mk('td', 'num', ddm(E.B_DEC, true)));
    r.appendChild(mk('td', 'num', E.B_SD > 0 ? E.B_SD.toFixed(1) + "'" : '\u2014'));
    r.appendChild(mk('td', 'num', E.B_HP > 0 ? E.B_HP.toFixed(1) + "'" : '\u2014'));
    t2.appendChild(r);
    /*  a star or planet also gets its SHA and magnitude, the way the
        shell prints a second line for it  */
    if (E.B_SHA !== '' && E.B_MAG !== '' && E.B_SD === 0) {
      var r2 = mk('tr', 'sub');
      r2.appendChild(mk('td', null, ''));
      r2.appendChild(mk('td', 'num', 'SHA ' + dm3(E.B_SHA)));
      r2.appendChild(mk('td', 'num', 'mag ' + (+E.B_MAG).toFixed(1)));
      r2.appendChild(mk('td', null, ''));
      r2.appendChild(mk('td', null, ''));
      t2.appendChild(r2);
    }
  });
  box.appendChild(t2);
  if (unknown.length)
    note.textContent = 'I do not know: ' + unknown.join(', ') +
      '. A name, or a star number from the list.';
}

/*  The 57 stars, computed for the date rather than reprinted. star_pos()
    applies proper motion and precession, so Alpheratz is not where a 2000
    catalogue puts it. SHA is 360 minus the right ascension, which is the
    form a sight form and a star finder use.  */
function starsShow() {
  var C = CNe(), box = $('st-out');
  box.textContent = '';
  var d = $('st-date').value.trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(d)) { box.appendChild(mk('p', 'note', 'A UT date as 2026-08-29.')); return; }
  var p = d.split('-');
  var jd = C.jdate(+p[0], +p[1], +p[2]) + C.deltaT(+p[0]) / 86400.0;
  var find = $('st-find').value.trim().toLowerCase();
  var S = C.stars, E = C.E, shown = 0;

  var t2 = mk('table', 'ct-tab');
  var hr = mk('tr');
  ['no', 'name', 'SHA', 'Dec', 'mag'].forEach(function (h) { hr.appendChild(mk('th', null, h)); });
  t2.appendChild(hr);
  /*  ZERO-BASED. The awk's SNUM[1]..SNUM[NSTAR] became SNUM[0]..SNUM[NSTAR-1]
      in the port, and engine.js says so on star_pos: "i is 0-based here".
      Written as the awk writes it, this list opened at Ankaa - Alpheratz,
      star 1, was simply absent - and ran one past the end.  */
  for (var i = 0; i < S.NSTAR; i++) {
    var name = S.SNAME[i];
    if (find && String(S.SNUM[i]) !== find && name.toLowerCase().indexOf(find) < 0) continue;
    C.star_pos(i, jd);
    shown++;
    var r = mk('tr');
    r.appendChild(mk('td', 'num', String(S.SNUM[i])));
    r.appendChild(mk('td', null, name));
    r.appendChild(mk('td', 'num', dm3(C.nrm360(360 - E.P_RA))));
    r.appendChild(mk('td', 'num', ddm(E.P_DEC, true)));
    r.appendChild(mk('td', 'num', (+S.SMAG[i]).toFixed(2)));
    t2.appendChild(r);
  }
  box.appendChild(t2);
  if (!shown) box.appendChild(mk('p', 'note', 'No star of that name or number.'));
}

/* =====================================================================
   THE TWO LATITUDES THAT NEED NO FIX

   A noon sight and a Polaris sight each give one line - a parallel of
   latitude - and neither needs crossing to be true. They are here because
   they are the two sights a navigator can work with the least gear: the
   noon sight needs almost no clock, and Polaris needs no reduction at all.

   Both follow cmd_noon() and cmd_polaris() in src/celnav/engine.awk field
   for field. docs/web/tests/celnav-latitude.js diffs the rendered tables
   against the shell's own printed working, the way celnav-tables.js does
   for the almanac.
   ===================================================================== */

/*  the correction rows, in the order and with the signs the shell's
    working shows. Shared by both screens because the chain is the same
    one; the shell omits semi-diameter and parallax for a star, and
    corrections() leaves C_LIMB and C_PAR at zero there, so the same
    filter does both.  */
function corrRows(C, hs, ie, star) {
  var E = C.E, rows = [['index error', mins(-ie)], ['dip', mins(-E.C_DIP)],
                       ['refraction', mins(-E.C_REF)]];
  if (!star) {
    rows.push(['semi-diameter', mins(E.C_LIMB)]);
    rows.push(['parallax', mins(E.C_PAR)]);
  }
  return rows;
}
function kvTable(rows, cls) {
  var t = mk('table', cls || 'kv');
  rows.forEach(function (r) {
    var tr = mk('tr', r[2] || null);
    tr.appendChild(mk('th', null, r[0]));
    tr.appendChild(mk('td', 'num', r[1]));
    t.appendChild(tr);
  });
  return t;
}
function numOf(id, dflt) {
  var v = parseFloat($(id).value);
  return isNaN(v) ? dflt : v;
}

function noonInit() {
  if (!$('n-date').value) $('n-date').value = utcToday();
  noonShow();
}
function polarisInit() {
  if (!$('p-date').value) $('p-date').value = utcToday();
  if (!$('p-time').value) $('p-time').value = utcClock();
  polarisShow();
}

function noonShow() {
  var C = CNe(), box = $('n-out'), note = $('n-note');
  box.textContent = ''; note.textContent = '';
  var lat = C.parse_ang($('n-lat').value), lon = C.parse_ang($('n-lon').value);
  if (lat === 'ERR' || lon === 'ERR' || isNaN(lat) || isNaN(lon)) {
    note.textContent = 'A DR latitude and longitude — 41 49.0 N and 071 24.0 W.'; return;
  }
  var d = $('n-date').value.trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(d)) { note.textContent = 'A UT date as 2026-08-29.'; return; }

  /*  midnight of the date, exactly as the awk takes it: int(jd+0.5)-0.5,
      so any time of day on that date gives the same starting point  */
  var jd0 = Math.floor(C.parse_utc(d) + 0.5) - 0.5;
  var jd = C.lan_jd(lon, jd0);
  C.body_at('Sun', jd);
  var dec = C.E.B_DEC;
  var h1 = C.reduce_sight(lat, lon, C.E.B_GHA, dec);
  var gha = C.E.B_GHA;
  C.jd2cal(jd);
  var cy = C.E.CAL_Y, cm = C.E.CAL_M, cd = C.E.CAL_D;
  var ut = C.E.CAL_FRAC * 24.0;
  var lmt = ut + lon / 15.0;
  if (lmt < 0) lmt += 24; if (lmt >= 24) lmt -= 24;
  var eot = C.nrm180(gha - (15.0 * ut - 180.0)) * 4.0;
  var mer = 90.0 - C.fabs(lat - dec);
  var sth = (lat > dec);

  /*  how fast the altitude falls two minutes either side. The altitude is
      at a stationary point, so it changes as the SQUARE of the time - which
      makes the clock nearly irrelevant at a workaday altitude and quite
      relevant near the zenith. The shell says which case it is rather than
      asserting the reassuring one, and so does this.  */
  C.body_at('Sun', jd + 120.0 / 86400.0);
  var h2 = C.reduce_sight(lat, lon, C.E.B_GHA, C.E.B_DEC);
  var fall = (h1 - h2) * 60.0;

  box.appendChild(mk('h3', null, 'Local apparent noon — ' +
    cy + '-' + ('0' + cm).slice(-2) + '-' + ('0' + cd).slice(-2)));
  box.appendChild(kvTable([
    ['Position', ddm(lat, true) + '   ' + ddm(lon, false)],
    ['Sun on your meridian at', C.fmt_hms(ut) + ' UT'],
    [' in local mean time', C.fmt_hms(lmt)],
    ['Equation of time', (eot >= 0 ? '+' : '−') + Math.abs(eot).toFixed(1) +
       ' min — the sundial is ' + (eot >= 0 ? 'ahead of' : 'behind') + ' the clock'],
    ["Sun's declination then", ddm(dec, true)],
    ['Meridian altitude to expect', mer.toFixed(1) + '°, bearing ' +
       (sth ? 'SOUTH (180)' : 'NORTH (000)')]
  ]));

  /*  A SUN THAT PASSES OVERHEAD HAS NO SIDE. Within a degree of the zenith
      the azimuth swings through 180 degrees as it crosses, so "bearing
      south" above is a statement the DR cannot support - and the sign of
      the latitude below turns on it.  */
  if (C.fabs(lat - dec) < 1.0)
    box.appendChild(mk('p', 'warn', 'The sun passes within a degree of your zenith today, ' +
      'so which side of you it stands is not decidable from the DR, and its azimuth swings ' +
      'through 180° as it crosses. Note which way it bore.'));

  box.appendChild(mk('p', 'note', fall <= 1.0
    ? 'Two minutes either side of it the altitude is only ' + fall.toFixed(1) +
      "' lower, so catch the maximum by watching it — the clock is not the point."
    : 'Two minutes either side of it the altitude is ' + fall.toFixed(1) +
      "' lower: the sun passes close to your zenith and crosses fast, so the maximum is " +
      'sharp and a careless moment here costs real altitude.'));

  var hsv = $('n-hs').value.trim();
  if (!hsv) {
    box.appendChild(mk('p', 'note',
      'Follow the sun up, catch the highest reading, and give it back in the Hs field.'));
    return;
  }
  var hs = C.parse_ang(hsv);
  if (hs === 'ERR' || isNaN(hs)) { note.textContent = 'Hs as degrees and minutes, like 68 14.2.'; return; }

  var lim = $('n-limb').value || 'L';
  var ie = numOf('n-ie', 0);
  var ho = C.corrections(hs, ie, numOf('n-he', 0), numOf('n-tm', 10), numOf('n-pr', 1010), lim);
  var zd = 90.0 - ho;
  var la = sth ? dec + zd : dec - zd;

  var rows = [['Hs (sextant, ' + (lim === 'U' ? 'upper' : 'lower') + ' limb)', dm(hs)]]
    .concat(corrRows(C, hs, ie, false));
  rows.push(['Ho (observed altitude)', dm(ho)]);
  rows.push(['Zenith distance  90 − Ho', dm(zd)]);
  rows.push(['Declination', ddm(dec, true)]);
  rows.push(['LATITUDE   dec ' + (sth ? '+' : '−') + ' ZD', ddm(la, true), 'tot']);
  box.appendChild(kvTable(rows));

  box.appendChild(mk('p', 'note', 'The sun was taken as bearing ' + (sth ? 'south' : 'north') +
    ' of you, from the DR.'));
  if (C.fabs(lat - dec) < 1.0)
    box.appendChild(mk('p', 'warn', 'CAREFUL: the sun passes within a degree of your zenith, ' +
      'so which side it stood is not obvious from the DR. Your own note of whether it bore ' +
      'north or south is what decides the sign here.'));
  box.appendChild(mk('p', 'note', 'One line only: a parallel of latitude. It needs no crossing ' +
    'to be true, and tells you nothing at all about your longitude.'));
}

function polarisShow() {
  var C = CNe(), box = $('p-out'), note = $('p-note');
  box.textContent = ''; note.textContent = '';
  var lon = C.parse_ang($('p-lon').value);
  if (lon === 'ERR' || isNaN(lon)) { note.textContent = 'A DR longitude — 071 24.0 W.'; return; }
  var d = $('p-date').value.trim(), t = $('p-time').value.trim();
  if (!d || !t) { note.textContent = 'Give the UT date and time.'; return; }
  var utc = d + ' ' + t;
  if (!/^\d{4}-\d{2}-\d{2}[ T]\d{1,2}:\d{2}/.test(utc)) {
    note.textContent = 'UT as 2026-08-29 and 23:12:00.'; return;
  }
  var jd = C.parse_utc(utc);
  if (C.body_at('Polaris', jd) === 'ERR') {
    note.textContent = 'Polaris is not in the catalogue.'; return;
  }
  var E = C.E, lha = C.nrm360(E.B_GHA + lon), p = 90.0 - E.B_DEC;

  box.appendChild(mk('h3', null, 'Polaris — ' + utc + ' UT'));
  box.appendChild(kvTable([
    ['Longitude', ddm(lon, false) + '   (latitude is what this sight gives you)'],
    ['Polaris GHA', dm3(E.B_GHA)],
    ['LHA   GHA + longitude', dm3(lha)],
    ['Declination', ddm(E.B_DEC, true)],
    ['Polar distance  90 − dec', (p * 60.0).toFixed(1) + "'"]
  ]));

  var hsv = $('p-hs').value.trim();
  if (!hsv) {
    box.appendChild(kvTable([
      ['Correction to Ho at this LHA', mins(-p * C.cosd(lha) * 60.0) +
         '   (it swings ±' + (p * 60.0).toFixed(1) + "' in a day)"]
    ]));
    box.appendChild(mk('p', 'note', 'Take Polaris and give the reading back in the Hs field.'));
    return;
  }
  var hs = C.parse_ang(hsv);
  if (hs === 'ERR' || isNaN(hs)) { note.textContent = 'Hs as degrees and minutes, like 42 18.4.'; return; }

  var ie = numOf('p-ie', 0);
  var ho = C.corrections(hs, ie, numOf('p-he', 0), 10, 1010, '');
  var first = -p * C.cosd(lha);
  var la = C.pol_lat(ho, E.B_DEC, lha);
  var exact = la - ho;

  var rows = [['Hs (sextant)', dm(hs)]].concat(corrRows(C, hs, ie, true));
  rows.push(['Ho (observed altitude)', dm(ho)]);
  rows.push(['Correction, first order  −p cos LHA',
             (first * 60.0 >= 0 ? '+' : '−') + Math.abs(first * 60.0).toFixed(2) + "'"]);
  rows.push(['Correction, solved exactly',
             (exact * 60.0 >= 0 ? '+' : '−') + Math.abs(exact * 60.0).toFixed(2) + "'"]);
  rows.push(['LATITUDE', ddm(la, true), 'tot']);
  box.appendChild(kvTable(rows));

  /*  Printing both corrections every time is what makes the almanac's
      three columns make sense, rather than being asserted.  */
  box.appendChild(mk('p', 'note', 'The two corrections differ by ' +
    (C.fabs(exact - first) * 60.0).toFixed(2) + "'. That gap is what the a1 and a2 columns of " +
    "the almanac's Polaris table exist to supply — they are the next terms of a series " +
    'for the line above them.'));
  if (la < 0)
    box.appendChild(mk('p', 'warn', 'WARNING: that is a southern latitude, which cannot be ' +
      'right — Polaris is not visible from the southern hemisphere at all.'));
  box.appendChild(mk('p', 'note', 'One line again, and a parallel of latitude: it says nothing ' +
    'about your longitude. But it is available all night, not for the few minutes either side ' +
    'of noon.'));
}

var views = {
  home:    { el: 'v-home',    title: 'celnav' },
  camera:  { el: 'v-camera',  title: 'Camera sight' },
  sight:   { el: 'v-sight',   title: 'Sight reduction' },
  almanac: { el: 'v-almanac', title: 'Almanac' },
  stars:   { el: 'v-stars',   title: 'The star list' },
  noon:    { el: 'v-noon',    title: 'Noon sight' },
  polaris: { el: 'v-polaris', title: 'Polaris' },
  learn:   { el: 'v-learn',   title: 'Learn' }
};
function go(name) {
  for (var k in views) if (views.hasOwnProperty(k)) $(views[k].el).hidden = (k !== name);
  $('title').textContent = views[name].title;
  $('nav-back').hidden = (name === 'home');
  window.scrollTo(0, 0);
  if (name === 'learn') syllabus();
  if (name === 'sight') sightInit();
  if (name === 'almanac') almanacInit();
  if (name === 'stars') starsInit();
  if (name === 'noon') noonInit();
  if (name === 'polaris') polarisInit();
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

  $('a-go').addEventListener('click', almanacShow);
  ['a-date', 'a-time', 'a-bodies'].forEach(function (id) {
    $(id).addEventListener('change', almanacShow);
  });
  ['st-date', 'st-find'].forEach(function (id) {
    $(id).addEventListener('input', starsShow);
  });

  $('n-go').addEventListener('click', noonShow);
  ['n-lat', 'n-lon', 'n-date', 'n-hs', 'n-limb', 'n-ie', 'n-he', 'n-tm', 'n-pr']
    .forEach(function (id) { $(id).addEventListener('change', noonShow); });
  $('p-go').addEventListener('click', polarisShow);
  ['p-lon', 'p-date', 'p-time', 'p-hs', 'p-ie', 'p-he']
    .forEach(function (id) { $(id).addEventListener('change', polarisShow); });

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
