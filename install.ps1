#Requires -Version 5.1
<#
.SYNOPSIS
    Add "Open in MDPreview" to the Windows right-click context menu.
.DESCRIPTION
    Writes per-user registry entries under HKCU — no admin rights required.
    Run install.bat to execute this without changing your execution policy.
#>

$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
$PsScript  = Join-Path $ScriptDir 'md-preview.ps1'

if (-not (Test-Path $PsScript)) {
    Write-Error "md-preview.ps1 not found at: $PsScript"
    exit 1
}

$MenuKey    = 'HKCU:\Software\Classes\*\shell\Open in MDPreview'
$CommandKey = "$MenuKey\command"
$Command    = "powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File `"$PsScript`" `"%1`""

New-Item    -Path $MenuKey    -Force | Out-Null
Set-ItemProperty -Path $MenuKey -Name '(Default)' -Value 'Open in MDPreview'

New-Item    -Path $CommandKey -Force | Out-Null
Set-ItemProperty -Path $CommandKey -Name '(Default)' -Value $Command

Write-Output ''
Write-Output '✓ Context menu entry added.'
Write-Output '  Right-click any file → "Open in MDPreview"'
Write-Output ''
Write-Output 'To remove:'
Write-Output "  Remove-Item -Recurse 'HKCU:\Software\Classes\*\shell\Open in MDPreview'"
