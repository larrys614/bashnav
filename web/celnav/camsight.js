/* =====================================================================
   camsight -- measuring a sextant altitude from a photograph.

   THE FORMULATION, because the obvious one is wrong.

   The tempting approach is "count pixels from the horizon up to the body
   and convert with atan(y/f)".  That is only correct for a body sitting
   on the frame's vertical centre line.  Off to one side it is wrong, and
   wrong by more the further off-axis and the more the camera is rolled -
   which on a boat is always.

   The correct formulation is cleaner anyway.  The visible horizon is the
   intersection of a PLANE through the camera centre with the image, so
   fit the horizon line, take two points on it, turn them into rays, and
   their cross product is that plane's normal n.  The body is another ray
   b.  The altitude of the body above the horizon is then

       Hs = asin( b . n )

   which is exact, needs no assumption about where in the frame anything
   sits, and handles camera roll for free - the horizon can run diagonally
   across the picture and the answer does not change.  That is the same
   property that makes a sextant a differential instrument.
   ===================================================================== */
const R2D = 180 / Math.PI;

/* ---- the camera model ------------------------------------------------
   f in pixels from the 35mm-equivalent focal length in EXIF.  The 35mm
   frame is 36 x 24 mm, and the equivalent length is referred to the LONG
   side, so it divides by the long pixel dimension. */
function fpxFrom35mm(focal35mm, wPx, hPx) {
  return focal35mm * Math.max(wPx, hPx) / 36.0;
}
function fpxFromHfov(hfovDeg, wPx) {
  return (wPx / 2) / Math.tan(hfovDeg / 2 / R2D);
}

/* Undo radial distortion: r_true = r * (1 + k1 r^2 + k2 r^4), r in units
   of f so the coefficients are dimensionless and portable between
   resolutions of the same lens. */
function undistort(px, py, cam) {
  const x = (px - cam.cx) / cam.f, y = (py - cam.cy) / cam.f;
  const r2 = x * x + y * y;
  const s = 1 + (cam.k1 || 0) * r2 + (cam.k2 || 0) * r2 * r2;
  return [x * s, y * s];
}
/* An image point as a unit ray in camera coordinates. */
function ray(px, py, cam) {
  const [x, y] = undistort(px, py, cam);
  const n = Math.sqrt(x * x + y * y + 1);
  return [x / n, y / n, 1 / n];
}
const cross = (a, b) => [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]];
const dot = (a, b) => a[0]*b[0] + a[1]*b[1] + a[2]*b[2];
function unit(v) { const n = Math.hypot(v[0], v[1], v[2]); return [v[0]/n, v[1]/n, v[2]/n]; }

/* ---- the measurement --------------------------------------------------
   horizon: two or more points along the visible horizon, in image pixels.
   body:    the body's centre, or the limb that was photographed.
   Returns Hs in degrees - the raw sextant-equivalent altitude, which then
   goes through the engine's existing corrections() unchanged. */
function measureHs(horizonPts, bodyPt, cam) {
  if (horizonPts.length < 2) throw new Error('need two horizon points');
  /* With more than two points, fit the plane by least squares on the rays:
     the normal is the smallest singular vector.  With exactly two, the
     cross product is that answer. */
  let n;
  if (horizonPts.length === 2) {
    n = unit(cross(ray(horizonPts[0][0], horizonPts[0][1], cam),
                   ray(horizonPts[1][0], horizonPts[1][1], cam)));
  } else {
    const rs = horizonPts.map(p => ray(p[0], p[1], cam));
    /* normal = eigenvector of the scatter matrix with the smallest
       eigenvalue; three points or more, solved by power iteration on the
       inverse via the adjugate - small and dependency-free. */
    const M = [[0,0,0],[0,0,0],[0,0,0]];
    for (const r of rs) for (let i = 0; i < 3; i++) for (let j = 0; j < 3; j++) M[i][j] += r[i]*r[j];
    n = smallestEigenvector(M);
  }
  const b = ray(bodyPt[0], bodyPt[1], cam);
  /* Sign: the body is above the horizon, so take the normal that points
     the body's way. */
  let s = dot(b, n);
  if (s < 0) { n = [-n[0], -n[1], -n[2]]; s = -s; }
  return { hs: Math.asin(s) * R2D, normal: n, bodyRay: b };
}

/* Smallest eigenvector of a 3x3 symmetric positive matrix, by inverse
   iteration.  Deliberately tiny: this ships in a page that must work with
   no network, so it carries no linear algebra library. */
