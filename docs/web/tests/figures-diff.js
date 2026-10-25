/*  How different are two PNGs, in pixels rather than in bytes.

    WHY THIS EXISTS. run-figures-web.sh recaptures the site's pictures and
    asked `git diff` whether any had changed. A screenshot of an unchanged
    page is not byte-stable: two consecutive captures of the celnav noon
    screen differ by 97 pixels out of 1,083,600, maximum channel delta 6 -
    font antialiasing, invisible, and gone again on the next run. So the
    check went red on pictures that were correct, which is the kind of
    check people learn to ignore.

    Decoding a PNG needs an image library, and the one thing this harness
    can already be sure of is a headless Chromium - it has just driven one
    to take the pictures. So the browser decodes them: both files go in as
    data URLs, onto a canvas, and out as a pixel count.

      node figures-diff.js a.png b.png
      -> "differ 97 1083600 6"  (pixels differing, pixels total, max delta)
      -> "size 860x1260 860x1240"  when the two are not the same shape  */
'use strict';
const fs = require('fs');
const { chromium } = require('playwright');

const [A, B] = process.argv.slice(2);
const url = p => 'data:image/png;base64,' + fs.readFileSync(p).toString('base64');

(async () => {
  const b = await chromium.launch();
  const p = await b.newPage();
  const out = await p.evaluate(async ([ua, ub]) => {
    const load = u => new Promise((res, rej) => {
      const i = new Image();
      i.onload = () => res(i); i.onerror = () => rej(new Error('decode'));
      i.src = u;
    });
    const [ia, ib] = await Promise.all([load(ua), load(ub)]);
    if (ia.width !== ib.width || ia.height !== ib.height)
      return 'size ' + ia.width + 'x' + ia.height + ' ' + ib.width + 'x' + ib.height;
    const px = (img) => {
      const c = document.createElement('canvas');
      c.width = img.width; c.height = img.height;
      c.getContext('2d').drawImage(img, 0, 0);
      return c.getContext('2d').getImageData(0, 0, img.width, img.height).data;
    };
    const da = px(ia), db = px(ib);
    let n = 0, worst = 0;
    for (let i = 0; i < da.length; i += 4) {
      let d = 0;
      for (let k = 0; k < 3; k++) { const v = Math.abs(da[i+k] - db[i+k]); if (v > d) d = v; }
      if (d > 0) { n++; if (d > worst) worst = d; }
    }
    return 'differ ' + n + ' ' + (ia.width * ia.height) + ' ' + worst;
  }, [url(A), url(B)]);
  await b.close();
  console.log(out);
})().catch(e => { console.error(String(e)); process.exit(2); });
