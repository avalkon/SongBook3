-- Earlier edition by Almiyan --


SongBook3Window = class( Turbine.UI.Window );

-- Shared modules live in sibling package namespaces.
local SongBook3EnsureDirectories = Sinduriel.SongBook3.Windows.Main.SongBook3EnsureDirectories;
local SongBook3ImmediateChild = Sinduriel.SongBook3.Windows.Main.SongBook3ImmediateChild;
local SongBook3SongPath = Sinduriel.SongBook3.Windows.Main.SongBook3SongPath;
local SongBook3PathHash = Sinduriel.SongBook3.Windows.Main.SongBook3PathHash;
local SongBook3EncodePath = Sinduriel.SongBook3.Windows.Main.SongBook3EncodePath;
local SongBook3DecodePath = Sinduriel.SongBook3.Windows.Main.SongBook3DecodePath;
local ListBoxScrolled = Sinduriel.SongBook3.Windows.Main.ListBoxScrolled;
local ListBoxCharColumn = Sinduriel.SongBook3.Windows.Main.ListBoxCharColumn;

SongBook3LyricsDB = nil;

selectedSong = ""; -- set the default song
selectedSongIndex = 1;
selectedTrack = 1;
selectedDir = "/"; -- set the default dir
dirPath = {}; -- table holding directory path
dirPath[1] = "/"; -- set first item as root dir

librarySize = 0;

--

HelpWindow_Load_Flag = 1;
Synced_Song_TrackName = "";
SelectedMatchedSong_Index = 1;
--MatchedSongsIndex = {};
OtherPlayer_Synced = 1;
Multiple_songs_match_Synced = 0;
YouDontHaveTheSameSong_Flag = 0;
InstrumentSlots_Shift = 45;
OtherPlayer_SyncedSong_Filepath = "";
OtherPlayer_SyncedSong_Filename = "";
OtherPlayer_SyncedSong_Index = 1;
OtherPlayer_SyncedSong_IndexListBox = 1;
GroupIsRaid = 0;
PlayerCantUseUserChat_Message = 0;
UserChatName = "";
Chatchannel = "/f";
selectedSongIndexListBox = 0;
syncSlot_Correct_Instrument = 0;
ShiftTop = 50;
UserChatNumber = 0;
PlayerSynced = 0;
syncedSongIndex = -1;
syncedTrack = -1;

--

SongBook3Load = Turbine.PluginData.Load;
SongBook3Save = Turbine.PluginData.Save;

Settings = { WindowPosition = { Left = "300", Top = "20", Width = "700", Height = "700" + ShiftTop }, WindowVisible = "no", WindowOpacity="0.9", DirHeight = "100", TracksHeight = "150", TracksVisible = "yes", ToggleVisible = "yes", ToggleLeft = "10", ToggleTop = "10", ToggleOpacity = "1", SearchVisible = "yes", DescriptionVisible = "no", DescriptionFirst = "no", ShowArtist = "no", ArtistAfterTime = "no", UserChatName = "" , PlayersSyncInfoWindowPosition = { Left = "350", Top = "100", Width = "400", Height = "300" } , 
Timer_WindowPosition = { Left = "50", Top = "1" } , TimerWindowVisible = "true" , UseRaidChat = "false", UseFellowshipChat = "false", AutoPickOnSongChange = "true", AutoPickOnInsChange = "true", hideMatchedSongsPopup = "false",
HelpWindowDisable = "false", LyricsPrefix = "~", LyricsCommentPrefix = "%",
LyricsIgnoreBlankLines = "true", LyricsDelay = "0", LyricsDirHeight = "90", LyricsFileHeight = "125",
LyricsWindowPosition = { Left = "420", Top = "120", Width = "620", Height = "620" } }; -- default values

-- Sync Start confirmation integrated into the Sync Check window.

--

CharSettings = {
};

-- if (lang == "de" or lang == "fr") then	
	-- if (Turbine.Engine.GetLocale() == "de" or Turbine.Engine.GetLocale() == "fr") then
		-- Settings.WindowOpacity = "0,9";
	-- end
-- end
euroFormat=(tonumber("1,000")==1);
if euroFormat then
	Settings.WindowOpacity = "0,9";
	Settings.ToggleOpacity = "1";
end

SongDB = {
	Directories = {
	},
	Songs = {	
	}
};

