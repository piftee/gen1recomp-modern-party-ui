#!/usr/bin/env python3
"""Check tracked repository files or a finished ZIP against reviewed asset grants.

Local imported files that are not tracked by Git are deliberately outside the
repository check. Run --zip on the actual release to check every shipped member.
This prevents accidental bundling; source/asset ownership still needs review.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path, PurePosixPath
import subprocess
import sys
import zipfile

PROHIBITED = {'.gb', '.gbc', '.gba', '.nds', '.3ds', '.nes', '.sfc', '.smc',
              '.z64', '.n64', '.v64', '.nsp', '.xci', '.iso', '.ips', '.bps',
              '.ups', '.zip', '.7z', '.rar', '.tar', '.gz', '.love', '.modpkg'}
MEDIA = {'.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp', '.tga', '.svg',
         '.wav', '.mp3', '.ogg', '.flac', '.mid', '.midi', '.mp4', '.webm',
         '.ttf', '.otf', '.woff', '.woff2', '.bin', '.dat', '.dll', '.so', '.dylib'}
GB_LOGO = bytes.fromhex(
    'ceed6666cc0d000b03730083000c000d0008111f8889000edccc6ee6ddddd999'
    'bbbb67636e0eecccdddc999fbbb9333e')

def inspect(name, data, approvals):
    p = PurePosixPath(name)
    if p.is_absolute() or '..' in p.parts or '\\' in name:
        return 'unsafe package path'
    lower = name.lower()
    if p.suffix.lower() in PROHIBITED:
        return 'ROM, patch, or nested archive cannot be distributed'
    if any(part in {'baseroms', 'mod-derived', 'screenshots'} for part in (x.lower() for x in p.parts)):
        return 'local imports, derived output, and game screenshots cannot be distributed'
    if any(x in lower for x in ('assets/generated/', 'data/generated/')):
        return 'generated import data cannot be distributed'
    if data[0x104:0x134] == GB_LOGO or data.startswith(b'NES\x1a'):
        return 'console ROM header, regardless of filename'
    if data[:4] in (b'PK\x03\x04', b'PK\x05\x06'):
        return 'embedded archive, regardless of filename'
    try:
        data.decode('utf-8')
        binary = b'\0' in data
    except UnicodeDecodeError:
        binary = True
    embedded = re.search(rb'data:(?:image|audio|video|font)/', data, re.I)
    if binary or embedded or p.suffix.lower() in MEDIA or data.startswith(b'\x89PNG\r\n\x1a\n'):
        grant = approvals.get(name)
        if not grant:
            return 'binary/media file has no reviewed source and licence'
        if not all(grant.get(k) for k in ('sha256', 'license', 'source', 'notice')):
            return 'asset approval must name its hash, licence, source, and notice'
        if hashlib.sha256(data).hexdigest() != grant['sha256']:
            return 'asset changed since its source and licence were reviewed'
    return None

def check(entries, policy):
    problems, names = [], set()
    for name, data in entries:
        if name in names:
            problems.append((name, 'duplicate archive path'))
        names.add(name)
        problem = inspect(name, data, policy['assets'])
        if problem:
            problems.append((name, problem))
    for notice in policy.get('required_notices', ['LICENSE']):
        if notice not in names:
            problems.append((notice, 'required distribution notice must be included'))
    for name, grant in policy['assets'].items():
        if name in names and grant['notice'] not in names:
            problems.append((name, 'required attribution/licence notice is missing'))
    return problems, len(names)

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--root', type=Path, default=Path('.'))
    ap.add_argument('--zip', type=Path)
    args = ap.parse_args()
    root = args.root.resolve()
    policy = json.loads((root/'.github/distribution-assets.json').read_text())
    if policy.get('version') != 1 or not isinstance(policy.get('assets'), dict):
        raise SystemExit('Invalid distribution asset policy')
    if args.zip:
        with zipfile.ZipFile(args.zip) as archive:
            entries = ((i.filename, archive.read(i)) for i in archive.infolist() if not i.is_dir())
            problems, count = check(entries, policy)
    else:
        tracked = subprocess.check_output(['git', '-C', str(root), 'ls-files', '-z']).split(b'\0')
        entries = []
        for raw in tracked:
            if not raw: continue
            name = raw.decode('utf-8')
            file = root/name
            if not file.exists(): continue  # staged/deleted file in a working-tree check
            if file.is_symlink():
                raise SystemExit('Tracked symlinks are not allowed: '+name)
            entries.append((name, file.read_bytes()))
        problems, count = check(entries, policy)
    for name, why in problems:
        print(f'FAIL {name}: {why}')
    if not problems:
        print(f'PASS: {count} files; every bundled binary/media file matches its reviewed grant.')
    return int(bool(problems))

if __name__ == '__main__':
    sys.exit(main())
