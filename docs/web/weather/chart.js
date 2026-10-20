// =====================================================================
//  weather -- reasoning over a 500 mb chart the user is holding.
//  A port of src/weather/chart.awk.
//
//  The app cannot fetch a chart and never will.  But a 500 mb chart
//  arrives by HF RADIOFAX, on an SSB receiver, at sea, with no
//  connectivity at all -- which is exactly the situation the rest of
//  bashnav is built for.  So this is the reasoning layer over a fax:
//  read three numbers off it and the rules do the rest, showing every
//  step.
//
//  Rules from Sienkiewicz & Chesneau, Mariner's Guide to the
//  500-Millibar Chart, NOAA -- public domain.  See docs/SOURCES.md.
// =====================================================================
'use strict';

var CHART = (function () {

  function g(x) {
    if (x === 0) return '0';
    var a = Math.abs(x);
    if (a >= 1e-4 && a < 1e6) {
      var s = (+x).toPrecision(6);
      if (s.indexOf('.') >= 0) s = s.replace(/0+$/, '').replace(/\.$/, '');
      return s;
    }
    var e = (+x).toExponential(5).split('e');
    return e[0].replace(/0+$/, '').replace(/\.$/, '') + 'e' +
           (+e[1] < 0 ? '-' : '+') + String(Math.abs(+e[1])).padStart(2, '0');
  }
  function d3(x) {
    var n = Math.trunc(x), s = String(Math.abs(n));
    while (s.length < (n < 0 ? 2 : 3)) s = '0' + s;
    return (n < 0 ? '-' : '') + s;
  }
  function f0(x) { return WX.cfixed(x, 0); }   // C rounds half to EVEN, not away from zero

  //  Is the 564 line on my POLEWARD side?  If it bears north of me in
  //  the northern hemisphere, I am equatorward of it, which is where I
  //  want to be.
  function poleward(brg, north) {
    var b = +brg;
    while (b < 0) b += 360;
    while (b >= 360) b -= 360;
    if (north) return (b < 90 || b > 270);     // the line lies to my north
    return (b > 90 && b < 270);                // southern: to my south
  }

  //  brg    bearing FROM you TO the nearest point of the 564 line
  //  dist   its distance in nm
  //  orient the line's own orientation, as a bearing (either end)
  //  w500   the 500 mb wind speed there, knots
  //  north  true northern hemisphere, false southern
  function report(brg, dist, orient, w500, north) {
    var out = [];
    function say(t) { out.push({ k: 'say', t: t }); }
    function warn(t) { out.push({ k: 'warn', t: t }); }
    function okk(t) { out.push({ k: 'ok', t: t }); }
    function acc(t) { out.push({ k: 'acc', t: t }); }
    function why(t) { out.push({ k: 'why', t: t }); }
    function gap() { out.push({ k: 'gap', t: '' }); }

    var pole = north ? 'north' : 'south';

    if (dist === '' || dist === undefined || brg === '' || brg === undefined) {
      say('Give me where the 564 line runs and I will walk the rules.');
      return out;
    }
    var or = +orient || 0;
    say('The 5640 m contour is ' + g(+dist) + ' nm away, bearing ' + d3(+brg) +
        ', lying ' + d3(or) + '/' + d3((or + 180) % 360) + '.');
    gap();

    // ---- 1. the storm track ---------------------------------------
    acc('The surface storm track runs parallel to that line, ' + pole + ' of it,');
    say('between 300 and 600 nm away from it.');
    why('so the depressions are travelling along ' + d3(or) + '/' + d3((or + 180) % 360) +
        ', not toward you');

    // ---- 2. the gale boundary, which is the one that matters ------
    gap();
    warn('All the gale force winds are on the ' + pole + ' side of the 564 line.');
    if (poleward(brg, north)) {
      okk('You are on the equatorward side of it. That is the right side.');
      why('stay there and you stay out of the gales - that is the routing rule,');
      why('and it is why the standard book on this is called Heavy Weather Avoidance');
    } else {
      warn('The line is equatorward of you, so you are on the gale side of it.');
      why('getting equatorward of the 564 line is the single most useful thing');
      why('you can do about the weather from here');
    }

    // ---- 3 and 4. speed and strength, if the wind was read --------
    if (w500 !== '' && w500 !== undefined && w500 !== null) {
      gap();
      var mn = (+w500) / 3.0, mx = (+w500) / 2.0;
      say('At ' + g(+w500) + ' knots aloft, systems below move at ' + f0(mn) +
          ' to ' + f0(mx) + ' knots.');
      why('a surface low or front travels at a third to a half of the 500 mb wind');
      if (+dist > 0) {
        say('So a system 300 nm off would be on you in ' + f0(300.0 / mx) +
            ' to ' + f0(300.0 / mn) + ' hours.');
      }
      gap();
      say('Behind it, in the cold air, expect about ' + f0((+w500) / 2.0) +
          ' knots on deck.');
      why('surface wind in the west-to-southwest quadrant is about half the 500 mb');
      why('wind - which is the number that decides what sail you are carrying');
    }
    return out;
  }

  var RULE = '  ' + new Array(71).join('-');
  function renderTerminal(items, gave) {
    var L = [''];
    L.push('  FROM THE 500 MILLIBAR CHART');
    L.push(RULE);
    items.forEach(function (it) {
      if (it.k === 'gap') L.push('');
      else if (it.k === 'why') L.push('     ' + it.t);
      else L.push('  ' + it.t);
    });
    if (!gave) { L.push(''); return L.join('\n') + '\n'; }
    L.push(RULE);
    L.push("  Rules from Sienkiewicz and Chesneau, Mariner's Guide to the");
    L.push('  500-Millibar Chart, NOAA. They are rules of thumb: good ones,');
    L.push('  and still rules of thumb.');
    L.push('');
    return L.join('\n') + '\n';
  }

  return { poleward: poleward, report: report, renderTerminal: renderTerminal };
})();

if (typeof module !== 'undefined') module.exports = CHART;
