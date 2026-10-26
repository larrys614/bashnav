/*  The gunnery demonstration: does the picture teach the right physics?

    The lesson makes three claims about Coriolis, and the demonstration
    exists so a reader can watch each one hold rather than take it on
    trust. If the demonstration is wrong, the reader is being taught the
    wrong thing with more conviction than prose could manage - so each
    claim is checked against an independent computation here, not against
    the page's own arithmetic.

      1. THE MAGNITUDE DOES NOT DEPEND ON THE BEARING. For horizontal
         motion the deflecting acceleration is 2*Omega*v*sin(phi),
         perpendicular to the track whichever way the gun is laid. Train it
         through the whole 180 and the number must not move. This is the
         claim the two-shell figure can only assert, and the reason the gun
         trains at all.

      2. IT IS ZERO AT THE EQUATOR. sin(0) = 0. This is the most useful
         consequence in the lesson, because it is also why no tropical
         cyclone forms within about five degrees of the line.

      3. IT REVERSES WITH HEMISPHERE AND GOES AS sin(latitude). Right in
         the north, left in the south, same size at mirrored latitudes.

    And the drawing has to agree with the words under it: the fall is
    marked at the deflection the readout states, on the correct side.

      node weather-gun.js   (needs the server on $PORT)  */
'use strict';
const { chromium } = require('playwright');
const BASE = 'http://127.0.0.1:' + (process.env.PORT || 8090) + '/weather/';

/*  the independent figure. Deliberately written from the textbook form -
    a = 2*Omega*v*sin(phi), deflection = half a t squared - rather than
    from the page's angular-momentum reasoning, so the two routes have to
    meet.  */
const OMEGA = 7.292115e-5;
function deflect(latDeg, range, tof) {
  const v = range / tof;
  const a = 2 * OMEGA * v * Math.sin(latDeg * Math.PI / 180);
  return 0.5 * a * tof * tof;
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
  const page = await browser.newPage({ viewport: { width: 420, height: 1800 }, timezoneId: 'UTC' });
  const errs = [];
  page.on('pageerror', e => errs.push(String(e)));
  await page.goto(BASE + 'index.html', { waitUntil: 'load', timeout: 20000 });
  await page.click('[data-go="learn"]');
  await page.waitForTimeout(250);
  await page.click('#les-list >> text=/Coriolis/i');
  await page.waitForTimeout(350);
  await page.click('#les-more button');
  await page.waitForTimeout(400);

  is('the demonstration is on the page', await page.evaluate(
    () => !!document.querySelector('.gundemo svg')), true);

  /*  the gun's own figures, read off the page rather than assumed, so a
      change to the shell or the range is picked up instead of hidden  */
  const gun = await page.evaluate(() => ({ range: GUN.range, tof: GUN.tof }));

  const read = async (brg, lat) => page.evaluate(([b, l]) => {
    const f = (id, v) => { const e = document.getElementById(id); e.value = v;
      e.dispatchEvent(new Event('input', { bubbles: true })); };
    f('gun-brg', b); f('gun-lat', l);
    const t = document.querySelector('.gunread').textContent;
    const m = /falls (\d+(?:\.\d+)?) m to the (RIGHT|LEFT)/.exec(t);
    const svg = document.querySelector('.gundemo svg');
    const q = s => svg.querySelector('[data-pt="' + s + '"]');
    const pt = s => [ +q(s).getAttribute('cx'), +q(s).getAttribute('cy') ];
    return { text: t, metres: m ? +m[1] : (/falls where it was aimed/.test(t) ? 0 : null),
             side: m ? m[2] : null, aim: pt('aim'), fall: pt('fall'),
             lat: +document.getElementById('gun-lat').value,
             brg: +document.getElementById('gun-brg').value };
  }, [brg, lat]);

  /* ---- 1. the bearing does not change the magnitude -------------- */
  const atNorth = await read(0, 45);
  near('deflection at 45 N', atNorth.metres, deflect(45, gun.range, gun.tof), 1.0);
  for (const brg of [-90, -45, -17, 0, 23, 45, 90]) {
    const r = await read(brg, 45);
    near('bearing ' + brg + ' at 45 N is the same size', r.metres, atNorth.metres, 0.6);
    is('bearing ' + brg + ' at 45 N falls right', r.side, 'RIGHT');
  }

  /* ---- 2. zero on the equator, at every bearing ------------------ */
  for (const brg of [-90, 0, 37, 90]) {
    const r = await read(brg, 0);
    is('bearing ' + brg + ' on the equator deflects nowhere', r.metres, 0);
    checks++;
    if (!/sin\(latitude\) is zero/.test(r.text)) {
      bad++; console.log('  FAIL the equator readout does not say why it is zero: ' +
                         JSON.stringify(r.text));
    }
  }

  /* ---- 3. hemisphere and sin(latitude) --------------------------- */
  for (const lat of [10, 23.5, 45, 66.5, 80]) {
    const n = await read(0, lat), s = await read(0, -lat);
    //  against the latitude the SLIDER landed on, not the one asked for:
    //  its step is a whole degree, so 23.5 becomes 24 and a computation
    //  at 23.5 would fail the page for the test's own rounding
    near('magnitude at ' + n.lat + ' N', n.metres, deflect(n.lat, gun.range, gun.tof), 1.0);
    near('magnitude at ' + s.lat + ' S', s.metres, Math.abs(deflect(s.lat, gun.range, gun.tof)), 1.0);
    if (n.lat === -s.lat)
      near('mirrored at ' + lat + ' is the same size', s.metres, n.metres, 0.6);
    is('at ' + n.lat + ' N it falls right', n.side, 'RIGHT');
    is('at ' + s.lat + ' it falls left', s.side, 'LEFT');
  }
  //  and it really is sin, not a straight line in latitude
  const a30 = (await read(0, 30)).metres, a90 = deflect(90, gun.range, gun.tof);
  near('30 N is half of the pole, as sin says', a30, 0.5 * a90, 1.0);

  /* ---- the drawing agrees with the words ------------------------- */
  //  the fall must sit to the correct side of the aim: cross the line of
  //  fire with the aim-to-fall vector and the sign is the side
  for (const [brg, lat, want] of [[0, 45, 'RIGHT'], [90, 45, 'RIGHT'],
                                  [-90, 45, 'RIGHT'], [0, -45, 'LEFT']]) {
    const r = await read(brg, lat);
    const a = brg * Math.PI / 180;
    const ux = Math.sin(a), uy = -Math.cos(a);        /* along the line of fire */
    const vx = r.fall[0] - r.aim[0], vy = r.fall[1] - r.aim[1];
    const cross = ux * vy - uy * vx;                  /* >0 is screen-right of it */
    is('the drawing puts the fall on the ' + want + ' at brg ' + brg + ' lat ' + lat,
       cross > 0 ? 'RIGHT' : 'LEFT', want);
  }

  if (errs.length) { bad++; console.log('  FAIL page errors: ' + errs.join(' | ')); }
  await browser.close();
  console.log('  ' + checks + ' checks on the gunnery demonstration' + (bad ? '' : ', all agree'));
  if (bad) { console.log('  ' + bad + ' FAILED'); process.exit(1); }
})().catch(e => { console.error(e); process.exit(2); });
