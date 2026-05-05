#!/bin/bash
# build-dmg.sh — build a signed, notarized MDPreview-<version>.dmg
#
# Usage: bash build-dmg.sh [version]
#   version  defaults to 1.0.0
#
# Requires:
#   - Developer ID Application cert in Keychain
#   - notarytool keychain profile named "mdpreview-notary"
#     (one-time setup: xcrun notarytool store-credentials "mdpreview-notary"
#      --apple-id <email> --team-id 59SWGJDWG4 --password <app-specific-pw>)
#
# Output: MDPreview-<version>.dmg in the repo root.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION="${1:-1.0.0}"
SKIP_NOTARIZE="${2:-}"   # pass "skip" as second arg to build+sign without notarizing
OUT="$SCRIPT_DIR/MDPreview-${VERSION}.dmg"

SIGN_ID="Developer ID Application: Reut Farkash (59SWGJDWG4)"
NOTARY_PROFILE="mdpreview-notary"

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

# ── 2. Sign the app (hardened runtime required for notarization) ──────────────

echo "Signing MDPreview.app..."
codesign --deep --force --options runtime \
    --entitlements "$SCRIPT_DIR/entitlements.plist" \
    --sign "$SIGN_ID" \
    "$APP"
echo "✓ Signed"

# ── 3. Stage: app + /Applications symlink ────────────────────────────────────

ln -s /Applications "$STAGING/Applications"

# ── 4. Create DMG ────────────────────────────────────────────────────────────

echo "Creating $OUT ..."
hdiutil create \
    -volname "MDPreview" \
    -srcfolder "$STAGING" \
    -ov -format UDZO \
    -o "$OUT"
echo "✓ DMG created"

# ── 5. Sign the DMG ───────────────────────────────────────────────────────────

echo "Signing DMG..."
codesign --sign "$SIGN_ID" "$OUT"
echo "✓ DMG signed"

if [[ "$SKIP_NOTARIZE" == "skip" ]]; then
    echo ""
    echo "✓ $OUT (signed, notarization skipped)"
    echo "Verify with:"
    echo "  hdiutil attach $OUT"
    echo "  codesign --verify --deep --strict --verbose=4 \"/Volumes/MDPreview/MDPreview.app\""
    echo "  spctl --assess --type exec \"/Volumes/MDPreview/MDPreview.app\""
    exit 0
fi

# ── 6. Notarize ───────────────────────────────────────────────────────────────

echo "Submitting to Apple notarization (this takes ~1-2 min)..."
xcrun notarytool submit "$OUT" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait
echo "✓ Notarized"

# ── 7. Staple ─────────────────────────────────────────────────────────────────

echo "Stapling notarization ticket..."
xcrun stapler staple "$OUT"

cp "$OUT" "$SCRIPT_DIR/MDPreview.dmg"

echo ""
echo "✓ $OUT (signed + notarized)"
echo "✓ MDPreview.dmg (latest alias — upload both as release assets)"
echo ""
echo "To distribute: attach the DMG, drag MDPreview.app to Applications."
echo "First run sets up ~/MDPreview automatically."
