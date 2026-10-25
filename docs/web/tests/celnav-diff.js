/*  The browser celnav build's sight reduction and fix, against the awk
    engine's own numbers, over whole generated cases.

    WHY WHOLE CASES AND NOT PIECES.  Every piece of this was already
    right: body_at(), corrections() and reduce_sight() agree with the awk
    to nine decimals, and did before this harness existed.  What shipped
    wrong was the DRIVING of them.  plot.js used solve_fix()'s first pass
    as the fix, and solve_fix() linearises the reduction about the
    position it is handed - so the answer was right to 0.02 nm from a
    live DR and 43 nm out from a DR five degrees away.  A module diff
    sees none of that.  Only the fix, from a spread of DRs, does.

    So the comparison runs the whole way through: the per-sight working
    from the DR, the converged fix, the normal matrix at the fix, and each
    LOP's residual.  The reference comes from engine.awk calling its own
    converge_fix(), which cmd_reduce() also calls - not from a second
    convergence typed into the test.

    The SHIPPED files under docs/web/celnav/ are loaded, so a stale copy
    cannot pass.

    Tolerances are libm-versus-V8 noise and nothing more: the two
    implementations are the same arithmetic in the same order, but sin,
    cos and sqrt are not required to agree in the last bit.  1e-7 of a
    degree is 0.000006 of a minute of arc and 1e-5 nm is two centimetres,
    so the bug this exists to catch - 0.016 nm at best, 43 nm at worst -
    fails these by four orders of magnitude.  */
'use strict';
const fs = require('fs'), path = require('path');
const W = path.resolve(__dirname, '..', 'celnav');

global.window = {};
require(path.join(W, 'tables.js'));              // sets window.CELNAV_TABLES
const { makeCelnav } = require(path.join(W, 'engine.js'));
const { extendCelnav } = require(path.join(W, 'engine2.js'));
require(path.join(W, 'plot.js'));                // sets window.CELPLOT
const CN = extendCelnav(makeCelnav(global.window.CELNAV_TABLES));
const PLOT = global.window.CELPLOT;

const TOL = { ang: 1e-7, nm: 1e-5, jd: 1e-9 };
const refFile = process.argv[2];
if (!refFile) { console.error('usage: celnav-diff.js ref.tsv'); process.exit(2); }

/* ---- read the reference ------------------------------------------- */
const cases = new Map();
const C = id => {
  if (!cases.has(id)) cases.set(id, { sgt: [], lop: [], res: [] });
  return cases.get(id);
};
for (const line of fs.readFileSync(refFile, 'utf8').split('\n')) {
  if (!line) continue;
  const f = line.split('\t'), id = f[1], k = C(id);
  const n = i => parseFloat(f[i]);
  if (f[0] === 'CASE') { k.dr = { lat: n(2), lon: n(3), spd: n(4), crs: n(5), fixjd: n(6), ns: n(7) }; }
  else if (f[0] === 'SGT') k.sgt[n(2) - 1] = { utc: f[3], body: f[4], jd: n(5), hs: n(6),
                                               ie: n(7), he: n(8), tm: n(9), pr: n(10), limb: f[11] };
  else if (f[0] === 'LOP') k.lop[n(2) - 1] = { ho: n(3), hc: n(4), zn: n(5), intercept: n(6),
                                               apLat: n(7), apLon: n(8), lha: n(9), gha: n(10),
                                               dec: n(11), run: n(12) };
  else if (f[0] === 'RES') k.res[n(2) - 1] = n(3);
  else if (f[0] === 'NRM') k.nrm = { a: n(2), b: n(3), c: n(4), det: n(5) };
  else if (f[0] === 'FIX') k.fix = { ok: n(2), lat: n(3), lon: n(4), N: n(5), E: n(6),
                                     shift: n(7), rms: n(8) };
  else if (f[0] === 'LAN') k.lan = n(2);
  else if (f[0] === 'POL') k.pol = [n(2), n(3), n(4)];
}

/* ---- compare ------------------------------------------------------- */
let checks = 0, bad = 0;
const worst = {};
function cmp(id, what, got, want, tol) {
  checks++;
  if (!isFinite(got) || !isFinite(want)) { bad++; report(id, what, got, want); return; }
  const d = Math.abs(got - want);
  const kind = tol === TOL.nm ? 'nm' : tol === TOL.jd ? 'jd' : 'deg';
  if (!(worst[kind] >= d)) worst[kind] = d;
  if (d > tol) { bad++; report(id, what, got, want, d); }
}
function report(id, what, got, want, d) {
  if (bad <= 25)
    console.log('  FAIL case ' + id + '  ' + what +
                '\n        awk ' + want + '\n        js  ' + got +
                (d === undefined ? '' : '\n        off by ' + d.toExponential(3)));
}