function SongBook3Window:Constructor()
	Turbine.UI.Lotro.Window.Constructor( self );
	
	SongDB = SongBook3Load( Turbine.DataScope.Account , "SongBook3Data") or SongDB;
	SongBook3EnsureDirectories(SongDB);
	table.sort(SongDB.Songs, sortby_Name);
    SongBook3LyricsDB = SongBook3Load(Turbine.DataScope.Account, "SongBook3Lyrics") or
        { Directories = { "/" }, Lyrics = { } };
    if type(SongBook3LyricsDB) ~= "table" then SongBook3LyricsDB = { Directories = { "/" }, Lyrics = { } }; end
    if type(SongBook3LyricsDB.Lyrics) ~= "table" then SongBook3LyricsDB.Lyrics = { }; end
    SongBook3EnsureDirectories(SongBook3LyricsDB);
    self.lyricLinks = SongBook3Load(Turbine.DataScope.Account, "SongBook3LyricLinks") or { };
    if type(self.lyricLinks) ~= "table" then self.lyricLinks = { }; end
	SettingsTemp = SongBook3Load( Turbine.DataScope.Account , gSettings) or Settings;
	if SettingsTemp.Timer_WindowPosition then
		Settings = SettingsTemp;
	end
	
	CharSettingsTemp = SongBook3Load( Turbine.DataScope.Character , gSettings) or CharSettings;
	if CharSettingsTemp.InstrSlots then 
		if CharSettingsTemp.InstrSlots[1] then
			CharSettings = CharSettingsTemp;
		end
	end
	
	-- Variables for filters and setups

	self.bArtistSearch = false -- show/hide artist search
	self.bLeaderMode = true -- enables sync start shortcut, uses party object (seems to work for FS leader)
	self.aFilteredIndices = { } -- Array for filtered indices, k = display index; v = SongDB index
    -- Cached lowercase text and directory/path lookups: constructed once per library load.
    self.searchIndex = { };
    self.songsByDirectory = { };
    self.songByPath = { };
    self.songByHash = { };
    self.songsByFilename = { };
    for i, song in ipairs(SongDB.Songs or {}) do
        local trackNames = { };
        for _, track in ipairs(song.Tracks or {}) do
            trackNames[#trackNames + 1] = track.Name or "";
            -- Make instruments from %%part-name searchable as well as visible.
            if track.PartName then trackNames[#trackNames + 1] = track.PartName; end
        end
        self.searchIndex[i] = string.lower(
            (song.Filepath or "") .. " " .. (song.Filename or "") .. " " .. table.concat(trackNames, " "));
        local directory = song.Filepath or "/";
        if not self.songsByDirectory[directory] then self.songsByDirectory[directory] = { }; end
        table.insert(self.songsByDirectory[directory], i);
        local key = SongBook3SongPath(song);
        self.songByPath[key] = i;
        local hash = SongBook3PathHash(key);
        if not self.songByHash[hash] then self.songByHash[hash] = { }; end
        table.insert(self.songByHash[hash], i);
        local filename = string.lower(song.Filename or "");
        if not self.songsByFilename[filename] then self.songsByFilename[filename] = { }; end
        table.insert(self.songsByFilename[filename], i);
    end
    -- Keep collections as relative paths, not database row numbers (rebuild safe).
    self.setlistData = SongBook3Load(Turbine.DataScope.Account, "SongBook3Setlists") or
        { names = { "Main Setlist" }, lists = { ["Main Setlist"] = { } }, active = "Main Setlist" };
    if type(self.setlistData) ~= "table" or type(self.setlistData.lists) ~= "table" then
        self.setlistData = { names = { "Main Setlist" }, lists = { ["Main Setlist"] = { } }, active = "Main Setlist" };
    end
    if type(self.setlistData.names) ~= "table" then self.setlistData.names = { "Main Setlist" }; end
    if #self.setlistData.names == 0 then
        self.setlistData.names[1] = "Main Setlist";
        self.setlistData.lists["Main Setlist"] = { };
    end
    self.activeSetlist = self.setlistData.active;
    if not self.setlistData.lists[self.activeSetlist] then self.activeSetlist = self.setlistData.names[1]; end
    self.activeSetlistPosition = 0;
    self.setlistActiveTab = "Setlists";
    -- Session history is an ordered play log.
    -- Each playback gets its own entry so repeated performances stay visible.
    self.sessionPlayed = { }; -- per-path play counts, used for bookkeeping
    self.sessionPlayedOrder = { };
    self.sessionNextEntryId = 0;
    self.sessionVisibleEntries = { };
    self.sessionSelectedEntryId = nil;
    self.sessionSelectedPath = nil;
    self.lyricEntries = { };
    self.lyricEntriesByDirectory = { };
    self.lyricDirectories = { "/" };
    self.lyricByKey = { };
    self.selectedLyricDir = "/";
    self.selectedLyricEntry = nil;
    self.currentLyricLines = { };
    self.selectedLyricLine = 0;
    self:BuildLyricsLibrary();
	self.aPlayers = { } -- k = player name, v = ready track, 0 if no track ready
	self.aPlayers_sync_msg = { }
	self.nPlayers = 0 -- number of players (unfortunately not as simple as #self.aPlayers)
	self.aCurrentSongReady = { } -- k = player name; v = track ready state (see GetTrackReadyState())
	self.aReadyTracks = "" -- indicates which tracks are ready (A = 1st, B = 2nd, etc). Used for setup checks
	self.aSetupTracksIndices = { } -- when tracks are filtered for a setup, this array contains track indices
	self.aSetupListIndices = { } -- list index for tracks that are part of the currently selected setup
	self.iCurrentSetup = nil -- indicates which setup is currently selected
	self.selectedSetupCount = 'A' -- Stores the code of the current setup to select it on song change, if available
	self.maxPartCount = nil -- the number of parts to use as filter (nil if not filtering, else player count)
	self.alignTracksRight = false -- if true, track names are listed right-aligned (resize will reset to left aligned)
	self.listboxSetupsWidth = 20 -- width of the setups listbox (to the left of the tracks list)
	self.setupsWidth = self.listboxSetupsWidth + 10 -- total width of setup list including scrollbar
	self.bShowSetups = false -- show/hide setups (autohide for songs with no setups defined)
	
	
	self.Players_Data = { } ;
    -- Keep instrument reports separately: LOTRO's normal /play sync chat
    -- overwrites aPlayers with only the track title, losing the instrument.
    self.bandSyncReports = {};
	self.TimerWindowVisible = true;
	self.UseRaidChat = false;
	self.UseFellowshipChat = false;
	self.HelpWindowDisable = false;
	
	-- colours for the different track/player ready states in the track and player listboxes
	self.colourDefaultHighlighted = Turbine.UI.Color( 1, 0.15, 0.95, 0.15 )
	self.colourReadyHighlighted = Turbine.UI.Color( 1, 0.40, 0.8, 0.15 )
	--self.colourReadyHighlighted = Turbine.UI.Color( 1, 0.15, 0.60, 0.15 )
	self.colourSyncedHighlighted = Turbine.UI.Color( 1, 1, 1, 0 )
	self.colourSyncedHighlighted_notSelected = Turbine.UI.Color( 1, 0.80, 0.80, 0.15 )
	self.colourReadyMultipleHighlighted = Turbine.UI.Color( 1, 0.7, 0.7, 1 )
	self.colourReadyMultipleHighlighted_synced = Turbine.UI.Color( 1, 0.7, 0.7, 0.80 )
	self.colourReadyMultipleHighlighted_synced_notSelected = Turbine.UI.Color( 1, 0.6, 0.6, 0.70 )
	self.colourDefault = Turbine.UI.Color( 1, 1, 1, 1 )
	--self.colourReady = Turbine.UI.Color( 1, 0.15, 0.70, 0 )
	--self.colourReady = Turbine.UI.Color( 1, 0.4, 0.8, 0.8 )
	self.colourReady = Turbine.UI.Color( 1, 0.4, 0.4, 0 )
	self.colourReadyMultiple = Turbine.UI.Color( 1, 0.6, 0.6, 0.95 )
	self.colourDifferentSong = Turbine.UI.Color( 1, 0, 0 )
	self.colourDifferentSetup = Turbine.UI.Color( 1, 0.6, 0 )
	self.colourWrongInstrument = Turbine.UI.Color( 1, 0.2, 0 )
	self.colourWrongInstrument_synced = Turbine.UI.Color( 1, 0.5, 0 )
	self.colourWrongInstrument_notSelected = Turbine.UI.Color( 1, 0.3, 0 )
	self.colourWrongInstrument_notSelected_synced = Turbine.UI.Color( 1, 0.6, 0 )
	self.colourWrongInstrumentMultiple = Turbine.UI.Color( 1, 0.4, 0.9 )
	self.colourReadyMultiple2 = Turbine.UI.Color( 1, 0.4, 0.9 )
	self.colourWrongInstrumentMultiple_notSelected = Turbine.UI.Color( 1, 0.1, 0.9 )
	self.colourWrongInstrumentMultiple_synced = Turbine.UI.Color( 1, 0.6, 1 )
	self.colourWrongInstrumentMultiple_synced_notSelected = Turbine.UI.Color( 1, 0.5, 1 )
	self.backColourDefault = Turbine.UI.Color( 1, 0, 0, 0 )
	self.backColourHighlight = Turbine.UI.Color( 1, 0.1, 0.1, 0.1 )
	self.backColourHighlight_self = Turbine.UI.Color( 1, 0.1, 0.15, 0.1 )
	self.backColourHighlight_wrong = Turbine.UI.Color( 1, 0.15, 0.15, 0.1 )
	self.backColourHighlight_Multiple = Turbine.UI.Color( 1, 0.15, 0.15, 0.2 )
	self.backColourHighlight_Multiple_synced = Turbine.UI.Color( 1, 0.15, 0.15, 0.15 )
	self.backColourWrongInstrument = Turbine.UI.Color( 1, 0.15	, 0.1, 0.1 )
	self.backColourWrongInstrument_ready = Turbine.UI.Color( 1, 0.2, 0.1, 0.1 )
	
	self.backColour_synced = Turbine.UI.Color( 1, 0.1, 0.1, 0 )
	self.backColour_synced_multiple = Turbine.UI.Color( 1, 0.1, 0.1, 0.15 )
	
	self.colourMessageTitle = Turbine.UI.Color( 1, 0.8, 0.8, 0 )
	self.colour_syncMessageTitle = Turbine.UI.Color( 1, 0, 1, 1 )
	self.colour_syncMessageTitle_OnlySynced = Turbine.UI.Color( 1, 1, 1, 0 )
	self.colour_syncMessageTitle_Back = Turbine.UI.Color( 1, 0.1, 0.2, 0.2 )
	self.colour_syncMessageTitle_Highlighted = Turbine.UI.Color( 1, 0, 0.8, 1 )
	self.colour_syncMessageTitle_Highlighted_OnlySynced = Turbine.UI.Color( 1, 1, 0.8, 0 )
	self.colour_syncMessageTitle_MouseDown = Turbine.UI.Color( 1, 0, 0.8, 0.8 )
	self.colour_syncMessageTitle_MouseDown_OnlySynced = Turbine.UI.Color( 1, 0.8, 0.8, 0 )
	
	
	self.bCheckInstrument = true
	self.bInstrumentOk = true
	self.aInstruments = { "bagpipe", "clarinet", "cowbell", "drum", "flute", "harp", "horn", "lute", "pibgorn", "theorbo"  }
	
	self.Instruments_List = {
	{"Basic Harp"},
	{"Misty Mountain Harp", "Summer Celebration Mountain Harp"},
	{"Basic Lute", "Summer Celebration Lute"},
	{"Lute of Ages"},
	{"Basic Theorbo"},
	{"Traveller's Trusty Fiddle"},
	{"Bardic Fiddle"},
	{"Basic Fiddle"},
	{"Lonely Mountain Fiddle", "Summer Celebration Fiddle"},
	{"Sprightly Fiddle"},
	{"Student's Fiddle"},
	{"Basic Bagpipe"},
	{"Basic Bassoon"},
	{"Brusque Bassoon"},
	{"Lonely Mountain Bassoon"},
	{"Basic Clarinet"},
	{"Basic Flute"},
	{"Basic Horn"},
	{"Basic Pibgorn"},
	{"Basic Cowbell", "Summer Celebration Cowbell"},
	{"Moor Cowbell"},
	{"Basic Drum"},
	{"Jaunty Hand-knells"} }
	
	self.Instruments_Names_inTrack = {
	{"Basic Harp"}, -- 1
	{"Misty Mountain Harp", "Misty Harp", "MM Harp", "MMH", "Mountain Harp", "Mountains Harp", "Misty_Mountains_Harp"}, -- 2
	{"Basic Lute", "New Lute", "LuteB", "BLute", "B Lute"}, -- 3
	{"Lute of Ages", "Lute of Age", "Age Lute", "Ages Lute", "LuteA", "LOA", "Lute OA", "Lute_of_Ages"}, -- 4
	{"Basic Theorbo", "Theorbo", " Theo "}, -- 5
	{"Traveller's Trusty Fiddle", "Traveller's Fiddle", "Travellers Fiddle", "Traveller Fiddle", "Traveler Fiddle", "Trusty Fiddle", "TT Fiddle", "TTF", "Traveler's_Trusty_Fiddle"}, -- 6
	{"Bardic Fiddle", "Bardic_Fiddle"}, -- 7
	{"Basic Fiddle", "B Fiddle", "BFiddle"}, -- 8
	{"Lonely Mountain Fiddle", "Lonely Fiddle", "LM Fiddle", "LMFiddle", "LMF", "Mountain Fiddle", "Mountains Fiddle", "Lonely_Mountain_Fiddle"}, -- 9
	{"Sprightly Fiddle", "Spright Fiddle", "Sprightly_Fiddle"}, -- 10
	{"Student's Fiddle", "Students Fiddle", "Student Fiddle"}, -- 11
	{"Basic Bagpipe", "Bagpipe", "Bag pipe"}, -- 12
	{"Basic Bassoon"}, -- 13
	{"Brusque Bassoon", "Brusk Bassoon"}, -- 14
	{"Lonely Mountain Bassoon", "Lonely Bassoon", "LM Bassoon", "Mountain Bassoon", "Mountains Bassoon", "Lonely_Mountain_Bassoon"}, -- 15
	{"Basic Clarinet", "Clarinet"}, -- 16
	{"Basic Flute", "Flute"}, -- 17
	{"Basic Horn", "Horn"}, -- 18
	{"Basic Pibgorn", "Pibgorn"}, -- 19
	{"Basic Cowbell"}, -- 20
	{"Moor Cowbell", "More Cowbell"}, -- 21
	{"Basic Drum", "Drum"},
	{"Jaunty Hand-knells", "Hand-knells", "Jaunty", "Glockenspiel", "Dingy Thingy", "Jaunty_Hand-Knells"}  } -- 22
	
	self.aSpecialInstruments = { }
	self.aSpecialInstruments[ "satakieli" ] = 6 -- index in the insturments array
	self.bTimer = true
	self.bTimerCountdown = true
	
	self.bShowReadyChars = true
	self.bHighlightReadyCol = true
	self.chNone = " "
	self.chReady = "~"
	self.chWrongSong = "S"
	self.chWrongPart = "P"
	self.chMultiple = "M"
	
	-- Legacy fixes
	
	if not CharSettings.UserChatNumber then CharSettings.UserChatNumber = 0; end
	if not CharSettings.InstrumentSlots_Rows then CharSettings.InstrumentSlots_Rows = 1; end
	
	if not Settings.UserChatName then
		Settings.UserChatName = "";
	end
	-- if not Settings.PlayersSyncInfoWindowPosition.Left then Settings.PlayersSyncInfoWindowPosition.Left = 350 end
	-- if not Settings.PlayersSyncInfoWindowPosition.Top then Settings.PlayersSyncInfoWindowPosition.Top = 100 end
	-- if not Settings.PlayersSyncInfoWindowPosition.Width then Settings.PlayersSyncInfoWindowPosition.Width = 400 end
	-- if not Settings.PlayersSyncInfoWindowPosition.Height then Settings.PlayersSyncInfoWindowPosition.Height = 300 end
	
	
	if not Settings.DirHeight then
		Settings.DirHeight = "100";
	end
	if not Settings.TracksHeight then
		Settings.TracksHeight = "150";
	end
	if not Settings.TracksVisible then
		Settings.TracksVisible = "yes";
	end
	if not WindowVisible then
		WindowVisible = "no";
	end	
	if not Settings.SearchVisible then
		Settings.SearchVisible = "yes";	
	end
	if not Settings.DescriptionVisible then
		Settings.DescriptionVisible = "no";	
	end
	if not Settings.DescriptionFirst then
		Settings.DescriptionFirst = "no";	
	end
	-- Added for the optional artist credit in song-list descriptions.
	-- Missing keys in older saved settings retain the original display.
	if not Settings.ShowArtist then Settings.ShowArtist = "no"; end
	if not Settings.ArtistAfterTime then Settings.ArtistAfterTime = "no"; end
	
	if not Settings.ToggleOpacity then
		Settings.ToggleOpacity = 1;
	end		

	-- Migrate the old filter-panel visibility preference on first run.
	if not Settings.ArtistSearchVisible then
		Settings.ArtistSearchVisible = Settings.FiltersState == "true" and "true" or "false";
	end		
	if not Settings.ChiefMode then Settings.ChiefMode = "true"; end		
	if not Settings.TimerState then Settings.TimerState = "true"; end
	if not Settings.TimerCountdown then Settings.TimerCountdown = "true"; end		
 	if not Settings.ReadyColState then Settings.ReadyColState = "true"; end
 	if not Settings.ReadyColHighlight then Settings.ReadyColHighlight = "true"; end
	
 	if not Settings.TimerWindowVisible then Settings.TimerWindowVisible = "true"; end
	self:ToggleTimerWindow( Settings.TimerWindowVisible == "true" )
	
	if not Settings.HelpWindowDisable then Settings.HelpWindowDisable = "false"; end
	self:SetHelpWindowDisabled( Settings.HelpWindowDisable == "true" )
	Sinduriel.SongBook3.Windows.Main.Help_Window_CB:SetChecked(Settings.HelpWindowDisable == "true" );
	
	if not Settings.UseRaidChat       then Settings.UseRaidChat 	  = "false"; end
	if not Settings.UseFellowshipChat then Settings.UseFellowshipChat = "false"; end
	self:ToggleUseRaidChat	    ( Settings.UseRaidChat 	     == "true" )
	self:ToggleUseFellowshipChat( Settings.UseFellowshipChat == "true" )

	if not Settings.AutoPickOnSongChange then Settings.AutoPickOnSongChange = "true"; end
	if not Settings.AutoPickOnInsChange then Settings.AutoPickOnInsChange = "true"; end

	if not Settings.hideMatchedSongsPopup then Settings.hideMatchedSongsPopup = "false"; end
    if Settings.LyricsPrefix == nil then Settings.LyricsPrefix = "~"; end
    if Settings.LyricsCommentPrefix == nil then Settings.LyricsCommentPrefix = "%"; end
    if Settings.LyricsIgnoreBlankLines == nil then Settings.LyricsIgnoreBlankLines = "true"; end
    if Settings.LyricsDelay == nil then Settings.LyricsDelay = "0"; end
    local initialLyricsDelay = tonumber(Settings.LyricsDelay) or 0;
    initialLyricsDelay = math.max(0, math.min(5, math.floor(initialLyricsDelay)));
    Settings.LyricsDelay = tostring(initialLyricsDelay);
    if Settings.LyricsDirHeight == nil then Settings.LyricsDirHeight = "90"; end
    if Settings.LyricsFileHeight == nil then Settings.LyricsFileHeight = "125"; end
    if type(Settings.LyricsWindowPosition) ~= "table" then
        Settings.LyricsWindowPosition = { Left = "420", Top = "120", Width = "620", Height = "620" };
    end
    if Settings.LyricsWindowPosition.Left == nil then Settings.LyricsWindowPosition.Left = "420"; end
    if Settings.LyricsWindowPosition.Top == nil then Settings.LyricsWindowPosition.Top = "120"; end
    if Settings.LyricsWindowPosition.Width == nil then Settings.LyricsWindowPosition.Width = "620"; end
    if Settings.LyricsWindowPosition.Height == nil then Settings.LyricsWindowPosition.Height = "620"; end
	
	if not SongDB.Songs then
		SongDB = {
			Directories = {
			},
			Songs = {	
			}
		};
	end		
	
	if not Settings.Commands then
		Settings.Commands = {};		
		Settings.Commands["1"] = { Title = Strings["cmd_demo1_title"], Command = Strings["cmd_demo1_cmd"] };
		Settings.Commands["2"] = { Title = Strings["cmd_demo2_title"], Command = Strings["cmd_demo2_cmd"] };
		Settings.Commands["3"] = { Title = Strings["cmd_demo3_title"], Command = Strings["cmd_demo3_cmd"] };
		Settings.DefaultCommand = "1";
	end

	CharSettings.InstrumentSlots_Rows = tonumber(CharSettings.InstrumentSlots_Rows);
	
	if not CharSettings.InstrSlots then
		CharSettings.InstrSlots = {};
		for j = 1, CharSettings.InstrumentSlots_Rows do
			table.insert(CharSettings.InstrSlots , {});
			CharSettings.InstrSlots[j]["visible"] = "yes";
			CharSettings.InstrSlots[j]["number"] = 11;
			for i = 1, CharSettings.InstrSlots[j]["number"] do
				CharSettings.InstrSlots[j][tostring(i)] = { qsType = "", qsData = "" };		
			end
		end
	end
	for j = 1, CharSettings.InstrumentSlots_Rows do
		if not CharSettings.InstrSlots[j]["number"] then
			CharSettings.InstrSlots[j]["number"] = 11;
		end
	end
	for j = 1, CharSettings.InstrumentSlots_Rows do
		for i = 1, CharSettings.InstrSlots[j]["number"] do
			CharSettings.InstrSlots[j][tostring(i)].qsType = tonumber(CharSettings.InstrSlots[j][tostring(i)].qsType);
		end	
	end
	
	UserChatName = string.lower ( Settings.UserChatName );
	
	-- unstringify settings
	Settings.WindowPosition.Left = tonumber(Settings.WindowPosition.Left);
	Settings.WindowPosition.Top = tonumber(Settings.WindowPosition.Top);
	Settings.WindowPosition.Width = tonumber(Settings.WindowPosition.Width);
	Settings.WindowPosition.Height = tonumber(Settings.WindowPosition.Height);
	self:ValidateWindowPosition( Settings.WindowPosition )
	Settings.ToggleTop = tonumber(Settings.ToggleTop);
	Settings.ToggleLeft = tonumber(Settings.ToggleLeft);
	Settings.DirHeight = tonumber(Settings.DirHeight);
	Settings.TracksHeight = tonumber(Settings.TracksHeight);
	Settings.WindowOpacity = tonumber(Settings.WindowOpacity);
	Settings.ToggleOpacity = tonumber(Settings.ToggleOpacity);
	for j = 1, CharSettings.InstrumentSlots_Rows do
		CharSettings.InstrSlots[j]["number"] = tonumber(CharSettings.InstrSlots[j]["number"]);
	end
	
	Settings.PlayersSyncInfoWindowPosition.Left = tonumber(Settings.PlayersSyncInfoWindowPosition.Left);
	Settings.PlayersSyncInfoWindowPosition.Top = tonumber(Settings.PlayersSyncInfoWindowPosition.Top);
	Settings.PlayersSyncInfoWindowPosition.Width = tonumber(Settings.PlayersSyncInfoWindowPosition.Width);
	Settings.PlayersSyncInfoWindowPosition.Height = tonumber(Settings.PlayersSyncInfoWindowPosition.Height);
	
	Settings.Timer_WindowPosition.Left = tonumber(Settings.Timer_WindowPosition.Left);
	Settings.Timer_WindowPosition.Top = tonumber(Settings.Timer_WindowPosition.Top);
	
	-- Fix to prevent window or toggle to travel outside of the screen
	local displayWidth, displayHeight = Turbine.UI.Display.GetSize();
	
	if Settings.WindowPosition.Width + 0 > displayWidth then
		Settings.WindowPosition.Width = displayWidth - 0;
	end
	if Settings.WindowPosition.Height + 0 > displayHeight then
		Settings.WindowPosition.Height = displayHeight - 0;
		Settings.TracksHeight = Settings.WindowPosition.Height / 7;
	end
	if Settings.WindowPosition.Left + Settings.WindowPosition.Width > displayWidth then
		Settings.WindowPosition.Left = displayWidth - Settings.WindowPosition.Width;
	end
	if Settings.WindowPosition.Top + Settings.WindowPosition.Height > displayHeight then
		Settings.WindowPosition.Top = displayHeight - Settings.WindowPosition.Height;
	end
	if Settings.WindowPosition.Left < 0 then
		Settings.WindowPosition.Left = 0;
	end
	if Settings.WindowPosition.Top < 0 then
		Settings.WindowPosition.Top = 0;
	end	
	if Settings.ToggleLeft + 0 > displayWidth then
		Settings.ToggleLeft = displayWidth - 0;
	end
	if Settings.ToggleTop + 0 > displayHeight then
		Settings.ToggleTop = displayHeight - 0;
	end
	if Settings.ToggleLeft < 0 then
		Settings.ToggleLeft = 0;
	end
	if Settings.ToggleTop < 0 then
		Settings.ToggleTop = 0;
	end
	
--------------------------------------------------------------------------
	if Settings.PlayersSyncInfoWindowPosition.Width + 0 > displayWidth then
		Settings.PlayersSyncInfoWindowPosition.Width = displayWidth - 0;
	end
	if Settings.PlayersSyncInfoWindowPosition.Height + 0 > displayHeight then
		Settings.PlayersSyncInfoWindowPosition.Height = displayHeight - 0;
	end
	if Settings.PlayersSyncInfoWindowPosition.Left + Settings.PlayersSyncInfoWindowPosition.Width > displayWidth then
		Settings.PlayersSyncInfoWindowPosition.Left = displayWidth - Settings.PlayersSyncInfoWindowPosition.Width;
	end
	if Settings.PlayersSyncInfoWindowPosition.Top + Settings.PlayersSyncInfoWindowPosition.Height > displayHeight then
		Settings.PlayersSyncInfoWindowPosition.Top = displayHeight - Settings.PlayersSyncInfoWindowPosition.Height;
	end
	if Settings.PlayersSyncInfoWindowPosition.Left < 0 then
		Settings.PlayersSyncInfoWindowPosition.Left = 0;
	end
	if Settings.PlayersSyncInfoWindowPosition.Top < 0 then
		Settings.PlayersSyncInfoWindowPosition.Top = 0;
	end
--------------------------------------------------------------------------
	
--------------------------------------------------------------------------
	if Settings.Timer_WindowPosition.Left + Sinduriel.SongBook3.Windows.Main.Timer_Window_Width > displayWidth then
		Settings.Timer_WindowPosition.Left = displayWidth - Sinduriel.SongBook3.Windows.Main.Timer_Window_Width;
	end
	if Settings.Timer_WindowPosition.Top + Sinduriel.SongBook3.Windows.Main.Timer_Window_Height > displayHeight then
		Settings.Timer_WindowPosition.Top = displayHeight - Sinduriel.SongBook3.Windows.Main.Timer_Window_Height;
	end
	if Settings.Timer_WindowPosition.Left < 0 then
		Settings.Timer_WindowPosition.Left = 0;
	end
	if Settings.Timer_WindowPosition.Top < 0 then
		Settings.Timer_WindowPosition.Top = 0;
	end
--------------------------------------------------------------------------

	-- Hide UI when F12 is pressed
	local hideUI = false;
	local wasVisible;
	local settingsWindowWasVisible;
	local Timer_WindowWasVisible;
	local PlayersSyncInfoWindowWasVisible;
    local LyricsWindowWasVisible;
	self:SetWantsKeyEvents(true);

	self.KeyDown = function(sender, args)
		
		------------------------------------------------------
		
		if (args.Action == 268435635) then
			if not hideUI then
				hideUI = true;
				if self:IsVisible() then
					wasVisible = true;
					self:SetVisible(false);					
				else
					wasVisible = false;
				end
				toggleWindow:SetVisible(false);
				
				if settingsWindow:IsVisible() then
					settingsWindowWasVisible = true;
					settingsWindow:SetVisible(false);					
				else
					settingsWindowWasVisible = false;
				end
				
				if Sinduriel.SongBook3.Windows.Main.PlayersSyncInfoWindow:IsVisible() then
					PlayersSyncInfoWindowWasVisible = true;
					Sinduriel.SongBook3.Windows.Main.PlayersSyncInfoWindow:SetVisible(false);
				else
					PlayersSyncInfoWindowWasVisible = false;
				end
				
				if Sinduriel.SongBook3.Windows.Main.Timer_Window:IsVisible() then
					Timer_WindowWasVisible = true;
					Sinduriel.SongBook3.Windows.Main.Timer_Window:SetVisible(false);
				else
					Timer_WindowWasVisible = false;
				end
                if self.lyricsWindow and self.lyricsWindow:IsVisible() then
                    LyricsWindowWasVisible = true;
                    self.lyricsWindow:SetVisible(false);
                else
                    LyricsWindowWasVisible = false;
                end
			else
				hideUI = false;
				if wasVisible then
					self:SetVisible(true);
					self:Activate();
				end
				if (Settings.ToggleVisible == "yes") then
					toggleWindow:SetVisible(true);
				end
				
				if settingsWindowWasVisible then
					settingsWindow:SetVisible(true);
					settingsWindow:Activate();					
				end
				if PlayersSyncInfoWindowWasVisible then
					Sinduriel.SongBook3.Windows.Main.PlayersSyncInfoWindow:SetVisible(true);
					Sinduriel.SongBook3.Windows.Main.PlayersSyncInfoWindow:Activate();
				end
				if Timer_WindowWasVisible then
					Sinduriel.SongBook3.Windows.Main.Timer_Window:SetVisible(true);
					Sinduriel.SongBook3.Windows.Main.Timer_Window:Activate();
				end
                if LyricsWindowWasVisible and self.lyricsWindow then
                    self.lyricsWindow:SetVisible(true);
                    self.lyricsWindow:Activate();
                end
			end
		
		------------------------------------------------------
		
		--elseif (args.Action == 268435635) then
			
		end
	end
	
	librarySize = #SongDB.Songs;
	
	self:SetPosition( Settings.WindowPosition.Left, Settings.WindowPosition.Top );
	self:SetSize( math.max(461, Settings.WindowPosition.Width), Settings.WindowPosition.Height );
	--self:SetZOrder(10);
	
	Sinduriel.SongBook3.Windows.Main.PlayersSyncInfoWindow:SetPosition( Settings.PlayersSyncInfoWindowPosition.Left, Settings.PlayersSyncInfoWindowPosition.Top );
	Sinduriel.SongBook3.Windows.Main.PlayersSyncInfoWindow:SetSize( Settings.PlayersSyncInfoWindowPosition.Width, Settings.PlayersSyncInfoWindowPosition.Height );
	Sinduriel.SongBook3.Windows.Main.SyncInfolistbox:SetSize( Sinduriel.SongBook3.Windows.Main.PlayersSyncInfoWindow:GetWidth() - 60 , Sinduriel.SongBook3.Windows.Main.PlayersSyncInfoWindow:GetHeight() - 80  );
	Sinduriel.SongBook3.Windows.Main.scrollBarV:SetPosition(Sinduriel.SongBook3.Windows.Main.SyncInfolistbox:GetLeft() + Sinduriel.SongBook3.Windows.Main.SyncInfolistbox:GetWidth(), Sinduriel.SongBook3.Windows.Main.SyncInfolistbox:GetTop());
	Sinduriel.SongBook3.Windows.Main.scrollBarV:SetSize(10,Sinduriel.SongBook3.Windows.Main.SyncInfolistbox:GetHeight());
	Sinduriel.SongBook3.Windows.Main.scrollBarH:SetPosition(Sinduriel.SongBook3.Windows.Main.SyncInfolistbox:GetLeft(),Sinduriel.SongBook3.Windows.Main.SyncInfolistbox:GetHeight() + Sinduriel.SongBook3.Windows.Main.SyncInfolistbox:GetTop());
	Sinduriel.SongBook3.Windows.Main.scrollBarH:SetSize(Sinduriel.SongBook3.Windows.Main.SyncInfolistbox:GetWidth(), 10);
	Sinduriel.SongBook3.Windows.Main.PlayersSyncInfoWindow.resizeCtrl:SetPosition(Sinduriel.SongBook3.Windows.Main.PlayersSyncInfoWindow:GetWidth() - 20,Sinduriel.SongBook3.Windows.Main.PlayersSyncInfoWindow:GetHeight() - 20);
	
	Sinduriel.SongBook3.Windows.Main.Timer_Window:SetPosition( Settings.Timer_WindowPosition.Left, Settings.Timer_WindowPosition.Top );
	
	self:SetOpacity( Settings.WindowOpacity );
	--self:SetText("SongBook3 " .. Plugins[gPlugin]:GetVersion() .. Strings["title"] );
	self:SetText("SongBook3");
	
	self.Version = Turbine.UI.Label();
	self.Version:SetParent( self );
	self.Version:SetFont(Turbine.UI.Lotro.Font.Verdana12);
	self.Version:SetForeColor( self.colourMessageTitle );
	self.Version:SetPosition( 40, 25 );
	self.Version:SetSize(50, 14);
	self.Version:SetText("V1.25.4");
	
	self.minWidth = 461;
	self.minHeight = 308;
	self.lFXmod = 23; -- listFrame x coord modifier
	self.lCXmod = 28; -- listContainer x coord modifier (original value was 42)

	if (CharSettings.InstrSlots[1]["visible"] == "yes") then
		self.lFYmod = 214 + ShiftTop + InstrumentSlots_Shift * ( CharSettings.InstrumentSlots_Rows - 1 ); -- listFrame     y coord modifier = difference between bottom pixels and window bottom
		self.lCYmod = 233 + ShiftTop + InstrumentSlots_Shift * ( CharSettings.InstrumentSlots_Rows - 1 ); -- listContainer y coord modifier = difference between bottom pixels and window bottom
	else
		self.lFYmod = 169 + ShiftTop + 0 * ( CharSettings.InstrumentSlots_Rows - 1 ) ; -- listFrame     y coord modifier = difference between bottom pixels and window bottom
		self.lCYmod = 188 + ShiftTop + 0 * ( CharSettings.InstrumentSlots_Rows - 1 ) ; -- listContainer y coord modifier = difference between bottom pixels and window bottom
	end
	
	-- Frame for the song list
	self.listFrame = Turbine.UI.Control();
	self.listFrame:SetParent( self );
	self.listFrame:SetBackColor( Turbine.UI.Color(1, 0.15, 0.15, 0.15) );
	self.listFrame:SetPosition(12, 134 + ShiftTop);
	--self.listFrame:SetSize(self:GetWidth() - self.lFXmod, self:GetHeight() - self.lFYmod);
	self.listContainer = Turbine.UI.Control();
	self.listContainer:SetParent( self );
	self.listContainer:SetBackColor( Turbine.UI.Color(1,0,0,0) );
	self.listContainer:SetPosition(18, 147 + ShiftTop);
	--self.listContainer:SetSize(self:GetWidth() - self.lCXmod, self:GetHeight() - self.lCYmod);

	-- outer frame title
	self.listFrame.heading = Turbine.UI.Label();
	self.listFrame.heading:SetParent( self.listFrame );
	self.listFrame.heading:SetLeft(5);
	self.listFrame.heading:SetSize(self.listFrame:GetWidth(),13);
	self.listFrame.heading:SetFont( Turbine.UI.Lotro.Font.TrajanPro13 );
	self.listFrame.heading:SetText( Strings["ui_dirs"] );
	
	-- separator1 between dir list and song list
	self.separator1 = self:CreateMainSeparator( Settings.DirHeight );
	self.separator1:SetVisible(true);
	-- separator1 title
	self.separator1.heading = self:CreateSeparatorHeading( self.separator1, Strings["ui_songs"] );
	-- separator1 hint arrows
	self.sArrows1 = self:CreateSeparatorArrows( self.separator1 )
	
	-- separator2 between song list and track list
	self.sepSongsTracks = self:CreateMainSeparator( self.listContainer:GetHeight() - Settings.TracksHeight - 13 );
	-- separator2 title
	self.sepSongsTracks.heading = self:CreateSeparatorHeading( self.sepSongsTracks, Strings["ui_parts"] );
	-- separator2 hint arrows
	self.sArrows2 = self:CreateSeparatorArrows( self.sepSongsTracks )

	-- Tooltip
	self.tipLabel = Turbine.UI.Label();
	self.tipLabel:SetParent( self );
	self.tipLabel:SetPosition( self:GetWidth() - 270, 27 + ShiftTop);
	self.tipLabel:SetSize(245, 30);
	self.tipLabel:SetTextAlignment( Turbine.UI.ContentAlignment.MiddleRight );
	self.tipLabel:SetText("");
	
	-- Music mode button
	self.musicSlot = self:CreateMainShortcut(20);
	-- Trying to fix the problem with unresponsive buttons. Haven't found out yet how to disable
	-- dragging from a quickslot altogether, so for now this just restores the shortcut.
	self.musicSlotShortcut = Turbine.UI.Lotro.Shortcut( Turbine.UI.Lotro.ShortcutType.Alias, Strings["cmd_music"]);
	self.musicSlot.DragDrop =
	function( sender, args )
		if( self.musicSlotShortcut ) then
			self.musicSlot:SetShortcut( self.musicSlotShortcut ); -- restore shortcut
		end
	end
	self.musicSlot:SetShortcut( self.musicSlotShortcut );
	self.musicSlot:SetVisible( true );
	
	-- Play button
	self.playSlot = self:CreateMainShortcut(60);
	self.playSlot.DragDrop =
	function( sender, args )
		if( self.playSlotShortcut ) then
			self.playSlot:SetShortcut( self.playSlotShortcut ); -- restore shortcut
		end
	end
	
	-- Ready check button
	self.readySlot = self:CreateMainShortcut(120);
	self.readySlot:SetShortcut( Turbine.UI.Lotro.Shortcut( Turbine.UI.Lotro.ShortcutType.Alias, Strings["cmd_ready"]));
	
	-- Sync play button
	self.syncSlot = self:CreateMainShortcut(161);
	self.syncSlot.DragDrop =
	function( sender, args )
		if( self.syncSlotShortcut ) then
			self.syncSlot:SetShortcut( self.syncSlotShortcut ); -- restore shortcut
		end
	end
	
--
	-- Announce Song button (uses the original send quickslot position)
	self.sendSyncInfoSlot = self:CreateMainShortcut(202);
	self.sendSyncInfoSlot.DragDrop =
	function( sender, args )
		if( self.sendSyncInfoSlotShortcut ) then
			self.sendSyncInfoSlot:SetShortcut( self.sendSyncInfoSlotShortcut ); -- restore shortcut
		end
	end

--

	-- Start sync play button
	self.syncStartSlot = self:CreateMainShortcut(287);
	--self.syncStartSlotShortcut = Turbine.UI.Lotro.Shortcut( Turbine.UI.Lotro.ShortcutType.Alias, Strings["cmd_start"] );
	self.syncStartSlotShortcut = Turbine.UI.Lotro.Shortcut( Turbine.UI.Lotro.ShortcutType.Undefined , "" );
	self.syncStartSlot.DragDrop =
	function( sender, args )
		if( self.syncStartSlotShortcut ) then
			self.syncStartSlot:SetShortcut( self.syncStartSlotShortcut ); -- restore shortcut
		end
	end
	self.syncStartSlot:SetShortcut(self.syncStartSlotShortcut);
	
	-- Share button
	self.shareSlot = self:CreateMainShortcut(328);
	if (Settings.Commands[Settings.DefaultCommand]) then
		self.shareSlot:SetShortcut( Turbine.UI.Lotro.Shortcut( Turbine.UI.Lotro.ShortcutType.Alias, self:ExpandCmd(Settings.DefaultCommand)));
	end
	
--

	-- List Channels button
	self.listchannelsSlot = self:CreateMainShortcut(369);
	self.listchannelsSlotShortcut = Turbine.UI.Lotro.Shortcut( Turbine.UI.Lotro.ShortcutType.Alias, "/listchannels" );
	self.listchannelsSlot.DragDrop =
	function( sender, args )
		if( self.listchannelsSlotShortcut ) then
			self.listchannelsSlot:SetShortcut( self.listchannelsSlotShortcut ); -- restore shortcut
		end
	end
	self.listchannelsSlot:SetShortcut( self.listchannelsSlotShortcut );
	self.listchannelsSlot:SetVisible( true );
	
--
	-- Join User Chat button
	self.joinUserChatSlot = self:CreateMainShortcut(410);
	self.joinUserChatSlotShortcut = Turbine.UI.Lotro.Shortcut( Turbine.UI.Lotro.ShortcutType.Alias, "/joinchannel " .. UserChatName );
	self.joinUserChatSlot.DragDrop =
	function( sender, args )
		if( self.joinUserChatSlotShortcut ) then
			self.joinUserChatSlot:SetShortcut( self.joinUserChatSlotShortcut ); -- restore shortcut
		end
	end
	self.joinUserChatSlot:SetShortcut( self.joinUserChatSlotShortcut );
	self.joinUserChatSlot:SetVisible( true );
	
--
	
	-- Track label
	self.trackLabel = Turbine.UI.Label();
	self.trackLabel:SetParent( self );
	self.trackLabel:SetPosition(247, 63 + ShiftTop);
	self.trackLabel:SetSize(30, 12);
	self.trackLabel:SetZOrder(200);
	self.trackLabel:SetText("X:");

	-- Track number
	self.trackNumber = Turbine.UI.Label();
	self.trackNumber:SetParent( self );
	self.trackNumber:SetPosition(262, 63 + ShiftTop);
	self.trackNumber:SetWidth(20);
	
		
	-- actions for button mouse hovers
	self.musicSlot.MouseEnter = function(sender,args)
		self.musicIcon:SetBackground(gDir .. "icn_m_hover.tga");
		self.tipLabel:SetText(Strings["tt_music"]);
	end
	self.musicSlot.MouseLeave = function(sender,args)
		self.musicIcon:SetBackground(gDir .. "icn_m.tga");
		self.tipLabel:SetText("");
	end
	self.musicSlot.MouseDown = function(sender,args)
		self.musicIcon:SetBackground(gDir .. "icn_m_down.tga");
	end
	self.musicSlot.MouseUp = function(sender,args)
		self.musicIcon:SetBackground(gDir .. "icn_m_hover.tga");
	end
--
	self.playSlot.MouseEnter = function(sender,args)
		self.playIcon:SetBackground(gDir .. "icn_p_hover.tga");
		self.tipLabel:SetText(Strings["tt_play"]);
	end
	self.playSlot.MouseLeave = function(sender,args)
		self.playIcon:SetBackground(gDir .. "icn_p.tga");
		self.tipLabel:SetText("");
	end
	self.playSlot.MouseDown = function(sender,args)
		self.playIcon:SetBackground(gDir .. "icn_p_down.tga");
	end
	self.playSlot.MouseUp = function(sender,args)
		self.playIcon:SetBackground(gDir .. "icn_p_hover.tga");
	end
--
	self.readySlot.MouseEnter = function(sender,args)
		self.readyIcon:SetBackground(gDir .. "icn_r_hover.tga");
		self.tipLabel:SetText(Strings["tt_ready"]);
	end
	self.readySlot.MouseLeave = function(sender,args)
		self.readyIcon:SetBackground(gDir .. "icn_r.tga");
		self.tipLabel:SetText("");
	end
	self.readySlot.MouseDown = function(sender,args)
		self.readyIcon:SetBackground(gDir .. "icn_r_down.tga");
	end
	self.readySlot.MouseUp = function(sender,args)
		self.readyIcon:SetBackground(gDir .. "icn_r_hover.tga");
	end
--
	
	self.syncSlot.MouseEnter = function(sender,args)
        self:EnsureChatListener();
        if self.syncSlotSendsInfo then
            self.syncIcon:SetBackground(gDir .. "icn_send_hover.tga");
            self.tipLabel:SetText("Send Sync Info (Click Play Sync Again)");
        else
            self.syncIcon:SetBackground(gDir .. "icn_s_hover.tga");
            self.tipLabel:SetText(Strings["tt_sync"]);
        end
	end
	self.syncSlot.MouseLeave = function(sender,args)
        if self.syncSlotSendsInfo then
            self.syncIcon:SetBackground(gDir .. "icn_send.tga");
		elseif syncSlot_Correct_Instrument == 1 then
			self.syncIcon:SetBackground(gDir .. "icn_s.tga");
		else
			self.syncIcon:SetBackground(gDir .. "icn_s_f.tga");
		end
		self.tipLabel:SetText("");
	end
	self.syncSlot.MouseDown = function(sender,args)
        self.syncIcon:SetBackground(gDir .. (self.syncSlotSendsInfo and
            "icn_send_down.tga" or "icn_s_down.tga"));
	end
	self.syncSlot.MouseUp = function(sender,args)
        self.syncIcon:SetBackground(gDir .. (self.syncSlotSendsInfo and
            "icn_send_hover.tga" or "icn_s_hover.tga"));
	end

--
	self.syncSlot.MouseClick = function(sender,args)
        if args.Button ~= Turbine.UI.MouseButton.Left then return; end
        self:EnsureChatListener();
        if self.syncSlotSendsInfo then
            -- Leave the alias in place until the game echoes the chat
            -- message; changing shortcuts here may cancel their execution.
            self.syncInfoSendPending = true;
            return;
        end
		PlayerCantUseUserChat_Message = 0;
		syncedSongIndex = selectedSongIndex;
		syncedTrack = selectedTrack;
		PlayerSynced = 0;
		self:PlayerSyncInfo();
	end

--
	self.sendSyncInfoSlot.MouseEnter = function(sender,args)
        self:EnsureChatListener();
		self.sendSyncInfoIcon:SetBackground(gDir .. "icn_song_hover.tga");
		self.tipLabel:SetText("Announce Song");
	end
	self.sendSyncInfoSlot.MouseLeave = function(sender,args)
		self.sendSyncInfoIcon:SetBackground(gDir .. "icn_song.tga");
		self.tipLabel:SetText("");
	end
	self.sendSyncInfoSlot.MouseDown = function(sender,args)
		self.sendSyncInfoIcon:SetBackground(gDir .. "icn_song_down.tga");
	end
	self.sendSyncInfoSlot.MouseUp = function(sender,args)
		self.sendSyncInfoIcon:SetBackground(gDir .. "icn_song_hover.tga");
	end
	
	self.sendSyncInfoSlot.MouseClick = function(sender,args)
        self:EnsureChatListener();
        PlayerCantUseUserChat_Message = 0;
        -- The slot already contains the prepared @SBANN alias for the current
        -- selection. Do not rebuild/replace its shortcut during the click:
        -- LOTRO must execute the alias that was present when clicked.
	end
--
	
	self.listchannelsSlot.MouseEnter = function(sender,args)
		self.listchannelsIcon:SetBackground(gDir .. "icn_listchannel_hover.tga");
		self.tipLabel:SetText("Recover User Channel");
	end
	self.listchannelsSlot.MouseLeave = function(sender,args)
		self.listchannelsIcon:SetBackground(gDir .. "icn_listchannel.tga");
		self.tipLabel:SetText("");
		
		--self:PlayerSyncInfo();
	end
	self.listchannelsSlot.MouseDown = function(sender,args)
		self.listchannelsIcon:SetBackground(gDir .. "icn_listchannel_down.tga");
	end
	self.listchannelsSlot.MouseUp = function(sender,args)
		self.listchannelsIcon:SetBackground(gDir .. "icn_listchannel_hover.tga");
	end

--
	
	self.joinUserChatSlot.MouseEnter = function(sender,args)
		self.joinUserChatIcon:SetBackground(gDir .. "icn_joinchannel_hover.tga");
		self.tipLabel:SetText("Join SongBook3 User Channel");
	end
	self.joinUserChatSlot.MouseLeave = function(sender,args)
		self.joinUserChatIcon:SetBackground(gDir .. "icn_joinchannel.tga");
		self.tipLabel:SetText("");
	end
	self.joinUserChatSlot.MouseDown = function(sender,args)
		self.joinUserChatIcon:SetBackground(gDir .. "icn_joinchannel_down.tga");
	end
	self.joinUserChatSlot.MouseUp = function(sender,args)
		self.joinUserChatIcon:SetBackground(gDir .. "icn_joinchannel_hover.tga");
	end
	
--
	
	self.syncStartSlot.MouseEnter = function(sender,args)
		self.syncStartIcon:SetBackground(gDir .. "icn_ss_hover.tga");
        self:UpdateSyncStartPreflight();
		self.tipLabel:SetText(Strings["tt_start"]);
	end
	self.syncStartSlot.MouseLeave = function(sender,args)
		self.syncStartIcon:SetBackground(gDir .. "icn_ss.tga");
		self.tipLabel:SetText("");
	end
	self.syncStartSlot.MouseDown = function(sender,args)
		self.syncStartIcon:SetBackground(gDir .. "icn_ss_down.tga");
	end
	self.syncStartSlot.MouseUp = function(sender,args)
		self.syncStartIcon:SetBackground(gDir .. "icn_ss_hover.tga");
	end

--
	self.syncStartSlot.MouseClick = function(sender,args)
        if args.Button == Turbine.UI.MouseButton.Left then
            local conflicts = self:UpdateSyncStartPreflight();
            if conflicts > 0 then self:ShowReadyCheck(true); end
            -- When clear, the underlying quickslot invokes /playstart.
        end
    end
--

	self.shareSlot.MouseEnter = function(sender,args)
		self.shareIcon:SetBackground(gDir .. "icn_sh_hover.tga");
		if (Settings.Commands[Settings.DefaultCommand].Title) then
			self.tipLabel:SetText(Settings.Commands[Settings.DefaultCommand].Title);
		end
	end
	self.shareSlot.MouseLeave = function(sender,args)
		self.shareIcon:SetBackground(gDir .. "icn_sh.tga");
		self.tipLabel:SetText("");
	end
	self.shareSlot.MouseDown = function(sender,args)
		self.shareIcon:SetBackground(gDir .. "icn_sh_down.tga");
	end
	self.shareSlot.MouseUp = function(sender,args)
		self.shareIcon:SetBackground(gDir .. "icn_sh_hover.tga");
	end
------------------------------------------------------------------------------------------

	self.shareSlot.MouseWheel = function(sender,args)
		local nextCmd = tonumber(Settings.DefaultCommand) - args.Direction;
		local size = Sinduriel.SongBook3.Windows.Main.SettingsWindow:CountCmds();
		
		if (nextCmd == 0) then
			Settings.DefaultCommand = tostring(size);		
		elseif (nextCmd > size) then
			Settings.DefaultCommand = "1";		
		else
			Settings.DefaultCommand = tostring(nextCmd);		
		end
		
		self.shareSlot:SetShortcut( Turbine.UI.Lotro.Shortcut( Turbine.UI.Lotro.ShortcutType.Alias, self:ExpandCmd(Settings.DefaultCommand)));		
		self.shareSlot:SetVisible(true);
	end
	self.trackLabel.MouseClick = function(sender,args)
		if(args.Button == Turbine.UI.MouseButton.Left) then
			self:ToggleTracks();
		end
	end
	
	-- icons that hide default quick slots
	self.musicIcon = self:CreateMainIcon(20,"icn_m");
	self.playIcon = self:CreateMainIcon(60,"icn_p");
	self.readyIcon = self:CreateMainIcon(120,"icn_r");
	self.syncIcon = self:CreateMainIcon(161,"icn_s");
	self.sendSyncInfoIcon = self:CreateMainIcon(202,"icn_song");
	self.syncStartIcon = self:CreateMainIcon(287,"icn_ss");
	self.shareIcon = self:CreateMainIcon(328,"icn_sh");
	self.listchannelsIcon = self:CreateMainIcon(369,"icn_listchannel");
	self.joinUserChatIcon = self:CreateMainIcon(410,"icn_joinchannel");
	
	-- selected song display
	self.songTitle = Turbine.UI.Label();
	self.songTitle:SetParent( self );
	self.songTitle:SetFont(Turbine.UI.Lotro.Font.Verdana16);
	self.songTitle:SetForeColor( self.colourDefaultHighlighted );	
	self.songTitle:SetPosition( 23, 90 + ShiftTop);
	self.songTitle:SetSize( self:GetWidth() - 52, 16);
	
--
	
	-- Player Name and Instrument display
	self.PlayerTitle = Turbine.UI.Label();
	self.PlayerTitle:SetParent( self );
	self.PlayerTitle:SetFont(Turbine.UI.Lotro.Font.Verdana16);
	self.PlayerTitle:SetForeColor( self.colourDefaultHighlighted );
	self.PlayerTitle:SetPosition( 15, 30 );
	self.PlayerTitle:SetSize(self:GetWidth() - 30, 16);
	self.PlayerTitle:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleCenter);
	self.PlayerTitle:SetText("");
	
--

	self:UpdatePlayerTitle();
	
	self.playerEquipment.ItemEquipped = function(sender, args)
		local insIndex = self:PlayerSyncInfo();
		if insIndex == 0 then return; end
		local trackListEmpty = self.tracklistBox == nil or self.tracklistBox:GetItemCount( ) < 1
		if Settings.AutoPickOnInsChange == "true" and not trackListEmpty then
			-- Check if current track is already the right instrument
			if self:IsAvailableTrackWithMatchingInstrument(selectedSongIndex, selectedTrack, insIndex) then
				return;
			end

			local iTrack = self:GetTrackToSelect(selectedSongIndex);
			if iTrack == 0 then return; end
			if self.bShowReadyChars then iTrack = iTrack * 2; end
			self:SelectTrack(iTrack);
		end
	end
	
	
--
	
	-- SongBook3 Messages display
	self.MessageTitle = Turbine.UI.Label();
	self.MessageTitle:SetParent( self );
	self.MessageTitle:SetFont(Turbine.UI.Lotro.Font.Verdana12);
	self.MessageTitle:SetForeColor( self.colourMessageTitle );
	self.MessageTitle:SetPosition( 23, 50 );
	self.MessageTitle:SetSize(self:GetWidth() - 30, 14);
	--self.MessageTitle:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleCenter);
	
	CharSettings.UserChatNumber = tonumber(CharSettings.UserChatNumber);
	UserChatNumber = CharSettings.UserChatNumber;
	if UserChatNumber ~= 0 and UserChatNumber ~= nil then
		Chatchannel = "/" .. UserChatNumber;
		self.MessageTitle:SetText("SongBook3 is using User Chat channel " .. UserChatNumber .. " - " .. UserChatName);
	else
		self.MessageTitle:SetText("SongBook3 is using Fellowship channel");
	end
--
	
	-- Synced song Messages display
	self.syncMessageTitle = Turbine.UI.Label();
	self.syncMessageTitle:SetParent( self );
	self.syncMessageTitle:SetFont(Turbine.UI.Lotro.Font.Verdana16);
	self.syncMessageTitle:SetForeColor( self.colour_syncMessageTitle );
	self.syncMessageTitle:SetBackColor( self.backColourHighlight );
	self.syncMessageTitle:SetPosition( 23, 70 );
	self.syncMessageTitle:SetSize(self:GetWidth() - 30, 16);
	--self.syncMessageTitle:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleCenter);
	--self.syncMessageTitle:SetText("");
	self.syncMessageTitle:SetVisible(false);
	
	self.syncMessageTitle.MouseEnter = function(sender, args)
		if self.syncMessageTitle:IsVisible() then
			if OtherPlayer_Synced == 0 then
				self.syncMessageTitle:SetForeColor( self.colour_syncMessageTitle_Highlighted );
			else
				self.syncMessageTitle:SetForeColor( self.colour_syncMessageTitle_Highlighted_OnlySynced );
			end
		end
	end
	self.syncMessageTitle.MouseLeave = function(sender, args)
		if self.syncMessageTitle:IsVisible() then
			if OtherPlayer_Synced == 0 then
				self.syncMessageTitle:SetForeColor( self.colour_syncMessageTitle );
			else
				self.syncMessageTitle:SetForeColor( self.colour_syncMessageTitle_OnlySynced );
			end
		end
	end
	self.syncMessageTitle.MouseDown = function(sender,args)
		if self.syncMessageTitle:IsVisible() then
			if OtherPlayer_Synced == 0 then
				self.syncMessageTitle:SetForeColor( self.colour_syncMessageTitle_MouseDown );
			else
				self.syncMessageTitle:SetForeColor( self.colour_syncMessageTitle_MouseDown_OnlySynced );
			end
		end
	end
	self.syncMessageTitle.MouseUp = function(sender,args)
		if self.syncMessageTitle:IsVisible() then
			if OtherPlayer_Synced == 0 then
				self.syncMessageTitle:SetForeColor( self.colour_syncMessageTitle );
			else
				self.syncMessageTitle:SetForeColor( self.colour_syncMessageTitle_OnlySynced );
			end
			if Multiple_songs_match_Synced == 1 then
				Sinduriel.SongBook3.Windows.Main.MatchedSongsWindow:SetVisible( true );
			elseif YouDontHaveTheSameSong_Flag == 0 then
				self:SelectDir( nil, OtherPlayer_SyncedSong_Filepath );
				self:SelectSong(OtherPlayer_SyncedSong_IndexListBox);
				local selectedItem = self.songlistBox:GetItem( OtherPlayer_SyncedSong_IndexListBox )
				if selectedItem then selectedItem:SetForeColor( self.colourDefaultHighlighted ); end
			end
		end
	end
