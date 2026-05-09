#Requires -Version 5.1
<#
.SYNOPSIS
    Remove MDPreview from this computer.
.DESCRIPTION
    Undoes everything setup.ps1 and install.ps1 did: removes the right-click
    context menu entry, file handler registration, Obsidian vault registration,
    and optionally the MDPreview vault folder. Safe to run multiple times.
    Run from PowerShell: .\uninstall.ps1
#>

$ErrorActionPreference = 'Stop'

$VaultDir = Join-Path $env:USERPROFILE 'MDPreview'
$ExePath  = Join-Path $PSScriptRoot 'MDPreview.exe'

# 1. Remove right-click context menu entry (added by install.ps1)
# Must use .NET Registry API - PowerShell provider treats * as a wildcard
Write-Host ''
Write-Host 'Step 1/4: Removing right-click context menu entry...'
$menuPath = 'Software\Classes\*\shell\Open in MDPreview'
try {
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($menuPath, $true)
    if ($key) {
        $key.Close()
        [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree($menuPath)
        Write-Host '[OK] Context menu entry removed.'
    } else {
        Write-Host '[--] Context menu entry not found (already clean).'
    }
} catch {
    Write-Host "[!!] Could not remove context menu entry: $_"
}

# 2. Remove file handler registry entries (added by set-default.ps1)
Write-Host ''
Write-Host 'Step 2/4: Removing file handler registration...'
try {
    $k = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Classes\MDPreview.md', $true)
    if ($k) {
        $k.Close()
        [Microsoft.Win32.Registry]::CurrentUser.DeleteSubKeyTree('Software\Classes\MDPreview.md')
        Write-Host '[OK] Removed MDPreview.md ProgID.'
    } else {
        Write-Host '[--] MDPreview.md ProgID not found (already clean).'
    }
} catch {
    Write-Host "[!!] Could not remove ProgID: $_"
}
try {
    $k = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Classes\.md\OpenWithProgids', $true)
    if ($k) {
        $k.DeleteValue('MDPreview.md', $false)
        $k.Close()
        Write-Host '[OK] Removed MDPreview.md from .md OpenWithProgids.'
    } else {
        Write-Host '[--] .md OpenWithProgids key not found (already clean).'
    }
} catch {
    Write-Host '[--] MDPreview.md not in OpenWithProgids (already clean).'
}

# 3. Remove MDPreview vault from Obsidian's vault list
Write-Host ''
Write-Host 'Step 3/4: Removing MDPreview vault from Obsidian...'
$obsidianJson = Join-Path $env:APPDATA 'Obsidian\obsidian.json'
if (Test-Path $obsidianJson) {
    try {
        $raw     = Get-Content $obsidianJson -Raw
        $content = $raw | ConvertFrom-Json
        $removed = $false
        $newVaults = [ordered]@{}
        foreach ($id in $content.vaults.PSObject.Properties.Name) {
            if ($content.vaults.$id.path -eq $VaultDir) {
                $removed = $true
            } else {
                $newVaults[$id] = $content.vaults.$id
            }
        }
        if ($removed) {
            $content.vaults = [PSCustomObject]$newVaults
            $content | ConvertTo-Json -Depth 10 | Set-Content $obsidianJson -Encoding UTF8
            Write-Host '[OK] MDPreview vault removed from Obsidian.'
        } else {
            Write-Host '[--] MDPreview vault not found in Obsidian (already clean).'
        }
    } catch {
        Write-Host "[!!] Could not update obsidian.json: $_"
    }
} else {
    Write-Host '[--] obsidian.json not found - Obsidian may not be installed.'
}

# Delete MDPreview.exe if it was compiled by set-default.ps1
if (Test-Path $ExePath) {
    Remove-Item $ExePath -Force
    Write-Host '[OK] Deleted MDPreview.exe'
}

# 4. Optionally delete the ~/MDPreview vault folder
Write-Host ''
Write-Host 'Step 4/4: MDPreview vault folder'
if (Test-Path $VaultDir) {
    $answer = Read-Host "Delete vault folder at $VaultDir`? [y/N]"
    if ($answer -match '^[Yy]') {
        Remove-Item $VaultDir -Recurse -Force
        Write-Host '[OK] Vault folder deleted.'
    } else {
        Write-Host '[--] Vault folder kept.'
    }
} else {
    Write-Host '[--] Vault folder not found (already clean).'
}

Write-Host ''
Write-Host 'Uninstall complete. You can now do a fresh install.'
Write-Host ''
