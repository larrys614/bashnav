/*  The two contacts exercises, as DATA rather than as a screen.

    The tracking party exercise and Ekelund are the only parts of the
    contacts module where the app marks you, so they are the parts where
    the browser and the shell have to be saying the same thing about the
    same contact -- not approximately, and not "ported, trust me".

    Every function here returns values and sentences, never markup and
    never a padded line. Three reasons, and the third is the point:

      the browser lays out a table with a table, not with %-23s;
      the marking screen reflows like every other screen now does;
      and values can be DIFFED. tests/contacts-web-diff.sh runs the awk
        and this over the same seeds, in every reporting style, and
        compares the lot -- which is what makes "the same exercise in
        both places" a fact rather than a claim.

    The sentences themselves come from ct_q1lead(), ct_q1why(),
    ct_q2line(), ct_report(), ct_findher() and ct_advice() in
    src/colregs/contacts.awk. They were printf statements inside
    ct_trackm() until this port needed them; they are functions now, in
    both languages, so the words live in one place.  */
(function (root) {
'use strict';

var C = root.CONTACTS;                 /* the arithmetic, already diffed */

function yd(v) { return C.ct_yd(v); }
function d3(v) { return ('00' + v).slice(-3); }
function brgInt(b) { return Math.trunc(b + 0.5) % 360; }

/* =====================================================================
   THE TRACKING PARTY

   Five marks three minutes apart, and the three questions the plot is
   supposed to answer: which way is she drawing, where does she go, and
   how close does she come.
   ===================================================================== */
function track(seed, relStyle) {
  var g = C.ct_gen(seed);
  if (!g.ok) return { ok: 0 };
  var rows = [], i, b, r;
  for (i = 0; i < 5; i++) {
    b = C.ct_brg(g, i); r = C.ct_rng(g, i);
    rows.push({ time: d3(C.ct_obs(i)) + '0'.slice(0, 0) , t: C.ct_obs(i),
                brg: d3(brgInt(b)), rel: relStyle(b - g.oc), rng: yd(r) });
  }
  return { ok: 1, g: g, oc: d3(g.oc), os: g.os, rows: rows };
}

/*  the side she is on, and whether the drift is toward your bow --
    ct_side() and ct_toward() in the awk  */
function side(g) { return (C.sgn180(g.tb - g.oc) < 0) ? 'port' : 'starboard'; }
function toward(g) {
  var rb = C.sgn180(g.tb - g.oc);
  return ((rb < 0 && g.drift === 'right') || (rb > 0 && g.drift === 'left')) ? 1 : 0;
}
function q1state(g) { return (g.drift === 'steady') ? 'steady' : ('drawing ' + g.drift); }
function q1lead(g) {
  if (g.drift === 'steady')
    return 'She is on your ' + side(g) + ' bow and the bearing is not changing,';
  return 'She is on your ' + side(g) + ' bow and the bearing is drawing ' +
         (toward(g) ? 'TOWARD your bow' : 'AWAY from your bow') + ',';
}
function q1why(g) {
  if (g.drift === 'steady')
    return 'which is the one thing that means collision. Constant bearing,\n' +
           'decreasing range. Rule 7(d)(i). Act now.';
  if (toward(g))
    return 'so she is going to cross ahead of you. The miss is being built\n' +
           'in front of your bow, and it shrinks to nothing if the drift\n' +
           'stops. This is the one you keep calling out.';
  return 'so she cannot cross ahead of you. A contact drawing away from\n' +
         'your bow passes astern - the relative track is a straight line\n' +
         'and the bearing can never come back.';
}
function q2line(g) {
  if (g.ahead < 0) return 'neither - she is CBDR';
  if (g.ahead === 1) return 'she crosses ahead';
  return 'she passes astern';
}
function cpaline(g) {
  if (g.cpa < 250) return 'CPA nil - she hits you in ' + Math.trunc(g.tc + 0.5) + ' minutes';
  return 'CPA ' + yd(g.cpa) + ' yards at ' + Math.trunc(g.tc + 0.5) + ' minutes';
}
function report(g, relStyle) {
  var rel = relStyle(C.ct_brg(g, 4) - g.oc);
  return 'Master 2, bearing ' + d3(brgInt(C.ct_brg(g, 4))) + ', ' +
         (rel === '' ? '' : (rel + ', ')) + q1state(g) +
         ', range ' + yd(C.ct_rng(g, 4)) +
         ', CPA ' + ((g.cpa < 250) ? 'nil' : yd(g.cpa)) +
         ' at ' + Math.trunc(g.tc + 0.5) + ' minutes.';
}
function findher(g, relOther) {
  return '(and if he still cannot find her: she is ' + relOther(C.ct_brg(g, 4) - g.oc) + '.)';
}
function advice(g) {
  if (g.cpa >= 3000) return '';
  if (g.cpa < 250) return 'Recommend coming right immediately to open the bearing.';
  return 'That is inside night orders. Recommend a course change.';
}

function trackMark(seed, a1, a2, a3, relStyle, relOther) {
  var g = C.ct_gen(seed);
  if (!g.ok) return { ok: 0 };
  var r1 = C.ct_ans1(g), r2 = C.ct_ans2(g), r3 = C.ct_ans3(g);
  var n = (a1 === r1 ? 1 : 0) + (a2 === r2 ? 1 : 0) + (a3 === r3 ? 1 : 0);
  return {
    ok: 1, g: g, n: n,
    fig: { t: 'fig', kind: 'plot', px: g.pxp, py: g.pyp, vx: g.vxp, vy: g.vyp,
           nobs: 5, dt: 3, cpa: 1 },
    q1: { said: a1, right: r1, got: a1 === r1, line: q1state(g),
          lead: q1lead(g), why: q1why(g) },
    q2: { said: a2, right: r2, got: a2 === r2, line: q2line(g) },
    q3: { said: a3, right: r3, got: a3 === r3, line: cpaline(g) },
    report: report(g, relStyle), findher: findher(g, relOther), advice: advice(g)
  };
}

/* =====================================================================
   EKELUND

   Range out of a course change, with bearings only. Two legs, and the
   whole trick is that her motion across your line of sight never
   changed -- all of the change in bearing rate was yours.
   ===================================================================== */
function ek(seed) {
  var e = C.ek_gen(seed);
  if (!e.ok) return { ok: 0 };
  return {
    ok: 1, e: e, tb: d3(e.tb),
    legs: [{ n: 1, co: d3(e.c1), sp: e.s1, rate: e.r1 },
           { n: 2, co: d3(e.c2), sp: e.s2, rate: e.r2 }]
  };
}
/*  ek_rfmt() in the awk: the sign is forced on everything EXCEPT a zero,
    because a plot at a tenth of a degree a minute cannot tell you the
    direction of a drift that small. See the note in contacts.awk.  */
/*  "%+.1f": the sign is forced on everything, a zero included, which is
    what the awk prints for a leg that is exactly beam-on. A negative
    zero is folded into the positive one first -- it cannot arise from
    sp * sin(0), but one-true-awk and gawk disagree about printing one,
    and that trap has been sprung on this module once already.  */
function sg(v, n) {
  if (Object.is(v, -0)) v = 0;
  return (v >= 0 ? '+' : '') + v.toFixed(n);
}
function rate(r) {
  /*  ek_rfmt() is "%+5.1f", or "%5.1f" for a zero: five wide, the sign
      forced on everything but the zero. The width is the terminal's
      business and the browser trims it, but the string is kept
      identical so the diff can compare the two functions directly.  */
  var s = (r === 0) ? (0).toFixed(1) : ((r > 0 ? '+' : '') + r.toFixed(1));
  while (s.length < 5) s = ' ' + s;
  return s;
}
function ekMark(seed, ans) {
  var e = C.ek_gen(seed);
  if (!e.ok) return { ok: 0 };
  var right = 'abcd'.charAt(e.band - 1);
  var da = e.a2 - e.a1, dr = e.r1 - e.r2;

  return {
    ok: 1, e: e, got: ans === right, right: right.toUpperCase(),
    head: right.toUpperCase() + ' is right -- she is ' + yd(e.R) + ' yards off.',
    work: [
      'across the line of sight, leg 1 = ' + e.s1 + ' x sin(' + d3(e.c1) + ' - ' + d3(e.tb) + ') = ' + sg(e.a1, 1) + ' kt',
      'across the line of sight, leg 2 = ' + e.s2 + ' x sin(' + d3(e.c2) + ' - ' + d3(e.tb) + ') = ' + sg(e.a2, 1) + ' kt',
      'change in across = ' + sg(da, 1) + '     change in rate = ' + sg(dr, 1) + ' deg/min',
      'range = 1.91 x ' + da.toFixed(1) + ' / ' + dr.toFixed(1) + ' = ' + yd(e.est) + ' yards'
    ],
    note: 'Her motion across your line of sight never changed. All of the\n' +
          'change in bearing rate was yours, and you knew exactly how much\n' +
          'of it you put in. That is the whole trick.'
  };
}

root.CONTACTS_EX = {
  track: track, trackMark: trackMark, ek: ek, ekMark: ekMark,
  rate: rate, sg: sg, cpaline: cpaline, q1state: q1state, q1lead: q1lead,
  q1why: q1why, q2line: q2line, report: report, findher: findher,
  advice: advice, side: side, toward: toward
};
if (typeof module !== 'undefined' && module.exports) module.exports = root.CONTACTS_EX;

})(typeof window !== 'undefined' ? window : this);
