"""Isolated real-app network-failure fixture, dedicated test DB only."""
import importlib.util
from functools import partial
from io import BytesIO
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('fresh_server', ROOT / 'scripts/serve-fresh-test.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class Handler(module.FreshHandler):
    def send_head(self):
        if urlsplit(self.path).path == '/tests/offline-app/':
            html = (ROOT / 'index.html').read_text()
            html = html.replace('<head>', '<head><base href="/">')
            html = html.replace('</body>', '<script src="/tests/offline-app/controls.js?v=2"></script></body>')
            body = html.encode()
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Content-Length', str(len(body)))
            self.send_header('Cache-Control', 'no-store')
            self.end_headers()
            return BytesIO(body)
        return super().send_head()

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', type=int, default=8877)
    args = parser.parse_args()
    server = module.ThreadingHTTPServer(('127.0.0.1',args.port),partial(Handler,directory=str(ROOT)))
    print(f'Offline app fixture: http://127.0.0.1:{args.port}/tests/offline-app/',flush=True)
    server.serve_forever()
