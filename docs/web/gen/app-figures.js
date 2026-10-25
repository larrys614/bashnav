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

/*  AND THE CLOCK IS FROZEN, for the same reason the deck-log menu picture
    had to have its timestamp frozen in make-site.sh: several of these
    screens show the time. The tides day view prints the date, draws a
    "time now" marker on the curve and states the height at this minute;
    deck-log heads its screen with the UTC stamp and the watch slot. A
    capture that moves every minute is not a capture, and the comparison
    against the committed file would be noise for ever.
    29 Aug 2026 12:00 UT, which is the day the celnav worked example uses.  */
const FIXED = Date.UTC(2026, 7, 29, 12, 0, 0);
const FREEZE = `(() => {
  const F = ${FIXED}, R = Date;
  function D(...a) {
    if (!(this instanceof D)) return new R(F).toString();
    return a.length ? new R(...a) : new R(F);
  }
  D.prototype = R.prototype;
  D.now = () => F; D.parse = R.parse; D.UTC = R.UTC;
  window.Date = D;
})();`;

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

/*  ---- screenshots ---------------------------------------------------
 *  Four of the six apps draw nothing at all: tides, deck-log, weather and
 *  drill are tables, logs, forms and prose. Their features cannot be shown
 *  as SVG because there is no SVG, so those figures are PNGs of the real
 *  screen, captured the same deterministic way.
 *
 *  They are the repository's only binary files and they cannot be diffed,
 *  only compared byte for byte - a changed screenshot says THAT it changed
 *  and not what. That is the price of showing an app whose output is a
 *  table. The viewport and the scale factor are fixed so the comparison
 *  means something, and day mode is forced, because the palette is stored
 *  per browser and a night-mode capture would be a different picture of
 *  the same screen.
 */
