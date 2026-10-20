'use strict';
const fs = require('fs'), path = require('path');
const W = path.resolve(__dirname, '..', 'deck-log');
global.LOG = require(path.join(W, 'log.js'));
const VIEWS = require(path.join(W, 'views.js'));

const logText = fs.readFileSync(process.argv[2], 'utf8');
const ref = fs.readFileSync(process.argv[3], 'utf8').split('\n');

const rd = LOG.read(logText, '');
let bad = 0, checks = 0;
const fail = m => { bad++; if (bad <= 12) console.log('  FAIL ' + m); };

const wantHold = {}, wantDef = [];
let wantRecs = 0, wantDefN = -1;
for (const L of ref) {
  const f = L.split('\t');
  if (f[0] === 'RECORDS') wantRecs = +f[1];
  else if (f[0] === 'HOLD') wantHold[f[1]] = +f[2];
  else if (f[0] === 'DEFN') wantDefN = +f[1];
  else if (f[0] === 'DEF') wantDef.push({ ts: f[2], eq: f[3], item: f[4] });
}

checks++;
if (rd.good !== wantRecs) fail('record count: JS parsed ' + rd.good + ', awk wrote ' + wantRecs);
if (rd.bad) fail(rd.bad + ' records the JS could not parse, first: ' + rd.badLine);

const hold = VIEWS.holdings(rd.recs);
const keys = new Set([...Object.keys(hold), ...Object.keys(wantHold)]);
for (const k of keys) {
  checks++;
  const a = hold[k] === undefined ? 0 : hold[k];
  const b = wantHold[k] === undefined ? 0 : wantHold[k];
  if (a !== b) fail('holding of ' + k + ': JS ' + a + ', awk ' + b);
}

const defs = VIEWS.defects(rd.recs);
checks++;
if (defs.length !== wantDefN) fail('open defects: JS ' + defs.length + ', awk ' + wantDefN);
for (let i = 0; i < Math.min(defs.length, wantDef.length); i++) {
  checks++;
  const a = defs[i], b = wantDef[i];
  if (a.ts !== b.ts || a.eq !== b.eq || a.item !== b.item)
    fail('defect ' + (i + 1) + ': JS ' + JSON.stringify([a.ts, a.eq, a.item]) +
         ', awk ' + JSON.stringify([b.ts, b.eq, b.item]));
}

console.log('  records ' + rd.good + '   holdings ' + keys.size +
            '   open defects ' + wantDefN + '   (' + checks + ' comparisons)');
if (bad > 12) console.log('  ... and ' + (bad - 12) + ' more');
process.exit(bad ? 1 : 0);
