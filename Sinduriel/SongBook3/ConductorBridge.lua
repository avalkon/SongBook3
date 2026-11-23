-- ConductorBridge 0.10.0, for Sinduriel SongBook3 v1.25.4.2.
-- Import AFTER SongBook3Window is constructed. Writes only through Turbine.PluginData.
import "Turbine.Gameplay";

local function Print(s) Turbine.Shell.WriteLine("Conductor: " .. tostring(s)); end
local function Clean(s)
    s = tostring(s or "");
    s = string.gsub(s, "%%", "_");
    return string.gsub(s, "[\r\n]", " ");
end
local function Main()
    return Sinduriel and Sinduriel.SongBook3 and Sinduriel.SongBook3.Windows
        and Sinduriel.SongBook3.Windows.Main or nil;
end
local function Window()
    -- Both objects are part of the SongBook3 module, never rely on Lua globals.
    local m = Main();
    -- Main.lua creates this window in the plugin top-level environment.
    return songBook3Window or (m and m.songBook3Window) or nil;
end
local function SongPath(song)
    local m = Main();
    if not m or type(m.SongBook3SongPath) ~= "function" then
        error("SongBook3 path helper unavailable");
    end
    return m.SongBook3SongPath(song);
end

local latest = nil;
local saving = false;
local queued = nil;
local token = ""; -- Only ever set by a deliberate /conductor identify <nonce> command.
local modeObserved = false;
local localReadyTrack = nil; -- Text from THIS client's localized game-ready chat line.
local function TrackKey(value)
    return string.lower(string.gsub(tostring(value or ""), "[^%w]", ""));
end

local function Snapshot()
    local m = Main();
    local w = Window();
    local player = Turbine.Gameplay.LocalPlayer:GetInstance();
    if not player then error("LocalPlayer unavailable"); end
    local instrument = "No instrument";
    local equipment = player:GetEquipment();
    if equipment then
        local item = equipment:GetItem(Turbine.Gameplay.Equipment.Instrument);
        if item then instrument = item:GetName(); end
    end
    local songs = m and m.SongDB and m.SongDB.Songs;
    local song = type(songs) == "table" and songs[m.selectedSongIndex or -1] or nil;
    local path = song and SongPath(song) or "";
    local track = 0;
    if song and w and type(w.SelectedTrackIndex) == "function" then
        local index = w:SelectedTrackIndex(m.selectedTrack);
        local part = index and song.Tracks and song.Tracks[index];
        if part then track = tonumber(part.Id) or 0; end
    end
    local musicMode = "unknown";
    if modeObserved and w then
        musicMode = w.timerInMusicMode == true and "observed-on" or "observed-off";
    end
    local ready = "unconfirmed";
    -- PlayerSynced changes only on a local game chat ready event. Require the
    -- same current song and track, NOT remote players' sync reports.
    if song and m and m.PlayerSynced == 1 then
        local selectedIndex = w and type(w.SelectedTrackIndex) == "function"
            and w:SelectedTrackIndex(m.selectedTrack) or nil;
        local part = selectedIndex and song.Tracks and song.Tracks[selectedIndex];
        local exactReadyText = part and localReadyTrack ~= nil
            and TrackKey(part.Name) ~= "" and TrackKey(part.Name) == TrackKey(localReadyTrack);
        local songBookReady = m.selectedSongIndex == m.syncedSongIndex
            and m.selectedTrack == m.syncedTrack;
        if exactReadyText or songBookReady then ready = "ready"; end
    end
    -- CG2 remains a literal substring in LOTRO's Lua .plugindata file.
    return "CG2%" .. Clean(player:GetName()) .. "%" .. Clean(instrument) .. "%"
        .. Clean(path) .. "%" .. tostring(track) .. "%" .. musicMode .. "%"
        .. ready .. "%" .. token .. "%", player:GetName();
end

local function Write(value, verbose)
    saving = true;
    Turbine.PluginData.Save(Turbine.DataScope.Character, "ConductorStatus", value,
        function(ok, message)
            saving = false;
            if ok then
                latest = value;
                if verbose then Print("report SAVED"); end
            else
                Print("status save FAILED: " .. tostring(message));
            end
            if queued then
                local nextReport = queued;
                queued = nil;
                if nextReport.force or latest ~= nextReport.value then
                    Write(nextReport.value, nextReport.verbose);
                end
            end
        end);
end
local function Report(force, verbose)
    local value, name = Snapshot();
    if saving then
        if force or value ~= latest then queued = { value=value, force=force, verbose=verbose }; end
        return;
    end
    if not force and value == latest then return; end
    Write(value, verbose);
    if verbose then Print("report requested for " .. tostring(name)); end
end
local function SafeReport()
    local ok, err = pcall(function() Report(false, false); end);
    if not ok then Print("report ERROR: " .. tostring(err)); end
