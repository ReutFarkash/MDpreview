# md-preview

Open any Markdown file in Obsidian — even files outside any vault — with a single double-click or right-click. Files are symlinked into a dedicated `~/MDPreview/` vault and opened in reading mode automatically.

## Requirements

- macOS
- [Obsidian](https://obsidian.md) installed

## Install

**Option A — DMG (recommended)**

1. Download `MDPreview-<version>.dmg` from [Releases](https://github.com/ReutFarkash/MDpreview/releases)
2. Open the DMG and drag **MDPreview.app** to **Applications**
3. Double-click MDPreview.app — it sets up `~/MDPreview` automatically on first run

**First-run prompts — all expected, here's what to click:**

| Prompt | Action |
|---|---|
| *"MDPreview.app is downloaded from the Internet…"* | Click **Open** — Apple has scanned it and found no malicious software |
| *"Would you like MDPreview to open .md files by default?"* | Click **Set as Default** to double-click open `.md` files. ⚠️ This dialog can appear behind Obsidian's window — if you don't see it, look behind the trust dialog below |
| *"Do you trust the author of this vault?"* | Click **Trust author and enable plugins** |

To also get the Finder right-click action, clone the repo and run `bash install.sh`.

**Option B — from source**

```bash
# 1. Set up the vault (choose one option below)
bash setup.sh

# 2. Install the app + Finder Quick Action
bash install.sh
```

### Setup options

| Command | Theme | Plugins |
|---|---|---|
| `bash setup.sh` | Plain Obsidian | None |
| `bash setup.sh --theme bundled` | AnuPpuccin (bundled) | Style Settings |
| `bash setup.sh --theme bundled --full --vault /path` | AnuPpuccin (bundled) | Dataview, Excalidraw, + more |
| `bash setup.sh --theme vault --vault /path/to/vault` | Your vault's theme | Style Settings only |
| `bash setup.sh --theme vault --full --vault /path/to/vault` | Your vault's theme | All your vault's plugins |

`--vault` can be omitted if your vault is in a standard location (iCloud Obsidian folder, `~/Obsidian/`, etc.).

### First-run permissions

- **Accessibility (for reading mode):** System Settings → Privacy & Security → Accessibility → enable **Finder**

## Usage

**Double-click** any `.md` file (after setting MDPreview as default — see below).

**Right-click** any `.md` file in Finder → **Open in MDPreview** (bottom of context menu).

**Terminal:**
```bash
bash /path/to/md-preview/md-preview.sh /path/to/file.md
```

Add an alias in `~/.bashrc`:
```bash
alias md-preview='bash /path/to/md-preview/md-preview.sh'
```

## Set as default app for .md files

On first launch from the DMG, MDPreview will ask you automatically — click **Set as Default**.

If you skipped it or installed from source:

**Option A — Finder:**
Right-click any `.md` file → Get Info → Open With → select MDPreview → Change All...

**Option B — Terminal:**
```bash
/Applications/MDPreview.app/Contents/Resources/set-default
```

## How it works

1. `md-preview.sh` resolves the absolute path of your file
2. Symlinks it into `~/MDPreview/<filename>.md` (original file is never modified)
3. Opens `obsidian://open?vault=MDPreview&file=<filename>` 
4. Switches Obsidian to reading mode via AppleScript

**Symlinks accumulate** in `~/MDPreview/` — delete them manually whenever. The originals are never touched.

**Same filename from different folders:** the symlink is overwritten with the latest file. Contents will always be correct.

## Files

```
md-preview/
├── md-preview.sh              # core script
├── setup.sh                   # vault creation (run once)
├── install.sh                 # app + Quick Action installer (local dev)
├── build-dmg.sh               # build distributable DMG
├── automator/
│   └── MDPreview.applescript  # source for MDPreview.app
└── vault-config/
    ├── bundled/.obsidian/     # AnuPpuccin theme + Style Settings (no personal data)
    ├── plain/.obsidian/       # bare Obsidian config
    ├── plugins-minimal.json   # ["obsidian-style-settings"]
    └── plugins-full.json      # Dataview, Excalidraw, Icon Shortcodes, etc.
```
