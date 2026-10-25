/*  Pub. 249 - the generated page and the tutor that marks your working -
    as the PAGE shows it, against what the shell PRINTS.

    tab_args(), tab_entry() and tab_Z() are held to the awk at full
    precision in celnav-diff.js, over a page's worth of entries per case.
    This is the screen around them, and the screen is where the teaching
    lives:

      - the ENTERING ARGUMENTS, two of which are derived and are the
        mistake the tables actually produce
      - the page itself, seven rows, with the reader's own LHA marked
      - the rule at the foot, which is the step the whole screen exists to
        teach, and which differs by hemisphere
      - THE ATTRIBUTION. The tutor does not report a difference, it blames
        it: the table's rounding is small and bounded, while each common
        slip has a size of its own. Four readings are fed in - the right
        one, the interpolation applied backwards, a declination one degree
        off and an LHA one degree off - and the page has to reach the same
        verdict as the shell on each.

      node celnav-tables249.js args.txt page.txt check-<n>.txt ...  */
'use strict';
const fs = require('fs');
const { chromium } = require('playwright');

const [argsFile, pageFile, ...checkFiles] = process.argv.slice(2);
const BASE = 'http://127.0.0.1:' + (process.env.PORT || 8731) + '/celnav/';

/*  the project's own worked example, which is what the README, the site
    figures and docs/make-site.sh all use  */
const CASE = {
  lat: '35 00 N', lon: '040 00 W', date: '2026-08-29', time: '07:30:00',
  body: 'Dubhe', hs: '19 32.1', ie: '1.5', he: '3.0'
};

const canon = s => String(s)
  /*  the shell glues the hemisphere to the degrees - "61N 36.5'" - and the
      page sets it off with the degree mark. Same angle.  */
  .replace(/(\d)([NSEW])/g, '$1 $2')
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
function shellNum(txt, re) { const m = re.exec(txt); return m ? m[1] : undefined; }

/*  WHICH VERDICT, not its wording. The tutor's whole value is that it
    blames the right thing, and the two implementations are free to word
    the blame differently; they are not free to blame differently.  */
