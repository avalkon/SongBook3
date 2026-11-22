#!/bin/sh
DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
# Python handles local copies as the default. Forward an explicit
# library location and/or --setlists without inserting a second positional path.
exec python3 "$DIR/songbook_planner.py" "$@"
