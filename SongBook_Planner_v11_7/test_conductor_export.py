"""Offline regression tests for the new dedicated Planner -> Conductor export."""
import unittest
from songbook_planner import export_conductor_setlist


class ConductorExportTest(unittest.TestCase):
    def setUp(self):
        self.songs = [{
            'filepath': '/home/user/Documents/The Lord of the Rings Online/Music/Songs/MixedCase/',
            'filename': 'Autumn Dance',
            'title': 'Autumn Dance',
            'tracks': [{'id': '7', 'instrument': 'Basic Harp'},
                       {'id': '13', 'instrument': 'Basic Lute'}]
        }]
        self.members = [{'id': 1, 'name': 'Sinduriel'}, {'id': 2, 'name': 'Arvael'}]

    def test_export_uses_original_ids_and_performed_instruments(self):
        result = export_conductor_setlist(self.songs, [0, 0],
            {'0:0': 1, '0:1': 2}, {'0:0': 'Misty Mountain Harp'}, self.members, 'Autumn')
        self.assertEqual(result['format'], 'lotro-conductor-setlist')
        self.assertEqual(len(result['songs']), 2)
        self.assertEqual(result['songs'][0]['gamePath'], '/Songs/MixedCase/Autumn Dance')
        self.assertEqual([p['trackId'] for p in result['songs'][0]['parts']], [7, 13])
        self.assertEqual(result['songs'][0]['parts'][0]['instrument'], 'Misty Mountain Harp')

    def test_nested_lowercase_songs_directory_kept(self):
        self.songs[0]['filepath'] = '/home/ava/.steam/compatdata/212500/pfx/drive_c/users/steamuser/Documents/The Lord of the Rings Online/music/songs/Condensed Music/2 Parts/'
        self.songs[0]['filename'] = 'Amaranth2'
        result = export_conductor_setlist(self.songs, [0], {}, {}, self.members, 'Paths')
        self.assertEqual(result['songs'][0]['gamePath'], '/songs/Condensed Music/2 Parts/Amaranth2')

    def test_relative_songbook_path_preserves_root_and_case(self):
        self.songs[0]['filepath'] = r'Songs\MusicSubFolderA\More Parts'
        result = export_conductor_setlist(self.songs, [0], {}, {}, self.members, 'Paths')
        self.assertEqual(result['songs'][0]['gamePath'], '/Songs/MusicSubFolderA/More Parts/Autumn Dance')

    def test_no_songs_component_keeps_existing_relative_paths(self):
        self.songs[0]['filepath'] = 'Folk/Acoustic'
        result = export_conductor_setlist(self.songs, [0], {}, {}, self.members, 'Paths')
        self.assertEqual(result['songs'][0]['gamePath'], '/Folk/Acoustic/Autumn Dance')

    def test_unassigned_preserved_as_information(self):
        result = export_conductor_setlist(self.songs, [0], {'0:0': 1}, {}, self.members, 'Incomplete')
        self.assertEqual(result['songs'][0]['unassignedTrackIds'], [13])
        self.assertEqual(len(result['songs'][0]['parts']), 1)

    def test_bad_track_id_is_not_invented(self):
        self.songs[0]['tracks'][0]['id'] = ''
        with self.assertRaisesRegex(ValueError, 'X: ID'):
            export_conductor_setlist(self.songs, [0], {}, {}, self.members, 'Bad')

    def test_same_character_twice_is_blocked(self):
        with self.assertRaisesRegex(ValueError, 'twice'):
            export_conductor_setlist(self.songs, [0], {'0:0':1, '0:1':1}, {}, self.members, 'Bad')

    def test_unconfigured_planner_member_is_blocked(self):
        with self.assertRaisesRegex(ValueError, 'character names'):
            export_conductor_setlist(self.songs, [0], {'0:0':1}, {}, [{'id':1,'name':'Player 1'}], 'Bad')


if __name__ == '__main__':
    unittest.main()
