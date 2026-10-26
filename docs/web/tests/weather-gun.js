/*  The gunnery demonstration: does the picture teach the right physics?

    THIS CHECK WAS REWRITTEN AFTER LARRY ASKED A GOOD QUESTION. The
    demonstration used to report one number - the sideways deflection -
    and he noticed that a shell fired EAST showed the same deflection as
    one fired north, which the lesson's angular-momentum story cannot
    explain, because an east-west shot does not change your distance from
    the axis. He was right that something was missing and right about its
    name: the Eoetvoes effect. Checking it turned up a third term as well.

    So the demonstration now reports three components, and this file holds
    it to a NUMERICAL INTEGRATION of the full rotating-frame equations
    rather than to a restatement of the page's own formulas. That is the
    point: the page derives its three closed forms by integrating the
    Coriolis acceleration twice along the unperturbed trajectory, and the
    only way to catch an error in that derivation is to not use it. The
    integrator below knows a = -2*Omega x V and gravity and nothing else.

    What is checked:

      1. ALL THREE COMPONENTS, against the integration, at a spread of
         latitudes and bearings - and the two corrections a gun captain
         actually applies, the drift across the track and the change in
         range, which are what the components add up to.

      2. THE TURNING TERM is bearing-independent, reverses with
         hemisphere, and goes as sin(latitude). Unchanged, because it is
         still true and still the lesson's spine.

      3. THE EOETVOES TERM is exactly zero due north and due south,
         largest on the equator, and reverses between east and west. If
         it ever became bearing-independent the lesson would be wrong
         again in the way that prompted this.

      4. THE CLIMB-AND-FALL TERM does NOT reverse with hemisphere, which
         is the one genuinely counter-intuitive thing here: cos(latitude)
         is positive on both sides of the equator. It is why the southern
         hemisphere is not quite the mirror of the northern.

      5. THE EQUATOR still says why there is no cyclone there, and no
         longer claims the shell lands where it was aimed - it does not;
         fired north on the equator it goes 87 m west, all of it the
         climb-and-fall term.

      6. THE DRAWING agrees with the words: the fall is on the side the
         readout states, and further out or shorter as the range line says.

      node weather-gun.js   (needs the server on $PORT)  */
'use strict';
const { chromium } = require('playwright');
const BASE = 'http://127.0.0.1:' + (process.env.PORT || 8090) + '/weather/';

const OMEGA = 7.292115e-5, G = 9.80665;

/*  THE INDEPENDENT ANSWER. Integrate the real equations in the rotating
    frame: local axes east, north, up; Omega = Omega*(0, cos phi, sin phi);
    a = -2*Omega x V - g. Launched along the given bearing with the
    horizontal speed and the vertical speed that would put the shell at
    `range` after `tof` with no rotation at all, so the perturbation is
    measured against the trajectory the lesson's own numbers describe.

    Returned relative to the LINE OF FIRE: drift positive to the right of
    it, along positive beyond the nominal range.  */
