-- Setlists window: setlist editor, session tab shell, layout, and navigation.
local Main = Sinduriel.SongBook3.Windows.Main;
local MainWindowClass = Main.SongBook3Window;
local Helpers = Sinduriel.SongBook3.Windows.Main;
local ListControls = Sinduriel.SongBook3.Windows.Main;
function MainWindowClass:CreateSetlistsWindow()
    -- Two-pane setlist editor with auto-save and a draggable directory divider.
    self.setlistBtn = Turbine.UI.Lotro.Button();
    self.setlistBtn:SetParent(self);
    self.setlistBtn:SetSize(92, 20);
    self.setlistBtn:SetText("Setlists");
    self.setlistBtn.MouseClick = function()
        self:ShowSetlistTab("Setlists");
        self:RefreshSetlistUI();
        self.setlistWindow:SetVisible(true);
        self.setlistWindow:Activate();
    end;
    self.lyricsBtn = Turbine.UI.Lotro.Button();
    self.lyricsBtn:SetParent(self);
    self.lyricsBtn:SetSize(75, 20);
    self.lyricsBtn:SetText("Lyrics");
    self.lyricsBtn.MouseClick = function()
        self.lyricsWindow:SetVisible(true);
        self.lyricsWindow:Activate();
    end;

    self.setlistWindow = Turbine.UI.Lotro.Window();
    self.setlistWindow:SetText("Setlists");
    -- Keep the familiar default size, but allow a compact 430px layout now
    -- that clicking a song already opens it (no separate Open Song button).
    self.setlistWindow:SetSize(Helpers.SongBook3SavedWindowSize("Setlists", 570, 485, 430, 430));
    self.setlistWindow:SetPosition(250, 150);
    self.setlistWindow:SetVisible(false);
    self.setlistWindow:SetZOrder(180);
    self.setlistNamesHeight = 88;
    self.setlistTabButton = Turbine.UI.Lotro.Button();
    self.setlistTabButton:SetParent(self.setlistWindow);
    self.setlistTabButton:SetSize(100, 24);
    self.setlistTabButton:SetText("Setlists");
    self.setlistTabButton.MouseClick = function() self:ShowSetlistTab("Setlists"); end;
    self.sessionTabButton = Turbine.UI.Lotro.Button();
    self.sessionTabButton:SetParent(self.setlistWindow);
    self.sessionTabButton:SetSize(100, 24);
    self.sessionTabButton:SetText("Session");
    self.sessionTabButton.MouseClick = function() self:ShowSetlistTab("Session"); end;
    -- Match the main window: 12px dark frame, inset black list panel,
    -- a 13px Trajan heading divider and integrated 10px scroll bars.
    self.setlistFrame = Turbine.UI.Control();
    self.setlistFrame:SetParent(self.setlistWindow);
    self.setlistFrame:SetBackColor(Turbine.UI.Color(1, 0.15, 0.15, 0.15));
    self.setlistBody = Turbine.UI.Control();
    self.setlistBody:SetParent(self.setlistWindow);
    self.setlistBody:SetBackColor(Turbine.UI.Color(1, 0, 0, 0));
    local function SetlistButton(text, width, callback)
        local button = Turbine.UI.Lotro.Button();
        button:SetParent(self.setlistWindow);
        button:SetSize(width, 26);
        button:SetText(text);
        button.MouseClick = callback;
        return button;
    end
    self.setlistNameInput = Turbine.UI.Lotro.TextBox();
    self.setlistNameInput:SetParent(self.setlistWindow);
    self.setlistNameInput:SetText(self.activeSetlist);
    self.setlistCreateButton = SetlistButton("Create / Open", 125, function() self:OpenSetlistByName(); end);
    self.setlistNamesHeading = Turbine.UI.Label();
    self.setlistNamesHeading:SetParent(self.setlistWindow);
    self.setlistNamesHeading:SetText("Saved Setlists");
    self.setlistNamesHeading:SetFont(Turbine.UI.Lotro.Font.TrajanPro13);
    self.setlistNamesHeading:SetMouseVisible(false);
    self.setlistNamesList = ListControls.ListBoxScrolled:New(10);
    self.setlistNamesList:SetParent(self.setlistBody);
    self.setlistNamesList:SetVisible(true);
    self.setlistNamesList.SelectedIndexChanged = function(sender)
        if self.refreshingSetlistUI then return; end
        local index = sender:GetSelectedIndex();
        local name = self.setlistData.names[index];
        if name and name ~= self.activeSetlist then
            self.activeSetlist = name;
            self.activeSetlistPosition = 0;
            self.currentSetlistPlayingIndex = 0;
            self:SaveSetlistData();
            self:RefreshSetlistUI();
        end
    end;
    self.setlistDivider = Turbine.UI.Control();
    self.setlistDivider:SetParent(self.setlistWindow);
    self.setlistDivider:SetBackColor(Turbine.UI.Color(1, 0.15, 0.15, 0.15));
    self.setlistDivider:SetZOrder(200);
    self.setlistDivider:SetMouseVisible(true);
    self.setlistDivider.MouseDown = function(sender, args)
        if args.Button == Turbine.UI.MouseButton.Left then
            sender.dragging = true;
            sender.dragStartY = args.Y;
        end
    end;
    self.setlistDivider.MouseUp = function(sender, args) sender.dragging = false; end;
    self.setlistDivider.MouseMove = function(sender, args)
        if not sender.dragging then return; end
        self.setlistNamesHeight = math.max(45, math.min(
            self.setlistWindow:GetHeight() - 285,
            self.setlistNamesHeight + args.Y - sender.dragStartY));
        self:LayoutSetlistWindow();
    end;
    self.setlistSongsHeading = Turbine.UI.Label();
    self.setlistSongsHeading:SetParent(self.setlistDivider);
    self.setlistSongsHeading:SetText("Songs");
    self.setlistSongsHeading:SetFont(Turbine.UI.Lotro.Font.TrajanPro13);
    self.setlistSongsHeading:SetMouseVisible(false);
    self.setlistDividerArrows = Turbine.UI.Control();
    self.setlistDividerArrows:SetParent(self.setlistDivider);
    self.setlistDividerArrows:SetBackground(gDir .. "arrows.tga");
    self.setlistDividerArrows:SetSize(20, 10);
    self.setlistDividerArrows:SetMouseVisible(false);
    self.setlistList = ListControls.ListBoxScrolled:New(10);
    self.setlistList:SetParent(self.setlistBody);
    self.setlistList:SetVisible(true);
    self.setlistList.SelectedIndexChanged = function(sender)
        -- Refreshing a list or moving the main song selection can change the
        -- selected row programmatically. Only a genuine user selection may
        -- navigate, or the two listboxes can continuously select each other.
        if self.refreshingSetlistUI or self.openingSetlistSong then return; end
        local index = sender:GetSelectedIndex();
        if not index or index < 1 then return; end
        self.activeSetlistPosition = index;
        self:OpenSetlistSong(0);
    end;
    self.setlistAdd = SetlistButton("Add Song", 104, function() self:AddCurrentSongToSetlist(); end);
    self.setlistRemove = SetlistButton("Remove", 82, function() self:RemoveSetlistSong(); end);
    self.setlistUp = SetlistButton("Move Up", 79, function() self:MoveSetlistSong(-1); end);
    self.setlistDown = SetlistButton("Move Down", 95, function() self:MoveSetlistSong(1); end);
    self.setlistPrevious = SetlistButton("Previous Song", 127, function() self:OpenSetlistSong(-1); end);
    self.setlistNext = SetlistButton("Next Song", 127, function() self:OpenSetlistSong(1); end);
    self.setlistSend = SetlistButton("Share Setlist", 127, function() self:BeginSetlistShare(); end);
    self.setlistNote = Turbine.UI.Label();
    self.setlistNote:SetParent(self.setlistWindow);
    self.setlistNote:SetMultiline(true);
    self.setlistNote:SetText("Changes Save Automatically to account plugin data.");
    self.setlistTotalTime = Turbine.UI.Label();
    self.setlistTotalTime:SetParent(self.setlistWindow);
    self.setlistTotalTime:SetMultiline(false);
    self.setlistTotalTime:SetMouseVisible(false);
    self.setlistTotalTime:SetForeColor(self.colourDefault);
    self.setlistTotalTime:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);

    self.sessionHeading = Turbine.UI.Label();
    self.sessionHeading:SetParent(self.setlistWindow);
    self.sessionHeading:SetText("Songs Played This Session");
    self.sessionHeading:SetFont(Turbine.UI.Lotro.Font.TrajanPro13);
    self.sessionHeading:SetMouseVisible(false);
    self.sessionList = ListControls.ListBoxScrolled:New(10);
    self.sessionList:SetParent(self.setlistBody);
    self.sessionList.SelectedIndexChanged = function(sender)
        if self.refreshingSessionUI then return; end
        local index = sender:GetSelectedIndex();
        local entry = (index and index > 0) and
            (self.sessionVisibleEntries or {})[index] or nil;
        self.sessionSelectedEntryId = entry and entry.id or nil;
        self.sessionSelectedPath = entry and entry.path or nil;
        self:UpdateSessionSelectionHighlight();
    end;
    local function SessionButton(text, width, callback)
        local button = Turbine.UI.Lotro.Button();
        button:SetParent(self.setlistWindow);
        button:SetSize(width, 26);
        button:SetText(text);
        button.MouseClick = callback;
        return button;
    end
    self.sessionMarkButton = SessionButton("Mark Played", 100, function() self:MarkCurrentSongPlayed(true); end);
    self.sessionRemoveButton = SessionButton("Mark Unplayed", 110, function() self:RemoveSessionPlayed(); end);
    self.sessionResetButton = SessionButton("Reset Session", 105, function() self:ResetSessionPlayed(); end);
    self.sessionSelectButton = SessionButton("Select Song", 100, function() self:SelectSessionSong(); end);
    self.sessionNote = Turbine.UI.Label();
    self.sessionNote:SetParent(self.setlistWindow);
    self.sessionNote:SetText("Auto-marked when your playback starts; use Mark Played for manual entries.");
    self.sessionNote:SetMultiline(true);

    -- Resize from the lower-right corner; the saved-list splitter still works.
    self.setlistResize = Helpers.SongBook3AttachResizeGrip(self.setlistWindow, 430, 430,
        function() self:LayoutSetlistWindow(); end,
        function() self:SaveSettings(); end);
    self:LayoutSetlistWindow();
    self:RefreshSetlistUI();
    self:ShowSetlistTab("Setlists");

