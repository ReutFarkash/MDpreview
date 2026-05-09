#!/bin/bash
# Build MDPreview-Windows.zip for release upload.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT="$SCRIPT_DIR/MDPreview-Windows.zip"
WORK="$(mktemp -d)/MDPreview-Windows"

mkdir -p "$WORK"
cp "$SCRIPT_DIR/md-preview.ps1" \
   "$SCRIPT_DIR/setup.ps1" \
   "$SCRIPT_DIR/install.ps1" \
   "$SCRIPT_DIR/install.bat" \
   "$SCRIPT_DIR/setup-and-install.bat" \
   "$SCRIPT_DIR/set-default.ps1" \
   "$SCRIPT_DIR/set-default.bat" \
   "$SCRIPT_DIR/uninstall.ps1" \
   "$SCRIPT_DIR/uninstall.bat" \
   "$WORK/"
cp -r "$SCRIPT_DIR/vault-config" "$WORK/"

cd "$(dirname "$WORK")"
zip -r "$OUT" MDPreview-Windows/ --exclude "*.DS_Store"

echo "Built: $OUT ($(du -sh "$OUT" | cut -f1))"
