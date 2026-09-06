#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Some upgraded Command Line Tools retain Swift 5.10 private manifest
# interfaces beside Swift 6 public interfaces. Overlay only those stale files.
MANIFEST_DIR="$(xcode-select -p)/usr/lib/swift/pm/ManifestAPI"
mkdir -p "$ROOT_DIR/.build"
OVERLAY="$ROOT_DIR/.build/manifest-overlay.json"
python3 - "$MANIFEST_DIR" "$OVERLAY" <<'PY'
import json, pathlib, sys
base, output = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
roots = []
for private in base.glob('*.swiftmodule/*.private.swiftinterface'):
    public = private.with_name(private.name.replace('.private.swiftinterface', '.swiftinterface'))
    if public.exists() and public.stat().st_mtime > private.stat().st_mtime:
        roots.append({'type': 'file', 'name': str(private), 'external-contents': str(public)})
legacy = base.parents[3] / 'include/swift/module.modulemap'
modern = legacy.with_name('bridging.modulemap')
if legacy.exists() and modern.exists() and 'module SwiftBridging' in legacy.read_text():
    empty = output.with_name('empty.modulemap')
    empty.write_text('// Duplicate legacy module map hidden by project-local overlay.\n')
    roots.append({'type': 'file', 'name': str(legacy), 'external-contents': str(empty)})
output.write_text(json.dumps({'version': 0, 'roots': roots}))
PY
COMMAND="$1"
shift
exec swift "$COMMAND" -Xswiftc -vfsoverlay -Xswiftc "$OVERLAY" -Xcc -ivfsoverlay -Xcc "$OVERLAY" -Xbuild-tools-swiftc -vfsoverlay -Xbuild-tools-swiftc "$OVERLAY" -Xbuild-tools-swiftc -module-cache-path -Xbuild-tools-swiftc "$ROOT_DIR/.build/ManifestModuleCache" "$@"
