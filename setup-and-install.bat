@echo off
echo =============================================
echo   MDPreview Setup
echo =============================================
echo.

echo Step 1/2 — Setting up the MDPreview vault...
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0setup.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Setup failed. See error above.
    pause
    exit /b 1
)

echo.
echo Step 2/2 — Adding right-click context menu entry...
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0install.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Install failed. See error above.
    pause
    exit /b 1
)

echo.
echo =============================================
echo   Done!
echo   Right-click any .md file and choose
echo   "Open in MDPreview", then press Ctrl+E
echo   in Obsidian for reading mode.
echo =============================================
pause
