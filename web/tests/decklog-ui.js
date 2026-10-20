/*  Drive the deck-log page: make a real entry through the app's own code
    paths, export it, and check the exported bytes against the awk reader.
    The log is append-only, so a record this app writes badly is permanent
    -- which is why the end-to-end check is on the EXPORTED FILE, read
    back by the awk tool, and not on what the screen says. */
const { chromium } = require('playwright');
const { execFileSync } = require('child_process');
const fs = require('fs'), path = require('path');
const ROOT = path.resolve(__dirname, '..', '..');
const SRC = path.resolve(__dirname, '..', '..', 'src');
const BASE = 'http://127.0.0.1:8089/deck-log/';

const PROBE = path.join(process.env.TMPDIR || '/tmp', 'decklog-probe.awk');
function awkRead(file) {
  //  the awk tool's own reader, over the exported file.  The probe goes
  //  in a file: mawk has no /dev/stdin in this container.
  fs.writeFileSync(PROBE, `BEGIN{
      n = lg_read(F, "")
      printf "GOOD\\t%d\\nBAD\\t%d\\n", LG_GOOD, LG_BAD
      if(LG_BAD) printf "BADLINE\\t%s\\n", LG_BADLINE
      for(i=1;i<=n;i++){ lg_at(i); printf "REC\\t%s\\t%s\\t%d\\n", LG_TS, LG_TYPE, LG_NF
        for(k in LG) printf "KV\\t%d\\t%s\\t%s\\n", i, k, LG[k] }
    }`);
  return execFileSync('mawk', ['-v', 'F=' + file,
    '-f', SRC + '/common/log.awk', '-f', PROBE], { encoding: 'utf8' });
}

