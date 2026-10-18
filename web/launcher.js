/* =====================================================================
   The launcher.  No framework, no build step; this file is the app.

   The tile list is the single source of truth for what exists.  A tool
   ships by flipping `ready` to true once its folder is published - the
   launcher needs no other edit, and a tool that is not ready renders as
   plainly unavailable rather than as a link that goes nowhere.
   ===================================================================== */
var TOOLS = [
  { id: 'celnav',   name: 'celnav',   ver: '1.6',
    desc: 'Camera sight \u2014 an altitude from a photograph', ready: true },
  { id: 'colregs',  name: 'colregs',  ver: '1.15',
    desc: 'Lights, shapes, sounds and the rules of the road', ready: true },
  { id: 'tides',    name: 'tides',    ver: '1.1',
    desc: 'Harmonic prediction, 8,334 stations', ready: false },
  { id: 'weather',  name: 'weather',  ver: '1.0',
    desc: 'Read your own barometer', ready: false },
  { id: 'deck-log', name: 'deck-log', ver: '1.1',
    desc: "The boat's records: deck, engine, provisions", ready: false }
];

function $(id) { return document.getElementById(id); }

function setMode(m) {
  document.documentElement.setAttribute('data-mode', m);
  $('mode').textContent = m === 'night' ? 'DARK' : 'NIGHT';
  var meta = document.querySelector('meta[name="theme-color"]');
  if (meta) meta.setAttribute('content', m === 'night' ? '#060101' : '#07090b');
  try { localStorage.setItem('bashnav-mode', m); } catch (e) { /* private mode */ }
}

function tiles() {
  var box = $('tiles');
  TOOLS.forEach(function (t) {
    var el = document.createElement(t.ready ? 'a' : 'div');
    el.className = 'tile';
    if (t.ready) { el.href = t.id + '/'; }
    else { el.setAttribute('aria-disabled', 'true'); }

    var img = document.createElement('img');
    img.src = 'icons/' + t.id + '.svg'; img.alt = '';
    var tx = document.createElement('div');
    var b = document.createElement('b'); b.textContent = t.name;
    var s = document.createElement('span'); s.textContent = t.desc;
    tx.appendChild(b); tx.appendChild(s);
    el.appendChild(img); el.appendChild(tx);

    if (!t.ready) {
      var tag = document.createElement('span');
      tag.className = 'soon'; tag.textContent = 'NOT YET';
      el.appendChild(tag);
    }
    box.appendChild(el);
  });
}

window.addEventListener('DOMContentLoaded', function () {
  var saved = 'dark';
  try { saved = localStorage.getItem('bashnav-mode') || 'dark'; } catch (e) {}
  setMode(saved === 'night' ? 'night' : 'dark');
  $('mode').addEventListener('click', function () {
    setMode(document.documentElement.getAttribute('data-mode') === 'night' ? 'dark' : 'night');
  });

  tiles();

  var ready = TOOLS.filter(function (t) { return t.ready; }).length;
  $('ver').textContent = ready + ' of ' + TOOLS.length +
    ' tools published. The rest are being built.';

  /* Add to Home Screen is a Safari function; inside another app's web
     view the menu item does not exist, and saying so beats the user
     hunting for it. */
  var standalone = window.navigator.standalone === true ||
                   window.matchMedia('(display-mode: standalone)').matches;
  var ios = /iPad|iPhone|iPod/.test(navigator.userAgent) ||
            (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
  if (ios && !standalone && window.navigator.standalone === undefined) {
    $('warn').textContent = 'This looks like an in-app browser rather than Safari. ' +
      'Add to Home Screen only exists in Safari itself — open this page there.';
    $('warn').hidden = false;
  }

  if ('serviceWorker' in navigator && location.protocol !== 'file:') {
    navigator.serviceWorker.register('sw.js').catch(function () {});
  }
});
