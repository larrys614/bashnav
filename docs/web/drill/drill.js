/* =====================================================================
   drill -- a study machine with no material in it.
   No framework, no build step; this file is the app.

   It ships EMPTY. The questions and the reference text come from a pack
   the user loads from their own device, read here and kept in this
   origin's storage. Nothing is uploaded and nothing of anybody's
   material is in the published files -- which is the point: material
   somebody else owns can be studied without ever being published.

   Three things here are not style choices.

     NO ANSWER IS IN THE PAGE until it is asked for. Not hidden, not
     collapsed, not transparent -- absent from the DOM. An answer you can
     reveal with a long press, or find by zooming, is an answer you have
     read, and then you have not recalled anything.

     THE REFERENCE IS NEVER GATED. Only the graded test waits its turn.
     Being locked out of a procedure you are carrying this for would be
     the one failure that actually matters, and it would happen at the
     worst possible moment.

     "NOT STUDIED" IS NOT "WEAK". The diagnostic reports a gap as a gap
     and never averages it in as a zero. A gap that looks like a score
     gets you a confidently wrong answer about your own readiness.
   ===================================================================== */
'use strict';

var BUILD = '2 \u2014 20 Oct 2026';
var DB_NAME = 'bashnav-drill';
var PACK = null;          // the loaded pack
var PROG = {};            // sectionId -> {best, attempts, seen{}, right, wrong}
var VIEW = 'empty';
var RUN = null;           // the drill or test in progress

function $(id) { return document.getElementById(id); }
function el(tag, cls, text) {
  var e = document.createElement(tag);
  if (cls) e.className = cls;
  if (text !== undefined) e.textContent = text;
  return e;
}
function lsGet(k, d) { try { var v = localStorage.getItem('drill-' + k); return v === null ? d : v; } catch (e) { return d; } }
function lsSet(k, v) { try { localStorage.setItem('drill-' + k, v); } catch (e) {} }

/* =====================================================================
   Storage.  A pack is a few hundred kilobytes, which is more than
   localStorage should be asked to hold, so both the pack and the
   progress live in IndexedDB.
   ===================================================================== */
var db = null;
function open_() {
  if (db) return Promise.resolve(db);
  return new Promise(function (res, rej) {
    if (!window.indexedDB) { rej(new Error('this browser has no IndexedDB')); return; }
    var rq = indexedDB.open(DB_NAME, 1);
    rq.onupgradeneeded = function () {
      var d = rq.result;
      if (!d.objectStoreNames.contains('kv')) d.createObjectStore('kv');
    };
    rq.onsuccess = function () { db = rq.result; res(db); };
    rq.onerror = function () { rej(rq.error || new Error('could not open storage')); };
  });
}
function kvGet(k) {
  return open_().then(function (d) {
    return new Promise(function (res, rej) {
      var r = d.transaction('kv', 'readonly').objectStore('kv').get(k);
      r.onsuccess = function () { res(r.result); };
      r.onerror = function () { rej(r.error); };
    });
  });
}
function kvPut(k, v) {
  return open_().then(function (d) {
    return new Promise(function (res, rej) {
      var t = d.transaction('kv', 'readwrite');
      t.objectStore('kv').put(v, k);
      t.oncomplete = function () { res(); };
      t.onerror = function () { rej(t.error); };
    });
  });
}
function saveProg() { return kvPut('progress', PROG).catch(function () {}); }

/* ---- mode and navigation ------------------------------------------ */
function setMode(m) {
  document.documentElement.setAttribute('data-mode', m);
  $('mode').textContent = m === 'night' ? 'DARK' : 'NIGHT';
  var meta = document.querySelector('meta[name="theme-color"]');
  if (meta) meta.setAttribute('content', m === 'night' ? '#060101' : '#07090b');
  lsSet('mode', m);
}
var TITLES = { empty: 'drill', home: 'drill', section: '', drill: '',
               diag: 'Where am I weak?', doc: 'The document', about: 'About' };
var BACKTO = { section: 'home', drill: 'home', diag: 'home', doc: 'home', about: 'home' };
function go(v, arg) {
  VIEW = v;
  Object.keys(TITLES).forEach(function (n) { $('v-' + n).hidden = (n !== v); });
  $('back').hidden = !(v in BACKTO);
  if (TITLES[v]) $('title').textContent = TITLES[v];
  window.scrollTo(0, 0);
  if (v === 'home') drawHome();
  if (v === 'diag') startDiagnostic();
  if (v === 'doc') drawDoc();
  if (v === 'about') drawAbout();
}

/* =====================================================================
   The pack
   ===================================================================== */