end
function conductorBridgeOnEquipmentChanged() SafeReport(); end
function conductorBridgeOnSelectionChanged() localReadyTrack = nil; SafeReport(); end
function conductorBridgeOnSyncStateChanged() SafeReport(); end
function conductorBridgeOnLocalReady(trackName)
    localReadyTrack = trackName;
    SafeReport();
end
function conductorBridgeOnPlaybackStarted()
    localReadyTrack = nil;
    SafeReport();
end
function conductorBridgeOnMusicModeChanged()
    modeObserved = true;
    SafeReport();
end

local function LibraryState()
    local m = Main();
    local w = Window();
    local available = w ~= nil and type(w.SelectSong) == "function"
        and type(w.SelectTrack) == "function";
    local songs = m and m.SongDB and type(m.SongDB.Songs) == "table"
        and m.SongDB.Songs or nil;
    return available, songs;
end
local function Diagnose()
    local w, songs = LibraryState();
    Print("SongBook3 window=" .. (w and "ready" or "missing") .. ", library="
        .. (songs and (tostring(#songs) .. " songs") or "missing")
        .. "; use /conductor report to inspect character state.");
end
local warned = false;
local function Select(path, partId)
    local m = Main();
    local wReady, songs = LibraryState();
    local w = Window();
    if not wReady or not songs then
        if not warned then
            warned = true;
            Print("NOTE: SongBook selection skipped; window/library unavailable. /play sync still works.");
        end
        return;
    end
    warned = false;
    path = string.lower(string.gsub(path, "\\", "/"));
    path = string.gsub(path, "%.abc$", "");
    if string.sub(path, 1, 1) ~= "/" then path = "/" .. path; end
    local dbIndex = nil;
    for i, song in ipairs(songs) do
        if string.lower(SongPath(song)) == path then dbIndex = i; break; end
    end
    if not dbIndex then error("Song not found in SongBook3 library: " .. path); end
    local song = songs[dbIndex];
    local trackIndex = nil;
    for i, track in ipairs(song.Tracks or {}) do
        if tonumber(track.Id) == partId then trackIndex = i; break; end
    end
    if not trackIndex then error("Track X:" .. tostring(partId) .. " not found in " .. path); end
    local function VisibleRow()
        for i, dbId in ipairs(w.aFilteredIndices or {}) do
            if dbId == dbIndex then return i; end
        end
        return nil;
    end
    local row = VisibleRow();
    if not row then
        w:SelectDir(nil, song.Filepath, true);
        row = VisibleRow();
    end
    if not row then error("Song hidden by SongBook filters: " .. path); end
    -- SongBook's SelectSong updates internal selection but does not select the
    -- underlying ListBox row. SetSelectedIndex is what makes it highlighted.
    -- The ListBox callback may also call SelectSong; this is harmless here.
    if w.songlistBox and type(w.songlistBox.SetSelectedIndex) == "function" then
        w.songlistBox:SetSelectedIndex(row);
    end
    w:SelectSong(row);
    if w.songlistBox and type(w.SetListboxColours) == "function" then
        w:SetListboxColours(w.songlistBox);
    end
    w:SelectSetup(nil);
    local displayIndex = w.bShowReadyChars and trackIndex * 2 or trackIndex;
    w:SelectTrack(displayIndex);
    if m.selectedSongIndex ~= dbIndex or
       w:SelectedTrackIndex(m.selectedTrack) ~= trackIndex then
        error("SongBook did not select requested track; no success reported");
    end
    Print("selected " .. path .. " X:" .. tostring(partId));
    Report(false, false);
end

conductorBridgeCommand = Turbine.ShellCommand();
function conductorBridgeCommand:Execute(command, arguments)
    local args = tostring(arguments or "");
    local ok, err = pcall(function()
        if string.match(args, "^%s*report%s*$") then Report(true,true); return; end
        if string.match(args, "^%s*diagnose%s*$") then Diagnose(); return; end
        local nonce = string.match(args, "^%s*identify%s+([0-9a-fA-F]+)%s*$");
        if nonce then
            if #nonce < 16 or #nonce > 64 then error("Identify token length must be 16..64 hex characters"); end
            token = string.lower(nonce);
            Report(true, true);
            return;
        end
        local path, part = string.match(args,"^%s*select%s+(.+)%s+|%s*(%d+)%s*$");
        if path and part then Select(path, tonumber(part)); return; end
        Print("usage: /conductor report | diagnose | identify <hex> | select /song | 1");
    end);
    if not ok then Print("ERROR: " .. tostring(err)); end
end
function conductorBridgeCommand:GetHelp()
    return "/conductor report | diagnose | identify <hex> | select /folder/song | 1";
end
function conductorBridgeCommand:GetShortHelp() return "Conductor bridge status and SongBook selection"; end
Turbine.Shell.AddCommand("conductor", conductorBridgeCommand);
Print("Bridge 0.10.0 LOADED. Try /conductor diagnose");
local ok, err = pcall(function() Report(true,false); end);
if not ok then Print("initial report ERROR: " .. tostring(err)); end
