#Requires -Version 5.1
<#
.SYNOPSIS
    Build MDPreview.exe and set it as the default app for .md files.
.DESCRIPTION
    Compiles a tiny .exe launcher in the same folder, registers it as a
    per-user file handler, then tells you how to complete the association
    through the Windows "Open with" dialog. No admin rights required.
    Run set-default.bat to execute this without changing your execution policy.
#>

$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
$ExePath   = Join-Path $ScriptDir 'MDPreview.exe'
$PsScript  = Join-Path $ScriptDir 'md-preview.ps1'

if (-not (Test-Path $PsScript)) {
    Write-Host "[!] md-preview.ps1 not found at: $PsScript"
    exit 1
}

Write-Host ''
Write-Host 'Step 1/2: Compiling MDPreview.exe...'

$source = @"
using System;
using System.Diagnostics;
using System.IO;
using System.Reflection;

public class MDPreview {
    [STAThread]
    public static void Main(string[] args) {
        if (args.Length == 0) return;
        string dir = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location);
        string ps  = Path.Combine(dir, "md-preview.ps1");
        string pw  = Path.Combine(Environment.GetEnvironmentVariable("SystemRoot"),
                         @"System32\WindowsPowerShell\v1.0\powershell.exe");
        Process.Start(new ProcessStartInfo {
            FileName        = pw,
            Arguments       = "-ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File \"" + ps + "\" \"" + args[0] + "\"",
            UseShellExecute = false,
            CreateNoWindow  = true
        });
    }
}
"@

Add-Type -TypeDefinition $source -Language CSharp -OutputAssembly $ExePath -OutputType WindowsApplication
Write-Host "[OK] Created: $ExePath"

Write-Host ''
Write-Host 'Step 2/2: Registering file handler...'

$ProgBase = 'Software\Classes\MDPreview.md'

$k = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey($ProgBase)
$k.SetValue('', 'Markdown Preview')
$k.Close()

$k = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey("$ProgBase\shell\open\command")
$k.SetValue('', "`"$ExePath`" `"%1`"")
$k.Close()

$k = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Software\Classes\.md\OpenWithProgids')
$k.SetValue('MDPreview.md', [byte[]]@(), [Microsoft.Win32.RegistryValueKind]::Binary)
$k.Close()

Write-Host '[OK] Handler registered.'
Write-Host ''
Write-Host 'Last step (manual - takes 30 seconds):'
Write-Host '  1. Right-click any .md file -> Open with -> Choose another app'
Write-Host '  2. Click "Look for another app on this PC"'
Write-Host "  3. Navigate to: $ExePath"
Write-Host '  4. Check "Always use this app to open .md files" -> OK'
Write-Host ''
