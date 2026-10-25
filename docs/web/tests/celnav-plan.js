/*  Sight planning and the compass check, as the PAGE shows them, against
    what the shell PRINTS.

    The planner's *selection* is already held to the awk's own choice by
    name, over 400 generated cases, in celnav-diff.js - plan_sky() is one
    function shared by the shell and the browser, and that is where the
    arithmetic is proved. What is checked here is everything the screen
    adds on top of it and the engine knows nothing about:

      - the twilight table, which is six find_cross() calls and two
        different clocks, and where a UT/LMT swap is invisible to a module
        diff and obvious in the row
      - the moon's illumination and phase
      - which of the four things the screen says about the horizon
      - that the table on the page is the table the shell printed, row for
        row, in the same order
      - the compass check entire, which has no engine function of its own:
        the error, the variation and the deviation are three subtractions
        and a sign, and a sign is exactly what a port gets backwards

      node celnav-plan.js plan.txt compass.txt compass-plain.txt  */
'use strict';
const fs = require('fs');
const { chromium } = require('playwright');

const [planFile, compFile, compPlainFile] = process.argv.slice(2);
const BASE = 'http://127.0.0.1:' + (process.env.PORT || 8731) + '/celnav/';

/*  the case, fixed here and in the shell commands that feed it  */
const CASE = {
  lat: '41 49.0 N', lon: '071 24.0 W', date: '2026-08-29',
  ptime: '23:30:00',
  ctime: '10:15:00', body: 'Sun', brg: '118.5', vr: '-14.0'
};

