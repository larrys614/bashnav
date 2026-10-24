// celnav's own cache, scoped to this folder so it and the other tools
// update independently.
const CACHE = 'celnav-v3'
//  this tool's family, derived from CACHE so there is no second
//  constant to drift out of step with it
const FAMILY = 'celnav-';
//  calib.js and plot.js were missing here from the day they were added
//  to index.html, so the camera calibration and the plot sheet were
//  fetched from the network on first use -- which at sea means never.
//  tests/sw-precache-check.sh found it and now keeps it found.
const FILES = ['./', './celnav.css', './camui.js', './engine.js', './engine2.js',
               './camsight.js', './refine.js', './exif.js', './tables.js',
               './calib.js', './plot.js', './lessons.js', './celnav-app.js',
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
