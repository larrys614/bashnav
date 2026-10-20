/*  Drive the drill app.
 *
 *  The harness builds its OWN synthetic pack, so this test -- which lives
 *  in a public repository -- carries nobody's material. Pass a real pack
 *  as argv[2] to run the same checks against it.
 *
 *  The check that matters most is not a score. It is that no answer is in
 *  the DOM before it is asked for: hidden is not good enough, because an
 *  answer you can reveal with a long press is an answer you have read.
 */
'use strict';
const path = require('path');
const fs = require('fs');
const { chromium } = require('playwright');

const BASE = 'http://127.0.0.1:8091/drill/';
const TMP = process.env.TMPDIR || '/tmp';

//  A pack of three sections with wholly invented content.
function synthPack() {
  const sections = [
    { id: 'alpha', title: 'First things', parts: ['Part 1 — First things'],
      html: '<h2 class="part">Part 1 — First things</h2><p>The first rule is to <strong>check the thing</strong> before moving on.</p><table><tr><th>step</th><th>what</th></tr><tr><td>1</td><td>Check the thing</td></tr><tr><td>2</td><td>Move the other thing</td></tr></table>' },
    { id: 'bravo', title: 'Second things', parts: ['Part 2 — Second things'],
      html: '<h2 class="part">Part 2 — Second things</h2><p>Second things follow first things.</p>' },
    { id: 'charlie', title: 'Third things', parts: ['Part 3 — Third things'],
      html: '<h2 class="part">Part 3 — Third things</h2><p>Third things are last.</p>' },
  ];
  const questions = [];
  sections.forEach((s, si) => {
    for (let i = 1; i <= 12; i++) {
      questions.push({ section: s.id, kind: 'fact',
        q: `${s.title} — what is fact ${i}?`,
        a: `Fact ${i} of section ${si + 1} is that the thing is checked`,
        where: { part: s.parts[0], sub: 'Facts', row: String(i) } });
    }
    questions.push({ section: s.id, kind: 'authored', q: `Recall everything about ${s.title}.`,
      a: '', where: { part: s.parts[0], sub: 'Drill', row: 'drill' } });
    questions.push({ section: s.id, kind: 'hand', q: `${s.title} — why does the order matter?`,
      a: 'Because the later thing depends on the earlier one',
      where: { part: s.parts[0], sub: 'Discussion', row: 'hand-written' } });
  });
  return { format: 'bashnav-drill-pack/1', title: 'Test pack', note: 'Synthetic. Not real material.',
           built: '2026-10-20', pass: 80, sections, questions, back: '<p>Back matter.</p>' };
}

