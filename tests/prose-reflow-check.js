/*  Does dropping the shell's line breaks keep every word, and hold the
    paragraphs whose layout IS their meaning?

    The lessons are written for a terminal and carry hard breaks at 72
    columns. In the browser those breaks are dropped and the browser
    wraps -- except where the line breaks are the layout, which
    renderProse() decides per paragraph. Two ways that can go wrong and
    neither shows up as an error:

      a word is lost or moved when lines are joined. A paragraph reads
        almost right and nobody notices which clause went.

      a table is flowed. C4's anatomy of a report, C5's and C6's
        formulas, C7's relative-bearing table: joined into a paragraph
        they are not wrong, they are unreadable, and the rule that holds
        them is six lines of regex that somebody will one day relax.

    So two things are checked over every lesson in the app -- 15 rules
    lessons with their questions, and the 7 contacts lessons:

      1. THE WORDS SURVIVE. The rendered text, read in order, is the
         same sequence of words as the source. Whitespace may change;
         nothing else may.

      2. ANYTHING WITH A COLUMN IN IT IS HELD, tested independently of
         the rule renderProse() uses: a paragraph with a run of three or
         more spaces inside a line is a table, whatever the renderer
         thinks, and must come back preformatted and byte-identical.

    The second test is deliberately NOT the renderer's own predicate. A
    check that asks the code whether it agrees with itself passes for
    ever.  */
const fs = require('fs');

/*  enough DOM for renderProse: it makes elements, sets className and
    textContent, and appends  */
function node(tag) {
  const n = { tag, className: '', textContent: '', kids: [],
              appendChild(c) { n.kids.push(c); return c; },
              setAttribute() {}, removeAttribute() {}, addEventListener() {},
              replaceChild() {} };
  return n;
}
global.document = { createElement: node, createElementNS: (ns, t) => node(t),
                    getElementById: () => null, querySelector: () => null,
                    querySelectorAll: () => [], addEventListener: () => {} };
global.window = global;
global.getComputedStyle = () => ({ getPropertyValue: () => '' });
global.localStorage = { getItem: () => null, setItem: () => {} };

/*  colregs.js is an IIFE with an export seam inside it, the same one
    tests/colregs-web-dump.js loads it through  */
const m = { exports: {} };
new Function('module', 'window', 'document',
             fs.readFileSync('docs/web/colregs/colregs.js', 'utf8'))
            (m, global.window, global.document);
const renderProse = m.exports.renderProse;
if (typeof renderProse !== 'function') {
  console.log('FAIL  colregs.js does not export renderProse'); process.exit(1);
}

const D = {}; new Function('window', fs.readFileSync('docs/web/colregs/data.js', 'utf8'))(D);
const C = {}; new Function('window', fs.readFileSync('docs/web/colregs/contacts-lessons.js', 'utf8'))(C);

const words = s => s.replace(/\s+/g, ' ').trim().split(' ').filter(Boolean);
const TABLE = /\S {3,}\S/;

let bad = 0, checked = 0, held = 0, flowed = 0;

function check(id, what, text) {
  checked++;
  const box = node('div');
  renderProse(text, box);

  /*  1. the words, in order  */
  const want = words(text), got = words(box.kids.map(k => k.textContent).join(' '));
  if (want.length !== got.length || want.some((w, i) => w !== got[i])) {
    let at = 0; while (at < want.length && want[at] === got[at]) at++;
    console.log('FAIL  ' + id + ' ' + what + ': the words changed at #' + at);
    console.log('        source:   ' + JSON.stringify(want.slice(at, at + 6).join(' ')));
    console.log('        rendered: ' + JSON.stringify(got.slice(at, at + 6).join(' ')));
    bad++;
  }

  /*  2. a paragraph with a column in it comes back preformatted, and
         byte-identical, because its alignment is its meaning  */
  text.split(/\n[ \t]*\n/).forEach(par => {
    const lines = par.split('\n').filter(l => l.trim() !== '');
    if (!lines.length) return;
    if (!lines.some(l => TABLE.test(l))) { flowed++; return; }
    held++;
    const want2 = par.replace(/^\n+/, '').replace(/\s+$/, '');
    const hit = box.kids.find(k => k.tag === 'pre' && k.textContent === want2);
    if (!hit) {
      const near = box.kids.find(k => k.textContent.indexOf(lines[0].trim().slice(0, 24)) >= 0);
      console.log('FAIL  ' + id + ' ' + what + ': a paragraph with columns was not held as-is');
      console.log('        ' + JSON.stringify(lines[0].slice(0, 66)));
      console.log('        came back as <' + (near ? near.tag : '?') + '>');
      bad++;
    }
  });
}

D.COLREGS_DATA.lessons.forEach(L => { check(L.id, 'body', L.body); check(L.id, 'question', L.question); });
C.CONTACTS_LESSONS.forEach(L => L.blocks.forEach((b, i) => { if (b.t === 'p') check(L.id, 'block ' + i, b.s); }));

if (bad) { console.log('  ' + bad + ' problem(s)'); process.exit(1); }
console.log('  ok    every word survives the reflow across ' + checked + ' lesson texts, and all ' +
            held + ' paragraphs with columns in them are held exactly');
