#!/bin/bash
# test.sh — test suite for md-preview
#
# Tests run with a temporary HOME to avoid touching your real Obsidian setup.
# Obsidian is never launched. All assertions are on-disk artifacts.
#
# Usage:
#   bash test.sh              # run all tests
#   bash test.sh --filter setup  # run only tests matching a pattern
#   bash test.sh --verbose    # show pass output too

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FILTER=""
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --filter)  FILTER="$2"; shift 2 ;;
        --verbose) VERBOSE=true; shift ;;
        *) echo "Unknown flag: $1"; exit 1 ;;
    esac
done

# ── Test harness ──────────────────────────────────────────────────────────────

PASS=0
FAIL=0
SKIP=0
declare -a FAILURE_NAMES=()
declare -a FAILURE_OUTPUTS=()

run_test() {
    local name="$1"
    local fn="$2"
    if [[ -n "$FILTER" && "$name" != *"$FILTER"* ]]; then
        (( SKIP++ )) || true
        return
    fi
    local output
    if output=$("$fn" 2>&1); then
        (( PASS++ )) || true
        $VERBOSE && echo "  ✓ $name" || true
    else
        (( FAIL++ )) || true
        FAILURE_NAMES+=("$name")
        FAILURE_OUTPUTS+=("$output")
        echo "  ✗ $name"
        echo "$output" | head -5 | sed 's/^/      /'
    fi
}

assert_file()    { [[ -f "$1" ]] || { echo "Missing file: $1"; return 1; }; }
assert_dir()     { [[ -d "$1" ]] || { echo "Missing dir: $1"; return 1; }; }
assert_contains(){ grep -qF "$2" "$1" || { echo "Expected '$2' in $1"; return 1; }; }
assert_absent()  { if grep -qF "$2" "$1" 2>/dev/null; then echo "Found '$2' in $1 (should be absent)"; return 1; fi; }

# ── Shared temp environment ───────────────────────────────────────────────────

TEST_HOME="$(mktemp -d /tmp/mdpreview-test-XXXXXX)"
trap 'rm -rf "$TEST_HOME"' EXIT

VAULT_DIR="$TEST_HOME/MDPreview"
OBSIDIAN_JSON="$TEST_HOME/Library/Application Support/obsidian/obsidian.json"

stub_obsidian_config() {
    mkdir -p "$(dirname "$OBSIDIAN_JSON")"
    echo '{}' > "$OBSIDIAN_JSON"
}

# Run setup.sh with HOME=TEST_HOME, stripping Obsidian launch lines.
# Uses a temp file so SCRIPT_DIR (computed from $0) resolves correctly.
setup_with_args() {
    stub_obsidian_config
    local tmp
    tmp=$(mktemp /tmp/mdpreview_setup_XXXXXX.sh)
    # Inject the real SCRIPT_DIR so the patched script finds vault-config/
    echo "SCRIPT_DIR=\"$SCRIPT_DIR\"" > "$tmp"
    sed '
        /^SCRIPT_DIR=/d
        /^if pgrep -x "Obsidian"/,/^fi$/d
        /python3 - "\$VAULT_DIR" "\$OBSIDIAN_CONFIG"/,/^PYEOF$/d
        /^echo "Launching Obsidian/d
        /^open -a Obsidian/d
        /^sleep 3/d
        /^open "obsidian:\/\//d
        /^echo "✓ Setup complete/d
        /^echo "  Run bash install/d
    ' "$SCRIPT_DIR/setup.sh" >> "$tmp"
    HOME="$TEST_HOME" bash "$tmp" "$@"
    rm -f "$tmp"
}

