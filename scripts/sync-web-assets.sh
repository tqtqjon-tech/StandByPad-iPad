#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source_ref="$(cat web-source-ref.txt)"
[[ "$source_ref" =~ ^[0-9a-f]{40}$ ]] || { echo 'Invalid source commit'; exit 1; }
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
git clone --quiet https://github.com/tqtqjon-tech/standbypad.git "$tmp_dir/source"
git -C "$tmp_dir/source" checkout --quiet "$source_ref"
mkdir -p WebAssets
git -C "$tmp_dir/source" archive "$source_ref" | tar -x -C WebAssets
python3 scripts/verify-assets.py WebAssets "$tmp_dir/source"
