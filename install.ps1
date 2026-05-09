#Requires -Version 5.1
<#
.SYNOPSIS
    Add "Open in MDPreview" to the Windows right-click context menu.
.DESCRIPTION
    Writes per-user registry entries under HKCU - no admin rights required.
    Run install.bat to execute this without changing your execution policy.
#>

$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
$PsScript  = Join-Path $ScriptDir 'md-preview.ps1'

if (-not (Test-Path $PsScript)) {
    Write-Error "md-preview.ps1 not found at: $PsScript"
    exit 1
}

$PS      = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$Command = "`"$PS`" -ExecutionPolicy Bypass -NoProfile -File `"$PsScript`" `"%1`""

# Use .NET Registry API directly — PowerShell's registry provider treats * as a
# wildcard and would iterate thousands of keys instead of targeting the literal * key.
$RegBase = 'Software\Classes\*\shell\Open in MDPreview'
$MenuKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($RegBase)
$MenuKey.SetValue('', 'Open in MDPreview')
$MenuKey.Close()
$CmdKey  = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey("$RegBase\command")
$CmdKey.SetValue('', $Command)
$CmdKey.Close()

Write-Host ''
Write-Host '[OK] Context menu entry added.'
Write-Host '  Right-click any file -> "Open in MDPreview"'
Write-Host ''
Write-Host 'To remove:'
Write-Host "  Remove-Item -Recurse 'HKCU:\Software\Classes\*\shell\Open in MDPreview'"
