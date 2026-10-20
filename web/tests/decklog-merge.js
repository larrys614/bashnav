/*  The merge's safety argument is two properties, so they are tested as
    properties over generated logs rather than on one hand-made example:

      commutative   merging A into B gives a byte-identical file to
                    merging B into A
      idempotent    merging the same file twice changes nothing

    A merge you can run twice by accident, or in either direction, is a
    merge nobody has to be careful with at 0400. */
'use strict';
const fs = require('fs'), path = require('path');
const W = path.resolve(__dirname, '..', 'deck-log');
global.LOG = require(path.join(W, 'log.js'));
global.window = {};                       // store.js only touches it inside open()
const STORE = require(path.join(W, 'store.js'));

const canon = ls => STORE.canonical(ls);
const text = ls => canon(ls).join('\n');

function rnd(seed) { let s = seed; return () => (s = (s * 1103515245 + 12345) & 0x7fffffff) / 0x7fffffff; }

function genLog(seed, n) {
  const r = rnd(seed), out = [], types = ['nav', 'wx', 'eng', 'pro', 'inv'];
  for (let i = 0; i < n; i++) {
    const d = 1 + Math.floor(r() * 28), h = Math.floor(r() * 8) * 3;
    const ts = '2026-0' + (1 + Math.floor(r() * 9)) + '-' + String(d).padStart(2, '0') +
               'T' + String(h).padStart(2, '0') + ':00Z';
    const ty = types[Math.floor(r() * types.length)];
    out.push(LOG.make(ts, ty, [['v', Math.floor(r() * 1000)], ['n', 'note|with=delims']]));
  }
  return out;
}

let bad = 0;
const fail = m => { bad++; console.log('  FAIL ' + m); };

for (let seed = 1; seed <= 40; seed++) {
  const A = genLog(seed, 120);
  // B overlaps A substantially, which is the real case: two devices that
  // both hold the 1800Z nav record hold the SAME line.
  const B = A.slice(0, 70).concat(genLog(seed + 500, 60));

  const ab = text(A.concat(B));
  const ba = text(B.concat(A));
  if (ab !== ba) fail('seed ' + seed + ': merge is not commutative');

  const aa = text(A.concat(A));
  if (aa !== text(A)) fail('seed ' + seed + ': merge is not idempotent');

  const abb = text(A.concat(B).concat(B));
  if (abb !== ab) fail('seed ' + seed + ': re-merging B a second time changed the log');

  // an identical record held by both appears exactly once
  const lines = canon(A.concat(B));
  const seen = new Set();
  for (const L of lines) {
    if (seen.has(L)) { fail('seed ' + seed + ': a duplicate line survived the merge'); break; }
    seen.add(L);
  }
  // and nothing was lost: every distinct line of either input is present
  const want = new Set(A.concat(B));
  for (const L of want) if (!seen.has(L)) { fail('seed ' + seed + ': a record was dropped'); break; }

  // ordering is total and device-independent: sorted by UTC timestamp
  for (let i = 1; i < lines.length; i++) {
    if (lines[i - 1].substring(0, 17) > lines[i].substring(0, 17)) {
      fail('seed ' + seed + ': output is not in timestamp order'); break;
    }
  }
}

// a conflict -- same timestamp AND type, different content -- keeps BOTH
const c1 = LOG.make('2026-10-14T18:00Z', 'wx', [['mslp', '1013.2']]);
const c2 = LOG.make('2026-10-14T18:00Z', 'wx', [['mslp', '1011.8']]);
const both = canon([c1, c2]);
if (both.length !== 2) fail('a conflict did not keep both records (' + both.length + ')');
if (!both.includes(c1) || !both.includes(c2)) fail('a conflicting record was dropped');

console.log('40 generated log pairs: commutative, idempotent, lossless, timestamp-ordered');
console.log(bad ? bad + ' FAILURES' : 'the merge is safe to run twice, in either direction');
process.exit(bad ? 1 : 0);