const canon = s => String(s)
  .replace(/[−–—]/g, '-')
  .replace(/[°]/g, ' ').replace(/[′']/g, ' ')
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
function shellVal(txt, label) {
  const m = new RegExp('^\\s+' + label + '\\s{2,}(.+?)\\s*$', 'm').exec(txt);
  return m ? m[1].replace(/\s{3,}\(.*$/, '').trim() : undefined;
}
function shellNum(txt, re) { const m = re.exec(txt); return m ? m[1] : undefined; }

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 900, height: 1600 }, timezoneId: 'UTC' });
  const errs = [];
  page.on('pageerror', e => errs.push(String(e)));
  await page.goto(BASE + 'index.html', { waitUntil: 'load', timeout: 20000 });

  const kv = sel => page.evaluate(s => {
    const out = {};
    document.querySelectorAll(s + ' table.kv tr').forEach(tr => {
      const th = tr.querySelector('th'), td = tr.querySelector('td');
      if (th && td) out[th.textContent.replace(/\s+/g, ' ').trim()] = td.textContent.trim();
    });
    out.__prose = Array.from(document.querySelectorAll(s + ' p')).map(p => p.textContent).join(' ');
    out.__head = (document.querySelector(s + ' h3') || {}).textContent || '';
    return out;
  }, sel);

  /* ================= sight planning ================================ */
  await page.click('[data-go="plan"]');
  await page.fill('#pl-lat', CASE.lat);
  await page.fill('#pl-lon', CASE.lon);
  await page.fill('#pl-date', CASE.date);
  await page.fill('#pl-time', CASE.ptime);
  await page.click('#pl-go');
  await page.waitForTimeout(500);
  const sh = fs.readFileSync(planFile, 'utf8');

  //  the twilight table: three labels x two columns, each "HH:MM / HH:MM"
  const tw = await page.evaluate(() => {
    const o = {};
    document.querySelectorAll('#pl-out table.ct-tab tr').forEach(tr => {
      const td = tr.querySelectorAll('td');
      if (td.length === 3) o[td[0].textContent.trim()] = [td[1].textContent.trim(), td[2].textContent.trim()];
    });
    return o;
  });
  //  the shell writes "  Sunrise/set  10:08 / 05:22        23:23 / 18:38"
  [['Sunrise/set', 'Sunrise / set'], ['Civil twi', 'Civil twilight'], ['Nautical', 'Nautical']]
    .forEach(([sLab, pLab]) => {
      const m = new RegExp('^\\s+' + sLab + '\\s{2,}(\\S+ / \\S+|\\s*--)\\s+(\\S+ / \\S+|\\s*--)', 'm').exec(sh);
      const want = m ? [m[1].trim(), m[2].trim()] : [undefined, undefined];
      eq('twilight ' + pLab + ' morning', (tw[pLab] || [])[0], want[0]);
      eq('twilight ' + pLab + ' evening', (tw[pLab] || [])[1], want[1]);
    });

  const panel = await page.evaluate(() => ({
    out: document.getElementById('pl-out').textContent,
    list: document.getElementById('pl-list').textContent,
    sky: document.getElementById('pl-sky').textContent
  }));
  eq('moon illumination', shellNum(panel.out, /Moon (\d+)% illuminated/),
     shellNum(sh, /Moon (\d+)% illuminated/));
  eq('moon phase', shellNum(panel.out, /illuminated, ([a-z \-]+)\./),
     shellNum(sh, /illuminated, (.+)$/m));
  //  WHICH of the four horizon verdicts, not the wording of it
  const verdict = t => /sun is above the horizon/i.test(t) ? 'day'
                     : /Civil twilight/.test(t) ? 'civil'
                     : /Nautical twilight/.test(t) ? 'nautical'
                     : /[Ff]ull night/.test(t) ? 'night' : '?';
  eq('horizon verdict', verdict(panel.out), verdict(sh));

  //  the body table, row for row and in order
  const rows = await page.evaluate(() => Array.from(
    document.querySelectorAll('#pl-list table.ct-tab tr')).slice(1).map(tr =>
      Array.from(tr.querySelectorAll('td')).map(td => td.textContent.trim())));
  const shRows = [];
  for (const line of sh.split('\n')) {
    const m = /^  (\S.{0,15})\s+(-?\d+\.\d)\s+(\d+\.\d)\s+(-?\d+\.\d)\s*(.*)$/.exec(line);
    if (m && !/BODY/.test(line)) shRows.push([m[1].trim(), m[2], m[3], m[4], m[5].trim()]);
  }
  eq('table length', String(rows.length), String(shRows.length));
  for (let i = 0; i < Math.min(rows.length, shRows.length); i++) {
    eq('row ' + (i + 1) + ' name', rows[i][0], shRows[i][0]);
    eq('row ' + (i + 1) + ' alt',  rows[i][1], shRows[i][1]);
    eq('row ' + (i + 1) + ' Zn',   rows[i][2], shRows[i][2]);
    eq('row ' + (i + 1) + ' mag',  rows[i][3], shRows[i][3]);
    eq('row ' + (i + 1) + ' note', rows[i][4], shRows[i][4]);
  }

  //  the recommendation, and the spread it was chosen for
  eq('azimuth spread', shellNum(panel.list, /(\d+)° of azimuth spread/),
     shellNum(sh, /azimuth spread (\d+) deg minimum/));
  for (let n = 1; n <= 3; n++) {
    const m = new RegExp('^\\s+' + n + '\\s+(\\S[^\\s]*(?: \\S+)?)\\s+alt\\s+(-?[\\d.]+)\\s+Zn\\s+([\\d.]+)', 'm').exec(sh);
    const want = m ? m : null;
    const pm = new RegExp(n + '\\s*([A-Za-z][A-Za-z ]*?)\\s*alt ([\\d.]+)\\u00b0\\s*Zn ([\\d.]+)').exec(panel.list);
    eq('pick ' + n + ' name', pm ? pm[1].trim() : undefined, want ? want[1].trim() : undefined);
    eq('pick ' + n + ' alt',  pm ? pm[2] : undefined, want ? want[2] : undefined);
    eq('pick ' + n + ' Zn',   pm ? pm[3] : undefined, want ? want[3] : undefined);
  }
  //  THE DRAWING AND THE TABLE HAVE TO NAME THE SAME THREE. The sky view
  //  takes its indices from the same rows array, so a drawing that marks
  //  a different three means the two readers of plan.best disagree.
  const skyNames = await page.evaluate(() => Array.from(
    document.querySelectorAll('#pl-sky svg text')).map(t => t.textContent)
      .filter(t => t.length > 1));
  for (let n = 1; n <= 3; n++) {
    const m = new RegExp('^\\s+' + n + '\\s+(\\S[^\\s]*(?: \\S+)?)\\s+alt', 'm').exec(sh);
    checks++;
    if (!m || skyNames.indexOf(m[1].trim()) < 0) {
      bad++;
      console.log('  FAIL the sky view does not label ' + (m ? m[1].trim() : '?') +
                  '; it labels ' + JSON.stringify(skyNames));
    }
  }

  /* ================= the compass check ============================= */
  await page.click('#nav-back');
  await page.click('[data-go="compass"]');
  await page.fill('#c-lat', CASE.lat);
  await page.fill('#c-lon', CASE.lon);
  await page.fill('#c-date', CASE.date);
  await page.fill('#c-time', CASE.ctime);
  await page.fill('#c-body', CASE.body);
  await page.fill('#c-brg', '');
  await page.fill('#c-var', '');
  await page.click('#c-go');
  await page.waitForTimeout(300);
  let cs = fs.readFileSync(compPlainFile, 'utf8');
  let pg = await kv('#c-out');
  eq('compass azimuth alone', pg['True azimuth of Sun'],
     shellNum(cs, /Zn\s+(-?[\d.]+) T/) + '° T');
  eq('compass altitude alone', pg['Altitude then'],
     shellNum(cs, /\(altitude (-?[\d.]+)\)/) + '°');
  eq('amplitude alone', pg['Amplitude (body on the horizon)'],
     shellVal(cs, 'Amplitude \\(body on horizon\\)').replace(' deg', '°'));
  //  no bearing given: there is nothing to call an error, and a screen
  //  that invented one would be the worst kind of wrong here
  checks++;
  if (pg['Compass error'] !== undefined) {
    bad++;
    console.log('  FAIL the page shows a compass error with no bearing given');
  }

  await page.fill('#c-brg', CASE.brg);
  await page.fill('#c-var', CASE.vr);
  await page.click('#c-go');
  await page.waitForTimeout(300);
  cs = fs.readFileSync(compFile, 'utf8');
  pg = await kv('#c-out');
  eq('compass azimuth', pg['True azimuth of Sun'], shellNum(cs, /Zn\s+(-?[\d.]+) T/) + '° T');
  eq('compass bearing', pg['Compass bearing observed'],
     shellNum(cs, /Compass bearing observed\s+([\d.]+) C/) + '° C');
  eq('compass error', pg['Compass error'],
     shellVal(cs, 'Compass error').replace(/^([\d.]+)\s+/, '$1° '));
  eq('variation', pg['Variation (chart)'],
     shellVal(cs, 'Variation \\(chart\\)').replace(/^([\d.]+)\s+/, '$1° '));
  eq('deviation', pg['Deviation of this compass'],
     shellVal(cs, 'Deviation of this compass').replace(/^([\d.]+)\s+/, '$1° '));
  //  the shell's note about a high body, and the page's, have to appear
  //  and disappear together
  eq('high-body caution', /most reliable below about 20/.test(pg.__prose) ? 'yes' : 'no',
     /most reliable with the body below about 20/.test(cs) ? 'yes' : 'no');

  if (errs.length) { bad++; console.log('  FAIL page errors: ' + errs.join(' | ')); }
  await browser.close();
  console.log('    ' + checks + ' checks' + (bad ? '' : ', all agree'));
  if (bad) { console.log('    ' + bad + ' FAILED'); process.exit(1); }
})().catch(e => { console.error(e); process.exit(2); });