function validate(p) {
  if (!p || typeof p !== 'object') return 'that file is not a pack';
  if (String(p.format || '').indexOf('bashnav-drill-pack/') !== 0)
    return 'that file does not declare itself a drill pack';
  if (!Array.isArray(p.sections) || !p.sections.length) return 'the pack has no sections';
  if (!Array.isArray(p.questions) || !p.questions.length) return 'the pack has no questions';
  var ids = {};
  for (var i = 0; i < p.sections.length; i++) {
    var s = p.sections[i];
    if (!s.id || !s.title) return 'section ' + (i + 1) + ' has no id or title';
    if (ids[s.id]) return 'two sections share the id ' + s.id;
    ids[s.id] = 1;
  }
  var orphan = 0;
  for (i = 0; i < p.questions.length; i++) if (!ids[p.questions[i].section]) orphan++;
  //  A CARRIED WRONG OPTION THAT EQUALS THE ANSWER IS A QUESTION WITH TWO
  //  RIGHT OPTIONS, and the mark it gives you is a lie either way. Cheap
  //  to check here, impossible to notice while drilling.
  //  An ordering question must have an order to be in, and an intruder
  //  that is not secretly part of it.
  for (i = 0; i < p.questions.length; i++) {
    var qs2 = p.questions[i];
    if (!qs2.seq) continue;
    if (!Array.isArray(qs2.seq) || qs2.seq.length < 3)
      return 'question ' + (i + 1) + ' has fewer than three steps to order';
    for (var a2 = 0; a2 < qs2.seq.length; a2++)
      if (qs2.seq.indexOf(qs2.seq[a2]) !== a2)
        return 'question ' + (i + 1) + ' lists the same step twice';
    var ex = qs2.extra || [];
    if (!Array.isArray(ex) || !ex.length)
      return 'question ' + (i + 1) + ' has no step that does not belong';
    for (var b2 = 0; b2 < ex.length; b2++)
      if (qs2.seq.indexOf(ex[b2]) >= 0)
        return 'question ' + (i + 1) + ' offers a real step as the one that does not belong';
  }
  for (i = 0; i < p.questions.length; i++) {
    var qq = p.questions[i];
    if (!qq.ch || !qq.ch.length) continue;
    if (!Array.isArray(qq.ch)) return 'question ' + (i + 1) + ' has wrong options that are not a list';
    for (var j = 0; j < qq.ch.length; j++) {
      if (qq.ch[j] === qq.a)
        return 'question ' + (i + 1) + ' offers its own answer as a wrong option';
      if (qq.ch.indexOf(qq.ch[j]) !== j)
        return 'question ' + (i + 1) + ' offers the same wrong option twice';
    }
  }
  //  A pack whose questions point at sections it does not contain is
  //  damaged, and loading it half-way would give a drill with silent
  //  holes in it. Rejected whole.
  if (orphan) return orphan + ' questions belong to sections the pack does not contain';
  return '';
}

function loadPack(file) {
  var note = $('load-note');
  note.textContent = 'Reading ' + file.name + '\u2026';
  return file.text().then(function (t) {
    var p;
    try { p = JSON.parse(t); }
    catch (e) { throw new Error('that file is not valid JSON: ' + e.message); }
    var bad = validate(p);
    if (bad) throw new Error(bad);
    return kvPut('pack', p).then(function () {
      PACK = p;
      return kvGet('progress');
    }).then(function (pr) {
      PROG = pr || {};
      go('home');
    });
  }).catch(function (e) {
    note.textContent = 'Not loaded: ' + e.message;
    note.className = 'warn';
  });
}

/* ---- progress ------------------------------------------------------ */
function prog(sid) {
  if (!PROG[sid]) PROG[sid] = { best: null, attempts: 0, seen: {}, right: 0, wrong: 0 };
  return PROG[sid];
}
function passed(sid) {
  var p = PROG[sid];
  return !!(p && p.best !== null && p.best >= (PACK.pass || 80));
}
//  Studied means worked, not merely opened: a recall prompt marked, or a
//  test taken. Reading the reference is not studying it.
function studied(sid) {
  var p = PROG[sid];
  if (!p) return false;
  return p.attempts > 0 || (p.right + p.wrong) > 0;
}
function unlocked(i) {
  if (i === 0) return true;
  return passed(PACK.sections[i - 1].id);
}
function qsFor(sid, graded) {
  return PACK.questions.filter(function (q) {
    return q.section === sid && (graded ? !!q.a : !q.a);
  });
}

/* =====================================================================
   Home
   ===================================================================== */
function drawHome() {
  $('pack-title').textContent = PACK.title || 'Content pack';
  $('pack-note').textContent = (PACK.note ? PACK.note + '   \u00b7   ' : '') +
    PACK.sections.length + ' sections, ' + PACK.questions.length + ' questions';

  var done = PACK.sections.filter(function (s) { return passed(s.id); }).length;
  $('prog-n').textContent = done;
  $('prog-n').className = 'big' + (done === PACK.sections.length ? ' pass' : '');
  $('prog-of').textContent = 'of ' + PACK.sections.length + ' sections passed at ' +
    (PACK.pass || 80) + '% or better';
  var next = PACK.sections.filter(function (s, i) { return unlocked(i) && !passed(s.id); })[0];
  $('prog-note').textContent = next
    ? 'Next up: ' + next.title + '.'
    : (done === PACK.sections.length ? 'All through. The diagnostic is the one to keep using now.' : '');

  var ul = $('seclist');
  ul.textContent = '';
  PACK.sections.forEach(function (s, i) {
    var p = PROG[s.id] || {};
    var open = unlocked(i), pass = passed(s.id), seen = studied(s.id);
    var state = pass ? 'pass' : (seen ? 'part' : (open ? 'open' : 'locked'));
    var b = el('button', 'seclink');
    b.setAttribute('data-state', state);
    var nm = el('div', 'nm');
    nm.appendChild(el('span', 'num', String(i + 1)));
    nm.appendChild(el('b', null, s.title));
    var label = pass ? 'PASSED' : seen ? 'STARTED' : open ? 'OPEN' : 'LOCKED';
    nm.appendChild(el('span', 'pill ' + (pass ? 'pass' : seen ? 'part' : open ? 'unseen' : 'locked'), label));
    b.appendChild(nm);
    var bits = [];
    bits.push(qsFor(s.id, true).length + ' graded');
    var rc = qsFor(s.id, false).length;
    if (rc) bits.push(rc + ' recall');
    if (p.best !== null && p.best !== undefined) bits.push('best ' + p.best + '%');
    if (!open) bits.push('opens when you pass ' + PACK.sections[i - 1].title.toLowerCase());
    b.appendChild(el('span', 'sub', bits.join('   \u00b7   ')));
    b.addEventListener('click', function () { openSection(i); });
    ul.appendChild(b);
  });
}

