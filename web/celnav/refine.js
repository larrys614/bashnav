/* =====================================================================
   Sub-pixel refinement of the two things a camera sight depends on:
   where the horizon is, and where the body's limb is.

   WHY THIS EXISTS.  One pixel is 1.18 arcmin on a full-res phone frame,
   which is 1.2 nautical miles.  A fingertip covers about 40 pixels.  So
   a purely manual "drag the line" interface cannot place the horizon to
   better than tens of miles, and a purely automatic one gives the user no
   way to correct it when haze, a cloud bank or a ship's wake fools it.

   The division of labour: the USER says roughly where, the IMAGE says
   exactly where, and the user can always override and nudge.  Every
   refinement reports how far it moved and how confident it is, so it is
   never silent about what it did.
   ===================================================================== */

/* PIXEL COORDINATE CONVENTION, and it is not a detail: half a pixel is
   0.6 arcmin, which is 0.6 of a nautical mile in the fix.

       An integer coordinate (x, y) is the CENTRE of pixel [x][y].

   So the first pixel's centre is (0, 0), not (0.5, 0.5), and the image
   spans -0.5 .. w-0.5.  Every coordinate handed to or returned by this
   module uses that convention, and the UI must convert touch coordinates
   into it.  Mixing the two conventions costs a constant 0.707 px, which
   is what it did when the test generator disagreed with the sampler. */

/* Greyscale luminance accessor over an ImageData-like {width,height,data}
   with bilinear sampling, because sub-pixel work needs sub-pixel reads. */
function makeSampler(img) {
  const { width: w, height: h, data: d } = img;
  const lum = (x, y) => {
    const i = (y * w + x) * 4;
    return 0.2126 * d[i] + 0.7152 * d[i + 1] + 0.0722 * d[i + 2];
  };
  return function sample(x, y) {
    if (x < 0) x = 0; if (y < 0) y = 0;
    if (x > w - 1.001) x = w - 1.001; if (y > h - 1.001) y = h - 1.001;
    const x0 = Math.floor(x), y0 = Math.floor(y), fx = x - x0, fy = y - y0;
    return lum(x0, y0) * (1 - fx) * (1 - fy) + lum(x0 + 1, y0) * fx * (1 - fy)
         + lum(x0, y0 + 1) * (1 - fx) * fy + lum(x0 + 1, y0 + 1) * fx * fy;
  };
}

/* Find a sub-pixel edge along a 1-D profile by the centroid of |gradient|.
   Centroid rather than peak because the peak is quantised to the sample
   spacing and the centroid is not - which is the whole point. */
function edgeSubpixel(prof, step) {
  const g = [];
  for (let i = 1; i < prof.length - 1; i++) g.push(Math.abs(prof[i + 1] - prof[i - 1]) / 2);
  let gmax = 0, imax = 0;
  g.forEach((v, i) => { if (v > gmax) { gmax = v; imax = i; } });
  if (gmax <= 0) return null;
  /* weight only the shoulder around the peak: a second edge elsewhere in
     the profile (a cloud base, a wave crest) must not drag the centroid */
  let lo = imax, hi = imax;
  while (lo > 0 && g[lo - 1] > gmax * 0.25) lo--;
  while (hi < g.length - 1 && g[hi + 1] > gmax * 0.25) hi++;
  let sw = 0, sx = 0;
  for (let i = lo; i <= hi; i++) { sw += g[i]; sx += g[i] * i; }
  if (sw <= 0) return null;
  return { at: (sx / sw + 1) * step, strength: gmax, width: (hi - lo + 1) * step };
}

/* ---- the horizon --------------------------------------------------
   Sample perpendicular profiles at intervals along the user's line, find
   the edge in each, then refit by least squares.  Profiles whose edge is
   weak or wildly off the line are dropped, because a horizon crossed by a
   ship or a squall line should lose those samples rather than bend. */
/* One pass of the horizon fit.  Kept separate because it is only correct
   when the starting line is already within `span` of the true edge along
   its WHOLE length - see refineHorizon() for why that needs iterating. */
