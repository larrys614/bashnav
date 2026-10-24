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
  renderProse(L.question.replace(/^Q\.\s*/, ''), qbox);

  var opts = $('les-opts');
  opts.textContent = '';
  $('les-answer').hidden = true;

  /*  the options are inside the question's own text in the shell -- "a)
      30 miles   b) 300 miles   c) 1800 miles" on one line -- so the
      buttons are letters, and the text above them is what they refer
      to. Pulling the options apart would mean parsing prose the awk
      never promised to shape, and getting it wrong silently.  */
  var letters = (L.question.match(/\b([a-d])\)/g) || []).map(function (x) { return x.charAt(0); });
  var answered = false, btns = [];
  letters.forEach(function (ltr) {
    var b = mk('button', 'opt'); b.type = 'button';
    b.appendChild(mk('span', 'ltr', ltr + ')'));
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
   ROUTER
   ===================================================================== */
var views = {
  home:   { el: 'v-home',   title: 'celnav' },
  camera: { el: 'v-camera', title: 'Camera sight' },
  learn:  { el: 'v-learn',  title: 'Learn' }
};
function go(name) {
  for (var k in views) if (views.hasOwnProperty(k)) $(views[k].el).hidden = (k !== name);
  $('title').textContent = views[name].title;
  $('nav-back').hidden = (name === 'home');
  window.scrollTo(0, 0);
  if (name === 'learn') syllabus();
  remember('view', name);
}

document.addEventListener('DOMContentLoaded', function () {
  Array.prototype.forEach.call(document.querySelectorAll('[data-go]'), function (b) {
    b.addEventListener('click', function () { go(b.dataset.go); });
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
  module.exports = { renderProse: renderProse, proseKind: proseKind, FIG_NAMES: FIG_NAMES };
}

})();
