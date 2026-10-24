/*  celnav's thirty-three lessons, in the browser.

    The lessons are generated from teach.awk, so the regenerate-and-
    compare check in run-tests.sh already proves the DATA is the awk's.
    This checks the three things that generation cannot:

      1. THE WORDS SURVIVE THE REFLOW. The prose is written for a 70-
         column terminal and those breaks are dropped so the browser can
         wrap for itself. A word lost at a seam reads almost right.

      2. ANYTHING WITH A COLUMN IN IT IS HELD. Seven of the seventeen
         figures in teach.awk print as rows of text rather than onto the
         character grid -- the correction bars, the deviation card, the
         interpolation tables, the almanac extracts -- so they arrive as
         prose and the hold rule is the only thing keeping their columns.
         Tested with its own idea of what a column is, three or more
         spaces inside a line, rather than by asking proseKind() whether
         it agrees with itself.

      3. EVERY FIGURE GAP IS NAMED. Ten lessons draw on the grid and
         those drawings are the second pass. Until then each gap says
         what belongs in it. A gap with no name reads as "a grid figure",
         which tells a reader nothing and would let a lesson go to the
         site with an anonymous hole in it. This fails if a lesson gains
         a figure and nobody adds a line to FIG_NAMES -- which is exactly
         what will happen when the figures land one module at a time.

    Every lesson must also have its question, its answer and the reason:
    those come from cmd=t_qmeta rather than from the printed lesson, and
    the first run of the generator produced all thirty-three with no
    question at all, because the rule before the question was matched
    with an interval expression that mawk does not implement.  */
'use strict';
const fs = require('fs');
const path = require('path');
const ROOT = path.resolve(__dirname, '..');

const made = [];
function node(tag) {
  const n = { tag, className: '', textContent: '', kids: [], dataset: {}, hidden: false,
              appendChild(c) { n.kids.push(c); return c; },
              setAttribute() {}, addEventListener() {} };
  made.push(n);
  return n;
}
global.document = { createElement: node, getElementById: () => node('div'),
                    addEventListener() {}, querySelector: () => null,
                    querySelectorAll: () => [] };
global.window = { addEventListener() {}, scrollTo() {}, caches: undefined };
global.localStorage = { getItem: () => null, setItem() {} };

const m = { exports: {} };
new Function('module', 'window', 'document',
             fs.readFileSync(path.join(ROOT, 'docs/web/celnav/celnav-app.js'), 'utf8'))
            (m, global.window, global.document);
const renderProse = m.exports.renderProse, FIG_NAMES = m.exports.FIG_NAMES;
if (typeof renderProse !== 'function') {
  console.log('FAIL  celnav-app.js does not export renderProse'); process.exit(1);
}

const L = {};
new Function('window', fs.readFileSync(path.join(ROOT, 'docs/web/celnav/lessons.js'), 'utf8'))(L);
const LESSONS = L.CELNAV_LESSONS, SYL = L.CELNAV_SYLLABUS;

function treeText(n) {
  if (n.kids.length) return n.kids.map(treeText).join('');
  return n.textContent || '';
}
const words = s => s.replace(/\s+/g, ' ').trim().split(' ').filter(Boolean);
const COLUMN = /\S {3,}\S/;

let bad = 0, checked = 0, held = 0, gaps = 0;

if (LESSONS.length !== SYL.length) {
  console.log('FAIL  ' + LESSONS.length + ' lessons for ' + SYL.length + ' syllabus entries');
  bad++;
}

