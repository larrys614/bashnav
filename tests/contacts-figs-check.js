/*  Do the contacts figures draw, and is every colour they use defined?

    contacts-figs.js draws the relative-motion plot and the compass rose
    as SVG, and takes its colours from classes in colregs.css rather than
    reading the custom properties at draw time. That is deliberate -- see
    the note at the top of the file -- but it moves the failure: a class
    the stylesheet does not define is not a crash, it is an element drawn
    in the browser's default black on a near-black panel, or one that
    sits out the night palette. Nothing would say so.

    Drawn the other way, with cssvar() at draw time, these came out blue
    and green on the red night palette and the only thing that found it
    was rendering all three and looking. This finds the same class of
    fault without a browser.

    Four things are checked, and the third is the one that bites:

      1. every figure the lessons carry has something that can draw it;
      2. drawing it produces an svg with an aria-label, since a figure
         with no text alternative is a picture of nothing to a reader;
      3. every class the drawing puts on an element is defined in
         colregs.css;
      4. the CPA the plot prints is the CPA the awk's own arithmetic
         gives, to the same rounding -- the figure is not allowed to
         disagree with the shell about how close she comes.  */
const fs = require('fs');

/*  the smallest DOM that will hold an SVG: the drawing code sets
    attributes, appends children and sets textContent, and -- now that
    the colours are in the stylesheet -- reads nothing back  */
const made = [];
function node(tag) {
  const n = { tag: tag, attrs: {}, kids: [], textContent: '',
              setAttribute: (k, v) => { n.attrs[k] = String(v); },
              appendChild: c => { n.kids.push(c); return c; } };
  made.push(n);
  return n;
}
/*  plot() now returns its range control and the figure together, so the
    stub needs plain elements as well as SVG ones  */
function hnode(tag) {
  const n = node(tag);
  n.className = '';
  n.addEventListener = () => {};
  n.replaceChild = (nw, old) => { n.kids[n.kids.indexOf(old)] = nw; return old; };
  n.removeAttribute = k => { delete n.attrs[k]; };
  return n;
}
global.document = { createElementNS: (ns, tag) => node(tag),
                    createElement: tag => hnode(tag) };

const win = {};
new Function('window', fs.readFileSync('docs/web/colregs/contacts.js', 'utf8'))(win);
new Function('window', fs.readFileSync('docs/web/colregs/contacts-figs.js', 'utf8'))(win);
new Function('window', fs.readFileSync('docs/web/colregs/contacts-lessons.js', 'utf8'))(win);

const css = fs.readFileSync('docs/web/colregs/colregs.css', 'utf8');
const defined = new Set();
(css.match(/\.[A-Za-z][-\w]*/g) || []).forEach(c => defined.add(c.slice(1)));

let bad = 0, drawn = 0;
for (const les of win.CONTACTS_LESSONS) {
  for (const b of les.blocks) {
    if (b.t !== 'fig') continue;
    const draw = win.CONTACTS_FIGS[b.kind];
    if (!draw) { console.log('FAIL  ' + les.id + ': nothing can draw a "' + b.kind + '"'); bad++; continue; }

    made.length = 0;
    try { draw(b); }
    catch (e) { console.log('FAIL  ' + les.id + ' ' + b.kind + ': ' + e.message); bad++; continue; }
    drawn++;

    const svgs = made.filter(n => n.tag === 'svg');
    if (!svgs.length) { console.log('FAIL  ' + les.id + ': the ' + b.kind + ' drew no svg'); bad++; continue; }
    for (const s of svgs) {
      if (!s.attrs['aria-label']) {
        console.log('FAIL  ' + les.id + ': a ' + b.kind + ' svg has no aria-label'); bad++;
      }
    }
    /*  the class check below must not trip over the plain elements the
        range control is built from, so they are excluded by tag  */

    const HTML = new Set(['div', 'span', 'button']);
    for (const n of made) {
      if (HTML.has(n.tag)) continue;
      for (const c of (n.attrs['class'] || '').split(/\s+/)) {
        if (c && !defined.has(c)) {
          console.log('FAIL  ' + les.id + ': class "' + c + '" on a <' + n.tag +
                      '> is not in colregs.css -- it will draw unstyled');
          bad++;
        }
      }
    }

    if (b.kind === 'plot') {
      const want = 'CPA ' + win.CONTACTS.ct_yd(win.CONTACTS.ct_cpa(b.px, b.py, b.vx, b.vy).cpa) + ' yd';
      const says = made.filter(n => n.tag === 'text' && n.textContent.indexOf('CPA ') === 0)
                       .map(n => n.textContent);
      if (!says.length || says[0].indexOf(want) !== 0) {
        console.log('FAIL  ' + les.id + ': the plot says ' + JSON.stringify(says[0] || '(nothing)') +
                    ', the arithmetic says ' + JSON.stringify(want));
        bad++;
      }
    }
  }
}
/*  THE CARD, which is generated the same way the lessons are and is
    prone to the same two faults: carrying the terminal's rule lines
    into the page, and losing the one line that differs per reporting
    style. Five variants, and the example report is what separates
    them.  */
new Function('window', fs.readFileSync('docs/web/colregs/contacts-card.js', 'utf8'))(win);
const CARD = win.CONTACTS_CARD;
const STYLES = ['rn', 'usn', 'rel360', 'words', 'none'];
const seen = {};
for (const st of STYLES) {
  const text = CARD[st];
  if (!text) { console.log('FAIL  the card has no "' + st + '" variant'); bad++; continue; }
  if (/^ *-{5,} *$/m.test(text)) {
    console.log('FAIL  the ' + st + ' card still carries a terminal rule line'); bad++;
  }
  if (/CONTACTS -- the card/.test(text)) {
    console.log('FAIL  the ' + st + ' card repeats the heading the screen already shows'); bad++;
  }
  const rep = text.split('\n').find(l => l.indexOf('Master 2') >= 0);
  if (!rep) { console.log('FAIL  the ' + st + ' card has no example report'); bad++; continue; }
  if (seen[rep] && seen[rep] !== st) {
    console.log('FAIL  the ' + st + ' card reads identically to the ' + seen[rep] +
                ' one -- the reporting style is not reaching it:');
    console.log('        ' + JSON.stringify(rep.trim()));
    bad++;
  }
  seen[rep] = st;
}

if (bad) { console.log('  ' + bad + ' problem(s)'); process.exit(1); }
console.log('  ok    all ' + drawn + ' contacts figures draw and are styled, and the card ' +
            'reads differently in all ' + STYLES.length + ' reporting styles');
