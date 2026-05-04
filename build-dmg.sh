#!/bin/bash
# build-dmg.sh — build a distributable MDPreview-<version>.dmg
#
# Usage: bash build-dmg.sh [version]
#   version  defaults to 1.0.0
#
# Output: MDPreview-<version>.dmg in the repo root.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION="${1:-1.0.0}"
OUT="$SCRIPT_DIR/MDPreview-${VERSION}.dmg"

STAGING="$(mktemp -d)"
APP="$STAGING/MDPreview.app"

cleanup() { rm -rf "$STAGING"; }
trap cleanup EXIT

# ── 1. Build self-contained MDPreview.app ────────────────────────────────────

echo "Building MDPreview.app..."
osacompile -o "$APP" "$SCRIPT_DIR/automator/MDPreview.applescript"

mkdir -p "$APP/Contents/Resources"
cp "$SCRIPT_DIR/md-preview.sh" "$APP/Contents/Resources/"
cp "$SCRIPT_DIR/setup.sh"      "$APP/Contents/Resources/"
cp -r "$SCRIPT_DIR/vault-config" "$APP/Contents/Resources/"

python3 - "$APP" << 'PYEOF'
import plistlib, sys

plist_path = sys.argv[1] + "/Contents/Info.plist"
with open(plist_path, "rb") as f:
    plist = plistlib.load(f)

plist["CFBundleIdentifier"] = "com.mdpreview.app"
plist["CFBundleDocumentTypes"] = [
    {
        "CFBundleTypeExtensions": ["md", "markdown", "mdown", "mkd", "mkdn"],
        "CFBundleTypeMIMETypes": ["text/markdown", "text/x-markdown"],
        "CFBundleTypeName": "Markdown Document",
        "CFBundleTypeRole": "Viewer",
        "LSItemContentTypes": ["net.daringfireball.markdown", "public.plain-text"],
        "LSHandlerRank": "Alternate",
    }
]

with open(plist_path, "wb") as f:
    plistlib.dump(plist, f)
PYEOF

echo "✓ App built"

# ── 2. Stage: app + /Applications symlink ────────────────────────────────────

ln -s /Applications "$STAGING/Applications"

# ── 3. Create DMG ────────────────────────────────────────────────────────────

echo "Creating $OUT ..."
hdiutil create \
    -volname "MDPreview" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    -o "$OUT"

echo ""
echo "✓ $OUT"
echo ""
echo "To distribute: attach the DMG, drag MDPreview.app to Applications."
echo "First run sets up ~/MDPreview automatically."
