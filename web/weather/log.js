// =====================================================================
//  deck-log -- the record layer, browser build.
//
//  A port of src/decklog/log.awk, and the one file here that must be
//  exact.  The log is append-only: a record written today has to parse
//  in five years, by a reader nobody has written yet, in whatever
//  language that reader is in.  Adding a key later is free -- a reader
//  ignores keys it does not know.  Changing the SHAPE is not, ever.
//
//      YYYY-MM-DDThh:mmZ|type|key=value|key=value|...|~
//
//  THE TRAILING ~ IS A COMPLETENESS MARKER.  Kill the app mid-write and
//  the half-line left behind is STRUCTURALLY PERFECT: right timestamp,
//  right type, every field a well-formed key=value.  Nothing
//  distinguishes it from a finished record, so a reader accepts it and
//  you silently lose whatever never reached the disk -- an engine entry
//  with the part but not the hours, and no sign anything is missing.
//  In an append-only log that is permanent.
//
//  A truncation cannot forge the marker: | is percent-encoded inside
//  values, so the sequence |~ appears nowhere else.
//
//  Everything in this file is byte-compatible with the awk tool, and
//  web/tests/decklog-roundtrip.js proves it by passing records both
//  ways.  The two tools share one log; they are not two formats that
//  look alike.
// =====================================================================
'use strict';

var LOG = (function () {

  // ---------------------------------------------------------------
  //  Encoding.  Only four characters, so ordinary text stays literal
  //  and the log is still readable by eye and by grep -- which matters
  //  for a file somebody may have to interpret after an incident with
  //  no software to hand.
  // ---------------------------------------------------------------
  function enc(s) {
    s = String(s === undefined || s === null ? '' : s);
    s = s.split('%').join('%25');     // first, or it double-encodes the rest
    s = s.split('|').join('%7C');
    s = s.split('=').join('%3D');
    s = s.split('\n').join('%0A');
    return s;
  }
  function dec(s) {
    s = s.split('%0A').join('\n');
    s = s.split('%3D').join('=');
    s = s.split('%7C').join('|');
    s = s.split('%25').join('%');     // last, for the same reason in reverse
    return s;
  }

  // ---------------------------------------------------------------
  //  Building a record.  Callers hand over keys and values, never a
  //  formatted string, so exactly one place knows the delimiters and
  //  exactly one place encodes.
  // ---------------------------------------------------------------
  function make(ts, type, fields) {
    var out = ts + '|' + type, i;
    for (i = 0; i < fields.length; i++) {
      if (fields[i][0] === '' || fields[i][0] === undefined) continue;
      out += '|' + fields[i][0] + '=' + enc(fields[i][1]);
    }
    return out + '|~';                // the completeness marker
  }

  //  A timestamp this reader will accept for ever: YYYY-MM-DDThh:mmZ
  var TS_RE = /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]Z$/;
  function tsOk(s) {
    if (s === undefined || s === null) return false;
    if (s.length !== 17) return false;
    return TS_RE.test(s);
  }

  //  Written out rather than as [a-z0-9]{0,4}, to stay the same pattern as
  //  the awk.  JavaScript implements interval expressions perfectly well;
  //  mawk 1.3.3 does not -- it reads {0,4} as four literal characters, so
  //  the awk side of this format rejected EVERY record under the awk that
  //  `awk` is on Debian, Ubuntu and a-Shell.  Keeping the two files
  //  literally the same pattern is the point of a port like this.
  var TYPE_RE = /^[a-z]([a-z0-9]([a-z0-9]([a-z0-9][a-z0-9]?)?)?)?$/;
  var KEY_RE = /^[a-z0-9_]+$/;

  // ---------------------------------------------------------------
  //  Parsing.  Returns a record, or null with .err set on the result of
  //  lastError() -- it never throws, because a damaged tail must not
  //  take the whole log with it.
  // ---------------------------------------------------------------
  var lastErr = '';
  function err() { return lastErr; }

  function parse(line) {
    lastErr = '';
    if (line === '' || line === undefined || line === null) { lastErr = 'blank or comment'; return null; }
    if (line.charAt(0) === '#') { lastErr = 'blank or comment'; return null; }
    var f = line.split('|'), n = f.length;
    if (n < 3) { lastErr = 'too few fields'; return null; }
    if (!tsOk(f[0])) { lastErr = 'bad timestamp: ' + f[0]; return null; }
    if (!TYPE_RE.test(f[1])) { lastErr = 'bad type: ' + f[1]; return null; }
    //  The record must be COMPLETE.  Without this a half-written line
    //  parses cleanly and quietly loses whatever never reached the disk.
    if (f[n - 1] !== '~') { lastErr = 'incomplete record (no terminator)'; return null; }
    var r = { ts: f[0], type: f[1], v: {}, nf: 0, line: line };
    for (var i = 2; i < n - 1; i++) {
      var p = f[i].indexOf('=');
      if (p < 1) { lastErr = 'field ' + (i + 1) + ' is not key=value: ' + f[i]; return null; }
      var key = f[i].substring(0, p), val = f[i].substring(p + 1);
      if (!KEY_RE.test(key)) { lastErr = 'bad key: ' + key; return null; }
      r.v[key] = dec(val);
      r.nf++;
    }
    return r;
  }

  // ---------------------------------------------------------------
  //  Reading a whole log.  A record that will not parse is COUNTED and
  //  SKIPPED, never fatal: the app is suspended, the battery dies, the
  //  tab is killed mid-write.  A half-written last line must not make
  //  the log unreadable, and must not silently swallow the good records
  //  above it either.
  // ---------------------------------------------------------------
  function read(text, want) {
    var out = { recs: [], good: 0, bad: 0, badLine: '' };
    var lines = text.split('\n'), i, r;
    for (i = 0; i < lines.length; i++) {
      var L = lines[i];
      if (L === '' || L.charAt(0) === '#') continue;
      r = parse(L);
      if (!r) {
        out.bad++;
        if (out.badLine === '') out.badLine = L;
        continue;
      }
      out.good++;
      if (want && r.type !== want) continue;
      out.recs.push(r);
    }
    return out;
  }

  // ---------------------------------------------------------------
  //  The UTC stamp, to the minute, as the log spells it.
  // ---------------------------------------------------------------
  function stamp(d) {
    d = d || new Date();
    function p(n) { return (n < 10 ? '0' : '') + n; }
    return d.getUTCFullYear() + '-' + p(d.getUTCMonth() + 1) + '-' + p(d.getUTCDate()) +
           'T' + p(d.getUTCHours()) + ':' + p(d.getUTCMinutes()) + 'Z';
  }
  //  The synoptic slot a time belongs to: the three-hourly cadence the
  //  whole tool runs on, and it includes 0000/0600/1200/1800 UTC, which
  //  is what forecast verification needs.
  function slot(d) {
    d = d || new Date();
    var h = Math.floor(d.getUTCHours() / 3) * 3;
    var u = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate(), h, 0, 0));
    return stamp(u);
  }
  function tsDate(ts) {
    return new Date(Date.UTC(+ts.substr(0, 4), +ts.substr(5, 2) - 1, +ts.substr(8, 2),
                             +ts.substr(11, 2), +ts.substr(14, 2), 0));
  }

  return { enc: enc, dec: dec, make: make, parse: parse, read: read,
           tsOk: tsOk, err: err, stamp: stamp, slot: slot, tsDate: tsDate };
})();

if (typeof module !== 'undefined') module.exports = LOG;
