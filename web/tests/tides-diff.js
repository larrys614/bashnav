// Diff the JS tide engine against the awk engine's own dump.
// The engine under test is the SHIPPED copy under web/, so this cannot
// pass against a stale file.
'use strict';
var fs = require('fs');
var path = require('path');
// Resolved from this file's own location: the harness must test the
// SHIPPED copies under web/tides/, so a stale file cannot pass.
var REPO = path.resolve(__dirname, '..', '..');
var ROOT = path.join(REPO, 'web', 'tides') + path.sep;
var tabs = require(ROOT + 'tables.js');
global.TT_CONST = tabs.TT_CONST; global.TT_SAT = tabs.TT_SAT; global.TT_SHAL = tabs.TT_SHAL;
var TIDE = require(ROOT + 'engine.js');

var refFile = process.argv[2] || 'ref.tsv';
var stFile = path.join(REPO, 'src', 'tides', 'stations.dat');

// ---- load the station file ------------------------------------------
var want = {}, lines = fs.readFileSync(refFile, 'utf8').split('\n');
lines.forEach(function (L) {
  var f = L.split('\t');
  if (f.length > 2) want[f[1]] = 1;
});
var stations = {};
fs.readFileSync(stFile, 'utf8').split('\n').forEach(function (L) {
  if (!L || L[0] === '#') return;
  var id = L.split('|')[1];
  if (want[id]) stations[id] = L;
});
// subordinates need their reference too
Object.keys(stations).forEach(function (id) {
  var st = TIDE.parseStation(stations[id]);
  if (st && st.kind === 'S') want[st.ref] = 1;
});
fs.readFileSync(stFile, 'utf8').split('\n').forEach(function (L) {
  if (!L || L[0] === '#') return;
  var id = L.split('|')[1];
  if (want[id] && !stations[id]) stations[id] = L;
});

// ---- rebuild each (station, date) and compare ------------------------
var cache = {}, worst = {}, counts = {}, fails = [];
function note(cat, err, where) {
  counts[cat] = (counts[cat] || 0) + 1;
  if (!worst[cat] || err > worst[cat].err) worst[cat] = { err: err, where: where };
}
function pred(id, date) {
  var key = id + '\t' + date;
  if (cache[key]) return cache[key];
  var st = TIDE.parseStation(stations[id]);
  var ref = (st && st.kind === 'S') ? TIDE.parseStation(stations[st.ref]) : null;
  var ymd = date.split('-');
  var jd0 = TIDE.jdate(+ymd[0], +ymd[1], +ymd[2]);
  var P = TIDE.open(st, ref, jd0 + 0.5);
  P.curvePrep(jd0, jd0 + 1);
  var hl = P.hilo(jd0, jd0 + 1);
  cache[key] = { P: P, jd0: jd0, hl: hl };
  return cache[key];
}


//  The awk dump writes -1 when a body does not cross the altitude that
//  day -- which happens, and not only in polar latitudes: the moon skips
//  a rising roughly every 25 days everywhere.
var evCache = {};
function ev(p, which, h0) {
  // The key MUST carry the position.  Keyed on the date alone, the first
  // station computed for a date answered for every other station that day,
  // and the diff reported a whole-day error in the engine.  It was the
  // cache.
  var k = p.jd0 + '|' + which + '|' + h0 + '|' + p.P.lat + '|' + p.P.lon;
  if (!evCache[k]) {
    var r = TIDE.riseSet(p.jd0, p.P.lat, p.P.lon, which, h0);
    evCache[k] = { rise: r.rise === null ? -1 : r.rise - p.jd0,
                   set:  r.set  === null ? -1 : r.set  - p.jd0 };
  }
  return evCache[k];
}

