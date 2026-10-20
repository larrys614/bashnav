// weather's own cache, scoped to this folder so it and the other tools
// update independently.
//
// The log itself is never cached: it lives in IndexedDB, shared with
// deck-log, and a cache is something the browser may throw away.
const CACHE = 'weather-v1';
const FILES = ['./', './index.html', './weather.css', './weather.js',
               './log.js', './store.js', './wx.js', './score.js',
               './chart.js', './lessons.js',
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
