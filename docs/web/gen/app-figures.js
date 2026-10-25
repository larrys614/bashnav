/*  The site's pictures, captured from the browser apps themselves.
 *
 *  The site used to show thirteen ansi2svg renderings - the TERMINAL's
 *  characters drawn as SVG. That was right when the shell build was the
 *  product. It is not any more: the page leads with the browser apps, and
 *  a picture of a terminal is a picture of something else.
 *
 *  So these are the apps' OWN drawings, lifted out of the running page.
 *  Nothing is redrawn here and no geometry is computed here; the file is
 *  the <svg> the app built, which is why it cannot drift from what a
 *  reader sees on the screen.
 *
 *  TWO THINGS MAKE IT REPRODUCIBLE, and both matter, because these files
 *  are committed and the suite diffs them against a fresh capture.
 *
 *  1. Math.random is replaced, before any app code runs, with the same
 *     seeded LCG the awk harnesses use. The lights and day-shape screens
 *     are quizzes that pick a vessel at random, and the encounter screen
 *     picks a scenario; unseeded, every capture would produce a different
 *     file and the comparison would be noise. Seeded, the sequence is
 *     fixed, so "the second question on the lights screen" is a stable
 *     address for a figure.
 *
 *  2. The styles are inlined. The celnav plot sheet resolves its colours
 *     at draw time and arrives with fill and stroke on every element, but
 *     the colregs figures were moved to CSS CLASSES so they follow the
 *     night palette - and a class means nothing in a standalone file, so
 *     those figures would have come out blank. Every classed element gets
 *     its computed paint written back as attributes.
 *
 *  Which question each figure comes from was chosen by stepping through
 *  the seeded sequence and taking the richest example: a vessel with ten
 *  lights rather than two, a day-shape question with shapes in it. The
 *  step count is part of the figure's address, not a magic number.
 */
'use strict';
const { chromium } = require('playwright');
const { writeFileSync, mkdirSync } = require('fs');

const BASE = 'http://127.0.0.1:' + (process.env.PORT || 8731) + '/';
const OUT = 'docs/img/app';

/*  the same multiplicative LCG as celnav-ref.awk, so a figure's address
    does not depend on which browser build is installed  */
const SEED = `(() => { let s = 20261025 % 2147483647; if (s <= 0) s += 2147483646;
  Math.random = () => { s = (s * 16807) % 2147483647; return (s - 1) / 2147483646; }; })();`;

/*  paint and type: everything a standalone file needs that a class was
    carrying. Geometry is already on the elements.  */
const PROPS = ['fill', 'fill-opacity', 'stroke', 'stroke-width', 'stroke-dasharray',
               'stroke-linecap', 'stroke-linejoin', 'opacity', 'font-family',
               'font-size', 'font-weight', 'font-style', 'text-anchor',
               'dominant-baseline', 'letter-spacing'];

async function grab(page, sel) {
  return page.evaluate(({ sel, PROPS }) => {
    const src = document.querySelector(sel);
    if (!src) return null;
    const svg = src.cloneNode(true);
    const a = src.querySelectorAll('*'), b = svg.querySelectorAll('*');
    for (let i = 0; i < a.length; i++) {
      const cs = getComputedStyle(a[i]);
      if (b[i].getAttribute('class')) {
        for (const prop of PROPS) {
          const v = cs.getPropertyValue(prop);
          /*  'none' IS NOT A NO-OP AND MUST BE WRITTEN. Skipping it was
              the first version of this, and it turned the contacts radar
              into a solid black disc: SVG's default fill is black, so a
              ring styled `fill: none` in CSS loses the only thing
              stopping it filling in. Only genuinely absent values are
              skipped.  */
          if (v !== '' && v !== 'normal' && v !== 'auto')
            b[i].setAttribute(prop, v.trim());
        }
        b[i].removeAttribute('class');
      }
    }
    /*  a class on the root can be carrying the figure's ground; without it
        the picture composites onto whatever is behind it  */
    const rs = getComputedStyle(src), bg = rs.backgroundColor;
    const vb = (src.getAttribute('viewBox') || '').split(/[ ,]+/).map(Number);
    if (bg && bg !== 'rgba(0, 0, 0, 0)' && bg !== 'transparent' && vb.length === 4) {
      const r = document.createElementNS('http://www.w3.org/2000/svg', 'rect');
      r.setAttribute('x', vb[0]); r.setAttribute('y', vb[1]);
      r.setAttribute('width', vb[2]); r.setAttribute('height', vb[3]);
      r.setAttribute('fill', bg);
      svg.insertBefore(r, svg.firstChild);
    }
    svg.removeAttribute('class');
    if (vb.length === 4 && !svg.getAttribute('width')) {
      svg.setAttribute('width', String(vb[2]));
      svg.setAttribute('height', String(vb[3]));
    }
    return { xml: new XMLSerializer().serializeToString(svg),
             nodes: src.querySelectorAll('*').length,
             label: src.getAttribute('aria-label') || '' };
  }, { sel, PROPS });
}

