"""Verify fresh-server routing without opening any external service."""
import importlib.util
import threading
import unittest
import urllib.request
from functools import partial
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('fresh_server', ROOT / 'scripts/serve-fresh-test.py')
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class FreshServerTest(unittest.TestCase):
    def test_config_isolated_and_assets_shared(self):
        original = (ROOT / 'cloud-config.js').read_bytes()
        server = module.ThreadingHTTPServer(('127.0.0.1', 0), partial(module.FreshHandler, directory=str(ROOT)))
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        base = f'http://127.0.0.1:{server.server_port}'
        try:
            with urllib.request.urlopen(base + '/cloud-config.js?v=probe') as response:
                self.assertEqual(response.read(), module.FRESH_CONFIG)
                self.assertEqual(response.headers['Cache-Control'], 'no-store')
            with urllib.request.urlopen(base + '/index.html') as response:
                self.assertEqual(response.read(), (ROOT / 'index.html').read_bytes())
            self.assertEqual((ROOT / 'cloud-config.js').read_bytes(), original)
        finally:
            server.shutdown()
            server.server_close()
            thread.join()
        self.assertEqual((ROOT / 'cloud-config.js').read_bytes(), original)

if __name__ == '__main__':
    unittest.main()
