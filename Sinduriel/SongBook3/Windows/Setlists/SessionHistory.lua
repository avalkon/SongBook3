-- Session history is SongBook3's play log.
local Main = Sinduriel.SongBook3.Windows.Main;
local MainWindowClass = Main.SongBook3Window;
local Helpers = Sinduriel.SongBook3.Windows.Main;
function MainWindowClass:UpdateSessionSelectionHighlight()
    if not self.sessionList then return; end
    for i = 1, self.sessionList:GetItemCount() do
        local item = self.sessionList:GetItem(i);
        local entry = (self.sessionVisibleEntries or {})[i];
        if item then
            item:SetForeColor(entry and entry.id == self.sessionSelectedEntryId and
                self.colourDefaultHighlighted or self.colourDefault);
        end
    end
end

function MainWindowClass:RefreshSessionUI()
    if not self.sessionList then return; end
    local previousId = self.sessionSelectedEntryId;
    self.refreshingSessionUI = true;
    self.sessionList:ClearItems();
    self.sessionVisibleEntries = { };
    local selectedIndex = 0;
    local playedCount = 0;
    for _, entry in ipairs(self.sessionPlayedOrder or {}) do
        local path = type(entry) == "table" and entry.path or entry;
        if path and path ~= "" then
            playedCount = playedCount + 1;
            local songIndex = self.songByPath[string.lower(path or "")];
            local song = songIndex and Main.SongDB.Songs[songIndex] or nil;
            local labelText = song and ((song.Filename or "Song") .. "  -  " .. (song.Filepath or "/")) or path;
            local item = Turbine.UI.Label();
            item:SetSize(math.max(100, self.sessionList:GetWidth() - 8), 20);
            item:SetMultiline(false);
            item:SetText(labelText);
            item:SetTextAlignment(Turbine.UI.ContentAlignment.MiddleLeft);
            item:SetForeColor(self.colourDefault);
            self.sessionList:AddItem(item);
            self.sessionVisibleEntries[#self.sessionVisibleEntries + 1] = entry;
            if type(entry) == "table" and entry.id == previousId then
                selectedIndex = #self.sessionVisibleEntries;
            end
        end
    end
    self.sessionHeading:SetText("Songs Played This Session (" .. tostring(playedCount) .. ")");
    if selectedIndex > 0 then
        local selectedEntry = self.sessionVisibleEntries[selectedIndex];
        self.sessionSelectedEntryId = selectedEntry.id;
        self.sessionSelectedPath = selectedEntry.path;
        self.sessionList:SetSelectedIndex(selectedIndex);
    elseif self.sessionList:GetItemCount() > 0 then
        local lastIndex = self.sessionList:GetItemCount();
        local selectedEntry = self.sessionVisibleEntries[lastIndex];
        self.sessionSelectedEntryId = type(selectedEntry) == "table" and selectedEntry.id or nil;
        self.sessionSelectedPath = type(selectedEntry) == "table" and selectedEntry.path or selectedEntry;
        self.sessionList:SetSelectedIndex(lastIndex);
    else
        self.sessionSelectedEntryId = nil;
        self.sessionSelectedPath = nil;
    end
    self.refreshingSessionUI = false;
    self:UpdateSessionSelectionHighlight();
end

function MainWindowClass:MarkSongPlayedByIndex(songIndex, manual)
    local song = Main.SongDB.Songs[songIndex];
    if not song then
        if manual and self.sessionNote then self.sessionNote:SetText("Select a song in the main window first."); end
        return false;
    end
    local path = Helpers.SongBook3SongPath(song);
    if path == "" then return false; end

    -- Append every play, even when the same song already appears earlier.
    self.sessionNextEntryId = (self.sessionNextEntryId or 0) + 1;
    local entry = { id = self.sessionNextEntryId, path = path };
    table.insert(self.sessionPlayedOrder, entry);
    self.sessionPlayed[path] = (self.sessionPlayed[path] or 0) + 1;
    self.sessionSelectedEntryId = entry.id;
    self.sessionSelectedPath = path;
    if manual and self.sessionNote then self.sessionNote:SetText("Marked " .. (song.Filename or path) .. " as played this session."); end
    self:RefreshSessionUI();
    return true;
end

function MainWindowClass:MarkCurrentSongPlayed(manual)
    return self:MarkSongPlayedByIndex(Main.selectedSongIndex, manual);
end

function MainWindowClass:MarkStartedSongPlayed(trackName)
    local wanted = Helpers.SongBook3NormalizeTitle(trackName or "");
    local function SongMatches(song)
        if not song or wanted == "" then return false; end
        local filename = Helpers.SongBook3NormalizeTitle(song.Filename or "");
        local filenameWithoutExtension = string.gsub(filename, "%.abc$", "");
        if wanted == filename or wanted == filenameWithoutExtension then return true; end
        for _, track in ipairs(song.Tracks or { }) do
            if Helpers.SongBook3NormalizeTitle(track.Name or "") == wanted then return true; end
        end
        return false;
    end

    local selected = Main.SongDB.Songs[Main.selectedSongIndex];
    if selected and (wanted == "" or SongMatches(selected)) then
        return self:MarkSongPlayedByIndex(Main.selectedSongIndex, false);
    end

    local matchIndex = nil;
    local ambiguous = false;
    for i, song in ipairs(Main.SongDB.Songs or { }) do
        if SongMatches(song) then
            if matchIndex and matchIndex ~= i then
                ambiguous = true;
            else
                matchIndex = i;
            end
        end
    end
    if matchIndex and not ambiguous then
        return self:MarkSongPlayedByIndex(matchIndex, false);
    end

    -- A local playback-start event with an unrecognised/omitted part title
    -- still belongs to the song currently selected in SongBook3 (including
    -- the song most recently opened from a setlist).
    if selected then return self:MarkSongPlayedByIndex(Main.selectedSongIndex, false); end
    return false;
end

function MainWindowClass:RemoveSessionPlayed()
    local selectedId = self.sessionSelectedEntryId;
    local selectedPath = self.sessionSelectedPath;
    local removeIndex = nil;
    for i = #self.sessionPlayedOrder, 1, -1 do
        local entry = self.sessionPlayedOrder[i];
        local entryId = type(entry) == "table" and entry.id or nil;
        local entryPath = type(entry) == "table" and entry.path or entry;
        if (selectedId and entryId == selectedId) or
           (not selectedId and selectedPath and entryPath == selectedPath) then
            removeIndex = i;
            break;
        end
    end
    if not removeIndex then
        self.sessionNote:SetText("Select a played entry to remove.");
        return;
    end
    local removed = table.remove(self.sessionPlayedOrder, removeIndex);
    local removedPath = type(removed) == "table" and removed.path or removed;
    if removedPath then
        local count = self.sessionPlayed[removedPath] or 0;
        if count <= 1 then self.sessionPlayed[removedPath] = nil;
        else self.sessionPlayed[removedPath] = count - 1; end
    end
    self.sessionSelectedEntryId = nil;
    self.sessionSelectedPath = nil;
    self:RefreshSessionUI();
    self.sessionNote:SetText("Removed this play from the session.");
end

function MainWindowClass:ResetSessionPlayed()
    self.sessionPlayed = { };
    self.sessionPlayedOrder = { };
    self.sessionNextEntryId = 0;
    self.sessionSelectedEntryId = nil;
    self.sessionSelectedPath = nil;
    self:RefreshSessionUI();
    self.sessionNote:SetText("Session history cleared.");
end

function MainWindowClass:SelectSongByPath(path)
    local songIndex = self.songByPath[string.lower(path or "")];
    if not songIndex then return false; end
    local directory = Main.SongDB.Songs[songIndex].Filepath;
    self:SelectDir(nil, directory);
    local listIndex = nil;
    for i, value in ipairs(self.aFilteredIndices or {}) do
        if value == songIndex then listIndex = i; break; end
    end
    if not listIndex then return false; end
    if self.songlistBox:GetSelectedIndex() ~= listIndex then
        self.songlistBox:SetSelectedIndex(listIndex);
    end
    if Main.selectedSongIndex ~= songIndex then self:SelectSong(listIndex); end
    local selectedItem = self.songlistBox:GetItem(listIndex);
    if selectedItem then selectedItem:SetForeColor(self.colourDefaultHighlighted); end
    return true;
end

function MainWindowClass:SelectSessionSong()
    local path = self.sessionSelectedPath;
    if not path then self.sessionNote:SetText("Select a song in the session list first."); return; end
    if self:SelectSongByPath(path) then
        self.sessionNote:SetText("Selected song in the main library.");
    else
        self.sessionNote:SetText("Song is unavailable or hidden by the current filters.");
    end
end

