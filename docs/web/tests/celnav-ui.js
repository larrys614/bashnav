/*  What the celnav page SHOWS, against what the awk tool PRINTS.

    celnav-diff.js holds the browser's arithmetic to the awk's at full
    precision, and that is the stage that proves the navigation.  It
    cannot see a wiring or formatting fault, and this build had one of
    each: the fix read "35 010.0' N" because the minutes were zero-padded
    from the value before toFixed() rounded 9.956 to "10.0", and the pad
    is invisible to any check that parses the number back out again.  So
    this stage compares the rendered STRINGS for anything a navigator
    copies onto a chart, and numbers only where the shell itself prints a
    rounded number.

    Reference: the awk tool's own stdout for the same sights and the same
    DR.  Nothing here is a value somebody typed.

      node celnav-ui.js sights.txt shell.txt "35 00 N" "040 00 W" 0 0   */
'use strict';
const fs = require('fs'), path = require('path');
const { chromium } = require('playwright');

const [sfile, outfile, drlat, drlon, speed, course] = process.argv.slice(2);
const PORT = process.env.PORT || 8731;
const BASE = 'http://127.0.0.1:' + PORT + '/celnav/';

/*  one spelling for an angle, so "35 10.3'N", "35° 10.3' N" and
    "35 010.3' N" are three different strings and only the first two are
    the same angle.  The pad is the whole point: it must survive.  */
