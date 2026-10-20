/*  Reconstruct each lesson's plain text from lessons.js and compare it
    with what `weather learn <key>` actually prints in plain mode. The
    generator converts ANSI colour into styled spans; this proves the
    conversion carried every character, not only most of them. */
'use strict';
const path = require('path');
const { execFileSync } = require('child_process');
const REPO = path.resolve(__dirname, '..', '..', '..');
const L = require(path.resolve(__dirname, '..', 'weather', 'lessons.js')).LESSONS;
const ENG = ['-f', REPO + '/src/common/log.awk', '-f', REPO + '/src/common/colour.awk',
             '-f', REPO + '/src/weather/wx.awk', '-f', REPO + '/src/weather/score.awk',
             '-f', REPO + '/src/weather/chart.awk', '-f', REPO + '/src/weather/teach.awk',
             '-f', REPO + '/src/weather/screens.awk'];
function awkLesson(k) {
  return execFileSync('mawk', ['-v', 'cmode=plain', '-v', 'cmd=lesson', '-v', 'key=' + k,
    '-v', 'LOG=/dev/null'].concat(ENG), { input: '', encoding: 'utf8' });
}
const RULE = '  ' + new Array(71).join('-');
//  The body stops before the question, which lessons.js carries
//  separately so the page can ask before it tells. So the comparison
//  puts it back: the whole printed lesson, reconstructed, against the
//  whole printed lesson.
function render(les) {
  var L = les.body.map(function (b) {
    if (b.s === 'gap') return '';
    if (b.s === 'rule') return RULE;
    return b.p.map(function (p) { return p.t; }).join('');
  });
  L.push(RULE);
  L.push('  Question: ' + les.q);
  L.push('');
  return L.join('\n') + '\n';
}
let bad = 0;
L.forEach(function (les) {
  const want = awkLesson(les.key);
  const got = render(les);
  if (got !== want) {
    bad++;
    const a = got.split('\n'), b = want.split('\n');
    console.log('  FAIL ' + les.key);
    for (let i = 0; i < Math.max(a.length, b.length); i++)
      if (a[i] !== b[i]) { console.log('    js  |' + a[i] + '|'); console.log('    awk |' + b[i] + '|'); break; }
  }
});
const styles = {};
L.forEach(l => l.body.forEach(b => (b.p || []).forEach(p => { styles[p.s] = (styles[p.s] || 0) + 1; })));
console.log(L.length + ' lessons reconstructed from lessons.js and compared with the awk');
console.log('  spans by style: ' + Object.keys(styles).sort().map(k => k + ' ' + styles[k]).join(', '));
console.log(bad ? bad + ' LESSONS DIFFER' : 'every lesson is character-identical, emphasis preserved');
process.exit(bad ? 1 : 0);
