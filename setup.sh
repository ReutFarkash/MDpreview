#!/bin/bash
# setup.sh — create and configure the MDPreview vault.
#
# USAGE
#   bash setup.sh [--theme plain|bundled|vault] [--full] [--vault /path]
#
# PRESETS
#   (no flags)                  Plain Obsidian — no theme, no community plugins
#   --theme bundled             AnuPpuccin theme + Style Settings (bundled in this repo)
#   --theme bundled --full      AnuPpuccin + Dataview, Excalidraw, etc. (needs --vault or auto-detect)
#   --theme vault               Copy theme from your Obsidian vault + Style Settings only
#   --theme vault --full        Copy theme + all plugins from your vault
#   --vault /path/to/vault      Specify vault explicitly (used with --theme vault)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VAULT_DIR="$HOME/MDPreview"
OBSIDIAN_CONFIG="$HOME/Library/Application Support/obsidian/obsidian.json"

THEME="bundled"
FULL=false
VAULT_PATH=""

# ── Parse arguments ───────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --theme)   THEME="$2"; shift 2 ;;
        --full)    FULL=true; shift ;;
        --vault)   VAULT_PATH="$2"; THEME="vault"; shift 2 ;;
        *)         echo "Unknown option: $1"; exit 1 ;;
    esac
done

# ── Auto-detect source vault (for --theme vault or --full only) ──────────────
find_vault() {
    # Explicit --vault flag or SOURCE_VAULT env var take priority
    for v in "$VAULT_PATH" "${SOURCE_VAULT:-}"; do
        [[ -n "$v" && -d "$v/.obsidian" ]] && echo "$v" && return
    done
    # Auto-detect: scan standard Obsidian locations for any vault
    local icloud="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents"
    if [[ -d "$icloud" ]]; then
        while IFS= read -r d; do
            [[ -d "$d/.obsidian" ]] && echo "$d" && return
        done < <(find "$icloud" -maxdepth 1 -mindepth 1 -type d 2>/dev/null)
    fi
    for base in "$HOME/Obsidian" "$HOME/Documents/Obsidian"; do
        if [[ -d "$base" ]]; then
            while IFS= read -r d; do
                [[ -d "$d/.obsidian" ]] && echo "$d" && return
            done < <(find "$base" -maxdepth 1 -mindepth 1 -type d 2>/dev/null)
        fi
    done
}

# Only scan for a source vault when it's actually needed
if [[ "$THEME" == "vault" || "$FULL" == true ]]; then
    SOURCE_VAULT="$(find_vault || true)"
else
    SOURCE_VAULT=""
fi

# Validate
if [[ "$THEME" == "vault" && -z "$SOURCE_VAULT" ]]; then
    echo "Error: --theme vault requires a source vault. Use --vault /path/to/vault"
    exit 1
fi
if [[ "$FULL" == true && -z "$SOURCE_VAULT" ]]; then
    echo "Warning: --full needs a source vault for large plugins. Auto-detect found nothing."
    echo "         Use --vault /path/to/vault or set SOURCE_VAULT=/path"
    FULL=false
fi

echo "─────────────────────────────────────────────"
echo "  md-preview setup"
echo "  Theme:   $THEME"
echo "  Plugins: $( [[ $FULL == true ]] && echo 'full' || echo 'minimal' )"
[[ -n "$SOURCE_VAULT" ]] && echo "  Source:  $SOURCE_VAULT"
echo "─────────────────────────────────────────────"

# ── Create vault directory ───────────────────────────────────────────────────
echo ""
echo "Creating vault at $VAULT_DIR ..."
mkdir -p "$VAULT_DIR"
rm -rf "$VAULT_DIR/.obsidian"

# ── Install .obsidian config ─────────────────────────────────────────────────
case "$THEME" in

  plain)
    cp -r "$SCRIPT_DIR/vault-config/plain/.obsidian" "$VAULT_DIR/.obsidian"
    echo "✓ Plain Obsidian config installed"
    ;;

  bundled)
    cp -r "$SCRIPT_DIR/vault-config/bundled/.obsidian" "$VAULT_DIR/.obsidian"
    if [[ "$FULL" == true ]]; then
        echo "✓ Bundled AnuPpuccin config installed"
        echo "  Copying full plugin set from $SOURCE_VAULT ..."
        FULL_PLUGINS=("dataview" "obsidian-excalidraw-plugin" "obsidian-icon-shortcodes"
                      "templater-obsidian" "obsidian-auto-link-title" "url-into-selection")
        for plugin in "${FULL_PLUGINS[@]}"; do
            src="$SOURCE_VAULT/.obsidian/plugins/$plugin"
            if [[ -d "$src" ]]; then
                cp -r "$src" "$VAULT_DIR/.obsidian/plugins/$plugin"
                echo "    ✓ $plugin"
            else
                echo "    ⚠ $plugin not found in source vault — skipping"
            fi
        done
        cp "$SCRIPT_DIR/vault-config/plugins-full.json" \
           "$VAULT_DIR/.obsidian/community-plugins.json"
    else
        echo "✓ Bundled AnuPpuccin config installed (Style Settings only)"
    fi
    ;;

  vault)
    echo "  Copying full .obsidian from $SOURCE_VAULT ..."
    cp -r "$SOURCE_VAULT/.obsidian" "$VAULT_DIR/.obsidian"
    # Clean vault-specific files
    rm -f "$VAULT_DIR/.obsidian/workspace.json" \
          "$VAULT_DIR/.obsidian/daily-notes.json" \
          "$VAULT_DIR/.obsidian/templates.json"
    # Disable plugins that reference vault-specific paths
    python3 -c "