function smallestEigenvector(M) {
  const tr = M[0][0] + M[1][1] + M[2][2];
  const A = [[tr - M[0][0], -M[0][1], -M[0][2]],
             [-M[1][0], tr - M[1][1], -M[1][2]],
             [-M[2][0], -M[2][1], tr - M[2][2]]];
  let v = [0, 1, 0];
  for (let it = 0; it < 200; it++) {
    const w = [A[0][0]*v[0]+A[0][1]*v[1]+A[0][2]*v[2],
               A[1][0]*v[0]+A[1][1]*v[1]+A[1][2]*v[2],
               A[2][0]*v[0]+A[2][1]*v[1]+A[2][2]*v[2]];
    v = unit(w);
  }
  return v;
}

/* ---- calibration from a star pair -------------------------------------
   The engine knows any two catalogue stars' true angular separation to
   arcseconds, so one photograph containing both solves f.  Measured
   separation is a monotonic function of f, so bisect rather than
   differentiate - robust, and fast enough at 60 iterations. */
function angleBetweenPoints(p1, p2, cam) {
  return Math.acos(Math.min(1, Math.max(-1,
    dot(ray(p1[0], p1[1], cam), ray(p2[0], p2[1], cam))))) * R2D;
}
function solveFocal(p1, p2, trueSepDeg, cam) {
  let lo = 100, hi = 100000;
  for (let i = 0; i < 60; i++) {
    const mid = (lo + hi) / 2;
    const got = angleBetweenPoints(p1, p2, { ...cam, f: mid });
    /* larger f = narrower field = smaller measured separation */
    if (got > trueSepDeg) lo = mid; else hi = mid;
  }
  return (lo + hi) / 2;
}

/* ---- synthesis, for the tests -----------------------------------------
   Project a direction into the image, given a camera attitude.  Used only
   by the test harness, but it lives here so the projection and the
   measurement cannot drift apart. */
function makeCam(wPx, hPx, f, k1, k2) {
  return { w: wPx, h: hPx, cx: wPx / 2, cy: hPx / 2, f, k1: k1 || 0, k2: k2 || 0 };
}
function project(v, cam) {
  if (v[2] <= 0) return null;                       // behind the camera
  let x = v[0] / v[2], y = v[1] / v[2];
  /* forward distortion: invert r_true = r(1+k1 r^2+k2 r^4) numerically */
  if (cam.k1 || cam.k2) {
    const rt = Math.hypot(x, y);
    let r = rt;
    for (let i = 0; i < 40; i++) {
      const s = 1 + cam.k1 * r * r + cam.k2 * r ** 4;
      r = rt / s;
    }
    const s = rt > 0 ? r / rt : 1;
    x *= s; y *= s;
  }
  return [cam.cx + x * cam.f, cam.cy + y * cam.f];
}
/* Rotate a world direction into camera frame: camera looks along +Z with
   the given azimuth, pitch (up positive) and roll. */
function worldToCam(altDeg, azDeg, camAzDeg, pitchDeg, rollDeg) {
  const a = altDeg / R2D, z = azDeg / R2D;
  let v = [Math.cos(a) * Math.sin(z), Math.sin(a), Math.cos(a) * Math.cos(z)]; // E, Up, N
  /* Rotate the world so the camera's azimuth lies along +Z.  The sign
     matters and is easy to get backwards: this must give sin(z - camAz),
     not sin(z + camAz), or every body lands behind the camera. */
  const ca = Math.cos(camAzDeg / R2D), sa = Math.sin(camAzDeg / R2D);
  v = [v[0] * ca - v[2] * sa, v[1], v[0] * sa + v[2] * ca];
  const cp = Math.cos(pitchDeg / R2D), sp = Math.sin(pitchDeg / R2D);
  v = [v[0], v[1] * cp - v[2] * sp, v[1] * sp + v[2] * cp];
  const cr = Math.cos(rollDeg / R2D), sr = Math.sin(rollDeg / R2D);
  v = [v[0] * cr - v[1] * sr, v[0] * sr + v[1] * cr, v[2]];
  /* camera image y runs DOWN, world y runs UP */
  return [v[0], -v[1], v[2]];
}

if (typeof window !== 'undefined') window.CAMSIGHT = { fpxFrom35mm, fpxFromHfov, undistort, ray, measureHs, angleBetweenPoints, solveFocal, makeCam, project, worldToCam };
if (typeof module !== 'undefined') module.exports = { fpxFrom35mm, fpxFromHfov, undistort, ray, measureHs,
                   angleBetweenPoints, solveFocal, makeCam, project,
                   worldToCam, smallestEigenvector };

