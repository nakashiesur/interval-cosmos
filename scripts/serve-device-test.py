#!/usr/bin/env python3
"""Serve only app assets and dedicated test config for same-Wi-Fi device checks."""
import argparse
import importlib.util
import re
from functools import partial
from http.server import ThreadingHTTPServer
from pathlib import Path
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('fresh_server', ROOT / 'scripts/serve-fresh-test.py')
fresh = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fresh)
asset_section = (ROOT / 'sw.js').read_text().split('const ASSETS = [', 1)[1].split('];', 1)[0]
ALLOWED = {'/' + name.removeprefix('./') for name in re.findall(r"'([^']+)'", asset_section)}
ALLOWED.update({'/', '/index.html', '/sw.js', '/cloud-config.js'})

class DeviceHandler(fresh.FreshHandler):
    def send_head(self):
        route = unquote(urlsplit(self.path).path)
        target = (ROOT / route.lstrip('/')).resolve()
        if route not in ALLOWED or not target.is_relative_to(ROOT):
            self.send_error(404)
            return None
        return super().send_head()

    def list_directory(self, path):
        self.send_error(404)
        return None

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--host', default='127.0.0.1')
    parser.add_argument('--port', type=int, default=8896)
    args = parser.parse_args()
    server = ThreadingHTTPServer((args.host, args.port), partial(DeviceHandler, directory=str(ROOT)))
    print(f'Device test: http://{args.host}:{server.server_port} (dedicated test backend; app assets only)', flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
