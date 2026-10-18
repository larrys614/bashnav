/* =====================================================================
   Camera sight -- the screen.

   REBUILT AS A SEQUENCE.  The first version put the photograph, a
   readout, two mode tabs and three button pads on one page with no order
   and no instructions, and the one sentence that did explain it sat in
   13 px grey monospace inside the readout.  Larry took a photograph with
   it and could not work out what to do next.  That is the whole verdict,
   so now there are four numbered steps, one plain-language instruction at
   reading size, and only the controls that step needs.

   Overlay state lives in IMAGE pixel coordinates, never display pixels,
   so zooming or rotating the device cannot move a sight.  The convention
   is refine.js's: an integer coordinate is the CENTRE of that pixel.
   ===================================================================== */
(function () {
  'use strict';
  const $ = id => document.getElementById(id);

  /* A visible build stamp.  Debugging this remotely without one meant
     guessing which version was on the device, and the guess was wrong:
     the service worker below had been serving a cached build. */
  const BUILD = '4 \u2014 18 Oct 2026';
  const R2D = 180 / Math.PI;

  const CN = extendCelnav(makeCelnav(window.CELNAV_TABLES));
  const CS = window.CAMSIGHT, RF = window.REFINE, EX = window.EXIF;

  let img = null, cam = null, exif = null, scale = 1, step = 1, view = 'wide';
  let zwin = null;     // the close-up's source window, for mapping taps back
  const H = { y: 0, tiltDeg: 0 };
  const B = { x: 0, y: 0, r: 14 };
  const pick = () => (step === 3 ? 'b' : 'h');

  const TELL = {
    1: 'Take a photograph of the sun or the moon with the horizon in the same frame.',
    2: 'Tap on the horizon in the picture. It does not have to be exact — then press "Find the edge for me", and use the buttons to fine-tune. Watch Hs change as you do.',
    3: 'Now tap the sun or moon. Again roughly is fine — press "Find the edge for me" and it will fit a circle to the limb.',
    4: 'Tell it which body and the time, and it works out Ho from Hs. Go Back to adjust the lines again.'
  };

  /* ---- step machinery ----------------------------------------------- */
  function show(id, on) { const e = $(id); if (e) e.hidden = !on; }
  function goStep(n) {
    if (n < 1) n = 1; if (n > 4) n = 4;
    if (n > 1 && !img) n = 1;
    step = n;
    document.querySelectorAll('.steps li').forEach(li => {
      const s = +li.dataset.step;
      li.classList.toggle('on', s === step);
      li.classList.toggle('done', s < step);
    });
    $('tellme').textContent = TELL[step];
    show('s1', step === 1);
    show('pic', step >= 2);
    show('readout', step >= 2);
    show('adjust', step === 2 || step === 3);
    show('sight', step === 4);
    show('dock', !!img);
    show('dockrow', step === 2 || step === 3);
    show('snap', step === 2 || step === 3);
    show('padTilt', step === 2);
    show('padBody', step === 3);
    $('back').disabled = step === 1;
    $('next').textContent = step === 4 ? 'Done' : 'Next';
    $('next').disabled = step === 4;
    if (step < 2 || step > 3) view = 'wide';
    setView(step >= 2 && step <= 3 ? view : 'wide');
    show('pic', step >= 2);
    setConf(step === 2 ? 'Tap the horizon, then Find the edge.'
          : step === 3 ? 'Tap the body, then Find the edge.' : '', '');
    draw(); recompute();
  }

  /* ---- plate scale ---------------------------------------------------- */
  function arcminPerPx() { return cam ? Math.atan(1 / cam.f) * R2D * 60 : 0; }
  function rebuildCam() {
    if (!img) return;
    const f35 = parseFloat($('f35').value) || (exif && exif.focal35);
    cam = f35 ? CS.makeCam(img.width, img.height,
                           CS.fpxFrom35mm(f35, img.width, img.height), 0, 0) : null;
  }

  /* ---- drawing -------------------------------------------------------- */
  function horizonPts() {
    const m = Math.tan(H.tiltDeg / R2D), cx = img.width / 2;
    return [[0, H.y - m * cx], [img.width - 1, H.y + m * (img.width - 1 - cx)]];
  }
  function halo(g, fn, colour) {
    g.strokeStyle = 'rgba(0,0,0,0.85)'; g.lineWidth = 4; fn();
    g.strokeStyle = colour; g.lineWidth = 1.4; fn();
  }
  function draw() {
    if (!img || step < 2) return;
    if (view === 'zoom') { drawZoom(); return; }
    const cv = $('cv'), g = cv.getContext('2d');
    const maxW = Math.min($('stage').clientWidth, 760) - 2;
    scale = Math.min(1, maxW / img.width);
    cv.width = Math.round(img.width * scale);
    cv.height = Math.round(img.height * scale);
    g.drawImage(img, 0, 0, cv.width, cv.height);
    const S = p => [p[0] * scale, p[1] * scale];
    const [a, b] = horizonPts().map(S);
    halo(g, () => { g.beginPath(); g.moveTo(a[0], a[1]); g.lineTo(b[0], b[1]); g.stroke(); },
         pick() === 'h' ? '#6fb3d9' : 'rgba(111,179,217,0.5)');
    const c = S([B.x, B.y]);
    halo(g, () => { g.beginPath(); g.arc(c[0], c[1], Math.max(5, B.r * scale), 0, 7); g.stroke();
                    g.moveTo(c[0] - 8, c[1]); g.lineTo(c[0] + 8, c[1]);
                    g.moveTo(c[0], c[1] - 8); g.lineTo(c[0], c[1] + 8); g.stroke(); },
         pick() === 'b' ? '#ff4438' : 'rgba(255,68,56,0.5)');
    drawZoom();
  }

  /* The whole frame fitted to a phone is ~10 image pixels per screen pixel,
     which is 12 arcminutes - the sun's disc is one pixel across and a
     snapped horizon vanishes into the edge it found.  So the selected
     feature also gets shown magnified, at an integer zoom with
     image-rendering: pixelated, because a browser's smoothing would be
     inventing the very edge being judged. */
  const ZOOM = 4;
  function drawZoom() {
    if (!img || step < 2 || step > 3 || view !== 'zoom') { zwin = null; return; }
    const cv = $('zoom'), g = cv.getContext('2d');
    const wCss = Math.min($('stage').clientWidth, 760) - 2;
    const srcW = Math.round(wCss / ZOOM), srcH = Math.round(Math.min(170, wCss * 0.4) / ZOOM);
    cv.width = srcW * ZOOM; cv.height = srcH * ZOOM;
    const cxI = pick() === 'h' ? img.width / 2 : B.x;
    const cyI = pick() === 'h' ? H.y : B.y;
    const sx = cxI - srcW / 2, sy = cyI - srcH / 2;
    g.imageSmoothingEnabled = false;
    g.fillStyle = '#10151a'; g.fillRect(0, 0, cv.width, cv.height);
    g.drawImage(img, sx, sy, srcW, srcH, 0, 0, cv.width, cv.height);
    const T = p => [(p[0] - sx) * ZOOM, (p[1] - sy) * ZOOM];
    if (pick() === 'h') {
      const [a, b] = horizonPts().map(T);
      halo(g, () => { g.beginPath(); g.moveTo(a[0], a[1]); g.lineTo(b[0], b[1]); g.stroke(); }, '#6fb3d9');
    } else {
      const c = T([B.x, B.y]);
      halo(g, () => { g.beginPath(); g.arc(c[0], c[1], B.r * ZOOM, 0, 7); g.stroke();
                      g.moveTo(c[0] - 12, c[1]); g.lineTo(c[0] + 12, c[1]);
                      g.moveTo(c[0], c[1] - 12); g.lineTo(c[0], c[1] + 12); g.stroke(); }, '#ff4438');
    }
    zwin = { sx, sy, srcW, srcH };
    $('zoomlbl').textContent = ZOOM + ':1  ' + (pick() === 'h' ? 'horizon' : 'body') +
      '  |  one screen pixel = ' + (arcminPerPx() / ZOOM).toFixed(3) + " arcmin";
  }

  function setView(v) {
    view = v;
    document.querySelectorAll('[data-view]').forEach(b =>
      b.classList.toggle('on', b.dataset.view === v));
    show('cv', v === 'wide');
    show('zoom', v === 'zoom');
    show('zoomlbl', v === 'zoom');
    draw();
  }

  /* ---- the measurement -------------------------------------------------- */
  function fmtAng(d) {
    const neg = d < 0; d = Math.abs(d);
    const deg = Math.floor(d), min = (d - deg) * 60;
    return (neg ? '-' : '') + deg + '° ' + min.toFixed(1) + "'";
  }
  function hsNow() {
    if (!cam) return null;
    try { return CS.measureHs(horizonPts(), [B.x, B.y], cam).hs; } catch (e) { return null; }
  }
  function recompute() {
    if (!img || step < 2) return;
    rebuildCam();
    if (!cam) {
      $('hs').textContent = '—'; $('ho').textContent = '—';
      $('chain').textContent = 'No focal length yet. Enter the 35 mm equivalent on step 4.';
      return;
    }
    const hs = hsNow();
    if (hs === null) { $('hs').textContent = '—'; return; }
    $('hs').textContent = fmtAng(hs);
    const body = $('body').value, utc = $('utc').value.trim();
    let jd = null;
    if (/^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}/.test(utc)) jd = CN.parse_utc(utc);
    if (!body || jd === null) {
      $('ho').textContent = '—';
      $('chain').textContent = 'Ho needs a body and a time — step 4.'; return;
    }
    if (CN.body_at(body, jd) === 'ERR') {
      $('ho').textContent = '—'; $('chain').textContent = 'Body not in the catalogue.'; return;
    }
    const he = parseFloat($('he').value) || 0, ie = parseFloat($('ie').value) || 0;
    const tm = parseFloat($('tm').value), pr = parseFloat($('pr').value);
    const ho = CN.corrections(hs, ie, he, isNaN(tm) ? 10 : tm, isNaN(pr) ? 1010 : pr, $('limb').value);
    const E = CN.E;
    $('ho').textContent = fmtAng(ho);
    $('chain').textContent = step < 4 ? '' : 'dip -' + E.C_DIP.toFixed(1) + "'  refr -" + E.C_REF.toFixed(1) +
      "'  parallax +" + E.C_PAR.toFixed(1) + "'  limb " + (E.C_LIMB >= 0 ? '+' : '') +
      E.C_LIMB.toFixed(1) + "'   |  " + arcminPerPx().toFixed(3) + "' per pixel";
  }
  function setConf(s, state) { const e = $('conf'); e.textContent = s; e.dataset.state = state || ''; }

  /* ---- find the edge ----------------------------------------------------- */
  function snap() {
    if (!img) return;
    const c = document.createElement('canvas');
    c.width = img.width; c.height = img.height;
    const ctx = c.getContext('2d', { willReadFrequently: true });
    ctx.drawImage(img, 0, 0);
    const data = ctx.getImageData(0, 0, img.width, img.height);
    if (pick() === 'h') {
      const [p1, p2] = horizonPts();
      const r = RF.refineHorizon(data, p1, p2);
      if (!r.ok) { setConf('No clear edge found there. Tap closer to the horizon, or set it by hand.', 'bad'); return; }
      const cx = img.width / 2, t = (cx - r.p1[0]) / (r.p2[0] - r.p1[0]);
      H.y = r.p1[1] + (r.p2[1] - r.p1[1]) * t;
      H.tiltDeg = Math.atan2(r.p2[1] - r.p1[1], r.p2[0] - r.p1[0]) * R2D;
      setConf('Horizon: ' + r.used + ' samples, ' + r.dropped + ' discarded, scatter ' +
              (r.rmsPx * arcminPerPx()).toFixed(2) + "' — " +
              (r.rmsPx < 1 ? 'a clean edge.' : 'ragged; check it in the magnified view.'),
              r.rmsPx < 1 ? 'good' : 'bad');
    } else {
      const r = RF.refineLimb(data, [B.x, B.y], B.r);
      if (!r.ok) { setConf('No limb found. Tap on the body and set the circle near its size.', 'bad'); return; }
      B.x = r.centre[0]; B.y = r.centre[1]; B.r = r.radius;
      let msg = 'Limb: ' + r.used + ' rays, scatter ' + r.rmsPx.toFixed(2) + ' px';
      let state = r.rmsPx < 0.75 ? 'good' : '';
      /* The ephemeris knows the true semi-diameter, so the fitted disc is an
         independent check on the focal length.  It is far too small a ruler
         to REFINE the scale, but it catches a gross error - a wrong lens, a
         digital zoom, bad EXIF - before it becomes a confident fix. */
      const sd = CN.E.B_SD;
      if (sd > 0 && cam) {
        const wantPx = sd / arcminPerPx(), pct = 100 * (r.radius - wantPx) / wantPx;
        msg += '. Disc is ' + r.radius.toFixed(1) + ' px where the almanac expects ' +
               wantPx.toFixed(1) + ' (' + (pct >= 0 ? '+' : '') + pct.toFixed(1) + '%)';
        if (Math.abs(pct) > 5) { msg += ' — the focal length looks wrong.'; state = 'bad'; }
        else msg += ' — consistent.';
      }
      setConf(msg, state);
    }
    draw(); recompute();
  }

  /* ---- nudging ------------------------------------------------------------
     A button that says one arcminute must deliver one arcminute.  The CENTRE
     plate scale does not: on a rectilinear lens a pixel is worth less angle
     off-axis, by 1/(1+(r/f)^2), so a horizon 280 px off-centre on a short
     lens moved 0.90' for a 1' tap.  Measure the local derivative instead. */
  function dHsPerPx(axis) {
    const h0 = hsNow(); if (h0 === null) return null;
    const save = { y: H.y, bx: B.x, by: B.y };
    if (axis === 'v') { if (pick() === 'h') H.y -= 1; else B.y -= 1; }
    else if (axis === 'x') B.x += 1;
    const h1 = hsNow();
    H.y = save.y; B.x = save.bx; B.y = save.by;
    return h1 === null ? null : (h1 - h0) * 60;
  }
  function nudge(axis, stepv) {
    if (!img) return;
    if (axis === 't') { H.tiltDeg += stepv; draw(); recompute(); return; }
    if (axis === 'r') { B.r = Math.max(2, B.r + stepv); draw(); recompute(); return; }
    if (!cam) return;
    const d = dHsPerPx(axis);
    if (d === null || Math.abs(d) < 1e-9) return;
    const px = Math.abs(stepv / d) * Math.sign(stepv);
    if (axis === 'v') { if (pick() === 'h') H.y -= px; else B.y -= px; }
    else if (axis === 'x') B.x += px;
    draw(); recompute();
  }

  /* ---- loading a photograph ------------------------------------------- */
  function loadFile(f) {
    if (!f) return;
    const fr = new FileReader();
    fr.onerror = () => { $('shotnote').textContent = 'Could not read that file.'; };
    fr.onload = function () {
      exif = null;
      try { exif = EX.readExif(fr.result); } catch (e) {}
      const url = URL.createObjectURL(new Blob([fr.result], { type: f.type || 'image/jpeg' }));
      const im = new Image();
      im.onerror = () => { $('shotnote').textContent = 'That file is not an image this browser can open.'; };
      im.onload = function () {
        img = im; URL.revokeObjectURL(url);
        H.y = img.height * 0.70; H.tiltDeg = 0;
        B.x = img.width / 2; B.y = img.height * 0.35; B.r = 14;
        if (exif && exif.focal35) $('f35').value = exif.focal35;
        const note = img.width + ' × ' + img.height +
          (exif && exif.focal35 ? '  |  ' + exif.focal35 + ' mm equivalent, from the photo'
                                : '  |  no focal length in the photo — enter it on step 4') +
          (exif && exif.model ? '  |  ' + exif.model : '');
        $('shotnote').textContent = note;
        goStep(2);
      };
      im.src = url;
    };
    fr.readAsArrayBuffer(f);
  }
  $('take').addEventListener('click', () => $('fileCam').click());
  $('choose').addEventListener('click', () => $('filePick').click());
  ['fileCam', 'filePick'].forEach(id =>
    $(id).addEventListener('change', e => loadFile(e.target.files && e.target.files[0])));

  /* ---- events ----------------------------------------------------------- */
  function onTap(ev) {
    if (!img || step < 2 || step > 3) return;
    /* Map the tap through the canvas's RENDERED rectangle, not through the
       scale used to size its backing store.  CSS caps the photo's height so
       the controls stay on screen, which makes the two differ - and taps
       then land in the wrong part of the image, silently, by hundreds of
       pixels.  The rect is the truth whatever the CSS does. */
    const el = view === 'zoom' ? $('zoom') : $('cv');
    const r = el.getBoundingClientRect();
    if (!r.width || !r.height) return;
    let x, y;
    if (view === 'zoom' && zwin) {
      x = zwin.sx + (ev.clientX - r.left) * (zwin.srcW / r.width);
      y = zwin.sy + (ev.clientY - r.top) * (zwin.srcH / r.height);
    } else {
      x = (ev.clientX - r.left) * (img.width / r.width);
      y = (ev.clientY - r.top) * (img.height / r.height);
    }
    if (pick() === 'h') H.y = y - Math.tan(H.tiltDeg / R2D) * (x - img.width / 2);
    else { B.x = x; B.y = y; }
    draw(); recompute();
  }
  $('cv').addEventListener('pointerdown', onTap);
  $('zoom').addEventListener('pointerdown', onTap);
  document.querySelectorAll('[data-view]').forEach(b =>
    b.addEventListener('click', () => setView(b.dataset.view)));
  document.querySelectorAll('.nudge').forEach(b => {
    let t = null, n = 0;
    const go = () => { nudge(b.dataset.axis, parseFloat(b.dataset.step)); n++;
                       t = setTimeout(go, n < 4 ? 320 : n < 12 ? 110 : 45); };
    const stop = () => { clearTimeout(t); t = null; n = 0; };
    b.addEventListener('pointerdown', e => { e.preventDefault(); go(); });
    ['pointerup', 'pointerleave', 'pointercancel'].forEach(k => b.addEventListener(k, stop));
  });
  $('snap').addEventListener('click', snap);
  $('next').addEventListener('click', () => goStep(step + 1));
  $('back').addEventListener('click', () => goStep(step - 1));
  ['body','limb','utc','he','ie','tm','pr','f35'].forEach(id => $(id).addEventListener('input', recompute));

  /* ---- boot ------------------------------------------------------------- */
  function setMode(m) {
    document.documentElement.setAttribute('data-mode', m);
    $('mode').textContent = m === 'night' ? 'DARK' : 'NIGHT';
    const meta = document.querySelector('meta[name="theme-color"]');
    if (meta) meta.setAttribute('content', m === 'night' ? '#060101' : '#07090b');
    try { localStorage.setItem('bashnav-mode', m); } catch (e) {}
  }
  let saved = 'dark';
  try { saved = localStorage.getItem('bashnav-mode') || 'dark'; } catch (e) {}
  setMode(saved === 'night' ? 'night' : 'dark');
  $('mode').addEventListener('click', () =>
    setMode(document.documentElement.getAttribute('data-mode') === 'night' ? 'dark' : 'night'));

  const sel = $('body');
  ['Sun','Moon','Venus','Mars','Jupiter','Saturn'].concat(CN.stars.SNAME)
    .forEach(n => { const o = document.createElement('option'); o.value = n; o.textContent = n; sel.appendChild(o); });
  $('utc').value = new Date().toISOString().slice(0, 19).replace('T', ' ');
  window.addEventListener('resize', draw);
  goStep(1);
  const bs = $('build'); if (bs) bs.textContent = 'build ' + BUILD;

  /* OFFLINE CACHING, AND WHY IT IS SWITCHED OFF IN SOME BUILDS.
     The service worker is cache-first, which is right at sea and wrong
     while the page is being changed: a republish then serves the OLD
     code to anyone who opened the page before, with no sign that it has
     done so.  That is exactly what happened - a whole round of testing
     against a stale build.  So a build can declare CELNAV_NO_SW, and it
     then actively unregisters any worker and clears the caches instead
     of installing one. */
  if ('serviceWorker' in navigator && location.protocol !== 'file:') {
    if (window.CELNAV_NO_SW) {
      navigator.serviceWorker.getRegistrations()
        .then(rs => Promise.all(rs.map(r => r.unregister()))).catch(() => {});
      if (window.caches && caches.keys)
        caches.keys().then(ks => Promise.all(ks.map(k => caches.delete(k)))).catch(() => {});
    } else {
      navigator.serviceWorker.register('sw.js').catch(() => {});
    }
  }
})();
