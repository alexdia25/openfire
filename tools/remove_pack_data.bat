@echo off
rem Deletes the game data Open Fire converted from your Return Fire install. Settings are kept.
set "DIR=%APPDATA%\OpenFire\packs\original_pc"
if not exist "%DIR%" (
  echo Nothing to remove: "%DIR%" does not exist.
  pause
  exit /b 0
)
echo This will delete:
echo   %DIR%
echo Your Return Fire install is not touched; Open Fire will offer the import again on next launch.
set /p OK=Type Y to continue: 
if /i not "%OK%"=="Y" (
  echo Cancelled.
  pause
  exit /b 1
)
rmdir /s /q "%DIR%"
if exist "%DIR%" (echo Could not remove it. Is Open Fire still running?) else (echo Removed.)
pause
