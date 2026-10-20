/* =====================================================================
   weather -- the browser build.  No framework, no build step.

   THE ORDER IS THE POINT, and the page has to enforce it as firmly as
   the code does: nothing of the app's reasoning is on screen until the
   user's own call has been committed to the log.  Not greyed out, not
   collapsed, not behind a tap -- absent.  A guess you can glimpse is a
   guess you have read, and then you have not forecast anything.

   It reads deck-log's observations out of the SAME IndexedDB.  Both
   tools are served from one origin, and IndexedDB is per-origin and not
   per-path, so this is literally the one shared store the design asks
   for: the watch stander says the report once.
   ===================================================================== */
'use strict';

var BUILD = '1 \u2014 20 Oct 2026';

var RECS = [];
var OBS = [];
var VIEW = 'home';

function $(id) { return document.getElementById(id); }
function el(tag, cls, text) {
  var e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text !== undefined) e.textContent = text;
  return e;
}
function lsGet(k, d) { try { var v = localStorage.getItem('weather-' + k); return v === null ? d : v; } catch (e) { return d; } }
function lsSet(k, v) { try { localStorage.setItem('weather-' + k, v); } catch (e) {} }

function setMode(m) {
  document.documentElement.setAttribute('data-mode', m);
  $('mode').textContent = m === 'night' ? 'DARK' : 'NIGHT';
  var meta = document.querySelector('meta[name="theme-color"]');
  if (meta) meta.setAttribute('content', m === 'night' ? '#060101' : '#07090b');
  lsSet('mode', m);
}

var TITLES = { home: 'weather', what: 'What the log says', fcast: 'Your forecast',
               score: 'The score', chart: '500 mb chart', learn: 'Lessons',
               about: 'About' };
function go(v) {
  VIEW = v;
  Object.keys(TITLES).forEach(function (n) { $('v-' + n).hidden = (n !== v); });
  $('back').hidden = (v === 'home');
  $('title').textContent = TITLES[v];
  window.scrollTo(0, 0);
  if (v === 'what') drawWhat();
  if (v === 'fcast') startForecast();
  if (v === 'score') drawScore();
  if (v === 'chart') drawChart();
  if (v === 'learn') drawLessonIndex();
  if (v === 'about') drawAbout();
}

/* ---- rendering a reasoning block ----------------------------------- */
function drawReason(box, items) {
  box.textContent = '';
  items.forEach(function (it) {
    if (it.k === 'gap') { box.appendChild(el('div', 'gap')); return; }
    box.appendChild(el('p', it.k === 'why' ? 'why' : it.k, it.t));
  });
}

/* =====================================================================
   What the log says
   ===================================================================== */
function lonVal() {
  var v = lsGet('lon', '');
  return (v === '' || v === null) ? '' : v;
}
function drawWhat() {
  var lon = lonVal();
  var items = WX.report(OBS, lon);
  drawReason($('what-out'), items);
  $('what-term').textContent = WX.renderTerminal(items, OBS.length >= 2);
}

/* =====================================================================
   The forecast -- yours first
   ===================================================================== */
function startForecast() {
  $('fc-compare').hidden = true;
  $('fc-state').textContent = '';
  updateValid();
  if (OBS.length < 1) {
    $('fc-state').textContent = 'There is no observation in the log yet, so there is ' +
      'nothing for the rules or persistence to work from. Log one in deck-log first.';
  }
}
function updateValid() {
  var h = +$('i-hours').value;
  var now = LOG.stamp();
  $('i-valid').value = SCORE.validTime(now, h);
}

