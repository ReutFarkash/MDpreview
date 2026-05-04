#!/bin/bash
# Open any markdown file in Obsidian via the MDPreview vault.
# Symlinks are kept — use `ls ~/MDPreview/` to see history.

set -euo pipefail

VAULT_DIR="$HOME/MDPreview"
VAULT_NAME="MDPreview"

if [[ $# -eq 0 ]]; then
    echo "Usage: md-preview <file.md>" >&2
    exit 1
fi

# Resolve absolute path without requiring realpath
FILE="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"

if [[ ! -f "$FILE" ]]; then
    echo "File not found: $FILE" >&2
    exit 1
fi

FILENAME="$(basename "$FILE")"

mkdir -p "$VAULT_DIR"
ln -sf "$FILE" "$VAULT_DIR/$FILENAME"

ENCODED=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1]))" "$FILENAME")

# Check if this file is already in reading mode in Obsidian's workspace.
# Cmd+E is a toggle — only send it when NOT already in reading mode.
ALREADY_READING=$(python3 - "$VAULT_DIR/.obsidian/workspace.json" "$FILENAME" <<'PYEOF'
import json, sys

ws_path, target = sys.argv[1], sys.argv[2]

def find_mode(obj):
    if isinstance(obj, dict):
        state = obj.get("state", {})
        if isinstance(state, dict):
            inner = state.get("state", {})
            if isinstance(inner, dict) and inner.get("file") == target:
                return inner.get("mode", "source")
        for v in obj.values():
            r = find_mode(v)
            if r is not None:
                return r
    elif isinstance(obj, list):
        for item in obj:
            r = find_mode(item)
            if r is not None:
                return r
    return None

try:
    ws = json.load(open(ws_path))
    mode = find_mode(ws)
    print("yes" if mode == "preview" else "no")
except Exception:
    print("no")
PYEOF
)

open "obsidian://open?vault=${VAULT_NAME}&file=${ENCODED}"

if [[ "$ALREADY_READING" == "no" ]]; then
    osascript -e '
tell application "Obsidian" to activate
-- Wait until Obsidian is frontmost (handles cold start)
set attempts to 0
repeat
    delay 0.3
    set attempts to attempts + 1
    try
        if frontmost of application "Obsidian" then exit repeat
    end try
    if attempts > 20 then exit repeat
end repeat
delay 0.5
tell application "System Events"
    tell process "Obsidian"
        keystroke "e" using command down
    end tell
end tell
' 2>/dev/null || true
fi
