/*  Hold the JS record layer to the awk record layer, both directions.
    The log is append-only and shared between the two tools: if these
    two ever disagree about a byte, one of them has been writing records
    the other cannot read, and in an append-only log that is permanent. */
'use strict';
const fs = require('fs');
const path = require('path');
const LOG = require(path.resolve(__dirname, '..', 'deck-log', 'log.js'));

const ref = fs.readFileSync(process.argv[2] || 'rt-mawk.tsv', 'utf8').split('\n');
function unhex(h) {
  let s = '';
  for (let i = 0; i < h.length; i += 2) s += String.fromCharCode(parseInt(h.substr(i, 2), 16));
  return s;
}

let n = 0, bad = 0;
const fail = (msg) => { bad++; if (bad <= 15) console.log('  FAIL ' + msg); };

for (const L of ref) {
  const f = L.split('\t');
  if (f.length < 2) continue;

  if (f[0] === 'CASE' || f[0] === 'TAIL') {
    const [, id, key, hexv, hexline] = f;
    const val = unhex(hexv);
    const line = unhex(hexline);
    n++;
    // 1. the JS parser reads the awk's record and recovers the value
    const r = LOG.parse(line);
    if (!r) { fail(f[0] + ' ' + id + ': JS rejected an awk record: ' + LOG.err()); continue; }
    if (r.v[key] !== val) {
      fail(f[0] + ' ' + id + ' key ' + key + ': decoded ' + JSON.stringify(r.v[key]) +
           ' want ' + JSON.stringify(val));
      continue;
    }
    // 2. the JS writer produces the awk's record, byte for byte
    const fields = f[0] === 'CASE'
      ? [['a', 'before'], [key, val], ['z', 'after']]
      : [[key, val]];
    const mine = LOG.make('2026-08-30T18:00Z', f[0] === 'CASE' ? 'eng' : 'wx', fields);
    if (mine !== line) {
      fail(f[0] + ' ' + id + ' key ' + key + ': built\n       ' + JSON.stringify(mine) +
           '\n  awk  ' + JSON.stringify(line));
    }
  }

  else if (f[0] === 'JUDGE') {
    const [, id, okStr, hexline, awkErr] = f;
    const line = unhex(hexline);
    const awkOk = okStr === '1';
    const r = LOG.parse(line);
    const jsOk = r !== null;
    n++;
    if (jsOk !== awkOk) {
      fail('JUDGE ' + id + ' ' + JSON.stringify(line) + ': awk ' +
           (awkOk ? 'accepts' : 'rejects (' + awkErr + ')') + ', JS ' +
           (jsOk ? 'accepts' : 'rejects (' + LOG.err() + ')'));
    }
  }

  else if (f[0] === 'TRUNC') {
    const [, at, okStr] = f;
    const good = '2026-08-30T18:00Z|eng|job=impeller|part=jabsco|qty=1|hrs=1234.5|~';
    const jsOk = LOG.parse(good.substring(0, +at)) !== null;
    n++;
    if (jsOk !== (okStr === '1')) {
      fail('TRUNC at ' + at + ': awk ' + (okStr === '1' ? 'accepts' : 'rejects') +
           ', JS ' + (jsOk ? 'accepts' : 'rejects'));
    }
  }
}

console.log(n + ' comparisons against the awk record layer');
if (bad > 15) console.log('  ... and ' + (bad - 15) + ' more');
console.log(bad ? bad + ' DISAGREEMENTS' : 'the two record layers agree on every byte');
process.exit(bad ? 1 : 0);
