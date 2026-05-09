#Requires -Version 5.1
<#
.SYNOPSIS
    Create and configure the MDPreview vault on Windows.
.DESCRIPTION
    USAGE
      .\setup.ps1                           Plain Obsidian - no theme, no community plugins
      .\setup.ps1 -Theme bundled            AnuPpuccin theme + Style Settings (bundled in repo)
      .\setup.ps1 -Theme bundled -Full      AnuPpuccin + Dataview, Excalidraw, etc. (needs -Vault or auto-detect)
      .\setup.ps1 -Theme vault              Copy theme from your Obsidian vault + Style Settings only
      .\setup.ps1 -Theme vault -Full        Copy theme + all plugins from your vault
      .\setup.ps1 -Vault C:\path\to\vault   Specify vault explicitly (implies -Theme vault)
#>
param(
    [ValidateSet('plain', 'bundled', 'vault')][string]$Theme = 'bundled',
    [switch]$Full,
    [string]$Vault
)

$ErrorActionPreference = 'Stop'

$ScriptDir      = $PSScriptRoot
$VaultDir       = Join-Path $env:USERPROFILE 'MDPreview'
$ObsidianConfig = Join-Path $env:APPDATA 'Obsidian\obsidian.json'

if ($Vault) { $Theme = 'vault' }

#  Auto-detect source vault (for -Theme vault or -Full only) 
$SourceVault = ''
if ($Theme -eq 'vault' -or $Full) {
    $SourceVault = $Vault
    if (-not $SourceVault) {
        foreach ($base in @(
            "$env:USERPROFILE\Documents\Obsidian",
            "$env:USERPROFILE\Obsidian"
        )) {
            if (Test-Path $base) {
                $found = Get-ChildItem -Path $base -Directory |
                         Where-Object { Test-Path (Join-Path $_.FullName '.obsidian') } |
                         Select-Object -First 1
                if ($found) { $SourceVault = $found.FullName; break }
            }
        }
    }
}

if ($Theme -eq 'vault' -and -not $SourceVault) {
    Write-Error 'Error: -Theme vault requires a source vault. Use -Vault C:\path\to\vault'
    exit 1
}
if ($Full -and -not $SourceVault) {
    Write-Warning '-Full needs a source vault. Auto-detect found nothing. Continuing without full plugins.'
    $Full = $false
}

Write-Host ''
Write-Host '  md-preview setup'
Write-Host "  Theme:   $Theme"
Write-Host "  Plugins: $(if ($Full) { 'full' } else { 'minimal' })"
if ($SourceVault) { Write-Host "  Source:  $SourceVault" }
Write-Host ''

#  Create vault directory 
Write-Host ''
Write-Host "Creating vault at $VaultDir ..."

if (-not (Test-Path $VaultDir)) { New-Item -ItemType Directory -Path $VaultDir | Out-Null }
$ObsidianDir = Join-Path $VaultDir '.obsidian'
if (Test-Path $ObsidianDir) { Remove-Item -Recurse -Force $ObsidianDir }

