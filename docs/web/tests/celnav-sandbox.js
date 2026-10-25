/*  The sandbox - the navigational triangle - as the PAGE shows it,
    against what the shell PRINTS.

    There is no new arithmetic here: Hc and Zn are reduce_sight(), which
    celnav-diff.js already holds to the awk at full precision over 400
    cases. What this checks is the wiring and the prose, and the prose is
    the teaching: the shell says four different things depending on where
    the body is, and each one is a real warning about a real sight. A
    screen that said the wrong one, or said nothing, would still print the
    right numbers.

    The slider positions are chosen to reach all four:

      35 /  20 /  45   an ordinary sight, no caveat
      35 /  20 / 170   the body is below the horizon
      20 /  19 /   1   very high, AND on the meridian
      35 /  20 / 100   low, refraction uncertain
      35 /  35 /   0   on the meridian exactly - the noon sight

      node celnav-sandbox.js case.txt case.txt ...   (one per position)  */
'use strict';
const fs = require('fs');
const { chromium } = require('playwright');

const BASE = 'http://127.0.0.1:' + (process.env.PORT || 8731) + '/celnav/';
const files = process.argv.slice(2);

let checks = 0, bad = 0;
function eq(what, got, want) {
  checks++;
  if (got === undefined || want === undefined || String(got) !== String(want)) {
    bad++;
    if (bad <= 20)
      console.log('  FAIL ' + what + '\n        shell ' + JSON.stringify(want) +
                  '\n        page  ' + JSON.stringify(got));
  }
}
function shellNum(txt, re) { const m = re.exec(txt); return m ? m[1] : undefined; }

/*  WHICH caveats, not their wording. More than one can apply at once -
    a body at 80 degrees on the meridian is both - so this is a set.  */