lines.forEach(function (L, ln) {
  var f = L.split('\t');
  if (f.length < 4) return;
  var tag = f[0], id = f[1], date = f[2];
  var p, got, exp, i;
  try { p = pred(id, date); } catch (e) { fails.push('line ' + ln + ': ' + e.message); return; }
  var P = p.P;
  switch (tag) {
    case 'ST':
      if (P.kind !== f[3]) fails.push(id + ' kind ' + P.kind + ' != ' + f[3]);
      if (P.datum !== f[4]) fails.push(id + ' datum ' + P.datum + ' != ' + f[4]);
      return;
    case 'LAT': note('lat', Math.abs(P.lat - (+f[3])), id); return;
    case 'N':
      if (P._n !== +f[3]) fails.push(id + ' n ' + P._n + ' != ' + f[3]);
      return;
    case 'C':
      i = +f[3];
      if (P._c[i] !== +f[4]) fails.push(id + ' c[' + i + '] ' + P._c[i] + ' != ' + f[4]);
      return;
    case 'CF': i = +f[3]; got = P._f[P._c[i]]; break;
    case 'CU': i = +f[3]; got = P._u[P._c[i]]; break;
    case 'CV': i = +f[3]; got = P._v[P._c[i]]; break;
    case 'CW': i = +f[3]; got = P._w[P._c[i]]; break;
    case 'AMP': i = +f[3]; got = P._amp[i]; break;
    case 'PHA': i = +f[3]; got = P._p[i]; break;
    case 'H': got = P.height(p.jd0 + (+f[3]) * 13.0 / 1440.0); break;
    case 'MPE': got = TIDE.moonPhase(p.jd0 + 0.5).elong; break;
    case 'MPA': got = TIDE.moonPhase(p.jd0 + 0.5).age; break;
    case 'MPI': got = TIDE.moonPhase(p.jd0 + 0.5).illum; break;
    case 'MPN':
      if (TIDE.moonPhase(p.jd0 + 0.5).name !== f[3]) fails.push(id + ' ' + date + ' phase name');
      return;
    case 'MPT':
      if (TIDE.moonPhase(p.jd0 + 0.5).tide !== f[3]) fails.push(id + ' ' + date + ' springs/neaps');
      return;
    case 'SR': got = ev(p, 'sun', -0.833).rise; break;
    case 'SS': got = ev(p, 'sun', -0.833).set; break;
    case 'MR': got = ev(p, 'moon', -0.833).rise; break;
    case 'MS': got = ev(p, 'moon', -0.833).set; break;
    case 'CT': got = ev(p, 'sun', -6).rise; break;
    case 'ALS': got = TIDE.altOf('sun',  p.jd0 + (+f[3]) * 97.0 / 1440.0, P.lat, P.lon); break;
    case 'ALM': got = TIDE.altOf('moon', p.jd0 + (+f[3]) * 97.0 / 1440.0, P.lat, P.lon); break;
    case 'HLN':
      if (p.hl.length !== +f[3]) fails.push(id + ' ' + date + ' hilo count ' + p.hl.length + ' != ' + f[3]);
      return;
    case 'HLT': i = +f[3]; got = p.hl[i - 1] ? p.hl[i - 1].t - p.jd0 : NaN; break;
    case 'HLH': i = +f[3]; got = p.hl[i - 1] ? p.hl[i - 1].h : NaN; break;
    case 'HLK':
      i = +f[3];
      if (!p.hl[i - 1] || p.hl[i - 1].k !== f[4]) fails.push(id + ' ' + date + ' hilo kind ' + i);
      return;
    default: return;
  }
  exp = +f[f.length - 1];
  if (!isFinite(got)) { fails.push(tag + ' ' + id + ' ' + date + ' ' + f[3] + ' got ' + got); return; }
  var err = Math.abs(got - exp);
  if (tag === 'HLT' || tag === 'SR' || tag === 'SS' || tag === 'MR'
      || tag === 'MS' || tag === 'CT') err = err * 86400;   // seconds
  note(tag, err, id + ' ' + date + ' #' + f[3]);
});

// ---- report ----------------------------------------------------------
var UNIT = { lat: 'deg', CF: '-', CU: 'cycles', CV: 'cycles', CW: 'cyc/day',
             AMP: 'm', PHA: 'deg', H: 'm', HLT: 's', HLH: 'm',
             MPE: 'deg', MPA: 'days', MPI: '-', SR: 's', SS: 's', MR: 's',
             MS: 's', CT: 's', ALS: 'deg', ALM: 'deg' };
// Tolerances are set by what the quantity MEANS, not by what the port
// happens to achieve.  awk uses the platform libm for sin/cos/atan2/exp/log;
// V8 uses its own fdlibm, so the last bit or two will differ and bit-equality
// is not the right test.  A millisecond on a tide time and a nanometre on a
// tide height are both far below anything the harmonics themselves can claim.
var TOL = { lat: 0, CF: 1e-12, CU: 1e-12, CV: 1e-12, CW: 1e-13,
            AMP: 1e-12, PHA: 0, H: 1e-9, HLT: 1e-3, HLH: 1e-9,
            MPE: 1e-9, MPA: 1e-9, MPI: 1e-12,
            SR: 1e-3, SS: 1e-3, MR: 1e-3, MS: 1e-3, CT: 1e-3,
            ALS: 1e-9, ALM: 1e-9 };
console.log('ref file: ' + refFile + '   (station,date) pairs: ' + Object.keys(cache).length);
console.log('');
console.log('  quantity      compared       worst error      unit      tol      verdict');
var bad = 0;
Object.keys(counts).sort().forEach(function (k) {
  var w = worst[k], t = TOL[k] === undefined ? 1e-9 : TOL[k];
  var ok = w.err <= t;
  if (!ok) bad++;
  console.log('  ' + k.padEnd(12) + String(counts[k]).padStart(9) +
    '   ' + w.err.toExponential(3).padStart(13) +
    '   ' + (UNIT[k] || '').padEnd(9) + t.toExponential(0).padStart(7) +
    '   ' + (ok ? 'ok' : 'FAIL  <- ' + w.where));
});
console.log('');
if (fails.length) {
  console.log('STRUCTURAL FAILURES (' + fails.length + '):');
  fails.slice(0, 20).forEach(function (s) { console.log('  ' + s); });
  process.exit(1);
}
if (bad) { console.log(bad + ' quantities outside tolerance'); process.exit(1); }
console.log('all quantities within tolerance');
