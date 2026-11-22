@echo off
setlocal
cd /d "%~dp0"
where py >nul 2>nul
if %ERRORLEVEL% EQU 0 (
  py -3 "%~dp0songbook_planner.py" %*
) else (
  python "%~dp0songbook_planner.py" %*
)
if errorlevel 1 (
  echo.
  echo The SongBook planner exited with an error.
  pause
)