/* =====================================================================
   A section
   ===================================================================== */
var CURSEC = 0;
function openSection(i) {
  CURSEC = i;
  var s = PACK.sections[i];
  $('title').textContent = 'Section ' + (i + 1);
  $('sec-title').textContent = s.title;
  var p = PROG[s.id] || {};
  $('sec-sub').textContent = (s.parts || []).join('  \u00b7  ') +
    (p.best !== null && p.best !== undefined ? '      best ' + p.best + '%' : '');
  drawTabs('ref');
  go('section');
  $('title').textContent = 'Section ' + (i + 1);
}

function drawTabs(which) {
  var s = PACK.sections[CURSEC];
  var open = unlocked(CURSEC);
  var tabs = [['ref', 'Reference'], ['quiz', 'Practice'], ['test', 'Test']];
  var nav = $('sec-tabs');
  nav.textContent = '';
  tabs.forEach(function (t) {
    var b = el('button', null, t[1]);
    b.setAttribute('aria-current', t[0] === which ? 'true' : 'false');
    if (t[0] === 'test' && passed(s.id)) {
      b.appendChild(el('span', 'tick', ' \u2713'));
    }
    b.addEventListener('click', function () { drawTabs(t[0]); });
    nav.appendChild(b);
  });
  var body = $('sec-body');
  body.textContent = '';

  if (which === 'ref') {
    var panel = el('div', 'panel');
    var ref = el('div', 'ref');
    ref.innerHTML = s.html || '';
    wrapTables(ref);
    panel.appendChild(ref);
    body.appendChild(panel);
    return;
  }

  if (which === 'quiz') {
    var n = qsFor(s.id, false).length + qsFor(s.id, true).length;
    var pq = el('div', 'panel');
    pq.appendChild(el('h2', null, 'Practice'));
    pq.appendChild(el('p', null,
      'Recall, not multiple choice: you answer from memory, then ask for the ' +
      'answer and mark yourself. Nothing here counts towards the test.'));
    pq.appendChild(el('p', 'note', n + ' questions in this section. ' +
      'They come in a different order each time.'));
    var go1 = el('button', 'btn wide go', 'Start practising');
    go1.style.marginTop = '12px';
    go1.addEventListener('click', function () { startQuiz(s.id); });
    pq.appendChild(go1);
    body.appendChild(pq);
    return;
  }

  // ---- the test -----------------------------------------------------
  var pt = el('div', 'panel');
  pt.appendChild(el('h2', null, 'Test'));
  if (!open) {
    //  Locked, and the reason is given rather than implied.
    pt.appendChild(el('p', 'warn',
      'This test opens when you pass \u201c' + PACK.sections[CURSEC - 1].title +
      '\u201d at ' + (PACK.pass || 80) + '% or better.'));
    pt.appendChild(el('p', 'note',
      'The reference above is open regardless, and always will be \u2014 being ' +
      'locked out of a procedure you are carrying this for is the one failure ' +
      'worth designing against.'));
    body.appendChild(pt);
    return;
  }
  var graded = qsFor(s.id, true);
  var len = Math.min(10, graded.length);
  pt.appendChild(el('p', null, len + ' questions, multiple choice, ' +
    (PACK.pass || 80) + '% to pass' +
    (CURSEC + 1 < PACK.sections.length ? ' and open the next section.' : '.')));
  pt.appendChild(el('p', 'note',
    'The wrong options are drawn from this same section, so they are the ' +
    'plausible confusions rather than obvious throwaways.'));
  var pp = PROG[s.id] || {};
  if (pp.attempts) {
    pt.appendChild(el('p', 'note', pp.attempts + ' attempt' + (pp.attempts === 1 ? '' : 's') +
      ', best ' + pp.best + '%.'));
  }
  var go2 = el('button', 'btn wide go', pp.attempts ? 'Take it again' : 'Take the test');
  go2.style.marginTop = '12px';
  go2.addEventListener('click', function () { startTest(s.id); });
  pt.appendChild(go2);
  body.appendChild(pt);
}

//  A wide table must scroll inside its own box, never take the page
//  sideways with it.
function wrapTables(root) {
  Array.prototype.forEach.call(root.querySelectorAll('table'), function (t) {
    if (t.parentNode && t.parentNode.className === 'tablewrap') return;
    var w = el('div', 'tablewrap');
    t.parentNode.insertBefore(w, t);
    w.appendChild(t);
  });
}

/* =====================================================================
   Drilling
   ===================================================================== */
function shuffle(a, rnd) {
  a = a.slice();
  for (var i = a.length - 1; i > 0; i--) {
    var j = Math.floor((rnd ? rnd() : Math.random()) * (i + 1));
    var t = a[i]; a[i] = a[j]; a[j] = t;
  }
  return a;
}