function caveats(t) {
  const o = [];
  if (/below the horizon/.test(t)) o.push('below');
  if (/azimuth swings fast/.test(t)) o.push('high');
  if (/[Rr]efraction is uncertain/.test(t)) o.push('low');
  if (/on your meridian/.test(t)) o.push('meridian');
  return o.sort().join(',');
}

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 900, height: 1300 }, timezoneId: 'UTC' });
  const errs = [];
  page.on('pageerror', e => errs.push(String(e)));
  await page.goto(BASE + 'index.html', { waitUntil: 'load', timeout: 20000 });
  await page.click('[data-go="sandbox"]');
  await page.waitForTimeout(300);

  for (const file of files) {
    const sh = fs.readFileSync(file, 'utf8');
    //  the shell echoes its own arguments, so the case is read out of its
    //  own output rather than passed twice and trusted to match
    const m = /latitude\s+(-?[\d.]+)\s+declination\s+(-?[\d.]+)\s+LHA\s+(-?[\d.]+)/.exec(sh);
    if (!m) { bad++; console.log('  FAIL ' + file + ' has no argument line'); continue; }
    const [, lat, dec, lha] = m;
    const tag = lat + '/' + dec + '/' + lha;

    await page.evaluate(([a, b, c]) => {
      const set = (id, v) => {
        const el = document.getElementById(id);
        el.value = v;
        el.dispatchEvent(new Event('input', { bubbles: true }));
      };
      set('sb-lat', a); set('sb-dec', b); set('sb-lha', c);
    }, [lat, dec, lha]);
    await page.waitForTimeout(150);

    const got = await page.evaluate(() => {
      const o = {};
      document.querySelectorAll('#sb-out table.kv tr').forEach(tr => {
        const th = tr.querySelector('th'), td = tr.querySelector('td');
        if (th && td) o[th.textContent.trim()] = td.textContent.trim();
      });
      o.__prose = Array.from(document.querySelectorAll('#sb-out p')).map(p => p.textContent).join(' ');
      o.__lat = document.getElementById('sb-lat-v').textContent;
      o.__dec = document.getElementById('sb-dec-v').textContent;
      o.__lha = document.getElementById('sb-lha-v').textContent;
      //  the drawing: how many arc polylines survived the horizon clip
      o.__arcs = document.querySelectorAll('#sb-out svg polyline').length;
      //  how far from the centre the furthest drawn point is, as a
      //  fraction of the horizon circle: anything over 1 is outside the
      //  rim, which is below the horizon and cannot be drawn honestly
      const rim = +document.querySelector('#sb-out svg circle').getAttribute('r');
      const cx = +document.querySelector('#sb-out svg circle').getAttribute('cx');
      const cy = +document.querySelector('#sb-out svg circle').getAttribute('cy');
      let far = 0;
      document.querySelectorAll('#sb-out svg polyline').forEach(pl => {
        pl.getAttribute('points').split(' ').forEach(pt => {
          const [x, y] = pt.split(',').map(Number);
          const r = Math.hypot(x - cx, y - cy) / rim;
          if (r > far) far = r;
        });
      });
      o.__far = far;
      o.__marks = Array.from(document.querySelectorAll('#sb-out svg text'))
                    .map(t => t.textContent).filter(t => /^(Z|P \(.\)|★)$/.test(t)).sort().join(',');
      //  where the three marks actually sit, as a fraction of the horizon
      //  radius and an azimuth: the ELEVATED POLE is a teaching point in
      //  its own right - in the south it is the south celestial pole,
      //  below the S point and not the N - and nothing about Hc, Zn or
      //  the prose would notice it drawn in the wrong place.
      o.__pts = {};
      document.querySelectorAll('#sb-out svg circle[data-pt]').forEach(c => {
        const x = +c.getAttribute('cx'), y = +c.getAttribute('cy');
        o.__pts[c.getAttribute('data-pt')] = {
          r: Math.hypot(x - cx, y - cy) / rim,
          az: (Math.atan2(x - cx, cy - y) * 180 / Math.PI + 360) % 360
        };
      });
      o.__poleLabel = (Array.from(document.querySelectorAll('#sb-out svg text'))
        .find(t => /^P \(/.test(t.textContent)) || {}).textContent;
      return o;
    });

    eq(tag + ' Hc', (got['Computed altitude Hc'] || '').replace('°', ''),
       shellNum(sh, /computed altitude Hc\s+(-?[\d.]+)/));
    eq(tag + ' Zn', (got['Azimuth Zn'] || '').replace(/° T$/, '').trim(),
       shellNum(sh, /azimuth Zn\s+([\d.]+)/));
    eq(tag + ' caveats', caveats(got.__prose), caveats(sh));
    //  the sliders have to read back what they were set to
    eq(tag + ' latitude readout', got.__lat.replace(/[° ]/g, '').replace(/[NS]$/, ''),
       String(Math.abs(parseFloat(lat)).toFixed(1)));
    //  THE DRAWING AND THE PROSE HAVE TO AGREE. Below the horizon, the two
    //  arcs that reach the body are clipped away and the body is not
    //  marked; above it, all three arcs are drawn and all three points
    //  labelled. A picture that still showed a visible body under
    //  "no sight is possible" would be the worst kind of wrong here.
    const below = /below the horizon/.test(sh);
    checks++;
    if (below && /★/.test(got.__marks)) {
      bad++; console.log('  FAIL ' + tag + ': the body is marked but the shell says it is below the horizon');
    } else if (!below && !/★/.test(got.__marks)) {
      bad++; console.log('  FAIL ' + tag + ': the body is not marked but it is above the horizon');
    }
    //  THREE SIDES WHEN THE BODY IS VISIBLE. With it below the horizon
    //  the two arcs that reach it are cut short rather than removed - the
    //  part of each that is still above the horizon is real and is drawn -
    //  so counting polylines proves nothing there. What has to hold in
    //  every case is that NOTHING is drawn outside the rim.
    checks++;
    if (!below && got.__arcs !== 3) {
      bad++; console.log('  FAIL ' + tag + ': ' + got.__arcs + ' arcs drawn, expected three sides');
    }
    //  THE ELEVATED POLE. Its altitude is the latitude and its azimuth is
    //  north or south according to the hemisphere, so on the plot it sits
    //  at radius (90 - |lat|) / 90 from the centre, due N or due S.
    const L = parseFloat(lat);
    const wantR = (90 - Math.abs(L)) / 90, wantAz = L >= 0 ? 0 : 180;
    checks++;
    if (!got.__pts.pole || Math.abs(got.__pts.pole.r - wantR) > 0.01) {
      bad++;
      console.log('  FAIL ' + tag + ': the pole is drawn at radius ' +
        (got.__pts.pole ? got.__pts.pole.r.toFixed(3) : 'nowhere') +
        ', expected ' + wantR.toFixed(3));
    }
    checks++;
    if (!got.__pts.pole || Math.abs(((got.__pts.pole.az - wantAz + 540) % 360) - 180) > 1) {
      bad++;
      console.log('  FAIL ' + tag + ': the pole is drawn at azimuth ' +
        (got.__pts.pole ? got.__pts.pole.az.toFixed(1) : 'nowhere') +
        ', expected ' + wantAz);
    }
    eq(tag + ' pole label', got.__poleLabel, L >= 0 ? 'P (N)' : 'P (S)');
    //  and the body, from Hc and Zn, which is the drawing agreeing with
    //  the numbers printed under it
    if (!below) {
      const hcv = parseFloat(shellNum(sh, /computed altitude Hc\s+(-?[\d.]+)/));
      const znv = parseFloat(shellNum(sh, /azimuth Zn\s+([\d.]+)/));
      checks++;
      if (!got.__pts.body || Math.abs(got.__pts.body.r - (90 - hcv) / 90) > 0.01) {
        bad++;
        console.log('  FAIL ' + tag + ': the body is drawn at radius ' +
          (got.__pts.body ? got.__pts.body.r.toFixed(3) : 'nowhere') +
          ', expected ' + ((90 - hcv) / 90).toFixed(3) + ' for Hc ' + hcv);
      }
      checks++;
      if (!got.__pts.body || Math.abs(((got.__pts.body.az - znv + 540) % 360) - 180) > 1.5) {
        bad++;
        console.log('  FAIL ' + tag + ': the body is drawn at azimuth ' +
          (got.__pts.body ? got.__pts.body.az.toFixed(1) : 'nowhere') + ', expected Zn ' + znv);
      }
    }
    checks++;
    if (!(got.__far <= 1.002)) {
      bad++; console.log('  FAIL ' + tag + ': an arc is drawn ' +
        (got.__far * 100).toFixed(1) + '% of the way out - past the horizon');
    }
  }

  if (errs.length) { bad++; console.log('  FAIL page errors: ' + errs.join(' | ')); }
  await browser.close();
  console.log('    ' + checks + ' checks over ' + files.length + ' positions' + (bad ? '' : ', all agree'));
  if (bad) { console.log('    ' + bad + ' FAILED'); process.exit(1); }
})().catch(e => { console.error(e); process.exit(2); });
