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
  const pad = (n, w, dec) => {
    let s = dec === undefined ? String(int(n)) : n.toFixed(dec);
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

  /*  THE AMPLITUDE, and it is only printed when the body is within two
      degrees of the horizon - which is the whole point of it: on the
      horizon the azimuth can be read off the declination and the latitude
      alone, with no altitude and no reduction.  */
  function amplitude(dec, lat) { return asind(sind(dec) / cosd(lat)); }

  Object.assign(C, {
    parse_ang, fmt_dm, fmt_lat, fmt_lon, fmt_hms, parse_utc,
    solve_fix, fix_geometry, sun_alt, find_cross, moon_ill, angsep,
    lan_jd, pol_lat, plan_sky, amplitude
  });
  return C;
}
if (typeof module !== 'undefined') module.exports = { extendCelnav };