function srcLine(q) {
  var w = q.where || {};
  var bits = [w.part, w.sub, w.row].filter(Boolean);
  return bits.join('  /  ');
}

function startQuiz(sid) {
  var s = PACK.sections[CURSEC];
  //  Recall prompts first -- they are the author's own and the harder
  //  kind -- then the graded ones asked as recall rather than as choices.
  var qs = shuffle(qsFor(sid, false)).concat(shuffle(qsFor(sid, true)));
  RUN = { mode: 'quiz', sid: sid, qs: qs, i: 0, right: 0, wrong: 0 };
  $('drill-title').textContent = s.title;
  go('drill');
  $('title').textContent = 'Practice';
  stepQuiz();
}

function stepQuiz() {
  var r = RUN, body = $('drill-body');
  body.textContent = '';
  $('drill-sub').textContent = 'marked by you \u00b7 nothing here counts towards the test';

  if (r.i >= r.qs.length) {
    var done = el('div', 'panel');
    done.appendChild(el('h2', null, 'Practice done'));
    done.appendChild(el('p', null, 'You marked ' + r.right + ' right and ' +
      r.wrong + ' wrong out of ' + r.qs.length + '.'));
    done.appendChild(el('p', 'note',
      'Self-marked, so it opens nothing \u2014 but it is recorded, which is how ' +
      'the diagnostic knows this section has been worked rather than only read.'));
    var again = el('button', 'btn wide', 'Again, reshuffled');
    again.addEventListener('click', function () { startQuiz(r.sid); });
    done.appendChild(again);
    var back = el('button', 'btn wide go', 'Back to the section');
    back.style.marginTop = '8px';
    back.addEventListener('click', function () { go('section'); drawTabs('quiz');
      $('title').textContent = 'Section ' + (CURSEC + 1); });
    done.appendChild(back);
    body.appendChild(done);
    return;
  }

  var q = r.qs[r.i];
  var card = el('div', 'card');
  card.appendChild(el('div', 'qnum', 'Question ' + (r.i + 1) + ' of ' + r.qs.length));
  card.appendChild(el('p', 'qtext', q.q));

  //  THE ANSWER IS NOT BUILT YET.  It is not in the DOM, hidden or
  //  otherwise, until the button below is pressed.
  var show = el('button', 'btn wide go', 'Show the answer');
  show.setAttribute('data-reveal', '1');
  show.style.marginTop = '16px';
  show.addEventListener('click', function () {
    show.remove();
    if (q.a) {
      card.appendChild(el('p', 'atext', q.a));
    } else {
      var p = el('p', 'atext');
      p.appendChild(el('span', null,
        'This one has no written answer \u2014 it is a recall prompt. Check yourself ' +
        'against the reference: '));
      var lk = el('button', 'btn', 'open the reference');
      lk.style.marginTop = '10px';
      lk.addEventListener('click', function () {
        go('section'); drawTabs('ref');
        $('title').textContent = 'Section ' + (CURSEC + 1);
      });
      p.appendChild(lk);
      card.appendChild(p);
    }
    var src = el('p', 'qsrc' + (q.kind === 'hand' ? ' hand' : ''),
      (q.kind === 'hand' ? 'hand-written \u00b7 ' : '') + srcLine(q));
    card.appendChild(src);
    var row = el('div', 'btnrow');
    row.style.marginTop = '14px';
    [['I had it', 'right'], ['I did not', 'wrong']].forEach(function (m) {
      var b = el('button', 'btn' + (m[1] === 'right' ? ' go' : ''), m[0]);
      b.setAttribute('data-mark-self', m[1]);
      b.addEventListener('click', function () {
        var pr = prog(r.sid);
        pr.seen[q.q] = 1;
        if (m[1] === 'right') { r.right++; pr.right++; } else { r.wrong++; pr.wrong++; }
        saveProg();
        r.i++;
        stepQuiz();
      });
      row.appendChild(b);
    });
    card.appendChild(row);
  });
  card.appendChild(show);
  body.appendChild(card);
}

/* ---- the graded test ------------------------------------------------ */
//  Distractors come from the SAME SECTION, preferring the same kind of
//  question, so the wrong options are the confusions that actually
//  happen rather than obvious throwaways. A test you can pass by
//  elimination has not tested anything.
function makeChoices(q, pool) {
  //  A QUESTION MAY CARRY ITS OWN WRONG OPTIONS, AND WHERE IT DOES THEY
  //  ARE THE ONLY ONES USED.  Drawing distractors from the section pool
  //  works when the answers are mutually exclusive, and breaks when they
  //  are not.  "Which of these is on the hoist preparation checklist?"
  //  drawn from the pool can offer three other items off the same
  //  checklist: three right answers marked wrong.  Those questions have
  //  to name their own wrong options -- items from a NEIGHBOURING
  //  checklist, real text in the wrong place -- and the pack does that.
  if (q.ch && q.ch.length) {
    var carried = q.ch.slice(0, 3).map(function (t) { return { t: t, ok: false }; });
    carried.push({ t: q.a, ok: true });
    return shuffle(carried);
  }
  var same = pool.filter(function (o) {
    return o.a && o.a !== q.a && o.kind === q.kind && !(o.ch && o.ch.length);
  });
  var other = pool.filter(function (o) {
    return o.a && o.a !== q.a && o.kind !== q.kind && !(o.ch && o.ch.length);
  });
  var picks = shuffle(same).slice(0, 3);
  if (picks.length < 3) picks = picks.concat(shuffle(other).slice(0, 3 - picks.length));
  var out = picks.map(function (o) { return { t: o.a, ok: false }; });
  out.push({ t: q.a, ok: true });
  return shuffle(out);
}