--

	-- search field
	self.searchInput = Turbine.UI.Lotro.TextBox();
	self.searchInput:SetParent(self);
	self.searchInput:SetPosition(17, 110 + ShiftTop);
	self.searchInput:SetSize(150, 20);
	self.searchInput:SetFont(Turbine.UI.Lotro.Font.Verdana14);
	self.searchInput:SetMultiline(false);	
	self.searchInput:SetVisible( false );
	
	self.searchInput:SetBackColor( Turbine.UI.Color( 0.2, 0.2, 0.2 ) );
		
	local searchFocus = false; 
	self.searchInput.KeyDown = function(sender, args)
		if (args.Action == 162) then
			if (searchFocus) then
				self:UpdateSongs();
			end
		end
	end
	self.searchInput.FocusGained = function(sender, args)
		searchFocus = true;
	end
	self.searchInput.FocusLost = function(sender, args)
		searchFocus = false;
	end
	
	-- search button
	self.searchBtn = Turbine.UI.Lotro.Button();
	self.searchBtn:SetParent(self);
	self.searchBtn:SetPosition(172, 110 + ShiftTop);
	self.searchBtn:SetSize(80, 20);
	self.searchBtn:SetText(Strings["ui_search"]);
	self.searchBtn:SetVisible( false );

	self.searchBtn.MouseClick = function(sender, args)
		self:UpdateSongs();
	end
	
	-- clear search button
	self.clearBtn = Turbine.UI.Lotro.Button();
	self.clearBtn:SetParent(self);
	self.clearBtn:SetPosition(255, 110 + ShiftTop);
	self.clearBtn:SetSize(70, 20);
	self.clearBtn:SetText(Strings["ui_clear"]);
	self.clearBtn:SetVisible( false );
	
	self.clearBtn.MouseClick = function(sender, args)
		self.searchInput:SetText("");
		self:UpdateSongs();
	end
	
	-- hide search components if not toggled
	if (Settings.SearchVisible == "yes") then
		self.searchInput:SetVisible( true );
		self.searchBtn:SetVisible( true );
		self.clearBtn:SetVisible( true );				
	end

	-- directory list box
	self.dirlistBox = ListBoxScrolled:New( 10 );
	self.dirlistBox:SetParent( self.listContainer );
	self.dirlistBox:SetVisible( true );
	
	-- track list box
	self.tracklistBox = ListBoxCharColumn:New( 10, 20 );
	self.tracklistBox:SetParent( self.listContainer );
	
	self:AdjustTracklistLeft( );
	-- show track components if toggled
	self:ShowTrackListbox( Settings.TracksVisible == "yes" )
	
	
	-- main song list box
	self.songlistBox = ListBoxScrolled:New( 10 );
	self.songlistBox:SetParent( self.listContainer );
	self.songlistBox:SetVisible( true );
	self.songlistBox:SetVisible( true );
	
	
	-- instrument slot containers
	self.instrContainer = {};
	
	for j = 1, CharSettings.InstrumentSlots_Rows do
		self.instrContainer[j] = Turbine.UI.Control();
		self.instrContainer[j]:SetParent( self );
		local TopShift = 75 + InstrumentSlots_Shift * ( j - 1 );
		self.instrContainer[j]:SetPosition( 10, self:GetHeight() - TopShift );
		if (CharSettings.InstrSlots[1]["visible"] == "yes") then
			self.instrContainer[j]:SetVisible( true );
		else
			self.instrContainer[j]:SetVisible( false );
		end
		self.instrContainer[j]:SetSize( 40*CharSettings.InstrSlots[j]["number"], 38 );
		self.instrContainer[j]:SetZOrder(90);
	end
	
--
	-- self.instrContainer.MouseClick = function(sender,args)
		
		-- local player = Turbine.Gameplay.LocalPlayer:GetInstance( );
		-- if not player then return; end
		-- local equip = player:GetEquipment( )
		-- if not equip then return; end
		-- local item = equip:GetItem( Turbine.Gameplay.Equipment.Instrument )
		-- if not item then return; end
		-- local equippedInstrument = item:GetName( )
		-- if not equippedInstrument then return; end

		-- local Player_Name = player:GetName();
		-- if not Player_Name then return; end

		-- self.PlayerTitle:SetText(Player_Name .. " - " .. equippedInstrument);
	-- end
--
	
	
	-- instrument slots
	self.instrSlot = { };
	
	local instrdrag = false;
	
	for j = 1, CharSettings.InstrumentSlots_Rows do
		table.insert(self.instrSlot , {});
		for i = 1, CharSettings.InstrSlots[j]["number"] do
			self.instrSlot[j][i] = Turbine.UI.Lotro.Quickslot();
			self.instrSlot[j][i]:SetParent( self.instrContainer[j] );
			self.instrSlot[j][i]:SetPosition(40*(i-1), 0);
			self.instrSlot[j][i]:SetSize(37, 37);
			self.instrSlot[j][i]:SetZOrder(100);
			self.instrSlot[j][i]:SetAllowDrop(true);
			
			if (CharSettings.InstrSlots[j][tostring(i)].data ~= "") then
				pcall(function() 
					local sc = Turbine.UI.Lotro.Shortcut( CharSettings.InstrSlots[j][tostring(i)].qsType, CharSettings.InstrSlots[j][tostring(i)].qsData);
					self.instrSlot[j][i]:SetShortcut(sc);
				end);
			end
			
			self.instrSlot[j][i].ShortcutChanged = function( sender, args )
				pcall(function() 
					local sc = sender:GetShortcut();
					CharSettings.InstrSlots[j][tostring(i)].qsType = tostring(sc:GetType());
					CharSettings.InstrSlots[j][tostring(i)].qsData = sc:GetData();
				end);
			end
			
			self.instrSlot[j][i].DragLeave = function( sender, args )
				if (instrdrag) then 
					CharSettings.InstrSlots[j][tostring(i)].qsType ="";
					CharSettings.InstrSlots[j][tostring(i)].qsData = "";
					local sc = Turbine.UI.Lotro.Shortcut( "", "");
					self.instrSlot[j][i]:SetShortcut(sc);
					instrdrag = false;
				end
			end
			
			self.instrSlot[j][i].MouseDown = function( sender, args )
				
	--
		
				-- local player = Turbine.Gameplay.LocalPlayer:GetInstance( );
				-- if not player then return; end
				-- local equip = player:GetEquipment( )
				-- if not equip then return; end
				-- local item = equip:GetItem( Turbine.Gameplay.Equipment.Instrument )
				-- if not item then return; end
				-- local equippedInstrument = item:GetName( )
				-- if not equippedInstrument then return; end

				-- local Player_Name = player:GetName();
				-- if not Player_Name then return; end

				-- self.PlayerTitle:SetText(Player_Name .. " - " .. equippedInstrument);
	--

				if(args.Button == Turbine.UI.MouseButton.Left) then	
					instrdrag = true;
				end
			end
		end
	end
	
	self.bTimer = ( Settings.TimerState == "true" )
	self.bTimerCountdown = ( Settings.TimerCountdown == "true" )
	self.bShowReadyChars = ( Settings.ReadyColState == "true" )
	self.bHighlightReadyCol = ( Settings.ReadyColHighlight == "true" )
	self.tracklistBox:EnableCharColumn( self.bShowReadyChars )

	-- initialize list items from song database
	if (librarySize ~= 0 and not SongDB.Songs[1].Realnames) then
		
		for i = 1, #SongDB.Directories do
			local name = SongBook3ImmediateChild("/", SongDB.Directories[i]);
			if name then
				local dirItem = Turbine.UI.Label();
				dirItem:SetText(name);
				dirItem:SetTextAlignment( Turbine.UI.ContentAlignment.MiddleLeft );
				dirItem:SetSize( 1000, 20 );
				self.dirlistBox:AddItem( dirItem );
			end
		end
		
		self.listFrame.heading:SetText( Strings["ui_dirs"] .. " (" .. selectedDir .. ")" );
		
		if (self.dirlistBox:ContainsItem(1)) then
			local dirItem = self.dirlistBox:GetItem(1);
			dirItem:SetForeColor( self.colourDefaultHighlighted );
		end
		
		-- load content to song list box
		self:LoadSongs();
		
		-- set first item as initial selection
		local found = self.songlistBox:GetItemCount();		
		if (found > 0) then
			self.songlistBox:SetSelectedIndex( 1 )
			self:SelectSong( 1 );
		else
			self:ClearSongState( );
		end
		self.separator1.heading:SetText( Strings["ui_songs"] .. " (" .. found .. ")" );
		
		-- action for selecting a dir
		self.dirlistBox.SelectedIndexChanged = function( sender, args )
			self:SelectDir(sender:GetSelectedIndex());
		end
		-- action for selecting a song
		self.songlistBox.SelectedIndexChanged = function( sender, args )
			self:SelectSong(sender:GetSelectedIndex());
		end
		-- action for selecting a track
		self.tracklistBox.SelectedIndexChanged = function( sender, args )
			-- Turbine.Shell.WriteLine( "<rgb=#00FF00>SIC</rgb>");
			self:SelectTrack(sender:GetSelectedIndex());
		end
		
		self.tracklistBox.MouseClick = function( sender, args )
			if args.Button == Turbine.UI.MouseButton.Right then
				self:RealignTracknames( )
			end
		end
		self.sepSongsTracks.MouseClick = self.tracklistBox.MouseClick
		
	else
		-- show message when library is empty or database format has changed
		self.separator1:SetVisible( false );
		self.sepSongsTracks:SetVisible( false );
		self.listFrame.heading:SetText( "" );
		self.emptyLabel = Turbine.UI.Label();
		self.emptyLabel:SetParent( self );
		self.emptyLabel:SetPosition( 30, 210 );
		self.emptyLabel:SetSize(220, 240);
		self.emptyLabel:SetText(Strings["err_nosongs"]);
	end
	
	-- window resize control
	self.resizeCtrl = Turbine.UI.Control();
	self.resizeCtrl:SetParent(self);
	self.resizeCtrl:SetSize(20,20);		
	self.resizeCtrl:SetZOrder(200);
	self.resizeCtrl:SetPosition(self:GetWidth() - 20,self:GetHeight() - 20); 
                    
	self.resizeCtrl.MouseDown = function(sender,args)
	  sender.dragStartX = args.X;
	  sender.dragStartY = args.Y;
	  sender.dragging = true;
	end
		
	self.resizeCtrl.MouseUp = function(sender,args)
	  sender.dragging = false;
	  Settings.WindowPosition.Width = self:GetWidth();
	  Settings.WindowPosition.Height = self:GetHeight();
	end
	
	self.resizeCtrl.MouseMove = function(sender,args)
	  	local width, height = self:GetSize();
		local gameDisplayWidth, gameDisplayHeight = Turbine.UI.Display.GetSize();
		
		if sender.dragging then
			
			width = width + args.X - sender.dragStartX;
			height = height + args.Y - sender.dragStartY;
			local WindowLeft = self:GetLeft();
			local WindowTop  = self:GetTop ();
			
			if width < self.minWidth then width = self.minWidth; end
			if height < 45 then height = 45; end
		------------------------------------
			if WindowLeft + width  > gameDisplayWidth  then
			width  = gameDisplayWidth  - WindowLeft; end
			if WindowTop  + height > gameDisplayHeight then
			height = gameDisplayHeight - WindowTop ; end
		------------------------------------
			local listContainerHeight = height - self.lCYmod;
			local tracksHeight = 0;
			if Settings.TracksVisible == "yes" then tracksHeight = Settings.TracksHeight; end
			if listContainerHeight < Settings.DirHeight + 13 + tracksHeight + 13 + 40 then
				listContainerHeight = Settings.DirHeight + 13 + tracksHeight + 13 + 40;
				height = listContainerHeight + self.lCYmod;
			end
			
			self:SetSize( width, height );

			self:ResizeAll( );
		end
    	
		sender:SetPosition( self:GetWidth() - sender:GetWidth(), self:GetHeight() - sender:GetHeight() );
	end -- resizeCtrl.MouseMove
	
	-- dir list, song list ratio adjust
	self.separator1.MouseDown = function(sender,args)
	  sender.dragStartX = args.X;
	  sender.dragStartY = args.Y;
	  sender.dragging = true;
	end
	
	self.separator1.MouseUp = function(sender,args)
	  sender.dragging = false;
	  Settings.DirHeight = self.dirlistBox:GetHeight(); 
	end
	
	self.separator1.MouseMove = function(sender,args)
		if ( sender.dragging ) then
			local y = self.separator1:GetTop();
			local h = self.dirlistBox:GetHeight() + args.Y - sender.dragStartY;
			if h < 40 then h = 40; end
			self.dirlistBox:SetHeight( h );
			self:AdjustSonglistHeight( )
			if self.songlistBox:GetHeight() < 40 then
				self:SetSonglistHeight( 40 )
				if (Settings.TracksVisible == "yes") then
					self.dirlistBox:SetHeight(self.listContainer:GetHeight() - Settings.TracksHeight - self.songlistBox:GetHeight() - 26);
				else
					self.dirlistBox:SetHeight(self.listContainer:GetHeight() - self.songlistBox:GetHeight() - 13);
				end
			end
			--self.separator1:SetTop(self.dirlistBox:GetHeight());
			self:SetSonglistTop( self.dirlistBox:GetHeight() + 13 )

			self:AdjustArtistSearchUI();
		end	
	end
	
	-- song list, track list ratio adjust
	self.sepSongsTracks.MouseDown = function(sender,args)
	  sender.dragStartX = args.X;
	  sender.dragStartY = args.Y;
	  sender.dragging = true;
	end
	
	self.sepSongsTracks.MouseUp = function(sender,args)
	  sender.dragging = false;
	  Settings.TracksHeight = self.tracklistBox:GetHeight(); 
	end
	
	self.sepSongsTracks.MouseMove = function(sender,args)
		if ( sender.dragging ) then
			local y = self.sepSongsTracks:GetTop();
			local h = self.tracklistBox:GetHeight() - args.Y + sender.dragStartY;
			if h < 40 then h = 40; end
			self:SetTracklistHeight( h )
			self:UpdateTracklistTop( );
			self:AdjustSonglistHeight( )
		end
		if self.songlistBox:GetHeight() < 40 then
			self:SetSonglistHeight( 40 )
			self:SetTracklistHeight( self.listContainer:GetHeight() - self.dirlistBox:GetHeight() - self.songlistBox:GetHeight() - 26 );
			self:UpdateTracklistTop( );
		end	
	end
	
	-- Settings button	
	self.settingsBtn = Turbine.UI.Lotro.Button();
	self.settingsBtn:SetParent( self );
	self.settingsBtn:SetPosition(self:GetWidth()/2 - 55, self:GetHeight() - 30 );	
	self.settingsBtn:SetSize(110,20);
	self.settingsBtn:SetText(Strings["ui_settings"]);
	
	-- actions for settings button
	self.settingsBtn.MouseClick = function(sender, args)
		if(args.Button == Turbine.UI.MouseButton.Left) then
			settingsWindow:SetVisible(true);
			settingsWindow:Activate();
		end
	end
	
--

    -- Auxiliary windows are assembled by their own modules.
    self:CreateSetlistsWindow();
    self:CreateShareSetlistWindow();
    self:CreateImportSetlistWindow();
    self:CreateSyncCheckWindow();
    self:CreateLyricsWindow();

    -- The legacy Sinduriel.SongBook3.Windows.Main.SyncInfolistbox remains as a hidden status cache, because
    -- SetTrackColours still uses its markup to preserve instrument details.
    -- A single Sync Check button replaces the old separate Sync Info view.
--

	-- action for closing window and saving position
	self.Closed = function( sender, args )
		self:SaveSettings();
		self:SetVisible( false );
	end
	
	if (Plugins[gPlugin] ~= nil ) then
		Plugins[gPlugin].Unload = function( sender, args )
			self:SaveSettings();
			RemoveCallback( Turbine.Chat, "Received", ChatHandler );
		end
	end
	
	self:CreateTimerUI( )
	self:CreateArtistSearchUI();
	self:CreatePartyListbox();
	self:CreateSetupsListbox();
    self:EnsureChatListener(); -- also repairs a listener replaced by another addon
	self.listboxPlayers:EnableCharColumn( self.bShowReadyChars )
	self:RefreshPlayerListbox( ) -- lists the current party members; more will be added through chat messages
	
	if Settings.ArtistSearchVisible == "true" then self:ShowArtistSearchUI(true); end
	self:SetLeaderMode( Settings.ChiefMode == "true" )
	self:HightlightReadyColumns( self.bHighlightReadyCol )
	
	-- adjust to search visibility
	if (Settings.SearchVisible == "no") then 
		self:ToggleSearch("off");
	end
	
	self:ResizeAll( ); -- Adjust variable sizes and positions to current main window size
end -- SongBook3Window:Constructor()

function SongBook3Window:ValidateWindowPosition( winPos )
	if winPos.Left < 0 or winPos.Top < 0 or winPos.Width < 0 or winPos.Height < 0 then
		winPos.Left = 700
		winPos.Top = 20
		winPos.Width = 342
		winPos.Height = 398
	end
end

function sortby_Name (song1, song2)
	if song1.Filepath == song2.Filepath then
		return string.lower(song1.Filename) < string.lower(song2.Filename)
	else
		return string.lower(song1.Filepath) < string.lower(song2.Filepath)
	end
end

function SongBook3Window:ActivateTimer( bActivate )
	self.bTimer = bActivate
	if not bActivate then self:StopTimer( ); end
end

function SongBook3Window:CreateTimerUI( )
	self.tracksMsg = Turbine.UI.Label( )
	self.tracksMsg:SetParent( self.listContainer )
	self.tracksMsg:SetMultiline( false )
	self.tracksMsg:SetSize( 150, 22 )
	self.tracksMsg:SetFont( Turbine.UI.Lotro.Font.BookAntiquaBold22 );
	--self.tracksMsg:SetForeColor( self.colourMessageTitle );
	self.tracksMsg:SetTextAlignment( Turbine.UI.ContentAlignment.MiddleRight )
	self.tracksMsg:SetZOrder( 350 )
	self.tracksMsg:SetVisible( false )

	self.Update =
		function( )
			local previous = self.currentTime
			self.currentTime = Turbine.Engine.GetLocalTime() - self.startTimer
			local bKeepRunning = ( self.songDuration == 0 or self.currentTime <= self.songDuration )
			if self.bTimerCountdown == true and self.songDuration > 0 then
				self.currentTime = self.songDuration - self.currentTime;
				bKeepRunning = self.currentTime >= 0
			end

			if bKeepRunning then
				if self.currentTime ~= previous then self:SetTimer( self.currentTime ); end
			else
				self:StopTimer( )
			end
		end
end

function SongBook3Window:SetTimer( value )
	local mins = math.floor( value / 60 )
	self.tracksMsg:SetText( string.format("%u:%02u", mins, value - mins * 60 ) )
	Sinduriel.SongBook3.Windows.Main.Timer_Label:SetText( string.format("%u:%02u", mins, value - mins * 60 ) )
end
	
function SongBook3Window:StartTimer( )
	self.startTimer = Turbine.Engine.GetLocalTime( )
	self.songDuration = 0
	--local item, songTime
	local songTime
	-- for i = 1, self.tracklistBox:GetItemCount( ) do
		-- item = self.tracklistBox:GetItem( i )
		sMinutes, sSeconds = string.match( Synced_Song_TrackName , ".*%((%d+):(%d+)%).*" ) -- try (mm:ss)
		-- if not sMinutes or not sSeconds then
			-- sMinutes, sSeconds = string.match( item:GetText( ), ".*(%d+):(%d+).*" ) -- no luck, try just mm:ss
		-- end
		if sMinutes and sSeconds and tonumber(sMinutes) < 60 and tonumber(sSeconds) < 60 then
			songTime = sMinutes * 60 + sSeconds
			if songTime > self.songDuration then self.songDuration = songTime; end -- need longest track
		end
	--end

	if self.bTimerCountdown == true and self.songDuration > 0 then self.currentTime = self.songDuration
	else self.currentTime = 0; end

	self:SetTimer( self.currentTime )
	self.tracksMsg:SetVisible( true )
	self:SetWantsUpdates( true )
end

function SongBook3Window:StopTimer( )
	self:SetWantsUpdates( false )
	self.tracksMsg:SetVisible( false )
	Sinduriel.SongBook3.Windows.Main.Timer_Label:SetText("0:00");
	Sinduriel.SongBook3.Windows.Main.Song_Label:SetText( "" );
end

-- Keep all four footer controls aligned in a compact right-anchored group.
function SongBook3Window:LayoutMainFooterButtons( )
    local width, height = self:GetSize();
    local bottom = height - 30;
    self.settingsBtn:SetSize(90, 20);
    self.setlistBtn:SetSize(75, 20);
    self.lyricsBtn:SetSize(75, 20);
    self.readyCheckBtn:SetSize(100, 20);
    self.settingsBtn:SetPosition(width - 401, bottom);
    self.setlistBtn:SetPosition(width - 303, bottom);
    self.lyricsBtn:SetPosition(width - 220, bottom);
    self.readyCheckBtn:SetPosition(width - 137, bottom);
end

