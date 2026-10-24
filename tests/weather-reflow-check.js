/*  Does weather's reflow keep every word, every emphasis, and every
    figure?

    The lessons were written for a terminal and arrived as one paragraph
    per 70-column line. drawLines() now gathers consecutive lines into a
    paragraph and joins the prose -- which puts three things at risk, and
    none of them would show up as an error:

      1. A WORD IS LOST OR MOVED at a seam. Each line's screen indent is
         trimmed and a single space goes in; an off-by-one in that and a
         paragraph reads almost right.

      2. AN EMPHASIS COMES OFF. The accent is per-SPAN, not per-line, so
         joining lines means concatenating span runs. "water vapour does
         not add molecules to the box, it REPLACES them" turns on the one
         word that is emphasised; merge the spans carelessly and the word
         is still there with the emphasis gone.

      3. A FIGURE IS FLOWED. The H2O/O2 diagram indents "O2  32" to sit
         under "N2  28". Flowed into a sentence it is not wrong, it is
         meaningless -- and it was already meaningless in a proportional
         font before any of this.

    The third test uses its own idea of what a figure is -- three or more
    spaces inside a line -- rather than asking wxKind() whether it agrees
    with itself, because a check that asks the code to confirm its own
    rule passes for ever.

    Both the lesson body and its deeper section are checked: drawLines()
    renders both, which is the whole reason it is one function.  */
'use strict';
const fs = require('fs');
const path = require('path');
const ROOT = path.resolve(__dirname, '..');

/*  enough DOM: drawLines makes elements, sets className and
    textContent, and appends  */
const made = [];
function node(tag) {
  const n = { tag, className: '', textContent: '', kids: [],
              appendChild(c) { n.kids.push(c); return c; },
              setAttribute() {}, addEventListener() {} };
  made.push(n);
  return n;
}
global.document = { createElement: node, createElementNS: (ns, t) => node(t),
                    createTextNode: t => ({ tag: '#text', textContent: t, kids: [] }),
                    getElementById: () => node('div'), addEventListener() {},
                    querySelector: () => null, querySelectorAll: () => [] };
/*  a window object of its own rather than the node global: weather.js
    registers a DOMContentLoaded handler on it at load, and the global
    has no addEventListener  */
global.window = { addEventListener() {}, matchMedia: () => ({ matches: false,
                  addEventListener() {} }), scrollTo() {}, caches: undefined };
global.localStorage = { getItem: () => null, setItem() {} };
/*  node 22 defines navigator as a getter-only global, so it is left
    alone: weather.js only reaches for navigator.serviceWorker inside a
    DOMContentLoaded handler that never fires here.  */
global.getComputedStyle = () => ({ getPropertyValue: () => '' });
global.indexedDB = undefined;

const m = { exports: {} };
new Function('module', 'window', 'document',
             fs.readFileSync(path.join(ROOT, 'docs/web/weather/weather.js'), 'utf8'))
            (m, global.window, global.document);
const drawLines = m.exports.drawLines;
if (typeof drawLines !== 'function') {
  console.log('FAIL  weather.js does not export drawLines'); process.exit(1);
}
const LESSONS = require(path.join(ROOT, 'docs/web/weather/lessons.js')).LESSONS;

/*  The text of a rendered tree, in order.

    BLOCKS ARE JOINED WITH A SPACE AND SPANS ARE NOT, which is the
    distinction the DOM makes and this has to make too: a span sits
    inside a sentence ("it replaces them") and must concatenate with no
    gap, while an h3 and the paragraph under it are separate blocks.
    Joined with nothing throughout, the first check read "LIGHTERAir"
    and reported the renderer had lost a space it never had.  */