end

-- ======= Setlists =======
-- Changes are immediately persisted with Turbine.PluginData.Save. No Save
-- button is necessary, and a failed save is displayed instead of hidden.
function MainWindowClass:SaveSetlistData()
    self.setlistData.active = self.activeSetlist;
    Main.SongBook3Save(Turbine.DataScope.Account, "SongBook3Setlists", self.setlistData,
        function(ok, message)
            if not ok then
                if self.setlistNote then
                    self.setlistNote:SetText("Save Failed: " .. tostring(message));
                end
                Turbine.Shell.WriteLine("SongBook3 setlist save failed: " .. tostring(message));
            end
        end);
end

-- SongBook3's song/track titles commonly include the estimated performance
-- length as a trailing (m:ss) token. Use the same metadata that the classic
-- playback timer reads, counting each setlist entry once (not each part).
local function SongBook3ParseDuration(text)
    if type(text) ~= "string" then return nil; end
    local minutes, seconds = string.match(text, "%((%d+):(%d%d?)%)");
    minutes = tonumber(minutes);
    seconds = tonumber(seconds);
    if not minutes or not seconds or seconds < 0 or seconds >= 60 then return nil; end
    return minutes * 60 + seconds;
end

local function SongBook3SongDuration(song)
    if not song then return nil; end
    local longestTrackDuration = nil;
    for _, track in ipairs(song.Tracks or {}) do
        local duration = SongBook3ParseDuration(track.Name);
        if duration and (not longestTrackDuration or duration > longestTrackDuration) then
            longestTrackDuration = duration;
        end
    end
    if longestTrackDuration then return longestTrackDuration; end
    return SongBook3ParseDuration(song.Filename);
