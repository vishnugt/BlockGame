#!/usr/bin/env python3
"""Local web server for Block Count with required CORS headers."""

from http.server import HTTPServer, SimpleHTTPRequestHandler
import os
import sys

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
WEB_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "build", "web")


class CORSHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-cache")
        super().end_headers()


def main():
    os.chdir(WEB_DIR)
    server = HTTPServer(("localhost", PORT), CORSHandler)
    print(f"Serving Block Count at http://localhost:{PORT}")
    print("Press Ctrl+C to stop")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nServer stopped")


if __name__ == "__main__":
    main()
