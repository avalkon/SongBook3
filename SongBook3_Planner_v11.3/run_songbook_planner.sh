#!/bin/sh
DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
exec python3 "$DIR/songbook_planner.py" "$DIR/SongBook3Data.plugindata"