end

local function SongBook3FormatDuration(seconds)
    local minutes = math.floor(seconds / 60);
    local remainder = seconds - minutes * 60;
    return string.format("%d:%02d", minutes, remainder);
end

function MainWindowClass:GetSetlistDuration(setlistName)
    local songs = self.setlistData.lists[setlistName] or {};
    local totalSeconds = 0;
    local unknownCount = 0;
    for _, path in ipairs(songs) do
        local songIndex = self.songByPath[string.lower(path or "")];
        local duration = songIndex and SongBook3SongDuration(Main.SongDB.Songs[songIndex]) or nil;
        if duration then
            totalSeconds = totalSeconds + duration;
        else
            unknownCount = unknownCount + 1;
        end
    end
    return totalSeconds, unknownCount, #songs;
end

function MainWindowClass:FormatSetlistDuration(setlistName)
    local totalSeconds, unknownCount, songCount = self:GetSetlistDuration(setlistName);
    if unknownCount == songCount and songCount > 0 then
        return "Unknown", totalSeconds, unknownCount, songCount;
    end
    local formatted = SongBook3FormatDuration(totalSeconds);
    if unknownCount > 0 then
        formatted = formatted .. " + " .. unknownCount .. " unknown";
    end
    return formatted, totalSeconds, unknownCount, songCount;
