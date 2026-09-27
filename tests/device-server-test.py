"""LAN preview must not expose repository files or normal backend configuration."""
import importlib.util
import threading
import unittest
import urllib.request
import urllib.error
from functools import partial
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('device_server', ROOT / 'scripts/serve-device-test.py')
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

class DeviceServerTest(unittest.TestCase):
    def test_allowlist(self):
        server = m.ThreadingHTTPServer(('127.0.0.1', 0), partial(m.DeviceHandler, directory=str(ROOT)))
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        base = f'http://127.0.0.1:{server.server_port}'
        try:
            for route in m.ALLOWED:
                with urllib.request.urlopen(base + route) as response:
                    self.assertEqual(response.status, 200, route)
            for route in ['/cloud-config.js?v=test', '/cloud-config.js?cache=old']:
                with urllib.request.urlopen(base + route) as response:
                    self.assertEqual(response.read(), m.fresh.FRESH_CONFIG)
            for route in ['/.git/config', '/work/', '/scripts/serve-fresh-test.py', '/sql/avatar-catalog-v2.0.5.sql', '/%2e%2e/.git/config', '/assets/', '/tests/']:
                with self.assertRaises(urllib.error.HTTPError) as error:
                    urllib.request.urlopen(base + route)
                self.assertEqual(error.exception.code, 404)
        finally:
            server.shutdown();server.server_close();thread.join()

if __name__ == '__main__':
    unittest.main()
