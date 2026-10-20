/*  Does the drawn moon actually show the illuminated fraction the engine
    computed?  The path is taken from the rendered SVG and re-drawn into a
    canvas with Path2D, and the lit pixels inside the disc are counted.
    Checking the path string by eye is how a gibbous moon shipped as a
    crescent in the first place. */
const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch();
  const p = await (await b.newContext({ viewport: { width: 744, height: 1133 } })).newPage();
  const errs = [];
  p.on('pageerror', e => errs.push(e.message));
  await p.goto('http://127.0.0.1:8088/tides/', { waitUntil: 'networkidle' });
  await p.waitForFunction(() => window.IDX && window.IDX.n > 0, { timeout: 20000 });
  await p.evaluate(() => window.choose('noaa/8452660'));
  await p.waitForFunction(() => window.PRED && !window.PRED.err);

  const res = await p.evaluate(() => {
    const out = [];
    // a whole lunation, every two days
    for (let k = 0; k < 15; k++) {
      const jd = TIDE.jdate(2026, 1, 1) + k * 2;
      const ph = TIDE.moonPhase(jd + 0.5);
      document.getElementById('moonart').innerHTML = window.moonArt(ph.illum, ph.elong);
      const path = document.querySelector('#moonart path');
      const d = path.getAttribute('d');
      const svg = document.querySelector('#moonart svg');
      const S = +svg.getAttribute('width');
      const cv = document.createElement('canvas');
      cv.width = cv.height = S;
      const g = cv.getContext('2d');
      g.fillStyle = '#fff';
      g.fill(new Path2D(d));
      const img = g.getImageData(0, 0, S, S).data;
      const c = S / 2, R = c - 2;
      let lit = 0, disc = 0;
      for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
        const dx = x + 0.5 - c, dy = y + 0.5 - c;
        if (dx * dx + dy * dy > R * R) continue;
        disc++;
        if (img[(y * S + x) * 4 + 3] > 128) lit++;
      }
      out.push({ elong: ph.elong, name: ph.name, want: ph.illum, got: lit / disc });
    }
    return out;
  });

  let bad = 0;
  console.log('  elongation   phase              computed   drawn    diff');
  res.forEach(r => {
    const diff = Math.abs(r.got - r.want);
    // A 46-pixel disc quantises to about 1.5%; anything past 4% is the
    // wrong shape, not rasterisation.
    const ok = diff < 0.04;
    if (!ok) bad++;
    console.log('  ' + r.elong.toFixed(1).padStart(9) + '   ' + r.name.padEnd(17) +
      '  ' + (r.want * 100).toFixed(1).padStart(6) + '%  ' +
      (r.got * 100).toFixed(1).padStart(6) + '%  ' +
      (diff * 100).toFixed(1).padStart(5) + '%' + (ok ? '' : '   <- WRONG SHAPE'));
  });
  if (errs.length) { console.log('page errors: ' + errs.join('; ')); bad++; }
  console.log(bad ? '\n' + bad + ' phases drawn wrong' : '\nevery phase draws the fraction the engine computed');
  await b.close();
  process.exit(bad ? 1 : 0);
})();
