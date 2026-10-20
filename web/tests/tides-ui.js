/* End-to-end: drive the page and check what it SHOWS against the awk
   tool's own output.  Module-level diffs cannot catch a wiring mistake --
   a wrong timezone, a date off by one, a panel that never updates -- and
   those are the bugs that actually reach the iPad. */
const { chromium } = require('playwright');
const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const BASE = 'http://127.0.0.1:8088/tides/';
const SRC = path.resolve(__dirname, '..', '..', 'src', 'tides') + path.sep;

function awkDay(id, y, m, d, now) {
  return execFileSync('mawk', [
    '-v', 'cmode=plain', '-v', 'SF=' + SRC + 'stations.dat', '-v', 'cmd=day',
    '-v', 'id=' + id, '-v', 'yy=' + y, '-v', 'mm=' + m, '-v', 'dd=' + d,
    '-v', 'sky=0', '-v', 'nowdate=' + (now || '1970-01-01'), '-v', 'nowtime=00:00',
    '-f', SRC + 'tables.awk', '-f', SRC + 'engine.awk'
  ], { input: '', encoding: 'utf8', cwd: SRC });
}
function awkTable(txt) {
  return txt.split('\n')
    .map(l => l.match(/^\s+(HIGH|low)\s+(\d\d:\d\d)\s+(-?\d+\.\d\d) m/))
    .filter(Boolean)
    .map(m => ({ k: m[1] === 'HIGH' ? 'H' : 'L', t: m[2], h: m[3] }));
}

const CASES = [
  { id: 'noaa/8452660', name: 'Newport RI (reference)',          y: 2026, m: 10, d: 20 },
  { id: 'noaa/9455920', name: 'Anchorage (69 constituents)',     y: 2026, m: 10, d: 20 },
  { id: 'noaa/8443970', name: 'Boston',                          y: 2027, m:  3, d: 15 },
  { id: 'noaa/1610367', name: 'Nonopapa (subordinate, ratio)',   y: 2026, m: 10, d: 20 },
  { id: 'noaa/1613077', name: 'subordinate, fixed offset',       y: 2026, m:  6, d: 21 },
  { id: 'ticon/ambon-133-idn-uhslc_fd', name: 'Ambon (near the equator)', y: 2026, m: 10, d: 20 },
  { id: 'ticon/albany-62120-aus-bom',   name: 'Albany (southern)',        y: 2024, m:  2, d: 29 }
];

