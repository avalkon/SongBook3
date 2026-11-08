@echo off
cd /d "%~dp0"

set "DATA=%USERPROFILE%\Documents\The Lord of the Rings Online\PluginData\elbeval\AllServers"

python songbook_planner.py "%DATA%\SongBook3Data.plugindata" --setlists "%DATA%\SongBook3Setlists.plugindata"

pause
