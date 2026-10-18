/* =====================================================================
   celnav engine -- offline celestial navigation core, ported from
   src/celnav/engine.awk function-for-function.

   Two rules governed this port and both are worth knowing before editing:

   1. The DATA was not retyped.  ML_TAB, MB_TAB, STAR_TAB, PL_TAB and the
      fitted CORR tables are the awk engine's own byte strings, dumped by
      work-celnav/dumptab.awk and parsed here with the same split logic.
      Thousands of fitted coefficients retyped by hand is a defect waiting
      to happen, and it would pass a spot check at one epoch and fail at
      another.

   2. awk's int() TRUNCATES toward zero.  It is Math.trunc, never
      Math.floor.  jdate(), jd2cal() and nrm360() all depend on it, and
      with Math.floor the Julian Day is a day out for negative arguments.

   Verified against 20,568 rows emitted by the awk engine itself - 140
   epochs x 17 bodies, 11,424 sight reductions over the whole sphere, and
   6,624 correction-chain cases.  See work-celnav/diff.js.
   ===================================================================== */

function makeCelnav(T) {           // T = the dumped tables object
  const E = {};                    // engine globals, named as in the awk

  /* ---- math ------------------------------------------------------- */
  const d2r = x => x * 0.0174532925199432958;
  const r2d = x => x * 57.2957795130823209;
  const sind = x => Math.sin(x * 0.0174532925199432958);
  const cosd = x => Math.cos(x * 0.0174532925199432958);
  const tand = x => Math.sin(x * 0.0174532925199432958) / Math.cos(x * 0.0174532925199432958);
  const asind = x => (x >= 1 ? 90 : x <= -1 ? -90 : r2d(Math.atan2(x, Math.sqrt(1 - x * x))));
  const acosd = x => (x >= 1 ? 0 : x <= -1 ? 180 : r2d(Math.atan2(Math.sqrt(1 - x * x), x)));
  const atan2d = (y, x) => r2d(Math.atan2(y, x));
  /* Math.trunc, not Math.floor - see the header. */
  const nrm360 = x => { x = x - 360 * Math.trunc(x / 360); return x < 0 ? x + 360 : x; };
  const nrm180 = x => { x = nrm360(x); return x > 180 ? x - 360 : x; };
  const fabs = Math.abs;
  const int = Math.trunc;

  /* ---- time ------------------------------------------------------- */
  function jdate(y, m, d) {
    if (m <= 2) { y = y - 1; m = m + 12; }
    const a = int(y / 100), b = 2 - a + int(a / 4);
    return int(365.25 * (y + 4716)) + int(30.6001 * (m + 1)) + d + b - 1524.5;
  }
  function jd2cal(jd) {
    jd = jd + 0.5;
    const z = int(jd), f = jd - z;
    let a;
    if (z < 2299161) { a = z; }
    else { const al = int((z - 1867216.25) / 36524.25); a = z + 1 + al - int(al / 4); }
    const b = a + 1524, c = int((b - 122.1) / 365.25), d = int(365.25 * c),
          e = int((b - d) / 30.6001), dd = b - d - int(30.6001 * e) + f;
    E.CAL_M = (e < 14) ? e - 1 : e - 13;
    E.CAL_Y = (E.CAL_M > 2) ? c - 4716 : c - 4715;
    E.CAL_D = int(dd); E.CAL_FRAC = dd - E.CAL_D;
    return E.CAL_Y;
  }
  function deltaT(y) {
    if (E.DT_OVERRIDE !== undefined && E.DT_OVERRIDE !== '') return +E.DT_OVERRIDE;
    if (y < 1961) return 33;
    if (y < 1986) { const t = y - 1975; return 45.45 + 1.067 * t - t * t / 260 - t * t * t / 718; }
    if (y < 2005) { const t = y - 2000;
      return 63.86 + 0.3345 * t - 0.060374 * t * t + 0.0017275 * t * t * t
           + 0.000651814 * t * t * t * t + 0.00002373599 * t * t * t * t * t; }
    if (y < 2020) return 64.7 + (y - 2005) * (69.36 - 64.7) / 15;
    if (y < 2026) return 69.36 - (y - 2020) * 0.03;
    return 69.2 + (y - 2026) * 0.10;
  }
  function nutation(Tc) {
    const om = nrm360(125.04452 - 1934.136261 * Tc + 0.0020708 * Tc * Tc);
    const ls = nrm360(280.4665 + 36000.7698 * Tc);
    const lm = nrm360(218.3165 + 481267.8813 * Tc);
    E.DPSI = -17.20 * sind(om) - 1.32 * sind(2 * ls) - 0.23 * sind(2 * lm) + 0.21 * sind(2 * om);
    E.DEPS = 9.20 * cosd(om) + 0.57 * cosd(2 * ls) + 0.10 * cosd(2 * lm) - 0.09 * cosd(2 * om);
    E.EPS0 = 23.439291111 - 0.0130041667 * Tc - 0.00000016389 * Tc * Tc + 0.0000005036 * Tc * Tc * Tc;
    E.EPS = E.EPS0 + E.DEPS / 3600;
    return E.EPS;
  }
  function gast(jdut) {
    const Tc = (jdut - 2451545.0) / 36525.0;
    const gm = 280.46061837 + 360.98564736629 * (jdut - 2451545.0)
             + 0.000387933 * Tc * Tc - Tc * Tc * Tc / 38710000.0;
    nutation(Tc);
    return nrm360(gm + (E.DPSI * cosd(E.EPS)) / 3600.0);
  }

  /* ---- tables: parsed from the engine's own strings ---------------- */
  const LD = [], LM = [], LMP = [], LF = [], LCL = [], LCR = [];
  const BD = [], BM = [], BMP = [], BF = [], BCB = [];
  T.ML_TAB.split(';').forEach(row => {
    const a = row.trim().split(/\s+/).map(Number);
    LD.push(a[0]); LM.push(a[1]); LMP.push(a[2]); LF.push(a[3]); LCL.push(a[4]); LCR.push(a[5]);
  });
  T.MB_TAB.split(';').forEach(row => {
    const a = row.trim().split(/\s+/).map(Number);
    BD.push(a[0]); BM.push(a[1]); BMP.push(a[2]); BF.push(a[3]); BCB.push(a[4]);
  });
  const NL = LD.length, NB = BD.length;

  const SNUM = [], SNAME = [], SRA = [], SDEC = [], SPMR = [], SPMD = [], SMAG = [];
  const SIDX = new Map();
  T.STAR_TAB.split(';').forEach((row, i) => {
    const a = row.split('|');
    SNUM[i] = +a[0]; SNAME[i] = a[1]; SRA[i] = +a[2]; SDEC[i] = +a[3];
    SPMR[i] = +a[4]; SPMD[i] = +a[5]; SMAG[i] = +a[6];
    SIDX.set(a[1].toLowerCase(), i); SIDX.set(String(+a[0]), i);
  });
  const NSTAR = SNAME.length;
  SIDX.set("al na'ir", SIDX.get('alnair'));
  SIDX.set('rigil kent', SIDX.get('rigil kentaurus'));
  SIDX.set('kaus aust', SIDX.get('kaus australis'));
  SIDX.set("zuben'ubi", SIDX.get('zubenelgenubi'));
  SIDX.set('polaris', NSTAR - 1);            // awk: SIDX["polaris"]=NSTAR (1-based)

  const PL_TAB = T.PL_TAB;
  const CORR = T.CORR;                        // keys "body|lam" etc.

  function corrval(tab, Tc) {
    if (!tab) return 0;
    const a = tab.split(';');
    let m = a[0].trim().split(/\s+/).map(Number);
    let v = m[0] + m[1] * Tc;
    for (let i = 1; i < a.length; i++) {
      m = a[i].trim().split(/\s+/).map(Number);
      const s = m[0] + m[1] * Tc;
      v += m[2] * sind(s) + m[3] * cosd(s);
    }
    return v;
  }

  /* ---- sun -------------------------------------------------------- */
  function sun_pos(jdtt) {
    earth_state(jdtt);
    const gx = -E.EX, gy = -E.EY, gz = -E.EZ;
    const R = Math.sqrt(gx * gx + gy * gy + gz * gz);
    ecl2eq(gx, gy, gz);
    const n = Math.sqrt(E.QX * E.QX + E.QY * E.QY + E.QZ * E.QZ);
    E.QX /= n; E.QY /= n; E.QZ /= n;
    aberrate();
    const ra = nrm360(atan2d(E.QY, E.QX)), dec = asind(E.QZ);
    precess_nutate(ra, dec, jdtt);
    E.P_DIST = R;
    E.P_SD = 15.993833 / R;
    E.P_HP = 0.14656667 / R;
    return E.P_RA;
  }

  /* ---- moon ------------------------------------------------------- */
  function moon_pos(jdtt) {
    const Tc = (jdtt - 2451545.0) / 36525.0;
    const Lp = nrm360(218.3164477 + 481267.88123421 * Tc - 0.0015786 * Tc * Tc
                      + Tc ** 3 / 538841.0 - Tc ** 4 / 65194000.0);
    const D = nrm360(297.8501921 + 445267.1114034 * Tc - 0.0018819 * Tc * Tc
                      + Tc ** 3 / 545868.0 - Tc ** 4 / 113065000.0);
    const M = nrm360(357.5291092 + 35999.0502909 * Tc - 0.0001536 * Tc * Tc + Tc ** 3 / 24490000.0);
    const Mp = nrm360(134.9633964 + 477198.8675055 * Tc + 0.0087414 * Tc * Tc
                      + Tc ** 3 / 69699.0 - Tc ** 4 / 14712000.0);
    const F = nrm360(93.2720950 + 483202.0175233 * Tc - 0.0036539 * Tc * Tc
                      - Tc ** 3 / 3526000.0 + Tc ** 4 / 863310000.0);
    const A1 = nrm360(119.75 + 131.849 * Tc);
    const A2 = nrm360(53.09 + 479264.290 * Tc);
    const A3 = nrm360(313.45 + 481266.484 * Tc);
    const Ec = 1 - 0.002516 * Tc - 0.0000074 * Tc * Tc;
    let sl = 0, sr = 0, sb = 0, arg, f;
    for (let i = 0; i < NL; i++) {
      arg = LD[i] * D + LM[i] * M + LMP[i] * Mp + LF[i] * F;
      f = 1;
      if (LM[i] === 1 || LM[i] === -1) f = Ec;
      else if (LM[i] === 2 || LM[i] === -2) f = Ec * Ec;
      sl += LCL[i] * f * sind(arg);
      sr += LCR[i] * f * cosd(arg);
    }
    for (let i = 0; i < NB; i++) {
      arg = BD[i] * D + BM[i] * M + BMP[i] * Mp + BF[i] * F;
      f = 1;
      if (BM[i] === 1 || BM[i] === -1) f = Ec;
      else if (BM[i] === 2 || BM[i] === -2) f = Ec * Ec;
      sb += BCB[i] * f * sind(arg);
    }
    sl += 3958 * sind(A1) + 1962 * sind(Lp - F) + 318 * sind(A2);
    sb += -2235 * sind(Lp) + 382 * sind(A3) + 175 * sind(A1 - F) + 175 * sind(A1 + F)
        + 127 * sind(Lp - Mp) - 115 * sind(Lp + Mp);
    let lam = Lp + sl / 1000000.0;
    const bet = sb / 1000000.0;
    const dist = 385000.56 + sr / 1000.0;
    const eps = nutation(Tc);
    lam = lam + E.DPSI / 3600.0;
    const x = cosd(bet) * cosd(lam);
    const y = cosd(eps) * cosd(bet) * sind(lam) - sind(eps) * sind(bet);
    const z = sind(eps) * cosd(bet) * sind(lam) + cosd(eps) * sind(bet);
    E.P_RA = nrm360(atan2d(y, x));
    E.P_DEC = asind(z);
    E.P_DIST = dist;
    E.P_HP = r2d(Math.atan2(6378.14 / dist, 1)) * 60.0;
    E.P_SD = r2d(Math.atan2(1737.4 / dist, 1)) * 60.0;
    return E.P_RA;
  }

  /* ---- planets ---------------------------------------------------- */
  function kepler(M, e) {
    M = nrm180(M);
    let Ee = M + (180 / 3.14159265358979) * e * sind(M), dE;
    for (let i = 0; i < 12; i++) {
      dE = (Ee - (180 / 3.14159265358979) * e * sind(Ee) - M) / (1 - e * cosd(Ee));
      Ee = Ee - dE;
      if (fabs(dE) < 1e-11) break;
    }
    return Ee;
  }
  function helio(body, jdtt) {
    const Tc = (jdtt - 2451545.0) / 36525.0;
    const el = PL_TAB[body].trim().split(/\s+/).map(Number);
    const a = el[0] + el[6] * Tc, e = el[1] + el[7] * Tc, I = el[2] + el[8] * Tc;
    const L = el[3] + el[9] * Tc, pe = el[4] + el[10] * Tc, no = el[5] + el[11] * Tc;
    const M = nrm180(L - pe), w = pe - no;
    const Ee = kepler(M, e);
    const xv = a * (cosd(Ee) - e), yv = a * Math.sqrt(1 - e * e) * sind(Ee);
    const cosw = cosd(w), sinw = sind(w), co = cosd(no), so = sind(no),
          ci = cosd(I), si = sind(I);
    E.HX = (cosw * co - sinw * so * ci) * xv + (-sinw * co - cosw * so * ci) * yv;
    E.HY = (cosw * so + sinw * co * ci) * xv + (-sinw * so + cosw * co * ci) * yv;
    E.HZ = (sinw * si) * xv + (cosw * si) * yv;
    if ((body + '|lam') in CORR) {
      let rr = Math.sqrt(E.HX * E.HX + E.HY * E.HY + E.HZ * E.HZ);
      const lm = nrm360(atan2d(E.HY, E.HX)) + corrval(CORR[body + '|lam'], Tc) / 60.0;
      const bt = asind(E.HZ / rr) + corrval(CORR[body + '|bet'], Tc) / 60.0;
      rr = rr + corrval(CORR[body + '|r'], Tc) * 0.000001;
      E.HX = rr * cosd(bt) * cosd(lm); E.HY = rr * cosd(bt) * sind(lm); E.HZ = rr * sind(bt);
    }
    return 0;
  }
  function earth_state(jdtt) {
    helio('earth', jdtt); E.EX = E.HX; E.EY = E.HY; E.EZ = E.HZ;
    helio('earth', jdtt - 0.5);
    const x1 = E.HX, y1 = E.HY, z1 = E.HZ;
    helio('earth', jdtt + 0.5);
    E.EVX = E.HX - x1; E.EVY = E.HY - y1; E.EVZ = E.HZ - z1;
    return 0;
  }
  function ecl2eq(x, y, z) {
    const ce = cosd(23.4392911), se = sind(23.4392911);
    E.QX = x; E.QY = ce * y - se * z; E.QZ = se * y + ce * z;
    return 0;
  }
  function aberrate() {
    const ce = cosd(23.4392911), se = sind(23.4392911);
    const vx = E.EVX, vy = ce * E.EVY - se * E.EVZ, vz = se * E.EVY + ce * E.EVZ;
    E.QX += vx / 173.144633; E.QY += vy / 173.144633; E.QZ += vz / 173.144633;
    const n = Math.sqrt(E.QX * E.QX + E.QY * E.QY + E.QZ * E.QZ);
    E.QX /= n; E.QY /= n; E.QZ /= n;
    return 0;
  }
  function precess_nutate(ra, dec, jdtt) {
    const Tc = (jdtt - 2451545.0) / 36525.0;
    const ze = (2306.2181 * Tc + 0.30188 * Tc * Tc + 0.017998 * Tc ** 3) / 3600.0;
    const z = (2306.2181 * Tc + 1.09468 * Tc * Tc + 0.018203 * Tc ** 3) / 3600.0;
    const th = (2004.3109 * Tc - 0.42665 * Tc * Tc - 0.041833 * Tc ** 3) / 3600.0;
    const A = cosd(dec) * sind(ra + ze);
    const B = cosd(th) * cosd(dec) * cosd(ra + ze) - sind(th) * sind(dec);
    const C = sind(th) * cosd(dec) * cosd(ra + ze) + cosd(th) * sind(dec);
    const ra1 = nrm360(z + atan2d(A, B));
    const de1 = asind(C);
    const eps = nutation(Tc);
    const dra = ((cosd(eps) + sind(eps) * sind(ra1) * tand(de1)) * E.DPSI
                 - cosd(ra1) * tand(de1) * E.DEPS) / 3600.0;
    const dde = (sind(eps) * cosd(ra1) * E.DPSI + sind(ra1) * E.DEPS) / 3600.0;
    E.P_RA = nrm360(ra1 + dra);
    E.P_DEC = de1 + dde;
    return 0;
  }
  function planet_pos(body, jdtt) {
    earth_state(jdtt);
    let tau = 0, gx = 0, gy = 0, gz = 0, d = 0;
    for (let i = 0; i < 3; i++) {
      helio(body, jdtt - tau);
      gx = E.HX - E.EX; gy = E.HY - E.EY; gz = E.HZ - E.EZ;
      d = Math.sqrt(gx * gx + gy * gy + gz * gz);
      tau = d / 173.144633;
    }
    ecl2eq(gx, gy, gz);
    d = Math.sqrt(E.QX * E.QX + E.QY * E.QY + E.QZ * E.QZ);
    E.QX /= d; E.QY /= d; E.QZ /= d;
    aberrate();
    const ra = nrm360(atan2d(E.QY, E.QX)), dec = asind(E.QZ);
    precess_nutate(ra, dec, jdtt);
    E.P_DIST = d; E.P_SD = 0; E.P_HP = 0;      /* awk: 0.14657/d*0 */
    return 0;
  }

  /* ---- stars ------------------------------------------------------ */
  function star_pos(i, jdtt) {                 // i is 0-based here
    const yr = (jdtt - 2451545.0) / 365.25;
    let dec = SDEC[i] + SPMD[i] * yr / 3600000.0;
    let ra = SRA[i] + SPMR[i] * yr / 3600000.0 / cosd(SDEC[i]);
    earth_state(jdtt);
    E.QX = cosd(dec) * cosd(ra); E.QY = cosd(dec) * sind(ra); E.QZ = sind(dec);
    aberrate();
    ra = nrm360(atan2d(E.QY, E.QX)); dec = asind(E.QZ);
    precess_nutate(ra, dec, jdtt);
    E.P_DIST = 0; E.P_SD = 0; E.P_HP = 0;
    return 0;
  }
  function star_lookup(key) {                  // returns 0-based index, or -1
    const k = String(key).toLowerCase();
    if (SIDX.has(k)) return SIDX.get(k);
    const n = parseFloat(key);
    if (!isNaN(n) && n > 0 && SIDX.has(String(n))) return SIDX.get(String(n));
    return -1;
  }
  function planet_mag(n) {
    if (n === 'venus') return -4.0;
    if (n === 'mars') return 0.7;
    if (n === 'jupiter') return -2.2;
    if (n === 'saturn') return 0.6;
    return 0.0;
  }

  /* ---- the body, as observed -------------------------------------- */
  function body_at(name, jdut) {
    jd2cal(jdut);
    const tt = jdut + deltaT(E.CAL_Y) / 86400.0;
    const lname = String(name).toLowerCase();
    E.B_MAG = '';
    if (lname === 'sun') { sun_pos(tt); E.B_NAME = 'Sun'; E.B_MAG = -26.7; }
    else if (lname === 'moon') {
      moon_pos(tt); E.B_NAME = 'Moon'; E.P_SD = 0.2725 * E.P_HP; E.B_MAG = -12;
    } else if (['venus','mars','jupiter','saturn','mercury'].includes(lname)) {
      planet_pos(lname, tt);
      E.B_NAME = lname.charAt(0).toUpperCase() + lname.slice(1);
      E.B_MAG = planet_mag(lname);
    } else {
      const i = star_lookup(name);
      if (i < 0) return 'ERR';
      star_pos(i, tt); E.B_NAME = SNAME[i]; E.B_MAG = SMAG[i];
    }
    E.B_GHA = nrm360(gast(jdut) - E.P_RA);
    E.B_DEC = E.P_DEC;
    E.B_SD = E.P_SD;
    E.B_HP = E.P_HP;
    E.B_SHA = nrm360(360 - E.P_RA);
    return E.B_GHA;
  }

  /* ---- the sextant correction chain -------------------------------- */
  function corrections(hs, ie, heye, temp, press, limb) {
    const dip = 1.7594 * Math.sqrt(heye > 0 ? heye : 0);
    const ha = hs - ie / 60.0 - dip / 60.0;
    E.C_HA = ha;
    const f = (press / 1010.0) * (283.0 / (273.0 + temp));
    const refr = (ha > -0.9) ? f / tand(ha + 7.31 / (ha + 4.4)) : 0;
    const par = E.B_HP * cosd(ha);
    let sd = E.B_SD;
    if (E.B_NAME === 'Moon' && sd > 0) sd = sd * (1.0 + sind(ha) * E.B_HP / 3437.75);
    E.C_DIP = dip; E.C_REF = refr; E.C_PAR = par; E.C_SD = sd;
    E.C_LIMB = (limb === 'L' ? sd : (limb === 'U' ? -sd : 0));
    E.C_HO = ha + (par - refr + E.C_LIMB) / 60.0;
    return E.C_HO;
  }

  /* ---- sight reduction --------------------------------------------- */
  function reduce_sight(lat, lon, gha, dec) {
    const lha = nrm360(gha + lon);
    E.R_LHA = lha;
    E.R_HC = asind(sind(lat) * sind(dec) + cosd(lat) * cosd(dec) * cosd(lha));
    const y = -cosd(dec) * sind(lha);
    const x = cosd(lat) * sind(dec) - sind(lat) * cosd(dec) * cosd(lha);
    E.R_ZN = nrm360(atan2d(y, x));
    return E.R_HC;
  }

  return {
    E, d2r, r2d, sind, cosd, tand, asind, acosd, atan2d, nrm360, nrm180, fabs,
    jdate, jd2cal, deltaT, nutation, gast,
    sun_pos, moon_pos, planet_pos, star_pos, star_lookup, planet_mag,
    body_at, corrections, reduce_sight, corrval, kepler, helio,
    stars: { SNUM, SNAME, SRA, SDEC, SPMR, SPMD, SMAG, NSTAR }
  };
}

if (typeof module !== 'undefined') module.exports = { makeCelnav };