/*  ---- the figures ------------------------------------------------- */
const FIGURES = [
  {
    file: 'celnav-plot.svg', app: 'celnav', sel: '#s-sheet svg',
    title: 'celnav: the plotting sheet - three star sights, their lines of position and the fix',
    async drive(p) {
      await p.click('[data-go="sight"]');
      await p.waitForTimeout(300);
      /*  the shell's own worked example, so the picture and the manual
          agree: Dubhe, Bellatrix and Markab from 35 00 N 040 00 W  */
      await p.evaluate(() => {
        const C = extendCelnav(makeCelnav(window.CELNAV_TABLES));
        window.CELPLOT.clear();
        [['Dubhe', '07:30:00', '19 32.1'], ['Bellatrix', '07:34:00', '49 37.2'],
         ['Markab', '07:38:00', '29 01.3']].forEach(([body, t, hs]) => {
          const utc = '2026-08-29 ' + t;
          window.CELPLOT.add({ body, utc, jd: C.parse_utc(utc), hs: C.parse_ang(hs),
                               ie: 0, he: 2.5, tm: 10, pr: 1010, limb: 'C' });
        });
      });
      await p.fill('#s-alat', '35 00 N');
      await p.fill('#s-alon', '040 00 W');
      await p.waitForTimeout(500);
    }
  },
  {
    file: 'colregs-lights.svg', app: 'colregs', sel: '#light-stage svg',
    title: 'colregs: a vessel’s lights drawn from the bearing you see her on',
    async drive(p) {
      await p.click('text=Lights');
      await p.waitForTimeout(500);
      /*  the second question of the seeded sequence: ten lights and five
          labels, where the first has six and the third has two  */
      await p.click('#light-next');
      await p.waitForTimeout(400);
    }
  },
  {
    file: 'colregs-shapes.svg', app: 'colregs', sel: '#shape-stage svg',
    title: 'colregs: day shapes - what she shows when it is light enough to see them',
    async drive(p) {
      await p.click('text=Day shapes');
      await p.waitForTimeout(500);
      for (let i = 0; i < 4; i++) { await p.click('#shape-next'); await p.waitForTimeout(300); }
    }
  },
  {
    file: 'colregs-encounter.svg', app: 'colregs', sel: '#enc-stage svg',
    title: 'colregs: an encounter drawn head-up, with her heading and the wind',
    async drive(p) {
      await p.click('text=Encounters');
      await p.waitForTimeout(600);
    }
  },
  {
    file: 'colregs-contacts.svg', app: 'colregs', sel: '#les svg, .lesson svg',
    title: 'colregs: the relative-motion plot from the tracking party, on a radar range scale',
    async drive(p) {
      await p.click('text=Contact management');
      await p.waitForTimeout(400);
      await p.click('text=C1');
      await p.waitForTimeout(700);
    }
  }
];

/*  ---- run ----------------------------------------------------------
    CommonJS, not a module: playwright is a global install here and on
    Larry's Mac, and `import` does not look in the global folder while
    require() does. Every other harness in this repository is require()
    for the same reason. */
async function main() {
mkdirSync(OUT, { recursive: true });
const b = await chromium.launch();
let bad = 0;
for (const f of FIGURES) {
  const p = await b.newPage();
  await p.addInitScript(SEED);
  const errs = [];
  p.on('pageerror', e => errs.push(String(e)));
  try {
    await p.goto(BASE + f.app + '/', { timeout: 15000 });
    await p.waitForTimeout(400);
    await f.drive(p);
    const got = await grab(p, f.sel);
    if (!got) throw new Error('no element matched ' + f.sel);
    if (got.nodes < 5) throw new Error('only ' + got.nodes + ' elements - the figure did not draw');
    const head = '<!-- ' + f.title + '\n     Captured from the ' + f.app +
                 ' app by docs/web/gen/make-app-figures.sh. Do not hand-edit:\n' +
                 '     it is regenerated and compared by tests/run-tests.sh. -->\n';
    writeFileSync(OUT + '/' + f.file, head + got.xml + '\n');
    console.log('  ' + f.file.padEnd(26) + got.nodes + ' elements' +
                (got.label ? '  "' + got.label.slice(0, 44) + '"' : ''));
    if (errs.length) { console.log('    the page threw: ' + errs[0]); bad++; }
  } catch (e) {
    console.log('  ' + f.file.padEnd(26) + 'FAILED: ' + e.message);
    bad++;
  }
  await p.close();
}
await b.close();
console.log(bad ? '\n  ' + bad + ' figure(s) did not capture' : '  ' + FIGURES.length + ' figures captured');
process.exit(bad ? 1 : 0);
}
main();
