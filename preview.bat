@echo off
cd /d "%~dp0"
echo [729] Closing running 729 app...
taskkill /im class_729.exe /f >nul 2>&1
timeout /t 1 /nobreak >nul
echo [729] Building release preview...
call flutter build windows --release
if errorlevel 1 goto buildfail
for %%f in ("build\windows\x64\runner\Release\*.exe") do (
  start "" "%%f"
  goto done
)
:done
echo Preview opened. You can close this window.
timeout /t 3 >nul
exit /b 0

:buildfail
echo BUILD FAILED. Copy the error above and send it to Claude.
pause
exit /b 1