function SongBook3Window:ResizeAll( )
	self.listFrame:SetSize(self:GetWidth() - self.lFXmod, self:GetHeight() - self.lFYmod);
	self.listContainer:SetSize(self:GetWidth() - self.lCXmod, self:GetHeight() - self.lCYmod);
	self.listFrame.heading:SetSize(self.listFrame:GetWidth(),13);
	
	for j = 1, CharSettings.InstrumentSlots_Rows do
		local TopShift = 75 + InstrumentSlots_Shift * ( j - 1 );
		self.instrContainer[j]:SetTop( self:GetHeight() - TopShift );
	end
	
	self.dirlistBox:SetHeight( Settings.DirHeight );
	self:AdjustDirlistPosition( );

	if Settings.TracksVisible == "yes" then
		self:AdjustTracklistSize( Settings.TracksHeight )
		self:UpdateTracklistTop( )
	else
		self.tracksMsg:SetPosition( self.dirlistBox:GetLeft()+self.dirlistBox:GetWidth()-160, self.dirlistBox:GetTop()+self.dirlistBox:GetHeight());	
	end

	self:AdjustSonglistHeight( );
	self:AdjustSonglistPosition( );
		
	self.songTitle:SetWidth(self:GetWidth() - 52);
	self:LayoutMainFooterButtons( );
		self.tipLabel:SetLeft(self:GetWidth() - 270);
	self:AdjustArtistSearchUI();
	
	self.PlayerTitle:SetWidth(self:GetWidth() - 30);
	self.MessageTitle:SetWidth(self:GetWidth() - 30);
	self.syncMessageTitle:SetWidth(self:GetWidth() - 30);
end -- SongBook3Window:ResizeAll( )


