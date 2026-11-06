-- Shared helpers and list controls live with the main windows.
import "Sinduriel.SongBook3.Windows.Main.Helpers";
import "Sinduriel.SongBook3.Windows.Main.ListControls";
-- Main window class is loaded before modules that extend or use it.
import "Sinduriel.SongBook3.Windows.Main.SongBook3Window";
import "Sinduriel.SongBook3.Windows.Setlists.SessionHistory";
-- Main windows and auxiliary UI.
import "Sinduriel.SongBook3.Windows.Main.HelpWindow";
import "Sinduriel.SongBook3.Windows.Main.TimerWindow";
import "Sinduriel.SongBook3.Windows.Main.MatchedSongsWindow";
import "Sinduriel.SongBook3.Windows.Main.PlayerSyncInfo";
import "Sinduriel.SongBook3.Windows.Setlists.SetlistsWindow";
import "Sinduriel.SongBook3.Windows.Setlists.ShareSetlistWindow";
import "Sinduriel.SongBook3.Windows.Setlists.ImportSetlistWindow";
import "Sinduriel.SongBook3.Windows.Main.SyncCheckWindow";
import "Sinduriel.SongBook3.Windows.Lyrics.LyricsWindow";
import "Sinduriel.SongBook3.Windows.Main.SettingsWindow";
import "Sinduriel.SongBook3.Windows.Main.ToggleWindow";