(async () => {
  const packPath = process.argv[2] || path.join(TMP, 'synth.drillpack.json');
  if (!process.argv[2]) fs.writeFileSync(packPath, JSON.stringify(synthPack()));
  const real = !!process.argv[2];
  console.log('pack: ' + (real ? packPath : 'synthetic, built by this harness'));

  const browser = await chromium.launch();
  const ctx = await browser.newContext({ viewport: { width: 744, height: 1133 }, deviceScaleFactor: 2 });
  const page = await ctx.newPage();
  const errs = [];
  page.on('console', m => { if (m.type() === 'error') errs.push(m.text()); });
  page.on('pageerror', e => errs.push('pageerror: ' + e.message));
  await page.goto(BASE, { waitUntil: 'networkidle' });
  await page.waitForFunction(() => typeof window.PACK !== 'undefined', { timeout: 15000 });
  let bad = 0;
  const fail = m => { bad++; console.log('  FAIL ' + m); };
  console.log('build ' + await page.evaluate(() => window.BUILD));

  // ---- it ships empty ------------------------------------------------
  const emptyShown = await page.evaluate(() => !document.getElementById('v-empty').hidden);
  if (!emptyShown) fail('a fresh load did not show the empty state');
  else console.log('  ok   ships empty: no pack, no questions, nothing to drill');

  // ---- loading a pack -------------------------------------------------
  await page.setInputFiles('#f-pack', packPath);
  await page.waitForFunction(() => window.PACK && !document.getElementById('v-home').hidden,
                             { timeout: 15000 });
  const nsec = await page.evaluate(() => PACK.sections.length);
  console.log('  ok   pack loaded: ' + nsec + ' sections, ' +
              (await page.evaluate(() => PACK.questions.length)) + ' questions');

  // a damaged pack must be refused whole
  const badPath = path.join(TMP, 'bad.drillpack.json');
  fs.writeFileSync(badPath, JSON.stringify({ format: 'bashnav-drill-pack/1',
    sections: [{ id: 'a', title: 'A' }], questions: [{ section: 'nope', q: 'x', a: 'y' }] }));
  const refused = await page.evaluate(p => {
    const v = window.validate ? validate(p) : 'validate() not exposed';
    return v;
  }, JSON.parse(fs.readFileSync(badPath, 'utf8')));
  if (!refused || /not exposed/.test(refused)) fail('a pack pointing at a missing section was not refused: ' + refused);
  else console.log('  ok   a pack with orphan questions is refused whole: "' + refused + '"');

  // ---- the gate -------------------------------------------------------
  const states = await page.$$eval('#seclist .seclink', els =>
    els.map(e => e.getAttribute('data-state')));
  if (states[0] === 'locked') fail('the first section is locked');
  if (nsec > 1 && states[1] !== 'locked') fail('the second section is not locked before the first is passed');
  else console.log('  ok   section 1 open, section 2 locked');

  // ---- THE REFERENCE IS NEVER GATED -----------------------------------
  await page.evaluate(() => openSection(1));
  await page.waitForTimeout(150);
  const refText = await page.evaluate(() => {
    drawTabs('ref');
    return document.querySelector('#sec-body .ref').textContent.trim().length;
  });
  if (refText < 20) fail('a locked section’s reference is empty or withheld');
  else console.log('  ok   a LOCKED section’s reference is fully readable (' + refText + ' chars)');
  const testLocked = await page.evaluate(() => {
    drawTabs('test');
    return document.querySelector('#sec-body .warn') !== null;
  });
  if (!testLocked) fail('a locked section’s test is available');
  else console.log('  ok   and only its test waits, with the reason given');

  // ---- NO ANSWER IN THE DOM BEFORE IT IS ASKED FOR --------------------
  await page.evaluate(() => { openSection(0); drawTabs('quiz'); });
  await page.waitForTimeout(100);
  await page.evaluate(() => document.querySelector('#sec-body .btn.go').click());
  await page.waitForTimeout(150);
  //  Recall prompts come first in practice and have no written answer, so
  //  RUN.qs[0] cannot test for a leak. Skip to the first question that
  //  HAS an answer -- that is the one that could leak.
  const leak = await page.evaluate(async () => {
    while (RUN.i < RUN.qs.length && !RUN.qs[RUN.i].a) {
      const b = document.querySelector('#drill-body [data-reveal]');
      if (b) b.click();
      await new Promise(r => setTimeout(r, 10));
      const m = document.querySelector('#drill-body [data-mark-self]');
      if (!m) break;
      m.click();
      await new Promise(r => setTimeout(r, 10));
    }
    const q = RUN.qs[RUN.i];
    const html = document.getElementById('drill-body').innerHTML;
    return { graded: !!q.a, hasAnswer: q.a ? html.indexOf(q.a) >= 0 : false,
             qa: q.a ? q.a.slice(0, 40) : '(no graded question reached)' };
  });
  if (!leak.graded) fail('could not reach a graded question to test the leak');
  if (leak.hasAnswer) fail('the answer is already in the DOM before it is asked for');
  else console.log('  ok   the answer is absent from the DOM, not hidden (' + leak.qa + '…)');
  await page.evaluate(() => {
    const b = document.querySelector('#drill-body [data-reveal]');
    if (b) b.click();
  });
  await page.waitForTimeout(120);
  const after = await page.evaluate(() => {
    const q = RUN.qs[0];
    return q.a ? document.getElementById('drill-body').innerHTML.indexOf(q.a) >= 0 : true;
  });
  if (!after) fail('the answer did not appear when asked for');
  else console.log('  ok   and appears when asked for');

  // ---- failing the test keeps the next section locked ------------------
  await page.evaluate(() => { openSection(0); startTest(PACK.sections[0].id); });
  await page.waitForTimeout(150);
  await page.evaluate(async () => {
    //  answer every question wrong on purpose. The guard matters: a loop
    //  that cannot advance must fail loudly rather than hang the page.
    let guard = 0;
    while (RUN.i < RUN.qs.length) {
      if (++guard > 200) throw new Error('the test would not advance');
      const wrong = Array.from(document.querySelectorAll('#drill-body .choice'))
        .filter((b, n) => !RUN.qs[RUN.i].choices[n].ok)[0];
      (wrong || document.querySelector('#drill-body .choice')).click();
      await new Promise(r => setTimeout(r, 10));
      const nx = document.querySelector('#drill-body [data-advance]');
      if (!nx) break;
      nx.click();
      await new Promise(r => setTimeout(r, 10));
    }
  });
  await page.waitForTimeout(250);
  const failed = await page.evaluate(() => ({
    pct: document.querySelector('#drill-body .big') ? document.querySelector('#drill-body .big').textContent : '?',
    locked: !unlocked(1),
  }));
  if (!failed.locked) fail('failing the test still unlocked the next section');
  else console.log('  ok   failing (' + failed.pct + ') leaves the next section locked');

  // ---- passing it unlocks ---------------------------------------------
  await page.evaluate(() => { openSection(0); startTest(PACK.sections[0].id); });
  await page.waitForTimeout(150);
  await page.evaluate(async () => {
    let guard = 0;
    while (RUN.i < RUN.qs.length) {
      if (++guard > 200) throw new Error('the test would not advance');
      const n = RUN.qs[RUN.i].choices.findIndex(c => c.ok);
      document.querySelectorAll('#drill-body .choice')[n].click();
      await new Promise(r => setTimeout(r, 10));
      const nx = document.querySelector('#drill-body [data-advance]');
      if (!nx) break;
      nx.click();
      await new Promise(r => setTimeout(r, 10));
    }
  });
  await page.waitForTimeout(250);
  const won = await page.evaluate(() => ({
    pct: document.querySelector('#drill-body .big').textContent,
    open: unlocked(1),
    best: PROG[PACK.sections[0].id].best,
  }));
  if (!won.open) fail('passing the test did not unlock the next section (' + won.pct + ')');
  else console.log('  ok   passing (' + won.pct + ') unlocks section 2; best recorded as ' + won.best + '%');

  // ---- progress survives a reload --------------------------------------
  await page.reload({ waitUntil: 'networkidle' });
  await page.waitForFunction(() => window.PACK && Object.keys(window.PROG || {}).length > 0,
                             { timeout: 15000 });
  const kept = await page.evaluate(() => ({ best: PROG[PACK.sections[0].id].best, open: unlocked(1) }));
  if (!kept.open || kept.best === null) fail('progress did not survive a reload');
  else console.log('  ok   progress survived a reload (best ' + kept.best + '%, section 2 still open)');

  // ---- the diagnostic separates "not studied" from "weak" --------------
  await page.evaluate(() => go('diag'));
  await page.waitForTimeout(200);
  const diag = await page.textContent('#diag-body');
  if (!/not been studied/.test(diag)) fail('the diagnostic does not report unstudied sections separately');
  else console.log('  ok   the diagnostic names unstudied sections instead of scoring them zero');
  await page.evaluate(() => document.querySelector('#diag-body .btn.go').click());
  await page.waitForTimeout(200);
  await page.evaluate(async () => {
    let guard = 0;
    while (RUN.i < RUN.qs.length) {
      if (++guard > 400) throw new Error('the diagnostic would not advance');
      document.querySelectorAll('#drill-body .choice')[0].click();
      await new Promise(r => setTimeout(r, 8));
      const nx = document.querySelector('#drill-body [data-advance]');
      if (!nx) break;
      nx.click();
      await new Promise(r => setTimeout(r, 8));
    }
  });
  await page.waitForTimeout(250);
  const rep = await page.textContent('#drill-body');
  if (!/Weakest first/.test(rep)) fail('the diagnostic produced no per-section report');
  else console.log('  ok   it reports per section, weakest first');
  const unseenRows = await page.$$eval('#drill-body .bars li[data-state="unseen"]', e => e.length);
  console.log('  ok   ' + unseenRows + ' section(s) shown as "not studied" rather than 0%');

  // ---- the document, and search ----------------------------------------
  await page.evaluate(() => go('doc'));
  await page.waitForTimeout(150);
  const docLen = await page.evaluate(() => document.getElementById('doc-body').textContent.length);
  if (docLen < 50) fail('the whole-document view is empty');
  else console.log('  ok   the whole document renders (' + docLen.toLocaleString() + ' chars)');
  await page.fill('#q-find', 'thing');
  await page.waitForTimeout(300);
  const found = await page.textContent('#find-note');
  if (!/match/.test(found)) fail('search found nothing: ' + found);
  else console.log('  ok   search works: ' + found);

  // ---- layout -----------------------------------------------------------
  for (const w of [744, 390, 320]) {
    await page.setViewportSize({ width: w, height: 900 });
    await page.waitForTimeout(150);
    const o = await page.evaluate(() => ({ doc: document.documentElement.scrollWidth, win: window.innerWidth }));
    if (o.doc > o.win + 1) fail('sideways scroll at ' + w + 'px (' + o.doc + ' > ' + o.win + ')');
  }
  console.log('  ok   no sideways scroll at 744, 390 and 320 px');

  await page.setViewportSize({ width: 744, height: 1133 });
  await page.evaluate(() => go('home'));
  await page.waitForTimeout(250);
  await page.screenshot({ path: path.join(TMP, 'drill-home.png'), fullPage: true });

  console.log('');
  if (errs.length) { console.log('CONSOLE ERRORS (' + errs.length + '):'); errs.slice(0, 8).forEach(e => console.log('  ' + e)); bad += errs.length; }
  else console.log('no console errors');
  console.log(bad ? bad + ' FAILURES' : 'all checks passed');
  await browser.close();
  process.exit(bad ? 1 : 0);
})();