end

-- LOTRO does not expose a simple text-measurement function. A conservative
-- width estimate makes long single-line labels wider than their viewport, so
-- the native ListBox horizontal scrollbar can reveal the entire line.
function MainWindowClass:LayoutSetlistWindow()
    local width, height = self.setlistWindow:GetSize();
    local paneTop = 136;
    local paneBottom = height - 138;
    local space = paneBottom - paneTop - 13;
    self.setlistNamesHeight = math.max(45,
        math.min(space - 45, self.setlistNamesHeight));
    self.setlistTabButton:SetPosition(18, 42);
    self.sessionTabButton:SetPosition(126, 42);
    self.setlistNameInput:SetPosition(18, 75);
    self.setlistNameInput:SetSize(width - 189, 24);
    self.setlistCreateButton:SetPosition(width - 155, 75);
    self.setlistNamesHeading:SetPosition(18, 125);
    self.setlistNamesHeading:SetSize(width - 36, 13);
    self.sessionHeading:SetPosition(18, 125);
    self.sessionHeading:SetSize(width - 36, 13);
    -- Use the same dimensions as the main window's listFrame/listContainer:
    -- frame right margin 11px, content right margin 10px, 10px scroll bars.
    self.setlistFrame:SetPosition(12, paneTop - 13);
    self.setlistFrame:SetSize(width - 23, paneBottom - (paneTop - 13) + 7);
    self.setlistBody:SetPosition(18, paneTop);
    self.setlistBody:SetSize(width - 28, paneBottom - paneTop);
    local listWidth = width - 38;
    self.setlistNamesList:SetPosition(0, 0);
    self.setlistNamesList:SetSize(listWidth, self.setlistNamesHeight);
    local dividerTop = paneTop + self.setlistNamesHeight;
    self.setlistDivider:SetPosition(18, dividerTop);
    self.setlistDivider:SetSize(width - 28, 13);
    self.setlistSongsHeading:SetPosition(0, 0);
    self.setlistSongsHeading:SetSize(125, 13);
    self.setlistDividerArrows:SetPosition(math.floor((width - 28) / 2) - 10, 1);
    local songsTop = dividerTop + 13;
    self.setlistList:SetPosition(0, songsTop - paneTop);
    self.setlistList:SetSize(listWidth, paneBottom - songsTop);
    self.sessionList:SetPosition(0, 0);
    self.sessionList:SetSize(listWidth, paneBottom - paneTop);
    -- Existing labels must grow/shrink with the pane, without rebuilding the
    -- list or firing its SelectedIndexChanged handler (prior freeze fix).
    for i = 1, self.setlistNamesList:GetItemCount() do
        local item = self.setlistNamesList:GetItem(i);
        if item then item:SetSize(math.max(100, listWidth - 8), 20); end
    end
    for i = 1, self.setlistList:GetItemCount() do
        local item = self.setlistList:GetItem(i);
        if item then item:SetSize(math.max(100, listWidth - 8), 20); end
    end
    for i = 1, self.sessionList:GetItemCount() do
        local item = self.sessionList:GetItem(i);
        if item then item:SetSize(math.max(100, listWidth - 8), 20); end
    end
    local rowA = height - 124;
    self.setlistAdd:SetPosition(18, rowA);
    self.setlistRemove:SetPosition(125, rowA);
    self.setlistUp:SetPosition(212, rowA);
    self.setlistDown:SetPosition(296, rowA);
    local rowB = height - 92;
    self.setlistPrevious:SetPosition(18, rowB);
    self.setlistNext:SetPosition(150, rowB);
    self.setlistSend:SetPosition(284, rowB);
    self.setlistNote:SetPosition(18, height - 64);
    self.setlistNote:SetSize(width - 55, 24);
    self.setlistTotalTime:SetPosition(18, height - 35);
    self.setlistTotalTime:SetSize(width - 55, 16);

    local sessionGap = 6;
    local sessionWidth = math.floor((width - 36 - sessionGap * 3) / 4);
    local sessionButtons = { self.sessionMarkButton, self.sessionRemoveButton,
        self.sessionResetButton, self.sessionSelectButton };
    for i, button in ipairs(sessionButtons) do
        button:SetPosition(18 + (i - 1) * (sessionWidth + sessionGap), rowA);
        button:SetSize(sessionWidth, 26);
    end
    self.sessionNote:SetPosition(18, height - 96);
    self.sessionNote:SetSize(width - 36, 30);
