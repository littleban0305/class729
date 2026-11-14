@echo off
cd /d "%~dp0"
echo [729] Closing running 729 app...
taskkill /im class_729.exe /f >nul 2>&1
timeout /t 1 /nobreak >nul
echo [729] 1/5 Bump version...
powershell -NoProfile -Command "$p='pubspec.yaml'; $t=[IO.File]::ReadAllText($p); if($t -match 'version:\s*(\d+\.\d+\.\d+)\+(\d+)'){ $v=$matches[1]+'+'+([int]$matches[2]+1); $t=$t -replace 'version:\s*\d+\.\d+\.\d+\+\d+', ('version: '+$v); [IO.File]::WriteAllText($p,$t); [IO.File]::WriteAllText('.729_version',$v) } else { exit 1 }"
if errorlevel 1 goto noversion
set /p VER=<.729_version
echo New version: %VER%
echo [729] 2/5 Building release...
call flutter build windows --release
if errorlevel 1 goto buildfail
echo [729] 3/5 Copying files to dist\729 ...
if exist "dist\729" rmdir /s /q "dist\729"
mkdir "dist\729"
xcopy /e /i /y /q "build\windows\x64\runner\Release\*" "dist\729\" >nul
if exist "dist\729\729_error_log.txt" del "dist\729\729_error_log.txt"
if exist "%SystemRoot%\System32\msvcp140.dll" copy /y "%SystemRoot%\System32\msvcp140.dll" "dist\729\" >nul
if exist "%SystemRoot%\System32\vcruntime140.dll" copy /y "%SystemRoot%\System32\vcruntime140.dll" "dist\729\" >nul
if exist "%SystemRoot%\System32\vcruntime140_1.dll" copy /y "%SystemRoot%\System32\vcruntime140_1.dll" "dist\729\" >nul
echo [729] 4/5 Zipping to dist\729.zip ...
if exist "dist\729.zip" del "dist\729.zip"
powershell -NoProfile -Command "Compress-Archive -Path 'dist\729\*' -DestinationPath 'dist\729.zip'"
echo [729] 5/5 Uploading to GitHub Releases...
where gh >nul 2>&1
if errorlevel 1 goto manual
gh release create "v%VER%" "dist\729.zip" -R littleban0305/class729-updater --title "v%VER%" --notes "729 v%VER%"
if errorlevel 1 goto uploadfail
echo.
echo DONE! School PC will auto-update to v%VER% next time the app opens.
pause
exit /b 0

:manual
echo GitHub CLI (gh) not installed. Upload manually:
echo   1. Browser will open the "new release" page
echo   2. Tag: v%VER%
echo   3. Drag dist\729.zip in, then click Publish release
start "" "https://github.com/littleban0305/class729-updater/releases/new"
explorer "dist"
pause
exit /b 0

:noversion
echo Cannot read version in pubspec.yaml (must look like 1.0.1+3)
pause
exit /b 1

:buildfail
echo BUILD FAILED. Copy the error above and send it to Claude.
pause
exit /b 1

:uploadfail
echo UPLOAD FAILED. Run "gh auth login" first, then try again.
pause
exit /b 1
