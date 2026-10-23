// Service worker: the whole point is that this works with no network at sea.
// Cache-first, because none of these files change while you are offshore and
// a network lookup you cannot satisfy is just latency you did not need.
const CACHE = 'colregs-v7'
const FAMILY = 'colregs-';
const FILES = [
  './', './index.html', './colregs.css', './colregs.js',
  './data.js', './contacts.js', './contacts-lessons.js', './contacts-figs.js',
  './manifest.webmanifest', './icon.svg'
];
self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(FILES)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      //  DELETE ONLY THIS TOOL'S OWN OLD CACHES.  caches.delete() is
      //  ORIGIN-wide, not scope-wide: every tool on larrys614.github.io
      //  shares one CacheStorage, so "delete everything that is not
      //  mine" had each worker evicting all the others. Visit colregs
      //  then drill and colregs' cache is gone -- and it does not come
      //  back, because install runs once per worker version, so from
      //  then on that tool is silently online-only. On a boat with no
      //  signal that is the whole promise broken.
      //  The family is derived from CACHE rather than written out
      //  again, so there is no second constant to drift.
      .then(ks => Promise.all(ks
            .filter(k => k.indexOf(FAMILY) === 0 && k !== CACHE)
            .map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  e.respondWith(
    caches.match(e.request).then(hit => hit || fetch(e.request).catch(() => caches.match('./index.html')))
  );
});