/*  ---- ordering questions -------------------------------------------
 *  A four-option question can test which step belongs. It cannot test
 *  that you know the ORDER, because naming a position -- "what is number
 *  four" -- tests the layout of the page rather than the procedure.
 *
 *  So: the steps are offered scrambled, with one that belongs to a
 *  different procedure mixed in, and you tap them into order and leave
 *  the intruder alone. Marked all or nothing. Partial credit would make
 *  a near miss on a sequence look like competence, and on a MOB chain a
 *  near miss is a different outcome entirely.
 */
function isOrder(q) { return !!(q && q.seq && q.seq.length); }

function renderOrder(card, q, mark, advLabel, onAdv) {
  var chosen = [];
  var pool = shuffle(q.seq.concat(q.extra || []));
  var hint = el('p', 'note', 'Tap them into the order they happen. One does not ' +
                            'belong \u2014 leave it out.');
  card.appendChild(hint);

  var picked = el('ol', 'seq-picked');
  var rest = el('div', 'seq-pool');
  card.appendChild(picked);
  card.appendChild(rest);

  var check = el('button', 'btn wide go', 'Check');
  check.setAttribute('data-seq-check', '1');
  check.style.marginTop = '14px';
  check.disabled = true;
  var done = false;

  function draw() {
    picked.textContent = '';
    rest.textContent = '';
    chosen.forEach(function (t, i) {
      var li = el('li', 'seq-row chosen');
      li.appendChild(el('span', 'seq-n', String(i + 1)));
      li.appendChild(el('span', null, t));
      if (!done) li.addEventListener('click', function () {
        chosen.splice(i, 1); draw();
      });
      picked.appendChild(li);
    });
    pool.forEach(function (t) {
      if (chosen.indexOf(t) >= 0) return;
      var b = el('button', 'seq-row');
      b.setAttribute('data-seq-item', t);
      b.appendChild(el('span', null, t));
      if (!done) b.addEventListener('click', function () { chosen.push(t); draw(); });
      rest.appendChild(b);
    });
    check.disabled = done || !chosen.length;
  }

  check.addEventListener('click', function () {
    if (done) return;
    done = true;
    var ok = chosen.length === q.seq.length &&
             chosen.every(function (t, i) { return t === q.seq[i]; });
    draw();
    //  Show the order it should have been, every time. The point of the
    //  question is the sequence, so being told only "wrong" teaches
    //  nothing.
    var right = el('ol', 'seq-picked right');
    q.seq.forEach(function (t, i) {
      var li = el('li', 'seq-row chosen');
      li.setAttribute('data-mark', 'right');
      li.appendChild(el('span', 'seq-n', String(i + 1)));
      li.appendChild(el('span', null, t));
      right.appendChild(li);
    });
    card.appendChild(el('p', 'qsrc', ok ? 'Correct, in that order.'
                                        : 'The order is:'));
    if (!ok) card.appendChild(right);
    if ((q.extra || []).length) {
      card.appendChild(el('p', 'note', 'Not part of it: \u201c' +
        q.extra.join('\u201d, \u201c') + '\u201d.'));
    }
    mark(ok, chosen.join(' \u2192 '));
    var nx = el('button', 'btn wide go', advLabel);
    nx.setAttribute('data-advance', '1');
    nx.style.marginTop = '14px';
    nx.addEventListener('click', onAdv);
    card.appendChild(nx);
  });
  card.appendChild(check);
  draw();
}

function startTest(sid) {
  var graded = qsFor(sid, true);
  var len = Math.min(10, graded.length);
  var qs = shuffle(graded).slice(0, len).map(function (q) {
    return { q: q, choices: isOrder(q) ? null : makeChoices(q, graded) };
  });
  RUN = { mode: 'test', sid: sid, qs: qs, i: 0, right: 0, answers: [] };
  $('drill-title').textContent = PACK.sections[CURSEC].title;
  go('drill');
  $('title').textContent = 'Test';
  stepTest();
}