#  Install .obsidian config 
switch ($Theme) {

    'plain' {
        Copy-Item -Recurse -Force (Join-Path $ScriptDir 'vault-config\plain\.obsidian') $ObsidianDir
        Write-Host '[OK] Plain Obsidian config installed'
    }

    'bundled' {
        Copy-Item -Recurse -Force (Join-Path $ScriptDir 'vault-config\bundled\.obsidian') $ObsidianDir
        if ($Full) {
            Write-Host '[OK] Bundled AnuPpuccin config installed'
            Write-Host "  Copying full plugin set from $SourceVault ..."
            $FullPlugins = @(
                'dataview', 'obsidian-excalidraw-plugin', 'obsidian-icon-shortcodes',
                'templater-obsidian', 'obsidian-auto-link-title', 'url-into-selection'
            )
            foreach ($plugin in $FullPlugins) {
                $src = Join-Path $SourceVault ".obsidian\plugins\$plugin"
                if (Test-Path $src) {
                    Copy-Item -Recurse -Force $src (Join-Path $ObsidianDir "plugins\$plugin")
                    Write-Host "    [OK] $plugin"
                } else {
                    Write-Host "    [!] $plugin not found in source vault - skipping"
                }
            }
            Copy-Item -Force (Join-Path $ScriptDir 'vault-config\plugins-full.json') `
                             (Join-Path $ObsidianDir 'community-plugins.json')
        } else {
            Write-Host '[OK] Bundled AnuPpuccin config installed (Style Settings only)'
        }
    }

    'vault' {
        Write-Host "  Copying full .obsidian from $SourceVault ..."
        Copy-Item -Recurse -Force (Join-Path $SourceVault '.obsidian') $ObsidianDir
        # Remove vault-specific files
        foreach ($f in @('workspace.json', 'daily-notes.json', 'templates.json')) {
            $p = Join-Path $ObsidianDir $f
            if (Test-Path $p) { Remove-Item $p }
        }
        # Disable core plugins that reference vault-specific paths
        $CorePluginsPath = Join-Path $ObsidianDir 'core-plugins.json'
        if (Test-Path $CorePluginsPath) {
            $cp = Get-Content $CorePluginsPath -Raw | ConvertFrom-Json
            foreach ($k in @('daily-notes', 'templates', 'sync', 'publish')) {
                $cp | Add-Member -NotePropertyName $k -NotePropertyValue $false -Force
            }
            $cp | ConvertTo-Json -Depth 5 | Set-Content $CorePluginsPath
        }
        if (-not $Full) {
            # Keep only style-settings from community plugins
            $CpJsonPath = Join-Path $ObsidianDir 'community-plugins.json'
            $SrcCpJson  = Join-Path $SourceVault '.obsidian\community-plugins.json'
            if (Test-Path $SrcCpJson) {
                $plugins   = @(Get-Content $SrcCpJson -Raw | ConvertFrom-Json)
                $keep      = @($plugins | Where-Object { $_ -eq 'obsidian-style-settings' })
                $keep | ConvertTo-Json | Set-Content $CpJsonPath
                $PluginDir = Join-Path $ObsidianDir 'plugins'
                if (Test-Path $PluginDir) {
                    Get-ChildItem $PluginDir -Directory |
                        Where-Object { $keep -notcontains $_.Name } |
                        Remove-Item -Recurse -Force
                }
            }
            Write-Host '[OK] Vault theme installed (Style Settings only)'
        } else {
            Write-Host '[OK] Vault theme + full plugin set installed'
        }
    }
}

#  Write clean workspace.json 
New-Item -ItemType Directory -Path $ObsidianDir -Force | Out-Null
@'
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
'@ | Set-Content (Join-Path $ObsidianDir 'workspace.json')

#  Register vault in Obsidian's config 
Write-Host ''
Write-Host 'Registering vault with Obsidian...'

$ObsProcess = Get-Process -Name 'Obsidian' -ErrorAction SilentlyContinue
if ($ObsProcess) {
    Write-Host '  Obsidian is running - quitting to update vault registry...'
    $ObsProcess | Stop-Process -Force
    Start-Sleep -Seconds 2
}

if (Test-Path $ObsidianConfig) {
    $config = Get-Content $ObsidianConfig -Raw | ConvertFrom-Json
} else {
    $config = [PSCustomObject]@{ vaults = [PSCustomObject]@{} }
}
if (-not $config.PSObject.Properties['vaults']) {
    $config | Add-Member -NotePropertyName 'vaults' -NotePropertyValue ([PSCustomObject]@{})
}

$AlreadyRegistered = $false
foreach ($uid in $config.vaults.PSObject.Properties.Name) {
    if ($config.vaults.$uid.path -eq $VaultDir) {
        Write-Host "  Already registered as $uid"
        $AlreadyRegistered = $true
        break
    }
}

if (-not $AlreadyRegistered) {
    $uid = [System.Guid]::NewGuid().ToString('N').Substring(0, 16)
    $ts  = [long][System.DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $config.vaults | Add-Member -NotePropertyName $uid `
        -NotePropertyValue ([PSCustomObject]@{ path = $VaultDir; ts = $ts })
    $ConfigDir = Split-Path $ObsidianConfig
    if (-not (Test-Path $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir | Out-Null }
    $config | ConvertTo-Json -Depth 5 -Compress | Set-Content $ObsidianConfig
    Write-Host "  [OK] Registered (id: $uid)"
}

#  Launch Obsidian 
Write-Host 'Launching Obsidian...'
Start-Process 'obsidian://open?vault=MDPreview'

Write-Host ''
Write-Host '[OK] Setup complete. If Obsidian asks to trust the vault, click Trust.'
Write-Host '  Run install.bat next to add the right-click context menu entry.'
