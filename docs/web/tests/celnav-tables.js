/*  The almanac and the star list, as the PAGE shows them, against what the
    shell PRINTS.

    celnav-diff.js holds the browser's arithmetic to the awk's at full
    precision. These two screens need the other kind of check, because
    what can go wrong in them is not the arithmetic:

      - the star list opened at Ankaa. Alpheratz, star 1, was absent and
        the loop ran one past the end, because the awk indexes its star
        arrays from 1 and the port indexes them from 0. Every value in the
        list was right. The list was wrong.
      - a GHA has no hemisphere. Rendered with the function that formats a
        latitude, Aries came out as "091 01.8' E", which is not a thing.

    Neither is visible to a module diff, and both are visible immediately
    in the rendered table.

      node celnav-tables.js almanac.txt stars.txt "2026-08-29 07:34:00" "2026-01-01"  */
'use strict';
const fs = require('fs');
const { chromium } = require('playwright');

const [almFile, starFile, utc, starDate] = process.argv.slice(2);
const BASE = 'http://127.0.0.1:' + (process.env.PORT || 8731) + '/celnav/';

/*  one spelling for an angle. The shell puts the hemisphere in front -
    "N09 18.6'" - and the page puts it after - "09° 18.6' N". Same angle,
    and the check is of the angle, not of which side the letter sits.  */