function horizonPass(img, p1, p2, opts) {
  opts = opts || {};
  const span = opts.span === undefined ? 24 : opts.span;     // +- pixels searched
  const nProf = opts.profiles || 40;
  const sample = makeSampler(img);
  const dx = p2[0] - p1[0], dy = p2[1] - p1[1];
  const L = Math.hypot(dx, dy);
  if (L < 10) return { ok: false, why: 'line too short' };
  const ux = dx / L, uy = dy / L;            // along the line
  const nx = -uy, ny = ux;                   // perpendicular
  const pts = [], strengths = [];
  for (let k = 0; k < nProf; k++) {
    const t = (k + 0.5) / nProf;
    const bx = p1[0] + dx * t, by = p1[1] + dy * t;
    const prof = [];
    const step = 0.5;
    for (let s = -span; s <= span; s += step) prof.push(sample(bx + nx * s, by + ny * s));
    const e = edgeSubpixel(prof, step);
    if (!e) continue;
    const off = e.at - span;                  // signed offset from the line
    pts.push([bx + nx * off, by + ny * off, off]);
    strengths.push(e.strength);
  }
  if (pts.length < 4) return { ok: false, why: 'no edge found along the line' };
  /* reject outliers at 2.5 sigma on the offset, then refit */
  const offs = pts.map(p => p[2]);
  const mean = offs.reduce((a, b) => a + b, 0) / offs.length;
  const sd = Math.sqrt(offs.reduce((a, b) => a + (b - mean) ** 2, 0) / offs.length) || 1e-9;
  const keep = pts.filter(p => Math.abs(p[2] - mean) <= 2.5 * sd);
  const use = keep.length >= 4 ? keep : pts;
  /* total least squares in the line's own frame: fit offset vs. along */
  let sa = 0, so = 0, saa = 0, sao = 0;
  for (const p of use) {
    const a = (p[0] - p1[0]) * ux + (p[1] - p1[1]) * uy;
    sa += a; so += p[2]; saa += a * a; sao += a * p[2];
  }
  const n = use.length;
  const den = n * saa - sa * sa;
  const slope = den !== 0 ? (n * sao - sa * so) / den : 0;
  const icept = (so - slope * sa) / n;
  const at = a => [p1[0] + ux * a + nx * (icept + slope * a),
                   p1[1] + uy * a + ny * (icept + slope * a)];
  let rms = 0;
  for (const p of use) {
    const a = (p[0] - p1[0]) * ux + (p[1] - p1[1]) * uy;
    rms += (p[2] - (icept + slope * a)) ** 2;
  }
  rms = Math.sqrt(rms / n);
  return {
    ok: true, p1: at(0), p2: at(L),
    moved: Math.abs(icept), tiltDeg: Math.atan(slope) * 180 / Math.PI,
    used: n, dropped: pts.length - n, rmsPx: rms,
    strength: strengths.reduce((a, b) => a + b, 0) / strengths.length
  };
}

/* COARSE TO FINE, and this is not an optimisation - it is required.
   A single pass only works if the starting line is within `span` of the
   edge along its whole length.  A user who drags a line at the wrong
   ANGLE is far outside that: a 580 px line placed at 8 degrees when the
   horizon is at 20 degrees diverges by 129 px at the far end, so most
   profiles find no edge or the wrong one, and the fit comes back
   confidently 97 px wrong.  Found by synthetic test, not by looking at
   it - on a photograph the result still sits plausibly near the horizon.

   So: start with a span wide enough for a badly angled line, use the
   result as the next guess, and narrow.  The final narrow pass is what
   gives sub-pixel placement; the wide passes only get us into its reach. */
function refineHorizon(img, p1, p2, opts) {
  opts = opts || {};
  const L = Math.hypot(p2[0] - p1[0], p2[1] - p1[1]);
  let span = opts.span === undefined
    ? Math.min(Math.max(32, L * 0.25), img.height / 2 - 2)
    : opts.span;
  const passes = opts.passes || 4;
  let a = p1, b = p2, last = null, history = [];
  for (let i = 0; i < passes; i++) {
    const r = horizonPass(img, a, b, { ...opts, span });
    if (!r.ok) return last || r;
    history.push({ span: Math.round(span), moved: +r.moved.toFixed(2), rms: +r.rmsPx.toFixed(2) });
    a = r.p1; b = r.p2; last = r;
    span = Math.max(4, span / 3);
  }
  return { ...last, p1: a, p2: b, passes: history,
           converged: last.rmsPx < 1.0 };
}

/* ---- the limb -----------------------------------------------------
   Radial profiles outward from the user's rough centre, edge in each,
   then an algebraic circle fit.  Returns the CENTRE, because that is
   what the sight reduction wants; the fitted radius is kept because it
   is an independent check on the plate scale. */