-- action for selecting a directory
function SongBook3Window:SelectDir( iDir , Directory )
	if not Directory then 
		local selectedItem = self:SetListboxColours( self.dirlistBox ) --, iDir )
		if not selectedItem then return; end
		Directory = selectedItem:GetText();
		
		if Directory == ".." then
			selectedDir = "";
			table.remove(dirPath,#dirPath);
			for i = 1,#dirPath do 
				selectedDir = selectedDir .. dirPath[i];
			end
		else		
			selectedDir = selectedDir .. Directory;
			dirPath[#dirPath+1] = Directory;	
		end
	else
		selectedDir = Directory;
		-- Fix a bug where clicking a song link multiple times breaks path
		-- dirPath[#dirPath+1] = Directory;
		dirPath = {}
		dirPath[1] = "/"
		for token in string.gmatch(Directory, "([^/]+)") do
			dirPath[#dirPath+1] = token .. "/"
		end
	end
		
	if (string.len(selectedDir)<31) then 
		self.listFrame.heading:SetText( Strings["ui_dirs"] .. " (" .. selectedDir .. ")" );
	else 
		self.listFrame.heading:SetText( Strings["ui_dirs"] .. " (" .. string.sub(selectedDir,string.len(selectedDir)-30) .. ")" );
	end
	
	-- refresh dir list
	self.dirlistBox:ClearItems();
	local dirItem = Turbine.UI.Label();
	if (selectedDir ~= "/") then
		dirItem:SetText(".."); -- first item as link to previous directory
		dirItem:SetTextAlignment( Turbine.UI.ContentAlignment.MiddleLeft );
		dirItem:SetSize( 1000, 20 );				
		self.dirlistBox:AddItem( dirItem );
	end
	
	for i = 1, #SongDB.Directories do
		local name = SongBook3ImmediateChild(selectedDir, SongDB.Directories[i]);
		if name then
			local dirItem = Turbine.UI.Label();
			dirItem:SetText(name);
			dirItem:SetTextAlignment( Turbine.UI.ContentAlignment.MiddleLeft );
			dirItem:SetSize( 1000, 20 );
			self.dirlistBox:AddItem( dirItem );
		end
	end

	self.songlistBox:ClearItems();
	if iDir ~= nil and self.bArtistSearch and
	   self.artistSearchInput:GetText() ~= "" then
		self:UpdateSongs();
	else
		self:LoadSongs();
		self:InitSonglist();
	end
end -- SelectDir


-- load content to song list box
function SongBook3Window:LoadSongs( )
    self.bShowingSongSearchResults = false;
	local nFiltered = 0;
    self.aFilteredIndices = { };
    for _, i in ipairs(self.songsByDirectory[selectedDir] or { }) do
		local songItem = Turbine.UI.Label();
		if SongDB.Songs[i].Filepath == selectedDir then
			songItem:SetText(self:SongListText(SongDB.Songs[i]));
			songItem:SetTextAlignment( Turbine.UI.ContentAlignment.MiddleLeft );
			songItem:SetSize( 1000, 20 );
			
			self.songlistBox:AddItem( songItem );
			nFiltered = nFiltered + 1;
			self.aFilteredIndices[ nFiltered ] = i; -- Create filtered index		
			
			if SelectedMatchedSong_Index == i then
				SelectedMatchedSong_IndexListBox = nFiltered;
			end
			if OtherPlayer_SyncedSong_Index == i then
				OtherPlayer_SyncedSong_IndexListBox = nFiltered;
			end
		end
	end
end

function SongBook3Window:SelectedTrackIndex( iList )
	if not iList then iList = selectedTrack; end -- use global selected track index if none provided
	if self.iCurrentSetup and self.aSetupTracksIndices[ iList ] then
		return self.aSetupTracksIndices[ iList ];
	end
	return iList;
end

function SongBook3Window:IsAvailableTrackWithMatchingInstrument(songIdx, trackIdx, equippedInstrumentIdx)
	local readyState = self:GetTrackReadyState(songIdx, trackIdx);
	local Track_Instrument = self:FindInstrumentForTrack( SongDB.Songs[songIdx].Tracks[trackIdx] );
	local Track_Instrument_Index = Track_Instrument[0];
	local isRightIns = self:CompareInstrument(equippedInstrumentIdx, Track_Instrument_Index, true --[[skip updating icon]]);
	return (readyState[0] == nil and isRightIns == 1);
end

function SongBook3Window:GetTrackToSelect(selectedSongIndex)
	local trackcount = #SongDB.Songs[selectedSongIndex].Tracks;

	-- Get instrument of current player
	local equippedInstrument_Index = self:UpdatePlayerTitle();

	for iTrack = 1,trackcount do
		if self:IsAvailableTrackWithMatchingInstrument(selectedSongIndex, iTrack, equippedInstrument_Index) then
			return iTrack;
		end
	end

	return 0;
end

-- action for selecting a song
function SongBook3Window:SelectSong( iSong )
	if( iSong < 1 or iSong > self.songlistBox:GetItemCount( ) ) then
		return;
	end
	local track = 1;
	self.aSetupTracksIndices = { };
	self.aSetupListIndices = { };
	self.iCurrentSetup = nil

	-- clear focus
	self:SetListboxColours( self.songlistBox ) --, iSong )
	
	selectedSongIndexListBox = iSong;
	selectedSongIndex = self.aFilteredIndices[ iSong ];
	selectedSong = SongDB.Songs[selectedSongIndex].Filename;

	if Settings.AutoPickOnSongChange == "true" then
			track = self:GetTrackToSelect(selectedSongIndex);
			if track == 0 then track = 1; end
			if self.bShowReadyChars then track = track * 2; end
	end
			
	if ( SongDB.Songs[selectedSongIndex].Tracks[1].Name ~= "") then
		self.songTitle:SetText( SongDB.Songs[selectedSongIndex].Tracks[1].Name );	
	else
		self.songTitle:SetText( SongDB.Songs[selectedSongIndex].Filename );	
	end
	self.trackNumber:SetText( SongDB.Songs[selectedSongIndex].Tracks[1].Id );

	self:ListTracks(selectedSongIndex);	
	
	self:ClearPlayerReadyStates( );
	self:SelectTrack( track );
	self:SetPlayerColours( );
	self:ListSetups( selectedSongIndex )
	self.iCurrentSetup = self:SetupIndexForCount( selectedSongIndex, self.selectedSetupCount )
	self:SelectSetup( self.iCurrentSetup )
	self:UpdateSetupColours( );
	
	self:SetTrackColours( selectedTrack );
	
	local found = self.tracklistBox:GetItemCount();
	self.sepSongsTracks.heading:SetText( Strings["ui_parts"] .. " (" .. found .. ")" );
    -- Selecting a song must never rebuild/reselect the setlist ListBox:
    -- that fires its SelectedIndexChanged and can recurse indefinitely.
    if self.setlistList and not self.refreshingSetlistUI then
        self:UpdateSetlistSelectionHighlight();
    end
end


-- action for repopulating the track list when song is changed
function SongBook3Window:ListTracks( songid )			
	self.tracklistBox:ClearItems();
	Sinduriel.SongBook3.Windows.Main.SyncInfolistbox:ClearItems( );
	for i = 1, #SongDB.Songs[songid].Tracks do
		self:AddTrackToList( songid, i )
	end
	--Turbine.Chat.Received = self.ChatHandler; -- Enable chat monitoring for ready messages to update track colours
end


function SongBook3Window:CreateTracklistItem( sText )
	local trackItem = Turbine.UI.Label();
	trackItem:SetMultiline( false )
	trackItem:SetText( sText );
	trackItem.MouseClick = self.sepSongsTracks.MouseClick
	trackItem:SetForeColor( self.colourDefault );
	return trackItem
end

function SongBook3Window:AddTrackToList( iSong, iTrack )
	local track = SongDB.Songs[iSong].Tracks[iTrack];
	local sTerseName = self:TerseTrackname( self:TrackDisplayName( track ) );
	local trackItem = self:CreateTracklistItem( "[" .. SongDB.Songs[iSong].Tracks[iTrack].Id .. "] " .. sTerseName )
	trackItem:SetTextAlignment( Turbine.UI.ContentAlignment.MiddleLeft );
	trackItem:SetSize( 1000, 20 );
	self.tracklistBox:AddItem( trackItem );
	
	local Track_Instrument = self:FindInstrumentForTrack( track );
	
	trackItem = Turbine.UI.Label();
	trackItem:SetMultiline( false )
	trackItem:SetTextAlignment( Turbine.UI.ContentAlignment.MiddleLeft );
	trackItem:SetSize( 2000, 20 );
	trackItem:SetMarkupEnabled(true);
	trackItem:SetText( "[" .. SongDB.Songs[iSong].Tracks[iTrack].Id .. "] " .. Track_Instrument[1] );
	trackItem:SetBackColor( self.backColourDefault );
	
	Sinduriel.SongBook3.Windows.Main.SyncInfolistbox:AddItem( trackItem );
end

	
-- Right-align track names (so user can quickly check then end of the track name)
function SongBook3Window:RealignTracknames( )
	local alignment, left
	if self.alignTracksRight == false then
		self.alignTracksRight = true
		alignment = Turbine.UI.ContentAlignment.MiddleRight
		left = self.tracklistBox:GetWidth( ) - 1010
	else
		self.alignTracksRight = false
		alignment = Turbine.UI.ContentAlignment.MiddleLeft
		if self.bShowReadyChars then left = 20
		else left = 0; end
	end

	for i = 1, self.tracklistBox:GetItemCount( ) do
		local item = self.tracklistBox:GetItem( i )
		item:SetLeft( left ) 
		item:SetTextAlignment( alignment );
	end
end

--

-- set track ready indicator
function SongBook3Window:SetTrackReadyChar( iList, readyState )
	if not readyState then -- track not ready
		self.tracklistBox:SetColumnChar( iList, self.chNone, false )
	elseif readyState == 0 then -- track is ready by more than one player
		self.tracklistBox:SetColumnChar( iList, self.chMultiple, true )
	else -- track ready by one player
		self.tracklistBox:SetColumnChar( iList, self.chReady, false )
	end
end


-- action to search songs
function SongBook3Window:SearchSongs()
    self.bShowingSongSearchResults = true;
    self.songlistBox:ClearItems();
    self.aFilteredIndices = { };
    local needle = string.lower(self.searchInput:GetText() or "");
    local artistNeedle = self.bArtistSearch and
        string.lower(self.artistSearchInput:GetText() or "") or "";
    local nFound = 0;
    for i, song in ipairs(SongDB.Songs) do
        if string.find(self.searchIndex[i] or "", needle, 1, true) and
           string.find(string.lower(song.Artist or ""), artistNeedle, 1, true) then
            local item = Turbine.UI.Label();
            item:SetText(self:SearchSongListText(song));
            item:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);
            item:SetSize(1000, 20);
            self.songlistBox:AddItem(item);
            nFound = nFound + 1;
            self.aFilteredIndices[nFound] = i;
        end
    end
    if nFound > 0 then self:SelectSong(1); else
        selectedSong = "";
        selectedSongIndexListBox = 0;
        self:InitSonglist();
    end
    self.separator1.heading:SetText(Strings["ui_songs"] .. " (" .. nFound .. ")");
end

-- action for toggling search function on and off
function SongBook3Window:ToggleSearch(mode)
	if (Settings.SearchVisible == "yes" or mode == "off") then		
		Settings.SearchVisible = "no";
		self:SetSearch( -20, false )
	else
		Settings.SearchVisible = "yes";
		self:SetSearch( 20, true )
	end

	self.listFrame:SetHeight(self:GetHeight() - self.lFYmod);	
	self.listContainer:SetHeight(self:GetHeight() - self.lCYmod);		
	if (Settings.TracksVisible == "no") then
		self:ShowTrackListbox( false ) -- ?
	end
end

function SongBook3Window:SetSearch( delta, bShow )
	self.searchInput:SetVisible(bShow);
	self.searchBtn:SetVisible(bShow);
	self.clearBtn:SetVisible(bShow);		
	self.lFYmod = self.lFYmod + delta;		
	self.lCYmod = self.lCYmod + delta;
	self.listFrame:SetTop( self.listFrame:GetTop( ) + delta);
	self.listContainer:SetTop( self.listContainer:GetTop( ) + delta );
	self:SetSonglistHeight(self.songlistBox:GetHeight() - delta);		
	self:MoveTracklistTop( -delta );
	
	if Settings.TracksVisible == "no" then
		self.tracksMsg:SetTop( self.dirlistBox:GetTop()+self.dirlistBox:GetHeight() );
	end
end

-- action for toggling description on and off
function SongBook3Window:ToggleDescription()
	if (Settings.DescriptionVisible == "yes") then
		Settings.DescriptionVisible = "no";
		self.songlistBox:ClearItems();
		self:LoadSongs();
		local found = self.songlistBox:GetItemCount();		
		if (found > 0) then self:SelectSong(1);
		else self:ClearSongState( ); end
	else
		Settings.DescriptionVisible = "yes";
		self.songlistBox:ClearItems();
		self:LoadSongs();
		local found = self.songlistBox:GetItemCount();		
		if (found > 0) then self:SelectSong(1);
		else self:ClearSongState( ); end
	end
end

-- action for toggling description on and off
function SongBook3Window:ToggleDescriptionFirst()
	if (Settings.DescriptionFirst == "yes") then
		Settings.DescriptionFirst = "no";		
		if (Settings.DescriptionVisible == "yes") then
			self.songlistBox:ClearItems();
			self:LoadSongs();
			local found = self.songlistBox:GetItemCount();		
			if (found > 0) then self:SelectSong(1);
			else self:ClearSongState( ); end
		end
	else
		Settings.DescriptionFirst = "yes";
		if (Settings.DescriptionVisible == "yes") then
			self.songlistBox:ClearItems();
			self:LoadSongs();
			local found = self.songlistBox:GetItemCount();		
			if (found > 0) then self:SelectSong(1);
			else self:ClearSongState( ); end
		end
	end
end

-- action for toggling tracks display on and off
function SongBook3Window:ToggleTracks()
	if (Settings.TracksVisible == "yes") then
		Settings.TracksVisible = "no";
		self:SetSonglistHeight(self.listContainer:GetHeight() - self.dirlistBox:GetHeight() - 13);
		self:ShowTrackListbox( false )
		self.listboxSetups:SetVisible(false);
		self.tracksMsg:SetPosition( self.dirlistBox:GetLeft()+self.dirlistBox:GetWidth()-150, self.dirlistBox:GetTop()+self.dirlistBox:GetHeight());	
	else
		Settings.TracksVisible = "yes";
		self:ShowTrackListbox( true )
		self.listboxSetups:SetVisible(self.bShowSetups)
		
		-- check if there's room for the track list and adjust
		local h = self.dirlistBox:GetHeight() + Settings.TracksHeight + 26;
		if (self.listContainer:GetHeight() - h < 40) then
			self.listContainer:SetHeight(h + self.songlistBox:GetHeight())
			self:SetHeight(self.listContainer:GetHeight() + self.lCYmod);
			self.listFrame:SetHeight(self:GetHeight() - self.lFYmod);
			self.resizeCtrl:SetTop(self:GetHeight() - 20); 
		end
					
		self:SetTracklistTop( self.listContainer:GetHeight() - Settings.TracksHeight )
		self:AdjustTracklistSize( Settings.TracksHeight )			
		self:SetSonglistHeight(self.listContainer:GetHeight() - self.dirlistBox:GetHeight() - self.tracklistBox:GetHeight() - 26);
		self:LayoutMainFooterButtons( );
				
		if (CharSettings.InstrSlots[1]["visible"] == "yes") then
			for j = 1, CharSettings.InstrumentSlots_Rows do
				local TopShift = 75 + InstrumentSlots_Shift * ( j - 1 );
				self.instrContainer[j]:SetTop( self:GetHeight() - TopShift );
			end
		end
	end
end

-- action for toggling instrument slots on and off
function SongBook3Window:ToggleInstrSlots()
	local hMod = InstrumentSlots_Shift * CharSettings.InstrumentSlots_Rows;
	if (CharSettings.InstrSlots[1]["visible"] == "yes") then		
		CharSettings.InstrSlots[1]["visible"] = "no";
		
		self:SetInstrSlots( -hMod );
		for j = 1, CharSettings.InstrumentSlots_Rows do
			self.instrContainer[j]:SetVisible( false );
		end
	else
		CharSettings.InstrSlots[1]["visible"] = "yes";
		
		self:SetInstrSlots( hMod );
		for j = 1, CharSettings.InstrumentSlots_Rows do
			self.instrContainer[j]:SetVisible( true );
		end
	end
end

function SongBook3Window:SetInstrSlots( delta )
	self.lFYmod = self.lFYmod + delta;
	self.lCYmod = self.lCYmod + delta;
	self.listFrame:SetHeight(self.listFrame:GetHeight() - delta);
	self.listContainer:SetHeight(self.listContainer:GetHeight() - delta);
	self:SetSonglistHeight(self.songlistBox:GetHeight() - delta);
	if (Settings.TracksVisible == "yes") then
		self:MoveTracklistTop( -delta )
		--self.tracklistBox:SetTop(self.tracklistBox:GetTop() - hMod);
		--self.sepSongsTracks:SetTop(self.sepSongsTracks:GetTop() - hMod);		
	end
	
	local height = self:GetHeight();
	if height < 45 then height = 45; end
	
	local listContainerHeight = height - self.lCYmod;
	local tracksHeight = 0;
	if Settings.TracksVisible == "yes" then tracksHeight = Settings.TracksHeight; end
	if listContainerHeight < Settings.DirHeight + 13 + tracksHeight + 13 + 40 then
		listContainerHeight = Settings.DirHeight + 13 + tracksHeight + 13 + 40;
		height = listContainerHeight + self.lCYmod;
	end
	
	self:SetHeight( height );
	self:ResizeAll( );
	self.resizeCtrl:SetPosition( self:GetWidth() - self.resizeCtrl:GetWidth(), self:GetHeight() - self.resizeCtrl:GetHeight() );
end

function SongBook3Window:ClearSlots()
	for j = 1, CharSettings.InstrumentSlots_Rows do
		for i=1,CharSettings.InstrSlots[j]["number"] do
			CharSettings.InstrSlots[j][tostring(i)].qsType ="";
			CharSettings.InstrSlots[j][tostring(i)].qsData = "";
			local sc = Turbine.UI.Lotro.Shortcut( "", "");
			self.instrSlot[j][i]:SetShortcut(sc);
		end
	end
end

function SongBook3Window:AddSlot()
	if self:GetWidth() > 10+(CharSettings.InstrSlots[1]["number"]+1)*40 then
		local newslot = CharSettings.InstrSlots[1]["number"]+1;
		for j = 1, CharSettings.InstrumentSlots_Rows do
			CharSettings.InstrSlots[j]["number"] = newslot;
			self.instrSlot[j][newslot] = Turbine.UI.Lotro.Quickslot();
			self.instrSlot[j][newslot]:SetParent( self.instrContainer[j] );
			self.instrSlot[j][newslot]:SetPosition(40*(newslot-1), 0);
			self.instrSlot[j][newslot]:SetSize(37, 37);
			self.instrSlot[j][newslot]:SetZOrder(100);
			self.instrSlot[j][newslot]:SetAllowDrop(true);
			self.instrContainer[j]:SetWidth(self.instrContainer[j]:GetWidth()+40); 
			
			local sc = Turbine.UI.Lotro.Shortcut("","");
			self.instrSlot[j][newslot]:SetShortcut(sc);
			
			CharSettings.InstrSlots[j][tostring(newslot)] = { qsType = "", qsData = "" };		
			
			self.instrSlot[j][newslot].ShortcutChanged = function( sender, args )
				pcall(function() 
					local sc = sender:GetShortcut();
					CharSettings.InstrSlots[j][tostring(newslot)].qsType = tostring(sc:GetType());
					CharSettings.InstrSlots[j][tostring(newslot)].qsData = sc:GetData();
				end);
			end
			
			self.instrSlot[j][newslot].DragLeave = function( sender, args )
				if (instrdrag) then 
					CharSettings.InstrSlots[j][tostring(newslot)].qsType ="";
					CharSettings.InstrSlots[j][tostring(newslot)].qsData = "";
					local sc = Turbine.UI.Lotro.Shortcut( "", "");
					self.instrSlot[j][newslot]:SetShortcut(sc);
					instrdrag = false;
				end
			end
			
			self.instrSlot[j][newslot].MouseDown = function( sender, args )
				if(args.Button == Turbine.UI.MouseButton.Left) then	
					instrdrag = true;
				end
			end
		end
	end
end

function SongBook3Window:DelSlot()
	for j = 1, CharSettings.InstrumentSlots_Rows do
		if CharSettings.InstrSlots[j]["number"] > 1 then
			local delslot = CharSettings.InstrSlots[j]["number"];
			CharSettings.InstrSlots[j]["number"] = CharSettings.InstrSlots[j]["number"]-1;
			self.instrContainer[j]:SetWidth(self.instrContainer[j]:GetWidth()-40); 
			self.instrSlot[j][delslot] = nil;
			CharSettings.InstrSlots[j][tostring(delslot)] = nil;
		end
	end
end

--
function SongBook3Window:AddSlot_row()
	if (CharSettings.InstrSlots[1]["visible"] == "yes") then
		CharSettings.InstrumentSlots_Rows = CharSettings.InstrumentSlots_Rows + 1;
		local InstrumentSlots_Rows = CharSettings.InstrumentSlots_Rows;
		
		table.insert(self.instrContainer , Turbine.UI.Control);
		
		self.instrContainer[InstrumentSlots_Rows] = Turbine.UI.Control();
		self.instrContainer[InstrumentSlots_Rows]:SetParent( self );
		local TopShift = 75 + InstrumentSlots_Shift * ( InstrumentSlots_Rows - 1 );
		self.instrContainer[InstrumentSlots_Rows]:SetPosition( 10, self:GetHeight() - TopShift );
		if (CharSettings.InstrSlots[1]["visible"] == "yes") then
			self.instrContainer[InstrumentSlots_Rows]:SetVisible( true );
		else
			self.instrContainer[InstrumentSlots_Rows]:SetVisible( false );
		end
		self.instrContainer[InstrumentSlots_Rows]:SetSize( 40*CharSettings.InstrSlots[1]["number"], 38 );
		self.instrContainer[InstrumentSlots_Rows]:SetZOrder(90);
		
		
		table.insert(self.instrSlot , {});
		
		table.insert(CharSettings.InstrSlots , {});
		CharSettings.InstrSlots[InstrumentSlots_Rows]["visible"] = "yes";
		CharSettings.InstrSlots[InstrumentSlots_Rows]["number"] = CharSettings.InstrSlots[1]["number"];
		for i = 1, CharSettings.InstrSlots[InstrumentSlots_Rows]["number"] do
			CharSettings.InstrSlots[InstrumentSlots_Rows][tostring(i)] = { qsType = "", qsData = "" };		
		end
		
		for i = 1, CharSettings.InstrSlots[1]["number"] do
			self.instrSlot[InstrumentSlots_Rows][i] = Turbine.UI.Lotro.Quickslot();
			self.instrSlot[InstrumentSlots_Rows][i]:SetParent( self.instrContainer[InstrumentSlots_Rows] );
			self.instrSlot[InstrumentSlots_Rows][i]:SetPosition(40*(i-1), 0);
			self.instrSlot[InstrumentSlots_Rows][i]:SetSize(37, 37);
			self.instrSlot[InstrumentSlots_Rows][i]:SetZOrder(100);
			self.instrSlot[InstrumentSlots_Rows][i]:SetAllowDrop(true);
			
			if (CharSettings.InstrSlots[InstrumentSlots_Rows][tostring(i)].data ~= "") then
				pcall(function() 
					local sc = Turbine.UI.Lotro.Shortcut( CharSettings.InstrSlots[InstrumentSlots_Rows][tostring(i)].qsType, CharSettings.InstrSlots[InstrumentSlots_Rows][tostring(i)].qsData);
					self.instrSlot[InstrumentSlots_Rows][i]:SetShortcut(sc);
				end);
			end
			
			self.instrSlot[InstrumentSlots_Rows][i].ShortcutChanged = function( sender, args )
				pcall(function() 
					local sc = sender:GetShortcut();
					CharSettings.InstrSlots[InstrumentSlots_Rows][tostring(i)].qsType = tostring(sc:GetType());
					CharSettings.InstrSlots[InstrumentSlots_Rows][tostring(i)].qsData = sc:GetData();
				end);
			end
			
			self.instrSlot[InstrumentSlots_Rows][i].DragLeave = function( sender, args )
				if (instrdrag) then 
					CharSettings.InstrSlots[InstrumentSlots_Rows][tostring(i)].qsType ="";
					CharSettings.InstrSlots[InstrumentSlots_Rows][tostring(i)].qsData = "";
					local sc = Turbine.UI.Lotro.Shortcut( "", "");
					self.instrSlot[InstrumentSlots_Rows][i]:SetShortcut(sc);
					instrdrag = false;
				end
			end
			
			self.instrSlot[InstrumentSlots_Rows][i].MouseDown = function( sender, args )
				
				if(args.Button == Turbine.UI.MouseButton.Left) then	
					instrdrag = true;
				end
			end
		end
		
		self:SetInstrSlots( InstrumentSlots_Shift );
	end
end
--
function SongBook3Window:DelSlot_row()
	if (CharSettings.InstrSlots[1]["visible"] == "yes") then
		if CharSettings.InstrumentSlots_Rows > 1 then
			local InstrumentSlots_Rows = CharSettings.InstrumentSlots_Rows;
			
			for i = 1, CharSettings.InstrSlots[1]["number"] do
				self.instrSlot[InstrumentSlots_Rows][i] = nil;
				CharSettings.InstrSlots[InstrumentSlots_Rows][tostring(i)] = nil;
			end
			
			self.instrContainer[InstrumentSlots_Rows]:SetVisible( false );
			self.instrContainer[InstrumentSlots_Rows] = nil;
			CharSettings.InstrSlots[InstrumentSlots_Rows] = nil;
			--table.remove(self.instrContainer);
			--table.remove(CharSettings.InstrSlots);
			
			CharSettings.InstrumentSlots_Rows = CharSettings.InstrumentSlots_Rows - 1;
			
			
			self:SetInstrSlots( -InstrumentSlots_Shift );
		end
	end
end
--

-- Return only the song title and a credited original artist for the /e emote.
-- SongBook3's T: track names frequently include durations, instruments, and
-- arrangement credits. None of those should become an original-artist credit.
local function EmoteTrim(value)
    return (tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""));
end

local function EmotePartAnnotation(value)
    local label = string.lower(EmoteTrim(value));
    if label == "" then return false; end
    if label == "solo" or label == "duet" or label == "trio" or
       label == "melody" or label == "bassline" or label == "multi" or
       label == "re" or label == "rev" then return true; end
    if label:match("^%d+/%d+") or label:match("^%d+$") or
       label:match("^v%d+[%d%.]*$") or label:match("^by%s+") or
       label:match("^arranged%s+by%s+") then return true; end
    -- Treat explicit instrument labels as part details, not title text.
    for _, instrument in ipairs({ "lute", "theorbo", "harp", "clarinet",
        "flute", "horn", "drum", "fiddle", "bassoon", "bagpipe",
        "pibgorn", "cowbell", "guitar", "bass", "piano", "violin" }) do
        if string.find(label, instrument, 1, true) then return true; end
    end
    return false;
end

local function EmoteSongTitleAndArtist(song)
    local firstTrack = song.Tracks and song.Tracks[1] or nil;
    local rawTitle = (firstTrack and firstTrack.Name) or song.Filename or "";
    local artist = EmoteTrim(song.OriginalArtist or song.Artist or
        (firstTrack and (firstTrack.OriginalArtist or firstTrack.Artist)) or "");
    local title = EmoteTrim(rawTitle):gsub("[\r\n]", " ");

    -- An explicitly marked original artist in T: is usable even when there
    -- is no separate Artist property in the library database.
    if artist == "" then
        local marked = title:match("%([Oo]riginal%s+[Aa]rtist:%s*([^%)]+)%)") or
            title:match("%[[Oo]riginal%s+[Aa]rtist:%s*([^%]]+)%]");
        if marked then artist = EmoteTrim(marked); end
    end
    title = title:gsub("%s*%([Oo]riginal%s+[Aa]rtist:%s*[^%)]*%)", "");
    title = title:gsub("%s*%[[Oo]riginal%s+[Aa]rtist:%s*[^%]]*%]", "");

    title = title:gsub("_%-_", " - "):gsub("_", " ");
    title = title:gsub("%s*%(%d+:%d%d%)", ""); -- ABC duration (M:SS)
    title = title:gsub("%s+[Mm][Uu][Ll][Tt][Ii]%d+", "");
    title = title:gsub("%s+", " ");

    -- Remove clearly marked instrumentation and part information; keep
    -- descriptive parentheses (e.g. alternate names of a composition).
    title = title:gsub("%s*%[([^%]]+)%]", function(label)
        return EmotePartAnnotation(label) and "" or " [" .. label .. "]";
    end);
    for _ = 1, 8 do
        local changed = false;
        local base, label = title:match("^(.-)%s*%(([^()]*)%)%s*$");
        if base and EmotePartAnnotation(label) then
            title = EmoteTrim(base);
            changed = true;
        else
            base, label = title:match("^(.*)%s+%-%s+(.+)$");
            if base and EmotePartAnnotation(label) then
                title = EmoteTrim(base);
                changed = true;
            end
        end
        if not changed then break; end
    end

    title = EmoteTrim(title:gsub("%.abc$", ""));
    if title == "" then title = EmoteTrim(song.Filename); end
    -- If a recognized artist is already at the front, don't repeat it.
    if artist ~= "" then
        local prefix, rest = title:match("^(.-)%s+%-%s+(.+)$");
        if prefix and string.lower(EmoteTrim(prefix)) == string.lower(artist) then
            title = EmoteTrim(rest);
        end
    end
    return title, artist;
end

-- Format the song-list *description*, without changing T: data used for
-- playback/sync or the separate /e emote formatter. Artist comes from C:.
function SongBook3Window:SongListText(song)
    local filename = song.Filename or "";
    if Settings.DescriptionVisible ~= "yes" then return filename; end
    local track = song.Tracks and song.Tracks[1] or nil;
    local description = track and track.Name or filename;
    if Settings.ShowArtist == "yes" then
        local artist = EmoteTrim(song.Artist or "");
        if artist == "" then artist = EmoteTrim(track and track.Artist or ""); end
        if artist ~= "" then
            local title, minutes, seconds, tail =
                description:match("^(.-)%s*%((%d+):(%d%d)%)%s*(.*)$");
            local time = nil;
            if title and EmoteTrim(title) ~= "" then
                title = EmoteTrim(title);
                time = "(" .. minutes .. ":" .. seconds .. ")";
                tail = EmoteTrim(tail);
                if tail ~= "" and not tail:match("^%-") then tail = "- " .. tail; end
            else
                -- In files without a duration, recognize a clear part suffix
                -- but don't mistake a hyphenated title for an instrument.
                local base, part = description:match("^(.-)%s+%-%s+(.+)$");
                if base and EmotePartAnnotation(part) then
                    title, tail = EmoteTrim(base), "- " .. EmoteTrim(part);
                else
                    title, tail = EmoteTrim(description), "";
                end
            end
            local ending = (tail ~= "") and " " .. tail or "";
            if time and Settings.ArtistAfterTime == "yes" then
                description = title .. " " .. time .. " " .. artist .. ending;
            else
                description = title .. " - " .. artist .. (time and " " .. time or "") .. ending;
            end
        end
    end
    if Settings.DescriptionFirst == "yes" then
        return description .. " / " .. filename;
    end
    return filename .. " / " .. description;
end

-- Search results show the total number of playable parts at the start of
-- each row. Folder browsing retains its existing label format.
function SongBook3Window:SearchSongListText(song)
    local partCount = song.Tracks and #song.Tracks or 0;
    return "(" .. tostring(partCount) .. ") " .. self:SongListText(song);
end

-- Update existing row labels rather than reselecting the first song. This
-- preserves folder/search results, the selected song, and currently ready track.
function SongBook3Window:RefreshSongListLabels()
    if not self.songlistBox or not self.aFilteredIndices then return; end
    for row = 1, self.songlistBox:GetItemCount() do
        local songIndex = self.aFilteredIndices[row];
        local song = songIndex and SongDB.Songs[songIndex];
        local label = self.songlistBox:GetItem(row);
        if song and label then
            local text = self.bShowingSongSearchResults and
                self:SearchSongListText(song) or self:SongListText(song);
            label:SetText(text);
        end
    end
end

function SongBook3Window:SetShowArtistInDescription(show)
    Settings.ShowArtist = show and "yes" or "no";
    self:RefreshSongListLabels();
end

function SongBook3Window:SetArtistAfterTime(afterTime)
    Settings.ArtistAfterTime = afterTime and "yes" or "no";
    self:RefreshSongListLabels();
end

function SongBook3Window:ExpandCmd(cmdId)
    local selTrack = self:SelectedTrackIndex();
    if librarySize == 0 then return; end
    local commandEntry = Settings.Commands[cmdId];
    local song = SongDB.Songs[selectedSongIndex];
    if not commandEntry or not song then return ""; end
    local cmd = commandEntry.Command or "";
    local track = song.Tracks and song.Tracks[selTrack];
    local trackName = track and track.Name or song.Filename or "";

    -- Only /e gets the concise song-level title; other custom chat commands
    -- retain the previous %name semantics and selected-part information.
    if cmd:match("^%s*/[eE]%s") then
        local title, artist = EmoteSongTitleAndArtist(song);
        local description = title;
        if artist ~= "" then description = description .. " by " .. artist; end
        cmd = cmd:gsub("%%name", function() return description; end);
    else
        cmd = cmd:gsub("%%name", function() return trackName; end);
    end
    cmd = cmd:gsub("%%file", function() return song.Filename or ""; end);
    cmd = cmd:gsub("%%part", function()
        return selTrack ~= 1 and tostring(selTrack) or "";
    end);
    return cmd;
end

function SongBook3Window:SaveSettings()
    Settings.SubWindowSizes = Settings.SubWindowSizes or {};
    if self.readyCheckWindow and self.setlistWindow and self.setlistShareWindow then
        local function Remember(key, window)
            Settings.SubWindowSizes[key] = {
                Width = tostring(window:GetWidth()),
                Height = tostring(window:GetHeight()),
            };
        end
        Remember("SyncCheck", self.readyCheckWindow);
        Remember("Setlists", self.setlistWindow);
        Remember("Share", self.setlistShareWindow);
        if self.lyricsWindow then Remember("Lyrics", self.lyricsWindow); end
    end
	Settings.WindowPosition.Left = tostring(self:GetLeft());
	Settings.WindowPosition.Top = tostring(self:GetTop());
	Settings.WindowPosition.Width = tostring(self:GetWidth());
	Settings.WindowPosition.Height = tostring(self:GetHeight());
	Settings.ToggleTop = tostring(Settings.ToggleTop);
	Settings.ToggleLeft = tostring(Settings.ToggleLeft);
	Settings.DirHeight = tostring(Settings.DirHeight);
	Settings.TracksHeight = tostring(Settings.TracksHeight);
	Settings.WindowOpacity = tostring(Settings.WindowOpacity);
	Settings.ToggleOpacity = tostring(Settings.ToggleOpacity);
	Settings.ArtistSearchVisible = tostring(self.bArtistSearch);
	Settings.ChiefMode = tostring( self.bLeaderMode )
	Settings.TimerState = tostring( self.bTimer )
	Settings.TimerCountdown = tostring( self.bTimerCountdown )
	Settings.ReadyColState = tostring( self.bShowReadyChars )
	Settings.ReadyColHighlight = tostring( self.bHighlightReadyCol )
	
	Settings.TimerWindowVisible = tostring( self.TimerWindowVisible )
	Settings.HelpWindowDisable = tostring( self.HelpWindowDisable )
	
	Settings.UseRaidChat = tostring( self.UseRaidChat )
	Settings.UseFellowshipChat = tostring( self.UseFellowshipChat )
	
	Settings.PlayersSyncInfoWindowPosition.Left = tostring(Sinduriel.SongBook3.Windows.Main.PlayersSyncInfoWindow:GetLeft());
	Settings.PlayersSyncInfoWindowPosition.Top = tostring(Sinduriel.SongBook3.Windows.Main.PlayersSyncInfoWindow:GetTop());
	Settings.PlayersSyncInfoWindowPosition.Width = tostring(Sinduriel.SongBook3.Windows.Main.PlayersSyncInfoWindow:GetWidth());
	Settings.PlayersSyncInfoWindowPosition.Height = tostring(Sinduriel.SongBook3.Windows.Main.PlayersSyncInfoWindow:GetHeight());
    if self.lyricsWindow and Settings.LyricsWindowPosition then
        Settings.LyricsDirHeight = tostring(self.lyricsDirHeight or 90);
        Settings.LyricsFileHeight = tostring(self.lyricsFileHeight or 125);
        Settings.LyricsWindowPosition.Left = tostring(self.lyricsWindow:GetLeft());
        Settings.LyricsWindowPosition.Top = tostring(self.lyricsWindow:GetTop());
        Settings.LyricsWindowPosition.Width = tostring(self.lyricsWindow:GetWidth());
        Settings.LyricsWindowPosition.Height = tostring(self.lyricsWindow:GetHeight());
    end
	
	CharSettings.UserChatNumber = tostring(CharSettings.UserChatNumber);
	CharSettings.InstrumentSlots_Rows = tostring(CharSettings.InstrumentSlots_Rows);
	
	for j = 1, CharSettings.InstrumentSlots_Rows do
		for i = 1, CharSettings.InstrSlots[j]["number"] do
			CharSettings.InstrSlots[j][tostring(i)].qsType = tostring(CharSettings.InstrSlots[j][tostring(i)].qsType);
		end
		CharSettings.InstrSlots[j]["number"] = tostring(CharSettings.InstrSlots[j]["number"]);
	end
	
	SongBook3Save( Turbine.DataScope.Account, gSettings, Settings,
		function( result, message )
			if ( result ) then
				Turbine.Shell.WriteLine( "<rgb=#00FF00>" .. Strings["sh_saved"] .. "</rgb>");
			else
				Turbine.Shell.WriteLine( "<rgb=#FF0000>" .. Strings["sh_notsaved"] .. " " .. message .. "</rgb>" );
			end
		end);
	SongBook3Save( Turbine.DataScope.Character, gSettings, CharSettings,
		function( result, message )
			if ( result ) then
				--Turbine.Shell.WriteLine( "<rgb=#00FF00>" .. Strings["sh_saved"] .. "</rgb>");
			else
				Turbine.Shell.WriteLine( "<rgb=#FF0000>" .. Strings["sh_notsaved"] .. " " .. message .. "</rgb>" );
			end
		end);	
end


-- Apply both search fields together. Any active search covers the whole library;
-- without a search, normal folder navigation shows the current directory.
function SongBook3Window:UpdateSongs()
    local titleQuery = self.searchInput and self.searchInput:GetText() or "";
    local artistQuery = self.bArtistSearch and self.artistSearchInput and
        self.artistSearchInput:GetText() or "";
    if titleQuery ~= "" or artistQuery ~= "" then
        self:SearchSongs();
    else
        self.songlistBox:ClearItems();
        self:LoadSongs();
        self:InitSonglist();
    end
end

-- Initialize song: List tracks, set/clear chat handler, set headings
function SongBook3Window:InitSonglist( )
	local nSongs = self.songlistBox:GetItemCount( );
	if nSongs > 0 then
		self:SelectSong( 1 );
	else
        selectedSong = "";
        selectedSongIndexListBox = 0;
		self.tracklistBox:ClearItems( );
		Sinduriel.SongBook3.Windows.Main.SyncInfolistbox:ClearItems( );
		--self:ClearSongState( )
		--Turbine.Chat.Received = nil; -- No tracks listed, so deactivate player ready indicator
		self.sepSongsTracks.heading:SetText( Strings["ui_parts"] .. " (0)" );
	end
	self.separator1.heading:SetText( Strings["ui_songs"] .. " (" .. nSongs .. ")" );
end -- UpdateSongs

-- Create compact track name by removing the title.
-- Note: Many songs have quite different naming schemes; not sure if it's even worth parsing.
function SongBook3Window:TerseTrackname( sTrack )
	return sTrack; -- disabled for now.
end

-- A T: title is the actual name LOTRO reports in sync/chat messages. Show
-- %%part-name in the part list when that title is not an instrument label,
-- without replacing the original title in the library or sync matching.
function SongBook3Window:TrackDisplayName( track )
	local title = track.Name or "";
	if track.PartName and track.PartName ~= "" and
	   self:FindInstrumentInTrack( title )[0] == 0 then
		return track.PartName;
	end
	return title;
end


function SongBook3Window:ClearSongState(  )
	syncedSongIndex = -1;
	syncedTrack = -1;
	self.aReadyTracks = "";
	self:ClearPlayerStates( );
	self:ClearSetups(  );
	self:SetTrackColours( selectedTrack );
	self:SetPlayerColours( );
	self:SetListboxColours( self.songlistBox );
end

function SongBook3Window:SongStarted(isLocalStart, trackName)
    if isLocalStart then self:MarkStartedSongPlayed(trackName); end
	self:ClearSongState(  )
	
	--Sinduriel.SongBook3.Windows.Main.Song_Label:SetText( string.sub( selectedSong, 1, 15 ) );
	Sinduriel.SongBook3.Windows.Main.Song_Label:SetText( Synced_Song_TrackName );
	
	songBook3Window.syncMessageTitle:SetText("");
	songBook3Window.syncMessageTitle:SetVisible(false);
	Sinduriel.SongBook3.Windows.Main.MatchedSongsWindow:SetVisible( false );

	self.syncStartSlotShortcut = Turbine.UI.Lotro.Shortcut( Turbine.UI.Lotro.ShortcutType.Undefined , "" );
	self.syncStartSlot:SetShortcut( self.syncStartSlotShortcut );
	self.syncStartSlot:SetVisible( true );
		
	if self.bInstrumentOk == false then
		self.tracksMsg:SetForeColor( self.colourDefault )
		self.tracksMsg:SetVisible( false )
		self.bInstrumentOk = true
	end
	if self.bTimer then self:StartTimer( )
	else --self:StopTimer( ) -- in case it is still counting ...
	end
end

--

-- Artist search replaces the retired multi-filter panel. It searches
-- song.Artist (from ABC C:) across all folders, independently of title search.
function SongBook3Window:CreateArtistSearchUI()
    self.artistSearchLabel = Turbine.UI.Label();
    self.artistSearchLabel:SetParent(self.listContainer);
    self.artistSearchLabel:SetPosition(4, 2);
    self.artistSearchLabel:SetSize(148, 18);
    self.artistSearchLabel:SetFont(Turbine.UI.Lotro.Font.Verdana14);
    self.artistSearchLabel:SetText(Strings["filterArtist"] or "Artist");
    self.artistSearchLabel:SetVisible(false);

    self.artistSearchInput = Turbine.UI.Lotro.TextBox();
    self.artistSearchInput:SetParent(self.listContainer);
    self.artistSearchInput:SetPosition(4, 20);
    self.artistSearchInput:SetSize(148, 20);
    self.artistSearchInput:SetFont(Turbine.UI.Lotro.Font.Verdana14);
    self.artistSearchInput:SetMultiline(false);
    self.artistSearchInput:SetBackColor(Turbine.UI.Color(0.2, 0.2, 0.2));
    self.artistSearchInput:SetVisible(false);
    self.artistSearchInput.KeyDown = function(sender, args)
        if args.Action == 162 then self:UpdateSongs(); end
    end;

    self.artistSearchButton = Turbine.UI.Lotro.Button();
    self.artistSearchButton:SetParent(self.listContainer);
    self.artistSearchButton:SetPosition(4, 43);
    self.artistSearchButton:SetSize(73, 20);
    self.artistSearchButton:SetText(Strings["ui_search"] or "Search");
    self.artistSearchButton:SetVisible(false);
    self.artistSearchButton.MouseClick = function() self:UpdateSongs(); end;

    self.artistClearButton = Turbine.UI.Lotro.Button();
    self.artistClearButton:SetParent(self.listContainer);
    self.artistClearButton:SetPosition(80, 43);
    self.artistClearButton:SetSize(72, 20);
    self.artistClearButton:SetText(Strings["ui_clear"] or "Clear");
    self.artistClearButton:SetVisible(false);
    self.artistClearButton.MouseClick = function()
        self.artistSearchInput:SetText("");
        self:UpdateSongs();
    end;

    self.separatorArtistSearch = Turbine.UI.Control();
    self.separatorArtistSearch:SetParent(self.listContainer);
    self.separatorArtistSearch:SetZOrder(300);
    self.separatorArtistSearch:SetBackColor(Turbine.UI.Color(1, 0.15, 0.15, 0.15));
    self.separatorArtistSearch:SetPosition(156, self.dirlistBox:GetTop());
    self.separatorArtistSearch:SetSize(10, self.dirlistBox:GetHeight());
    self.separatorArtistSearch:SetVisible(false);
end

function SongBook3Window:ShowArtistSearchUI(show)
    self.bArtistSearch = show;
    self.artistSearchLabel:SetVisible(show);
    self.artistSearchInput:SetVisible(show);
    self.separatorArtistSearch:SetVisible(show);
    -- Player data remains in the hidden listbox for Sync/setup calculations.
    -- The old Players sidebar is intentionally no longer part of the UI.
    self:ResizeAll();
    self:UpdateSongs();
end

function SongBook3Window:AdjustArtistSearchUI()
    local height = self.dirlistBox:GetHeight();
    local showButtons = self.bArtistSearch and height >= 67;
    self.artistSearchButton:SetVisible(showButtons);
    self.artistClearButton:SetVisible(showButtons);
    self.separatorArtistSearch:SetHeight(height);
end

function SongBook3Window:CheckInstrument( sTrack )
	local player = Turbine.Gameplay.LocalPlayer:GetInstance( );
	if not player then return; end
	local equip = player:GetEquipment( )
	if not equip then return; end
	local item = equip:GetItem( Turbine.Gameplay.Equipment.Instrument )
	if not item then return; end
	sTrack = sTrack:lower()
	--local sName = string.match( item:GetName( ), "%a+$" )
	self.bInstrumentOk = true -- only set to false if we can successfully determine track and equipped instrument
	local iName = self:GetInstrumentName( item:GetName( ):lower( ) )
	if not iName then return; end -- can't determine equipped instrument, disable message

	local iTrackInstrument = self:CheckTracksForInstrument( sTrack, iName, self.aInstruments ) -- try english names first
	if not iTrackInstrument then -- try localized names
		iTrackInstrument = self:CheckTracksForInstrument( sTrack, iName, aInstrumentsLoc )
	end

	if not iTrackInstrument then return; end -- could not determine the track instrument
	self:SetInstrumentMessage( aInstrumentsLoc[ iTrackInstrument ] ) -- print the localized name
end

function SongBook3Window:GetInstrumentName( sItem )
	if self.aSpecialInstruments and self.aSpecialInstruments[ sItem ] then
		return self.aSpecialInstruments[ sItem ] -- already contains the index 
	end
	for k,v in pairs( aInstrumentsLoc ) do
		if sItem:find( v ) then return k; end
	end
	return nil
end

function SongBook3Window:CheckTracksForInstrument( sTrack, iInstrument, aInstruments )
	if not iInstrument or iInstrument > #aInstruments then return nil; end
	local sName = aInstruments[ iInstrument ]
	for k,v in pairs( aInstruments ) do
		if sTrack:find( v ) then -- track name seems to contain the instrument name
			self.bInstrumentOk = not not string.find( sTrack, "[^%a]" .. sName:lower() )
			return k
		end
	end
	return nil
end
	

function SongBook3Window:SetInstrumentMessage( sInstr )
	if self.bInstrumentOk then
		self.tracksMsg:SetFont( Turbine.UI.Lotro.Font.BookAntiquaBold22 );
		self.tracksMsg:SetForeColor( self.colourDefault )
		self.tracksMsg:SetVisible( false )
	else
		self.tracksMsg:SetFont( Turbine.UI.Lotro.Font.BookAntiquaBold18 );
		self.tracksMsg:SetForeColor( self.colourWrongInstrument )
		self.tracksMsg:SetText( sInstr .. Strings["instr"] )
		self.tracksMsg:SetVisible( true )
	end
end


-- Add player to the fellowship list
function SongBook3Window:AddPlayerToList( sPlayername )
	if( self.listboxPlayers == nil ) then return; end -- Listbox not created yet

	local memberItem = Turbine.UI.Label( );
	memberItem:SetText( sPlayername );
	memberItem:SetTextAlignment( Turbine.UI.ContentAlignment.MiddleLeft );
	memberItem:SetSize( 100, 20 );				
	self.listboxPlayers:AddItem( memberItem );
end

-- Remove player from the fellowship list
function SongBook3Window:RemovePlayerFromList( sPlayername )
	if( self.listboxPlayers == nil ) then return; end -- Listbox not created yet

	local i, item = self:GetItemFromList( self.listboxPlayers, sPlayername )
	if i then self.listboxPlayers:RemoveItemAt( i ); end
end

-- Get index and item for player name from player listbox
function SongBook3Window:GetItemFromList( listbox, sText )
	local i, item
	for i = 1, listbox:GetItemCount( ) do
		item = listbox:GetItem( i )
		if item:GetText( ) == sText then return i, item; end
	end
	return nil, nil
end
		


function SongBook3Window:EnableReadyColumns( bOn )
	self.listboxPlayers:EnableCharColumn( bOn )
	self.tracklistBox:EnableCharColumn( bOn )
end

function SongBook3Window:ShowReadyColumns( bShow )
	if self.bShowReadyChars == bShow then return; end
	self.bShowReadyChars = bShow
	self:EnableReadyColumns( bShow )
	if selectedSongIndex then
		--self:ListTracks( selectedSongIndex )
		--self:RefreshPlayerListbox( )
		self:SetTrackColours( selectedTrack );
		self:SetPlayerColours( );
	end
end

function SongBook3Window:HightlightReadyColumns( bOn )
	self.listboxPlayers.bHighlightReadyCol = bOn
	self.tracklistBox.bHighlightReadyCol = bOn
end


-- Read party member names and add them to the party members listbox

function SongBook3Window:RefreshPlayerListbox( )
	if self.listboxPlayers == nil then return; end
	
	self.listboxPlayers:ClearItems( );

	local player = Turbine.Gameplay.LocalPlayer:GetInstance( );
	if player == nil then return; end
	
	if self.sPlayerName == nil then self.sPlayerName = player:GetName( ); end
	
	local party = player:GetParty( );
	if party == nil or party:GetMemberCount( ) <= 0 then
		if self.bLeaderMode then	self.aPlayers = { }; self.aCurrentSongReady = { }; end
		self:AddPlayerToList( self.sPlayerName )
		self.aPlayers[ self.sPlayerName ] = 0;
		self.Players_Data[ self.sPlayerName ] = 0;
		return;
	end 

	-- When leader mode is enabled, we rely on the party object; otherwise, we keep the known players.
	if self.bLeaderMode then	self.aPlayers = { }; self.Players_Data = { }; self.aCurrentSongReady = { }; self.bandSyncReports = {};
	else self:ListKnownPlayers( ); end
	
	local iPlayer;
	for iPlayer = 1, party:GetMemberCount( ) do
		local member = party:GetMember( iPlayer )
		local sName = member:GetName( )
		if self.aPlayers[ sName ] == nil then self:AddPlayer( sName ); end
	end
	
	self:SetPlayerColours( ); -- restore current states
	self:UpdateMaxPartCount( )
	if self.maxPartCount then self:UpdateSongs( ) end
	self:UpdateSetupColours( );
end

-- Add player to arrays
function SongBook3Window:AddPlayer( sName )
	if self.aPlayers[ sName ] then return; end
	self.aCurrentSongReady[ sName ] = false
	self:AddPlayerToList( sName )
	self.aPlayers[ sName ] = 0
	self.Players_Data[ sName ] = 0
end

-- Add player to arrays
function SongBook3Window:RemovePlayer( sName )
	if not self.aPlayers[ sName ] then return; end
	self.aCurrentSongReady[ sName ] = nil
	self:RemovePlayerFromList( sName )
	self.aPlayers[ sName ] = nil
	self.Players_Data[ sName ] = nil
    if self.bandSyncReports then self.bandSyncReports[sName] = nil; end
end


-- Write known players to player listbox
function SongBook3Window:ListKnownPlayers( )
	if not self.aPlayers then return; end
	for k,v in pairs( self.aPlayers ) do
		self:AddPlayerToList( k )
	end
end


-- Parse player join message, add player
-- Party object occasionally seems to become stale in raid settings, so we try to use client messages for player list updates
function SongBook3Window:PlayerJoined( sMsg )
	local temp, sPlayerName, sTrackName;
	temp, temp, sPlayerName = string.find( sMsg, "(%a+)" .. Strings["chat_playerJoin"] );
	if sPlayerName then self:AddPlayer( sPlayerName ); end
	self:PlayerSyncInfo();
end

-- Parse player left message, remove player
function SongBook3Window:PlayerLeft( sMsg )
	local temp, sPlayerName, sTrackName;
	temp, temp, sPlayerName = string.find( sMsg, "(%a+)" .. Strings["chat_playerLeave"] );
	if sPlayerName then self:RemovePlayer( sPlayerName ); end
	self:PlayerSyncInfo();
end


-- Clear the ready states for players
function SongBook3Window:ClearPlayerStates( )
	if not self.aPlayers then return; end
	for k in pairs( self.aPlayers ) do
		self.aPlayers[ k ] = 0; -- present, no song ready
		self.Players_Data[ k ] = 0;
        if self.bandSyncReports then self.bandSyncReports[k] = nil; end
	end
end


-- Update item colours in party listbox to indicate ready states
function SongBook3Window:SetPlayerColours( )
	if not self.aPlayers or not self.listboxPlayers then return; end

	local iMember;
	for iMember=1,self.listboxPlayers:GetItemCount( ) do
		local item = self.listboxPlayers:GetItem( iMember );
		if( self.aPlayers[ item:GetText( ) ] == nil ) then	-- should not happen
			item:SetForeColor( self.colourDefault );
			if self.bShowReadyChars then self.listboxPlayers:SetColumnChar( iMember, self.chNone, false ); end
		elseif( self.aPlayers[ item:GetText( ) ] == 0 ) then -- present, but no song ready
			item:SetForeColor( self.colourDefault );
			if self.bShowReadyChars then self.listboxPlayers:SetColumnChar( iMember, self.chNone, false ); end
		elseif self.aCurrentSongReady and self.aCurrentSongReady[ item:GetText( ) ] == 1 then 
			item:SetForeColor( self.colourReady ); -- Track from the currently displayed song ready
			if self.bShowReadyChars then self.listboxPlayers:SetColumnChar( iMember, self.chReady, false ); end
		elseif self.aCurrentSongReady and self.aCurrentSongReady[ item:GetText( ) ] == 2 then 
			item:SetForeColor( self.colourReadyMultiple ); -- Correct song, but same track as another player
			if self.bShowReadyChars then self.listboxPlayers:SetColumnChar( iMember, self.chMultiple, true ); end
		elseif self.aCurrentSongReady and self.aCurrentSongReady[ item:GetText( ) ] == 3 then 
			item:SetForeColor( self.colourDifferentSetup ); -- Correct song, but track not in current setup
			if self.bShowReadyChars then self.listboxPlayers:SetColumnChar( iMember, self.chWrongPart, true ); end
		else
			item:SetForeColor( self.colourDifferentSong ); -- Track ready, but different song
			if self.bShowReadyChars then self.listboxPlayers:SetColumnChar( iMember, self.chWrongSong, true ); end
		end
	end
end

-- Create party member listbox
function SongBook3Window:CreatePartyListbox( )
	local songsHeight = self.songlistBox:GetHeight( );
	local songsTop = self.songlistBox:GetTop( );
	if( songsHeight < 40 ) then songsHeight = 40; end

	-- Retain the player list as an internal (always hidden) readiness cache.
	self.listboxPlayers = ListBoxCharColumn:New( 10, 20 );
	self.listboxPlayers:SetParent( self.listContainer );
	self.listboxPlayers:SetSize( 80, songsHeight - 20 );
	self.listboxPlayers:SetPosition( 2 , songsTop + 20 );
	self.listboxPlayers:SetVisible( false );
end

-- Use the number of currently listed players as limit for part counts
function SongBook3Window:SetMaxPartCount( bActivate )
	--self:RefreshPlayerListbox( )
	if bActivate and self.listboxPlayers then self.maxPartCount = self.listboxPlayers:GetItemCount( )
	else self.maxPartCount = nil;
	end
end

-- Due to party object issues, we only increase partcount here
function SongBook3Window:UpdateMaxPartCount( )
	if self.maxPartCount and self.listboxPlayers and self.maxPartCount < self.listboxPlayers:GetItemCount( ) then
		self.maxPartCount = self.listboxPlayers:GetItemCount( )
	end
end

-- Create listbox to show the possible setup counts
function SongBook3Window:CreateSetupsListbox( )
	self.listboxSetups = ListBoxScrolled:New( 10 );
	self.listboxSetups:SetParent( self.listContainer );
	self.listboxSetups:SetSize( self.listboxSetupsWidth - 0, self.tracklistBox:GetHeight( ) );
	self.listboxSetups:SetPosition( 0, self.tracklistBox:GetTop() );
	self.listboxSetups:SetVisible( self.bShowSetups );
	self.listboxSetups.SelectedIndexChanged =
		function( sender, args )
			self:ListTracksForSetup( sender:GetSelectedIndex( ) );
		end
end

function SongBook3Window:SelectSetup( iSetup )
	if not self.listboxSetups then return; end
	if not iSetup or iSetup > self.listboxSetups:GetItemCount( ) then iSetup = self.listboxSetups:GetItemCount( ); end
	self.listboxSetups:SetSelectedIndex( iSetup )
	self:ListTracksForSetup( iSetup )
end

function SongBook3Window:ListTracksForSetup( iSetup )
	if not SongDB.Songs[selectedSongIndex] or not SongDB.Songs[selectedSongIndex].Setups then return; end
	
	for iItem = 1, self.listboxSetups:GetItemCount( ) do
		self.listboxSetups:GetItem( iItem ):SetBackColor( self.backColourDefault );
	end

	local selTrack = self.tracklistBox:GetSelectedIndex( );
	
	self.aSetupTracksIndices = { };
	self.aSetupListIndices = { };
	self.iCurrentSetup = nil;

	if not iSetup or iSetup >= self.listboxSetups:GetItemCount( ) then
		self:ListTracks( selectedSongIndex );
		self.selectedSetupCount = nil
	else
		self.iCurrentSetup = iSetup;
		self.tracklistBox:ClearItems( );
		Sinduriel.SongBook3.Windows.Main.SyncInfolistbox:ClearItems( );
		for i = 1, #SongDB.Songs[selectedSongIndex].Setups[ iSetup ] do
			local iTrack = SongDB.Songs[selectedSongIndex].Setups[ iSetup ]:byte( i ) - 64;
			self.aSetupTracksIndices[ i ] = iTrack;
			self.aSetupListIndices[ iTrack ] = i;
			self:AddTrackToList( selectedSongIndex, iTrack )
		end
		self.selectedSetupCount = #SongDB.Songs[selectedSongIndex].Setups[ iSetup ]
	end

	local selItem = self.listboxSetups:GetSelectedItem( );
	if selItem then selItem:SetBackColor( self.backColourHighlight ); end
	
	self:SelectTrack( 1 ); --selTrack );
	self:SetPlayerColours( );
	local found = self.tracklistBox:GetItemCount( );
	self.sepSongsTracks.heading:SetText( Strings["ui_parts"] .. " (" .. found .. ")" );
