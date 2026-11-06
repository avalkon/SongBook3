#!/bin/sh
DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
exec python3 "$DIR/songbook_planner.py" "/home/USERNAMEHERE/.steam/debian-installation/steamapps/compatdata/212500/pfx/drive_c/users/steamuser/Documents/The Lord of the Rings Online/PluginData/ACCOUNTNAMEHERE/AllServers/SongBook3Data.plugindata" --setlists "/home/USERNAMEHERE/.steam/debian-installation/steamapps/compatdata/212500/pfx/drive_c/users/steamuser/Documents/The Lord of the Rings Online/PluginData/ACCOUNTNAMEHERE/AllServers/SongBook3Setlists.plugindata" "$@"
