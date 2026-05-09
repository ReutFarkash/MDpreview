@echo off
:: Thin wrapper so users can double-click without changing their PS execution policy.
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0install.ps1"
pause
