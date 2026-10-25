/*  The noon sight and Polaris, as the PAGE shows them, against what the
    shell PRINTS.

    celnav-diff.js holds lan_jd() and pol_lat() to the awk at full
    precision over 400 generated cases. That is the arithmetic. This is
    the other half, and the half that has actually shipped faults in this
    repository: a correct number wired to the wrong field, a zero-pad
    taken before rounding, an hour angle rendered with the formatter that
    appends a hemisphere. None of those are visible to a module diff.

    Four screens are checked, because each half of each screen is a
    different code path: the noon sight before a reading (what to expect
    on deck) and after one (the latitude), and the same for Polaris.

      node celnav-latitude.js noon-plan.txt noon-work.txt pol-plan.txt pol-work.txt  */
'use strict';
const fs = require('fs');
const { chromium } = require('playwright');

const [nPlan, nWork, pPlan, pWork] = process.argv.slice(2);
const BASE = 'http://127.0.0.1:' + (process.env.PORT || 8731) + '/celnav/';

/*  THE CASE IS FIXED HERE AND IN THE SHELL COMMANDS THAT FEED IT, and the
    two must agree or the check is comparing two different sights. Kept in
    one object so there is one place to change them together.  */
const CASE = {
  lat: '41 49.0 N', lon: '071 24.0 W', date: '2026-08-29',
  nhs: '60 03.2', ie: '1.5', he: '2',
  ptime: '23:12:00', phs: '42 18.4'
};

/*  one spelling for a number. The shell writes a minus as '-', the page
    as U+2212; the shell puts a hemisphere in front of a latitude and the
    page puts it after; and the shell's degree mark is a space.  */
const canon = s => String(s)
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
    console.log('  FAIL ' + what + '\n        shell ' + JSON.stringify(want) +
                '\n        page  ' + JSON.stringify(got));
  }
}

/*  the shell's value for a label: everything after two or more spaces,
    with any trailing parenthetical kept out of it. Returns undefined when
    the label is absent, and an absent label fails rather than passes.  */
