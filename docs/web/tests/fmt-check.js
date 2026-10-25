/*  printf's %.1f against JavaScript's, value for value.

    Deneb's magnitude is exactly 1.25. The shell printed it 1.2 and the
    page printed 1.3, because C rounds a tie to the even last digit and
    toFixed() rounds it up. Every number in this repository that both
    implementations print is one decimal wide, so that one difference
    reaches the almanac, the planning table, the correction chain and the
    fix.

    celnav-app.js's f(v, dec) is the fix. This pins it: the awk is asked
    to print a few thousand values and the JavaScript has to agree with
    every one, with the odd quarters - the only values where the two can
    differ at all - deliberately over-represented.

      awk -f fmt-ref.awk | node fmt-check.js  */
'use strict';
const fs = require('fs');

/*  THE FUNCTION UNDER TEST IS TAKEN OUT OF THE PAGE, not copied here.
    A copy needs a guard that it has not drifted from the original, and
    the guard then fires instead of the value comparison - which is what
    happened when this check was first written with a copy: planting a
    plain toFixed() in the page made it report "not the function this
    check tests" and never compare a single value. Reading the source and
    evaluating it means the page's own arithmetic is what agrees with the
    awk, or does not.  */
const src = fs.readFileSync(__dirname + '/../celnav/celnav-app.js', 'utf8');
const m = /\nfunction f\(v, dec\) \{[\s\S]*?\n\}/.exec(src);
if (!m) { console.log('  FAIL celnav-app.js has no f(v, dec) to test'); process.exit(1); }
const f = new Function(m[0] + '\nreturn f;')();

let n = 0, bad = 0, ties = 0;
for (const line of fs.readFileSync(process.argv[2] || 0, 'utf8').split('\n')) {
  if (!line.trim()) continue;
  const [vs, dec, want] = line.split('\t');
  const v = Number(vs), d = +dec;
  const got = f(v, d);
  n++;
  const h = v * Math.pow(2, d + 1);
  if (h === Math.round(h) && Math.abs(h) % 2 === 1) ties++;
  if (got !== want) {
    bad++;
    if (bad <= 15) console.log('  FAIL %.' + d + 'f of ' + vs + ': awk ' + want + ', js ' + got +
                               '   (toFixed gives ' + v.toFixed(d) + ')');
  }
}
console.log('    ' + n + ' values, ' + ties + ' of them an exact tie' + (bad ? '' : ', all agree'));
if (bad) { console.log('    ' + bad + ' FAILED'); process.exit(1); }