end

function SongBook3Window:SetupIndexForCount( iSong, setupCount )
	if not setupCount or not SongDB.Songs[iSong] or not SongDB.Songs[iSong].Setups then return nil; end
	for i = 1, #SongDB.Songs[iSong].Setups do
		if setupCount == #SongDB.Songs[iSong].Setups[ i ] then return i; end
	end
	return i
end

function SongBook3Window:UpdateSetupColours(  )
	if not self.listboxSetups or not SongDB.Songs[selectedSongIndex] or not SongDB.Songs[selectedSongIndex].Setups then return; end
	
	self:UpdateTrackReadyString( );

	local item;
	local matchPattern;
	local antiMatchPattern;
	local matchLength = 0;
	for i = 1, self.listboxSetups:GetItemCount( ) - 1 do
		item = self.listboxSetups:GetItem( i );

		matchPattern = "[" .. SongDB.Songs[selectedSongIndex].Setups[ i ] .. "]";
		antiMatchPattern = "[^" .. SongDB.Songs[selectedSongIndex].Setups[ i ] .. "]";
		_, matchLength = string.gsub( self.aReadyTracks, matchPattern, " " )

		if SongDB.Songs[selectedSongIndex].Setups[ i ] == self.aReadyTracks then
			item:SetForeColor( self.colourReady );
		elseif string.match( self.aReadyTracks, antiMatchPattern ) then
			item:SetForeColor( Turbine.UI.Color( 0.7, 0, 0 ) );
		elseif matchLength and matchLength + 1 == #SongDB.Songs[selectedSongIndex].Setups[ i ] then
			item:SetForeColor( Turbine.UI.Color( 0, 0.7, 0 ) );
		else
			item:SetForeColor( self.colourDefault );
		end
	end
end

function SongBook3Window:ClearSetups(  )
	if not self.listboxSetups then return; end	
	local selItem = self:SetListboxColours( self.listboxSetups, true );
	if selItem then selItem:SetBackColor( self.backColourHighlight ); end
end

function SongBook3Window:UpdateTrackReadyString( )
	self.aReadyTracks = "";
	for iList = 1,self.tracklistBox:GetItemCount( ) do
		local i = self:SelectedTrackIndex( iList );
		local ReadyState = self:GetTrackReadyState(  selectedSongIndex, i );
		
		if ReadyState[4] > 0 then
			self.aReadyTracks = self.aReadyTracks .. string.char( 0x40 + i );
		end
	end
end
		

-- Add an item with the given text to the given listbox
function SongBook3Window:AddItemToList( sText, listbox, width )
	if( listbox == nil ) then return; end -- Listbox not created yet

	local item = Turbine.UI.Label( );
	item:SetText( sText );
	item:SetTextAlignment( Turbine.UI.ContentAlignment.MiddleCenter );
	item:SetSize( width, 20 );				
	listbox:AddItem(item);
end


function SongBook3Window:ListSetups( songID )
	if not self.listboxSetups or not self.listboxPlayers then return; end
	self.listboxSetups:ClearItems( )
	if not SongDB or not SongDB.Songs[songID] or not SongDB.Songs[songID].Setups then
		self:ShowSetups( false )
		return;
	end

	self:ShowSetups( true )
	local playerCount;
	if not self.maxPartCount then playerCount = 1000;
	else playerCount = self.maxPartCount; end
--playerCount = 6;	
	local countInSetup;
	for i = 1, #SongDB.Songs[songID].Setups do
		countInSetup = #SongDB.Songs[songID].Setups[ i ];
		if countInSetup <= playerCount then
			self:AddItemToList( countInSetup, self.listboxSetups, self.listboxSetupsWidth );
		end
	end
	self:AddItemToList( "A", self.listboxSetups, self.listboxSetupsWidth );
end


function SongBook3Window:ClearPlayerReadyStates( )
	if( self.aPlayers ~= nil ) then
		for k,v in pairs( self.aPlayers ) do
			self.aCurrentSongReady[ k ] = false;
		end
	end
end


function SongBook3Window:SetLeaderMode( bState )
	self.bLeaderMode = (bState==true)
	self.syncStartSlot:SetVisible( self.bLeaderMode )
	self.syncStartIcon:SetVisible( self.bLeaderMode )
end

function SongBook3Window:SetListboxColours( listbox, bNoSelectionHighlight )
	for i = 1,listbox:GetItemCount() do
		local item = listbox:GetItem( i );
		local SongIndex = self.aFilteredIndices[ i ];
		
		local ReadyState = self:GetSongReadyState( SongIndex );
		
		if ReadyState[0] == nil then
			item:SetForeColor( self.colourDefault );
			item:SetBackColor( self.backColourDefault );
		elseif ReadyState[0] == 10 then
			item:SetForeColor( self.colourSyncedHighlighted );
			if ReadyState[1] == "LocalPlayer" then
				item:SetBackColor( self.backColourHighlight );
			else
				item:SetBackColor( self.backColourDefault );
			end
		elseif ReadyState[0] == 0 then
			item:SetForeColor( self.colourReadyMultiple2 );
			if ReadyState[1] == "LocalPlayer" then
				item:SetBackColor( self.backColourHighlight );
			else
				item:SetBackColor( self.backColourDefault );
			end
		end
	end
	if bNoSelectionHighlight then return nil; end 
	local selectedItem = listbox:GetSelectedItem( )
	if selectedItem then selectedItem:SetForeColor( self.colourDefaultHighlighted ); end
	return selectedItem;
end

function SongBook3Window:CreateSeparator(left, top, width, height)
	local separator = Turbine.UI.Control();
	separator:SetParent(self.listContainer);
	separator:SetZOrder(300);
	separator:SetBackColor(Turbine.UI.Color(1, 0.15, 0.15, 0.15));
	separator:SetPosition( left, top );
	separator:SetSize(width,height);
	separator:SetVisible( false );
	return separator;
end

function SongBook3Window:CreateMainSeparator(top)
	return self:CreateSeparator(0, top, self.listContainer:GetWidth(), 13);
end

function SongBook3Window:CreateSeparatorHeading(parent, sText)
	local heading = Turbine.UI.Label();
	heading:SetParent(parent);
	heading:SetLeft(0);
	heading:SetSize(100,13);
	heading:SetFont(Turbine.UI.Lotro.Font.TrajanPro13);
	heading:SetText(sText);
	heading:SetMouseVisible(false);
	return heading;
end

function SongBook3Window:CreateSeparatorArrows(parent)
	local arrows = Turbine.UI.Control();
	arrows:SetParent(parent);
	arrows:SetZOrder(310);
	arrows:SetBackground(gDir .. "arrows.tga");
	arrows:SetSize(20,10);
	arrows:SetPosition(parent:GetWidth( ) / 2 - 10, 1);
	arrows:SetMouseVisible( false );
	return arrows;
end

function SongBook3Window:CreateMainShortcut(left)
	local slot = Turbine.UI.Lotro.Quickslot();
	slot:SetParent(self);
	slot:SetPosition(left, 50 + ShiftTop);
	slot:SetSize(32, 30);
	slot:SetZOrder(100);
	slot:SetAllowDrop(false);
	slot:SetVisible( true );
	return slot;
end

function SongBook3Window:CreateMainIcon(left,sImageName)
	local icon = Turbine.UI.Control();
	icon:SetParent( self );
	icon:SetPosition(left, 50 + ShiftTop);
	icon:SetSize(35, 35);
	icon:SetZOrder(110);
	icon:SetMouseVisible(false);
	icon:SetBlendMode( Turbine.UI.BlendMode.AlphaBlend );
	icon:SetBackground(gDir .. sImageName .. ".tga" );
	return icon;
end

function SongBook3Window:AddScrollbar(parent,listbox,xPos,yPos)
	local scroll = Turbine.UI.Lotro.ScrollBar();
	scroll:SetParent( parent );
	scroll:SetOrientation( Turbine.UI.Orientation.Vertical );
	scroll:SetPosition( xPos, yPos )
	scroll:SetHeight( listbox:GetHeight() );
	scroll:SetZOrder(320);
	scroll:SetWidth(10);
	scroll:SetValue(0);
	listbox:SetVerticalScrollBar( scroll );
	scroll:SetVisible( false );
	return scroll;
end


function SongBook3Window:SetSonglistHeight( height )
	self.songlistBox:SetHeight( height );
	self.sepSongsTracks:SetTop(self.listContainer:GetHeight() - self.tracklistBox:GetHeight() - 13);
	self.listboxPlayers:SetHeight( height - 20 );
end

function SongBook3Window:AdjustSonglistHeight( )
	local height = self.listContainer:GetHeight() - self.dirlistBox:GetHeight() - 13;
	if Settings.TracksVisible == "yes" then height = height - self.tracklistBox:GetHeight() - 13; end
	self:SetSonglistHeight( height )
end

function SongBook3Window:SetSonglistTop( top )
	self.songlistBox:SetTop( top );
	self.separator1:SetTop( top - 13 );
	self.listboxPlayers:SetTop( top + 20 );
end

function SongBook3Window:AdjustSonglistLeft( )
	-- No Players sidebar: the song list uses the available width.
	self.songlistBox:SetLeft( 0 );
	self.songlistBox:SetWidth( self.listContainer:GetWidth( ) - 10 );
end

function SongBook3Window:AdjustSonglistPosition( )
	self:AdjustSonglistLeft( )
	self:SetSonglistTop( self.dirlistBox:GetHeight() + 13 )
	self.separator1:SetWidth( self.listContainer:GetWidth() );
	self.sArrows1:SetLeft( self.separator1:GetWidth() / 2 - 10 );
end

function SongBook3Window:AdjustDirlistSize( )
	local width = self.listContainer:GetWidth( ) - 10;
	local height = self.listContainer:GetHeight() - self.songlistBox:GetHeight() - 13;

	if self.bArtistSearch then width = width - 170; end
	if Settings.TracksVisible == "yes" then height = height - Settings.TracksHeight - 13; end

	self.dirlistBox:SetSize( width, height );
end

function SongBook3Window:AdjustDirlistPosition( )
	local xPos = 0;
	if self.bArtistSearch then xPos = xPos + 170; end
	self.dirlistBox:SetPosition( xPos , 0 );
	self.dirlistBox:SetWidth( self.listContainer:GetWidth( ) - xPos - 10 );
end

function SongBook3Window:ShowTrackListbox( bShow )
	self.tracklistBox:SetVisible( bShow );
	self.sepSongsTracks:SetVisible( bShow );
	self.sArrows2:SetVisible( bShow );		
end

function SongBook3Window:SetTracklistTop( top )

	if top < self.songlistBox:GetTop() + 13 + 40 then
		top = self.songlistBox:GetTop() + 13 + 40;
	end	
		
	self.tracklistBox:SetTop( top )
	self.sepSongsTracks:SetTop( top - 13 )
	self.listboxSetups:SetTop( top );
	self.tracksMsg:SetTop( top - 15 - 3 );
end

function SongBook3Window:MoveTracklistTop( delta )
	self:SetTracklistTop( self.tracklistBox:GetTop( ) + delta )
end

function SongBook3Window:AdjustTracklistLeft( )
	if self.bShowSetups then self.tracklistBox:SetLeft( self.setupsWidth )
	else self.tracklistBox:SetLeft( 0 ) end
end

function SongBook3Window:AdjustTracklistWidth( )
	local width = self.listContainer:GetWidth( ) - 10
	if self.bShowSetups then width = width - self.setupsWidth end
	self.tracklistBox:SetWidth( width )
	--if self.alignTracksRight == true then self:AdjustTracklistItemsPosition( width ) end
	if self.alignTracksRight == true then self:RealignTracknames( ) end
	self.sepSongsTracks:SetWidth( self.listContainer:GetWidth( ) )
	self.sArrows2:SetLeft( self.sepSongsTracks:GetWidth() / 2 - 10 )
	self.tracksMsg:SetLeft( self.tracklistBox:GetLeft( ) + width - self.tracksMsg:GetWidth( ) )
end

function SongBook3Window:AdjustTracklistItemsPosition( width )
	for i = 1, self.tracklistBox:GetItemCount( ) do
		local item = self.tracklistBox:GetItem( i )
		item:SetLeft( width - 1000 )
	end
end

function SongBook3Window:SetTracklistHeight( height )
	self.tracklistBox:SetHeight( height )			
	self.listboxSetups:SetHeight( height );
end

function SongBook3Window:AdjustTracklistSize( height )
	self:AdjustTracklistWidth( )
	self:SetTracklistHeight( height )
end

function SongBook3Window:UpdateTracklistTop( )
	self:SetTracklistTop( self.listContainer:GetHeight() - self.tracklistBox:GetHeight() )
end

function SongBook3Window:ShowSetups( bShow )
	if bShow and not self.bShowSetups then 
		self.bShowSetups = true
		self.listboxSetups:SetVisible( true )
		self:AdjustTracklistLeft( )
		self:AdjustTracklistWidth( )
	elseif not bShow and self.bShowSetups then 
		self.bShowSetups = false
		self.listboxSetups:ClearItems( )
		self.listboxSetups:SetVisible( false )
		self:AdjustTracklistLeft( )
		self:AdjustTracklistWidth( )
	end
end


function AddCallback(object, event, callback)
    if (object[event] == nil) then
        object[event] = callback;
    else
        if (type(object[event]) == "table") then
            table.insert(object[event], callback);
        else
            object[event] = {object[event], callback};
        end
    end
    return callback;
end

function RemoveCallback(object, event, callback)
    if (object[event] == callback) then
        object[event] = nil;
    else
        if (type(object[event]) == "table") then
            local size = table.getn(object[event]);
            for i = 1, size do
                if (object[event][i] == callback) then
                    table.remove(object[event], i);
                    break;
                end
            end
        end
    end
end

-- A second plugin can accidentally replace the shared chat event (rather
-- than adding a callback), removing SongBook3's sync listener. Restore it
-- without overwriting that plugin's handler. Called before sync/chat actions.
function SongBook3Window:EnsureChatListener()
    local registered = Turbine.Chat.Received;
    if registered == ChatHandler then return; end
    if type(registered) == "table" then
        for _, callback in ipairs(registered) do
            if callback == ChatHandler then return; end
        end
    end
    AddCallback(Turbine.Chat, "Received", ChatHandler);
    if self.chatListenerWasInstalled then
        Turbine.Shell.WriteLine("SongBook3: Chat listener restored after another plugin changed it.");
    end
    self.chatListenerWasInstalled = true;
end

--

-- action for changing track selection (trackid is listbox index)
function SongBook3Window:SelectTrack( trackid )
	if self.bShowReadyChars then trackid = math.floor( (trackid+1) / 2 ); end
	selectedTrack = trackid;
	local iTrack = self:SelectedTrackIndex( trackid );

	self.trackNumber:SetText(SongDB.Songs[selectedSongIndex].Tracks[iTrack].Id);
	self.songTitle:SetText(SongDB.Songs[selectedSongIndex].Tracks[iTrack].Name);

	self.playSlotShortcut = Turbine.UI.Lotro.Shortcut( Turbine.UI.Lotro.ShortcutType.Alias, Strings["cmd_play"] .. " \"" .. SongDB.Songs[selectedSongIndex].Filepath .. selectedSong .. "\" " .. SongDB.Songs[selectedSongIndex].Tracks[iTrack].Id);
	self.playSlot:SetShortcut( self.playSlotShortcut );
	self.playSlot:SetVisible( true );

	self.playSyncShortcut = Turbine.UI.Lotro.Shortcut( Turbine.UI.Lotro.ShortcutType.Alias, Strings["cmd_play"] .. " \"" .. SongDB.Songs[selectedSongIndex].Filepath .. selectedSong .. "\" " .. SongDB.Songs[selectedSongIndex].Tracks[iTrack].Id .. " " .. Strings["cmd_sync"]);
    self.syncSlotSendsInfo = false;
    self.syncInfoSendPending = false;
    self.syncIcon:SetBackground(gDir .. "icn_s.tga");
    self.syncSlotShortcut = self.playSyncShortcut;
	self.syncSlot:SetShortcut( self.syncSlotShortcut );
	self.syncSlot:SetVisible( true );
	
	self.shareSlot:SetShortcut( Turbine.UI.Lotro.Shortcut( Turbine.UI.Lotro.ShortcutType.Alias, self:ExpandCmd(Settings.DefaultCommand)));		
	self.shareSlot:SetVisible( true );
--

	self:PlayerSyncInfo();
	
	if YouDontHaveTheSameSong_Flag == 0 then
		
		if OtherPlayer_SyncedSong_Filepath .. OtherPlayer_SyncedSong_Filename == SongDB.Songs[selectedSongIndex].Filepath .. selectedSong then
			self.syncMessageTitle:SetVisible(false);
		else
			if OtherPlayer_SyncedSong_Filepath .. OtherPlayer_SyncedSong_Filename ~= "" then
				if self.syncMessageTitle:GetText() ~= "" then
					self.syncMessageTitle:SetVisible(true);
				end
			end
		end
	end
	
	self:SetTrackColours( selectedTrack );
end

-- action for setting focus on the track list
function SongBook3Window:SetTrackColours( iSelectedTrack )
	if not self.tracklistBox or self.tracklistBox:GetItemCount( ) < 1 then return; end
	self:ClearPlayerReadyStates( ); -- Clear ready states for currently displayed song
	local trackcount = #SongDB.Songs[selectedSongIndex].Tracks;
	
	for iTrack = 1,trackcount do
		if self.iCurrentSetup and not self.aSetupListIndices[ iTrack ] then
			self:GetTrackReadyState( selectedSongIndex, iTrack, 3 );
		else
			local iList = iTrack;
			if self.aSetupListIndices[ iTrack ] then iList = self.aSetupListIndices[ iTrack ]; end
			local item = self.tracklistBox:GetItem(iList);
			local readyState = self:GetTrackReadyState( selectedSongIndex, iTrack );
			
			
			
			item:SetForeColor( self:GetColourForTrack( readyState[0], iList == iSelectedTrack ) );
			item:SetBackColor( self:GetBackColourForTrack( readyState[0] , readyState[1] , readyState[8] ) );
			
			
			self:SetTrackReadyChar( iList, readyState[0] );
			
			local Track_Instrument = self:FindInstrumentForTrack( SongDB.Songs[selectedSongIndex].Tracks[iTrack] );
			local Track_item = Sinduriel.SongBook3.Windows.Main.SyncInfolistbox:GetItem(iTrack);
			Track_item:SetText( "[" .. SongDB.Songs[selectedSongIndex].Tracks[iTrack].Id .. "] " .. Track_Instrument[1] );
			
			Track_item:SetForeColor( self:GetColourForTrack( readyState[0], iList == iSelectedTrack ) );
			Track_item:SetBackColor( self:GetBackColourForTrack( readyState[0] , readyState[1] , readyState[8] ) );
						
			for i = 0, readyState[4]-1 do
				if tonumber( readyState[3][i] ) > 0 then
					Track_item:AppendText("  - <rgb=0x00FF00>" .. readyState[2][i] .. "</rgb> [<rgb=0x00FF80>" .. 
						self.Instruments_List[tonumber( readyState[3][i] )][1] .. "</rgb>]" );
				else
					Track_item:AppendText("  - <rgb=0x00FF00>" .. readyState[2][i] .. "</rgb> [<rgb=0x00FF80>No Instrument</rgb>]" );
				end
			end
			
			for i = 0, readyState[7]-1 do
				if tonumber( readyState[6][i] ) > 0 then
					Track_item:AppendText("  - <rgb=0xFF0000>" .. readyState[5][i] .. "</rgb> [<rgb=0xFF0080>" .. 
						self.Instruments_List[tonumber( readyState[6][i] )][1] .. "</rgb>]" );
				else
					Track_item:AppendText("  - <rgb=0xFF0000>" .. readyState[5][i] .. "</rgb> [<rgb=0xFF0080>No Instrument</rgb>]" );
				end
			end
			
			for i = 0, readyState[8]-1 do
				Track_item:AppendText("  - <rgb=0xFFFF00>" .. readyState[9][i] .. "</rgb>" );
			end
		end
	end
	
    self.syncStartSlotShortcut = Turbine.UI.Lotro.Shortcut(
        Turbine.UI.Lotro.ShortcutType.Undefined, "");
    self.syncStartSlot:SetShortcut(self.syncStartSlotShortcut);
    self.syncStartSlot:SetVisible(self.bLeaderMode);

end

--