function commitForecast() {
  var hours = +$('i-hours').value;
  var valid = $('i-valid').value;
  var fields = [['for', valid], ['by', 'you']];
  var any = false;
  [['wdir', 'f-wdir'], ['wspd', 'f-wspd'], ['mslp', 'f-mslp'], ['sea', 'f-sea']]
    .forEach(function (p) {
      var v = $(p[1]).value.trim();
      if (v !== '') { fields.push([p[0], v]); any = true; }
    });
  if (!any) {
    $('fc-state').textContent = 'Put at least one number in. A forecast of nothing ' +
      'cannot be scored, and an unscored forecast teaches nothing.';
    return;
  }
  var mine = LOG.make(valid === '' ? LOG.stamp() : LOG.stamp(), 'fc', fields);
  if (!LOG.parse(mine)) {
    $('fc-state').textContent = 'Refused to write that record: ' + LOG.err();
    return;
  }

  //  YOURS GOES IN FIRST, on its own write.  Only once it is in the log
  //  are the machine forecasts computed, written and shown.
  STORE.append(mine).then(function () {
    return reload();
  }).then(function () {
    var n = OBS.length - 1;
    var k = -1, i;
    for (i = n - 1; i >= 0; i--) if (WX.has(OBS[i].p) && WX.has(OBS[n].p)) break;
    k = i;
    var lon = lonVal();
    var theirs = [
      { by: 'rules', f: SCORE.rules(OBS, n, k, hours, lon) },
      { by: 'persist', f: SCORE.persist(OBS, n) }
    ];
    var lines = theirs.map(function (t) {
      var ff = [['for', valid], ['by', t.by]];
      if (WX.has(t.f.wdir)) ff.push(['wdir', WX.cfixed(t.f.wdir + 0.5, 0)]);
      if (WX.has(t.f.wspd)) ff.push(['wspd', WX.cfixed(t.f.wspd, 0)]);
      if (WX.has(t.f.mslp)) ff.push(['mslp', WX.cfixed(t.f.mslp, 1)]);
      if (WX.has(t.f.sea)) ff.push(['sea', WX.cfixed(t.f.sea, 0)]);
      ff.push(['why', t.f.why === '' ? '-' : t.f.why]);
      return LOG.make(LOG.stamp(), 'fc', ff);
    });
    return STORE.append(lines).then(reload).then(function () { return { valid: valid }; });
  }).then(function (r) {
    showComparison(r.valid);
    $('fc-state').textContent = 'Yours is logged. Log the observation for ' + r.valid +
      ' in deck-log when it comes, then look at the score.';
  }).catch(function (e) {
    $('fc-state').textContent = 'Nothing was logged: ' + e.message;
  });
}

function showComparison(valid) {
  var rows = {};
  RECS.forEach(function (r) {
    if (r.type !== 'fc' || r.v['for'] !== valid) return;
    var by = r.v.by === 'user' ? 'you' : r.v.by;
    rows[by] = r.v;
  });
  var t = $('fc-table');
  t.textContent = '';
  var head = el('tr');
  ['', 'wind', 'knots', 'hPa', 'sea'].forEach(function (h) { head.appendChild(el('th', null, h)); });
  var thead = document.createElement('thead'); thead.appendChild(head); t.appendChild(thead);
  var tb = document.createElement('tbody');
  ['you', 'rules', 'persist'].forEach(function (by) {
    var v = rows[by];
    if (!v) return;
    var tr = el('tr', by);
    tr.appendChild(el('td', null, by));
    tr.appendChild(el('td', null, v.wdir === undefined ? '\u2014' : v.wdir));
    tr.appendChild(el('td', null, v.wspd === undefined ? '\u2014' : v.wspd));
    tr.appendChild(el('td', null, v.mslp === undefined ? '\u2014' : v.mslp));
    tr.appendChild(el('td', null, v.sea === undefined ? '\u2014' : v.sea));
    tb.appendChild(tr);
  });
  t.appendChild(tb);
  var whys = [];
  ['rules', 'persist'].forEach(function (by) {
    if (rows[by] && rows[by].why && rows[by].why !== '-') whys.push(by + ': ' + rows[by].why);
  });
  $('fc-why').textContent = whys.join('    \u00b7    ');
  $('fc-compare').hidden = false;
}

/* =====================================================================
   The score
   ===================================================================== */
