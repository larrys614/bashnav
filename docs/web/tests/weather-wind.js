/*  The wind demonstration: does the picture teach the right physics?

    THIS ONE EXISTS BECAUSE THE SCIENCE WAS CHECKED BEFORE IT WAS BUILT.
    Larry asked for a circular plot with isobars round a low and the wind
    flowing in from eight points, with sliders for latitude and for the
    low's pressure - and said the wind should follow the isobars more
    closely as the pressure differential rose, with centrifugal force as
    the cause. Worked through, that is wrong in its causal direction, and
    the check is shaped by the wrongness:

      1. IN A FRICTIONLESS BALANCE THE WIND ALREADY FOLLOWS THE ISOBARS
         EXACTLY, at every gradient and every latitude. So the angle this
         panel shows can only come from friction, and the check holds it
         to the friction balance.

      2. THE ANGLE DOES NOT DEPEND ON THE PRESSURE GRADIENT. With a linear
         drag the steady balance gives tan(alpha) = k/f exactly and G
         cancels. Asserted here across the whole pressure slider: if the
         angle ever moves with it, the panel has gone back to the
         intuitive and wrong story.

      3. LATITUDE IS THE DIAL, through f = 2*Omega*sin(lat), and the angle
         must fall as latitude rises.

      4. CENTRIFUGAL FORCE CHANGES THE SPEED, NOT THE ANGLE. Round a low
         the gradient wind is below geostrophic, round a high above it,
         and for a high there is a hard limit at f*f*R = 4G past which no
         solution exists - which is why tight intense highs do not occur.
         The threshold is checked from both sides.

      5. AND THE DRAWING HAS TO AGREE WITH THE WORDS. Every arrow's angle
         to its own isobar tangent is measured off the SVG and compared
         with the stated angle, and the circulation sense is checked from
         the cross product - anticlockwise round a low in the north,
         clockwise in the south.

      node weather-wind.js   (needs the server on $PORT)  */
'use strict';
const { chromium } = require('playwright');
const BASE = 'http://127.0.0.1:' + (process.env.PORT || 8090) + '/weather/';

/*  the independent answer, written from the balance rather than from the
    page: Coriolis, a linear drag pinned by the observed angle at 45, and
    the gradient-wind quadratic for curvature.  */
const OMEGA = 7.292115e-5, RHO = 1.225, KN = 1.943844;
const f = lat => Math.abs(2 * OMEGA * Math.sin(lat * Math.PI / 180));
const drag = a45 => f(45) * Math.tan(a45 * Math.PI / 180);
const alphaOf = (lat, a45) => Math.atan2(drag(a45), f(lat)) * 180 / Math.PI;
const pgf = mb => (mb * 100 / 1e5) / RHO;
function vgrad(mb, lat, rkm, low) {
  const F = f(lat), g = pgf(mb), r = rkm * 1000;
  if (low) return r / 2 * (-F + Math.sqrt(F * F + 4 * g / r));
  const d = F * F - 4 * g / r;
  return d < 0 ? -1 : r / 2 * (F - Math.sqrt(d));
}

