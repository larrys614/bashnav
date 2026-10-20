'use strict';
const path = require('path');
const { execFileSync } = require('child_process');
const REPO = path.resolve(__dirname, '..', '..', '..');
const W = path.resolve(__dirname, '..');
global.LOG = require(path.join(W, 'deck-log', 'log.js'));
global.WX = require(path.join(W, 'weather', 'wx.js'));
const CHART = require(path.join(W, 'weather', 'chart.js'));

function awkChart(brg, dist, orient, w500, north) {
  return execFileSync('mawk', ['-v', 'cmode=plain', '-v', 'cmd=chart',
    '-v', 'brg=' + brg, '-v', 'dist=' + dist, '-v', 'orient=' + orient,
    '-v', 'w500=' + w500, '-v', 'north=' + north, '-v', 'LOG=/dev/null',
    '-f', REPO + '/src/common/log.awk', '-f', REPO + '/src/common/colour.awk',
    '-f', REPO + '/src/weather/wx.awk', '-f', REPO + '/src/weather/score.awk',
    '-f', REPO + '/src/weather/chart.awk', '-f', REPO + '/src/weather/teach.awk',
    '-f', REPO + '/src/weather/screens.awk'], { input: '', encoding: 'utf8' });
}
let bad = 0, n = 0, first = null;
const brgs = [0, 1, 45, 89, 90, 91, 180, 269, 270, 271, 359];
const dists = ['', 0, 1, 120, 300.5, 640, 1200];
const ors = [0, 37, 90, 180, 263, 359];
const w5s = ['', 0, 25, 45, 65, 95, 130];
for (const north of [1, 0]) for (const brg of brgs) for (const dist of dists)
  for (const or of [ors[(brg + dist.toString().length) % ors.length]])
    for (const w5 of w5s) {
      n++;
      const want = awkChart(brg, dist, or, w5, north);
      const items = CHART.report(brg, dist === '' ? '' : dist, or, w5 === '' ? '' : w5, !!north);
      const got = CHART.renderTerminal(items, dist !== '' && brg !== '');
      if (got !== want) {
        bad++;
        if (!first) {
          const a = got.split('\n'), b = want.split('\n'), L = [];
          for (let i = 0; i < Math.max(a.length, b.length); i++)
            if (a[i] !== b[i]) L.push('    js  |' + a[i] + '|\n    awk |' + b[i] + '|');
          first = `brg=${brg} dist=${dist} or=${or} w500=${w5} north=${north}\n` + L.slice(0, 6).join('\n');
        }
      }
    }
console.log(n + ' chart cases compared, character for character');
if (first) console.log('  first disagreement:\n' + first);
console.log(bad ? bad + ' DISAGREEMENTS' : 'the 500 mb rules match the awk exactly');
process.exit(bad ? 1 : 0);
