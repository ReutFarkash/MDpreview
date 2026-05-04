#!/bin/bash
# install.sh — install MDPreview.app and the Finder Quick Action.
# Run after setup.sh. Safe to re-run.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
: "${SERVICES_DIR:=$HOME/Library/Services}"
: "${APP_DEST:=/Applications/MDPreview.app}"
WORKFLOW_NAME="Open in MDPreview"
WORKFLOW_DIR="$SERVICES_DIR/${WORKFLOW_NAME}.workflow"

# ── 1. Compile MDPreview.app ─────────────────────────────────────────────────

echo "Building MDPreview.app..."
osacompile -o "$APP_DEST" "$SCRIPT_DIR/automator/MDPreview.applescript"

# Bundle scripts + vault-config so the app is self-contained (no path injection needed)
mkdir -p "$APP_DEST/Contents/Resources"
cp "$SCRIPT_DIR/md-preview.sh" "$APP_DEST/Contents/Resources/"
cp "$SCRIPT_DIR/setup.sh"      "$APP_DEST/Contents/Resources/"
cp -r "$SCRIPT_DIR/vault-config" "$APP_DEST/Contents/Resources/"

# Patch Info.plist: add bundle ID + explicit markdown document type declarations
python3 - "$APP_DEST" << 'PYEOF'
import plistlib, subprocess, sys

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

lsregister = ("/System/Library/Frameworks/CoreServices.framework/Versions/A"
              "/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister")
subprocess.run([lsregister, "-f", sys.argv[1]], check=False)
PYEOF

echo "✓ Installed to $APP_DEST"

# ── 2. Install Finder Quick Action ──────────────────────────────────────────

echo "Installing Quick Action '$WORKFLOW_NAME'..."
mkdir -p "$WORKFLOW_DIR/Contents"

# Info.plist
cat > "$WORKFLOW_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSServices</key>
    <array>
        <dict>
            <key>NSMenuItem</key>
            <dict>
                <key>default</key>
                <string>Open in MDPreview</string>
            </dict>
            <key>NSMessage</key>
            <string>runWorkflowAsService</string>
            <key>NSSendFileTypes</key>
            <array>
                <string>net.daringfireball.markdown</string>
                <string>public.plain-text</string>
                <string>public.text</string>
                <string>public.content</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
PLIST

# document.wflow — Automator "Run Shell Script" service
cat > "$WORKFLOW_DIR/Contents/document.wflow" <<'WFLOW'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>AMApplicationBuild</key>
    <string>523</string>
    <key>AMApplicationVersion</key>
    <string>2.10</string>
    <key>AMDocumentType</key>
    <string>Service</string>
    <key>AMVerboseLogging</key>
    <integer>0</integer>
    <key>actions</key>
    <array>
        <dict>
            <key>action</key>
            <dict>
                <key>AMAccepts</key>
                <dict>
                    <key>Container</key>
                    <string>List</string>
                    <key>Optional</key>
                    <true/>
                    <key>Types</key>
                    <array>
                        <string>com.apple.cocoa.path</string>
                    </array>
                </dict>
                <key>AMActionVersion</key>
                <string>2.0.3</string>
                <key>AMApplication</key>
                <array>
                    <string>Finder</string>
                </array>
                <key>AMParameterProperties</key>
                <dict>
                    <key>COMMAND_STRING</key>
                    <dict/>
                    <key>CheckedForUserDefaultShell</key>
                    <dict/>
                    <key>inputMethod</key>
                    <dict/>
                    <key>shell</key>
                    <dict/>
                    <key>source</key>
                    <dict/>
                </dict>
                <key>AMProvides</key>
                <dict>
                    <key>Container</key>
                    <string>List</string>
                    <key>Types</key>
                    <array>
                        <string>com.apple.cocoa.path</string>
                    </array>
                </dict>
                <key>ActionBundlePath</key>
                <string>/System/Library/Automator/Run Shell Script.action</string>
                <key>ActionName</key>
                <string>Run Shell Script</string>
                <key>ActionParameters</key>
                <dict>
                    <key>COMMAND_STRING</key>
                    <string>for f in "$@"