function treeText(n) {                 /* inside a block: no gaps */
  if (n.tag === '#text') return n.textContent;
  if (n.kids.length) return n.kids.map(treeText).join('');
  return n.textContent || '';
}
function treeTextTop(n) {              /* between blocks: one space */
  return n.kids.map(treeText).join(' ');
}
/*  every word that sits inside a styled span, with its style  */
function styled(n, cur, out) {
  out = out || []; cur = cur || null;
  if (n.tag === '#text') {
    if (cur) n.textContent.split(/\s+/).filter(Boolean).forEach(w => out.push(cur + ':' + w));
    return out;
  }
  const st = (n.tag === 'span' && n.className) ? n.className : cur;
  if (!n.kids.length && n.textContent) {
    if (st) n.textContent.split(/\s+/).filter(Boolean).forEach(w => out.push(st + ':' + w));
    return out;
  }
  n.kids.forEach(k => styled(k, st, out));
  return out;
}
const words = s => s.replace(/\s+/g, ' ').trim().split(' ').filter(Boolean);
const FIGURE = /\S {3,}\S/;

let bad = 0, checked = 0, figs = 0;

function check(key, what, lines) {
  if (!lines || !lines.length) return;
  checked++;
  made.length = 0;
  const box = node('div');
  drawLines(box, lines);

  /*  what the source says, and what was emphasised in it  */
  const srcText = lines.filter(b => b.s === 'line')
    .map(b => (b.p || []).filter(Boolean).map(s => s.t).join('')).join(' ');
  const srcStyled = [];
  lines.filter(b => b.s === 'line').forEach(b =>
    (b.p || []).filter(Boolean).forEach(s => {
      if (s.s && s.s !== 'plain')
        s.t.split(/\s+/).filter(Boolean).forEach(w => srcStyled.push(s.s + ':' + w));
    }));

  /*  1. the words, in order. The heading is rendered as an h3 from the
         first line, so it is in the tree too -- both sides include it. */
  const want = words(srcText), got = words(treeTextTop(box));
  if (want.length !== got.length || want.some((w, i) => w !== got[i])) {
    let at = 0; while (at < want.length && want[at] === got[at]) at++;
    console.log('FAIL  ' + key + ' ' + what + ': the words changed at #' + at);
    console.log('        source:   ' + JSON.stringify(want.slice(at, at + 6).join(' ')));
    console.log('        rendered: ' + JSON.stringify(got.slice(at, at + 6).join(' ')));
    bad++;
  }

  /*  2. the emphasis. Every emphasised word is still emphasised, and in
         the same style -- the heading's accent is dropped from both
         sides, because it becomes an h3 rather than a span.           */
  const head = lines.filter(b => b.s === 'line')[0];
  const headWords = new Set((head && (head.p || []).filter(Boolean) || [])
    .filter(s => s.s && s.s !== 'plain')
    .reduce((a, s) => a.concat(s.t.split(/\s+/).filter(Boolean).map(w => s.s + ':' + w)), []));
  const wantS = srcStyled.filter(w => !headWords.has(w)).sort();
  const gotS = styled(box).filter(w => !headWords.has(w)).sort();
  for (const w of wantS) {
    if (gotS.indexOf(w) < 0) {
      console.log('FAIL  ' + key + ' ' + what + ': ' + JSON.stringify(w) +
                  ' lost its emphasis in the join');
      bad++;
      break;
    }
  }

  /*  3. a paragraph with a column in it comes back preformatted  */
  let para = [];
  const flushCheck = () => {
    if (!para.length) { return; }
    const txt = para.map(b => (b.p || []).filter(Boolean).map(s => s.t).join(''));
    para = [];
    if (!txt.some(l => FIGURE.test(l))) return;
    figs++;
    const want2 = txt.join('\n');
    const hit = made.find(n => n.tag === 'pre' && treeText(n) === want2);
    if (!hit) {
      console.log('FAIL  ' + key + ' ' + what + ': a figure with columns was not held:');
      console.log('        ' + JSON.stringify(txt[0].slice(0, 66)));
      bad++;
    }
  };
  let first = true;
  lines.forEach(b => {
    if (b.s === 'gap' || b.s === 'rule') { flushCheck(); return; }
    if (first) { first = false; return; }          /* the heading */
    para.push(b);
  });
  flushCheck();
}

LESSONS.forEach(l => {
  check(l.key, 'body', l.body);
  check(l.key, 'more', l.more);      /* the deeper section, where there is one */
});

if (bad) { console.log('  ' + bad + ' problem(s)'); process.exit(1); }
console.log('  ok    weather\'s reflow keeps every word and every emphasis across ' +
            checked + ' lesson sections, and holds all ' + figs + ' figures with columns');