function stepTest() {
  var r = RUN, body = $('drill-body');
  body.textContent = '';
  $('drill-sub').textContent = 'graded \u00b7 ' + (PACK.pass || 80) + '% to pass';

  if (r.i >= r.qs.length) { finishTest(); return; }

  var item = r.qs[r.i], q = item.q;
  var card = el('div', 'card');
  card.appendChild(el('div', 'qnum', 'Question ' + (r.i + 1) + ' of ' + r.qs.length));
  card.appendChild(el('p', 'qtext', q.q));
  if (isOrder(q)) {
    renderOrder(card, q, function (ok, got) {
      if (ok) r.right++;
      r.answers.push({ q: q, got: got, ok: ok });
      card.appendChild(el('p', 'qsrc', srcLine(q)));
    }, r.i + 1 >= r.qs.length ? 'See the score' : 'Next',
       function () { r.i++; stepTest(); });
    body.appendChild(card);
    return;
  }
  var grid = el('div', 'choices');
  var answered = false;
  item.choices.forEach(function (c, n) {
    var b = el('button', 'choice');
    b.appendChild(el('i', null, 'ABCD'.charAt(n)));
    b.appendChild(el('span', null, c.t));
    b.addEventListener('click', function () {
      if (answered) return;
      answered = true;
      //  Mark it on the spot: right or wrong, and where the right one
      //  came from. Learning happens here, not on the score screen.
      Array.prototype.forEach.call(grid.children, function (x) { x.disabled = true; });
      item.choices.forEach(function (cc, m) {
        if (cc.ok) grid.children[m].setAttribute('data-mark', 'right');
      });
      if (!c.ok) b.setAttribute('data-mark', 'wrong');
      if (c.ok) r.right++;
      r.answers.push({ q: q, got: c.t, ok: c.ok });
      card.appendChild(el('p', 'qsrc' + (q.kind === 'hand' ? ' hand' : ''),
        (q.kind === 'hand' ? 'hand-written \u00b7 ' : '') + srcLine(q)));
      //  A STABLE HOOK, so nothing has to find this button by its words.
      //  A test that matched on "next" clicked an answer containing the
      //  word instead, the question never advanced, and the page hung.
      var nx = el('button', 'btn wide go', r.i + 1 >= r.qs.length ? 'See the score' : 'Next');
      nx.setAttribute('data-advance', '1');
      nx.style.marginTop = '14px';
      nx.addEventListener('click', function () { r.i++; stepTest(); });
      card.appendChild(nx);
    });
    grid.appendChild(b);
  });
  card.appendChild(grid);
  body.appendChild(card);
}

function finishTest() {
  var r = RUN, s = PACK.sections[CURSEC];
  var pct = Math.round(r.right / r.qs.length * 100);
  var need = PACK.pass || 80;
  var ok = pct >= need;
  var pr = prog(r.sid);
  pr.attempts++;
  if (pr.best === null || pct > pr.best) pr.best = pct;
  saveProg();

  var body = $('drill-body');
  body.textContent = '';
  var card = el('div', 'panel');
  var sc = el('div', 'score');
  var big = el('div', 'big ' + (ok ? 'pass' : 'fail'), pct + '%');
  sc.appendChild(big);
  sc.appendChild(el('div', 'of', r.right + ' of ' + r.qs.length + ' \u00b7 ' + need + '% needed'));
  card.appendChild(sc);

  var nextSec = PACK.sections[CURSEC + 1];
  if (ok) {
    card.appendChild(el('p', 'verdict ok', nextSec
      ? 'Passed. \u201c' + nextSec.title + '\u201d is open.'
      : 'Passed \u2014 and that was the last section.'));
  } else {
    card.appendChild(el('p', 'verdict no', 'Not yet. Work the reference and the ' +
      'practice, then take it again \u2014 it reshuffles and redraws the wrong options.'));
  }
  if (pr.best !== pct) card.appendChild(el('p', 'note', 'Your best on this section is ' + pr.best + '%.'));

  var missed = r.answers.filter(function (a) { return !a.ok; });
  if (missed.length) {
    card.appendChild(el('h2', null, 'What you missed'));
    var ul = el('ul', 'items');
    missed.forEach(function (a) {
      var li = el('li');
      var nm = el('span', 'nm');
      nm.appendChild(el('b', null, a.q.q));
      nm.appendChild(el('span', null, a.q.a));
      li.appendChild(nm);
      ul.appendChild(li);
    });
    card.appendChild(ul);
  }

  var b1 = el('button', 'btn wide' + (ok ? '' : ' go'), 'Take it again');
  b1.style.marginTop = '12px';
  b1.addEventListener('click', function () { startTest(r.sid); });
  card.appendChild(b1);
  var b2 = el('button', 'btn wide' + (ok ? ' go' : ''),
    ok && nextSec ? 'On to ' + nextSec.title : 'Back to the sections');
  b2.style.marginTop = '8px';
  b2.addEventListener('click', function () {
    if (ok && nextSec) { openSection(CURSEC + 1); } else { go('home'); }
  });
  card.appendChild(b2);
  body.appendChild(card);
}

/* =====================================================================
   The diagnostic
   ===================================================================== */
function startDiagnostic() {
  var body = $('diag-body');
  body.textContent = '';
  var worked = PACK.sections.filter(function (s) { return studied(s.id); });
  var notYet = PACK.sections.filter(function (s) { return !studied(s.id); });

  if (!worked.length) {
    body.appendChild(el('p', 'note',
      'Nothing to diagnose yet \u2014 no section has been worked. Practise or test ' +
      'one and come back.'));
    return;
  }

  var pick = [];
  worked.forEach(function (s) {
    var graded = qsFor(s.id, true);
    //  An even spread, so one big section cannot dominate the verdict.
    shuffle(graded).slice(0, 4).forEach(function (q) {
      pick.push({ q: q, choices: isOrder(q) ? null : makeChoices(q, graded) });
    });
  });
  pick = shuffle(pick);

  var p = el('p', null, pick.length + ' questions across the ' + worked.length +
    ' section' + (worked.length === 1 ? '' : 's') + ' you have worked.');
  body.appendChild(p);
  if (notYet.length) {
    body.appendChild(el('p', 'note', notYet.length + ' section' +
      (notYet.length === 1 ? ' has' : 's have') + ' not been studied at all and ' +
      'are left out rather than scored as zero: ' +
      notYet.map(function (s) { return s.title; }).join(', ') + '.'));
  }
  var b = el('button', 'btn wide go', 'Start');
  b.style.marginTop = '12px';
  b.addEventListener('click', function () {
    RUN = { mode: 'diag', qs: pick, i: 0, right: 0, answers: [], notYet: notYet };
    $('drill-title').textContent = 'Where am I weak?';
    go('drill');
    $('title').textContent = 'Diagnostic';
    stepDiag();
  });
  body.appendChild(b);
}

