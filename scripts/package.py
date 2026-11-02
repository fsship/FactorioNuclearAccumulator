#!/usr/bin/env python3
"""Build both Factorio targets from one source tree, without editing the source manifest."""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

REPO = Path(__file__).resolve().parent.parent
TARGETS = json.loads((Path(__file__).parent / 'build-targets.json').read_text())


def manifest_for(source: Path, target: str) -> dict:
    """Only target compatibility fields differ; the mod version comes from mod/info.json."""
    info = json.loads((source / 'info.json').read_text())
    info.update(TARGETS[target])
    return info


def build_package(source: Path, target: str, output: Path) -> Path:
    source = source.resolve()
    info = manifest_for(source, target)
    folder = f"{info['name']}_{info['version']}"
    output.mkdir(parents=True, exist_ok=True)
    artifact = output / (folder + '.zip')
    contents = {}
    for path in sorted(source.rglob('*')):
        if not path.is_file() or '__pycache__' in path.parts:
            continue
        relative = path.relative_to(source)
        if relative.parts[0] in {'tests', 'work'} or path.suffix in {'.pyc', '.pyo'}:
            continue
        contents[relative.as_posix()] = path.read_bytes()
    contents['info.json'] = (json.dumps(info, indent=2) + '\n').encode('utf-8')
    with zipfile.ZipFile(artifact, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        for name, content in sorted(contents.items()):
            entry = zipfile.ZipInfo(folder + '/' + name, (2026, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            entry.create_system = 3
            entry.external_attr = 0o100644 << 16
            archive.writestr(entry, content)
    with zipfile.ZipFile(artifact) as archive:
        assert archive.testzip() is None
        assert len(archive.namelist()) == len(contents)
        for name, content in contents.items():
            assert archive.read(folder + '/' + name) == content
    return artifact


def write_checksums(output: Path) -> None:
    lines = [f'{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(output).as_posix()}'
             for path in sorted(output.rglob('*.zip'))]
    (output / 'SHA256SUMS.txt').write_text('\n'.join(lines) + '\n')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=REPO / 'mod')
    parser.add_argument('--target', choices=[*TARGETS, 'all'], default='all')
    parser.add_argument('--output', type=Path, default=REPO / 'releases')
    args = parser.parse_args()
    targets = TARGETS if args.target == 'all' else [args.target]
    for target in targets:
        artifact = build_package(args.source, target, args.output / ('factorio-' + target))
        print(f'{hashlib.sha256(artifact.read_bytes()).hexdigest()}  {artifact}')
    write_checksums(args.output)


if __name__ == '__main__':
    main()
