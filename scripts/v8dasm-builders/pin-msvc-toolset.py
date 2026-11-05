#!/usr/bin/env python3
"""Pin the MSVC toolset used by V8's Windows build.

Usage: pin-msvc-toolset.py <v8_dir> <toolset_version>     e.g. 14.29

Why: V8 10.2 builds with its own (2022-era) clang, which cannot parse the
headers of the newest MSVC STL on the GitHub runners (14.4x uses
static_assert(false, ...) in templates, which needs clang >= 17).
build/toolchain/win/setup_toolchain.py always calls vcvarsall.bat without a
toolset version, so it picks the newest MSVC. This script makes it pass
-vcvars_ver=<toolset_version> so an older, compatible STL is used.

The edit is idempotent and only touches the separate build/ checkout, which
apply-patch's reset of the V8 repo does not undo.
"""

import sys
from pathlib import Path

MARKER = '# v8dasm: pinned MSVC toolset'


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__)
        return 1
    v8_dir, version = Path(sys.argv[1]), sys.argv[2]
    path = v8_dir / 'build' / 'toolchain' / 'win' / 'setup_toolchain.py'
    if not path.exists():
        print(f'[MSVC] ERROR: {path} not found')
        return 1

    with open(path, encoding='utf-8', newline='') as f:
        text = f.read()

    nl = '\r\n' if '\r\n' in text else '\n'
    lines = text.split(nl)
    # Drop any line added by a previous run so the version can change.
    lines = [l for l in lines if MARKER not in l]

    # Append after the Windows SDK version argument, i.e. last, so it does not
    # disturb the "store must come before the SDK version" ordering.
    anchor = "    args.append('10.0."
    idx = [i for i, l in enumerate(lines) if l.startswith(anchor)]
    if len(idx) != 1:
        print(f'[MSVC] ERROR: expected exactly one "{anchor.strip()}..." line '
              f'in {path}, found {len(idx)}; V8 build scripts changed?')
        return 1

    lines.insert(idx[0] + 1,
                 f"    args.append('-vcvars_ver={version}')  {MARKER}")
    with open(path, 'w', encoding='utf-8', newline='') as f:
        f.write(nl.join(lines))
    print(f'[MSVC] setup_toolchain.py now calls vcvarsall.bat with '
          f'-vcvars_ver={version}')
    return 0


if __name__ == '__main__':
    sys.exit(main())
