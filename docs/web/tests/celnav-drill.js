/*  The drills, as the PAGE shows them, against what the shell PRINTS.

    The GENERATOR is held to the awk seed for seed by drill-check.js, with
    no browser: same problem, same body, same numbers. This is the other
    half - the question as it is put, and the MARKING.

    The marking is the part worth checking here, because the tolerances
    are the drill: half a mile on an intercept, 0.3' on an Ho, 0.6 degrees
    on a Zn in the reduction drill and 1.0 in the full one. A drill that
    marks to a different standard than the tool is a different drill, and
    nothing about the numbers on screen would show it.

    So each kind is marked TWICE: once with the shell's own correct answer,
    which has to come back CORRECT, and once with an answer placed just
    outside the shell's tolerance, which has to come back wrong. The second
    is what catches a tolerance that has been widened, and a tolerance that
    has been widened is the one fault a drill cannot survive.

      node celnav-drill.js <seed> q-corr.txt m-corr.txt q-alm.txt m-alm.txt ...  */
'use strict';
const fs = require('fs');
const { chromium } = require('playwright');

const argv = process.argv.slice(2);
const SEED = argv[0];
const files = argv.slice(1);
const BASE = 'http://127.0.0.1:' + (process.env.PORT || 8731) + '/celnav/';