end


function MainWindowClass:ShowSetlistTab(tabName)
    if not self.setlistWindow then return; end
    self.setlistActiveTab = (tabName == "Session") and "Session" or "Setlists";
    local showLists = self.setlistActiveTab == "Setlists";
    self.setlistTabButton:SetEnabled(not showLists);
    self.sessionTabButton:SetEnabled(showLists);
    for _, control in ipairs({ self.setlistNameInput, self.setlistCreateButton,
        self.setlistNamesHeading, self.setlistNamesList, self.setlistDivider,
        self.setlistList, self.setlistAdd, self.setlistRemove, self.setlistUp,
        self.setlistDown, self.setlistPrevious, self.setlistNext, self.setlistSend,
        self.setlistNote, self.setlistTotalTime }) do
        control:SetVisible(showLists);
    end
    self.sessionHeading:SetVisible(not showLists);
    self.sessionList:SetVisible(not showLists);
    self.sessionMarkButton:SetVisible(not showLists);
    self.sessionRemoveButton:SetVisible(not showLists);
    self.sessionResetButton:SetVisible(not showLists);
    self.sessionSelectButton:SetVisible(not showLists);
    self.sessionNote:SetVisible(not showLists);
    self:LayoutSetlistWindow();
    if not showLists then self:RefreshSessionUI(); end
end

function MainWindowClass:GetCurrentSetlistIndex()
    local songs = self.setlistData.lists[self.activeSetlist] or {};
    local song = Main.SongDB.Songs[Main.selectedSongIndex];
    if not song then return 0; end
    local fullPath = Helpers.SongBook3SongPath(song);
    local index = self.currentSetlistPlayingIndex or 0;
    if songs[index] and string.lower(songs[index]) == fullPath then return index; end
    for i, path in ipairs(songs) do
        if string.lower(path) == fullPath then return i; end
    end
    return 0;
end

-- Change only row text/colours when the currently selected main-window song
-- changes.  Clearing and rebuilding a ListBox from inside a selection callback
-- can raise another selection event and freeze LOTRO.
function MainWindowClass:UpdateSetlistSelectionHighlight()
    if not self.setlistList or self.refreshingSetlistUI then return; end
    local songs = self.setlistData.lists[self.activeSetlist] or {};
    local playing = self:GetCurrentSetlistIndex();
    self.currentSetlistPlayingIndex = playing;
    for i, path in ipairs(songs) do
        local item = self.setlistList:GetItem(i);
        if item then
            item:SetText((i == playing and "> " or "   ") .. i .. ". " .. path);
            item:SetForeColor(i == playing and self.colourDefaultHighlighted or self.colourDefault);
        end
    end
end

