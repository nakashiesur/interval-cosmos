#!/usr/bin/env python3
"""Serve the app against the dedicated test project without editing cloud-config.js."""
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FRESH_CONFIG = b"""window.INTERVAL_COSMOS_CLOUD = {
  supabaseUrl: 'https://yaqeeyhajnpwqvdjondk.supabase.co',
  supabaseAnonKey: 'sb_publishable_fVjvKHTikP_GEMiukEXqFw_oziY4vET',
  rankingsTable: 'rankings',
  profilesTable: 'profiles'
};
"""

class FreshHandler(SimpleHTTPRequestHandler):
    def send_head(self):
        from io import BytesIO
        from urllib.parse import urlsplit
        if urlsplit(self.path).path == '/cloud-config.js':
            self.send_response(200)
            self.send_header('Content-Type', 'application/javascript; charset=utf-8')
            self.send_header('Cache-Control', 'no-store')
            self.send_header('Content-Length', str(len(FRESH_CONFIG)))
            self.end_headers()
            return BytesIO(FRESH_CONFIG)
        return super().send_head()

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=8876)
    args = parser.parse_args()
    server = ThreadingHTTPServer(('127.0.0.1', args.port), partial(FreshHandler, directory=str(ROOT)))
    print(f'Fresh test server: http://127.0.0.1:{server.server_port}', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