(async () => {
  const browser = await chromium.launch();
  // iPad mini 6, portrait: the device this is for.
  const ctx = await browser.newContext({ viewport: { width: 744, height: 1133 }, deviceScaleFactor: 2 });
  const page = await ctx.newPage();
  const errs = [];
  page.on('console', m => { if (m.type() === 'error') errs.push(m.text()); });
  page.on('pageerror', e => errs.push('pageerror: ' + e.message));

  await page.goto(BASE, { waitUntil: 'networkidle' });
  await page.waitForFunction(() => window.IDX && window.IDX.n > 0, { timeout: 20000 })
    .catch(() => {});
  const n = await page.evaluate(() => (window.IDX ? IDX.n : -1));
  console.log('station index loaded: ' + n + ' stations');
  console.log('build stamp: ' + (await page.evaluate(() => window.BUILD || '(none)')));

  let bad = 0;
  for (const c of CASES) {
    // choose the station and the date through the app's own code paths
    await page.evaluate(id => window.choose(id), c.id);
    await page.waitForFunction(() => window.PRED && !window.PRED.err, { timeout: 15000 });
    await page.evaluate(([y, m, d]) => {
      window.DAY = { y: y, m: m, d: d, jd0: TIDE.jdate(y, m, d) };
      window.rebuild();
    }, [c.y, c.m, c.d]);
    await page.waitForTimeout(60);

    const shown = await page.$$eval('#hl-body tr', rows => rows.map(r => ({
      k: r.children[0].textContent === 'HIGH' ? 'H' : 'L',
      t: r.children[1].textContent.trim(),
      h: r.children[2].textContent.replace(' m', '').trim()
    })));
    const want = awkTable(awkDay(c.id, c.y, c.m, c.d));

    const same = JSON.stringify(shown) === JSON.stringify(want);
    const date = c.y + '-' + String(c.m).padStart(2, '0') + '-' + String(c.d).padStart(2, '0');
    console.log((same ? '  ok   ' : '  FAIL ') + date + '  ' + c.name +
                '  (' + want.length + ' turns)');
    if (!same) {
      bad++;
      console.log('    page: ' + JSON.stringify(shown));
      console.log('    awk:  ' + JSON.stringify(want));
    }

    // the station banner must name the station the engine actually used
    const nm = await page.textContent('#st-name');
    const awkNm = awkDay(c.id, c.y, c.m, c.d).split('\n').map(x => x.trim()).filter(Boolean)[0];
    if (nm.trim() !== awkNm) { bad++; console.log('    FAIL name: page "' + nm + '" vs awk "' + awkNm + '"'); }
  }

  // ---- the terminal picture, against the awk's own grid --------------
  // A date that is not today, so neither side draws the now marker.
  await page.evaluate(id => window.choose(id), 'noaa/8452660');
  await page.waitForFunction(() => window.PRED && !window.PRED.err);
  await page.evaluate(() => {
    window.DAY = { y: 2027, m: 3, d: 15, jd0: TIDE.jdate(2027, 3, 15) };
    window.rebuild();
  });
  const termJs = await page.textContent('#term');
  const termAwk = awkDay('noaa/8452660', 2027, 3, 15);
  function grid(t) {
    const L = t.split('\n');
    const i = L.findIndex(l => /^\s{2}0?0\s{5,}03/.test(l));
    return i < 0 ? null : L.slice(i - 15, i + 1).map(l => l.replace(/\s+$/, '')).join('\n');
  }
  const gj = grid(termJs), ga = grid(termAwk);
  if (gj && ga && gj === ga) console.log('  ok   terminal picture matches the awk grid character for character');
  else {
    bad++;
    console.log('  FAIL terminal picture differs');
    if (gj && ga) {
      const a = gj.split('\n'), b = ga.split('\n');
      for (let i = 0; i < Math.max(a.length, b.length); i++)
        if (a[i] !== b[i]) { console.log('    js  |' + a[i] + '|'); console.log('    awk |' + b[i] + '|'); }
    } else console.log('    could not locate the grid: js=' + !!gj + ' awk=' + !!ga);
  }

  // ---- depth and clearance ------------------------------------------
  await page.fill('#i-charted', '2.4');
  await page.fill('#i-draft', '1.8');
  await page.fill('#i-clear', '0.5');
  await page.waitForTimeout(120);
  const depth = await page.textContent('#depth-out');
  console.log('  depth panel: ' + depth.replace(/\s+/g, ' ').slice(0, 150));
  await page.fill('#i-air', '18.0');
  await page.fill('#i-mast', '16.5');
  await page.waitForTimeout(120);
  const air = await page.textContent('#depth-out');
  if (!/clear/i.test(air)) { bad++; console.log('  FAIL bridge clearance produced nothing'); }
  else console.log('  ok   bridge clearance renders');

  // ---- the canvas actually drew something ---------------------------
  const painted = await page.evaluate(() => {
    const c = document.getElementById('curve');
    const g = c.getContext('2d');
    const d = g.getImageData(0, 0, c.width, c.height).data;
    let on = 0;
    for (let i = 3; i < d.length; i += 4) if (d[i] > 8) on++;
    return { w: c.width, h: c.height, lit: on, frac: on / (c.width * c.height) };
  });
  console.log('  canvas ' + painted.w + 'x' + painted.h + ', ' +
              (painted.frac * 100).toFixed(1) + '% of pixels painted');
  if (painted.frac < 0.05) { bad++; console.log('  FAIL the curve canvas is essentially blank'); }

  // ---- nothing overflows sideways at phone width --------------------
  for (const w of [744, 390, 320]) {
    await page.setViewportSize({ width: w, height: 900 });
    await page.waitForTimeout(150);
    const over = await page.evaluate(() => ({
      doc: document.documentElement.scrollWidth,
      win: window.innerWidth
    }));
    const ok = over.doc <= over.win + 1;
    console.log((ok ? '  ok   ' : '  FAIL ') + 'no sideways scroll at ' + w +
                'px (content ' + over.doc + ', window ' + over.win + ')');
    if (!ok) bad++;
  }

  await page.setViewportSize({ width: 744, height: 1133 });
  await page.waitForTimeout(200);
  await page.screenshot({ path: 'shot-day.png', fullPage: true });
  await page.evaluate(() => window.go('pick'));
  await page.fill('#q', 'lon new');
  await page.waitForTimeout(300);
  const hits = await page.$$eval('#results .row b', e => e.map(x => x.textContent));
  console.log('  search "lon new" -> ' + JSON.stringify(hits.slice(0, 3)));
  await page.screenshot({ path: 'shot-pick.png', fullPage: true });

  console.log('');
  if (errs.length) { console.log('CONSOLE ERRORS (' + errs.length + '):'); errs.slice(0, 10).forEach(e => console.log('  ' + e)); bad += errs.length; }
  else console.log('no console errors');
  console.log(bad ? bad + ' FAILURES' : 'all checks passed');
  await browser.close();
  process.exit(bad ? 1 : 0);
})();
