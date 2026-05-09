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

# Remove osacompile's asset catalog — it embeds the generic AppleScript icon
# and macOS resolves it before CFBundleIconFile, overriding our .icns.
rm -f "$APP/Contents/Resources/Assets.car"

# ── 1a. Generate app icon ─────────────────────────────────────────────────────

echo "Generating app icon..."
ICON_TMP="$(mktemp -d)"
/Users/reut/Code/claude/.venv/bin/python3 - "$ICON_TMP" << 'PYEOF'
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

out_dir = Path(sys.argv[1])
iconset = out_dir / "MDPreview.iconset"
iconset.mkdir()

# (logical_size, scale, actual_pixels)
entries = [
    (16, 1, 16),   (16, 2, 32),
    (32, 1, 32),   (32, 2, 64),
    (128, 1, 128), (128, 2, 256),
    (256, 1, 256), (256, 2, 512),
    (512, 1, 512), (512, 2, 1024),
]

ROSE     = "#D4839A"
SAGE     = "#7DC490"
LAVENDER = "#A898D4"
BG       = "#FAF8F5"
INK      = "#2C1A10"

def make_icon(pixels):
    r = int(pixels * 0.18)
    stripe_h = int(pixels * 0.28)
    sw = pixels // 3

    # Rounded-rect mask
    mask = Image.new("L", (pixels, pixels), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, pixels - 1, pixels - 1], radius=r, fill=255)

    # Background layer: cream fill + three color stripes across the top
    bg = Image.new("RGBA", (pixels, pixels), BG)
    d = ImageDraw.Draw(bg)
    d.rectangle([0,        0, sw,      stripe_h], fill=ROSE)
    d.rectangle([sw,       0, sw * 2,  stripe_h], fill=SAGE)
    d.rectangle([sw * 2,   0, pixels,  stripe_h], fill=LAVENDER)

    # Clip to rounded rect
    result = Image.new("RGBA", (pixels, pixels), (0, 0, 0, 0))
    result.paste(bg, mask=mask)

    # Draw "M↓" in the lower portion
    font_size = int(pixels * 0.33)
    try:
        font = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", font_size)
    except Exception:
        font = ImageFont.load_default()

    draw = ImageDraw.Draw(result)
    text = "M↓"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    lower_top = stripe_h
    lower_h   = pixels - stripe_h
    x = (pixels - tw) / 2 - bbox[0]
    y = lower_top + (lower_h - th) / 2 - bbox[1]
    draw.text((x, y), text, font=font, fill=INK)

    return result

for (logical, scale, pixels) in entries:
    name = f"icon_{logical}x{logical}.png" if scale == 1 else f"icon_{logical}x{logical}@2x.png"
    make_icon(pixels).save(iconset / name)

print(f"✓ Iconset written to {iconset}")
PYEOF

iconutil --convert icns "$ICON_TMP/MDPreview.iconset" -o "$APP/Contents/Resources/MDPreviewIcon.icns"
rm -rf "$ICON_TMP"
echo "✓ Icon generated"

python3 - "$APP" << 'PYEOF'
import plistlib, sys

plist_path = sys.argv[1] + "/Contents/Info.plist"
with open(plist_path, "rb") as f:
    plist = plistlib.load(f)

plist["CFBundleIdentifier"] = "com.mdpreview.app"
plist["CFBundleIconFile"] = "MDPreviewIcon"
plist["CFBundleDocumentTypes"] = [
    {
        "CFBundleTypeExtensions": ["md", "markdown", "mdown", "mkd", "mkdn"],
        "CFBundleTypeMIMETypes": ["text/markdown", "text/x-markdown"],
        "CFBundleTypeName": "Markdown Document",
        "CFBundleTypeRole": "Viewer",
        "LSItemContentTypes": ["net.daringfireball.markdown", "public.plain-text"],
        "LSHandlerRank": "Owner",
    }
]

with open(plist_path, "wb") as f:
    plistlib.dump(plist, f)
PYEOF

echo "✓ App built"

# ── 1b. Compile Swift helper ──────────────────────────────────────────────────

echo "Compiling set-default helper..."
swiftc -O -o "$APP/Contents/Resources/set-default" \
    "$SCRIPT_DIR/automator/set-default.swift"
echo "✓ Helper compiled"

# ── 2. Sign the app (hardened runtime required for notarization) ──────────────

echo "Signing MDPreview.app..."
# Sign the helper binary explicitly — --deep does not traverse loose executables in Resources/
codesign --force --options runtime \
    --sign "$SIGN_ID" \
    "$APP/Contents/Resources/set-default"
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
