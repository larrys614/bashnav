# bashnav — the web build

Five tools and a launcher, as ordinary web pages. No build step, no
dependencies, no network once loaded.

    index.html        the launcher: one tile per tool
    colregs/          rules of the road, lights, shapes, sounds   (v1.15)
    celnav/           camera sight: an altitude from a photograph
    icons/            one icon per tool, drawn to read at 60 px

`tides/`, `weather/` and `deck-log/` are not built yet; the launcher shows
them as "NOT YET" rather than as links that go nowhere.

## Installing

Drop this `web/` directory into the repository root, commit, push, then turn
on GitHub Pages: **Settings → Pages → Deploy from a branch → `main` → `/ (root)`**.
Each tool is then its own page:

    https://larrys614.github.io/bashnav/web/
    https://larrys614.github.io/bashnav/web/colregs/
    https://larrys614.github.io/bashnav/web/celnav/

Open one in **Safari** on the iPad and use **Share → Add to Home Screen**. Each
URL gets its own icon, because each has its own manifest.

Turning Pages on publishes the whole repository as a browsable website. That is
worth deciding deliberately rather than discovering.

## Offline

Every tool registers a service worker scoped to its own folder and caches
itself cache-first, so each updates independently and all of them keep working
with no signal. Prove it once at the dock rather than at sea: open every
screen, turn the network off, and relaunch from the icon.

**Cache-first bites during development.** A republish serves the old code to
anyone who opened the page before, with no sign it has done so. A build can
set `window.CELNAV_NO_SW = 1`, which unregisters any worker and clears the
caches instead of installing one; the hosted test builds use it. Every page
also prints a build stamp at the bottom, because debugging remotely without
one means guessing which version is on the device.

## What is verified, and how

`colregs` geometry was diffed against the awk engine over all 361 integer
bearings, and its data was emitted by running that engine's own table
initialisers rather than transcribed.

`celnav`'s engine was diffed over 20,568 reference rows — 140 epochs × 17
bodies, 11,424 sight reductions across the whole sphere, 6,624 correction
cases — plus the fix solver, the twilight search and the drill generator.
Worst disagreement 1.7e-7 degrees. It also reproduces the shell tool's
self-test against an independent reference ephemeris at 0.151 arcmin.

The camera geometry has no awk counterpart, so it is checked by synthesis:
project a body of known altitude into a synthetic photograph, measure the
picture, and compare. The plane-normal method is exact to 2.5e-8 arcmin over
300 geometries; the obvious `atan(y/f)` approach is wrong by up to 384
arcminutes once the camera is rolled and the body off-axis.