function limbPass(img, centre, radius, opts) {
  opts = opts || {};
  const nRay = opts.rays || 64;
  const span = opts.span === undefined ? Math.max(6, radius * 0.4) : opts.span;
  const sample = makeSampler(img);
  const step = 0.25;
  const hits = [];
  for (let k = 0; k < nRay; k++) {
    const th = 2 * Math.PI * k / nRay;
    const cx = Math.cos(th), cy = Math.sin(th);
    const prof = [];
    for (let s = -span; s <= span; s += step)
      prof.push(sample(centre[0] + cx * (radius + s), centre[1] + cy * (radius + s)));
    const e = edgeSubpixel(prof, step);
    if (!e) continue;
    const r = radius + (e.at - span);
    hits.push([centre[0] + cx * r, centre[1] + cy * r]);
  }
  if (hits.length < 8) return { ok: false, why: 'limb not found' };
  /* Kasa circle fit: linear least squares on x^2+y^2 = 2ax + 2by + c */
  let Sx = 0, Sy = 0, Sxx = 0, Syy = 0, Sxy = 0, Sz = 0, Sxz = 0, Syz = 0;
  for (const [x, y] of hits) {
    const z = x * x + y * y;
    Sx += x; Sy += y; Sxx += x * x; Syy += y * y; Sxy += x * y;
    Sz += z; Sxz += x * z; Syz += y * z;
  }
  const N = hits.length;
  const A = [[2 * Sxx, 2 * Sxy, Sx], [2 * Sxy, 2 * Syy, Sy], [2 * Sx, 2 * Sy, N]];
  const b = [Sxz, Syz, Sz];
  const sol = solve3x3(A, b);
  if (!sol) return { ok: false, why: 'circle fit singular' };
  const [a0, b0, c0] = sol;
  const rr = Math.sqrt(Math.max(0, c0 + a0 * a0 + b0 * b0));
  let rms = 0;
  for (const [x, y] of hits) rms += (Math.hypot(x - a0, y - b0) - rr) ** 2;
  rms = Math.sqrt(rms / N);
  return {
    ok: true, centre: [a0, b0], radius: rr,
    moved: Math.hypot(a0 - centre[0], b0 - centre[1]),
    used: N, rmsPx: rms
  };
}

/* Same reason as the horizon: if the rough centre or radius is off by more
   than the search annulus is wide, much of the limb falls outside it and
   the circle fit is confidently wrong.  Start wide, narrow, repeat. */
function refineLimb(img, centre, radius, opts) {
  opts = opts || {};
  let span = opts.span === undefined ? Math.max(10, radius * 0.75) : opts.span;
  const passes = opts.passes || 4;
  let c = centre, r = radius, last = null, history = [];
  for (let i = 0; i < passes; i++) {
    const res = limbPass(img, c, r, { ...opts, span });
    if (!res.ok) return last || res;
    history.push({ span: +span.toFixed(1), moved: +res.moved.toFixed(2), rms: +res.rmsPx.toFixed(2) });
    c = res.centre; r = res.radius; last = res;
    span = Math.max(2.5, span / 2.5);
  }
  return { ...last, centre: c, radius: r, passes: history,
           moved: Math.hypot(c[0] - centre[0], c[1] - centre[1]),
           converged: last.rmsPx < 0.75 };
}

function solve3x3(A, b) {
  const M = A.map((r, i) => [...r, b[i]]);
  for (let c = 0; c < 3; c++) {
    let piv = c;
    for (let r = c + 1; r < 3; r++) if (Math.abs(M[r][c]) > Math.abs(M[piv][c])) piv = r;
    if (Math.abs(M[piv][c]) < 1e-12) return null;
    [M[c], M[piv]] = [M[piv], M[c]];
    for (let r = 0; r < 3; r++) {
      if (r === c) continue;
      const f = M[r][c] / M[c][c];
      for (let k = c; k < 4; k++) M[r][k] -= f * M[c][k];
    }
  }
  return [M[0][3] / M[0][0], M[1][3] / M[1][1], M[2][3] / M[2][2]];
}

if (typeof window !== 'undefined') window.REFINE = { makeSampler, edgeSubpixel, refineHorizon, refineLimb, horizonPass, limbPass };
if (typeof module !== 'undefined') module.exports = { makeSampler, edgeSubpixel, refineHorizon, refineLimb,
                   horizonPass, limbPass, solve3x3 };