-- action for setting focus on the track list
function SongBook3Window:PlayerSyncInfo()
	if not self.sendSyncInfoSlot then return 0; end
	
	local trackcount = #SongDB.Songs[selectedSongIndex].Tracks;
	local Track_Name = SongDB.Songs[selectedSongIndex].Tracks[selectedTrack].Name; 

	local equippedInstrument_Index = self:UpdatePlayerTitle();
    local hasInstrumentInfo = equippedInstrument_Index ~= nil;
    if not hasInstrumentInfo then
        -- Announcing a song is informational and must work even when the
        -- player has no instrument equipped. Keep the detailed @SBL report
        -- disabled in that case, but still identify the local player.
        if self.playerInstance then
            self.Player_Name = self.playerInstance:GetName();
        end
        equippedInstrument_Index = 0;
        if self.PlayerTitle and self.Player_Name then
            self.PlayerTitle:SetText(self.Player_Name .. " - No Instrument Equipped");
        end
    end
	local Track_Instrument = self:FindInstrumentForTrack( SongDB.Songs[selectedSongIndex].Tracks[selectedTrack] );
	local Track_Instrument_Index = Track_Instrument[0];
	local CorrectInstrument = hasInstrumentInfo and
        self:CompareInstrument(equippedInstrument_Index, Track_Instrument_Index) or 0;
	
	-------------------------------------------------------
	
	local CorrectSongAndTrack = 1;
	if selectedSongIndex ~= syncedSongIndex or selectedTrack ~= syncedTrack then
		CorrectSongAndTrack = 0;
	end
	
	local Party = self.playerInstance:GetParty();
	local PartyMemberCount = 0;
	if Party ~= nil then PartyMemberCount = Party:GetMemberCount(); end
	

	if self.UseFellowshipChat then
		Chatchannel = "/f";
		self.MessageTitle:SetText("SongBook3 is using Fellowship channel");
	else
	if self.UseRaidChat then
		Chatchannel = "/ra";
		self.MessageTitle:SetText("SongBook3 is using Raid channel");
	else
		if UserChatNumber ~= 0 and UserChatNumber ~= nil then
			Chatchannel = "/" .. UserChatNumber;
			self.MessageTitle:SetText("SongBook3 is using User Chat channel " .. UserChatNumber .. " - " .. UserChatName);
		else
			if PartyMemberCount > 6 or GroupIsRaid == 1 then
				Chatchannel = "/ra";
				if PlayerCantUseUserChat_Message == 0 then
					self.MessageTitle:SetText("SongBook3 is using Raid channel");
				elseif PlayerCantUseUserChat_Message == 1 then
					songBook3Window.MessageTitle:SetText("Low level to use User chat. Now using Raid channel");
				end
			elseif PartyMemberCount > 1 then
				Chatchannel = "/f";
				if PlayerCantUseUserChat_Message == 0 then 
					self.MessageTitle:SetText("SongBook3 is using Fellowship channel");
				elseif PlayerCantUseUserChat_Message == 1 then
					songBook3Window.MessageTitle:SetText("Low level to use User chat. Now using Fellowship channel");
				end
			end
		end
	end
	end

    -- Prepare an informational announcement for the currently selected song.
    -- This is deliberately separate from @SBL: recipients can click the song
    -- in SongBook3, but the announcement does not mark the sender as synced,
    -- add a ready player, or affect Sync Check.
    local path = SongBook3SongPath(SongDB.Songs[selectedSongIndex]);
    local fullTag = " [SBPATH:" .. SongBook3EncodePath(path) .. "]";
    local hashTag = " [SBHASH:" .. SongBook3PathHash(path) .. "]";
    local announceBase = Chatchannel .. " <rgb=#211f1d>@SBANN|" .. self.Player_Name ..
        "|" .. SongDB.Songs[selectedSongIndex].Filename .. "|" .. Track_Name ..
        "|" .. trackcount .. "|</rgb>";
    local announceTag = fullTag;
    if #announceBase + #fullTag > 240 then announceTag = hashTag; end
    self.currentSongAnnouncementAlias = announceBase .. announceTag;
    self.sendSyncInfoSlotShortcut = Turbine.UI.Lotro.Shortcut(
        Turbine.UI.Lotro.ShortcutType.Alias, self.currentSongAnnouncementAlias);
    self.sendSyncInfoSlot:SetShortcut(self.sendSyncInfoSlotShortcut);
    self.sendSyncInfoSlot:SetVisible(true);

	if hasInstrumentInfo and CorrectSongAndTrack == 1 and PlayerSynced == 1 then
	
        local baseMessage = Chatchannel .. " <rgb=#211f1d>@SBL|" .. self.Player_Name ..
            "|" .. SongDB.Songs[selectedSongIndex].Filename .. "|" .. Track_Name ..
            "|" .. PlayerSynced .. "|" .. CorrectSongAndTrack .. "|" .. trackcount ..
            "|" .. selectedSongIndexListBox .. "|" .. selectedSongIndex .. "|" ..
            selectedTrack .. "|" .. Track_Instrument_Index .. "|" ..
            equippedInstrument_Index .. "|" .. CorrectInstrument .. "|</rgb>";
        local tag = fullTag;
        -- If an ABC path is very long, use a short path fingerprint so the
        -- detailed report remains within a conservative chat-command limit.
        if #baseMessage + #fullTag > 240 then tag = hashTag; end
        self.currentSyncInfoAlias = baseMessage .. tag;
	else
        self.currentSyncInfoAlias = nil;
	end

	return equippedInstrument_Index;
end
--

-- A click cannot issue both /play ... sync and a fellowship/raid message:
-- LOTRO's API requires separate real quickslot activations. Reuse the same
-- main Sync control for the second click when standard chat confirms syncing.
function SongBook3Window:ArmSyncInfoOnPlaySlot()
    if not self.currentSyncInfoAlias or
       selectedSongIndex ~= syncedSongIndex or selectedTrack ~= syncedTrack or
       PlayerSynced ~= 1 then return; end
    self.syncSlotShortcut = Turbine.UI.Lotro.Shortcut(
        Turbine.UI.Lotro.ShortcutType.Alias, self.currentSyncInfoAlias);
    self.syncSlot:SetShortcut(self.syncSlotShortcut);
    self.syncSlotSendsInfo = true;
    self.syncInfoSendPending = false;
    self.syncIcon:SetBackground(gDir .. "icn_send_hover.tga");
    self.tipLabel:SetText("Sync Prepared - Click Again To Send Sync Info");
end

function SongBook3Window:RestorePlaySyncShortcut()
    if not self.syncSlotSendsInfo then return; end
    self.syncSlotSendsInfo = false;
    self.syncInfoSendPending = false;
    if self.playSyncShortcut then
        self.syncSlotShortcut = self.playSyncShortcut;
        self.syncSlot:SetShortcut(self.playSyncShortcut);
    end
    self.syncIcon:SetBackground(gDir ..
        (syncSlot_Correct_Instrument == 0 and "icn_s_f.tga" or "icn_s.tga"));
    self.tipLabel:SetText("");
end

-- return track colour based on readyState retrieved from GetTrackReadyState(...)
function SongBook3Window:GetColourForTrack( readyState, bSelectedTrack )
	if bSelectedTrack then
		if not readyState then -- track not ready
			return self.colourDefaultHighlighted;
		else
			if readyState == 0 then -- track is ready by more than one player
				return self.colourReadyMultipleHighlighted;
			elseif readyState == 1 then -- track is synced but wrong or not ready yet
				return self.colourSyncedHighlighted;
			elseif readyState == 2 then -- track is ready by more than one player and is synced
				return self.colourReadyMultipleHighlighted_synced;
			elseif readyState == 3 then -- track is synced with wrong instrument
				return self.colourWrongInstrument_synced;
			elseif readyState == 4 then -- track is ready by more than one player and is synced with wrong instrument
				return self.colourWrongInstrumentMultiple;
			elseif readyState == 5 then -- track is ready with wrong instrument
				return self.colourWrongInstrument;
			elseif readyState == 6 then -- track is ready by more than one player wrong instrument
				return self.colourWrongInstrumentMultiple_synced;
			else -- track ready by one player
				return self.colourReadyHighlighted;
			end
		end
	else
		if not readyState then
			return self.colourDefault;
		else
			if readyState == 0 then
				return self.colourReadyMultiple;
			elseif readyState == 1 then
				return self.colourSyncedHighlighted_notSelected;
			elseif readyState == 2 then
				return self.colourReadyMultipleHighlighted_synced_notSelected;
			elseif readyState == 3 then
				return self.colourWrongInstrument_notSelected_synced;
			elseif readyState == 4 then
				return self.colourWrongInstrumentMultiple_notSelected;
			elseif readyState == 5 then
				return self.colourWrongInstrument_notSelected;
			elseif readyState == 6 then
				return self.colourWrongInstrumentMultiple_synced_notSelected;
			else
				return self.colourReady;
			end
		end
	end
end

--

-- background colour indicates the track one has ready
function SongBook3Window:GetBackColourForTrack( readyState, playerName , readyState8)
	if readyState8 >= 1 then
		if playerName == "LocalPlayer" then
			return self.backColour_synced_multiple;
		elseif readyState == 10 and playerName == self.sPlayerName then
			return self.backColour_synced_multiple;
		elseif readyState8 > 1 then
			return self.backColour_synced_multiple;
		else
			return self.backColour_synced;
		end
	end
	
	if not readyState then
		return self.backColourDefault;
	elseif playerName == "LocalPlayer" then
		return self.backColourHighlight;
	elseif readyState == 0 then
		--return self.backColourHighlight_Multiple;
		return self.backColourDefault;
	elseif readyState == 1 then
		--return self.backColourHighlight_wrong;
		return self.backColourDefault;
	elseif readyState == 2 then
		--return self.backColourHighlight_Multiple_synced;
		return self.backColourDefault;
	elseif readyState == 3 then
		--return self.backColourWrongInstrument;
		return self.backColourDefault;
	elseif readyState == 4 then
		--return self.backColourWrongInstrument;
		return self.backColourDefault;
	elseif readyState == 5 then
		--return self.backColourWrongInstrument_ready;
		return self.backColourDefault;
	elseif readyState == 6 then
		--return self.backColourWrongInstrument_ready;
		return self.backColourDefault;
	elseif readyState == 10 and playerName == self.sPlayerName then
		--return self.backColourHighlight_self;
		return self.backColourHighlight;
	else
		return self.backColourDefault;
	end
	--if self.bInstrumentOk then return self.backColourHighlight; end
	--return self.backColourWrongInstrument
end	

--
-- Choose the normal group channel, not user-defined channels where outsiders
-- can send a signal. Raid overrides fellowship when explicitly selected.
-- Setlist transfer messages are processed by ChatHandler below.

