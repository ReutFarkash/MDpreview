#Requires -Version 5.1
try {
    $PsScript = Join-Path $PSScriptRoot 'md-preview.ps1'
    if (-not (Test-Path $PsScript)) {
        throw "md-preview.ps1 not found next to this script. Make sure fix-registry.ps1 is in the MDPreview-Windows folder."
    }

    $PS      = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
    $Command = "`"$PS`" -ExecutionPolicy Bypass -NoProfile -File `"$PsScript`" `"%1`""
    $RegBase = 'Software\Classes\*\shell\Open in MDPreview'

    $MenuKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($RegBase)
    $MenuKey.SetValue('', 'Open in MDPreview')
    $MenuKey.Close()

    $CmdKey = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey("$RegBase\command")
    $CmdKey.SetValue('', $Command)
    $CmdKey.Close()

    Write-Host '[OK] Done. Right-click any file -> Show more options -> Open in MDPreview'
} catch {
    Write-Host "ERROR: $_"
}
Read-Host "Press Enter to close"
