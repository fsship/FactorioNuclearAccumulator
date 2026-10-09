#!/usr/bin/env python3
"""Build deterministic install ZIPs; tests and engine logs stay in the source repository."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument('source', type=Path, help='Mod source directory containing info.json')
parser.add_argument('--output', type=Path, default=Path('releases'))
args = parser.parse_args()
source = args.source.resolve()
info = json.loads((source / 'info.json').read_text())
folder = f"{info['name']}_{info['version']}"
args.output.mkdir(parents=True, exist_ok=True)
artifact = args.output / (folder + '.zip')
files = [p for p in source.rglob('*') if p.is_file()
         and p.relative_to(source).parts[0] != 'tests'
         and '__pycache__' not in p.parts]
with zipfile.ZipFile(artifact, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for path in sorted(files):
        entry = zipfile.ZipInfo(folder + '/' + path.relative_to(source).as_posix(), (2026, 1, 1, 0, 0, 0))
        entry.compress_type = zipfile.ZIP_DEFLATED
        entry.external_attr = 0o100644 << 16
        archive.writestr(entry, path.read_bytes())
with zipfile.ZipFile(artifact) as archive:
    assert archive.testzip() is None
    for path in files:
        assert archive.read(folder + '/' + path.relative_to(source).as_posix()) == path.read_bytes()
print(f"{hashlib.sha256(artifact.read_bytes()).hexdigest()}  {artifact} ({len(files)} files)")
