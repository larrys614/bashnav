/* =====================================================================
   The line of position, and the fix.

   A sight that stops at Ho is a number that goes nowhere.  This turns it
   into what it is for: an assumed position, a computed altitude, an
   intercept, and a line drawn on a plotting sheet.

   NOTHING IS RECOMPUTED HERE.  The arithmetic is engine2.js's solve_fix()
   and fix_geometry(), which were diffed against the awk engine over 700
   cases.  This file stores sights, scales a plot and draws it.  A second
   implementation of the sight reduction would be a second thing to get
   wrong.

   A saved sight stores the RAW sextant reading and the conditions, not
   Ho.  That way the whole correction chain is re-run when the fix is
   solved - so correcting the height of eye, or the time, or which limb,
   fixes every sight that used it rather than leaving a stale Ho behind.
   ===================================================================== */
(function () {
  'use strict';
  var KEY = 'celnav-sights';

  function load() {
    try { return JSON.parse(localStorage.getItem(KEY) || '[]'); }
    catch (e) { return []; }          /* private mode, cleared data, anything */
  }
  function save(a) {
    try { localStorage.setItem(KEY, JSON.stringify(a)); } catch (e) {}
  }

  var SIGHTS = load();

  function add(s) { SIGHTS.push(s); save(SIGHTS); return SIGHTS.length; }
  function remove(i) { SIGHTS.splice(i, 1); save(SIGHTS); }
  function clear() { SIGHTS = []; save(SIGHTS); }
  function all() { return SIGHTS; }

  /* ---- solving ------------------------------------------------------
     Returns per-sight detail (name, Hc, Zn, intercept) and, with two or
     more, the fix offset from the assumed position and its error ellipse.
     The fix time is the LAST sight, so earlier sights are advanced up to
     it along the run - which is what a running fix is. */
  function solve(CN, aLat, aLon, speed, course) {
    if (!SIGHTS.length) return null;
    var fixjd = SIGHTS[SIGHTS.length - 1].jd;
    var r = CN.solve_fix(SIGHTS, fixjd, speed || 0, course || 0, aLat, aLon, 1);
    var out = { lops: r.sights, ok: r.ok, N: r.N, E: r.E, n: SIGHTS.length };
    if (r.ok && SIGHTS.length >= 2) {
      out.geom = CN.fix_geometry(1.0);
      var cosl = Math.cos(aLat * Math.PI / 180);
      if (Math.abs(cosl) < 0.02) cosl = 0.02;
      out.lat = aLat + r.N / 60.0;
      out.lon = aLon + r.E / (60.0 * cosl);
    }
    return out;
  }

  /* ---- the plotting sheet -------------------------------------------
     North up, the assumed position at the centre, nautical miles.  Each
     sight draws its azimuth from the AP, a tick at the intercept, and the
     LOP perpendicular there - which is how it is done on paper, and means
     the picture can be checked against a plotting sheet by eye. */
  function nice(x) {
    var e = Math.pow(10, Math.floor(Math.log(x) / Math.LN10));
    var m = x / e;
    return (m <= 1 ? 1 : m <= 2 ? 2 : m <= 5 ? 5 : 10) * e;
  }
  function draw(svgNS, host, sol, opts) {
    opts = opts || {};
    host.textContent = '';
    if (!sol || !sol.lops.length) return;
    var W = 420, H = 420, cx = W / 2, cy = H / 2, pad = 26;

    /* scale: everything must fit - the intercepts and the fix */
    var reach = 1;
    sol.lops.forEach(function (L) { reach = Math.max(reach, Math.abs(L.intercept)); });
    if (sol.ok) reach = Math.max(reach, Math.abs(sol.N), Math.abs(sol.E));
    var span = nice(reach * 2.4);
    var k = (Math.min(W, H) / 2 - pad) / (span / 2);     /* px per nm */

    var svg = document.createElementNS(svgNS, 'svg');
    svg.setAttribute('viewBox', '0 0 ' + W + ' ' + H);
    svg.setAttribute('role', 'img');
    svg.setAttribute('aria-label', 'Plotting sheet with ' + sol.lops.length +
      ' line' + (sol.lops.length === 1 ? '' : 's') + ' of position');
    function e(n, a, p) {
      var x = document.createElementNS(svgNS, n);
      for (var q in a) if (a.hasOwnProperty(q)) x.setAttribute(q, a[q]);
      (p || svg).appendChild(x);
      return x;
    }
    var C = opts.css || function () { return '#6fb3d9'; };
    var line = C('--line'), dim = C('--dim'), text = C('--text'),
        accent = C('--accent'), warn = C('--warn'), good = C('--good');

    /* the grid, in whole miles */
    var step = nice(span / 6);
    for (var d = -span; d <= span; d += step) {
      if (Math.abs(d) < 1e-9) continue;
      e('line', { x1: cx + d * k, y1: pad, x2: cx + d * k, y2: H - pad,
                  stroke: line, 'stroke-width': 1, opacity: 0.5 });
      e('line', { x1: pad, y1: cy + d * k, x2: W - pad, y2: cy + d * k,
                  stroke: line, 'stroke-width': 1, opacity: 0.5 });
    }
    e('line', { x1: cx, y1: pad, x2: cx, y2: H - pad, stroke: dim, 'stroke-width': 1.2 });
    e('line', { x1: pad, y1: cy, x2: W - pad, y2: cy, stroke: dim, 'stroke-width': 1.2 });
    var nlab = e('text', { x: cx + 5, y: pad + 12, fill: dim, 'font-size': 12,
                           'font-family': 'ui-monospace, Menlo, monospace' });
    nlab.textContent = 'N';
    var slab = e('text', { x: W - pad, y: cy - 6, fill: dim, 'font-size': 11,
                           'text-anchor': 'end',
                           'font-family': 'ui-monospace, Menlo, monospace' });
    slab.textContent = step + ' nm grid';

    /* the assumed position */
    e('circle', { cx: cx, cy: cy, r: 4, fill: 'none', stroke: dim, 'stroke-width': 1.5 });
    var ap = e('text', { x: cx + 8, y: cy + 14, fill: dim, 'font-size': 11,
                         'font-family': 'ui-monospace, Menlo, monospace' });
    ap.textContent = 'AP';

    /* each line of position */
    sol.lops.forEach(function (L, i) {
      var zn = L.zn * Math.PI / 180;
      /* toward the body if the intercept is positive, away if negative -
         "computed greater, away" is the rule, and the sign here already
         carries it because intercept = Ho - Hc */
      var ux = Math.sin(zn), uy = -Math.cos(zn);          /* screen: y down */
      var px = cx + ux * L.intercept * k, py = cy + uy * L.intercept * k;
      /* the azimuth, drawn faintly from the AP to the intercept point */
      e('line', { x1: cx, y1: cy, x2: px, y2: py, stroke: accent,
                  'stroke-width': 1, opacity: 0.45, 'stroke-dasharray': '4 4' });
      /* the LOP itself: perpendicular to the azimuth, through that point */
      var L2 = Math.max(W, H);
      e('line', { x1: px - uy * L2, y1: py + ux * L2,
                  x2: px + uy * L2, y2: py - ux * L2,
                  stroke: accent, 'stroke-width': 2 });
      var t = e('text', { x: px + uy * 54 + 4, y: py - ux * 54, fill: accent,
                          'font-size': 11, 'font-family': 'ui-monospace, Menlo, monospace' });
      t.textContent = L.name + '  ' + (L.intercept >= 0 ? 'T' : 'A') +
                      Math.abs(L.intercept).toFixed(1);
    });

    /* the fix */
    if (sol.ok && sol.n >= 2) {
      var fx = cx + sol.E * k, fy = cy - sol.N * k;
      if (sol.geom && !sol.geom.parallel) {
        var brg = sol.geom.brg * Math.PI / 180;
        e('ellipse', {
          cx: fx, cy: fy, rx: sol.geom.minor * k, ry: sol.geom.major * k,
          transform: 'rotate(' + (sol.geom.brg) + ' ' + fx + ' ' + fy + ')',
          fill: 'none', stroke: sol.geom.major > 3 ? warn : good,
          'stroke-width': 1.2, 'stroke-dasharray': '5 4', opacity: 0.9
        });
        void brg;
      }
      e('circle', { cx: fx, cy: fy, r: 5.5, fill: 'none',
                    stroke: good, 'stroke-width': 2.5 });
      e('line', { x1: fx - 9, y1: fy, x2: fx + 9, y2: fy, stroke: good, 'stroke-width': 1.5 });
      e('line', { x1: fx, y1: fy - 9, x2: fx, y2: fy + 9, stroke: good, 'stroke-width': 1.5 });
      var ft = e('text', { x: fx + 11, y: fy - 9, fill: good, 'font-size': 12,
                           'font-weight': 700,
                           'font-family': 'ui-monospace, Menlo, monospace' });
      ft.textContent = 'FIX';
    }
    host.appendChild(svg);
  }

  window.CELPLOT = { add: add, remove: remove, clear: clear, all: all,
                     solve: solve, draw: draw };
})();