do
    open -a MDPreview "$f"
done</string>
                    <key>CheckedForUserDefaultShell</key>
                    <true/>
                    <key>inputMethod</key>
                    <integer>1</integer>
                    <key>shell</key>
                    <string>/bin/bash</string>
                    <key>source</key>
                    <string></string>
                </dict>
                <key>BundleIdentifier</key>
                <string>com.apple.RunShellScript</string>
                <key>CFBundleVersion</key>
                <string>2.0.3</string>
                <key>CanShowSelectedItemsWhenRun</key>
                <false/>
                <key>CanShowWhenRun</key>
                <true/>
                <key>Category</key>
                <array>
                    <string>AMCategoryUtilities</string>
                </array>
                <key>Class Name</key>
                <string>RunShellScriptAction</string>
                <key>InputUUID</key>
                <string>A1B2C3D4-E5F6-7890-ABCD-EF1234567890</string>
                <key>Keywords</key>
                <array>
                    <string>Shell</string>
                    <string>Script</string>
                </array>
                <key>OutputUUID</key>
                <string>B2C3D4E5-F6A7-8901-BCDE-F12345678901</string>
                <key>UUID</key>
                <string>C3D4E5F6-A7B8-9012-CDEF-123456789012</string>
                <key>UnlocalizedApplications</key>
                <array>
                    <string>Automator</string>
                </array>
                <key>arguments</key>
                <dict>
                    <key>0</key>
                    <dict>
                        <key>default value</key>
                        <integer>0</integer>
                        <key>name</key>
                        <string>inputMethod</string>
                        <key>required</key>
                        <string>0</string>
                        <key>type</key>
                        <string>0</string>
                        <key>uuid</key>
                        <string>0</string>
                    </dict>
                </dict>
                <key>isViewVisible</key>
                <true/>
                <key>location</key>
                <string>309.5:253.00</string>
                <key>nickname</key>
                <string>Run Shell Script</string>
                <key>overrideNickname</key>
                <false/>
            </dict>
        </dict>
    </array>
    <key>connectors</key>
    <dict/>
    <key>workflowMetaData</key>
    <dict>
        <key>inputTypeIdentifier</key>
        <string>com.apple.Automator.fileSystemObject</string>
        <key>outputTypeIdentifier</key>
        <string>com.apple.Automator.nothing</string>
        <key>presentationMode</key>
        <integer>11</integer>
        <key>processesInput</key>
        <false/>
        <key>serviceInputTypeIdentifier</key>
        <string>com.apple.Automator.fileSystemObject</string>
        <key>serviceOutputTypeIdentifier</key>
        <string>com.apple.Automator.nothing</string>
        <key>serviceProcessesInput</key>
        <false/>
        <key>useAutomaticInputType</key>
        <false/>
        <key>workflowTypeIdentifier</key>
        <string>com.apple.Automator.servicesMenu</string>
    </dict>
</dict>
</plist>
WFLOW

echo "✓ Quick Action installed to $WORKFLOW_DIR"

# ── 3. Reload services ───────────────────────────────────────────────────────

/System/Library/CoreServices/pbs -update 2>/dev/null || true
echo ""
echo "✓ Done. Quick Action will appear in Finder right-click → Quick Actions."
echo ""
echo "TO SET AS DEFAULT APP FOR .md FILES:"
echo "  1. Right-click any .md file in Finder → Get Info"
echo "  2. Under 'Open With', select MDPreview"
echo "  3. Click 'Change All...'"
echo ""
echo "OR from terminal:"
echo "  duti -s com.mdpreview.app net.daringfireball.markdown all"
echo "  (install duti first: brew install duti)"