function fly(latDeg, brgDeg, range, tof) {
  const phi = latDeg * Math.PI / 180, b = brgDeg * Math.PI / 180;
  const Vh = range / tof, w0 = G * tof / 2;
  const Oy = OMEGA * Math.cos(phi), Oz = OMEGA * Math.sin(phi);
  let u = Vh * Math.sin(b), v = Vh * Math.cos(b), w = w0;
  let x = 0, y = 0, z = 0, t = 0;
  const dt = 0.002;
  const acc = (u, v, w) => [-2 * (Oy * w - Oz * v), -2 * (Oz * u), -2 * (-Oy * u) - G];
  for (;;) {
    const [ax, ay, az] = acc(u, v, w);
    const nz = z + w * dt + 0.5 * az * dt * dt;
    if (nz <= 0 && t > 1) {
      /*  land exactly: the fraction of this step at which z crosses zero  */
      const f = z / (z - nz);
      x += (u * dt + 0.5 * ax * dt * dt) * f;
      y += (v * dt + 0.5 * ay * dt * dt) * f;
      t += dt * f;
      break;
    }
    x += u * dt + 0.5 * ax * dt * dt;
    y += v * dt + 0.5 * ay * dt * dt;
    z = nz;
    const [bx, by, bz] = acc(u + ax * dt, v + ay * dt, w + az * dt);
    u += 0.5 * (ax + bx) * dt; v += 0.5 * (ay + by) * dt; w += 0.5 * (az + bz) * dt;
    t += dt;
  }
  const sb = Math.sin(b), cb = Math.cos(b);
  return { drift: x * cb - y * sb, along: (x * sb + y * cb) - range, tof: t };
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
  is('three components are named', await page.evaluate(
    () => document.querySelectorAll('.guncomp .gcrow').length), 3);

  /*  the gun's own figures, read off the page rather than assumed, so a
      change to the shell or the range is picked up instead of hidden  */
  const gun = await page.evaluate(() => ({ range: GUN.range, tof: GUN.tof }));

  const read = async (brg, lat) => page.evaluate(([b, l]) => {
    const f = (id, v) => { const e = document.getElementById(id); e.value = v;
      e.dispatchEvent(new Event('input', { bubbles: true })); };
    f('gun-brg', b); f('gun-lat', l);
    const t = document.querySelector('.gunread').textContent;
    const md = /falls (\d+(?:\.\d+)?) m to the (RIGHT|LEFT)/.exec(t);
    const ma = /(\d+(?:\.\d+)?) m (LONG|SHORT)/.exec(t);
    /*  the component rows, by the name each one carries, so a reordering
        of the list cannot quietly swap two readings  */
    const comp = {};
    Array.prototype.forEach.call(document.querySelectorAll('.guncomp .gcrow'), function (r) {
      comp[r.querySelector('.gcn').textContent] = r.querySelector('.gcv').textContent;
    });
    const svg = document.querySelector('.gundemo svg');
    const q = s => svg.querySelector('[data-pt="' + s + '"]');
    const pt = s => [ +q(s).getAttribute('cx'), +q(s).getAttribute('cy') ];
    return { text: t, comp: comp,
             drift: md ? +md[1] * (md[2] === 'RIGHT' ? 1 : -1)
                        : (/falls where it was aimed/.test(t) ? 0 : null),
             along: ma ? +ma[1] * (ma[2] === 'LONG' ? 1 : -1) : 0,
             aim: pt('aim'), fall: pt('fall'),
             lat: +document.getElementById('gun-lat').value,
             brg: +document.getElementById('gun-brg').value };
  }, [brg, lat]);

  /*  a component row, as a signed number in the direction the check
      expects: 'right' positive for the turning term, 'long' positive for
      the Eoetvoes term, 'west' always positive for the third.  */
  function comp(r, name, pos) {
    const t = r.comp[name];
    if (t === undefined) { checks++; bad++; console.log('  FAIL no row named ' + name); return NaN; }
    if (/nothing here/.test(t)) return 0;
    const m = /(\d+(?:\.\d+)?) m (\w+)/.exec(t);
    if (!m) { checks++; bad++; console.log('  FAIL unreadable row ' + name + ': ' + t); return NaN; }
    return +m[1] * (m[2] === pos ? 1 : -1);
  }
  const TURN = 'turning with the earth', EOT = 'the Eötvös effect',
        RISE = 'its own climb and fall';

  /* ---- 1. the two corrections, against the integration ----------- */
  for (const [brg, lat] of [[0, 45], [90, 45], [-90, 45], [45, 45], [-30, 20],
                            [0, 0], [90, 0], [0, 80], [90, 80],
                            [0, -45], [90, -45], [-60, -70]]) {
    const r = await read(brg, lat);
    const f = fly(r.lat, r.brg, gun.range, gun.tof);
    /*  WHY THE TOLERANCE IS 2.5 METRES AND NOT A ROUNDING ALLOWANCE. The
        page's three closed forms are the FIRST-ORDER perturbation -
        Coriolis evaluated along the unperturbed trajectory - while this
        integrator solves the same model exactly, so the two differ by the
        second-order terms the derivation drops. Swept over every setting
        the sliders can reach, the worst disagreement is 1.39 m of drift
        and 1.67 m of range; the page rounds to the metre on top of that.
        2.5 m is that bound, not a number chosen to make this pass: at 1.5
        it failed on four settings and every one of them was the
        truncation rather than a fault.  */
    near('drift at brg ' + r.brg + ' lat ' + r.lat, r.drift, f.drift, 2.5);
    near('range change at brg ' + r.brg + ' lat ' + r.lat, r.along, f.along, 2.5);
    /*  and the components must ADD UP to what is reported, or the rows
        are decoration rather than a decomposition. Three displayed values
        each rounded to the metre, so the slack is 1.6 and not 1.0.  */
    const b = r.brg * Math.PI / 180;
    near('the components add up across, brg ' + r.brg + ' lat ' + r.lat,
         comp(r, TURN, 'right') - comp(r, RISE, 'west') * Math.cos(b), r.drift, 1.6);
    near('the components add up along, brg ' + r.brg + ' lat ' + r.lat,
         comp(r, EOT, 'long') - comp(r, RISE, 'west') * Math.sin(b), r.along, 1.6);
  }

  /* ---- 2. the turning term: bearing-blind, sin(lat), reversing --- */
  const t45 = comp(await read(0, 45), TURN, 'right');
  for (const brg of [-90, -45, -17, 0, 23, 45, 90]) {
    near('the turning term at brg ' + brg + ', 45 N', comp(await read(brg, 45), TURN, 'right'),
         t45, 0.6);
  }
  for (const lat of [10, 30, 45, 66, 80]) {
    const n = await read(0, lat), s = await read(0, -lat);
    near('turning at ' + n.lat + ' S mirrors ' + n.lat + ' N',
         comp(s, TURN, 'right'), -comp(n, TURN, 'right'), 0.6);
  }
  near('30 N is half the pole, as sin says', comp(await read(0, 30), TURN, 'right'),
       0.5 * OMEGA * (gun.range / gun.tof) * gun.tof * gun.tof, 1.0);

  /* ---- 3. Eoetvoes: east-west only, largest on the equator -------- */
  for (const lat of [0, 20, 45, 70, -45]) {
    is('no Eoetvoes due north at ' + lat, comp(await read(0, lat), EOT, 'long') === 0, true);
    const e = comp(await read(90, lat), EOT, 'long'), w = comp(await read(-90, lat), EOT, 'long');
    near('east and west are opposite at ' + lat, e, -w, 0.6);
    /*  cos(latitude) is positive on both sides, so fired east carries
        LONG in both hemispheres - this term does not reverse either  */
    checks++;
    if (!(e > 0)) { bad++; console.log('  FAIL fired east at ' + lat + ' does not carry long'); }
  }
  near('Eoetvoes is largest on the equator',
       comp(await read(90, 0), EOT, 'long'),
       2 * OMEGA * (gun.range / gun.tof) * gun.tof * (gun.range / gun.tof) / G, 1.0);
  //  and it must NOT be bearing-blind, which is the fault that started this
  checks++;
  {
    const n = comp(await read(0, 45), EOT, 'long'), e = comp(await read(90, 45), EOT, 'long');
    if (!(Math.abs(e - n) > 50)) {
      bad++; console.log('  FAIL the Eoetvoes term does not depend on bearing - it must');
    }
  }

  /* ---- 4. climb and fall does not reverse with hemisphere -------- */
  for (const lat of [0, 30, 60, 80]) {
    const n = comp(await read(0, lat), RISE, 'west'), s = comp(await read(0, -lat), RISE, 'west');
    near('climb-and-fall at ' + lat + ' S equals ' + lat + ' N, not its negative', s, n, 0.6);
    checks++;
    if (!(n > 0)) { bad++; console.log('  FAIL the climb-and-fall term is not westward at ' + lat); }
  }
  near('climb and fall is largest on the equator', comp(await read(0, 0), RISE, 'west'),
       OMEGA * G * Math.pow(gun.tof, 3) / 6, 1.0);

  /* ---- 5. the equator says why, and no longer claims no deflection */
  {
    const r = await read(0, 0);
    checks++;
    if (!/sin\(latitude\) is zero/.test(r.text)) {
      bad++; console.log('  FAIL the equator readout does not say why nothing turns it');
    }
    checks++;
    if (/falls where it was aimed/.test(r.text)) {
      bad++; console.log('  FAIL the equator still claims the shell lands on the aim');
    }
    near('fired north on the equator it goes west', r.drift, fly(0, 0, gun.range, gun.tof).drift, 1.5);
  }

  /* ---- 6. the drawing agrees with the words ---------------------- */
  for (const [brg, lat] of [[0, 45], [90, 45], [-90, 45], [0, -45], [90, 0]]) {
    const r = await read(brg, lat);
    const a = brg * Math.PI / 180;
    const ux = Math.sin(a), uy = -Math.cos(a);        /* along the line of fire */
    const vx = r.fall[0] - r.aim[0], vy = r.fall[1] - r.aim[1];
    const cross = ux * vy - uy * vx;                  /* >0 is screen-right of it */
    const alongPx = ux * vx + uy * vy;                /* >0 is beyond the aim     */
    if (Math.abs(r.drift) >= 0.5)
      is('the drawing puts the fall on the ' + (r.drift > 0 ? 'RIGHT' : 'LEFT') +
         ' at brg ' + brg + ' lat ' + lat,
         cross > 0 ? 'RIGHT' : 'LEFT', r.drift > 0 ? 'RIGHT' : 'LEFT');
    if (Math.abs(r.along) >= 0.5)
      is('the drawing puts the fall ' + (r.along > 0 ? 'LONG' : 'SHORT') +
         ' at brg ' + brg + ' lat ' + lat,
         alongPx > 0 ? 'LONG' : 'SHORT', r.along > 0 ? 'LONG' : 'SHORT');
  }

  if (errs.length) { bad++; console.log('  FAIL page errors: ' + errs.join(' | ')); }
  await browser.close();
  console.log('  ' + checks + ' checks on the gunnery demonstration' + (bad ? '' : ', all agree'));
  if (bad) { console.log('  ' + bad + ' FAILED'); process.exit(1); }
})().catch(e => { console.error(e); process.exit(2); });