function drawScore() {
  var res = SCORE.verify(RECS, OBS);
  var box = $('score-out');
  box.textContent = '';
  $('score-term').textContent = SCORE.reportLines(res);
  if (res.n === 0) {
    box.appendChild(el('p', 'note',
      'No forecast has reached its valid time yet, or no observation has been ' +
      'logged near one. Make a forecast, then log the observation it was for, ' +
      'and this fills in.'));
    return;
  }
  var t = el('table', 'score');
  var head = el('tr');
  ['', 'points', 'dir', 'spd', 'hPa'].forEach(function (h) { head.appendChild(el('th', null, h)); });
  var thead = document.createElement('thead'); thead.appendChild(head); t.appendChild(thead);
  var tb = document.createElement('tbody');
  ['you', 'rules', 'persist'].forEach(function (by) {
    if (!(by in res.cnt)) return;
    var tr = el('tr', by);
    tr.appendChild(el('td', null, by));
    tr.appendChild(el('td', null, WX.cfixed(res.tot[by], 1)));
    ['wdir', 'wspd', 'mslp'].forEach(function (f) {
      var kk = by + '\u001c' + f;
      tr.appendChild(el('td', null, kk in res.fcnt ? WX.cfixed(res.ftot[kk] / res.fcnt[kk], 1) : '\u2014'));
    });
    tb.appendChild(tr);
  });
  t.appendChild(tb);
  box.appendChild(t);
  box.appendChild(el('p', 'note', res.n + ' forecast' + (res.n === 1 ? '' : 's') +
    ' verified against an observation.'));

  //  The app's own misses go on the record.  That is the whole point of
  //  scoring the rules as well as the user.
  if (('persist' in res.cnt) && ('rules' in res.cnt) &&
      res.tot.rules / res.cnt.rules > res.tot.persist / res.cnt.persist) {
    box.appendChild(el('p', 'warn',
      'The rules are not beating persistence. That is the honest result so far, ' +
      'and it is worth knowing.'));
  }
  if (('you' in res.cnt) && ('rules' in res.cnt) &&
      res.tot.you / res.cnt.you < res.tot.rules / res.cnt.rules) {
    box.appendChild(el('p', 'acc',
      'You are beating the rule set. Trust yourself over it here.'));
  }
}

/* =====================================================================
   The 500 mb chart
   ===================================================================== */
function drawChart() {
  var brg = $('c-brg').value.trim();
  var dist = $('c-dist').value.trim();
  var or = $('c-or').value.trim();
  var w5 = $('c-w5').value.trim();
  var north = $('c-hemi').value === '1';
  ['brg', 'dist', 'or', 'w5'].forEach(function (k) { lsSet('c-' + k, $('c-' + k).value); });
  lsSet('c-hemi', $('c-hemi').value);
  //  A 500 mb wind of zero knots divides by zero and the awk prints
  //  "inf to inf hours" for it.  Rather than reproduce that on a screen,
  //  say what is wrong with the input.
  $('chart-warn').textContent = (w5 !== '' && +w5 <= 0)
    ? 'A 500 mb wind of zero gives a system speed of nothing and a time to arrival of ' +
      'infinity. Read the isotachs again \u2014 the 564 line runs through a jet.'
    : '';
  var items = CHART.report(brg, dist, or === '' ? 0 : or, w5, north);
  drawReason($('chart-out'), items);
  $('chart-term').textContent = CHART.renderTerminal(items, dist !== '' && brg !== '');
}

/* =====================================================================
   The lessons
   ===================================================================== */
function doneList() {
  try { return JSON.parse(lsGet('done', '[]')) || []; } catch (e) { return []; }
}
function markDone(k) {
  var d = doneList();
  if (d.indexOf(k) < 0) { d.push(k); lsSet('done', JSON.stringify(d)); }
}
function drawLessonIndex() {
  $('les-index').hidden = false;
  $('les-body').hidden = true;
  var done = doneList();
  var box = $('les-list');
  box.textContent = '';
  LESSONS.forEach(function (l) {
    var b = el('button', 'row');
    b.appendChild(el('b', null, l.title));
    b.appendChild(el('span', null, done.indexOf(l.key) >= 0 ? 'read' : ''));
    b.addEventListener('click', function () { showLesson(l.key); });
    box.appendChild(b);
  });
}
function showLesson(key) {
  var l = null;
  LESSONS.forEach(function (x) { if (x.key === key) l = x; });
  if (!l) return;
  markDone(key);
  $('les-index').hidden = true;
  $('les-body').hidden = false;
  var box = $('les-text');
  box.textContent = '';
  var firstLine = true;
  l.body.forEach(function (b) {
    if (b.s === 'gap') { box.appendChild(el('div', 'gap')); return; }
    if (b.s === 'rule') { box.appendChild(document.createElement('hr')); return; }
    //  the first printed line of every lesson is its heading
    if (firstLine) {
      firstLine = false;
      box.appendChild(el('h3', null, b.p.map(function (p) { return p.t; }).join('').trim()));
      return;
    }
    var p = el('p', 'ln');
    b.p.forEach(function (span) {
      if (span.s === 'plain') p.appendChild(document.createTextNode(span.t));
      else p.appendChild(el('span', span.s, span.t));
    });
    box.appendChild(p);
  });
  var q = $('les-q');
  q.textContent = '';
  if (l.q) {
    q.hidden = false;
    q.appendChild(el('b', null, 'Question'));
    q.appendChild(el('p', null, l.q));
    //  NEVER TELL BEFORE YOU ASK.  The answer is not in the page until
    //  it is asked for.
    var show = el('button', 'btn wide', 'Show the answer');
    var ans = el('p', null, '');
    show.addEventListener('click', function () {
      ans.textContent = l.a;
      show.remove();
    });
    q.appendChild(show);
    q.appendChild(ans);
  } else q.hidden = true;
  window.scrollTo(0, 0);
}

