@echo off
cd /d "%~dp0"
echo [729] 1/2 Push source code to GitHub...
git add -A
git commit -m "729 update %date% %time%"
git push
if errorlevel 1 goto pushfail
echo [729] 2/2 Build and publish release (pack.bat)...
call "%~dp0pack.bat"
exit /b 0

:pushfail
echo PUSH FAILED. Copy the message above and send it to Claude.
echo (If it says "nothing to commit", that is fine - continuing to release.)
pause
call "%~dp0pack.bat"
exit /b 0
