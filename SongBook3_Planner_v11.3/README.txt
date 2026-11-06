SongBook3 Setlist Planner v11.3
============================

WHAT'S NEW IN v11.3
-------------------
Named saved setlists, independent of your autosaved working setlist:

- Enter a name (e.g. Friday Night) and click "Save setlist".
- Select a saved setlist from the dropdown and click "Load" to restore its
  song order, player assignments, actual instruments used, and part locks.
- Rename or Delete saved setlists, or choose New / empty to start another list.
- Edits to the current working list autosave, but do not overwrite a named
  snapshot until you explicitly choose "Save setlist" again.
- Exporting a named setlist creates setlist-Friday-Night.ods, using your name.
  Blank names retain the former songbook-setlist.ods filename. Library export
  continues to produce songbook-library.ods.
- Named copies are stored in settings/saved-setlists.json; the current working
  setlist remains in settings/setlists.json. Other settings stay unchanged.
- Backups exported through "Export full settings backup" include named setlists.
- Existing settings files are compatible. Copy the old settings/ folder
  into this version's directory before starting, to keep your data.

PREVIOUS v11.1 FEATURES
-----------------------
- A Shut down button in the header saves settings and stops the local web server.
  It asks for confirmation and will not stop the server if saving fails.
  The browser shows a finished screen; you may close its tab manually.

Player lists and all planner settings are now saved automatically as readable JSON
files under the local settings/ directory, rather than relying on browser storage.
The application still keeps a browser recovery copy and supports manual JSON backup
export/import. All setlist, player-assignment, specialty, lock, and ODS export
features from v10.1 remain available.

RUNNING
-------
1. Extract the ZIP. Stop the previous SongBook Planner first (port 8765).
2. On Linux/macOS, open the SongBook_Planner_v11_3 folder and run:
      chmod +x run_songbook_planner.sh
      ./run_songbook_planner.sh
3. On Windows: run `python songbook_planner.py` from the extracted folder.
4. Open http://127.0.0.1:8765 if a browser does not open automatically.
5. Install odfpy for OpenDocument (.ods) exports:
      python3 -m pip install odfpy
6. Click "Shut down" in the app header, and confirm. The program saves your
   latest settings to disk before stopping the local server. Ctrl+C also works.


WHERE SETTINGS ARE STORED
-------------------------
All files live inside the extracted SongBook_Planner_v11_3/settings/ folder:

  settings/
    players.json                 member names and playable instruments
    instrument-profiles.json     capacities and named profiles
    setlists.json                current working song order, player assignments,
                                 actual instruments played, locked parts
    saved-setlists.json          named setlist snapshots, including assignments
    song-corrections.json        song titles and per-part instrument corrections
    ui-preferences.json          selected directory and expanded folder tree
    metadata.json                revision counter for ordered/autosaved writes

The JSON files are generated as soon as you first open the program in a browser
and are rewritten after changes. The old browser localStorage record remains
as a safety copy, but the settings/ files are authoritative after first save.

To back up everything, copy the whole settings/ folder while the program is
stopped. Alternatively, use "Export full settings backup" in the app.

UPGRADING AGAIN LATER
---------------------
When replacing the entire program directory, copy your settings/ folder into
the newer release's program directory. Do not overwrite your newer settings
with an empty settings/ folder from a fresh ZIP. You can also import your
saved JSON backup instead of copying files.

If the SongBook3Data.plugindata library changes, numeric song IDs may change.
The app intentionally retains player names, skills, capacities, and profiles,
but clears incompatible song-specific setlists, assignments, and corrections.
Export a JSON backup before replacing the library file.

To edit JSON files by hand, stop the program, edit the file, and then restart;
otherwise the next UI change could overwrite your manual edits.

The program binds only to 127.0.0.1 and does not send your library or settings
to any cloud service.

ABOUT THE REST OF THE PLANNER
-----------------------------
- Recursive directory browsing and scoped song/artist searches
- Player skills and instrument capacity profiles
- Specialist-first assignments, player locking, reassignment and approved
  substitute instruments
- Optimizing setlist order for fewer musician instrument changes
- ODS setlist export with Player Timeline FIRST, followed by Setlist,
  Change Log, and Legend
- Original full-library ODS export with song/artist/track details

The bundled SongBook3Data.plugindata contains 7,202 songs / 20,202 tracks.
You can provide a different file by running:
  python3 songbook_planner.py /path/to/SongBook3Data.plugindata

NAMED SETLIST NOTES
-------------------
Snapshots reference song indexes from your SongBook3Data.plugindata. Loading a
setlist saved with a different library version is blocked, to avoid corrupting
track/part assignments. If you change your song library, back up settings before upgrading. Setlist names may contain spaces; the exported .ods filename uses safe hyphens and characters.
