#!/usr/bin/env python3
"""Export a fresh, app-only staging directory. Does not deploy or modify any DB."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location('device_server', ROOT / 'scripts/serve-device-test.py')
device = importlib.util.module_from_spec(spec)
spec.loader.exec_module(device)

def build(destination):
    destination = Path(destination).resolve()
    # Refuse existing destinations rather than risk stale or unrelated files.
    destination.mkdir(parents=True, exist_ok=False)
    entries = {}
    for route in sorted(device.ALLOWED - {'/'}):
        relative = route.lstrip('/')
        source = (ROOT / relative).resolve()
        if not source.is_relative_to(ROOT) or not source.is_file():
            raise ValueError(f'Invalid asset: {relative}')
        payload = device.fresh.FRESH_CONFIG if relative == 'cloud-config.js' else source.read_bytes()
        target = destination / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(payload)
        entries[relative] = hashlib.sha256(payload).hexdigest()
    # Common static-host headers: entry point and SW must be revalidated.
    (destination / '_headers').write_text('/index.html\n  Cache-Control: no-cache\n/sw.js\n  Cache-Control: no-cache\n/cloud-config.js\n  Cache-Control: no-store\n')
    return entries

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('destination', help='New directory outside the source tree recommended')
    args = parser.parse_args()
    entries = build(args.destination)
    print(json.dumps({'directory': str(Path(args.destination).resolve()), 'assets': len(entries), 'backend': 'Fresh Build Test', 'deployed': False}))
