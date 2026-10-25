/*  The annotated walkthrough, as the PAGE shows it, against what the
    shell PRINTS, step by step.

    The prose is generated rather than retyped, so what could go wrong is
    not the words: it is the ORDER, the splitting, and the figures.

      - a step dropped, or two steps shown as one
      - a paragraph lost where the dumper split the text
      - a figure's title taken as prose, or prose taken as a title
      - and the three drawings, which are the reason this was worth
        porting at all: the triangle at step 4 and the plotting sheets at
        steps 7 and 8 are the app's own, not named gaps, so they can be
        wrong in ways a gap cannot

    Every word of every step is compared, after the same canonicalisation
    both sides' line wrapping needs.

      node celnav-walk.js step1.txt step2.txt ... step10.txt  */
'use strict';
const fs = require('fs');
const { chromium } = require('playwright');

const files = process.argv.slice(2);
const BASE = 'http://127.0.0.1:' + (process.env.PORT || 8731) + '/celnav/';

/*  one spelling for a block of wrapped prose: the shell wraps at 70
    columns and the browser wraps at whatever the window is, so the line
    breaks carry no meaning and come out. The degree mark and the
    hemisphere do, and are normalised the way the other harnesses do it.  */
const words = s => String(s)
  .replace(/[−–—]/g, '-')
  .replace(/[°]/g, ' ').replace(/[′']/g, ' ')
  .replace(/\s+/g, ' ')
  .trim();

let checks = 0, bad = 0;
function eq(what, got, want) {
  checks++;
  if (got === undefined || want === undefined || words(got) !== words(want)) {
    bad++;
    if (bad <= 12) {
      console.log('  FAIL ' + what);
      console.log('        shell ' + JSON.stringify(words(want).slice(0, 160)));
      console.log('        page  ' + JSON.stringify(words(got).slice(0, 160)));
    }
  }
}

/*  the shell's step: its title, and its prose with the figure and the
    figure's own caption lines taken out - the caption describes the
    character grid and the browser draws real lines instead.  */
function shellStep(txt) {
  const lines = txt.split('\n');
  let i = lines.findIndex(l => /^\s+WALKTHROUGH\s+step /.test(l));
  if (i < 0) return null;
  i += 2;                                   /* the rule under the header */
  while (i < lines.length && lines[i].trim() === '') i++;
  const title = lines[i].trim();
  const prose = [];
  let inGrid = false;
  for (let j = i + 1; j < lines.length; j++) {
    const l = lines[j];
    //  the grid itself: between the figure's title line and the caption
    if (/^@@(FIG|PLOT|LOP) /.test(l)) { inGrid = true; continue; }
    if (inGrid) {
      if (/^\s+AP = /.test(l) || /near-vertical LOP/.test(l) ||
          /^\s+wide, so one degree/.test(l)) continue;
      if (l.trim() === '') { inGrid = false; continue; }
      inGrid = false;
    }
    //  a figure's title is its own all-capitals line and belongs to the
    //  figure, which is drawn rather than written
    if (/^  [A-Z][A-Z ,:-]+$/.test(l) && l.length < 50) continue;
    prose.push(l);
  }
  return { title: title, prose: prose.join(' ') };
}

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 900, height: 1500 }, timezoneId: 'UTC' });
  const errs = [];
  page.on('pageerror', e => errs.push(String(e)));
  await page.goto(BASE + 'index.html', { waitUntil: 'load', timeout: 20000 });
  //  start at step one whatever this browser profile remembers
  await page.evaluate(() => { try { localStorage.removeItem('celnav-walkstep'); } catch (e) {} });
  await page.reload({ waitUntil: 'load' });
  await page.click('[data-go="walk"]');
  await page.waitForTimeout(400);

  for (let n = 1; n <= files.length; n++) {
    const sh = shellStep(fs.readFileSync(files[n - 1], 'utf8'));
    if (!sh) { bad++; console.log('  FAIL ' + files[n - 1] + ' is not a walkthrough step'); continue; }
    const got = await page.evaluate(() => ({
      pos: document.getElementById('walk-pos').textContent,
      title: (document.querySelector('#walk-body h2') || {}).textContent || '',
      //  THE LEAF BLOCKS, JOINED WITH A SPACE. textContent of the whole
      //  .prose div runs its paragraphs together - "...no way on.You put
      //  the sextant..." - which is this check's own fault and not the
      //  page's: the browser renders them as separate blocks.
      prose: Array.from(document.querySelectorAll('#walk-body .prose > *'))
               .map(d => d.textContent).join(' '),
      svgs: document.querySelectorAll('#walk-body svg').length,
      lops: Array.from(document.querySelectorAll('#walk-body svg text'))
              .map(t => t.textContent).filter(t => /^[a-c]\s+[TA][\d.]+$/.test(t)),
      fix: Array.from(document.querySelectorAll('#walk-body svg text'))
             .some(t => t.textContent === 'FIX'),
      //  WHICH COMES FIRST on the page. The prose beside every one of
      //  these three figures refers to the picture above it - "Z is your
      //  zenith, P the north pole" - so a page that put the words first
      //  would read as a caption for nothing, with the right words, the
      //  right numbers and the right drawing.
      figFirst: (function () {
        const kids = Array.from(document.getElementById('walk-body').children);
        const f = kids.findIndex(k => k.querySelector && k.querySelector('svg'));
        const p = kids.findIndex(k => k.classList && k.classList.contains('prose'));
        return (f >= 0 && p >= 0) ? (f < p) : null;
      })(),
      kv: (function () {
        const o = {};
        document.querySelectorAll('#walk-body table.kv tr').forEach(tr => {
          const th = tr.querySelector('th'), td = tr.querySelector('td');
          if (th && td) o[th.textContent.trim()] = td.textContent.trim();
        });
        return o;
      })()
    }));

    eq('step ' + n + ' position', got.pos, 'Step ' + n + ' of ' + files.length);
    eq('step ' + n + ' title', got.title, sh.title);
    eq('step ' + n + ' prose', got.prose, sh.prose);

    //  the three drawings: present where the shell drew, absent elsewhere
    const drew = /@@FIG /.test(fs.readFileSync(files[n - 1], 'utf8'));
    checks++;
    if (drew && got.svgs !== 1) {
      bad++; console.log('  FAIL step ' + n + ': the shell drew a figure, the page drew ' + got.svgs);
    } else if (!drew && got.svgs !== 0) {
      bad++; console.log('  FAIL step ' + n + ': the page drew ' + got.svgs + ' figures, the shell drew none');
    }

    //  and in the order the shell printed them: the figure, then the
    //  paragraph that talks about it
    if (drew) {
      const raw0 = fs.readFileSync(files[n - 1], 'utf8');
      const li = raw0.split('\n');
      const fi = li.findIndex(l => /^@@FIG /.test(l));
      //  the first prose line after the title, which is the line after the
      //  rule and the title itself
      const ti = li.findIndex(l => /^\s+WALKTHROUGH\s+step /.test(l)) + 3;
      let pi = -1;
      for (let j = ti; j < li.length; j++) {
        if (/^@@/.test(li[j]) || li[j].trim() === '') continue;
        if (/^  [A-Z][A-Z ,:-]+$/.test(li[j]) && li[j].length < 50) continue;
        if (/^\s+AP = /.test(li[j]) || /near-vertical LOP/.test(li[j]) ||
            /^\s+wide, so one degree/.test(li[j])) continue;
        pi = j; break;
      }
      checks++;
      if (got.figFirst !== (fi < pi)) {
        bad++;
        console.log('  FAIL step ' + n + ': the page puts the ' +
          (got.figFirst ? 'figure' : 'prose') + ' first and the shell puts the ' +
          (fi < pi ? 'figure' : 'prose') + ' first');
      }
    }

    //  a plotted step: the LOP labels and intercepts have to be the ones
    //  the shell dumped, because the prose beside them names the letters
    const raw = fs.readFileSync(files[n - 1], 'utf8');
    const lops = raw.split('\n').filter(l => /^@@LOP /.test(l))
      .map(l => { const a = l.split(' '); return { p: parseFloat(a[3]), label: a[4] }; });
    if (lops.length) {
      const want = lops.map(L => L.label + ' ' + (L.p >= 0 ? 'T' : 'A') + Math.abs(L.p).toFixed(1));
      eq('step ' + n + ' plotted lines', got.lops.join(', '), want.join(', '));
      const fixLine = /^@@PLOT (\d+) (-?[\d.]+) (-?[\d.]+) (\d)/m.exec(raw);
      checks++;
      if (fixLine && (fixLine[4] === '1') !== got.fix) {
        bad++; console.log('  FAIL step ' + n + ': the fix is ' + (got.fix ? 'marked' : 'not marked') +
                           ' and the shell says ' + (fixLine[4] === '1' ? 'it is' : 'it is not'));
      }
    }

    //  THE TRIANGLE STEP IS DRAWN FOR THIS SIGHT, so the numbers beside it
    //  have to be the ones the shell reaches a step later: it prints the
    //  equation with the decimal LHA in it, and Hc and Zn as degrees and
    //  minutes. Compared as ANGLES, not as strings - the page shows Hc in
    //  decimal degrees because a sandbox slider is a decimal thing.
    if (drew && !lops.length) {
      const all = files.map(f => fs.readFileSync(f, 'utf8')).join('\n');
      const dm = t => {
        const m = /(\d+)\D+([\d.]+)/.exec(String(t));
        return m ? +m[1] + +m[2] / 60 : NaN;
      };
      const near = (what, g, w, tol) => {
        checks++;
        if (!(Math.abs(g - w) <= tol)) {
          bad++;
          console.log('  FAIL step ' + n + ' ' + what + ': page ' + g + ', shell ' + w +
                      ' (tolerance ' + tol + ')');
        }
      };
      const lhaM = /cos\((\d+\.\d+)\)\s*$/m.exec(all);
      const hcM = /Hc = (\d+ [\d.]+)'/.exec(all);
      const znM = /Zn = (\d+ [\d.]+)'/.exec(all);
      const hcCell = got.kv['Computed altitude Hc'] || '';
      near('triangle LHA', parseFloat(got.kv['LHA']), parseFloat(lhaM[1]), 0.01);
      near('triangle Hc', parseFloat(hcCell), dm(hcM[1]), 0.01);
      near('triangle Zn', parseFloat(hcCell.split('Zn')[1]), dm(znM[1]), 0.05);
      const decM = /Dec\s+([NS])(\d+ [\d.]+)'/.exec(all);
      near('triangle declination', dm(got.kv['Declination']),
           dm(decM[2]) * (decM[1] === 'S' ? -1 : 1), 0.01);
    }

    if (n < files.length) { await page.click('#walk-next'); await page.waitForTimeout(220); }
  }

  if (errs.length) { bad++; console.log('  FAIL page errors: ' + errs.join(' | ')); }
  await browser.close();
  console.log('    ' + checks + ' checks over ' + files.length + ' steps' + (bad ? '' : ', all agree'));
  if (bad) { console.log('    ' + bad + ' FAILED'); process.exit(1); }
})().catch(e => { console.error(e); process.exit(2); });