# Run md-preview.sh with HOME=TEST_HOME, stripping Obsidian open+keystroke lines.
run_md_preview() {
    local tmp
    tmp=$(mktemp /tmp/mdpreview_preview_XXXXXX.sh)
    sed '
        /^open "obsidian:\/\//d
        /^if \[\[ "\$ALREADY_READING" == "no" \]\]/,/^fi$/d
    ' "$SCRIPT_DIR/md-preview.sh" > "$tmp"
    HOME="$TEST_HOME" bash "$tmp" "$@"
    rm -f "$tmp"
}

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 1 — setup.sh: plain theme
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "── setup.sh: plain ─────────────────────────────────────────────────────"

t_plain_creates_vault() {
    setup_with_args --theme plain
    assert_dir "$VAULT_DIR"
}

t_plain_installs_obsidian() {
    setup_with_args --theme plain
    assert_dir "$VAULT_DIR/.obsidian"
}

t_plain_writes_workspace() {
    setup_with_args --theme plain
    assert_file "$VAULT_DIR/.obsidian/workspace.json"
}

t_plain_workspace_has_main_leaf() {
    setup_with_args --theme plain
    assert_contains "$VAULT_DIR/.obsidian/workspace.json" "main-leaf"
}

t_plain_empty_community_plugins() {
    setup_with_args --theme plain
    assert_file "$VAULT_DIR/.obsidian/community-plugins.json"
    local content
    content="$(cat "$VAULT_DIR/.obsidian/community-plugins.json")"
    [[ "$content" == "[]" ]] || { echo "Expected [] got: $content"; return 1; }
}

t_plain_no_themes_dir() {
    setup_with_args --theme plain
    [[ ! -d "$VAULT_DIR/.obsidian/themes" ]] || { echo "Unexpected themes dir in plain mode"; return 1; }
}

t_plain_safe_to_rerun() {
    setup_with_args --theme plain
    setup_with_args --theme plain
    assert_dir "$VAULT_DIR/.obsidian"
}

run_test "plain: creates vault dir"            t_plain_creates_vault
run_test "plain: installs .obsidian"           t_plain_installs_obsidian
run_test "plain: writes workspace.json"        t_plain_writes_workspace
run_test "plain: workspace.json has main-leaf" t_plain_workspace_has_main_leaf
run_test "plain: empty community-plugins.json" t_plain_empty_community_plugins
run_test "plain: no themes dir"                t_plain_no_themes_dir
run_test "plain: safe to re-run"               t_plain_safe_to_rerun

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 2 — setup.sh: bundled theme
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "── setup.sh: bundled ───────────────────────────────────────────────────"

t_bundled_theme_css() {
    setup_with_args --theme bundled
    assert_file "$VAULT_DIR/.obsidian/themes/AnuPpuccin/theme.css"
}

t_bundled_style_settings_plugin() {
    setup_with_args --theme bundled
    assert_dir  "$VAULT_DIR/.obsidian/plugins/obsidian-style-settings"
    assert_file "$VAULT_DIR/.obsidian/plugins/obsidian-style-settings/main.js"
}

t_bundled_community_plugins_lists_ss() {
    setup_with_args --theme bundled
    assert_contains "$VAULT_DIR/.obsidian/community-plugins.json" "obsidian-style-settings"
}

t_bundled_appearance_sets_theme() {
    setup_with_args --theme bundled
    assert_contains "$VAULT_DIR/.obsidian/appearance.json" "AnuPpuccin"
}

t_bundled_data_json_nonempty() {
    setup_with_args --theme bundled
    assert_file "$VAULT_DIR/.obsidian/plugins/obsidian-style-settings/data.json"
    local size
    size=$(wc -c < "$VAULT_DIR/.obsidian/plugins/obsidian-style-settings/data.json")
    [[ "$size" -gt 10 ]] || { echo "data.json too small (${size} bytes)"; return 1; }
}

t_bundled_snippets_installed() {
    setup_with_args --theme bundled
    assert_file "$VAULT_DIR/.obsidian/snippets/wide-view.css"
}

