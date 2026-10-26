const path = require('path');
/*  Score the same logs with both engines.  The score sheet is a table of
    weighted error points -- low wins -- and the wording matters as much
    as the arithmetic, so it is compared character for character. */
'use strict';
const fs = require('fs');
const { execFileSync } = require('child_process');
const REPO = path.resolve(__dirname, '..', '..', '..');
const W = path.resolve(__dirname, '..');
global.LOG = require(path.join(W, 'deck-log', 'log.js'));
global.WX = require(path.join(W, 'weather', 'wx.js'));
const SCORE = require(path.join(W, 'weather', 'score.js'));

function awkScore(logfile) {
  return execFileSync('mawk', ['-v', 'cmode=plain', '-v', 'LOG=' + logfile, '-v', 'cmd=score',
    '-f', REPO + '/src/common/log.awk', '-f', REPO + '/src/common/colour.awk',
    '-f', REPO + '/src/weather/grid.awk', '-f', REPO + '/src/weather/wx.awk', '-f', REPO + '/src/weather/score.awk',
    '-f', REPO + '/src/weather/chart.awk', '-f', REPO + '/src/weather/teach.awk',
    '-f', REPO + '/src/weather/screens.awk'], { input: '', encoding: 'utf8' });
}
function rnd(seed) { let s = seed >>> 0; return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 4294967296); }

function gen(seed) {
  const r = rnd(seed), lines = [];
  const n = 3 + Math.floor(r() * 12);
  let p = 995 + r() * 30, wd = Math.floor(r() * 360);
  const lat = (20 + r() * 40).toFixed(3), lon = (-80 + r() * 20).toFixed(2);
  const stamps = [];
  for (let i = 0; i < n; i++) {
    const tot = i * 3, d = 5 + Math.floor(tot / 24), h = tot % 24;
    const ts = '2026-09-' + String(d).padStart(2, '0') + 'T' + String(h).padStart(2, '0') + ':00Z';
    stamps.push(ts);
    p += -5 + r() * 10;
    wd = (wd + Math.floor(-30 + r() * 60) + 360) % 360;
    const spd = Math.floor(r() * 40);
    lines.push(LOG.make(ts, 'nav', [['lat', lat], ['lon', lon],
      ['wdir', String(wd)], ['wspd', String(spd)], ['sea', String(SCORE.sea(spd))]]));
    lines.push(LOG.make(ts, 'wx', [['mslp', p.toFixed(1)]]));
  }
  //  forecasts made at earlier slots FOR later ones, by all three
  for (let i = 0; i < n - 1; i++) {
    if (r() < 0.45) continue;
    const hours = [6, 12, 24][Math.floor(r() * 3)];
    const valid = SCORE.validTime(stamps[i], hours);
    ['you', 'rules', 'persist'].forEach(who => {
      if (r() < 0.2) return;
      const f = [['for', valid], ['by', who], ['why', 'generated|case']];
      if (r() > 0.1) f.push(['wdir', String(Math.floor(r() * 360))]);
      if (r() > 0.15) f.push(['wspd', String(Math.floor(r() * 45))]);
      if (r() > 0.2) f.push(['mslp', (990 + r() * 35).toFixed(1)]);
      else if (r() > 0.5) f.push(['mslp', '-']);
      lines.push(LOG.make(stamps[i], 'fc', f));
    });
  }
  return lines.join('\n') + '\n';
}

const TMP = process.env.TMPDIR || '/tmp';
let bad = 0, n = 0, first = null, withScore = 0;
const N = +(process.argv[2] || 300);
for (let seed = 1; seed <= N; seed++) {
  const text = gen(seed);
  const f = path.join(TMP, 'scdiff.log');
  fs.writeFileSync(f, text);
  const want = awkScore(f);
  const rd = LOG.read(text, '');
  const obs = WX.load(rd.recs);
  const res = SCORE.verify(rd.recs, obs);
  const got = SCORE.reportLines(res);
  n++;
  if (res.n > 0) withScore++;
  if (got !== want) {
    bad++;
    if (!first) {
      const a = got.split('\n'), b = want.split('\n'), L = [];
      for (let i = 0; i < Math.max(a.length, b.length); i++)
        if (a[i] !== b[i]) L.push('    js  |' + a[i] + '|\n    awk |' + b[i] + '|');
      first = 'seed ' + seed + '\n' + L.slice(0, 8).join('\n');
      fs.writeFileSync(path.join(TMP, 'scdiff-fail.log'), text);
    }
  }
}
console.log(n + ' logs scored (' + withScore + ' produced an actual score sheet)');
if (first) console.log('  first disagreement:\n' + first);
console.log(bad ? bad + ' DISAGREEMENTS' : 'the score sheets match the awk exactly');
process.exit(bad ? 1 : 0);