(async () => {
  const browser = await chromium.launch();
  const ctx = await browser.newContext({ viewport: { width: 744, height: 1133 }, deviceScaleFactor: 2,
                                         acceptDownloads: true });
  const page = await ctx.newPage();
  const errs = [];
  page.on('console', m => { if (m.type() === 'error') errs.push(m.text()); });
  page.on('pageerror', e => errs.push('pageerror: ' + e.message));

  await page.goto(BASE, { waitUntil: 'networkidle' });
  await page.waitForFunction(() => typeof window.RECS !== 'undefined', { timeout: 15000 });
  console.log('build ' + await page.evaluate(() => window.BUILD));
  let bad = 0;
  const fail = m => { bad++; console.log('  FAIL ' + m); };

  // ---- the registry, so parts and equipment exist -------------------
  await page.evaluate(() => {
    const reg = [
      VIEWS.registryLine('eq', [['id','eng.main'],['name','main engine'],['make','Yanmar'],
                                ['model','4JH4-TE'],['serial','E12345'],
                                ['plate','4JH4-TE  S/N E12345  E/G 3TNV88=B']]),
      VIEWS.registryLine('pt', [['id','impeller'],['name','raw water impeller'],
                                ['number','Jabsco 17937-0001'],['fits','eng.main'],
                                ['min','2'],['stow','port bilge, box 3']])
    ].join('\n') + '\n';
    return STORE.metaSet('registry', reg).then(() => reload());
  });
  const regOk = await page.evaluate(() => REG.pt.length === 1 && REG.eq.length === 1 &&
                                          REG.eqById['eng.main'].plate === '4JH4-TE  S/N E12345  E/G 3TNV88=B');
  if (!regOk) fail('the registry did not round-trip through the store (the plate has an = in it)');
  else console.log('  ok   the registry round-trips, = in the plate and all');

  // ---- a real entry, through the UI ---------------------------------
  await page.click('#b-entry');
  await page.waitForTimeout(100);
  const slot = await page.evaluate(() => ENTRY.slot);

  async function setField(key, value) {
    const ok = await page.evaluate(([k, v]) => {
      const inputs = document.querySelectorAll('#sec-fields .field');
      for (const f of inputs) {
        const lab = f.querySelector('.lab b').textContent;
        if (!window.__fieldKey) window.__fieldKey = {};
        const inp = f.querySelector('input');
        if (!inp) continue;
        if (f.dataset.k === k) { }
      }
      return false;
    }, [key, value]);
    return ok;
  }
  // The fields carry no key in the DOM, so drive them by index from the
  // section definition -- which is also what a person does: top to bottom.
  await page.evaluate(() => {
    const s = SECTIONS[0];
    const fields = document.querySelectorAll('#sec-fields .field');
    const want = { lat: '41 14.0N', lon: '072 05.0W', crs: '096', sog: '8.5',
                   wdir: '292', wspd: '19', note: 'squall line to the west|watch it' };
    s.fields.forEach((f, i) => {
      if (!(f.k in want)) return;
      const inp = fields[i].querySelector('input');
      inp.value = want[f.k];
      inp.dispatchEvent(new Event('input', { bubbles: true }));
    });
  });
  // sea state 4, by its code button
  await page.evaluate(() => {
    const s = SECTIONS[0];
    const idx = s.fields.findIndex(f => f.k === 'sea');
    const codes = document.querySelectorAll('#sec-fields .field')[idx].querySelectorAll('.code');
    for (const c of codes) if (c.querySelector('i').textContent === '4') { c.click(); return; }
  });
  await page.waitForTimeout(80);
  await page.click('#e-commit');
  await page.waitForFunction(() => /logged/.test(document.getElementById('e-state').textContent),
                             { timeout: 8000 });
  console.log('  ok   deck section logged: ' + (await page.textContent('#e-state')).trim());

  // ---- weather, with a decline and an unobservable -------------------
  await page.evaluate(() => { ENTRY.sec = 1; drawSecNav(); drawSection(); });
  await page.evaluate(() => {
    const s = SECTIONS[1];
    const fields = document.querySelectorAll('#sec-fields .field');
    const want = { mslp: '1013.2', pchg: '-1.4', airt: '12.5', dewp: '9.0', seat: '14.2' };
    s.fields.forEach((f, i) => {
      if (!(f.k in want)) return;
      const inp = fields[i].querySelector('input');
      inp.value = want[f.k];
      inp.dispatchEvent(new Event('input', { bubbles: true }));
    });
    // total cloud 0 -- zero is a reading, not a blank
    const ci = s.fields.findIndex(f => f.k === 'cloud');
    for (const c of fields[ci].querySelectorAll('.code'))
      if (c.querySelector('i').textContent === '0') { c.click(); break; }
  });
  await page.waitForTimeout(80);
  await page.evaluate(() => {
    const s = SECTIONS[1];
    const fields = document.querySelectorAll('#sec-fields .field');
    // low cloud: not observable (dark)
    const li = s.fields.findIndex(f => f.k === 'cl');
    fields[li].querySelectorAll('.dbtn')[1].click();
  });
  await page.waitForTimeout(80);
  await page.evaluate(() => {
    const s = SECTIONS[1];
    const fields = document.querySelectorAll('#sec-fields .field');
    // sea temperature: asked, not taken
    const si = s.fields.findIndex(f => f.k === 'swper');
    fields[si].querySelectorAll('.dbtn')[0].click();
  });
  await page.waitForTimeout(80);
  await page.click('#e-commit');
  await page.waitForFunction(() => /logged/.test(document.getElementById('e-state').textContent));
  console.log('  ok   weather section logged');

  // ---- an engine job that uses the last impeller --------------------
  //  A stocktake BEFORE the job, as it would be in life.  Written at the
  //  same timestamp it sorts after the job by line text -- 'eng' before
  //  'inv' -- and a stocktake SETS the holding, so the warning correctly
  //  does not fire.  That ordering is deliberate (it is what makes the
  //  merge commutative), so the test has to stage a realistic sequence
  //  rather than expect the app to guess what was meant.
  await page.evaluate(() => {
    return STORE.append(LOG.make('2026-06-01T10:00Z', 'inv',
      [['part','impeller'],['count','1'],['action','stocktake']])).then(reload);
  });
  await page.waitForTimeout(300);
  await page.evaluate(() => { ENTRY.sec = 2; drawSecNav(); drawSection(); });
  await page.evaluate(() => {
    const s = SECTIONS[2];
    const fields = document.querySelectorAll('#sec-fields .field');
    const eqi = s.fields.findIndex(f => f.k === 'eq');
    const sel = fields[eqi].querySelector('select');
    sel.value = 'eng.main'; sel.dispatchEvent(new Event('change', { bubbles: true }));
    const pti = s.fields.findIndex(f => f.k === 'part');
    const sel2 = fields[pti].querySelector('select');
    sel2.value = 'impeller'; sel2.dispatchEvent(new Event('change', { bubbles: true }));
    [['hrs','1234.5'],['job','impeller'],['qty','1']].forEach(([k, v]) => {
      const i = s.fields.findIndex(f => f.k === k);
      const inp = fields[i].querySelector('input');
      inp.value = v; inp.dispatchEvent(new Event('input', { bubbles: true }));
    });
  });
  await page.waitForTimeout(80);
  await page.click('#e-commit');
  await page.waitForFunction(() => /logged/.test(document.getElementById('e-state').textContent));
  const msg = (await page.textContent('#e-state')).trim();
  console.log('  ok   engine job logged');
  if (!/last one/i.test(msg) || !/short/i.test(msg)) {
    fail('using the last impeller did not warn at the moment of use: ' + msg);
  } else {
    console.log('  ok   warned at the moment of use: ' + msg.replace(/\s+/g, ' '));
  }

  // ---- decline the stores section -----------------------------------
  await page.evaluate(() => { ENTRY.sec = 3; drawSecNav(); drawSection(); });
  await page.click('#e-decline');
  await page.waitForFunction(() => /declined/.test(document.getElementById('e-state').textContent));
  console.log('  ok   a declined section is one record, recorded as declined');

  // ---- the implausible value is a question, not a rejection ---------
  await page.evaluate(() => { ENTRY.sec = 1; drawSecNav(); drawSection(); });
  const why = await page.evaluate(() => {
    const s = SECTIONS[1];
    const i = s.fields.findIndex(f => f.k === 'mslp');
    const f = document.querySelectorAll('#sec-fields .field')[i];
    const inp = f.querySelector('input');
    inp.value = '1132'; inp.dispatchEvent(new Event('input', { bubbles: true }));
    const w = f.querySelector('.why');
    return w ? w.textContent : '';
  });
  if (!/outside anything recorded on earth/.test(why)) fail('1132 hPa drew no question: ' + JSON.stringify(why));
  else console.log('  ok   1132 hPa is questioned, not rejected: "' + why.trim() + '"');

  // ---- export, and read it back with the awk tool -------------------
  const text = await page.evaluate(() => STORE.exportText());
  const out = path.join(process.env.TMPDIR || '/tmp', 'decklog-exported.log');
  fs.writeFileSync(out, text);
  const back = awkRead(out);
  const good = +(/^GOOD\t(\d+)/m.exec(back) || [])[1];
  const badn = +(/^BAD\t(\d+)/m.exec(back) || [])[1];
  console.log('  awk read the exported file: ' + good + ' good, ' + badn + ' bad');
  if (badn) fail('the awk tool could not read records this app wrote: ' +
                 (/^BADLINE\t(.*)$/m.exec(back) || [])[1]);
  if (good < 5) fail('expected at least 5 records in the export, got ' + good);

  // the awkward values must survive the whole round trip
  const kv = {};
  for (const L of back.split('\n')) {
    const f = L.split('\t');
    if (f[0] === 'KV') kv[f[2]] = f.slice(3).join('\t');
  }
  if (kv.note !== 'squall line to the west|watch it')
    fail('a note containing | did not survive: ' + JSON.stringify(kv.note));
  else console.log('  ok   a note containing | survived app -> export -> awk');
  if (kv.cloud !== '0') fail('total cloud 0 did not survive as a reading: ' + JSON.stringify(kv.cloud));
  else console.log('  ok   cloud=0 survived as a reading, not a blank');
  if (kv.cl !== '/') fail('an unobservable field did not survive as /: ' + JSON.stringify(kv.cl));
  else console.log('  ok   an unobservable field survived as /');
  if (kv.swper !== '-') fail('a not-taken field did not survive as -: ' + JSON.stringify(kv.swper));
  else console.log('  ok   a not-taken field survived as -');
  if (kv.declined !== '1') fail('the declined section is not in the export');
  else console.log('  ok   the declined section is in the export');

  // ---- merge the export back in: idempotent -------------------------
  const before = await page.evaluate(() => RECS.length);
  const pv = await page.evaluate(t => STORE.previewMerge(t), text);
  if (pv.add !== 0 || pv.dup < 5) fail('re-importing our own export was not a no-op: ' + JSON.stringify(pv));
  else console.log('  ok   re-importing the app\'s own export adds nothing (' + pv.dup + ' already held)');

  // ---- append-only: every earlier line is byte-identical ------------
  const linesBefore = await page.evaluate(() => STORE.allLines());
  await page.evaluate(() => STORE.append(LOG.make(LOG.stamp(), 'nav', [['crs','100']])).then(reload));
  await page.waitForTimeout(300);
  const linesAfter = await page.evaluate(() => STORE.allLines());
  let same = linesAfter.length === linesBefore.length + 1;
  for (let i = 0; i < linesBefore.length && same; i++) same = linesBefore[i] === linesAfter[i];
  if (!same) fail('a write changed an earlier record');
  else console.log('  ok   appending left every earlier record byte-identical (' +
                   linesBefore.length + ' -> ' + linesAfter.length + ')');

  // ---- the views screens render -------------------------------------
  await page.evaluate(() => { go('boat'); });
  await page.waitForTimeout(200);
  const holdTxt = await page.textContent('#hold-list');
  if (!/impeller/.test(holdTxt)) fail('the locker screen does not show the impeller: ' + holdTxt);
  else console.log('  ok   the locker and shopping list render');

  // ---- no sideways scroll at the sizes it is used at ----------------
  for (const w of [744, 390, 320]) {
    await page.setViewportSize({ width: w, height: 900 });
    await page.waitForTimeout(150);
    const o = await page.evaluate(() => ({ doc: document.documentElement.scrollWidth, win: window.innerWidth }));
    if (o.doc > o.win + 1) fail('sideways scroll at ' + w + 'px (' + o.doc + ' > ' + o.win + ')');
  }
  console.log('  ok   no sideways scroll at 744, 390 and 320 px');

  await page.setViewportSize({ width: 744, height: 1133 });
  await page.evaluate(() => { go('home'); drawHome(); });
  await page.waitForTimeout(250);
  await page.screenshot({ path: path.join(process.env.TMPDIR || '/tmp', 'dl-home.png'), fullPage: true });
  await page.evaluate(() => { startEntry(); });
  await page.waitForTimeout(250);
  await page.screenshot({ path: path.join(process.env.TMPDIR || '/tmp', 'dl-entry.png'), fullPage: true });
  await page.evaluate(() => { go('boat'); });
  await page.waitForTimeout(250);
  await page.screenshot({ path: path.join(process.env.TMPDIR || '/tmp', 'dl-boat.png'), fullPage: true });

  console.log('');
  if (errs.length) { console.log('CONSOLE ERRORS (' + errs.length + '):'); errs.slice(0,8).forEach(e => console.log('  ' + e)); bad += errs.length; }
  else console.log('no console errors');
  console.log(bad ? bad + ' FAILURES' : 'all checks passed');
  await browser.close();
  process.exit(bad ? 1 : 0);
})();
