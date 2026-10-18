/* Minimal EXIF reader -- just enough to get the plate scale and the
   orientation out of a JPEG the camera handed us.  No library, because the
   page must work with no network and every dependency is a thing that can
   fail at sea.
   Returns { focal35, focal, wPx, hPx, orientation, make, model, exposure }. */
function readExif(buf) {
  const v = new DataView(buf);
  if (v.byteLength < 4 || v.getUint16(0) !== 0xFFD8) return null;     // not a JPEG
  let off = 2;
  while (off < v.byteLength - 4) {
    if (v.getUint8(off) !== 0xFF) { off++; continue; }
    const marker = v.getUint8(off + 1);
    if (marker === 0xE1) {                                            // APP1
      const len = v.getUint16(off + 2);
      if (v.getUint32(off + 4) === 0x45786966) return parseTiff(v, off + 10);
      off += 2 + len;
    } else if (marker === 0xD8 || (marker >= 0xD0 && marker <= 0xD9)) { off += 2; }
    else { off += 2 + v.getUint16(off + 2); }
  }
  return null;
}
function parseTiff(v, base) {
  const le = v.getUint16(base) === 0x4949;
  const u16 = o => v.getUint16(o, le), u32 = o => v.getUint32(o, le);
  if (u16(base + 2) !== 42) return null;
  const out = {};
  const TAGS = {
    0x0112: 'orientation', 0x010F: 'make', 0x0110: 'model',
    0x8769: '_exifIfd', 0xA002: 'wPx', 0xA003: 'hPx',
    0x920A: 'focal', 0xA405: 'focal35', 0x829A: 'exposure', 0x8827: 'iso'
  };
  function readIfd(ifdOff) {
    if (ifdOff <= 0 || base + ifdOff + 2 > v.byteLength) return;
    const n = u16(base + ifdOff);
    for (let i = 0; i < n; i++) {
      const e = base + ifdOff + 2 + i * 12;
      if (e + 12 > v.byteLength) return;
      const tag = u16(e), type = u16(e + 2), count = u32(e + 4);
      const name = TAGS[tag];
      if (!name) continue;
      let val = null;
      if (type === 3) val = u16(e + 8);                               // SHORT
      else if (type === 4) val = u32(e + 8);                          // LONG
      else if (type === 5) {                                          // RATIONAL
        const p = base + u32(e + 8);
        if (p + 8 <= v.byteLength) { const d = u32(p + 4); val = d ? u32(p) / d : null; }
      } else if (type === 2) {                                        // ASCII
        const p = count > 4 ? base + u32(e + 8) : e + 8;
        let s = '';
        for (let k = 0; k < count - 1 && p + k < v.byteLength; k++) s += String.fromCharCode(v.getUint8(p + k));
        val = s;
      }
      if (name === '_exifIfd') { readIfd(val); continue; }
      if (val !== null) out[name] = val;
    }
  }
  readIfd(u32(base + 4));
  return out;
}
if (typeof module !== 'undefined') module.exports = { readExif };

if (typeof window !== 'undefined') window.EXIF = { readExif };
