# Safety notice

**These are training and cross-checking tools. They are not certified navigation
equipment, and nothing in this repository relieves you of any duty at sea.**

## celnav

`celnav` computes an almanac and reduces sights. Its accuracy has been measured
against an independent high-precision ephemeris and is documented in the manual:
better than half a minute of arc for every body over 1990–2076, which is smaller
than a good sextant observation from a small vessel.

That is a statement about the arithmetic, not about your fix. A fix is only as
good as the sight, the horizon, and above all the time. Four seconds of clock
error is one nautical mile of longitude.

Use it as a check on your own work, and carry the tables. A single script on a
single device is a single point of failure, which is exactly why every
intermediate value is printed: you can continue the reduction by hand from any
line of the output.

## colregs

`colregs` is a training aid for the International Regulations for Preventing
Collisions at Sea. It is not the rules, it does not reproduce their text in
full, and it carries no authority.

The Convention is published by the IMO and is what governs at sea. Where this
program and the Convention differ, the Convention is right and this program is
wrong — please open an issue.

Nothing here relieves any vessel, owner, master or crew of the consequences of
neglecting to comply with the rules, of neglecting a proper look-out, or of
neglecting any precaution which the ordinary practice of seamen, or the special
circumstances of the case, may require.

## No warranty

Both tools are provided under the MIT licence, which includes an explicit
disclaimer of warranty and of liability. Read `LICENSE`.
