// tides' own cache, scoped to this folder so it and the other tools
// update independently.
//
// stations.dat (2.9 MB) is deliberately NOT in the install list.  A
// single large file in addAll() fails the whole install on a flaky
// connection, and the result is that nothing at all gets cached -- the
// opposite of what a worker is for on a boat.  It is cached on first
// successful fetch instead, and the About screen has a button that
// fetches it with a progress bar.
const CACHE = 'tides-v1';
const FILES = ['./', './index.html', './tides.css', './tides.js',
               './engine.js', './tables.js', './stations.idx',
               './manifest.webmanifest', './icon.svg'];
const BIG = './stations.dat';

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(FILES)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(caches.keys()
    .then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k))))
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