function stepDiag() {
  var r = RUN, body = $('drill-body');
  body.textContent = '';
  $('drill-sub').textContent = 'scored per section \u00b7 opens nothing';
  if (r.i >= r.qs.length) { finishDiag(); return; }

  var item = r.qs[r.i], q = item.q;
  var card = el('div', 'card');
  card.appendChild(el('div', 'qnum', 'Question ' + (r.i + 1) + ' of ' + r.qs.length));
  card.appendChild(el('p', 'qtext', q.q));
  if (isOrder(q)) {
    renderOrder(card, q, function (ok) {
      if (ok) r.right++;
      r.answers.push({ section: q.section, ok: ok });
    }, r.i + 1 >= r.qs.length ? 'What should I study?' : 'Next',
       function () { r.i++; stepDiag(); });
    body.appendChild(card);
    return;
  }
  var grid = el('div', 'choices');
  var answered = false;
  item.choices.forEach(function (c, n) {
    var b = el('button', 'choice');
    b.appendChild(el('i', null, 'ABCD'.charAt(n)));
    b.appendChild(el('span', null, c.t));
    b.addEventListener('click', function () {
      if (answered) return;
      answered = true;
      Array.prototype.forEach.call(grid.children, function (x) { x.disabled = true; });
      item.choices.forEach(function (cc, m) {
        if (cc.ok) grid.children[m].setAttribute('data-mark', 'right');
      });
      if (!c.ok) b.setAttribute('data-mark', 'wrong');
      if (c.ok) r.right++;
      r.answers.push({ section: q.section, ok: c.ok });
      var nx = el('button', 'btn wide go', r.i + 1 >= r.qs.length ? 'What should I study?' : 'Next');
      nx.setAttribute('data-advance', '1');
      nx.style.marginTop = '14px';
      nx.addEventListener('click', function () { r.i++; stepDiag(); });
      card.appendChild(nx);
    });
    grid.appendChild(b);
  });
  card.appendChild(grid);
  body.appendChild(card);
}

function finishDiag() {
  var r = RUN, body = $('drill-body');
  body.textContent = '';
  var by = {};
  r.answers.forEach(function (a) {
    if (!by[a.section]) by[a.section] = { n: 0, right: 0 };
    by[a.section].n++;
    if (a.ok) by[a.section].right++;
  });
  var rows = Object.keys(by).map(function (sid) {
    var s = PACK.sections.filter(function (x) { return x.id === sid; })[0];
    return { id: sid, title: s ? s.title : sid, n: by[sid].n, right: by[sid].right,
             pct: Math.round(by[sid].right / by[sid].n * 100) };
  });
  rows.sort(function (a, b) { return a.pct - b.pct; });

  var card = el('div', 'panel');
  var pct = Math.round(r.right / r.qs.length * 100);
  var sc = el('div', 'score');
  sc.appendChild(el('div', 'big' + (pct >= (PACK.pass || 80) ? ' pass' : ''), pct + '%'));
  sc.appendChild(el('div', 'of', r.right + ' of ' + r.qs.length + ' across the sections you have worked'));
  card.appendChild(sc);

  card.appendChild(el('h2', null, 'Weakest first'));
  var ul = el('ul', 'bars');
  rows.forEach(function (x) {
    var li = el('li');
    li.setAttribute('data-state', x.pct >= (PACK.pass || 80) ? 'pass' : 'part');
    var top = el('div', 'top');
    top.appendChild(el('b', null, x.title));
    top.appendChild(el('span', null, x.right + '/' + x.n + '   ' + x.pct + '%'));
    li.appendChild(top);
    var tr = el('div', 'track');
    var i2 = el('i');
    i2.style.width = x.pct + '%';
    tr.appendChild(i2);
    li.appendChild(tr);
    ul.appendChild(li);
  });
  //  Not studied is reported, never averaged in. A gap that looks like a
  //  score gets you a confidently wrong answer about your own readiness.
  (r.notYet || []).forEach(function (s) {
    var li = el('li');
    li.setAttribute('data-state', 'unseen');
    var top = el('div', 'top');
    top.appendChild(el('b', null, s.title));
    top.appendChild(el('span', null, 'not studied'));
    li.appendChild(top);
    var tr = el('div', 'track');
    tr.appendChild(el('i'));
    li.appendChild(tr);
    ul.appendChild(li);
  });
  card.appendChild(ul);

  var worst = rows.filter(function (x) { return x.pct < (PACK.pass || 80); });
  card.appendChild(el('p', 'note', worst.length
    ? 'Study these next: ' + worst.slice(0, 3).map(function (x) { return x.title; }).join(', ') + '.'
    : 'Nothing below the mark in what you have worked.' +
      ((r.notYet || []).length ? ' The gaps above are what is left.' : '')));

  var b = el('button', 'btn wide go', 'Back to the sections');
  b.style.marginTop = '12px';
  b.addEventListener('click', function () { go('home'); });
  card.appendChild(b);
  body.appendChild(card);
}