run_test "bundled: installs AnuPpuccin theme.css"        t_bundled_theme_css
run_test "bundled: installs style-settings plugin"       t_bundled_style_settings_plugin
run_test "bundled: community-plugins.json lists ss"      t_bundled_community_plugins_lists_ss
run_test "bundled: appearance.json sets AnuPpuccin"      t_bundled_appearance_sets_theme
run_test "bundled: style-settings data.json non-empty"   t_bundled_data_json_nonempty
run_test "bundled: snippets installed"                   t_bundled_snippets_installed

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 3 — setup.sh: vault theme
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "── setup.sh: vault theme ───────────────────────────────────────────────"

FAKE_VAULT="$TEST_HOME/fake-vault"
mkdir -p "$FAKE_VAULT/.obsidian/plugins/obsidian-style-settings"
echo '{"cssTheme":"FakeTheme"}' > "$FAKE_VAULT/.obsidian/appearance.json"
echo '["obsidian-style-settings"]' > "$FAKE_VAULT/.obsidian/community-plugins.json"
echo '{}' > "$FAKE_VAULT/.obsidian/plugins/obsidian-style-settings/data.json"
echo '{"editor":true}' > "$FAKE_VAULT/.obsidian/core-plugins.json"
echo '{"active":"some-leaf"}' > "$FAKE_VAULT/.obsidian/workspace.json"

t_vault_theme_copies_appearance() {
    setup_with_args --vault "$FAKE_VAULT"
    assert_file "$VAULT_DIR/.obsidian/appearance.json"
    assert_contains "$VAULT_DIR/.obsidian/appearance.json" "FakeTheme"
}

t_vault_theme_removes_old_workspace() {
    setup_with_args --vault "$FAKE_VAULT"
    assert_absent "$VAULT_DIR/.obsidian/workspace.json" "some-leaf"
}

t_vault_theme_writes_fresh_workspace() {
    setup_with_args --vault "$FAKE_VAULT"
    assert_file "$VAULT_DIR/.obsidian/workspace.json"
    assert_contains "$VAULT_DIR/.obsidian/workspace.json" "main-leaf"
}

t_vault_theme_keeps_style_settings() {
    setup_with_args --vault "$FAKE_VAULT"
    assert_dir "$VAULT_DIR/.obsidian/plugins/obsidian-style-settings"
}

t_vault_theme_error_without_vault() {
    local out exit_code=0
    out=$(HOME="$TEST_HOME" bash "$SCRIPT_DIR/setup.sh" --theme vault 2>&1) || exit_code=$?
    [[ "$exit_code" -ne 0 ]] || { echo "Expected non-zero exit, got 0"; return 1; }
    echo "$out" | grep -q -i "error\|requires\|source vault" || {
        echo "Expected error message, got: $out"; return 1
    }
}

run_test "vault theme: copies appearance.json"        t_vault_theme_copies_appearance
run_test "vault theme: removes old workspace.json"    t_vault_theme_removes_old_workspace
run_test "vault theme: writes fresh workspace.json"   t_vault_theme_writes_fresh_workspace
run_test "vault theme: keeps style-settings plugin"   t_vault_theme_keeps_style_settings
run_test "vault theme: error without --vault flag"    t_vault_theme_error_without_vault

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 4 — vault registration (the Python snippet from setup.sh)
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "── setup.sh: vault registration ────────────────────────────────────────"

do_register() {
    python3 - "$TEST_HOME/MDPreview" "$OBSIDIAN_JSON" <<'PYEOF'
import json, os, sys, time, secrets
vault_path, config_path = sys.argv[1], sys.argv[2]
config = {}
if os.path.exists(config_path):
    with open(config_path) as f:
        config = json.load(f)
vaults = config.setdefault("vaults", {})
for uid, v in vaults.items():
    if v.get("path") == vault_path:
        sys.exit(0)
uid = secrets.token_hex(8)
vaults[uid] = {"path": vault_path, "ts": int(time.time() * 1000)}
with open(config_path, "w") as f:
    json.dump(config, f, separators=(",", ":"))
PYEOF
}

