#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
mkdir -p exports
"$GODOT_BIN" --headless --path . --export-debug Android exports/CrownAndAshes-v0.3.1-android.apk
python3 tools/package_android.py
