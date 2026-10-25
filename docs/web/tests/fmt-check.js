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

/*  THE FUNCTION UNDER TEST IS THE ENGINE'S OWN, required and called.

    It used to be a copy kept here, which needed a guard that it had not
    drifted from the original - and when a plain toFixed() was planted in
    the page to prove the check worked, the GUARD fired and not one value
    was ever compared. Then it was scraped out of celnav-app.js and
    evaluated, which was better but still read the source as text. It is
    an exported engine function now, so this calls it.  */
const { makeCelnav } = require('../celnav/engine.js');
const { extendCelnav } = require('../celnav/engine2.js');
global.window = {};
// eslint-disable-next-line no-eval
eval(fs.readFileSync(__dirname + '/../celnav/tables.js', 'utf8'));
const CN = extendCelnav(makeCelnav(global.window.CELNAV_TABLES));
const f = CN.fx;

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
