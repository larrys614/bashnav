// drill's own cache, scoped to this folder so it and the other tools
// update independently.
//
// THE PACK IS NEVER CACHED. It lives in IndexedDB, it is the user's own
// material, and a cache is something the browser may throw away and
// something a later version of this worker deletes wholesale on
// activate. Only the empty machine is cached here.
//  BUMP THIS WHENEVER ANY CACHED FILE CHANGES.  The fetch handler below
//  is cache-first, so an installed copy serves the drill.js it cached and
//  a new deploy never reaches it -- the browser only reinstalls the
//  worker when THIS file's bytes differ.  The version here must match
//  BUILD in drill.js, and the test harness checks that it does.
const CACHE = 'drill-v9';
const FILES = ['./', './index.html', './drill.css', './drill.js',
               './manifest.webmanifest', './icon.svg'];
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
  e.respondWith(caches.match(e.request).then(hit => hit ||
    fetch(e.request).catch(() => caches.match('./'))));
});