function verdict(t) {
  if (/wrong way|WRONG WAY/.test(t)) return 'backwards';
  if (/declination one whole degree off/.test(t)) return 'declination';
  if (/LHA one degree off/.test(t)) return 'lha';
  if (/[Rr]ounding in the table/.test(t)) return 'rounding';
  if (/not one of the usual slips/.test(t)) return 'unknown';
  return '?';
}

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 900, height: 2000 }, timezoneId: 'UTC' });
  const errs = [];
  page.on('pageerror', e => errs.push(String(e)));
  await page.goto(BASE + 'index.html', { waitUntil: 'load', timeout: 20000 });

  const kv = sel => page.evaluate(s => {
    const out = {};
    document.querySelectorAll(s + ' table.kv tr').forEach(tr => {
      const th = tr.querySelector('th'), td = tr.querySelector('td');
      if (th && td) out[th.textContent.replace(/\s+/g, ' ').trim()] = td.textContent.trim();
    });
    return out;
  }, sel);

  await page.click('[data-go="tables"]');
  await page.fill('#t-lat', CASE.lat);
  await page.fill('#t-lon', CASE.lon);
  await page.fill('#t-date', CASE.date);
  await page.fill('#t-time', CASE.time);
  await page.fill('#t-body', CASE.body);
  await page.fill('#t-hs', CASE.hs);
  await page.fill('#t-ie', CASE.ie);
  await page.fill('#t-he', CASE.he);
  await page.click('#t-go');
  await page.waitForTimeout(400);

  /* ---- the entering arguments ------------------------------------ */
  const sh = fs.readFileSync(argsFile, 'utf8');
  const a = await kv('#t-args');
  const head = Object.keys(a).find(k => /at .* UT$/.test(k));
  eq('GHA and dec', (a[head] || '').replace(/\s+/g, ' '),
     'GHA ' + shellNum(sh, /GHA\s+(\d+ [\d.]+')/) + ' Dec ' + shellNum(sh, /Dec\s+(\d+ [\d.]+'[NS])/));
  eq('assumed latitude', (a['Assumed latitude'] || '').split(' ')[0],
     shellNum(sh, /Assumed LAT\s+(\d+[NS])/));
  eq('assumed longitude', (a['Assumed longitude'] || '').split(' ')[0],
     shellNum(sh, /Assumed LON\s+(\d+ [\d.]+'[EW])/));
  eq('LHA', a['LHA'], shellNum(sh, /^\s+LHA\s+(\d+)\s*$/m));
  eq('declination entry', (a['Declination'] || '').split(' ')[0],
     shellNum(sh, /Declination\s+(\d+[NS] [\d.]+')/));
  eq('Ho', (a['Ho'] || '').split(' ')[0], shellNum(sh, /Ho\s+(\d+ [\d.]+')/));

  /* ---- the page --------------------------------------------------- */
  const sp = fs.readFileSync(pageFile, 'utf8');
  const rows = await page.evaluate(() => Array.from(
    document.querySelectorAll('#t-page table.ct-tab tr')).slice(1).map(tr =>
      Array.from(tr.querySelectorAll('td')).map(td => td.textContent.trim())));
  const shRows = [];
  for (const line of sp.split('\n')) {
    const m = /^\s+(\d+)\s+(\d+ [\d.]+')\s+([-+][\d.]+)\s+(\d+)/.exec(line);
    if (m) shRows.push([m[1], m[2], m[3], m[4]]);
  }
  eq('page is seven rows', String(rows.length), String(shRows.length));
  for (let i = 0; i < Math.min(rows.length, shRows.length); i++) {
    eq('page row ' + (i + 1) + ' LHA', rows[i][0], shRows[i][0]);
    eq('page row ' + (i + 1) + ' Hc',  rows[i][1], shRows[i][1]);
    eq('page row ' + (i + 1) + ' d',   rows[i][2], shRows[i][2]);
    eq('page row ' + (i + 1) + ' Z',   rows[i][3], shRows[i][3]);
  }
  //  the reader's own LHA has to be the marked row, and the right one
  const marked = await page.evaluate(() => {
    const tr = document.querySelector('#t-page tr.picked');
    return tr ? tr.querySelector('td').textContent.trim() : undefined;
  });
  eq('the marked row is the reader\'s LHA', marked, shellNum(sp, /^\s+(\d+).*your LHA/m));
  //  the rule at the foot, by hemisphere
  const foot = await page.evaluate(() =>
    Array.from(document.querySelectorAll('#t-page p')).map(p => p.textContent).join(' '));
  eq('the rule at the foot', /N\. Lat/.test(foot) ? 'N' : 'S', /N\. Lat/.test(sp) ? 'N' : 'S');
  eq('Zn = Z above 180', /Zn = Z/.test(foot) ? 'yes' : 'no', /Zn = Z/.test(sp) ? 'yes' : 'no');

  /* ---- the four markings ------------------------------------------ */
  for (const cf of checkFiles) {
    const txt = fs.readFileSync(cf, 'utf8');
    const uhc = shellNum(txt, /Your Hc\s+(\d+ [\d.]+')/);
    const uz = shellNum(txt, /Your Z\s+(\d+)/);
    await page.fill('#t-uhc', uhc.replace(/'/, ''));
    await page.fill('#t-uz', uz || '');
    await page.click('#t-mark');
    await page.waitForTimeout(300);
    const c = await kv('#t-check');
    const prose = await page.evaluate(() =>
      Array.from(document.querySelectorAll('#t-check p')).map(p => p.textContent).join(' '));
    const tag = cf.replace(/^.*\//, '');
    eq(tag + ' from the page Hc', (c['From the page'] || '').split(' ')[0],
       'Hc ' + shellNum(txt, /From the page\s+Hc (\d+ [\d.]+')/));
    eq(tag + ' interpolated', (c['Interpolated'] || '').split(' ')[0],
       shellNum(txt, /Interpolated\s+Hc (\d+ [\d.]+')/));
    eq(tag + ' your Hc', c['Your Hc'], uhc);
    eq(tag + ' exact Hc', c['Exact Hc'], shellNum(txt, /Exact Hc\s+(\d+ [\d.]+')/));
    eq(tag + ' difference', c['Difference'], shellNum(txt, /Difference\s+([-+][\d.]+')/));
    eq(tag + ' VERDICT', verdict(prose), verdict(txt));
    eq(tag + ' intercept exactly', (c['and exactly'] || ''),
       shellNum(txt, /and exactly:\s+([\d.]+' (?:TOWARD|AWAY))/));
  }

  if (errs.length) { bad++; console.log('  FAIL page errors: ' + errs.join(' | ')); }
  await browser.close();
  console.log('    ' + checks + ' checks' + (bad ? '' : ', all agree'));
  if (bad) { console.log('    ' + bad + ' FAILED'); process.exit(1); }
})().catch(e => { console.error(e); process.exit(2); });
