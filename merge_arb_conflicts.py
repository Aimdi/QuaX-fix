#!/usr/bin/env python3
"""Resolves conflicted ARB files during a merge by taking the union of keys.

Every feature branch adds its own strings to all 29 locale files, so git sees a
conflict in each one even though the changes never overlap. Both sides are read
from the index (:2 = ours, :3 = theirs) and merged, preferring "theirs" for keys
only that side has. l10n.py re-sorts and re-adds metadata afterwards.
"""
import json
import subprocess
import sys
from pathlib import Path


def side(stage: int, path: str):
    result = subprocess.run(['git', 'show', f':{stage}:{path}'], capture_output=True, text=True)
    if result.returncode != 0:
        return None
    return json.loads(result.stdout)


def main() -> int:
    conflicted = subprocess.run(
        ['git', 'diff', '--name-only', '--diff-filter=U'], capture_output=True, text=True, check=True
    ).stdout.split()

    arbs = [p for p in conflicted if p.startswith('lib/l10n/') and p.endswith('.arb')]
    if not arbs:
        print('no conflicted ARB files')
        return 0

    for path in arbs:
        ours = side(2, path)
        theirs = side(3, path)
        if ours is None or theirs is None:
            print(f'skipping {path}: missing a side')
            continue

        merged = dict(ours)
        merged.update(theirs)
        for key in list(merged):
            if key.startswith('@'):
                del merged[key]

        Path(path).write_text(json.dumps(merged, ensure_ascii=False, indent=2) + '\n')
        subprocess.run(['git', 'add', path], check=True)

    print(f'merged {len(arbs)} ARB files')
    return 0


if __name__ == '__main__':
    sys.exit(main())