const SHOT = { width: 860, height: 1000 };

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
    file: 'colregs-sound.svg', app: 'colregs', sel: '#v-sounds svg',
    title: 'colregs: a sound signal drawn against time, because a script cannot make a noise',
    async drive(p) {
      await p.click('text=Sound signals');
      await p.waitForTimeout(500);
      /*  the second question of the seeded sequence: five short blasts,
          which is a pattern worth drawing. The first is a single blast  */
      await p.click('#sound-next');
      await p.waitForTimeout(400);
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
  },
  /*  ---- and the screens that are not drawings --------------------
      tides, deck-log, weather and drill put out tables, logs, forms and
      prose. There is no SVG to lift, so these are pictures of the real
      screen.  */
  {
    file: 'tides-day.png', app: 'tides', shot: '#v-day', height: 1700,
    title: 'tides: a day at New London - the curve, the turns, and what is under the keel',
    async drive(p) {
      await p.fill('#q', 'new london');
      await p.waitForTimeout(700);
      await p.click('text=/New LondonCT/i');
      await p.waitForTimeout(1200);
    }
  },
  {
    file: 'tides-find.png', app: 'tides', shot: '#v-pick',
    title: 'tides: finding a station by any part of its name, out of 8,334',
    async drive(p) {
      await p.fill('#q', 'new lon');
      await p.waitForTimeout(800);
    }
  },
  {
    file: 'celnav-sight.png', app: 'celnav', shot: '#v-sight', height: 1640,
    title: 'celnav: a sight worked from any sextant - the correction chain, the sights kept, and the fix',
    async drive(p) {
      await p.click('[data-go="sight"]');
      await p.waitForTimeout(300);
      /*  the form carries the first sight, so the screen reads as a
          session in progress rather than an empty form above a result  */
      await p.fill('#s-date', '2026-08-29');
      await p.fill('#s-time', '07:30:00');
      await p.fill('#s-body', 'Dubhe');
      await p.fill('#s-hs', '19 32.1');
      await p.fill('#s-he', '2.5');
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
      await p.waitForTimeout(600);
    }
  },
  {
    file: 'decklog-entry.png', app: 'deck-log', shot: '#v-entry',
    title: 'deck-log: an entry, with the position, course and speed the next one carries forward',
    async drive(p) { await p.click('text=New entry'); await p.waitForTimeout(600); }
  },
  {
    file: 'decklog-boat.png', app: 'deck-log', shot: '#v-boat',
    title: 'deck-log: the boat - her equipment, and the spares replayed from the log rather than stored',
    async drive(p) { await p.click('text=The boat'); await p.waitForTimeout(600); }
  },
  {
    file: 'weather-forecast.png', app: 'weather', shot: '#v-fcast',
    title: 'weather: your forecast, written down before the program will show you its own',
    async drive(p) { await p.click('text=Make a forecast'); await p.waitForTimeout(600); }
  },
  {
    file: 'weather-chart.png', app: 'weather', shot: '#v-chart',
    title: 'weather: reading a 500 mb chart - the steering flow above the surface weather',
    async drive(p) { await p.click('text=From a 500 mb chart'); await p.waitForTimeout(600); }
  },
  {
    file: 'launcher.png', app: '', shot: 'body',
    title: 'the launcher: one screen reaching all six apps, installable to a home screen',
    async drive(p) { await p.waitForTimeout(600); }
  },
  /*  DRILL GETS ONE FIGURE, and it is the empty machine. With no pack
      loaded the app shows #v-empty and nothing else exists to
      photograph - the sections, the test and "where am I weak" are all
      behind a pack, and the repository has no sample pack because the
      whole point of the tool is that the material is yours and stays
      yours. A second figure would mean authoring a demo pack.  */
  {
    file: 'drill-home.png', app: 'drill', shot: '#v-empty',
    title: 'drill: a study machine that ships empty - you load a pack from your own device and it never leaves the browser',
    async drive(p) { await p.waitForTimeout(600); }
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
  /*  UTC and one locale, so nothing renders a local time or a localised
      number differently on another machine  */
  /*  A TALLER VIEWPORT WHERE THE SCREEN IS TALLER. celnav and tides keep
      the body at viewport height and scroll an inner container, so
      fullPage stops at the fold and the celnav capture lost the fix and
      the plotting sheet below it. The height is part of the figure.  */
  const p = await b.newPage({ viewport: { width: SHOT.width, height: f.height || SHOT.height },
                              deviceScaleFactor: 1, timezoneId: 'UTC', locale: 'en-GB' });
  await p.addInitScript(SEED);
  await p.addInitScript(FREEZE);
  const errs = [];
  p.on('pageerror', e => errs.push(String(e)));
  try {
    await p.goto(BASE + (f.app ? f.app + '/' : ''), { timeout: 15000 });
    await p.waitForTimeout(400);
    /*  day mode, always: the palette is remembered per browser and a
        night capture is a different picture of the same screen  */
    await p.evaluate(() => document.documentElement.removeAttribute('data-mode'));
    await f.drive(p);
    if (f.shot) {
      /*  THE WHOLE PAGE, not the view element. An element screenshot of
          #v-entry came out clipped on the right and at the bottom: the
          app's header is sticky and sits over the element's box, the tab
          strip scrolls sideways inside it, and the footer buttons are a
          wider row - so "Entry", the NIGHT button, the Stores tab and
          "Log this section" were all cut. The page is what a reader sees;
          photograph that.  */
      const el = await p.$(f.shot);
      if (!el) throw new Error('nothing matched ' + f.shot + ' - the screen is not showing');
      const box = await el.boundingBox();
      if (!box || box.height < 80) throw new Error('the screen is ' + (box ? Math.round(box.height) : 0) + 'px tall - it did not render');
      /*  FIT THE VIEWPORT TO THE SCREEN. fullPage takes the LARGER of the
          content and the viewport, so a screen shorter than the window
          came out padded with dead space - the weather chart was 565px of
          content in a 1000px picture.
          document.documentElement.scrollHeight is no use for measuring it:
          these apps hold html and body at the window height and scroll an
          INNER container, so it reports the window back. The view
          element's own box is the screen, so the target is its bottom
          edge plus the page's own bottom padding.  */
      for (let i = 0; i < 4; i++) {
        const b2 = await el.boundingBox();
        if (!b2) break;
        const want = Math.max(360, Math.ceil(b2.y + b2.height + 24));
        const vp = p.viewportSize();
        if (Math.abs(want - vp.height) <= 4) break;
        await p.setViewportSize({ width: SHOT.width, height: want });
        await p.waitForTimeout(300);
      }
      await p.screenshot({ path: OUT + '/' + f.file, fullPage: true });
      const h = p.viewportSize().height;
      console.log('  ' + f.file.padEnd(26) + SHOT.width + 'x' + h + ' screenshot');
    } else {
      const got = await grab(p, f.sel);
      if (!got) throw new Error('no element matched ' + f.sel);
      if (got.nodes < 5) throw new Error('only ' + got.nodes + ' elements - the figure did not draw');
      const head = '<!-- ' + f.title + '\n     Captured from the ' + f.app +
                   ' app by docs/web/gen/make-app-figures.sh. Do not hand-edit:\n' +
                   '     it is regenerated and compared by tests/run-tests.sh. -->\n';
      writeFileSync(OUT + '/' + f.file, head + got.xml + '\n');
      console.log('  ' + f.file.padEnd(26) + got.nodes + ' elements' +
                  (got.label ? '  "' + got.label.slice(0, 44) + '"' : ''));
    }
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