function MainWindowClass:RefreshSetlistUI()
    if not self.setlistList then return; end
    self.refreshingSetlistUI = true;
    local songs = self.setlistData.lists[self.activeSetlist] or {};
    self.setlistNameInput:SetText(self.activeSetlist);
    self.setlistWindow:SetText("Setlists");
    self.setlistNamesList:ClearItems();
    for i, name in ipairs(self.setlistData.names) do
        local item = Turbine.UI.Label();
        item:SetSize(math.max(100, self.setlistNamesList:GetWidth() - 8), 20);
        item:SetMultiline(false);
        local durationText = self:FormatSetlistDuration(name);
        item:SetText(name .. " (" .. #(self.setlistData.lists[name] or {}) .. " Songs) (" .. durationText .. ")");
        if name == self.activeSetlist then
            item:SetForeColor(self.colourDefaultHighlighted);
        end
        self.setlistNamesList:AddItem(item);
        if name == self.activeSetlist then self.setlistNamesList:SetSelectedIndex(i); end
    end
    self.setlistList:ClearItems();
    local playing = self:GetCurrentSetlistIndex();
    self.currentSetlistPlayingIndex = playing;
    for i, path in ipairs(songs) do
        local label = Turbine.UI.Label();
        label:SetSize(math.max(100, self.setlistList:GetWidth() - 8), 20);
        label:SetMultiline(false);
        label:SetText((i == playing and "> " or "   ") .. i .. ". " .. path);
        label:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);
        if i == playing then
            label:SetForeColor(self.colourDefaultHighlighted);
        else
            label:SetForeColor(self.colourDefault);
        end
        self.setlistList:AddItem(label);
    end
    if self.activeSetlistPosition > #songs then self.activeSetlistPosition = #songs; end
    if self.activeSetlistPosition > 0 then
        self.setlistList:SetSelectedIndex(self.activeSetlistPosition);
    end
    local durationText, totalSeconds, unknownCount, songCount = self:FormatSetlistDuration(self.activeSetlist);
    if unknownCount > 0 then
        if unknownCount < songCount then
            self.setlistTotalTime:SetText("Total Time: " .. SongBook3FormatDuration(totalSeconds) ..
                " (" .. unknownCount .. " songs without duration)");
        else
            self.setlistTotalTime:SetText("Total Time: Unknown (" .. unknownCount .. " songs without duration)");
        end
    else
        self.setlistTotalTime:SetText("Total Time: " .. durationText);
    end
    self.refreshingSetlistUI = false;
    if self.setlistActiveTab == "Session" then self:RefreshSessionUI(); end
end

function MainWindowClass:OpenSetlistByName()
    local name = self.setlistNameInput:GetText() or "";
    name = string.gsub(name, "^%s*(.-)%s*$", "%1");
    if name == "" then return; end
    if #name > 55 then name = string.sub(name, 1, 55); end
    if not self.setlistData.lists[name] then
        self.setlistData.lists[name] = {};
        table.insert(self.setlistData.names, name);
    end
    self.activeSetlist = name;
    self.activeSetlistPosition = 0;
    self.currentSetlistPlayingIndex = 0;
    self:SaveSetlistData();
    self:RefreshSetlistUI();
    self.setlistNote:SetText("Changes Save Automatically. Select a setlist above to open it.");
end

function MainWindowClass:CycleSetlist(delta)
    local current = 1;
    for i, name in ipairs(self.setlistData.names) do
        if name == self.activeSetlist then current = i; break; end
    end
    local count = #self.setlistData.names;
    if count == 0 then return; end
    self.activeSetlist = self.setlistData.names[((current - 1 + delta) % count) + 1];
    self.activeSetlistPosition = 0;
    self.currentSetlistPlayingIndex = 0;
    self:SaveSetlistData();
    self:RefreshSetlistUI();
end

function MainWindowClass:AddCurrentSongToSetlist()
    local song = Main.SongDB.Songs[Main.selectedSongIndex];
    if not song or not Main.selectedSong or Main.selectedSong == "" then return; end
    local songs = self.setlistData.lists[self.activeSetlist];
    if not songs then return; end
    table.insert(songs, Helpers.SongBook3SongPath(song));
    self.activeSetlistPosition = #songs;
    self:SaveSetlistData();
    self:RefreshSetlistUI();
    self.setlistNote:SetText("Added Song. Changes Save Automatically.");
end

