/* =====================================================================
   contacts -- managing them the way a tracking party does: by bearing
   drift, in relative motion, with the arithmetic done in your head
   before the plot has caught up.

   Ported function for name from src/colregs/contacts.awk, which is
   where the methods came from: Larry stood the manoeuvring watch and
   worked in the fire control tracking party, and the awk was written
   from what he remembered and then verified. This file is checked
   against it by tests/colregs-web-diff.sh rather than by reading, for
   the same reason the rest of the browser build is: the two drifted
   once before and nothing on screen showed it.

   Units throughout are yards, knots and minutes. A knot is 2000 yards
   in an hour in fire-control arithmetic, so 33 1/3 yards a minute.
   ===================================================================== */
(function (root) {
'use strict';

/* ---- the maths the awk shares with the engine ---------------------
   Repeated here rather than imported because this file is diffed as a
   unit: a helper that differs by a rounding step is exactly the kind of
   divergence the diff exists to catch, and it cannot catch what it
   cannot see. */
function sind(x) { return Math.sin(x * 0.0174532925199432958); }
function cosd(x) { return Math.cos(x * 0.0174532925199432958); }
function fabs(x) { return (x < 0) ? -x : x; }
/* awk's int() truncates toward zero, which Math.trunc does and
   Math.floor does not -- nrm360 of a negative angle depends on it. */
function nrm360(x) { x = x - 360 * Math.trunc(x / 360); if (x < 0) x += 360; return x; }
function atan2d(y, x) { return 57.2957795130823209 * Math.atan2(y, x); }

/* ---- a reproducible pseudo-random generator -----------------------
   Park-Miller, written out in the awk because awk's own srand()/rand()
   is not reproducible across implementations -- and that is exactly
   what makes the seeded exercises diffable between the two builds.
   16807 * 2147483646 is about 3.6e13, well inside the 2^53 where
   JavaScript integer arithmetic is still exact. */
var RS_ = 1;
function xsrand(s) {
  RS_ = Math.trunc(s) % 2147483647;
  if (RS_ <= 0) RS_ += 2147483646;
  for (var i = 0; i < 8; i++) RS_ = (16807 * RS_) % 2147483647;
  return 0;
}
function xrand() { RS_ = (16807 * RS_) % 2147483647; return RS_ / 2147483647.0; }

/* ---- bearings ----------------------------------------------------
   rbrg takes the EAST component first and the NORTH component second,
   and hands them to atan2d in that order -- so atan2d's own first
   argument is the east one. Worth stating because the obvious port
   flips it and the result still looks like a bearing. */
function ktym() { return 33.3333333; }
function rbrg(x, y) { return nrm360(atan2d(x, y)); }
function sgn180(a) { a = nrm360(a); return (a > 180) ? a - 360 : a; }

/* ---- closest point of approach ------------------------------------
   Lifted out of ct_plot, which computed it as a side effect of drawing.
   The browser draws in SVG and does not want the character grid, so the
   arithmetic is its own function here and the drawing calls it.

   Own ship at the origin; she travels in a straight line in relative
   motion, which is the whole reason this plot answers the question.
   tc is clamped at zero because a CPA already passed is not a CPA. */
function ct_cpa(px, py, vx, vy) {
  var rr = vx * vx + vy * vy;
  var tc = (rr > 1e-9) ? -(px * vx + py * vy) / rr : 0;
  if (tc < 0) tc = 0;
  var cpx = px + vx * tc, cpy = py + vy * tc;
  return { cpa: Math.sqrt(cpx * cpx + cpy * cpy), tcpa: tc,
           ahead: (cpy > 0) ? 1 : 0, cpx: cpx, cpy: cpy };
}

/* ---- a range, as a range is reported ------------------------------
   14200 -> "14,200", and 16807 -> "16,800": it ROUNDS TO THE NEAREST
   HUNDRED YARDS before inserting the commas, because that is how a
   tracking party reports a range and because it is handed computed
   ranges -- ct_rng, CPA, the Ekelund estimate -- not round numbers.

   The first version of this port inserted the commas and nothing else.
   It passed reading and failed the diff on the second line, which is
   the entire argument for diffing the port instead of reading it. */
function ct_yd(v) {
  var n = String(Math.trunc(v / 100 + 0.5) * 100), s = '';
  while (n.length > 3) {
    s = ',' + n.substring(n.length - 3) + s;
    n = n.substring(0, n.length - 3);
  }
  return n + s;
}

/* ---- the observations ---------------------------------------------
   Marks every three minutes, which is why a knot is 33 1/3 yards a
   minute and 100 yards of range rate reads straight off the plot. */
function ct_obs(i) { return i * 3; }
function ct_brg(g, i) { return rbrg(g.px + g.vx * ct_obs(i), g.py + g.vy * ct_obs(i)); }
function ct_rng(g, i) {
  var x = g.px + g.vx * ct_obs(i), y = g.py + g.vy * ct_obs(i);
  return Math.sqrt(x * x + y * y);
}

/* ---- generating a contact -----------------------------------------
   True frame first, north up, because that is what a bearing is; then
   rotated head up for the plot. The awk keeps its state in CG_*
   globals; here it comes back as an object, which is the only
   structural difference and the diff compares the fields.

   One run in five is a genuine collision, on purpose: the band is
   chosen first and the geometry is searched until it lands there,
   rather than taking whatever the geometry throws up. */
function ct_gen(seed) {
  xsrand(seed + 0);
  var want = (xrand() < 0.2) ? 1 : (2 + Math.trunc(xrand() * 3));
  for (var attempt = 0; attempt < 6000; attempt++) {
    var oc = Math.trunc(xrand() * 360);
    var os = 8 + Math.trunc(xrand() * 13);
    var rb = -80 + xrand() * 160;
    var tb = nrm360(oc + rb);
    var r0 = 9000 + Math.trunc(xrand() * 90) * 100;
    var cc = Math.trunc(xrand() * 360);
    var cs = 4 + Math.trunc(xrand() * 17);
    var px = r0 * sind(tb), py = r0 * cosd(tb);
    var vx = cs * ktym() * sind(cc) - os * ktym() * sind(oc);
    var vy = cs * ktym() * cosd(cc) - os * ktym() * cosd(oc);
    if (px * vx + py * vy >= 0) continue;              /* not closing */
    var tc = -(px * vx + py * vy) / (vx * vx + vy * vy);
    if (tc < 14 || tc > 50) continue;                  /* 12 min of marks must fit */
    var cpa = Math.sqrt(Math.pow(px + vx * tc, 2) + Math.pow(py + vy * tc, 2));
    /* head-up frame: own course is +y, so her track crossing x=0 is her
       crossing your bow or your stern */
    var pxp =  px * cosd(oc) - py * sind(oc);
    var pyp =  px * sind(oc) + py * cosd(oc);
    var vxp =  vx * cosd(oc) - vy * sind(oc);
    var vyp =  vx * sind(oc) + vy * cosd(oc);
    if (fabs(vxp) < 1e-6) continue;
    var tc0 = -pxp / vxp;
    if (tc0 <= 0.5) continue;              /* she must actually cross your track */
    var ahead = ((pyp + vyp * tc0) > 0) ? 1 : 0;
    /* drift over the twelve minutes of the run */
    var b0  = rbrg(px, py);
    var b12 = rbrg(px + vx * 12, py + vy * 12);
    var d   = sgn180(b12 - b0);
    if (fabs(d) > 0.6 && fabs(d) < 4.0) continue;   /* neither clearly one nor the other */
    var drift = (fabs(d) <= 0.6) ? 'steady' : ((d > 0) ? 'right' : 'left');
    /* a steady bearing IS the collision, so the two must agree */
    if (drift === 'steady' && cpa > 900) continue;
    if (drift !== 'steady' && cpa < 900) continue;
    /* CPA band, kept clear of its own boundaries */
    var band;
    if (cpa < 1000)      band = 1;
    else if (cpa < 3000) band = 2;
    else if (cpa < 6000) band = 3;
    else                 band = 4;
    if (band === 1 && cpa > 870) continue;
    if (band === 2 && (cpa < 1180 || cpa > 2650)) continue;
    if (band === 3 && (cpa < 3400 || cpa > 5400)) continue;
    if (band === 4 && (cpa < 6800 || cpa > 14000)) continue;
    if (Math.sqrt(Math.pow(px + vx * 12, 2) + Math.pow(py + vy * 12, 2)) < 4000) continue;
    if (band !== want) continue;
    return { ok: 1, want: want, oc: oc, os: os, tb: tb, r0: r0, cc: cc, cs: cs,
             px: px, py: py, vx: vx, vy: vy, tc: tc, cpa: cpa,
             pxp: pxp, pyp: pyp, vxp: vxp, vyp: vyp,
             drift: drift, band: band,
             /* neither: she is CBDR */
             ahead: (drift === 'steady') ? -1 : ahead };
  }
  return { ok: 0 };
}

/* ---- Ekelund -------------------------------------------------------
   Two legs on different courses, bearings only, no range. Her motion
   across your line of sight never changed; all of the change in bearing
   rate was yours, and you knew how much of it you put in.
   1909.86 is the constant that falls out of 33 1/3 yards a minute and
   degrees per minute. */
function ek_plot(r) {
  var v = Math.trunc(r * 10 + (r < 0 ? -0.5 : 0.5)) / 10;
  if (v === 0) v = 0;                  /* -0 === 0, so this stores +0 */
  return v;
}
function ek_across(sp, co, bg) { return sp * sind(co - bg); }
function ek_rate(R, bg, cs, cc, os, oc) {
  return ((ek_across(cs, cc, bg) - ek_across(os, oc, bg)) * ktym() / R) * 57.2957795130823;
}
function ek_gen(seed) {
  xsrand(seed + 0);
  var want = 1 + Math.trunc(xrand() * 4);
  for (var attempt = 0; attempt < 6000; attempt++) {
    var R  = 5000 + Math.trunc(xrand() * 300) * 100;
    var tb = Math.trunc(xrand() * 360);
    var cc = Math.trunc(xrand() * 360), cs = 4 + Math.trunc(xrand() * 17);
    var c1 = Math.trunc(xrand() * 360), s1 = 6 + Math.trunc(xrand() * 15);
    var c2 = Math.trunc(xrand() * 360), s2 = 6 + Math.trunc(xrand() * 15);
    var a1 = ek_across(s1, c1, tb), a2 = ek_across(s2, c2, tb);
    if (fabs(a2 - a1) < 6) continue;            /* too small a change to be worth it */
    var r1 = ek_rate(R, tb, cs, cc, s1, c1);
    var r2 = ek_rate(R, tb, cs, cc, s2, c2);
    /* what the plot would give you, rounded to a tenth the way the awk
       rounds it: int(x*10 +/- 0.5)/10, which is away from zero */
    /*  ek_plot() in the awk: a small negative rounds to a zero that
        carries a sign bit, and the sign is not ours to claim at this
        resolution. See the long note there.  */
    var R1 = ek_plot(r1), R2 = ek_plot(r2);
    if (fabs(R1) > 9 || fabs(R2) > 9) continue;
    if (fabs(R1 - R2) < 0.6) continue;
    var est = 1909.86 * (a2 - a1) / (R1 - R2);
    if (est < 0) est = -est;
    if (fabs(est - R) / R > 0.06) continue;     /* rounding must not move the answer */
    var band  = (R < 8000) ? 1 : ((R < 15000) ? 2 : ((R < 25000) ? 3 : 4));
    var eband = (est < 8000) ? 1 : ((est < 15000) ? 2 : ((est < 25000) ? 3 : 4));
    if (band !== eband || band !== want) continue;
    if (band === 1 && R > 7200) continue;
    if (band === 2 && (R < 8900 || R > 13800)) continue;
    if (band === 3 && (R < 16200 || R > 23200)) continue;
    if (band === 4 && R < 27000) continue;
    return { ok: 1, want: want, R: R, tb: tb, cc: cc, cs: cs,
             c1: c1, s1: s1, c2: c2, s2: s2,
             a1: a1, a2: a2, r1: R1, r2: R2, est: est, band: band };
  }
  return { ok: 0 };
}

/* the answers, keyed the way the awk keys them */
function ct_ans1(g) { return (g.drift === 'left') ? 'a' : ((g.drift === 'right') ? 'b' : 'c'); }
function ct_ans2(g) { return (g.ahead < 0) ? 'c' : ((g.ahead === 1) ? 'a' : 'b'); }
function ct_ans3(g) { return 'abcd'.charAt(g.band - 1); }

var API = {
  sind: sind, cosd: cosd, fabs: fabs, nrm360: nrm360, atan2d: atan2d,
  xsrand: xsrand, xrand: xrand,
  ktym: ktym, rbrg: rbrg, sgn180: sgn180,
  ct_cpa: ct_cpa, ct_yd: ct_yd,
  ct_obs: ct_obs, ct_brg: ct_brg, ct_rng: ct_rng, ct_gen: ct_gen,
  ek_across: ek_across, ek_rate: ek_rate, ek_gen: ek_gen, ek_plot: ek_plot,
  ct_ans1: ct_ans1, ct_ans2: ct_ans2, ct_ans3: ct_ans3
};
root.CONTACTS = API;
/*  the same seam the rest of the build uses: `module` is undefined in a
    browser, and tests/colregs-web-diff.sh loads this in node to run
    these against the awk originals over their whole input range. */
if (typeof module !== 'undefined' && module.exports) module.exports = API;

})(typeof window !== 'undefined' ? window : this);
