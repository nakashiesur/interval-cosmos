import importlib.util
import tempfile
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('builder', ROOT / 'scripts/build-device-test-site.py')
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)

class BuildTest(unittest.TestCase):
    def test_export_isolated_and_complete(self):
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / 'site'
            manifest = builder.build(output)
            actual = {str(p.relative_to(output)) for p in output.rglob('*') if p.is_file()}
            self.assertEqual(actual, set(manifest) | {'_headers'})
            self.assertEqual((output/'cloud-config.js').read_bytes(), builder.device.fresh.FRESH_CONFIG)
            self.assertIn('sb_publishable_', (output/'cloud-config.js').read_text())
            self.assertNotEqual((output/'cloud-config.js').read_bytes(), (ROOT/'cloud-config.js').read_bytes())
            for name in manifest:
                self.assertFalse(name.startswith(('.git/', 'work/', 'sql/', 'scripts/', 'tests/')))
                if name != 'cloud-config.js':
                    self.assertEqual((output/name).read_bytes(), (ROOT/name).read_bytes())
            with self.assertRaises(FileExistsError):
                builder.build(output)

if __name__ == '__main__':
    unittest.main()
