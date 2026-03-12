#!/usr/bin/env python3
"""Local web server for Block Count with required CORS headers and gzip support."""

from http.server import HTTPServer, SimpleHTTPRequestHandler
import os
import sys
import gzip

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
WEB_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "build", "web")

COMPRESSIBLE = {'.wasm', '.js', '.pck', '.html'}


class Handler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def do_GET(self):
        path = self.translate_path(self.path)
        ext = os.path.splitext(path)[1].lower()
        accepts_gzip = 'gzip' in self.headers.get('Accept-Encoding', '')

        if accepts_gzip and ext in COMPRESSIBLE and os.path.isfile(path):
            with open(path, 'rb') as f:
                data = gzip.compress(f.read(), compresslevel=6)
            self.send_response(200)
            self.send_header('Content-Encoding', 'gzip')
            self.send_header('Content-Length', str(len(data)))
            ctype = self.guess_type(path)
            self.send_header('Content-Type', ctype)
            self.end_headers()
            self.wfile.write(data)
        else:
            super().do_GET()


def main():
    os.chdir(WEB_DIR)
    server = HTTPServer(("localhost", PORT), Handler)
    print(f"Serving Block Count at http://localhost:{PORT}")
    print("Press Ctrl+C to stop")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped")


if __name__ == "__main__":
    main()