for (const [id, k] of cases) {
  if (!k.dr || !k.fix) continue;

  /* the sight list, exactly as the awk built it.  parse_utc is checked
     here rather than assumed: the harness feeds the UT STRING and holds
     the resulting julian date to the awk's. */
  PLOT.clear();
  k.sgt.forEach(s => {
    cmp(id, 'parse_utc(' + s.utc + ')', CN.parse_utc(s.utc), s.jd, TOL.jd);
    PLOT.add({ body: s.body, utc: s.utc, jd: s.jd, hs: s.hs, ie: s.ie,
               he: s.he, tm: s.tm, pr: s.pr, limb: s.limb });
  });

  const sol = PLOT.solve(CN, k.dr.lat, k.dr.lon, k.dr.spd, k.dr.crs);
  checks++;
  if (!sol) { bad++; console.log('  FAIL case ' + id + ': no solution object'); continue; }
  cmp(id, 'ok', sol.ok, k.fix.ok, 0);
  if (!k.fix.ok) continue;

  k.lop.forEach((L, i) => {
    const g = sol.lops[i];
    if (!g) { checks++; bad++; report(id, 'LOP ' + (i + 1) + ' missing', 'absent', 'present'); return; }
    ['ho', 'hc', 'zn', 'lha', 'gha', 'dec', 'apLat', 'apLon'].forEach(
      key => cmp(id, 'sight ' + (i + 1) + ' ' + key, g[key], L[key], TOL.ang));
    cmp(id, 'sight ' + (i + 1) + ' intercept', g.intercept, L.intercept, TOL.nm);
    cmp(id, 'sight ' + (i + 1) + ' run', g.run, L.run, TOL.nm);
  });

  /*  the two engine functions the noon and Polaris screens rest on.
      lan_jd is a julian date, so it is held to the jd tolerance - a
      millisecond is 1.2e-8 of a day and this is far tighter than that.  */
  if (k.lan !== undefined)
    cmp(id, 'lan_jd', CN.lan_jd(k.dr.lon, Math.floor(k.dr.fixjd + 0.5) - 0.5), k.lan, TOL.jd);
  if (k.pol) {
    const n360 = CN.nrm360;
    cmp(id, 'pol_lat a', CN.pol_lat(48.2, 89.37, n360(343.0 + k.dr.lon)), k.pol[0], TOL.ang);
    cmp(id, 'pol_lat b', CN.pol_lat(Math.abs(k.dr.lat), 89.37, n360(k.sgt[0].jd * 13.0 + k.dr.lon)), k.pol[1], TOL.ang);
    cmp(id, 'pol_lat c', CN.pol_lat(Math.abs(k.dr.lat) / 2 + 10, 89.0, n360(k.dr.lon * 3)), k.pol[2], TOL.ang);
  }
  cmp(id, 'FIX lat', sol.lat, k.fix.lat, TOL.ang);
  cmp(id, 'FIX lon', sol.lon, k.fix.lon, TOL.ang);
  cmp(id, 'offset N', sol.N, k.fix.N, TOL.nm);
  cmp(id, 'offset E', sol.E, k.fix.E, TOL.nm);
  cmp(id, 'convergence shift', sol.shift, k.fix.shift, TOL.nm);
  cmp(id, 'RMS', sol.rms, k.fix.rms, TOL.nm);
  if (k.nrm) {
    cmp(id, 'NM_A', CN.E.NM_A, k.nrm.a, TOL.ang);
    cmp(id, 'NM_B', CN.E.NM_B, k.nrm.b, TOL.ang);
    cmp(id, 'NM_C', CN.E.NM_C, k.nrm.c, TOL.ang);
    cmp(id, 'NM_DET', CN.E.NM_DET, k.nrm.det, TOL.ang);
  }
  k.res.forEach((r, i) => cmp(id, 'residual ' + (i + 1), sol.resid[i], r, TOL.nm));
}

console.log('  ' + cases.size + ' cases, ' + checks + ' checks' +
            '\n  worst disagreement:  ' +
            Object.keys(worst).sort().map(k => k + ' ' + worst[k].toExponential(2)).join('   '));
if (bad) { console.log('\n  ' + bad + ' PROBLEMS'); process.exit(1); }
console.log('  all agree');