let checks = 0, bad = 0;
function near(what, got, want, tol) {
  checks++;
  if (!(Math.abs(got - want) <= tol)) {
    bad++;
    console.log('  FAIL ' + what + ': page ' + got + ', computed ' + want.toFixed(2) +
                ' (tolerance ' + tol + ')');
  }
}
function is(what, got, want) {
  checks++;
  if (got !== want) { bad++; console.log('  FAIL ' + what + ': got ' + JSON.stringify(got) +
                                         ', want ' + JSON.stringify(want)); }
}

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 420, height: 2400 }, timezoneId: 'UTC' });
  const errs = [];
  page.on('pageerror', e => errs.push(String(e)));
  await page.goto(BASE + 'index.html', { waitUntil: 'load', timeout: 20000 });
  await page.click('[data-go="learn"]');
  await page.waitForTimeout(250);
  await page.click('#les-list >> text=/Coriolis/i');
  await page.waitForTimeout(350);
  await page.click('#les-more button');
  await page.waitForTimeout(600);

  is('both demonstrations are on the page', await page.evaluate(
    () => document.querySelectorAll('.gundemo').length), 2);
  is('the wind panel has eight arrows', await page.evaluate(
    () => (document.querySelectorAll('.gundemo')[1] || document)
            .querySelectorAll('[data-arrow]').length), 8);

  const rkm = await page.evaluate(() => WIND.RKM);

  const read = async (lat, a45, grad, low) => page.evaluate(([la, su, gr, lw]) => {
    const pan = document.querySelectorAll('.gundemo')[1];
    const f = (id, v) => { const e = document.getElementById(id); e.value = v;
      e.dispatchEvent(new Event('input', { bubbles: true })); };
    /*  the toggle is a button, so it is pressed rather than set - read the
        state back off WX afterwards instead of assuming it took  */
    if (WIND.low !== lw) pan.querySelector('button').click();
    f('wx-lat', la); f('wx-surf', su); f('wx-grad', Math.round(gr * 10));
    const rows = {};
    Array.prototype.forEach.call(pan.querySelectorAll('.gcrow'), r => {
      rows[r.querySelector('.gcn').textContent] = r.querySelector('.gcv').textContent;
    });
    const svg = pan.querySelector('svg');
    const arr = [...svg.querySelectorAll('[data-arrow]')].map(a => ({
      x1: +a.getAttribute('x1'), y1: +a.getAttribute('y1'),
      x2: +a.getAttribute('x2'), y2: +a.getAttribute('y2'),
      op: +a.getAttribute('opacity')
    }));
    return { rows, arr, lat: WIND.lat, a45: WIND.a45, grad: WIND.grad, low: WIND.low,
             text: pan.querySelector('.gunread').textContent,
             centre: svg.querySelector('text').textContent };
  }, [lat, a45, grad, low]);

  const num = t => { const m = /(-?\d+(?:\.\d+)?)/.exec(t); return m ? +m[1] : NaN; };
  const ANG = 'crossing the isobar', GEO = 'geostrophic',
        GRAD = 'gradient wind', SFC = 'surface wind';

  /* ---- 1. the angle does NOT move with the pressure gradient ------ */
  const base = await read(45, 15, 4, true);
  for (const g of [0.5, 1, 2, 4, 6, 8]) {
    const r = await read(45, 15, g, true);
    near('the angle at ' + g + ' mb/100km', num(r.rows[ANG]), num(base.rows[ANG]), 0.6);
    /*  and the speed DOES, or the slider is doing nothing at all  */
    near('geostrophic at ' + g + ' mb/100km', num(r.rows[GEO]),
         pgf(g) / f(45) * KN, 1.0);
  }

  /* ---- 2. latitude is the dial ------------------------------------ */
  for (const lat of [10, 20, 30, 45, 60, 75, -45]) {
    const r = await read(lat, 15, 4, true);
    near('the angle at ' + r.lat, num(r.rows[ANG]), alphaOf(r.lat, r.a45), 0.6);
  }
  {
    const lo = await read(15, 15, 4, true), hi = await read(70, 15, 4, true);
    checks++;
    if (!(num(lo.rows[ANG]) > num(hi.rows[ANG]) + 5)) {
      bad++; console.log('  FAIL the inflow angle does not fall as latitude rises');
    }
  }

  /* ---- 3. a rougher surface turns it further ---------------------- */
  {
    const sea = await read(45, 10, 4, true), land = await read(45, 40, 4, true);
    near('open water at 45', num(sea.rows[ANG]), 10, 0.6);
    near('rough land at 45', num(land.rows[ANG]), 40, 0.6);
  }

  /* ---- 4. curvature changes the speed ----------------------------- */
  for (const [lat, g] of [[45, 4], [30, 2], [60, 6], [-45, 4]]) {
    const r = await read(lat, 15, g, true);
    const geo = pgf(g) / f(r.lat), gr = vgrad(g, r.lat, rkm, true);
    near('gradient wind at ' + r.lat + ', ' + g + ' mb', num(r.rows[GRAD]), gr * KN, 1.0);
    near('surface wind at ' + r.lat + ', ' + g + ' mb', num(r.rows[SFC]),
         gr * Math.cos(alphaOf(r.lat, r.a45) * Math.PI / 180) * KN, 1.0);
    checks++;
    if (!(gr < geo)) { bad++; console.log('  FAIL the gradient wind round a low is not subgeostrophic at ' + r.lat); }
  }
  {
    const r = await read(45, 15, 1, false);
    const geo = pgf(1) / f(45), gr = vgrad(1, 45, rkm, false);
    near('a high at 45, 1 mb, is supergeostrophic', num(r.rows[GRAD]), gr * KN, 1.0);
    checks++;
    if (!(gr > geo)) { bad++; console.log('  FAIL the gradient wind round a high is not supergeostrophic'); }
    is('the centre is marked H', r.centre, 'H');
  }

  /* ---- 5. the high's limit, from both sides ----------------------- */
  for (const lat of [30, 45, 60]) {
    const lim = f(lat) * f(lat) * (rkm * 1000) / 4 / (100 / 1e5 / RHO);   /* mb/100km */
    const below = Math.max(0.5, Math.floor((lim - 0.3) * 10) / 10);
    const above = Math.min(8, Math.ceil((lim + 0.3) * 10) / 10);
    const rb = await read(lat, 15, below, false);
    const ra = await read(lat, 15, above, false);
    checks++;
    if (/impossible/.test(rb.rows[GRAD])) {
      bad++; console.log('  FAIL a high at ' + lat + ', ' + below + ' mb (limit ' +
                         lim.toFixed(2) + ') is called impossible and is not');
    }
    checks++;
    if (!/impossible/.test(ra.rows[GRAD])) {
      bad++; console.log('  FAIL a high at ' + lat + ', ' + above + ' mb (limit ' +
                         lim.toFixed(2) + ') should have no solution');
    }
    checks++;
    if (!/cannot exist/.test(ra.text)) {
      bad++; console.log('  FAIL the impossible high does not say so in words at ' + lat);
    }
  }

  /* ---- 6. the drawing agrees with the words ----------------------- */
  /*  THE GRADIENT IS PART OF EACH CASE, because a high at 4 mb/100 km at
      45 degrees is past the limit: the arrows are hidden and their
      coordinates are whatever they were last set to. The first version of
      this loop asked for exactly that and measured the stale ones, which
      read as the page being wrong when the case was simply impossible.
      Hidden arrows are checked on purpose below instead.  */
  for (const [lat, a45, grad, low] of [[45, 15, 4, true], [45, 35, 4, true],
                                       [-45, 15, 4, true], [45, 1, 1, false],
                                       [-30, 15, 0.5, false], [20, 25, 4, true]]) {
    const r = await read(lat, a45, grad, low);
    const want = num(r.rows[ANG]);
    let worstAng = 0, sense = 0, inward = 0;
    r.arr.forEach((a, i) => {
      const th = i * 45 * Math.PI / 180;
      /*  the isobar's tangent at this arrow's foot, in screen pixels:
          outward is (sin, -cos) with y down, and the tangent is that
          turned a quarter turn  */
      const ox = Math.sin(th), oy = -Math.cos(th);
      const tx = oy, ty = -ox;                    /* one tangent direction */
      const wx = a.x2 - a.x1, wy = a.y2 - a.y1;
      const wn = Math.hypot(wx, wy) || 1;
      /*  the angle between the arrow and the isobar, either tangent  */
      const dot = Math.abs((wx * tx + wy * ty) / wn);
      const ang = Math.acos(Math.min(1, dot)) * 180 / Math.PI;
      worstAng = Math.max(worstAng, Math.abs(ang - want));
      /*  inward or outward: the radial component  */
      inward += (wx * ox + wy * oy) / wn < 0 ? 1 : -1;
      /*  circulation: cross the outward radial with the wind  */
      sense += (ox * wy - oy * wx) > 0 ? 1 : -1;
    });
    near('every arrow meets its isobar at the stated angle (' + lat + ', ' + a45 +
         (low ? ', low' : ', high') + ')', worstAng, 0, 1.2);
    is('all eight ' + (low ? 'blow inward' : 'blow outward') +
       ' (' + lat + (low ? ', low' : ', high') + ')', inward, low ? 8 : -8);
    /*  anticlockwise on screen (y down) is a NEGATIVE cross product of
        outward with the flow; a low in the north and a high in the south
        turn that way, the other two the other way  */
    const ccw = (low ? 1 : -1) * (lat >= 0 ? 1 : -1);
    is('the circulation turns the right way (' + lat + (low ? ', low' : ', high') + ')',
       Math.sign(sense), ccw > 0 ? -1 : 1);
  }

  /* ---- 7. and an impossible high draws nothing rather than nonsense -- */
  {
    const r = await read(45, 15, 8, false);
    is('an impossible high hides its arrows', r.arr.every(a => a.op === 0), true);
  }

  if (errs.length) { bad++; console.log('  FAIL page errors: ' + errs.join(' | ')); }
  await browser.close();
  console.log('  ' + checks + ' checks on the wind demonstration' + (bad ? '' : ', all agree'));
  if (bad) { console.log('  ' + bad + ' FAILED'); process.exit(1); }
})().catch(e => { console.error(e); process.exit(2); });