/* =====================================================================
   The whole document, and about
   ===================================================================== */
function drawDoc() {
  var box = $('doc-body');
  box.textContent = '';
  PACK.sections.forEach(function (s) {
    var h = el('h2', 'part', s.title);
    box.appendChild(h);
    var d = el('div');
    d.innerHTML = s.html || '';
    while (d.firstChild) box.appendChild(d.firstChild);
  });
  if (PACK.back) {
    var d2 = el('div');
    d2.innerHTML = PACK.back;
    while (d2.firstChild) box.appendChild(d2.firstChild);
  }
  wrapTables(box);
  $('find-note').textContent = '';
}

var findTimer = null;
function doFind() {
  var q = $('q-find').value.trim().toLowerCase();
  var box = $('doc-body');
  //  clear any previous marks
  Array.prototype.forEach.call(box.querySelectorAll('mark'), function (m) {
    var t = document.createTextNode(m.textContent);
    m.parentNode.replaceChild(t, m);
  });
  box.normalize();
  if (q.length < 2) { $('find-note').textContent = ''; return; }
  var walker = document.createTreeWalker(box, NodeFilter.SHOW_TEXT, null);
  var hits = 0, nodes = [], n;
  while ((n = walker.nextNode())) {
    if (n.nodeValue.toLowerCase().indexOf(q) >= 0) nodes.push(n);
  }
  nodes.forEach(function (node) {
    var parts = node.nodeValue.split(new RegExp('(' + q.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + ')', 'ig'));
    if (parts.length < 2) return;
    var frag = document.createDocumentFragment();
    parts.forEach(function (p) {
      if (p.toLowerCase() === q) { frag.appendChild(el('mark', null, p)); hits++; }
      else frag.appendChild(document.createTextNode(p));
    });
    node.parentNode.replaceChild(frag, node);
  });
  $('find-note').textContent = hits ? hits + ' match' + (hits === 1 ? '' : 'es') : 'nothing found';
  var first = box.querySelector('mark');
  if (first) first.scrollIntoView({ block: 'center' });
}

function drawAbout() {
  $('about-pack').textContent = PACK
    ? (PACK.title || 'a pack') + ', built ' + (PACK.built || 'unknown') + ', ' +
      PACK.sections.length + ' sections and ' + PACK.questions.length + ' questions. ' +
      'It is held in this browser on this device only.'
    : 'No pack loaded.';
  if (!('caches' in window)) { $('off-state').textContent = 'This browser will not cache for offline use.'; return; }
  caches.open('drill-v1').then(function (c) { return c.match('./'); }).then(function (hit) {
    $('off-state').textContent = hit
      ? 'The app is cached and runs with no network. Your pack is in storage, not in the cache.'
      : 'Not cached yet \u2014 open this page once with a connection.';
  }).catch(function () { $('off-state').textContent = 'Could not read the cache.'; });
}

/* =====================================================================
   Start
   ===================================================================== */
window.addEventListener('DOMContentLoaded', function () {
  setMode(lsGet('mode', 'dark') === 'night' ? 'night' : 'dark');
  $('mode').addEventListener('click', function () {
    setMode(document.documentElement.getAttribute('data-mode') === 'night' ? 'dark' : 'night');
  });
  $('back').addEventListener('click', function () {
    if (VIEW === 'drill' && RUN && RUN.mode !== 'diag') { go('section'); drawTabs(RUN.mode === 'test' ? 'test' : 'quiz');
      $('title').textContent = 'Section ' + (CURSEC + 1); return; }
    go(BACKTO[VIEW] || 'home');
  });
  ['ver', 'ver2', 'ver3'].forEach(function (id) {
    if ($(id)) $(id).textContent = 'build ' + BUILD;
  });
  Array.prototype.forEach.call(document.querySelectorAll('[data-go]'), function (b) {
    b.addEventListener('click', function () { go(b.getAttribute('data-go')); });
  });
  $('f-pack').addEventListener('change', function (e) {
    if (e.target.files && e.target.files[0]) loadPack(e.target.files[0]);
  });
  $('b-replace').addEventListener('click', function () { go('empty'); });
  $('b-reset').addEventListener('click', function () {
    //  Destructive and irreversible, so it asks.
    if (!window.confirm('Reset every score and lock every section again? The pack stays loaded.')) return;
    PROG = {};
    saveProg().then(function () {
      $('reset-note').textContent = 'Progress reset.';
      drawHome();
    });
  });
  $('q-find').addEventListener('input', function () {
    if (findTimer) clearTimeout(findTimer);
    findTimer = setTimeout(doFind, 180);
  });

  Promise.all([kvGet('pack'), kvGet('progress')]).then(function (r) {
    PACK = r[0] || null;
    PROG = r[1] || {};
    go(PACK ? 'home' : 'empty');
  }).catch(function (e) {
    go('empty');
    $('load-note').textContent = 'Storage is not available here: ' + e.message;
  });

  if ('serviceWorker' in navigator && location.protocol !== 'file:') {
    if (window.DRILL_NO_SW) {
      navigator.serviceWorker.getRegistrations().then(function (rs) {
        rs.forEach(function (x) { x.unregister(); });
      }).catch(function () {});
    } else {
      navigator.serviceWorker.register('sw.js').catch(function () {});
    }
  }
});