const canon = s => String(s)
  .replace(/(\d)([NSEW])/g, '$1 $2')
  .replace(/[\u2212\u2013\u2014]/g, '-')
  .replace(/[\u00b0]/g, ' ').replace(/[\u2032']/g, ' ')
  .replace(/^([NSEW])\s*(.*)$/, '$2 $1')
  .replace(/^(.*?[\d.])\s*([NSEW])\s*$/, '$1 $2')
  .trim().replace(/\s+/g, ' ');

let checks = 0, bad = 0;
function eq(what, got, want) {
  checks++;
  if (got === undefined || want === undefined || canon(got) !== canon(want)) {
    bad++;
    if (bad <= 25)
      console.log('  FAIL ' + what + '\n        shell ' + JSON.stringify(want) +
                  '\n        page  ' + JSON.stringify(got));
  }
}
function yes(what, cond, why) {
  checks++;
  if (!cond) { bad++; if (bad <= 25) console.log('  FAIL ' + what + ': ' + why); }
}
const num = (t, re) => { const m = re.exec(t); return m ? m[1] : undefined; };

/*  the correct answer, and one just outside the tolerance, read out of the
    shell's own marking output - which prints the right values whatever
    answer it was given  */
function answers(kind, m) {
  switch (kind) {
    case 'corr': {
      const ho = num(m, /correct Ho is (\d+ [\d.]+)'/i);
      return { right: [ho], wrong: [bump(ho, 0.5)] };      /* tol 0.3' */
    }
    case 'alm': {
      const gha = num(m, /GHA (\d+ [\d.]+)'/);
      const dec = num(m, /Dec ([NS]\d+ [\d.]+)'/);
      return { right: [gha, hemi(dec)], wrong: [bump(gha, 1.4), hemi(dec)] };  /* 1.0' */
    }
    case 'red': {
      const hc = num(m, /Hc = (\d+ [\d.]+)'/);
      const zn = num(m, /Zn = ([\d.]+) T/);
      return { right: [hc, zn], wrong: [hc, String(+zn + 1.2)] };              /* 0.6 deg */
    }
    case 'int': {
      const nm = num(m, /= ([\d.]+) nm (?:TOWARD|AWAY)/);
      const away = /nm AWAY/.test(m);
      const v = (away ? -1 : 1) * +nm;
      //  flipped is the third answer: the right distance, plotted the
      //  wrong way, which is the mistake the drill exists to catch
      return { right: [String(v)], wrong: [String(v + (away ? -0.8 : 0.8))],
               flipped: [String(-v)] };                                   /* 0.5 nm */
    }
    case 'full': {
      const nm = num(m, /Intercept = Ho - Hc = ([\d.]+) nm (?:TOWARD|AWAY)/);
      const away = /Intercept = Ho - Hc = [\d.]+ nm AWAY/.test(m);
      const zn = num(m, /Zn ([\d.]+) T/);
      const v = (away ? -1 : 1) * +nm;
      return { right: [String(v), zn], wrong: [String(v), String(+zn + 1.4)],
               flipped: [String(-v), zn] };                               /* 1.0 deg */
    }
    case 'fix': {
      const la = num(m, /Fix\s+(\d+ [\d.]+'[NS])/);
      const lo = num(m, /Fix\s+\d+ [\d.]+'[NS]\s+(\d+ [\d.]+'[EW])/);
      //  three miles out, against a two-mile tolerance
      return { right: [hemi2(la), hemi2(lo)], wrong: [bumpLat(la, 3.0), hemi2(lo)] };
    }
  }
}
//  "66 45.7" plus n minutes
function bump(dm, n) {
  const m = /(\d+) ([\d.]+)/.exec(dm);
  let d = +m[1], mi = +m[2] + n;
  if (mi >= 60) { mi -= 60; d += 1; }
  return d + ' ' + mi.toFixed(1);
}
const hemi = s => s.replace(/^([NS])(.*)$/, '$2 $1');       /* N08 10.0 -> 08 10.0 N */
const hemi2 = s => s.replace(/'/g, '');
function bumpLat(s, n) {
  const m = /(\d+) ([\d.]+)'?([NS])/.exec(s);
  let d = +m[1], mi = +m[2] + n;
  if (mi >= 60) { mi -= 60; d += 1; }
  return d + ' ' + mi.toFixed(1) + ' ' + m[3];
}

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 900, height: 1800 }, timezoneId: 'UTC' });
  const errs = [];
  page.on('pageerror', e => errs.push(String(e)));
  await page.goto(BASE + 'index.html', { waitUntil: 'load', timeout: 20000 });
  await page.click('[data-go="drill"]');
  await page.waitForTimeout(300);

  const KINDS = ['corr', 'alm', 'red', 'int', 'full', 'fix'];
  for (let i = 0; i < KINDS.length; i++) {
    const kind = KINDS[i];
    const q = fs.readFileSync(files[i * 2], 'utf8');
    const m = fs.readFileSync(files[i * 2 + 1], 'utf8');

    await page.selectOption('#d-kind', kind);
    await page.fill('#d-seed', SEED);
    await page.dispatchEvent('#d-seed', 'change');
    await page.waitForTimeout(250);

    /* ---- the question ------------------------------------------- */
    const kv = await page.evaluate(() => {
      const o = {};
      document.querySelectorAll('#d-q table.kv tr').forEach(tr => {
        const th = tr.querySelector('th'), td = tr.querySelector('td');
        if (th && td) o[th.textContent.trim()] = td.textContent.trim();
      });
      o.__rows = Array.from(document.querySelectorAll('#d-q table.ct-tab tr')).slice(1)
                   .map(tr => Array.from(tr.querySelectorAll('td')).map(td => td.textContent.trim()));
      return o;
    });
    if (kind === 'corr' || kind === 'full')
      eq(kind + ' Hs', kv['Sextant reading Hs'].split('\u2003')[0],
         num(q, /Sextant reading Hs\s+(\d+ [\d.]+')/));
    if (kind === 'alm' || kind === 'full')
      yes(kind + ' UT', JSON.stringify(kv).indexOf(num(q, /(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d)/)) >= 0,
          'the page does not show the shell\'s UT');
    if (kind === 'red') {
      eq('red GHA', kv['GHA of the body'], num(q, /GHA of the body\s+(\d+ [\d.]+')/));
      eq('red declination', kv['Declination'], num(q, /Declination\s+([NS]\d+ [\d.]+')/));
    }
    if (kind === 'int') {
      eq('int Ho', kv['Observed altitude Ho'], num(q, /Observed altitude Ho\s+(\d+ [\d.]+')/));
      eq('int Hc', kv['Computed altitude Hc'], num(q, /Computed altitude Hc\s+(\d+ [\d.]+')/));
      eq('int Zn', kv['Azimuth Zn'], num(q, /Azimuth Zn\s+(\d+ T)/));
    }
    if (kind === 'fix') {
      const shRows = q.split('\n')
        .map(l => /^\s+(\S[^\s]*(?: \S+)?)\s+(\d{3}) T\s+([\d.]+) nm (toward|away)\s*$/.exec(l))
        .filter(Boolean)
        .map(x => [x[1], x[2] + ' T', x[3] + ' nm ' + x[4]]);
      eq('fix sight table', JSON.stringify(kv.__rows), JSON.stringify(shRows));
    }

    /* ---- marked right, then marked wrong ------------------------ */
    const A = answers(kind, m);
    const fill = async vals => {
      for (let j = 0; j < vals.length; j++) await page.fill('#d-a' + (j + 1), String(vals[j]));
      await page.click('#d-mark');
      await page.waitForTimeout(250);
      return page.evaluate(() => ({
        verdict: (document.querySelector('#d-out h3') || {}).textContent || '',
        note: document.getElementById('d-note').textContent,
        text: document.getElementById('d-out').textContent
      }));
    };

    let r = await fill(A.right);
    yes(kind + ' marks the shell\'s own answer correct',
        /Correct\./.test(r.verdict), 'got ' + JSON.stringify(r.verdict + ' ' + r.note));
    //  the working shown beside it has to be the shell's working
    if (kind === 'corr')
      eq('corr Ho in the chain', num(r.text, /Ho\s+observed altitude\s*(\d+\D+[\d.]+')/),
         num(m, /correct Ho is (\d+ [\d.]+)'/i) + "'");
    if (kind === 'fix')
      eq('fix position', num(r.text, /Fix(\d+\D+[\d.]+'\s*[NS])/),
         num(m, /Fix\s+(\d+ [\d.]+'[NS])/));

    r = await fill(A.wrong);
    yes(kind + ' refuses an answer outside the tolerance',
        /Not right\./.test(r.verdict),
        'an answer the shell calls wrong was marked ' + JSON.stringify(r.verdict));

    //  THE RIGHT DISTANCE, PLOTTED THE WRONG WAY. "Computed greater, away"
    //  is the rule a navigator gets backwards, and an intercept with the
    //  sign reversed is the same number of miles on the wrong side of the
    //  assumed position - a fix twice the intercept out, with nothing on
    //  the sheet to say so. The shell checks the sign; so must this.
    if (A.flipped) {
      r = await fill(A.flipped);
      yes(kind + ' refuses the right distance plotted the wrong way',
          /Not right\./.test(r.verdict),
          'an intercept with the sign reversed was marked ' + JSON.stringify(r.verdict));
    }
  }

  if (errs.length) { bad++; console.log('  FAIL page errors: ' + errs.join(' | ')); }
  await browser.close();
  console.log('    ' + checks + ' checks over six kinds of drill' + (bad ? '' : ', all agree'));
  if (bad) { console.log('    ' + bad + ' FAILED'); process.exit(1); }
})().catch(e => { console.error(e); process.exit(2); });
