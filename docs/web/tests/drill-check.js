/*  The drill generator, browser against awk, seed for seed.

    A seed is the problem's NAME. "drill red 4821" has to be the same
    sight in both, or a navigator working a drill on an iPad and checking
    it at a terminal gets two different right answers. That makes the
    pseudo-random sequence part of the specification and not an
    implementation detail, so this compares every value the generator
    produces - including WHICH BODY it picked, by name, and which seeds
    failed to produce a usable problem at all.

      awk -v N=400 -f engine.awk -f teach.awk -f drill-ref.awk | drill-check.js  */
'use strict';
const fs = require('fs');
const { makeCelnav } = require('../celnav/engine.js');
const { extendCelnav } = require('../celnav/engine2.js');
global.window = {};
// eslint-disable-next-line no-eval
eval(fs.readFileSync(__dirname + '/../celnav/tables.js', 'utf8'));
const CN = extendCelnav(makeCelnav(global.window.CELNAV_TABLES));

const TOL = { ang: 1e-7, jd: 1e-9, nm: 1e-5 };
let checks = 0, bad = 0, worst = 0, gen = 0, fails = 0;
function cmp(what, got, want, tol) {
  checks++;
  if (!isFinite(got) || !isFinite(want)) {
    bad++;
    if (bad <= 15) console.log('  FAIL ' + what + ': got ' + got + ', want ' + want);
    return;
  }
  const d = Math.abs(got - want);
  if (d > worst) worst = d;
  if (d > tol) {
    bad++;
    if (bad <= 15) console.log('  FAIL ' + what + ': got ' + got + ', want ' + want +
                               ', off by ' + d.toExponential(3));
  }
}
function same(what, got, want) {
  checks++;
  if (String(got) !== String(want)) {
    bad++;
    if (bad <= 15) console.log('  FAIL ' + what + ': got ' + JSON.stringify(got) +
                               ', want ' + JSON.stringify(want));
  }
}

const seeds = {};
for (const line of fs.readFileSync(process.argv[2] || 0, 'utf8').split('\n')) {
  if (!line.trim()) continue;
  const f = line.split('\t');
  const n = i => +f[i];
  const s = (seeds[f[1]] = seeds[f[1]] || { seed: +f[1] });
  if (f[0] === 'GEN') {
    s.gen = { lat: n(2), lon: n(3), ie: n(4), he: n(5), t: n(6), p: n(7),
              body: f[8], name: f[9], limb: f[10], jd: n(11), gha: n(12), dec: n(13),
              sd: n(14), hp: n(15), hc: n(16), zn: n(17), off: n(18), hs: n(19) };
  } else if (f[0] === 'GENU') { s.utc = f[2]; }
  else if (f[0] === 'GENFAIL') { s.genfail = true; }
  else if (f[0] === 'FIXG') {
    s.fix = { lat: n(2), lon: n(3), fixlat: n(4), fixlon: n(5), N: n(6), E: n(7), lops: [] };
  } else if (f[0] === 'FIXL') {
    s.fix.lops[+f[2] - 1] = { zn: n(3), p: n(4), name: f[5] };
  }
}

for (const key of Object.keys(seeds)) {
  const k = seeds[key], id = 'seed ' + k.seed;
  const D = CN.drill_gen('full', k.seed);

  /*  WHICH SEEDS FAIL IS PART OF THE ANSWER. Eighty tries without a body
      between 12 and 72 degrees is a real outcome, and a port that
      produced a problem there - or failed where the awk succeeded - would
      hand out a different set of drills.  */
  checks++;
  if (!!k.genfail !== !D) {
    bad++;
    console.log('  FAIL ' + id + ': the awk ' + (k.genfail ? 'failed' : 'generated') +
                ' and the browser ' + (D ? 'generated' : 'failed'));
    continue;
  }
  if (k.genfail) { fails++; continue; }
  gen++;

  const g = k.gen;
  same(id + ' body', D.BODY, g.body);
  same(id + ' name', D.NAME, g.name);
  same(id + ' limb', D.LIMB, g.limb);
  same(id + ' UTC', D.UTC, k.utc);
  cmp(id + ' DR latitude', D.LAT, g.lat, TOL.ang);
  cmp(id + ' DR longitude', D.LON, g.lon, TOL.ang);
  cmp(id + ' index error', D.IE, g.ie, TOL.ang);
  cmp(id + ' height of eye', D.HE, g.he, TOL.ang);
  cmp(id + ' temperature', D.T, g.t, 0);
  cmp(id + ' pressure', D.P, g.p, 0);
  cmp(id + ' JD', D.JD, g.jd, TOL.jd);
  cmp(id + ' GHA', D.GHA, g.gha, TOL.ang);
  cmp(id + ' declination', D.DEC, g.dec, TOL.ang);
  cmp(id + ' semi-diameter', D.SD, g.sd, TOL.ang);
  cmp(id + ' horizontal parallax', D.HP, g.hp, TOL.ang);
  cmp(id + ' Hc', D.HC, g.hc, TOL.ang);
  cmp(id + ' Zn', D.ZN, g.zn, TOL.ang);
  cmp(id + ' intercept', D.OFF, g.off, TOL.ang);
  //  Hs is twelve passes backwards through the correction chain, so it
  //  carries the most accumulated arithmetic of anything here
  cmp(id + ' Hs', D.HS, g.hs, TOL.ang);

  const F = CN.fix_gen(k.seed), fx = k.fix;
  cmp(id + ' fix DR latitude', F.LAT, fx.lat, TOL.ang);
  cmp(id + ' fix DR longitude', F.LON, fx.lon, TOL.ang);
  for (let i = 0; i < 3; i++) {
    same(id + ' fix body ' + (i + 1), F.N[i], fx.lops[i].name);
    cmp(id + ' fix Zn ' + (i + 1), F.Z[i], fx.lops[i].zn, TOL.ang);
    cmp(id + ' fix intercept ' + (i + 1), F.P[i], fx.lops[i].p, TOL.ang);
  }
  cmp(id + ' fix north', F.SOL_N, fx.N, TOL.nm);
  cmp(id + ' fix east', F.SOL_E, fx.E, TOL.nm);
  cmp(id + ' fix latitude', F.FIXLAT, fx.fixlat, TOL.ang);
  cmp(id + ' fix longitude', F.FIXLON, fx.fixlon, TOL.ang);
}

console.log('    ' + Object.keys(seeds).length + ' seeds (' + gen + ' usable, ' + fails +
            ' the generator refused), ' + checks + ' checks');
console.log('    worst disagreement: ' + worst.toExponential(2));
if (bad) { console.log('    ' + bad + ' PROBLEMS'); process.exit(1); }
console.log('    all agree');