const canon = s => String(s)
  .replace(/°/g, ' ').replace(/[′']/g, ' ')
  .replace(/^([NSEW])\s*(.*)$/, '$2 $1')
  .replace(/^(.*?)\s*([NSEW])$/, '$1 $2')
  .trim().replace(/\s+/g, ' ');

let checks = 0, bad = 0;
function eq(what, got, want) {
  checks++;
  if (canon(got) !== canon(want)) {
    bad++;
    if (bad <= 20)
      console.log('  FAIL ' + what + '\n        shell ' + JSON.stringify(want) +
                  '\n        page  ' + JSON.stringify(got));
  }
}

/* ---- the shell's almanac ------------------------------------------ */
const alm = { bodies: [] };
let cur = null;
for (const line of fs.readFileSync(almFile, 'utf8').split('\n')) {
  let m;
  if ((m = /\(JD ([\d.]+)\)/.exec(line))) alm.jd = m[1];
  if ((m = /Delta-T used:\s*([\d.]+)/.exec(line))) alm.dt = m[1];
  if ((m = /^\s+Aries\s+(\d+ [\d.]+')/.exec(line))) alm.aries = m[1];
  //  a body row: name, GHA, Dec, SD, HP - SD and HP are "-" when absent
  if ((m = /^\s{2}(\S[^\s].*?)\s{2,}(\d{3} [\d.]+')\s+([NS]\d+ [\d.]+')\s+(\S+)\s+(\S+)\s*$/.exec(line))) {
    cur = { name: m[1].trim(), gha: m[2], dec: m[3], sd: m[4], hp: m[5] };
    alm.bodies.push(cur);
  }
  if ((m = /^\s+SHA (\d+ [\d.]+')\s+mag (-?[\d.]+)/.exec(line)) && cur) {
    cur.sha = m[1]; cur.mag = m[2];
  }
}

/* ---- the shell's star list ----------------------------------------- */
const stars = [];
for (const line of fs.readFileSync(starFile, 'utf8').split('\n')) {
  const m = /^\s+(\d+)\s+(\S.*?)\s{2,}(\d{3} [\d.]+')\s+([NS]\d+ [\d.]+')\s+(-?[\d.]+)\s*$/.exec(line);
  if (m) stars.push({ no: m[1], name: m[2].trim(), sha: m[3], dec: m[4], mag: m[5] });
}

(async () => {
  if (!alm.bodies.length) { console.log('  the shell almanac reference parsed to nothing'); process.exit(2); }
  if (!stars.length) { console.log('  the shell star list parsed to nothing'); process.exit(2); }

  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 900, height: 1200 } });
  const errs = [];
  p.on('pageerror', e => errs.push(String(e)));
  await p.goto(BASE, { timeout: 15000 });
  await p.waitForTimeout(400);

  /* ---- the almanac ------------------------------------------------- */
  const [d, t] = utc.split(' ');
  await p.click('[data-go="almanac"]');
  await p.waitForTimeout(300);
  await p.fill('#a-date', d);
  await p.fill('#a-time', t);
  await p.fill('#a-bodies', alm.bodies.map(x => x.name.toLowerCase()).join(','));
  await p.click('#a-go');
  await p.waitForTimeout(600);

  const page = await p.evaluate(() => {
    const note = document.querySelector('#a-out .note');
    const rows = Array.from(document.querySelectorAll('#a-out table tr')).slice(1)
      .map(tr => Array.from(tr.children).map(c => c.textContent.trim()));
    return { note: note ? note.textContent : '', rows };
  });

  checks++;
  if (page.note.indexOf(alm.jd) < 0) {
    bad++; console.log('  FAIL the julian date\n        shell ' + alm.jd + '\n        page  ' + page.note);
  }
  checks++;
  if (page.note.indexOf(alm.dt) < 0) {
    bad++; console.log('  FAIL delta-T\n        shell ' + alm.dt + '\n        page  ' + page.note);
  }

  const aries = page.rows.find(r => /aries/i.test(r[0]));
  checks++;
  if (!aries) { bad++; console.log('  FAIL the page does not show Aries'); }
  else {
    eq('Aries GHA', aries[1], alm.aries);
    //  and it must NOT have acquired a hemisphere
    checks++;
    if (/[NSEW]\s*$/.test(aries[1].trim())) {
      bad++; console.log('  FAIL Aries GHA carries a hemisphere: ' + JSON.stringify(aries[1]));
    }
  }

  alm.bodies.forEach(ref => {
    const row = page.rows.find(r => r[0].toLowerCase() === ref.name.toLowerCase());
    checks++;
    if (!row) { bad++; console.log('  FAIL the page has no row for ' + ref.name); return; }
    eq(ref.name + ' GHA', row[1], ref.gha);
    eq(ref.name + ' Dec', row[2], ref.dec);
    if (ref.sd !== '-') eq(ref.name + ' SD', row[3], ref.sd);
    if (ref.hp !== '-') eq(ref.name + ' HP', row[4], ref.hp);
    if (ref.sha) {
      const i = page.rows.indexOf(row), sub = page.rows[i + 1] || [];
      eq(ref.name + ' SHA', (sub[1] || '').replace(/^SHA\s*/, ''), ref.sha);
      eq(ref.name + ' mag', (sub[2] || '').replace(/^mag\s*/, ''), ref.mag);
    }
  });

  /* ---- the star list ----------------------------------------------- */
  await p.click('#nav-back');
  await p.waitForTimeout(300);
  await p.click('[data-go="stars"]');
  await p.waitForTimeout(300);
  await p.fill('#st-date', starDate);
  await p.waitForTimeout(700);

  const srows = await p.evaluate(() =>
    Array.from(document.querySelectorAll('#st-out table tr')).slice(1)
      .map(tr => Array.from(tr.children).map(c => c.textContent.trim())));

  checks++;
  if (srows.length !== stars.length) {
    bad++;
    console.log('  FAIL the page lists ' + srows.length + ' stars and the shell lists ' +
                stars.length + (srows.length ? ' - the page starts at ' + srows[0][0] +
                ' ' + srows[0][1] + ' and ends at ' + srows[srows.length-1][0] : ''));
  }
  stars.forEach((ref, i) => {
    const row = srows[i];
    checks++;
    if (!row) { bad++; if (bad <= 20) console.log('  FAIL no row for star ' + ref.no + ' ' + ref.name); return; }
    eq('star ' + ref.no + ' number', row[0], ref.no);
    eq('star ' + ref.no + ' name', row[1], ref.name);
    eq(ref.name + ' SHA', row[2], ref.sha);
    eq(ref.name + ' Dec', row[3], ref.dec);
    eq(ref.name + ' mag', row[4], ref.mag);
  });

  checks++;
  if (errs.length) { bad++; console.log('  FAIL the page threw: ' + errs[0]); }
  await b.close();

  console.log('  ' + checks + ' checks against the shell (' + alm.bodies.length +
              ' bodies, ' + stars.length + ' stars)');
  if (bad) { console.log('\n  ' + bad + ' PROBLEMS'); process.exit(1); }
  console.log('  the almanac and the star list agree with the shell');
})();
