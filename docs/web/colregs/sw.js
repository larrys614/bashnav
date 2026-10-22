// Service worker: the whole point is that this works with no network at sea.
// Cache-first, because none of these files change while you are offshore and
// a network lookup you cannot satisfy is just latency you did not need.
const CACHE = 'colregs-v3';
const FILES = [
  './', './index.html', './colregs.css', './colregs.js',
  './data.js', './manifest.webmanifest', './icon.svg'
];
self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(FILES)).then(() => self.skipWaiting()));
});
self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys()
      .then(ks => Promise.all(ks.filter(k => k !== CACHE).map(k => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  e.respondWith(
    caches.match(e.request).then(hit => hit || fetch(e.request).catch(() => caches.match('./index.html')))
  );
});
