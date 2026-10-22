global.window = { addEventListener: function () {}, COLREGS_DATA: { encounters: [] } };
global.document = { getElementById: function () { return null; },
                    createElement: function () { return { style: {}, dataset: {},
                      appendChild: function () {}, addEventListener: function () {},
                      setAttribute: function () {} }; },
                    documentElement: { style: {}, setAttribute: function () {} },
                    addEventListener: function () {} };
global.localStorage = undefined;
const path = process.argv[2];
const src = require('fs').readFileSync(path, 'utf8');
const m = { exports: {} };
new Function('module', 'window', 'document', src)(m, global.window, global.document);
const F = m.exports;
const out = [];
for (let b = 0; b < 360; b++) out.push('relp\t' + b + '\t' + F.rel_phrase(b, 'your'));
for (let b = 0; b < 360; b++) out.push('relpthe\t' + b + '\t' + F.rel_phrase(b, 'the'));
for (let t = -180; t <= 180; t++) out.push('aspect\t' + t + '\t' + F.aspect_words(t));
for (const a of ['M','S','P','T','Y','A']) for (let t = -180; t <= 180; t++)
  out.push('arc\t' + a + '\t' + t + '\t' + (F.arc_vis(a, t) ? 1 : 0));
console.log(out.join('\n'));
