/* =====================================================================
   celnav engine, part 2: the fix, the planner, parsing and formatting.
   Ported from src/celnav/engine.awk, same two rules as engine.js -
   data lifted rather than retyped, and awk int() is Math.trunc.

   The one shape change: solve_fix() took its sights from a wall of S_*
   globals because awk has no structures.  Here it takes an array of
   sight objects and returns a result object.  The arithmetic is
   unchanged line for line, and the diff harness checks that.
   ===================================================================== */
function extendCelnav(C) {
  const { E, sind, cosd, tand, asind, acosd, atan2d, nrm360, nrm180, fabs } = C;
  const int = Math.trunc;

  /* ---- parsing ----------------------------------------------------- */
  function parse_ang(s) {
    let sign = 1, h = '';
    s = String(s).toUpperCase();
    s = s.replace(/[°'"]/g, ' ').replace(/DEG/g, ' ');
    let t = '';
    for (const ch0 of s) {
      let c = ch0;
      if (c === 'N' || c === 'E') { h = '+'; c = ' '; }
      else if (c === 'S' || c === 'W') { h = '-'; c = ' '; }
      else if (c === '-') { if (/^[ ]*$/.test(t)) sign = -1; c = ' '; }
      else if (c === ':' || c === '/' || c === ',' || c === 'D' || c === 'M') c = ' ';
      t += c;
    }
    const a = t.trim().split(/\s+/).filter(x => x !== '');
    if (a.length === 0) return 'ERR';
    let v = parseFloat(a[0]) || 0;
    if (a.length >= 2) v += (parseFloat(a[1]) || 0) / 60.0;
    if (a.length >= 3) v += (parseFloat(a[2]) || 0) / 3600.0;
    if (h === '-') sign = -1;
    return sign * v;
  }
  /*  printf's %.*f, WHICH IS NOT toFixed().
      C rounds a tie to the EVEN last digit; JavaScript's toFixed rounds
      it up. Deneb's catalogue magnitude is exactly 1.25, so the shell's
      planning table printed 1.2 and the browser printed 1.3 - found by
      docs/web/tests/celnav-plan.js diffing that table row for row, and
      by nothing numerical, because both are the same number.

      A tie at `dec` decimals needs the value to be an odd multiple of
      1/2^(dec+1); any other x.x5 is not exactly representable and the two
      languages already agree which side of the tie it falls. That test is
      exact, because multiplying by a power of two cannot round - and the
      obvious alternative, multiplying by ten and testing for .5, is
      wrong: 2.45 is stored as 2.4500000000000001776 and rounds UP in
      both languages, but ten times it is exactly 24.5.

      This is the engine's, so there is one of it. celnav-app.js formats
      through C.fx() and tests/fmt-check.js holds it to awk's printf.  */
  function fx(v, dec) {
    const h = v * Math.pow(2, dec + 1);
    if (h === Math.round(h) && Math.abs(h) % 2 === 1) {
      const p = Math.pow(10, dec), x = v * p;
      let t = Math.trunc(x);
      if (Math.abs(t) % 2 === 1) t += (x > 0 ? 1 : -1);
      return (t / p).toFixed(dec);
    }
    return v.toFixed(dec);
  }
  const pad = (n, w, dec) => {
    let s = dec === undefined ? String(int(n)) : fx(n, dec);
    while (s.length < w) s = '0' + s;
    return s;
  };
  function fmt_dm(x, w) {
    const neg = x < 0; if (neg) x = -x;
    let d = int(x), m = (x - d) * 60.0;
    if (m >= 59.95) { m = 0; d = d + 1; }
    const s = (w === 3 ? pad(d, 3) : pad(d, 2)) + ' ' + pad(m, 4, 1) + "'";
    return (neg ? '-' : '') + s;
  }
  const fmt_lat = x => fmt_dm(fabs(x), 2) + (x < 0 ? 'S' : 'N');
  const fmt_lon = x => fmt_dm(fabs(x), 3) + (x < 0 ? 'W' : 'E');
  function fmt_hms(h) {
    let hh = int(h), mm = int((h - hh) * 60), ss = int((h - hh - mm / 60.0) * 3600 + 0.5);
    if (ss >= 60) { ss -= 60; mm++; }
    if (mm >= 60) { mm -= 60; hh++; }
    return pad(hh, 2) + ':' + pad(mm, 2) + ':' + pad(ss, 2);
  }
  function parse_utc(s) {
    s = String(s).replace(/[Tt]/g, ' ').replace(/\//g, '-');
    const a = s.trim().split(/\s+/);
    const b = a[0].split('-'), c = (a[1] || '').split(':');
    E.UT_Y = +b[0] || 0; E.UT_MO = +b[1] || 0; E.UT_D = +b[2] || 0;
    E.UT_H = +c[0] || 0; E.UT_MI = +c[1] || 0; E.UT_S = (a.length >= 2 ? (+c[2] || 0) : 0);
    return C.jdate(E.UT_Y, E.UT_MO, E.UT_D) + (E.UT_H + E.UT_MI / 60.0 + E.UT_S / 3600.0) / 24.0;
  }

  /* ---- the fix ------------------------------------------------------
     Least squares over the LOPs.  Each sight is advanced to the fix time
     along the run, reduced from its own assumed position, and the normal
     equations accumulated.  det near zero means the azimuths are parallel
     and there is no fix - which is a real situation at sea, not an error.
     ------------------------------------------------------------------ */
  function solve_fix(sights, fixjd, speed, course, tlat, tlon, keep) {
    let A = 0, B = 0, Cc = 0, D = 0, E2 = 0;
    const det1 = [], zns = [], pps = [];
    for (const s of sights) {
      const dt = (fixjd - s.jd) * 24.0;
      const runN = speed * dt * cosd(course), runE = speed * dt * sind(course);
      const la = tlat - runN / 60.0;
      let cosl = cosd(la); if (fabs(cosl) < 0.02) cosl = 0.02;
      const lo = tlon - runE / (60.0 * cosl);
      C.body_at(s.body, s.jd);
      const ho = C.corrections(s.hs, s.ie, s.he, s.tm, s.pr, s.limb);
      C.reduce_sight(la, lo, E.B_GHA, E.B_DEC);
      const rec = {
        name: E.B_NAME, apLat: la, apLon: lo, ho, ha: E.C_HA,
        hc: E.R_HC, zn: E.R_ZN, lha: E.R_LHA,
        gha: E.B_GHA, dec: E.B_DEC, sd: E.B_SD, hp: E.B_HP,
        intercept: (ho - E.R_HC) * 60.0,
        dip: E.C_DIP, ref: E.C_REF, par: E.C_PAR, limb: E.C_LIMB,
        run: Math.sqrt(runN * runN + runE * runE)
      };
      if (keep) det1.push(rec);
      /*  ZN[] and PP[] in the awk are set whether or not keep is on - the
          residual pass at the converged position asks for keep=0 and then
          reads them.  Same here, so the two agree.  */
      const pp = (ho - E.R_HC) * 60.0;
      zns.push(E.R_ZN); pps.push(pp);
      A += cosd(E.R_ZN) ** 2;
      B += cosd(E.R_ZN) * sind(E.R_ZN);
      Cc += sind(E.R_ZN) ** 2;
      D += pp * cosd(E.R_ZN);
      E2 += pp * sind(E.R_ZN);
    }
    const det = A * Cc - B * B;
    E.NM_A = A; E.NM_B = B; E.NM_C = Cc; E.NM_DET = det;
    if (fabs(det) < 1e-9)
      return { ok: 0, N: 0, E: 0, A, B, C: Cc, det, sights: det1, zn: zns, pp: pps };
    return {
      ok: 1,
      N: (D * Cc - E2 * B) / det,
      E: (A * E2 - B * D) / det,
      A, B, C: Cc, det, sights: det1, zn: zns, pp: pps
    };
  }

  /* The error ellipse, from the same normal matrix.  mu2 is the weakest
     direction, so the major axis is 1/sqrt(mu2) - which is why a narrow
     cut blows up and the tool warns about it rather than reporting a
     confident position. */
  function fix_geometry(sig) {
    sig = sig === undefined ? 1.0 : sig;
    const tr = E.NM_A + E.NM_C;
    const dd = Math.sqrt((E.NM_A - E.NM_C) ** 2 + 4 * E.NM_B * E.NM_B);
    const mu1 = (tr + dd) / 2, mu2 = (tr - dd) / 2;
    if (mu2 <= 1e-9) return { parallel: true };
    return {
      parallel: false,
      major: sig / Math.sqrt(mu2),
      minor: sig / Math.sqrt(mu1),
      brg: nrm360(atan2d(mu2 - E.NM_A, E.NM_B))
    };
  }

  /* ---- local apparent noon, and latitude from Polaris -----------------
     Both are engine functions in the awk - lan_jd() and pol_lat() - and
     both are ported here rather than reimplemented in the screens, so the
     diff harness can hold them to the awk's values at full precision.  */

  /*  LAN is the instant the sun's GHA equals your longitude measured west
      of Greenwich. Solved by iteration rather than from a formula, because
      the sun's GHA is not linear in time - that non-linearity IS the
      equation of time - and five passes settle it to far under a second.
      Five, not "until it converges": the awk does five, and a loop that
      stops on a tolerance would agree with it only by luck.  */
  function lan_jd(lon, jd0) {
    const tgt = nrm360(-lon);
    let jd = jd0 + (12.0 - lon / 15.0) / 24.0;
    for (let i = 0; i < 5; i++) {
      C.body_at('Sun', jd);
      const d = nrm180(tgt - E.B_GHA);
      jd = jd + d / 360.9856;
    }
    return jd;
  }

  /*  Latitude from a star near a pole, in closed form. If Polaris sat on
      the pole its altitude would BE the latitude; it lies a little over
      half a degree off and circles the pole once a day, so the correction
      is "where on that circle is it now", which its LHA says.

          sin Ho = sin L sin d + cos L cos d cos LHA

      rearranges, with A = sin d and B = cos d cos LHA, to

          L = asin( sin Ho / sqrt(A^2 + B^2) ) - atan2(B, A)

      which is what the almanac's a0, a1 and a2 columns approximate with a
      series. The tool solves it instead, and prints both so the gap is
      visible rather than asserted.  */
  function pol_lat(ho, dec, lha) {
    const a = sind(dec), b = cosd(dec) * cosd(lha);
    const r = Math.sqrt(a * a + b * b);
    return asind(sind(ho) / r) - atan2d(b, a);
  }

  /* ---- planning ----------------------------------------------------- */
  function sun_alt(jd, lat, lon) {
    C.body_at('sun', jd);
    C.reduce_sight(lat, lon, E.B_GHA, E.B_DEC);
    return E.R_HC;
  }
  /* Scan the 24h from jd0 for the sun crossing altitude h in the given
     direction, then bisect.  10-minute steps: a coarser scan can step
     straight over a crossing in high latitudes where the sun skims. */
  function find_cross(jd0, lat, lon, h, dirn) {
    let a = sun_alt(jd0, lat, lon);
    for (let t = 1 / 144.0; t <= 1.0; t += 1 / 144.0) {
      const b = sun_alt(jd0 + t, lat, lon);
      if ((dirn > 0 && a < h && b >= h) || (dirn < 0 && a > h && b <= h)) {
        let lo = jd0 + t - 1 / 144.0, hi = jd0 + t;
        for (let i = 0; i < 25; i++) {
          const mid = (lo + hi) / 2;
          if (((sun_alt(mid, lat, lon) < h) ? 1 : 0) === ((dirn > 0) ? 1 : 0)) lo = mid; else hi = mid;
        }
        return (lo + hi) / 2;
      }
      a = b;
    }
    return -1;
  }
  function moon_ill(jd) {
    C.body_at('sun', jd);
    const sr = E.P_RA, sd = E.P_DEC;
    C.body_at('moon', jd);
    const mr = E.P_RA, md = E.P_DEC;
    const el = acosd(sind(sd) * sind(md) + cosd(sd) * cosd(md) * cosd(sr - mr));
    E.MOON_ILL = (1 - cosd(el)) / 2 * 100;
    E.MOON_PH = (nrm360(mr - sr) < 180 ? 'waxing' : 'waning');
    if (E.MOON_ILL < 3) E.MOON_PH = 'new - no moon';
    else if (E.MOON_ILL > 97) E.MOON_PH = 'full';
    return E.MOON_ILL;
  }
  function angsep(a, b) { const d = nrm180(a - b); return fabs(d); }

  /* ---- sight planning ----------------------------------------------
     cmd_plan()'s body gathering, sort and best-three selection, lifted
     whole, because the SELECTION is the part that is easy to get subtly
     different and impossible to eyeball. The screen's twilight times and
     prose live in the app; everything that decides which three bodies to
     recommend lives here, where celnav-diff.js can hold it to the awk.

     The awk's TO[] array is set to 1 and then conditionally to 0 under a
     condition that has already `continue`d the loop, so it is always 1.
     Reproduced as always-1 rather than as the dead branch.
     ------------------------------------------------------------------ */
  function plan_sky(jd, lat, lon) {
    const N = [], A = [], Z = [], M = [];
    const sp = sun_alt(jd, lat, lon);
    //  the sun, the moon and the four planets: gathered whatever their
    //  altitude, and filtered when the table is built
    for (const nm of ['sun', 'moon', 'venus', 'mars', 'jupiter', 'saturn']) {
      C.body_at(nm, jd);
      C.reduce_sight(lat, lon, E.B_GHA, E.B_DEC);
      N.push(E.B_NAME); A.push(E.R_HC); Z.push(E.R_ZN); M.push(+E.B_MAG);
    }
    //  the stars, filtered at 5 and 82 degrees as they are gathered.
    //  NOTE the two different times: star_pos takes TT and the hour angle
    //  is taken from gast(jd) at UT, which is what the awk does.
    const S = C.stars, dt = C.deltaT(E.UT_Y) / 86400.0;
    for (let i = 0; i < S.NSTAR; i++) {
      C.star_pos(i, jd + dt);
      C.reduce_sight(lat, lon, nrm360(C.gast(jd) - E.P_RA), E.P_DEC);
      if (E.R_HC < 5 || E.R_HC > 82) continue;
      N.push(S.SNAME[i]); A.push(E.R_HC); Z.push(E.R_ZN); M.push(+S.SMAG[i]);
    }
    //  the awk's insertion sort by azimuth, written out rather than handed
    //  to Array.sort: equal azimuths have to come out in the same order
    for (let i = 1; i < Z.length; i++) {
      const tz = Z[i], tn = N[i], ta = A[i], tm = M[i];
      let j = i - 1;
      while (j >= 0 && Z[j] > tz) { Z[j+1] = Z[j]; N[j+1] = N[j]; A[j+1] = A[j]; M[j+1] = M[j]; j--; }
      Z[j+1] = tz; N[j+1] = tn; A[j+1] = ta; M[j+1] = tm;
    }
    //  the table: above 5 degrees, and nothing fainter than -3.5 while
    //  the sun is up, because you will not find it
    const rows = [];
    for (let i = 0; i < Z.length; i++) {
      if (A[i] < 5) continue;
      if (sp > -0.9 && M[i] > -3.5) continue;
      rows.push({ name: N[i], alt: A[i], zn: Z[i], mag: M[i],
                  note: A[i] < 15 ? 'low - refraction uncertain'
                      : A[i] > 75 ? 'very high - Zn changes fast' : '' });
    }
    //  the best three: brightest usable, maximising the SMALLEST azimuth
    //  separation of the three pairs. A strict > keeps the first triple
    //  found on a tie, as the awk's does.
    const ok = r => !(r.mag > 2.6 || r.alt < 15 || r.alt > 70);
    let best = -1, bi = -1, bj = -1, bk = -1;
    for (let i = 0; i < rows.length; i++) { if (!ok(rows[i])) continue;
      for (let j = i + 1; j < rows.length; j++) { if (!ok(rows[j])) continue;
        for (let n = j + 1; n < rows.length; n++) { if (!ok(rows[n])) continue;
          const d1 = angsep(rows[i].zn, rows[j].zn),
                d2 = angsep(rows[j].zn, rows[n].zn),
                d3 = angsep(rows[i].zn, rows[n].zn);
          let mn = (d1 < d2 ? d1 : d2); if (d3 < mn) mn = d3;
          if (mn > best) { best = mn; bi = i; bj = j; bk = n; }
        } } }
    return { rows: rows, sunalt: sp, spread: best,
             best: best > 0 ? [bi, bj, bk] : null };
  }

  /* ---- the drills --------------------------------------------------
     drill_gen() and fix_gen() in src/celnav/teach.awk. A drill is a
     generated problem with a known answer, and the generator is where it
     matters that both implementations agree EXACTLY: a seed is the
     problem's name, so "drill red 4821" has to be the same sight in the
     shell and in the browser or the two are not the same study machine.

     That makes the pseudo-random generator part of the specification
     rather than an implementation detail. It is Lehmer's, 16807 modulo
     2^31 - 1, with eight warm-up steps; 16807 x 2147483646 is about
     3.6e13, comfortably inside a double's exact integers, so it is exact
     in both languages and not merely close.
     ------------------------------------------------------------------ */
  let RS_ = 1;
  function xsrand(seed) {
    RS_ = Math.trunc(seed) % 2147483647;
    if (RS_ <= 0) RS_ += 2147483646;
    for (let i = 0; i < 8; i++) RS_ = (16807 * RS_) % 2147483647;
    return 0;
  }
  function xrand() { RS_ = (16807 * RS_) % 2147483647; return RS_ / 2147483647.0; }

  const DRILL_BODIES = ['sun', 'moon', 'venus', 'mars', 'jupiter', 'saturn', 'Sirius',
                        'Vega', 'Dubhe', 'Arcturus', 'Capella', 'Antares', 'Rigel',
                        'Spica', 'Altair', 'Polaris'];
  function drill_body(k) { return DRILL_BODIES[int(k * DRILL_BODIES.length)]; }

  /*  Hs from Ho, by iterating the correction chain backwards. Twelve
      passes, not until it converges: the awk does twelve.  */
  function invert_corr(ho, D) {
    const f = (D.P / 1010.0) * (283.0 / (273.0 + D.T));
    let ha = ho;
    for (let i = 0; i < 12; i++) {
      const refr = f / tand(ha + 7.31 / (ha + 4.4));
      const par = D.HP * cosd(ha);
      let sd = D.SD;
      if (D.NAME === 'Moon' && sd > 0) sd = sd * (1.0 + sind(ha) * D.HP / 3437.75);
      const lim = (D.LIMB === 'L' ? sd : (D.LIMB === 'U' ? -sd : 0));
      ha = ho - (par - refr + lim) / 60.0;
    }
    return ha + D.IE / 60.0 + 1.7594 * Math.sqrt(D.HE) / 60.0;
  }

  /*  one drill problem. Returns null when eighty tries failed to find a
      body between 12 and 72 degrees, which is what the awk's `return 0`
      means and is a real outcome for an unlucky seed.  */
  function drill_gen(kind, seed) {
    xsrand(seed);
    for (let i = 0; i < 3; i++) xrand();
    const D = {};
    D.LAT = int((xrand() * 110 - 55) * 10) / 10.0;
    D.LON = int((xrand() * 360 - 180) * 10) / 10.0;
    D.IE = int((xrand() * 6 - 3) * 10) / 10.0;
    D.HE = int((2 + xrand() * 10) * 10) / 10.0;
    D.T = int(xrand() * 30 - 5);
    D.P = 990 + int(xrand() * 40);
    let ok = 0;
    for (let tries = 0; tries < 80 && !ok; tries++) {
      const y = 2026 + int(xrand() * 7), mo = 1 + int(xrand() * 12), d = 1 + int(xrand() * 28);
      const hh = xrand() * 24;
      D.JD = C.jdate(y, mo, d) + hh / 24.0;
      D.BODY = drill_body(xrand());
      if (C.body_at(D.BODY, D.JD) === 'ERR') continue;
      C.reduce_sight(D.LAT, D.LON, E.B_GHA, E.B_DEC);
      if (E.R_HC < 12 || E.R_HC > 72) continue;
      ok = 1;
    }
    if (!ok) return null;
    C.jd2cal(D.JD);
    D.UTC = pad(E.CAL_Y, 4) + '-' + pad(E.CAL_M, 2) + '-' + pad(E.CAL_D, 2) + ' ' +
            fmt_hms(E.CAL_FRAC * 24);
    D.JD = parse_utc(D.UTC);
    C.body_at(D.BODY, D.JD);
    D.GHA = E.B_GHA; D.DEC = E.B_DEC; D.SD = E.B_SD; D.HP = E.B_HP; D.NAME = E.B_NAME;
    D.LIMB = (D.NAME === 'Sun' || D.NAME === 'Moon') ? ((xrand() < 0.7) ? 'L' : 'U') : 'C';
    C.reduce_sight(D.LAT, D.LON, D.GHA, D.DEC);
    D.HC = E.R_HC; D.ZN = E.R_ZN; D.LHA = E.R_LHA;
    D.OFF = int((xrand() * 24 - 12) * 10) / 10.0;      /* the intercept, nm */
    D.HO = D.HC + D.OFF / 60.0;
    D.HS = invert_corr(D.HO, D);
    D.kind = kind;
    return D;
  }

  /*  the three-star fix drill: three azimuths spread around a random
      base, intercepts ROUNDED to a tenth the way a plotted sheet is, and
      the fix solved back out of the rounded numbers - so the answer is
      what a navigator would actually get, not what the generator started
      from.  */
  function solve3(F) {
    let A = 0, B = 0, Cc = 0, Dd = 0, E2 = 0;
    for (let i = 0; i < 3; i++) {
      A += Math.pow(cosd(F.Z[i]), 2);
      B += cosd(F.Z[i]) * sind(F.Z[i]);
      Cc += Math.pow(sind(F.Z[i]), 2);
      Dd += F.P[i] * cosd(F.Z[i]);
      E2 += F.P[i] * sind(F.Z[i]);
    }
    const det = A * Cc - B * B;
    F.SOL_N = (Dd * Cc - E2 * B) / det;
    F.SOL_E = (A * E2 - B * Dd) / det;
    return 0;
  }
  function fix_gen(seed) {
    xsrand(seed);
    for (let i = 0; i < 5; i++) xrand();
    const F = { Z: [], P: [], N: [] };
    F.LAT = int((xrand() * 100 - 50) * 10) / 10.0;
    F.LON = int((xrand() * 360 - 180) * 10) / 10.0;
    const base = xrand() * 360, sp = 90 + xrand() * 60;
    const dn = int((xrand() * 30 - 15) * 10) / 10.0;
    const de = int((xrand() * 30 - 15) * 10) / 10.0;
    for (let i = 0; i < 3; i++) {
      F.Z[i] = nrm360(base + i * sp + xrand() * 10 - 5);
      F.P[i] = int((dn * cosd(F.Z[i]) + de * sind(F.Z[i])) * 10) / 10.0;
      F.N[i] = drill_body(xrand() * 0.4 + 0.4);
    }
    solve3(F);
    let cl = cosd(F.LAT); if (fabs(cl) < 0.02) cl = 0.02;
    F.FIXLAT = F.LAT + F.SOL_N / 60.0;
    F.FIXLON = F.LON + F.SOL_E / (60.0 * cl);
    return F;
  }

  /* ---- Pub. 249, generated rather than shipped ---------------------
     Every entry in the tables is the navigational triangle solved for
     whole degrees of latitude, declination and LHA, which is what
     reduce_sight() already does for arbitrary arguments. Restrict the
     arguments to integers and the engine IS the table - so there is no
     data file, and the browser can print the exact page a sight needs
     instead of the handful an extract would cover.

     Z IS NOT Zn. The tables print the azimuth ANGLE, 0 to 180, measured
     from the elevated pole, and leave the reader to apply the rule at
     the foot of the page. Teaching that rule is half the point, so the
     page gives Z and the rule, never Zn.
     ------------------------------------------------------------------ */
  function tab_Z(zn, lha, lat) {
    if (lat >= 0) return (nrm360(lha) > 180) ? zn : nrm360(360 - zn);
    return (nrm360(lha) > 180) ? nrm360(180 - zn) : nrm360(zn - 180);
  }
  /*  one entry: the altitude at the whole degree of declination, how much
      it changes per whole degree (the `d` column the minutes are
      interpolated with), and the azimuth angle.
      reduce_sight computes lha = gha + lon, so with lon 0 the GHA
      argument IS the LHA - negating it put the whole table a quadrant
      away, a body east of the meridian, with every altitude still
      correct. cos LHA is even, so nothing in the Hc column could show
      it.  */
  function tab_entry(lat, dec, lha) {
    C.reduce_sight(lat, 0, nrm360(lha), dec);
    const hc1 = E.R_HC;
    E.TB_Z = tab_Z(E.R_ZN, lha, lat);
    C.reduce_sight(lat, 0, nrm360(lha), dec + (dec >= 0 ? 1 : -1));
    E.TB_HC = hc1;
    E.TB_D = (E.R_HC - hc1) * 60;
    return 0;
  }
  /*  THE ENTERING ARGUMENTS, which is where the method actually goes
      wrong. Two of the three are not free choices: the assumed latitude
      is the whole degree nearest the DR, and the assumed longitude is
      whatever makes the LHA a whole number - within half a degree of the
      DR, which is what the two corrections below enforce.  */
  function tab_args(utc, body, drlat, drlon) {
    const jd = parse_utc(utc);
    if (C.body_at(body, jd) === 'ERR') return 0;
    const gha = E.B_GHA, dec = E.B_DEC;
    E.TA_GHA = gha; E.TA_DEC = dec;
    const la = parse_ang(drlat), lo = parse_ang(drlon);
    E.TA_ALAT = int(la + (la >= 0 ? 0.5 : -0.5));
    E.TA_ALON = int(gha + lo + (gha + lo >= 0 ? 0.5 : -0.5)) - gha;
    if (E.TA_ALON - lo > 0.5) E.TA_ALON -= 1;
    if (E.TA_ALON - lo < -0.5) E.TA_ALON += 1;
    E.TA_LHA = nrm360(gha + E.TA_ALON);
    E.TA_LHA = int(E.TA_LHA + 0.5); if (E.TA_LHA === 360) E.TA_LHA = 0;
    E.TA_DECD = int(dec); if (dec < 0) E.TA_DECD = -int(-dec);
    E.TA_DECM = (fabs(dec) - fabs(E.TA_DECD)) * 60;
    return 1;
  }

  /*  THE AMPLITUDE, and it is only printed when the body is within two
      degrees of the horizon - which is the whole point of it: on the
      horizon the azimuth can be read off the declination and the latitude
      alone, with no altitude and no reduction.  */
  function amplitude(dec, lat) { return asind(sind(dec) / cosd(lat)); }

  Object.assign(C, {
    parse_ang, fmt_dm, fmt_lat, fmt_lon, fmt_hms, parse_utc, fx,
    solve_fix, fix_geometry, sun_alt, find_cross, moon_ill, angsep,
    lan_jd, pol_lat, plan_sky, amplitude, tab_Z, tab_entry, tab_args,
    xsrand, xrand, drill_body, invert_corr, drill_gen, fix_gen
  });
  return C;
}
if (typeof module !== 'undefined') module.exports = { extendCelnav };
