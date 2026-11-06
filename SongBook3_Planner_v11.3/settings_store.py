"""Local disk persistence for SongBook Planner. No third-party packages."""
from __future__ import annotations

import json
import os
import tempfile
import threading
from pathlib import Path

# These are independent, human-readable documents. A valid players.json can still
# be recovered if an unrelated setlist file is deleted, and vice versa.
FILES = {
    'players.json': ('members',),
    'instrument-profiles.json': ('capacities', 'profiles'),
    'setlists.json': ('libraryFingerprint', 'setlist', 'assignments', 'playedAs', 'locks', 'activeSetlistId', 'workingSetlistName'),
    'saved-setlists.json': ('savedSetlists',),
    'song-corrections.json': ('libraryFingerprint', 'overrides', 'titles'),
    'ui-preferences.json': ('currentDirectory', 'treeExpanded'),
}
TYPES = {
    'members': list, 'capacities': dict, 'profiles': dict, 'setlist': list,
    'assignments': dict, 'playedAs': dict, 'locks': dict, 'overrides': dict,
    'titles': dict, 'treeExpanded': list, 'currentDirectory': str,
    'libraryFingerprint': str, 'activeSetlistId': str, 'workingSetlistName': str,
    'savedSetlists': dict,
}


class SettingsStore:
    def __init__(self, root: Path):
        self.root = Path(root)
        self.root.mkdir(parents=True, exist_ok=True)
        self._lock = threading.RLock()

    def _read_json(self, name):
        path = self.root / name
        if not path.exists():
            return None
        try:
            with path.open('r', encoding='utf-8') as f:
                value = json.load(f)
            if not isinstance(value, dict):
                raise ValueError('expected an object')
            return value
        except (OSError, ValueError) as exc:
            # Never overwrite a corrupted file with defaults without warning.
            raise ValueError(f'Cannot read {path}: {exc}') from exc

    def read(self):
        with self._lock:
            merged = {}
            for name, fields in FILES.items():
                obj = self._read_json(name)
                if obj is not None:
                    for field in fields:
                        if field in obj:
                            merged[field] = obj[field]
            metadata = self._read_json('metadata.json')
            if metadata:
                merged['revision'] = metadata.get('revision', 0)
            return merged

    def has_saved_settings(self):
        return any((self.root / name).is_file() for name in FILES)

    def _atomic_json(self, name, obj):
        temp_name = None
        try:
            with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8',
                                             prefix='.songbook-', suffix='.tmp',
                                             dir=self.root, delete=False) as handle:
                temp_name = handle.name
                json.dump(obj, handle, indent=2, ensure_ascii=False)
                handle.write('\n')
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(temp_name, self.root / name)
        finally:
            if temp_name and os.path.exists(temp_name):
                os.unlink(temp_name)

    def write(self, incoming, library_fingerprint):
        if not isinstance(incoming, dict):
            raise ValueError('Settings must be a JSON object.')
        for field, expected_type in TYPES.items():
            if field in incoming and not isinstance(incoming[field], expected_type):
                raise ValueError(f'Invalid settings value for {field}.')
        if incoming.get('libraryFingerprint') != library_fingerprint:
            raise ValueError('Library changed. Refresh the planner before saving settings.')
        if len(incoming.get('members', [])) > 99:
            raise ValueError('Too many band members.')
        if len(incoming.get('setlist', [])) > 15000:
            raise ValueError('Setlist exceeds the supported limit.')
        named = incoming.get('savedSetlists', {})
        if len(named) > 500:
            raise ValueError('Too many saved setlists (maximum 500).')
        for identifier, entry in named.items():
            if not isinstance(identifier, str) or len(identifier) > 150 or not isinstance(entry, dict):
                raise ValueError('Invalid saved setlist identifier or record.')
            if not isinstance(entry.get('name'), str) or not entry['name'].strip() or len(entry['name']) > 100:
                raise ValueError('Invalid saved setlist name.')
            if entry.get('libraryFingerprint') != library_fingerprint:
                raise ValueError('Saved setlist belongs to another song library.')
            if not isinstance(entry.get('setlist'), list) or len(entry['setlist']) > 15000:
                raise ValueError('Invalid saved song list.')
            if any(not isinstance(i, int) or isinstance(i,bool) or i<0 for i in entry['setlist']):
                raise ValueError('Invalid song index in a saved setlist.')
            for field in ('assignments','playedAs','locks'):
                if not isinstance(entry.get(field), dict):
                    raise ValueError('Invalid saved setlist assignments.')
        revision = incoming.get('revision')
        if not isinstance(revision, int) or isinstance(revision, bool) or revision < 1:
            raise ValueError('Missing or invalid settings revision.')
        with self._lock:
            metadata = self._read_json('metadata.json') or {}
            if revision <= metadata.get('revision', 0):
                return False
            for name, fields in FILES.items():
                self._atomic_json(name, {key: incoming[key] for key in fields if key in incoming})
            # Commit marker is written only after all other files are safely replaced.
            self._atomic_json('metadata.json', {'schemaVersion': 1, 'revision': revision})
            return True
