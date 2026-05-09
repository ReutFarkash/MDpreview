@echo off
:: Run set-default.ps1 without changing your PowerShell execution policy.
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0set-default.ps1"
pause