function MainWindowClass:RemoveSetlistSong()
    local songs = self.setlistData.lists[self.activeSetlist] or {};
    local index = self.setlistList:GetSelectedIndex();
    if not index or index < 1 or index > #songs then return; end
    table.remove(songs, index);
    self.activeSetlistPosition = math.min(index, #songs);
    if self.currentSetlistPlayingIndex == index then
        self.currentSetlistPlayingIndex = 0;
    elseif self.currentSetlistPlayingIndex > index then
        self.currentSetlistPlayingIndex = self.currentSetlistPlayingIndex - 1;
    end
    self:SaveSetlistData();
    self:RefreshSetlistUI();
    self.setlistNote:SetText("Removed Song. Changes Save Automatically.");
end

function MainWindowClass:MoveSetlistSong(delta)
    local songs = self.setlistData.lists[self.activeSetlist] or {};
    local index = self.setlistList:GetSelectedIndex();
    if not index or index < 1 or index + delta < 1 or index + delta > #songs then return; end
    songs[index], songs[index + delta] = songs[index + delta], songs[index];
    if self.currentSetlistPlayingIndex == index then
        self.currentSetlistPlayingIndex = index + delta;
    elseif self.currentSetlistPlayingIndex == index + delta then
        self.currentSetlistPlayingIndex = index;
    end
    self.activeSetlistPosition = index + delta;
    self:SaveSetlistData();
    self:RefreshSetlistUI();
    self.setlistNote:SetText("Reordered Songs. Changes Save Automatically.");
end

-- direction: -1 previous, 0 open selection, +1 next.
-- A guarded entry point is important: LOTRO's ListBox selection event may
-- fire synchronously while the main browser or setlist row is being updated.
-- Never allow the resulting callbacks to recursively open the same song.
function MainWindowClass:OpenSetlistSong(direction)
    if self.openingSetlistSong then return; end
    self.openingSetlistSong = true;
    local ok, err = pcall(self.OpenSetlistSongCore, self, direction);
    self.openingSetlistSong = false;
    if not ok then
        local message = "Setlist Could Not Open Song: " .. tostring(err);
        if self.setlistNote then self.setlistNote:SetText(message); end
        Turbine.Shell.WriteLine("SongBook3: " .. message);
    end
end

function MainWindowClass:OpenSetlistSongCore(direction)
    local songs = self.setlistData.lists[self.activeSetlist] or {};
    if #songs == 0 then return; end
    direction = direction or 0;
    local index;
    if direction == 0 then
        index = self.setlistList:GetSelectedIndex();
        if not index or index < 1 then index = self.activeSetlistPosition; end
        if not index or index < 1 then index = 1; end
    else
        local current = self:GetCurrentSetlistIndex();
        if current < 1 then current = self.setlistList:GetSelectedIndex(); end
        if not current or current < 1 then
            index = direction > 0 and 1 or #songs;
        else
            index = math.max(1, math.min(current + direction, #songs));
        end
    end
    local path = songs[index];
    local songIndex = self.songByPath[string.lower(path or "")];
    if not songIndex then
        self.setlistNote:SetText("Not In Library: " .. (path or "") .. "\nRebuild the song database if moved.");
        return;
    end

    -- Avoid needlessly repopulating the main browser (and firing its own
    -- selection events) when the requested song is already visible.
    local directory = Main.SongDB.Songs[songIndex].Filepath;
    local listIndex;
    if Main.selectedDir == directory then
        for i, v in ipairs(self.aFilteredIndices or {}) do
            if v == songIndex then listIndex = i; break; end
        end
    end
    if not listIndex then
        self:SelectDir(nil, directory);
        for i, v in ipairs(self.aFilteredIndices or {}) do
            if v == songIndex then listIndex = i; break; end
        end
    end
    if not listIndex then
        self.setlistNote:SetText("Song Hidden By Current Filters: " .. path);
        return;
    end

    self.currentSetlistPlayingIndex = index;
    self.activeSetlistPosition = index;
    if self.songlistBox:GetSelectedIndex() ~= listIndex then
        self.songlistBox:SetSelectedIndex(listIndex);
    end
    -- The native SelectedIndexChanged callback normally selects the song;
    -- call it explicitly only if no callback updated the main song yet.
    if Main.selectedSongIndex ~= songIndex then self:SelectSong(listIndex); end
    if self.setlistList:GetSelectedIndex() ~= index then
        self.setlistList:SetSelectedIndex(index);
    end
    self:UpdateSetlistSelectionHighlight();
    self.setlistNote:SetText("Selected " .. (Main.SongDB.Songs[songIndex].Filename or "") ..
        ". Choose a part and sync normally. Changes Save Automatically.");
end

-- Send a setlist with explicit quickslot clicks; LOTRO disallows Lua-side chat
-- sending. Percent-encoded chunks are bounded to keep chat messages short.
