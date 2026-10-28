"""Localhost receiver for Studio rig dumps: POST /rig/<name> with JSON -> rigs/<name>.json.
GET /file/<path> serves files from this folder (rbxm/rbxmx for Studio to deserialize).
  python3 receiver.py [port]   (default 8804)"""
import json, sys, http.server
from pathlib import Path
from urllib.parse import unquote
HERE = Path(__file__).resolve().parent
PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8804


class H(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        body = self.rfile.read(int(self.headers['Content-Length']))
        name = unquote(self.path.split('/rig/', 1)[1])
        (HERE / 'rigs' / f'{name}.json').write_bytes(body)
        self.send_response(200); self.end_headers(); self.wfile.write(b'ok')

    def do_GET(self):
        p = (HERE / unquote(self.path.split('/file/', 1)[1])).resolve()
        if HERE not in p.parents or not p.exists():
            self.send_response(404); self.end_headers(); return
        self.send_response(200); self.end_headers(); self.wfile.write(p.read_bytes())

    def log_message(self, *a):
        pass


http.server.ThreadingHTTPServer(('127.0.0.1', PORT), H).serve_forever()