t_registration_adds_entry() {
    stub_obsidian_config
    do_register
    python3 -c "
import json, sys
c = json.load(open('$OBSIDIAN_JSON'))
paths = [v['path'] for v in c['vaults'].values()]
assert any('MDPreview' in p for p in paths), f'MDPreview not in vaults: {paths}'
"
}

t_registration_idempotent() {
    stub_obsidian_config
    do_register; do_register; do_register
    local count
    count=$(python3 -c "
import json
c = json.load(open('$OBSIDIAN_JSON'))
print(len(c['vaults']))
")
    [[ "$count" -eq 1 ]] || { echo "Expected 1 vault entry, got $count"; return 1; }
}

run_test "registration: adds vault entry"   t_registration_adds_entry
run_test "registration: idempotent"         t_registration_idempotent

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 5 — md-preview.sh
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "── md-preview.sh ───────────────────────────────────────────────────────"

t_mdpreview_creates_symlink() {
    mkdir -p "$VAULT_DIR"
    local src="$TEST_HOME/sample.md"
    echo "# Hello" > "$src"
    run_md_preview "$src"
    assert_file "$VAULT_DIR/sample.md"
    [[ -L "$VAULT_DIR/sample.md" ]] || { echo "Expected symlink, got regular file"; return 1; }
}

t_mdpreview_symlink_points_to_original() {
    mkdir -p "$VAULT_DIR"
    local src="$TEST_HOME/target.md"
    echo "# Content" > "$src"
    run_md_preview "$src"
    local dest
    dest=$(readlink "$VAULT_DIR/target.md")
    [[ "$dest" == "$src" ]] || { echo "Symlink points to '$dest', expected '$src'"; return 1; }
}

t_mdpreview_original_unchanged() {
    mkdir -p "$VAULT_DIR"
    local src="$TEST_HOME/orig.md"
    echo "original content" > "$src"
    run_md_preview "$src"
    local content
    content=$(cat "$src")
    [[ "$content" == "original content" ]] || { echo "Original modified: $content"; return 1; }
}

t_mdpreview_fails_on_missing_file() {
    local out exit_code=0
    out=$(HOME="$TEST_HOME" bash "$SCRIPT_DIR/md-preview.sh" /nonexistent/file.md 2>&1) || exit_code=$?
    [[ "$exit_code" -ne 0 ]] || { echo "Expected non-zero exit"; return 1; }
    echo "$out" | grep -q -i "not found\|no such" || { echo "Unexpected output: $out"; return 1; }
}

t_mdpreview_fails_without_args() {
    local out exit_code=0
    out=$(HOME="$TEST_HOME" bash "$SCRIPT_DIR/md-preview.sh" 2>&1) || exit_code=$?
    [[ "$exit_code" -ne 0 ]] || { echo "Expected non-zero exit"; return 1; }
    echo "$out" | grep -q "Usage" || { echo "Expected Usage message, got: $out"; return 1; }
}

t_mdpreview_workspace_detects_preview_mode() {
    mkdir -p "$VAULT_DIR/.obsidian"
    cat > "$VAULT_DIR/.obsidian/workspace.json" <<'JSON'
{"main":{"children":[{"children":[{"state":{"state":{"file":"test.md","mode":"preview"}}}]}]}}
JSON
    local result
    result=$(python3 - "$VAULT_DIR/.obsidian/workspace.json" "test.md" <<'PYEOF'
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
            if r is not None: return r
    elif isinstance(obj, list):
        for item in obj:
            r = find_mode(item)
            if r is not None: return r
    return None
try:
    ws = json.load(open(ws_path))
    mode = find_mode(ws)
    print("yes" if mode == "preview" else "no")
except Exception:
    print("no")
PYEOF
)
    [[ "$result" == "yes" ]] || { echo "Expected 'yes', got '$result'"; return 1; }
}

t_mdpreview_workspace_detects_source_mode() {
    mkdir -p "$VAULT_DIR/.obsidian"
    cat > "$VAULT_DIR/.obsidian/workspace.json" <<'JSON'
{"main":{"children":[{"children":[{"state":{"state":{"file":"test.md","mode":"source"}}}]}]}}
JSON
    local result
    result=$(python3 - "$VAULT_DIR/.obsidian/workspace.json" "test.md" <<'PYEOF'
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
            if r is not None: return r
    elif isinstance(obj, list):
        for item in obj:
            r = find_mode(item)
            if r is not None: return r
    return None
try:
    ws = json.load(open(ws_path))
    mode = find_mode(ws)
    print("yes" if mode == "preview" else "no")
except Exception:
    print("no")
PYEOF
)
    [[ "$result" == "no" ]] || { echo "Expected 'no', got '$result'"; return 1; }
}

run_test "md-preview: creates symlink in vault"           t_mdpreview_creates_symlink
run_test "md-preview: symlink points to original"         t_mdpreview_symlink_points_to_original
run_test "md-preview: original file unchanged"            t_mdpreview_original_unchanged
run_test "md-preview: fails gracefully on missing file"   t_mdpreview_fails_on_missing_file
run_test "md-preview: fails without arguments"            t_mdpreview_fails_without_args
run_test "md-preview: workspace detects preview mode"     t_mdpreview_workspace_detects_preview_mode
run_test "md-preview: workspace detects source mode"      t_mdpreview_workspace_detects_source_mode

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 6 — install.sh: path substitution (no Obsidian needed)
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "── install.sh: path substitution ──────────────────────────────────────"

t_applescript_uses_path_to_me() {
    assert_contains "$SCRIPT_DIR/automator/MDPreview.applescript" "path to me"
    assert_contains "$SCRIPT_DIR/automator/MDPreview.applescript" "Contents/Resources/md-preview.sh"
}

t_applescript_no_hardcoded_paths() {
    assert_absent "$SCRIPT_DIR/automator/MDPreview.applescript" "/Users/"
}

t_wflow_uses_open_app() {
    assert_contains "$SCRIPT_DIR/install.sh" "open -a MDPreview"
}

t_install_no_personal_paths() {
    assert_absent "$SCRIPT_DIR/install.sh" "/Users/reut"
}

t_setup_no_personal_paths() {
    assert_absent "$SCRIPT_DIR/setup.sh" "/Users/reut"
    assert_absent "$SCRIPT_DIR/setup.sh" "ReutsVault"
    assert_absent "$SCRIPT_DIR/setup.sh" "claude_vault"
}

run_test "applescript: uses path to me + Resources path"      t_applescript_uses_path_to_me
run_test "applescript: no hardcoded personal paths"           t_applescript_no_hardcoded_paths
run_test "wflow: Quick Action delegates to open -a MDPreview" t_wflow_uses_open_app
run_test "install.sh: no personal paths"                      t_install_no_personal_paths
run_test "setup.sh: no personal paths"                        t_setup_no_personal_paths

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 7 — md-preview.sh: Obsidian URI (mock open)
#
# We don't simulate Obsidian's GUI — we verify that md-preview.sh calls
# `open` with a correctly formed obsidian:// URL. A mock `open` binary in
# $PATH captures the call and writes it to a log file.
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "── md-preview.sh: Obsidian URI ─────────────────────────────────────────"

MOCK_BIN="$TEST_HOME/mock-bin"
OPEN_LOG="$TEST_HOME/open-calls.log"
mkdir -p "$MOCK_BIN"

# Mock `open` — logs every call, silently succeeds
cat > "$MOCK_BIN/open" <<MOCK
#!/bin/bash
echo "\$@" >> "$OPEN_LOG"
MOCK
chmod +x "$MOCK_BIN/open"

# Mock `osascript` — silently succeeds (we're not testing keystroke delivery)
cat > "$MOCK_BIN/osascript" <<'MOCK'
#!/bin/bash
exit 0
MOCK
chmod +x "$MOCK_BIN/osascript"

# Mock `pgrep` — always returns "not running" so the quit block is skipped
cat > "$MOCK_BIN/pgrep" <<'MOCK'
#!/bin/bash
exit 1
MOCK
chmod +x "$MOCK_BIN/pgrep"

run_md_preview_with_mocks() {
    mkdir -p "$VAULT_DIR/.obsidian"
    # Write a minimal workspace.json so the mode-check doesn't fail on missing file
    echo '{"main":{"children":[]}}' > "$VAULT_DIR/.obsidian/workspace.json"
    : > "$OPEN_LOG"
    PATH="$MOCK_BIN:$PATH" HOME="$TEST_HOME" bash "$SCRIPT_DIR/md-preview.sh" "$@"
}

t_mdpreview_calls_open_with_obsidian_uri() {
    local src="$TEST_HOME/hello.md"
    echo "# Hi" > "$src"
    run_md_preview_with_mocks "$src"
    assert_file "$OPEN_LOG"
    grep -q "obsidian://open" "$OPEN_LOG" || {
        echo "open was not called with obsidian://open. Got: $(cat "$OPEN_LOG")"; return 1
    }
}

t_mdpreview_uri_contains_vault_name() {
    local src="$TEST_HOME/vault-check.md"
    echo "# Test" > "$src"
    run_md_preview_with_mocks "$src"
    grep -q "vault=MDPreview" "$OPEN_LOG" || {
        echo "URI missing vault=MDPreview. Got: $(cat "$OPEN_LOG")"; return 1
    }
}

t_mdpreview_uri_contains_encoded_filename() {
    local src="$TEST_HOME/encoded.md"
    echo "# Test" > "$src"
    run_md_preview_with_mocks "$src"
    grep -q "file=encoded" "$OPEN_LOG" || {
        echo "URI missing file=encoded. Got: $(cat "$OPEN_LOG")"; return 1
    }
}

t_mdpreview_uri_encodes_spaces() {
    local src="$TEST_HOME/my file.md"
    echo "# Test" > "$src"
    run_md_preview_with_mocks "$src"
    grep -q "file=my%20file" "$OPEN_LOG" || {
        echo "Spaces not percent-encoded. Got: $(cat "$OPEN_LOG")"; return 1
    }
}

run_test "open: called with obsidian:// URI"         t_mdpreview_calls_open_with_obsidian_uri
run_test "open: URI contains vault=MDPreview"        t_mdpreview_uri_contains_vault_name
run_test "open: URI contains encoded filename"       t_mdpreview_uri_contains_encoded_filename
run_test "open: spaces percent-encoded in filename"  t_mdpreview_uri_encodes_spaces

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 8 — install.sh: compile round-trip (requires osacompile/osadecompile)
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "── install.sh: compile round-trip ─────────────────────────────────────"

if ! command -v osacompile &>/dev/null || ! command -v osadecompile &>/dev/null; then
    echo "  (skipped — osacompile/osadecompile not available on this platform)"
else

TEST_APP="$TEST_HOME/MDPreview-test.app"
TEST_SERVICES="$TEST_HOME/Services"

run_install() {
    APP_DEST="$TEST_APP" SERVICES_DIR="$TEST_SERVICES" \
        bash "$SCRIPT_DIR/install.sh" 2>/dev/null
}

t_compile_app_exists() {
    run_install
    assert_dir "$TEST_APP"
    assert_file "$TEST_APP/Contents/Resources/Scripts/main.scpt"
}

t_compile_no_placeholder_in_app() {
    run_install
    local decompiled
    decompiled=$(osadecompile "$TEST_APP/Contents/Resources/Scripts/main.scpt" 2>/dev/null)
    echo "$decompiled" | grep -q "MDPREVIEW_SH_PATH" && {
        echo "Placeholder still present in compiled app"; return 1
    } || true
}

t_compile_uses_path_to_me() {
    run_install
    local decompiled
    decompiled=$(osadecompile "$TEST_APP/Contents/Resources/Scripts/main.scpt" 2>/dev/null)
    echo "$decompiled" | grep -q "path to me" || {
        echo "Expected 'path to me' not found in compiled app. Got: $decompiled"; return 1
    }
}

t_compile_resources_bundled() {
    run_install
    assert_file "$TEST_APP/Contents/Resources/md-preview.sh"
    assert_file "$TEST_APP/Contents/Resources/setup.sh"
    assert_dir  "$TEST_APP/Contents/Resources/vault-config"
}

t_compile_plist_has_bundle_id() {
    run_install
    assert_file "$TEST_APP/Contents/Info.plist"
    python3 -c "
import plistlib, sys
with open('$TEST_APP/Contents/Info.plist', 'rb') as f:
    p = plistlib.load(f)
assert p.get('CFBundleIdentifier') == 'com.mdpreview.app', \
    f\"Expected com.mdpreview.app, got {p.get('CFBundleIdentifier')}\"
"
}

t_compile_wflow_uses_open_app() {
    run_install
    local wflow="$TEST_SERVICES/Open in MDPreview.workflow/Contents/document.wflow"
    assert_file    "$wflow"
    assert_contains "$wflow" "open -a MDPreview"
    assert_absent   "$wflow" "MDPREVIEW_SH_PATH"
}

run_test "compile: app bundle created"                  t_compile_app_exists
run_test "compile: no placeholder in compiled .scpt"    t_compile_no_placeholder_in_app
run_test "compile: uses path to me in compiled .scpt"   t_compile_uses_path_to_me
run_test "compile: resources bundled in app"            t_compile_resources_bundled
run_test "compile: Info.plist has correct bundle ID"    t_compile_plist_has_bundle_id
run_test "compile: wflow delegates to open -a MDPreview" t_compile_wflow_uses_open_app

fi  # end osacompile check

# ─────────────────────────────────────────────────────────────────────────────
# SECTION 9 — README completeness
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "── README ──────────────────────────────────────────────────────────────"

t_readme_mentions_setup()         { assert_contains "$SCRIPT_DIR/README.md" "setup.sh"; }
t_readme_mentions_install()       { assert_contains "$SCRIPT_DIR/README.md" "install.sh"; }
t_readme_mentions_accessibility() { assert_contains "$SCRIPT_DIR/README.md" "Accessibility"; }
t_readme_mentions_trust()         { assert_contains "$SCRIPT_DIR/README.md" "Trust"; }
t_readme_no_personal_bundle_id()  { assert_absent   "$SCRIPT_DIR/README.md" "com.reut"; }

run_test "README: mentions setup.sh"             t_readme_mentions_setup
run_test "README: mentions install.sh"           t_readme_mentions_install
run_test "README: mentions Accessibility"        t_readme_mentions_accessibility
run_test "README: mentions Trust prompt"         t_readme_mentions_trust
run_test "README: no personal bundle ID"         t_readme_no_personal_bundle_id

# ─────────────────────────────────────────────────────────────────────────────
# Results
# ─────────────────────────────────────────────────────────────────────────────

echo ""
echo "────────────────────────────────────────────────────────────────────────"
echo "  Results: $PASS passed, $FAIL failed, $SKIP skipped"
echo "────────────────────────────────────────────────────────────────────────"

if [[ "${#FAILURE_NAMES[@]}" -gt 0 ]]; then
    echo ""
    echo "Failed tests:"
    for i in "${!FAILURE_NAMES[@]}"; do
        echo ""
        echo "  FAIL: ${FAILURE_NAMES[$i]}"
        echo "${FAILURE_OUTPUTS[$i]}" | sed 's/^/    /'
    done
    exit 1
fi