/* =====================================================================
   About, and loading
   ===================================================================== */
function drawAbout() {
  $('share-state').textContent = RECS.length
    ? RECS.length + ' records in the shared log, ' + OBS.length + ' of them observations.'
    : 'No log on this device yet. Keep a watch in deck-log and this fills in.';
  if (!('caches' in window)) { $('off-state').textContent = 'This browser will not cache for offline use.'; return; }
  caches.open('weather-v1').then(function (c) { return c.match('./'); }).then(function (hit) {
    $('off-state').textContent = hit
      ? 'Cached. This runs with no network at all.'
      : 'Not cached yet \u2014 open this page once with a connection.';
  }).catch(function () { $('off-state').textContent = 'Could not read the cache.'; });
}

function reload() {
  return STORE.allLines().then(function (lines) {
    var rd = LOG.read(STORE.canonical(lines).join('\n'), '');
    RECS = rd.recs;
    OBS = WX.load(RECS);
    return rd;
  });
}

function drawHome() {
  if (!OBS.length) {
    $('st-obs').textContent = 'No observations yet';
    $('st-sub').textContent = 'Almost every rule here needs history, not a snapshot. ' +
      'Keep a few three-hourly watches in deck-log and this starts working.';
    return;
  }
  var last = OBS[OBS.length - 1];
  $('st-obs').textContent = OBS.length + ' observation' + (OBS.length === 1 ? '' : 's') +
    ', the last at ' + last.ts;
  var bits = [];
  if (WX.has(last.p)) bits.push(WX.cfixed(last.p, 1) + ' hPa');
  if (WX.has(last.wdir) && WX.has(last.wspd)) bits.push('wind ' + last.wdir + '/' + last.wspd);
  if (WX.has(last.air)) bits.push('air ' + WX.cfixed(last.air, 1) + '\u00b0C');
  $('st-sub').textContent = bits.join('   \u00b7   ') || 'nothing recorded in it';
}

window.addEventListener('DOMContentLoaded', function () {
  setMode(lsGet('mode', 'dark') === 'night' ? 'night' : 'dark');
  $('mode').addEventListener('click', function () {
    setMode(document.documentElement.getAttribute('data-mode') === 'night' ? 'dark' : 'night');
  });
  $('back').addEventListener('click', function () { go('home'); drawHome(); });
  $('ver').textContent = 'build ' + BUILD;
  Array.prototype.forEach.call(document.querySelectorAll('[data-go]'), function (b) {
    b.addEventListener('click', function () { go(b.getAttribute('data-go')); });
  });

  $('i-lon').value = lsGet('lon', '');
  $('b-lonsave').addEventListener('click', function () {
    var v = $('i-lon').value.trim();
    if (v !== '' && (!isFinite(+v) || +v < -180 || +v > 180)) {
      $('lon-state').textContent = 'Longitude runs -180 to 180.';
      return;
    }
    lsSet('lon', v);
    $('lon-state').textContent = v === ''
      ? 'Cleared. Without it the atmospheric tide cannot be taken off the trend.'
      : 'Saved. The tide correction is now applied before anything is said about tendency.';
  });

  $('i-hours').addEventListener('change', updateValid);
  $('b-commit').addEventListener('click', commitForecast);
  ['c-brg', 'c-dist', 'c-or', 'c-w5'].forEach(function (id) {
    $(id).value = lsGet(id, '');
    $(id).addEventListener('input', drawChart);
  });
  $('c-hemi').value = lsGet('c-hemi', '1');
  $('c-hemi').addEventListener('change', drawChart);
  $('les-back').addEventListener('click', drawLessonIndex);

  go('home');
  reload().then(drawHome).catch(function (e) {
    $('st-obs').textContent = 'Could not open the log store';
    $('st-sub').textContent = e.message;
  });

  if ('serviceWorker' in navigator && location.protocol !== 'file:') {
    if (window.WEATHER_NO_SW) {
      navigator.serviceWorker.getRegistrations().then(function (rs) {
        rs.forEach(function (r) { r.unregister(); });
      }).catch(function () {});
    } else {
      navigator.serviceWorker.register('sw.js').catch(function () {});
    }
  }
});