const canon = s => String(s)
  .replace(/°/g, ' ').replace(/[′']/g, ' ')
  .replace(/([NSEW])\s*$/, ' $1')
  .trim().replace(/\s+/g, ' ');
const LIMBS = { C: 'centre', L: 'lower', U: 'upper' };

/* ---- the sights, in the shell's own file format ------------------- */
const sights = fs.readFileSync(sfile, 'utf8').split('\n')
  .filter(l => l.trim() && !/^\s*#/.test(l))
  .map(l => {
    const f = l.split('|');
    return { utc: f[0], body: f[1], limb: (f[2] || 'C').toUpperCase(), hs: f[3],
             ie: f[4] || '0', he: f[5] || '2.5', tm: f[6] || '10', pr: f[7] || '1010' };
  });

/* ---- the shell's printed working ---------------------------------- */
const shell = fs.readFileSync(outfile, 'utf8').split('\n');
const ref = { sights: [] };
let cur = null;
for (const line of shell) {
  let m;
  if ((m = /^\s+Sight [a-z]:\s+(.+?)\s{2,}/.exec(line))) {
    cur = { body: m[1].trim() }; ref.sights.push(cur); continue;
  }
  if (cur) {
    if ((m = /Hs\s+(-?\d+ [\d.]+')/.exec(line))) cur.hs = canon(m[1]);
    if ((m = /Hc\s+(-?\d+ [\d.]+')/.exec(line))) cur.hc = canon(m[1]);
    if ((m = /Zn\s+(\d+ [\d.]+')/.exec(line))) {
      const p = m[1].replace("'", '').split(' ');
      cur.zn = Math.round(+p[0] + +p[1] / 60) % 360;
    }
    if ((m = /Intercept\s+([\d.]+) nm (TOWARD|AWAY)/.exec(line)))
      cur.int = (m[2] === 'AWAY' ? -1 : 1) * +m[1];
  }
  if ((m = /^\s+FIX\s+(\d+ [\d.]+'[NS])\s+(\d+ [\d.]+'[EW])/.exec(line))) {
    ref.lat = canon(m[1]); ref.lon = canon(m[2]);
  }
  if ((m = /Offset from DR:\s+([\d.]+) nm ([NS]),\s+([\d.]+) nm ([EW])/.exec(line))) {
    ref.N = (m[2] === 'S' ? -1 : 1) * +m[1];
    ref.E = (m[4] === 'W' ? -1 : 1) * +m[3];
  }
}

let checks = 0, bad = 0;

/*  A STRING CHECK THAT CANNOT FAIL IS NOT A CHECK, and my first two
    attempts at this one could not.  The zero-pad bug fires in ONE narrow
    window: minutes of arc in [9.95, 10), which print as "10.0" but are
    below 10 before the rounding, so a pad decided from the value puts a
    third digit in front - "010.0".  At 01.3' the buggy code is right, and
    at 10.3' it is right, so a scenario without that window passes with the
    fault planted.  I planted it twice and watched it pass twice.
    Two things here, therefore:
      wide()   a property - no rendered angle may carry three digits of
               minutes, whatever the scenario
      carry    proof the scenario reaches the window at all, read off the
               INPUT sights where it is knowable, rather than off the
               output where "10.0" is "10.0" either way                  */
let wide3 = 0;
function wide(what, str) {
  const m = /^-?\d+ (\d\d\d+)\./.exec(String(str).trim());
  if (!m) return;
  wide3++;
  bad++;
  console.log('  FAIL ' + what + ' shows ' + JSON.stringify(str) +
              '\n        three digits of minutes - the pad was decided from the' +
              '\n        value instead of from the rounded string');
}
const carry = sights.filter(s => {
  const m = /(\d+(?:\.\d+)?)[^\d]*$/.exec(String(s.hs).trim());
  if (!m) return false;
  const v = parseFloat(m[1]) % 60;
  return v >= 9.95 && v < 10;
}).length;
function eq(what, got, want) {
  checks++;
  wide(what, got);
  if (got !== want) {
    bad++;
    console.log('  FAIL ' + what + '\n        awk shows  ' + JSON.stringify(want) +
                '\n        page shows ' + JSON.stringify(got));
  }
}
function near(what, got, want, tol) {
  checks++;
  if (!(Math.abs(got - want) <= tol)) {
    bad++;
    console.log('  FAIL ' + what + '\n        awk ' + want + '\n        page ' + got);
  }
}

(async () => {
  const b = await chromium.launch();
  const p = await b.newPage();
  const errs = [];
  p.on('pageerror', e => errs.push(String(e)));
  await p.goto(BASE);
  await p.waitForTimeout(400);

  /*  start from an empty sight list however the last run left it: the
      sights live in localStorage, and a harness that inherits them is a
      harness whose result depends on what ran before it.  */
  await p.evaluate(() => { window.CELPLOT.clear(); });
  /*  the page routes with go(), not with the hash: the views are
      sections toggled by hidden, and playwright will not fill an input
      inside a hidden one.  */
  await p.click('[data-go="sight"]');
  await p.waitForTimeout(300);

  for (const s of sights) {
    const [d, t] = s.utc.split(' ');
    await p.fill('#s-date', d);
    await p.fill('#s-time', t);
    await p.fill('#s-body', s.body);
    await p.fill('#s-hs', s.hs);
    await p.fill('#s-ie', s.ie);
    await p.fill('#s-he', s.he);
    await p.fill('#s-tm', s.tm);
    await p.fill('#s-pr', s.pr);
    await p.selectOption('#s-limb', s.limb).catch(() => {});
    await p.click('#s-add');
    await p.waitForTimeout(80);
  }
  await p.fill('#s-alat', drlat);
  await p.fill('#s-alon', drlon);
  await p.fill('#s-spd', String(speed));
  await p.fill('#s-crs', String(course));
  await p.dispatchEvent('#s-crs', 'change');
  await p.waitForTimeout(400);

  const rows = await p.$$eval('#s-list table tr', trs =>
    trs.slice(1).map(tr => Array.from(tr.querySelectorAll('td')).map(td => td.textContent)));
  const fix = await p.$$eval('#s-fix table tr', trs =>
    trs.map(tr => [tr.querySelector('th').textContent, tr.querySelector('td').textContent]));
  const sheet = await p.$eval('#s-sheet', e => e.querySelectorAll('*').length);
  await b.close();

  checks++;
  if (errs.length) { bad++; console.log('  FAIL the page threw: ' + errs[0]); }

  eq('sight count on the page', rows.length, ref.sights.length);
  ref.sights.forEach((r, i) => {
    const row = rows[i];
    if (!row) return;
    eq('sight ' + (i + 1) + ' Hs', canon(row[2]), r.hs);
    eq('sight ' + (i + 1) + ' Hc', canon(row[3]), r.hc);
    eq('sight ' + (i + 1) + ' Zn', +row[4] % 360, r.zn);
    const m = /([\d.]+) nm (TOWARD|AWAY)/.exec(row[5]) || [0, '0', 'TOWARD'];
    near('sight ' + (i + 1) + ' intercept',
         (m[2] === 'AWAY' ? -1 : 1) * +m[1], r.int, 0.051);
  });

  const F = {};
  fix.forEach(([k, v]) => { F[k.trim()] = v; });
  if (ref.lat !== undefined) {
    const parts = (F['FIX'] || '').trim().split(/\s{2,}/);
    eq('FIX latitude', canon(parts[0] || ''), ref.lat);
    eq('FIX longitude', canon(parts[1] || ''), ref.lon);
    const o = /([\d.]+) nm ([NS]), ([\d.]+) nm ([EW])/.exec(F['from the AP'] || '');
    checks++;
    if (!o) { bad++; console.log('  FAIL the offset from the AP is not shown'); }
    else {
      near('offset N', (o[2] === 'S' ? -1 : 1) * +o[1], ref.N, 0.051);
      near('offset E', (o[4] === 'W' ? -1 : 1) * +o[3], ref.E, 0.051);
    }
    checks++;
    if (sheet < 10) { bad++; console.log('  FAIL the plotting sheet drew ' + sheet + ' elements'); }
  }

  checks++;
  if (!carry) {
    bad++;
    console.log('  FAIL no sight in this scenario has minutes in [9.95, 10), so\n' +
                '       the zero-pad\'s only failing window was never reached and\n' +
                '       these string checks could not have failed. Add one.');
  }
  console.log('  ' + checks + ' checks against the awk tool\'s own output' +
              '  (' + carry + ' sight' + (carry === 1 ? '' : 's') +
              ' in the pad\'s failing window)');
  if (bad) { console.log('\n  ' + bad + ' PROBLEMS'); process.exit(1); }
  console.log('  the page agrees with the shell');
})();