function shellVal(txt, label) {
  const re = new RegExp('^\\s+' + label + '\\s{2,}(.+?)\\s*$', 'm');
  const m = re.exec(txt);
  if (!m) return undefined;
  return m[1].replace(/\s{3,}\(.*$/, '').trim();
}
function shellNum(txt, re) {
  const m = re.exec(txt);
  return m ? m[1] : undefined;
}

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 900, height: 1400 } });
  const errs = [];
  page.on('pageerror', e => errs.push(String(e)));
  await page.goto(BASE + 'index.html', { waitUntil: 'load', timeout: 20000 });

  /*  read the rendered key/value rows as a map. Both screens render every
      line through the same kvTable(), so one reader does all four.  */
  const rows = sel => page.evaluate(s => {
    const out = {};
    document.querySelectorAll(s + ' table.kv tr').forEach(tr => {
      const th = tr.querySelector('th'), td = tr.querySelector('td');
      if (th && td) out[th.textContent.replace(/\s+/g, ' ').trim()] = td.textContent.trim();
    });
    out.__prose = Array.from(document.querySelectorAll(s + ' p'))
                    .map(p => p.textContent).join(' ');
    out.__head = (document.querySelector(s + ' h3') || {}).textContent || '';
    return out;
  }, sel);

  const fill = async (vals) => {
    for (const [id, v] of Object.entries(vals))
      await page.fill('#' + id, v);
  };

  /* ---- the noon sight, before a reading --------------------------- */
  await page.click('[data-go="noon"]');
  await fill({ 'n-lat': CASE.lat, 'n-lon': CASE.lon, 'n-date': CASE.date, 'n-hs': '' });
  await page.click('#n-go');
  let sh = fs.readFileSync(nPlan, 'utf8');
  let pg = await rows('#n-out');

  eq('noon date', pg.__head, 'Local apparent noon - ' + CASE.date);
  //  the shell writes the position on one line with a single space after
  //  the label, so it does not come through shellVal's two-space rule
  eq('noon position', pg['Position'],
     shellNum(sh, /^\s+Position (.+?)\s*$/m).replace(/\s{2,}/, '   '));
  eq('noon meridian UT', pg['Sun on your meridian at'],
     shellNum(sh, /Sun on your meridian at\s+(\d\d:\d\d:\d\d) UT/) + ' UT');
  eq('noon LMT', pg['in local mean time'],
     shellNum(sh, /\((\d\d:\d\d:\d\d) local mean time\)/));
  eq('noon equation of time', (pg['Equation of time'] || '').split(' ')[0],
     shellNum(sh, /Equation of time\s+([-+][\d.]+) min/));
  eq("noon sun's declination", pg["Sun's declination then"], shellVal(sh, "Sun's declination then"));
  eq('noon meridian altitude', pg['Meridian altitude to expect'],
     shellVal(sh, 'Meridian altitude to expect').replace(' deg,', '\u00b0,'));
  //  the conditional paragraph: the SIZE of the fall and which of the two
  //  things the shell says about it. A stationary point near the zenith is
  //  not the same statement as one at a workaday altitude.
  eq('noon fall in 2 min', shellNum(pg.__prose, /altitude is (?:only )?([\d.]+)' lower/),
     shellNum(sh, /altitude is (?:only )?([\d.]+)' lower/));
  eq('noon fall, which claim',
     /the clock is not the point/.test(pg.__prose) ? 'watch' : 'sharp',
     /the clock is not the point/.test(sh) ? 'watch' : 'sharp');

  /* ---- the noon sight, with a reading ----------------------------- */
  await fill({ 'n-hs': CASE.nhs, 'n-ie': CASE.ie, 'n-he': CASE.he });
  await page.click('#n-go');
  sh = fs.readFileSync(nWork, 'utf8');
  pg = await rows('#n-out');
  eq('noon Hs', pg['Hs (sextant, lower limb)'], shellVal(sh, 'Hs  \\(sextant, lower limb\\)'));
  ['index error', 'dip', 'refraction', 'semi-diameter', 'parallax'].forEach(k => {
    eq('noon ' + k, pg[k], shellVal(sh, k));
  });
  eq('noon Ho', pg['Ho (observed altitude)'], shellVal(sh, 'Ho  \\(observed altitude\\)'));
  eq('noon zenith distance', pg['Zenith distance 90 \u2212 Ho'], shellVal(sh, 'Zenith distance  90 - Ho'));
  eq('noon declination', pg['Declination'], shellVal(sh, 'Declination'));
  eq('noon LATITUDE', pg['LATITUDE dec + ZD'], shellVal(sh, 'LATITUDE   dec \\+ ZD'));
  eq('noon which side', /bearing south/.test(pg.__prose) ? 'S' : 'N',
     /bearing south of you/.test(sh) ? 'S' : 'N');

  /* ---- Polaris, before a reading ---------------------------------- */
  await page.click('#nav-back');
  await page.click('[data-go="polaris"]');
  await fill({ 'p-lon': CASE.lon, 'p-date': CASE.date, 'p-time': CASE.ptime, 'p-hs': '' });
  await page.click('#p-go');
  sh = fs.readFileSync(pPlan, 'utf8');
  pg = await rows('#p-out');
  eq('polaris GHA', pg['Polaris GHA'], shellVal(sh, 'Polaris GHA'));
  eq('polaris LHA', pg['LHA GHA + longitude'], shellVal(sh, 'LHA   GHA \\+ longitude'));
  eq('polaris declination', pg['Declination'], shellVal(sh, 'Declination'));
  eq('polaris polar distance', pg['Polar distance 90 \u2212 dec'], shellVal(sh, 'Polar distance  90 - dec'));
  eq('polaris planning correction',
     (pg['Correction to Ho at this LHA'] || '').split(' ')[0],
     shellNum(sh, /Correction to Ho at this LHA\s+([-+][\d.]+)'/));
  eq('polaris daily swing',
     shellNum(pg['Correction to Ho at this LHA'] || '', /\u00b1([\d.]+)'/),
     shellNum(sh, /swings \+\/- ([\d.]+)'/));

  /* ---- Polaris, with a reading ------------------------------------ */
  await fill({ 'p-hs': CASE.phs, 'p-he': CASE.he });
  await page.click('#p-go');
  sh = fs.readFileSync(pWork, 'utf8');
  pg = await rows('#p-out');
  eq('polaris Hs', pg['Hs (sextant)'], shellVal(sh, 'Hs  \\(sextant\\)'));
  ['index error', 'dip', 'refraction'].forEach(k => { eq('polaris ' + k, pg[k], shellVal(sh, k)); });
  //  A STAR HAS NO LIMB AND NO PARALLAX, and the shell prints neither
  //  row. A page that shows them would be showing two zeros as if they
  //  were corrections.
  checks++;
  if (pg['semi-diameter'] !== undefined || pg['parallax'] !== undefined) {
    bad++;
    console.log('  FAIL polaris shows a limb or parallax row; a star has neither');
  }
  eq('polaris Ho', pg['Ho (observed altitude)'], shellVal(sh, 'Ho  \\(observed altitude\\)'));
  eq('polaris first-order correction', pg['Correction, first order \u2212p cos LHA'],
     shellVal(sh, 'Correction, first order  -p cos LHA'));
  eq('polaris exact correction', pg['Correction, solved exactly'],
     shellVal(sh, 'Correction, solved exactly'));
  eq('polaris LATITUDE', pg['LATITUDE'], shellVal(sh, 'LATITUDE'));
  eq('polaris gap between the two', shellNum(pg.__prose, /differ by ([\d.]+)'/),
     shellNum(sh, /differ by ([\d.]+)'/));

  if (errs.length) { bad++; console.log('  FAIL page errors: ' + errs.join(' | ')); }
  await browser.close();
  console.log('    ' + checks + ' checks' + (bad ? '' : ', all agree'));
  if (bad) { console.log('    ' + bad + ' FAILED'); process.exit(1); }
})().catch(e => { console.error(e); process.exit(2); });
