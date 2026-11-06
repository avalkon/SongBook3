@echo off
rem Launch the SongBook3 Windows library builder on systems with MSHTA installed.
start "" "%SystemRoot%\System32\mshta.exe" "%~dp0SongBook3_LibraryBuilder.hta"
