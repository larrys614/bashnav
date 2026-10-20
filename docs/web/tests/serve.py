#!/usr/bin/env python3
"""A static server that honours Range, so the browser build's 206 path is
exercised and not just its fallback.  Python's own SimpleHTTPRequestHandler
does not do ranges, and testing against it proves only the fallback."""
import http.server, os, re, socketserver, sys

ROOT = sys.argv[2] if len(sys.argv) > 2 else '.'
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8088
NORANGE = os.environ.get('NORANGE') == '1'

class H(http.server.SimpleHTTPRequestHandler):
    def translate_path(self, path):
        p = path.split('?', 1)[0].split('#', 1)[0]
        p = os.path.normpath(p).lstrip('/\\')
        return os.path.join(ROOT, p)

    def log_message(self, *a):
        pass

    def do_GET(self):
        rng = self.headers.get('Range')
        path = self.translate_path(self.path)
        if os.path.isdir(path):
            path = os.path.join(path, 'index.html')
        if not rng or NORANGE or not os.path.isfile(path):
            return super().do_GET()
        m = re.match(r'bytes=(\d+)-(\d*)$', rng.strip())
        if not m:
            return super().do_GET()
        size = os.path.getsize(path)
        a = int(m.group(1))
        b = int(m.group(2)) if m.group(2) else size - 1
        if a >= size:
            self.send_response(416); self.end_headers(); return
        b = min(b, size - 1)
        with open(path, 'rb') as f:
            f.seek(a); data = f.read(b - a + 1)
        self.send_response(206)
        self.send_header('Content-Type', self.guess_type(path))
        self.send_header('Content-Length', str(len(data)))
        self.send_header('Content-Range', 'bytes %d-%d/%d' % (a, b, size))
        self.send_header('Accept-Ranges', 'bytes')
        self.end_headers()
        self.wfile.write(data)

class S(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True

S(('127.0.0.1', PORT), H).serve_forever()
