#Requires -Version 5.1
<#
.SYNOPSIS
    Open any Markdown file in Obsidian via the MDPreview vault.
.DESCRIPTION
    Symlinks (or copies) the file into ~/MDPreview, then opens it via the
    obsidian:// URI protocol. Press Ctrl+E in Obsidian to enter reading mode.
.PARAMETER FilePath
    Path to the Markdown file to preview.
.EXAMPLE
    .\md-preview.ps1 C:\notes\readme.md
#>
param(
    [Parameter(Mandatory)][string]$FilePath
)

$ErrorActionPreference = 'Stop'

$VaultDir  = Join-Path $env:USERPROFILE 'MDPreview'
$VaultName = 'MDPreview'

# Resolve to absolute path
$AbsPath = (Resolve-Path $FilePath -ErrorAction Stop).Path

if (-not (Test-Path $AbsPath -PathType Leaf)) {
    Write-Error "File not found: $AbsPath"
    exit 1
}

$Filename = Split-Path $AbsPath -Leaf

if (-not (Test-Path $VaultDir)) {
    New-Item -ItemType Directory -Path $VaultDir | Out-Null
}

# Prefer symlink (requires Developer Mode on Windows 10+); fall back to copy
$LinkPath = Join-Path $VaultDir $Filename
try {
    New-Item -ItemType SymbolicLink -Path $LinkPath -Target $AbsPath -Force -ErrorAction Stop | Out-Null
} catch {
    Copy-Item -Path $AbsPath -Destination $LinkPath -Force
}

$Encoded = [System.Uri]::EscapeDataString($Filename)
Start-Process "obsidian://open?vault=${VaultName}&file=${Encoded}"

# Reading mode: press Ctrl+E in Obsidian (Option C - no auto-toggle on Windows yet)