-- LOTRO may shorten displayed ABC titles in the standard /play sync line.
-- Do not erase a richer instrument report just because one form is truncated
-- or includes a trailing period.  Only treat it as a different track when
-- both known prefixes disagree (case/whitespace-insensitive).
local function SongBook3SameSyncedTrack(a, b)
    if type(a) ~= "string" or type(b) ~= "string" then return false; end
    local function norm(s)
        return string.lower(string.gsub(string.gsub(s, "%s+", ""), "[%.]+$", ""));
    end
    a, b = norm(a), norm(b);
    if a == "" or b == "" then return false; end
    return a == b or string.sub(a, 1, math.min(#a, #b, 55)) ==
        string.sub(b, 1, math.min(#a, #b, 55));
end

-- Handler for chat messages to indicate players readying tracks
function ChatHandler( sender, args )
	local sMessage = args.Message;
	if sMessage == nil or songBook3Window == nil then return; end
	
	if args.ChatType == Turbine.ChatType.Error then
		if string.find( sMessage, "You are not in a Raid." ) ~= nil then
			songBook3Window.MessageTitle:SetText("You are not in a Raid.");
			GroupIsRaid = 0;
		end
		
		return;
	end
	
    -- Receive only explicit setlist-share chunks from fellowship/raid chat.
    if (args.ChatType == Turbine.ChatType.Fellowship or
        args.ChatType == Turbine.ChatType.Raid) and
        string.find(sMessage, "[SB2LIST|", 1, true) then
        songBook3Window:ReceiveSetlistChunk(args.Sender, sMessage);
        return;
    end

	if( args.ChatType == Turbine.ChatType.UserChat1 or args.ChatType == Turbine.ChatType.UserChat2  or
		args.ChatType == Turbine.ChatType.UserChat3 or args.ChatType == Turbine.ChatType.UserChat4  or
		args.ChatType == Turbine.ChatType.UserChat5 or args.ChatType == Turbine.ChatType.UserChat6  or
		args.ChatType == Turbine.ChatType.UserChat7 or args.ChatType == Turbine.ChatType.UserChat8  or
		args.ChatType == Turbine.ChatType.Raid		or args.ChatType == Turbine.ChatType.Fellowship	
	) then
		
		if string.find( sMessage, "raid chat is now available." ) ~= nil then
			GroupIsRaid = 1;
			Chatchannel = "/ra";
			songBook3Window:PlayerSyncInfo();
			return;
		end
		
		if string.find( sMessage, "You left room '" .. UserChatName .. "'" ) ~= nil then
			UserChatNumber = 0;
			CharSettings.UserChatNumber = 0;
			songBook3Window:PlayerSyncInfo();
			return;
		end
		
		if  string.match( sMessage, "uc(%d+): '" .. UserChatName .. "'" ) ~= nil then 
			UserChatNumber =  string.match( sMessage, "uc(%d+): '" .. UserChatName .. "'" );
			CharSettings.UserChatNumber = UserChatNumber;
			songBook3Window:PlayerSyncInfo();
			return;
		end
		
        -- Informational song announcements are intentionally separate from
        -- @SBL sync reports. They provide a clickable song reference without
        -- changing the sender's readiness, instrument report, or sync state.
        if string.find(sMessage, "@SBANN|", 1, true) then
            local sPlayerName, Filename, TrackName, NumberOfParts = string.match(
                sMessage, "@SBANN|([^|]*)|([^|]*)|([^|]*)|([^|]*)|");
            if not sPlayerName or sPlayerName == "" or
               not Filename or not TrackName or not NumberOfParts then return; end
            if sPlayerName == songBook3Window.sPlayerName then return; end

            local playerIsInParty = false;
            for playerName in pairs(songBook3Window.aPlayers or {}) do
                if playerName == sPlayerName then
                    playerIsInParty = true;
                    break;
                end
            end
            if not playerIsInParty then return; end

            local taggedPath = string.match(sMessage, "%[SBPATH:([^%]]+)%]");
            if taggedPath then taggedPath = SongBook3DecodePath(taggedPath); end
            local taggedHash = string.match(sMessage, "%[SBHASH:(%x+)%]");
            local SongIndex = songBook3Window:Find_OtherPlayer_SyncedSong_Index(
                Filename, TrackName, NumberOfParts, taggedPath, taggedHash);
            OtherPlayer_Synced = 0; -- announced, not synchronized
            songBook3Window:Update_syncMessage(SongIndex, sPlayerName, TrackName);
            return;
        end

		if string.find( sMessage, "@SBL" ) then
			
			local sPlayerName, Filename, TrackName, SyncStatus, CorrectSongAndTrack, NumberOfParts, SongIndexListBox, SongIndex_OtherPlayer, TrackIndex, neededInstrument, equippedInstrument_Index, CorrectInstrument = string.match(
                sMessage, "@SBL|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|");
            if not sPlayerName or sPlayerName == "" then return; end
            local taggedPath = string.match(sMessage, "%[SBPATH:([^%]]+)%]");
            if taggedPath then taggedPath = SongBook3DecodePath(taggedPath); end
            local taggedHash = string.match(sMessage, "%[SBHASH:(%x+)%]");
			
			--
			local PlayerIsInParty_Flag = 0;
			
			if( songBook3Window.aPlayers ~= nil ) then
				for k,v in pairs( songBook3Window.aPlayers ) do
					if k == sPlayerName then
						PlayerIsInParty_Flag = 1;
						break;
					end
				end
			end
			
			if PlayerIsInParty_Flag == 0 then return; end
			
			--
			
			local SongIndex = songBook3Window:Find_OtherPlayer_SyncedSong_Index (Filename, TrackName, NumberOfParts, taggedPath, taggedHash) ;
			
			if sPlayerName ~= nil then
				
				OtherPlayer_Synced = 0;
                if sPlayerName ~= songBook3Window.sPlayerName then
                    songBook3Window:Update_syncMessage(SongIndex, sPlayerName, TrackName);
                elseif songBook3Window.syncSlotSendsInfo and
                       songBook3Window.syncInfoSendPending then
                    -- The game echoed our detailed report, so restore the
                    -- original Play Sync command for subsequent performances.
                    songBook3Window:RestorePlaySyncShortcut();
                end
				
				if not songBook3Window.aPlayers[ sPlayerName ] then --- Player not yet registered 
					songBook3Window.nPlayers = songBook3Window.nPlayers + 1;
					songBook3Window:AddPlayerToList( sPlayerName ); -- add to player listbox
					songBook3Window:UpdateMaxPartCount( );
				end
				
				songBook3Window.aPlayers[ sPlayerName ] = "|" .. sPlayerName .. "|" .. SyncStatus .. "|" .. CorrectSongAndTrack .. "|" .. SongIndex[0] .. "|" .. TrackIndex .. "|" .. equippedInstrument_Index .. "|" .. CorrectInstrument .. "|"; -- and to player array with the track info
				
				songBook3Window.Players_Data[ sPlayerName ] = SongIndex;
                songBook3Window.bandSyncReports = songBook3Window.bandSyncReports or {};
                songBook3Window.bandSyncReports[sPlayerName] = {
                    indices = SongIndex, trackIndex = tonumber(TrackIndex),
                    instrument = tonumber(equippedInstrument_Index),
                    correct = tonumber(CorrectInstrument),
                    synced = tonumber(SyncStatus),
                    valid = tonumber(CorrectSongAndTrack),
                    trackName = TrackName
                };
				
				songBook3Window:SetListboxColours( songBook3Window.songlistBox );
				songBook3Window:SetTrackColours( selectedTrack );
				songBook3Window:SetPlayerColours( );
				songBook3Window:UpdateSetupColours( );
			end
		end
		
		return;
	end
	
-----------------------------------------------------------------------------------

	if( args.ChatType ~= Turbine.ChatType.Standard ) then
		return; -- Player ready messages appear in the standard chat
	end
	
--
	if string.find( sMessage, "You have joined a Fellowship." ) ~= nil then
		songBook3Window.playerInstance = Turbine.Gameplay.LocalPlayer:GetInstance( );
		local Party = songBook3Window.playerInstance:GetParty();
		local PartyMemberCount = 0;
		if Party ~= nil then PartyMemberCount = Party:GetMemberCount(); end
		
		if PartyMemberCount > 1 then
			for i = 1, PartyMemberCount do
				local PartyMember = Party:GetMember(i);
				local MemberName  = PartyMember:GetName();
				if songBook3Window.aPlayers[ MemberName ] == nil then songBook3Window:AddPlayer( MemberName ); end
			end
		end
		
		--songBook3Window.MessageTitle:SetText("You have joined a Fellowship.");
		Chatchannel = "/f";
		GroupIsRaid = 0;
		songBook3Window:PlayerSyncInfo();
		return;
	end
	
	if string.find( sMessage, "You have joined a Raid." ) ~= nil then
		songBook3Window.playerInstance = Turbine.Gameplay.LocalPlayer:GetInstance( );
		local Party = songBook3Window.playerInstance:GetParty();
		local PartyMemberCount = 0;
		if Party ~= nil then PartyMemberCount = Party:GetMemberCount(); end
		
		if PartyMemberCount > 1 then
			for i = 1, PartyMemberCount do
				local PartyMember = Party:GetMember(i);
				local MemberName  = PartyMember:GetName();
				if songBook3Window.aPlayers[ MemberName ] == nil then songBook3Window:AddPlayer( MemberName ); end
			end
		end
		
		--songBook3Window.MessageTitle:SetText("You have joined a Raid.");
		GroupIsRaid = 1;
		Chatchannel = "/ra";
		songBook3Window:PlayerSyncInfo();
		return;
	end
	
	if string.find( sMessage, "You joined room '" .. UserChatName .. "'" ) ~= nil then
		UserChatNumber = string.match( sMessage, 'UserChat(%d+)' );
		CharSettings.UserChatNumber = UserChatNumber;
		songBook3Window:PlayerSyncInfo();
		return;
	end
	
	if string.find( sMessage, "You are already in room '" .. UserChatName .. "'" ) ~= nil then
		songBook3Window.MessageTitle:SetText("You are already in room '" .. UserChatName .. "'. Use recover button to find it.");
		return;
	end
	
	if string.find( sMessage, "You are not in room '" .. UserChatName .. "'" ) ~= nil then
		UserChatNumber = 0;
		CharSettings.UserChatNumber = 0;
		songBook3Window:PlayerSyncInfo();
		return;
	end
	
	if string.find( sMessage, "You are already in 8 rooms, which is the maximum allowed" ) ~= nil then
		songBook3Window.MessageTitle:SetText("You are already in 8 rooms, which is the maximum allowed");
		return;
	end
	
	if string.find( sMessage, "You haven't played this character for long enough to use this chat channel." ) ~= nil then
		UserChatNumber = 0;
		CharSettings.UserChatNumber = 0;
		PlayerCantUseUserChat_Message = 1;
		songBook3Window:PlayerSyncInfo();
		return;
	end
	
	if string.find( sMessage, "Your Raid has been disbanded." ) ~= nil then
		songBook3Window.MessageTitle:SetText("Your Raid has been disbanded.");
		Chatchannel = "/f";
		GroupIsRaid = 0;
		return;
	end
	
	if string.find( sMessage, "dismiss" ) ~= nil then
		if string.find( sMessage, "You have been dismissed from your" ) ~= nil then
			songBook3Window.MessageTitle:SetText("You have been dismissed.");
			Chatchannel = "/f";
			GroupIsRaid = 0;
			return;
		end
		
		if string.find( sMessage, "You dismiss" ) ~= nil then
			local temp, sPlayerName;
			temp, temp, sPlayerName = string.find( sMessage, "You dismiss (%a+)" );
			if sPlayerName then songBook3Window:RemovePlayer( sPlayerName ); end
			
			songBook3Window:PlayerSyncInfo();
		
			local PartyMemberCount = 0;
			if( songBook3Window.aPlayers ~= nil ) then
				for k,v in pairs( songBook3Window.aPlayers ) do
					PartyMemberCount = PartyMemberCount + 1;
				end
			end
			
			if PartyMemberCount == 1 then
				songBook3Window.MessageTitle:SetText("You dismiss party.");
				Chatchannel = "/f";
				GroupIsRaid = 0;
				return;
			end
			
			return;
		end
		
		local temp, sPlayerName;
		temp, temp, sPlayerName = string.find( sMessage, "(%a+) has been dismissed from your" );
		if sPlayerName then songBook3Window:RemovePlayer( sPlayerName ); end
		songBook3Window:PlayerSyncInfo();
		return;
	end
	
--

    local lowerMessage = string.lower(sMessage);
    local syncStartText = string.lower(Strings["chat_playBegin"] or "");
    local selfStartText = Strings["chat_playBeginSelf"] or "";
    local lowerSelfStartText = string.lower(selfStartText);
    local syncStartPosition = syncStartText ~= "" and string.find(lowerMessage, syncStartText, 1, true) or nil;
    local selfStartPosition = lowerSelfStartText ~= "" and string.find(lowerMessage, lowerSelfStartText, 1, true) or nil;
    if syncStartPosition or selfStartPosition then
        local TrackName = nil;
        if selfStartPosition then
            local tail = string.sub(sMessage, selfStartPosition + #selfStartText);
            TrackName = string.match(tail, '"(.-)"');
        end
        if TrackName then Synced_Song_TrackName = TrackName; end
        -- Both the solo start message and the sync-start countdown are local
        -- playback-start signals. Record the current library/setlist song even
        -- when LOTRO omits a part title from the message.
        songBook3Window:SongStarted(true, TrackName);
        return;
    end

	if string.find( sMessage, Strings["chat_playerJoin"] ) ~= nil then
		songBook3Window:PlayerJoined( sMessage );
		return;
	end
	if string.find( sMessage, Strings["chat_playerLeave"] ) ~= nil then
		songBook3Window:PlayerLeft( sMessage );
		return;
	end
	
	local temp, sPlayerName, sTrackName;
	temp, temp, sPlayerName, sTrackName = string.find( sMessage, Strings["chat_playReadyMsg"] );
	if not sPlayerName or not sTrackName then
		sPlayerName = songBook3Window.sPlayerName;
		temp, temp, sTrackName = string.find( sMessage, Strings["chat_playSelfReadyMsg"] );
	end
	
	-- if sTrackName then
		-- Synced_Song_TrackName = sTrackName;
	-- end
	
	if sPlayerName and sTrackName and songBook3Window.aPlayers then
        local report = songBook3Window.bandSyncReports and songBook3Window.bandSyncReports[sPlayerName];
        if report and type(report.trackName) == "string" and
           not SongBook3SameSyncedTrack(report.trackName, sTrackName) then
            songBook3Window.bandSyncReports[sPlayerName] = nil;
        end
		if sPlayerName == songBook3Window.sPlayerName and songBook3Window.sPlayerName then
			
			Synced_Song_TrackName = sTrackName;
			
			--songBook3Window.aPlayers_sync_msg[ songBook3Window.sPlayerName ] = sTrackName;
			--songBook3Window.aPlayers[ songBook3Window.sPlayerName ] = "|sync_msg|" .. sTrackName .. "|";
			songBook3Window.aPlayers[ songBook3Window.sPlayerName ] = sTrackName;
			
			--local SongIndex = songBook3Window:Find_OtherPlayer_SyncedSong_Index_WithOnlySync(sTrackName);
			--OtherPlayer_Synced = 1;
			--songBook3Window:Update_syncMessage(SongIndex, sPlayerName, sTrackName);
			
			songBook3Window:SetListboxColours( songBook3Window.songlistBox );
			songBook3Window:SetTrackColours( selectedTrack );
			songBook3Window:SetPlayerColours( );
			songBook3Window:UpdateSetupColours( );
			PlayerSynced = 1;
			songBook3Window:PlayerSyncInfo();
            songBook3Window:ArmSyncInfoOnPlaySlot();
		else
			if songBook3Window.aPlayers[ sPlayerName ] ~= nil then
				
				--songBook3Window.aPlayers_sync_msg[ sPlayerName ] = sTrackName;
				--songBook3Window.aPlayers[ sPlayerName ] = "|sync_msg|" .. sTrackName .. "|";
				songBook3Window.aPlayers[ sPlayerName ] = sTrackName;
				
				local SongIndex = songBook3Window:Find_OtherPlayer_SyncedSong_Index_WithOnlySync(sTrackName);
				OtherPlayer_Synced = 1;
				songBook3Window:Update_syncMessage(SongIndex, sPlayerName, sTrackName);
				
				songBook3Window:SetListboxColours( songBook3Window.songlistBox );
				songBook3Window:SetTrackColours( selectedTrack );
				songBook3Window:SetPlayerColours( );
				songBook3Window:UpdateSetupColours( );
			end
		end
	end
end

--

-- Return a track state indicator: 
-- nil = track not ready, name of a player = ready by this player, 0 = ready by more than one player
function SongBook3Window:GetTrackReadyState( sSongIndex, sTrackIndex,  indicator )
	local ReadyState = {};
	ReadyState[0] = nil;
	ReadyState[1] = nil;
	ReadyState[2] = nil;
	ReadyState[3] = nil;
	ReadyState[4] = nil;
	ReadyState[5] = nil;
	ReadyState[6] = nil;
	ReadyState[7] = nil;
	ReadyState[8] = nil;
	ReadyState[9] = nil;
	local readyIndicator = 1;
	if indicator then readyIndicator = indicator; end
	
	local SyncedPlayersCounter = 0;
	local SyncedPlayersNames = {};
	local ReadyPlayersCounter = 0;
	local ReadyPlayersNames = {};
	local ReadyPlayersEquippedInstrument_Index = {};
	local WrongPlayersCounter = 0;
	local WrongPlayersNames = {};
	local WrongPlayersEquippedInstrument_Index = {};
	
	local SyncedPlayer = 0;
	
	if( self.aPlayers ~= nil ) then
		for k,v in pairs( self.aPlayers ) do
			
			v = string.gsub( v, "%s+", "" );
			
			local sPlayerName, SyncStatus, CorrectSongAndTrack, SongIndex, TrackIndex, equippedInstrument_Index, CorrectInstrument =  string.match( v, '|(.+)|(.+)|(.+)|(.+)|(.+)|(.+)|(.+)|' );
			
			local Track_Name = SongDB.Songs[sSongIndex].Tracks[sTrackIndex].Name;
			
			if string.gsub( string.sub( Track_Name, 1, 63 ) , "%s+", "" ) == v or
			   string.gsub( string.sub( Track_Name, 1, -2 ) , "%s+", "" ) == v
			then
				SyncedPlayersNames[SyncedPlayersCounter] = k;
				SyncedPlayersCounter = SyncedPlayersCounter + 1;
			end
						
			local SongIndex_Synced = 0;
			
			if self.Players_Data[ k ] ~= nil then
			if self.Players_Data[ k ] ~= 0 then
			if self.Players_Data[ k ][0] ~= 0 then
				for i = 1, self.Players_Data[ k ][0] do
					if sSongIndex == self.Players_Data[ k ][i] then
						SongIndex_Synced = 1;
					end
				end
			end
			end
			end
			
			if SongIndex_Synced == 1 and sTrackIndex == tonumber(TrackIndex) and
			   tonumber(CorrectSongAndTrack) == 1 and tonumber(SyncStatus) == 1 then
				
				if sPlayerName == songBook3Window.sPlayerName then
					ReadyState[1] = "LocalPlayer";
				end

				if tonumber(CorrectInstrument) == 1 then
					ReadyPlayersNames[ReadyPlayersCounter] = k;
					ReadyPlayersEquippedInstrument_Index[ReadyPlayersCounter] = equippedInstrument_Index;
					ReadyPlayersCounter = ReadyPlayersCounter + 1;
				else
					WrongPlayersNames[WrongPlayersCounter] = k;
					WrongPlayersEquippedInstrument_Index[WrongPlayersCounter] = equippedInstrument_Index;
					WrongPlayersCounter = WrongPlayersCounter + 1;
				end
			else
				if sSongIndex == syncedSongIndex and  sTrackIndex == syncedTrack and k == songBook3Window.sPlayerName then
					
					--------------------------------------------------------------------
					local Track_Name = SongDB.Songs[sSongIndex].Tracks[sTrackIndex].Name; 

					local equippedInstrument_Index = self:UpdatePlayerTitle();
					local Track_Instrument = self:FindInstrumentForTrack( SongDB.Songs[sSongIndex].Tracks[sTrackIndex] );
					local Track_Instrument_Index = Track_Instrument[0];
					local CorrectInstrument = self:CompareInstrument (equippedInstrument_Index, Track_Instrument_Index);
					
					-------------------------------------------------------
					
					if CorrectInstrument == 1 then
						SyncedPlayer = 1;
					else
						SyncedPlayer = 2;
					end
				end
			end
		end
	end
	
    -- A normal LOTRO sync notice can replace an @SBL instrument report in
    -- aPlayers. Reinstate that member's last verified report only when their
    -- current plain-text sync status and song/part still match. Don't double
    -- count players who still have the structured @SBL status.
    for playerName, report in pairs(self.bandSyncReports or {}) do
        local current = self.aPlayers and self.aPlayers[playerName];
        if type(current) == "string" and
           not string.match(current, "^|[^|]+|") and
           report and report.synced == 1 and report.valid == 1 and
           report.trackIndex == sTrackIndex and
           type(report.indices) == "table" and
           SongBook3SameSyncedTrack(report.trackName,
               current) then
            local sameSong = false;
            for i = 1, tonumber(report.indices[0]) or 0 do
                if report.indices[i] == sSongIndex then
                    sameSong = true; break;
                end
            end
            if sameSong then
                local needed = self:FindInstrumentForTrack(
                    SongDB.Songs[sSongIndex].Tracks[sTrackIndex]);
                local matched = self:CompareInstrument(report.instrument or 0,
                    needed[0], true);
                if report.correct == 0 or matched == 0 then
                    WrongPlayersNames[WrongPlayersCounter] = playerName;
                    WrongPlayersEquippedInstrument_Index[WrongPlayersCounter] =
                        tostring(report.instrument or 0);
                    WrongPlayersCounter = WrongPlayersCounter + 1;
                else
                    ReadyPlayersNames[ReadyPlayersCounter] = playerName;
                    ReadyPlayersEquippedInstrument_Index[ReadyPlayersCounter] =
                        tostring(report.instrument or 0);
                    ReadyPlayersCounter = ReadyPlayersCounter + 1;
                end
            end
        end
    end

	if ReadyPlayersCounter == 1 and SyncedPlayer == 0 and WrongPlayersCounter == 0 then
		ReadyState[0] = 10;
		self.aCurrentSongReady[ ReadyPlayersNames[0] ] = readyIndicator;
	elseif ReadyPlayersCounter > 1 and SyncedPlayer == 0 and WrongPlayersCounter == 0 then
		ReadyState[0] = 0;
		for i = 0, ReadyPlayersCounter-1, 1 do
			self.aCurrentSongReady[ ReadyPlayersNames[i] ] = 2;
		end
	elseif WrongPlayersCounter == 1 and ReadyPlayersCounter == 0 and SyncedPlayer == 0 then
		ReadyState[0] = 5;
	elseif WrongPlayersCounter >= 1 and ReadyPlayersCounter >= 0 and SyncedPlayer == 0 then
		ReadyState[0] = 4;
	elseif SyncedPlayer == 1 and ReadyPlayersCounter == 0 and WrongPlayersCounter == 0 then
		ReadyState[0] = 1;
	elseif SyncedPlayer == 1 and ReadyPlayersCounter >= 1 and WrongPlayersCounter == 0 then
		ReadyState[0] = 2;
	elseif SyncedPlayer == 1 and ReadyPlayersCounter >= 0 and WrongPlayersCounter >= 1 then
		ReadyState[0] = 6;
	elseif SyncedPlayer == 2 and ReadyPlayersCounter >= 1 and WrongPlayersCounter == 0 then
		ReadyState[0] = 6;
	elseif SyncedPlayer == 2 and ReadyPlayersCounter >= 0 and WrongPlayersCounter >= 1 then
		ReadyState[0] = 6;
	elseif SyncedPlayer == 2 and ReadyPlayersCounter == 0 and WrongPlayersCounter == 0 then
		ReadyState[0] = 3;
	end
	
	
	ReadyState[2] = ReadyPlayersNames;
	ReadyState[3] = ReadyPlayersEquippedInstrument_Index;
	ReadyState[4] = ReadyPlayersCounter;
	ReadyState[5] = WrongPlayersNames;
	ReadyState[6] = WrongPlayersEquippedInstrument_Index;
	ReadyState[7] = WrongPlayersCounter;
	
	ReadyState[8] = SyncedPlayersCounter;
	ReadyState[9] = SyncedPlayersNames;
	
	return ReadyState;
end
--

function SongBook3Window:GetSongReadyState( sSongIndex )
	local ReadyState = {};
	ReadyState[0] = nil;
	ReadyState[1] = nil;

	local ReadyPlayersCounter = 0;
	local ReadyPlayersNames = {};
	
	local SyncedPlayer = 0;
			
	if( self.aPlayers ~= nil ) then
		for k,v in pairs( self.aPlayers ) do
			
			v = string.gsub( v, "%s+", "" );
			
			local sPlayerName, SyncStatus, CorrectSongAndTrack, SongIndex, TrackIndex, equippedInstrument_Index, CorrectInstrument =  string.match( v, '|(.+)|(.+)|(.+)|(.+)|(.+)|(.+)|(.+)|' );
			
					
			local SongIndex_Synced = 0;
			
			if self.Players_Data[ k ] ~= nil then
			if self.Players_Data[ k ] ~= 0 then
			if self.Players_Data[ k ][0] ~= 0 then
				for i = 1, self.Players_Data[ k ][0] do
					if sSongIndex == self.Players_Data[ k ][i] then
						SongIndex_Synced = 1;
					end
				end
			end
			end
			end
			
			if SongIndex_Synced == 1 and tonumber(SyncStatus) == 1 then
			   
				if sPlayerName == songBook3Window.sPlayerName then
					ReadyState[1] = "LocalPlayer";
				end
				
				ReadyPlayersNames[ReadyPlayersCounter] = k;
				ReadyPlayersCounter = ReadyPlayersCounter + 1;
			end
		end
	end
	
	if ReadyPlayersCounter == 1 then
		ReadyState[0] = 10;
		--ReadyState[1] = ReadyPlayersNames[0];
	elseif ReadyPlayersCounter > 1 then
		ReadyState[0] = 0;
	end
	
	return ReadyState;
end

--

function SongBook3Window:Activated(sender, args)

	self:UpdatePlayerTitle();
	
	local width, height = self:GetSize();
	local left , top    = self:GetPosition();
	local displayWidth, displayHeight = Turbine.UI.Display.GetSize();
	
	local changeFlag = 0;
	-- Fix to prevent window to travel outside of the screen
	if width + 0 > displayWidth then
		width = displayWidth - 0;
		changeFlag = 1;
	end
	if height + 0 > displayHeight then
		height = displayHeight - 0;
		changeFlag = 1;
	end
	if left + width > displayWidth then
		left = displayWidth - width;
		changeFlag = 1;
	end
	if top + height > displayHeight then
		top = displayHeight - height;
		changeFlag = 1;
	end
	if left < 0 then
		left = 0;
		changeFlag = 1;
	end
	if top < 0 then
		top = 0;
		changeFlag = 1;
	end	
	
	Settings.WindowPosition.Left = left;
	Settings.WindowPosition.Top = top;
	Settings.WindowPosition.Width = width;
	Settings.WindowPosition.Height = height;
		
	if changeFlag == 1 then
		self:SetPosition( left, top );
		self:SetSize( width, height );
		self.resizeCtrl:SetPosition(self:GetWidth() - self.resizeCtrl:GetWidth(),self:GetHeight() - self.resizeCtrl:GetHeight()); 
		self:ResizeAll( );
	end
end

--

function SongBook3Window:UserChatNameChange( Text )
	
	Settings.UserChatName = string.upper (Text);
	UserChatName = string.upper (Text);
	
	self.joinUserChatSlotShortcut = Turbine.UI.Lotro.Shortcut( Turbine.UI.Lotro.ShortcutType.Alias, "/joinchannel " .. UserChatName );
	self.joinUserChatSlot:SetShortcut( self.joinUserChatSlotShortcut );
	self.joinUserChatSlot:SetVisible( true );
end

--

function SongBook3Window:FindInstrumentForTrack( track )
	return self:FindInstrumentInTrack( track.Name, track.PartName );
end

function SongBook3Window:FindInstrumentInTrack( Track_Name, Part_Name )
	local Track_Instrument = {};
	local Track_Instrument_Index = 0;
	local Track_Instrument_Name = "";
	Track_Name = Track_Name or "";
	local Track_Name_lowercase = string.lower(Track_Name);
	local found_Instruments = {};
	local found_Instruments_startIndex = {};
	local found_Instruments_count = 0;
	
	for k,v in pairs( self.Instruments_Names_inTrack ) do
		for k2,v2 in pairs( self.Instruments_Names_inTrack[k] ) do
			local startIndex = string.find( Track_Name_lowercase, string.lower(self.Instruments_Names_inTrack[k][k2]) );
			if startIndex then
				found_Instruments_count = found_Instruments_count + 1;
				found_Instruments[found_Instruments_count] = k;
				found_Instruments_startIndex[found_Instruments_count] = startIndex;
				break;
			end
		end
	end
	
	if found_Instruments_count > 1 then
		local startIndex = -1;
		for i = 1, found_Instruments_count do
			if found_Instruments_startIndex[i] > startIndex then
				startIndex = found_Instruments_startIndex[i];
				
				Track_Instrument_Index = found_Instruments[i];
				Track_Instrument_Name = self.Instruments_List[Track_Instrument_Index][1];
			end
		end
	elseif found_Instruments_count == 1 then
		Track_Instrument_Index = found_Instruments[1];
		Track_Instrument_Name = self.Instruments_List[Track_Instrument_Index][1];
	end
	
	if Track_Instrument_Index == 0 then
		if string.find( Track_Name_lowercase, "harp" ) then
			Track_Instrument_Index = 1;
			Track_Instrument_Name = "Basic Harp";
		elseif string.find( Track_Name_lowercase, "lute" ) then
			Track_Instrument_Index = 103;
			Track_Instrument_Name = "Basic Lute";
		elseif string.find( Track_Name_lowercase, "fiddle" ) or
			   string.find( Track_Name_lowercase, "fiddl" )
			then
			Track_Instrument_Index = 108;
			Track_Instrument_Name = "Basic Fiddle";
		elseif string.find( Track_Name_lowercase, "bassoon" ) or
			   string.find( Track_Name_lowercase, "basoon" ) or
			   string.find( Track_Name_lowercase, "basson" )
			then
			Track_Instrument_Index = 13;
			Track_Instrument_Name = "Basic Bassoon";
		end
	end

	-- T: takes precedence if its instrument is recognizable. ABC files from
	-- some transcribers instead store the instrument in %%part-name.
	if Track_Instrument_Index == 0 and type(Part_Name) == "string" and Part_Name ~= "" then
		return self:FindInstrumentInTrack( Part_Name );
	end
		
	Track_Instrument[0] = Track_Instrument_Index;
	Track_Instrument[1] = Track_Instrument_Name;
	
	return Track_Instrument;
end

--

function SongBook3Window:UpdatePlayerTitle ( )
	self.playerInstance = Turbine.Gameplay.LocalPlayer:GetInstance( );
	self.playerEquipment = self.playerInstance:GetEquipment( );
	self.playerInstrument = self.playerEquipment:GetItem( Turbine.Gameplay.Equipment.Instrument );
			
	if not self.playerInstrument then return; end
	self.playerInstrumentName = self.playerInstrument:GetName( );
	if not self.playerInstrumentName then return; end

	self.Player_Name = self.playerInstance:GetName();
	if not self.Player_Name then return; end

	-------------------------------------------------------
	local equippedInstrument_Index = 0;
	for k,v in pairs( self.Instruments_List ) do
		for k2,v2 in pairs(v) do
			if v2 == self.playerInstrumentName then
				equippedInstrument_Index = k;
				break;
			end
		end
	end
	
	local playerInstrumentName = string.lower(self.playerInstrumentName);
	if equippedInstrument_Index == 0 then
		if string.find( playerInstrumentName , "harp" ) then
			equippedInstrument_Index = 1;
		elseif string.find( playerInstrumentName , "flute" ) then
			equippedInstrument_Index = 17;
		elseif string.find( playerInstrumentName , "lute" ) then
			equippedInstrument_Index = 3;
		elseif string.find( playerInstrumentName , "theorbo" ) then
			equippedInstrument_Index = 5;
		elseif string.find( playerInstrumentName , "fiddle" ) then
			equippedInstrument_Index = 8;
		elseif string.find( playerInstrumentName , "bagpipe" ) then
			equippedInstrument_Index = 12;
		elseif string.find( playerInstrumentName , "bassoon" ) then
			equippedInstrument_Index = 13;
		elseif string.find( playerInstrumentName , "clarinet" ) then
			equippedInstrument_Index = 16;
		elseif string.find( playerInstrumentName , "horn" ) then
			equippedInstrument_Index = 18;
		elseif string.find( playerInstrumentName , "pibgorn" ) then
			equippedInstrument_Index = 19;
		elseif string.find( playerInstrumentName , "cowbell" ) then
			equippedInstrument_Index = 21;
		elseif string.find( playerInstrumentName , "drum" ) then
			equippedInstrument_Index = 22;
		end
	end
	
	if equippedInstrument_Index ~= 0 then
		self.PlayerTitle:SetText(self.Player_Name .. " - " .. self.playerInstrumentName);
	else
		self.PlayerTitle:SetText(self.Player_Name .. " - No Instrument Equipped");
	end
	-------------------------------------------------------
	
	return equippedInstrument_Index;
end

--

function SongBook3Window:CompareInstrument (equippedInstrument_Index, Track_Instrument_Index, skipUpdateIcon)
	
	local CorrectInstrument = 0;
	
	if equippedInstrument_Index ~= 0 then
		if Track_Instrument_Index ~= 0 then
			if Track_Instrument_Index == equippedInstrument_Index then
				CorrectInstrument = 1;
			elseif Track_Instrument_Index == 103 then
				if equippedInstrument_Index == 3 or equippedInstrument_Index == 4 then
					CorrectInstrument = 1;
				end
			elseif Track_Instrument_Index == 108 then
				if equippedInstrument_Index == 8 or equippedInstrument_Index == 9 then
					CorrectInstrument = 1;
				end
			end
		else
			CorrectInstrument = 1;
		end
	else
		CorrectInstrument = 0;
	end

	if skipUpdateIcon == true then
		return CorrectInstrument;
	end
	
    syncSlot_Correct_Instrument = CorrectInstrument;
    if self.syncSlotSendsInfo then
        self.syncIcon:SetBackground(gDir .. "icn_send.tga");
    elseif CorrectInstrument == 0 then
        self.syncIcon:SetBackground(gDir .. "icn_s_f.tga");
    else
        self.syncIcon:SetBackground(gDir .. "icn_s.tga");
    end
	
	-------------------------------------------------------
	
	return CorrectInstrument;
end
--

function SongBook3Window:Find_OtherPlayer_SyncedSong_Index(Filename, TrackName, NumberOfParts, taggedPath, taggedHash)
    local matched = { [0] = 0 };
    if not Filename or not TrackName then return matched; end
    local filename = string.lower(Filename);
    local trackName = string.lower(TrackName);
    local partCount = tonumber(NumberOfParts);
    local function TrackMatches(i)
        local song = SongDB.Songs[i];
        if not song or #song.Tracks ~= partCount then return false; end
        for _, track in ipairs(song.Tracks) do
            if string.lower(track.Name or "") == trackName then return true; end
        end
        return false;
    end
    local function Add(i)
        if i and TrackMatches(i) then
            matched[0] = matched[0] + 1;
            matched[matched[0]] = i;
        end
    end

    if taggedPath and taggedPath ~= "" then
        -- New clients: exact folder+filename; no ambiguous same-name popup.
        local path = string.lower(string.gsub(taggedPath, "\\", "/"));
        if string.sub(path, 1, 1) ~= "/" then path = "/" .. path; end
        Add(self.songByPath[path]);
        -- Do not fall back to a different song when a path was explicitly sent.
        return matched;
    end

    if taggedHash and taggedHash ~= "" then
        for _, i in ipairs(self.songByHash[string.lower(taggedHash)] or { }) do
            if string.lower(SongDB.Songs[i].Filename or "") == filename then Add(i); end
        end
        return matched;
    end

    -- Legacy clients: filename + part title, falling back to track title only.
    for _, i in ipairs(self.songsByFilename[filename] or { }) do Add(i); end
    if matched[0] == 0 then
        for i = 1, librarySize do Add(i); end
    end
    return matched;
end

function SongBook3Window:Find_OtherPlayer_SyncedSong_Index_WithOnlySync (TrackName)
	local SongIndex = {};
	
	local Number_Of_Found_Songs = 0;
	SongIndex[0] = Number_Of_Found_Songs;
	
	local Synced_TrackName = string.lower( TrackName );
	
	for i = 1, librarySize do
		
		local trackcount = #SongDB.Songs[i].Tracks;
		
		for j = 1, trackcount do
			local SongDB_TrackName = string.lower( SongDB.Songs[i].Tracks[j].Name );

			-- Check if track name starts with 63-len-max track name sent by lotro
			if Synced_TrackName == string.sub(SongDB_TrackName, 1, #Synced_TrackName) then
				Number_Of_Found_Songs = Number_Of_Found_Songs + 1;
				SongIndex[Number_Of_Found_Songs] = i;
				break;
			end
		end
	end
	
	SongIndex[0] = Number_Of_Found_Songs;
	
	return SongIndex;
end

function SongBook3Window:Update_syncMessage (SongIndex, PlayerName, TrackName)
	
	Multiple_songs_match_Synced = 0;
	Sinduriel.SongBook3.Windows.Main.MatchedSongsWindow:SetVisible(false);
	
	if SongIndex[0] > 1 and Settings.hideMatchedSongsPopup ~= "true" then
		YouDontHaveTheSameSong_Flag = 0;
		if PlayerName == songBook3Window.sPlayerName then
			-- OtherPlayer_SyncedSong_Index = selectedSongIndex;
			-- OtherPlayer_SyncedSong_Filepath = SongDB.Songs[OtherPlayer_SyncedSong_Index].Filepath;
			-- OtherPlayer_SyncedSong_Filename = SongDB.Songs[OtherPlayer_SyncedSong_Index].Filename;
			
			-- self.syncMessageTitle:SetText(PlayerName .. "-> " .. OtherPlayer_SyncedSong_Filepath .. " " .. OtherPlayer_SyncedSong_Filename);
			
			-- if OtherPlayer_Synced == 0 then
				-- self.syncMessageTitle:SetForeColor( self.colour_syncMessageTitle );
			-- else
				-- self.syncMessageTitle:SetForeColor( self.colour_syncMessageTitle_OnlySynced );
			-- end
			
			-- self.syncMessageTitle:SetVisible(false);
		else
			--MatchedSongsIndex = SongIndex;
			Multiple_songs_match_Synced = 1;
			self.syncMessageTitle:SetText(PlayerName .. "-> " .. TrackName .. " - Multiple songs match");
			if OtherPlayer_Synced == 0 then
				self.syncMessageTitle:SetForeColor( self.colour_syncMessageTitle );
			else
				self.syncMessageTitle:SetForeColor( self.colour_syncMessageTitle_OnlySynced );
			end
			self.syncMessageTitle:SetVisible(true);
			
			Sinduriel.SongBook3.Windows.Main.MatchedSongsListbox:ClearItems( );
			for i = 1, SongIndex[0] do
				local SongItem = Turbine.UI.Label();
				SongItem:SetMultiline( false )
				SongItem:SetTextAlignment( Turbine.UI.ContentAlignment.MiddleLeft );
				SongItem:SetSize( 2000, 20 );
				SongItem:SetMarkupEnabled(true);
				if OtherPlayer_Synced == 0 then
					SongItem:SetForeColor( self.colour_syncMessageTitle );
				else
					SongItem:SetForeColor( self.colour_syncMessageTitle_OnlySynced );
				end
				SongItem:SetBackColor( self.backColourDefault );
				SongItem:SetText( SongDB.Songs[SongIndex[i]].Filepath .. " " .. SongDB.Songs[SongIndex[i]].Filename );
				Sinduriel.SongBook3.Windows.Main.MatchedSongsListbox:AddItem( SongItem );
				
				SongItem.MouseEnter = function(sender, args)
					if SongItem:IsVisible() then
						if OtherPlayer_Synced == 0 then
							SongItem:SetForeColor( self.colour_syncMessageTitle_Highlighted );
						else
							SongItem:SetForeColor( self.colour_syncMessageTitle_Highlighted_OnlySynced );
						end
					end
				end
				SongItem.MouseLeave = function(sender, args)
					if SongItem:IsVisible() then
						if OtherPlayer_Synced == 0 then
							SongItem:SetForeColor( self.colour_syncMessageTitle );
						else
							SongItem:SetForeColor( self.colour_syncMessageTitle_OnlySynced );
						end
					end
				end
				SongItem.MouseDown = function(sender,args)
					if SongItem:IsVisible() then
						if OtherPlayer_Synced == 0 then
							SongItem:SetForeColor( self.colour_syncMessageTitle_MouseDown );
						else
							SongItem:SetForeColor( self.colour_syncMessageTitle_MouseDown_OnlySynced );
						end
					end
				end
				SongItem.MouseUp = function(sender,args)
					if SongItem:IsVisible() then
						if OtherPlayer_Synced == 0 then
							SongItem:SetForeColor( self.colour_syncMessageTitle );
						else
							SongItem:SetForeColor( self.colour_syncMessageTitle_OnlySynced );
						end
						
						SelectedMatchedSong_Index = SongIndex[i];
	
						songBook3Window:SelectDir( nil, SongDB.Songs[SelectedMatchedSong_Index].Filepath );
						songBook3Window:SelectSong(SelectedMatchedSong_IndexListBox);
						local selectedItem = songBook3Window.songlistBox:GetItem( SelectedMatchedSong_IndexListBox )
						if selectedItem then selectedItem:SetForeColor( songBook3Window.colourDefaultHighlighted ); end
					end
				end
			end
		end
	elseif SongIndex[0] > 1 and Settings.hideMatchedSongsPopup == "true" then
		YouDontHaveTheSameSong_Flag = 0;
		local indexToSelect = 0

		-- Check if any paths are exactly the current dir
		for i = 1, SongIndex[0] do
			if SongDB.Songs[SongIndex[i]].Filepath == selectedDir then
				indexToSelect = i;
				break;
			end
		end

		-- Else check if any paths are a sub-path of the current dir
		if indexToSelect == 0 then
			for i = 1, SongIndex[0] do
				-- Synced_TrackName == string.sub(SongDB_TrackName, 1, #Synced_TrackName)
				if selectedDir == string.sub(SongDB.Songs[SongIndex[i]].Filepath, 1, #selectedDir) then
					indexToSelect = i;
					break;
				end
			end
		end

		-- Else pick first path
		if indexToSelect == 0 then
			indexToSelect = 1;
		end

		OtherPlayer_SyncedSong_Index = SongIndex[indexToSelect];
		OtherPlayer_SyncedSong_Filepath = SongDB.Songs[OtherPlayer_SyncedSong_Index].Filepath;
		OtherPlayer_SyncedSong_Filename = SongDB.Songs[OtherPlayer_SyncedSong_Index].Filename;

		self.syncMessageTitle:SetText(PlayerName .. "-> " .. OtherPlayer_SyncedSong_Filepath .. OtherPlayer_SyncedSong_Filename);
		
		if OtherPlayer_Synced == 0 then
			self.syncMessageTitle:SetForeColor( self.colour_syncMessageTitle );
		else
			self.syncMessageTitle:SetForeColor( self.colour_syncMessageTitle_OnlySynced );
		end
		
		if OtherPlayer_SyncedSong_Filepath .. OtherPlayer_SyncedSong_Filename == SongDB.Songs[selectedSongIndex].Filepath .. selectedSong then
			self.syncMessageTitle:SetVisible(false);
		else
			if OtherPlayer_SyncedSong_Filepath .. OtherPlayer_SyncedSong_Filename ~= "" then
				self.syncMessageTitle:SetVisible(true);
			end
		end
	elseif SongIndex[0] == 0 then
		self.syncMessageTitle:SetText("You don't have the same song. " .. PlayerName .. "-> " .. TrackName);
		if OtherPlayer_Synced == 0 then
			self.syncMessageTitle:SetForeColor( self.colour_syncMessageTitle );
		else
			self.syncMessageTitle:SetForeColor( self.colour_syncMessageTitle_OnlySynced );
		end
		self.syncMessageTitle:SetVisible(true);
		YouDontHaveTheSameSong_Flag = 1;
	elseif SongIndex[0] == 1 then
		YouDontHaveTheSameSong_Flag = 0;
		
		OtherPlayer_SyncedSong_Index = SongIndex[1];
		OtherPlayer_SyncedSong_Filepath = SongDB.Songs[OtherPlayer_SyncedSong_Index].Filepath;
		OtherPlayer_SyncedSong_Filename = SongDB.Songs[OtherPlayer_SyncedSong_Index].Filename;
		
		self.syncMessageTitle:SetText(PlayerName .. "-> " .. OtherPlayer_SyncedSong_Filepath .. OtherPlayer_SyncedSong_Filename);
		
		
		if OtherPlayer_Synced == 0 then
			self.syncMessageTitle:SetForeColor( self.colour_syncMessageTitle );
		else
			self.syncMessageTitle:SetForeColor( self.colour_syncMessageTitle_OnlySynced );
		end
		
		if OtherPlayer_SyncedSong_Filepath .. OtherPlayer_SyncedSong_Filename == SongDB.Songs[selectedSongIndex].Filepath .. selectedSong then
			self.syncMessageTitle:SetVisible(false);
		else
			if OtherPlayer_SyncedSong_Filepath .. OtherPlayer_SyncedSong_Filename ~= "" then
				self.syncMessageTitle:SetVisible(true);
			end
		end
	end
end

-- The floating plugin icon hides every SongBook3-owned window as one group.
-- Remember exactly which windows were open so the next click restores that
-- same workspace instead of opening every auxiliary window indiscriminately.
function SongBook3Window:ToggleUseRaidChat( State )
	self.UseRaidChat = State;
	if State == true then
		self.UseFellowshipChat = false;
	else
	end
	self:PlayerSyncInfo();
end

function SongBook3Window:ToggleUseFellowshipChat( State )
	self.UseFellowshipChat = State;
	if State == true then
		self.UseRaidChat = false;
	else
	end
	self:PlayerSyncInfo();
end



