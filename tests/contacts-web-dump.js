/*  The JavaScript side of the contacts port diff. Prints the same lines
    in the same order as tests/contacts-web-dump.awk, so `diff` is the
    judge rather than a reading of the two files.  */
const path = process.argv[2];
const src = require('fs').readFileSync(path, 'utf8');
const m = { exports: {} };
new Function('module', 'window', src)(m, {});
const F = m.exports;
const out = [];
/*  NEGATIVE ZERO. A bearing rate that rounds to zero from below is -0
    on both sides -- awk's int() and JavaScript's Math.trunc() both
    return -0 for -0.7 -- but awk's printf keeps the sign bit and
    JavaScript's toFixed drops it, so the same value printed "-0.0" on
    one side and "0.0" on the other. The sign carries information here:
    it says the bearing is creeping left rather than not moving. So the
    formatter reproduces printf rather than the port being changed to
    hide it, and the UI will have to print it the same way.  */
const fx = (x, n) => (Object.is(x, -0) ? '-' + (0).toFixed(n) : x.toFixed(n));
const f9 = x => fx(x, 9), f12 = x => fx(x, 12), f6 = x => fx(x, 6), f1 = x => fx(x, 1);
for (let i = -360; i <= 720; i += 7) out.push('nrm360\t' + i + '\t' + f9(F.nrm360(i)));
for (let i = -360; i <= 720; i += 7) out.push('sgn180\t' + i + '\t' + f9(F.sgn180(i)));
for (let y = -5; y <= 5; y++) for (let x = -5; x <= 5; x++) {
  if (x === 0 && y === 0) continue;
  out.push('rbrg\t' + x + '\t' + y + '\t' + f9(F.rbrg(x, y)));
}
out.push('ktym\t' + f9(F.ktym()));
for (let s = 1; s <= 40; s++) {
  F.xsrand(s);
  for (let i = 0; i < 6; i++) out.push('xrand\t' + s + '\t' + i + '\t' + f12(F.xrand()));
}
for (let v = 1; v <= 2000000; v *= 7) out.push('ctyd\t' + v + '\t' + F.ct_yd(v));
for (let sp = 4; sp <= 20; sp += 4) for (let co = 0; co < 360; co += 30) for (let bg = 0; bg < 360; bg += 45)
  out.push('ekacross\t' + sp + '\t' + co + '\t' + bg + '\t' + f9(F.ek_across(sp, co, bg)));
for (let s = 1; s <= 60; s++) {
  const e = F.ek_gen(s);
  out.push(e.ok ? ['ekgen', s, e.R, e.tb, e.cc, e.cs, e.c1, e.s1, e.c2,
                   f6(e.a1), f6(e.a2), f1(e.r1), f1(e.r2), f6(e.est), e.band].join('\t')
                : 'ekgen\t' + s + '\tnone');
}
for (let s = 1; s <= 60; s++) {
  const g = F.ct_gen(s);
  out.push(g.ok ? ['ctgen', s, g.oc, g.os, f6(g.tb), g.r0, g.cc, g.cs,
                   f6(g.px), f6(g.py), f6(g.vx), f6(g.vy), f6(g.tc), f6(g.cpa),
                   g.drift, g.band, g.ahead].join('\t')
                : 'ctgen\t' + s + '\tnone');
}
for (let s = 1; s <= 20; s++) {
  const g = F.ct_gen(s);
  if (!g.ok) continue;
  for (let i = 0; i < 5; i++)
    out.push('ctobs\t' + s + '\t' + i + '\t' + f6(F.ct_brg(g, i)) + '\t' + f6(F.ct_rng(g, i)));
}
console.log(out.join('\n'));
