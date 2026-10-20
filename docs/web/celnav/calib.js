/* =====================================================================
   Camera calibration from a star field.

   WHY THIS IS NEEDED AT ALL.  Unmodelled barrel distortion is the
   dominant error in a camera sight: k1 = -0.05 costs up to 44 arcminutes
   of altitude, which is forty-four miles.  And a SINGLE star pair cannot
   detect it - at one separation and one frame radius, "longer focal
   length" and "more barrel" produce the same measured angle.  They are
   degenerate.  Breaking that degeneracy needs pairs at DIFFERENT radii,
   which means a field of stars rather than a pair.

   WHAT IT DOES NOT NEED, and this is the useful part: no time, and no
   observer position.  The angle between two stars is a property of the
   sky, not of where or when you stand - and precession, which does move
   every star, is a rigid rotation of the celestial sphere and therefore
   leaves the angles between them alone.  So J2000 catalogue positions
   give the true separations directly.  Proper motion changes them by
   milliarcseconds a year and is ignored.

   Refraction is the one thing that does distort the sky, compressing it
   near the horizon.  Calibrate high up, where it is small and nearly
   uniform; the instructions say so.
   ===================================================================== */
(function () {
  'use strict';
  var R2D = 180 / Math.PI;
  function sind(x) { return Math.sin(x / R2D); }
  function cosd(x) { return Math.cos(x / R2D); }

  /* True angular separation of two catalogue stars, from J2000 RA/Dec. */
  function trueSep(ra1, de1, ra2, de2) {
    var c = sind(de1) * sind(de2) + cosd(de1) * cosd(de2) * cosd(ra1 - ra2);
    return Math.acos(Math.max(-1, Math.min(1, c))) * R2D;
  }

  /* Measured separation of two image points under a trial camera. */
  function measSep(p1, p2, cam) {
    var r1 = ray(p1, cam), r2 = ray(p2, cam);
    var d = r1[0] * r2[0] + r1[1] * r2[1] + r1[2] * r2[2];
    return Math.acos(Math.max(-1, Math.min(1, d))) * R2D;
  }
  function ray(p, cam) {
    var x = (p[0] - cam.cx) / cam.f, y = (p[1] - cam.cy) / cam.f;
    var r2 = x * x + y * y;
    var s = 1 + (cam.k1 || 0) * r2 + (cam.k2 || 0) * r2 * r2;
    x *= s; y *= s;
    var n = Math.sqrt(x * x + y * y + 1);
    return [x / n, y / n, 1 / n];
  }

  /* Physically possible bounds.  Without them the search happily wandered
     off to k1 = +1.4 and a focal length 28% wrong, and reported it with no
     sign of distress - at k1 = -0.10 with half a pixel of centroid noise.
     A confident wrong calibration is worse than no calibration, because
     every sight afterwards inherits it silently. */
  var LIMIT = { k1: 0.5, k2: 0.2, fRel: 0.4 };
  function penalty(cam, f0) {
    var p = 0;
    var over = function (v, lim) { return Math.max(0, Math.abs(v) - lim); };
    p += over(cam.k1, LIMIT.k1) * 1e4;
    p += over(cam.k2, LIMIT.k2) * 1e4;
    p += over((cam.f - f0) / f0, LIMIT.fRel) * 1e4;
    return p;
  }

  /* Residual in arcminutes, root-mean-square over every pair. */
  function cost(obs, cam) {
    var s = 0, n = 0;
    for (var i = 0; i < obs.length; i++)
      for (var j = i + 1; j < obs.length; j++) {
        var d = measSep(obs[i].p, obs[j].p, cam) - obs[i].sepTo[j];
        s += d * d; n++;
      }
    return n ? Math.sqrt(s / n) * 60 : Infinity;
  }

  /* Nelder-Mead over (f, k1, k2).  Small, dependency-free, and good enough
     for three parameters with a sane starting point from EXIF.  Written out
     rather than pulled in, because this page has to work with no network. */
  function nelderMead(f0, obs, cx, cy, start) {
    var scale = [f0 * 0.08, 0.02, 0.01];
    var make = function (v) { return { cx: cx, cy: cy, f: v[0], k1: v[1], k2: v[2] }; };
    var score = function (v) { var c = make(v); return cost(obs, c) + penalty(c, f0); };
    var s0 = start || [f0, 0, 0];
    var S = [s0.slice(),
             [s0[0] + scale[0], s0[1], s0[2]],
             [s0[0], s0[1] + scale[1], s0[2]],
             [s0[0], s0[1], s0[2] + scale[2]]];
    var F = S.map(score);
    var ord = function () {
      var idx = S.map(function (_, i) { return i; })
                 .sort(function (a, b) { return F[a] - F[b]; });
      S = idx.map(function (i) { return S[i]; });
      F = idx.map(function (i) { return F[i]; });
    };
    var add = function (a, b, t) { return a.map(function (x, i) { return x + t * (b[i] - x); }); };
    for (var it = 0; it < 600; it++) {
      ord();
      if (Math.abs(F[0] - F[3]) < 1e-9) break;
      var cen = [0, 0, 0];
      for (var i = 0; i < 3; i++) for (var k = 0; k < 3; k++) cen[k] += S[i][k] / 3;
      var ref = add(cen, S[3], -1), fr = score(ref);
      if (fr < F[0]) {
        var exp = add(cen, S[3], -2), fe = score(exp);
        if (fe < fr) { S[3] = exp; F[3] = fe; } else { S[3] = ref; F[3] = fr; }
      } else if (fr < F[2]) { S[3] = ref; F[3] = fr; }
      else {
        var con = add(cen, S[3], 0.5), fc = score(con);
        if (fc < F[3]) { S[3] = con; F[3] = fc; }
        else for (var m = 1; m < 4; m++) { S[m] = add(S[0], S[m], 0.5); F[m] = score(S[m]); }
      }
    }
    ord();
    var best = make(S[0]);
    return { cam: best, rms: cost(obs, best) };
  }

  /* obs: [{ p:[px,py], ra, dec, name }]  - image point and catalogue position
     Returns the solved camera and how well it fits, in arcminutes. */
  function solveCamera(obs, f0, cx, cy) {
    if (obs.length < 3) return { err: 'Need at least three stars. Four is better.' };
    obs.forEach(function (o, i) {
      o.sepTo = [];
      obs.forEach(function (q, j) {
        o.sepTo[j] = i === j ? 0 : trueSep(o.ra, o.dec, q.ra, q.dec);
      });
    });
    /* Several starting points, best kept.  One start found a garbage minimum
       at strong barrel; the surface is not convex and pretending otherwise
       produced a 28% focal-length error with no warning. */
    var starts = [[f0, 0, 0], [f0, -0.05, 0], [f0, -0.12, 0],
                  [f0 * 0.92, -0.02, 0], [f0 * 1.08, 0.02, 0]];
    var best = null;
    for (var si = 0; si < starts.length; si++) {
      var t = nelderMead(f0, obs, cx, cy, starts[si]);
      if (!best || t.rms < best.rms) best = t;
    }
    /* How well-determined is k1?  If every star sits at a similar radius the
       pairs cannot separate focal length from distortion, and a confident
       answer would be a lie.  Measure the spread of radii and say so. */
    var rr = obs.map(function (o) {
      return Math.hypot(o.p[0] - cx, o.p[1] - cy) / best.cam.f;
    }).sort(function (a, b) { return a - b; });
    var spread = rr[rr.length - 1] - rr[0];
    /* The gate.  A good fit sits well under an arcminute; anything past a
       few means the solve did not converge, or a star was misidentified, or
       the picture is not what it is claimed to be.  Refuse it rather than
       hand back numbers that every later sight will silently inherit. */
    var GATE = 3.0;
    var out = {
      f: best.cam.f, k1: best.cam.k1, k2: best.cam.k2,
      rmsArcmin: best.rms,
      radiusSpread: spread,
      wellPosed: spread > 0.25,
      pairs: obs.length * (obs.length - 1) / 2,
      stars: obs.length,
      accepted: best.rms <= GATE
    };
    if (!out.accepted)
      out.err = 'The stars do not fit any camera: residual ' +
                best.rms.toFixed(1) + " arcmin against a limit of " + GATE +
                '. Check that each star is the one named, and that nothing is ' +
                'cropped or zoomed.';
    else if (!out.wellPosed)
      out.warn = 'All the stars sit at a similar distance from the centre, so ' +
                 'focal length and distortion cannot be told apart. Include a ' +
                 'star near a corner and one near the middle.';
    return out;
  }

  window.CELCALIB = { solveCamera: solveCamera, trueSep: trueSep,
                      measSep: measSep, ray: ray };
  if (typeof module !== 'undefined') module.exports = window.CELCALIB;
})();