import json, os
p_path = '$VAULT_DIR/.obsidian/core-plugins.json'
if os.path.exists(p_path):
    p = json.load(open(p_path))
    for k in ('daily-notes', 'templates', 'sync', 'publish'):
        p[k] = False
    json.dump(p, open(p_path, 'w'), indent=2)
"
    if [[ "$FULL" == false ]]; then
        # Keep only style-settings from community plugins
        python3 -c "
import json, os
src = '$SOURCE_VAULT/.obsidian/community-plugins.json'
dst = '$VAULT_DIR/.obsidian/community-plugins.json'
if os.path.exists(src):
    plugins = json.load(open(src))
    keep = [p for p in plugins if p == 'obsidian-style-settings']
    json.dump(keep, open(dst, 'w'))
    # Remove plugin folders not in keep list
    import shutil
    plugin_dir = '$VAULT_DIR/.obsidian/plugins'
    if os.path.isdir(plugin_dir):
        for folder in os.listdir(plugin_dir):
            if folder not in keep:
                shutil.rmtree(os.path.join(plugin_dir, folder))
"
        echo "✓ Vault theme installed (Style Settings only)"
    else
        echo "✓ Vault theme + full plugin set installed"
    fi
    ;;

esac

# ── Write clean workspace.json ───────────────────────────────────────────────
mkdir -p "$VAULT_DIR/.obsidian"
cat > "$VAULT_DIR/.obsidian/workspace.json" <<'JSON'
{
  "main": {
    "id": "main-split",
    "type": "split",
    "children": [
      {
        "id": "main-tabs",
        "type": "tabs",
        "children": [
          { "id": "main-leaf", "type": "leaf", "state": { "type": "empty", "state": {} } }
        ]
      }
    ],
    "direction": "vertical"
  },
  "left": {
    "id": "left-split",
    "type": "split",
    "children": [
      {
        "id": "left-tabs",
        "type": "tabs",
        "children": [
          { "id": "file-explorer", "type": "leaf", "state": { "type": "file-explorer", "state": {} } }
        ]
      }
    ],
    "direction": "vertical",
    "width": 240,
    "collapsed": true
  },
  "right": {
    "id": "right-split",
    "type": "split",
    "children": [],
    "direction": "vertical",
    "width": 300,
    "collapsed": true
  },
  "active": "main-leaf",
  "lastOpenFiles": []
}
JSON

# ── Register vault in Obsidian's config ──────────────────────────────────────
echo ""
echo "Registering vault with Obsidian..."

if pgrep -x "Obsidian" &>/dev/null; then
    echo "  Obsidian is running — quitting to update vault registry..."
    osascript -e 'tell application "Obsidian" to quit'
    sleep 2
fi

python3 - "$VAULT_DIR" "$OBSIDIAN_CONFIG" <<'PYEOF'
import json, os, sys, time, secrets

vault_path, config_path = sys.argv[1], sys.argv[2]
config = {}
if os.path.exists(config_path):
    with open(config_path) as f:
        config = json.load(f)

vaults = config.setdefault("vaults", {})
for uid, v in vaults.items():
    if v.get("path") == vault_path:
        print(f"  Already registered as {uid}")
        sys.exit(0)

uid = secrets.token_hex(8)
vaults[uid] = {"path": vault_path, "ts": int(time.time() * 1000)}
with open(config_path, "w") as f:
    json.dump(config, f, separators=(",", ":"))
print(f"  ✓ Registered (id: {uid})")
PYEOF

# ── Launch Obsidian ──────────────────────────────────────────────────────────
echo "Launching Obsidian..."
open -a Obsidian
sleep 3
open "obsidian://open?vault=MDPreview"

# ── Offer to set as default .md opener ───────────────────────────────────────
SET_DEFAULT_BIN="$SCRIPT_DIR/set-default"

# If running from repo (no pre-compiled binary), try to compile on the fly
if [[ ! -f "$SET_DEFAULT_BIN" && -f "$SCRIPT_DIR/automator/set-default.swift" ]] \
    && command -v swiftc &>/dev/null; then
    echo ""
    echo "Compiling set-default helper..."
    swiftc -O -o "$SET_DEFAULT_BIN" "$SCRIPT_DIR/automator/set-default.swift" 2>/dev/null \
        || SET_DEFAULT_BIN=""
fi

if [[ -f "$SET_DEFAULT_BIN" ]]; then
    echo ""
    DIALOG_RESULT=$(osascript 2>/dev/null <<'APPLESCRIPT' || true
        tell application "System Events"
            set r to display dialog "Would you like MDPreview to open .md files by default?" ¬
                buttons {"Not Now", "Set as Default"} ¬
                default button "Set as Default" ¬
                with title "MDPreview"
            return button returned of r
        end tell
APPLESCRIPT
    )
    if [[ "$DIALOG_RESULT" == "Set as Default" ]]; then
        if "$SET_DEFAULT_BIN"; then
            echo "✓ MDPreview is now your default .md opener"
        else
            echo "  Could not set as default — try System Settings → Privacy & Security → Default Apps"
        fi
    else
        echo "  Skipped — set it later via System Settings → Privacy & Security → Default Apps"
    fi
fi

echo ""
echo "✓ Setup complete. If Obsidian asks to trust the vault, click Trust."
echo "  Run bash install.sh next to add the Finder Quick Action and app."
