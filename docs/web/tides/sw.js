// tides' own cache, scoped to this folder so it and the other tools
// update independently.
//
// stations.dat (2.9 MB) is deliberately NOT in the install list.  A
// single large file in addAll() fails the whole install on a flaky
// connection, and the result is that nothing at all gets cached -- the
// opposite of what a worker is for on a boat.  It is cached on first
// successful fetch instead, and the About screen has a button that
// fetches it with a progress bar.
const CACHE = 'tides-v1'
//  this tool's family, derived from CACHE so there is no second
//  constant to drift out of step with it
const FAMILY = 'tides-';
const FILES = ['./', './index.html', './tides.css', './tides.js',
               './engine.js', './tables.js', './stations.idx',
               './manifest.webmanifest', './icon.svg'];
const BIG = './stations.dat';

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(FILES)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys()
    //  DELETE ONLY THIS TOOL'S OWN OLD CACHES.  caches.delete() is
    //  ORIGIN-wide, not scope-wide: every tool on larrys614.github.io
    //  shares one CacheStorage, so "delete everything that is not mine"
    //  had each worker evicting all the others.  Visit colregs then
    //  drill and colregs' cache is gone -- and it does not come back,
    //  because install runs once per worker version, so from then on
    //  that tool is silently online-only.  On a boat with no signal
    //  that is the whole promise broken.
    .then(ks => Promise.all(ks
          .filter(k => k.indexOf(FAMILY) === 0 && k !== CACHE)
          .map(k => caches.delete(k))))
    .then(() => self.clients.claim()));
});
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  const url = new URL(e.request.url);
  const isBig = url.pathname.endsWith('/stations.dat');

  if (isBig) {
    // A cached copy answers a ranged request in full; the page checks the
    // status and slices the bytes itself, so that is correct and cheap.
    e.respondWith(
      caches.match(new Request(url.pathname)).then(hit => {
        if (hit) return hit;
        return fetch(e.request).then(r => {
          // NEVER store a 206.  A partial response saved under this URL
          // would make every later read return a few hundred bytes of the
          // file, and the failure looks like corrupt data rather than a
          // caching mistake.
          if (r.status === 200) {
            const copy = r.clone();
            caches.open(CACHE).then(c => c.put(url.pathname, copy)).catch(() => {});
          }
          return r;
        });
      })
    );
    return;
  }

  e.respondWith(caches.match(e.request).then(hit => hit ||
    fetch(e.request).catch(() => caches.match('./'))));
});
