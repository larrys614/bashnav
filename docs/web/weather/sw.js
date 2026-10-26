// weather's own cache, scoped to this folder so it and the other tools
// update independently.
//
// The log itself is never cached: it lives in IndexedDB, shared with
// deck-log, and a cache is something the browser may throw away.
//  Bump on any change to a cached file. The worker is cache-first, so an
//  installed copy serves what it already has until THIS file's bytes
//  differ. The page no longer names this string -- it finds the cache by
//  prefix -- so bumping it here is all that is needed.
const CACHE = 'weather-v7'
//  this tool's family, derived from CACHE so there is no second
//  constant to drift out of step with it
const FAMILY = 'weather-';
const FILES = ['./', './index.html', './weather.css', './weather.js',
               './log.js', './store.js', './wx.js', './score.js',
               './chart.js', './lessons.js',
               './manifest.webmanifest', './icon.svg'];
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
  e.respondWith(caches.match(e.request).then(hit => hit ||
    fetch(e.request).catch(() => caches.match('./'))));
});
