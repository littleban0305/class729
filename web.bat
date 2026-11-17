@echo off
cd /d "%~dp0"
echo [729 web] 1/2 Building teacher website...
call flutter build web --release --base-href /class729-updater/
if errorlevel 1 goto buildfail
echo [729 web] 2/2 Publishing to GitHub Pages (gh-pages branch of class729-updater)...
set "OUT=%TEMP%\729_web_publish"
if exist "%OUT%" rmdir /s /q "%OUT%"
mkdir "%OUT%"
xcopy /e /i /y /q "build\web\*" "%OUT%\" >nul
type nul > "%OUT%\.nojekyll"
pushd "%OUT%"
git init -q
git checkout -q -b gh-pages
git add -A
git commit -q -m "teacher web %date% %time%"
git push -f https://github.com/littleban0305/class729-updater.git gh-pages
if errorlevel 1 goto pushfail
popd
echo.
echo DONE! Teacher website: https://littleban0305.github.io/class729-updater/
echo (It can take 1-2 minutes for GitHub Pages to update.)
pause
exit /b 0

:buildfail
echo BUILD FAILED. Copy the error above and send it to Claude.
pause
exit /b 1

:pushfail
popd
echo PUSH FAILED. Copy the message above and send it to Claude.
pause
exit /b 1
