// =====================================================================
//  deck-log -- where the log lives in a browser, and how it leaves.
//
//  IndexedDB, one record per row, keyed by insertion order.  Not one
//  big string: appending a record must not rewrite the records already
//  written, and a store that rewrites its whole contents on every
//  append is one interrupted transaction away from losing a passage.
//  The append-only promise is kept by the STORAGE too, not only by the
//  code above it.
//
//  EXPORT IS THE BACKUP, not a convenience feature.  Browser storage is
//  reliable on a real origin -- which is why these tools are hosted
//  rather than opened out of Files -- but it is per-device, invisible,
//  and the user can erase it by clearing website data.  A boat's record
//  cannot live only there, so the app asks for persistent storage and
//  nags honestly about exporting.
//
//  Export is the log itself, byte for byte.  Plain text, no JSON, no
//  wrapper.  The format was chosen so somebody could read it with no
//  software to hand after an incident; wrapping it on the way out would
//  throw that away at exactly the moment it matters.
// =====================================================================
'use strict';

var STORE = (function () {

  var DB_NAME = 'deck-log';
  var DB_VER = 1;
  var REC = 'records';        // the log: append-only, insertion-keyed
  var META = 'meta';          // the registry and settings: these do change
  var db = null;

  function open() {
    if (db) return Promise.resolve(db);
    return new Promise(function (res, rej) {
      if (!window.indexedDB) { rej(new Error('this browser has no IndexedDB')); return; }
      var rq = indexedDB.open(DB_NAME, DB_VER);
      rq.onupgradeneeded = function () {
        var d = rq.result;
        if (!d.objectStoreNames.contains(REC)) d.createObjectStore(REC, { autoIncrement: true });
        if (!d.objectStoreNames.contains(META)) d.createObjectStore(META);
      };
      rq.onsuccess = function () { db = rq.result; res(db); };
      rq.onerror = function () { rej(rq.error || new Error('could not open the log store')); };
    });
  }

  function tx(store, mode) {
    return open().then(function (d) {
      return d.transaction(store, mode).objectStore(store);
    });
  }
  function done(request) {
    return new Promise(function (res, rej) {
      request.onsuccess = function () { res(request.result); };
      request.onerror = function () { rej(request.error); };
    });
  }

  // ---- persistence ------------------------------------------------
  //  Ask the browser to treat this as durable rather than as a cache it
  //  may reclaim.  It can refuse, and the About screen says which it is
  //  rather than implying the log is safer than it is.
  var asked = false;
  function persist() {
    if (asked || !navigator.storage || !navigator.storage.persist) return Promise.resolve(null);
    asked = true;
    return navigator.storage.persist().catch(function () { return null; });
  }
  function persistState() {
    if (!navigator.storage || !navigator.storage.persisted) return Promise.resolve(null);
    return navigator.storage.persisted().catch(function () { return null; });
  }

  // ---- the log ----------------------------------------------------
  function append(lines) {
    if (typeof lines === 'string') lines = [lines];
    if (!lines.length) return Promise.resolve(0);
    return open().then(function (d) {
      return new Promise(function (res, rej) {
        var t = d.transaction(REC, 'readwrite'), s = t.objectStore(REC);
        lines.forEach(function (L) { s.add(L); });
        t.oncomplete = function () { res(lines.length); };
        t.onerror = function () { rej(t.error); };
        t.onabort = function () { rej(t.error || new Error('the write was aborted')); };
      });
    }).then(function (n) { persist(); return n; });
  }

  function allLines() {
    return tx(REC, 'readonly').then(function (s) { return done(s.getAll()); });
  }

  // ---------------------------------------------------------------
  //  The canonical text of the log: unique lines, ordered by UTC
  //  timestamp and then by the whole line.
  //
  //  Sorting on the way OUT rather than on the way in is what makes the
  //  merge safe.  Storage stays strictly append-only, and the exported
  //  file is a pure function of the SET of records held -- so merging A
  //  into B and B into A produce byte-identical files, and merging the
  //  same file twice changes nothing.  Those two properties are the
  //  whole safety argument: a merge you can run twice by accident, or
  //  in either direction, is a merge nobody has to be careful with at
  //  0400.
  // ---------------------------------------------------------------
  function canonical(lines) {
    var seen = {}, out = [], i;
    for (i = 0; i < lines.length; i++) {
      if (lines[i] === '' || Object.prototype.hasOwnProperty.call(seen, lines[i])) continue;
      seen[lines[i]] = 1;
      out.push(lines[i]);
    }
    out.sort(function (a, b) {
      var ta = a.substring(0, 17), tb = b.substring(0, 17);
      if (ta !== tb) return ta < tb ? -1 : 1;
      return a < b ? -1 : a > b ? 1 : 0;
    });
    return out;
  }

  function exportText() {
    return allLines().then(function (ls) {
      var c = canonical(ls);
      return c.length ? c.join('\n') + '\n' : '';
    });
  }

  // ---------------------------------------------------------------
  //  Import never replaces.  It merges.
  //
  //  Replacing a log with an imported one is the most destructive thing
  //  this app could offer and it is one mis-tap from losing a passage,
  //  so there is no replace.  The preview runs before anything is
  //  written, and a file that will not parse whole is rejected whole.
  // ---------------------------------------------------------------
  function previewMerge(text) {
    return allLines().then(function (ls) {
      var held = {}, i, r;
      var heldByKey = {};
      for (i = 0; i < ls.length; i++) {
        held[ls[i]] = 1;
        r = LOG.parse(ls[i]);
        if (r) {
          var k = r.ts + '|' + r.type;
          (heldByKey[k] = heldByKey[k] || []).push(ls[i]);
        }
      }
      var incoming = text.split('\n');
      var out = { dup: 0, add: 0, bad: 0, badLine: '', newLines: [], conflicts: [], total: 0 };
      for (i = 0; i < incoming.length; i++) {
        var L = incoming[i];
        if (L === '' || L.charAt(0) === '#') continue;
        out.total++;
        r = LOG.parse(L);
        if (!r) {
          out.bad++;
          if (out.badLine === '') out.badLine = L + '   (' + LOG.err() + ')';
          continue;
        }
        if (Object.prototype.hasOwnProperty.call(held, L)) { out.dup++; continue; }
        out.add++;
        out.newLines.push(L);
        //  A genuine conflict is the same timestamp AND the same type
        //  with different content: two people logged 1800Z weather and
        //  they disagree.  BOTH are kept.  Picking one would be deleting
        //  a record, which is the operation this format forbids, and the
        //  maritime convention is already clear -- you do not erase a
        //  log, you line through and annotate.
        var key = r.ts + '|' + r.type;
        if (heldByKey[key]) {
          out.conflicts.push({ ts: r.ts, type: r.type, held: heldByKey[key][0], incoming: L });
        }
      }
      return out;
    });
  }

  //  A truncated or corrupt import is rejected WHOLE, leaving the held
  //  log byte-identical.  Half an imported log is worse than none: you
  //  cannot tell afterwards which half you got.
  function applyMerge(preview, srcName, by) {
    if (preview.bad) {
      return Promise.reject(new Error(preview.bad +
        ' records in that file will not parse, so nothing was imported. First: ' +
        preview.badLine));
    }
    var lines = preview.newLines.slice();
    //  The merge is itself an event.  A log that has been merged says
    //  so, and says what came in -- after an incident that is the
    //  difference between a record and a mystery.
    lines.push(LOG.make(LOG.stamp(), 'mrg', [
      ['src', srcName],
      ['add', preview.add],
      ['dup', preview.dup],
      ['conf', preview.conflicts.length],
      ['by', by || '']
    ]));
    return append(lines).then(function () { return preview; });
  }

  // ---- the registry and settings ----------------------------------
  function metaGet(k, dflt) {
    return tx(META, 'readonly').then(function (s) { return done(s.get(k)); })
      .then(function (v) { return v === undefined ? dflt : v; })
      .catch(function () { return dflt; });
  }
  function metaSet(k, v) {
    return tx(META, 'readwrite').then(function (s) { return done(s.put(v, k)); });
  }

  // ---- how overdue is the backup ----------------------------------
  //  A backup nobody is reminded about is a backup that does not exist,
  //  and unlike a desktop app this one sits on storage the operating
  //  system is entitled to reclaim.
  function backupState() {
    return Promise.all([allLines(), metaGet('lastExport', '')]).then(function (r) {
      var lines = r[0], last = r[1];
      var since = 0, oldest = '';
      for (var i = 0; i < lines.length; i++) {
        var ts = lines[i].substring(0, 17);
        if (last && ts <= last) continue;
        since++;
        if (oldest === '' || ts < oldest) oldest = ts;
      }
      return { total: lines.length, since: since, oldest: oldest, last: last };
    });
  }
  function markExported() {
    return allLines().then(function (lines) {
      var max = '';
      for (var i = 0; i < lines.length; i++) {
        var ts = lines[i].substring(0, 17);
        if (ts > max) max = ts;
      }
      return metaSet('lastExport', max);
    });
  }

  return { open: open, append: append, allLines: allLines, canonical: canonical,
           exportText: exportText, previewMerge: previewMerge, applyMerge: applyMerge,
           metaGet: metaGet, metaSet: metaSet, persist: persist,
           persistState: persistState, backupState: backupState,
           markExported: markExported };
})();

if (typeof module !== 'undefined') module.exports = STORE;
