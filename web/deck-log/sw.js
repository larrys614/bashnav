// deck-log's own cache, scoped to this folder so it and the other tools
// update independently.
//
// The LOG is not in here and must never be: it lives in IndexedDB, which
// is the boat's record, and a cache is something the browser may throw
// away. This worker caches the app, nothing else.
const CACHE = 'deck-log-v1';
const FILES = ['./', './index.html', './decklog.css', './decklog.js',
               './log.js', './store.js', './views.js', './menus.js',
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