for (const les of LESSONS) {
  /*  the question and its marking  */
  if (!les.question) { console.log('FAIL  ' + les.id + ': no question'); bad++; }
  if (!/^[a-d]$/.test(les.answer || '')) {
    console.log('FAIL  ' + les.id + ': answer is ' + JSON.stringify(les.answer)); bad++;
  }
  if (!les.why) { console.log('FAIL  ' + les.id + ': no reason given for the answer'); bad++; }
  /*  THE QUESTION SPLITS INTO A STEM AND OPTIONS WITH TEXT. The options
      are columns on one line in the shell; the browser puts them on the
      buttons, which means reading a shape the awk never promised to
      keep. All 33 read cleanly today -- this is what says so, and what
      will say so when a question is reworded.  */
  const sp = m.exports.splitQuestion(les.question || '');
  if (!sp) {
    console.log('FAIL  ' + les.id + ': the question does not split into a stem and options,' +
                ' so the browser falls back to bare letters:');
    console.log('        ' + JSON.stringify((les.question || '').slice(0, 72)));
    bad++;
  } else {
    if (sp.opts.length < 2) {
      console.log('FAIL  ' + les.id + ': ' + sp.opts.length + ' option(s) parsed'); bad++;
    }
    if (!sp.opts.some(o => o.ltr === les.answer)) {
      console.log('FAIL  ' + les.id + ': the answer "' + les.answer + '" is not among ' +
                  sp.opts.map(o => o.ltr).join(' '));
      bad++;
    }
    /*  EVERY WORD OF THE QUESTION IS ACCOUNTED FOR, in order, between
        the stem and the options -- the same test the prose gets.

        Asking instead whether each option's text is a SUBSTRING of the
        question was the first version and it was useless: slicing one
        character off "30 miles" gives "0 miles", which is still a
        substring, and an empty stem passed because nothing looked at
        the stem at all. Both were planted and both got through. This
        catches a character dropped at either end, a stem swallowed into
        the options, and an option invented from nothing.  */
    const qwords = (les.question || '').replace(/^Q\.\s*/, '')
      .replace(/\b[a-d]\)/g, ' ').replace(/\s+/g, ' ').trim().split(' ').filter(Boolean);
    const got = (sp.stem + ' ' + sp.opts.map(o => o.text).join(' '))
      .replace(/\s+/g, ' ').trim().split(' ').filter(Boolean);
    if (qwords.length !== got.length || qwords.some((w, i) => w !== got[i])) {
      let at = 0; while (at < qwords.length && qwords[at] === got[at]) at++;
      console.log('FAIL  ' + les.id + ': splitting the question changed it at word #' + at);
      console.log('        question: ' + JSON.stringify(qwords.slice(at, at + 5).join(' ')));
      console.log('        split:    ' + JSON.stringify(got.slice(at, at + 5).join(' ')));
      bad++;
    }
  }

  /*  the figure gaps  */
  for (const b of les.blocks) {
    if (b.t !== 'fig') continue;
    gaps++;
    if (!FIG_NAMES[les.id]) {
      console.log('FAIL  ' + les.id + ': has a figure gap and no name in FIG_NAMES -- ' +
                  'it would read as "a grid figure" and say nothing');
      bad++;
    }
  }

  /*  the prose  */
  for (const b of les.blocks) {
    if (b.t !== 'p') continue;
    checked++;
    made.length = 0;
    const box = node('div');
    renderProse(b.s, box);

    const want = words(b.s), got = words(box.kids.map(treeText).join(' '));
    if (want.length !== got.length || want.some((w, i) => w !== got[i])) {
      let at = 0; while (at < want.length && want[at] === got[at]) at++;
      console.log('FAIL  ' + les.id + ': the words changed at #' + at);
      console.log('        source:   ' + JSON.stringify(want.slice(at, at + 6).join(' ')));
      console.log('        rendered: ' + JSON.stringify(got.slice(at, at + 6).join(' ')));
      bad++;
    }

    b.s.split(/\n[ \t]*\n/).forEach(par => {
      const lines = par.split('\n').filter(l => l.trim() !== '');
      if (!lines.length || !lines.some(l => COLUMN.test(l))) return;
      held++;
      const want2 = par.replace(/^\n+/, '').replace(/\s+$/, '');
      if (!box.kids.some(k => k.tag === 'pre' && k.textContent === want2)) {
        console.log('FAIL  ' + les.id + ': a paragraph with columns was not held as-is:');
        console.log('        ' + JSON.stringify(lines[0].slice(0, 66)));
        bad++;
      }
    });
  }
}

/*  a name with no gap is dead weight and will mislead the next pass  */
for (const id of Object.keys(FIG_NAMES)) {
  const les = LESSONS.filter(l => l.id === id)[0];
  if (!les || !les.blocks.some(b => b.t === 'fig')) {
    console.log('FAIL  FIG_NAMES has an entry for ' + id + ', which has no figure gap');
    bad++;
  }
}

if (bad) { console.log('  ' + bad + ' problem(s)'); process.exit(1); }
console.log('  ok    all ' + LESSONS.length + ' celnav lessons keep their words across ' +
            checked + ' blocks, hold all ' + held + ' paragraphs with columns, ' +
            'and name all ' + gaps + ' figure gaps');
